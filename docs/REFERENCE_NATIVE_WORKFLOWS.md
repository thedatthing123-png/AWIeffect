# Native reference workflow mapping

The pixel import accounts for 513 of the 560 active reference definitions, using another 34 private dependency programs. The remaining 47 definitions modify native objects or select several shader groups through their host. A fragment-only wrapper would not reproduce them. Their XML/scripts are inspected as data and are not executed.

Existing AWI systems to compare before creating duplicate effect entries:

| Reference operations | Existing implementation |
|---|---|
| Fade, flicker, pulse size/opacity, shakes, oscillate, swing, spin, random displacement/jitter | Layer transform/opacity keys; motion registry definitions and expressions |
| Motion blur, Chroma Key/Advanced Chroma Key, Spot Color, Replace Color, Voronoi Cells, sharpen, Hollow Box | Existing blur/key/color/procedural/3D definitions; shader-group parity needs review |
| Count Up/Down, Timecode | `TextCounter` and the Text Studio Counter / Timer controls |
| Smooth Text Animator, Text Progress, Text Randomizer, Text Transform, Text Spacing | Text Studio animators, range selectors, character offset/scramble and existing Letter Spacing |
| Grid/line/radial/scatter repeat, repeat | Existing repeat effects and shape Repeater |
| Time Quantization, Echo Keyframes | `TimeEffects`, frame sampling and graph/keyframe system; key-index-specific echo parity needs checking |
| Draw Progress, Stroke Color, Stroke Taper, Morph Path | Draw Progress, per-path fill/stroke, keyframed Bézier geometry and drawing brush taper; non-destructive vector parity is not established |
| Move Along Path, Scale Assist, Shake Parts, Grow Parts, blurmocurves | Position motion paths/graphs, separate scale axes, Text Studio selectors and existing effect stacks; host-specific contracts need checking |

Specific unresolved parity work: Repeat Along Path needs actual copies following another layer's outline, rather than a grid or a pixel-mask approximation. The [Alight Motion guide](https://guide.alightmotion.com/effects/repeat-along-path) confirms the outline comes from the layer beneath. Absolute-frame Timecode needs project-FPS-aware formatting; the existing counter/timer is not proof of that feature. Scale Assist's linked X/-Y behavior, key-index echo, and whole-shape-part selection must be assessed against their native contracts. Do not mark these solved by importing similarly named fragment shaders.

The original source records and their reasons remain in `REFERENCE_IMPORT_STATUS.json`. The full GPU batch validates the imported programs and the active AWI browser; it does not certify the native workflow parity listed here. Finish review and implementation of genuine gaps before calling the entire reference expansion complete.
