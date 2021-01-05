const AWS = require("aws-sdk");
const fs = require("fs");
const path = require("path");
const yargs = require("yargs");
const readline = require("readline");

const argv = yargs
  .usage("Usage: node $0 <command> [options]")
  .epilog(
    "You need to run $(maws) in your shell to have the correct AWS credentials"
  )
  .command(
    "fetch",
    "Fetches ec2 and route53 data from AWS, and saves that info to json files in this directory."
  )
  .example(
    "$0 fetch -z MY_HOSTED_ZONE_ID",
    "Fetches data from AWS and write ec2_instances.json and dns_records.json"
  )
  .command(
    "filter",
    "Filters the (local copy of) DNS records to find the ones that should be deleted."
  )
  .example(
    "$0 filter",
    "Identifies the DNS records that should be deleted and writes that to unmatched_dns_records.json"
  )
  .command("delete", "Delete a DNS record by the given name.")
  .example(
    "$0 delete -n some-subdomain -z MY_HOSTED_ZONE_ID",
    "Finds the Route53 DNS record with name some-subdomain.my-hosted-zone"
  )
  .command(
    "delete-unmatched",
    "Delete the DNS records that do not match an EC2 node."
  )
  .example(
    "$0 delete-unmatched -z MY_HOSTED_ZONE_ID",
    "Deletes the unmatched DNS records (asks for confirmation in batches)."
  )
  .options("hosted_zone_id", {
    alias: "z",
    description: "The Route53 HostedZoneId",
    type: "string",
  })
  .options("record_name", {
    alias: "n",
    description: "A record name to delete",
    type: "string",
  })
  .options("dry", {
    alias: "d",
    description: "Dry run. Will not execute deletes.",
    type: "boolean",
  })
  .options("quiet", {
    alias: "q",
    description:
      "Do not write messages to the console while running unless an error occurs.",
    type: "boolean",
  })
  .help()
  .alias("help", "h")
  .showHelpOnFail(true)
  .demandCommand().argv;

const logger = {
  log: function (msg) {
    if (!argv.quiet) {
      console.log(msg);
    }
  },
  error: console.error,
};

const promisify = (f) => (arg) =>
  new Promise((res, rej) =>
    f(arg, (err, data) => {
      if (err) {
        logger.error(err);
        rej(err);
      } else {
        res(data);
      }
    })
  );

function load_array(name) {
  return load_string(name).split("\n");
}

function load_string(name) {
  const filename = path.join(__dirname, `${name}`);
  const string = fs.readFileSync(filename, "utf8");
  return string;
}

function load_json(name) {
  const string = load_string(name);
  return JSON.parse(string);
}

function write_json(name, obj) {
  const filename = path.join(__dirname, `${name}.json`);
  const string = JSON.stringify(obj);
  fs.writeFileSync(filename, string);
}

async function load_ec2_instances() {
  const ec2 = new AWS.EC2({
    region: "us-west-1",
  });
  const instanceInfo = await promisify(ec2.describeInstances.bind(ec2))({
    Filters: [
      {
        Name: "instance-state-name",
        Values: ["running"],
      },
    ],
  });

  const instances = [];
  instanceInfo["Reservations"].map(function ({ Instances }) {
    Instances.map(function ({
      InstanceId,
      PrivateIpAddress,
      PublicIpAddress,
      Tags,
    }) {
      instances.push({
        InstanceId,
        PrivateIpAddress,
        PublicIpAddress,
        Name: Tags.filter(function ({ Key }) {
          return Key === "Name";
        })[0].Value,
      });
    });
  });
  return instances;
}

const load_dns_records = (function () {
  const route53 = new AWS.Route53();
  return async function load_dns_records({
    StartRecordName,
    StartRecordType,
    HostedZoneId,
    MaxItems,
  }) {
    return await promisify(route53.listResourceRecordSets.bind(route53))({
      StartRecordName,
      StartRecordType,
      HostedZoneId,
      MaxItems,
    });
  };
})();

