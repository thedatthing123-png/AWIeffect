# AWIeffect — joint / Puppet recovery and full development handoff

Prepared November 8, 2026, after reviewing the owner's latest two phone screenshots, inspecting the implementation, and researching the official references below. This is a self-contained briefing for ChatGPT, Claude, or the next coding session. The owner's latest feedback takes priority over older completion claims.

## 1. The immediate situation

The owner installed Build 25 and reports that the joint workflow is confusing and only partly works: the elbow/upper connection moves, but a lower piece appears to float away. They also want a precision position swipe pad for selected joints and Puppet pins, rather than having to cover tiny canvas handles with a finger. They want optional weighted mesh deformation integrated with the same rig, including meaningful stretch controls. They are nearly out of usage, so prioritize solving the editing workflow instead of broadening into unrelated features.

**Build 25 is not evidence that this user workflow is finished.** Its automated checks passed, but the new phone feedback exposes an acceptance gap. Do not tell the owner this is only a misunderstanding or repeat the same manual anchor instructions as the entire fix.

This handoff documents requirements and a repair plan. It does not claim the new precision pad, stretch settings, floating-piece repair, or mesh editing have been implemented in Build 25. No app code was changed while preparing this document.

## 2. Product goal and constraints

AWIeffect is a personal, professional mobile editor for an experienced manga/AMV/MMV editor. The owner wants the creative control demonstrated in four reference videos, including the Hush/Valorant rig demonstration, advanced typography, manga staging, camera depth and compositing. It is an editable authoring application, not a collection of one-click styles. The immediate rig is for flat image pieces and 2.5D camera/depth placement, not Blender-style volumetric model rigging.

Preserve the working Text Studio, shape contents, graphs, timing, camera, effects, cutout, projects and existing animation. Inspect related code before changes. Never delete the owner's projects or change AI Link settings. Ask before changing Motion Sketch behavior. Keep established one-tap controls in place; do not move them into menus to look cleaner. Use existing ValueScrubber, numeric-entry and SwipePad patterns. Keep touch targets at least 44 pt and at most three controls per row. Put controls in the existing relevant bottom panel; do not build another full-screen studio or cover the canvas with a control rack.

The earlier reference review covered `IMG_1835.MP4` (PHANTOM-style typography), `IMG_1836.MP4` (Hello / intermediate symbol / Evolve), `IMG_1837.MP4` (manga staging), and `video.mp4` (Hush/Valorant rig breakdown). Prior review artifacts are in `../outputs/video-reference-review/REVIEW.md`, with contact sheets and closeups. This turn re-examined the two new screenshots and researched documentation; it did not rewatch those four files. The handoff does not include the user's source project or the original reference videos.

## 3. Versions, branches, evidence and boundaries

| Item | Verified state |
|---|---|
| Repository | https://github.com/thedatthing123-png/AWIeffect |
| Delivery branch | `feat/image-piece-rig` |
| Build 25 tested product commit | `a85a8f13020464ab9e6e73250804139549492747` |
| Current documentation commit before this handoff | `017f7c9f9c88b1b40d9864576ff2da29de6e48c4` |
| Full Build 25 CI | https://github.com/thedatthing123-png/AWIeffect/actions/runs/42539101097 — successful, 639 passed, 0 failed, 1 skipped |
| Build 25 download | https://github.com/thedatthing123-png/AWIeffect/releases/download/v0.1.2-build25/AWIeffect.ipa |
| Previous Build 24 | https://github.com/thedatthing123-png/AWIeffect/releases/download/v0.1.2-build24/AWIeffect.ipa — keep as a safe fallback |
| Deferred mesh branch | `feat/advanced-authoring`, commit `d2be924ba1d773dc2de5321790acfecba07c4473` |
| Earlier full controls checkpoint | `313d71f`, run 42515877823: 631 passed, 0 failed, 1 skipped |
| Connected bone focused checkpoint | `3b7f44e`, run 42535188684: 62 passed, 0 failed, 0 skipped |

Build 25 includes authored end-joint placement, rest-bend preservation, direct IK targets, animated IK/FK mix, connected bone drawing, direct selected-letter rotation, and shared character-parent framing for newly bound image-piece rigs. Position tracks use the existing timeline/graph traversal. The three-piece regression checks a preconfigured valid arm, its attached hand, rendered wrist alignment, uniform character scale/rotation/depth and serialization. It does not prove that arbitrary user selections produce a correct rig, that competing rigs are handled, or that the setup is understandable on a phone. Nonuniform scale/shear needs additional rendered validation; do not generalize the uniform-scale test.

