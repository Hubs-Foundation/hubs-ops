// Underlying source to RegisterNodeLambda.
// Packer: https://skalman.github.io/UglifyJS-online/
const AWS = require("aws-sdk");
const promisify = (f) => (arg) =>
  new Promise((res, rej) =>
    f(arg, (err, data) => {
      if (err) {
        console.log(err);
        rej(err);
      } else {
        res(data);
      }
    })
  );

// Note this doesn't have to be an exact match since we explicit don't check
// for the full offline string, only online string, in template.
const OFFLINE_SETTING = "Offline - Temporarily shut off servers";

async function handleBudgetAlert(event, context) {
  const topicArn = event.Records[0].Sns.TopicArn;
  const sns = new AWS.SNS();
  const tags = (
    await promisify(sns.listTagsForResource.bind(sns))({
      ResourceArn: topicArn,
    })
  ).Tags;
  const stackName = tags.find((t) => t.Key === "stack-name").Value;
  const stackRegion = tags.find((t) => t.Key === "stack-region").Value;

  const cf = new AWS.CloudFormation({ region: stackRegion });

  await new Promise(async (res) => {
    let interval;

    const f = async () => {
      const stackInfo = await promisify(cf.describeStacks.bind(cf))({
        StackName: stackName,
      });

      if (stackInfo) {
        const stackStatus = stackInfo.Stacks[0].StackStatus;

        if (
          stackStatus.endsWith("_COMPLETE") ||
          stackStatus.endsWith("_FAILED")
        ) {
          if (interval) {
            clearInterval(interval);
          }

          res();

          return true;
        }
      }

      return false;
    };

    if (!(await f())) {
      interval = setInterval(f, 30000);
    }
  });

  const stackInfo = await promisify(cf.describeStacks.bind(cf))({
    StackName: stackName,
  });
  const params = stackInfo.Stacks[0].Parameters;
  const newParams = [];

  for (const p of params) {
    if (p.ParameterKey === "StackOffline") {
      newParams.push({
        ParameterKey: p.ParameterKey,
        ParameterValue: OFFLINE_SETTING,
      });
    } else {
      newParams.push({ ParameterKey: p.ParameterKey, UsePreviousValue: true });
    }
  }

  await promisify(cf.updateStack.bind(cf))({
    StackName: stackName,
    UsePreviousTemplate: true,
    Parameters: newParams,
    Capabilities: ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"],
  });
}

