# Priority polish — build 8

The 125+ expansion is paused. This branch starts from delivered build 7, not the unvalidated expansion prototype.

## Existing owners inspected

- Deep Glow: the original six-blur stack and alpha/light mismatch were inspected, then replaced by `DeepGlow.swift` / `DeepGlow.metal`: energy-normalized logarithmic scales, threshold softness, gamma correction, hue-preserving tone shoulder, falloff, glow-only/mix and bounded 256/512/1024 work grids. Radius/exposure ranges expand. This approximates a long-tailed light kernel; it is not the commercial plugin implementation. Per-layer scratch scopes allow tracked Metal resources to be reused by later encoders in the same command buffer. Pools must still remain exclusive to a single in-flight frame.
- Tracking: `VisionTools.swift`, `CutoutTrackUI.swift`, `ClipPanel.swift`, `LayerHome.swift`. Existing accurate Vision object tracking respects video source time, reverse/remap, parenting and undo. Add optional symmetric weighted smoothing to the samples before writing keyframes. Zero preserves the raw track; endpoints stay anchored. This is position tracking, not a new planar or 3D tracker. Move its entry to its own layer-home tile.
- Import: `MediaPicker.swift` and `MyLibrarySection` in `QuickTools.swift`. Reuse the same albums/favorites browser for library import. Ordered selection, numbered badges, a 20-item cap and sequential processing prevent asynchronous download completion from reordering the import calls. Failure remains visible rather than silently dismissing the browser.
- Cutout: `CutoutBrush.swift`. Add a pointer-centered magnified crop without replacing the existing smart matte brush or Art Studio's independent selection tools.
- Color: `ColorWell.swift`, `EditorView.swift`. Editor swatches launch a canvas overlay rather than a separate full-screen image panel. Rendering a sample image internally is still required to read GPU colors; the actual editor canvas stays visible. Non-editor contexts retain the previous fallback.
- Export: `ExportSheet.swift`, `Exporter.swift`, `Renderer.renderImage`. PNG already encodes alpha but the project canvas fill made it opaque. Frame export clears that fill. MOV-alpha is the default video choice; explicit background layers still render. MP4 remains an opaque format. Physical-device codec and Photos compatibility still require phone validation.
- Sweep: `EffectRegistry10.swift`, `Effects10.metal`. Keep the straight sweep ID, defaults and formula; enlarge width/intensity/speed/offset ranges. Organic Light Sweep is an additional curved, multiscale sinusoidal contour clipped to existing alpha. Curvature, irregularity, contour scale and keyframeable evolution change the light, not geometry. It is an artistic highlight, not physically based lighting or an implementation of a named commercial plugin.
- Turbulence: existing `fxWarp` already uses multioctave noise. Add X/Y/XY displacement, anisotropic scale and noise offsets. Missing parameters retain old isotropic behavior. This is an extension of the existing effect, not a renamed catalog entry.

## Additional editing fixes requested

- Puppet pin animation already existed. Each pin now exposes its own keyframe diamond using the existing effect-keyframe API.
- Null objects already existed in Quick Tools and now also appear in Add → Basic.
- XYZ uses one position diamond and a local XY/Z pad selector. Saved XY/Z channels remain compatible; new editing pairs key times instead of presenting a separate depth tool.
- Multi-selection scale/rotate changes propagate around the primary anchor through each member's parent projection. Selected descendants inherit once.
- Move-start/end actions reuse existing clip movement, preserving clip length and shifting keys. Group movement shifts descendants too.
- Plain 2D ungrouping bakes container movement/scale/rotation/opacity; group-wide filters, masks, non-normal blending and 3D projection cannot be distributed among individual layers without altering the composite, so those cases give an explicit message. Un-precompose brings members into an editable group to retain container treatments; restore normal speed and disable remapping before unpacking retimed comps.
- Pre-render exports an alpha preview cache through the existing exporter, fingerprints composition/dependencies, ignores volatile dates/cache metadata, and checks the fingerprint before reuse. Final export bypasses proxies and renders the original layers. A changed source automatically invalidates the cache.
- Phone-image file decoding has a UIKit, orientation-aware fallback. Native model import validates meshes before adding a layer, stores a SceneKit archive and sets 3D automatically. GLB/glTF use MIT-licensed GLTFKit2 0.5.15; FBX mesh import uses pinned ufbx v0.23.1 with its license retained. This adds mesh/material import; animated FBX rig editing is not claimed. External texture access depends on file-provider permissions; embedded resources are preferable.
- Pixel Motion Blur moves from Time into Motion Blur, with amount, sample count and maximum trail. Its settings persist while off. Frame blending no longer returns before pixel blur can run. Layer shutter range expands to 1440 degrees and maximum samples to 64; preview remains adaptive.


## Reference checks

[Adobe tracking documentation](https://helpx.adobe.com/after-effects/desktop/animate-in-after-effects/track-motion/tracking-stabilizing-motion-cs5.html) describes applying tracked motion to another layer and confidence/adaptation concerns. [Apple Motion's tracking strategies](https://support.apple.com/en-in/guide/motion/motn20fba77/6.4/mac/26.6) describes smoothing with neighboring tracked samples. Our symmetric triangular window avoids causal-filter delay; it does not claim to improve the underlying Vision observations.

[Adobe Distort effects](https://helpx.adobe.com/la/after-effects/desktop/apply-effects-and-animation-presets/list-of-effects/distort-effects.html) distinguishes turbulence displacement and evolution. The supplied IPA contains multiple turbulence variants; the shown X/Y/XY controls motivate the axis options, while the existing AWI noise implementation remains its owner.

Time Slice is deferred to a separate deeper pass at the owner's request, after these faster fixes. The supplied IPA's `time_slice_mask.xml` emits grayscale/alpha stripes, while `atimeslice.xml` is a striped transition from content to composition. Neither samples different footage times. The owner rejected another mask variation. [Adobe's Time Displacement documentation](https://helpx.adobe.com/after-effects/desktop/apply-effects-and-animation-presets/list-of-effects/time-effects.html) describes genuine pixel time displacement and slit scanning. The current saved mask stays compatible; this build does not claim a completed Time Slice remake.

The glow reference is [Plugin Everything’s product documentation](https://www.plugineverything.com/deep-glow), which describes falloff, gamma and threshold softness. Import sources: [GLTFKit2](https://github.com/warrenm/GLTFKit2) and [ufbx](https://github.com/ufbx/ufbx/tree/v0.23.1).

## Verification

Full simulator suite and archive are required, including existing rendering, export/audio, timeline and UI regressions. Added checks cover tracking smoothing/identity, black-glow halo coverage, sweep alpha/identity and old turbulence defaults. CI success is not physical-device validation. The larger 3D/rigging and Art Studio renewals remain separate as requested.
