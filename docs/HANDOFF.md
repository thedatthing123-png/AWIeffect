# AWIeffect — handoff (Claude → Codex), 2026-11-07

Latest priority update (2026-11-08): read [JOINT_RIG_RECOVERY_HANDOFF.md](JOINT_RIG_RECOVERY_HANDOFF.md) before more rig work. Build 25 is published and passed CI, but the owner reports a floating image piece and confusing setup. Joint/Puppet precision movement and coherent attachment/conflict handling are the immediate repair; weighted mesh work is deferred on its separate branch.

Read this, AGENTS.md, ROADMAP.md, docs/RENEWAL_PLAN.md and docs/TEXT_STUDIO_SPEC.md before touching code. Then docs/EXPANSION_PLAN.md for everything after the renewal.

## The owner and how to work
- One professional manga/AMV editor, phone only. AWIeffect replaces After Effects, Alight Motion, Ibis Paint and Blender for their own work (not a public release). They write casually with typos — read intent.
- Real editing, not button clicking: every value scrubbable + tap-to-type, keyframe diamonds, on-canvas handles, the swipe pad, graph easing. Presets unpack into editable parts.
- Never cramped: ≤ 3 controls per row, 44 pt tap targets, no truncation, no overlaps, no duplicate controls.
- Design every effect/preset with intent and judge it by eye on rendered sheets (not only "it animates" tests). Fewer strong beats many weak. Half the old effects were bad because they were added, not designed.
- References (AE/AM/etc.) illustrate an idea; design it our way. Copy exactly only when they say "copy it / exactly like that".
- Controls must feel steady: not too fast, not too slow, no flinging acceleration.
- 60 fps+ effects (preview may be lower), export always at project fps.
- Saved projects must keep opening (new fields Optional / decodeIfPresent). One undo step per action.
- Finish fully before sending a build; find gaps yourself. Never delete user projects; never change AI Link settings.
- Commits end with: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (Codex: use your own trailer).

## Build / CI
- Swift / SwiftUI / Metal, XcodeGen (`project.yml`, CURRENT_PROJECT_VERSION is the build number; currently "20").
- No local Xcode (Windows). Build on GitHub Actions: `gh workflow run build.yml --ref <branch> -f validation=all|quick|audit` (quick = no tests).
  A new push cancels the running run on the same branch.
- Artifacts: `test-results` (test-summary.json, test.log), `AWIeffect-ipa`, `ui-screenshots` (includes text-preset-sheet.jpg), `contact-sheet` (every effect rendered).
- Common compile traps: `@MainActor` for non-View types touching EditorState; overlapping inout access (copy to a local first);
  the app has its own `TimelineView` (use `SwiftUI.TimelineView`); Metal fast-math `tanh` of big values = NaN (clamp args);
  static `let`s that read each other during init (startup crash); every Metal kernel must be listed in `EffectGPU.init` (EffectRegistry.swift).
- Test `EffectTests.testEveryNumericControlIsWired` stops at the first unwired slider; controls that only act in a mode go in its `modal` set.

## Branches
- Working branch: **feat/effects-remake** (everything below is on it). `main` is still at Build 7 — nothing merged to main yet.
- Earlier chain (all merged into effects-remake): animation-timing-validation → art-studio-renew → cutout-studio → 3d-renew → motion-blur → 3d-viewport.

## What was done since the Codex handoff (Builds 10 → 20)
- Build 10–12: animation timing fixes; **Art Studio** renewed (stroke engine, smudge/blur, selection, transform, brush library, pen paths, layers, live filters).
- Build 13: **Cutout Studio** (manual + auto matte baking).
- Build 14–17: **3D renewal** (models through the scene camera/lights, lens presets, focus, materials/glow, model animation, masks on models, viewport gizmo, 3D motion path); **motion blur** rebuilt (shutter angle/phase, camera blur, no see-through); effect paste keeps keyframes relative; multi-color keyframe focus; Transform offset cap.
- Build 18: **Effects remake** of ~120 effects across every section, built on shared engines:
  Effects24 (glitch engine fxGX, inner glow, paint/Kuwahara), Effects25 (light engine: threshold + core/halo, hue-keeping), Effects26 (blur/shake),
  Effects27 (print/ink/film/glitch), Effects28 (distort AA + edge modes, transitions easing), Effects29 (fractal noise, clouds/fire/smoke, particles depth, keyers, color).
  Stuck-slider fix (scroll cancelling a drag left edits in the live copy).
- Build 19: Motion Tile seam fix; AM-style **pen tool** (cursor + swipe pad, unlimited points); noise/grain refresh every frame (60 fps+); weak effect defaults retuned.
- Build 20: **Text Studio renewal** (spec: docs/TEXT_STUDIO_SPEC.md):
  engine (no clipping, stable character ids, style stack fills/strokes/shadows/glow, real per-letter 3D, multiple selectors incl. random/beat, new properties, letter effects, paragraph box/vertical, color emoji);
  real 3D text (Text3DMesh/Text3DRenderer, bevels, per-part materials, environment); captions & lyrics (on-device transcription, karaoke highlights);
  new Studio UI (Style/Animate/Presets/3D tabs, on-canvas caret + letter selection + drag, selector strip, graph editor for text properties and selector timing);
  preset system (presets add on top as removable groups, live previews). **Decision:** the big new preset library was removed for now — current presets kept;
  the full designed library (text animators combined with the new effects) comes after the effects expansion.
