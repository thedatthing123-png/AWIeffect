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
- Initial full Build 33 run https://github.com/thedatthing123-png/AWIeffect/actions/runs/44388323381 began on `b74f104`. The layer-touch follow-up requires a newer full run before delivery. Render quality review, screenshots and device performance remain pending. Do not describe this as a validated release yet.
