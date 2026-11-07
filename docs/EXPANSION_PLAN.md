# AWIeffect: the plan after the renewal (for Codex)

Written 2026-11-07 by Claude with the owner. This is the agreed plan for everything after the old-feature renewal (Build 21).
Read first: `AGENTS.md`, `docs/HANDOFF.md` (rules, CI, compile traps), `ROADMAP.md`, then this file.
Where this file and an older doc disagree, this file and the owner's latest messages win.

## 0. Who it's for and what "good" means

- The owner (Awiliao) is one professional manga/AMV/MMV editor who works **only on a phone**. AWIeffect is their
  "editing app where I can make anything": drawing, motion design, custom animation, AMV, manga edits, 3D. It replaces
  After Effects, Alight Motion, Ibis Paint and Blender for their own work.
- It is **one editing app** (layers, text, effects) where the editor crafts the look. Do **not** add "style sections",
  style modes or one-tap "make it a phonk edit" features. Give strong building blocks; the editor stacks them.
- An edit made on an older build was already called "looks like After Effects" by another editor. The bar now is:
  every effect is something a real editor would reach for and that looks right at first try.
- The owner writes casually with typos. Read intent. Talk like a collaborator: honest, with opinions, not obedient
  restatements. When they ask for thoughts, give opinions, not an implementation.

## 1. Order of work (agreed)

1. **Shape-layer rebuild**: multi-path shapes and Merge Paths. Section 3.
2. **Effects expansion**: the big last piece. Sections 4 to 8.
3. **Preset system**, including text presets that combine text animators with the new effects. Section 9.
4. **Final performance pass**. Section 10.

Don't start a later step before the earlier one is built, tested and judged on rendered sheets.

## 2. Rules that apply to every change

- **Real editing controls**: every number can be scrubbed and tapped to type a value, every control can take keyframes, and on-canvas
  handles are used where the value is a position, size or angle. Presets unpack into editable layers and effects.
- **Never cramped**: at most 3 controls per row, 44 pt tap targets, no truncated labels, no overlaps, no duplicate controls.
  Check the `ui-screenshots` artifact after every UI change.
- **Steady controls**: not too fast, not too slow, no flinging. Use `ValueScrubber` (travel formula
  `travel = min(span, max(min(span,150), |value|*1.5))`, gain 0.4 slow / 0.8 normal). Never write a new slider widget.
- **60 fps+** in preview for normal comps on an iPhone 16 Pro Max; export always runs at project fps. Noise, grain and
  random patterns must change every frame unless a "Hold" or "Random seed" control says otherwise.
- **Old projects keep opening**: new model fields are Optional or use `decodeIfPresent`; new effect params fall back to the
  definition default (see the `v29` / `b29` helper pattern in `EffectRegistry29.swift`). Never rename an existing
  effect id or param id. Each user action is one undo step.
- **References illustrate an idea.** AE, Alight Motion and AE Motion (`Downloads/AE Motion 2.5.ipa`, ~560 effects) may be
  inspected for behavior and parameter ranges, but write your own shaders. Copy behavior exactly only where this file says
  "exactly" (Fractal Ridges). Never paste proprietary or GPL code.
- **Design every effect with intent**: judge it by eye on the contact sheet and a moving render, not only by "the test passes".
  Ten strong effects beat fifty weak ones. Half the old effects were bad because they were added instead of designed.
- Never delete the owner's projects. Never change AI Link settings. Commits end with your own co-author trailer.
- Use the build number in `project.yml` (`CURRENT_PROJECT_VERSION`); bump it once per build you send.

## 3. Shape-layer rebuild (do first)

Today a shape layer holds one path. The owner needs AE-style shape layers. Read `App/Model/ShapeOps.swift`,
`App/UI/PenTool.swift` (AM-style pen: cursor + swipe pad, unlimited points, select and move) and the shape renderer first.

- **Multiple paths per shape layer**, each with its own fill/stroke on or off, order, name, transform and visibility. Old single-path
  layers decode as a layer with one path.
