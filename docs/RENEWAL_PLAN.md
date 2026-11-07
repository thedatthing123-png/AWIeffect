# Old-feature renewal plan (from the full-app audit, 2026-11-07)

Four batches, each owning its own files so they can run in parallel. Every batch fixes its bugs FIRST, then renews
the shallow parts, then cleans the UI (44 pt targets, max 3 controls per row, real editing controls, no duplicates).
Saved projects keep opening.

## R1 — Timeline, keyframes, groups
Bugs (lose work):
- Undo lost after editing inside a group/precomp (Precomps.swift:80/142/149-158, EditorState.swift:723-731): closing must add one undo step for the inside work; history must survive.
- Splitting a group leaves the second half empty (EditorState.swift:424-437): split children too.
- Trimming a group doesn't trim children (TimelineEditing.swift:29-41).
- Trims run past the media start/end (TimelineEditing.swift:34-38).
- Moving a keyframe onto another silently deletes it (TimelineEditing.swift:58-65, KeyframeMoverSheet.swift:61).
- Copy/Paste Keys copies values not keyframes (TimelineEditing.swift:90-109): real keyframe copy (all properties incl. effects, easing, relative timing).
- Keyframe Velocity "all" skips size/fill/corner/effects (KeyframeVelocity.swift:89-126).
- Dead code clipHold/clipDrag (TimelineView.swift:306-346); FlowGraph curve not drawing (08-ov-graph); group member color bar.
Renew:
- Value graph + speed graph (real values, units/sec), multi-key selection and drag, separate X/Y.
- Marquee / multi-select keys on the timeline; keyframe stretch, reverse.
- Property lanes (twirl a layer row open: one lane per animated property).
- Ripple delete / ripple trim / close gap, slip, trim in/out to playhead, multi-clip move/trim.
- Ruler with frame numbers; named, colored markers (comp + layer markers).
- Expressions: pick-whip to other layers' properties, live errors, list of properties with expressions.
- History: timestamps; memory-light undo for big projects.
UI: transport bar to ≤7 primary controls (rest in a menu); timeline row header with lock/solo/visibility at 44 pt; 44 pt diamonds/handles; Trim/Split row becomes trim-to-playhead edits; graph presets readable.

## R2 — Canvas, transform, 3D scene, rig, masks, shapes
Bugs:
- Pivot drag jumps parented/3D/camera layers (CanvasTransform.swift:185-192); Scale/Rotate use the wrong center (:100).
- Motion Sketch records nothing with Snap off, 3D, or multi-select; old keys continue after (CanvasTransform.swift:130-162, MotionPath.swift:282-296).
- Motion path wrong under 3D/camera/anchor, hidden for parented (MotionPath.swift:335-375).
- IK erases keyframes, allows link loops, overrides rotation keys (IKRig.swift:102-104,176; IKSolver 69-70).
- New masks offset on transformed layers (PenTool.swift:36); mask outline ignores curves (Puppet.swift:281) and overlaps handles.
- Free view tap/handles offset (EditorView.swift:675/689, CanvasTransform.swift:38).
- Z diamond keys X/Y (TransformTools.swift:74-75); linked scale strips distort (:255-259); duplicate scale-link toggles.
- Physics wrong for parented layers, drops results past duration (PhysicsLab.swift:281-318).
Renew:
- Mask editing: add/delete points, curve handles (broken corners), move/scale whole mask, per-mask feather/opacity/expansion keyframes; pen: corner points with handles, insert point on segment.
- Motion path bezier handles + orient along path.
- Shape operators as reorderable cards with keyframes; Merge Paths, Round Corners, Twist, gradient fill/stroke; Trim Paths keyframes (start/end/offset).
- Snapping: anchor, grid, guides; scale snapping; rotation snap optional.
- Align/distribute to selection; fit/fill to comp; center anchor; reset transform.
- Canvas: tap-cycle stacked layers; marquee multi-select.
- Camera point-of-interest handle; light gizmo; lens buttons 44 pt.
- Rig: IK with FK/IK blend, 3-bone chains, bone overlay; puppet pin record, more pins.
UI: Position tool rows decluttered (Simplify as a scrubbable tolerance); 44 pt everywhere; tap-a-layer pick instead of name menus.

