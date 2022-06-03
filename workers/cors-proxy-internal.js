const ALLOWED_ORIGINS = [
  "https://hubs.local:8080",
  "https://hubs.local:9090",
  "https://hubs.local:4000",
  "https://dev.reticulum.io",
  "https://smoke-dev.reticulum.io",
  "https://hubs.mozilla.com",
  "https://smoke-hubs.mozilla.com",
  "https://photomnemonic-utils.reticulum.io",
];
const PROXY_URL = "https://hubs-proxy.com";

addEventListener("fetch", (event) => {
  const request = event.request;
  const origin = request.headers.get("Origin");
  const proxyUrl = new URL(PROXY_URL);

  const protocolWithSingleSlash = /^http(s?):\/([^/])/;
  let targetUrlStr = request.url.substring(PROXY_URL.length + 1).replace(protocolWithSingleSlash, "http$1://$2");
  if (!targetUrlStr.startsWith("http://") && !targetUrlStr.startsWith("https://")) {
    targetUrlStr = proxyUrl.protocol + "//" + targetUrlStr;
  }

  const requestHeaders = new Headers(request.headers);
  requestHeaders.delete("Origin"); // Some domains disallow access from improper Origins

  event.respondWith(
    (async () => {
      const res = await fetch(targetUrlStr, {
        headers: requestHeaders,
        method: request.method,
        redirect: "manual",
        referrer: request.referrer,
        referrerPolicy: request.referrerPolicy,
      });

      const responseHeaders = new Headers(res.headers);

      const redirectLocation = responseHeaders.get("Location");
      if (redirectLocation) {
        if (!redirectLocation.startsWith("/")) {
          responseHeaders.set("Location", PROXY_URL + "/" + redirectLocation);
        } else {
          const targetUrl = new URL(targetUrlStr);
          responseHeaders.set("Location", PROXY_URL + "/" + targetUrl.origin + redirectLocation);
        }
      }

      if (origin && ALLOWED_ORIGINS.includes(origin)) {
        responseHeaders.set("Access-Control-Allow-Origin", origin);
        responseHeaders.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
        responseHeaders.set("Access-Control-Allow-Headers", "Range");
        responseHeaders.set(
          "Access-Control-Expose-Headers",
          "Accept-Ranges, Content-Encoding, Content-Length, Content-Range"
        );
      }

      responseHeaders.set("Vary", "Origin");
      responseHeaders.set("X-Content-Type-Options", "nosniff");

      const responseContentType = (responseHeaders.get("Content-Type") || "").toLowerCase();
      if (responseContentType.includes("script") || responseContentType.includes("html")) {
        responseHeaders.set("Content-Type", "text/plain");
      }

      return new Response(res.body, {
        status: res.status,
        statusText: res.statusText,
        headers: responseHeaders,
      });
    })()
  );
});
