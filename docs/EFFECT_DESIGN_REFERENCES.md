# Build 32 behavior research

Reference behavior informs independent implementations; no proprietary shader code
is copied. These are design references, not evidence the current expansion has
passed runtime/visual tests. The owner requested one combined validation after all
families are implemented.

## Signal damage and sorting

Sapphire PixelSort documents thresholded source-pixel sorting along linear, radial
and circular paths. Real sorting needs an ordering pass; moving blocks is not a
pixel sort. The new signal primitives deliberately have names describing their
actual spatial operations. None is mislabeled as true temporal datamosh, frame
stutter or history-based echo.

https://borisfx.com/documentation/sapphire/ae/pixelsort/

## Distortion

Adobe's distortion documentation distinguishes displacement fields from geometry
transforms, with explicit source sampling and edge handling. The new flow family
uses bounded vector fields, signed displacement, editable center/direction and four
edge modes. Fine sampling uses a fixed 2x2 footprint. Each flow mode has its own
formula, not a different seed/default of the same warp.

https://helpx.adobe.com/after-effects/desktop/apply-effects-and-animation-presets/list-of-effects/distort-effects.html

## Matte and reference-layer operations

Adobe's keying documentation distinguishes chroma, luminance and reference-image
difference keys. Existing AWIeffect keyers were inspected before adding channel,+saturation, local-contrast, chroma-edge and finite-luma-band mattes. The difference
and wrap effects use the existing explicit reference-layer picker. No reference
means passthrough, not fabricated input. Source alpha is respected, and matte-only
output remains an inspectable grayscale view.

https://helpx.adobe.com/after-effects/desktop/animate-in-after-effects/work-with-keying-effects/keying-effects.html

## Transition controls

Sapphire's dissolve documentation separates an editable progress parameter from
automatic timing. New transitions keep manual, keyframeable Completion, explicit
visible/hidden endpoints, reverse direction and edge softness. They do not silently
replace the clip's timing or become black-box presets.

Four additional camera-path transitions integrate eight samples of the keyed
Completion animation during an editable millisecond shutter interval. Held curves
use one spatial sample and stay sharp. Curved Whip, Corner Tumble, Spiral Pull and
Split Fold have different inverse mappings, including perspective division for the
folding paths. These blur their transition movement, not the source video's own
motion. Existing transition IDs and their saved rendering remain unchanged.

https://borisfx.com/documentation/sapphire/ae/dissolve/

## Glow/light

Blender's Glare documentation distinguishes bloom, streaks and ghost artifacts.
Use the app's existing soft-knee light extraction and downsampled blur pyramid as
infrastructure. New light families still need distinct emission/compositing designs
and visual review; re-tinting one bloom is not another effect.

https://docs.blender.org/manual/en/4.5/compositing/types/filter/glare.html

The new optical pass gathers source-derived emission through six different
structures: circular annulus, scaled inverted reflections, contracting spiral,
opposed tinted streaks, polygon perimeter, and channel-separated annuli. These are
independent implementations, not Blender shader copies. Source prefiltering and
bounded tap counts avoid loops that grow with radius. All six still require
rendered comparison, edge checks and performance review before release.

## Fractal Ridges and Hot Color

The supplied AE Motion IPA's parameter metadata and arithmetic were inspected.
Ridges uses evolving 3D simplex noise, a squared ridge response, a previous-octave
coupling term, and an octave-specific parallax offset. The two supplied versions
have different stretch/scale behavior; do not silently conflate them. Exact-match
acceptance still requires reference numerical/visual comparison.

Hot Color is a luminance-conditioned chroma/tint operation with a bright shoulder,
not merely a red gradient map. Both treatments are implemented; comparison and
default tuning remain. These must not be marked complete just because named entries exist.

The underlying published simplex formulation has an MIT-licensed upstream reference:
https://github.com/ashima/webgl-noise

## Frequency detail

Detail Bands reconstructs the source from a broad Gaussian base, a middle
difference band and a fine residual, with separately editable signed gains.
Band Pass retains only the difference between two independently scaled surrounds.
Both normalize blurred samples by their own alpha coverage and preserve the source
matte, rather than treating transparent padding as black image data.

