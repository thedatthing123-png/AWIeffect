# Surface finishes: batch 44

Eight source-image finishes combine procedural surface geometry, image-derived
relief, directional lighting and (where applicable) refraction or coating color.
They retain the original cutout alpha. These are editable building blocks for
artwork, lettering and surfaces, not baked bitmap overlays or color-only presets.

| Finish | Distinct construction |
| --- | --- |
| Brushed Surface | Fine wandering grooves and strongly anisotropic reflections. |
| Hammered Surface | Irregular rounded impact pits with normals derived from nearest-cell geometry. |
| Woven Relief | Continuous crossing thread profiles with alternating over-under height and directional reflection. |
| Cracked Glaze | Narrow cellular seam depressions, glossy surface shading and independent crack darkening. |
| Pooled Ink | Nonlinear dark-region pooling, low-amplitude capillary texture and glossy light. No fluid simulation is claimed. |
| Prism Grooves | Asymmetric triangular facets, directional reflection and opposite red/blue refraction. |
| Folded Foil | Interacting broad and fine crease fields with a separately editable crease exponent. |
| Iridescent Ridges | Curved ridges and an angle-dependent three-wavelength coating approximation. |

Surface Scale/Depth and the finish-specific shape control define the microgeometry.
Image Relief adds a separate smoothed brightness-derived height. Surface Direction
turns the microstructure; Light Direction/Elevation move illumination. Roughness,
Metalness, Light Energy and Ambient control reflection and diffuse color. Evolution
and Surface Speed move the material field without moving the artwork. Controls use
the normal effect card, keyframes, numeric entry and scrubbers; no new studio exists.

## Lighting and execution

The shader uses an original implementation of anisotropic Trowbridge-Reitz/GGX
distribution, separable Smith masking and Schlick Fresnel, with diffuse shading.
Brushed/weave finishes have distinct tangent/bitangent roughness; other finishes
use isotropic roughness. The source is interpreted using the existing engine's
gamma-style color convention, with premultiplication removed/restored around
shading. This is an image-space material approximation, not a path tracer or a
complete energy-conserving layered BSDF. There is no inferred 3D mesh, environment
map, indirect lighting or physically complete thin-film interference solver.

The iridescent coating samples three representative wavelengths, with optical
phase changing by normal/light orientation and film thickness. Prism dispersion
reads shifted source channels, falling back to the original channel if a lookup
has no alpha. No finish fills an empty pixel or changes input coverage. Blend zero
returns the input before allocating a smoothing texture.

Image-relief smoothing uses the existing separable/downsampled Gaussian. It is
skipped when neither linear image relief nor ink pooling needs it. Fine unresolved
micro-relief is attenuated to reduce shimmer. Hammered/glaze normals use analytic
derivatives from one 3x3 cell search, also reused for crack shading, rather than
four repeated neighborhood searches. Other finishes use bounded finite-difference
height evaluation. The flat-height path avoids procedural height evaluation.

Finite bounds, pooled textures and fewer searches do not establish 60 fps. Large
surfaces, many stacked finishes and animated source relief need device profiling.
The final performance pass remains open.

## Design and validation

Independent CPU design references on colored cutout lettering were inspected for
all eight profiles. Brushed scale/depth and light alignment were retuned to produce
coherent brushing instead of tiny isolated sparkles. Pooled-ink light elevation,
roughness and capillary amplitude were adjusted for a clearer coating response.
These reference images are **not Metal-rendered contact sheets**.

`SurfaceFinishTests` checks real default visibility, missing-parameter compatibility,
Blend bypass, alpha preservation and empty input on ordinary/adjustment layers.
A separate scalar flat-plane reflection oracle verifies the actual GPU shader's
lighting with microgeometry disabled, including anisotropic and coating cases.
All controls remain in the generic numeric-control test without new exemptions.
The family is registered for contact sheets and per-effect moving renders.

Local analytic cellular gradients were checked against independent small-step
finite differences: maximum error was `1.61e-10` for pits and `2.78e-9` for cracks
over 1,994 comparisons away from nondifferentiable cell boundaries. Swift syntax
checks pass. Metal compilation, GPU tests and actual moving/UI review remain pending.

Research references (behavior/formulas only; no shader source copied):

- [Physically Based Rendering: roughness and microfacet theory](https://www.pbr-book.org/4ed/Reflection_Models/Roughness_Using_Microfacet_Theory)
- [MaterialX PBR specification](https://github.com/AcademySoftwareFoundation/MaterialX/blob/main/documents/Specification/MaterialX.PBRSpec.md)
