# Advanced Drawing Features Beyond ibis Paint (Procreate, Clip Studio Paint, Krita, Infinite Painter) and Mobile GPU Brush Engines

## Brush engine design (stamps, spacing, dynamics, stabilization, predicted touches, wet mix, grain, dual brush)

### Takeaway
Every leading engine is a stamp/dab engine: dabs are placed along a smoothed path at a spacing set as a percent of brush size, and each dab's size, opacity, color and rotation are driven by pressure, tilt, azimuth, barrel roll and speed. A brush feels "advanced" because of a few added layers: shape and grain textures (moving vs. texturized), a wet-mix pass that picks up canvas color, several stabilizer modes, and correct Apple Pencil coalesced/predicted/estimated touch handling.

### Cited Findings
- Procreate's Brush Studio groups its parameters as Stroke Path (Spacing, Spacing Jitter, Jitter Lateral/Linear, Fall Off), Stabilization (Stabilization, StreamLine Amount and Pressure, Motion Filtering Amount and Expression), Taper (Pressure Taper, Touch Taper, Classic), Shape, Grain, Rendering, Wet Mix, Color Dynamics, Dynamics, Apple Pencil, Properties and Materials — [Procreate Handbook: Brush Studio settings](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings)
- Shape settings: Shape Source, input style (Touch only / Azimuth / Azimuth with barrel roll), Rotation, Scatter, Count and Count Jitter, Randomized, Flip X/Y, Roundness (including Pressure and Tilt Roundness), Shape Filtering (None/Classic/Improved) — [Procreate Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings)
- Grain has two modes. **Moving** grain drags with the stroke and gives streaks. **Texturized** grain stays fixed behind the stroke like a stencil, so it is canvas-space. Controls: Movement, Zoom, Rotation, Depth, Depth Min, Depth Jitter, Offset Jitter, Blend Mode, Brightness/Contrast, Grain Filtering — [Procreate Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings)
- Rendering modes run Light Glaze → Uniformed Glaze → Intense Glaze → Heavy Glaze → Uniform Blending → Intense Blending, with Flow, Wet Edges, Burnt Edges, Luminance Blending and Alpha Threshold — [Procreate Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings)
- Wet Mix parameters: Dilution, Charge, Attack, Pull, Grade, Blur, Blur Jitter, Wetness Jitter — [Procreate Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings)
- Color Dynamics has two scopes: per-stamp jitter and per-stroke jitter for hue, saturation, lightness, darkness and secondary color. Pressure, tilt and barrel roll can each be mapped to these color attributes — [Procreate Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings)
- Speed dynamics drive Size, Opacity and Spacing. Apple Pencil pressure graphs drive Size, Opacity, Flow and Bleed. Tilt has a trigger-angle graph plus Opacity, Gradation, Bleed, Size and Size Compression. Apple Pencil Pro barrel roll drives Size, Opacity and Bleed — [Procreate Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings)
- Dual brush is documented on a separate Procreate page. The Brush Studio page only mentions a "Classic Normal Combine" toggle — [Procreate Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings)
- Motion Filtering removes the extremes of wobbles instead of averaging them. Stabilization squashes wobbles toward a central line. Motion Filtering Expression puts some expression back, but has less effect at high filtering amounts. Stabilization can be set globally (Actions → Preferences → Pressure & Smoothing) or per brush — [Procreate Handbook: Accessibility](https://help.procreate.com/procreate/handbook/interface-gestures/accessibility)
- Lazy Nezumi stabilizer modes:
  - **Pulled String:** the brush stays still until a virtual string of set length is taut, then follows the pen. This keeps sharp corners and ends the line as soon as the pen lifts.
  - **Moving Average:** averages recent positions, so curves get smoother but lag and rounded corners grow with Amount. Its "Catch Up" option snaps the brush to the pen when the pen stops or lifts.
  - **Exponential Moving Average:** weights recent samples more.
  - **Weighted:** a scripted mode that gives the brush mass, applies a spring force proportional to distance, has a drag parameter, and derives pressure from speed.
  — [Lazy Nezumi: Smoothing](https://lazynezumi.com/smoothing)
- Apple Pencil touch APIs:
  - `UIEvent.coalescedTouches(for:)` returns every touch sample since the last delivery. On Pencil this is a higher rate than the display.
  - `UIEvent.predictedTouches(for:)` returns predicted future samples that UIKit refreshes as new samples arrive.
  - `UITouch.estimatedProperties`, `estimatedPropertiesExpectingUpdates` and `estimationUpdateIndex` mark values (for example force, azimuth) that arrive late and let you patch earlier samples later through `touchesEstimatedPropertiesUpdated`.
  — [WWDC15 233 notes](https://wwdcnotes.com/documentation/wwdc15-233-advanced-touch-input-on-ios/); [Apple: estimatedProperties](https://developer.apple.com/documentation/uikit/uitouch/estimatedproperties.md); [Apple: Handling input from Apple Pencil](https://developer.apple.com/documentation/uikit/handling-input-from-apple-pencil.md); [Apple: estimationUpdateIndex](https://developer.apple.com/documentation/uikit/uitouch/estimationupdateindex.md)
- Krita Color Smudge engine:
  - **Color Rate** is how much foreground color enters the smudge mix.
  - With the "new smudge algorithm" (Krita 5.0+), Color Rate interacts only with Opacity, so it no longer depends on Smudge Length. The docs say this version is also slightly faster.
  - **Dulling** mode samples the color under the dab (within Smudge Radius) and fills the dab with it before applying color and opacity.
  - Smearing needs spacing of 0.05 or less to look smooth. For dulling brushes, raise spacing as far as it goes without choppiness, for speed.
  — [Krita docs: Color Smudge Engine](https://docs.krita.org/Color_Smudge)
- An older Krita bug shows why Color Rate and Smudge Length must be separate controls: if they are tied, you cannot make opaque brushes that blend slightly — [KDE bug 353665](https://bugs.kde.org/show_bug.cgi?id=353665)
- Procreate's engine, Silica M (Procreate 4, 2017), is built entirely on Metal, and Procreate says it taps the GPU directly for painting, smudging and adjustments — [Procreate: Meet Procreate 4](https://procreate.com/insight/2017/meet-procreate-4); [Procreate Pocket 2 release](https://procreate.com/insight/2018/pocket-2-release)
- Research on GPU stroke rendering: Ciallo (SIGGRAPH 2024) renders vanilla, stamp and airbrush strokes on the GPU with vector-editable geometry. A Blender developer calls the stamp brush the most common brush type and cites their SIGGRAPH 2023 talk on GPU stamp rendering — [Adobe Research: Ciallo](https://research.adobe.com/publication/ciallo-gpu-accelerated-rendering-of-vector-brush-strokes); [Blender devtalk](https://devtalk.blender.org/t/add-stamp-brush-and-fix-airbrush/30884)
- Apple developer forum users report that they have not found a clean way to keep a Metal canvas fast as it fills up — [Apple Developer Forums](https://origin-devforums.apple.com/forums/profile/kyroneus/replies)

### Inferences
- Suggested Metal pipeline (my design, not sourced):
  1. Gather coalesced touches.
  2. Run the stabilizer (offer Pulled String, Moving Average with Catch Up, and a mass-spring "Weighted" mode, plus Procreate-style Motion Filtering that rejects outliers).
  3. Fit a Catmull-Rom or cubic curve and resample by arc length at spacing × size.
  4. Emit dabs as instanced quads (per instance: position, size, rotation, opacity, color, grain offset) into an offscreen stroke texture with max-alpha or flow accumulation.
  5. Composite the stroke texture onto the layer with the layer blend mode on each frame, and bake it into the layer on pen-up. A separate stroke buffer is what makes glaze vs. blending modes and per-stroke opacity caps possible.
- Predicted touches: render them only into a throwaway overlay each frame and discard them when the real samples arrive. When `touchesEstimatedPropertiesUpdated` delivers late force values, re-render the dabs for the affected tail of the stroke.
- Grain in a fragment shader:
  - Texturized grain: sample with canvas UVs.
  - Moving grain: sample with UVs that accumulate along the stroke's arc length.
- Dual brush: render a second dab stream into its own mask texture and combine the two in the composite step (multiply, subtract or darken).
- Wet mix / smudge: before writing each dab, sample the canvas under it (a small compute pass or a read with framebuffer fetch on Apple GPUs) into a "brush reservoir" color, then blend reservoir and paint color using Dilution and Charge. This forces serialized per-dab passes, so batch only dabs that do not overlap.

### Gaps
- No primary source on how Procreate's Wet Mix parameters (Attack, Pull, Grade) map to math. Silica M internals are not published.
- Infinite Painter's brush engine: no sources gathered in this pass.
- The Procreate dual-brush page and Lazy Nezumi's exact formulas were not retrieved.

## Procreate features: QuickShape, StreamLine, Liquify, selection feathering, Animation Assist, reference companion, color harmony, gestures

### Takeaway
Procreate's advantage is low-friction recognition and assist tools: hold-to-snap shapes, five-mode color harmony, a Liquify suite, and Animation Assist with onion skins, hold frames and three playback modes. All of these can be built in a Metal app at moderate cost.

### Cited Findings
- QuickShape: draw a shape and hold, and Procreate converts it into a clean shape. Procreate's education material counts six shape types (line, arc, ellipse/circle, rectangle/square, triangle, polyline; I added the list from general knowledge) — [Procreate update 4.2](https://procreate.com/insight/2018/procreate-update-42); [Procreate education PDF: painting tools](https://education-downloads.procreate.art/pdfs/part2-painting-tools.pdf)
- Liquify (4.2) added Edge and Crystals modes, along with Distortion and Momentum controls — [Procreate update 4.2](https://procreate.com/insight/2018/procreate-update-42)
- Color Harmony has five modes: Complementary, Split Complementary, Analogous, Triadic, Tetradic — [Procreate Handbook: Colors](https://help.procreate.com/procreate/handbook/5.0/colors)
- Animation Assist:
  - Onion skin ranges from none up to 12 surrounding frames, with an opacity slider. Default tints are red for previous and green for next frames — [Procreate Handbook: Animation interface](https://help.procreate.com/procreate/handbook/animation/animation-interface); [Design Bundles tutorial](https://fontbundles.net/design-school/how-to-animate-in-procreate-with-animation-assist)
  - Hold Duration is set per frame and shows as grayed duplicate frames — [Procreate Handbook: Animation settings](https://help.procreate.com/procreate/handbook/5.0/animation/animation-settings)
  - Playback modes are Loop, Ping-Pong (forward then reverse) and One Shot. One third-party site wrongly calls ping-pong "random" — [Procreate animation settings](https://help.procreate.com/pocket/handbook/animation/animation-settings); [Cartoon Brew](https://www.cartoonbrew.com/apps/procreate-5-expands-animation-features-in-new-release-183662.html)

### Inferences
- QuickShape: on a dwell timer (about 0.5 s with no movement while the pen is down), fit candidate shapes and pick the lowest normalized residual:
  - line: least squares
  - ellipse: algebraic conic fit (Fitzgibbon)
  - polygon: Ramer–Douglas–Peucker corner detection
  - arc: circle fit on a partial sweep

  Then turn it into an editable shape with handles, and snap to a perfect circle or square when a second finger touches.
- Liquify on Metal: keep a displacement-field texture (RG16F). Each brush dab adds push, twirl, pinch or expand vectors with falloff, and a render pass resamples the source layer through the field. Momentum means the push continues decaying after the finger lifts.
- Selection feather: a separable Gaussian blur on the R8 selection mask (MPSImageGaussianBlur).

### Gaps
- No official text was retrieved on the Reference companion window (canvas/image/face modes), Procreate's gesture list, or Liquify parameter math.

## Clip Studio Paint: vector layers and eraser, fill "refer other layers" / close gap, auto action, gradient map, line smoothing, perspective rulers, 3D figures, timeline, light table

### Takeaway
CSP's edge for line-art and manga work is two things. Vector strokes stay editable (width, erase-to-intersection) on a raster-looking layer, and fill can read line art from other layers while closing gaps. These two features matter most for an AMV/manga artist.

### Cited Findings
- The vector eraser's "Erase up to intersection" option deletes a line segment only up to where it crosses another line on the vector layer. It is not available in CSP DEBUT — [CSP Help: Eraser tools](https://help.clip-studio.com/en-us/manual_en/240_brushes/Eraser_tools.htm); [CSP tips: vector layers](https://tips.clip-studio.com/en-us/articles/7572)
- The fill tool's "Refer other layers" sub-tool fills on the current layer using line art on others. "Refer multiple" options are all layers, reference layer, selected layers, and layers in folder. Hidden layers are never referenced — [CSP tips: Mastering the fill tool ① Basics](https://tips.clip-studio.com/en-us/articles/590); [CSP tips: Reference layer](https://tips.clip-studio.com/en-us/articles/6463)
- Close gap: a larger value bridges bigger line breaks, but lines that are just close together may also be read as gaps and leave unfilled areas. Community advice is 7–15, or the maximum for very broken line art — [CSP tips: Closed area fill](https://tips.clip-studio.com/q/articles/591); [CSP tips 6344](https://tips.clip-studio.com/es-es/articles/6344?org=1)
- Sources disagree on whether multi-layer referencing is on by default — [CSP tips 590](https://tips.clip-studio.com/en-us/articles/590) vs [CSP tips 6331](https://tips.clip-studio.com/en-us/articles/6331)

### Inferences
- Vector layer in Metal: store each stroke as a polyline with per-point pressure, so it can be re-tessellated as a ribbon or re-stamped. Erase-to-intersection means computing segment intersections against the other strokes (with a spatial grid) and cutting the hit segment between the nearest two.
- Gradient map: a 1D LUT texture indexed by luminance. This is a cheap fragment adjustment layer.
- Auto actions: record the editor's command objects (already needed for undo) as a replayable macro.
- Light table: onion skin that pins chosen arbitrary frames or images instead of only neighboring frames.

### Gaps
- Gradient map, auto action, perspective ruler, 3D figure, timeline and light-table pages were not retrieved this pass. The search returned no authoritative source on them, so the descriptions above are general knowledge.

## Krita: assistants, wrap-around, brush preset architecture

### Takeaway
Krita adds snapping assistants (vanishing point, rulers and others) that you can toggle on and off, and a wrap-around view for seamless textures. Its preset system separates brush engines from the presets built on them.

### Cited Findings
- Wrap-around mode shows the image tiled orthographically, for making tileable textures. Painting assistants have their own show/hide toggle — [Krita docs: View menu](https://docs.krita.org/ja/_sources/reference_manual/main_menu/view_menu.rst.txt)
- A draft merge request proposes wrapping on one axis only (horizontal or vertical); it is not confirmed as merged — [KDE MR 1524](https://invent.kde.org/graphics/krita/-/merge_requests/1524)
- A Krita forum answer suggests combining Wrap Around with Vanishing Point and Ruler assistants to make array-style repeats, which ibis Paint offers as an "array ruler" — [Krita Artists](https://krita-artists.org/t/is-this-feature-that-is-available-in-ibispaint-also-available-in-krita-ruler-array-ruler/76381)

### Inferences
- Wrap-around in Metal: sample the layer with `address::repeat` in the display pass, and wrap dab positions modulo the canvas size (stamp up to four copies when a dab crosses an edge).
- Assistants: project each stabilized point onto the constraint (line, vanishing-point ray, ellipse, perspective grid) before resampling into dabs.

### Gaps
- No primary documentation was retrieved on Krita's preset architecture (engine + settings XML + resource bundle).

## Fill algorithms: perceptual tolerance, gap closing, anti-aliased edges

### Takeaway
Pro fills combine three things: a reference composite (line art from chosen layers), a tolerance test, and gap closing. Users accept that gap closing can leave unfilled areas next to lines that are merely close together, so it needs a slider and an option to expand the fill afterwards.

### Cited Findings
- CSP's close-gap trade-off and multi-layer reference behavior — [CSP tips 591](https://tips.clip-studio.com/q/articles/591); [CSP tips 590](https://tips.clip-studio.com/en-us/articles/590)

### Inferences
- Suggested algorithm (my design, not sourced):
  1. Build the reference image from the visible selected layers.
  2. Compute ΔE in OKLab against the seed color, giving a binary "barrier" mask.
  3. Close gaps by dilating the barrier with radius r (morphological), flood-fill from the seed (scanline fill on the CPU, or a GPU jump-flood/iterative compute pass on a downscaled tile grid), then dilate the result by r again so it reaches back under the line.
  4. Anti-alias the edge by using the line art's alpha as fill coverage (fill alpha = 1 − line alpha in the border band) instead of a hard mask.
  5. Add an "expand by N px" option to tuck the fill under the lines.

### Gaps
- No engineering source was found on how Procreate, CSP or ibis Paint implement fill.

## Undo architecture, tile-based canvases and layer compositing

### Takeaway
Big-canvas apps store layers as fixed-size tiles and keep undo as copy-on-write tile snapshots, so only the tiles a stroke touched are saved. They also cap memory with a pool and swap to disk.

### Cited Findings
- Krita's undo is built on transactions: the lifetime of a KisTransactionData object is the lifetime of that transaction's undo data. Commands follow QUndoCommand — [KDE: Krita Transactions Design](https://community.kde.org/Krita/Transactions_Design)
- Krita's tile system was rewritten (2008) so paint devices can share identical tile data for past states (memento) — [KDE commit digest 2008-05-25](https://commit-digest.kde.org/issues/2008-05-25/)
- Krita has a memory-bounded pooler thread limited by `memoryPoolLimitPercent`. Old undo states move to a swap file when memory limits are hit, and Krita can freeze if both limits are reached — [KDE commit digest 2011](https://commit-digest.kde.org/issues/2011-03-13/moreinfo/e09e0f0b9db6e95aa8a35c879c2d9b530f48d838/); [Krita docs: Performance Settings](https://docs.krita.org/Performance_Settings)
- Krita performance work with Intel is documented — [Intel: Enhancing UX in Krita](https://www.intel.com/content/dam/develop/external/us/en/documents/enhancing-user-experience-krita-application.pdf)

### Inferences
- Metal design (my suggestion, not sourced):
  - Use 256×256 tiles in an MTLHeap.
  - Each stroke keeps a dirty-tile bounding set. On pen-down, `blit` copy the tiles the stroke will touch into an undo record, LZ4-compress them on a background queue, and swap old records to disk past a memory budget.
  - Composite with a cached "below current layer" and "above current layer" texture, so painting one layer costs 3 draws instead of N. Invalidate the caches only when other layers change.

### Gaps
- No tile-size or memory figures from Procreate or CSP were found.

## What artists say are must-haves and common annoyances

### Takeaway
ibis Paint complaints center on ads, upsells and export limits, missing brush-engine depth and animation, no Procreate brush import, and buggy PSD import. Procreate complaints center on sync reliability, missing vector tools, and lost work after crashes.

### Cited Findings
- ibis Paint's low ratings cite ads, premium push and export limits. Reviews say it lacks animation, advanced text and brush depth compared with Procreate and Fresco — [Unstar ranking 2026](https://unstar.app/blog/procreate-ibis-paint-sketchbook-adobe-fresco-concepts-drawing-apps-ranked-2026)
- Users want to import Procreate .brush/.brushset files into ibis Paint. Reviewers report broken PSD import and slow font loading — [Techjockey ibisPaint reviews](https://www.techjockey.com/reviews/ibispaint); [Capterra ES](https://www.capterra.es/software/1016388/ibispaint)
- Common 1-star themes across apps: crashes that lose hours of work, brush lag, paywalled layers. For Procreate specifically: sync issues. (The same source claims a Procreate "subscription"; Procreate is a one-time purchase, so treat that source with caution) — [Unstar ranking 2026](https://unstar.app/blog/procreate-ibis-paint-sketchbook-adobe-fresco-concepts-drawing-apps-ranked-2026)

### Inferences
- Features that would beat ibis Paint:
  - autosave and crash-safe journaling
  - .brushset import (it is a zip of a plist plus shape/grain PNGs)
  - layered PSD import/export that works
  - no layer caps beyond memory
  - CSP-grade fill with reference layers and gap closing
  - vector ink layers
  - an animation timeline with onion skin, holds and ping-pong, tied into the AWIeffect editor

### Gaps
- No Reddit threads came back from search; artist sentiment here comes from review aggregators of moderate reliability.