## R3 — Media, audio, export, projects
Bugs:
- Export size estimate ~half the real file (ExportSheet.swift:171-176, :120).
- Save Frame / range inside a group render the wrong comp (ExportSheet.swift:103-105, 262-263); AI Link /project uses the open group (AILink.swift:96-117).
- GIF caps not shown (Exporter.swift:282-294).
- Restore Version loses unsaved work without confirm (HomeView.swift:84-87).
- Delete is permanent (ProjectStore.swift:127) → Recently Deleted.
- Video import loads the whole file into RAM, fails silently (MediaImport.swift:22-28).
- Clip panel duplicates (Smooth Slow vs Frame Blending; Beat Sync twice; unused tempo).
- Punch on Beats overwrites scale animation, fixed strength.
- Project list decodes every project + black thumbnails (ProjectStore.swift:115-124).
Renew:
- Clip: trim end, slip, speed curve (editable presets, keep pitch), freeze frame, fade handles with curve shape, volume keyframes + clip waveform.
- Audio: EQ, compressor, pitch, denoise, ducking; beat markers editable (drag/delete), BPM grid with subdivisions.
- Export: ProRes 422/4444, image sequence, audio-only, custom in/out & work area, presets (TikTok/IG/Shorts), accurate estimate, opaque/JPG frame export.
- Projects: search, sort, folders, multi-select, Recently Deleted, named versions with preview, package export/import (with media), media bin + relink missing media.
- Settings: default size/fps, autosave interval, storage & cache management, backup/restore.
UI: clip panel tool rows ≤3 per row, Twixtor factor scrubbable, export sheet cleaned (no duplicate quality controls, codec visible for every format), visible project card actions.

## R4 — CC Studio, effects panel UI, color, particles UI
Bugs:
- CC histogram stale while scrubbing and races the preview (CCStudio.swift:81-82, 209-215).
- Color picker drag floods undo (EffectsPanel.swift:407-413, ColorWell.swift:171-249) — coalesce like Fill.
- Effect cards re-open on scroll (EffectsPanel.swift:328).
- Curve points can't move sideways, fixed 3 points (CCStudio.swift:269).
- Saved Looks not portable, missing LUT silently drops (CCStudio.swift:283-296, Grade.swift:46).
- Presets stack duplicates and overwrite opacity (PresetLibrary.swift:23-28, 59, 156); applying a Look wipes grade keyframes.
- Border/Shadow switch hides an active effect (ScenePanels.swift:141-143).
- Art Studio eyedropper blocks the main thread (DrawStudioView.swift:553-555).
Renew — CC Studio (merges the planned CC Studio renewal):
- Color wheels with 2D pucks + luminance ring (lift/gamma/gain/offset).
- Curves with add/remove points, Hue-vs-Sat / Hue-vs-Hue / Luma-vs-Sat.
- HSL secondary: 8-vector HSL + qualifier with softness and "show mask".
- Scopes: waveform, vectorscope, RGB parade.
- Bypass, A/B compare, white-balance eyedropper; looks saved inside the project; look-type color effects (Cross Process, Bleach Bypass, film stocks…) available as LUTs.
Renew — effects panel:
- Drag to reorder; per-effect mix % and solo; keyframable toggles/choices (hold keys); angle revolutions; point params scrubbable + on-canvas crosshair; save your own effect stacks as user presets; collapse all.
- Fill: linear/radial gradient fill; layer styles: inner shadow, glow, gradient overlay, stroke position.
- Blending: compact scrollable mode picker with live preview; track matte from any layer.
- Particles: on-canvas emitter handle, color over life, burst mode, floor collide.
UI: all effect-card controls 44 pt; FFX import moved into a menu; CC tabs not cramped.