Retinex Detail uses the three-scale log source/surround relationship documented
in the IPOL paper, implemented independently. It operates on luminance, restores
the source hue through a luminance ratio, and uses a bounded analytic tone mapping
instead of the paper's image-wide percentile normalization. It is an editable
local-detail adaptation, not a claim to implement the paper's complete MSRCR or
MSRCP pipeline. No external implementation code was copied.

https://www.ipol.im/pub/art/2014/107/

## Actual time sampling

Adobe's time-effects reference distinguishes image differences across frames from
spatial displacement of a single image. The new Time Slice reads upstream frames
at an editable interval and maps them linearly or radially across the image.
Hold and Blend describe sample interpolation; no optical-flow reconstruction is
claimed. Frame Difference compares actual temporal samples, and Temporal Median
uses previous/current/next frames. The earlier Time Slice Mask keeps its existing
ID and remains explicitly a spatial matte.

https://helpx.adobe.com/after-effects/desktop/apply-effects-and-animation-presets/list-of-effects/time-effects.html

Sampling re-evaluates raw animation/parenting at project-frame times, excludes the
current/downstream pixel stack, and preserves upstream processing. Layers,
adjustments, camera/3D viewports and backdrop-displacement stacks have explicit
sampling paths. Backdrop samples are captured before the current coverage mask.
The cache lives only for a root render and owns its images independently of nested
scratch-pool scopes. Its retained entries are capped at 64 MiB; that is a cache
bound, not a claim about total in-flight GPU memory or device frame rate.

Tests include a generated red/blue video cut, animated parent motion, upstream vs
downstream fill ordering, moved backdrop coverage and cache invalidation after an
edit. Runtime validation, deep-stack stress and visual judgment remain pending.

## Image-driven drawing

The new drawing pass distinguishes nine image operations: tangent-guided bilateral
smoothing, gradient-aligned hatch patches, oriented capsule marks, multi-scale
mezzotint pits, signed gradient displacement, signed Laplacian curvature, Hessian
line-center detection, source-tone spiral engraving and local-surround solarization.
It does not rename a Kuwahara filter or a fixed crosshatch to create extra entries.
Mezzotint has an explicit stable Random Seed control. Ink/paper alpha participate
in the treatment, source coverage is preserved except for the intentional Edge
Stretch warp, and every pass uses bounded sample counts. Rendered tuning remains
required before these are accepted for release.

## Segmented sorting

Segment Pixel Sort implements an independent cooperative bitonic network over
segment/key/original-position tuples. Threshold-excluded pixels are isolated
segments, so sorting cannot move a pixel across a threshold boundary. Hue ties
remain stable. Windows are intentionally bounded (8–128 layer pixels, up to 256
buffer samples after density scaling), not marketed as a full-image arbitrary-run
sort. Horizontal/vertical and key choices are settings of one effect, not extra
catalog entries. Existing sorted-looking streaks keep their original ID/behavior.
An independent tuple-sort oracle checks randomized networks locally; GPU tests
check actual pixel ordering, excluded locations, partial windows and both axes.

https://developer.nvidia.com/gpugems/gpugems2/part-vi-simulation-and-numerical-algorithms/chapter-46-improved-gpu-sorting

## Native text geometry and retro

Text Arc, Cylinder, Sphere, Accordion, Helix and Attractor operate on glyph states
before existing glyph projection. They also work through Text Studio's stable-ID
letter selectors. The effects do not create/replace animators or animation presets.
Their render-snapshot data is excluded from TextData's CodingKeys; settings remain
stored once on Layer.effects or the existing animator letterEffects. Animated
bounds use the same geometry states as drawing, including vertical type and real
per-letter depth. Layer and effect Mix/Solo semantics are applied explicitly.

Retro additions use different image mechanisms: one-way thresholded CCD charge
smear, scanline carrier modulation/demodulation, independently transformed RGB
plates and actual previous-frame channel-dependent phosphor decay. These are
stylizations, not calibrated emulations of a named camera or broadcast standard.

## Change-driven light composites

The first batch 38 family compares actual upstream frames, thresholds changing
RGB/luminance/alpha and then constructs glow, directional streaks, radial rays or
hollow rings. The current image is retained separately from the emission. No
emission means exact source passthrough; this is enforced without altering the
older photographic glow compositor or saved glow rendering. These composites
still need rendered tuning, timing/stack tests and device profiling.
# Coordinate maps (batch 32)

