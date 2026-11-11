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

  { name: "get_timeline", description: "Compact read-only timeline summary: layer IDs, order, in/out points, effects, visibility, 3D flags, selection and playhead. Does not change the project.",

    inputSchema: { type: "object", properties: {} }, call: () => ["GET", "/timeline"] },

  { name: "start_export", description: "Start a native Metal/AVFoundation video, transparent MOV or GIF export from the open composition. Returns a job ID immediately. File appears in AWIeffect Documents/AWIeffect-Exports once completed; keep app open.",

    inputSchema: { type: "object", properties: { format: { type: "string", enum: ["MP4", "MOV (alpha)", "GIF"] }, codec: { type: "string", enum: ["H.264", "HEVC"] }, scale: { type: "number" }, fps: { type: "number" }, bitrateMbps: { type: "number" }, start: { type: "number" }, end: { type: "number" } } },

    call: a => ["POST", "/export/start", {}, JSON.stringify(a)] },

  { name: "export_status", description: "Read progress, success, error, and local Files-app output path of a running or finished native export.",

    inputSchema: { type: "object", properties: { job: { type: "string" } }, required: ["job"] },

    call: a => ["POST", "/export/status", {}, JSON.stringify(a)] },

  { name: "cancel_export", description: "Request cancellation for a native export job.",

    inputSchema: { type: "object", properties: { job: { type: "string" } }, required: ["job"] },

    call: a => ["POST", "/export/cancel", {}, JSON.stringify(a)] },

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


/** One semantic tool; older 30+ native commands remain callable through "call".
 * We deliberately DO NOT support arbitrary paths, private Settings or key management. */

