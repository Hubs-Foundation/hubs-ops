const fetch = require("node-fetch");
const process = require("process");
const mkdirp = require("mkdirp");
const Table = require("cli-table");
const fs = require("fs");
const base32Encode = require("base32-encode");
const { randomBytes } = require("crypto");
const qrcode = require("qrcode");
const qrcodeTerminal = require("qrcode-terminal");
const { writeStackConfigs } = require("./write");
const dns = require("dns");

require("colors");

const randomString = () =>
  Math.random()
    .toString(36)
    .substring(7);

const argv = require("yargs")
  .usage("Usage: arbortect [options] <output-file>")
  .option("d", { alias: "provider", describe: "Cloud provider" })
  .option("f", { alias: "ret-files-path", describe: "Reticulum service files path" })
  .option("y", { alias: "ready-file-path", describe: "Ready file to touch when finish path" })
  .option("b", { alias: "configure-db", describe: "Force manual database configuration" })
  .option("k", { alias: "2fa key destination", describe: "Destination for google pam 2fa configuration" })
  .option("q", { alias: "2fa qr code destination", describe: "Destination for QR code url data" })
  .boolean("b")
  .default("f", "/hab/svc/reticulum/files")
  .choices("d", ["digitalocean"])
  .default("o", "").argv;

const DigitalOcean = require("do-wrapper").default;
const inquirer = require("inquirer");
const getDOHeaders = token => ({ "content-type": "application/json", authorization: `bearer ${token}` });

const DEV_INFO = {
  DO: process.env.DO_TOKEN,
  SMTP: process.env.SMTP_TOKEN,
  IP: "127.0.0.1",
  DROPLET_ID: process.env.DROPLET_ID
};

const isProd = process.env.ARBORTECT_ENV !== "dev";

const runDO = async function(retFilesPath, forceDb, ssh2faConfigFile, ssh2faQrFile, outFile) {
  let token;

  if (isProd) {
    ({ token } = await require("inquirer").prompt([
      {
        type: "password",
        name: "token",
        message:
          "Welcome to Hubs Cloud by Mozilla. Your hub is almost ready.\n\nWe'll need some more info to finish setting it up.\n\n---\n\nBefore continuing:\n\n  - You'll need two registered domain names, one for your site and one for short room links. We recommend using .link domains for short links.\n\n  - Consider adding your two domains to your DigitalOcean project for this droplet.\n    - If you do so, we'll be able to automatically add the necessary DNS records for you.\n    - Otherwise, you'll have to add the necessary DNS records yourself. At the end of setup we'll tell you what records to create.\n\n  - You'll need SMTP connection info for an email provider in order to send emails so you can log in.\n    - We recommend using SendGrid and setting the SMTP port to 2525 to prevent firewall blocking.\n\n  - If you want additional storage for uploads, avatars, and scenes, you should attach a block storage volume to this droplet before continuing.\n\n  - Need help? Visit https://github.com/mozilla/hubs-cloud for documentation and support.\n\n---\n\nReady to set up your hub? Let's go!\n\nFirst, we'll need a writable Personal Access Token from DigitalOcean.\nTo create one, go to https://cloud.digitalocean.com/account/api/tokens.\n\nThis token will *not* be saved.\n\nYour Writable Personal Access Token:"
      }
    ]));
  } else {
    token = DEV_INFO.DO;
  }

  const client = new DigitalOcean(token, 200);
  let ip, dropletId;

  if (isProd) {
    dropletId = await (await fetch("http://169.254.169.254/metadata/v1/id")).text();
    ip = await (await fetch("http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address")).text();
  } else {
    ip = DEV_INFO.IP;
    dropletId = DEV_INFO.DROPLET_ID;
  }

  const { droplet } = (await client.dropletsGetById(dropletId)).body;
  const region = droplet.region.slug;
  const { project, projectResources } = await loadProject(client, dropletId);

  const projectSha = project.id.split("-")[4];

  const stackName = project.name
    .replace(/[^\w ]+/g, "")
    .replace(/ +/g, "-")
    .replace(/^\W+/, "")
    .replace(/\W+$/, "")
    .toLowerCase();

  let configs = { stackName, projectSha, ip };
  configs = { ...configs, ...(await setupAdminEMailDO(project, client)) };
  configs = { ...configs, ...(await setupDomainsDO()) };
  configs = {
    ...configs,
    ...(await setupDatabaseDO(client, stackName, region, project, projectResources, token, forceDb))
  };
  configs = { ...configs, ...(await setupSMTPDo(configs)) };
  configs = { ...configs, ...(await createDNSRecords(client, ip, projectResources, configs)) };

  if (ssh2faConfigFile && ssh2faQrFile && !fs.existsSync(ssh2faConfigFile)) {
    await setupSSH2FA(stackName, ssh2faConfigFile, ssh2faQrFile);
  }

  // End of interactive prompting ^^

  configs = { ...configs, ...(await setupStorage(client, droplet, token)) };

  if (configs.databaseId) {
    await createInitialDb(client, dropletId, configs.databaseId, project, token);
  }

  await configureFirewall(token, stackName, droplet, configs);
  await showFinalSteps(ip, configs);
  await writeStackConfigs(outFile, retFilesPath, configs);
};

