# November 13 editing polish

Scope: the November 12 pasted editing notes, plus the correction that enabling one layer's motion blur must not enable Every Layer. Connector/Cloudflare work is excluded.

## Motion blur

- The primary switch in a layer's panel controls that layer. Enabling it opens the project master gate without changing other switches or Every Layer.
- The camera's switch opts its affected shot into shutter sampling. A 3D-only camera leaves 2D overlays sharp. Camera eligibility is evaluated at the rendered time, including camera cuts.
- Turning a layer off explicitly keeps it sharp even when camera blur or Every Layer is active.
- Individual layer shutter samples continue evaluating camera, parent/null and transform-effect movement together. Existing camera and parenting GPU tests are retained; new tests cover switch isolation and camera opt-in.
- Group buffers retain authored animation and composition shutter settings. Editing a member's switch inside a group retains the master gate when its local timeline is closed.
- Shutter accumulation uses three reusable textures instead of allocating another full composition texture for every sample.
- Pixel Motion Blur in Quick Tools opens the actual footage-motion controls rather than silently enabling transform blur.

## Glitches and adjustment edges

- Wave Glitch flows continuously by default. Hold Frames retains intentional stepped animation.
- Earthquake Displace keeps its chunk layout stable while smoothly interpolating displacement vectors.
- AWI Glitch, Glitch Blocks, Glitch Lines, Block Corruption, Slice Glitch, Interlace, Displacement Glitch and VHS Tracking expose Smooth Slide / Snap-Hold where they move pieces. Smooth movement interpolates coordinates; it does not crossfade snapshots. Static noise and intentionally frozen codec blocks retain their character.
- Motion Tile on an adjustment retains repeat/mirror sampling when a later transform moves beyond the frame. Manual Output Size still uses the explicit bounded output.
- Existing group/precomp and clip-below alpha fixes remain in place.

## Selection and interaction

- AI-assisted selection unions the inferred result with explicit paint and prior selection. A model missing thin outlines can no longer erase coverage the editor deliberately painted.
- Brush region-growing allocates only its bounded search area, and visits each queued pixel once. Quick Select, Select Brush and cutout edge assistance use this same flood routine.
- Timeline key/trim/slip/lane drags and marquee selection clean up cancelled gestures; scrolling must not remain disabled after a system cancellation. Panel resizing also finalizes cancellation cleanly.

## Already delivered/preserved

Group-local zero-based timelines, separate Paste Size & Bounds, duration-adapted effect-key pasting, repeated text presets, spatial motion-path handles, rotation snapping, per-letter/word styling and group subtree duplication. No replacement controls were added for these existing systems.

## Validation

Local Swift parsing and whitespace checks precede CI. Full CI must pass before handing over the IPA. Regression tests cover independent blur selection, camera cuts, adjustment tiling, and between-frame glitch motion. The authoring artifact contains 60 sampled frames for each changed glitch family for visual inspection. Passing those renders is not a measurement of sustained 60 fps on the user's phone.

Manual phone checks: enable one moving layer's blur and compare with a sharp neighbour; enable the camera's blur and use a camera cut; cancel a keyframe drag and scroll; stack adjustment Motion Tile before Transform; paint across an ink edge and apply AI selection; replay the glitch examples.

## References consulted

- Adobe motion blur and shutter semantics: https://helpx-origin-uw2.aws116.adobeitc.com/after-effects/desktop/animate-in-after-effects/assorted-animation-tools/assorted-animation-tools.html
- Adobe footage pixel-motion blur: https://helpx.adobe.com/after-effects/desktop/apply-effects-and-animation-presets/list-of-effects/time-effects.html
- Adobe Quick Selection brush and edge refinement: https://helpx.adobe.com/photoshop/desktop/make-selections/automatic-color-based-selections/paint-a-selection-with-quick-selection-tool.html
- Adobe selection refinement: https://helpx.adobe.com/photoshop/desktop/make-selections/refine-modify-selections/refine-your-selection-and-mask.html
