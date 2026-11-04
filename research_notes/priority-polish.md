# Priority polish — build 8

The 125+ expansion is paused. This branch starts from delivered build 7, not the unvalidated expansion prototype.

## Existing owners inspected

- Deep Glow: `EffectRegistry2.swift` and `fx19GlowKeep`. Six blur scales already exist. The defect is halo coverage based on summed blur alpha independently of emitted color. A black source can therefore darken the background despite emitting no light. Derive halo coverage from the tinted, saturated emitted RGB instead; retain the existing multiscale blur and hue-preserving limit.
- Tracking: `VisionTools.swift`, `CutoutTrackUI.swift`, `ClipPanel.swift`, `LayerHome.swift`. Existing accurate Vision object tracking respects video source time, reverse/remap, parenting and undo. Add optional symmetric weighted smoothing to the samples before writing keyframes. Zero preserves the raw track; endpoints stay anchored. This is position tracking, not a new planar or 3D tracker. Move its entry to its own layer-home tile.
- Import: `MediaPicker.swift` and `MyLibrarySection` in `QuickTools.swift`. Reuse the same albums/favorites browser for library import. Ordered selection, numbered badges, a 20-item cap and sequential processing prevent asynchronous download completion from reordering the import calls. Failure remains visible rather than silently dismissing the browser.
- Cutout: `CutoutBrush.swift`. Add a pointer-centered magnified crop without replacing the existing smart matte brush or Art Studio's independent selection tools.
- Color: `ColorWell.swift`, `EditorView.swift`. Editor swatches launch a canvas overlay rather than a separate full-screen image panel. Rendering a sample image internally is still required to read GPU colors; the actual editor canvas stays visible. Non-editor contexts retain the previous fallback.
- Export: `ExportSheet.swift`, `Exporter.swift`, `Renderer.renderImage`. PNG already encodes alpha but the project canvas fill made it opaque. Frame export clears that fill. MOV-alpha is the default video choice; explicit background layers still render. MP4 remains an opaque format. Physical-device codec and Photos compatibility still require phone validation.
- Sweep: `EffectRegistry10.swift`, `Effects10.metal`. Keep the straight sweep ID, defaults and formula; enlarge width/intensity/speed/offset ranges. Organic Light Sweep is an additional curved, multiscale sinusoidal contour clipped to existing alpha. Curvature, irregularity, contour scale and keyframeable evolution change the light, not geometry. It is an artistic highlight, not physically based lighting or an implementation of a named commercial plugin.
- Turbulence: existing `fxWarp` already uses multioctave noise. Add X/Y/XY displacement, anisotropic scale and noise offsets. Missing parameters retain old isotropic behavior. This is an extension of the existing effect, not a renamed catalog entry.

## Reference checks

[Adobe tracking documentation](https://helpx.adobe.com/after-effects/desktop/animate-in-after-effects/track-motion/tracking-stabilizing-motion-cs5.html) describes applying tracked motion to another layer and confidence/adaptation concerns. [Apple Motion's tracking strategies](https://support.apple.com/en-in/guide/motion/motn20fba77/6.4/mac/26.6) describes smoothing with neighboring tracked samples. Our symmetric triangular window avoids causal-filter delay; it does not claim to improve the underlying Vision observations.

[Adobe Distort effects](https://helpx.adobe.com/la/after-effects/desktop/apply-effects-and-animation-presets/list-of-effects/distort-effects.html) distinguishes turbulence displacement and evolution. The supplied IPA contains multiple turbulence variants; the shown X/Y/XY controls motivate the axis options, while the existing AWI noise implementation remains its owner.

Time Slice is deferred to a separate deeper pass at the owner's request, after these faster fixes. The supplied IPA's `time_slice_mask.xml` emits grayscale/alpha stripes, while `atimeslice.xml` is a striped transition from content to composition. Neither samples different footage times. The owner rejected another mask variation. [Adobe's Time Displacement documentation](https://helpx.adobe.com/after-effects/desktop/apply-effects-and-animation-presets/list-of-effects/time-effects.html) describes genuine pixel time displacement and slit scanning. The current saved mask stays compatible; this build does not claim a completed Time Slice remake.

## Verification

Full simulator suite and archive are required, including existing rendering, export/audio, timeline and UI regressions. Added checks cover tracking smoothing/identity, black-glow halo coverage, sweep alpha/identity and old turbulence defaults. CI success is not physical-device validation. The larger 3D/rigging and Art Studio renewals remain separate as requested.
