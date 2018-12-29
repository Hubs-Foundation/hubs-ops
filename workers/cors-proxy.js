const ALLOWED_ORIGINS = ["https://hubs.local:8080", "https://hubs.local:4000", "https://dev.reticulum.io", "https://smoke-dev.reticulum.io", "https://hubs.mozilla.com", "https://smoke-hubs.mozilla.com"];

async function streamBody(readable, writable) {
  let reader = readable.getReader()
  let writer = writable.getWriter()

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    await writer.write(value)
  }

  await writer.close()
}

addEventListener("fetch", e => {
  const request = e.request;
  const url = new URL(request.url);
  const origin = request.headers.get("Origin");

  let targetUrl = decodeURIComponent(url.pathname.substring(1));

  if (!targetUrl.startsWith("http://") && !targetUrl.startsWith("https://")) {
    targetUrl = url.protocol + "//" + targetUrl;
  }

  const proxyHeaders = {};

  for (let name of ["Accept", "Accept-Encoding", "Accept-Language", "Range", "Referer", "User-Agent"]) {
    let value = request.headers.get(name);
    if (!value) continue;

    proxyHeaders[name] = value;
  }

  e.respondWith((async () => {
    const res = await fetch(targetUrl, { headers: proxyHeaders, method: request.method, redirect: "manual", referrer: request.referrer, referrerPolicy: request.referrerPolicy });

    const responseHeaders = {};

    for (let name of ["Content-Type", "Cache-Control", "Expires", "Accept-Ranges", "Range", "Date", "Last-Modified", "ETag", "Location"]) {
      let value = res.headers.get(name);
      if (!value) continue;

      if (name === "Location") {
        responseHeaders[name] = url.protocol + "//" + url.host + "/" + encodeURIComponent(value);
      } else {
        responseHeaders[name] = value;
      }
    }

    if (origin && ALLOWED_ORIGINS.indexOf(origin) >= 0) {
      responseHeaders["Access-Control-Allow-Origin"] = origin;
      responseHeaders["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS";
    }

    responseHeaders["Vary"] = "Origin";
    responseHeaders['X-Content-Type-Options'] = "nosniff"

    let { readable, writable } = new TransformStream();

    streamBody(res.body, writable);
    return new Response(readable, { status: res.status, statusText: res.statusText, headers: responseHeaders });
  })());
});
