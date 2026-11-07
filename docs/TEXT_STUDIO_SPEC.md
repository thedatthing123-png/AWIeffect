# Text Studio renewal — spec

Goal: Text Studio becomes a full typography + animation studio that a professional AMV/manga editor uses instead of
After Effects. It must feel like editing (values, keyframes, on-canvas handles, the swipe pad), never like button
clicking. Nothing cramped, overlapping, tiny or confusing. Presets unpack into editable parts.

Read AGENTS.md. Keep every saved project opening (all new model fields Optional or decodeIfPresent).

## Current state (summary, see code)
- Model: App/Model/Text.swift — TextData, TextAnimator (one TextSelector + optional Animated properties), TextCounter.
- Render: App/Render/TextEngine.swift — CoreText layout, per-glyph r8 masks tinted in a shader, one compute encoder per
  glyph, fake per-letter 3D (cos squash), unanimated bounds used for the layer buffer (animated letters clip).
- UI: App/UI/TextStudioPanel.swift (TextPanel, TypeBar, sections Style/Letters/Animate/Animators/Counter/3D),
  App/UI/TextStudio.swift (AnimatorCard, FontPicker, presets apply).
- Presets: App/Library/TextPresetPack.swift, TextPresetStudio.swift, Text.swift TextPresets; title looks in
  App/Library/TitleStyles.swift. Applying replaces all animators.
- 3D: per-glyph fake 3D, layer is3D+extrude slab (Renderer.swift ~836), SceneKit `.model` text (ModelRenderer.swift,
  Extrude3D.swift) that loses all 2D styling.

## Parts

### Part 1 — Engine and model (foundation; others build on its API)
Model (Text.swift), all new fields Optional:
- `TextStyleStack` on TextData (`style: TextStyleStack?`):
  - `fills: [TextFillLayer]` — solid / linear gradient / radial gradient (colors Animated, angle Animated), opacity.
  - `strokes: [TextStrokeLayer]` — color Animated, width Animated, position (outside/center/inside), join, opacity;
    drawn in order under the fill (stroke-on-stroke AMV look).
  - `shadows: [TextShadowLayer]` — inner or drop: color, opacity, angle, distance, blur (all Animated).
  - `glow: TextGlowLayer?` — color, radius, intensity (Animated), hue-keeping like the light engine.
- Per-character styling that does not drift: `TextCharStyle` keyed by stable character ids. Give TextData a
  `charIDs: [UInt32]?` array parallel to the string's Characters; editing the string through
  `TextData.edit(replacing:with:)` keeps ids of untouched characters. Color spans, letter styles and split animators
  target ids, not indices/percent. Migrate old spans/✦/◆ animators on load.
- Per-character overrides: font, size %, fill, stroke, baseline shift (TextCharStyle).
- Paragraph: `boxWidth: Double?` (wrap), `autoFit: Bool?`, `vertical: Bool?` (top-to-bottom, right-to-left columns,
  CJK upright, Latin rotated), `kerningPairs` handled by CoreText, `baselineShift`.
- Animators:
  - `selectors: [TextSelector]?` (multiple, with `mode` add/subtract/intersect/min/max/difference); keep `selector` as
    the first for compatibility.
  - Selector kinds: add `.random` (per-unit random amount, seed, animated), `.beat` (amount pulses on project beat
    markers, attack/decay).
  - Every selector value Animated (easeHigh/easeLow, frequency, spread, min/max) — Optional Animated replacements.
  - New properties: anchor (Vec2), fillOpacity, strokeWidth, strokeColor, baselineShift, glow (amount), hueShift,
    directionalBlur (amount + angle), scramble (random characters that settle), lineSpacing, per-letter motion blur flag.
- Effects per letter: `TextAnimator.letterEffects: [EffectInstance]?` rendered only on the letters the selector picks
  (amount = mix).
Render (TextEngine.swift + Renderer.swift):
- Real per-letter 3D: project each glyph quad with the layer/camera perspective (rotationX/Y, positionZ), backface
  shows the glyph mirrored; no cos squash.
- Batch all glyphs of a layer into one encoder (instanced quads, atlas or texture array); keep caches bounded LRU, not
  wipe-all.
- Animated bounds: the layer buffer and motion-blur checks use the bounds of the animated glyph states at that time
  (plus stroke/glow/shadow margins). No clipping ever.
