# Build 32: combined effect expansion

Owner decision: Build 32 is the combined effects-expansion release, not another
single-family release. Presets, final device performance work and AI cutout follow
the expansion, in that order. Training remains paused.

## Completion ledger

| Plan batch | Scope | Status |
| --- | --- | --- |
| 30 | Backgrounds + browser | 12 shipped in Build 31; 24 additional designs implemented, awaiting CI and visual review |
| 31 | 30+ distinct glitches + motion styles | 30 implemented; axis-only variants combined into controls; unvalidated |
| 32 | Liquid + distortion | 32 implemented; unvalidated |
| 33 | Key/matte + actual time effects | 16 matte tools implemented; temporal rendering and review pending |
| 34 | Transitions | 24 mask/warp transitions and 4 keyed-shutter camera-path transitions implemented; runtime/visual review pending |
| 35 | Shapes + particles | 24 generated shapes + 16 particle profiles implemented; unvalidated |
| 36 | Procedural, Fractal Ridges reference match, glow/light | 36 procedural definitions and 6 source-derived optical light structures implemented; reference comparison and visual review pending |
| 37 | Stylize, retro, text, blur, Hot Color and remakes | Pixel Blur, both Hot Color treatments and 6 detail-cleanup filters implemented; other families and review pending |
| 38 | Designed composites + licensed on-device upscale bake | Pending |

Do not interpret the build number as a plan batch number. A candidate with only
batch 30 finished is not the completed Build 32. Do not create aliases, color-only
variants or hidden presets to inflate the effect count. The latest owner request
requires over 1,000 working, distinct definitions. ExpansionRenderTests enforces the
count gate; the current catalog is still below it. Passing the count gate alone
does not prove distinctness, visual quality or performance.

## Release gates

Keep one registry and one Metal file per batch. Preserve IDs, parameter defaults,
editing, undo, existing projects, transport and AI Link settings. Inspect the current
implementation and reference behavior before each family. No GPL/proprietary shader
code is copied. Numeric wiring tests, compatibility, alpha, edge and animation checks
must pass. Review contact sheets and motion for each family; retune weak defaults.

Owner update: implement all families before the big validation run. Do not dispatch
more family-only CI runs. The earlier background checkpoint failed on a reserved
Metal identifier, now corrected locally. After every family is implemented, run the
combined full validation, review all sheets/moving renders/UI, fix and retune, then
package the fully green release. No intermediate IPA is sent as the combined release.
Simulator validation does not establish 60 fps on the owner's phone.