async function handleASGMessage(message, context) {
  const asgName = message.AutoScalingGroupName;
  const asgEvent = message.Event;
  const REGION = "${AWS::Region}";
  const INTERNAL_APP_RECORD_NAME =
    "${LowerStackName.Value}-app.${InternalZoneInfo.Name}.";
  const HOSTED_ZONE_ID = "${InternalZoneInfo.Id}";
  const ttl = 15;
  const DOMAIN_URL = "${InternalZoneInfo.Name}.";

  if (
    asgEvent === "autoscaling:EC2_INSTANCE_LAUNCH" ||
    asgEvent === "autoscaling:EC2_INSTANCE_TERMINATE" ||
    asgEvent === "INSTANCE_REBOOT"
  ) {
    // console.log('Handling Launch/Terminate Event for ' + asgName)

    const autoscaling = new AWS.AutoScaling({ region: REGION });
    const ec2 = new AWS.EC2({ region: REGION });
    const route53 = new AWS.Route53();

    const asgResponse = await promisify(
      autoscaling.describeAutoScalingGroups.bind(autoscaling)
    )({
      AutoScalingGroupNames: [asgName],
      MaxRecords: 1,
    });

    const recordSets = (
      await promisify(route53.listResourceRecordSets.bind(route53))({
        HostedZoneId: HOSTED_ZONE_ID,
        MaxItems: "100",
      })
    ).ResourceRecordSets;

    const instanceIds = asgResponse.AutoScalingGroups[0].Instances.map(
      (i) => i.InstanceId
    );

    // Sometimes instanceIds is an empty array
    // Will cause an error on the ec2 describe instances
    if (!instanceIds.length) {
      instanceIds.push(message.EC2InstanceId);
    }

    const instanceInfo = await promisify(ec2.describeInstances.bind(ec2))({
      DryRun: false,
      InstanceIds: instanceIds,
    });

    const ipAddresses = [];
    for (let i = 0; i < instanceInfo.Reservations.length; i++) {
      const reservation = instanceInfo.Reservations[i];
      for (let j = 0; j < reservation.Instances.length; j++) {
        const ip =
          reservation.Instances[j].NetworkInterfaces.length &&
          reservation.Instances[j].NetworkInterfaces[0].Association &&
          reservation.Instances[j].NetworkInterfaces[0].Association.PublicIp;
        if (ip && ipAddresses.indexOf(ip) < 0) {
          ipAddresses.push(ip);
        }
      }
    }

    // Go through record sets, removing records that don't have an IP
    // that are missing.
    for (let i = 0, l = recordSets.length; i < l; i++) {
      const record = recordSets[i];

      if (record.Type !== "A") continue;

      const resourceValue =
        record.ResourceRecords.length > 0
          ? record.ResourceRecords[0].Value
          : "";
      const hasAssignedHostname = isAssignedHostName(record.Name, DOMAIN_URL);
      const isIpAddress =
        resourceValue.match(/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/) !== null;
      const isInternalAppRecord = record.Name === INTERNAL_APP_RECORD_NAME;

      // Only delete the records that are host names we assign and the record value is an ip address
      if (
        !resourceValue ||
        !isIpAddress ||
        (!hasAssignedHostname && !isInternalAppRecord)
      )
        continue;

      if (!ipAddresses.find((ip) => ip === resourceValue)) {
        // console.log('Removing dead IP record')
        // console.log(JSON.stringify(resourceValue))
        // console.log('name ' + record.Name)
        // console.log('type ' + record.Type)
        // console.log('resourcerecords ' + record.ResourceRecords)
        // console.log('ttl ' + record.TTL)
        // console.log('setidentifier ' + record.SetIdentifier)
        // console.log('healthcheckid ' + record.HealthCheckId)
        // console.log('hostedZoneId ' + HOSTED_ZONE_ID)

        try {
          const recordSetToDelete =
            record.Name === INTERNAL_APP_RECORD_NAME
              ? {
                  MultiValueAnswer: true,
                  Name: record.Name,
                  Type: record.Type,
                  TTL: record.TTL,
                  SetIdentifier: record.SetIdentifier,
                  ResourceRecords: record.ResourceRecords,
                  HealthCheckId: record.HealthCheckId,
                }
              : {
                  Name: record.Name,
                  Type: record.Type,
                  TTL: record.TTL,
                  ResourceRecords: record.ResourceRecords,
                };
          await promisify(route53.changeResourceRecordSets.bind(route53))({
            ChangeBatch: {
              Changes: [
                {
                  Action: "DELETE",
                  ResourceRecordSet: recordSetToDelete,
                },
              ],
            },
            HostedZoneId: HOSTED_ZONE_ID,
          });
        } catch (e) {
          console.log("ERROR DELETING RECORD");
          console.log(e);
        }
      }
    }

    let healthChecks = (
      await promisify(route53.listHealthChecks.bind(route53))({
        MaxItems: "100",
      })
    ).HealthChecks;

    // If we only have one IP, don't bother with health checks (to save cost)
    if (ipAddresses.length > 1) {
      // Go through IPs, adding missing records and health checks
      for (let i = 0, l = ipAddresses.length; i < l; i++) {
        const ip = ipAddresses[i];
        if (!healthChecks.find((h) => h.HealthCheckConfig.IPAddress === ip)) {
          // console.log('Adding check ' + ip)

          try {
            await promisify(route53.createHealthCheck.bind(route53))({
              CallerReference: Math.floor(
                Math.random() * 1000000000
              ).toString(),
              HealthCheckConfig: {
                EnableSNI: true,
                FailureThreshold: 2,
                FullyQualifiedDomainName: INTERNAL_APP_RECORD_NAME,
                IPAddress: ip,
                Port: 443,
                RequestInterval: 10,
                ResourcePath: "/health",
                Type: "HTTPS",
              },
            });
          } catch (e) {}
        }
      }
    }

    // Re-fetch health checks to get ids.
    healthChecks = (await promisify(route53.listHealthChecks.bind(route53))({}))
      .HealthChecks;

    for (let i = 0, l = ipAddresses.length; i < l; i++) {
      const ip = ipAddresses[i];
      if (
        !recordSets.find(
          (r) =>
            r.Name === INTERNAL_APP_RECORD_NAME &&
            r.ResourceRecords &&
            r.ResourceRecords.length &&
            r.ResourceRecords[0].Value === ip
        )
      ) {
        const check = healthChecks.find(
          (h) => h.HealthCheckConfig.IPAddress === ip
        );
        // console.log('Adding ip ' + ip + ' with check ')
        try {
          await promisify(route53.changeResourceRecordSets.bind(route53))({
            ChangeBatch: {
              Changes: [
                {
                  Action: "UPSERT",
                  ResourceRecordSet: {
                    MultiValueAnswer: true,
                    Name: INTERNAL_APP_RECORD_NAME,
                    Type: "A",
                    HealthCheckId: check ? check.Id : null,
                    TTL: ttl,
                    SetIdentifier: ip,
                    ResourceRecords: [{ Value: ip }],
                  },
                },
              ],
            },
            HostedZoneId: HOSTED_ZONE_ID,
          });
        } catch (e) {}
      }
    }

    // Remove unneeded health checks
    for (let i = 0, l = healthChecks.length; i < l; i++) {
      const check = healthChecks[i];

      // Remove all health checks if only one IP or if a health check is registered to an IP not used.
      if (
        ipAddresses.length === 1 ||
        !ipAddresses.find((ip) => check.HealthCheckConfig.IPAddress === ip)
      ) {
        // console.log("deleting health check " + check.Id);

        try {
          await promisify(route53.deleteHealthCheck.bind(route53))({
            HealthCheckId: check.Id,
          });
        } catch (e) {}
      }
    }
  } else {
    context.done("Unsupported ASG event: " + asgName + " " + asgEvent);
  }
}

