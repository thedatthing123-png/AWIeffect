# Build 32: combined effect expansion

Owner decision: Build 32 is the combined effects-expansion release, not another
single-family release. Presets, final device performance work and AI cutout follow
the expansion, in that order. Training remains paused.

## Completion ledger

| Plan batch | Scope | Status |
| --- | --- | --- |
| 30 | Backgrounds + browser | 12 shipped in Build 31; 24 additional designs implemented, awaiting CI and visual review |
| 31 | 30+ distinct glitches + motion styles | 30 signal primitives plus actual segmented GPU pixel sorting implemented; axis-only variants combined into controls; unvalidated |
| 32 | Liquid + distortion | 32 implemented; unvalidated |
| 33 | Key/matte + actual time effects | 16 matte tools plus Time Slice, Frame Difference and Temporal Median implemented with actual upstream frame sampling; runtime/visual review pending |
| 34 | Transitions | 24 mask/warp transitions and 4 keyed-shutter camera-path transitions implemented; runtime/visual review pending |
| 35 | Shapes + particles | 24 generated shapes + 16 particle profiles implemented; unvalidated |
| 36 | Procedural, Fractal Ridges reference match, glow/light | 36 procedural definitions and 6 source-derived optical light structures implemented; reference comparison and visual review pending |
| 37 | Stylize, retro, text, blur, Hot Color and remakes | Pixel Blur, both Hot Color treatments, 6 cleanup filters, 3 frequency-detail tools, 9 drawing tools, 4 retro treatments and 6 native glyph geometry tools implemented; rendered review/remake checks pending |
| 38 | Designed composites + licensed on-device upscale bake | 4 temporal-change-driven light composites implemented; remaining composite families and licensed upscale bake pending |

Do not interpret the build number as a plan batch number. A candidate with only
batch 30 finished is not the completed Build 32. Do not create aliases, color-only
variants or hidden presets to inflate the effect count. The latest owner request
sets 900 working, distinct definitions as the revised stopping point (November 17).
ExpansionRenderTests enforces the
count gate; the source catalog now reaches its target. Passing the count gate alone
does not prove distinctness, visual quality or performance.

Current source enumeration is 900 definitions, including the legacy catalog.
This is a source inventory, not a verified runtime count or a quality result. The
final 50 are documented in [FINAL_FIFTY_EFFECTS.md](FINAL_FIFTY_EFFECTS.md); do not replace this review with aliases or renamed settings. The all-effects test remains the runtime count authority.

Textured surface family 40 adds 21 native depth-tested image meshes: bend, twist,
dome, saddle, cone, scroll, pleats, ripples, flag, drape, Mobius ribbon, S bend,
hinged panels, crumple, woven image, Gerstner waves, spiral steps, facets, corner
drape, bubbles and image relief. These use the actual source image, cached native
render/depth resources and GPU-generated vertices. They are registered in 3D,
contact sheets and per-effect moving review. Source and adjustment paths preserve
known upstream effect extents instead of silently cropping them at layer bounds.
Tests cover defaults, imported parameter fallbacks, bypass and uniform alignment.
Swift syntax checks pass locally; Metal compilation, rendered results and device
performance remain unverified. Semi-transparent overlapping surfaces use ordinary
depth-tested blending, not order-independent transparency. This is still a partial
expansion checkpoint: the final 50 implementation entries are now present, while release gates remain open.

Contour family 41 adds ten distance-driven tools: signed distance and nearest
boundary vectors, nearest-color extension, boundary pull, contour bands, medial
ridges, contour refraction, tangential contour flow, contour light sweep and
contour folding. See [DISTANCE_EFFECTS.md](DISTANCE_EFFECTS.md) for controls,
algorithm references, memory/accuracy limits and tests. The local CPU oracle
comparison passes; GPU results, visual review and device performance are pending.