async function setupSSH2FA(stackName, configFile, qrFile) {
  if (
    (
      await inquirer.prompt([
        {
          name: "setup2FA",
          type: "confirm",
          message: `To keep your server secure, we highly recommend enabling two-factor authentication for ssh connections.\nYou'll need to install a 2FA app like Google Authenticator.\nEnable ssh two-factor authentication?`,
          default: true
        }
      ])
    ).setup2FA
  ) {
    const bytes = await new Promise(resolve => {
      randomBytes(16, (err, buf) => resolve(buf));
    });
    const secret = base32Encode(bytes, "RFC4648", { padding: false });
    const url = `otpauth://totp/${stackName}-ssh?secret=${secret}&issuer=Hubs+Cloud`;
    const qrUrl = await new Promise(r => qrcode.toDataURL(url, { errorCorrectionLevel: "H" }, (err, url) => r(url)));
    const config = `${secret}\n" RATE_LIMIT 5 30\n" WINDOW_SIZE 3\n" STEP_SIZE 30\n" TOTP_AUTH\n`;
    fs.writeFileSync(configFile, config);
    fs.writeFileSync(qrFile, qrUrl);
    console.log(
      "Great. Here is the QR code to scan.\nYou can also access this QR code in the 'Server Access' section of the Hubs Cloud admin console"
        .brightWhite
    );
    const qrAscii = await new Promise(res => qrcodeTerminal.generate(url, res));
    console.log(qrAscii);
  }
}

async function loadProject(client, dropletId) {
  const { projects } = (await client.projects()).body;
  let project;
  let projectResources;

  for (const p of projects) {
    const { resources } = (await client.projectsGetResources(p.id)).body;

    for (const { urn } of resources) {
      if (urn === `do:droplet:${dropletId}`) {
        project = p;
        projectResources = resources;
        break;
      }
    }

    if (project) break;
  }

  if (project.is_default) {
    console.log(
      "Error: This droplet should be assigned to a project other than the default. To proceed, create a new project for your hub and move this droplet into it."
        .yellow
    );
    process.exit(1); // eslint-disable-line no-process-exit
  }

  for (const { urn } of projectResources) {
    if (urn.startsWith("do:droplet:") && urn !== `do:droplet:${dropletId}`) {
      try {
        const { droplet } = (await client.dropletsGetById(urn.split(":")[2])).body;

        if (droplet.status !== "archive") {
          console.log(
            "Error: This droplet is in a project with one or more other droplets. To proceed, you should remove all other droplets from your project or create a new project and move this droplet into it."
              .yellow
          );
          process.exit(1); // eslint-disable-line no-process-exit
        }
      } catch (e) {
        // Sometimes old droplets can remain in project
      }
    }
  }

  return { project, projectResources };
}

