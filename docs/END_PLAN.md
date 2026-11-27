# AWIeffect end plan

Saved November 25, 2026. Use this roadmap to recover the agreed direction when returning to the project. Read the working rules and relevant handoff before implementation. This plan describes intended work. A later explicit owner decision takes precedence.

## Product direction

One phone editor for compositing and timing, 2D and 2.5D character animation, spatial scene editing, illustration, and text motion. Use After Effects and Alight Motion as workflow references for editing, Blender for spatial controls, Spine for character rigging, and ibisPaint for drawing. Build AWI's own interface and add or replace engine components where needed. Preserve projects, one-tap controls, and established editing workflows. Put controls where the user edits the object and keep frequently used actions visible. Judge features by finished shots, phone responsiveness, and how much control they give the editor.

## Interface standard

Every workspace must feel finished on a phone. Keep the canvas visible, give the selected object the controls that affect it, and reuse the existing timeline and graph tools. Keep frequent actions one tap away, with rare actions in menus. Avoid repetitive confirmation taps, oversized setup forms, duplicated panels, and placeholder UI. Give key controls readable labels, consistent numeric editing, and comfortable tap targets. Verify placement, precision, and discoverability in real editing sessions and inspect phone screenshots at narrow widths.

## First priority: one Rig Studio

Replace the fragmented authoring workflow with one studio containing Setup and Animate. The main composition sees one character or rig layer. The studio exposes the internal bone hierarchy, geometry, bindings, constraints, and keys without creating a timeline layer for every joint or controller.

- Offer precision placement with the same interaction as vector points. Zoom into the artwork, position a crosshair with the X/Y pad or enter coordinates, and tap **Add Bone** to pin the start. Position the endpoint and confirm. Direct canvas drawing remains available for quick placement. Either endpoint can be selected and nudged afterward. Use a high-contrast overlay and a magnified placement view so the artwork remains visible beneath the finger. The pad and canvas drag should agree in direction at any zoom.
- Separate placement from hierarchy. Select any bone and choose **Make Root** or **Set Parent**, then pick a valid parent on the canvas or in the tree. Allow multiple roots, branching chains, and reparenting while preserving the current pose. Keep rest-pose edits in Setup. Store bones and controllers inside the artwork's rig, with bone tracks visible inside the studio.
- Support one intact image and separate artwork pieces in the same rig. For an intact image, generate a surface mesh from its alpha silhouette or an editable outline. Bind the selected bones and compute initial weights using the mesh topology. Moving the wrist should carry the forearm and bend the elbow. Auto binding should serve as the starting point, with influence overlays, paint, smooth, lock, and local rebind when needed.
- Allow rigid attachments and weighted attachments on the same hierarchy. Hidden pixels may require a separate piece or a redraw when exposed by a pose. Artist-guided cutout remains optional.
- Rotate joints directly in FK. Add IK explicitly to a chosen root-to-tip chain and expose its target, bend direction, stretch limits, and blend only when selected. Support branching and chains beyond a fixed upper/lower limb form.
- Keep Puppet Pin available as a quick local tool. Rig Studio covers full character authoring. Later use shared controls for facial poses, such as one Mouth Open value driving lip shapes, jaw movement, and the mask for teeth and tongue.
- Keep meshes and bind weights cached. Evaluate poses and constraints without rebuilding the mesh or entire timeline each frame. Profile drag, playback, and export on a phone. Preserve existing saved rigs and their rendering until a migration is tested.

First acceptance shot: take an uncut manga arm, bend it with shoulder/elbow/wrist joints, add a rigid accessory, pose with and without IK, then place the character in a layered background with a camera move. Test dragging, scrubbing, undo, save/reopen, and export before expanding the toolset.