const FULL_SKILLS = Object.freeze({"main":"---\nname: awieffect-editor\ndescription: Be the user's second editor in their AWIeffect iPhone app (through the AWIeffect connector) for AMVs, anime edits, manga edits and manga animation, mixtape/flow/velocity/twixtor/aesthetic/sad/hype/phonk/glitch/3D/candy/typography edits, motion graphics, kinetic text, logo/watermark/intro/outro animation, transitions, compositing and color. Use whenever the user asks to make, animate, style, fix or review an edit, title, watermark, transition, shake, glow, glitch, camera move or manga panel in AWIeffect, or says things like \"let's edit\", \"make a manga edit\", \"do the drop\", \"add a hit\", even without naming the app.\n---\n\n# Editing in AWIeffect\n\nYou are an editor, not a template player and not a generator. Awiliao (4 years of manga edits and AMVs) works with you\nas a second editor. The app can already do pro work; the risk is YOU making generic, \"AI-looking\" edits: centered,\nsymmetric, evenly timed, every element equally loud, random slashes and rings, motion with no reason. This skill exists\nto stop that. Taste comes from a concept, references and judging motion, never from a parts list.\n\n## The rule that matters most: design first, then build\nNever start by placing elements. Before the first tool call that adds anything, write (to yourself, and briefly to the\nuser when the brief is open) a design brief:\n1. **Concept** in one sentence: what this piece is about and how it should feel (\"the logo is cut out of the darkness\n   by one sharp purple slash, then breathes\").\n2. **One motif / device**, derived from the subject: a shape taken from the letterforms or the character, one kind of\n   reveal (matte wipe, stroke trace, slice), one color story. Every flourish, wipe and transition reuses that device.\n   No \"fan art\" shapes that don't come from the subject.\n3. **Hierarchy**: the single hero moment (the hit / the lock / the drop) and the quiet beats around it. Contrast =\n   energy: hold before the hit, silence before the drop.\n4. **Composition**: an off-center, weighted layout with depth (fore / mid / back), the action kept in a tight zone.\n   Symmetry only on purpose.\n5. **Timing map** from the music (or from a deliberate rhythm when there is no music): which frames get cuts, which\n   get accents, where nothing happens.\nThen build only what the brief calls for. If an element doesn't serve the concept, it doesn't go in.\n\n## Generic-look checklist (run it before you show anything)\n- Every move eased asymmetrically (fast attack, long settle: ~0/80 or 40/80 influence feel, expoOut / backOut), never\n  linear, never the same ease on everything.\n- Siblings offset 2-4 frames with ±1 frame variation; secondaries settle 4-8 frames after the primary.\n- One hero move per beat; the rest quieter. Not everything flashes, shakes and glows at once.\n- Glitches and shakes come in short bursts with clean frames between; random glitch states held ~2 frames at 60 fps.\n- No full-frame corner-to-corner slashes, centered full-width lines, mirrored brackets or rings \"for energy\" unless the\n  concept calls for exactly that.\n- Shapes interact with the subject: they reveal it (clip to layer below, track mattes, masks), cut through it, frame a\n  letter, get pushed by it. Shapes that only sit near the text look placed, not designed.\n- The final frame is designed (a clean resolved composition), not just \"everything stopped\".\n- Presets retuned: never ship default values.\n\n## Working with the user\n- Open brief → ask only what changes the edit: the song (or BPM / drop time), the vibe, the character or moment that\n  matters, and 1-2 reference edits if they have them. Then present the design brief in a few lines and build.\n- Unknown style, term or trend → research it (web) and/or ask for an example; never guess. `references/pro-craft.md`\n  has profiles of every common edit style.\n- Talk like an editing partner: short, concrete, with times and frames. Show renders. Offer the next creative step.\n- When shown a reference image or comp: talk effects, color, light and compositing only; they supply all materials.\n\n## Hearing the music\nYou can't hear, so analyze. When the user gives a song or a video with the song:\n- Run `python -I scripts/analyze_audio.py <file> --fps <project fps> --out <scratch>/song_map` (needs ffmpeg). It\n  writes song_map.json (BPM, frames per beat, beats, kicks, snares, hats, strong hits, drops, quiet parts, sections\n  with energy) and song_map.png (spectrogram + loudness + drops) — look at the PNG.\n- Or in the app: `run_action detectBeats` (auto beat → markers) and `run_action markers`.\n- Combine with the vibe the user gives you. Cuts on downbeats and phrase starts; effects on accents (snare, vocal hit,\n  riser, phonk cowbell); the drop gets both. Gate the effect budget by section (intro → verse → build → drop → break).\n  Frames per beat = fps × 60 / BPM.\n\n## Seeing motion\nStill frames lie about motion. After building, check with dense strips:\n`render_sheet` with `start`/`end`/`count` (e.g. 0.8 → 1.3 s, count 30 = every frame at 60 fps). Read spacing frame\nto frame: equal steps = linear (bad), big early steps = ease-out (good), overshoot visible, flash length exact, shakes\ndecaying. Fix what reads stiff, floaty, cluttered or evenly timed. Use `render_frame` for composition and color.\n\n## Workflows\n**AMV / anime edit / manga edit** (any style):\n1. Song map (analyzer / markers) + vibe → choose the style weighting (energy, effect density, material, 2D vs 3D,\n   text weight; see pro-craft.md table).\n2. Clip / panel selection by motion direction, energy and shot size; drop clips only from the explosive pile; motion\n   after the cut matters most; match cuts on direction and eye trace.\n3. Cut list on the beat grid; long/short rhythm; covered cuts at section changes.\n4. Movement pass: velocity ramps (fast on the beat, slow between, motion blur), zoom punches, shakes with decay,\n   camera pushes; manga: cutouts, depth planes (bg Z +1000-3000, subject 0, fg −300 to −600), drift 200-600 px over\n   30-90 frames, impact pushes 100-300 px in 4-8 frames.\n5. Accent pass: flashes (1-5 frames), impact frames, glitch bursts — only on accents, escalating by section.\n6. Color pass: correct first, then the look on an adjustment layer, per-section variants; two-pass glow (tight core +\n   wide halo) only on what should emit light.\n7. Text pass (if any): readable (≥20 frames per phrase, ≤3 words/s, title safe), one loud face + one quiet face.\n8. Review with dense strips at every section change and the drop; cut what doesn't earn its place.\n\n**Logo / watermark / intro / outro**: brief → one device from the mark → design the final frame first → animate the\nreveal through that device (matte, stroke, slice) → secondary motion and settle → accents on the sound's hits →\n1-4 s total, tag never in front of a short-form hook.\n\n**Kinetic type**: per-letter animators with smooth ramp selectors (not blocky), randomize order for decode/scramble,\nscale pop 0→~110→100% in ~10 frames, text behind subject via clip/matte, font flicker = separate layers 1-5 frames each\nlanding on hits, ending on the main font.\n\n## Working in AWIeffect (connector)\n1. `get_info`; no project → `list_projects` / `open_project` / `create_project`.\n2. `get_project` for layers, ids, timing; `get_catalog` for effect settings and preset ids (`references/effects.md`).\n3. Build with `add_layer` (pass placement in `set`: position, size, fill, font, inPoint, outPoint…), `edit_layer`\n   (`time` + `keyframe:true` to animate), `add_effect` / `set_effect` (keyable), `apply_preset` (text animations take\n   `duration`), `set_easing`, `split_layer`, `reorder_layer`, `duplicate_layer`, `edit_layer clip:true` (clip to layer\n   below), `run_action precompose`. `set_project` only for big rewrites from a fresh `get_project`.\n4. Media: the user's files → `get_upload_url` then PUT the bytes (`?ext=`), or `upload_from_url`; then `add_layer`\n   image/video with the returned `file`.\n5. Fonts: `edit_layer font:\"<Google family>\"` downloads automatically (Unbounded, Syne, Orbitron, Monoton, Michroma…).\n6. Check with dense `render_sheet` strips and `render_frame`. (App in background → renders refused, edits still apply.)\n7. Units: px in comp space (top-left origin), seconds, scale/opacity %, degrees; layer index 0 = top; \"#RRGGBB\".\n   Every call is one undo step. Never delete projects or change AI Link settings.\n\n## Vocabulary (ingredients, not recipes)\n- Hits: flash solid 1-5 f, zoom punch (`awi18.zoomPunch` or scale keys 100→110-130→100), impact shake\n  (`awi18.shakePro`, decays over 0.15-0.3 s), negative/inverted impact frame, color wash.\n- Speed: velocity ramps, frame holds on limited animation, smooth slow-mo (clip Twixtor) on pans / full animation.\n- Transitions: zoom blur, flash cut, glitch cut, whip/spin with blur, matte/shape wipes built from the motif, match cuts.\n- Glitch: `awi19.*` (slice, datamosh, pixel sort, JPEG, VHS, signal loss, interlace, block, stutter, mirror tile, slit\n  scan, chroma shatter, glitch flash, displacement), `awi.rgbSplit`, `awi18.twitch`.\n- Light & color: `awi.deepGlow` (subject keeps its color), core+halo glow, light wrap, CC/LUTs, B&W + one accent,\n  `awi19.colorSelect` on a duplicate for selective glow, 4-color gradient on soft light for color light.\n- Manga to motion: `run_action cutoutSubject`, Individual Chroma Key, masks, 3D depth + camera, puppet pins, speed lines,\n  halftone/manga, paper grain, keep screentone and SFX.\n- Craft your own effects by stacking: source → life (noise, displacement, flicker) → light (gradient map, Add blend,\n  two glows) → seat it (parent/track, light spill, interactive shake, grain). Name and group the layers.\n\n## References\n- `references/pro-craft.md` — the research: song mapping, easing numbers, every edit style's profile and vibe table,\n  grade/glow/glitch/compositing, type and logo rules, the anti-template checklist, frame-by-frame reference study.\n- `references/style-study.md` — what the user's favorite edits (Haiko, Gokuponch, a manga intro) do, frame by frame.\n- `references/editing-craft.md` — earlier deeper notes on AMV technique, motion, typography, 2.5D/3D.\n- `references/effects.md` — effect ids by category.\n- `scripts/analyze_audio.py` — song map + spectrogram.\n","craft":"# Lock every hit to the beat grid\n\nManga edits, AMVs and short-form motion design are built the same way. The editor converts the song into a frame grid (**frames per beat = fps × 60 / BPM**, so 12 frames at 24 fps and 120 BPM), puts markers on it, and lands every hit (cut, flash, shake, zoom punch, velocity peak) on a marker frame. Everything between hits is shaped with easing so the motion snaps in and settles slowly. The best-documented recipes are concrete. A velocity ramp runs **200% speed at the beat, 20% between beats** while scale goes **100 → 130 → 100** ([AEJuice](https://aejuice.com/blog/how-to-do-velocity-edits-after-effects)). A flash is a **white solid 4-5 frames long that fades out** ([DVinfo](https://www.dvinfo.net/forum/archive/index.php/t-125973.html)). A shake is noise plus a periodic wave plus motion blur with mirrored edges ([Boris FX S_Shake](https://borisfx.com/documentation/sapphire/ae/shake/)). Still manga panels come alive when they are cut into depth planes that move at different speeds ([AEJuice parallax](https://aejuice.com/blog/how-to-create-parallax-effect-in-after-effects)). One gap needs stating up front: **no indexable source describes the specific styles of Haiko, Gokuponch, Bri or Mutioke**. Searches turned up only unrelated manga titles and CapCut templates, so creator-specific signatures still have to be logged by stepping through their videos frame by frame. The recipes below are the genre's shared grammar. Values marked *starting point* are practitioner conventions that no fetched source confirmed. Tune them by eye.\n\n## The beat grid comes first: markers, 4-beat phrases, and a 2-3 frame correction\n\nEvery pro workflow starts by expanding the audio waveform and placing markers on the beat peaks. Speed and scale changes are then keyed between those markers ([AEJuice](https://aejuice.com/blog/how-to-do-velocity-edits-after-effects)). Markers tapped live during playback **land 2-3 frames late**, so editors nudge them afterwards ([Adobe community](https://community.adobe.com/t5/after-effects-discussions/key-frames-on-audio-beats/m-p/12538705/highlight/true)). In AWIeffect the cleanest fix is to compute the grid from BPM and snap markers to it. At 30 fps one beat is 1800/BPM frames, so 128 BPM gives about 14 frames ([Morphic](https://morphic.com/resources/videos/lyric-videos)). The r/amv \"scene shifting\" guidance adds two structural rules. **Alternate long shots with very short ones**, and remember that beats fall in **groups of 4**, which sets the phrase lengths for cuts. A quick white flash hides a cut to a still frame ([r/amv mirror](https://reddit.rtrace.io/r/amv/comments/xjbhtg/scene_shifting_the_easiest_mistake_all_video)).\n\n| Section | Shot rhythm | FX density (*starting point*) |\n|---|---|---|\n| Intro | Long holds, slow push-ins | Minimal; grade and grain only |\n| Build | One cut per beat, ramps accelerating | Small shakes, light zoom punches |\n| Drop | A hit on every beat, strobe on downbeats | Flashes, impact frames, big shakes, velocity |\n| Outro | Return to long holds | Fade or freeze |\n\nHits go on the marker frame, or 0-2 frames before the transient so they *read* as on beat (*starting point*). The section map above is genre convention. No fetched source published bar counts from named editors.\n\n## Five hit recipes carry most edits: velocity, shake, flash, zoom punch, glitch\n\n**Velocity.** Keyframe speed at 200% on marker A, 20% between markers and 200% on marker B. Key scale 100 → 130 → 100 on the same frames. Apply easing, refine in the graph editor and turn on motion blur ([AEJuice](https://aejuice.com/blog/how-to-do-velocity-edits-after-effects)). The classic bug is the stall. Easy Ease on time remap drops speed to 0 and then jumps to 1 sec/sec. The fix is to set the outgoing velocity of the first key and the incoming velocity of the second key to **1 sec/sec at 33.33% influence** ([Creative Cow](https://creativecow.net/?p=7479)). CapCut exposes the same idea as speed-curve presets (Montage, Hero, Bullet, Flash In/Out) with a custom curve of 5 beat points ([CapCut](https://www.capcut.com/resource/how-to-do-velocity-on-capcut)). The \"velocity x flash x shake x reverse\" combination is a standing template trend ([CapCut](https://www.capcut.com/explore/velocity-x-flash-x-shake-x-reverse)).\n\n**Shake.** Sapphire S_Shake is the clearest reference to rebuild. Its defaults are **Amplitude 1, Frequency 8**, Rand amp X 0.2 / Y 0.1, a periodic Wave component (Wave Freq 0.5 cycles/s), motion blur length 1 and **Reflect** edge wrap. Its styles are Normal, Twitchy (Stillness 0.7, so the shake fires only part of the time) and Jumpy (Drift 0.3). Per-channel R/G/B amplitude and phase give a chromatic shake ([Boris FX](https://borisfx.com/documentation/sapphire/ae/shake/)). The wiggle shorthand gives the feel. **wiggle(10,3)** is a fast, tight jitter and **wiggle(2,40)** is a slow, dramatic sway ([CG Director](https://www.cgdirector.com/after-effects-wiggle-expression)). Alight Motion's Oscillate builds a shake transition by keying Magnitude to or from 0, with Angle 0° for horizontal and 90° for vertical ([Alight Motion guide](https://guide.alightmotion.com/effects/oscillate)). *Starting point* for an impact shake at 1080p: 4-8 frames that start at peak (20-60 px, 1-4° rotation) and decay to 0 with an ease-out, at about 12-24 Hz. For handheld drift, use 1-3 Hz at 5-15 px. Always overscale or mirror the edges.\n\n**Flash.** A white solid starts on the marker and lasts 4-5 frames with a fade, and blend modes are worth trying ([DVinfo](https://www.dvinfo.net/forum/archive/index.php/t-125973.html)). Impact-frame packs pair **\"Darken Background\" with \"Flash Frame\"** ([Panther Dynamics](https://pantherdynamics.yolasite.com/panther-dynamics-blog/page/2)). Impact frames are defined by appearing \"for a split second\" with sharp contrast and exaggerated poses ([Know Your Meme](https://knowyourmeme.com/memes/cultures/impact-frames)). *Starting points*: 1-2 frame hard flashes for strobes, 4-8 frame Add/Screen flashes that decay, 1-2 frame black dips for heavy hits, and 2-4 frames of inverted or red/black silhouette for impact frames.\n\n**Zoom punch and zoom transition.** Scaling exposes black edges. Motion Tile with a larger output (150-300%) and **Mirror Edges**, plus motion blur, hides them ([AEJuice transitions](https://aejuice.com/blog/how-to-design-dynamic-transitions-between-clips-in-adobe-after-effects); [Adobe community](https://community.adobe.com/t5/after-effects-discussions/mirror-edges-not-working/m-p/11946662)). *Starting points*: for a punch, scale 100 → 110-130% over 2-4 frames and ease back over 6-12. For a transition, clip A goes to 200-400% over 4-8 frames ending on the cut and clip B comes in from 30-50% (or 200%) to 100, with a hard ease into the cut.\n\n**Glitch.** Video Copilot Twitch fires random operators (Blur, Color, Light, Scale, Slide, Time) at a \"twitch interval\", each with Speed, Amount and Seed. Slide includes an RGB split ([Video Copilot](https://www.videocopilot.net/products/twitch/features)). Universe Glitch Transition keys **Mix** for duration and adds RGB Split Max, Size and Displacement ([Maxon](https://help.maxon.net/rg/en-us/Content/html/glitch-transition.html)). *Starting point* for a rebuild: R offset +X and B offset −X (5-30 px) for 2-6 frames on the hit, plus random block-slice displacement re-seeded every 1-2 frames.\n\n## Easing decides whether motion feels cheap or After Effects grade\n\nUse the speed graph to shape acceleration (best for position) and the value graph to judge values (easier for scale) ([Adobe community](https://community.adobe.com/t5/after-effects-discussions/after-effects-graph-editor-problem/m-p/10552536/highlight/true)). Easy Ease is **speed 0 at 33.33% influence**. That is a neutral default, and some editors switch to **60%** for a snappier move ([Adobe community](https://community.adobe.com/t5/after-effects-discussions/changing-the-ease-default-values/m-p/10906650)). Overshoot uses the inertial bounce expression. Animoplex defaults are **amp 5, freq 2, decay 4**, and amp 0.05 / freq 4 / decay 8 gives a fast bounce. Raise decay to 5-6 if the bounce lingers ([Animoplex gist](https://gist.github.com/jexchan/bbff1a3c9701ce5fd4db6f07b2f78d6d); [Tuts+](https://photography.tutsplus.com/tutorials/how-to-animate-inertial-bounce-expressions-in-after-effects--cms-41469)). Contact keys on a bounce get **0% influence**, which gives a hard contact ([Adobe community](https://community.adobe.com/t5/after-effects-discussions/help-with-speed-animation-in-graph-editor/m-p/11757827)). Motion-design timing guides run exits at about **75% of the entrance duration** and note that ease-out feels faster than ease-in at the same length ([impeccable reference](https://cdn.jsdelivr.net/npm/@nqlib/nqui@0.6.3/docs/nqui-skills/impeccable/reference/motion-design.md)). At 30 fps, that puts title entrances at roughly 8-15 frames and exits at 6-10.\n\n| Feel | Curve (*starting point*, except where cited) |\n|---|---|\n| Neutral | 33% / 33% (AE default, cited) |\n| Punch-in / impact | Launch 0-30%, landing 70-90% (fast start, long settle) |\n| Zoom into cut | Ease-in heavy: slow start, fastest on the cut frame |\n| Velocity whip | Narrow speed spike, both handles 80-100% |\n| Pop / logo | Overshoot 5-15% past target (0 → 110 → 97 → 100), 4-6 f per segment |\n| Anticipation | 2-4 f pull-back of 3-10% before the main move |\n\n## Still panels animate through depth planes, paper texture and per-beat life\n\nThe documented core is to split the panel into planes and move the background slower than the foreground. Studios call this \"the multiple planes technique\" ([AEJuice](https://aejuice.com/blog/how-to-create-a-parallax-effect-in-after-effects); [ArtStation](https://gustozoh.artstation.com/projects/n00DzE)). In a 3D camera setup, set the layers at different Z values, use a 50 mm camera with Depth of Field and link focus to the subject layer. Aperture sets blur strength ([AEJuice DOF](https://aejuice.com/blog/how-to-create-depth-of-field-in-after-effects)). Mobile editors cut the layers in Ibis Paint X and animate them in Alight Motion. Desktop editors use Photoshop with After Effects ([fbpe tutorial list](https://old.fbpe.org/manga-animation-tutorial-alight-motion.html)). The full workflow below is genre convention that no transcript confirmed. Clean the scan and remove bubbles. Cut the character, the FX (debris, speed lines) and the background into layers, and fill the hole behind the character with cloned screentone. Push in across the shot (100 → 110%) with the foreground moving faster. Add mesh warp sway on hair and cloth, eye glows and dust. Overlay scrolling speed lines plus paper grain or halftone so it still reads as print. Then hit the beats with the recipes above. *Starting points* for 3D depth: background at Z +1000 to 3000, midground at 0, foreground at −300 to −600. Compensate scale as **100 × distance / zoom** so each layer keeps its framing. Drift pushes travel 200-600 px over 30-90 frames, impact pushes travel 100-300 px in 4-8 frames with shake, and orbits rotate a null 10-30° on Y over 1-2 s. For a dolly zoom, key camera Z and zoom in opposite directions so the subject's size stays constant. Faked in 2D, it needs real camera motion to read ([Lester Banks](https://lesterbanks.com/2012/07/creating-a-dolly-zoom-vertigo-effect-in-a-timelapse-shot-using-after-effects/)).\n\n## Type, grade and layout follow a \"one loud thing per frame\" rule\n\nText reveals are one animator (Opacity, Position, Scale or Character Offset) driven by a keyed Range Selector. Set **Smoothness 0** for a crisp typewriter ([Pixel Bakery](https://pixelbakery.com/education/tutorials/how-to-add-typewriter-effect)). Ease High/Low shape each character's transition separately from how fast the selector sweeps ([ProVideo Coalition](https://www.provideocoalition.com/cmg_hidden_gems_chapter_21_textacy/)). Per-character 3D plus Rotation animators give letter flips ([Adobe](https://helpx.adobe.com/after-effects/using/examples-resources-text-animation.html)). Lyric timing counts hold time from the moment a word stops moving. A rule of thumb is about 1 s for a short word and 2-3 s for a 4-8 word phrase, with one word per beat or a scale-up on the chorus ([Morphic](https://morphic.com/resources/videos/lyric-videos)). *Starting points*: stagger 1-2 frames per character or 2-4 per word, use blur-in (Blur 20-40), masked slide-ups and scramble reveals, and keep the original Japanese SFX animated with a scale pop and shake.\n\nFor 9:16 at 1080×1920, keep faces and titles inside about **870×1310**. That means clearing about 130 px at the top, 480 px at the bottom and 150 px on the right for TikTok, and about 180 px on the right for Reels ([Moda](https://moda.app/tools/story-safe-zone-checker)). Pair one loud display face with one quiet face and use 1-2 accent colors. Bold weights survive fast scaling, and headlines should be at least 36 px ([Oakgen](https://oakgen.ai/blog/kinetic-typography-without-after-effects)). For grading, set **Levels first** (black, mid and white points) rather than crude curves or exposure, because rough corrections make edits look \"weird\" ([AMV tutorial summary](https://youtubesummary.com/summary/DY14ugv1wd8)). Animate Levels to match brightness between shots and Curves to match color ([Michael DeVowe](https://vimeo.com/14396098)). Glow stacks in two passes, one tight (threshold around 30, radius around 5) and one wide ([Tuts+](https://photography.tutsplus.com/courses/create-a-stranger-things-inspired-text-animation-in-adobe-after-effects/lessons/how-to-add-color-and-glow-effects)). Deep Glow uses a 100-300 px radius with exposure kept below clipping, and needs Grow Bounds at about 2× the glow extent ([Toolfarm](https://www.toolfarm.com/?p=22323)). On anime, correct casts with luminance and not hue-only tools ([Doom9](https://forum.doom9.org/archive/index.php/t-167027.html)). *Starting point* for the stack: Levels → gentle S curve → vibrance +10-30 → LUT at 30-70% → two glows → grain and vignette, with glow or exposure spiking on hits.\n\n## Conclusion\n\nThe craft comes down to three moves. Quantize to the beat grid, give every hit an asymmetric ease (fast attack, long decay) plus motion blur and mirrored edges, and gate the intensity by song section so the drop has somewhere to go. For AWIeffect, every key effect is buildable from the documented recipes. S_Shake maps to per-axis noise, a sine wave, a stillness gate and edge reflect. Twitch maps to random operators fired at an interval with a seed. Velocity maps to a speed curve that hands off at 1× speed so it never stalls. Those features matter more than any one creator's preset.\n\nThe biggest unknown is the named creators themselves. Haiko, Gokuponch, Bri and Mutioke left no text trail, and the scene's numbers live inside videos and shared Alight Motion links. One source warns that those \"copy the link\" preset schemes are a common malware vector ([search result](https://postecards.poste.it/bold-stats/alight-motion-shakes-get-the-ialight-link-1767648748)). The next research step is primary: step through 3-5 edits per creator frame by frame, then log hit lengths, flash types and shake decay against the beat grid to turn the *starting point* values here into measured presets.\n","pro":"# Edit to the grid, then break it on purpose\n\nA pro editor working in the After Effects / Alight Motion idiom has one workflow, whatever the label on the edit. **Map the song before importing clips.** **Cut on downbeats and phrase starts, put effects on accents.** **Ease every move asymmetrically** (fast attack, long settle). **Grade in two passes**, correction first and look second. **Hold the heaviest effects back for the drop.** The styles (mixtape, flow, velocity, twixtor, aesthetic, sad, hype, glitch, 3D/camera, typography, candy, phonk, manga) are not separate crafts. They are different weightings of one shared toolkit: shake, speed ramp, flash, grade, transition, text, overlay and camera. Freelance listings sell exactly that menu as the standard parts of an anime edit ([Fiverr](https://fiverr.com/xephroxz/make-professional-anime-edits-and-amvs)). Generic, template-looking or \"AI-looking\" work has a recognizable signature in the sources: linear or default 33% eases on every key, identical timing on every element, effects firing constantly, preset values left untouched, grades that change from clip to clip, and motion that would fit any subject. Each of those has a fix you can name and measure. The evidence base has a real limitation. Written sources on AMV craft are thin and full of SEO spam, the community's knowledge lives in un-indexed TikTok, YouTube and Discord videos, and many numbers here are labelled *starting point*: practitioner convention, unconfirmed by any fetched source, to be tuned by eye and checked against references studied frame by frame.\n\n## The song is mapped before a single clip goes in\n\nThe sources agree on order. Build a \"sync map\" by hand rather than trusting a beat-detect button: mark the visual anchors, find the beats and phrases, then decide which moments need exact alignment ([Sonilo](https://sonilo.com/blog/guides/how-to-make-video-sync-with-music)). A rough first pass that blocks out the song's structure gives \"a quick overview of its dynamic differences\", and you mark beats and off-beats while listening ([Filmdaft](https://filmdaft.com/how-to-edit-video-clips-to-the-beat-of-music-the-easy-way/)). The hybrid method works best: mark by hand, let an auto tool propose cuts, then adjust by ear ([Splice](https://spliceapp.com/blog/what-is-good-for-beat-synced-edits)). BeatEdit writes the markers in Premiere and passes them to After Effects ([aescripts](https://aescripts.com/learn/tag/BeatEdit-for-Premiere-Pro/)). Markers tapped live during playback **land 2-3 frames late** and need nudging ([Adobe Community](https://community.adobe.com/t5/after-effects-discussions/key-frames-on-audio-beats/m-p/12538705/highlight/true)). Computing the grid is cleaner: **frames per beat = fps × 60 / BPM**. That gives about 14 frames at 30 fps and 128 BPM ([Morphic](https://morphic.com/resources/videos/lyric-videos)). At 24 fps and 140 BPM it gives about 10.3 frames, so a half-time cut lasts about 21 frames and a double-time cut about 5, which is practical only as strobe flashes. Beats fall in **groups of 4**, which sets phrase lengths, and alternating long shots with very short ones keeps rhythm alive ([r/amv mirror](https://reddit.rtrace.io/r/amv/comments/xjbhtg/scene_shifting_the_easiest_mistake_all_video)). Most AMVs time their visuals to the lyrics, which are easier to cut against than drums ([Utrecht thesis](https://studenttheses.uu.nl/handle/20.500.12932/37631)).\n\nThe music guides the cuts but should not dictate every one. A borrowed EDM shape (build, add layers, crescendo, breakdown, rebuild) is the useful arc. **Tension comes from faster cuts, tighter framing and more intensity. Release comes from a longer shot, softer sound or negative space.** Holding one energy level too long loses the viewer ([Dream Engine](https://www.dreamengine.com.au/tips-and-resources/learning-the-art-of-video-editing/)). The working rule is to put cuts on downbeats and phrase starts and effects on accents (snares, vocal hits, risers, the phonk cowbell). A drop gets both. Section gating, a *starting point*, turns this into numbers:\n\n| Section | Shot rhythm | Effect budget |\n|---|---|---|\n| Intro | Long holds, slow push-ins, half-time | Grade and grain only |\n| Verse | Cut per bar or per 2 beats | Subtle drift, 2-6 px RGB offset at most |\n| Build | Cut per beat, ramps accelerating | Small shakes, light zoom punches, rising glow |\n| Drop | Hit on every beat, strobe on downbeats | Flashes, impact frames, big shakes, velocity, glitch bursts |\n| Break / outro | Back to long holds, or a freeze | Fade, hard silence-cut, one accent |\n\nClip choice follows motion, not just content. Cutting during movement makes the edit less noticeable, and **the motion after the cut matters more than the motion before it** ([Smith & Martin-Portugues Santacreu, UAL](https://ualresearchonline.arts.ac.uk/id/eprint/21152/2/4592cb6f-bad6-4ef9-a488-be3cb33fee43.pdf)). In a motion match the incoming shot continues the outgoing trajectory. Editing can refine a match but cannot rescue incompatible framing, so test neighbouring frames and keep the best one ([CapCut](https://www.capcut.com/create/match-cuts-seamless-scene-transitions)). Eye trace means keeping the key detail in the same screen area across the cut ([CineD](https://cined.com/mastering-match-cuts-a-deep-dive-into-seamless-storytelling/)). In practice, tag every clip by direction (L→R, R→L, toward or away from camera), energy (still, mid, explosive) and shot size, and pull drop clips only from the explosive bin. \"Not being original\" is music-video mistake number one ([No Film School](https://nofilmschool.com/2017/09/5-music-video-editing-mistakes-and-how-fix-them)), so skip the series' most-reposted fight frames or recontextualize them with a crop or a ramp.\n\n## Easing curves separate After Effects grade from cheap\n\nLinear keyframes make movement \"look stiff and robotic\". Ease everything (F9), never ease the launch of something thrown (its peak speed belongs at the start), and **hide abrupt changes at the fastest point of a move**, not in its slow parts ([School of Motion](https://www.schoolofmotion.com/blog/3-pro-tips-after-effects-beginners)). Joey Korenman reads the value graph rather than the speed graph, separates the X and Y dimensions, uses the fewest keyframes possible (two for most moves) and pulls handles long for a \"fling\" ([School of Motion](https://schoolofmotion.com/blog/intro-to-the-graph-editor-in-after-effects)). The AE default Easy Ease is speed 0 at **33.33% influence**, a neutral setting that pros move away from. Speed 0 at about **75% influence** in and out gives a slow start, snappy middle and gentle settle ([Creative Cow](https://creativecow.net/forums/thread/easy-ease-adjusting-softness/)). Material Design publishes AE influence equivalents that work as presets: standard **40/80**, deceleration **0/80**, acceleration **40/0**, sharp **40/40** ([Material Design](https://m1.material.io/motion/duration-easing.html)). Stiff motion comes from linear or symmetric easing. Floaty motion comes from a move that is too long or an ease-out that is too gentle, and the fix is to shorten the move and sharpen the curve ([playbooks.com](https://playbooks.com/skills/dylantarre/animation-principles/slow-in-out-mastery)). Keep linear only for continuous loops and for keys that feed expressions.\n\nOvershoot and bounce carry weight. For a hand-built bounce, each bounce reaches about **half the previous height**. SoM's example uses an 8-frame fall followed by bounces of 4, 3 and 2 frames ([School of Motion](https://schoolofmotion.com/blog/intro-to-the-graph-editor-in-after-effects)). For scale overshoot, key a middle value past the target, or add a rebound key (50 → 150 → 75 → 100) with shorter and smaller repeats ([Mt. Mograph](https://mtmograph.com/blogs/tools/the-bounce-and-overshoot-animation-trick-every-motion-designer-should-know)). Expression versions use freq 3 / decay 5, or Animoplex's amp 5 / freq 2 / decay 4. Velocity-driven inertia can overshoot wildly on fast moves, so clamp it ([Mt. Mograph](https://mtmograph.com/blogs/tools/the-bounce-and-overshoot-animation-trick-every-motion-designer-should-know); [Animoplex](https://gist.github.com/jexchan/bbff1a3c9701ce5fd4db6f07b2f78d6d)). Of Disney's twelve principles, easing, timing, follow-through/overlap and anticipation carry the most weight in mograph. Follow-through shows rigidity and environment: parts trail the lead (arm, then hand, then stick), and how long they keep moving tells the viewer how hard the stop was ([School of Motion](https://schoolofmotion.com/blog/follow-through-tutorial)). Timing (how many frames) sets weight, and spacing (how the frames are spread) sets acceleration ([Full Frontal](https://fullfrontal.moe/animation-fundamentals-timing-and-spacing/)).\n\nDurations convert with **frames = ms × fps / 1000**. UI-scale moves run about 300 ms (entering 225, exiting 195), and anything over 400 ms feels slow ([Material Design](https://m1.material.io/motion/duration-easing.html)). That is 7 frames at 24 fps, 9 at 30 and 18 at 60. Exits take about 75% of the entrance time. Siblings stagger at a constant **2-4 frames, 3 by default** ([fframes](https://docs.rs/crate/fframes-components/latest/source/src/components/word_by_word.README.md)). Secondary elements settle **4-8 frames after the primary** ([agentskills](https://agentskills.so/skills/dylantarre-animation-principles-video-motion-graphics)), and a group's total reveal stays around 600-800 ms ([claudemarket](https://www.claudemarket.ai/skills/iart-ai/motion-design-skills/animation-principles)). Hit-level edit moves are shorter than UI moves:\n\n| Move | Recipe |\n|---|---|\n| Velocity ramp | 200% speed on the beat, 20% between, scale 100 → 130 → 100, motion blur ([AEJuice](https://aejuice.com/blog/how-to-do-velocity-edits-after-effects)). Time-remap stall fix: **1 sec/sec at 33.33% influence** on the handoff keys ([Creative Cow](https://creativecow.net/?p=7479)) |\n| Shake | S_Shake defaults Amplitude 1, Frequency 8, Reflect edges, Twitchy style Stillness 0.7 ([Boris FX](https://borisfx.com/documentation/sapphire/ae/shake/)). wiggle(10,3) tight jitter, wiggle(2,40) slow sway ([CG Director](https://www.cgdirector.com/after-effects-wiggle-expression)). Hit shakes 0.15-0.30 s ([sccreationss](https://sccreationss.com/smooth-shake-effect-in-alight-motion/)) |\n| Flash | White solid 4-5 frames, fading out ([DVinfo](https://www.dvinfo.net/forum/archive/index.php/t-125973.html)). *Starting point*: 1-2 f strobes, 1-2 f black dip for heavy hits, 2-4 f inverted impact frame |\n| Zoom punch | *Starting point*: 100 → 110-130% over 2-4 f, ease back over 6-12 f. Motion Tile with Mirror Edges hides the borders ([AEJuice](https://aejuice.com/blog/how-to-design-dynamic-transitions-between-clips-in-adobe-after-effects)) |\n| Anticipation | *Starting point*: 2-4 f pull-back of 3-10% before the main move |\n\nTwixtor has documented settings. Input Frame Rate must equal the source fps, because a wrong value causes stutter. Use Speed mode with Speed% = 100 / duration factor (50% gives 2× length). **Lower Motion Sensitivity to cut warping, raise it to cut blending**, and keyframe it if you have both problems ([Boris FX](https://borisfx.com/blog/twixtor-after-effects-how-to-step-by-step-guide/)). Anime is drawn at about 12-24 fps with held frames, and motion in many directions or moving hair confuses the estimator ([animeworldtwixtor](https://animeworldtwixtor.com/how-to-use-twixtor-on-anime-clips-beginners-guide-2026/); [AMV.org](https://www.animemusicvideos.org/forum/viewtopic.php?t=120400)). So pick camera pans and animation on ones for interpolation, and use frame holds plus shake on limited animation.\n\n## Every style is the same toolkit with different weights\n\nOnly a few labels have written definitions. Viddertips defines **raw** as minimal cuts, crops and fades, story-first. **Flow** is less a style than a quality: how well clips connect in color, movement and theme. **Effects style** puts technique ahead of story. **MMV** uses manga as the main material and **FMV** uses fanart ([Viddertips](https://www.tumblr.com/viddertips/86480880308/can-you-tell-me-the-different-editing-styles-and)). **Candy** means bright color, light music, borders and thick outlines (same source), usually with bouncy motion and an S/Z-shaped curves grade ([sccreationss](https://sccreationss.com/cc-editing-in-alight-motion-tutorial/)). **Velocity** means speed changes on the beat, eased in the graph editor and exported 1080p60, often paired with shakes ([AlightMotionLab](https://alightmotionlab.pro/how-to-do-velocity-edits-in-alight-motion/)). Phonk is a music-defined style. Brazilian phonk (funk automotivo) became synonymous with the genre by the mid-2020s ([Wikipedia](https://en.wikipedia.org/wiki/Phonk)) and runs **140-170 BPM** with high-impact drops ([Melodigging](https://www.melodigging.com/genre/drift-phonk)). Long YouTube AMVs are declining under algorithms and rights-holder takedowns, while 9:16 IG and TikTok edits are shorter, faster and cut more often ([Sabukaru](https://sabukaru.online/articles/visual-remix-culture-the-legacy-of-amv)). The other labels (mixtape, hype, sad, aesthetic, 3D/camera, glitch, typography) are hashtag-level and defined by practice. The vibe-to-choice table below is therefore a practitioner synthesis. Treat it as a set of priors to test against references, not as rules.\n\n| Style / vibe | Cut rate | Motion and FX | Color | Text | Signature mistake |\n|---|---|---|---|---|---|\n| Classic AMV | Phrase and lyric; hits on accents | Light: crossfades, flashes, masks | Unified across sources | Title card | Clip dump with no narrative |\n| Short anime edit | Every beat or half-beat after the drop | Shakes, flashes, velocity, zoom punch, RGB split | Punchy contrast, glow | Name or caption | Preset shake on every beat |\n| Flow | Long, match cuts on motion and color | Zoom, spin and whip-blur transitions, gentle ease, few hard shakes | Consistent mood | Little | Motion direction reversing between cuts |\n| Velocity | Ramps on every strong beat | Fast-slow-fast, motion blur, shakes | Contrast | Minimal | Linear speed keys; blur turning faces to mush |\n| Twixtor / smooth | Long dramatic holds | Interpolated slow-mo ramps | Clean | Little | Warping on hair and limbs; slowing everything |\n| Aesthetic / soft | Slow | Fades, light leaks, grain, bloom | Pastel or film, lifted | Small lowercase serif or handwritten | Over-blur, washed-out blacks |\n| Sad | Half-time, held faces | Sparse soft shakes, dissolves, a silence-cut before the climax | Desaturated, cool | Lyric lines | Effects fighting the emotion |\n| Hype / badass | Every hit | Heavy shakes, impact frames, flashes, chromatic aberration | High contrast | Big bold type | Constant intensity, so the drop doesn't land |\n| Phonk | On the cowbell pattern | Heavy velocity and shake, often B/W manga | B/W plus one accent | Bold | Cutting on the 808 tail instead of the transient |\n| Glitch | On transients | Bursts of slice, RGB split, datamosh, pixel sort | Digital, neon accents | Glitched type | Continuous glitch that hides the subject |\n| 3D / camera | Per move | Orbits, Z-parallax, flips, depth of field | Any | 3D type | Unmotivated spinning; cardboard depth |\n| Typography / lyric | On the syllable | Kinetic type, mattes, tracking | Limited palette | Text is the subject | Under ~0.3 s per word; too many fonts |\n| Candy | Bouncy, on the beat | Overshoot, shapes, stickers, strokes | Bright, saturated, S/Z curve | Rounded, outlined | Clutter with no hierarchy |\n| Mixtape | Each segment its own mini edit | Tape or glitch interludes between songs | A distinct grade per segment | Segment titles | Segments with no arc linking them |\n\nThe useful mental model is a set of axes: **energy** (sad/aesthetic → flow → hype/phonk), **effect density** (raw → effects, overlay, glitch), **material** (anime, manga, game, fanart), **motion space** (2D → 3D) and **text weight** (none → typography). Hybrids are the norm: phonk + manga + velocity, sad + typography, flow + twixtor, hype + glitch + 3D. Switching style inside one edit (a soft flow intro into a velocity drop) is the most reliable shape. **Manga edits and manga animation** have documented workflows. Scan at 300+ DPI, import the layers, turn on 3D layers and keyframe a camera ([Live Anime](https://www.liveanime.org/post/how-to-animate-manga-panels-after-effects)). Split each panel into depth planes that move at different speeds ([AEJuice](https://aejuice.com/blog/how-to-create-a-parallax-effect-in-after-effects)). Use one-node cameras for push-ins and two-node cameras to orbit a point ([Adobe](https://helpx.adobe.com/th_th/after-effects/how-to/camera-animation.html)). Mobile editors cut the layers in Ibis Paint X and animate in Alight Motion ([fbpe](https://old.fbpe.org/manga-animation-tutorial-alight-motion.html)). *Starting points* for 3D depth: background at Z +1000-3000, subject at 0, foreground at −300 to −600, with scale compensated as 100 × distance / zoom. Drift pushes travel 200-600 px over 30-90 frames, impact pushes 100-300 px in 4-8 frames with shake. Keep the screentone and the Japanese SFX, add paper grain, and invert or go red/black on hits. The marks of an amateur are flat 2D zooms, moiré scans, ignoring reading order, rubbery mesh warps and no secondary motion.\n\n## Grade, glow and glitch are layered, thresholded and timed\n\nColor is two passes. The correction pass balances exposure and casts on scopes: waveform for exposure, RGB parade for casts, vectorscope for hue and skin ([DaVinci Resolve Club](https://davinciresolveclub.com/davinci-resolve-scopes-explained/)). The skin line sits at about 11 o'clock and works for matching faces across shots, but it is a convention, not a target ([Videomaker](https://www.videomaker.com/how-to/editing/color-correction/what-are-vectorscopes-and-why-are-they-important/); [Creative COW](https://creativecow.net/?p=1982922)). Use Levels before curves or exposure, because crude corrections make edits look \"weird\" ([AMV tutorial summary](https://youtubesummary.com/summary/DY14ugv1wd8)). On flat-shaded anime, correct casts with luminance tools rather than hue-only tools ([Doom9](https://forum.doom9.org/archive/index.php/t-167027.html)). The look pass is split toning, one color in the shadows and another in the highlights with the midtones left alone ([Darkroom](https://darkroom.co/help/guide/color-grading-mood.md)). Teal/orange works because the two hues are complementary and warm skin pops against cool surroundings ([Zoner](https://learn.zoner.com/color-grading-step-by-step-iii-how-to-get-the-popular-teal-orange-look/)). **Oversaturation paired with over-contrast is the most frequent grading error** ([TechBullion](https://techbullion.com/common-mistakes-in-color-grading-and-how-to-avoid-them-a-guide-for-video-editors/)). Pros compress saturation in targeted ranges instead of using a global slider ([MixingLight](https://mixinglight.com/color-grading-tutorials/fixing-saturation-baseligh-look/)), and they rest their eyes before final calls. A *starting point* stack: Levels → gentle S-curve → vibrance +10-30 → LUT at 30-70% after correction → two glows → grain and vignette. Put it on an adjustment layer with per-section variants: cooler and desaturated in the verse, more contrast at the build, full palette or monochrome plus one accent at the drop. Dropping a CC preset straight onto footage blows highlights and crushes blacks ([sccreationss](https://sccreationss.com/cc-editing-in-alight-motion-tutorial/)).\n\nGlow is a thresholded, desaturated, blurred copy added over an untouched original. The manual build is Levels to crush blacks (the threshold), Fast Blur, Hue/Saturation down, then composite in Add, with \"Clip to Output Black\" on in 32-bit ([School of Motion](https://www.schoolofmotion.com/blog/glows-after-effects)). Stack a tight core (threshold around 30, radius around 5) under a wide halo ([Tuts+](https://photography.tutsplus.com/courses/create-a-stranger-things-inspired-text-animation-in-adobe-after-effects/lessons/how-to-add-color-and-glow-effects)). Deep Glow runs at 100-300 px with **Grow Bounds at about 2× the radius** so the glow doesn't clip at the layer edge ([Toolfarm](https://www.toolfarm.com/?p=22323); [Adobe Community](https://community.adobe.com/t5/after-effects-discussions/deep-glow-effects-extends-all-the-way-to-the-canvas-boundary/m-p/13858274)). Glowing everything, or glowing without a threshold, is the blown-out amateur look.\n\nGlitches read as intentional when they come **in bursts with clean frames between them**, not at constant maximum ([Videobolt](https://blog.videobolt.net/post/glitch-effect-in-your-videos)). On 60 fps footage, random glitch states that change every frame feel twice as fast, and the fix is to hold each state for several frames ([Adobe Community](https://community.adobe.com/t5/after-effects-bugs/single-frame-glitch/idi-p/15139320)). Red Giant Glitch's frequency control (100% means almost every frame) is the knob to keep low ([Maxon](https://help.maxon.net/rg/en-us/Content/html/glitch.html.md)). What separates crafted from cheap is how the displacement ramps in and out ([Freevisuals](https://www.freevisuals.net/templates/premium-dynamic-glitch-text-animations-and-modern-lower-thirds)). Datamosh deletes the I-frame so P-frame motion smears over the previous image, and it needs motion-heavy footage ([SpotlightFX](https://spotlightfx.com/blog/what-is-datamoshing)). Pixel sort's threshold sets how much of the frame sorts ([Superhive](https://superhivemarket.com/products/pixel-sort/docs)). *Starting point*: 2-6 frame bursts on snares, each random state held 2 frames, up to 8-12 frames on a big drop, and at least a second of clean picture in calm sections. Escalate by section: RGB offset in the verse, slices at the build, datamosh or pixel sort only at the drop.\n\nCompositing a cutout means degrading it to match the plate: light direction, color, contrast, edge softness, depth of field, then grain sampled from the plate and added last ([Adobe Community](https://community.adobe.com/t5/after-effects-discussions/effect-s-to-use-for-my-greenscreen/m-p/10307681); [Vitrina](https://vitrina.ai/blog/advanced-compositing-techniques-seamless-vfx-integration/)). Light wrap blurs a strip of background onto the subject's edges. Make it stronger where the edge faces a bright background, and remember that overdoing it makes footage soft ([PremiumBeat](https://www.premiumbeat.com/blog/what-is-light-wrapping-tips-tutorials); [Beverly Boy](https://beverlyboy.com/film-technology/light-wrap-problems-how-to-add-softness-without-flatness)). Blend-mode conventions: Screen or Add for light, Multiply for shadow and paper, Overlay or Soft Light for texture, Color for tint. Put the grade on top as an adjustment layer and one shared grain pass last.\n\n## Type, logos and outros earn their look from one constraint\n\nText animation in AE is an animator (position, scale, opacity, blur, tracking, character offset) driven by a Range Selector sweeping characters, words or lines. The default Square shape \"gives a choppy, blocky look\". Switch to Ramp Up with Ease High/Low around 50% ([PremiumBeat](https://www.premiumbeat.com/blog/animate-individual-letters-in-after-effects/)). Ease High/Low shapes each character's move, which is separate from easing the selector's sweep ([ProVideo Coalition](https://www.provideocoalition.com/cmg_hidden_gems_chapter_21_textacy/)). Randomize Order with a seed gives decode and scramble reveals, and a Wiggly selector adds flicker ([Adobe Community](https://community.adobe.com/t5/after-effects/decoder-expression-linear-to-random-resolution/td-p/11033156)). For a scale pop, go 0 → about 110% in about 10 frames, then settle to 100 ([Creative COW](https://creativecow.net/?p=224621)). For text behind a subject, set an Alpha Inverted track matte from the cutout ([AEJuice](https://aejuice.com/blog/how-to-make-transparent-text-in-after-effects)). Readability sets the hard limits. Keep text inside the inner 80% title-safe area ([ProVideo Coalition](https://www.provideocoalition.com/unsafe_areas/amp/)), and on 9:16 inside about 870×1310, clear of the TikTok and Reels UI ([Moda](https://moda.app/tools/story-safe-zone-checker)). Hold any phrase at least **20 frames at 24 fps** ([Netflix](https://backlothelp.netflix.com/hc/en-us/articles/215758617)). Run kinetic type at **no more than about 3 words per second** ([SBCC](https://soma.sbcc.edu/Users/Russotti/113/113lect_typeinmotion.html)). Add 5-12% tracking to all caps ([Butterick](https://practicaltypography.com/letterspacing.html)). On mobile, use fewer type styles, heavier sans-serifs and about 30% less text ([Hera](https://hera.video/blog/kinetic-typography-video-generator-guide)). Giving every word a different animation is the signature typography mistake (same source). Land each lyric's first frame on the syllable onset or 1-2 frames early (*starting point*), and pair one loud display face with one quiet face.\n\nLogo, watermark and outro work runs on one principle: **derive a single visual device from the mark and reuse it everywhere**. School of Motion's process runs Brief → Concept → Design (still keyframes, final frame defined first) → Animation → Audio, and the final reveal was \"simple masking\" ([School of Motion](https://www.schoolofmotion.com/blog/5-step-blueprint-motion-designers-use)). Motion \"has to be something specific to the logo\", and generic motion is why templates fail ([HackerNoon](https://hackernoon.com/how-designers-approach-logo-animation)). GitLab only allows its logo to enter with a trace/stroke reveal and bans fades, off-frame move-ins and scale reveals. It also sets icon motion at 0.65 s, lower thirds at a 1 s fade in, 4-5 s hold and 1 s fade out, and subtle drift at 2-5% ([GitLab](https://design.gitlab.com/brand-design/motion)). That restriction is what makes the motion recognizable. Motion Design School names five cheap-sting mistakes: **territory grab** (elements scattered across the frame), overlong runtime, floaty motion, palette and stroke weights that don't match the logo, and \"fan art\" (newly drawn icons in the logo's style), which it says look out of style 99% of the time ([Motion Design School](https://motiondesign.school/blog/5-mistakes-in-logo-animation/)). Trim Paths (strokes only), Repeater, Offset, Merge and Wiggle Paths cover most shape flourishes ([AEJuice](https://aejuice.com/blog/how-to-use-trim-paths-in-after-effects); [Motion Array](https://blog.motionarray.com/learn/software/animatedshapes/)). Wiggle Paths held at stepped intervals gives Ben Marriott's handmade paper-cutout look ([Lester Banks](https://lesterbanks.com/2020/02/an-easy-way-to-get-a-paper-cutout-stop-motion-look-in-ae/)). For an editor's tag, keep intro stings within about **1-4 s** ([Renderforest](https://www.renderforest.com/blog/how-long-should-youtube-intro-be)) with a 2-3 s audio sting landing on the logo lock ([Wavemaker](https://wavemaker.adwave.com/video-styles/logo_sting)). Short-form edits want the tag at 0.5-2 s or at the end, never in front of the hook. YouTube end screens occupy the last 5-20 s, so keep key visuals out from under them ([Videobolt](https://blog.videobolt.net/post/how-to-make-a-youtube-outro)). A watermark should be small, cornered and low-opacity, built from the sting's motif, with a short entrance and then static. No source gave opacity numbers.\n\n## Generic results come from defaults; references break the defaults\n\nThe anti-template checklist falls straight out of the sources. **Replace symmetric 33% eases** with asymmetric ones (0/80, 40/80). **Offset siblings** by 2-4 frames, with ±1 frame of variation so the cascade isn't mechanical. **Give each beat one hero move** with quieter secondaries. **Keep the action in a tight zone** instead of territory-grabbing the frame. **Fire glitches and shakes in bursts with clean frames between them.** **Retune every preset**, because templates are pre-timed and break when retimed ([Videobolt](https://videobolt.net/motion-graphics-glossary/glitch-effect)). Derive shapes, angles and colors from the subject or logo rather than adding random slashes and centered full-width lines. Community critique agrees that effects need a reason: VHS \"just distracts\" without one ([r/amv megathread](https://redlib.ssps.io/r/amv/comments/gbe7nq/feedback_megathread_may_2020)), beginners who stack effects \"spoil it all\" ([Fanlore](https://fanlore.org/wiki/How_to_be_a_PERFECT_VIDDER)), and no edit needs effects to \"compensate\" ([r/amv Q2 2024](https://lr.sudovanilla.org/r/amv/comments/1d4z9ky/feedback_megathread_q2_2024)). Excess is fine when it is deliberate and builds an aesthetic ([No Film School](https://nofilmschool.com/2017/09/5-music-video-editing-mistakes-and-how-fix-them)). No source addresses \"AI-looking\" motion directly. By inference it is the same failure in a purer form: uniform timing, uniform intensity, motion with no physical cause, and elements that don't come from the subject. Originality comes from things a template can't supply: custom rotoscoped cutouts, hand-set type, measured 3D depth, a held silence before the drop. Work within a familiar structure, then add one unexpected moment ([Dream Engine](https://www.dreamengine.com.au/tips-and-resources/learning-the-art-of-video-editing/)).\n\nReference study is where the missing numbers come from. No fetched source documents a pro study routine, and the named creators (Haiko, Gokuponch, Bri, Mutioke) left no text trail. The method that follows from everything above is a *starting point*:\n\n1. Import the reference at its native fps.\n2. Drop a marker on every cut, flash, shake onset and text hit.\n3. Overlay the BPM grid and log each event's offset from the beat in frames.\n4. Measure durations: flash length, shake decay frames, ramp peak and trough, stagger offsets, how long text holds after it stops moving.\n5. Check whether the move is eased by stepping frames and comparing per-frame displacement. Equal steps mean linear. Big early steps mean ease-out.\n6. Sample the grade on scopes.\n7. Count effects per section to recover the effect budget.\n\nWatch it once muted for visual rhythm, then once with sound, and check that viewers get time to absorb the key details ([Dream Engine](https://www.dreamengine.com.au/tips-and-resources/learning-the-art-of-video-editing/)). After 3-4 finished videos, post to feedback threads, and learn the software rather than collecting one-effect tutorials ([r/amv help](https://nyc1.lr.ggtyler.dev/r/amv/comments/1h915gn/amv_help)). Be wary of \"copy the link\" preset schemes, which one source flags as a malware vector ([search result](https://postecards.poste.it/bold-stats/alight-motion-shakes-get-the-ialight-link-1767648748)).\n\n## Conclusion\n\nThe research changes the question from \"which style?\" to \"which defaults are you still using?\" Every documented gap between amateur and pro work is a default left in place: 33% eases, preset shakes, global saturation, untimed glitches, full-frame flourishes, or a logo that enters with a fade. Style labels are just recipes for weighting a fixed toolkit by energy, density, material, space and text. That means a tool or an editor can treat style as a parameter set over shared, beat-quantized primitives rather than as a separate preset for each style. Gating intensity by song section is the single highest-leverage habit, because without it every other technique flattens into noise.\n\nWhat stays unknown is the measured signature of top short-form editors: their exact hit lengths, shake decays and ramp shapes. That knowledge exists only inside videos and shared project files. The frame-by-frame logging method above is how to turn this report's *starting point* values into real presets. It is also the most direct way to get past generic work, because it replaces guessed numbers with measured ones taken from work that already lands.\n","effects":"# AWIeffect effect ids\n\nUse these ids as `type` in add_effect. Read get_catalog for each effect's exact settings and ranges.\n\n## blur\n`ae.gaussianBlur` Gaussian Blur, `ae.directionalBlur` Directional Blur, `ae.radialBlur` Radial Blur, `awi15.hexagonBlur` Hexagon Blur, `awi15.vortexBlur` Vortex Blur, `awi15.smear` Smear, `awi15.innerBlur` Inner Blur, `awi15.edgeBlur` Edge Blur, `awi15.maskBlur` Luma Mask Blur, `awi15.minimax` Minimax, `awi15.bilateral` Bilateral Smooth, `awi15.channelBlur` Channel Blur, `awi15.shakeBlur` Camera Shake Blur, `awi15.radialStreaks` Radial Streaks, `awi15.spinStreaks` Spin Streaks, `awi15.linearStreaks` Linear Streaks, `awi15.clarity` Clarity, `awi15.highPass` High Pass Sharpen, `awi15.structure` Structure, `ae.sharpen` Sharpen, `ae.unsharpMask` Unsharp Mask, `awi.lensBlur` Lens Blur (Bokeh), `awi.chromaticZoom` Chromatic Zoom Blur, `awi8.boxBlur` Box Blur, `awi8.spinBlur` Spin Blur, `awi8.starStreaks` Star Streaks, `awi8.lightStreaks` Light Streaks, `awi8.frostedGlass` Frosted Glass, `awi8.tiltShift` Tilt-Shift, `awi8.sharpenPro` Sharpen Pro\n\n## color\n`ae.exposure` Exposure, `ae.brightnessContrast` Brightness & Contrast, `ae.hueSaturation` Hue/Saturation, `ae.tint` Tint, `ae.levels` Levels, `ae.invert` Invert, `ae.fill` Fill, `awi.vignette` Vignette, `ae.glow` Glow, `awi10.normalLight` Normal Map Lighting, `awi10.lightSweep` Light Sweep, `awi10.starGlint` Star Glint, `awi10.rainbowGlint` Rainbow Glint, `awi10.spotlight` Spotlight, `awi10.pointLight` Point Light Glow, `awi10.twoTone` Two-Tone Lighting, `awi10.fresnel` Fresnel Edge Glow, `awi10.holoFoil` Holographic Foil, `awi10.specular` Specular Highlight, `awi10.filmBloom` Film Glow Bloom, `awi10.lensDirt` Lens Dirt, `awi13.cyberpunk` Cyberpunk Grade, `awi13.lomo` Lomo, `awi13.dayForNight` Day for Night, `ae.curves` Curves, `awi.looks` AWI Looks, `ae.noise` Noise / Grain, `awi.deepGlow` AWI Deep Glow, `awi.saber` AWI Saber, `awi.shine` AWI Shine, `ae.colorBalance` Color Balance, `ae.vibrance` Vibrance, `ae.blackWhite` Black & White, `ae.photoFilter` Photo Filter, `ae.tritone` Tritone, `ae.leaveColor` Leave Color, `ae.changeToColor` Change to Color, `awi.rimLight` Rim Light, `awi.godRays` God Rays, `awi.halation` Halation, `awi.gradientMap` Gradient Map, `awi.flicker` Flicker, `awi.hueCycle` Hue Cycle, `awi8.gradeWheels` Color Grade Wheels, `awi8.hslSecondary` HSL Secondary, `awi8.selectiveColor` Selective Color, `awi8.splitToning` Split Toning, `awi8.channelMixer` Channel Mixer, `awi8.temperatureTint` Temperature & Tint, `awi8.bleachBypass` Bleach Bypass, `awi8.crossProcess` Cross Process, `awi8.infrared` Infrared, `awi8.thermal` Thermal Vision, `awi8.nightVision` Night Vision, `awi8.sepiaPlus` Sepia+, `awi8.vintageFade` Vintage Fade\n\n## distort\n`awi10.cardTilt` Pseudo 3D Card Tilt, `awi14.blackHole` Black Hole, `awi14.droste` Droste Spiral, `awi14.fractalZoom` Fractal Zoom, `awi14.pageCurl` Page Curl, `awi14.fold` Accordion Fold, `awi14.skew` Skew / Shear, `awi14.keystone` Perspective Tilt, `awi14.stretchSegment` Stretch Segment, `awi14.waveLine` Wave Ripple Line, `awi14.twistColumns` Twist Columns, `awi14.smearDrag` Smear Drag, `awi14.meshJitter` Mesh Jitter, `awi14.elasticBounce` Elastic Bounce Warp, `awi14.magnifier` Magnifier Lens, `awi14.tunnelWarp` Tunnel Warp, `awi14.puff` Puff / Inflate, `awi14.pinchWaves` Pinch Waves, `awi14.polarRipple` Polar Ripple, `awi14.vortexSpin` Vortex Spin, `awi14.glassBlocks` Glass Blocks, `awi14.frostedWindow` Frosted Window, `awi14.waterSurface` Water Surface, `awi14.mirage` Mirage, `awi14.earthquake` Earthquake Displace, `awi14.zoomRings` Zoom Rings, `awi17.cubeSkybox` Cube Skybox, `awi17.sphereMap` Sphere Map, `awi17.cylinderWrap` Cylinder Wrap, `awi17.pageFlip` Page Flip 3D, `awi17.cubeFlip` Cube Flip, `awi17.logoPlane` Rotating Logo Plane, `awi18.warpChroma` Warp Chroma, `awi18.puppet` Puppet Pins, `awi18.displacementMap` Displacement Map, `ae.turbulentDisplace` Turbulent Displace, `ae.waveWarp` Wave Warp, `ae.bulge` Bulge, `ae.twirl` Twirl, `ae.opticsCompensation` Optics Compensation, `ae.mirror` Mirror, `ae.polarCoordinates` Polar Coordinates, `ae.motionTile` Motion Tile, `ae.offset` Offset, `ae.ripple` Ripple, `ae.spherize` Spherize, `ae.magnify` Magnify, `ae.cornerPin` Corner Pin, `cc.lens` CC Lens, `awi6.fisheye` Fisheye, `awi6.lensDistortion` Lens Distortion, `awi6.glass` Glass Refraction, `awi6.liquid` Liquid Warp, `awi6.ripples` Water Ripples, `awi6.rainOnGlass` Rain on Glass, `awi6.heatHaze` Heat Haze, `awi6.bulge` Bulge / Pinch, `awi6.squeeze` Squeeze, `awi6.bend` Bend, `awi6.swirl` Swirl+, `awi6.hexTiles` Hexagon Tiles, `awi6.shatter` Shatter, `awi6.slice` Perfect Slice, `awi6.lumaDisplace` Luma Displace, `awi6.kaleidoscope` Kaleidoscope+, `awi6.wobble` Wobble\n\n## generate\n`ae.fractalNoise` Fractal Noise, `awi10.volumetricBeam` Volumetric Light Beam, `awi12.plexus` Plexus, `awi12.constellation` Constellation, `awi12.fireworks` Fireworks, `awi12.bubbles` Bubbles, `awi12.rainRipples` Rain Ripples, `awi12.vortexDust` Vortex Dust, `awi12.neuralNetwork` Neural Network, `awi12.metaballs` Metaballs, `awi12.voronoiShapes` Voronoi Shapes, `awi12.isolines` Isolines, `awi12.cosmicNebula` Cosmic Nebula, `awi12.glowTunnel` Glow Tunnel, `awi12.waveLines` Wave Lines, `awi12.hexGridGlow` Hex Grid Glow, `awi12.lightTrails` Light Trails, `awi12.sunburst` Sunburst, `awi12.kaleidoMandala` Kaleido Mandala, `awi12.gridWarp` Grid Warp, `awi12.liquidGradient` Liquid Gradient, `awi12.inkSmoke` Ink Smoke, `awi12.crystalShards` Crystal Shards, `awi12.spiralGalaxy` Spiral Galaxy, `awi12.orbitRings` Orbit Rings, `awi12.heartbeatLine` Heartbeat Line, `awi12.sparkleDust` Sparkle Dust, `awi17.tunnel3D` Infinite Tunnel 3D, `awi17.floorGrid` Floor Grid 360, `awi17.starPlanes` 3D Starfield Planes, `awi17.citySkyline` City Skyline, `awi17.seascape` Seascape, `awi17.volClouds` Volumetric Clouds, `awi17.pointCloud` Point Cloud Sphere, `awi17.orbitParticles` 3D Particles Orbit, `awi17.extrudeFlat` Extrude Flat, `awi.particles` AWI Particles, `ae.gradientRamp` Gradient Ramp, `ae.fourColorGradient` 4-Color Gradient, `ae.checkerboard` Checkerboard, `ae.grid` Grid, `ae.cellPattern` Cell Pattern, `ae.lightning` Advanced Lightning, `ae.lensFlare` Lens Flare, `awi.lightLeak` Light Leak, `awi.cinematicBars` Cinematic Bars, `awi7.starfield` Starfield Warp, `awi7.twinklingStars` Twinkling Stars, `awi7.snow` Snow, `awi7.rain` Rain, `awi7.embers` Embers & Sparks, `awi7.bokehParticles` Bokeh Particles, `awi7.dustMotes` Dust Motes, `awi7.fireflies` Fireflies, `awi7.speedLines` Speed Lines, `awi7.mangaFocusLines` Manga Focus Lines, `awi7.shockwave` Shockwave Ring, `awi7.energyBeam` Energy Beam, `awi7.plasma` Plasma, `awi7.aurora` Aurora, `awi7.clouds` Clouds & Fog, `awi7.smoke` Smoke, `awi7.fire` Fire, `awi7.electricArcs` Electric Arcs, `awi7.codeRain` Code Rain, `awi7.retroGrid` Retro Grid & Sun, `awi7.tunnel` Tunnel, `awi7.equalizer` Equalizer Bars, `awi7.halftoneBackground` Halftone Pattern, `awi7.confetti` Confetti\n\n## glitch\n`awi19.slice` Slice Glitch, `awi19.datamosh` Datamosh, `awi19.pixelSort` Pixel Sort, `awi19.jpeg` JPEG Corruption, `awi19.vhs` VHS Tracking, `awi19.signalLoss` Signal Loss, `awi19.interlace` Interlace / Bad TV, `awi19.blockCorrupt` Block Corruption, `awi19.stutter` Stutter Jump, `awi19.mirrorTile` Mirror Tile Glitch, `awi19.slitScan` Slit Scan, `awi19.chromaShatter` Chroma Shatter, `awi19.flash` Glitch Flash, `awi19.displace` Displacement Glitch\n\n## keying\n`awi.chromaKey` Chroma Key, `awi11.featherEdges` Feather Edges, `awi11.advancedChromaKey` Advanced Chroma Key, `awi11.spillCleaner` Key Spill Cleaner, `awi11.matteChoker` Matte Choker, `awi11.unmultiply` Unmultiply, `awi11.colorRangeKey` Color Range Key, `awi11.lumaMatteSoft` Luma Matte Soft, `awi11.alphaLevels` Alpha Levels, `awi11.edgeRefine` Edge Refine, `awi11.removeColorMatting` Remove Color Matting, `awi18.setMatte` Set Matte, `awi19.colorSelect` Individual Chroma Key, `ae.simpleChoker` Simple Choker, `ae.lumaKey` Luma Key\n\n## motion\n`awi.shake` Shake, `awi11.repeatGrid` Repeat Grid, `awi11.repeatLine` Repeat Line, `awi11.repeatRadial` Repeat Radial, `awi11.scatterField` Scatter Field, `awi11.mirrorTile` Mirror Tile, `awi11.zoomTunnel` Infinite Zoom Tunnel, `awi11.echoOffset` Echo Offset, `awi18.shakePro` Shake Pro, `awi18.zoomPunch` Zoom Punch, `awi18.transform` Transform (Effect), `awi.swing` Swing, `awi.oscillate` Oscillate, `awi.pulse` Pulse, `awi.spin` Spin, `awi.bounce` Bounce, `awi.jitter` Random Jitter\n\n## stylize\n`awi.rgbSplit` RGB Split, `awi10.bevelAlpha` Bevel Alpha, `awi10.smoothBevel` Smooth Bevel+, `awi10.bumpMap` Bump Map, `awi10.chrome` Chrome Metal, `awi10.gold` Gold Text, `awi10.glass` Glass Material, `awi10.edgeAO` Edge Occlusion, `awi10.innerShadow` Inner Shadow, `awi10.embossColor` Emboss Color, `awi10.neonTubes` Neon Tubes, `awi11.blink` Blink, `awi11.pulseOpacity` Pulse Opacity, `awi11.randomDissolve` Random Dissolve, `awi11.vignetteAlpha` Vignette Alpha, `awi11.linearAlphaFade` Linear Alpha Fade, `awi11.opacityFlicker` Opacity Flicker, `awi13.filmBurn` Film Burn, `awi13.lightDamage` Light Damage Frames, `awi13.gateWeave` Gate Weave, `awi13.superEight` Super 8, `awi13.instantPhoto` Instant Photo, `awi13.jpegArtifacts` JPEG Artifacts, `awi13.bitCrush` Bit Crush, `awi13.teletext` Teletext Mosaic, `awi13.thermalPrinter` Thermal Printer, `awi13.risograph` Risograph, `awi13.screenPrint` Screen Print, `awi13.ledScreen` LED Screen, `awi13.lcdSubpixels` LCD Subpixels, `awi13.hologramScan` Hologram Scan, `awi13.analogTV` Analog TV, `awi13.neonSign` Neon Sign, `awi15.prismGlow` Prism Glow, `awi15.dreamBloom` Dream Bloom, `awi15.softGlow` Soft Glow, `awi15.darkGlow` Dark Glow, `awi15.hueGlow` Glow Threshold Color, `awi15.neonBloom` Neon Bloom, `awi15.starglow` Starglow, `awi15.lightWrap` Light Wrap, `awi15.diffusion` Diffusion Filter, `awi16.animeShading` Anime Shading, `awi16.mangaScreentone` Manga Screentone, `awi16.mangaSpeedHatch` Manga Speed Hatch, `awi16.cartoonOutline` Cartoon Outline, `awi16.contourLines` Contour Lines, `awi16.contourGradient` Contour Gradient, `awi16.edgeColorize` Edge Colorize, `awi16.electricEdges` Electric Edges, `awi16.glowScan` Glow Scan, `awi16.halftoneLines` Halftone Lines, `awi16.crossHatch` Cross Hatch, `awi16.stipple` Stipple, `awi16.charcoal` Charcoal, `awi16.chalkboard` Chalkboard, `awi16.blueprint` Blueprint, `awi16.neonOutlineArt` Neon Outline Art, `awi16.stainedGlass` Stained Glass, `awi16.pixelArt` Pixel Art, `awi16.lowPoly` Low Poly, `awi16.asciiArt` ASCII Art, `awi16.paperTexture` Paper Texture, `awi16.tornEdges` Torn Edges, `awi16.woodcut` Woodcut, `awi16.graffitiSpray` Graffiti Spray, `awi16.glitchColorBands` Glitch Art Color Bands, `awi18.twitch` Twitch Glitch, `awi18.negativeFlash` Negative Flash, `awi18.scanTear` Scanline Tear, `awi18.waveGlitch` Wave Glitch, `awi18.blockShuffle` Block Shuffle, `awi18.channelSmear` Channel Smear, `ae.posterize` Posterize, `ae.threshold` Threshold, `ae.findEdges` Find Edges, `ae.mosaic` Mosaic, `awi.halftone` Halftone, `awi.crt` CRT / Scanlines, `awi.manga` AWI Manga FX, `awi.impactFrame` AWI Impact Frame, `awi.glitch` AWI Glitch, `awi.vhs` AWI VHS, `awi.pixelSort` AWI Pixel Sort, `ae.emboss` Emboss, `ae.roughenEdges` Roughen Edges, `ae.scatter` Scatter, `ae.strobe` Strobe Light, `cc.kaleida` Kaleida, `ae.dropShadow` Drop Shadow, `awi.outlineGlow` Outline Glow, `awi.energyAura` Energy Aura, `awi.outerGlow` Outer Glow, `awi.innerGlow` Inner Glow, `awi.border` Border, `awi.neonStroke` Neon Stroke, `awi.chromaticAberration` Chromatic Aberration, `awi.oldFilm` Old Film, `awi.inkSketch` Ink Sketch, `awi.retroDither` Retro Dither, `awi6.glitchBlocks` Glitch Blocks, `awi6.glitchLines` Glitch Lines, `awi6.digitalNoise` Digital Noise Glitch, `awi6.datamosh` Datamosh Smear, `awi6.pixelStretch` Pixel Stretch, `awi6.interference` Signal Interference, `awi6.scanDistort` Scan Distort, `awi8.celShading` Cel Shading, `awi8.oilPaint` Oil Paint, `awi8.watercolor` Watercolor, `awi8.pencilSketch` Pencil Sketch, `awi8.cmykHalftone` Comic Halftone CMYK, `awi8.mosaicTiles` Mosaic Tiles, `awi8.crystallize` Crystallize, `awi8.pointillism` Pointillism, `awi8.longShadow` Long Shadow\n","style":"# Style study: the user's reference edits\n\nFour manga / anime edits the user (Awiliao) likes, studied frame by frame (cut times detected automatically at\n30 fps). This is a taste profile: it shows what this world of editing values. Don't replay it; use it to understand\nthe language and make your own choices for each new edit.\n\n## What these edits have in common\n- **Fast, beat-locked cutting.** Long holds (1-4 s) on build-ups, then bursts of cuts 2-3 frames apart on the drop\n  (one edit had ~14 cuts between 12.9 s and 13.9 s, i.e. a 1-3 frame strobe).\n- **Every cut is \"covered\":** white flash, color-inverted flash, zoom-blur smear, or a glitch frame. Clean straight\n  cuts are rare.\n- **Hits = flash + zoom punch + shake together** on the same frame, then settle over 6-10 frames.\n- **Cutout characters** sit over moved / blurred backgrounds (parallax), often with a soft drop shadow.\n- **Debris and particles** (dark chunks, sparks) drifting across the frame during action.\n- **Creator watermark** as glowing text, low in frame, present the whole edit.\n- **Contrast is pushed hard**; manga panels stay black & white with **one accent color** (cyan eyes, yellow eyes,\n  gold hair, green energy).\n\n## Per edit\n1. **Chibi / manga intro (\"WHO WILL BE THE MOG\")**: B&W manga, gray gradient background.\n   - Opener: yellow hand-drawn style text that types in word by word with a smear (scramble / blur in).\n   - Chibi heads pop in one by one (scale pop with bounce), then a panel split (slanted white border) reveals the\n     main character.\n   - **Full-frame color tints as hits:** a cyan wash, then an orange wash, 1-2 frames each.\n   - Name captions glow on the reveal; eye glow on the character (selective color: cyan / yellow eyes, rest gray).\n2. **haikoxpp (colored anime)**: clean anime clips, warm grade.\n   - Object glow (green gem) added as an overlay with glow.\n   - **Game-UI gag:** pixel-shatter glitch into a \"You died / Respawn\" screen, desaturated.\n   - Red halftone flash frame before the shatter.\n   - White-out flash into a high-contrast mono frame, then a hard cut to a green-lit corridor.\n   - Ends on a character with chains (impact pose).\n3. **xgokuponchx (heavy FX manga)**: the most effect-dense.\n   - **Rainbow / chromatic distortion** frames (lens warp, prismatic edges), color-inverted psychedelic hits\n     (magenta / green / orange), pixel-sort smears.\n   - Manga panel in gray with film grain; letterbox bars.\n   - Gold hair with glint; eye close-ups with speed-lines / light streaks.\n   - Lens-flare sunburst behind the character with flying rocks.\n   - Glowing watermark \"GOKUPONCH\".\n4. **gokuponch (colored manga, Goku & Broly)**:\n   - Title card on white: bold title \"GOKU AND BROLY\" + subtitle, colored stripes (green / cyan) sliding in\n     behind the cutout fighters, debris flying.\n   - Then zoom-blur transition into colored panels, a white radial flash (circle), and rapid zoom punches between\n     close-ups with motion blur.\n   - Sun flare and glints on impacts.\n\n## Ways to get these looks in AWIeffect (one option each, not the only way)\n| Look | AWIeffect pieces |\n|---|---|\n| Hit (flash + punch + shake) | white Solid 2-4 frames, opacity 100→0 (expoOut) + `awi18.zoomPunch` or scale keys 100→115→100 (backOut) + `awi18.shakePro` mode Impact Hits |\n| Strobe on the drop | split the clip every 2-3 frames; alternate `ae.invert` / Negative Flash `awi18.negativeFlash` on every other piece |\n| Color-wash hit | Solid in cyan / orange, blend Color or Screen, 1-2 frames |\n| Cutout character | Remove BG (cutoutSubject action) or Individual Chroma Key on a copy; drop shadow `ae.dropShadow` |\n| Selective color eyes / hair | duplicate layer → `awi19.colorSelect` (Individual Chroma Key) on the eye color → `awi.deepGlow`; base layer `ae.blackWhite` (desaturate) |\n| Rainbow distortion | `awi18.warpChroma` + `awi19.chromaShatter` / `awi19.pixelSort` on 1-3 frames |\n| Pixel shatter / game glitch | `awi19.blockCorrupt` + `awi19.signalLoss` + `awi19.flash` burst |\n| Zoom-blur transition | `ae.radialBlur` (zoom) keyed up over 3-4 frames + scale 100→140, next clip starts blurred → sharp |\n| Debris | Particles layer (sprite chunks), gravity on, short life |\n| Watermark | Text layer, fontSize ~6% of height, `awi.outerGlow`, low center, full length |\n| Letterbox | two black Solids top / bottom |\n| Grain on manga | `ae.noise` small amount + contrast up |\n"});
const FULL_SKILL_TOPICS = Object.freeze({
  index:["main"], core:["main","craft"], all:["main","craft","pro","effects","style"],
  manga:["main","craft","pro","style"], anime:["main","craft","pro","style"],
  "art-studio":["main","craft","pro"], art:["main","craft","pro"],
  cutout:["main","craft","pro"], background:["main","craft"], masks:["main","craft"],
  rigging:["main","pro"], bones:["main","pro"], effects:["effects","craft"],
  animation:["craft","pro"], velocity:["craft","pro"], audio:["craft","pro"],
  typography:["main","pro"], color:["craft","pro"], glow:["effects","craft"], style:["style","pro"]
});
function readFullEditingSkill(p={}) {
  const action=p.action||"index";
  const policy=[
    "Use real AWIeffect native editor operations and user-supplied artwork. No generic AI image generation, automated manga coloring or random placeholder graphics.",
    "Use native subject/background removal only when requested; it is different from AI artwork generation.",
    "Inspect live app capabilities and effect parameter ranges before editing; preserve unrelated project data.",
    "Private app Settings, accounts and pairing/relay keys are not editable."
  ];
  if(action==="index")return {version:"full-uploaded-editor-skill",policy,topics:Object.keys(FULL_SKILL_TOPICS),
    sources:Object.fromEntries(Object.entries(FULL_SKILLS).map(([k,v])=>[k,{characters:v.length,firstLine:v.split("\n")[0]}]))};
  if(action==="search"){
    const needle=String(p.query||"").trim().toLowerCase();
    if(!needle)return {error:"query required for search"};
    const out=[],limit=Math.min(50,Math.max(1,Number(p.limit)||15));
    for(const [name,document] of Object.entries(FULL_SKILLS)){
      let lines=document.split("\n");
      for(let i=0;i<lines.length;i++)if(lines[i].toLowerCase().includes(needle)){
        out.push({source:name,line:i+1,context:lines.slice(Math.max(0,i-2),i+3).join("\n")});
        if(out.length>=limit)break;
      }if(out.length>=limit)break;
    }
    return {query:needle,matches:out};
  }
  if(action==="read"||action==="get"){
    const sources=FULL_SKILL_TOPICS[String(p.topic||"core").toLowerCase()]||
      (FULL_SKILLS[p.topic]?[p.topic]:["main"]);
    const document=sources.map(k=>"# SOURCE "+k+"\n"+FULL_SKILLS[k]).join("\n\n");
    const offset=Math.max(0,Math.floor(Number(p.offset)||0)),
      max=Math.min(32000,Math.max(1000,Number(p.maxChars)||15000));
    return {topic:p.topic||"core",sources,policy,content:document.slice(offset,offset+max),
      offset,totalCharacters:document.length,nextOffset:offset+max<document.length?offset+max:null};
  }
  return {error:"unknown skill action",valid:["index","read","search"]};
}
const SKILL_TOOL = {
 name:"editing_skills",description:"Complete indexed original AWIeffect skill with native editing techniques, effects, real Art Studio, manga, velocity, color, mask/cutout and rigging guides. No generic AI coloring. action=index|read|search; topic/search/offset options.",
 inputSchema:{type:"object",properties:{
   action:{type:"string",enum:["index","read","search"]},topic:{type:"string"},
   query:{type:"string"},offset:{type:"integer",minimum:0},
   maxChars:{type:"integer",minimum:1000,maximum:32000},
   limit:{type:"integer",minimum:1,maximum:50}
 }}
};

