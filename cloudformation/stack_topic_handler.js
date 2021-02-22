// Underlying source to RegisterNodeLambda.
// Packer: https://skalman.github.io/UglifyJS-online/
const AWS = require('aws-sdk')
const promisify = (f) => (arg) =>
  new Promise((res, rej) =>
    f(arg, (err, data) => {
      if (err) {
        console.log(err)
        rej(err)
      } else {
        res(data)
      }
    })
  )

// Note this doesn't have to be an exact match since we explicit don't check
// for the full offline string, only online string, in template.
const OFFLINE_SETTING = 'Offline - Temporarily shut off servers'

async function handleBudgetAlert(event, context) {
  const topicArn = event.Records[0].Sns.TopicArn
  const sns = new AWS.SNS()
  const tags = (
    await promisify(sns.listTagsForResource.bind(sns))({
      ResourceArn: topicArn,
    })
  ).Tags
  const stackName = tags.find((t) => t.Key === 'stack-name').Value
  const stackRegion = tags.find((t) => t.Key === 'stack-region').Value

  const cf = new AWS.CloudFormation({ region: stackRegion })

  await new Promise(async (res) => {
    let interval

    const f = async () => {
      const stackInfo = await promisify(cf.describeStacks.bind(cf))({
        StackName: stackName,
      })

      if (stackInfo) {
        const stackStatus = stackInfo.Stacks[0].StackStatus

        if (
          stackStatus.endsWith('_COMPLETE') ||
          stackStatus.endsWith('_FAILED')
        ) {
          if (interval) {
            clearInterval(interval)
          }

          res()

          return true
        }
      }

      return false
    }

    if (!(await f())) {
      interval = setInterval(f, 30000)
    }
  })

  const stackInfo = await promisify(cf.describeStacks.bind(cf))({
    StackName: stackName,
  })
  const params = stackInfo.Stacks[0].Parameters
  const newParams = []

  for (const p of params) {
    if (p.ParameterKey === 'StackOffline') {
      newParams.push({
        ParameterKey: p.ParameterKey,
        ParameterValue: OFFLINE_SETTING,
      })
    } else {
      newParams.push({ ParameterKey: p.ParameterKey, UsePreviousValue: true })
    }
  }

  await promisify(cf.updateStack.bind(cf))({
    StackName: stackName,
    UsePreviousTemplate: true,
    Parameters: newParams,
    Capabilities: ['CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM'],
  })
}

