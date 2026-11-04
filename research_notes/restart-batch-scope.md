# Restart implementation gate — first audited foundations

The 125+ expansion objective is not considered complete by this batch. The 155-row ownership audit removes overlaps and leaves unresolved items explicitly unresolved. Nothing from the abandoned text-wrapper batch is merged wholesale.

## Demonstrated gaps selected for implementation

| Entry | Existing implementation checked | Missing behavior | Integration |
|---|---|---|---|
| Alpha Distance Field | Chokes, feather, alpha levels, outlines in Registry11/16 | Signed distance data from the alpha silhouette, including holes | Shared compositor, bounded jump-flood buffers, explicit grayscale encoding |
| Distance Bands | Luminance contours, ordinary borders | Multiple bands measured from alpha boundaries | Reuses distance field; correct alpha and extended bounds |
| Distance-Gradient Warp | Registry18 Displacement Map | Self-silhouette gradient displacement without an authored reference image | Shared image renderer and distance field |
| Matte Frequency Split | Alpha levels, chokes, edge refine | Independent low/high-frequency alpha gains | Existing Gaussian GPU passes and premultiplied color handling |
| Local Contrast Matte | Absolute brightness/color selection | Selection relative to neighborhood luminance | Existing Gaussian passes, defined threshold/polarity/softness |
| Font Contour Reveal | Text Studio visibility/selectors/outline width; shape Draw Progress | Actual intra-glyph contour tracing by measured path length | Core Text glyph paths, existing path rasterizer, existing glyph placement, animators and blur |

Font Contour Reveal traces all letters in parallel; it is not another Typewriter/Text Progress control. Its geometry cache is bounded. End zero yields an empty trace; full End yields outlined contours. Start/End can trace contours in font order or together. Multiple effect instances trim remaining geometry. Bitmap/color glyphs without font outlines fall back to existing rendering. Text Studio remains the owner of text animation, character transforms and future 3D expansion.

Distance fields use approximate jump flooding with an extra unit-step refinement and a 2048-pixel working-grid cap. Fine sub-grid features can be lost on larger inputs. Two RG32Float working textures are reused; they consume at most 64 MiB of pixel storage together, excluding driver overhead. This is not advertised as an exact full-resolution Euclidean solver.

## Legitimate remakes

CMYK Halftone and Halftone Lines are older effects. Their new modes follow the supplied plate-/line-center sampling and controls. Legacy mode and saved IDs are preserved; switching modes initializes missing fields from declared defaults. Main Halftone and the other build 7 additions are untouched.

## Validation contract

- Shared batch checks: registry, every effect/control, disabled identity and extremes.
- Grouped semantic checks: measured distance/holes, alpha, neutral recombination, legacy modes/defaults and print reference equations.
- Font checks: real multi-contour geometry, length trimming, empty/partial/full traces, coexistence with saved Text Studio animation, blur and save/reopen.
- Render actual previews and export a runtime manifest before accepting the batch.
- Do not claim 125 new effects, the 600 goal or physical-device validation from this foundation batch.

## References

- [Core Text glyph path extraction](https://developer.apple.com/documentation/coretext/ctfontcreatepathforglyph(_:_:_:)) — used through the existing shaped glyphs, not string-to-image imitation.
- [Rong and Tan, jump flooding](https://www.comp.nus.edu.sg/~tants/jfa/i3d06-submitted.pdf).
- Supplied `halftonelines.xml` and `halftonecmyk.xml`, checked against existing Swift/Metal implementations.
- [AM Halftone Lines](https://guide.alightmotion.com/effects/halftone-lines).

Other proposed algorithms require their own source/owner comparison. Similar names, presets and existing tools are not accepted as new capabilities.
