import { EDITOR_SKILL, findEditorGuide } from "./editor-skill.js";

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
    else if (url.pathname.startsWith("/u/")) {
      // Upload address: /u/<durable object id>/<secret> (handed out by the get_upload_url tool).
      const doid = url.pathname.split("/")[2] || "";
      if (!/^[0-9a-f]{64}$/.test(doid)) return new Response("bad upload address", { status: 401 });
      return env.LINK.get(env.LINK.idFromString(doid)).fetch(req);
    }
    else if (url.pathname === "/") return new Response("AWIeffect relay is running.", { status: 200 });
    else return new Response("not found", { status: 404 });
    if (!/^[0-9a-f]{32,128}$/.test(key)) return new Response("missing or bad key", { status: 401 });
    const stub = env.LINK.get(env.LINK.idFromName(key));
    return stub.fetch(req);
  },
};

const TOOLS = [
  { name: "get_upload_url", description: "Your permanent upload address for this phone (reusable for any number of files, no setup). Send a file's raw bytes with an HTTP PUT or POST to it, adding ?ext=png|jpg|mp4|mov|mp3...; the answer is {\"file\": name} to use in add_layer (type image / video, file). Any size up to 100 MB.",
    inputSchema: { type: "object", properties: {} }, local: "uploadURL" },
  { name: "upload_from_url", description: "Download an image / video / audio file from a public URL straight into the project's media. Returns {\"file\": name} for add_layer.",
    inputSchema: { type: "object", properties: { url: { type: "string" }, ext: { type: "string", description: "file extension if the URL has none" } }, required: ["url"] }, local: "fromURL" },
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
  { name: "list_projects", description: "All projects on the phone (id, name, size, fps, which one is open).",
    inputSchema: { type: "object", properties: {} }, call: () => ["GET", "/projects"] },
  { name: "create_project", description: "Create a new project and open it. width/height in px (default 1080x1920), fps (default 30), background '#RRGGBB'.",
    inputSchema: { type: "object", properties: { name: { type: "string" }, width: { type: "integer" }, height: { type: "integer" }, fps: { type: "number" }, background: { type: "string" } } },
    call: (a) => ["POST", "/projects/create", {}, JSON.stringify(a)] },
  { name: "open_project", description: "Open a project by id (from list_projects).",
    inputSchema: { type: "object", properties: { id: { type: "string" } }, required: ["id"] }, call: (a) => ["POST", "/projects/open", {}, JSON.stringify(a)] },
  { name: "duplicate_project", description: "Copy a project (by id).",
    inputSchema: { type: "object", properties: { id: { type: "string" } }, required: ["id"] }, call: (a) => ["POST", "/projects/duplicate", {}, JSON.stringify(a)] },
  { name: "add_layer", description: "Add a layer: type text|shape|solid|adjustment|null|camera|light|particles|image|video. Extra fields like edit_layer's set (e.g. text, shape: rectangle|ellipse|polygon|star, file from upload_media, position, scale, fill). Returns its id.",
    inputSchema: { type: "object", properties: { type: { type: "string" }, text: { type: "string" }, shape: { type: "string" }, file: { type: "string" }, set: { type: "object", description: "same as edit_layer's set (position, size, fill, font, inPoint...)" } }, required: ["type"], additionalProperties: true },
    call: (a) => ["POST", "/layers/add", {}, JSON.stringify(a)] },
  { name: "edit_layer", description: "Change a layer. set: {position:[x,y], scale:[x,y] or number, rotation, opacity, anchor:[x,y], positionZ, rotationX, rotationY, fill:'#RRGGBB' or [r,g,b,a 0-1], size:[w,h], name, inPoint, outPoint, speed, blend, is3D, visible, motionBlur, clip (clip to the layer below), parent:id|null, text, font (a library family like Unbounded, Orbitron, Monoton, Syne, Bungee, Michroma, DotGothic16, Rubik Glitch, Zen Dots: downloads automatically; or a PostScript name), fontSize, tracking}. time = seconds; keyframe:true adds keyframes at that time (otherwise it sets the value, keying only if already animated).",
    inputSchema: { type: "object", properties: { id: { type: "string" }, set: { type: "object" }, time: { type: "number" }, keyframe: { type: "boolean" } }, required: ["id", "set"] },
    call: (a) => ["POST", "/layers/edit", {}, JSON.stringify(a)] },
  { name: "delete_layer", description: "Delete a layer.", inputSchema: { type: "object", properties: { id: { type: "string" } }, required: ["id"] },
    call: (a) => ["POST", "/layers/delete", {}, JSON.stringify(a)] },
  { name: "duplicate_layer", description: "Duplicate a layer; returns the copy's id.", inputSchema: { type: "object", properties: { id: { type: "string" } }, required: ["id"] },
    call: (a) => ["POST", "/layers/duplicate", {}, JSON.stringify(a)] },
  { name: "reorder_layer", description: "Move a layer to index (0 = top).", inputSchema: { type: "object", properties: { id: { type: "string" }, index: { type: "integer" } }, required: ["id", "index"] },
    call: (a) => ["POST", "/layers/reorder", {}, JSON.stringify(a)] },
  { name: "split_layer", description: "Split a clip at time (seconds).", inputSchema: { type: "object", properties: { id: { type: "string" }, time: { type: "number" } }, required: ["id", "time"] },
    call: (a) => ["POST", "/layers/split", {}, JSON.stringify(a)] },
  { name: "add_effect", description: "Add an effect (type = effect id from get_catalog) to a layer, optionally with params {settingId: value}. time + keyframe:true keys them. Returns the effect id.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, type: { type: "string" }, params: { type: "object" }, time: { type: "number" }, keyframe: { type: "boolean" } }, required: ["layer", "type"] },
    call: (a) => ["POST", "/effects/add", {}, JSON.stringify(a)] },
  { name: "set_effect", description: "Change an effect's settings {settingId: value}; time + keyframe:true adds keyframes.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, effect: { type: "string" }, params: { type: "object" }, time: { type: "number" }, keyframe: { type: "boolean" } }, required: ["layer", "effect", "params"] },
    call: (a) => ["POST", "/effects/set", {}, JSON.stringify(a)] },
  { name: "remove_effect", description: "Remove an effect from a layer.", inputSchema: { type: "object", properties: { layer: { type: "string" }, effect: { type: "string" } }, required: ["layer", "effect"] },
    call: (a) => ["POST", "/effects/remove", {}, JSON.stringify(a)] },
  { name: "apply_preset", description: "duration (seconds, text animations only, default 1) sets how long it takes. Apply a preset to a layer: kind text (text animation id), title (title style id) or layer (layer preset id) — ids from get_catalog. time = where it starts.",
    inputSchema: { type: "object", properties: { duration: { type: "number" },  layer: { type: "string" }, kind: { type: "string" }, id: { type: "string" }, time: { type: "number" } }, required: ["layer", "kind", "id"] },
    call: (a) => ["POST", "/presets/apply", {}, JSON.stringify(a)] },
  { name: "set_easing", description: "Shape a keyframed property's motion: property position|scale|rotation|opacity|anchor|positionZ|rotationX|rotationY; curve = bounceOut, elasticOut, backOut, expoOut, sineInOut, cubicInOut… or easy|linear|hold|snap|velocity. segment = keyframe index (omit for all).",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, property: { type: "string" }, curve: { type: "string" }, segment: { type: "integer" } }, required: ["layer", "property", "curve"] },
    call: (a) => ["POST", "/ease", {}, JSON.stringify(a)] },
  { name: "render_sheet", description: "Contact sheet of frames to check motion. Whole clip by default; with start/end (seconds) it's a dense strip over that range (like scrubbing: e.g. start 0.8, end 1.3, count 30 = every frame). Labels show time and frame number. count up to 36.",
    inputSchema: { type: "object", properties: { count: { type: "integer" }, size: { type: "number" }, start: { type: "number" }, end: { type: "number" } } },
    call: (a) => ["POST", "/render/sheet", Object.fromEntries(Object.entries({ count: a.count, size: a.size, start: a.start, end: a.end }).filter(([, v]) => v != null).map(([k, v]) => [k, String(v)])), "", ], image: true },
  { name: "run_action", description: "Run an app action: undo, redo, seek {time}, select {layer}, play, pause, cutoutSubject {layer, mode}, detectBeats {layer?, sensitivity?} (auto beat -> markers list), markers (read beat markers), precompose {layers?: [ids], name?} (groups layers, or all, into one pre-comp).",
    inputSchema: { type: "object", properties: { name: { type: "string" } }, required: ["name"], additionalProperties: true },
    call: (a) => ["POST", "/action", {}, JSON.stringify(a)] },
];


