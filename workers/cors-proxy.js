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

async function proxyRequest(r) {
  const url = new URL(r.url);

  const prefix = "/";

  if (url.pathname.startsWith(prefix)) {
    const remainingUrl = url.pathname.replace(new RegExp("^" + prefix), "");
    let targetUrl = decodeURIComponent(remainingUrl);
    if (!targetUrl.startsWith("http://") && !targetUrl.startsWith("https://")) {
      targetUrl = url.protocol + "//" + targetUrl;
    }

    const sendHeaders = new Headers();

    for (const [name, value] of r.headers) {
      sendHeaders[name] = value;
    }

    return fetch(targetUrl, {
      headers: sendHeaders,
      method: r.method,
      redirect: "manual",
      referrer: r.referrer,
      referrerPolicy: r.referrerPolicy
    }).then(res => {
      const headers = {};

      for (const [name, value] of res.headers) {
        if (name === "location") {
          headers[name] = url.protocol + "//" + url.host + "/" + encodeURIComponent(value);
        } else {
          headers[name] = value;
        }
      }

      for (const [name, value] of r.headers) {
        if (name.toLowerCase() === "origin" && ALLOWED_ORIGINS.indexOf(value) >= 0) {
          headers["access-control-allow-origin"] = value;
          headers["access-control-allow-methods"] = "GET, HEAD, OPTIONS"
        }
      }

      headers["vary"] = "Origin";

      let { readable, writable } = new TransformStream();

      streamBody(res.body, writable);

      return new Response(readable, { status: res.status, statusText: res.statusText, headers });
    });
  } else {
    return new Response("Bad Request", { status: 400, statusText: "Bad Request" });
  }
}

addEventListener("fetch", e => {
  e.respondWith(proxyRequest(e.request));
});
