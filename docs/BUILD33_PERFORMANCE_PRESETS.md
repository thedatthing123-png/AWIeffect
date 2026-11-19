# Build 33: responsiveness, then editable presets

Owner update November 18: prioritize the reported response delays first, then rebuild premades with at least 300 text/3D-text entries and 100 general entries. This changes the earlier performance-last ordering. Combinations may be simple, elaborate or unusual, but each needs a deliberate visual purpose. AI selection training stays paused.

## Responsiveness changes implemented first

- Normal preview updates use the editor content/live revision instead of comparing every layer, key and effect on every clock tick. Derived orbit/cutout/rest-mesh views retain the safe comparison fallback.
- Active gestures request a lighter immediate preview; releasing restores the established full-quality settle path. Export is unchanged. Frame pressure includes CPU encoding time as well as GPU time.
- GPU capacity is checked before acquiring a display drawable. Cache-bar publications are coalesced instead of notifying the timeline per cached frame.
- Text preset tiles request one 200px poster. Only the selected tile requests its moving preview. Disappearing or superseded tiles cancel queued work, including between animation frames. Live previews remain on the selected tile without another button.
- Actual video frame requests get priority over speculative decoder prefetch.
- Automatic home-card thumbnails no longer wait for GPU readback on the main actor; manual close/export save behavior is retained.

These changes target observed code paths, not a claim of device profiling. Added checks cover stable preview revisions, edit invalidation and large-project CPU update cost. Existing video/timing/gesture/undo/render tests remain required. Native-phone Instruments traces and real-project scrubbing/playback still determine whether the owner's delay is fully resolved.

## Preset requirements

Use the existing animators, selectors, effects and real text geometry. Presets must expand into editable components with group ownership and safe removal, retain existing IDs, preserve user-authored content, and never load baked animations. Catalog counts and uniqueness alone do not establish designed quality. Validate referenced effects/parameters, timing, removal/undo, real 3D setup, default rendering and motion sheets; inspect phone screenshots.

## Research

- Apple: https://developer.apple.com/documentation/metal/synchronizing-cpu-and-gpu-work
- Apple: https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/
- Adobe text animators/selectors: https://helpx.adobe.com/after-effects/desktop/animating-text/text-animation/animating-text.html

- TextEvo's editable per-unit delay / selector approach: https://textevo.github.io/ and https://textevo.github.io/fx/
- Professional preset category references: https://misterhorse.com/products/text-presets/42 and https://aescripts.com/text-split-and-animate/

References inform timing/control structure; no proprietary presets, source or assets are copied.

## Catalog implementation

`CraftPresets33.swift` loads three authored JSON manifests. `scripts/build_preset_catalog33.py` reproduces those explicit recipes; it does not expand a Cartesian product of strength/color variants.

- 240 new animated text composites: entrance, exit, emphasis, loops, typing/decode, kinetic, lyric, impact, manga and 3D. They combine native range/wave/wiggly selectors with per-character/word/line transforms, secondary accents and selected layer effects.
- 60 new text looks: fills, strokes, shadows, glow, printing/distortion stacks and real extruded/beveled material treatments. Together these are 300 new text entries.
- 100 new general composites across shakes, transitions, loops, light, manga, grading and frame-time treatments. Effects and keyed transforms remain editable. Velocity-category entries are effects/transform recipes using actual upstream frame-time effects, not a replacement time-remap implementation.
- Old IDs remain accessible. Animation effects and new text geometry share the animator's removable group. Existing user text geometry and animator groups survive animation application/removal. Reapplying creates independent text groups as before.
- Exit recipes author keys before their end anchor and respect the LayerPreset wrapper's normalized opacity contract. Existing transform curves/expressions outside authored intervals are retained; native loop expressions are added only where no user expression exists.
- Preview cache keys now include actual style content. Catalog review writes bounded sheets and a 20-frame GIF for every new animation/general recipe, avoiding a single enormous sheet. No extra tool panels or buttons were introduced.

## Layer touch response follow-up

The owner reported a pause between a clip tap and the layer panel appearing. Timeline rows had competing single/double tap recognizers, introducing a double-tap recognition wait. They now handle the first completed tap immediately; a second tap within 320ms still enters a group/precomp. Multi-selection, link picking, long-hold movement and range selection retain their paths. Canvas hit testing hoists the camera calculation out of its per-layer loop. Added tests cover immediate state changes, multi-selection and double-tap group entry. Device input-to-display timing remains to be measured.

## Validation status