- After Build 20 (committed, not yet sent as an app):
  - **Full-app audit** → docs/RENEWAL_PLAN.md.
  - **Bug batch** (all fixed, 519 tests passing): undo inside groups, group split/trim, trims past media, key moves never delete keys,
    real Copy/Paste Keys, Recently Deleted (30 days), safe Restore Version, export estimate, root comp for frame/range/AI Link inside groups,
    streamed video import, clip panel duplicates, pivot/scale/rotate for parented/3D/camera layers, Motion Sketch, motion path, IK (FK/IK blend),
    mask placement/outline, free-view hit-tests, Z diamond, linked scale, physics for parented layers, CC histogram, color-picker undo, curve x,
    looks stored in project, presets don't stack, Border/Shadow switch, Art Studio eyedropper.
  - **Steadier controls** (commit e7dfecd): ValueScrubber travel = min(span, max(min(span,150), |value|·1.5)) per bar width, no acceleration;
    NumberField ½ step/pt; SwipePad and rulers capped (1.2× / 1.3×); trackball 0.4°/pt. Fixes Deep Glow radius flying and imprecise vector points.

## In flight right now (renewal batches, worktrees under .claude/worktrees/, NOT merged yet)
Each is a branch based on 73d4991. Merge into feat/effects-remake, then build, fix compile errors, check UI screenshots.
- **R1 timeline** — `worktree-agent-a007f2cba8c2e3add` @ 281e426 — DONE: property lanes, marquee/multi-select keys + stretch/reverse,
  value/speed graph, ripple delete/close gap/slip/multi-clip move, named markers + frame numbers, transport 7 controls + More menu,
  eye/lock/solo, expression pick-whip + live errors, history timestamps.
  Watch: row header now 132 pt wide (may squeeze the timeline on a 375 pt phone — slim it if screenshots show it).
- **R2 canvas** — `worktree-agent-a2336a1dcb7195100` @ 62b8124 (+ maybe a newer commit) — DONE part 1: mask point editing (add/delete/handles/corner/broken, move/scale/rotate whole mask, feather/opacity/expansion keys), pen corners/insert, shape operator cards with keyframes + Round Corners + Twist, Trim Paths keys.
  Was continuing: motion path handles + orient along path, snapping/guides/align/distribute, tap-cycle + marquee select, camera POI + light gizmo, Position tool cleanup + tap-a-layer picking, bone overlay. Skip Merge Paths (model has one path per shape).
- **R3 media** — `worktree-agent-a556ed80c735e8153` @ a11f858 — DONE: trim start/end/slip, speed curve presets, freeze frame, Twixtor scrubber,
  waveform + fade handles/shapes, volume keyframes, audio FX (EQ, low/high cut, compressor, pitch, ducking), editable beat markers + BPM grid,
  ProRes/PNG sequence/audio-only export, platform presets, custom range, quality scrubber, frame export options, project search/sort/select,
  named versions with thumbnails, Settings (defaults, autosave interval, storage, backup/restore).
  Not done: media bin + relink, project folders, work area, denoise, keep-pitch under a speed curve.
- **R4 color/effects UI** — `worktree-agent-a37fdfe8d7923a43b` @ b21ba85 (+ maybe a newer commit) — DONE part 1: CC Studio renewal
  (wheels with pucks + luminance ring incl. Offset, curves up to 6 points, hue-vs-hue/sat/lum + luma-vs-sat, HSL qualifier + show mask,
  histogram/waveform/parade/vectorscope, bypass, A/B, white-balance eyedropper, built-in LUT looks), effect card targets 44 pt, collapse all, FFX in a menu.
  Was continuing: drag-reorder effects, per-effect Mix/Solo (renderer), keyframable toggles, angle revolutions, point param crosshair, user effect-stack presets,
  gradient fill, layer styles (inner shadow, glows, gradient overlay, stroke position), compact blend picker, track matte from any layer,
  particles emitter handle / color over life / burst / floor collide.

These branches are also pushed to GitHub as `renewal/<id>` (e.g. `origin/renewal/a007f2cba8c2e3add`); if the R2/R4 work continued after
2026-11-07 the newest commits may only be local — push again from `.claude/worktrees/`.
To merge: `git merge --no-edit worktree-agent-<id>` (or `origin/renewal/<id>`) for each (check `git -C .claude/worktrees/agent-<id> log --oneline -3` for the latest commit first), push, run CI, fix errors.

## Open decisions / notes
- Motion Sketch currently clears position keys after the sketched range (AE keeps them) — ask the owner which they want.
- Canvas handles are lighter on small layers (short text stays visible).

## Next, in order (ROADMAP.md)
1. Finish + merge R1–R4, build, check screens, send the app.
2. **Effects expansion** to 600+, designed (not filler): glitch pack 30+ each with its own design and Smooth/Choppy/Burst motion options (AWI Glitch and Glitch Blocks currently share the engine — make them distinct),
   big families for Text, Glitch, Key & Matte, etc.; Fractal Ridges (match AE Motion exactly — inspect its code), Pixel Blur (custom), Hot Color, Topaz-style upscale (press to process, then baked), Echo-style tools.
   Skip AE Motion "combo" effects (effect + baked overlay).
3. **New preset system** after the expansion, including the full text preset library that combines text animators WITH the new effects (normal editable controls, not a single-knob wrapper).
4. Rigging pass, remaining audit items (media bin/relink, folders, work area, denoise), layer folders in Art Studio, Cutout Studio canvas zoom.
5. Final performance pass (build on the precomp pre-render; never crash).
6. Train/integrate SAM 2 for cutouts after the app is done. Make the repo private when the app is done.
