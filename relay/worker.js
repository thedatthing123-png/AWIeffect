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
  { name: "get_timeline", description: "Compact read-only timeline summary: layer IDs, order, in/out points, effects, visibility, 3D flags, selection and playhead. Does not change the project.",
    inputSchema: { type: "object", properties: {} }, call: () => ["GET", "/timeline"] },
  { name: "text_animators", description: "List, add or remove native per-character AE text animators. Use patch_layer to edit their native selectors and keyframed properties.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, operation: { type: "string", enum: ["list", "add", "remove"] }, animator: { type: "string" }, name: { type: "string" } }, required: ["layer", "operation"] },
    call: a => ["POST", "/text/animators", {}, JSON.stringify(a)] },
  { name: "add_mask_path", description: "Add a native closed mask from layer-local 2D points. Supports AE modes, inversion and feather. Further changes are available through patch_layer.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, points: { type: "array", items: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2 } }, name: { type: "string" }, mode: { type: "string" }, feather: { type: "number" }, inverted: { type: "boolean" } }, required: ["layer", "points"] },
    call: a => ["POST", "/masks/path", {}, JSON.stringify(a)] },
  { name: "bake_soft_body", description: "Bake native soft-body simulation to editable Puppet Pins keyframes, with material/drop/gravity/duration. Get valid material values from project/native implementation.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, material: { type: "string" }, drop: { type: "number" }, gravity: { type: "number" }, duration: { type: "number" }, floorAtBottom: { type: "boolean" } }, required: ["layer", "material"] },
    call: a => ["POST", "/physics/soft-body", {}, JSON.stringify(a)] },
  { name: "edit_drawing_layer", description: "Manage layers within a linked Art Studio drawing using native DrawEngine. add/duplicate/delete/up/down/set supports name, opacity, blend, visibility, clipping, alpha lock.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, index: { type: "integer" }, operation: { type: "string", enum: ["add", "duplicate", "delete", "up", "down", "set"] }, name: { type: "string" }, opacity: { type: "number" }, blend: { type: "string" }, visible: { type: "boolean" }, clipping: { type: "boolean" }, alphaLock: { type: "boolean" } }, required: ["layer", "operation"] },
    call: a => ["POST", "/draw/layer", {}, JSON.stringify(a)] },
  { name: "get_capabilities", description: "Inspect native AI Link capability groups and patchable project/layer properties.",
    inputSchema: { type: "object", properties: {} }, call: () => ["GET", "/capabilities"] },
  { name: "create_group", description: "Group existing layer IDs using the native group editor.",
    inputSchema: { type: "object", properties: { layers: { type: "array", items: { type: "string" } } }, required: ["layers"] },
    call: a => ["POST", "/groups/create", {}, JSON.stringify(a)] },
  { name: "ungroup", description: "Ungroup a native group layer without deleting its children.",
    inputSchema: { type: "object", properties: { layer: { type: "string" } }, required: ["layer"] },
    call: a => ["POST", "/groups/ungroup", {}, JSON.stringify(a)] },
  { name: "create_ik_rig", description: "Create a native two-bone IK rig with upper/lower layer IDs, and optional controller. Automatically creates controller if omitted.",
    inputSchema: { type: "object", properties: { upper: { type: "string" }, lower: { type: "string" }, controller: { type: "string" } }, required: ["upper", "lower"] },
    call: a => ["POST", "/rig/ik", {}, JSON.stringify(a)] },
  { name: "remove_ik_rig", description: "Remove native IK rig from the specified lower limb layer.",
    inputSchema: { type: "object", properties: { layer: { type: "string" } }, required: ["layer"] },
    call: a => ["POST", "/rig/remove", {}, JSON.stringify(a)] },
  { name: "edit_puppet_pin", description: "Add/move/remove/starch/reset native Puppet Pins on a layer. Position is comp-space [x,y], index identifies existing pin.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, operation: { type: "string", enum: ["add", "move", "remove", "starch", "reset"] }, point: { type: "array", items: { type: "number" } }, index: { type: "integer" } }, required: ["layer", "operation", "point"] },
    call: a => ["POST", "/puppet/pin", {}, JSON.stringify(a)] },
  { name: "bake_physics", description: "Use the existing physics solver to bake editable position/rotation keyframes for selected dynamic layers; static layers act as obstacles.",
    inputSchema: { type: "object", properties: { dynamic: { type: "array", items: { type: "string" } }, static: { type: "array", items: { type: "string" } }, gravity: { type: "number" }, bounciness: { type: "number" }, friction: { type: "number" }, wind: { type: "array", items: { type: "number" } }, launch: { type: "array", items: { type: "number" } }, duration: { type: "number" }, substeps: { type: "integer" } }, required: ["dynamic"] },
    call: a => ["POST", "/physics/bake", {}, JSON.stringify(a)] },
  { name: "set_keyframe_velocity", description: "Apply existing AE-style speed and influence controls at a chosen time on all keyframed transform properties of a layer.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, time: { type: "number" }, inInfluence: { type: "number" }, inSpeed: { type: "number" }, outInfluence: { type: "number" }, outSpeed: { type: "number" } }, required: ["layer", "inInfluence", "inSpeed", "outInfluence", "outSpeed"] },
    call: a => ["POST", "/keyframes/velocity", {}, JSON.stringify(a)] },
  { name: "patch_project_settings", description: "Safely update native project settings via Codable JSON. Preserves existing layers, IDs and nested compositions. Read get_project first.",
    inputSchema: { type: "object", properties: { set: { type: "object" } }, required: ["set"] },
    call: a => ["POST", "/project/patch", {}, JSON.stringify(a)] },
  { name: "draw_strokes", description: "Paint vector-specified brush paths into the native Metal Art Studio document, creating a new drawing layer or editing an existing linked drawing. strokes:[{points:[[x,y,pressure?],...]}]. Requires app foreground.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, brush: { type: "string" }, size: { type: "number" }, opacity: { type: "number" }, color: { type: "string" }, strokes: { type: "array", items: { type: "object", properties: { points: { type: "array", items: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 3 } } }, required: ["points"] } } }, required: ["strokes"] },
    call: a => ["POST", "/draw/strokes", {}, JSON.stringify(a)] },
  { name: "add_3d_model", description: "Import an already-uploaded USDZ or OBJ model as a 3D layer (use upload_media first).",
    inputSchema: { type: "object", properties: { file: { type: "string" } }, required: ["file"] },
    call: a => ["POST", "/layers/model", {}, JSON.stringify(a)] },
  { name: "add_3d_text", description: "Create an extruded 3D text model layer using the app's native model system.",
    inputSchema: { type: "object", properties: { text: { type: "string" } }, required: ["text"] },
    call: a => ["POST", "/layers/text3d", {}, JSON.stringify(a)] },
  { name: "set_expression", description: "Set or remove an AE-style expression on a layer's keyframeable property. Omit expression to clear.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, property: { type: "string" }, expression: { type: "string" } }, required: ["layer", "property"] },
    call: a => ["POST", "/layers/expression", {}, JSON.stringify(a)] },
  { name: "set_graph_handles", description: "Set native Graph Editor easing handles on all or one segment for an animated layer property. Requires at least 2 keyframes. out/in are [x,y] pairs.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, property: { type: "string" }, out: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2 }, in: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2 }, interpolation: { type: "string" }, segment: { type: "integer" } }, required: ["layer", "property", "out", "in"] },
    call: a => ["POST", "/layers/graph", {}, JSON.stringify(a)] },
  { name: "set_time_remap", description: "Map composition seconds to media-source seconds with points [{time,source}]. Pass clear:true to remove remap.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, clear: { type: "boolean" }, points: { type: "array", items: { type: "object", properties: { time: { type: "number" }, source: { type: "number" } }, required: ["time", "source"] } } }, required: ["layer"] },
    call: a => ["POST", "/layers/remap", {}, JSON.stringify(a)] },
  { name: "open_precomp", description: "Open an existing precomposition layer for editing its child composition.",
    inputSchema: { type: "object", properties: { layer: { type: "string" } }, required: ["layer"] },
    call: a => ["POST", "/precomp/open", {}, JSON.stringify(a)] },
  { name: "close_precomp", description: "Close the current nested precomposition and apply its changes to the parent.",
    inputSchema: { type: "object", properties: {} }, call: () => ["POST", "/precomp/close", {}, "{}"] },
  { name: "patch_layer", description: "Safely patch native Codable layer fields (text animator, masks, model3D, rig, camera, light, timeFX, shapeOps, stroke etc.) via nested set JSON; preserve all other fields. Protected identity, content and parent/group IDs cannot be patched. Read get_project first.",
    inputSchema: { type: "object", properties: { layer: { type: "string" }, set: { type: "object" } }, required: ["layer", "set"] },
    call: a => ["POST", "/layers/patch", {}, JSON.stringify(a)] },
  { name: "batch_patch_layers", description: "Validate and patch up to 256 native layer JSON objects atomically (one undo step). Supports existing serialized art, rigs, text animators, masks, 3D and time effects without rewriting renderer. Read get_project first.",
    inputSchema: { type: "object", properties: { patches: { type: "array", items: { type: "object", properties: { layer: { type: "string" }, set: { type: "object" } }, required: ["layer", "set"] } } }, required: ["patches"] },
    call: a => ["POST", "/layers/batch-patch", {}, JSON.stringify(a)] },
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