- **Merge Paths**: Add, Subtract, Intersect, Exclude (XOR), Merge. It applies to the paths above it in the stack (AE semantics).
  Booleans need a real polygon clipper on flattened Bézier paths (write your own or use a permissively licensed one such as Clipper2, Boost licence, and credit it).
- The existing operators (`ShapeOps`: pucker, round corners, offset, zigzag, twist, wiggle, repeater) can be placed
  per path or for the whole group, and they stay reorderable (`move(_:by:)` is one step only).
- Trim Paths per path, with Simultaneous and Individually modes. A gradient fill or stroke per path.
- UI: a path list inside Edit Shape (rows ≥ 44 pt, drag to reorder, tap to select, the pen edits the selected path). On canvas,
  only the selected path's points show.
- Tests: decoding an old project, the area results of each boolean, and the operator order. A contact-sheet render of a 3-path logo.

## 4. Effects expansion: the vision

- **The effect count is the app's limit right now.** Aim for roughly **1,000 usable effects**. The number is *not* a target;
  "usable" means each one does its job cleanly and is worth picking. It may end above 1,000.
- **Mix of simple, weird and complex.** Simple building blocks (a clean one-job effect) matter as much as big designed
  families, because stacking simple things is how editors build crazy looks. "Broken-looking" or odd effects are welcome:
  editors cheese them.
- **Designed composite families are wanted** (plugin-maker style): several looks built together as one effect with
  its own controls, e.g. sun rays + light wrap + glow as one designed "light" effect, or a custom glitch with its own motion styles.
- **Skip only AE Motion's baked-texture combos** (a simple effect with a bitmap overlay baked in, e.g. ripple + light texture).
  The editor can stack those looks themself.
- **No "rotation shapes"** (the owner dislikes them).
- Every new effect has: a clear name an editor would say out loud (no AI-sounding names like "Ethereal Prism Cascade"),
  sensible defaults that already look good, a Blend / Effect-only control where it makes sense, and full keyframing.

## 5. Browser reorganization

The browser has 10 categories today (`EffectCategory` in `App/Model/Effects.swift`). Reorganize freely and **add
sections**. Some things are misfiled; for example, the 3D shapes are in the wrong place. Proposed set (adjust if a better split shows up while building):

| Section | What lives there |
|---|---|
| Blur & Sharpen | blurs, sharpen, detail, denoise, Pixel Blur |
| Color & Light | grading ops, glows, light, exposure (looks/LUT-type color stays in CC Studio, see ROADMAP 12) |
| Glow & Light FX | Deep Glow, light sweeps, rays, flares, sunbursts, rim light, light wrap |
| Stylize | ink, halftone, posterize, paint, toon, outlines |
| Distort & Warp | waves, bends, displacements, lens, bulge, twirl |
| **Liquid** (new) | liquid, melt, drip, ink-in-water, gooey, wave-warp-in-motion |
| Glitch | the glitch pack (section 7) |
| Backgrounds (new) | animated backgrounds, patterns, solid sunburst, gradients, grids, sky/space |
| Procedural / Noise | fractal noise, Fractal Ridges, cells, turbulence, clouds, fire, smoke |
| Particles | emitters, dust, sparks, debris, snow, bokeh |
| Shapes (new) | generated shapes, rings, stars, bursts, speed lines, frames, 3D shapes (move them here) |
| Key & Matte | keyers, chokers, alpha tools, Unmult, matte from luma/color/edges |
| Move & Transform | transform, shakes, wiggle, motion tile, mirror, kaleido, camera-ish moves |
| Time | echo, posterize time, time slice, frame blend, stutter, datamosh-time |
| Transitions | wipes, zooms, slides, glitch cuts, liquid/ink transitions, shape reveals |
| Text | per-letter effects, type glitch, outline type, text fills |
| Retro & Film | VHS, film, CRT, print, scan, grain |
| 3D | 3D-looking effects (extrude, bevel, depth, cards) |

