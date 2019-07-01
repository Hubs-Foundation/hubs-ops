const ALLOWED_ORIGINS = ["https://hubs.local:8080", "https://hubs.local:9090", "https://hubs.local:4000", "https://dev.reticulum.io", "https://smoke-dev.reticulum.io", "https://hubs.mozilla.com", "https://smoke-hubs.mozilla.com"];
const PROXY_HOST = "https://hubs-proxy.com"

addEventListener("fetch", e => {
  const request = e.request;
  const origin = request.headers.get("Origin");
  const proxyUrl = new URL(PROXY_HOST);
  let targetUrl = request.url.substring(PROXY_HOST.length + 1).replace(/^http(s?):\/([^/])/, "http$1://$2");
  
  if (!targetUrl.startsWith("http://") && !targetUrl.startsWith("https://")) {
    targetUrl = proxyUrl.protocol + "//" + targetUrl;
  }
  
  const requestHeaders = new Headers(request.headers);
  requestHeaders.delete("Origin"); // Some domains disallow access from improper Origins

  e.respondWith((async () => {
    const res = await fetch(targetUrl, { headers: requestHeaders, method: request.method, redirect: "manual", referrer: request.referrer, referrerPolicy: request.referrerPolicy });
    const responseHeaders = new Headers(res.headers);

    if(responseHeaders.get("Location")) {
      responseHeaders.set("Location",  proxyUrl.protocol + "//" + proxyUrl.host + "/" + responseHeaders.get("Location"));
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
