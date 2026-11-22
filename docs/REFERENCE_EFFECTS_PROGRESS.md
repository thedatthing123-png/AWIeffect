# Reference-led effect expansion — November 19

## Current checkpoint — November 22

The complete available pixel-shader import is implemented on `feat/reference-effects`, pending native validation. It contains **547 internal programs: 513 active definitions plus 34 required legacy dependency stages**. Legacy stages remain private. The other **47 definitions need native animation/vector/text or host-selected multi-shader mapping**; see `REFERENCE_NATIVE_WORKFLOWS.md`. These counts are not counts of new browser effects.

The browser now contains **482 definitions**: the 452-definition recovery catalog, three initial additions, 25 curated reference entries and two original transitions. Ten additional reference entries and the two transitions were integrated at this checkpoint. **42 reference candidates** receive stills, configured examples, motion GIFs, exact review settings and numeric-control observation reports in the full run. Seventeen candidates remain internal until their renders and overlap checks are accepted. The complete expansion is not release-approved yet.

The final batch must use `validation=all`, `package_ipa=false`. After dispatch, the owner requested stopping active work while CI runs. Do not send an IPA or claim release readiness from shader translation alone. Review the new control reports, screenshots and moving renders first, then repair failures and retune defaults.

The owner authorized a new expansion using the supplied AE Motion 2.5 IPA as a concrete reference. This supersedes the no-new-expansion restriction for this branch only; it does not authorize restoring the discarded batches 30–48 or presets. Stable Build 34 remains recoverable on feat/stable-editor-recovery. Work continues on feat/reference-effects.

## Inventory and comparison

scripts/audit_reference_effects.py scans XML definitions without running IPA code. The supplied archive has 772 effect-root XML definitions: 671 outside quarantine, including 111 deprecated versions; 560 non-deprecated definitions remain. There are 101 quarantined definitions. These are definition counts, not promises of distinct working effects or a final AWI count.

The audit resolves English labels, records parameter types/defaults/ranges/choices, hashes shaders, and flags controls not referenced in shader text for manual review. No-shader definitions can be native animation/path effects and are not automatically broken. A registered-effects.json artifact from XCTest records the actual active AWI catalog. Feed that to --catalog for candidate matches. A name mismatch is not evidence an effect is missing; semantic comparison is still required.

Some aemotion_native_* entries share a generic branch-based shader and expose unused radius/colors. Do not wholesale import these or treat their labels as faithful plugin implementations. Compare the primary complete definition instead (e.g. fractalwarp4.xml rather than aemotion_native_fractalWarp.xml).

## First checkpoint implemented, awaiting render validation

- Fractal Ridges: new awi.am35.fractalRidges. Native Metal adaptation of ridges2.xml simplex/ridged-multifractal equations, with parallax, offset, evolution, scale, X/Y stretch, intensity, seed, two colors, octaves and blend. Alpha-safe compositing prevents writes outside the subject. Endpoint colors currently use the app's packed RGBA8 constant convention. Reference noise can exceed the color interval; interpolation is clamped for valid premultiplied output.
- PsykoBlobs: new awi.am35.psykoBlobs. Reference s_psykoblobs.xml value-noise field and luma-driven color phase, all seven controls. Explicit straight-color processing, preserved source alpha, bounded output and defined smoothstep behavior at zero outline preservation.
- Spectral Map: new awi.am35.spectralMap. Reference spectralmap.xml periodic three-color mapping, phase, repetition, squeeze, saturation, brightness scaling, reversal and mix. Fixes source coverage inflation from summing palette alpha; preserves premultiplied invariants.
- Normal Map Lighting: enhance existing awi10.normalLight instead of duplicating normal_map.xml. Output Lit / Normal Map and Invert Height. Missing fields retain the old lit image. Existing lighting controls remain; the reference's raw normal preview now has an equivalent output mode.

