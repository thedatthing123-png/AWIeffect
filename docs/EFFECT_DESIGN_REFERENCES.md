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
