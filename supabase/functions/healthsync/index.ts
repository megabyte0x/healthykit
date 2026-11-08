const upstreamOrigin = "https://api.healthysync.app";
const timeoutMilliseconds = 60_000;
const unavailableMessage = "Hosted service temporarily unavailable";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-app-version, x-device-id",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function proxyHeaders(source: Headers): Headers {
  const headers = new Headers(source);
  const connectionHeaders = (headers.get("connection") ?? "").split(",");
  for (const name of [
    ...connectionHeaders.map((name) => name.trim()).filter(Boolean),
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailer", "transfer-encoding", "upgrade", "host",
  ]) {
    headers.delete(name);
  }
  return headers;
}

function unavailable(): Response {
  return new Response(JSON.stringify({ detail: unavailableMessage }), {
    status: 503,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Retry-After": "5",
    },
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const abort = new AbortController();
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
  let output: ReadableStreamDefaultController<Uint8Array> | undefined;
  let finished = false;
  const cleanup = () => {
    finished = true;
    clearTimeout(timer);
    request.signal.removeEventListener("abort", fail);
  };
  const fail = () => {
    if (finished) return;
    cleanup();
    abort.abort(new Error(unavailableMessage));
    output?.error(new Error(unavailableMessage));
    void reader?.cancel().catch(() => {});
  };
  // Keep the deadline alive through streaming, including a stalled response body.
  const timer = setTimeout(fail, timeoutMilliseconds);
  request.signal.addEventListener("abort", fail, { once: true });

  try {
    if (request.signal.aborted) {
      fail();
      return unavailable();
    }
    const incoming = new URL(request.url);
    let path = incoming.pathname;
    for (const prefix of ["/functions/v1/healthsync", "/healthsync"]) {
      if (path === prefix || path.startsWith(prefix + "/")) {
        path = path.slice(prefix.length) || "/";
        break;
      }
    }
    // Assign the path on a fixed URL: a leading // must never select another host.
    const target = new URL(upstreamOrigin);
    target.pathname = path;
    target.search = incoming.search;
    const headers = proxyHeaders(request.headers);
    headers.set("Accept-Encoding", "identity");
    const response = await fetch(target, {
      method: request.method,
      headers,
      body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
      redirect: "manual",
      signal: abort.signal,
    });
    if (abort.signal.aborted) {
      void response.body?.cancel().catch(() => {});
      return unavailable();
    }
    const responseHeaders = proxyHeaders(response.headers);
    // Fetch can decompress upstream bytes while retaining their original framing.
    responseHeaders.delete("Content-Encoding");
    responseHeaders.delete("Content-Length");
    for (const [name, value] of Object.entries(corsHeaders)) {
      if (!responseHeaders.has(name)) responseHeaders.set(name, value);
    }
    const init = { status: response.status, statusText: response.statusText, headers: responseHeaders };
    if (!response.body || request.method === "HEAD") {
      cleanup();
      void response.body?.cancel().catch(() => {});
      return new Response(null, init);
    }
    reader = response.body.getReader();
    const body = new ReadableStream<Uint8Array>({
      start(controller) { output = controller; },
      async pull(controller) {
        try {
          const chunk = await reader!.read();
          if (finished) return;
          if (chunk.done) {
            cleanup();
            controller.close();
          } else {
            controller.enqueue(chunk.value);
          }
        } catch {
          fail();
        }
      },
      async cancel() {
        cleanup();
        abort.abort(new Error(unavailableMessage));
        await reader!.cancel().catch(() => {});
      },
    });
    return new Response(body, init);
  } catch {
    fail();
    return unavailable();
  }
});