Projection family 42 adds twelve actual spherical camera/format tools, with
independent analytic input-layout fixtures and decoder/orientation tests. See
[PROJECTION_EFFECTS.md](PROJECTION_EFFECTS.md). CPU reference imagery was inspected
to tune defaults; actual Metal contact sheets and moving renders remain pending.

Temporal analysis family 43 adds nine actual-frame tools: variance, change
occupancy/timing, acceleration, rank, sigma clipping, color trend, frequency
response and a frame-history grid. See
[TEMPORAL_ANALYSIS_EFFECTS.md](TEMPORAL_ANALYSIS_EFFECTS.md). Tests include known
temporal sample values against independent scalar oracles. Windows are bounded
to eight frames (three for acceleration); runtime/visual/device checks are pending.

Surface finish family 44 adds eight image-space materials: brushed, hammered,
woven, cracked glaze, pooled ink, prism grooves, folded foil and iridescent ridges.
See [SURFACE_FINISH_EFFECTS.md](SURFACE_FINISH_EFFECTS.md). CPU design references
were inspected and weak defaults retuned. Coverage, fallback, bypass and flat-plane
GPU lighting-oracle tests are added; actual GPU and moving-render review is pending.

Gradient-domain family 45 adds Normal to Height, Gradient Integrate, Gradient
Reshape and Periodic Texture, backed by a bounded float32 GPU FFT/Poisson solve.
See [GRADIENT_DOMAIN_EFFECTS.md](GRADIENT_DOMAIN_EFFECTS.md). Independent CPU FFT
and reconstruction checks pass; diagnostic image defaults were retuned after
reference-image inspection. GPU tests include known height fields, independent
direct-DFT comparison, partial/empty coverage, fallbacks and bypass. Actual Metal
execution and rendered/device review remain pending.

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

Owner correction: finish every family and new section before dispatching the big
run. The premature snapshot run 44117862297 was cancelled. Do not run a knowingly
incomplete catalog merely to reach a waiting state. Keep the count gate enabled;
implement the missing effects first, then validate all of them together. Stop
watching once that completed-expansion run has started, as the owner requested.

Coordinate-map additions: Mobius Lens, Sine Fold, Power Spiral, Joukowski Lens,
Exponential Wrap and Tangent Fold. These map complex coordinates rather than
reusing noise displacement. Reciprocal poles are transparent, integer addressing
rejects nonfinite/unsafe coordinates, and zero strength/blend is exact passthrough.
They are registered for the combined sheets and coverage/fallback checks; GPU and
visual validation is still pending, and this is not the completed expansion.

Six morphology tools now use separable min/max envelopes: bright-speck removal,
dark-gap filling, bright/dark detail mattes, local-range matte and extrema smoothing.
They preserve source coverage, offer box/horizontal/vertical neighborhoods, and
bound each 1D pass to 97 samples. No quadratic neighborhood scan is used. The
combined sheets and fallback/bypass checks include these tools; runtime remains
unverified until the completed-catalog run.

Five real temporal samplers: Frame Hold, RGB Time Split, Frame Echo, Time Exposure
and Temporal Range. They request upstream frames through the existing temporal
provider, cap multi-frame sampling at eight, and keep blend bypass/fallback behavior.
Echo composites and extrema modes remain controls within their tool, not additional
catalog entries. Tests now include held-clock stability and zero-delay channel
reconstruction. Artifact generation includes the new temporal tools. No combined
run has been dispatched for this incomplete checkpoint.

Eight feature mattes add structure-tensor corner/coherence/junction/energy responses
and sampled texture deviation/entropy/skew/peak responses. These are editable
building blocks for isolating image structure; they do not identify semantic
objects or replace AI selection. Source coverage is retained, empty fields stay
empty, and the test matrix includes flat-field rejection and parameter fallbacks.

