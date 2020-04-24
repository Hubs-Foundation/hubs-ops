const fs = require("fs");
const webpush = require("web-push");

function generateSecret() {
  return (
    Math.random()
      .toString(36)
      .slice(2) +
    Math.random()
      .toString(36)
      .slice(2) +
    Math.random()
      .toString(36)
      .slice(2)
  );
}

async function writeStackConfigs(
  outFile,
  retFilesPath,
  {
    domainName,
    stackName,
    projectSha,
    assetsDomain,
    corsProxyDomain,
    linkDomain,
    ip,
    databaseHost,
    databasePort,
    databaseUser,
    databasePassword,
    databaseName,
    nearsparkDomain,
    smtpHost,
    smtpPort,
    smtpUser,
    smtpPassword,
    smtpFrom,
    adminEmail,
    storagePath
  }
) {
  const vapidKeys = webpush.generateVAPIDKeys();

  let configs = await ensureConfigs(outFile, {
    JanusAndReticulumAdminSecret: {
      Targets: ["reticulum/phx/admin_access_key", "janus-gateway/general/admin_secret", "reticulum/janus/admin_secret"],
      OutputValue: generateSecret()
    },
    RetPhoenixSecretKey: {
      Targets: ["reticulum/phx/secret_key"],
      OutputValue: generateSecret()
    },
    GuardianSecretKeySecret: {
      Targets: ["reticulum/guardian/secret_key"],
      OutputValue: generateSecret()
    },
    ReticulumOAuthTokenSecret: {
      Targets: ["reticulum/guardian/oauth_token_key"],
      OutputValue: generateSecret()
    },
    ReticulumCookieSecret: {
      Targets: ["reticulum/erlang/node_cookie"],
      OutputValue: generateSecret()
    },
    ReticulumBotAccessKeySecret: {
      Targets: ["reticulum/ret/bot_access_key"],
      OutputValue: generateSecret()
    },
    AppPostgrestDbSecret: {
      Targets: ["reticulum/db/postgrest_password"],
      OutputValue: generateSecret()
    },
    ReticulumPublicVapidKey: {
      Targets: ["reticulum/web_push/public_key"],
      OutputValue: vapidKeys.publicKey
    },
    ReticulumPrivateVapidKey: {
      Targets: ["reticulum/web_push/private_key"],
      OutputValue: vapidKeys.privateKey
    }
  });

  configs = {
    ...configs,
    ...(await getReticulumPermsKey(retFilesPath))
  };

  // TODO generate vapid keys
  const postgrestDbPassword = configs.AppPostgrestDbSecret.OutputValue;

  configs = {
    ...configs,
    ...{
      DomainName: {
        Targets: ["reticulum/phx/url_host", "reticulum/phx/static_url_host", "spoke/general/hubs_server"],
        OutputValue: domainName
      },
      ReticulumServer: {
        Targets: ["hubs/general/reticulum_server", "spoke/general/reticulum_server"],
        OutputValue: ""
      },
      CorsOrigins: {
        Targets: ["reticulum/security/cors_origins"],
        OutputValue: `https://${domainName},https://${linkDomain},https://hubs.local:8080,https://localhost:8080`
      },
      NonCorsProxyDomains: {
        Targets: ["hubs/general/non_cors_proxy_domains", "spoke/general/non_cors_proxy_domains"],
        OutputValue: `${domainName},${assetsDomain},${stackName}-${projectSha}-hubs-worker.com`
      },
      WorkerDomain: {
        OutputValue: `${stackName}-${projectSha}-hubs-worker.com`
      },
      JanusMediaRtpPortRange: {
        Targets: ["janus-gateway/media/rtp_port_range"],
        OutputValue: "49152-60999"
      },
      JanusInternalPort: {
        Targets: ["janus-gateway/transports.websockets/wss_port"],
        OutputValue: 8443
      },
      JanusExternalPort: {
        Targets: ["reticulum/janus/janus_port"],
        OutputValue: 8443
      },
      JanusAdminPort: {
        Targets: ["janus-gateway/transports.http/admin_port", "reticulum/janus/admin_port"],
        OutputValue: 7000
      },
      JanusServiceName: {
        Targets: ["reticulum/janus/service_name"],
        OutputValue: "janus-gateway"
      },
      JanusNatMapping: {
        Targets: ["janus-gateway/nat/nat_1_1_mapping"],
        OutputValue: ip
      },
      RetInternalPort: {
        Targets: ["reticulum/phx/port"],
        OutputValue: 4000
      },
      RetExternalPort: {
        Targets: ["reticulum/phx/url_port"],
        OutputValue: 443
      },
      CorsProxyDNS: {
        Targets: [
          "reticulum/phx/cors_proxy_url_host",
          "hubs/general/cors_proxy_server",
          "spoke/general/cors_proxy_server"
        ],
        OutputValue: corsProxyDomain
      },
      ReticulumWebPushSubject: {
        Targets: ["reticulum/web_push/subject"],
        OutputValue: `mailto:info@${smtpFrom}`
      },
      AppDbUsername: {
        Targets: ["reticulum/db/username", "ita/db/username", "reticulum/session_lock_db/username"],
        OutputValue: databaseUser
      },
      AppDbSecret: {
        Targets: ["ita/db/password", "reticulum/db/password", "reticulum/session_lock_db/password"],
        OutputValue: databasePassword
      },
      AppDbDatabase: {
        Targets: ["reticulum/db/database", "ita/db/database", "reticulum/session_lock_db/database"],
        OutputValue: databaseName
      },
      AppDbHostname: {
        Targets: ["ita/db/hostname", "reticulum/db/hostname", "reticulum/session_lock_db/hostname"],
        OutputValue: databaseHost
      },
      AppDbPort: {
        Targets: ["reticulum/db/port", "ita/db/port", "reticulum/session_lock_db/port"],
        OutputValue: parseInt(databasePort)
      },
      PostgrestDbURI: {
        Targets: ["postgrest/db/uri"],
        OutputValue: `postgres://postgrest_authenticator:${postgrestDbPassword}@${databaseHost}:${databasePort}/${databaseName}?ssl=true`
      },
      PostgrestDbPool: {
        Targets: ["postgrest/db/pool"],
        OutputValue: 2
      },
      AssetsPath: {
        Targets: ["hubs/deploy/target", "spoke/deploy/target", "reticulum/assets/assets_path"],
        OutputValue: `${storagePath}/assets`
      },
      HubsBaseAssetsPath: {
        Targets: ["hubs/general/base_assets_path"],
        OutputValue: `https://${assetsDomain}/hubs/`
      },
      SpokeBaseAssetsPath: {
        Targets: ["spoke/general/base_assets_path"],
        OutputValue: `https://${assetsDomain}/spoke/`
      },
      HubsPageOrigin: {
        Targets: ["reticulum/pages/hubs_page_origin"],
        OutputValue: `https://${assetsDomain}/hubs/pages/latest`
      },
      SpokePageOrigin: {
        Targets: ["reticulum/pages/spoke_page_origin"],
        OutputValue: `https://${assetsDomain}/spoke/pages/latest`
      },
      AssetsDomain: {
        Targets: ["reticulum/phx/assets_url_host"],
        OutputValue: assetsDomain
      },
      ClientDeployType: {
        Targets: ["hubs/deploy/type", "spoke/deploy/type"],
        OutputValue: "cp"
      },
      StorageHost: {
        Targets: ["reticulum/uploads/host"],
        OutputValue: `https://${domainName}`
      },
      StoragePath: {
        Targets: ["reticulum/uploads/storage_path"],
        OutputValue: storagePath
      },
      ReticulumCSP: {
        Targets: ["reticulum/security/content_security_policy"],
        OutputValue: `default-src 'none'; manifest-src 'self'; script-src https://${stackName}-${projectSha}-hubs-worker.com 'self' 'sha256-hsbRcgUBASABDq7qVGVTpbnWq/ns7B+ToTctZFJXYi8=' 'sha256-MIpWPgYj31kCgSUFc0UwHGQrV87W6N5ozotqfxxQG0w=' 'sha256-/S6PM16MxkmUT7zJN2lkEKFgvXR7yL4Z8PCrRrFu4Q8=' https://www.google-analytics.com https://${assetsDomain} https://aframe.io https://www.youtube.com https://s.ytimg.com 'unsafe-eval'; prefetch-src 'self' https://${stackName}-${projectSha}-hubs-worker.com https://${assetsDomain}; child-src 'self' blob:; worker-src https://${assetsDomain} 'self' blob:; font-src 'self' https://fonts.googleapis.com https://cdn.jsdelivr.net https://fonts.gstatic.com https://cdn.aframe.io https://${assetsDomain} https://${stackName}-${projectSha}-hubs-worker.com https://${corsProxyDomain}; style-src 'self' https://fonts.googleapis.com https://cdn.jsdelivr.net https://${assetsDomain} https://${corsProxyDomain} https://${stackName}-${projectSha}-hubs-worker.com 'unsafe-inline'; connect-src 'self' https://${corsProxyDomain} https://cors-proxy.${stackName}-${projectSha}-hubs-worker.com https://${stackName}-${projectSha}-hubs-worker.com https://${linkDomain} https://dpdb.webvr.rocks https://${assetsDomain} https://${corsProxyDomain} https://${nearsparkDomain} wss://${domainName} wss://${domainName}:8443 https://cdn.aframe.io https://www.youtube.com https://api.github.com data: blob:; img-src 'self' https://www.google-analytics.com https://${assetsDomain} https://${corsProxyDomain} https://cors-proxy.${stackName}-${projectSha}-hubs-worker.com https://${stackName}-${projectSha}-hubs-worker.com https://${nearsparkDomain} https://cdn.aframe.io https://www.youtube.com https://user-images.githubusercontent.com https://cdn.jsdelivr.net data: blob:; media-src 'self' https://${corsProxyDomain} https://cors-proxy.${stackName}-${projectSha}-hubs-worker.com https://${stackName}-${projectSha}-hubs-worker.com https://${assetsDomain} https://${nearsparkDomain} https://www.youtube.com *.googlevideo.com data: blob:; frame-src https://www.youtube.com https://docs.google.com 'self'; base-uri 'none'; form-action 'self';`
      },
      SmtpUser: {
        Targets: ["reticulum/email/username"],
        OutputValue: smtpUser
      },
      SmtpPassword: {
        Targets: ["reticulum/email/password"],
        OutputValue: smtpPassword
      },
      SmtpSendFromAddress: {
        Targets: ["reticulum/email/from"],
        OutputValue: `noreply@${smtpFrom}`
      },
      SmtpServer: {
        Targets: ["reticulum/email/server"],
        OutputValue: smtpHost
      },
      SmtpPort: {
        Targets: ["reticulum/email/port"],
        OutputValue: parseInt(smtpPort)
      },
      BioHost: {
        Targets: ["reticulum/habitat/ip"],
        OutputValue: "127.0.0.1"
      },
      BioCensusPort: {
        Targets: ["reticulum/habitat/http_port"],
        OutputValue: 9631
      },
      ShortlinkDomainName: {
        Targets: ["hubs/general/shortlink_domain", "reticulum/phx/link_url_host"],
        OutputValue: linkDomain
      },
      AdminEmailAddress: {
        Targets: ["certbot/general/admin_email", "reticulum/accounts/admin_email"],
        OutputValue: adminEmail
      },
      CertbotPlugin: {
        Targets: ["certbot/general/plugin"],
        OutputValue: "standalone"
      },
      CertbotStandalonePort: {
        Targets: ["certbot/general/standalone_port"],
        OutputValue: 8000
      },
      ImgProxyHost: {
        Targets: ["reticulum/phx/imgproxy_url_host"],
        OutputValue: "localhost"
      },
      ImgProxyPort: {
        Targets: ["reticulum/phx/imgproxy_url_port"],
        OutputValue: 5000
      },
      ThumbnailServer: {
        Targets: ["hubs/general/thumbnail_server", "spoke/general/thumbnail_server"],
        OutputValue: domainName
      },
      EnableDbSsl: {
        Targets: ["reticulum/db/ssl", "reticulum/session_lock_db/ssl"],
        OutputValue: true
      }
    }
  };

  fs.writeFileSync(outFile, JSON.stringify(configs));

  console.log(`All set! Your hub will be available in a few minutes at https://${domainName}.`.brightWhite);
  console.log("To re-run setup, run /opt/polycosm/setup.sh".brightWhite);
}

async function ensureConfigs(inFile, configs) {
  const newConfigs = {};
  let oldConfigs = {};

  if (fs.existsSync(inFile)) {
    oldConfigs = JSON.parse(fs.readFileSync(inFile, "utf8"));
  }

  for (const [key, value] of Object.entries(configs)) {
    if (oldConfigs[key]) {
      newConfigs[key] = oldConfigs[key];
    } else {
      newConfigs[key] = value;
    }
  }

  return newConfigs;
}

async function getReticulumPermsKey(retFilesPath) {
  const path = `${retFilesPath}/jwt-key.pem`;

  if (!fs.existsSync(path)) {
    console.log("Waiting for keys...".cyan);

    await new Promise(res => {
      const interval = setInterval(() => {
        if (fs.existsSync(path)) {
          clearInterval(interval);
          res();
        }
      }, 5000);
    });
  }

  const pem = fs.readFileSync(path, "utf8").replace(/\n/g, "\\n");
  return {
    ReticulumPermsKey: {
      Targets: ["reticulum/guardian/perms_key"],
      OutputValue: pem
    }
  };
}

module.exports = { writeStackConfigs };
