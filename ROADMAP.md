# AWIeffect roadmap

Goal: a phone editor good enough that the owner never needs After Effects, Alight Motion, Ibis Paint or Blender for an edit. "Done" means professional quality for the owner's own work, not a public release.

Rules for every item: read the existing system first, improve what's there before adding, test with real renders, and judge it on the phone. See `AGENTS.md`.

## Where things stand (November 2026)

| Area | State |
|---|---|
| Animation and timing (keyframe moving, speed, time remap, parenting) | Done, Build 10 |
| Art Studio renewal (brush engine, transform, smudge, vector paths, live filters, layers) | Done, Builds 11 to 12. Layer folders still missing |
| Cutout Studio (per-frame mattes, Keep or Cut brush, auto box) | First version, Build 13. Canvas zoom missing |
| 3D models as real objects | Done, Build 14 |
| Motion blur rebuild (master switch, every layer from the camera, shutter phase, true averaging, 3D models) | Testing, Build 15 |

## Planned, in order

1. **3D scene renewal.** Viewport with orbit, pan and zoom, grid, on-object move, rotate and scale handles. Camera lens, depth of field, 3D motion paths. Model settings and editable materials. Faster model rendering, so the camera stops being heavy and crashing. Masks on models. Later: playing animations inside imported models, and rigging.
2. **Text Studio and 3D text renewal.** Keep the advanced text tools; add extrusion and inflated 3D text, glyph outline reveal, variable font axes.
3. **Audio.** Waveform editing, fades, volume keyframes, cutting to beats by hand, sound effects, sync through speed ramps. Beat detection accuracy.
4. **Project safety.** Autosave, versions, crash recovery, backups. A crash never costs work.
5. **Masks and roto.** Feathered, animatable Bezier masks with tracking (AE's core comping tool, separate from Cutout).
6. **Tracking.** Planar and corner-pin tracking; attach text and effects to moving things. Motion tracking gets its own section with smoothing.
7. **Effects expansion to 600+.** First pass: remake the outdated effects (about half: the pixel, glitch, distortion and block effects; Mosaic is fine) before adding new ones. New effects include **Fractal Ridges** (match AE Motion's exactly: inspect its code for behavior and parameters), a custom **Pixel Blur** (blocky pixelated blur, built by the owner's spec if AE/AM don't have it). Each effect checked against AE and AM (AE Motion XML may be inspected for behavior). Includes Unmult, Hot Color, an upscale "quality" effect (on-device model, bake to process), remakes of Halftone family, Inner Glow and others that don't match, and a real Time Slice.
8. **Shape layers.** Trim paths, repeater, offset and wiggle paths, plus the vector pen in the main editor.
9. **Particles.** A real emitter for sparks, debris, dust and energy.
10. **Expressions.** Easy wiggle, loopOut and property linking on a phone.
11. **New preset system and previews.** After the effects are done.
12. **CC Studio renewal.** Look-type color effects (Cross Process, Bleach Bypass, Infrared, Day for Night, Cyberpunk, Lomo, Vintage Fade, Sepia, film stocks) are really LUTs: move them into CC Studio as LUTs, add many more LUTs, and give CC Studio finer grading settings.
12. **Media and export.** Proxies for heavy footage, high frame rate and HDR clips, quality presets, ProRes and transparent video, exports that match the preview.
13. **Workflow speed.** Own presets and rigs, templates, fast duplicate and replace.
14. **Performance pass.** Build on the existing precomp pre-render (faster to make, never stale after edits, used for heavy 3D). Final optimization. Crashes are fixed whenever they appear, not only here.
15. **SAM 2 cutout model.** After the app is done; train on saved hand-fixed frames if needed.

## How effects are chosen

Many AE Motion effects are a simple effect with a texture or overlay baked in (a ripple with its own light overlay, for example). Once the app's building blocks are strong, the owner can make those looks by stacking layers and effects,. So the effects expansion favors:

- **Building blocks that do something new**, not one family copied with small changes.
- **Real quality on each one**, matched to how AE and AM behave.
- **No combo effects.** AE Motion's combos (like a ripple with an overlay baked in) are skipped; the owner builds those by stacking.
## Ideas from research

What the big tools added recently, and what's worth bringing to a phone editor:

- **After Effects 26 (2026):** native 3D shapes (sphere, cube, cone) with materials; depth of field in the 3D renderer; an object matte that isolates moving subjects and keeps its result cached; a much faster mask tracker; SVG import as editable shapes; variable font axes. *Fits:* 3D shapes in the 3D renewal, cached mattes in Cutout Studio, faster mask tracking in Masks and roto, SVG import with shape layers.
- **DaVinci Resolve 20:** Magic Mask with a refine brush, motion-vector (optical flow) warp and transform tools in Fusion, animated word-by-word subtitles, AI audio cleanup. *Fits:* optical-flow warps in the effects expansion (we already estimate flow for Pixel Motion Blur), word-timed captions in Text Studio.
- **Premiere Pro 25:** search footage by what's in it, extend a clip with generated frames, automatic caption translation. *Fits:* on-device footage search in media handling later; generated frames are out of reach on a phone for now.
- **Unreal Engine Sequencer:** physical cine cameras (focal length, aperture, focus distance), camera cut tracks that switch between several cameras, nested sequences. *Fits:* a cine camera and camera cuts in the 3D renewal.
- **Alight Motion, Node Video, CapCut:** velocity speed ramps, keyframe precision, node-based compositing. *Fits:* speed ramps exist (Build 10); node compositing stays a later idea to discuss.

## Later, to discuss first

Node compositing, planar tracking beyond corner pins, reusable rigs with exposed controls, letting the owner build custom tools inside the app.
