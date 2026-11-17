# Build 32: combined effect expansion

Owner decision: Build 32 is the combined effects-expansion release, not another
single-family release. Presets, final device performance work and AI cutout follow
the expansion, in that order. Training remains paused.

## Completion ledger

| Plan batch | Scope | Status |
| --- | --- | --- |
| 30 | Backgrounds + browser | 12 shipped in Build 31; 24 additional designs implemented, awaiting CI and visual review |
| 31 | 30+ distinct glitches + motion styles | Pending |
| 32 | Liquid + distortion | Pending |
| 33 | Key/matte + actual time effects | Pending |
| 34 | Transitions | Pending |
| 35 | Shapes + particles | Pending |
| 36 | Procedural, Fractal Ridges reference match, glow/light | Pending |
| 37 | Stylize, retro, text, blur, Hot Color and remakes | Pending |
| 38 | Designed composites + licensed on-device upscale bake | Pending |

Do not interpret the build number as a plan batch number. A candidate with only
batch 30 finished is not the completed Build 32. Do not create aliases, color-only
variants or hidden presets to inflate the effect count. Around 1,000 usable effects
is the ambition; each effect must earn its place.

## Release gates

Keep one registry and one Metal file per batch. Preserve IDs, parameter defaults,
editing, undo, existing projects, transport and AI Link settings. Inspect the current
implementation and reference behavior before each family. No GPL/proprietary shader
code is copied. Numeric wiring tests, compatibility, alpha, edge and animation checks
must pass. Review contact sheets and motion for each family; retune weak defaults.

Checkpoint CI runs use `validation=all` and `package_ipa=false`. After every ledger
entry is complete and the UI is inspected, run the final full validation with IPA
packaging enabled. Only that reviewed, green package is sent as the combined release.
Simulator validation does not establish 60 fps on the owner's phone.