The mesh branch is work in progress. It contains optional mesh data, inverse bind transforms, forward Metal triangle skinning, cached topology, automatic weights, Paint/Erase/Smooth and locking, a rest/weight preview, transactional brush attempts, reference remapping, deformation shutter sampling, and render tests. Runs 42537378174 and 42537735397 failed the weight-painting UI test because the stroke did not change the observed revision. Later changes on that branch were not fully validated. Do not merge the whole branch blindly, call it production-ready, or discard it and start a duplicate implementation. Build 25 deliberately excludes it.

## 4. What the research established

### Joint control and artwork attachment are separate responsibilities

FK rotates a chain from its root; IK solves a chain from an end target. A conventional arm has two solved segments, shoulder-to-elbow and elbow-to-wrist. The hand is attached at the wrist and may have independent orientation. It does not need another competing two-bone constraint just to remain attached. The target must sit outside the constrained descendants to avoid a dependency loop. Stretch, soft reach and IK/FK influence are separate properties. [Spine IK documentation](https://esotericsoftware.com/spine-ik-constraints).

The AE ecosystem also supports rigging ordinary artwork layers using their parent relationships and anchors; bone helpers need not mean 3D modeling. This supports a setup action which establishes an editable hierarchy, rather than making the user manually repair every parent/pivot combination. [Duik Auto-rig guide, official repository](https://github.com/RxLaboratory/Duik/blob/master/src-docs/docs/guide/bones/autorig/index.md).

A bone-following attachment and a target-following attachment can have different orientation behavior. Supporting chosen transform components and a preserved offset makes that relationship explicit. [Spine transform constraints](https://esotericsoftware.com/spine-transform-constraints).

### Weights and Puppet are deformation methods, not IK sensitivity

Weights distribute a mesh vertex's response across bones. Binding records a reference pose; normalized weights, smoothing and locks make the influence editable. Automatic weights are a starting point, not a guarantee of good deformation. [Spine weights guide](https://esotericsoftware.com/spine-weights). Mesh topology and its relationship to the source image also matter. [Spine mesh guide](https://esotericsoftware.com/spine-meshes).

Puppet pins instead control locations within a deforming image. Adobe distinguishes position, stiffness, rotation/scale and overlap controls. This is useful behavioral context, but AWI's current MLS pin warp is not Adobe's mesh engine and must retain its saved-project behavior. [Adobe Puppet guide](https://helpx.adobe.com/after-effects/desktop/animate-in-after-effects/animate-with-puppet-tools/animating-puppet-tools.html).

These are behavioral references. This research did not decompile AE Motion, inspect the original Hush project's rig data, or establish that its exact solver is identical to AWI's. No source code from these products was copied for this document.

## 5. Latest screenshots: observations versus diagnosis

Observed in the supplied phone screenshots:

- Three purple rectangle pieces, white joint/chain markers and an orange target are visible.
- A lower purple piece is separated from the apparent chain in one image.
- The selected layer names differ: one ends in `copy Controller`, another in `copy copy Controller`.
- The panel exposes a collider toggle, bend direction, IK/FK mix, Select Controller and Remove IK. It does not expose a selected joint/pin position pad there.

Do not claim the screenshots reveal parent IDs, rest offsets, the target graph, or whether the owner created two overlapping constraints. The exact project JSON is not available in this handoff. Reproduce from three freshly duplicated shapes and follow the same visible setup paths; request the project only if needed to resolve remaining uncertainty.

Code-backed gaps and reproduction hypotheses:

1. `makeIK` operates on a selected lower layer and chosen upper layer. It does not identify or bind a third hand attachment, verify wrist coincidence, or repair a wrong hand link. An arbitrary third image can therefore remain elsewhere while the two-bone solve itself succeeds.
2. `ikRestTip` defaults to the lower artwork's bottom-center unless an endpoint was authored. A horizontal rectangle, cropped PNG, rotated piece or transparent border makes that assumption unsafe for setup.
3. `IKSolver.apply` loops through layer-owned constraints and writes rotations. There is no explicit conflict-resolution/dependency model for two constraints writing the same upper/lower bone. Differently named controllers in the screenshots suggest this is worth testing; they do not prove it happened.
4. Parent links preserve offsets. Parenting a misplaced hand does not automatically attach its wrist point to the forearm endpoint. Moving a child layer's position is also different from rotating a connected bone. The UI does not make these distinctions sufficiently clear.
5. The displayed white lines can describe pivots/endpoints while the art uses unrelated anchors. A connected overlay is not proof that the painted image pieces connect.
6. The target can lie beyond fixed arm reach. Fixed-length IK should show the maximum reachable wrist and the remaining target gap; an unbounded white line can look like a broken or floating attachment.
7. Nonuniform parent scale, mirrored artwork, camera projection and group nesting can expose a mismatch between full affine evaluation and decomposed rendering transforms. Evaluate the rendered edges, not only pivot math.

Working conclusion: treat this as both setup/attachment correctness and interaction design work. Do not invent one confirmed root cause from screenshots or blame the owner.

## 6. First repair: one coherent arm rig

Implement and validate this before more optional deformation or typography.

### Setup on the normal canvas

- Reuse the Rig panel to assign Upper Arm, Forearm and optional Hand artwork, with clear current assignments and stable IDs. Renaming or duplicate names must not change identity.
- Let the user select Shoulder, Elbow and Wrist markers. Keep them visually distinct from the orange pose target.
- All three joints can be positioned directly or with the precision pad specified below. Rest setup must not accidentally keyframe pose animation.
- Binding computes the bone rest frames and artwork attachment offsets from those markers. Align the wrist attachment intentionally while preserving the artwork's current appearance wherever possible. A proposed correction that moves artwork must be visibly previewed before the single Bind action commits it.
- Establish one parent/constraint graph and one hand target for this arm. Rebinding edits/reuses that rig's target; it must not silently accumulate controllers.
- A hand is an attachment, not another two-bone arm solve. Make its wrist attachment explicit. Preserve an independent local hand rotation track.
- Before commit, detect missing layers, zero-length segments, cycles and competing constraints. Select and explain the existing conflicting rig in place, rather than adding another hidden constraint.
- One bind/rebind action is one undo step. Cancel restores the original state. Existing rigs remain compatible; offer an explicit repair/rebind instead of destructive migration.

### Posing

The character root moves the whole character. An FK bone rotates around its joint and carries descendants. The IK hand target moves the wrist; the solver rotates the two arm segments and carries the hand attachment. For a fixed-length arm, keep segment lengths and joint coincidence invariant. Reaching past the limit should extend the arm to its limit without detaching the hand. Show both the target and reached wrist when they differ.

Support bend direction and editable elbow preference without random flips around straight/folded poses. Decide whether a draggable bend guide is necessary after reproducing the current setup; do not add an elaborate 3D pole-vector panel by default. For future longer chains, use an explicitly defined chain length, solve order and attachment graph, not repeated Make IK on adjacent pieces.

## 7. Precision dragging: mandatory for Rig AND Puppet

The owner's “drag position thing” means an indirect swipe pad like Move & Transform. A number field alone is not the requested control.

- Tap a joint, target, bone endpoint or Puppet pin to select it; highlight only that editable item. Show its role/name in the existing bottom panel.
- Provide one shared position pad for the selected item, plus X/Y values using existing scrubbing and tap-to-type controls. Reuse the panel's current space; avoid an expanded pad for every pin simultaneously.
- Direct handle dragging remains available. The pad lets the user see the point unobscured while moving it precisely.
- Add an editor interaction preference for drag sensitivity/fine movement. Suggested starting gains are tuning proposals, not verified values. They must be tested at different zoom levels and on the owner's phone.
- Take a gesture-start snapshot of the target's coordinate frame and starting position. Apply accumulated screen translation to that snapshot; convert through camera, viewport and parent transforms consistently. Do not recompute displacement from a moving handle's changing local touch position.
- Decide and label whether X/Y are artwork-local or parent-local. Puppet positions are currently layer-local; IK controller position tracks are parent-local. Never silently interpret a typed value as screen pixels.
- Rest markers edit rest setup; IK targets edit pose position; FK endpoints alter bone rotation; Puppet pins edit existing `pinD` tracks. They can share the input pad without writing the wrong data.
- The selected marker stays visible near frame edges. Keep at least 44 pt hit areas without making adjacent joints impossible to select. Canvas zoom/pan must never move the selected point.
- One gesture is one undo step. Selection, opening the panel, unchanged gestures and cancelled drafts create no empty undo. Test interruption, leaving the panel, changing selection, multitouch and repeated drags.
- Preserve Puppet Animate, existing per-pin keyframes and graph buttons. Existing Puppet X/Y fields are useful but are not a substitute for the pad.

## 8. Sensitivity, stretch, softness and deformation: do not conflate them

| Requested behavior | Proposed control | Meaning / boundary |
|---|---|---|
| More precise finger movement | Drag sensitivity / Fine | Editor input gain only; does not alter saved motion or export |
| How much a target drives the arm | IK/FK mix | Blend solved rotations with existing FK animation; already present |
| Gentler near-straight behavior | Soft reach | Spatial easing near maximum reach; not a temporal delay or brush strength |
| Arm can lengthen toward a distant target | Stretch amount + maximum stretch | Optional, default off; bound extension and keep elbow/wrist/attachments coherent |
| Shortening | Compression, if implemented | A separate explicit capability; do not imply the current two-bone solver already supports it |
| Which parts bend with which bones | Vertex weights + locks | Spatial influence distribution, normalized across bound bones |
| Strength of weight painting | Brush strength/falloff/radius | Editing influence; does not change IK target travel |
| Resistance to shape distortion | Local stiffness / deformation policy | Requires an actual deformation method; a renamed slider cannot provide rigidity or volume preservation |
| Whole deformation blend | Deformation amount, if added | Blend from rest to the evaluated deformed surface; must remain distinct from IK/FK mix |

Stretch parameters are proposals to implement, not current Build 25 settings. Define how soft reach and stretch combine before exposing both; reference tools have restrictions and their semantics should not be assumed interchangeable. Clamp degenerate cases and specify the distribution across both segments. If an arm is stretched, update child joint translations, artwork attachment frames and skin matrices consistently. Scaling just one visible image while leaving the wrist attachment unchanged recreates the floating problem.

Temporal springiness/inertia is another feature. Do not label it “sensitivity” or add playback-history-dependent simulation to a deterministic IK solver. If later needed, define scrubbing/export evaluation or a bake first.

## 9. Optional mesh deformation integrated with the same rig

The owner now explicitly wants this retained in the plan, after the basic joint repair. A rigid hand/arm setup must remain usable without it.

Use the same stable bone IDs, rest frames, pose solver, controller keys and camera placement. Bind flexible artwork to a mesh, storing rest vertices, source UVs, topology and inverse bind matrices. Evaluate skinning from the solved pose; do not solve an unrelated second skeleton. Permit rigid and weighted attachments in one character. Support visible weights, paint/erase/smooth, locks, a rigid/root fallback and bounded influences. Preserve locked weights while redistributing the remainder.

Reuse the existing mesh branch selectively. First reproduce its failed brush test; test actual painted pixels/weights as well as revision changes, rather than weakening assertions to pass. Its current regular grid and distance-based initial weights are a foundation, not a claim of silhouette-aware, production-quality hair/clothing deformation. Improve topology and manual vertex/weight control as needed by real examples. Do not claim it already traces alpha outlines or preserves area/volume.

Clearly separate rest editing from posing and weight editing. A rebind or changed mesh must preserve animation unless the user deliberately chooses otherwise. Painting during a pose versus a rest preview needs an explicit consistent policy. Keep original Puppet Pins compatible; it is currently a different deformation algorithm. Define the order or reject unsupported simultaneous warps instead of silently double-deforming.

Evaluate complete deformation at shutter samples so moving bones blur even when the image layer matrix is stationary. Cache topology, pipelines and buffers; update only pose palettes per frame. Keep transparent regions transparent, handle folds/triangle order predictably, bound memory, and verify groups, masks, effects, precomp proxies, save/reload and export.

## 10. Code map for the next implementer

| Area | Current files / notes |
|---|---|
| IK model, solve, bind and Rig UI | `App/Editor/IKRig.swift` — `IKRig`, `IKSolver.apply`, `makeIK`, `poseIKController`, `RigPanel` |
| Existing direct handles | `App/UI/CanvasOverlays.swift` — endpoint draft, controller handles, white chain overlay |
| Connected null-layer bones | `App/Editor/BoneAuthoring.swift` — optional `BoneSettings`, artwork-plane coordinates, FK tip posing |
| Parent/frame evaluation | `App/Editor/Parenting.swift` — full `parentAffine`, resolved frame baking; preserve nested-render IK snapshot fix |
| Layer picking | `App/UI/CanvasTools.swift` — preserve return selection/panel when assigning a limb |
| Existing position pad | `App/UI/TransformTools.swift` — `SwipePad`; inspect its callback/gain contract before reuse |
| Editor transient state | `App/Editor/EditorState.swift` — rig draft fields and live/edit grouping |
| Puppet model/UI/overlay | `App/Editor/Puppet.swift` — layer-local pins, `pinR`/`pinD`/`pinS`, 32-pin cap, stiffness, keyed positions and X/Y fields |
| Existing Puppet warp | `App/Render/Effects18.metal` and registry definitions — inverse rigid MLS; do not replace silently |
| Deferred weighted renderer | On mesh branch: `App/Model/BoneMesh.swift`, `App/Render/BoneMeshGPU.swift`, `BoneMesh.metal`, `BoneMeshEvaluation.swift` |
| Deferred weight authoring | On mesh branch: `App/Editor/BoneMeshAuthoring.swift`, `BoneWeightCanvas.swift` |
| Regression tests | `Tests/BoneAuthoringTests.swift`, `BugBatchBTests.swift`, `AdvancedAuthoringRenderTests.swift`, `UITests/RigAuthoringUITests.swift`; mesh branch also has `BoneMeshTests.swift` |

## 11. Acceptance tests that the previous checkpoint lacked

Use the actual setup workflow, not only a hand-built valid project fixture:

1. Duplicate a rectangle twice. Assign all three pieces, place joints with the pad, bind once, and pose the target. The hand and painted forearm endpoint stay together throughout the reachable region.
2. Repeat with horizontal/vertical/diagonal art, transparent PNG padding, edited anchors, cropped artwork and differing piece lengths.
3. Bind again, or select the hand and try to rig the same arm again. Confirm safe reuse or an actionable conflict state; no silently competing rigs or controller accumulation.
4. Deliberately mis-parent/displace a hand. The setup must identify and repair the attachment with a preview, not report a successful rig while leaving the hand floating.
5. Move root, rotate FK upper/forearm, drag IK target, blend FK/IK, rotate the hand independently and key all relevant tracks. Show the distinction clearly without extra studios.
6. Test targets beyond reach, inside minimum reach, exactly on the shoulder, fully straight and crossing the bend side. No NaNs, flipping spikes, detached images or unexplained endless lines.
7. Test mirrored and nonuniformly scaled parent chains, nonzero anchors, animated Z/camera, mode switches, nested groups and precomps. Compare rendered joint alignment with the solver, not just pivot positions.
8. Precision pad and direct dragging must agree at different viewport zoom/pan and camera poses. Test very small adjustments, numeric entry, selection changes, repeated drags and gesture cancellation. Do the equivalent for Puppet pins with keys/undo.
9. Round-trip save, duplicate/copy/paste, group/ungroup, trim/split/speed/reverse and controller-key graph editing. Check that references and retiming stay correct.
10. Weighted phase: visible paint changes, exact locked influence preservation, normalization, skinning at bind pose, rigid/weighted attachment mixtures, bounded stretch and matching preview/export/motion blur. No “green” claim from a screenshot of controls alone.

Create an editable three-image arm example with visible shoulder/elbow/wrist labels, a separate hand rotation track and one target. Include a short normal-speed recording of building it from scratch on a phone. Inspect frames across the full motion and moving renders. User confirmation that the setup is understandable is an acceptance requirement; automated tests alone are insufficient. Do not claim measured 60 fps from simulator results.

## 12. Remaining overall plan, in priority order

1. Repair the rigid image-piece setup, attachment behavior, precision Rig/Puppet movement and conflict handling described here. This is the owner's most wanted feature.
2. Finish optional weighted deformation with meaningful stretch/softness/stiffness semantics and the existing rig. Keep rigid mode independent.
3. Extend existing Text Studio for intentional per-letter pivot/rotation/scale/depth authoring, editable stroke/letter assembly, path geometry and genuine morphing where needed. Preserve stable character IDs, selectors, styles, progress and 3D text. Do not add duplicate Text Transform/Progress effects to replace the stronger engine.
4. Validate manga staging, 2.5D camera/null relationships, attachments, foreground/background separation, editable trails and motion blur using the four reference videos. Actual 3D scene/model/text and rig renewal is a separate later scope, not what this image-rig request means.
5. Resume the shape/effects/preset/performance roadmap only after authoring is usable. Shape multi-path/Merge Paths exists; audit the current implementation before redoing it. `docs/EXPANSION_PLAN.md` is the detailed agreed effect roadmap, subordinate to the owner's newer priorities. Its latest aspiration is roughly 1,000 genuinely useful effects, not the older conversation's 600–700 or a guaranteed current count. Recount the registry when needed; do not invent a current total.
6. Effects: research/remake only weak current behavior, retain good recent implementations, and add distinct usable effects in the documented registry/Metal batches. No name padding. Planned families include backgrounds, distinct glitches, liquid/warps, key/matte/time, transitions, shapes/particles, procedural/glow composites, stylize/film/text/blur and composites. Halftone, Inner Glow, Time Slice, light effects and the requested ripple need behavior-based verification where still unresolved. Confirm current code before deciding any item is missing.
7. Important unresolved terminology: the owner previously described Pixel Blur as video-motion/optical-flow blur, while the older expansion document describes block/pixel-grid blur. Those are different operations. Reconcile intent from the actual latest feature before implementing or renaming it.
8. Presets must unpack into editable layers, keys, animators and effects, with live previews. Final profiling uses real phone projects with video, many layers, camera/3D and glow. Cache invalidation and pre-render must remain correct.

Earlier conversation also raised audio/beat detection, Art Studio selections/cutout/lasso/brushes, masks/mattes, grouping, timeline gestures, speed/remap/reverse, export alpha/audio/Photos, import/library hit testing, Deep Glow performance, 3D imports and text. Some were renewed or repaired in earlier builds; this handoff is not a fresh audit declaring all fixed or all broken. Use `HANDOFF.md`, `EXPANSION_PLAN.md`, `ADVANCED_AUTHORING.md`, `TEXT_STUDIO_SPEC.md` and current tests/code to establish each item's actual status. Prioritize reported regressions over more effect names.

## 13. Safe resumption and delivery

Inspect `git status`, branch and commit before editing. Do not reset over either branch. Start the immediate repair from `feat/image-piece-rig`; selectively integrate the mesh work later. Read this document, AGENTS.md and related code first. Keep Build 25 and Build 24 tags/assets untouched as fallbacks. Do not modify the owner's open phone project through AI Link as a shortcut to diagnosing source behavior.

CI command: `gh workflow run build.yml --ref <working-branch> -f validation=all`. Focused `authoring` checks are useful during development but do not replace full validation before delivery. Inspect `ui-screenshots` and motion artifacts. Bump `CURRENT_PROJECT_VERSION` once per delivered build, not for every test. Deliver a verified file named `AWIeffect.ipa` with a usable download link; state passed/failed/skipped counts and known limitations honestly.

For future effect batches follow section 8 of EXPANSION_PLAN.md: one registry Swift file and Metal file per batch; register definitions in `EffectRegistry.all` and kernels in EffectGPU; preserve IDs and parameter fallbacks; wire every numeric control; validate visible behavior and alpha; review contact sheets and moving renders. Do not change AI Link configuration to generate examples. Parallel-agent work is not automatically authorized by an old roadmap line; follow the active session's delegation rules.

## 14. Suggested opening instruction for the next chat

“Read this handoff completely. Build 25's joint workflow is only partly working on the owner's phone despite green tests. Inspect the existing setup, attachment and solve code, reproduce the detached third piece and overlapping-rig cases, then design a coherent shoulder/elbow/wrist bind workflow and a selected-point precision pad shared with Puppet. Preserve all existing systems and saved projects. Finish that before optional weights. Reuse the deferred mesh branch selectively, implement real stretch semantics, and follow the remaining plan after the basic rig is understandable and correct. Explain observations versus confirmed causes; don't promise completion from unit tests alone.”
