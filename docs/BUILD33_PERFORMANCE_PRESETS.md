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

References inform timing/control structure; no proprietary presets, source or assets are copied. Results and render review are pending.
