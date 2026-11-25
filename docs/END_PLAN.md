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
