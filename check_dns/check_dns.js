// Use this script to check for and remove dangling DNS entries:
//   $(maws)
//   node check_dns.js generate-report
//   node check_dns.js delete-records --report-id="<report_id>"

const AWS = require("aws-sdk");
const fs = require("fs");
const path = require("path");
const yargs = require("yargs");
const readline = require("readline");

const logger = (function () {
  let quiet = false;
  return {
    setQuiet: (q) => {
      quiet = q;
    },
    // log: (msg) => {
    //   if (!quiet) {
    //     console.log(msg, ...arguments);
    //   }
    // },
    log: console.log,
    warn: console.warn,
    error: console.error,
  };
})();

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

// function load_array(name) {
//   return load_string(name).split("\n");
// }

function load_string(name) {
  const filename = path.join(__dirname, `${name}`);
  const string = fs.readFileSync(filename, "utf8");
  return string;
}

function load_json(name) {
  const string = load_string(`${name}.json`);
  return JSON.parse(string);
}

function write_json(name, obj) {
  const filename = path.join(__dirname, `${name}.json`);
  const string = JSON.stringify(obj);
  fs.writeFileSync(filename, string);
}

async function fetch_all_ec2_instances() {
  return [
    ...(await ec2_describe_instances({ region: "us-west-1" })),
    ...(await ec2_describe_instances({ region: "us-west-2" })),
    ...(await ec2_describe_instances({ region: "us-east-1" })),
    ...(await ec2_describe_instances({ region: "us-east-2" })),
    ...(await ec2_describe_instances({ region: "ca-central-1" })),
  ];
}

async function ec2_describe_instances({ region }) {
  const ec2 = new AWS.EC2({ region });
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
      const NameTags = Tags.filter(function ({ Key }) {
        return Key === "Name";
      });
      const Name = (NameTags.length && NameTags[0].Value) || "";
      instances.push({
        InstanceId,
        PrivateIpAddress,
        PublicIpAddress,
        Name,
      });
    });
  });
  return instances;
}