exports.handler = async function (event, context) {
  if (event.Records[0].Sns.Message.indexOf("Budget Name") >= 0) {
    return handleBudgetAlert(event, context);
  } else {
    const message = JSON.parse(event.Records[0].Sns.Message);
    return handleASGMessage(message, context);
  }
};

const e = require("aws-sdk"),
  t = (e) => (t) =>
    new Promise((a, n) =>
      e(t, (e, t) => {
        e ? (console.log(e), n(e)) : a(t);
      })
    );
function a(e, t) {
  if (!e) return !1;
  const a = e.split("-");
  if (a.length >= 2) {
    const e = a[0],
      t = a.slice(1).join("-").split("."),
      r = t[0].includes("-local") ? t[0].replace("-local", "") : t[0];
    return n.includes(e) && s.includes(r);
  }
  return !1;
}
exports.handler = async function (n, s) {
  if (n.Records[0].Sns.Message.indexOf("Budget Name") >= 0)
    return (async function (a, n) {
      const s = a.Records[0].Sns.TopicArn,
        r = new e.SNS(),
        i = (await t(r.listTagsForResource.bind(r))({ ResourceArn: s })).Tags,
        o = i.find((e) => "stack-name" === e.Key).Value,
        c = i.find((e) => "stack-region" === e.Key).Value,
        l = new e.CloudFormation({ region: c });
      await new Promise(async (e) => {
        let a;
        const n = async () => {
          const n = await t(l.describeStacks.bind(l))({ StackName: o });
          if (n) {
            const t = n.Stacks[0].StackStatus;
            if (t.endsWith("_COMPLETE") || t.endsWith("_FAILED"))
              return a && clearInterval(a), e(), !0;
          }
          return !1;
        };
        (await n()) || (a = setInterval(n, 3e4));
      });
      const d = (await t(l.describeStacks.bind(l))({ StackName: o })).Stacks[0]
          .Parameters,
        u = [];
      for (const e of d)
        "StackOffline" === e.ParameterKey
          ? u.push({
              ParameterKey: e.ParameterKey,
              ParameterValue: "Offline - Temporarily shut off servers",
            })
          : u.push({ ParameterKey: e.ParameterKey, UsePreviousValue: !0 });
      await t(l.updateStack.bind(l))({
        StackName: o,
        UsePreviousTemplate: !0,
        Parameters: u,
        Capabilities: ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"],
      });
    })(n);
  return (async function (n, s) {
    const r = n.AutoScalingGroupName,
      i = n.Event,
      o = "${AWS::Region}",
      c = "${LowerStackName.Value}-app.${InternalZoneInfo.Name}.",
      l = "${InternalZoneInfo.Id}";
    if (
      "autoscaling:EC2_INSTANCE_LAUNCH" === i ||
      "autoscaling:EC2_INSTANCE_TERMINATE" === i ||
      "INSTANCE_REBOOT" === i
    ) {
      const s = new e.AutoScaling({ region: o }),
        i = new e.EC2({ region: o }),
        d = new e.Route53(),
        u = await t(s.describeAutoScalingGroups.bind(s))({
          AutoScalingGroupNames: [r],
          MaxRecords: 1,
        }),
        h = (
          await t(d.listResourceRecordSets.bind(d))({
            HostedZoneId: l,
            MaxItems: "100",
          })
        ).ResourceRecordSets,
        f = u.AutoScalingGroups[0].Instances.map((e) => e.InstanceId);
      f.length || f.push(n.EC2InstanceId);
      const g = await t(i.describeInstances.bind(i))({
          DryRun: !1,
          InstanceIds: f,
        }),
        m = [];
      for (let e = 0; e < g.Reservations.length; e++) {
        const t = g.Reservations[e];
        for (let e = 0; e < t.Instances.length; e++) {
          const a =
            t.Instances[e].NetworkInterfaces.length &&
            t.Instances[e].NetworkInterfaces[0].Association &&
            t.Instances[e].NetworkInterfaces[0].Association.PublicIp;
          a && m.indexOf(a) < 0 && m.push(a);
        }
      }
      for (let e = 0, n = h.length; e < n; e++) {
        const n = h[e];
        if ("A" !== n.Type) continue;
        const s =
            n.ResourceRecords.length > 0 ? n.ResourceRecords[0].Value : "",
          r = a(n.Name),
          i = null !== s.match(/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/),
          o = n.Name === c;
        if (s && i && (r || o) && !m.find((e) => e === s))
          try {
            const e =
              n.Name === c
                ? {
                    MultiValueAnswer: !0,
                    Name: n.Name,
                    Type: n.Type,
                    TTL: n.TTL,
                    SetIdentifier: n.SetIdentifier,
                    ResourceRecords: n.ResourceRecords,
                    HealthCheckId: n.HealthCheckId,
                  }
                : {
                    Name: n.Name,
                    Type: n.Type,
                    TTL: n.TTL,
                    ResourceRecords: n.ResourceRecords,
                  };
            await t(d.changeResourceRecordSets.bind(d))({
              ChangeBatch: {
                Changes: [{ Action: "DELETE", ResourceRecordSet: e }],
              },
              HostedZoneId: l,
            });
          } catch (e) {
            console.log("ERROR DELETING RECORD"), console.log(e);
          }
      }
      let I = (await t(d.listHealthChecks.bind(d))({ MaxItems: "100" }))
        .HealthChecks;
      if (m.length > 1)
        for (let e = 0, a = m.length; e < a; e++) {
          const a = m[e];
          if (!I.find((e) => e.HealthCheckConfig.IPAddress === a))
            try {
              await t(d.createHealthCheck.bind(d))({
                CallerReference: Math.floor(1e9 * Math.random()).toString(),
                HealthCheckConfig: {
                  EnableSNI: !0,
                  FailureThreshold: 2,
                  FullyQualifiedDomainName: c,
                  IPAddress: a,
                  Port: 443,
                  RequestInterval: 10,
                  ResourcePath: "/health",
                  Type: "HTTPS",
                },
              });
            } catch (e) {}
        }
      I = (await t(d.listHealthChecks.bind(d))({})).HealthChecks;
      for (let e = 0, a = m.length; e < a; e++) {
        const a = m[e];
        if (
          !h.find(
            (e) =>
              e.Name === c &&
              e.ResourceRecords &&
              e.ResourceRecords.length &&
              e.ResourceRecords[0].Value === a
          )
        ) {
          const e = I.find((e) => e.HealthCheckConfig.IPAddress === a);
          try {
            await t(d.changeResourceRecordSets.bind(d))({
              ChangeBatch: {
                Changes: [
                  {
                    Action: "UPSERT",
                    ResourceRecordSet: {
                      MultiValueAnswer: !0,
                      Name: c,
                      Type: "A",
                      HealthCheckId: e ? e.Id : null,
                      TTL: 15,
                      SetIdentifier: a,
                      ResourceRecords: [{ Value: a }],
                    },
                  },
                ],
              },
              HostedZoneId: l,
            });
          } catch (e) {}
        }
      }
      for (let e = 0, a = I.length; e < a; e++) {
        const a = I[e];
        if (
          1 === m.length ||
          !m.find((e) => a.HealthCheckConfig.IPAddress === e)
        )
          try {
            await t(d.deleteHealthCheck.bind(d))({ HealthCheckId: a.Id });
          } catch (e) {}
      }
    } else s.done("Unsupported ASG event: " + r + " " + i);
  })(JSON.parse(n.Records[0].Sns.Message), s);
};