async function handleASGMessage(message, context) {
  const asgName = message.AutoScalingGroupName
  const asgEvent = message.Event
  const REGION = '${AWS::Region}'
  const RECORD_NAME = '${LowerStackName.Value}-app.${InternalZoneInfo.Name}.'
  const HOSTED_ZONE_ID = '${InternalZoneInfo.Id}'
  const ttl = 15
  const DOMAIN_URL = '${InternalZoneInfo.Name}.'

  if (
    asgEvent === 'autoscaling:EC2_INSTANCE_LAUNCH' ||
    asgEvent === 'autoscaling:EC2_INSTANCE_TERMINATE' ||
    asgEvent === 'INSTANCE_REBOOT'
  ) {
    // console.log('Handling Launch/Terminate Event for ' + asgName)

    const autoscaling = new AWS.AutoScaling({ region: REGION })
    const ec2 = new AWS.EC2({ region: REGION })
    const route53 = new AWS.Route53()

    const asgResponse = await promisify(
      autoscaling.describeAutoScalingGroups.bind(autoscaling)
    )({
      AutoScalingGroupNames: [asgName],
      MaxRecords: 1,
    })

    const recordSets = (
      await promisify(route53.listResourceRecordSets.bind(route53))({
        HostedZoneId: HOSTED_ZONE_ID,
        MaxItems: '100',
      })
    ).ResourceRecordSets

    const instanceIds = asgResponse.AutoScalingGroups[0].Instances.map(
      (i) => i.InstanceId
    )

    // Sometimes instanceIds is an empty array
    // Will cause an error on the ec2 describe instances
    if (!instanceIds.length) {
      console.log(message.EC2InstanceId)
      instanceIds.push(message.EC2InstanceId)
    }

    const instanceInfo = await promisify(ec2.describeInstances.bind(ec2))({
      DryRun: false,
      InstanceIds: instanceIds, // Can conflict with other ec2 instances. Only get the ones in the asg.
    })

    const ipAddresses = []
    for (let i = 0; i < instanceInfo.Reservations.length; i++) {
      const reservation = instanceInfo.Reservations[i]
      for (let j = 0; j < reservation.Instances.length; j++) {
        const ip =
          reservation.Instances[j].NetworkInterfaces.length &&
          reservation.Instances[j].NetworkInterfaces[0].Association.PublicIp
        if (ip && ipAddresses.indexOf(ip) < 0) {
          console.log('pushed ip :', ip)
          ipAddresses.push(ip)
        }
      }
    }

    // Go through record sets, removing records that don't have an IP
    // that are missing.
    for (let i = 0, l = recordSets.length; i < l; i++) {
      const record = recordSets[i]

      if (record.Type !== 'A') continue

      const resourceValue =
        record.ResourceRecords.length > 0 ? record.ResourceRecords[0].Value : ''
      const hasAssignedHostname = isAssignedHostName(record.Name, DOMAIN_URL)

      // Only delete the records that are host names we assign and the record value is an ip address
      if (
        !resourceValue ||
        !(
          resourceValue.match(/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/) !== null &&
          (hasAssignedHostname || record.Name === RECORD_NAME)
        )
      )
        continue

      if (!ipAddresses.find((ip) => ip === resourceValue)) {
        // console.log('Removing dead IP record, resource: ')
        // console.log(JSON.stringify(resourceValue))
        // console.log('name ' + record.Name)
        // console.log('type ' + record.Type)
        // console.log('resourcerecords ' + record.ResourceRecords)
        // console.log('ttl ' + record.TTL)
        // console.log('setidentifier ' + record.SetIdentifier)
        // console.log('healthcheckid ' + record.HealthCheckId)
        // console.log('hostedZoneId ' + HOSTED_ZONE_ID)

        try {
          const obj =
            record.Name === RECORD_NAME
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
                }
          await promisify(route53.changeResourceRecordSets.bind(route53))({
            ChangeBatch: {
              Changes: [
                {
                  Action: 'DELETE',
                  ResourceRecordSet: obj,
                },
              ],
            },
            HostedZoneId: HOSTED_ZONE_ID,
          })
        } catch (e) {
          console.log('ERROR DELETING RECORD')
          console.log(e)
        }
      }
    }

    let healthChecks = (
      await promisify(route53.listHealthChecks.bind(route53))({
        MaxItems: '100',
      })
    ).HealthChecks

    // If we only have one IP, don't bother with health checks (to save cost)
    if (ipAddresses.length > 1) {
      // Go through IPs, adding missing records and health checks
      for (let i = 0, l = ipAddresses.length; i < l; i++) {
        const ip = ipAddresses[i]
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
                FullyQualifiedDomainName: RECORD_NAME,
                IPAddress: ip,
                Port: 443,
                RequestInterval: 10,
                ResourcePath: '/health',
                Type: 'HTTPS',
              },
            })
          } catch (e) {}
        }
      }
    }

    // Re-fetch health checks to get ids.
    healthChecks = (await promisify(route53.listHealthChecks.bind(route53))({}))
      .HealthChecks

    for (let i = 0, l = ipAddresses.length; i < l; i++) {
      const ip = ipAddresses[i]
      if (
        !recordSets.find(
          (r) =>
            r.Name === RECORD_NAME &&
            r.ResourceRecords &&
            r.ResourceRecords.length &&
            r.ResourceRecords[0].Value === ip
        )
      ) {
        const check = healthChecks.find(
          (h) => h.HealthCheckConfig.IPAddress === ip
        )
        // console.log('Adding ip ' + ip + ' with check ')
        // console.log(RECORD_NAME)
        // console.log('A')
        // console.log(
        //   'HealthCheckId: ' + check && check !== undefined ? check.Id : null
        // )
        // console.log('TTL ' + ttl)
        // console.log('setIdentifier ' + ip)
        // console.log('resourcerecords: ' + [{ Value: ip }])
        // console.log(HOSTED_ZONE_ID)

        try {
          await promisify(route53.changeResourceRecordSets.bind(route53))({
            ChangeBatch: {
              Changes: [
                {
                  Action: 'UPSERT',
                  ResourceRecordSet: {
                    MultiValueAnswer: true,
                    Name: RECORD_NAME,
                    Type: 'A',
                    HealthCheckId: check ? check.Id : null,
                    TTL: ttl,
                    SetIdentifier: ip,
                    ResourceRecords: [{ Value: ip }],
                  },
                },
              ],
            },
            HostedZoneId: HOSTED_ZONE_ID,
          })
        } catch (e) {}
      }
    }

    // Remove unneeded health checks
    for (let i = 0, l = healthChecks.length; i < l; i++) {
      const check = healthChecks[i]

      // Remove all health checks if only one IP or if a health check is registered to an IP not used.
      if (
        ipAddresses.length === 1 ||
        !ipAddresses.find((ip) => check.HealthCheckConfig.IPAddress === ip)
      ) {
        console.log('deleting health check ' + check.Id)

        try {
          await promisify(route53.deleteHealthCheck.bind(route53))({
            HealthCheckId: check.Id,
          })
        } catch (e) {}
      }
    }
  } else {
    context.done('Unsupported ASG event: ' + asgName + ' ' + asgEvent)
  }
}

