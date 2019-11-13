const https = require("https");
const url = require("url");
const AWS = require('aws-sdk');
const promisify = f =>
  arg =>
    new Promise((res, rej) => f(arg, (err, data) => { if (err) { console.log(err); rej(err); } else { res(data); } }));

function getReason(err) {
  if (err)
    return err.message;
  else
    return '';
}

async function sendResponse(fileSystemId, event, context, status, data, err) {
  const responseBody = {
    StackId: event.StackId,
    RequestId: event.RequestId,
    LogicalResourceId: event.LogicalResourceId,
    PhysicalResourceId: fileSystemId,
    Status: status,
    Reason: getReason(err) + " See details in CloudWatch Log: " + context.logStreamName,
    Data: data
  };

  const json = JSON.stringify(responseBody);

  const parsedUrl = url.parse(event.ResponseURL);

  const options = {
    hostname: parsedUrl.hostname,
    port: 443,
    path: parsedUrl.path,
    method: "PUT",
    headers: {
      "content-type": "",
      "content-length": json.length
    }
  };

  await new Promise((res, rej) => {
    const request = https.request(options, () => {
      context.done(null, data)
      res();
    });

    request.on("error", (error) => {
      console.log("sendResponse Error:\n", error);
      context.done(error);
      rej();
    });

    request.write(json);
    request.end();
  });
}

exports.handler = async function (event, context) {
  const efs = new AWS.EFS();

  if (event.RequestType == 'Create' || event.RequestType == 'Update') {
    const PerformanceMode = event.ResourceProperties.PerformanceMode || "generalPurpose";
    const ThroughputMode = event.ResourceProperties.ThroughputMode || "bursting";
    const CreationToken = event.RequestId;
    let ProvisionedThroughputInMibps = null;

    if (ThroughputMode === "provisioned") {
      ProvisionedThroughputInMibps = event.ResourceProperties.ProvisionedThroughputInMibps;
    }

    const Encrypted = event.ResourceProperties.Encrypted || false;
    const Tags = event.ResourceProperties.FileSystemTags || [];
    const KmsKeyId = event.ResourceProperties.KmsKeyId || null;
    let FileSystemId;

    if (event.RequestType === 'Create') {
      const BackupVaultName = event.ResourceProperties.RestoreBackupVaultName;
      const RecoveryPointArn = event.ResourceProperties.RestoreRecoveryPointArn;
      const IamRoleArn = event.ResourceProperties.RestoreIamRoleArn;

      if (RecoveryPointArn && BackupVaultName) {
        const backup = new AWS.Backup();

        const restorePointMetadata = (await promisify(backup.getRecoveryPointRestoreMetadata.bind(backup))({
          BackupVaultName, RecoveryPointArn
        })).RestoreMetadata;

        const RestoreJobId = (await promisify(backup.startRestoreJob.bind(backup))({
          RecoveryPointArn,
          Metadata: {
            "file-system-id": restorePointMetadata["file-system-id"],
            PerformanceMode,
            CreationToken,
            Encrypted,
            KmsKeyId,
            newFileSystem: "true"
          },
          ResourceType: "EFS",
          IdempotencyToken: CreationToken,
          IamRoleArn
        })).RestoreJobId;

        FileSystemId = await new Promise(async (res, rej) => {
          let interval;

          const f = async () => {
            const restoreStatus = await promisify(backup.describeRestoreJob.bind(backup))({
              RestoreJobId
            });

            if (restoreStatus.Status === "COMPLETED" || restoreStatus.Status === "FAILED") {
              if (interval) {
                clearInterval(interval);
              }

              if (restoreStatus.Status === "COMPLETED") {
                res(restoreStatus.CreatedResourceArn);
              } else {
                await sendResponse(null, event, context, "FAILED", {}, "Restore job failed.");
                rej();
              }

              return true;
            }

            return false;
          };

          if (!await f()) {
            interval = setInterval(f, 10000);
          }
        });

        await promisify(efs.createTags.bind(efs))({ FileSystemId, Tags });
      } else {
        FileSystemId = (await promisify(efs.createFileSystem.bind(efs))({
          PerformanceMode, CreationToken, ThroughputMode, Encrypted, Tags, KmsKeyId, ProvisionedThroughputInMibps
        })).FileSystemId;
      }
    } else {
      FileSystemId = event.PhysicalResourceId;

      await promisify(efs.updateFileSystem.bind(efs))({
        FileSystemId, ThroughputMode, ProvisionedThroughputInMibps
      });
    }

    await new Promise(async res => {
      let interval;

      const f = async () => {
        const info = (await promisify(efs.describeFileSystems.bind(efs))({
          FileSystemId
        }));

        if (info.FileSystems[0].LifeCycleState === "available") {
          if (interval) {
            clearInterval(interval);
          }

          res();
          return true;
        }

        return false;
      };

      if (!await f()) {
        interval = setInterval(f, 10000);
      }
    });

    const LifecyclePolicies = event.ResourceProperties.LifecyclePolicies;

    if (LifecyclePolicies) {
      await promisify(efs.putLifecycleConfiguration.bind(efs))({
        FileSystemId, LifecyclePolicies
      });
    }

    await sendResponse(FileSystemId, event, context, "SUCCESS");

    return;
  }

  if (event.RequestType == 'Delete') {
    const FileSystemId = event.PhysicalResourceId;

    await promisify(efs.deleteFileSystem.bind(efs))({ FileSystemId });
    await sendResponse(FileSystemId, event, context, "SUCCESS");

    return;
  }
}
