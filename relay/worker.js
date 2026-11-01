// AWIeffect AI Link relay (Cloudflare Worker + Durable Object).
//
// Phone:  wss://<relay>/phone?key=<secret>       — the app keeps this socket open while a project is open.
// Claude: https://<relay>/mcp/<secret>           — remote MCP server (add it as a custom connector in Claude).
//
// Each secret key gets its own Durable Object, which holds the phone's socket and forwards Claude's tool calls
// to it as JSON requests, then hands the phone's answer back. Nothing is stored; without the key nothing works.

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    let key = "";
    if (url.pathname === "/phone") key = url.searchParams.get("key") || "";
    else if (url.pathname.startsWith("/mcp/")) key = url.pathname.slice(5).split("/")[0];
    else if (url.pathname === "/") return new Response("AWIeffect relay is running.", { status: 200 });
    else return new Response("not found", { status: 404 });
    if (!/^[0-9a-f]{32,128}$/.test(key)) return new Response("missing or bad key", { status: 401 });
    const stub = env.LINK.get(env.LINK.idFromName(key));
    return stub.fetch(req);
  },
};

const TOOLS = [
  { name: "get_info", description: "App version, effect count and a summary of the open project (size, fps, duration, layers, playhead, selection).",
    inputSchema: { type: "object", properties: {} }, call: () => ["GET", "/info"] },
  { name: "get_catalog", description: "Every effect with its settings and ranges, blend modes, layer presets, title styles and text animations. Read this before adding effects.",
    inputSchema: { type: "object", properties: {} }, call: () => ["GET", "/catalog"] },
  { name: "get_project", description: "The open project as JSON (layers, keyframes, effects, text, cameras…).",
    inputSchema: { type: "object", properties: {} }, call: () => ["GET", "/project"] },
  { name: "set_project", description: "Replace the open project with edited JSON (one undo step in the app). Always start from get_project and keep ids.",
    inputSchema: { type: "object", properties: { project: { type: "object" } }, required: ["project"] },
    call: (a) => ["PUT", "/project", {}, JSON.stringify(a.project)] },
  { name: "render_frame", description: "Render the frame at t seconds as a PNG to check your work.",
    inputSchema: { type: "object", properties: { t: { type: "number" }, size: { type: "number", description: "max side in px (default 720)" } } },
    call: (a) => ["POST", "/render", { t: String(a.t ?? ""), size: String(a.size ?? 720) }], image: true },
  { name: "upload_media", description: "Add an image / video / audio file to the project's media (base64). Returns the file name to use in a layer.",
    inputSchema: { type: "object", properties: { base64: { type: "string" }, ext: { type: "string" } }, required: ["base64", "ext"] },
    call: (a) => ["POST", "/media", { ext: a.ext }, null, a.base64] },
  { name: "run_action", description: "Run an app action: undo, redo, seek {t}, select {id}, play, pause, cutoutSubject {id}.",
    inputSchema: { type: "object", properties: { name: { type: "string" } }, required: ["name"], additionalProperties: true },
    call: (a) => ["POST", "/action", {}, JSON.stringify(a)] },
];

export class Link {
  constructor(state) {
    this.state = state;
    this.pending = new Map();
  }

  phone() { return this.state.getWebSockets("phone")[0]; }

  async fetch(req) {
    const url = new URL(req.url);
    if (url.pathname === "/phone") {
      if (req.headers.get("Upgrade") !== "websocket") return new Response("websocket only", { status: 426 });
      for (const old of this.state.getWebSockets("phone")) { try { old.close(4000, "replaced"); } catch {} }
      const [client, server] = Object.values(new WebSocketPair());
      this.state.acceptWebSocket(server, ["phone"]);
      server.send(JSON.stringify({ id: "hello", hello: true }));
      return new Response(null, { status: 101, webSocket: client });
    }
    return this.mcp(req);
  }

  webSocketMessage(ws, msg) {
    let m;
    try { m = JSON.parse(typeof msg === "string" ? msg : new TextDecoder().decode(msg)); } catch { return; }
    const p = this.pending.get(m.id);
    if (p) { this.pending.delete(m.id); p(m); }
  }

  webSocketClose() {
    for (const [, p] of this.pending) p({ status: 503, type: "application/json", body: btoa(JSON.stringify({ error: "phone disconnected" })) });
    this.pending.clear();
  }

  ask(method, path, query = {}, bodyText = null, bodyB64 = null) {
    const ws = this.phone();
    if (!ws) return Promise.resolve(null);
    const id = crypto.randomUUID();
    const body = bodyB64 ?? (bodyText != null ? btoa(unescape(encodeURIComponent(bodyText))) : "");
    return new Promise((resolve) => {
      const timer = setTimeout(() => { this.pending.delete(id); resolve({ status: 504, type: "application/json", body: btoa('{"error":"phone took too long"}') }); }, 60000);
      this.pending.set(id, (m) => { clearTimeout(timer); resolve(m); });
      ws.send(JSON.stringify({ id, method, path, query, body }));
    });
  }

  async mcp(req) {
    if (req.method === "GET") return new Response("POST JSON-RPC here", { status: 405 });
    if (req.method !== "POST") return new Response(null, { status: 405 });
    let msg;
    try { msg = await req.json(); } catch { return rpcError(null, -32700, "parse error"); }
    const batch = Array.isArray(msg) ? msg : [msg];
    const out = [];
    for (const m of batch) {
      const r = await this.handle(m);
      if (r) out.push(r);
    }
    if (!out.length) return new Response(null, { status: 202 });
    return Response.json(Array.isArray(msg) ? out : out[0]);
  }

  async handle(m) {
    const { id, method, params } = m;
    if (id === undefined) return null; // notification
    switch (method) {
      case "initialize":
        return { jsonrpc: "2.0", id, result: {
          protocolVersion: params?.protocolVersion || "2025-03-26",
          capabilities: { tools: {} },
          serverInfo: { name: "awieffect", version: "1.0" },
          instructions: "Edits the AWIeffect project open on the user's iPhone. Read get_catalog and get_project first, change the JSON, set_project, then render_frame to check.",
        } };
      case "ping": return { jsonrpc: "2.0", id, result: {} };
      case "tools/list":
        return { jsonrpc: "2.0", id, result: { tools: TOOLS.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })) } };
      case "tools/call": {
        const tool = TOOLS.find((t) => t.name === params?.name);
        if (!tool) return { jsonrpc: "2.0", id, error: { code: -32602, message: "unknown tool" } };
        const res = await this.ask(...tool.call(params.arguments || {}));
        if (!res) return toolText(id, "The phone isn't connected. Open AWIeffect, open a project, and turn on Settings → Connect to Claude.", true);
        if (tool.image && res.status === 200) {
          return { jsonrpc: "2.0", id, result: { content: [{ type: "image", data: res.body, mimeType: "image/png" }] } };
        }
        let text = "";
        try { text = decodeURIComponent(escape(atob(res.body || ""))); } catch { text = atob(res.body || ""); }
        return toolText(id, text, res.status >= 400);
      }
      default:
        return { jsonrpc: "2.0", id, error: { code: -32601, message: "method not found" } };
    }
  }
}

function toolText(id, text, isError = false) {
  return { jsonrpc: "2.0", id, result: { content: [{ type: "text", text }], isError } };
}

function rpcError(id, code, message) {
  return Response.json({ jsonrpc: "2.0", id, error: { code, message } }, { status: 400 });
}
