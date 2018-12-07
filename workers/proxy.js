const ALLOWED_ORIGINS = ["hubs.mozilla.com", "smoke-hubs.mozilla.com"];

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

        if (name.toLowerCase() === "origin" && ALLOWED_ORIGINS.indexOf(value) >= 0) {
          headers["Access-Control-Allow-Origin"] = value;
        }
      }

      return new Response(res.body, { headers });
    });
  } else {
    return new Response("Bad Request", { status: 400, statusText: "Bad Request" });
  }
}

addEventListener("fetch", e => {
  e.respondWith(proxyRequest(e.request));
});
