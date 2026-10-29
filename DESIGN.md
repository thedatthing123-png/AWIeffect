# AWIeffect — Design Document

> A private, personal iOS motion-graphics editor for iPhone 16 Pro Max.
> Feels like Alight Motion, works like After Effects + Blender + ibisPaint — with its own engine, its own look, and **every feature real and tested**.

Status: **Design locked pending owner's "go".** Research backing this doc lives in `research/reports/`:
- `AWIeffect engine research.md` — formats, engine, iOS stack, CI, testing
- `AE effects catalog deep dive.md` — every AE effect/feature, match names, plugins, edit packs

---

## 0. Ground rules (non-negotiable)

1. **Everything is real.** No stubbed effects, no fake overlays pretending to be effects, no renamed duplicates, no placeholder sliders.
2. **Definition of done** for any effect / plugin / preset / feature:
   - Does what it says, visibly and distinctly.
   - Every control changes the result and is keyframeable.
   - Passes automated tests on every build (see §19).
   - Appears in the build's contact sheet.
   - Runs smoothly on iPhone 16 Pro Max.
   - **Owner has tried it on the phone and approved it.**
   If not done → hidden behind a flag, never shipped half-working.
3. **No overlapping UI.** Every screen is screenshot-tested at iPhone 16 Pro Max size; overlap or off-screen controls fail the build.
4. **Never lose work.** Autosave, versions, crash-safe mode, backups.
5. **Build in stages.** Each stage ends with a working, tested IPA on the owner's phone before the next starts.
6. **Code provenance.** Only our own code or properly licensed open source. Because the app is private and never distributed, **GPL code is allowed** (repo is licensed GPL-3.0 while public). Never: Adobe code, plugin vendors' code, Alight Motion code (including the "AE Motion" IPA), cracked anything.

---

## 1. Platform & project facts