- Style stack rendering: fills (gradients in glyph space or whole-text space option), multiple strokes via distance
  field or path stroke, inner/drop shadows, glow.
- Color emoji render in color (RGBA glyph textures when the run font has color glyphs).
- Character offset/scramble re-lays out neighbours.
API for other parts: `TextEngine.layout(_:)`, `TextEngine.glyphStates(...)`, `TextData.edit(...)`, the model types above.
Tests: drift-free spans after edits, animated bounds no clipping, stroke stack renders, real 3D (letter at 60° is
narrower and trapezoidal), multiple selectors combine, migration of old projects.

### Part 2 — Studio UI (App/UI/TextStudioPanel.swift, App/UI/TextStudio.swift)
Full-screen-capable Text Studio with a live canvas on top and three clear tabs: **Style**, **Animate**, **Presets**
(+ **3D** when 3D). No row with more than 3 controls; min tap target 44 pt; labels never truncated.
- On-canvas: tap text to edit with a real caret; drag across letters to select a range (selection highlight); selected
  letters can be styled/animated; drag a letter to offset it (writes an animator); pinch to size.
- Style tab: font browser (search, favorites, live preview with the user's own text), size, tracking, line height,
  alignment, box width/auto-fit, vertical; the style stack editor (add/reorder/remove fills, strokes, shadows, glow) —
  each layer a card with ValueScrubbers + keyframe diamonds.
- Animate tab: animator list (rename, reorder up/down, duplicate, delete, enable); each animator: selectors list
  (add/remove, mode), a **visual selector graph** (draggable start/end/offset/ease handles over a strip of the letters),
  properties with keyframe diamonds and remove buttons, letter effects list. All numbers: ValueScrubber + tap-to-type.
  Easing: open the existing graph editor for any property.
- Use the existing swipe pad for precise letter offset / anchor moves.
- Applying a preset never deletes the user's own animators/styles: presets add a named group that can be removed.

### Part 3 — Preset library (App/Library/*)
- 300+ distinct presets, no duplicate names, real categories:
  In, Out, Loop, Emphasis, Glitch, Typewriter, Kinetic, Manga/AMV, Lyric, Impact, 3D In, 3D Out, 3D Loop.
- Two kinds: **Animation** presets (animators + letter effects) and **Look** presets (style stack + effects). Mix freely.
- 3D presets: animations (flip, spin, fly-from-depth, cascade, orbit, unfold, shatter, push-in) and 3D looks
  (chrome, gold, glass, toon, neon, stone) for Part 4's 3D text.
- Duration control (default = clip length or 1 s), start at playhead, optional snap to beats.
- Previews: live, rendered with the user's own text and font, animated, cached with a bounded LRU.
- Every preset unpacks into editable animators/styles tagged with the preset group.
- AI Link catalog: categories included.

### Part 4 — 3D text engine (App/Render/ModelRenderer.swift, Extrude3D.swift, new files)
- One 3D text system: a text layer with `text3D: Text3DOptions?` keeps all 2D styling/animation (string, font,
  per-letter animators drive per-letter 3D transforms).
- Real geometry per letter (CoreText path → extruded mesh with bevel profile: flat/round/angle/custom depth+segments),
  separate materials for front, bevel and sides; PBR with an environment map (procedural studio HDR) so metals read.
- Materials presets: chrome, gold, glass, toon (cel + outline), neon (emissive), stone, plastic.
- Lit by scene lights and camera; depth of field; per-letter animation in real 3D.
- Controls: extrusion, bevel size/segments/profile, material per part, environment intensity/rotation — all keyframeable.
- Old `.model` text and is3D extrude slabs keep rendering as before.

### Part 5 — Captions and lyrics
- Generate word-timed captions from a layer's audio (on-device SFSpeechRecognizer, user picks language).
- Caption layer: words with times; styles from the preset Looks; karaoke highlight (fill/scale/glow per active word),
  per-word style overrides; edit words and timings in a list with scrubbable times.

## Acceptance
- Every control reachable, ≥44 pt, no overlaps on iPhone widths (check UI screenshots).
- Old projects open and look the same unless the user changes them.
- Presets: 300+, unique names, each previewed, each tested to animate and differ.
- No text clipping with any animator + effects combination.
