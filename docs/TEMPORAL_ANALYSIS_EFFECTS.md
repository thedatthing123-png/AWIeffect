# Temporal analysis tools: batch 43

Nine effects operate on real upstream frames, not warped duplicates of the current
image. They use the renderer's existing scoped temporal sampler and its cache,
preserving camera, parenting, media decode and effect-stack sampling behavior.
There is no separate studio or new project model.

| Tool | Operation and intended use |
| --- | --- |
| Temporal Variance | Per-channel population standard deviation across a window; maps motion/flicker independently of spatial texture. |
| Change Occupancy | Fraction of adjacent samples exceeding a soft difference threshold; maps frequent changes rather than their single largest magnitude. |
| Change Timing Map | Time of strongest adjacent change, encoded as a color with a strength gate. Useful as an animated color/displacement source. |
| Temporal Acceleration | Absolute second difference from three evenly spaced frames. Separates changing rate from steady first-order change. |
| Temporal Rank | Brightness-ordered whole RGBA samples, with interpolation between neighboring ranks. Not independent channel extrema. |
| Temporal Sigma Clip | Softly reject temporal color outliers relative to mean/stddev, then average retained premultiplied pixels. |
| Temporal Color Trend | Least-squares RGB slope over the window, centered around middle gray for falling/rising channels. |
| Temporal Frequency | Mean-subtracted, Hann-weighted complex response at selected cycles per window. Maps periodic flicker energy. |
| Frame History Grid | Earlier-to-later frames placed left to right, top to bottom, with editable columns and gap. |

Time Window looks backward from current composition time plus Time Offset. A
negative offset moves the window earlier; a positive offset can sample future
frames. Project-time boundary behavior is handled by the existing renderer.
Blend zero and unavailable temporal input return the original input exactly.
All authoring controls use normal keyframing, scrubbing and numeric entry.

## Bounded execution and limitations

- Acceleration always uses exactly three samples and has no inactive sample-count
  slider. Other effects use at most eight frames. Frequency defaults to eight;
  the other variable-count tools default to six.
- Rank sorting is bounded to eight elements per pixel and keeps whole pixels
  together, preserving the coverage/color relationship.
- Frequency is limited to the sampled window's Nyquist bound, `(N-1)/2` cycles.
  Lowering frame count can therefore limit the requested frequency. It is a local
  frequency response, not an automatic musical beat detector or audio analyzer.
- Sigma clipping has a positive noise floor and falls back to the mean if all
  samples are rejected. Sparse sampling can still mix moving subjects; it does
  not perform motion-compensated video denoising.
- Statistics analyze premultiplied rendered colors. Diagnostic outputs retain the
  maximum sampled coverage, including locations previously occupied by a moving
  cutout. Rank, sigma clipping and grid output retain their sampled RGBA values.
- The history-grid shader samples only the frame belonging to its tile and skips
  unnecessary statistics. Upstream frame rendering still has a real cost.
- Processing stays on GPU with no production readback. A capped sample count is
  not proof of 60 fps: real footage and heavy upstream stacks need device profiling.

## Verification

The family is registered with the temporal sampler, Time browser, default/fallback
and bypass tests on ordinary and adjustment layers, numeric-control checks, contact
sheets and moving renders. `TemporalAnalysisTests` additionally feeds known constant
GPU textures through the actual kernel and compares variance, interpolated rank and
second differences with independent scalar formulas. Constant-window tests reject
spurious variance, acceleration and frequency energy.

Local CPU oracle values for `[0, .25, .5, .75, 1, .25]` are standard deviation
`0.33592740` and 70th-percentile rank `0.625`. The centered second difference of
`[.1, .2, .5]` is `0.2`. These math checks and Swift parsing pass locally; the GPU
tests, full rendered review and device performance are still pending.

Texture arrays use consecutive argument-table slots as documented by
[Apple's Metal programming guide](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/WhatsNewiniOS10tvOS10andOSX1012.html).
Every slot is bound, including unused entries beyond the active sample count.
