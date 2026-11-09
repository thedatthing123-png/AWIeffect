# Rig authoring - Build 28 candidate

Two workflows share the existing layer transforms, timeline keys and graph editor.

## Separate pieces: Rig

1. Set each piece's anchor at its joint. Parent the pieces in order, or attach artwork to a drawn bone.
2. Select the end piece/bone in Rig. Choose Root / Upper. Leave Controller empty to create a target, or choose an existing layer outside the driven chain.
3. Make IK. Drag the target on canvas or use the Rig X/Y pad. The existing transform timeline keys animate that target. IK / FK is separately keyable.
4. End artwork attaches an extra piece at the reached joint, rather than allowing it to float beyond an unreachable target.

## One continuous image/vector: Bone / Weight

1. Select the artwork and open Bone / Weight. Draw Bones; each new stroke continues the selected tip. Done exits creation.
2. Select any earlier bone on canvas or in Bone hierarchy, then Branch. This makes another child of that selected bone, not another child of the last-created tip.
3. Edit Rest adjusts joint placement with the existing X/Y fields/pad or joint head. Pose rotates a selected bone or drives its IK target. Leaving Edit Rest refreshes bind matrices while retaining painted weights.
4. Bind Mesh generates regional vertex weights. Pixels far outside the influence radius retain the artwork transform. Binding options controls mesh detail and influence reach; Reset Auto Weights is undoable and replaces painted weights.
5. Weights opens the rest-pose heatmap on the same canvas. Choose an influence, then Paint, Erase or Smooth. Size controls brush radius; Strength controls weight change; Hardness controls edge falloff. Locked influences retain their values. Every stroke normalizes weights automatically and commits as one undo step. A second-finger viewport gesture cancels an unfinished stroke.
6. Done returns to posing. Deform blends the mesh result with the original artwork; it is neither input sensitivity nor IK stretch.

## Hierarchy and precision

Parent chooses a new parent in the same skeleton and rejects cycles. Deleting a bone reparents its children and removes that influence from the mesh. The X/Y pad uses a fixed projection from gesture start, not the moving joint's latest output. Numeric entry stays in the coordinate space named above the pad. Fine changes input gain only.

Copy/duplicate and grouping/precomposition carry a bound artwork's owned skeleton and targets. References are remapped to the copied bones. Existing saved Puppet-based skins remain available until explicitly upgraded.

## Candidate limits

This uses a rectangular subdivided mesh with up to four influences per vertex, not an automatic outline-traced topology editor. Dense bends may need weight painting and more mesh detail. Stretch/soft-reach controls remain future work; joint lengths stay fixed. Actual iPhone responsiveness requires device testing; simulator tests and rendered artifacts do not establish phone frame rate.

## Algorithm references

- [Spine weights](https://esotericsoftware.com/spine-weights): normalized vertex influences, brushes, locking and binding updates.
- [Spine IK](https://esotericsoftware.com/spine-ik-constraints): target-driven rotation, mix and separate stretch/softness concepts.
- [FABRIK paper](https://www.andreasaristidou.com/publications/papers/FABRIK.pdf): forward/backward fixed-length chain solving.
- [Adobe Puppet](https://helpx.adobe.com/after-effects/desktop/animate-in-after-effects/animate-with-puppet-tools/animating-puppet-tools.html): image deformation and animated pin authoring.