async function configureFirewall(token, stackName, droplet, { smtpPort, databasePort }) {
  const { firewalls } = await (
    await fetch(`https://api.digitalocean.com/v2/firewalls?per_page=200`, {
      headers: getDOHeaders(token)
    })
  ).json();

  if (firewalls) {
    for (const firewall of firewalls) {
      if (firewall.droplet_ids.includes(droplet.id)) {
        console.log(`Removing existing firewall ${firewall.id}.`.cyan);

        await fetch(`https://api.digitalocean.com/v2/firewalls/${firewall.id}`, {
          headers: getDOHeaders(token),
          method: "DELETE"
        });
      }
    }
  }

  const rule = (protocol, ports) => ({ protocol, ports: `${ports}`, sources: { addresses: ["0.0.0.0/0", "::/0"] } });
  const orule = (protocol, ports) => ({
    protocol,
    ports: `${ports}`,
    destinations: { addresses: ["0.0.0.0/0", "::/0"] }
  });

  await fetch(`https://api.digitalocean.com/v2/firewalls`, {
    headers: getDOHeaders(token),
    method: "POST",
    body: JSON.stringify({
      name: `${stackName}-firewall-${randomString()}`,
      droplet_ids: [droplet.id],
      inbound_rules: [
        rule("tcp", 22),
        rule("tcp", 80),
        rule("tcp", 8443),
        rule("tcp", 443),
        rule("udp", "49152-60999")
      ],
      outbound_rules: [
        orule("tcp", 53),
        orule("tcp", 80),
        orule("udp", 123),
        orule("tcp", 443),
        orule("tcp", databasePort),
        orule("tcp", smtpPort),
        orule("udp", "all")
      ]
    })
  });
}

async function setupStorage(client, droplet, token) {
  let storagePath;

  if (droplet.volume_ids.length === 0) {
    console.log("No block storage found. Using droplet disk for asset storage.".cyan);
    storagePath = "/storage";
    await new Promise(res => mkdirp(storagePath, res));
  } else {
    // NOTE uses first volume
    const volumeId = droplet.volume_ids[0];
    const { volume } = await (
      await fetch(`https://api.digitalocean.com/v2/volumes/${volumeId}`, {
        headers: getDOHeaders(token)
      })
    ).json();

    storagePath = `/mnt/${volume.name}`;
    console.log(`Using block storage ${volume.name} (${volume.size_gigabytes} GB) for asset storage.`.cyan);
  }

  await new Promise(res => fs.chown(storagePath, 1001, 1001, res));

  return { storagePath };
}