async function load_all_dns_records() {
  let record_sets = [];
  let response = {};
  do {
    response = await load_dns_records({
      HostedZoneId: argv.hosted_zone_id,
      MaxItems: "100",
      StartRecordName: response.NextRecordName,
      StartRecordType: response.NextRecordType,
    });
    record_sets = record_sets.concat(response.ResourceRecordSets);
  } while (response.IsTruncated);
  return record_sets;
}

function filter_by_type(dns_records, type) {
  return dns_records.filter(function ({ Type }) {
    return Type === type;
  });
}

const has_valid_hostname = (function () {
  const adjectives = load_array("../packer/shared/files/hostname-adjectives");
  const nouns = load_array("../packer/shared/files/hostname-nouns");
  return function has_valid_hostname({ Name }) {
    names = Name.split(/[-\.]/); // split on hyphen (-) and dot (.)
    return (
      names.length >= 2 &&
      adjectives.indexOf(names[0]) !== -1 &&
      nouns.indexOf(names[1]) !== -1
    );
  };
})();

function filter_by_hostname(dns_records) {
  return dns_records.filter(has_valid_hostname);
}

function filter_by_has_ip(dns_records) {
  return dns_records.filter(function ({ ResourceRecords }) {
    return ResourceRecords.length === 1 && !!ResourceRecords[0].Value;
  });
}

function has_matching_ip(ip) {
  return function match({ PrivateIpAddress, PublicIpAddress }) {
    return PrivateIpAddress === ip || PublicIpAddress === ip;
  };
}

function matches_dns_record({ ResourceRecords, Name }) {
  const record_ip = ResourceRecords[0] && ResourceRecords[0].Value;
  const check_match_ip = has_matching_ip(record_ip);
  return function match(ec2_instance) {
    name_matches =
      Name === `${ec2_instance.Name}.reticulum.io.` ||
      Name === `${ec2_instance.Name}-local.reticulum.io.`;
    ip_matches = check_match_ip(ec2_instance); // Not needed. I just used this to find anomalies

    return !!record_ip && name_matches;
  };
}

function filter_by_ec2_instances(dns_records, ec2_instances) {
  return dns_records.filter(function (record) {
    return !ec2_instances.find(matches_dns_record(record));
  });
}

async function fetch_aws_info() {
  if (!argv.hosted_zone_id) {
    logger.error(
      `Must set the hosted_zone_id.\n  node ${argv["$0"]} fetch --hosted_zone_id <your_hosted_zone_id>\n  node ${argv["$0"]} fetch -z <your_hosted_zone_id>`
    );
    return 0;
  }

  logger.log("Fetching ec2 data...");
  const ec2_instances = await load_ec2_instances();
  logger.log("Writing ec2 data to ec2_instances.json");
  write_json("ec2_instances", ec2_instances);
  logger.log("Fetching route53 data...");
  const dns_records = await load_all_dns_records();
  write_json("dns_records", dns_records);
  logger.log("Writing dns record data to dns_records.json");
}

async function filter_dns_records() {
  const ec2_instances = load_json("ec2_instances.json");
  const dns_records = load_json("dns_records.json");

  let records = dns_records;
  records = filter_by_type(records, "A");
  records = filter_by_has_ip(records);
  records = filter_by_ec2_instances(records, ec2_instances);
  records = filter_by_hostname(records);
  const output_filename = "unmatched_dns_records";
  write_json(output_filename, records);

  logger.log(`Matched ${records.length} records. See ${output_filename}.json`);
}

