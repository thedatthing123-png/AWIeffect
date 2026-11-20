# Reference-led effect expansion — November 19

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
