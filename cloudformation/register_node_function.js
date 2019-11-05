// Underlying source to RegisterNodeLambda.
// Quick packer http://dean.edwards.name/packer/
const AWS = require('aws-sdk');

exports.handler = async function (event, context) {
  const asgMessage = JSON.parse(event.Records[0].Sns.Message);
  const asgName = asgMessage.AutoScalingGroupName;
  const instanceId = asgMessage.EC2InstanceId;
  const asgEvent = asgMessage.Event;
  const promisify = f =>
    arg =>
      new Promise((res, rej) => f(arg, (err, data) => { if (err) { console.log(err); rej(err); } else { res(data); } }));
  const region = "${AWS::Region}";
  const recordName = "app.${InternalZoneInfo.Name}.";
  const hostedZoneId = "${InternalZoneInfo.Id}";

  //console.log(asgEvent);

  if (asgEvent === "autoscaling:EC2_INSTANCE_LAUNCH" || asgEvent === "autoscaling:EC2_INSTANCE_TERMINATE") {
    //console.log("Handling Launch/Terminate Event for " + asgName);

    const autoscaling = new AWS.AutoScaling({region});
    const ec2 = new AWS.EC2({region});
    const route53 = new AWS.Route53();

    const asgResponse = await promisify(autoscaling.describeAutoScalingGroups.bind(autoscaling))({
      AutoScalingGroupNames: [asgName],
      MaxRecords: 1
    });

    const recordSets = (await promisify(route53.listResourceRecordSets.bind(route53))({
      StartRecordName: recordName,
      StartRecordType: "A",
      HostedZoneId: hostedZoneId,
      MaxItems: "100"
    })).ResourceRecordSets;

    const instanceIds = asgResponse.AutoScalingGroups[0].Instances.map(i => i.InstanceId);
    const instanceInfo = await promisify(ec2.describeInstances.bind(ec2))({
      DryRun: false,
      InstanceIds: instanceIds
    });

    const ipAddresses = [];
    for (let i = 0; i < instanceInfo.Reservations.length; i++) {
      const reservation = instanceInfo.Reservations[i];
      for (let j = 0; j < reservation.Instances.length; j++) {
          const ip = reservation.Instances[j].NetworkInterfaces[0].Association.PublicIp;
          if (ip && ipAddresses.indexOf(ip) < 0) {
            ipAddresses.push(ip);
          }
      }
    }

    // Go through record sets, removing records that don't have an IP
    // that are missing.
    for (let i = 0, l = recordSets.length; i < l; i++) {
      const record = recordSets[i];
      if (record.Name !== recordName || record.Type !== "A") continue;

      const resource = record.ResourceRecords.length > 0 && record.ResourceRecords[0].Value;
      if (!resource) continue;

      if (!ipAddresses.find(ip => ip === resource)) {
        //console.log("Removing dead IP record " + resource);
        try {
          await promisify(route53.changeResourceRecordSets.bind(route53))({
            ChangeBatch: {
              Changes: [
                {
                  Action: 'DELETE',
                  ResourceRecordSet: {
                    MultiValueAnswer: true, Name: recordName, Type: 'A',
                    TTL: 30, SetIdentifier: ip, ResourceRecords: [{ Value: resource }]
                  }
                }
              ]
            },
            HostedZoneId: hostedZoneId
          });
        } catch (e) {}
      }
    }

    let healthChecks = (await promisify(route53.listHealthChecks.bind(route53))({ MaxItems: "100"})).HealthChecks;

    // Go through IPs, adding missing records and health checks
    for (let i = 0, l = ipAddresses.length; i < l; i++) {
      const ip = ipAddresses[i];
      if (!healthChecks.find(h => h.HealthCheckConfig.IPAddress === ip)) {
        console.log("Adding check " + ip);

        try {
          await promisify(route53.createHealthCheck.bind(route53))({
            CallerReference: Math.floor(Math.random() * 1000000000).toString(),
            HealthCheckConfig: {
              EnableSNI: true,
              FailureThreshold: 2,
              FullyQualifiedDomainName: recordName,
              IPAddress: ip,
              Port: 443,
              RequestInterval: 10,
              ResourcePath: "/health",
              Type: "HTTPS"
            }
          });
        } catch (e) {}
      } 
    }

    // Re-fetch health checks to get ids.
    healthChecks = (await promisify(route53.listHealthChecks.bind(route53))({})).HealthChecks;

    for (let i = 0, l = ipAddresses.length; i < l; i++) {
      const ip = ipAddresses[i];
      if (!recordSets.find(r => r.Name === recordName && r.ResourceRecords && r.ResourceRecords.length && r.ResourceRecords[0].Value === ip)) {
        const checkId = healthChecks.find(h => h.HealthCheckConfig.IPAddress === ip).Id;
        //console.log("Adding ip " + ip + " with check " + checkId);

        try {
          await promisify(route53.changeResourceRecordSets.bind(route53))({
            ChangeBatch: {
              Changes: [
                {
                  Action: 'UPSERT',
                  ResourceRecordSet: {
                    MultiValueAnswer: true, Name: recordName, Type: 'A', HealthCheckId: checkId,
                    TTL: 60, SetIdentifier: ip, ResourceRecords: [{ Value: ip }]
                  }
                }
              ]
            },
            HostedZoneId: hostedZoneId
          });
        } catch(e) {}
      }
    }

    // Remove unneeded health checks
    for (let i = 0, l = healthChecks.length; i < l; i++) {
      const check = healthChecks[i];

      if (!ipAddresses.find(ip => check.HealthCheckConfig.IPAddress === ip)) {
        //console.log("deleting check " + check.Id);

        try {
          await promisify(route53.deleteHealthCheck.bind(route53))({ HealthCheckId: check.Id });
        } catch(e) {}
      }
    }
  } else {
    console.log("Unsupported ASG event: " + asgName + " " + asgEvent);
    context.done("Unsupported ASG event: " + asgName + " " + asgEvent);
  }
};

