'use strict';

const AWS = require('aws-sdk');
const qs = require('querystring');
const https = require('https');

const slackToken = process.env.slackToken;
const jenkinsToken = process.env.jenkinsToken;
const reticulumToken = process.env.reticulumToken;
const slackClientIdToken = process.env.slackClientIdToken;
const slackSecretToken = process.env.slackSecretToken;

let token;
let jtoken;
let rtoken;
let slackClientId;
let slackSecret;

function processOAuth(event, callback) {
    const params = new URLSearchParams({
        code: event.queryStringParameters.code,
        client_id: slackClientId,
        client_secret: slackSecret
    });

    https.get("https://slack.com/api/oauth.v2.access?" + params, (res) => {
        if (res.statusCode < 400) {
            callback(null, 'Slack App successfully registered', 'text');
        } else {
            callback(null, `Slack App failed to register (${res.statusCode})`, 'text');
        }
    })
}

function processEvent(event, callback) {
    if (event.httpMethod === "GET" && "oauth" in event.queryStringParameters) {
        processOAuth(event, callback);
        return;
    }

    const params = qs.parse(event.body);
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
    } else if (commandText.startsWith("test ")) {
        const msg = commandParts[2].trim();
        const url = `${ciBaseUrl}?job=bp-test&MSG=${msg}&token=${jtoken}&SOURCE=${user}`;
        https.get(url, () => { callback(null, "Test job started. See #mr-push."); });
    } else if (commandText.startsWith("hubs support on")) {
        const options = {
            hostname: 'hubs.mozilla.com',
            port: 443,
            path: '/api/v1/support/subscriptions',
            method: 'POST',
            headers: {
                'x-ret-admin-access-key': rtoken,
                'Content-Type': "application/json"
            }
        };

        const req = https.request(options, () => { callback(null, "You are now available for Hubs support requests."); });
        req.write("{ \"subscription\": { \"identifier\": \"" + user + "\" } }");
        req.end();
    } else if (commandText.startsWith("hubs support off")) {
        const options = {
            hostname: 'hubs.mozilla.com',
            port: 443,
            path: '/api/v1/support/subscriptions/' + user,
            method: 'DELETE',
            headers: {
                'x-ret-admin-access-key': rtoken,
                'Content-Type': "application/json"
            }
        };

        const req = https.request(options, () => {
            callback(null, "You are now no longer available for Hubs support requests.");
        });
        req.write("{ }");
        req.end();
    } else {
        callback(null, (
            `Invalid command, try \`hab promote <package>, ret deploy <version> <pool>, ` +
            `hubs deploy <version> <s3 target>, hubs support on, hubs support off\``
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

    if (token && jtoken && rtoken && slackClientId && slackSecret) {
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
                token = await decryptWithFunctionContext(kms, slackToken);
                jtoken = await decrypt(kms, jenkinsToken); 
                rtoken = await decrypt(kms, reticulumToken);
                slackClientId = await decryptWithFunctionContext(kms, slackClientIdToken);  
                slackSecret = await decryptWithFunctionContext(kms, slackSecretToken);
                processEvent(event, done);
            })()
        } catch(e) {
            done(e);
        }
    } else {
        done('Token has not been set.');
    }
};