const list_resource_record_sets = (function () {
  const route53 = new AWS.Route53();
  return async function list_resource_record_sets({
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

async function fetch_all_resource_record_sets(hosted_zone_id) {
  let record_sets = [];
  let response = {};
  do {
    response = await list_resource_record_sets({
      HostedZoneId: hosted_zone_id,
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

// This is only relevant for reticulum nodes
// const has_valid_hostname = (function () {
//   const adjectives = load_array("../packer/shared/files/hostname-adjectives");
//   const nouns = load_array("../packer/shared/files/hostname-nouns");
//   return function has_valid_hostname({ Name }) {
//     names = Name.split(/[-\.]/); // split on hyphen (-) and dot (.)
//     return (
//       names.length >= 2 &&
//       adjectives.indexOf(names[0]) !== -1 &&
//       nouns.indexOf(names[1]) !== -1
//     );
//   };
// })();

// This is only relevant for reticulum nodes
// function filter_by_hostname(dns_records) {
//   return dns_records.filter(has_valid_hostname);
// }

function filter_by_has_ip(dns_records) {
  return dns_records.filter(function ({ ResourceRecords }) {
    return ResourceRecords.length === 1 && !!ResourceRecords[0].Value;
  });
}

function has_matching_ip(dns_record_ip) {
  return function match({ PrivateIpAddress, PublicIpAddress }) {
    return (
      PrivateIpAddress === dns_record_ip || PublicIpAddress === dns_record_ip
    );
  };
}

function matches_dns_record({ ResourceRecords, Name }) {
  const record_ip = ResourceRecords[0] && ResourceRecords[0].Value;
  const check_match_ip = has_matching_ip(record_ip);
  return function match(ec2_instance) {
    // This name check was only valid for reticulum nodes.
    // name_matches =
    //   Name === `${ec2_instance.Name}.reticulum.io.` ||
    //   Name === `${ec2_instance.Name}-local.reticulum.io.`;
    // return !!record_ip && name_matches;

    // Find an ec2 node whose ip address matches the dns record.
    ip_matches = check_match_ip(ec2_instance);
    return !!record_ip && ip_matches;
  };
}

function filter_by_no_matching_ec2_instance(dns_records, ec2_instances) {
  return dns_records.filter(function (record) {
    return !ec2_instances.find(matches_dns_record(record));
  });
}

function filter_dns_records({ ec2_instances, dns_records }) {
  let unmatched_records = dns_records;
  unmatched_records = filter_by_type(unmatched_records, "A");
  unmatched_records = filter_by_has_ip(unmatched_records);
  unmatched_records = filter_by_no_matching_ec2_instance(
    unmatched_records,
    ec2_instances
  );

  // This is only valid for reticulum nodes
  // unmatched_records = filter_by_hostname(unmatched_records);

  return unmatched_records;
}

async function batch_delete_dns_records({ dry, records, hosted_zone_id }) {
  if (dry) {
    logger.log(
      `These ${records.length} records will not be deleted because this is a dry run.\n`
    );
    return 0;
  }
  changes = records.map(function (record) {
    return {
      Action: "DELETE",
      ResourceRecordSet: record,
    };
  });

  const route53 = new AWS.Route53();
  try {
    const result = await promisify(
      route53.changeResourceRecordSets.bind(route53)
    )({
      ChangeBatch: { Changes: changes },
      HostedZoneId: hosted_zone_id,
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

    rl.question("Press any key to continue...", function () {
      rl.close();
      resolve();
    });
  });
}

function delete_records_with_confirmation_prompt({
  dry,
  records,
  hosted_zone_id,
  hosted_zone_name,
}) {
  return new Promise(function (resolve) {
    const separator =
      "---------------------------------------------------------------------------------------";
    logger.log(`\n${separator}\n`);
    logger.log("Records to be deleted:");
    logger.log(JSON.stringify(records, null, 2));
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    const message = dry
      ? "(This is a dry run. Records will NOT be deleted.)\n"
      : "(CAUTION: THIS IS NOT A DRY RUN. Records WILL be deleted.)\n";
    rl.question(
      [
        ``,
        `Hosted Zone Name : ${hosted_zone_name}`,
        `Hosted Zone Id   : ${hosted_zone_id}`,
        `${message}`,
        `Are you sure you want to delete these ${records.length} records?`,
        `(Type "delete" to confirm.)`,
        ``,
      ].join("\n"),
      async function (answer) {
        rl.close();
        if (answer === "delete") {
          logger.log("\nAttempting to delete records...\n");
          await batch_delete_dns_records({ dry, records, hosted_zone_id });
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

async function delete_records({
  target_report_id,
  is_dry_run,
  program_name,
  command_delete_records,
  option_report_id,
}) {
  if (!target_report_id) {
    logger.error(
      [
        `Error: No report id specified.`,
        `       You must specify a report by id to indicate which unmatched dns records you want to delete:`,
        `           node ${program_name} ${command_delete_records} --${option_report_id}=<YOUR_REPORT_ID>`,
      ].join("\n")
    );

    return 0;
  }

  const { report_directory, hosted_zones_filename } =
    files_for_report_id(target_report_id);

  const hosted_zones = load_json(hosted_zones_filename);
  for (const zone of hosted_zones) {
    const hosted_zone_name = zone.Name;
    const hosted_zone_id = zone.Id.match(/\/hostedzone\/(.*)/)[1];
    const hosted_zone_directory = path.join(report_directory, hosted_zone_id);
    const unmatched_dns_records_filename = path.join(
      hosted_zone_directory,
      "unmatched_dns_records"
    );
    const unmatched_dns_records = load_json(unmatched_dns_records_filename);

    const BATCH_SIZE = 100;
    let records_to_delete = unmatched_dns_records.splice(0, BATCH_SIZE);
    while (records_to_delete.length) {
      await delete_records_with_confirmation_prompt({
        dry: is_dry_run,
        records: records_to_delete,
        hosted_zone_id,
        hosted_zone_name,
      });
      records_to_delete = unmatched_dns_records.splice(0, BATCH_SIZE);
    }
  }

  logger.log("Finished.");
}

const route53_list_hosted_zones = (function () {
  const route53 = new AWS.Route53();
  return async function route53_list_hosted_zones({
    DelegationSetId,
    Marker,
    MaxItems,
  }) {
    return await promisify(route53.listHostedZones.bind(route53))({
      DelegationSetId,
      Marker,
      MaxItems,
    });
  };
})();

async function fetch_all_route53_hosted_zones() {
  let hosted_zones = [];
  let response = {};
  do {
    response = await route53_list_hosted_zones({
      DelegationSetId: null,
      Marker: response.NextMarker || null,
      MaxItems: "100",
    });
    hosted_zones = hosted_zones.concat(response.HostedZones);
  } while (response.IsTruncated);
  return hosted_zones;
}

function make_directory(directory) {
  if (!fs.existsSync()) {
    fs.mkdirSync(directory, { recursive: true });
  }
}

function files_for_report_id(report_id) {
  const report_directory = `./reports/${report_id}/`;
  const hosted_zones_filename = path.join(report_directory, "hosted_zones");
  const ec2_instances_filename = path.join(report_directory, "ec2_instances");
  return {
    report_directory,
    hosted_zones_filename,
    ec2_instances_filename,
  };
}

const allow_list = [
  "reticulum.io.",
  "hubs.social.",
  "hubs.link.",
  "hub.link.",
  "fxr.zone.",
  "hubs-proxy.com.",
  "mozillareality.com.",
  "hubs-login.com.",
  "ducksandrobots.com.",
  "robotsandducks.com.",
  "tryhubs.com.",
  "quackstack.net.",
  "quak.me.",
  "polycosm.net.",
  "polycosm2.net.",
  "quackstack2.net.",
  "quak2.me.",
  "hubs-cloud.com.",
  "quak.link.",
  "jasonsvirtualworld.com.",
  "hubsloadtesting.com.",
  "mozillatubs.com.",
  "hihc.link.",
  "hellohubscloud.com.",
  "hubs.club.",
  "hubsloadtesting.link.",
  "tubbs.link.",
  "hello-hubs-cloud.com.",
  "hubs.today.",
  "hubs.chat.",
  "hubs.wtf.",
  "hubs.fun.",
  "svtesthub.com.",
  "svtesthub.link.",
  "svtesthub2.com.",
  "svtesthub2.link.",
  "svtesthub3.com.",
  "svtesthub3.link.",
  "svtesthub4.com.",
  "svtesthub4.link.",
];

function filter_by_allow_list({ hosted_zones, allow_list }) {
  const in_list = hosted_zones.filter((zone) => allow_list.includes(zone.Name));
  const not_in_list = hosted_zones.filter(
    (zone) => !allow_list.includes(zone.Name)
  );
  return { in_list, not_in_list };
}

async function generate_report({
  command_delete_records,
  option_report_id,
  option_dry_run,
  program_name,
}) {
  const report_id = timestamp_for_date(new Date());
  const { report_directory, hosted_zones_filename, ec2_instances_filename } =
    files_for_report_id(report_id);
  make_directory(report_directory);

  const all_hosted_zones = await fetch_all_route53_hosted_zones();
  hosted_zones = all_hosted_zones.filter((zone) =>
    allow_list.includes(zone.Name)
  );
  disallowed_hosted_zones = all_hosted_zones.filter(
    (zone) => !allow_list.includes(zone.Name)
  );
  write_json(hosted_zones_filename, hosted_zones);

  const ec2_instances = await fetch_all_ec2_instances();
  write_json(ec2_instances_filename, ec2_instances);

  const summary = await Promise.all(
    hosted_zones.map(async (zone) => {
      const hosted_zone_id = zone.Id.match(/\/hostedzone\/(.*)/)[1];
      const hosted_zone_directory = path.join(report_directory, hosted_zone_id);
      make_directory(hosted_zone_directory);

      const dns_records = await fetch_all_resource_record_sets(hosted_zone_id);
      const dns_records_filename = path.join(
        hosted_zone_directory,
        "dns_records"
      );
      write_json(dns_records_filename, dns_records);

      unmatched_dns_records = filter_dns_records({
        ec2_instances,
        dns_records,
      });
      const unmatched_dns_records_filename = path.join(
        hosted_zone_directory,
        "unmatched_dns_records"
      );
      write_json(unmatched_dns_records_filename, unmatched_dns_records);

      return {
        hosted_zone_id,
        hosted_zone_name: zone.Name,
        num_dns_records: dns_records.length,
        num_unmatched_dns_records: unmatched_dns_records.length,
      };
    })
  );

  const summary_filename = path.join(report_directory, "summary");
  write_json(summary_filename, summary);

  const report_summary = summary.some((info) => info.num_unmatched_dns_records)
    ? summary
        .filter((info) => info.num_unmatched_dns_records)
        .map(
          ({ hosted_zone_name, hosted_zone_id, num_unmatched_dns_records }) =>
            `    ${String(num_unmatched_dns_records).padStart(
              2
            )} unmatched DNS records found for hosted zone ${hosted_zone_name} (${hosted_zone_id}).`
        )
    : ["    No unmatched DNS records found. You're all good!"];

  logger.log(
    [
      `Report with id ${report_id} generated successfully.`,
      ``,
      `    ${report_directory}`,
      `    ./${hosted_zones_filename}.json`,
      `    ./${ec2_instances_filename}.json`,
      `    ./${summary_filename}.json`,
      `    ${report_directory}<HOSTED_ZONE_ID>/dns_records.json`,
      `    ${report_directory}<HOSTED_ZONE_ID>/unmatched_dns_records.json`,
      ``,
      "Ignoring these hosted zones:",
      ...disallowed_hosted_zones.map((zone) => `    ${zone.Name}`),
      "",
      `Report Summary:`,
      ...report_summary,
      ``,
      `See ${report_directory}<HOSTED_ZONE_ID> for details about a particular hosted zone.`,
      ``,
      `To delete dangling DNS records, use:`,
      `    node ${program_name} ${command_delete_records} --${option_report_id}="${report_id}"`,
      ``,
      `To preview this command without deleting records, use the --${option_dry_run} option:`,
      `    node ${program_name} ${command_delete_records} --${option_report_id}="${report_id}" --${option_dry_run}`,
    ].join("\n")
  );

  return {
    report_id,
    report_directory,
    hosted_zones_filename,
    ec2_instances_filename,
    hosted_zones,
    ec2_instances,
    summary,
  };
}

function init() {
  command_generate_report = "generate-report";
  command_delete_records = "delete-records";
  option_report_id = "report-id";
  option_dry_run = "dry";
  option_quiet = "quiet";

  const argv = yargs
    .usage("Usage: node $0 <command> [options]")
    .epilog(
      "You need to run $(maws) in your shell to have the correct AWS credentials"
    )
    .command(
      command_generate_report,
      "Generate a report about which DNS records do not have a matching EC2 node."
    )
    .command(
      command_delete_records,
      "Delete the DNS records that do not have a matching EC2 node."
    )
    .options(option_report_id, {
      alias: "t",
      description: "Specify which report to follow when deleting records.",
      type: "string",
    })
    .options(option_dry_run, {
      alias: "d",
      description: "Dry run. Will not execute deletes.",
      type: "boolean",
    })
    .options(option_quiet, {
      alias: "q",
      description:
        "Do not write messages to the console while running unless an error occurs.",
      type: "boolean",
    })
    .help()
    .alias("help", "h")
    .showHelpOnFail(true)
    .demandCommand().argv;

  return {
    command_delete_records,
    option_report_id,
    option_dry_run,
    program_name: argv["$0"],
    is_dry_run: !!argv[option_dry_run],
    should_only_log_errors: !!argv[option_quiet],
    should_generate_report: argv._.includes(command_generate_report),
    should_delete_records: argv._.includes(command_delete_records),
    target_report_id: argv[option_report_id],
    argv_underscore: argv._,
  };
}

function timestamp_for_date(date) {
  return [
    [date.getFullYear(), date.getMonth() + 1, date.getDate()].join("-"),
    [date.getHours(), date.getMinutes(), date.getSeconds()].join("-"),
  ].join("_");
}

function main() {
  const {
    command_delete_records,
    option_report_id,
    option_dry_run,
    program_name,
    is_dry_run,
    should_only_log_errors,
    should_generate_report,
    should_delete_records,
    target_report_id,
    argv_underscore,
  } = init();

  logger.setQuiet(should_only_log_errors);

  if (should_generate_report) {
    generate_report({
      command_delete_records,
      option_report_id,
      option_dry_run,
      program_name,
    });
  } else if (should_delete_records) {
    delete_records({
      target_report_id,
      is_dry_run,
      program_name,
      command_delete_records,
      option_report_id,
    });
  } else {
    logger.warn("Unknown command:", argv_underscore);
    logger.warn("Try invoking --help");
  }
}

main();
