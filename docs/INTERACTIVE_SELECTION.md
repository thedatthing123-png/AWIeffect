# Brush-guided selection

Art Studio Quick Select / smart selection brush and Remove BG Smart Edges now share a
promptable on-device segmentation session. Auto Subject / Auto Remove Background still
use the existing automatic path. Plain painting remains available without inference.

The model sees the source image and stroke positions, rather than stopping at each
color change. Inferred masks are combined with explicit brush coverage. Internal ink
is not treated as a transparent hole. A second Add/Cut gesture can correct the result.
Inference runs away from the UI thread, reuses one embedding for an unchanged source,
and applies results only if the selection/frame/layer has not changed. A completed
cutout stroke is one undo step. Closing or cancelling does not apply a late result.

## Model and attribution

Pretrained MobileSAM; no new model training is claimed. Runtime SAMKit is pinned to
`a4f7866c0b009628ece6c0c3e72a86ece0405463`.
Core ML packages and matching prompt weights are pinned to
`mlboydaisuke/MobileSAM-CoreML@1a87f0e568226d4bb3f32c0b9d5cdda48408e4c4`.
Packages are compiled by Xcode and bundled for offline use; no user images leave the device.
Apache 2.0 license notices ship in Resources.

- https://github.com/ChaoningZhang/MobileSAM
- https://github.com/john-rocky/SamKit
- https://huggingface.co/mlboydaisuke/MobileSAM-CoreML
- Adobe interaction reference: https://helpx.adobe.com/after-effects/desktop/roto-brush-and-refine-matte/roto-brush/roto-brush-refine-matte.html

## Verification

InteractiveSelectionTests runs the actual bundled encoder and decoder on an inked,
shaded object, a detailed public-domain manga print, and the existing anime preview.
It saves source/mask pairs in the selection-evaluation CI artifact for visual review.
Unit checks cover stroke sampling, hard painted coverage, subtraction and orientation.
These fixtures are evaluation data, not training data or proof of perfect generalization.
Core ML inference must be checked on Apple's runtime; Windows cannot execute it.

For future fine-tuning, collect image + desired alpha + positive/negative stroke pairs,
split by original artwork to avoid train/test leakage, and compare boundary error,
missed ink, background leaks, latency and peak memory against this pretrained baseline.