async function createDNSRecords(client, ip, projectResources, { domainName, rootDomain, linkDomain }) {
  const subdomain = rootDomain === domainName ? "" : domainName.replace(`.${rootDomain}`, "");
  const corsProxyName = `cors-proxy${subdomain === "" ? "" : `.${subdomain}`}`;
  const assetsName = `assets${subdomain === "" ? "" : `.${subdomain}`}`;
  const nearsparkName = `nearspark${subdomain === "" ? "" : `.${subdomain}`}`;
  const corsProxyDomain = `${corsProxyName}.${rootDomain}`;
  const assetsDomain = `${assetsName}.${rootDomain}`;
  const nearsparkDomain = `${nearsparkName}.${rootDomain}`;

  const pendingRecords = {
    hub: [
      { type: "A", name: `${subdomain === "" ? "@" : subdomain}`, data: ip, ttl: 600 },
      { type: "A", name: corsProxyName, data: ip, ttl: 600 },
      { type: "A", name: assetsName, data: ip, ttl: 600 }
    ],
    link: [{ type: "A", name: "@", data: ip, ttl: 600 }]
  };

  const ensureRecord = async (domain, record, currentRecords) => {
    const currentRecord = currentRecords.find(r => r.type === record.type && r.name === record.name);

    if (currentRecord) {
      await client.domainRecordsUpdate(domain, currentRecord.id, record);
    } else {
      await client.domainRecordsCreate(domain, record);
    }
  };

  if (projectResources.find(({ urn }) => urn === `do:domain:${rootDomain}`)) {
    if (
      (
        await inquirer.prompt([
          {
            name: "createDomainRecords",
            type: "confirm",
            message: `The domain ${rootDomain} is in your project. Great!\nWould you like us to create your hub's DNS records?`,
            default: true
          }
        ])
      ).createDomainRecords
    ) {
      const currentRecords = (await client.domainRecordsGetAll(rootDomain)).body.domain_records;

      for (const record of pendingRecords.hub) {
        await ensureRecord(rootDomain, record, currentRecords);
      }

      delete pendingRecords.hub;
    }
  }

  if (projectResources.find(({ urn }) => urn === `do:domain:${linkDomain}`)) {
    if (
      (
        await inquirer.prompt([
          {
            name: "createLinkDomainRecords",
            type: "confirm",
            message: `The shortlink domain ${linkDomain} is in your project. Great!\nWould you like us to create your shortlink DNS records?`,
            default: true
          }
        ])
      ).createLinkDomainRecords
    ) {
      const currentRecords = (await client.domainRecordsGetAll(linkDomain)).body.domain_records;

      for (const record of pendingRecords.link) {
        await ensureRecord(linkDomain, record, currentRecords);
      }

      delete pendingRecords.link;
    }
  }

  return { pendingRecords, assetsDomain, corsProxyDomain, nearsparkDomain };
}

async function showFinalSteps(ip, { rootDomain, linkDomain, pendingRecords }) {
  const recordToTableRow = r => [r.type, r.name, r.data, r.ttl];
  const hasPendingRecords = !!(pendingRecords.hub || pendingRecords.link);

  if (hasPendingRecords) {
    console.log("\nThere are some remaining steps you'll need to complete manually:\n".cyan);
  }

  if (pendingRecords.hub) {
    console.log(`Create the following A records in your DNS for ${rootDomain}:`);
    const table = new Table({
      head: ["Type", "Name", "Value", "TTL"]
    });

    table.push.apply(table, pendingRecords.hub.map(recordToTableRow));
    console.log(table.toString());
  }

  if (pendingRecords.link) {
    console.log(`\nCreate the following A records in your DNS for ${linkDomain}:`);
    const table = new Table({
      head: ["Type", "Name", "Value", "TTL"]
    });

    table.push.apply(table, pendingRecords.link.map(recordToTableRow));
    console.log(table.toString());
  }

  if (hasPendingRecords) {
    await inquirer.prompt([
      {
        name: "finish",
        type: "text",
        message: `Once you've finished setting DNS press enter to finish setup...`
      }
    ]);
  }
}

async function createInitialDb(client, dropletId, databaseId, project, token) {
  let { database } = (await client.databasesGet(databaseId)).body;

  if (database.status !== "online") {
    console.log("Waiting for your database to come online... (usually takes 5 minutes or so.)".cyan);
    let interval;
    let host;

    await new Promise(res => {
      interval = setInterval(async () => {
        const { database } = (await client.databasesGet(databaseId)).body;
        if (database.status === "online") {
          host = database.connection.host;
          clearInterval(interval);
          res();
        }
      }, 5000);
    });

    console.log("Waiting for database DNS...".cyan);

    await new Promise(res => {
      interval = setInterval(() => {
        dns.lookup(host, {}, err => {
          if (!err) {
            clearInterval(interval);
            res();
          }
        });
      }, 5000);
    });

    // Sometimes project assignment fails? Retry it here :P
    try {
      await fetch(`https://api.digitalocean.com/v2/projects/${project.id}/resources`, {
        headers: getDOHeaders(token),
        method: "POST",
        body: JSON.stringify({ resources: [`do:dbaas:${databaseId}`] })
      });
    } catch (e) {
      // Ignore errors in case it succeeded earlier
    }
  }

  ({ database } = (await client.databasesGet(databaseId)).body);

  await fetch(`https://api.digitalocean.com/v2/databases/${databaseId}/firewall`, {
    headers: getDOHeaders(token),
    method: "PUT",
    body: JSON.stringify({ rules: [{ type: "droplet", value: dropletId }] })
  });

  if (!database.db_names || !database.db_names.includes("polycosm_production")) {
    await client.databasesCreateDB(databaseId, "polycosm_production");
  }
}

