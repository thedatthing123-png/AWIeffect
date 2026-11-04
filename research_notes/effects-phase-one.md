# Effects phase one — first implementation batch

## References and scope

Inspected the user's AE Motion 2.5 IPA, including `bcc_ripple.xml`, `time_slice_mask.xml` and `halftonedots.xml`. These are bundled effect definitions, not proof of pixel equivalence with commercial Boris FX or Adobe plugins. No downloaded code or dependency was added. The Metal implementations integrate the reference mathematics with AWIeffect's premultiplied compositor and vector paths.

Primary documentation:

- [Alight Motion Drawing Progress](https://support.alightmotion.com/hc/en-us/articles/10537114872337-Drawing-Progress): path-length reveal, Start/End remove segments; filled shapes close across remaining endpoints.
- [Alight Motion Halftone Dots](https://guide.alightmotion.com/effects/halftone-dots): project-width Amount, tonal Strength, grid Angle, staggered Phase and two colors.
- [Boris FX Ripple](https://borisfx.com/documentation/continuum/bcc-ripple/): contextual ripple/lighting reference. The user's custom IPA effect is the immediate behavioral target.

## Implemented

### BCC-style Lit Ripple

Separate from existing Ripple and Water Ripples. The reference uses radial sine displacement, exponential decay and cosine-shaped light bands. Defaults match the supplied effect: Strength .02, Frequency 20, Speed 1, Radius Scale 1, Decay .5, centered origin, Light Intensity .3, Sharpness 2, full mix. The net highlight multiplier is .5, matching the reference's added light minus half-light. Added optional tint. Transparent pixels do not acquire RGB pollution. Mix zero preserves the original.

Tests compare pixel brightness and radial resampling to the supplied reference equations at multiple positions and times; additional tests cover tint, animation, alpha and mix identity. These establish the tested cases, not universal pixel equivalence with every similarly named plugin.

### Time Slice Mask

The supplied custom shader is a moving striped alpha mask. It does **not** sample different video frames, despite its name. Count, Smoothness, Speed, Angle and Feather follow that construction. Phase allows keyframe control. Reverse inverts the coverage (the supplied shader declares Reverse but does not use it). Reveal Layer applies coverage to existing pixels; White Mask emits white/alpha for track-matte use. Zero smoothing/feather have defined hard-edge behavior, avoiding equal-edge smoothstep.

### Draw Progress

Uses saved vector/freehand geometry and the existing length-based path rasterizer. Start and End delimit the visible percentage interval, with defaults 0 and 100 verified against the bundled drawing-progress.xml. Animate End from 0 to 100 to draw on. Multiple instances trim the surviving geometry. Filled shapes close between visible endpoints; the stroke does not gain that closing chord. Existing Stroke Trim is applied to the surviving stroke. Saved geometry/keyframes remain unchanged. Raster Art Studio paintings do not store stroke history and cannot be replayed by this feature; the picker disables it for raster layers and the panel explains vector use.

### Halftone rework

Same `awi.halftone` ID; not counted as a new effect. Newly added instances default to AM Dots: Amount controls project-relative grid density, Strength controls the tone threshold, Phase staggers rows, Angle rotates the grid, and Ink/Paper set its two colors. Default colors follow the supplied XML. Optional Print Screen offers an antialiased area-based print look, and Color Dots/Mix extend both new modes. Controls irrelevant to the current rendering mode are hidden.

Older saved instances without a version field retain the original renderer. The inaccurate `CC Ball Action` import alias was removed: 2D halftone is not a replacement for 3D ball displacement. Such unsupported imports should not silently pretend to be equivalent.

## Validation and remaining work

Full CI is required on the final commit, including the existing effect/control regression suite and dedicated phase-one tests. Exported preview PNGs allow inspection of actual Metal output. iPhone interaction and long editing sessions still need device checks.

This is the first focused batch of the larger effect expansion, not completion of the 600-effect goal. Art Studio reworks, major 3D/physics, additional effect reviews and the rest of the expansion remain separate batches.
