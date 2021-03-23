'use strict';

const AWS = require('aws-sdk');
const qs = require('querystring');
const https = require('https');

const slackToken = process.env.slackToken;
const jenkinsToken = process.env.jenkinsToken;
const allowedChannels = (process.env.allowedChannels || "").split(",").map(s => s.trim());

let token;
let jtoken;

function processEvent(event, callback) {
    const params = qs.parse(event.body);

    if (!allowedChannels.includes(params.channel_id)) {
        console.error(`Channel id ${params.channel_id} is not in the allowed channel list.`);
        return callback('Invalid channel id');
    }

    const requestToken = params.token;
    if (requestToken !== token) {
        console.error(`Request token (${requestToken}) does not match expected`);
        return callback('Invalid request token');
    }

    const user = params.user_name;
    const commandText = params.text;
    const commandParts = commandText.split(" ");

    const ciBaseUrl = 'https://ci-dev.reticulum.io/buildByToken/buildWithParameters';

    if (commandText.startsWith("hab promote ")) {
        const pkg = commandParts[2].trim();
        const url = `${ciBaseUrl}?job=hab-promote&PACKAGE=${pkg}&CHANNEL=stable&token=${jtoken}&SOURCE=${user}`;
        https.get(url, () => { callback(null, "Promotion started. See #mr-push."); });
    } else if (commandText.startsWith("hubs deploy ")) {
        const buildVersion = commandParts[2].trim();
        const s3url = commandParts[3].trim();
        const url = `${ciBaseUrl}?job=hubs-deploy&S3URL=${s3url}&token=${jtoken}&SOURCE=${user}&BUILD_VERSION=${buildVersion}`;
        https.get(url, () => { callback(null, "Hubs deploy started. See #mr-push."); });
    } else if (commandText.startsWith("spoke deploy ")) {
        const buildVersion = commandParts[2].trim();
        const s3url = commandParts[3].trim();
        const url = `${ciBaseUrl}?job=spoke-deploy&S3URL=${s3url}&token=${jtoken}&SOURCE=${user}&BUILD_VERSION=${buildVersion}`;
        https.get(url, () => { callback(null, "Spoke deploy started. See #mr-push."); });
    } else if (commandText.startsWith("ret deploy ")) {
        const retVersion = commandParts[2].trim();
        const retPool = commandParts[3].trim();
        const url = `${ciBaseUrl}?job=ret-deploy&RET_VERSION=${retVersion}&RET_POOL=${retPool}&token=${jtoken}&SOURCE=${user}`;
        https.get(url, () => { callback(null, "Reticulum deploy started. See #mr-push."); });
    } else if (commandText.startsWith("promote-ret-qa ") || commandText.startsWith("promote-hubs-qa ") || commandText.startsWith("promote-spoke-qa ")) {
        const type = commandParts[0].trim();
        const packageIdent = commandParts[1].trim();
        const url = `${ciBaseUrl}?job=promote-qa&PACKAGE=${encodeURIComponent(packageIdent)}&TYPE=${type}&token=${jtoken}&SOURCE=${user}`;
        https.get(url, () => { callback(null, "Promotion started."); });
    } else if (commandText.startsWith("test ")) {
        const msg = commandParts[2].trim();
        const url = `${ciBaseUrl}?job=bp-test&MSG=${msg}&token=${jtoken}&SOURCE=${user}`;
        https.get(url, () => { callback(null, "Test job started. See #mr-push."); });
    } else {
        callback(null, (
            `Invalid command, try \`hab promote <package>, ret deploy <version> <pool>, ` +
            `hubs deploy <version> <s3 target>, spoke deploy <version> <s3 target>\``
        ));
    }
}

function decrypt(kms, token, useFunctionName) {
    return new Promise((resolve, reject) => {
        const cipherText = { CiphertextBlob: Buffer.from(token, 'base64') };
        if (useFunctionName) {
            cipherText.EncryptionContext = {LambdaFunctionName: process.env.AWS_LAMBDA_FUNCTION_NAME}
        }

        kms.decrypt(cipherText, (err, data) => {
            if (err) {
                console.log('Decrypt error:', err);
                reject(err);
                return;
            }

            resolve(data.Plaintext.toString('ascii'));
        });
    });
}

function decryptWithFunctionContext(kms, token) {
    return decrypt(kms, token, true);
}

exports.handler = (event, context, callback) => {
    const done = (err, res, type) => callback(null, {
        statusCode: err ? '400' : '200',
        body: err ? (err.message || err) : type === "text" ? res : JSON.stringify(res),
        headers: {
            'Content-Type': type === "text" ? 'text/plain' : 'application/json',
        },
    });

    if (token && jtoken) {
        // Container reuse, simply process the event with the key in memory
        processEvent(event, done);
    } else if (slackToken && slackToken !== '<slackToken>') {
        try {
            // We want to use `await` for the decryption calls in order to avoid callback hell.
            // You'd think we could just make the `handler` function async, but that changes the behavior 
            // with respect to AWS Lambda's execution context. We'd have to `await` processEvent all the way
            // through. Instead, we still want to use `done` to signal completion, so we just wrap this section with
            // an anonymous async iife in order to await the decryption calls.
            (async () => {
                const kms = new AWS.KMS();
                // Newer tokens are encrypted with a function context.
                token = await decryptWithFunctionContext(kms, slackToken);
                jtoken = await decrypt(kms, jenkinsToken); 
                processEvent(event, done);
            })()
        } catch(e) {
            done(e);
        }
    } else {
        done('Token has not been set.');
    }
};
