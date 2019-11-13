const https = require("https");
const url = require("url");

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
    PhysicalResourceId: 'efs-' + fileSystemId,
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
		let ProvisionedThroughputInMibps = null;

		if (ThroughputMode === "provisioned") {
			ProvisionedThroughputInMibps = event.ResourceProperties.ProvisionedThroughputInMibps;
		}

		const Encrypted = event.ResourceProperties.Encrypted || false;
		const Tags = event.ResourceProperties.FileSystemTags || [];
		const KmsKeyId = event.ResourceProperties.KmsKeyId || null;
		let FileSystemId;

		if (event.RequestType === 'Create') {
			FileSystemId = (await promisify(efs.createFileSystem.bind(efs)({
				PerformanceMode, ThroughputMode, Encrypted, Tags, KmsKeyId, ProvisionedThroughputInMibps
			}))).FileSystemId;
		} else {
			FileSystemId = event.PhysicalResourceId;

			await promisify(efs.updateFileSystem.bind(efs)({
				FileSystemId, ThroughputMode, ProvisionedThroughputInMibps
			}));
		}

		await new Promise(res => {
			const interval = setInterval(async () => {
				const info = (await promisify(efs.describeFileSystems.bind(efs))({
					FileSystemId
				}));

				if (info.LifeCycleState === "available") {
					res();
					clearInterval(interval);
				}
			}, 10000);
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
    return sendResponse(event, context, "SUCCESS");
  }
}
