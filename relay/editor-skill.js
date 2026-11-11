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
