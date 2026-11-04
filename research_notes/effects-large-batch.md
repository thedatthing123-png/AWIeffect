# Effects expansion — larger batch and text research

This supplements the original 155-proposal roadmap. Build 7 is the baseline: ordinary Halftone, Lit Ripple, Time Slice Mask and Draw Progress are not being remade again. Prototypes below are not accepted until the final batch validates.

## Current image batch

| Entry | How it works | Main controls |
|---|---|---|
| Alpha Distance Field (#29) | Jump flooding finds the nearest alpha boundary; grayscale encodes signed distance, including holes | Range, Bias |
| Distance Bands (#30) | Draw contour bands at measured distances from the alpha silhouette | Range, spacing, width, phase, color, side |
| Distance-Gradient Warp (#92) | Move sampling along the silhouette distance gradient with edge falloff | Range, displacement |
| Matte Frequency Split (#39) | Gaussian alpha base plus independent high-frequency residual, recombined with valid premultiplication | Radius, base gain, detail gain |
| Local Contrast Matte (#44) | Select brightness differences relative to a local Gaussian average | Radius, threshold, softness, polarity, mix |
| Height to Normal Map | Encode luminance-height derivatives as RGB normals; the existing Normal Map Lighting instead bakes illumination | Strength, derivative radius, green convention |
| Lens Calibration Warp (#89) | Brown–Conrady radial and tangential distortion with bounded iterative inversion | K1/K2, P1/P2, optical center, inverse, mix |
| Spectral Prism Dispersion (#53) | Seven wavelength bands sampled along a prism axis; neutral reconstruction at zero separation | Separation, axis, spectral curve, mix |

Distance fields use approximate jump flooding plus an extra unit-step refinement. Two RG32Float buffers are reused, not a new buffer per step. The working grid is capped at 2048 on its longest side, bounding those buffers to 64 MiB combined. Sub-grid features can be lost at very large resolutions. Spectral Prism is an artistic seven-band approximation, not a physical optical solver.

## Older effect remakes

- **CMYK Halftone:** retain the current ID and Legacy mode. Add AM-style plate-center sampling, Amount, Strength, Black Weight and staggered Phase. Four plate angles follow the bundled reference. Existing Dot Size/Angle/Mix remain available in Legacy mode.
- **Halftone Lines:** retain the current ID and Legacy mode. Add line-center sampling, Amount, Strength and Phase. Existing line-spacing/contrast/color behavior remains in Legacy mode.
- New mode selection must initialize missing settings from defaults when switching an older effect. Irrelevant controls are hidden. These are two remakes, not two new counted effects.

## Text section missing from the original plan

These reuse Core Text layout, cached glyphs, Text Studio selectors/animators, keyframes and the common preview/export renderer. They do not append saved animators or alter source text. Based On selects character/word/line units; it does not change the glyph-centered transform pivot.

| ID | Effect and behavior | Controls | Current status / overlap |
|---|---|---|---|
| T01 | Text Transform: transform a selected unit range | Start/End, units, X/Y, rotation, scale, opacity | Prototype; uses existing selector engine |
| T02 | Text Progress: reveal without reflowing the remaining layout | Start/End, units, reverse | Prototype; exposes existing opacity-selector capability |
| T03 | Text Wave: travelling sinusoidal glyph displacement and rotation | X/Y amplitude, rotation, frequency, units per wave, phase, units | Prototype; builds on existing wave math |
| T04 | Text Jitter: coherent per-unit noise, deterministic on seeking | X/Y, rotation, frequency, seed, units | Prototype; shares existing Wiggle |
| T05 | Text Arc: bend each line onto a circular arc while retaining advance length | Bend, orient letters | Prototype; new layout operation |
| T06 | Text Color Ramp: color interpolation through unit order | Colors, repeats, phase, mix, units | Prototype; direct ordered color mapping |
| T07 | Character Offset: shift Latin letters and digits, preserve other scripts | Start/End, units, offset | Prototype; existing animator capability exposed directly |
| T08 | Text Line Spacing: multiply existing baseline spacing | Spacing | Prototype; existing layout control exposed, not new algorithm |
| T09 | Text Outline: animate hollow glyph width; zero is solid | Width | Prototype; existing glyph-outline renderer exposed, not new algorithm |
| T10 | Word Spacing: measure real space clusters instead of tracking every glyph | Space advance, anchor, tabs | Proposed |
| T11 | Paragraph Reflow: wrap within a shaped text frame | Box width, wrapping, overflow | Proposed; needs Core Text paragraph support |
| T12 | Intra-Glyph Gradient: vary color inside each letter | Gradient stops, axis, coordinate space | Proposed; differs from per-letter color spans |
| T13 | Font Contour Draw: reveal glyph outlines by contour length | Start/End, contour order, fill policy | Proposed; needs font contours, not a rectangular wipe |
| T14 | Fit Text to Box: shaping-aware font size solver | Width/height, size limits, overflow | Proposed; layout utility |
| T15 | Typewriter Caret: actual caret at reveal boundary | Caret style, blink, progress | Proposed extension of T02, not another reveal effect |
| T16 | Text Repeater | Copies, transform, phase | Audit generic repeater first; don't count duplicates |
| T17 | Text Follow Path | Offset, orientation, alignment | Already in Text Studio; discoverability improvement |
| T18 | Text Counter | Formatting, separators, units | Already present; optional catalog exposure |
| T19 | Variable Font Axes | Font-defined weight, width, optical size | Proposed; axis discovery and layout-cache changes needed |
| T20 | Paragraph Justification | Target width, gap limits, final-line policy | Proposed; preserve shaping, bidi and combining marks |
| T21 | Per-Word Pivot | Group anchor and word transforms | Proposed T01 extension; selection units aren't pivots |
| T22 | Per-Glyph 3D | X/Y rotation, depth, selector | Existing animators; extend T01 without inventing another 3D renderer |

Nine text catalog entries and eight image entries are prototyped. Several text entries expose existing functionality and are not claimed as nine new animation algorithms. Reworks and presets do not advance the 600-unique-capability target. The original backlog still needs overlap audits and infrastructure-heavy temporal/simulation work; this batch does not complete it.

## Batch validation

Use the existing table-driven registry, effect visibility, control-response, disabled-identity and extreme-setting tests for the entire catalog in one full run. Mode-dependent controls are tested in their relevant mode. Text uses multiline fixtures; alpha-detail operations use alpha-shape fixtures. Grouped batch checks cover zero-operation identity, alpha, distance sign/holes, normal-map output, source-text preservation, seeking, old project modes/defaults and save/reopen. Export actual Metal previews plus the runtime manifest. Physical iPhone checks remain necessary.

## Primary references

- [Adobe animating text](https://helpx.adobe.com/after-effects/desktop/animating-text/text-animation/animating-text.html)
- [Adobe text animation examples](https://helpx.adobe.com/after-effects/desktop/animating-text/text-animation-examples/examples-resources-text-animation.html)
- [AM Text Transform](https://guide.alightmotion.com/effects/text-transform)
- [AM Text Progress](https://support.alightmotion.com/hc/en-us/articles/10537154109841-Text-Progress)
- [AM Halftone Lines](https://guide.alightmotion.com/effects/halftone-lines)
- The user's bundled `halftonecmyk.xml` and `halftonelines.xml`, compared with the existing Swift/Metal implementations.
- [Rong/Tan jump flooding paper](https://www.comp.nus.edu.sg/~tants/jfa/i3d06-submitted.pdf)
- [OpenCV calibration equations](https://docs.opencv.org/4.12.0/dc/dbb/tutorial_py_calibration.html)
- [Blender bump/height-to-normal reference](https://docs.blender.org/manual/en/latest/render/shader_nodes/displacement/bump.html)