- First performance checkpoint `4d86302`: stability CI https://github.com/thedatthing123-png/AWIeffect/actions/runs/44384493565 passed (17 tests). This compiled the project/tests but did not execute the new performance test class under that filter.
- Catalog syntax parsing and deterministic manifest generation pass locally. Windows cannot typecheck UIKit/Metal or render iOS presets.
- Initial full Build 33 run on `b74f104` exposed an immutable project variable in a new test fixture; corrected in `79b6395`. App compilation reached the test target before that failure. Superseded runs were canceled so the layer-touch follow-up is included in the actual release validation.
- Current full validation and IPA job: https://github.com/thedatthing123-png/AWIeffect/actions/runs/44389276590 on `79b6395`, initially pending runner assignment. This includes all-shader compilation, all tests, per-preset sheets/moving renders, UI screenshots and packaging. Render quality review, screenshots and device performance remain pending. Do not describe this as a validated release yet.

### Timeout recovery

The ARM run remained queued and was superseded by Intel run `44390977879`. That run passed simulator/device Metal preflight and Swift parsing, but exhausted the 100-minute job limit in the simulator test step. Result extraction/upload was incomplete, so there is no reliable test-pass count or IPA from that run. The available evidence does not identify whether compilation, a particular test or aggregate render time consumed the limit.

The workflow now isolates compilation (`build-for-testing`, 25-minute step cap), distributes the same built products to nine disjoint simulator shards, and gates the archive on aggregate success. `test_shards.py` inventories all 853 parameterless XCTest methods, including same-line actor annotations; each is assigned exactly once. Focused validation modes remain supported. Shards use `test-without-building`, a 65-minute outer cap and XCTest per-test limits. Raw logs upload before bounded result extraction; the reported test count must match assigned selectors and GPU skips cannot quietly pass. Fail-fast is disabled to retain independent failure/render evidence. Artifact names are suffixed per shard to avoid collisions.

The legacy 900-effect single contact sheet is now split into 48-effect pages at explicit scale 1. Every effect still renders, with per-image assertions, but review no longer allocates a roughly 51,000-pixel-high bitmap. Native-device responsiveness and visual preset review still require actual successful artifacts.

### Targeted repair pass (owner requested no full retest)

Split Intel run `44419984280` completed compilation and all unit shards. General premade renders passed 8/8. Other results exposed 26 failed unit checks and one UI-host initialization failure (Accessibility timed out before the UI suite ran); 797 checks passed and one skipped. Failures were collected from the actual per-shard reports in `build_out/44419984280-*`, not inferred from job colors.

Changes under focused validation:

- Contour/surface/interaction shaders read the unmodified source pixel directly instead of linearly sampling it at a nominal pixel center. Frequency-detail transparent pixels explicitly clear RGB. Map Dissolve returns its input directly at zero completion. Exact alpha/endpoint assertions remain unchanged.
- Full-strength smudge no longer drains the carried tip by an unconditional 2% every dab. Low-strength pickup remains.
- 3D text does not return a texture or dismantle/reuse its scene before its separate GPU command buffer has completed; Metal errors now fail rendering explicitly. Blank 3D on the Intel simulator still needs the matching Apple Silicon run to distinguish a host/backend issue from an app bug.
- Preview identity uses the canonical encoded style payload instead of a process-local hash. A fixture additionally asserts style exists before comparing cache identities.
- Preset save round-trip fixtures initialize stable character IDs before asserting exact model equality; the decoder's existing legacy-ID migration was the actual differing data. It is not removed or disabled.
- General preset visibility checks sample the active interval, including motion away from a deliberately neutral first key. Temporal presets receive moving upstream content. Existing difference thresholds remain unchanged.
- The Core ML FP16 tensor bridge uses NSNumber scalar conversion on Intel Simulator only. Device/Apple Silicon typed execution is unchanged; no training starts. Intel Core Image uses its software renderer for filter parity. Live-filter tests wait for actual preview completion rather than a fixed one-second timer.
- The failed all-numeric-controls check is divided into eight disjoint parts and the failed remaining-family motion review into twelve parts. Their original registry/property/render coverage is retained; per-test timeout limits are unchanged.
- Simulators boot to readiness before XCUITest requests Accessibility.

The `repairs` profile selects 152 checks: every failed test (including the replacement parts of timed-out tests), adjacent regressions, and the UI suite that never initialized. It excludes the already-passing general-premade renders and unrelated unit checks. Packaging after that profile is explicitly allowed by the owner's request for a focused rerun. Validation will use Apple Silicon to match the phone's architecture; it is not evidence of real-phone frame rate.

Reference API constraints: [Apple SCNRenderer Metal rendering](https://developer.apple.com/documentation/scenekit/scnrenderer/render(attime:viewport:commandbuffer:passdescriptor:)), [Metal Simulator differences](https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator), and [Core ML typed execution](https://github.com/apple/coremltools/blob/main/docs-guides/source/typed-execution.md). These document the APIs and host differences; they do not establish the cause of our Intel failures without the focused results.
