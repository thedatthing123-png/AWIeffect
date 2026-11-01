# AI Cutout / Rotoscoping and Puppet-Pin Deformation for an iOS (Metal + Vision/Core ML) Editor

Note: Adobe helpx pages returned HTTP 403 to the fetcher; Adobe facts below come from search-result summaries of those pages and from third-party tutorials (FilmDaft, AEJuice, No Film School). Re-verify exact defaults against Adobe Help.

## 1. AE Roto Brush 3 / Refine Edge workflow and mobile auto-cutout UX (CapCut, Alight Motion, Runway)

### Takeaway
AE's model is: paint foreground strokes (Alt = subtract) on a base frame, propagate forward/back, correct with more strokes on any frame (each correction becomes a new key that re-propagates), Freeze to cache, then refine with matte controls (Feather, Contrast, Shift Edge, Reduce Chatter, Motion Blur, Decontaminate). Mobile apps (CapCut) collapse this into a one-tap "Auto Cutout" plus a fix-up review; this is the gap to beat: one-tap auto plus AE-style correction strokes and refine sliders.

### Cited Findings
- Next-Gen Roto Brush is selected by setting Version = 3.0 in the "Roto Brush & Refine Edge" effect; after propagation, Freeze caches segmentation data, and pressing Freeze again unfreezes — [Adobe Help (search summary)](https://helpx.adobe.com/ca/after-effects/desktop/roto-brush-and-refine-matte/roto-brush/roto-brush-refine-matte.html)
- Refine Edge tool is a brush for fine detail such as hair; you must unfreeze before using it — [Adobe Learn: Roto Brush refine edges](https://www.adobe.com/learn/after-effects/web/roto-brush-refine-edges)
- Propagation settings: Search Radius (area searched for matching pixels between adjacent frames; start ~50+ for heavy motion), View Search Region, Invert Foreground/Background, Enable Classic Controls — [FilmDaft Roto Brush Part 2](https://filmdaft.com/roto-brush-tutorial-part-2-after-effects-advanced/)
- Roto Brush matte: Feather (boundary softness), Contrast (tightens boundary), Shift Edge (+ expands / - contracts), Reduce Chatter (reduces erratic edge noise; can cost finger/hair precision) — [FilmDaft](https://filmdaft.com/roto-brush-tutorial-part-2-after-effects-advanced/)
- Refine Edge matte: Smoothness (low for hair), Feather, Contrast, Shift Edge, Chatter Reduction (Off / More Detailed / Smoother (Slower)) — [FilmDaft](https://filmdaft.com/roto-brush-tutorial-part-2-after-effects-advanced/)
- Motion Blur: Samples Per Frame default 8, Shutter Angle default 180, Higher Quality toggle — [FilmDaft](https://filmdaft.com/roto-brush-tutorial-part-2-after-effects-advanced/)
- Decontaminate Edge Colors: Amount, Extend Where Smoothed, Increase Radius, View Map; removes background color spill/halos from edge pixels — [FilmDaft](https://filmdaft.com/roto-brush-tutorial-part-2-after-effects-advanced/)
- A user reports flicker-free results with Reduce Chatter 100% and Chatter Reduction = Smoother, but says Freeze is slow — [Adobe Community: Rotobrush 3 beta](https://community.adobe.com/t5/after-effects-beta-discussions/rotobrush-3-now-available-in-the-after-effects-beta/td-p/13984477)
- CapCut flow: select clip -> Cutout -> Remove Background / Auto Cutout (one tap, processes whole clip) — [Miracamp CapCut guide](https://www.miracamp.com/learn/capcut/how-to-remove-background); [Primal Video](https://primalvideo.com/video-creation/editing/capcut-video-editing-ai-features)
- CapCut's own guidance says manual review is needed around hair, hands, contact points, motion blur and same-color clothing — [CapCut](https://www.capcut.com/create/capcut-background-removal-player-cutout-reels)

### Inferences
- Spec UX: (a) Auto: one tap -> Vision instance mask on current frame, tap an instance to pick it; (b) Brush: green add / red subtract (toggle button, since no Alt key), brush size via two-finger pinch or slider; (c) "Propagate" runs forward/backward from each key frame with a progress bar in the timeline, keyed frames shown as diamonds; (d) Freeze = bake masks to a cached mask track; (e) Refine panel with exactly AE's names (Feather, Contrast, Shift Edge, Reduce Chatter, Decontaminate, Motion Blur) so AE-trained editors map instantly.
- Store strokes, not just pixels, so propagation can be rerun after model upgrades.

### Gaps
- No independent review of Alight Motion's or Runway's cutout found; Runway Green Screen UX not researched here. Exact AE defaults for Feather/Contrast/Shift Edge not confirmed (Adobe pages blocked).

## 2. Apple Vision frameworks: subject lifting, person segmentation, instance masks

### Takeaway
Use VNGenerateForegroundInstanceMaskRequest (iOS 17+, class-agnostic, instance-labeled, tap to pick) for "any subject" stills and keyframes, and VNGeneratePersonSegmentationRequest (.balanced for video, .accurate for export) / VNGeneratePersonInstanceMaskRequest for people. VisionKit is out-of-process and size-limited, so call Vision directly in an editing pipeline.

### Cited Findings
- WWDC23 10176 "Lift subjects from images in your app": subject = foreground object(s), not only people/pets; Vision API is class agnostic; instance 0 = background, foreground instances labeled from 1; iOS 17 / macOS 14 — [WWDC Notes 10176](https://wwdcnotes.com/notes/wwdc23/10176)
- VisionKit ImageAnalysisInteraction with `.imageSubject`; async subject lookup at a point returns nil if none; `subject.image` / `interaction.image(for:)` — [WWDC Notes](https://wwdcnotes.com/notes/wwdc23/10176)
- VisionKit runs out-of-process (perf benefit) but image size is limited; Vision is better for advanced editing and higher-res inputs — [WWDC Notes](https://wwdcnotes.com/notes/wwdc23/10176)
- Per-point instance lookup on the observation (instanceAtPoint-style; 0 = background) — [Axiom Vision skill summary](https://playbooks.com/skills/charleswiltgen/axiom/axiom-vision-ref) (third-party)
- Saliency maps are low-res and not suitable for segmentation — [WWDC Notes](https://wwdcnotes.com/notes/wwdc23/10176)
- PersonSegmentation quality levels: accurate (0, default), balanced (1), fast (2); fast is for streaming on Neural Engine devices — [Apple docs](https://developer.apple.com/documentation/vision/vngeneratepersonsegmentationrequest/qualitylevel-swift.enum.md); [objc2-vision header](https://docs.rs/objc2-vision/latest/src/objc2_vision/generated/VNGeneratePersonSegmentationRequest.rs.html)
- Kodeco recommends balanced for video frames, fast for streaming, accurate when time isn't constrained; accurate uses much more memory/time — [Kodeco](https://www.kodeco.com/29650263-person-segmentation-in-the-vision-framework?page=2)

### Inferences
- Pipeline: preview at .balanced (or ForegroundInstance at reduced res), export at .accurate. Upscale low-res Vision masks with a guided filter using the full-res frame (section 3) before compositing.
- Tap-to-pick: map tap to normalized mask coords, read instance label from `instanceMask` pixel buffer, then `generateMaskedImage/generateScaledMask(forInstances:)`. Store chosen instance index plus tap point; on later frames re-pick the instance whose mask overlaps the warped previous mask most (labels are not stable across frames).

### Gaps
- No measured ms/frame numbers per device found for ForegroundInstanceMask vs PersonSegmentation; benchmark in-app. VNGeneratePersonInstanceMaskRequest (iOS 17, up to 4 people per Apple's WWDC23 session, from memory, unverified here) details not fetched.

## 3. Flicker-free video segmentation; mobile models and Core ML feasibility

### Takeaway
Per-frame Vision masks flicker; fix with (1) a temporal model (RVM's recurrent state, SAM2-family memory), or (2) post-processing: warp previous mask by optical flow (VNGenerateOpticalFlowRequest), blend with current via confidence-weighted EMA, then guided-filter to the frame's edges. On-device SAM2-class trackers (EdgeTAM ~16 FPS, EfficientTAM ~10 FPS on iPhone 15 Pro Max) make click-to-track propagation feasible.

### Cited Findings
- RVM: recurrent architecture (ConvGRU in decoder), trimap- and background-free, 4K 76 FPS / HD 104 FPS on GTX 1080Ti; trained on matting + segmentation for robustness — [RVM paper arXiv 2108.11515](https://arxiv.org/pdf/2108.11515); [WACV PDF](https://openaccess.thecvf.com/content/WACV2022/papers/Lin_Robust_High-Resolution_Video_Matting_With_Temporal_Guidance_WACV_2022_paper.pdf)
- RVM paper: MODNet handles video only via neighbour-frame post-processing to reduce flicker and struggles with fast-moving body parts — [WACV PDF](https://openaccess.thecvf.com/content/WACV2022/papers/Lin_Robust_High-Resolution_Video_Matting_With_Temporal_Guidance_WACV_2022_paper.pdf)
- RVM official repo ships Core ML MobileNetV3 models at fixed 1280x720 and 1920x1080, fp16/int8 (no dynamic resolution); GPL-3.0 license — [awesome.ecosyste.ms RVM listing](https://awesome.ecosyste.ms/projects/github.com%2FPeterL1n%2FRobustVideoMatting); real-time iOS camera RVM via Core ML — [Giphy Engineering](https://engineering.giphy.com/?p=909)
- MobileSAM Core ML (ViT-Tiny encoder + light decoder), iOS 17+, ~19 MB, with SamKit sample — [HF MobileSAM-CoreML](https://huggingface.co/mlboydaisuke/MobileSAM-CoreML)
- Apple publishes Core ML SAM 2.1 (Large) for its SAM2 Studio demo — [HF apple/coreml-sam2.1-large](https://huggingface.co/apple/coreml-sam2.1-large)
- MatAnyone Core ML: 5-model memory-propagation pipeline; load models one at a time to avoid iPhone OOM — [HF MatAnyone-CoreML](https://huggingface.co/mlboydaisuke/MatAnyone-CoreML)
- EdgeTAM: 16 FPS on iPhone 15 Pro Max vs SAM 2 ~0.7-1 FPS; memory attention identified as SAM 2's mobile bottleneck — [EdgeTAM HF](https://huggingface.co/facebook/EdgeTAM); [Qualcomm AI Hub](https://aihub.qualcomm.com/models/edgetam)
- EfficientTAM: ~10 FPS VOS on iPhone 15 Pro Max using vanilla ViT-Tiny/Small; independent FMOX benchmark found it fastest but least accurate of SAM2 trackers on fast motion — [sotaverified EfficientTAM](https://sotaverified.org/papers/efficient-track-anything); [Moonlight FMOX review](https://www.themoonlight.io/fr/review/benchmarking-sam2-based-trackers-on-fmox)
- VNGenerateOpticalFlowRequest (iOS 14+) exposes computationAccuracy levels and revisions — [Apple docs](https://developer.apple.com/documentation/vision/vngenerateopticalflowrequest.md)

### Inferences
- Recommended tiers: Tier A (all devices): Vision mask per frame + flow-warped previous mask + EMA (alpha ~0.6 current where flow-consistency high, lower where low) + guided filter (r~8, eps~1e-4 on 0..1) in Metal. Tier B (A17+/M-series): EdgeTAM Core ML for tap-to-track any object with memory of user key frames. Hair/fine detail: RVM (people) — but GPL-3.0 is a blocker for a closed-source App Store app; MODNet (Apache-2.0, check) or retrain.
- Guided filter / joint bilateral are standard (He et al. 2010 guided filter); implement as box filters in Metal compute (MPSImageBox) — cheap at 1080p.
- Load one large model at a time (MatAnyone note) — keep a model manager that unloads.

### Gaps
- EfficientSAM Core ML conversion not found. EdgeTAM Core ML conversion not confirmed (MLX and Qualcomm builds found). Guided-filter citation not fetched. Licenses for MODNet/EdgeTAM not verified.

## 4. Refine brush implementation: per-frame edits, propagation, morphology, hair matting

### Takeaway
Model the cutout as: base auto-mask per frame + sparse user stroke keys (add/subtract vector strokes with radius/hardness) + global refine params. Corrections become prompts (for SAM-style trackers: positive/negative points + mask) and propagate until the next key; refine ops run as a Metal post chain.

### Cited Findings
- AE treats corrections on any frame as new strokes that propagate from that frame; Shift Edge +/-, Feather, Contrast, Smoothness, Reduce Chatter as post controls — [FilmDaft](https://filmdaft.com/roto-brush-tutorial-part-2-after-effects-advanced/)
- Refine Edge brush used specifically along hair to compute soft alpha in a band — [Adobe Learn](https://www.adobe.com/learn/after-effects/web/roto-brush-refine-edges)
- Decontamination removes background color from edge pixels — [FilmDaft](https://filmdaft.com/roto-brush-tutorial-part-2-after-effects-advanced/)

### Inferences (implementation notes)
- Data: `MaskTrack { keys: [frame: [Stroke{points, radius, mode:add/sub/refine}]], cache: [frame: R8/R16 texture, compressed], params }`. Cache to disk as 8-bit PNG/HEIF per frame; invalidate range [prevKey, nextKey] when a key changes.
- Propagating edits without a tracker: warp stroke-delta mask (edited minus auto) by optical flow to neighbors with decaying weight (e.g. 0.85^n) until next key or flow confidence drops; with tracker, feed edited mask as new memory frame.
- Refine chain (Metal): Shift Edge = morphology (MPSImageAreaMax/Min, or distance field threshold for subpixel shift); Smooth = Gaussian then re-threshold; Feather = Gaussian on alpha; Contrast = levels/smoothstep around 0.5; Reduce Chatter = temporal median/EMA of alpha; Refine band = guided filter (or a matting net) only inside a tri-band (dilate-erode of the mask) painted by Refine brush; Decontaminate = estimate F = (I - (1-a)B)/a with B from blurred outside pixels, clamp.
- Show overlay modes: red onion, alpha (B/W), on checkerboard, on black/white — as in AE.

### Gaps
- No source on how AE internally propagates edits; decay weights above are design choices, not sourced.

## 5. AE Puppet tool and ARAP algorithm; Alight Motion equivalent; pin UX

### Takeaway
AE Puppet (Advanced engine since AE 2019) has Position, Starch, Bend, Advanced, Overlap pins; mesh from layer alpha with Triangles and Expansion; pins are keyframed (Puppet Position) and can be "sketched" in record mode. Underlying math: Igarashi 2005 two-step closed-form ARAP — fast enough for real-time on a few hundred triangles.

### Cited Findings
- AE 2019 Advanced Puppet Engine added Position, Bend, and Advanced pins alongside Starch and Overlap — [No Film School](https://nofilmschool.com/2018/10/adobe-after-effects-2019-has-new-puppet-tools-and-they-are-badass)
- Bend pin: rotates/scales like Advanced pin but cannot change position; rotates relative to other position pins; Advanced pin rotates around its own center — [No Film School](https://nofilmschool.com/2018/10/adobe-after-effects-2019-has-new-puppet-tools-and-they-are-badass)
- Starch pins stiffen areas; Overlap pins set which parts draw in front when parts overlap — [Kelley AE Puppet tutorial](https://tutorials.nmdprojects.net/ae_puppet/script/kelley_aepuppet.html); [Evergreen AE week 2](https://archives.evergreen.edu/webpages/curricular/2012-2013/trajectories/wq_animation/after-effects-week-2/index.html)
- Triangles controls mesh density/sensitivity; Expansion grows the mesh past the alpha edge so edges aren't left behind; these are mesh options (Show Mesh to see) — [AEJuice](https://aejuice.com/blog/how-to-increase-the-control-area-of-a-rig-in-adobe-after-effects/); [Adobe Community](https://community.adobe.com/questions-529/puppet-tool-help-new-starch-69220)
- Users report starch alone can't stop unwanted bending in Advanced engine; recommended jointed rigs instead — [Adobe Community](https://community.adobe.com/questions-529/puppet-tool-help-new-starch-69220)
- Pins can be keyframed or expression-driven; over-constraining with many pins loses natural deformation — [Adobe Help (search summary)](https://helpx.adobe.com/fi/after-effects/desktop/animate-in-after-effects/animate-with-puppet-tools/animating-puppet-tools.html)
- Igarashi, Moscovich, Hughes, SIGGRAPH 2005: point handles on a triangle mesh; two-step closed form — step 1 finds per-triangle rotation (allowing scale), step 2 stitches/adjusts scale; both linear, real time — [Project page](https://www-ui.is.s.u-tokyo.ac.jp/~takeo/research/rigid); [Paper PDF](https://www-ui.is.s.u-tokyo.ac.jp/~takeo/papers/rigid.pdf); [Course slides 2018](https://www-ui.is.s.u-tokyo.ac.jp/~takeo/course/2018/ui/graphics.pdf)
- Implementation walkthrough of ARAP with linear matrix solve — [Igarashi JGT 2009](https://www-ui.is.s.u-tokyo.ac.jp/~takeo/papers/takeo_jgt09_arapFlattening.pdf)
- Commercial analog: Tangenten Puppet Pin for Resolve Fusion builds a mesh from image/mask and warps it via pins — [Digital Production](https://digitalproduction.com/2026/05/18/tangenten-puppet-pin-brings-mesh-warping-to-resolve/)

### Inferences (implementation notes)
- Mesh: trace alpha contour (marching squares), simplify (Douglas-Peucker), offset by Expansion px, constrained Delaunay triangulate with max-area from Triangles count (AE default ~350 — from memory, verify). Render as textured triangles in Metal with original UVs.
- Solver: precompute factorization of the step-1 and step-2 normal matrices when the pin set changes (sparse Cholesky via Accelerate `SparseFactor`); per frame only back-substitute — sub-ms for ~500 verts. Starch = higher weight on rigidity in those triangles (or extra soft constraints keeping local frame); Advanced/Bend pins = handle with rotation/scale target (constrain a small vertex ring, rotate around pin). Overlap = per-pin depth value painted into nearby triangles' z, render with depth test.
- Keyframing: each pin = keyframed position (+ rotation/scale for Advanced/Bend) using the app's existing easing; "Record" mode: hold record button, drag pin, samples captured at playback rate in real time then simplified to keys (AE-style Ctrl-sketch equivalent).
- Touch UX to avoid accidental pins: separate modes — "Add pins" (tap empty mesh adds) vs "Animate" (default; taps only select/drag existing pins, hit radius ~44pt); dragging always moves never adds; long-press on mesh in Animate mode offers "Add pin here"; undo for each add; pins drawn large with type icon/color; mesh preview toggle.
- Re-use cutout mask alpha as mesh source, so Cutout -> Puppet is one flow (anime character cutout then wiggle).

### Gaps
- Alight Motion: no documentation found confirming a puppet pin tool (only an unanswered Habr question) — [Habr Q&A](https://qna.habr.com/q/926087). Adobe's Legacy vs Advanced engine algorithm is not publicly documented; Igarashi ARAP is the presumed basis for Legacy, unconfirmed. Exact AE defaults (Triangles, Expansion, Starch amount) not verified because Adobe Help was blocked.