async function setupAdminEMailDO(project, client) {
  const { account } = (await client.account()).body;
  const accountEmail = account.email;

  return await inquirer.prompt([
    {
      name: "adminEmail",
      type: "text",
      message: `Anyone with access to this email address will have full admin rights to your hub.\nAdministrator email address:`,
      default: accountEmail
    }
  ]);
}

async function setupSMTPDo({ rootDomain }) {
  return await inquirer.prompt([
    {
      name: "smtpHost",
      type: "text",
      message: `Your hub will use email for authentication. You'll need to set up an email provider like SendGrid or MailChimp.
      
*Note*: New DigitalOcean accounts block normal SMTP ports for 60 days to reduce spam.  To mitigate this, we suggest using SendGrid and setting your SMTP port here to 2525.

SMTP server:`,
      default: isProd ? null : "smtp.sendgrid.net"
    },
    {
      name: "smtpPort",
      type: "text",
      message: "SMTP port:",
      default: isProd ? "587" : "2525"
    },
    {
      name: "smtpUser",
      type: "text",
      message: "SMTP User:",
      default: isProd ? null : "gfodor"
    },
    {
      name: "smtpPassword",
      type: "password",
      message: "SMTP Password:",
      default: isProd ? null : DEV_INFO.SMTP
    },
    {
      name: "smtpFrom",
      type: "text",
      message: "From domain for emails:",
      default: `mail.${rootDomain}`
    }
  ]);
}

async function setupDatabaseDO(client, stackName, region, project, projectResources, token, forceDb) {
  let databaseId;

  const dbResource = projectResources.find(({ urn }) => urn.startsWith("do:dbaas"));

  if (dbResource) {
    const urnParts = dbResource.urn.split(":");
    const databaseIdCandidate = urnParts[urnParts.length - 1];

    try {
      // This can fail on recently deleted databases.
      await client.databasesGet(databaseIdCandidate);
      databaseId = databaseIdCandidate;
    } catch (e) {
      console.log(`Ignoring deleted database ${databaseIdCandidate}`);
    }
  }

  if (!databaseId || forceDb) {
    let createDb;

    if (!forceDb) {
      ({ createDb } = await inquirer.prompt([
        {
          name: "createDb",
          type: "list",
          message: `Your hub requires a PostgreSQL database.`,
          choices: [
            { name: "Create a Managed Database on DigitalOcean", value: "managed" },
            { name: "Specify custom database connection settings", value: "unmanaged" }
          ],
          default: "managed"
        }
      ]));
    }

    if (createDb === "unmanaged" || forceDb) {
      const { databaseHost, databasePort, databaseUser, databasePassword, databaseName } = await inquirer.prompt([
        {
          name: "databaseHost",
          type: "text",
          message: `Your hub needs a PostgreSQL database (v10 or higher).

Database server:`
        },
        {
          name: "databasePort",
          type: "text",
          message: "PostgreSQL port:",
          default: "5432"
        },
        {
          name: "databaseUser",
          type: "text",
          message: "PostgreSQL user:",
          default: "postgres"
        },
        {
          name: "databasePassword",
          type: "password",
          message: "PostgreSQL password:"
        },
        {
          name: "databaseName",
          type: "text",
          message: "PostgreSQL database name (you should create a dedicated database):"
        }
      ]);

      return {
        databaseHost,
        databasePort,
        databaseUser,
        databasePassword,
        databaseName
      };
    }

    const { dbType } = await inquirer.prompt([
      {
        name: "dbType",
        type: "list",
        message: `Choose the database to create. (Pricing: https://www.digitalocean.com/pricing/#Databases)`,
        choices: [
          { name: "1 GB RAM, 1 vCPU, 10GB Storage", value: "db-s-1vcpu-1gb" },
          { name: "2 GB RAM, 1 vCPU, 25GB Storage", value: "db-s-1vcpu-2gb" },
          { name: "4 GB RAM, 2 vCPU, 38GB Storage", value: "db-s-2vcpu-4gb" },
          { name: "8 GB RAM, 4 vCPU, 115GB Storage", value: "db-s-4vcpu-8gb" },
          { name: "16 GB RAM, 6 vCPU, 270GB Storage", value: "db-s-6vcpu-16gb" },
          { name: "32 GB RAM, 8 vCPU, 580GB Storage", value: "db-s-8vcpu-32gb" },
          { name: "64 GB RAM, 16 vCPU, 1.12TB Storage", value: "db-s-16vcpu-64gb" }
        ],
        default: "db-s-1vcpu-1gb"
      }
    ]);

    console.log("Creating your database...".brightWhite);

    const { database } = (
      await client.databasesCreate({
        name: `${stackName}-app-db-${randomString()}`,
        engine: "pg",
        size: dbType,
        region,
        num_nodes: 1
      })
    ).body;

    databaseId = database.id;

    // Sometimes project assignment fails (request succeeds but remains unassigned.)
    // Lets wait a few seconds to see if that helps.
    await new Promise(res => setTimeout(res, 5000));

    await fetch(`https://api.digitalocean.com/v2/projects/${project.id}/resources`, {
      headers: { "content-type": "application/json", authorization: `bearer ${token}` },
      method: "POST",
      body: JSON.stringify({ resources: [`do:dbaas:${databaseId}`] })
    });
  }

  const { database } = (await client.databasesGet(databaseId)).body;

  return {
    databaseId,
    databaseHost: database.connection.host,
    databasePort: database.connection.port,
    databaseUser: database.connection.user,
    databasePassword: database.connection.password,
    databaseName: "polycosm_production"
  };
}

