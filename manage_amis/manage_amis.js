#! node
const yargs = require("yargs");
const { exec } = require("child_process");

const argv = yargs
  .usage("Usage: node $0 <command> [options]")
  .epilog(
    "You need to set the HUBS_OPS_SECRETS_PATH environment variable and run $(maws) in your shell to get the mixed-reality role credentials."
  )
  .command("add", "Add an account to AMIs")
  .example("$0 add --accountId 12345")
  .command("list", "List the most recently used AMIs in the manifest file.")
  .command("remove", "Remove account from AMIs")
  .options("accountId", {
    description:
      "The account id that will gain or lose launch-permission on the AMIs",
    type: "string",
  })
  .help()
  .alias("help", "h")
  .showHelpOnFail(true)
  .demandCommand().argv;

function get_most_recent_amis() {
  return new Promise(function (resolve, reject) {
    exec("./list-amis.sh", function (error, stdout, stderr) {
      if (error) {
        console.error(error);
        process.exit(1);
      }
      amis = JSON.parse(stdout);
      resolve(amis);
    });
  });
}

async function list_amis() {
  const amis = await get_most_recent_amis();
  console.log(amis);
}

async function modify_launch_perms_for_amis(action) {
  const amis = await get_most_recent_amis();
  const accountId = argv.accountId;
  if (!accountId) {
    console.error(`Must set the accountId.`);
    return 0;
  }
  console.log(`Performing ${action} ${accountId} on amis:\n`, amis);
  for (const { region, ami_id } of amis) {
    await modify_launch_perms(action, accountId, ami_id, region);
  }
}

async function modify_launch_perms(action, accountId, ami_id, region) {
  return new Promise(function (resolve, reject) {
    console.log({ action, accountId, ami_id, region });
    exec(
      `./share-ami.sh ${action} ${accountId} ${ami_id} ${region}`,
      function (error, stdout, stderr) {
        if (error) {
          console.error(error);
          process.exit(1);
        }
        if (stderr) {
          console.error(stderr);
          process.exit(1);
        }
        console.log(stdout);
        resolve(stdout);
      }
    );
  });
}

function main() {
  if (argv._.includes("list")) {
    list_amis();
  } else if (argv._.includes("add")) {
    modify_launch_perms_for_amis("add");
  } else if (argv._.includes("remove")) {
    modify_launch_perms_for_amis("remove");
  } else {
    logger.log("Unknown command.", argv._);
    logger.log("Try invoking --help");
  }
}
main();
