const ALLOWED_ORIGINS = ["https://hubs.local:8080", "https://hubs.local:9090", "https://hubs.local:4000", "https://dev.reticulum.io", "https://smoke-dev.reticulum.io", "https://hubs.mozilla.com", "https://smoke-hubs.mozilla.com", "https://photomnemonic-utils.reticulum.io"];
const CORS_PROXY_HOST = "https://cors-proxy.hubs-proxy.com"
const PROXY_HOST = "https://hubs-proxy.com"
const STORAGE_HOST = "https://hubs.mozilla.com";
const ASSETS_HOST = "https://assets-prod.reticulum.io";
  
let cache = caches.default;

addEventListener("fetch", e => {
  const request = e.request;
  const origin = request.headers.get("Origin");
  // eslint-disable-next-line no-useless-escape

  const isCorsProxy = request.url.indexOf(CORS_PROXY_HOST) === 0;
  const proxyUrl = new URL(isCorsProxy ? CORS_PROXY_HOST : PROXY_HOST);
  const targetPath = request.url.substring((isCorsProxy ? CORS_PROXY_HOST : PROXY_HOST).length + 1);
  let useCache = false;
  let targetUrl;

  if (targetPath.indexOf("files/") === 0) {
    useCache = true;
    targetUrl = `${STORAGE_HOST}/${targetPath}`;
  } else if (targetPath.indexOf("hubs/") === 0 || targetPath.indexOf("spoke/") === 0 || targetPath.indexOf("admin/") === 0) {
    useCache = true;
    targetUrl = `${ASSETS_HOST}/${targetPath}`;
  } else {
    if (!isCorsProxy) {
      // Do not allow cors proxying from main domain, always require cors-proxy. subdomain to ensure CSP stays sane.
      return;
    }
    targetUrl = targetPath.replace(/^http(s?):\/([^/])/, "http$1://$2");

    if (!targetUrl.startsWith("http://") && !targetUrl.startsWith("https://")) {
      targetUrl = proxyUrl.protocol + "//" + targetUrl;
    }
  }
  
  const requestHeaders = new Headers(request.headers);
  requestHeaders.delete("Origin"); // Some domains disallow access from improper Origins

  e.respondWith((async () => {
    let cacheReq;
    let res;
    let fetched = false;

    if (useCache) {
      cacheReq = new Request(targetUrl, { headers: requestHeaders, method: request.method, redirect: "manual" });
      res = await cache.match(cacheReq, {});
    }

    if (!res) {
      res = await fetch(targetUrl, { headers: requestHeaders, method: request.method, redirect: "manual", referrer: request.referrer, referrerPolicy: request.referrerPolicy });      
      fetched = true;
    }

    let body = res.body;

    if (useCache && fetched) {
      const [body1, body2] = res.body.tee();
      body = body2;
      await cache.put(cacheReq, new Response(body1, { status: res.status, statusText: res.statusText, headers: res.headers }));
    }

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

    return new Response(body, { status: res.status, statusText: res.statusText, headers: responseHeaders });  
  })());
});
