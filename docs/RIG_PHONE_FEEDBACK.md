# Rig polishing after Build 28 phone feedback

The owner tested the build: chains move, but weighted artwork sometimes remains partly fixed or stretches badly; ordinary piece-based IK controllers show an almost empty Bone / Weight panel; collider controls produce surprising poses. This is behavioral polishing, not permission to replace unrelated systems.

## Findings versus hypotheses

Confirmed in source: localized binding adds a rigid base influence outside a fixed 60px radius. That is useful for preserving a distant torso, but unsuitable as the only option for a wide cutout arm. Normal piece-based IK targets resolve to no drawable artwork, and binding only accepts authored BoneSettings nodes. Collider tests previously include the controller's own rectangle and driven pieces. Origin dragging is restricted to Edit Rest even though posing also needs translation. These are implementation/workflow gaps, not evidence that the user lacks editing knowledge.

Unconfirmed for the exact red-arm screenshot: whether it uses legacy MLS skinning, the new vertex mesh, custom weights, or a stale bind pose. The phone connector was offline; no user projects or AI Link settings were changed. Do not claim a screenshot alone establishes the exact source of every stretch.

## Changes in the Build 29 candidate

- Continuous artwork can bind either Whole artwork or Near bones. Whole artwork assigns every mesh vertex to actual deform bones; Near bones retains the fixed base region outside Reach. Saved bindings keep their weights until the owner explicitly resets them.
- Piece-based IK targets resolve to their controlled artwork. Bone / Weight offers its pieces, and the shared vertex renderer can optionally weight a piece to neighboring joints. Rig also exposes available artwork deformation controls.
- The position pad translates an FK joint rather than implicitly rotating its tip. Its frame comes from the exact displayed projection, including rotated/mirrored parents. The editor cache clears already-evaluated Auto Orient before parenting is baked, preventing an orientation from being applied twice.
- Selecting a bone origin in Pose selects translation for the existing X/Y pad; origin dragging translates the bone. Its tip rotates it. Rest editing remains a separate setup operation and updates bindings. With IK active, middle joint translation stays constrained; move the target or edit Rest instead.
- IK targets and driven pieces cannot act as obstacles to their own solve. New rigs start with solid avoidance off; real external obstacles are an explicit option. Existing old collision preference remains readable.
- Choosing the skeleton's own image as a rigid attachment opens its weight workflow rather than attempting a cyclic parent link.

## How to animate

For one cutout arm: place the bones along the arm in its original shape, choose Whole artwork, then Bind Mesh. In Pose, rotate a tip to bend the chain or drag an origin to translate its branch. Root movement carries descendants in FK. IK moves an end target while the root stays planted; moving a root with a world-space target can change the bend. To move the complete rig including an independent target, move their common artwork/parent transform.

For an arm inside a full character: Near bones preserves distant regions, while Whole artwork requires bones/weights for the body regions that must remain supported. Increasing deformation amount is not a substitute for correct weights.

For separate cutout pieces: parent their pivots as usual, create IK, then choose the specific artwork in Bone / Weight if it needs flexible joint transitions. Rigid pieces do not require painting.

Painting edits influence, not image pixels or 3D depth. Red means strong influence from the selected bone; blue means weak influence. Paint increases it, Erase redistributes it to other influences, and Smooth blends weight transitions with neighboring vertices. The base artwork influence is rigid relative to the artwork. Test the bend, refine its transition, then return to Pose. Automatic weights provide the starting pose; painting refines it.

## Primary research and what remains different

