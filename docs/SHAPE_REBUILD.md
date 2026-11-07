# Shape contents — Build 22

Implements expansion-plan step 1, on the Build 21 baseline. Effects expansion has not started.

## Editing and order

Edit Shape contains ordered path and Merge Paths rows. Drag rows, or use Move Up/Down in their menus. Each path has
its own name, visibility, fill, stroke, gradient, transform, trim and operator stack. Tap a row to select it. Edit Points
opens the existing cursor/swipe-pad pen for that path only; Done commits one undo action and Cancel leaves it unchanged.
The selected path has canvas move/scale/rotate handles and gradient endpoints. Numeric controls use ValueScrubber.

Paths are ordered top to bottom (top draws over bottom). A Merge Paths row consumes the geometry above it; paths below
it are independent. Add unions; Subtract removes the upper paths from the bottom path; Intersect keeps the common area;
Exclude performs XOR; Merge keeps the compound contours without removing interior edges. The result inherits the bottom
path's fill/stroke. Source paths remain editable. Open paths are implicitly closed for boolean area operations.

Local operators precede path transform and Merge Paths. Whole-layer operators run on the result; whole-layer Repeater
copies the complete result. Existing ShapeOps order and one-step move semantics remain. Simultaneous trim applies the
same percentage to each contour; Individually measures consecutive contour lengths as one ordered sequence.

## Implementation and compatibility

`Layer.shapeContents` is optional. Nil retains the exact old rendering route; opening Edit Shape does not migrate or
rewrite the document. First contents edit copies the old animated primitive/path, fill and stroke into one path item.
Primitive size/points/roundness animation remains editable. New paths participate in AnimationTraversal and timeline
lanes, so clip moves/speed/reverse and copy/paste keys can see their animation. Clipboard replacement carries contents.
Extrusion stores compound contours so holes and disconnected pieces survive conversion to a 3D object.

Polygon booleans use Core Graphics CGPath union/subtract/intersection/symmetricDifference after adaptive flattening
(0.25 local-pixel tolerance). This is vector polygon clipping, not raster masking. No third-party clipper was copied.
Reference: https://developer.apple.com/documentation/coregraphics/cgpath

Compound GPU drawing shares PathGPU and premultiplied compositing with old paths/masks; separate contours are never
connected by synthetic chords. Linear/radial gradients are evaluated in path coordinates for fill and stroke.

## Acceptance

ShapeContentsTests covers old decode, booleans/areas/holes/coincident edges/curves, above-only scope, operator order,
undo, timeline timing, serialization, bounds and GPU rendering. ShapeContentsUITests covers row tap sizes, selection,
pen opening/cancel and screenshots. CI uploads a five-mode three-path logo sheet and an animated GIF in shape-renders.
Inspect both plus ui-screenshots before delivery; passing compilation alone is insufficient.

No Motion Sketch behavior or AI Link settings are changed. No user projects are deleted.
