# Gradient-domain tools: batch 45

Four image operators share a bounded float32 spectral Poisson solver. They add
global reconstruction from gradients; they are not renamed derivative filters.

| Tool | Operation |
| --- | --- |
| Normal to Height | Decode front-facing tangent-space RGB normals, convert to slopes, and integrate a relative height field. Minimum Normal Z protects grazing samples. |
| Gradient Integrate | Integrate centered RG vectors into a relative height. Inconsistent/nonintegrable vectors are projected to a least-squares scalar potential. |
| Gradient Reshape | Nonlinearly compress/amplify RGB gradient magnitudes, then reconstruct color with the sampled input mean restored. |
| Periodic Texture | Remove a smooth boundary-discontinuity component to reduce RGB tile seams. Vertical Priority weights vertical boundary corrections. |

The height tools output middle gray at zero mean. Height Range is in authored
layer-pixel units; scale zero gives neutral gray and negative scale inverts the
height. Absolute surface elevation cannot be recovered from slopes alone. The
normal tool expects RGB encoded around 0.5 and a positive normal Z. The gradient
tool interprets RG around 0.5 as signed horizontal/vertical differences, with a
forward-edge discrete convention. External centered-gradient normal maps are
therefore approximate inputs, not a guarantee of bit-exact inverse conversion.

Gradient Reshape's exponent 1 leaves gradients unchanged. Values below 1 boost
weak differences relative to the pivot and reduce stronger differences; values
above 1 reverse that relationship. Gain is bounded to prevent runaway amplification.
The sampled RGB mean fixes the reconstruction's otherwise unknown constant.

Periodic Texture uses weighted periodic-plus-smooth decomposition. It reduces
opposite-edge discontinuities without requiring identical border pixels. It can
change broad color variation as part of that correction. It does not synthesize
new texture. Alpha is retained, so it does not make mismatched alpha borders tile.

All four tools retain source alpha and premultiplication, including partial/empty
coverage. Blend zero bypasses the solver exactly. They use the existing effect
cards, numeric scrubbing, keyframes and sections; no extra studio is introduced.

## Solver and resource bounds

1. Resample the logical input extent into a power-of-two grid capped at 128, 256
   (default), or 512 on either side. A small source may be enlarged to the next
   power of two; large inputs are downsampled. Preserve authored-pixel slope units.
2. Build backward divergence of forward gradients, or the boundary discrepancy.
3. Bit-reverse both axes and run radix-2 FFT butterflies using four reused complex
   scratch planes. Divide by the discrete Laplacian's Fourier eigenvalues.
4. Fix the DC component to zero, inverse-transform, normalize once, and reconstruct
   the requested image. Gradient Reshape uses a separate bounded mean-reduction
   pyramid. The Laplacian denominator uses squared sines to avoid cancellation.

Arithmetic and scratch textures are float32. Source plus four complex planes use
at most 20 MiB at 512x512, plus at most about 1.34 MiB for mean reduction. Input,
output, pool spares and other in-flight frames are additional. The default solve
uses about one quarter of that scratch memory. No production CPU readback occurs.
Repeated butterfly passes remain real work; a bounded grid does not establish
60 fps. The final device performance pass remains required.

Fourier reconstruction assumes periodic boundaries. Sharp source discontinuities,
very thin details, resolution caps, clipping to the available output range and
nonintegrable slopes can affect results. Solver Resolution changes approximation
detail. Use Height Range/Scale to expose the useful height range. Invalid allocation
or blend bypass leaves the original input intact.

## Design and verification

Independent CPU reference images were inspected. Initial diagnostic-field defaults
clipped broad height regions; Normal to Height's range was increased to 400 px,
Gradient Integrate's to 120 px, and the reshaping exponent was softened to 0.8.
These are mathematical references, **not verified Metal renders**.

`PoissonEffectTests` checks:

- Known periodic heights reconstructed from quantized RG gradients and RGB normals.
- Positive, negative and zero scale, including sign and normalization.
- Periodic decomposition against direct 2D DFT sums on a rectangular image; this
  oracle does not use the shader's FFT, bit reversal or ping-pong schedule.
- Linear gradient reconstruction, partial alpha, empty images, defaults, missing
  saved parameters and exact blend bypass on ordinary/adjustment layers.

Local CPU checks passed: float32 butterfly FFT maximum error `3.82e-6` against
NumPy, roundtrip error `2.05e-7`, quantized-gradient height error `0.00110`.
On the 16x8 ramp fixture, edge jumps of 1 reduced to 0.0625 horizontally and 0.125
vertically. Vertical Priority visibly changes coupled 2D content. Swift syntax
checks pass. Metal compilation, GPU tests, rendered moving review and device
profiling remain pending. The family is registered for all release artifacts and
generic numeric-control checks with no new exemptions.

Research references (mathematics/behavior only; no third-party implementation copied):

- Moisan, [Periodic plus Smooth Image Decomposition](https://helios2.mi.parisdescartes.fr/~moisan/papers/2009-11r.pdf).
- Fattal, Lischinski and Werman, [Gradient Domain High Dynamic Range Compression](https://www.cs.jhu.edu/~misha/Fall07/Papers/Fattal02.pdf).
  Gradient Reshape is a simpler image-space reconstruction operator; it does not
  claim that paper's complete multiscale HDR algorithm.
