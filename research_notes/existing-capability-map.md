# Existing capability map — restart baseline

Baseline: delivered build 7, commit `ca879d0`. This is a source-based ownership/overlap audit, not a claim that every feature is bug-free or has been tested on a phone.

## Owners and evidence

| Owner | Existing capabilities inspected | Source evidence | Consequence for expansion |
|---|---|---|---|
| Text Studio | Style, Letters, Animate, Animators, Counter, 3D; selected-range styling; split words/letters; presets | `App/UI/TextStudioPanel.swift`, `App/UI/TextStudio.swift` | No parallel Text Transform/Progress/Wave/Jitter/Outline/Line Spacing wrappers |
| Text model and renderer | Range/wiggly/wave selectors; character/word/line units; position, scale, rotation, opacity, fill, tracking, skew, blur, character offset, per-glyph X/Y/Z and outline; text on a path | `App/Model/Text.swift`, `App/Render/TextEngine.swift` | Improve the owner for typography/layout/3D changes. Extra text effects need a separate visual gap |
| Shape/path tools | Bezier and freehand paths, primitive conversion, stroke trim, repeater, offset, wiggle, zigzag, pucker/bloat | `App/UI/PenTool.swift`, `App/Model/Paths.swift`, `App/Model/ShapeOps.swift`, `App/Render/PathRenderer.swift` | Moving stroke windows are already trim/offset animation. Geometry proposals need path integration, not image wipes |
| Art Studio | Raster brush kinds, pressure size/opacity, taper, spacing/jitter, symmetry/ruler, paint layers, clipping/alpha lock, selection modes, transforms, undo, frames/parts export | `App/Draw/DrawEngine.swift`, `App/Draw/DrawStudioView.swift` | Replay requires a stroke journal; `DrawingDoc` currently stores layer image files and settings, not stroke events |
| Color studio | Basic grade, lift/gamma/gain wheels, curves, HSL isolation, LUT and looks | `App/UI/CCStudio.swift`, `App/Render/Grade.swift` | Do not add renamed grades or color-tool duplicates as new effects |
| Temporal tools | Echo, posterize time, freeze, frame blending, pixel-motion blur; speed/reverse/remap; motion interpolation | `App/Model/Project.swift`, `App/UI/ScenePanels.swift`, `App/UI/ClipPanel.swift`, `App/Media/SlowMotion.swift` | Frame interpolation already exists. New temporal algorithms must extend this pipeline and use real source frames |
| Motion tools | Easing, excite/overshoot, loops/ping-pong, anchor preservation, camera aim, depth/parallax scene setup | `App/Editor/MotionTools.swift` | Do not repackage those as independent movement effects |
| Physics | Rigid-body baking with circle and polygon SAT contacts; soft materials/plasticity; cloth/rope/liquid-related controls | `App/Model/PhysicsLab.swift`, `App/Model/SoftPhysics.swift`, `App/UI/ModelPhysicsPanels.swift` | Elastic sheets, melt and pigment simulations require owner review and real solvers. A noise warp is not a substitute |
| Scene / 3D | Camera/light/model tools, depth layouts, parallax camera moves; model/extruded text rendering | `App/UI/Scene3DPanel.swift`, `App/UI/ThreeDPanel.swift`, `App/Render/ModelRenderer.swift` | Keep scene, camera, materials and future 3D-text work in their systems |
| Rigging | IK, controllers, collisions and layer links | `App/Editor/IKRig.swift` | Deformation proposals must be compared with puppet/rig capabilities |
| Layer/reference compositor | Parent transforms, mattes, groups/precomps, adjustments, displacement of self or layers below, explicit map-layer input | `App/Render/Renderer.swift`, `App/Render/EffectRegistry18.swift` | Background-copy and reference operations are not empty new-name slots. New multi-input effects need cycle-safe reference handling |
| Particles | GPU emitter/model and dedicated particle layers | `App/Render/Particles.swift` | Particle transition proposals must use actual correspondence, not another emitter preset |

The physics header still describes circle-only collision, but its implementation includes polygon SAT contacts. `DESIGN.md` also contains historical platform/status statements. Implementation and current tests take precedence over stale descriptions; reading names/comments alone is insufficient.

## Concrete restart decisions

- Protect the main Halftone remake, Lit Ripple, Time Slice Mask and Draw Progress shipped in build 7. Demonstrate a defect before changing them.
- Reject the abandoned nine text-wrapper entries. Text Arc, paragraph layout, variable fonts and group pivots belong in a later Text Studio expansion. Existing color spans/selectors/presets must be checked before proposing text color tools.
- A **font-contour reveal** is a potentially genuine extra: Text Progress changes glyph visibility, while Outline changes stroke width. Neither traces a glyph's individual contours over time. It requires Core Text path extraction and the existing length-based path renderer; it must not be another opacity selector or rectangular wipe.
- Alpha-distance data and contour-distance operations are candidates because existing chokes, outlines and luminance contours do not expose measured signed distance. Confirm shape/holes, margins and scale behavior before acceptance.
- Brown–Conrady calibration belongs as an advanced mode of existing Lens Distortion; spectral separation must be compared with Chromatic Aberration/Prism Glow and preferably extend the relevant owner. Normal-map output should extend the existing material/normal workflow rather than create redundant lighting.
- CMYK Halftone and Halftone Lines predate build 7 and have specific sampling/control differences from the supplied references. They remain legitimate remake targets, preserving their saved IDs and legacy modes.
- Temporal median and general temporal percentile are one family; do not count them twice. Average exposure/trails belong with Echo/Time. Flash/color stabilization belongs with analysis and Color Studio. Optical flow interpolation already exists.

## Gate before each implementation

Record source evidence, the existing operation, the precise missing behavior, owning subsystem, required inputs/cache/bake behavior, backward compatibility and meaningful validation. An unresolved row stays unresolved; it does not become an accepted effect merely to reach 125 or 600.