Two further composite designs: Contour Bloom (separate sharp core and colored
multi-scale halo) and Glass Relief (brightness-driven refraction, specular surface
lighting and softened reflection halo). Their light is added in an approximate
linear working space, with source coverage and both color opacities respected.
Browser placement is explicit. Moving-review generation now covers every effect
in batches 30–38, with a control/range manifest, instead of only selected examples.

Four measured-motion tools add a bounded dense GPU Lucas–Kanade pyramid: Motion
Warp, Motion Path Smear, Motion Field and Flow Datamosh. Old simulated datamosh
looks are retained. The new solver uses actual upstream frames, stays on the GPU,
and solves at most 128/256 pixels on the long side with bounded neighborhood and
iteration counts. Datamosh includes the existing smooth/choppy/burst/key-hit
control convention. Dedicated tests use stable moving texture, not changing
illumination; a direct half-float fixture checks known displacement, zero motion
and solve resolution. GPU accuracy, defaults and phone performance remain pending.

A small independent NumPy check of the flow equations and half-float rounding
recovered shifts (4,-3) and (-4,3) with mean error 0.0612/0.0706 pixels on the
analytic texture fixture, and zero for a static pair. This checks sign/scale math;
it does not substitute for running the Metal fixture or reviewing footage.

Frequency stylization adds DCT Blocks and DoG Ink. DCT Blocks performs cooperative
8x8 forward/inverse cosine transforms with coefficient quantization or soft
thresholding; it is not a checker overlay or a JPEG file encoder. All lanes,
including partial-block padding, participate in barriers. Alpha is retained. An
independent direct 2D CPU oracle checks both filters and non-multiple-of-eight
image sizes. DoG Ink uses two Gaussian scales and a smooth extended-difference
ink threshold. Both are included in full moving review; Metal remains unvalidated.

Three nonlinear detail tools add contrast-dependent Edge Diffusion, bounded Shock
Sharpen and Curvature Smooth. Iterative passes alternate two scratch textures, so
raising the pass count does not allocate a full image for each iteration. Original
coverage is retained; transparent neighbors use a no-flux boundary. Noisy fixtures
exercise the cleanup controls. Metal/runtime and visual validation remain pending.

Seven mathematical backgrounds add Chladni Plate, Quasicrystal, Fractal Carpet,
Newton Basins, Prime Spiral, Hilbert Path and Dipole Lines. They use separate
analytic/recursive constructions, not noise variants. Newton iteration, prime
search and curve order have explicit bounds. The prime grid has a known-integer
GPU fixture; every generator has fallback/bypass checks and full moving review.
Their appearance and runtime cost remain unverified until the combined run.

The remaining-expansion work now includes Guided Smooth and TV Luma Clean.
Guided Smooth uses Gaussian-weighted local linear color coefficients and an HDR-
bounded luminance guide. TV Luma Clean uses a bounded primal-dual solve, alternating
four state textures instead of allocating per iteration. Both retain source alpha,
have dedicated constant/empty/bypass checks, and use textured numeric-control
fixtures. These implementations have not yet been validated on Metal.

Continuation batch 39 adds 26 vector/normal data-map operators and the explicit
Vectors & Surface browser section. Operators cover derivatives, field transforms,
midpoint advection, streamline convolution, height normals, normal transforms,
facing mattes, lighting and reference-driven reflection/refraction/reorientation.
They reuse existing effect cards and reference-layer pickers. Their fixture is an
analytic RGB unit-normal field with varied directions and grazing slopes, not
arbitrary artwork whose colors cannot exercise normal-map controls. No render or
UI approval is claimed; the combined run has not been started.

Final continuation batches 46�48 add 15 spectral operators, 20 layer interactions and 15 graphic craft tools. See [FINAL_FIFTY_EFFECTS.md](FINAL_FIFTY_EFFECTS.md) for the complete manifest, research, controls, local evidence and limitations. This reaches 900 source entries. Metal/runtime count, all-effects quality, moving renders, UI review and device performance are still pending; this is not a verified shipping claim.
