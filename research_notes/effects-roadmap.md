# Restarted effects roadmap

Baseline: delivered build 7 (`ca879d0`), 449 catalog entries. The abandoned 17-entry prototype batch is excluded. Target: 600 useful effects; 125+ additions remain a development objective, not a count to fill with duplicates.

Standing rule: inspect the model, UI, implementation and tests in the owning system before each change. Text Studio animation/transforms/progress/3D remain in Text Studio. Reworks preserve saved IDs and compatibility.

## Audit of the original 155 proposals

These decisions are a first ownership/overlap pass. `needs_review` and `overlap_review` are unresolved, not approved additions. `candidate_gap` still requires algorithm research and validation. No new effect has been accepted by this document.

| # | Proposal | Decision | Existing owner / reason |
|---|---|---|---|
| 1 | Drawing Progress | delivered | Paths / Art Studio: Build 7 Draw Progress; no new slot. |
| 2 | Recorded Brush Replay | owner_extension | Paths / Art Studio: Art Studio needs saved stroke events; DrawingDoc currently saves raster layers. |
| 3 | Sequential Stroke Build | owner_extension | Paths / Art Studio: Review Art Studio multi-stroke ordering and path ownership; not a second basic progress effect. |
| 4 | Stroke Growth from Seeds | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 5 | Moving Stroke Window | covered | Paths / Art Studio: Existing ShapeStroke trimStart/trimEnd/trimOffset animate a moving window. |
| 6 | Variable Width Profile | owner_extension | Paths / Art Studio: Compare raster pressure/taper with vector width profiles; extend stroke model where missing. |
| 7 | Animated Dash Flow | owner_extension | Paths / Art Studio: Dash sequences belong in shape stroke geometry; check trims and caps. |
| 8 | Brush Stamp Along Path | owner_extension | Paths / Art Studio: Review brush stamps and path tools before approving a separate effect. |
| 9 | Calligraphic Nib | owner_extension | Paths / Art Studio: Flat Chisel already exists; inspect nib orientation/pressure gap. |
| 10 | Brush Bristle Separation | owner_extension | Paths / Art Studio: Art Studio brush model, not a renamed paint filter. |
| 11 | Stroke Junction Welding | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 12 | Stroke to Ribbon | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 13 | Path Envelope Deform | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 14 | Path Attractor | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 15 | Curvature Smooth | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 16 | Length-Preserving Path Relax | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 17 | Contour Resample | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 18 | Path Boolean Combine | owner_extension | Paths / Art Studio: Vector geometry/boolean tooling; compare mask add/subtract/intersect first. |
| 19 | Skeleton Stroke | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 20 | Contour Correspondence Morph | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 21 | Shape Medial Inflation | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 22 | Silhouette Bridge | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 23 | Path Weave | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 24 | Stroke Knot Reveal | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 25 | Contour Travel Markers | needs_review | Paths / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 26 | Copy Background | existing_workflow | Compositor / mattes: Adjustment and Displacement Map Layers Below already process scene content. Prove any missing copy input before adding. |
| 27 | Difference Matte | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 28 | Clean Plate Builder | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 29 | Alpha Distance Field | candidate_gap | Compositor / mattes: No signed-distance data output found in inspected alpha/choke/outline controls; needs measured-distance implementation. |
| 30 | Distance Bands | candidate_gap | Compositor / mattes: Existing luma contours are not alpha-distance contour bands; reuse the distance foundation. |
| 31 | Variable Distance Outline | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 32 | Matte Hole Fill | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 33 | Matte Island Filter | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 34 | Matte Topology Guard | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 35 | Temporal Matte Stabilizer | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 36 | Motion-Aware Edge Fill | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 37 | Foreground Color Recovery | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 38 | Alpha-Aware Decontamination | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 39 | Matte Frequency Split | candidate_gap | Compositor / mattes: Independent alpha base/detail recombination is not provided by current alpha levels/choke/feather. |
| 40 | Channel Route | extend_existing | Compositor / mattes: RGB Channel Mixer exists; extend alpha/constants routing only if absent. |
| 41 | Channel Math | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 42 | Alpha Premultiplication Repair | repair_infrastructure | Compositor / mattes: Integrate alpha interpretation with import/compositor; do not expose unsafe redundant conversion blindly. |
| 43 | Luminance-Preserving Composite | existing_workflow | Compositor / mattes: Compare Color/Luminosity blend modes; do not count their existing behavior again. |
| 44 | Local Contrast Matte | candidate_gap | Compositor / mattes: Current absolute color/luma selection does not expose neighborhood-relative contrast selection. |
| 45 | Texture Similarity Matte | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 46 | Depth Range Matte | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 47 | Normal Direction Matte | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 48 | Object ID Matte | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 49 | Guided Matte Upscale | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 50 | Occlusion Composite | needs_review | Compositor / mattes: Compare implementation and controls with existing owner before accepting. |
| 51 | Edge-Derived Rays | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 52 | Diffraction Aperture | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 53 | Spectral Prism Dispersion | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 54 | Thin-Film Interference | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 55 | Caustic Projector | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 56 | Light-Field Occlusion Rays | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 57 | Anamorphic Flare Ghosts | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 58 | Lens Ghost Model | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 59 | Sensor Microlens Bloom | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 60 | Rolling Shutter Exposure | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 61 | Chromatic Focus Shift | extend_existing | Optics / materials: Channel Blur/Lens Blur already exist; depth-dependent focal offsets are the gap, not channel blur itself. |
| 62 | Cat-Eye Bokeh | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 63 | Split Diopter | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 64 | Tilted Focal Plane | extend_existing | Optics / materials: Compare existing Tilt Shift and Lens Blur before adding another focus effect. |
| 65 | Lens Breathing | owner_extension | Optics / materials: Camera focus/zoom behavior belongs in camera/lens controls. |
| 66 | Anisotropic Surface Reflection | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 67 | Subsurface Light Spread | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 68 | Transmission Shadow Color | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 69 | Contact Light Spill | remake_review | Optics / materials: Light Wrap exists. Review actual background sampling rather than adding another name. |
| 70 | Polarization Response | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 71 | Spectral Absorption | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 72 | Optical Vignetting Map | extend_existing | Optics / materials: Vignette exists; data-map output/model variants should be modes where appropriate. |
| 73 | Depth Fog Integration | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 74 | Relight from Normal and Depth | owner_extension | Optics / materials: Normal Map Lighting and 3D lights exist; inspect normal/depth input support first. |
| 75 | Environment Reflection Lookup | needs_review | Optics / materials: Compare implementation and controls with existing owner before accepting. |
| 76 | Vector Field Advection | needs_review | Warp / scene / physics: Compare implementation and controls with existing owner before accepting. |
| 77 | Curl Field Warp | needs_review | Warp / scene / physics: Compare implementation and controls with existing owner before accepting. |
| 78 | Reaction-Diffusion Warp | needs_review | Warp / scene / physics: Compare implementation and controls with existing owner before accepting. |
| 79 | Harmonic Cage Warp | owner_extension | Warp / scene / physics: Inspect Puppet Pins and path handles before adding a cage solver. |
| 80 | Rigid Region Deform | owner_extension | Warp / scene / physics: ARAP-style rigid regions must improve Puppet/rig deformation, not duplicate pin UI. |
| 81 | Content-Aware Retarget | needs_review | Warp / scene / physics: Compare implementation and controls with existing owner before accepting. |
| 82 | Seam Insertion Stretch | merge_proposal | Warp / scene / physics: Merge with #81 content-aware resizing if one seam-carving engine handles insertion/removal. |
| 83 | Conformal Region Warp | needs_review | Warp / scene / physics: Compare implementation and controls with existing owner before accepting. |
| 84 | Perspective Surface Reproject | existing_workflow | Warp / scene / physics: Compare Corner Pin/homography source-target mapping; do not rename an equivalent mapping. |
| 85 | Depth Reprojection | needs_review | Warp / scene / physics: Compare implementation and controls with existing owner before accepting. |
| 86 | Stereo Disparity Shift | needs_review | Warp / scene / physics: Compare implementation and controls with existing owner before accepting. |
| 87 | Equirectangular View Extract | overlap_review | Warp / scene / physics: Inspect existing Sphere Map/Skybox projection math and camera controls. |
| 88 | Projection Converter | overlap_review | Warp / scene / physics: Audit projection modes as one family, not a new entry for each conversion. |
| 89 | Lens Calibration Warp | extend_existing | Warp / scene / physics: Lens Distortion already has K1/K2, chromatic fringe, zoom and center. Tangential terms/inversion should extend it. |
| 90 | Mesh UV Distortion | extend_existing | Warp / scene / physics: Displacement Map already reads RG; distinguish absolute UV remap from relative displacement before approval. |
| 91 | Flow Map Painter | owner_extension | Warp / scene / physics: Painted vector assets belong in Art Studio and feed displacement; requires vector-field storage. |
| 92 | Distance-Gradient Warp | candidate_gap | Warp / scene / physics: Self-silhouette distance-gradient displacement is absent from current reference-image Displacement Map. |
| 93 | Voronoi Cell Reassemble | extend_existing | Warp / scene / physics: Voronoi Shatter/Crystallize already exist; inspect cell transform controls before adding. |
| 94 | Topology-Preserving Melt | owner_extension | Warp / scene / physics: Plastic soft materials already exist; topology constraints belong in Physics Studio. |
| 95 | Directional Compression Field | overlap_review | Warp / scene / physics: Compare Stretch Segment, Squeeze and RG Displacement Map before accepting. |
| 96 | Elastic Sheet Solver | owner_extension | Warp / scene / physics: Elastic simulation/pins belong in Physics Studio; no noise-warp substitute. |
| 97 | Shock Refraction Field | overlap_review | Warp / scene / physics: Compare Ripple/Shockwave plus backdrop displacement and proposed distance bands. |
| 98 | Gradient-Domain Warp Repair | needs_review | Warp / scene / physics: Compare implementation and controls with existing owner before accepting. |
| 99 | Barycentric Triangle Morph | needs_review | Warp / scene / physics: Compare implementation and controls with existing owner before accepting. |
| 100 | Folded Surface Refraction | extend_existing | Warp / scene / physics: Compare Page Curl/Accordion Fold; transparent refraction is a material extension. |
| 101 | Anisotropic Kuwahara | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 102 | Flow-Guided Line Extraction | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 103 | Coherent Line Hatching | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 104 | Engraving Plate Simulation | overlap_review | Illustration / Art Studio: Compare Woodcut, line screens and emboss before approving physical plate behavior. |
| 105 | Lithographic Grain Transfer | overlap_review | Illustration / Art Studio: Risograph/Screen Print already exist; establish a pressure/plate transfer gap. |
| 106 | Mezzotint Scrape | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 107 | Drypoint Burr Ink | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 108 | Monotype Transfer | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 109 | Gouache Coverage | overlap_review | Illustration / Art Studio: Oil Paint and Watercolor already exist; deposition must differ algorithmically. |
| 110 | Granulating Pigment | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 111 | Wet-Pigment Separation | owner_extension | Illustration / Art Studio: Pigment diffusion requires Art Studio simulation state and reproducible baking. |
| 112 | Backrun Bloom Simulation | owner_extension | Illustration / Art Studio: Actual wet backruns require simulation; current Ink Bleed is not proof of that capability. |
| 113 | Scratchboard Removal | existing_workflow | Illustration / Art Studio: Authored scratches/eraser/layers already reveal a substrate; identify missing material behavior first. |
| 114 | Sgraffito Layers | owner_extension | Illustration / Art Studio: Multi-coating scratch depth belongs with Art Studio layers/erasing. |
| 115 | Needle-Felt Texture Synthesis | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 116 | Thread Embroidery | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 117 | Woven Image Reconstruction | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 118 | Mosaic Grout Solver | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 119 | Vector Region Simplify | owner_extension | Illustration / Art Studio: Editable vector output requires path assets and simplification tooling. |
| 120 | Palette Error-Diffusion Mapper | needs_review | Illustration / Art Studio: Compare implementation and controls with existing owner before accepting. |
| 121 | Motion-Compensated Temporal Denoise | needs_review | Time / media: Compare implementation and controls with existing owner before accepting. |
| 122 | Temporal Median Cleanup | merge_proposal | Time / media: Median is percentile 50; merge with #123 instead of counting twice. |
| 123 | Temporal Percentile Composite | needs_review | Time / media: Compare implementation and controls with existing owner before accepting. |
| 124 | Motion Vector Display | owner_extension | Time / media: Existing optical-flow pipeline needs a diagnostic/data-output mode, not a second estimator. |
| 125 | Motion Vector Remap | extend_existing | Time / media: Integrate signed motion-vector mapping with existing Displacement Map/reference inputs. |
| 126 | Motion-Compensated Frame Interpolation | covered | Time / media: SlowMotion.swift already invokes optical-flow interpolation; do not add another Twixtor wrapper. |
| 127 | Temporal Slice Scan | needs_review | Time / media: Compare implementation and controls with existing owner before accepting. |
| 128 | Temporal Depth Scan | needs_review | Time / media: Compare implementation and controls with existing owner before accepting. |
| 129 | Temporal Texture Advection | needs_review | Time / media: Compare implementation and controls with existing owner before accepting. |
| 130 | Motion-Tracked Paint Accumulation | owner_extension | Time / media: Tracking plus recorded paint accumulation must extend tracking/Art Studio state. |
| 131 | Long Exposure Integrator | extend_existing | Time / media: Echo/time sampling exists; extend integration/averaging where genuinely absent. |
| 132 | Selective Motion Freeze | existing_workflow | Time / media: Freeze plus masks/layer compositing exists; any automatic motion selection is a workflow extension. |
| 133 | Temporal Background Hold | needs_review | Time / media: Compare implementation and controls with existing owner before accepting. |
| 134 | Motion Cadence Converter | owner_extension | Time / media: Cadence conversion belongs in media/timeline/export, not a visual filter name. |
| 135 | Field Order Repair | owner_extension | Time / media: Interlaced repair belongs in media decoding/repair. |
| 136 | Duplicate Frame Repair | owner_extension | Time / media: Analyze duplicate frames and reuse interpolation; not an extra generic blur. |
| 137 | Flash Exposure Equalizer | owner_extension | Time / media: Brightness analysis should drive existing Exposure keyframes. |
| 138 | Temporal Color Stabilizer | owner_extension | Time / media: Temporal color analysis should drive CC Studio rather than duplicate grading. |
| 139 | Occlusion-Aware Motion Trails | extend_existing | Time / media: Echo already exists; occlusion-aware flow is an advanced time mode. |
| 140 | Flow-Aligned Motion Texture | needs_review | Time / media: Compare implementation and controls with existing owner before accepting. |
| 141 | Flow Morph Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 142 | Depth Portal Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 143 | Distance-Matte Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 144 | Object-Matched Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 145 | Motion-Continuation Cut | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 146 | Luminance-Ordered A/B Reveal | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 147 | Frequency-Separated Dissolve | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 148 | Gradient-Domain A/B Blend | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 149 | Shared-Edge Peel Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 150 | Volume Slice Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 151 | Tracked Surface Replacement Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 152 | Particle Correspondence Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 153 | Silhouette Interlock Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 154 | Seam-Optimized Transition | needs_review | A/B / timeline: Compare implementation and controls with existing owner before accepting. |
| 155 | Audio-Driven Transition Timing | owner_extension | A/B / timeline: Audio/beat timing should drive real transition progress; not a separate visual effect. |

