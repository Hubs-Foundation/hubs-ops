const ALLOWED_ORIGINS = ["hubs.mozilla.com", "smoke-hubs.mozilla.com"];

async function streamBody(readable, writable) {
  let reader = readable.getReader()
  let writer = writable.getWriter()

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    // Optionally transform value's bytes here.
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

    return fetch(targetUrl, {
      headers: r.headers,
      method: r.method,
      redirect: "follow",
      referrer: r.referrer,
      referrerPolicy: r.referrerPolicy
    }).then(res => {
      const headers = {};

      for (const [name, value] of res.headers) {
        headers[name] = value;
      }

      for (const [name, value] of r.headers) {
        if (name.toLowerCase() === "origin" && ALLOWED_ORIGINS.indexOf(value) >= 0) {
          headers["access-control-allow-origin"] = value;
        }
      }

      let { readable, writable } = new TransformStream();

      streamBody(res.body, writable);

      return new Response(readable, { headers });
    });
  } else {
    return new Response("Bad Request", { status: 400, statusText: "Bad Request" });
  }
}

addEventListener("fetch", e => {
  e.respondWith(proxyRequest(e.request));
});