- Harvard Math 113, linear fractional transformations and the Joukowski map:
  https://people.math.harvard.edu/~siu/math113/13_linear_fractional_transformation.pdf
- NIST DLMF elementary complex and hyperbolic identities:
  https://dlmf.nist.gov/4.28 and https://dlmf.nist.gov/4.35

Independent coordinate implementations: fractional linear, complex sine/power,
reciprocal Joukowski, exponential and complex tangent. Field size is in layer
pixels; direction rotates the map's frame, not just its output. These are inverse
texture-coordinate maps, not simulations of physical glass. Principal-angle power
has an intentional branch seam. Undefined poles become transparent under all edge
modes. Finite extreme coordinates are bounded before integer addressing; hyperbolic
arguments are limited to prevent overflow. No reference implementation was copied.

## Morphology (batch 37)

MathWorks documents opening as erosion then dilation, closing in reverse, and
white/black top hats as differences from those envelopes:
https://www.mathworks.com/help/images/morphological-dilation-and-erosion.html
The implementation independently applies separable rectangular scalar min/max
passes to straight luminance, then restores source coverage. This is luminance
cleanup and matte extraction, not an alpha choke or replacement for Remove BG.
Neighborhoods are sampled in image pixels, with replicated buffer boundaries;
source transparency contributes zero light. Fine antialiased edges retain their
original coverage. Half-float intermediate scalar textures avoid 8-bit clipping.

## Structure and texture mattes (batch 33)

- Harris and Stephens, *A Combined Corner and Edge Detector*, AVC 1988:
  https://www.bmva.org/bmvc/1988/avc-88-023.html
- Local texture histogram entropy:
  https://www.mathworks.com/help/images/ref/entropyfilt.html

Independent central-derivative tensors are Gaussian integrated, then converted to
corner response, directional coherence, isotropy/junction and gradient energy.
The corner tool exposes a response field, not discrete nonmaximum-suppressed
tracking points. Texture tools sample 9/25/49 locations across the chosen radius;
this is a sparse neighborhood at large radii, not a dense all-pixel histogram.
Skew and excess-kurtosis responses are deviation weighted to suppress unstable
standardized moments in flat regions. Eight entropy bins use a bounded SDR
histogram; tensor and moment paths retain HDR input. Coverage contributes to the
signal so constant-color silhouettes still have detectable edges.

## Surface composites (batch 38)

Contour Bloom separates a difference-of-surround contour source from a four-scale
halo. Sharp/halo intensities and color opacities remain independent. Glass Relief
uses derivatives of smoothed image brightness as a height-field normal, offsets
source sampling through that field, and shades a specular halfway-vector highlight
before a separate halo pass. This is an artistic image-space relief, not ray-traced
glass or a physical thickness simulation. Both composite in an approximate gamma
2.2 linear space and retain HDR headroom rather than clamping each light channel to
one. Their default appearance still requires the combined GPU/render review.

## Measured motion (batch 31)

Bouguet, *Pyramidal Implementation of the Lucas Kanade Feature Tracker*:
https://web.stanford.edu/class/cs231m/references/pyr-lucas-kanade-feature-tracker-bouget.pdf
and OpenCV's explanation of the method:
https://docs.opencv.org/4.x/d4/dee/tutorial_optical_flow.html

Independent dense GPU implementation with three pyramid levels, regularized local
normal equations and bounded updates. It estimates backward correspondence:
previous(x - displacement) approximates current(x). Fields store displacement in
their own level's pixels and are rescaled between levels and at final sampling.
Fast/Fine use long-side limits 128/256, windows 3x3/5x5 and 3/5 iterations per
level. The confidence term penalizes residual mismatch and weak image gradients.
This is not neural flow; scene cuts, occlusion, repeating patterns and illumination
changes remain ambiguous. Maximum Motion bounds correspondence search, not just
the final artistic displacement. The solver performs no synchronous CPU readback
in the editing/render path. Motion Field exposes direction, RG displacement and
magnitude as controls in one tool rather than counting those as separate effects.

## Frequency stylization (batch 37)