All new definitions and kernels are explicitly registered. Tests cover bypass, alpha, missing defaults, evolution, colors, existing-project compatibility and generated PNG/GIF review artifacts. The established numeric-control and all-effect contact-sheet tests also include the new definitions.

## Remaining work — not complete

Complete semantic mapping of the remaining reference definitions against the actual registered catalog; prioritize genuine missing capabilities, not counts. Inspect still and motion output before accepting this checkpoint. Extend existing Turbulent Displace (already X/Y/XY) only after matching radial/angular direction, single-axis, parallax/seed and coordinate-space behavior without altering old renders. Continue other families from the mapped backlog; do not label unreviewed candidates as implemented.

No presets, AI models, cutout behavior, projects, AI Link settings or editor layout were changed. No IPA should be sent from an unreviewed checkpoint. CI checkpoints use validation=all and package_ipa=false.


## Consolidated import preparation (not yet integrated)

Owner follow-up: after checkpoint validation, assemble the expansion before a single consolidated full validation run rather than dispatching small runs after each effect.

Checkpoint a709ea2 / run 44676484328 has passed compilation (Swift, simulator/device Metal), core, effects, contact sheets and text tests. The UI job is still running at this preparation checkpoint. Downloaded contact-9.png shows all three new effects on the common artwork fixture. Sampled motion GIF frames 0/6/12/18 show evolving ridges, animated PsykoBlobs and shifting spectral phase. These are actual native renders, not generated mockups.

The actual registered catalog artifact contains 455 definitions. The reference comparison must use build_out/44676484328-core-review/awi-ui/registered-effects.json rather than guesses from source names.

Offline tools: glslang 16.6.0 (official Windows release) and locally built Khronos SPIRV-Cross commit 57e4efcc84112abcd426dc5ec248b5339bee04f2, built with two compiler workers. No model training is running.

