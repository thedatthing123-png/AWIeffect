// Built from the user's awieffect-editor skill ZIP (Build 29 authoring model).
// Read by use_awieffect(action:"guide", topic:"..."). No AI-generated art pipeline.
export const EDITOR_SKILL = {
  version: "build29-editor-2026-11-10",
  origin: "skill/awieffect-editor/SKILL.md and references/*.md",
  policy: [
    "You are an editing partner, not a generative image/coloring tool. Use AWIeffect's native editing operations, provided assets, masks, manually authored paths, effects and keyframes.",
    "Never create generic AI-looking geometry, random neon shapes, mirrored rings or automatic character coloring in place of an intentional composition.",
    "Begin with a concept, a single visual motif taken from the subject, a color story, a hero moment, composition hierarchy and a beat/timing map.",
    "Inspect get_info, get_catalog and get_project before destructive edits. Preserve unrelated layers and project identity; mutate minimally and keep edits undoable.",
    "Verify the static composition with render_frame and motion with render_sheet. Don't claim quality based on tool success alone.",
    "Private Settings, relay secrets, pairing keys and account details are off limits."
  ],
  topics: {
    core: {
      purpose: "Taste, style and working method",
      steps: [
        "Make a one-sentence brief and identify the one hero moment. Final frame should be intentional.",
        "Choose one motif from the source artwork or typography; use it for reveal, wipe or cut. Avoid decorative rings, slashes, random rectangles.",
        "Build rhythm using holds and accents. A first pass is rough cuts; a second pass is motion; effects and grade come later.",
        "Prefer asymmetric easing with a fast attack and long settle. Offset secondary elements by a few frames, not identically.",
        "Use real source media and manual art/path work for manga/anime; never ask an image generator to color panels.",
        "After each major pass inspect real renders and correct clipped edges, wrong stacking, stiffness and visual noise."
      ],
      native: ["get_info", "get_catalog", "get_project", "add_layer", "edit_layer", "set_easing", "render_frame", "render_sheet"]
    },
    rig: {
      purpose: "Native Rig vs Bone / Weight, branching and deformation",
      steps: [
        "Rig is for separate image pieces; Bone / Weight is for one continuous transparent image or vector artwork. Do not pretend these are the same cutout workflow.",
        "Add a main bone to the artwork, then add child bones with explicit parent IDs. To branch fingers, select wrist as the parent for EVERY new finger instead of extending the prior tip.",
        "For set-up joints use move_rest_joint in bone-parent X/Y. Pose only after rest placement. Do not write raw bone JSON when native functions exist.",
        "Bind mesh after bones are placed; choose coverage=whole for one continuous character or localized for isolated zones. Mesh detail and influence radius affect result and performance.",
        "Paint influence in small, deliberate dabs: paint, erase or smooth with explicit influence bone, brush radius and hardness. Keep weights normalized and review the heatmap.",
        "Use pose_bone and make_chain_ik for animation. Deform amount blends deformation; it is not touch sensitivity, reach or stretch. Avoid impossible/overstretched targets.",
        "With single-image limbs, inspect shoulder, elbow, wrist, fingertips and silhouette during motion; if bending collapses, adjust weights before increasing deformation."
      ],
      native: ["rig.inspect", "rig.add_bone", "rig.move_rest_joint", "rig.reparent_bone", "rig.bind_mesh", "rig.paint_weights", "rig.pose_bone", "rig.make_chain_ik", "rig.set_deform_amount"]
    },
    mask_cutout: {
      purpose: "High-precision cutouts, masks, occlusion and manga panel separation",
      steps: [
        "For an already transparent asset, preserve its alpha instead of running automatic removal.",
        "For a photo/video source, try native cutoutSubject only when requested; inspect hair, hands and feet at full frame and correct edges with native masks and refine controls.",
        "Use masks, track mattes and clip-to-below for reveals and selective effects. Key mask paths in layer-local image coordinates, checking rotation/scale, feather, inversion and blend mode.",
        "For manga art separate foreground character, midground and background using source-driven cutouts. Fill holes behind the removed foreground rather than stretching the original layer.",
        "Redraw lines manually in native Draw Studio when necessary, preserving line-weight and perspective. Never substitute AI auto-coloring or placeholder geometry.",
        "For selective glow on eyes duplicate/mask the eye region, isolate color where needed and apply a tight bright core and a wider dim halo."
      ],
      native: ["run_action cutoutSubject", "patch_layer masks/cutout/trackMatte/clipToBelow", "add_effect", "set_effect", "draw_strokes if supported by live app"]
    },
    animation: {
      purpose: "Motion, graph easing, expressions, transitions and typography",
      steps: [
        "For a beat-locked edit compute frames per beat = fps * 60 / BPM; place exact hit frames, vary holds by phrases.",
        "Animate native transform, opacity, camera and graph values with keyframes and meaningful segment easing; smooth velocity ramps instead of uniform travel.",
        "Use Bend, Wave or other native effects by looking up exact effect IDs and parameter ranges in get_catalog first; never invent angles, IDs or sliders.",
        "For natural motion, stagger secondary keys 2-4 frames and allow 4-8 frames for trailing settles. Match animation to character anatomy and movement direction.",
        "Verify movement by dense render_sheet strips (e.g. 0.8..1.3 seconds across 20-30 frames); check velocity spacing and smears, not only first/last frame.",
        "AE-like text animators should use readable timing and ramps. Don't drown readable text behind overlapping effects."
      ],
      native: ["edit_layer", "set_easing", "add_effect", "set_effect", "render_sheet", "run_action seek/play/pause"]
    },
    effects: {
      purpose: "Effect stacks, color, depth, glow and compositing",
      steps: [
        "Fetch get_catalog for current effect IDs and exact numerical ranges. Build effects on a targeted layer; order matters.",
        "Color correct first. Then establish an intentional look, usually on an adjustment layer. Preserve manga blacks and whites when a monochrome look is intended.",
        "Deep glow: isolate actual emitting pixels, use a narrow luminous core and a broad low-intensity halo; do not glow the entire frame by default.",
        "Impact: brief flash (often 1-4 frames), zoom punch, short shake with decay and motion blur. Keep clear frames between hits.",
        "Chroma key only when source genuinely contains green/blue or a color isolation request. Inspect edges and adjust screen balance intentionally.",
        "For depth parallax, animate real separated source layers in coherent perspective; ensure foreground/midground/background occlude properly.",
        "Review before/after toggles and renders. Presets are starting points, not final grading."
      ],
      native: ["get_catalog", "add_effect", "set_effect", "remove_effect", "add_layer", "edit_layer", "render_frame"]
    },
    manga: {
      purpose: "Manga redraw, character motion and reference-led style",
      steps: [
        "Work from provided panels, linework and character cutouts. Do not generate/color characters using AI. Preserve original ink style and negative space.",
        "Split a panel into meaningful planes using precise native masks or cutouts: body, front hair, back hair, hand, foreground debris, background.",
        "Paint missing background manually on native drawing layers if a lifted character reveals holes. Do not stretch pixels as an automatic shortcut.",
        "For motion in a still panel use discreet parallax, anatomical bone bends, hair/cloth wave, masked reveals and correct depth stacking.",
        "When a style is named (Haiko, haikoxpp, Gokuponch, etc.), analyze supplied frame references rather than claiming exact creator-specific parameters.",
        "One intentional accent color on monochrome artwork is often stronger than uniform rainbow effects; only color requested regions from supplied assets.",
        "Check edges in closeups and wide frames, particularly at joints, eyes, hands and masks."
      ],
      native: ["patch_layer masks", "rig", "add_effect", "set_effect", "render_frame", "render_sheet"]
    },
    typography: {
      purpose: "Readable kinetic text, watermarks and reveal design",
      steps: [
        "Design the final resolved frame first, then create a reveal using a subject-derived mask, stroke or slide.",
        "Short titles should remain readable; use one loud typeface plus a quieter secondary face, not many equal voices.",
        "Use per-letter native text animator capabilities if present; shape selector ramps and stagger characters thoughtfully.",
        "Avoid default bounce on every word; hit one hero syllable on beat, then settle other text unobtrusively.",
        "Preview on actual phone dimensions and check title-safe margins."
      ],
      native: ["add_layer text", "edit_layer", "add_effect", "apply_preset", "render_sheet"]
    },
    audio: {
      purpose: "Beat maps and edit pacing",
      steps: [
        "Use user-provided music or native detectBeats markers; a supplied WAV/MP3 can be analyzed offline with the bundled analyze_audio.py script.",
        "Map downbeats, snares, vocal accents and sections before building effects. Cuts on phrases, accents on transient beats.",
        "Use fewer effects in the intro, increasing energy toward the drop; break releases the pressure.",
        "Auto beat markers are suggestions, verify by listening; map BPM to frames at actual project fps.",
        "Don't claim the app's connected MCP itself can hear or analyze raw audio unless that native feature is confirmed."
      ],
      native: ["run_action detectBeats", "run_action markers", "edit_layer", "render_sheet"]
    },
    qa: {
      purpose: "Editing QA and connector safety",
      steps: [
        "Read get_info, get_project and get_catalog. Verify selected layers, IDs, timeline duration and effect params first.",
        "Prefer native target operations to full set_project; if full rewrite is unavoidable preserve IDs, media links, keys, and unrelated composition data.",
        "Perform small edits, render_frame to inspect and render_sheet to check motion, then iterate.",
        "Use undo to recover if output looks wrong. Never modify Settings, pairing code, relay URL or secret key.",
        "Do not claim a Cloudflare deployment, IPA build or mobile testing occurred without external confirmation."
      ],
      native: ["get_info", "get_catalog", "get_project", "render_frame", "render_sheet", "run_action undo"]
    }
  }
};

export function findEditorGuide(topic) {
  const key = (topic || "core").toLowerCase().trim();
  if (key === "all" || key === "index") {
    return { version: EDITOR_SKILL.version, source: EDITOR_SKILL.origin, policy: EDITOR_SKILL.policy,
      topics: Object.fromEntries(Object.entries(EDITOR_SKILL.topics).map(([k, v]) => [k, v.purpose])) };
  }
  if (EDITOR_SKILL.topics[key]) {
    return { version: EDITOR_SKILL.version, policy: EDITOR_SKILL.policy, topic: key, ...EDITOR_SKILL.topics[key] };
  }
  const matches = Object.entries(EDITOR_SKILL.topics)
    .filter(([k,v]) => (k + " " + v.purpose + " " + v.steps.join(" ")).toLowerCase().includes(key))
    .map(([k,v]) => ({ topic: k, purpose: v.purpose }));
  return { topic: key, matches, available: Object.keys(EDITOR_SKILL.topics) };
}


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