/** One semantic tool; older 30+ native commands remain callable through "call".
 * We deliberately DO NOT support arbitrary paths, private Settings or key management. */
const UNIFIED_TOOL = {
  name: "use_awieffect",
  description: "Full native AWIeffect iPhone editing controller. One tool for layers, effects, masks, shapes, timelines, groups/precomps, rig/bones, weights, cutouts and rendering. FIRST call action='guide', topic='core' and the task-specific topic. Then action='discover' for supported native commands, action='call' with a command + args, or action='batch' for sequential edits. No AI coloring or generative-graphics shortcuts. Settings/keys are private.",
  inputSchema: { type: "object", properties: {
    action: { type: "string", enum: ["guide","discover","call","batch","status"],
              description: "guide=skill instruction, discover=commands, call=one native operation, batch=ordered native operations" },
    topic: { type: "string", description: "Skill index topic: core, rig, mask_cutout, animation, effects, manga, typography, audio, qa, all; can also search text" },
    command: { type: "string", description: "A command listed by discover (e.g. rig.add_bone, rig.paint_weights, patch_layer, add_effect, render_frame)" },
    args: { type: "object", description: "Arguments for the selected command; see discover or the native capability output" },
    steps: { type: "array", maxItems: 30, items: { type: "object", properties: {
      command: { type: "string" }, args: { type: "object" }
    }, required: ["command"] } },
    stopOnError: { type: "boolean", default: true }
  }, required: ["action"] }
};
const ADVANCED_COMMANDS = {
  get_editor_capabilities: { method: "GET", path: "/editor/capabilities",
    description: "Supported native rig commands and layer-patch whitelist; no app Settings" },
  patch_layer: { method: "POST", path: "/editor/layer/patch",
    description: "Safely edit masks, cutouts, paths, shape contents, blend mode, group collapse and other validated layer fields; args {id,set} (one undo)" },
  rig: { method: "POST", path: "/editor/rig",
    description: "Native rig command; args {command:'inspect|add_bone|select_bone|reparent_bone|delete_bone|move_rest_joint|pose_bone|bind_mesh|unbind_mesh|paint_weights|make_chain_ik|remove_ik|set_deform_amount', ...}" }
};
const RIG_COMMANDS = ["inspect","add_bone","select_bone","reparent_bone","delete_bone",
  "move_rest_joint","pose_bone","bind_mesh","unbind_mesh","paint_weights","make_chain_ik","remove_ik","set_deform_amount"];

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
    if (url.pathname.startsWith("/u/")) return this.upload(req, url);
    return this.mcp(req);
  }

  async secret() {
    let s = await this.state.storage.get("uploadSecret");
    if (!s) { s = [...crypto.getRandomValues(new Uint8Array(24))].map((b) => b.toString(16).padStart(2, "0")).join(""); await this.state.storage.put("uploadSecret", s); }
    return s;
  }

  async upload(req, url) {
    if (req.method !== "PUT" && req.method !== "POST") return new Response("PUT or POST the file bytes", { status: 405 });
    if (url.pathname.split("/")[3] !== await this.secret()) return new Response("bad upload address", { status: 401 });
    const bytes = new Uint8Array(await req.arrayBuffer());
    const ext = (url.searchParams.get("ext") || "bin").replace(/[^a-z0-9]/gi, "").toLowerCase();
    const r = await this.sendFile(bytes, ext);
    return new Response(r.text, { status: r.status, headers: { "content-type": "application/json" } });
  }

  /// Sends a file to the phone in pieces (socket messages stay small), the app joins them into project media.
  async sendFile(bytes, ext) {
    if (!this.phone()) return { status: 503, text: '{"error":"phone not connected: open AWIeffect with a project"}' };
    if (!bytes.length) return { status: 400, text: '{"error":"empty file"}' };
    const CH = 384 * 1024, total = Math.ceil(bytes.length / CH), up = crypto.randomUUID();
    let last = null;
    for (let i = 0; i < total; i++) {
      const part = bytes.subarray(i * CH, Math.min(bytes.length, (i + 1) * CH));
      let bin = ""; for (let k = 0; k < part.length; k += 8192) bin += String.fromCharCode(...part.subarray(k, k + 8192));
      last = await this.ask("POST", "/media/chunk", { upload: up, index: String(i), total: String(total), ext }, null, btoa(bin));
      if (!last || last.status >= 400) break;
    }
    if (!last) return { status: 503, text: '{"error":"phone disconnected"}' };
    let text = ""; try { text = atob(last.body || ""); } catch {}
    return { status: last.status, text };
  }

  async local(name, a, origin) {
    if (name === "uploadURL") {
      return { text: JSON.stringify({ url: `${origin}/u/${this.state.id.toString()}/${await this.secret()}`,
        how: "curl -X PUT --data-binary @file.mp4 \"<url>?ext=mp4\"" }) };
    }
    if (name === "fromURL") {
      let res; try { res = await fetch(a.url); } catch (e) { return { text: `{"error":"download failed"}`, error: true }; }
      if (!res.ok) return { text: `{"error":"download failed (${res.status})"}`, error: true };
      const guess = (new URL(a.url).pathname.split(".").pop() || "").toLowerCase();
      const ext = (a.ext || (guess.length <= 4 ? guess : "") || "png").replace(/[^a-z0-9]/gi, "");
      const r = await this.sendFile(new Uint8Array(await res.arrayBuffer()), ext);
      return { text: r.text, error: r.status >= 400 };
    }
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
    this.origin = new URL(req.url).origin;
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


  async runNativeCommand(name, args = {}) {
    if (!name || typeof name !== "string") return { status: 400, response: {error:"command is required"} };
    if (!args || typeof args !== "object" || Array.isArray(args)) return { status: 400, response: {error:"args must be an object"} };
    if (name === "get_upload_url") return { status: 403, response: {error:"permanent upload capability links are not exposed by the unified tool; use upload_media or upload_from_url"} };
    let native = null;
    let invocation = args;
    if (name.startsWith("rig.")) {
      const sub = name.slice(4);
      if (!RIG_COMMANDS.includes(sub)) return {status:400,response:{error:"unknown rig command",available:RIG_COMMANDS}};
      native = ADVANCED_COMMANDS.rig;
      invocation = { ...args, command: sub };
    } else if (ADVANCED_COMMANDS[name]) {
      native = ADVANCED_COMMANDS[name];
    }
    if (native) {
      const res = await this.ask(native.method, native.path, {},
        native.method === "GET" ? null : JSON.stringify(invocation));
      return this.decodeNativeResponse(res, name, false);
    }
    const legacy = TOOLS.find(t => t.name === name);
    if (!legacy) return {status:404,response:{error:"unknown command; call discover", command:name}};
    if (legacy.local) {
      const ret = await this.local(legacy.local, args, this.origin);
      let response = ret.text;
      try { response = JSON.parse(ret.text); } catch {}
      return {status: ret.error ? 400 : 200, response};
    }
    let request;
    try { request = legacy.call(args); }
    catch (error) { return {status:400,response:{error:"bad arguments",message:String(error)}}; }
    const res = await this.ask(...request);
    return this.decodeNativeResponse(res, name, !!legacy.image);
  }

  decodeNativeResponse(res, name, image) {
    if (!res) return {status:503, response:{error:"Phone not connected; open AWIeffect and a project"}};
    if (image && res.status === 200) return {status:200, image:res.body, mimeType:res.type || "image/png"};
    let text = "";
    try { text = decodeURIComponent(escape(atob(res.body || ""))); }
    catch { try { text = atob(res.body || ""); } catch { text = ""; } }
    let response = text;
    try { response = JSON.parse(text); } catch {}
    return {status:res.status, command:name, response};
  }

  async useAwieffect(id, p) {
    const action = p.action;
    if (action === "guide") return toolText(id, JSON.stringify(findEditorGuide(p.topic)), false);
    if (action === "discover") {
      const legacy = TOOLS.filter(t => t.name !== "get_upload_url")
        .map(({name,description,inputSchema}) => ({name,description,inputSchema}));
      const advanced = Object.entries(ADVANCED_COMMANDS).map(([name,v]) => ({name,description:v.description}));
      const rig = RIG_COMMANDS.map(name => ({name:"rig."+name,description:"Native Rig / Bone & Weight operation",args:"See guide topic=rig and get_editor_capabilities"}));
      const data = {oneTool:"use_awieffect", build:"Build 29 native + Build 30 unified connector",
        commands:[...advanced,...rig,...legacy], guideTopics:Object.keys(EDITOR_SKILL.topics),
        rules:EDITOR_SKILL.policy, format:{action:"call",command:"add_effect",args:{layer:"UUID",type:"from catalog"}},
        batching:"Ordered calls, not atomic; inspect each response. Full set_project remains a risky last resort."};
      return toolText(id, JSON.stringify(data));
    }
    if (action === "status") {
      const res = await this.runNativeCommand("get_info", {});
      return toolText(id, JSON.stringify(res), res.status >= 400);
    }
    if (action === "call") {
      const res = await this.runNativeCommand(p.command, p.args || {});
      if (res.image && res.status === 200) {
        return {jsonrpc:"2.0",id,result:{content:[{type:"image",data:res.image,mimeType:res.mimeType}]}};
      }
      return toolText(id, JSON.stringify(res), res.status >= 400);
    }
    if (action === "batch") {
      if (!Array.isArray(p.steps) || !p.steps.length || p.steps.length > 30) {
        return toolText(id, JSON.stringify({error:"steps must contain 1..30 commands"}), true);
      }
      const results = [];
      let failed = false;
      for (const [index,step] of p.steps.entries()) {
        const result = await this.runNativeCommand(step.command, step.args || {});
        const item = result.image
          ? {command:step.command,status:result.status,image:"Use action=call to view a rendered image"}
          : result;
        results.push({step:index+1,...item});
        if (result.status >= 400) { failed = true; if (p.stopOnError !== false) break; }
      }
      return toolText(id, JSON.stringify({ok:!failed,stepsCompleted:results.length,results}), failed);
    }
    return toolText(id, JSON.stringify({error:"Unsupported action",actions:["guide","discover","status","call","batch"]}), true);
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
          instructions: "Use the single use_awieffect tool. Start with action=guide topic=core and the relevant editing topic; inspect get_info, get_catalog and get_project before making changes. Favor native rig/mask/FX operations. Do not auto-generate manga coloring or generic shapes; only edit assets. Settings, relay keys and pairing secrets are private. Render and review the result.",
        } };
      case "ping": return { jsonrpc: "2.0", id, result: {} };
      case "tools/list":
        return { jsonrpc: "2.0", id, result: { tools: [UNIFIED_TOOL] } };
      case "tools/call": {
        if (params?.name === "use_awieffect") return this.useAwieffect(id, params.arguments || {});
        const tool = TOOLS.find((t) => t.name === params?.name);
        if (!tool) return { jsonrpc: "2.0", id, error: { code: -32602, message: "unknown tool" } };
        if (tool.local) { const o = await this.local(tool.local, params.arguments || {}, this.origin); return toolText(id, o.text, !!o.error); }
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