[Spine tools](https://en.esotericsoftware.com/spine-tools) explicitly distinguish origin translation, tip rotation, creation and weights. [Spine IK](https://esotericsoftware.com/spine-ik-constraints) controls rotations toward targets, separate from weight binding and from softness/stretch settings. [Spine weights](https://esotericsoftware.com/spine-weights) documents normalization, binding updates and topology-aware automatic weights. [Blender Armature Deform](https://docs.blender.org/manual/en/5.4/animation/armatures/skinning/parenting.html) distinguishes armature parenting, automatic weights and envelopes. [Blender pose/rest display](https://docs.blender.org/manual/en/latest/animation/armatures/properties/introduction.html) distinguishes setup geometry from animation.

AWI's current auto weights still use distance on a rectangular grid. They are not Spine's topology-aware solver or Blender's bone-heat implementation. Contour-aware mesh topology, more advanced automatic weighting, preserve-volume bending and IK soft reach/stretch remain separate work. Do not claim those exist because whole-artwork coverage was added.

## Validation gate

Build 28 source 89fd5c9 passed full CI run 42575382756: 679 passed, 0 failed, 1 skipped. That did not prove phone usability. Build 29 changes require fresh targeted interaction/model tests, textured moving-artwork review, full validation and final screenshot inspection before an IPA is sent.

## Additional phone feedback — brush, gallery, mask and rig controls

The next candidate also fixes Smart Edges discarding explicitly painted coverage, including ink outlines, in Art Studio and Remove BG. Slow brush movement cancels hold-to-pick as soon as a stroke moves, while a still hold remains an eyedropper shortcut. Select Brush stamps every event endpoint, and Quick Select preserves its swept brush disk instead of leaving high-contrast line fragments. AI Subject no longer adds a second vertical flip to Vision's pixel-buffer mask. A synthetic asymmetric buffer regression checks row orientation without depending on Vision recognizing a test character.

The existing Smooth brush control is now named Stabilizer and displayed on a 0–10 scale (0 = off). Refine Edge has an explanation of its existing Smooth, Feather and Shift Edge operations. The gallery's hard 3,000-item cap is removed; limited Photos authorization is clearly identified and the picker reloads after returning from Settings.

Rig keeps piece/controller posing and IK. Bone creation, hierarchy and branching live in Bone / Weight; New Root starts another root on the same artwork, Branch continues from the selected bone. Rig and Puppet start at normal pad gain rather than Fine. Fine is still available for small corrections.

Repeat and Back & Forth accept up to 1,000 cycles, evaluated in constant time. Bend now solves both sides of Start independently; Freeze, Same Side and Opposite Side are distinct. Tune Head/Tail limit the curvature at short, wide ends. This follows the documented circular-arc model, not extracted source code. New masks become one editable precomp with bounds based on the masked content in a 2D scene; inverse masks retain the target bounds. Camera/3D scenes retain full composition bounds to avoid applying a 2D crop to projection.

Primary references: [ibisPaint Stabilizer](https://ibispaint.com/lecture/index.jsp?lang=en&no=50), [Alight Motion Bend](https://guide.alightmotion.com/effects/bend). Exact frame-rate claims require phone profiling; a successful simulator test is not proof every effect stack sustains 60 fps. Music/beat detection is the next phase, not included as an already completed change.

Full run 42653473792 at 47fb213 reported 688 passed, 1 failed, 1 skipped. The failure was Time Remap's UI test at the newly added-key assertion after attempting to tap an offscreen control. The revised test requires the Add Key center to lie inside the visible clip panel before tapping, retaining its source-key/value/drag assertions. This cause remains subject to the next run; do not call it flaky without a passing unchanged rerun.

## Validation follow-up

Expanded run 42734826022 at 8b8a1b9: 691 passed, 3 failed, 1 skipped. The downloaded report exposed two model/render failures in addition to the graph UI failure initially reported from the failed-step excerpt. Art selection orientation/coverage, bounded mask render parity, rig tests and Time Remap passed in that run.

Corrections: the two-handle graph now uses logarithmic travel for 1–1,000 loop counts so increasing the upper limit does not make low counts jump by hundreds. Its regression checks both ordinary edits and the larger bound. The graph scroll content explicitly includes its padded edges in the hit surface; the failed UI test drags that edge to avoid grabbing a graph handle or numeric field. Failure diagnostics now save the screen and name the exact unreachable control. Bend tuning is tested in its documented active condition (short/wide ends, with tail bending enabled) instead of asking a curvature limiter to alter a mild default bend. No tests were removed or skipped.
