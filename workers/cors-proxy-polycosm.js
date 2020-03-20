const ALLOWED_ORIGINS = ["https://hubs.local:8080", "https://hubs.local:9090", "https://hubs.local:4000", "https://dev.reticulum.io", "https://smoke-dev.reticulum.io", "https://hubs.mozilla.com", "https://smoke-hubs.mozilla.com", "https://photomnemonic-utils.reticulum.io"];
const CORS_PROXY_HOST = "https://cors-proxy.hubs-proxy.com"
const PROXY_HOST = "https://hubs-proxy.com"
const STORAGE_HOST = "https://hubs.mozilla.com";
const ASSETS_HOST = "https://assets-prod.reticulum.io";
  
addEventListener("fetch", e => {
  const request = e.request;
  const origin = request.headers.get("Origin");
  // eslint-disable-next-line no-useless-escape

  const isCorsProxy = request.url.indexOf(CORS_PROXY_HOST) === 0;
  const proxyUrl = new URL(isCorsProxy ? CORS_PROXY_HOST : PROXY_HOST);
  const targetPath = request.url.substring((isCorsProxy ? CORS_PROXY_HOST : PROXY_HOST).length + 1);
  let targetUrl;

  if (targetPath.startsWith("files/")) {
    targetUrl = \`\${STORAGE_HOST}/\${targetPath}\`;
  } else if (targetPath.startsWith("hubs/") || targetPath.startsWith("spoke/") || targetPath.startsWith("admin/")) {
    targetUrl = \`\${ASSETS_HOST}/\${targetPath}\`;
  } else {
    if (!isCorsProxy) {
      // Do not allow cors proxying from main domain, always require cors-proxy. subdomain to ensure CSP stays sane.
      return;
    }
    // This is a weird workaround that seems to stem from the cloudflare worker receiving the wrong url
    targetUrl = targetPath.replace(/^http(s?):\/([^/])/, "http$1://$2");

    if (!targetUrl.startsWith("http://") && !targetUrl.startsWith("https://")) {
      targetUrl = proxyUrl.protocol + "//" + targetUrl;
    }
  }
  
  const requestHeaders = new Headers(request.headers);
  requestHeaders.delete("Origin"); // Some domains disallow access from improper Origins

  e.respondWith((async () => {
    const res = await fetch(targetUrl, { headers: requestHeaders, method: request.method, redirect: "manual", referrer: request.referrer, referrerPolicy: request.referrerPolicy });      
    const responseHeaders = new Headers(res.headers);
    const redirectLocation = responseHeaders.get("Location") || responseHeaders.get("location");

    if(redirectLocation) {
      if (!redirectLocation.startsWith("/")) {
        responseHeaders.set("Location",  proxyUrl.protocol + "//" + proxyUrl.host + "/" + redirectLocation);
      } else {
        const tUrl = new URL(targetUrl);
        responseHeaders.set("Location",  proxyUrl.protocol + "//" + proxyUrl.host + "/" + tUrl.origin + redirectLocation);
      }
    }

    if (origin && ALLOWED_ORIGINS.indexOf(origin) >= 0) {
      responseHeaders.set("Access-Control-Allow-Origin", origin);
      responseHeaders.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
      responseHeaders.set("Access-Control-Allow-Headers", "Range");
      responseHeaders.set("Access-Control-Expose-Headers", "Accept-Ranges, Content-Encoding, Content-Length, Content-Range");
    }

    responseHeaders.set("Vary", "Origin");
    responseHeaders.set('X-Content-Type-Options', "nosniff");

    return new Response(res.body, { status: res.status, statusText: res.statusText, headers: responseHeaders });  
  })());
});