Rules: an effect lives in **one** section; search finds every effect by name and by a few tags; the browser shows a
small live thumbnail per effect (reuse the contact-sheet renderer). Moving an effect to another section never changes its id.

## 6. Must-have specific effects (owner asked by name)

- **Solid sunburst / "candy" starburst**: radial solid wedges (no rays, no light), like AE Motion's version. Inspect it.
  Controls: wedge count, two or more colors, wedge width ratio, rotation + speed, center (on-canvas point), twist, softness of edges,
  an optional radial fade. A separate effect next to today's light Sunburst, in Backgrounds.
- **Fractal Ridges**: match AE Motion's **exactly** (behavior, parameters, ranges, defaults). Inspect its implementation
  for behavior, then write our own shader. Render ours side by side against AE Motion at the same settings and check by eye.
- **Pixel Blur**: a blocky pixelated blur (pixelate the blurred result, or blur in a pixel grid, with controls for block size and blur amount).
  If AE/AM have nothing like it, design it to the owner's description and show it to them.
- **Hot Color**: inspect how AE Motion does it during the expansion, then build ours.
- **Unmult**: brightness → alpha so overlays on black composite with normal blending, keeping the light solid.
- **Topaz-style upscale**: not a live effect. An on-device Core ML step that is baked to a processed clip (research licensed
  models such as Real-ESRGAN with a compatible licence). Put it in the clip menu, not the effect browser.
- **Glitch pack 30+**: section 7.
- Also from the roadmap: Halftone family remake, Inner Glow fixes, a real Time Slice.

## 7. Glitch pack (30+, each distinct)