Spine references: [Meshes](https://eu.esotericsoftware.com/spine-meshes) and [Weights](https://en.esotericsoftware.com/spine-weights). Spine computes initial weights when a mesh is bound and allows manual correction. AWI's automatic mesh generation is a planned addition to that workflow.

## Manga scenes, 3D Scene, and Lighting Studio

Use Bri's 2.5D manga animation as a visual target once the exact handle or clip is confirmed. The search found edits crediting @bri but did not verify how those backgrounds were made. Analyze camera motion, Z separation, foreground occlusion, lighting, and which elements appear to be image planes or geometry from confirmed clips. The supplied elevator-hand and mouth-rig videos are already useful tests for relighting and expression controls.

- Refresh the 3D Scene and Lighting Studio interfaces as dedicated workspaces. Prioritize the live canvas, a compact scene hierarchy, direct position/aim handles, and controls relevant to the selected object, light, or camera. Confirm the design on phone captures. Fix slider direction, range, and precision against canvas behavior.
- Keep flat 2D artwork compatible with lighting and let editors use Z for 2.5D layers. Build toward shared lights for artwork and imported models, controllable falloff and shadows, and better contact and distance-dependent softness.
- Add optional normal and depth maps to image/video materials. Normals let inked surfaces respond to light across the artwork. Depth can add limited relief and parallax. Use the elevator hand as a test: a blue light sweeps over fingers while linework survives and the hand sits convincingly in the room.
- Current checkpoint: Lighting Studio passed full CI and screenshot review at b1ee559. It supports point/spot/sun/ambient lights, per-layer reception, keyframeable color and placement, and shadow-edge blur for depth layers. Imported meshes still use their existing lighting. The standalone TV prototype was set aside by the owner.

## Text Studio, Art Studio, and cutout

Improve Text Studio's existing controls with the depth of a good motion graphics plug-in and direct access to the features editors actually use. Make new premades fully editable, with deliberate typography, timing, and motion. Judge them on different words and lengths and by quality in motion. Add variety across text, 3D text, and effects as warranted by distinct uses. Avoid quotas and duplicate variants.

Improve Art Studio's access to drawing, selection, and refinement with ibisPaint as a workflow reference. Keep the current working auto-cutout available. Resume training and evaluation of the archived brush-guided cutout model after the rig and studio foundations are stable. Prior reference requirements include previewing the selection before applying it, retaining linework, and keeping corrections local. Keep the model files and training data for that phase.

## Alight Motion XML and After Effects AEP compatibility

Preserve an imported project's source identity and the original effect IDs, parameters, animation, and effect order. Keep imported effect implementations separate from AWI effects even when their display names match. Copying an imported effect into a regular AWI project should carry its versioned implementation reference and settings, plus supported resources and dependency bindings. Use explicit IDs/namespaces and cached render pipelines so the same effect has the same meaning in either project. Import source graphs into a validated supported representation.

An AEP can reference effect code installed separately on the desktop and depend on AE host features. Render supported effects using compatible implementations. Preserve unsupported settings and report what is unresolved. Allow baked media from the source app for exact looks that depend on unavailable plug-ins, while keeping supported layers editable. Apply the same capability checks to XML effects with unavailable native stages or resources. Test import, copy/paste, save/reopen, and visual parity using actual projects.

Use freely released or open-source AEP and Alight Motion XML projects, including downloadable examples linked from YouTube, as test fixtures. Prefer an explicit free download from the creator or source repo. Record the source URL, expected look, bundled media, and known effect dependencies. Use a disposable project or stripped-down test copy, remove fixture artwork and layers when testing is done, and keep third-party project assets out of builds. Keep small synthetic fixtures for repeatable regression checks alongside real-project testing. This is a later workstream, separate from Rig Studio.

Reference: [After Effects SDK guide](https://ae-plugins.docsforadobe.dev/intro/what-can-i-do/).

## Delivery order

1. Design and build one Rig Studio, then validate the manga shot on a phone.
2. Modernize the 3D Scene and Lighting Studio workspaces and renderer. Validate the layered shot and relighting.
3. Improve Text Studio, its curated premades, and Art Studio workflows.
4. Resume the trained cutout model after those foundations are stable.
5. Stage XML/AEP compatibility as its own workstream. Prove a supported effect can be copied between projects before widening coverage.

Treat performance as part of each phase. Use stills and moving renders, inspect phone UI captures, preserve saved projects, and only send builds after the agreed validation passes.

## Part 2 — Effects, scene motion, timeline precision, and UI

Saved November 26, 2026. Use this section for the latest priorities and delivery order. Part 1 remains the reference for the broader Rig, Lighting, 3D, Text, Art, and import requirements.

### Reference edits and native effect quality

Use all four supplied edits as moving references. The Black Flash ranking shows readable poses between impact flashes. The Yuta edit times lyric reveals, panel motion, and transitions independently. The blue Gojo pullback uses light, smoke, and particles to create depth around the character. The phone-screen edit carries the framing through a screen into the next shot, then uses small movements and lighting to keep the composition alive. Around 10.7–11.1 seconds it also gives a close reference for coordinated position, roll, and scale. Judge the whole sequence, including image animation, depth, text, transitions, and timing.

- Keep the native effects that have useful, distinct behavior. Improve how Shake and other animated effects evaluate curves and motion over time. Check continuity during playback, scrubbing, and export, especially at high speed and when effects are stacked. Fix unintentional stepping, jitter, and timing differences.
- Preserve the editor's chosen direction, speed, intensity, and timing. Sustained shakes, abrupt stops, stepped glitches, and other deliberate jumps must remain available. Retain compatible saved behavior and controls. Judge changes using moving renders at both gentle and extreme settings.
- Keep AWI branding only on **AWI CC** inside CC Studio. Review AWI-branded catalog entries such as AWI Glitch and AWI Looks beside their closest equivalents. Retire duplicates from the public browser while preserving their legacy IDs for saved projects. Give any replacement genuinely distinct behavior and a plain name that describes it. Review output in motion before adding it to the catalog.
- The native AWI remake pass covers all nine retired AWI-branded entries. Edge Current replaces Saber, Sync Roll replaces VHS, Line Hold replaces Glitch, Ink Overprint replaces Manga, Sort Bands replaces Pixel Sort, and Panel Flash replaces Impact Frame. AWI CC, God Rays, and Particle System cover Looks, Shine, and Particles. Keep legacy effect IDs loadable and keep the native Deep Glow name and implementation. Dedicated AEP and XML source effect rendering remains part of the import workstream.
- Keep **Ghost** independently keyframeable as a scaled negative overlay of the current frame. Validate it on individual artwork and on an adjustment layer. The effect and motion blur remain independently controllable.
- Judge native animation with motion blur disabled in preview and export. Preserve the editor's choice of soft, heavy, sustained, abrupt, or intentionally stepped motion. Use explicit primary categories for Effects, with secondary search tags and new families where they help discovery. Place 3D Shape under 3D.

### Boris FX lighting references and animatable distortion

- Keep AWI's existing **Light Sweep** as the quick shine control. Evaluate a separate advanced sweep inspired by **BCC Light Sweep**. Compare beam position, angle, width, intensity, color, falloff, and mask behavior on text, transparent artwork, and a shot. Review other Continuum lighting effects against AWI's catalog and add an effect only when it gives the editor a distinct result or useful control. Use native implementations for new AWI effects. For imported BCC instances, preserve the source match ID and settings and verify render parity before marking an implementation compatible. [Boris FX Light Sweep](https://borisfx.com/documentation/continuum/bcc-light-sweep/) · [BCC effects list](https://borisfx.com/documentation/continuum/bcc-effects-list/)
- Audit animated controls on Turbulent Displace, Wave Warp, Fractal Warp, and the other distortion families. Verify in the renderer and in the effect panel that Evolution, Phase, Offset, and Parallax actually animate where applicable. Put the control that drives motion near the main strength control, with a visible keyframe affordance. Use After Effects and Alight Motion behavior as references. [After Effects distortion controls](https://helpx.adobe.com/ph_fil/after-effects/desktop/apply-effects-and-animation-presets/list-of-effects/distort-effects.html) · [Alight Motion Turbulent Displace](https://guide.alightmotion.com/effects/turbulent-displace)
- Separate automatic travel from deform strength. A speed of zero should hold the pattern still while the editor keys strength to fade the warp in or out. For Wave Warp, test zero Wave Speed with a Wave Height ramp and with manually keyed Phase. For Turbulent Displace, test fixed Evolution with keyed Amount, then key Evolution to animate the pattern. Add optional automatic motion where useful and keep legacy defaults when reopening saved projects. Test forward, reverse, zero speed, intentional holds, and preview/export parity with motion blur disabled.

### Smooth Scene

Add an opt-in **Smooth Scene** control for the existing adjustment layer and camera. It should improve how motion is evaluated or paced while producing a single image at the output frame. Shutter accumulation, trails, and pixel-motion blur remain separate controls.

- **Adjustment layer:** apply smoothing to eligible content beneath that layer during its active span and within its composition, following the existing adjustment scope. An adjustment layer spanning the timeline can cover that full span. Layers above it and motion outside its span remain unaffected.
- **Camera:** expose the control on the camera itself. Scope it to the active shot and to the scene motion that camera governs. Respect camera cuts and the camera's existing 2D influence.
- Start by verifying fractional-time evaluation of transforms, camera motion, and compatible animated effects. Give the editor control over the strength if the feature changes motion pacing. Preserve deliberate holds, hard cuts, and stepped effects. Keep beat timing, key positions, and authored endpoints intact. Treat smoothing internal footage motion as a separate capability that needs its own validation.
- Decide how overlapping camera and adjustment scopes resolve before implementation, so motion is evaluated consistently when both are enabled. Measure on-device responsiveness and compare preview and export. Use a test scene with moving artwork above and below the adjustment, two camera shots, and a fast effect crossing an intentional cut.

The current implementation interpolates the existing linear transform and selected effect segments in place. Strength softens changes in velocity and reduces fine noise in continuous Shake. Authored Bezier curves, holds, and spatial paths evaluate as saved. Scope transitions fade over two frames inside the clip or shot. The higher strength wins when scopes overlap on an eligible layer. The renderer keeps source media time and motion blur independent. [Adobe speed graph](https://helpx.adobe.com/after-effects/desktop/animate-in-after-effects/speed-between-keyframes/speed.html) · [Blender curve smoothing](https://docs.blender.org/manual/en/5.3/editors/graph_editor/fcurves/properties.html)

### Timeline precision

Make clip moves, trim handles, and split workflows align to exact project frames. Use frame positions as the common reference so an edge at 2.00 seconds can be matched exactly by another edge. Snap to eligible clip starts and ends, the playhead, and applicable markers. Show the active snap guide during the gesture and commit the same frame the guide showed on release. Keep free placement available when snapping is off.

Verify the 2-second example at multiple timeline zoom levels and project frame rates. Test both edges, drag and trim direction, split at an aligned playhead, undo, and save/reopen. Preserve source offsets, speed remapping, and layer duration according to the editing operation.

### Effects, CC Studio, Puppet, and layout

- CC grades and LUTs belong in **CC Studio**, and pins belong in **Puppet**. Remove duplicate studio entries from the Effects browser and visible effect stack. Check search, favorites, and recents as well. Preserve rendering, order, parameters, keyframes, and access to older projects' controls.
- Replace CC Studio's text LUT list with a **three-column picture grid** for built-in and imported LUTs. Use the scene at the current playhead as the common preview, before the selected grade's LUT stage. Include a **None** tile for comparison. A tile selects the LUT directly. Keep strength and import close to the grid. Reuse one captured frame, load visible thumbnails as needed, and refresh when the playhead settles so browsing and scrubbing remain responsive.
- Tighten oversized rows, fills, and padding across the editor for the iPhone 16 Pro Max. Give the space back to the canvas and timeline. Keep one-tap actions on the objects and bars they control, with comfortable hit areas even when the visible controls get smaller. Review the layout in normal editing sessions and on narrower phones.
- Continue the Art Studio workflow and layout pass with direct access to drawing, selection, and refinement. Schedule cutout model work separately after the editing systems are stable.

### Import parity and reusable source effects

Carry forward the AEP/XML plan in Part 1. Extend, add, or replace renderer and animation-engine components where source fidelity requires it. Import the composition as editable layers where supported, including transforms, motion paths, opacity, blending, masks, cameras, nested compositions, and text animation. Match source timing and rendering in motion. Optimize for the phone while preserving the visible result.

Resolve effects by source format and original effect ID, with a versioned implementation reference. Instances from different projects share that implementation and keep their own settings, keyframes, curves, and stack order. A script or plugin can create standard keys, layers, text animators, or effects in the project. Import everything it saved in a supported form. For example, if a plugin applies Deep Glow and saves a Deep Glow effect instance, import that instance with its original ID and settings and render it when a compatible Deep Glow implementation is available. Copy/paste into an AWI project must retain the source behavior and resources it depends on. If an effect still needs an unavailable runtime, preserve its original slot and source data and report the dependency.

Keep imported AE text editable where the project exposes the underlying text and the animation can be evaluated. Preserve a supported plugin-authored animation as an editable text template with its original choreography. Expose the wording, playback speed, overall color, per-word and per-letter colors, and the normal ability to stack additional effects. Preserve the source animation's order, easing, and relationships when those controls change. The plugin's internal animation controls can stay encapsulated. Standard text keyframes and animators remain editable when supported. If a live plugin stage is unresolved, retain the authored text and animation data and identify which part needs the runtime.

For a transform-based shake, compare the imported position, rotation, scale, easing, and shutter against a source render. For a plugin-based shake, verify matching output with a compatible implementation before calling it equivalent. Keep AWI's native effects useful independently of import coverage. Use publicly released fixtures, including [HOUDINI](https://github.com/ShubhamAdelkar/free-adobe-presets/blob/main/HOUDINI.aep) for real transform data and the existing effect fixtures for automated checks. Test a whole imported shot and a single copied effect through save, reopen, and export.

The first source-import build pins source IDs and raw properties independently of the selected renderer, retains unresolved plug-in slots, and keeps the effect clipboard across projects. The existing AEP fixtures include the Yuta edit and the existing Alight Motion fixtures include a real shake edit. Oscillate 3 uses its documented cyclic frequency and clip-local clock. Reviewed Alight Motion renderers are selected by the exact source ID where available. Compare against actual source exports before marking rendering parity. Desktop plug-ins that lack a compatible renderer and unsupported text plug-in internals remain saved as unresolved. [Alight Motion Oscillate](https://guide.alightmotion.com/effects/oscillate)

### Relight Studio for footage and artwork

Use the supplied Beeble-to-Blender elevator clip as the reference. The creator isolates the moving hand with alpha, generates aligned normal, depth, and base-color passes, then uses depth to displace the surface in Blender and lights it inside the elevator scene.

Build a layer-level workspace that prepares an image, drawing, or clip for relighting and sends the resulting surface into the existing 3D Scene and Lighting Studio. It should support importing matching passes and, once quality is verified, generating them in AWI. Start with alpha, normals, depth, and base color. Keep the source timing, trim, and transparency aligned with the passes. Provide a live preview and direct controls for depth amount and normal strength. Add roughness and specular controls where reflective footage benefits from them.

Relight Studio opens on an image or video layer. Import still maps or synchronized video passes. The scene lights shade the imported normals and depth, including optional relief shadows within the cutout. Camera projection still uses the layer plane. Depth changes lighting and relief shadows while preserving the imported silhouette. Generating passes and moving the camera around reconstructed geometry are separate work.

Prove the renderer with supplied passes before committing to automatic generation. Use the elevator hand as the acceptance shot. Animate a blue light over the moving fingers, preserve the linework and clean edges, and check depth, occlusion, and frame-to-frame stability in a moving export. Treat depth as relief from the visible view. A wide camera orbit needs additional geometry or views.

Build Relight after the editing-readiness pass and before the AEP/XML import overhaul. [Beeble's relighting workflow](https://beeble.space/features/3d-relight)

### Home screen and Video Enhance

Redesign the AWIeffect home screen with a persistent bottom bar. Put Projects on the left, a prominent center + for Create Project, and Video Enhance on the right. Keep AEP/XML import visible at the top of Projects, next to the project list it adds to. Keep the rest of that screen focused on browsing and opening projects.

Finish the edit, then open Video Enhance and choose an AWIeffect export or a video from Photos or Files. Work on the rendered video in a standalone preview and save a new video.

- **Keep Resolution** is a full restoration mode. Improve visible compression damage, noise, ringing, aliasing, and fine detail at the exact input dimensions. **Upscale** uses the same restoration workflow with an explicit output resolution. Preserve aspect ratio, FPS, timing, and audio sync in both modes.
- Offer Auto as a starting point and expose manual restoration controls directly, including detail recovery, compression cleanup, denoise, sharpening, halo removal, and original texture. Let the editor adjust each independently. Compare the same moving range before and after at the same zoom. [Topaz Video Enhancement controls](https://docs.topazlabs.com/topaz-video/filters/enhancement)
- Judge restoration at the original dimensions against the source and a simple sharpen baseline. Check anime linework, manga screentones, small titles, and live-action texture for meaningful improvement and frame-to-frame stability. For upscale, also compare against a conventional resize at the same output dimensions.
- Run enhancement as a standalone render with progress and cancellation. Start with a short preview range and measure sustained memory, heat, and processing time on the iPhone 16 Pro Max before selecting the model and execution path.

### Text Studio overhaul

Owner update November 27, 2026. Start this pass after AEP/XML import is validated. Use the same Text Studio for native, After Effects, and Alight Motion text. Follow it with the remaining studio work and build new premades after the authoring tools settle.

Give the studio a compact, persistent tab bar using AWI colors and typography. Keep the live canvas and playhead visible. Pin the current selection and its common actions within reach, and show detailed controls in the tab that owns them. Verify the layout with the keyboard open and on narrower phones.

- **Style** owns wording, fonts, colors, stroke and appearance. Use a clear Layer, Word, Letter, or Selection scope. Apply a font to the whole layer or mix families and weights within a line. Show mixed values when styles differ. Let editors clear an override and restore the layer style. Reuse the existing per-character font data and stable character IDs. Preserve unaffected styles through typing, undo, save, and copy/paste.
- **Layout** owns alignment, wrapping, kerning, tracking, leading, baseline, and text on a path. Preview path direction, alignment, and travel on the canvas, with a keyframeable path offset. Evaluate paragraph boxes and fitting controls for multi-line titles and captions. [Motion text layout controls](https://support.apple.com/guide/motion/text-layout-controls-motn159c2279/mac)
- **Animate** owns the animator stack, target selectors, timing and keyframes. Make character, word, line, and custom-range targets easy to see and adjust. Add or improve selector stacking, stagger, order, seeded variation, and easing wherever the current engine falls short. Expose the selected animator's tracks near the playhead. Evaluate variable-font axes on fonts that expose them, with independent keys for the supported axes. [After Effects text animators and selectors](https://helpx.adobe.com/after-effects/desktop/animating-text/text-animation/animating-text.html) · [After Effects variable font axes](https://helpx.adobe.com/after-effects/using/working-with-variable-font-axes.html)
- **3D** owns extrusion, bevel, front and side materials, depth, and orientation. Keep object pose and per-character motion accessible, including editable X/Y rotation, Z offsets, and grouped pivots where supported. Test mixed-font 3D titles with the scene camera, lighting, and effects.
- Reuse the same scoped typography controls for imported editable text. Preserve source font names and formatting where the importer can read them, and make unavailable fonts easy to replace. Editing wording, scoped fonts, colors, or playback speed must preserve imported animation timing and effect identity. Use the regular Effects stack for source effects so copying preserves their renderer and settings. Keep a distinct indication for imported animation that needs an unavailable renderer.

Acceptance shot. Style a single letter and a whole word with different fonts inside an imported animated title. Retype adjacent text, edit the animation speed, paste the title and a source effect into another project, and verify the selected formatting and motion in preview and export after reopening. Repeat with native text, multiline text, and a script that uses complex shaping.

### Puppet overhaul

Rework Puppet after the Text Studio overhaul. Keep the dedicated Puppet workspace for quick local deformation. Study After Effects' Position, Starch, Bend, Advanced, and Overlap pins in actual shots before choosing the mesh and constraints. [Adobe Puppet tools](https://helpx.adobe.com/after-effects/desktop/animate-in-after-effects/animate-with-puppet-tools/animating-puppet-tools.html)

- Use smaller visible pins and a precision placement cursor. Move it with the Rig Studio-style XY pad or type coordinates, then tap Add Pin. Keep direct placement on the artwork and make nearby pins independently selectable. Show scale and rotation handles only while editing a selected pin that supports them.
- Separate rest placement from posing. Use stationary Position pins to hold points in place and Starch pins to stiffen a region. Provide dedicated Bend and Advanced controls for targeted rotation and scale. Build deformation from the layer silhouette or mask and test overlap handling where limbs cross.
- Verify a wrist or hair tip can move while the shoulder, torso, and nearby hair roots stay fixed. Check closely spaced pins, transformed layers, zoom and pan, fast motion, undo, save and reopen, and preview versus export. Preserve how earlier Puppet projects render.

### Updated delivery order

1. Organize Effects, CC Studio, LUTs, and Puppet. Apply the compact layout standard and fix timeline alignment during the editor UI overhaul.
2. Polish the motion of existing effects, validate Smooth Scene on both scopes, and review full edits in motion. Continue the remaining studio work, including Art Studio, with the same UI and performance standards.
3. Finish the full Effects category audit and verify an end-to-end edit with timeline snapping, scoped motion, effect stacking, and export. Work on Art Studio friction that interrupts that workflow.
4. Build Relight Studio around imported, aligned passes and verify the moving reference shot in Lighting Studio.
5. Build AEP and XML import fidelity and cross-project source effect reuse as a dedicated workstream. Extend the animation and render engines where source behavior requires it.
6. Overhaul Text Studio for both native and imported text, including easy access to mixed fonts and deeper animation controls.
7. Overhaul Puppet placement and localized deformation.
8. Redesign the home screen and build the standalone Video Enhance studio together.
9. Finish the curated premades. Judge them by what they let editors make and review them in motion.
10. Finish the trained cutout model. Keep the current auto-cutout available and retain the model and training data during development.
