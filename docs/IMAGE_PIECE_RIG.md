# Image-piece joints and IK

This checkpoint prioritizes separated 2D artwork with 2.5D camera/depth positioning. It does not require a 3D model, mesh binding, or weight painting. Unfinished mesh work is preserved separately on `feat/advanced-authoring`.

## Three-piece arm workflow

1. Import the upper arm, forearm and hand as separate layers. In Move & Transform, place their anchors at the shoulder, elbow and wrist. Position the pieces in their resting pose.
2. Use the existing Link control to parent the forearm to the upper arm and the hand to the forearm. Moving/rotating a parent carries its children.
3. Select the forearm and open Rig. Pick the upper arm in Upper Limb. Drag the on-canvas end-joint crosshair onto the wrist. Make IK creates a controller there without changing the rest pose.
4. Drag the controller on the normal canvas. The upper arm and forearm solve toward it; the linked hand follows the wrist. Bend the other way selects the elbow side.
5. Use the normal position keyframe button and timeline/graph to animate the controller. IK / FK is independently keyable: 100% follows the target, 0% uses the limbs' own rotation animation.
6. For a character-wide control, link the upper arm to a null before binding. New IK places its controller in that same parent frame, so moving, rotating, uniformly scaling or changing the null's depth carries the whole rig.

Existing projects retain their stored legacy IK behavior. Undo restores binding/link edits; normal layer timing and keyframe traversal remain in use. Opening Rig or moving an unbound rest-endpoint draft does not write an undo step.

## Validation

The earlier connected-joint checkpoint passed 62 focused tests. The current image-piece checkpoint adds an explicit three-piece hand attachment and shared character-null test, including rendered wrist alignment, depth inheritance and save/reload. Full validation and screenshot review are required before shipping its IPA. Simulator validation does not establish measured phone frame rate.

Advanced weighted deformation, topology editing and expanded typography are outside this delivery checkpoint.
