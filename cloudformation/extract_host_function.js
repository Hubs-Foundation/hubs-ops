const URL = require('url');
const parseURL = {};

function btoa(s) {
  return Buffer.from(s).toString('base64');
}

parseURL.handler = function(event, context) {
	const url = event.ResourceProperties.URL || "https://en.wikipedia.org/wiki/Rubber_duck";

	try {
		const parsed = URL.parse(url);
		const pathname = parsed.pathname;

		return sendResponse(event, context, "SUCCESS", {
			S3ReplaceKeyPrefixWith: `${parsed.pathname.substring(1)}${parsed.search || ""}${parsed.hash || ""}`,
			S3Protocol: parsed.protocol.replace(":", ""),
			S3Hostname: parsed.host,
			ALBProtocol: parsed.protocol.replace(":", "").toUpperCase(),
			ALBPort: parsed.port,
			ALBHost: parsed.host,
      ALBPath: parsed.pathname,
			ALBQuery: `${parsed.search || ""}${parsed.hash || ""}`.replace(/^\?/, "")
		});
	} catch (e) {
    return sendResponse(event, context, "FAILED", null, `Invalid URL specified: ${url}`);
	}
};

function getReason(err) {
  if (err)
    return err.message;
  else
    return '';
}

function sendResponse(event, context, status, data, err) {
  var responseBody = {
    StackId: event.StackId,
    RequestId: event.RequestId,
    LogicalResourceId: event.LogicalResourceId,
    PhysicalResourceId: 'parseUrl-' + btoa(event.ResourceProperties.URL),
    Status: status,
    Reason: getReason(err) + " See details in CloudWatch Log: " + context.logStreamName,
    Data: data
  };

  console.log("RESPONSE:\n", responseBody);
  var json = JSON.stringify(responseBody);

  var https = require("https");
  var url = require("url");

  var parsedUrl = url.parse(event.ResponseURL);
  var options = {
    hostname: parsedUrl.hostname,
    port: 443,
    path: parsedUrl.path,
    method: "PUT",
    headers: {
      "content-type": "",
      "content-length": json.length
    }
  };

  var request = https.request(options, function(response) {
    console.log("STATUS: " + response.statusCode);
    console.log("HEADERS: " + JSON.stringify(response.headers));
    context.done(null, data);
  });

  request.on("error", function(error) {
    console.log("sendResponse Error:\n", error);
    context.done(error);
  });

  request.on("end", function() {
    console.log("end");
  });
  request.write(json);
  request.end();
}

module.exports = parseURL;