Adobe Research's XDoG paper describes extended difference-of-Gaussians ink
thresholding and its artistic range:
https://research.adobe.com/publication/xdog-an-extended-difference-of-gaussians-compendium-including-advanced-image-stylization/
DoG Ink independently applies two Gaussian scales and a tanh threshold; it does
not implement the paper's separate flow-based variants or texture synthesis.
DCT Blocks uses an orthonormal type-II cosine basis and its transpose, centered
Rec.601-style YUV and an editable frequency-weighted coefficient filter. It has
neither JPEG entropy coding nor chroma subsampling and does not claim bitstream
compatibility. Filter type and chroma loss are options inside one tool, not catalog
duplicates. Average-preserving mode skips the DC coefficient; original alpha is
copied after reconstruction. Edge blocks replicate source coordinates, and all
64 cooperative lanes reach every barrier.

## Analytic backgrounds (batch 30)

Wolfram's first-party mathematical references describe plate nodal figures and
the Hilbert space-filling curve:
https://resources.wolframcloud.com/FunctionRepository/resources/ChladniFigure/
https://reference.wolfram.com/language/ref/HilbertCurve.html
Independent implementations also cover plane-wave quasicrystals, recursive square
carpets, complex Newton iteration for z^n-1, and a prime-marked integer spiral.
The dipole construction uses a two-dimensional logarithmic potential and its
angular harmonic conjugate; it does not claim the 3D point-charge 1/r potential.
Newton points that do not converge within the bounded iteration budget are shown
as background. Prime-number offsets cycle within a bounded range so trial division
remains valid even at long timeline times. No reference shader code was copied.

## Advanced denoise (batch 37)

- He, Sun and Tang, *Guided Image Filtering*:
  https://kaiminghe.github.io/publications/eccv10guidedfilter.pdf
- Chambolle and Pock, *A First-Order Primal-Dual Algorithm for Convex Problems with
  Applications to Imaging*: https://www.cmap.polytechnique.fr/preprint/repository/685.pdf

Guided Smooth independently uses Gaussian-weighted, coverage-normalized moments,
bounded local linear coefficients and a luminance/(1+luminance) guide. This differs
from the reference's box-window implementation. TV Luma Clean uses ROF-style
luminance fidelity, projected dual gradients, tau=sigma=0.25 and extrapolation one.
Neumann boundaries exclude transparent neighbors. Half-float state is bounded;
extreme HDR values above the solver range keep their original luminance plus the
bounded solved correction. Original chroma and alpha are restored. CPU equation
checks and eventual Metal fixtures are separate forms of evidence.

## Vector and normal maps (continuation batch 39)

- Cabral and Leedom, *Imaging Vector Fields Using Line Integral Convolution*:
  https://dl.acm.org/doi/10.1145/166117.166151
- Barré-Brisebois and Hill, *Blending in Detail*:
  https://blog.selfshadow.com/publications/blending-in-detail/

Independent operators use centered RG vectors and decoded unit RGB normals.
Finite differences, local Jacobians and midpoint field integration operate on
values, not the positions of the entire image. Streamline noise is bidirectionally
integrated with a bounded sample count. Normal composition includes reorientation,
whiteout and normalized linear blending in one tool. Reflection uses a chosen
equirectangular environment; refraction uses a chosen image, an entering-ray index
ratio and per-channel dispersion. Source alpha is retained or multiplied by sampled
reference coverage. Facing selection is the explicit exception that modifies alpha.
This is data-map processing, not automatic character normal estimation or mesh
rigging. No reference source code was copied. Pipeline/interface and visual checks
are included in the combined validation, not claimed from source syntax checks.

## Nonlinear detail (batch 37)

- Perona and Malik, *Scale-Space and Edge Detection Using Anisotropic Diffusion*:
  https://people.eecs.berkeley.edu/~malik/papers/MP-aniso.pdf
- Osher and Rudin, *Feature-Oriented Image Enhancement Using Shock Filters*:
  https://epubs.siam.org/doi/10.1137/0727053

Independent explicit GPU updates implement four-neighbor contrast conduction,
luminance-driven shock steepening, and regularized curvature-directed smoothing.
Step sizes are bounded and the updated color is limited to local extrema. This
preserves practical numerical bounds, not a claim to reproduce every continuous
PDE property from the papers. Alpha is unchanged; transparent neighbors contribute
the center value. Two scratch images alternate through encoder-ordered passes.
