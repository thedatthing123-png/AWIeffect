# Animation and timing — build 10

Starts from validated build 9. Preserve its position-field activation, group navigation and visible timeline rows.

## Owners and decisions

- `AnimationTraversal` remains the inventory for keyframe indicators, movement, speed and reversal, including text, masks, effects and puppet pins. Add grouped-time selection movement; occupied destinations are rejected instead of silently deleting another key. Marker identities stay tied to keys while dragging. The existing Move Keyframes sheet now moves multiple selected times as a block.
- `GraphEditor`, `FlowGraph` and `EffectGraph` remain the easing system. Handle gestures use their start handles plus translation; all-property drags share one undo transaction. Reversed math/hold curves display their actual easing and new edits clear obsolete reverse flags only on the edited segments.
- Connect the existing source-time map to Flow Graph. Time Remap opens an editor for source values, timing and signed playback-rate inspection, and uses the existing graph for segment easing. Curves and manual cubic Béziers can be subdivided when inserting source keys. Optional curve windows preserve ordinary sampled math segments without changing old saved curves.
- Velocity controls use the current transform tool's property and read its stored handles. Position applies to XY and Z together. These percentages are relative to a segment's linear speed, not absolute AE spatial units.
- Uniform speed changes stretch authored animation timing and the clip duration, including a group's hidden members. Frame-blending fallback and interpolated slow-motion bakes carry keys too. These do not retime expression source code or rewrite procedural effect time functions. The existing device-only interpolation output remains video-only; this is not a replacement optical-flow engine.
- The editable fast/slow ramp retains source endpoints and duration, and integrates a continuous piecewise-linear speed profile into Bézier source-time segments. The weights control the ramp shape; they are normalized to the existing source interval. Arbitrary existing remap interiors are replaced when applying this preset.
- Playback reverse and animation reverse remain separate reversible operations. Enabling an existing remap does not reset it. Disabling remap preserves its start/end source values with a constant average rate. Trim extension before source zero no longer shifts the frames in the retained part.
- Camera pad gestures pair XY/Z keys and account for a 2D camera's parent basis. Unlinking from an animated null samples inherited position, rotation, scale and depth at comp frames (36k-sample limit for unusually long layers). This keeps existing 2D parenting/2.5D depth semantics; it is not a new full 3D hierarchy/rig engine.
- Motion-blur detection follows several placements through the shutter, so out-and-back movement and full spins no longer disappear merely because their endpoints match. Existing camera/null/effect placement sampling and Pixel Motion Blur remain distinct.

## References

[Adobe time-stretching and time-remapping](https://helpx.adobe.com/after-effects/desktop/animate-in-after-effects/time-stretching-and-time-remapping/time-stretching-time-remapping.html) describes source-time values, graph-based retiming, speed and reversal. The source-time curve's signed derivative is playback rate; it is not a second independent speed animation.

[Blender Graph Editor](https://docs.blender.org/manual/en/5.2/editors/graph_editor/introduction.html) is a reference for selecting and transforming keys/handles. Mobile editing retains AWI's current panels and touch targets rather than adopting desktop controls wholesale.

## Verification required

Full simulator suite, new animation/timing unit regressions, UI checks for source editing/shared easing and multi-key movement, reviewed screenshots, then an unsigned device archive. Cover existing build 9 grouping/position tests, camera/null blur, reverse audio/source timing, project decoding and export. Physical-device editing and device-only interpolation still need phone validation.