The owner's complaint: the old glitches all looked alike. Every glitch must have a **different visual idea**, and most need
**motion style options**: Smooth (continuous drift), Choppy (held frames, anime-style), Burst (quiet → hit → quiet with
Frequency/Duration), and On Keyframe (only where a key says). Ideas to design from (don't treat as a fixed list):
slice shift, RGB split with directional smear, block corruption, datamosh/pixel bleed using the existing optical flow,
pixel sort (by luma/hue, threshold, direction), JPEG/macroblock crush, scanline roll, VHS tracking, signal loss to
noise, interlace tear, digital stutter (repeat frames), mirror tear, slit-scan, chroma shatter, bad-codec color banding,
wave line distortion, screen tear with offset, glitch flash (white/inverse frames), bit-depth crush, channel swap,
row duplicate, column melt, grid displacement, CRT roll, analog noise bars, zoom glitch, text-shaped glitch blocks,
twitch, warp chroma, ghost trails, data rain.
Build them on the existing glitch engine (`fxGX` in `Effects24.metal`) where it fits, so they share quality and speed.

## 8. How to add effects (the actual mechanics)

1. **A batch = one Swift registry file + one Metal file**: e.g. `App/Render/EffectRegistry30.swift` + `App/Render/Effects30.metal`.
   Ids use a batch prefix, e.g. `awi30.solidSunburst`. Metal kernel names carry a per-batch suffix (`fxSunburst30`) so
   parallel batches never collide.
2. **Register the definitions** by appending your batch array to `EffectRegistry.all` (`App/Render/EffectRegistry.swift`,
   the `+ batch2 + … + batchR4` chain).
3. **Register every kernel name** in the list in `EffectGPU.init` (same file, the long `for name in [...]` list). A missing
   name compiles fine and fails at runtime.
4. **Param defaults with fallback**: copy the `v29/b29/ch29/rgba29` helper pattern so instances saved before a param existed
   still render.
5. Point params get an on-canvas handle automatically through `ParamKind.point`; angle params use `.angle`.
6. **Tests that must pass** (`Tests/EffectTests.swift`):
   - every effect makes a visible change with its defaults;
   - `testEveryNumericControlIsWired`: every numeric control changes the image at t = 0.4. Controls that only act in a
     certain mode (a cycle length that only applies with Cycle on, extra curve points that are off by default, hue-specific controls)
     go in the `modal` set **with a comment saying why**. Don't hide real bugs there.
   - effects that only change alpha edges go in `EffectRegistry.alphaShaped`;
   - the `contact-sheet` artifact renders every effect: look at it.
7. Metal traps: fast-math `tanh` of big values returns NaN (clamp the argument); premultiplied alpha in and out; sample with
   edge modes (repeat / mirror / transparent) where it makes sense; no per-pixel loops over large radii without a separable or
   downsampled pass (60 fps rule).
8. Compile traps (see HANDOFF): `@MainActor` on non-View types that touch `EditorState`; SwiftUI `Canvas` closures can't call
   main-actor code, so compute values before the Canvas; copy to a local before overlapping inout access; use `SwiftUI.TimelineView`;
   static lets must not read each other during init; switches must be exhaustive.
9. **Batches in parallel**: several worktrees can build different sections at once. Each starts from the same base commit,
   touches only its own `EffectRegistry3x.swift` / `Effects3x.metal`, and appends one line to the `all` chain and the kernel
   list (merge conflicts there are trivial). Section-move edits to existing effects belong to one batch only.
10. **Per batch, before merging**: CI green with `validation=all`; look at the contact sheet; make a short moving render
    (the AI Link `render_sheet`) of the 5 most important new effects; retune weak defaults.

### Suggested batch split (about 60–120 effects each)

| Batch | Section focus |
|---|---|
| 30 | Backgrounds (solid sunburst, patterns, gradients, grids, sky/space, animated BGs) + browser reorganization |
| 31 | Glitch pack 30+ with motion styles |
| 32 | Liquid + Distort & Warp additions |
| 33 | Key & Matte (Unmult, chokers, luma/edge/difference mattes, spill, light wrap) + Time |
| 34 | Transitions (wipes, liquid/ink, shape reveals, glitch cuts, zoom/whip variants with real motion blur) |
| 35 | Shapes (generated shapes, speed lines, frames, bursts; move 3D shapes here) + Particles |
| 36 | Procedural (Fractal Ridges exact, cells, turbulence variants) + Glow & Light FX composites |
| 37 | Stylize, Retro & Film, Text effects, Blur (Pixel Blur), Hot Color, remakes (Halftone family, Inner Glow, Time Slice) |
| 38 | Designed composite families (plugin-style) across sections; upscale (Core ML bake) |

## 9. Presets (after the effects)

- A new preset system with **live previews** in the browser.
- **Text presets wave 2**: combine the text engine's animators (Text Studio, per-letter selectors, `TextEngine.placement`)
  with the new effects (glitch pack, glows, distortions) applied per letter and per layer. Today's text presets use only the engine's
  own animators; keep them and add the new ones. Names should be what an editor would call them, not AI-sounding.
- Presets **unpack into editable parts** (layers, animators, effects, keys), never a black box.
- After-Effects-style presets combine text and effects; design ours, don't copy theirs.

## 10. Performance pass (last)

Profile on the device with real projects: 20+ layers, video, 3D, heavy glow stacks. Use the precomp pre-render that already exists (faster to build,
never stale after edits, used for heavy 3D), cache effect results that don't change between frames, and downsample big-radius passes.
Target 60 fps+ preview; export matches the preview.

## 11. Still open / leftovers from the renewal

- Motion Sketch: today it clears keys after the sketched range, AE keeps them. **Ask the owner** before changing it.
- Renewal leftovers: media bin + relink, project folders, work area, audio denoise; guides dragged in from the ruler edge; 3-bone IK;
  a floor-height handle in the 3D scene.
- CC Studio renewal (ROADMAP 12): look-type color effects become LUTs in CC Studio, plus more LUTs and finer grading.
- SAM 2 cutout: only after the app is done.
- Make the GitHub repo **private** again when the app is finished (it's public only for free macOS CI minutes).
