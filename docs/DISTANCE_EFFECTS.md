# Contour effects: batch 41

Ten new image operators share an approximate Euclidean distance field. They work
from the input image at their position in the stack, including earlier effects.
They do not change project models, selection tools, AI cutout or rig behavior.

## Tools and intended use

| Effect | What it does |
| --- | --- |
| Signed Distance Map | Middle gray is the threshold contour; white moves inward, black outward. Use as a matte or displacement source. |
| Boundary Vectors | RG encodes displacement to the nearest contour, centered at 0.5; it differs from local brightness-gradient vectors. |
| Nearest Color Extend | Fills outward from actual contour colors with controllable reach, fade and sample inset. Useful before texture deformation. |
| Boundary Pull | Smears interior texture toward the silhouette while retaining the input alpha. |
| Contour Bands | Repeated colored bands follow the silhouette and holes. Spacing, width, phase and inside/outside placement are editable. |
| Medial Ridges | Soft matte of interior distance ridges where competing fronts meet. Not a topology-preserving or one-pixel skeleton. |
| Contour Refraction | A curved rim bends texture along outward contour normals; input alpha stays unchanged. |
| Contour Flow | Several integration steps transport texture tangentially around the boundary, with falloff into the interior. |
| Contour Light Sweep | An animated distance band emits a sharp light and separately sized halo while retaining the source. |
| Contour Fold | Reflects successive texture strips along nearest-boundary normals, keeping the existing cutout alpha. |

Use **Alpha** on an isolated shape, text or cutout. Use **Luminance** to derive
contours from opaque artwork. Luminance uses premultiplied brightness so transparent
RGB does not create phantom boundaries. Threshold is shared by the field and the
inside/outside classifier. Missing parameters resolve to registry defaults.

## Implementation and limits

An eight-neighbor initialization locates subpixel threshold crossings. Two RG32F
textures propagate candidate contour positions in descending power-of-two jumps,
followed by two extra one-pixel refinement passes. Coordinates stay in source
pixels; distance measurements account for rectangular field/source sizes.
Tie breaking is deterministic. No valid boundary means unchanged input, including
for an empty image. Texture allocation fallback also bypasses the operator.

Field Resolution caps the longest scratch side at 512, 1024 (default), or 2048.
It never enlarges a smaller source. The two scratch textures occupy at most
16 MiB at the default or 64 MiB at 2048, excluding input/output and pool spares.
Flooding uses nine candidate reads per pixel per pass; tangential transport is
capped at twelve steps. No CPU mesh, synchronous readback or training runs in
production. The pool's format byte accounting and blank fallback initialization
now include RG32F's actual eight bytes per pixel.

This is an approximation: sub-resolution features can disappear on large inputs,
and the nearest candidate can differ from an exhaustive distance transform.
Increase field resolution for thin details. Numeric thresholds and renderer tests
do not establish visual quality or 60 fps. The combined release must still pass
Metal compilation, GPU tests, per-effect contact sheets and moving review.

## Research and validation

The algorithm follows the published jump-flooding approach; implementation is
original and does not import third-party shaders:

- Rong and Tan, [Jump Flooding in GPU with Applications to Voronoi Diagram and Distance Transform (2006)](https://www.comp.nus.edu.sg/~tants/jfa.html).
- Rong and Tan, [Variants of Jump Flooding Algorithm for Computing Discrete Voronoi Diagrams (2007)](https://www.comp.nus.edu.sg/~tants/jfa-variants.html).

`DistanceEffectTests` uses a colored, soft-alpha cutout with a hole. It checks
defaults, missing saved parameters, blend bypass, empty inputs, and preservation
of alpha by the four texture warps. A separate oracle enumerates every threshold
crossing and exhaustively searches nearest seeds on a 39x27 concave fixture with
a hole, isolated island and border contact. The GPU tolerance is 0.75 source px.
An independent local CPU simulation of that fixture produced zero distance error;
this is a math check, not a GPU test result.

The generic numeric-control tests use the same cutout fixture and matched baseline.
The family is included in registry uniqueness, contact sheets and per-effect moving
render generation. No numeric-control exemptions were added for these tools.
