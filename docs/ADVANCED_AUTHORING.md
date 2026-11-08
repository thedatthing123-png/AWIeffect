# Advanced authoring — reference-driven implementation

Owner request, November 8, 2026. This extends Build 24; it does not replace Text Studio, Motion Sketch, the graph remake, shape contents, the repaired timeline or cutout workflow. Work on feat/advanced-authoring. Do not change AI Link or delete user projects.

## Intended editing workflow

The user prepares separated artwork. Select the pieces, establish connected shoulder/elbow/wrist or hip/knee/ankle joints, bind the rest pose, then pose the hand/foot target directly. FK rotates individual bones; IK positions the target; mixing must be keyable without destroying either track. Attachments follow the chosen bone. Flexible artwork binds to a real mesh with normalized bone weights; it is not another name for the existing Puppet Pins warp.

All authoring belongs on the canvas and in the existing Rig, Puppet, Text Studio and graph panels. No preset-only approximation, global mode drawer, button-count cleanup or nested menus for everyday editing. Keep 44-point targets and at most three controls per row. Frame changes must not rebuild topology, triangulate artwork, regenerate weights or recreate GPU pipelines.

## Existing systems inspected

- IKRig.swift: analytic two-bone constraints stored on lower layers. Existing makeIK preserves animation via setParent; previously assumed bottom-center tip and positive bend on binding.
- CanvasOverlays.swift: rig bones were drawing-only. Positioning must share LayerPlacement and displayPlacement camera/parent transforms.
- Parenting.swift: solve IK before parent transforms, then project through the active camera. Camera motion must never alter bind coordinates.
- Puppet.swift / Effects18.metal: up to 32 keyed pins, starch, inverse rigid MLS pixel warp. Keep compatibility; do not pass it off as weighted skinning.
- SoftMeshEffect.swift: existing forward triangle renderer for baked physics meshes. Candidate rendering infrastructure, not an editable skeletal mesh model.
- TextStudioLogic.swift / TextAnimateEditor.swift / Text.swift: stable character IDs, exact-letter selectors, offset/anchor authoring, additive animator properties and letter effects already exist. Extend these rather than introducing duplicate text transform/progress effects.

## Implementation sequence and acceptance

### 1. Rest joints and direct posing

- Author wrist/ankle endpoints on the artwork, including sideways images. Setup is transient until Bind/Make IK; one binding action is one undo entry.
- Capture the authored bend side; binding must not flip the elbow or rotate the image unexpectedly.
- Picked controllers define the actual endpoint. Keep existing projects' stored lengths and bend values unchanged.
- Direct target dragging uses an initial gesture snapshot plus screen translation, converted through the existing parent/camera projection. Never recalculate motion from a moving handle's local touch coordinates.
- Joint selection, rest editing and posing must be distinguishable without placing a control rack on top of the artwork.
- Validate mirrored/scaled parents, unreachable and coincident targets, chained constraints, target cycles, cancel, undo/redo, serialization and preview/export agreement before extending the solver.

### 2. Mesh binding and weights

- Backward-compatible optional mesh binding data: vertices/rest UVs, topology, bone references/inverse bind transforms, normalized bounded influences.
- Bind selected artwork to its existing hierarchy. Automatic weights provide a starting point; visible weight painting, smoothing, locking and removal permit correction.
- Use a shared forward mesh renderer with cached topology and GPU resources. Transparent silhouettes and overlapping folds must render without filling transparent space or seams.
- Preserve the existing Puppet tool; allow flexible hair/clothing independently of rigid separated limb attachments.
- Deterministic evaluation at arbitrary times. No playback-history-dependent spring state. Bake secondary motion when needed for reproducible scrubbing/export.

### 3. Typography authoring

- Extend selected-letter manipulation and existing animator graphs: intentional pivot editing, rotation/scale/depth posing, keys and coordinated pose changes.
- PHANTOM reference: separately controlled letter/stroke assembly, stagger, local deformation, settle and glow timing.
- Hello → symbol → Evolve reference: independently pose selected glyphs into the intermediate composition. Outline/path authoring is needed where actual shape geometry changes; do not claim crossfade is a shape morph.
- Reuse stable character IDs; editing the string must preserve unaffected IDs and their animation. Preserve text fills/strokes, outline progress, 3D text and advanced selectors.

### 4. Staging and integration

- Rigs, null parenting and camera depth share one transform evaluation; 2.5D flips, hierarchy motion and motion blur follow the same evaluated pose.
- Manga reference acceptance: separate foreground/background, posed character/limbs, ball/weapon attachment, camera moves and editable energy trails/reveals.
- Keep effects as compositing building blocks. Do not expand the effect catalog as a substitute for authoring controls.

## Delivery gates

Use editable example projects, not flattened demonstration videos. Inspect moving renders of a sideways arm/hand IK chain, flexible hair mesh, camera depth flip, PHANTOM-style letter assembly, and letters posed into an intermediate symbol. Check small-phone UI screenshots for clipping and overlaps, touch cancellation and undo. Run unit/save/render regressions and full validation=all before publishing AWIeffect.ipa. Simulator success is not proof of measured 60 fps on the owner's phone.

## References

Behavioral references, not copied implementation:
- [Spine IK constraints](https://esotericsoftware.com/spine-ik-constraints): rest setup, targets, bend, mixing and soft reach.
- [Spine weights](https://esotericsoftware.com/spine-weights): binding, weight adjustment and normalized influences.
- [Spine transform constraints](https://esotericsoftware.com/spine-transform-constraints): attachments and mixed inherited transforms.
- [Adobe text animation](https://helpx.adobe.com/after-effects/desktop/animating-text/text-animation/animating-text.html): animator properties, selectors and anchor grouping.
- Local reference review: ../outputs/video-reference-review/REVIEW.md (four complete clips, timestamped contact sheets and native-frame closeups).

## Current status

Initial code change only: authored endpoint handle, controller-based endpoint capture, bind bend-side preservation, and regression tests. The mesh binding, typography extensions and full integration above are not implemented or verified yet. No new IPA is approved by this document.