async function setupDomainsDO() {
  const { domainName } = await inquirer.prompt([
    {
      name: "domainName",
      type: "text",
      message: `Your hub's domain name (eg myhub.com or hub.mycompany.com):`,
      default: isProd ? null : "quackstack-do.net"
    }
  ]);

  const domainParts = domainName.split(".");
  const rootDomain = `${domainParts[domainParts.length - 2]}.${domainParts[domainParts.length - 1]}`;

  const { linkDomain } = await inquirer.prompt([
    {
      name: "linkDomain",
      type: "text",
      message: "Your hub's shortlinks domain (eg myhub.link):",
      default: isProd ? null : "quak.link"
    }
  ]);

  if (linkDomain.split(".").length !== 2) {
    console.log(`Your shortlink ${linkDomain} cannot be a subdomain.`.yellow);
    process.exit(1); // eslint-disable-line no-process-exit
  }

  if (rootDomain === linkDomain) {
    console.log(`Your hub domain ${rootDomain} cannot be the same as your shortlink domain ${linkDomain}.`.yellow);
    process.exit(1); // eslint-disable-line no-process-exit
  }

  return { domainName, rootDomain, linkDomain };
}

const run = async function() {
  const forceDb = argv.b;
  const retFilesPath = argv.f;
  const readyFile = argv.y;
  const ssh2faConfigFile = argv.k;
  const ssh2faQrFile = argv.q;

  let outFile = argv._[0];

  if (!outFile) {
    throw new Error("Did not specify an output file. See usage.");
  }

  if (argv.d === "digitalocean") {
    try {
      await runDO(retFilesPath, forceDb, ssh2faConfigFile, ssh2faQrFile, outFile);

      if (readyFile) {
        fs.closeSync(fs.openSync(readyFile, "w"));
      }
    } catch (e) {
      console.error(e);
      process.exit(1); // eslint-disable-line no-process-exit
    }
  }
};

module.exports = { run };