const UNIFIED_TOOL = {
  name: "editor_function",
  description: "Full native AWIeffect iPhone editing controller. Main editing tool for layers, effects, masks, shapes, timelines, groups/precomps, rig/bones, weights, cutouts and rendering. FIRST call action='guide', topic='core' and the task-specific topic. Then action='discover' for supported native commands, action='call' with a command + args, or action='batch' for sequential edits. No AI coloring or generative-graphics shortcuts. Settings/keys are private.",
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
  draw_operations: { method:"POST", path:"/draw/operations", description:"Native Art Studio selections/fill/undo/erase/flip in a single persisted operation; args {layer?,operations:[{name,point?,points?,tolerance?}]}." },
  background_remove: { method:"POST", path:"/action", description:"Native background cutout shortcut; args {name:'cutoutSubject',layer,mode:'object'}." },
  get_editor_capabilities: { method: "GET", path: "/editor/capabilities",
    description: "Supported native rig commands and layer-patch whitelist; no app Settings" },
  group: { method: "POST", path: "/editor/group",
    description: "Native grouping; args {command: create|ungroup|duplicate, layers?:[UUID], group?:UUID}" },
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
    if (name === "background.remove") return this.runNativeCommand("run_action",{name:"cutoutSubject",layer:args.layer,mode:args.mode || "object"});
    if (name === "art_studio.strokes") return this.runNativeCommand("draw_strokes",args);
    if (name === "art_studio.layer") return this.runNativeCommand("edit_drawing_layer",args);
    if (name === "art_studio.operations") return this.runNativeCommand("draw_operations",args);
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
    if (action === "guide") return toolText(id, JSON.stringify(readFullEditingSkill({action:"read",topic:p.topic||"core"})), false);
    if (action === "discover") {
      const legacy = TOOLS
        .map(({name,description,inputSchema}) => ({name,description,inputSchema}));
      const advanced = Object.entries(ADVANCED_COMMANDS).map(([name,v]) => ({name,description:v.description}));
      const rig = RIG_COMMANDS.map(name => ({name:"rig."+name,description:"Native Rig / Bone & Weight operation",args:"See guide topic=rig and get_editor_capabilities"}));
      const data = {oneTool:"use_awieffect", build:"Build 29 native + Build 30 unified connector",
        commands:[...advanced,...rig,...legacy,{name:"background.remove",description:"Native subject/background cutout from existing /action endpoint"},{name:"art_studio.strokes"},{name:"art_studio.layer"},{name:"art_studio.operations"}], guideTopics:Object.keys(FULL_SKILL_TOPICS),
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
          instructions: "Use editor_function for all native editing and editing_skills for the original full indexed ZIP knowledge. Start editor_function action=status/discover and editing_skills action=index/read.  Start with action=guide topic=core and the relevant editing topic; inspect get_info, get_catalog and get_project before making changes. Favor native rig/mask/FX operations. Do not auto-generate manga coloring or generic shapes; only edit assets. Settings, relay keys and pairing secrets are private. Render and review the result.",
        } };
      case "ping": return { jsonrpc: "2.0", id, result: {} };
      case "tools/list":
        return { jsonrpc: "2.0", id, result: { tools: [UNIFIED_TOOL, SKILL_TOOL] } };
      case "tools/call": {
        if (params?.name === "editor_function" || params?.name === "use_awieffect") return this.useAwieffect(id, params.arguments || {});
        if (params?.name === "editing_skills") return toolText(id, JSON.stringify(readFullEditingSkill(params.arguments || {})));
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