## Text extras

Do not add Text Transform, Text Progress, Wave, Jitter, Character Offset, Outline, Line Spacing, Counter or 3D wrappers when Text Studio already supports them. Typography layout, variable font axes, group pivots and additional 3D controls belong in a later Text Studio expansion.

One genuine extra to investigate is font-contour reveal: tracing actual glyph outlines by measured contour length. Existing letter-opacity progression and outline width do not do that. It must reuse font shaping/Core Text contours and the path renderer, with holes, multiple contours, correct glyph placement and preview/export parity. No rectangular-wipe or opacity-selector substitute.

## Remake scope

Protect the freshly delivered Halftone, Lit Ripple, Time Slice Mask and Draw Progress. CMYK Halftone and Halftone Lines remain older candidates because their plate/line sampling and controls differ from the references. Other remakes require a specific demonstrated defect or missing behavior; names or age alone are not enough.

## Integration and validation

One batch-wide run can cover registry integrity, all-effect visibility, every-control responses, disabled identity, extremes and regression behavior. Add grouped assertions for real semantics, old projects, alpha, reference inputs, timing and source-data preservation. Inspect actual rendered previews. Runtime manifests count catalog entries; do not misrepresent wrappers, presets or remakes as new capabilities.

Source evidence and full proposal specifications are in `effect-overlap-audit.json`; the owner map is `existing-capability-map.md`.