/**
 * Takes a recordName and checks it against the assigned hostname adjectives/nouns
 * returns boolean whether the recordName is an assigned hostname
 */
function isAssignedHostName(recordName, domainUrl) {
  if (!recordName) return false

  const splitRecordName = recordName.split('-')
  if (splitRecordName.length >= 2) {
    // ["adjective","noun" || "noun.url.com", ?"local.url.com"]
    const adjective = splitRecordName[0]
    const noun = splitRecordName[1].includes('.' + domainUrl)
      ? splitRecordName[1].replace('.' + domainUrl, '')
      : splitRecordName[1]

    return ADJECTIVES.includes(adjective) && NOUNS.includes(noun)
  }
  return false
}

exports.handler = async function (event, context) {
  if (event.Records[0].Sns.Message.indexOf('Budget Name') >= 0) {
    return handleBudgetAlert(event, context)
  } else {
    const message = JSON.parse(event.Records[0].Sns.Message)
    return handleASGMessage(message, context)
  }
}

// Assigned host names
const ADJECTIVES = [
  'admiring',
  'adoring',
  'affectionate',
  'agitated',
  'amazing',
  'angry',
  'awesome',
  'blissful',
  'boring',
  'brave',
  'clever',
  'cocky',
  'compassionate',
  'competent',
  'condescending',
  'confident',
  'cranky',
  'dazzling',
  'determined',
  'distracted',
  'dreamy',
  'eager',
  'ecstatic',
  'elastic',
  'elated',
  'elegant',
  'eloquent',
  'epic',
  'fervent',
  'festive',
  'flamboyant',
  'focused',
  'friendly',
  'frosty',
  'gallant',
  'gifted',
  'goofy',
  'gracious',
  'happy',
  'hardcore',
  'heuristic',
  'hopeful',
  'hungry',
  'infallible',
  'inspiring',
  'jolly',
  'jovial',
  'keen',
  'kind',
  'laughing',
  'loving',
  'lucid',
  'mystifying',
  'modest',
  'musing',
  'naughty',
  'nervous',
  'nifty',
  'nostalgic',
  'objective',
  'optimistic',
  'peaceful',
  'pedantic',
  'pensive',
  'practical',
  'priceless',
  'quirky',
  'quizzical',
  'relaxed',
  'reverent',
  'romantic',
  'sad',
  'serene',
  'sharp',
  'silly',
  'sleepy',
  'stoic',
  'stupefied',
  'suspicious',
  'tender',
  'thirsty',
  'trusting',
  'unruffled',
  'upbeat',
  'vibrant',
  'vigilant',
  'vigorous',
  'wizardly',
  'wonderful',
  'xenodochial',
  'youthful',
  'zealous',
  'zen',
]

const NOUNS = [
  'ardent',
  'artificer',
  'balrog',
  'barbarian',
  'bard',
  'cleric',
  'druid',
  'dwarf',
  'elf',
  'ent',
  'fighter',
  'giant',
  'goblin',
  'halfling',
  'hobbit',
  'illusionist',
  'invoker',
  'mage',
  'monk',
  'mystic',
  'orc',
  'paladin',
  'psion',
  'ranger',
  'rogue',
  'seeker',
  'sorcerer',
  'thief',
  'troll',
  'vampire',
  'warlock',
  'werewolf',
  'wizard',
]