| Item | Decision |
|---|---|
| Device | iPhone 16 Pro Max (6.9", 120 Hz ProMotion, A18 Pro) |
| Min iOS | iOS 18 (target current iOS) |
| Language / UI | Swift 6, SwiftUI (+ UIKit where needed for performance, e.g. timeline, canvas) |
| Rendering | Metal (compute + render), HDR float pipeline |
| Media | AVFoundation (custom compositor), VideoToolbox |
| AI | Core ML + Vision, all on-device |
| Scripting / expressions | JavaScriptCore |
| Project gen | XcodeGen (`project.yml`) — no Mac needed |
| CI | GitHub Actions, `macos-26` runners → unsigned IPA artifact |
| Install | Sideloadly (Windows) with owner's Apple ID; re-sign every 7 days |
| Repo | GitHub `thedatthing123-png/AWIeffect`, **public during build, switched to private when done** |
| Repo hygiene | No personal info, no private media, commits via GitHub no-reply email |

---

## 2. Look & feel

**Theme:** dark purple-black base, purple glow accents, soft glass panels, AE mood.

| Token | Value (initial) |
|---|---|
| Background | `#0E0B14` |
| Surface | `#17121F` |
| Surface raised / glass | `#211A2D` @ 85% + blur |
| Accent (primary) | `#9B5CFF` |
| Accent glow | `#B98CFF` |
| Keyframe / selection | `#C9A2FF` |
| Text primary / secondary | `#F2EEF8` / `#A69DB5` |
| Danger / warning / ok | `#FF5C7A` / `#FFC75C` / `#5CFFB0` |
| Layer colors | purple, blue, teal, pink, amber, green (user-changeable per layer) |

- 120 Hz animations, spring panels, haptics on tap / snap / keyframe add.
- One consistent custom icon set (SF Symbols where they fit, custom where not).
- Real rendered thumbnails everywhere (effects, presets, transitions, fonts).
- App icon + launch animation in purple.
- **Easy by default, Advanced on tap**: every effect/layer shows key controls; an "Advanced" toggle reveals all params, graph, expressions.

### Layout reference (from owner's screen recordings)
We keep the *workflow* that feels right in Alight Motion and ibisPaint, with our own design:

- **Home:** templates row, recent projects list (thumbnail, resolution, fps, duration), big "+" create.
- **Create sheet:** project name, aspect presets (16:9, 9:16, 4:5, 1:1, 4:3, custom), resolution, frame rate, background.
- **Editor:** top bar (back, project name, settings, export) → preview → transport row (undo, jump start, play, jump end, loop, fit) → timecode + ruler → **layer timeline** (eye toggle, layer icon, color bar, drag to trim/move) → bottom **tool panel** that changes with selection.
- **Add menu** (from "+"): Shape, Media, Audio, Object/Element (camera, null, empty group, element/project), Template, Freehand Drawing, Vector Drawing, Text.
- **Layer selected:** quick row (speed, split, trim helpers), then tiles: Color & Fill, Border & Shadow, Blending & Opacity, Move & Transform, Edit Shape, Presets, Effects.
- **Move & Transform:** numeric X/Y/rotation fields, keyframe diamond, mode buttons (move / rotate / scale / skew), swipe pad to nudge.
- **Add Effect browser:** featured row with live thumbnails, grid, category tiles (Color & Light, Drawing & Edge, Blur, Distortion/Warp, Procedural, 3D, Move/Transform, Repeat, Matte/Mask/Key, Opacity/Visibility, Text, Other) + search.
- **Effect stack:** collapsible effect cards with params, keyframe diamond per param, blending mode, reorder, delete, "…" menu.
- **Layer long-press menu:** select all, duplicate, copy, save preset, paste layer, paste style.
- **Export & Share sheet:** Video, GIF, Image Sequence, Project Package, Current Frame as PNG, "also export as template".
- **Draw Studio** (ibisPaint-style): top tool strip (selection, transform, fill, layer ops), canvas, size/opacity sliders, bottom bar (tools, brush, color, layers, undo/redo), floating Layer panel (thumbnails, selection layer, blend, opacity, lock, clipping, FX), selection menu (remove/invert/clear, select opacity, color range, expand/contract, cut/copy/paste), stabilizer panel, color wheel + RGB/HSB.

What we do **better** than both:
- Nothing ever covers the canvas by accident; panels dock, collapse, and the preview resizes.
- No ads, no paywalls, no watermark.
- Bigger preview, cleaner timeline, color-coded layers & effects.

### Global UI pieces
- **Quick-action button:** small floating button → customizable radial menu (split, keyframe, duplicate, precomp, favorite effects, scripts).
- **Undo history panel**, **Performance HUD** (FPS / memory / thermal, toggle), **Bug report button**.
- Gestures: pinch timeline zoom, two-finger scrub, haptic snapping to keyframes/markers/beats.

---

## 3. Core editor

- **Import:** video, photos, audio, PNG sequences, 3D models (.glb/.usdz), fonts — from Files and Photos.
- **Layer types:** video, image, text, shape, solid, adjustment, null, camera, light, 3D model, drawing, audio, precomp.
- **Keyframes:** on every property; interpolation linear / bezier / hold / auto-bezier / continuous; AE speed+influence model.
- **Graph editor:** value + speed graphs; Flow-style easing presets library.
- **Motion paths on canvas** with bezier handles.
- **Parenting + pick-whip** (layers and property links).
- **Precomps** (open, edit, reuse), **essential properties** for templates.
- **Blend modes:** all 38 AE modes; track mattes (alpha/luma/inverted, AE 2023+ layer-reference model); adjustment layers; preserve transparency; collapse transformations.
- **Masks & shapes:** pen tool (bezier), freehand, rect/ellipse/polygon/star; mask modes (add, subtract, intersect, lighten, darken, difference, none), feather (incl. variable), expansion, opacity, invert. Shape operators: trim paths, repeater, wiggle paths, offset, pucker & bloat, round corners, merge, twist, zig zag; fill/stroke incl. dashes, taper, gradients.
- **Markers & beat grid**, snapping.
- **Autosave + version history**, multi-step undo panel.
- **Motion blur** per layer + comp (shutter angle/phase, samples).

---

## 4. Render engine

- **Single Metal compositor** used by preview and export → identical output.
- Internal format **rgba16Float**, linear-light working space, display transform at the end (HDR-correct glows).
- **Render graph:** each layer = source → masks → effect stack → transform → blend into comp. Precomps render recursively.
- **Render cache** keyed by (layer, time, param hash); only dirty frames re-render.
- **Proxy preview** (½ / ¼ res) with full-res export.
- **Texture pool** (no per-frame allocation), frame pacing for 60/120 fps preview, thermal-aware quality drop.
- **Effect Registry** (central): every effect self-describes — id, AE match names it maps from, params (name, type, default, range, AE param match names), shader(s), thumbnail spec, tests. UI panels, serialization, import mapping, and tests are **generated from the registry**, so an effect cannot exist without its UI, tests, and import mapping.

---

## 5. Effects (~150 in launch scope → full AE catalog later)

Each is a real GPU effect, AE-named params/ranges where an AE equivalent exists, live thumbnail, fully keyframeable.

| Category | Launch examples |
|---|---|
| Blur & Sharpen | Gaussian, Fast Box, Directional, CC Radial Blur, CC Radial Fast Blur, Zoom, Camera Lens Blur, Bokeh, Bilateral, Sharpen, Unsharp Mask |
| Color Correction | Curves, Levels, Lumetri-style, Hue/Saturation, Exposure, Brightness & Contrast, Tint, Tritone, Color Balance, Vibrance, Selective Color, Change to Color, Photo Filter, Black & White, Gamma/Pedestal/Gain, Apply LUT |
| Glow & Light | Glow (AE-accurate params), Light Rays, Lens Flare, Bloom, Neon, Edge Glow, CC Light Burst, CC Light Sweep |
| Distort | Transform (with motion blur), Turbulent Displace, Wave Warp, Displacement Map, Optics Compensation, Bulge, Twirl, Ripple, Polar Coordinates, Mirror, Offset, Corner Pin, Spherize, Magnify, CC Bend It, CC Lens, CC Flo Motion, CC Tiler |
| Glitch & Digital | RGB Split, Chromatic Aberration, Block Glitch, Scanlines, VHS, CRT, Signal Noise, Digital Tear, Pixel Sort |
| Stylize | Halftone, Posterize, Find Edges, Emboss, Mosaic, Threshold, Cartoon, Motion Tile, Roughen Edges, Scatter, Strobe, Vignette, Cinematic Bars |
| Noise & Grain | Add Grain, Noise, Fractal Noise (all types), Turbulent Noise, Curl Noise, Median, Dust & Scratches |
| Shake & Motion | Wiggle shakes (position/rotation/scale), Impact Shake, Camera Shake, Echo, Motion Blur |
| Keying & Matte | Keylight-style Chroma Key, Luma Key, Linear Color Key, Color Range, Matte Choker, Simple Choker, Spill Suppressor, Refine Matte |
| Generate | Fill, Gradient Ramp, 4-Color Gradient, Cell Pattern, Checkerboard, Grid, Circle, Beam, Lightning, Audio Spectrum, Audio Waveform, Stroke, Write-on |
| Perspective | Drop Shadow, Radial Shadow, Bevel Alpha, CC Sphere, CC Cylinder |
| Transitions | Linear/Radial/Iris/Gradient Wipe, Venetian Blinds, Block Dissolve, Card Wipe, Zoom, Spin, Whip, Glitch, Flash, Luma Fade, Ink, Shape wipes |
| Time | Time Remap, Frame Blending, Echo, Posterize Time, Timewarp-style |

### Chroma key (Keylight-style)
Screen color picker (area sample), Screen Gain, Screen Balance, Despill/Alpha Bias, Clip Black/White, Clip Rollback, Shrink/Grow, Softness, Despot, Replace method, view modes (Final, Screen Matte, Status, Combined…), AI edge refine, garbage mask.

### Effect priority (from edit-pack usage)
1. Transform+motion blur, wiggle shakes, adjustment layers, mattes, Gaussian/Directional/CC Radial Fast Blur, Curves, Levels, Exposure, Glow, Fractal Noise, AWI Shake
2. Turbulent Displace, Wave Warp, Optics Compensation, Motion Tile, Echo, Posterize Time, Chroma Key, Hue/Sat, Tint, Find Edges, Threshold, Halftone
3. Glitch family, transitions, CC distorts, Deep Glow / Twixtor / RSMB equivalents
4. Remaining built-ins until the **full AE catalog (~300+)** is covered

---

## 6. AWI Plugins (~25 flagship)

Pro-grade, multi-pass, HDR implementations. Importer maps the originals to these.

| Group | Plugin | Real technique |
|---|---|---|
| Glow & light | **AWI Deep Glow** | HDR soft threshold, 10+ level blur pyramid, per-channel radius, tint, chromatic aberration, lens dirt, tonemap |
| | **AWI Saber** | distance-field beam along paths/masks/text, core + glow, flicker, start/end/offset |
| | **AWI Flares** | element-based flare builder along source→center axis |
| | **AWI Starglow / Shine** | directional streak blurs / radial light rays from a point |
| Motion & time | **AWI Shake** | S_Shake-parity params (style, amplitude, frequency, stillness, drift, seed, per-axis, RGB offsets) |
| | **AWI Twixtor** | optical-flow / AI frame interpolation retime |
| | **AWI Motion Blur** | flow-based motion blur on footage (RSMB-style) |
| | **AWI Flow** | easing curve editor + presets |
| | **AWI Velocity** | speed-ramp graph + frame blending |
| Glitch | **AWI Glitch**, **AWI Pixel Sort**, **AWI VHS**, **AWI Datamosh** | block/RGB/data glitches; GPU span sort; tape emulation; motion-vector melt |
| 3D & particles | **AWI Particles** | GPU particle sim (emitters, forces, textures, collisions) |
| | **AWI Plexus** | point/line networks with distance falloff |
| | **AWI Element** | 3D models + extruded text, PBR materials, reflections |
| | **AWI Newton** | 2D/3D physics → baked keyframes |
| Anime & manga | **AWI Manga FX**, **AWI Impact Frame**, **AWI Cel Shade** | halftone/screentone/ink/speed lines; one-tap impact frame; toon shading |
| Color | **AWI Looks**, **AWI Film** | grading stack + LUTs; film emulation + grain |
| Utility | **AWI Tracker**, **AWI Beat**, **AWI Twitch** | point/planar tracking; beat detection; beat-synced chaos |

---

## 7. AWI Scripts

- JavaScript tools (JavaScriptCore) that **generate** normal layers, keyframes, expressions, and effects — never hidden runtime magic, so results are always editable.
- Built-ins: auto-shake on beats, easing presets, sway, physics bake, one-tap text setups, stagger, randomize, align/distribute.
- Owner can write, save, and share scripts.

---

## 8. Expressions

- AE-compatible expression engine on JavaScriptCore with a shim: `time`, `value`, `thisComp`, `thisLayer`, `comp()`, `effect()`, `wiggle`, `temporalWiggle`, `smooth`, `loopIn/loopOut` (cycle, pingpong, offset, continue), `valueAtTime`, `velocity`, `linear/ease/easeIn/easeOut`, `posterizeTime`, vector math (AE-style array `+ - * /`), `random/seedRandom`, `clamp`, sliders/controls.
- Expression editor: autocomplete, inline error line, library of ready-made expressions (shake, bounce, inertia, loop).
- Expression Controls effects (Slider, Angle, Checkbox, Color, Point, 3D Point, Layer, Dropdown).

---

## 9. Text Studio

- AE-style **text animators**: per character / word / line; Range Selector (start/end/offset, units, based on, mode, amount, shape square/ramp/triangle/round/smooth, ease high/low, randomize, seed), Wiggly Selector, Expression Selector; per-character 3D.
- Animatable: anchor, position, scale, skew, rotation, opacity, blur, tracking, line spacing, fill/stroke color (RGB/HSB), stroke width, character offset.
- Styling: any font, size, fill, stroke, shadow, glow, **per-letter / per-word color & style**.
- Text on path, paragraph options.
- **Premade pack** (glitch, bounce, typewriter, wave, blur-in, flicker, scale pop, slide stagger, …) — each visually distinct, live-previewed, fully editable after apply.
- Save / import / share text presets. 3D extruded text.

---

## 10. Font Library

- Google Fonts + Fontshare browser (search, live preview, one-tap download).
- Personal-use edit fonts (DaFont-style) — source checked before integrating.
- Import .ttf/.otf; favorites; recents.
- On `.aep` import: detect fonts used, offer to fetch missing ones.

---

## 11. Background Cutter

| Mode | Tech |
|---|---|
| Realistic | Vision person segmentation |
| Object | Vision foreground instance mask (subject lift) |
| Anime / Manga | Bundled Core ML anime-segmentation model (license checked; personal-use OK) |
| AWI Smart | auto-pick best model |

Photos and video. Refine brush (add/remove), feather, choke, spill cleanup, temporal smoothing for video. Output is a matte usable with any layer/track matte.

---

## 12. AWI Draw Studio (ibisPaint built in)

- **Full-screen mode**, panels slide/dock, never overlap the canvas.
- **Canvas = project resolution exactly** (1:1 project → 1:1 canvas). Opening from a layer keeps its frame position; **Send to Timeline** drops it exactly where drawn.
- **Live link:** drawing layers stay editable; edits update the timeline instantly.
- **Brushes:** pen, pencil, ink, marker, airbrush, watercolor, screentone, glow, halftone, eraser, blur, smudge; pressure & tilt (Apple Pencil / finger), stabilizer (real-time / after), fade in/out.
- **Layers:** blend modes, opacity, clipping, alpha lock, folders, layer FX.
- **Selection & cutout:** lasso (free/polygon), magic wand, select by opacity, color range, brush select, **AI cutout** (§11); expand/contract, invert, feather. Actions: **cut, copy, paste, delete, paste as new layer, paste in place, transform (move/scale/rotate/flip/perspective/mesh warp), make mask**.
- **Manga tools:** screentones, speed / focus lines, panel cutter, line-art extract, smart gap-closing fill, auto flats.
- **Animation:** frame-by-frame with onion skin, rotoscope over video frames.
- Color wheel, RGB/HSB, palettes, eyedropper.

---

## 13. 3D & Physics Lab

- 3D layers; AE-style camera (one/two-node, zoom, DOF focus/aperture/blur, iris), lights (point, spot, parallel, ambient; shadows), material options.
- Custom Metal 3D renderer (SceneKit is soft-deprecated) integrated in the 2D compositor.
- Import .glb / .usdz with PBR materials; extruded text & shapes.
- **Physics Lab:** 2D (Box2D) and 3D (Jolt/Bullet) — drop, throw, collide, joints; **bake to keyframes**.
- Camera shake / handheld presets.

---

## 14. Audio & timing

- Waveform on timeline, volume keyframes, fades.
- **Beat sync:** auto detection (aubio, allowed since private) + manual tap markers; snap cuts/shakes/keyframes.
- Audio-reactive linking (bass/mid/high → any property).
- Velocity edits: time-remap speed graph, frame blending, AI slow-mo.

---

## 15. Tracking

Point tracking and planar (Mocha-style) tracking; attach layers/text/effects; track data as keyframes.

---

## 16. AI tools (on-device)

Background cutter, AI slow-mo interpolation, AI upscale (anime-tuned), auto captions with animated subtitles, auto beat-edit.

---

## 17. Importing

| Format | Priority | Content |
|---|---|---|
| `.aep` | **1** | comps, layers, keyframes + easing, expressions, masks, shapes, text, effects (via registry), 3D, cameras, lights, mattes, blend modes |
| `.aepx` | 1 | same tree, XML form |
| `.ffx` | 2 | effect/animation presets from edit packs |
| Alight Motion XML | 3 | best-effort (format undocumented; built from owner's own exports) |
| Lottie JSON | 3 | Bodymovin exports |

- Parser: Swift port informed by py-aep / aep-reader (MIT) and Glaxnimate's importer (GPL, allowed here).
- **Import report:** ✅ native / 🟡 approximate / 🔴 missing per effect, tap to jump. Missing effects keep all params and auto-upgrade when implemented.
- Third-party plugin mapping: match by match name → by param names → defaults; mark approximate; keep original data.
- Missing-font detection.
- **Effect scanner tool:** scans owner's `.aep`/`.ffx` files and reports which effects are used and how often → drives build priority.

---

## 18. Libraries, export, sharing

- **Overlay/VFX library** (light leaks, grain, flares, smoke, sparks, explosions, dust) hosted on GitHub, downloaded in-app.
- **Preset library** (effects, text, transitions, shakes, CC stacks) and **personal asset library**.
- **Export:** up to 4K, 24/30/60 fps, bitrate; MP4 (H.264/HEVC), MOV, ProRes (if device supports), GIF, PNG sequence, transparent HEVC-with-alpha; range or single frame.
- **Share** presets, scripts, projects; templates with replaceable clips.
- **Backups:** full project package (with media) to Files / iCloud Drive.

---

## 19. Reliability & testing

Every build runs:

1. **Logic tests** (no GPU): data model, keyframe math, expressions, importers.
2. **Registry tests:** every registered effect has a compiled shader, every param is wired, every AE match name maps.
3. **Anti-stub render tests:** at non-zero strength output must differ from input; at zero/neutral it must match input; never blank/NaN.
4. **Golden-image tests** with perceptual tolerance.
5. **Contact sheet** artifact: every effect/preset at several settings.
6. **UI layout tests:** screenshots of every screen at iPhone 16 Pro Max size; fail on overlap/off-screen.

If the CI runner has no usable Metal device, GPU tests **skip loudly and are counted**, never silently pass. Final GPU truth = **in-app hidden Self-Test screen** run on the owner's iPhone.

Plus: safe mode / crash recovery, bug-report bundle (screenshot + recent actions + log), performance HUD.

---

## 20. Build & install pipeline

1. Repo with `project.yml` (XcodeGen), Swift packages: `AWICore` (model), `AWIRender` (Metal), `AWIEffects`, `AWIImport`, `AWIScript`, `AWIDraw`, `AWI3D`, app target.
2. GitHub Actions:
   - Linux job: fast lint/logic checks where possible.
   - macOS job: `xcodegen generate` → tests → `xcodebuild archive` unsigned → `Payload/` → `AWIeffect.ipa` + contact sheet + layout screenshots as artifacts.
3. Owner downloads IPA → Sideloadly → iPhone (Developer Mode on).
4. Repo switched to private when the full app is done.

---

## 21. Build order (stages)

| # | Stage | Exit criteria |
|---|---|---|
| 1 | **Pipeline + base app** — CI → IPA, purple UI shell, home, create sheet, editor layout, timeline, layers, keyframes, Metal compositor, MP4 export | Owner installs, creates a project, animates a shape, exports MP4 |
| 2 | **First effects batch + registry + test harness** — Transform+MB, shakes, Gaussian/Directional/Radial blurs, Curves, Levels, Exposure, Glow, Fractal Noise, Chroma Key | All pass tests; contact sheet; owner approves |
| 3 | **Text Studio + expressions + graph editor** | Premade text pack distinct & editable; wiggle/loopOut work |
| 4 | **`.aep` importer + effect registry mapping + import report + effect scanner**, then `.ffx` | Owner's real projects open with report |
| 5 | **Masks, shapes, Draw Studio** | Cutout workflow end-to-end, send to timeline |
| 6 | **AI cutout, tracking, beat sync, velocity/time remap** | Works on owner's clips |
| 7 | **3D + Physics Lab** | Camera/lights/models; physics bake |
| 8 | **Effects expansion + AWI plugins** in tested batches of ~10 | Toward full AE catalog |
| 9 | **Libraries, fonts, Alight Motion import, sharing, polish** | Feature-complete; repo → private |

Each stage: build → tests → IPA → owner tests on phone → fixes → approval → next stage.

---

## 22. Out of scope (for now)

Cloud accounts/sync, Blender-level modeling, App Store distribution, iPad layout (later).