- scripts/translate_reference_shaders.py: translate complete single-fragment definitions through GLSL -> SPIR-V -> MSL; preserve explicit std140 parameter slots, selectors' native values, coordinate uniforms and bundled image inputs. Outputs and shader diagnostics remain under build_out. The full pass translates 313 / 560 non-deprecated reference definitions. The other 247 remain explicitly unsupported or require repairs/adapters; they are not claimed implemented.
- A reflection audit of all 313 converted shaders found zero parameter offset/texture binding mismatches. Report: build_out/reference-translation-images/reflection-audit.json.
- scripts/prepare_reference_import.py: generate typed Swift descriptors and native shader sources into build_out/prepared-reference-import. All 313 descriptors are internal audit candidates; 28 explicit names are public candidates pending native validation and semantic/visual review. Never treat the internal audit catalog as 313 new public effects.
- scripts/reference/*.swift.template: native fragment adapter and eight bounded audit tests. These remain templates outside App until the checkpoint gate passes. Pipeline and image caches are bounded by the catalog; raw source imagery and integer/bool parameter layouts are handled explicitly. Targets clear before fragment draws so discard cannot expose recycled pixels. Percentage controls use the same displayed 0..100 convention as the editor and convert back to source ratios.

Preparation is not a completed expansion. Multi-pass shaders, missing native context, 3D orientation matrices, background buffers and path/text operations need deliberate adapters; do not activate placeholder equivalents. Keep existing IDs and render behavior, and do not restore the discarded count-driven catalog.


## Checkpoint UI repair — gate still pending

Run 44676484328 finished with only EditorPolishUITests/testIndividualAndCameraBlurDoNotEnableEveryLayer failing: its first selected-layer switch still read 0 after tap. Core had 556 passes / one skip, and all 85 effect tests, contact sheets and text groups passed; UI had 26 passes / one failure.

Commit a6708ee reads live selected-layer/project state in the blur switch getter, adds unique accessibility identifiers to the existing selected-layer and Every Layer switches, and makes the UI test hit the switch track once and wait for published accessibility state. It does not add controls or enable all layers. The focused motion-blur scope includes EditorPolishUITests and MotionBlurTests. Run 44680703554 is validating this repair with package_ipa=false. Do not activate the bulk import until that gate passes; inspect its blur screenshots.

The native bulk adapter, generated registry and 313 Metal translations are still staged in build_out, not in App. No public-candidate definitions have been activated beyond the original three checkpoint additions. The 247 remaining native/multipass/unconverted references are explicitly unfinished. The next substantial action is a consolidated native import audit, not a claim that all 560 references are finished.


## Checkpoint gate cleared; consolidated native audit integrated

Focused run 44680703554 passed all 16 tests with zero failures/skips. Both downloaded screenshots show the selected layer/camera blur switch on and Every Layer off, without new layout overlaps. This clears the checkpoint repair gate while retaining all earlier passing non-UI checks.

The native fragment adapter and 313 converted fragment programs (plus one shared vertex function) are now integrated on this development branch, with five deduplicated reference texture resources. The eight ReferenceFragmentAuditTests exercise every converted program through Metal, compare complete/default-missing instances, check GPU completion and finite pixels, and write per-source stills/reports. The 28 current public candidates additionally produce eight-frame motion GIFs. The established full validation suite is being dispatched as one consolidated run, package_ipa=false.

Important: the internal ReferenceFragmentCatalog is not appended to EffectRegistry.all. The browser still has 455 accepted definitions. Candidate promotion follows native render review and overlap checks; 313 translations are not 313 new public effects. The other 247 reference definitions still require native/multipass adapters or repairs. No claim of a finished full expansion or releasable new IPA is made here.


## First reviewed browser promotion — validation pending

Audit run 44683887738 passed every job. Its native output and eight-frame motion sequences were inspected in candidate-review-0/1.jpg under build_out/44683887738-review/awi-reference-review. Review identified neutral/weak defaults, opaque-output behavior in image filters, and inaccurate initial descriptions (the supplied Colorama is fractal color noise; Omino Diffusion is palette error diffusion; Waveloq is a dot display, not a wave warp).

Fifteen distinct entries are now registered through reviewedReferenceEffects: Linescape, Pixelate Edge, Fractal Color Bands, Tile Shift, Palette Map, Iridescence, Tile Break, Heatmap, Tile Rotate, Error Diffusion, Fractal Texture, Money Filter, Psykostripes, Rounded Edge Mask and Block Noise. This makes 470 browser definitions (18 new additions versus the 452-definition recovery baseline), pending the promotion validation. Internal native references are still not all exposed in the browser.

Native adaptations are explicit in translate_reference_shaders.py: preserve translucent coverage for Pixelate Edge/Iridescence, keep gradient endpoints finite, use premultiplied coverage during Tile Break's fade, and make zero-mix Fractal Color an exact source bypass. Reviewed defaults show a partly progressed tile breakup, useful rounded clipping, and clearer psychedelic stripe density/color phase. Geometry/noise source algorithms remain derived from the supplied archive.

ReferenceFragmentControls honors the reference selectors' enableTargets. Fixed palettes hide inactive custom color rows; selecting custom palettes shows only the relevant colors/shade count, without deleting stored colors or keys. Original palettes use sparse numeric choice values, so control visibility follows UI choice indices while the shader retains original native values. The HSV color generator hides its color-only controls in grayscale mode. No extra studio, buttons or workflow was added.

ReviewedReferenceEffectsTests cover unique browser names/IDs, translucent coverage, exact zero-mix bypass, animated Tile Break endpoints and palette visibility. A dedicated UI fixture writes Tile Break and custom Error Diffusion panel screenshots. The global numeric-control test uses a custom Palette Map fixture to activate Shades, and a progressed Tile Break fixture. Rounded Edge Mask is correctly tested as an alpha-shaped effect. Full validation and updated contact/motion artifacts must pass before packaging.

Other candidates remain internal: neutral utility defaults need configured fixtures; several source labels overlap accepted features; small/sparse defaults need tuning; generator descriptions must reflect actual shader behavior. The remaining native/multipass adapters and the separately authorized original transition expansion are still unfinished. This is not a completed full expansion.

## Promotion validation repairs

Run 44691530406 compiled successfully and passed core, rendering and text checks. Two failures blocked release: Tile Rotate's Seed fixture left Random Rotation at zero, and opening an unselected group by double tap failed after the first tap reflowed the timeline.

Tile Rotate now labels random strength explicitly, hides Seed while that field is disabled, and tests Seed with random rotation enabled. Regression coverage also checks that changing Seed with random rotation off leaves the image unchanged. The timeline observer records individual window taps in editor state so a recreated view cannot lose the first tap; nearby second taps can complete only a matching recorded container action. The unselected-group UI test remains unchanged, and unit tests reject distant/expired observations.

The reference-repairs scope runs numeric controls, reviewed effects, container/selection logic and related UI workflows. Local Swift parsing, shard coverage and whitespace checks passed; actual iOS behavior and GPU checks remain pending CI. No additional effects were promoted by this repair.

## Complete pixel-pipeline implementation and consolidated review batch

The second repair run, 45061040677, still failed the unselected-group double tap. The Seed fixture passed. The revised group observer captures the original container from its visible clip bounds at touch-down, observes completed taps without claiming or delaying UIKit gestures, and survives the first tap's panel reflow. Drags/holds cancel pending container taps. The original UI test is unchanged and remains part of the full gate.

Deeper archive inspection found that deprecated XML files are active rendering dependencies of current effects, including the hexadecimal IDs. The importer now resolves that dependency closure instead of discarding it. All 547 available shader programs pass GLSL-to-SPIR-V-to-MSL conversion. The adapter retains named intermediate buffers, downsampling, ordered stages, supported external prepasses, explicit stage sources, iteration counts, sparse choices, and scalar unit conversion between parent and dependency. XYZ/orientation/hue-disc controls map to keyframeable components without inventing new tool panels. An RGBA16Float range guard retains HDR while preventing final half-float overflow. Unsupported host scripts are never executed.

The ten additional browser entries are Wave Dot Display, Radial Shadow, Comet Trails, Ribbon, Bent Rays, Glass Spheres, Highlights and Shadows, Film Damage Dots, Channel Remap HSV and Ink Splash. Defaults were adjusted after inspection of native still/motion output from 44683887738; the updated output still requires review. Alpha adaptations preserve translucent artwork for the dot display/ribbon/rays, composite glass with its tint alpha, and keep ink matte RGB and alpha consistent. Radial Shadow reserves room for its output and anchors its light to the source layer rather than the grown scratch buffer.

New original effects are Liquid Lens Wipe and Voronoi Peel, in one registry/Metal pair. Both have exact intact/empty completion endpoints, deterministic seeds, ordinary keyframes and transparent output revealing the actual layer beneath. Liquid Lens Wipe uses a noise-shaped refractive boundary with lens width and chromatic separation. Voronoi Peel uses independently contracting/turning cells with radial/directional/random delay. Their motion review writes 16 frames each, rather than a decorative static mockup. Research reference: [Adobe transition controls and compositing](https://helpx.adobe.com/after-effects/desktop/apply-effects-and-animation-presets/list-of-effects/transition-effects.html).

Existing Fractal Warp gains X/Y restriction with XY as the unchanged default. Native point fields now display actual offset/stretch units; radial light handles convert between canvas and native coordinates. Abstract vectors do not receive misleading normalized-position crosshairs. No working transport controls, panels, projects, AI data/settings or Motion Sketch behavior were replaced.

Local checks: Swift parsing, ten host-side translation contracts, complete XCTest shard inventory and graph dependency/binding checks. Only macOS CI can establish Metal compilation, actual rendering, workflow/UI results and screenshots. Pending native workflows are described separately rather than counted as imported effects.