const n = [
    "admiring",
    "adoring",
    "affectionate",
    "agitated",
    "amazing",
    "angry",
    "awesome",
    "blissful",
    "boring",
    "brave",
    "clever",
    "cocky",
    "compassionate",
    "competent",
    "condescending",
    "confident",
    "cranky",
    "dazzling",
    "determined",
    "distracted",
    "dreamy",
    "eager",
    "ecstatic",
    "elastic",
    "elated",
    "elegant",
    "eloquent",
    "epic",
    "fervent",
    "festive",
    "flamboyant",
    "focused",
    "friendly",
    "frosty",
    "gallant",
    "gifted",
    "goofy",
    "gracious",
    "happy",
    "hardcore",
    "heuristic",
    "hopeful",
    "hungry",
    "infallible",
    "inspiring",
    "jolly",
    "jovial",
    "keen",
    "kind",
    "laughing",
    "loving",
    "lucid",
    "mystifying",
    "modest",
    "musing",
    "naughty",
    "nervous",
    "nifty",
    "nostalgic",
    "objective",
    "optimistic",
    "peaceful",
    "pedantic",
    "pensive",
    "practical",
    "priceless",
    "quirky",
    "quizzical",
    "relaxed",
    "reverent",
    "romantic",
    "sad",
    "serene",
    "sharp",
    "silly",
    "sleepy",
    "stoic",
    "stupefied",
    "suspicious",
    "tender",
    "thirsty",
    "trusting",
    "unruffled",
    "upbeat",
    "vibrant",
    "vigilant",
    "vigorous",
    "wizardly",
    "wonderful",
    "xenodochial",
    "youthful",
    "zealous",
    "zen",
  ],
  s = [
    "ardent",
    "artificer",
    "balrog",
    "barbarian",
    "bard",
    "cleric",
    "druid",
    "dwarf",
    "elf",
    "ent",
    "fighter",
    "giant",
    "goblin",
    "halfling",
    "hobbit",
    "illusionist",
    "invoker",
    "mage",
    "monk",
    "mystic",
    "orc",
    "paladin",
    "psion",
    "ranger",
    "rogue",
    "seeker",
    "sorcerer",
    "thief",
    "troll",
    "vampire",
    "warlock",
    "werewolf",
    "wizard",
  ];
