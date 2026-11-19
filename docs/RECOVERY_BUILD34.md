# Build 34 — stable editor recovery

Owner direction, November 18: return to the working editor before effect expansion, discard the new premade batch, restore the older auto-cutout/selection behavior, and keep the subsequent performance/responsiveness work. Keep newer AI models and training data for later. This direction supersedes the expansion/preset plan; no new effect or preset expansion is authorized by those older plans.

## Exact baseline

`21634bc` ("Extend adjustment tiling through pixel distortion stacks") is the editor immediately before `e46521c` introduced shared experimental brush-guided region selection. The first expansion commit is later (`718f24f`). Choosing the earlier boundary also satisfies the owner's explicit confirmation to restore the pre-experiment AI behavior.

This retains the accepted shape-contents rebuild, native text studio, graphs/remap, rig/bone/weight systems, original effect catalog and premades, masking/groups, individual/camera blur and prior editing fixes. `App/Library/PresetLibrary.swift`, `TextPresetLibrary.swift`, `App/Model/Text.swift`, `Renderer.swift`, `CutoutStudio.swift`, `InlineCutout.swift` and `DrawStudioView.swift` have been byte-compared (normalizing line endings) against that baseline.

The product version is **34**, not 29: feature recovery must not make an installed update's build number go backward.

## Retained later fixes

- Cherry-picked `4d86302`: revision-based normal preview invalidation, CPU/GPU-aware adaptive preview, capacity checks before drawable acquisition, coalesced cache notifications, selected-only moving preset previews/cancellation, priority for actual video requests over prefetch, background automatic thumbnail rendering.
- Immediate timeline selection and camera calculation hoisting. The window-level simultaneous container double-tap observer is retained: its latest UI check passed on `44441397401`; the earlier moving SwiftUI observer was insufficient.
- Canonical style-content preview keys, bounded preview LRU, and synchronized 3D text command-buffer completion/error handling.
- Full-strength smudge retains carried paint; Intel-simulator filter fallback and completion-based live-filter testing are retained independently of AI selection.
- The small existing Block Corruption timing repair (`3b592ea`) is retained; it does not add an effect family.

## Removed from this product

The registry/shaders/render core come from the baseline, so expansion batches 30–48 and their renderer changes are absent. Build 33 CraftPresets33, its three new catalogs and its expansion/preset tests/resources are absent. Legacy premades remain exactly as they were. PromptSegmentationModel, InteractiveSelection and the SAM model bundles are not compiled or bundled in this recovery app. The older Auto Remove Background, Auto Box, Keep/Cut and Art Studio selection paths remain available.

Projects and AI Link settings have not been opened, rewritten, deleted or reset. Unknown serialized effect instances still decode and retain their parameters; expansion-only effects cannot render in the restored catalog. A regression checks that unsupported effect data survives serialization rather than being silently discarded.

## Preservation / provenance

Recovery worktree: `C:/Users/loana/Documents/Codex/2026-11-01/hey/AWIeffect-stable-recovery`, branch `feat/stable-editor-recovery`.

The original checkout `C:/Users/loana/Documents/Codex/2026-11-01/hey/AWIeffect-graph` and branch `feat/rig-authoring-overhaul` retain all expansion code, bundled AI model packages, datasets/resources, and the owner's existing uncommitted `.gitignore`, `docs/SELECTION_TRAINING.md` and `scripts/train_selection.py`. They were not moved or deleted. Model training is not started. This separate recovery branch avoids a destructive reset, forced push or deletion of experimental work.

## Validation

Modern split CI and shader preflight are retained, adjusted to discover only the recovered tests. Original numeric-control coverage is divided into eight disjoint methods without removing checks. Effect and old-text review sheets are paginated at scale 1 to avoid enormous bitmap allocation. The matrix omits empty expansion-only shards and the old segmentation scope no longer asks for a removed experimental test class.

Local baseline/source checks, Swift parsing, workflow/shell syntax and complete test-inventory checks are required before dispatch. Recovery tests check that the discarded catalogs/model are not bundled and archived effect data remains readable. The build is not validated until the restored suite, UI screenshots and packaging pass; real-phone responsiveness still requires testing on the owner's phone.
