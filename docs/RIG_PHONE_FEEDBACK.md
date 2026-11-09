# Rig polishing after Build 28 phone feedback

The owner tested the build: chains move, but weighted artwork sometimes remains partly fixed or stretches badly; ordinary piece-based IK controllers show an almost empty Bone / Weight panel; collider controls produce surprising poses. This is behavioral polishing, not permission to replace unrelated systems.

## Findings versus hypotheses

Confirmed in source: localized binding adds a rigid base influence outside a fixed 60px radius. That is useful for preserving a distant torso, but unsuitable as the only option for a wide cutout arm. Normal piece-based IK targets resolve to no drawable artwork, and binding only accepts authored BoneSettings nodes. Collider tests previously include the controller's own rectangle and driven pieces. Origin dragging is restricted to Edit Rest even though posing also needs translation. These are implementation/workflow gaps, not evidence that the user lacks editing knowledge.

Unconfirmed for the exact red-arm screenshot: whether it uses legacy MLS skinning, the new vertex mesh, custom weights, or a stale bind pose. The phone connector was offline; no user projects or AI Link settings were changed. Do not claim a screenshot alone establishes the exact source of every stretch.

## Changes in the Build 29 candidate

- Continuous artwork can bind either Whole artwork or Near bones. Whole artwork assigns every mesh vertex to actual deform bones; Near bones retains the fixed base region outside Reach. Saved bindings keep their weights until the owner explicitly resets them.
- Piece-based IK targets resolve to their controlled artwork. Bone / Weight offers its pieces, and the shared vertex renderer can optionally weight a piece to neighboring joints. Rig also exposes available artwork deformation controls.
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