async function batch_delete_dns_records(records) {
  if (argv.dry) {
    logger.log("Not deleting any records. This is a dry run...");
    return 0;
  }
  changes = records.map(function (record) {
    return {
      Action: "DELETE",
      ResourceRecordSet: {
        Name: record.Name,
        Type: record.Type,
        ResourceRecords: record.ResourceRecords,
        TTL: record.TTL,
        // MultiValueAnswer: true,
        // SetIdentifier: record.SetIdentifier,
        // HealthCheckId: record.HealthCheckId,
      },
    };
  });

  const route53 = new AWS.Route53();
  try {
    const result = await promisify(
      route53.changeResourceRecordSets.bind(route53)
    )({
      ChangeBatch: { Changes: changes },
      HostedZoneId: argv.hosted_zone_id,
    });
    logger.log(result);
  } catch (e) {
    // logger.error(e); // Already logged by promisify
    logger.error("Batch delete request failed. Did not delete records:");
    logger.error(records);
  }
}

function prompt_for_continue() {
  return new Promise(function (resolve, reject) {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    rl.question("Press any key to continue...", function (anything) {
      rl.close();
      resolve();
    });
  });
}

function delete_records_with_confirmation_prompt(records) {
  return new Promise(function (resolve, reject) {
    logger.log(JSON.stringify(records, null, 2));
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    const message = argv.dry
      ? "(This is a dry run. Records will NOT be deleted.)\n"
      : "(CAUTION: THIS IS NOT A DRY RUN. Records WILL be deleted.)\n";
    rl.question(
      `Are you sure you want to delete these records? (Type "delete" to confirm.)\n${message}`,
      async function (answer) {
        rl.close();
        if (answer === "delete") {
          logger.log("Attempting to delete records...");
          await batch_delete_dns_records(records);
          await prompt_for_continue();
        } else {
          logger.log("You chose not to delete these records. Exiting...");
          process.exit(0);
        }
        resolve();
      }
    );
  });
}

async function delete_unmatched_dns_records() {
  if (!argv.hosted_zone_id) {
    logger.error(
      `Must set the hosted_zone_id.\n  node ${argv["$0"]} delete --record_name <your_record_name> --hosted_zone_id <your_hosted_zone_id> \n  node ${argv["$0"]} delete -n <your_record_name> -z <your_hosted_zone_id>`
    );
    return 0;
  }
  const unmatched_dns_records = load_json("unmatched_dns_records.json");

  const BATCH_SIZE = 100;
  let records_to_delete = unmatched_dns_records.splice(0, BATCH_SIZE);
  while (records_to_delete.length) {
    await delete_records_with_confirmation_prompt(records_to_delete);
    records_to_delete = unmatched_dns_records.splice(0, BATCH_SIZE);
  }
  logger.log("Finished.");
}

async function delete_dns_record() {
  if (!argv.hosted_zone_id) {
    logger.error(
      `Must set the hosted_zone_id.\n  node ${argv["$0"]} delete --record_name <your_record_name> --hosted_zone_id <your_hosted_zone_id> \n  node ${argv["$0"]} delete -n <your_record_name> -z <your_hosted_zone_id>`
    );
    return 0;
  }
  if (!argv.record_name) {
    logger.error(
      `Must set the record_name.\n  node ${argv["$0"]} delete --record_name <your_record_name> --hosted_zone_id <your_hosted_zone_id> \n  node ${argv["$0"]} delete -n <your_record_name> -z <your_hosted_zone_id>`
    );
    return 0;
  }
  const dns_records = load_json("dns_records.json");
  const record = dns_records.find(function ({ Name }) {
    return Name === `${argv.record_name}`;
  });
  if (!record) {
    logger.log(
      `Could not find dns record with name ${argv.record_name}. Exiting...`
    );
    return 0;
  }
  await delete_records_with_confirmation_prompt([record]);
  logger.log("Finished.");
}

function main() {
  if (argv._.includes("fetch")) {
    fetch_aws_info();
  } else if (argv._.includes("filter")) {
    filter_dns_records();
  } else if (argv._.includes("delete")) {
    delete_dns_record();
  } else if (argv._.includes("delete-unmatched")) {
    delete_unmatched_dns_records();
  } else {
    logger.log("Unknown command.", argv._);
    logger.log("Try invoking --help");
  }
}
main();
