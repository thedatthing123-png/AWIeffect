# AWIeffect: plan for 600 useful effects

Updated November 3, 2026. **Roadmap plus batch ledger; prototype does not mean validated.**

## Baseline and counting rules

Build 3 had 445 entries; build 7 has a 449-entry baseline after Letter Spacing and three new effects. The original 155 proposals below are a backlog requiring overlap checks, not a claim of 155 completed additions. The target remains 600 useful effects. Reworks, presets and existing-tool exposures are tracked separately from new algorithms.

The current registry names were checked while preparing this list. Existing Glow, Deep Glow, Shine, Motion Tile, Wave Warp, Displacement Map, Halftone, Cross Hatch, Oil Paint, Watercolor, Page Curl and other current entries must not be counted again under new names. Several proposals may overlap an existing effect's deeper controls or a non-effect tool; those require an implementation audit before approval. If a candidate is already fully supported, improve its discoverability and replace its slot with a genuinely missing operation. The final accepted count must come from a deduplicated runtime manifest.

Every entry explains its visible behavior and proposed controls. The controls are specifications to design and validate, not claims of exact compatibility with another product. Shared algorithms and parameter modes should remain one effect when their behavior is substantially the same. Presets do not advance the count.

## Implementation order

1. Build Drawing Progress and its path/stroke foundation. Audit overlaps with Trim Paths and shape operators first.
2. Add geometry, mattes and compositing operations needed by other effects.
3. Implement illustration, optics and distortion in small reviewable batches.
4. Add temporal effects after frame-history and motion-vector handling are reliable.
5. Add genuine two-source transitions after timeline A/B inputs and clip handles are supported.
6. At each batch, validate old projects, preview/export parity, alpha, keyframes, cancellation and memory. Package an app only after the batch's required checks pass.

## A. Drawing, strokes and geometry — 25 proposed additions

These operate on paths or recorded brush data before pixels are rendered. They are not rectangular wipes of a finished image. Existing path operators must be checked for overlap.

1. **Drawing Progress.** Reveal or hide a stroke along its measured length. Controls: Start Trim, End Trim, Offset, Reverse. Preserve brush width, caps and path direction; glow sees only the revealed segment.
2. **Recorded Brush Replay.** Reconstruct newly recorded Art Studio painting in its original order, including pressure and erasing. Controls: progress, playback rate, pause compression. Requires saved stroke events; old flattened PNGs cannot recover this history.
3. **Sequential Stroke Build.** Finish one path before beginning the next. Controls: progress, ordering, inter-stroke delay, length-weighted timing. Compare against Drawing Progress's modes before approving a separate catalog entry.
4. **Stroke Growth from Seeds.** Grow visible segments outward from selected points on a path. Controls: seed positions, growth distance, overlap merging. Multiple seeds can reveal branches simultaneously.
5. **Moving Stroke Window.** Move a finite visible section along a path, like a traveling highlight. Controls: head position, tail length, taper. If Drawing Progress already covers this completely, keep it as a preset instead.
6. **Variable Width Profile.** Shape stroke thickness with an editable curve along its length. Controls: profile, minimum width, pressure blend. Tapers should remain smooth when the path is resampled.
7. **Animated Dash Flow.** Move a configurable dash-and-gap pattern along a stroke. Controls: dash sequence, phase, cap shape, fit-to-length. Dashes follow actual distance rather than vertex spacing.
8. **Brush Stamp Along Path.** Place a chosen image repeatedly along a path. Controls: distance, tangent alignment, scale, seeded variation. Useful for leaves, stitches and decorative borders.
9. **Calligraphic Nib.** Change apparent stroke width according to its direction relative to a tilted nib. Controls: nib angle, aspect ratio, pressure influence. This generates geometry rather than merely rotating a texture.
10. **Brush Bristle Separation.** Split a recorded stroke into fine parallel bristle traces. Controls: bristle count, spread, ink loading, seed. Keep the traces tied to the stroke's local frame.
11. **Stroke Junction Welding.** Join intersecting stroke outlines into clean continuous shapes. Controls: weld distance, corner handling, hole preservation. Avoid dark overlaps and gaps at crossings.
12. **Stroke to Ribbon.** Turn a centerline into a shaded ribbon with independently controlled width and twist. Controls: width profile, twist, edge lighting. It must handle tight bends without exploding geometry.
13. **Path Envelope Deform.** Bend artwork inside two editable boundary curves. Controls: upper/lower guides, mapping resolution, pinning. Unlike point displacement, the guides define the entire deformation region.
14. **Path Attractor.** Pull path vertices toward a target curve with distance-based falloff. Controls: guide, strength, radius, preserve length. Useful for organizing loose lines around a silhouette.
15. **Curvature Smooth.** Remove unwanted bumps while protecting deliberate corners. Controls: smoothing scale, iterations, corner threshold. Operate on curve shape rather than blurring its rendered pixels.
16. **Length-Preserving Path Relax.** Even out kinks while resisting changes in total path length. Controls: relaxation, stiffness, pinned endpoints. Useful for animated ropes and drawn gestures.
17. **Contour Resample.** Redistribute path samples by arc length or curvature. Controls: spacing, curvature density, corner preservation. Primarily a technical operation; expose as a tool if no useful animatable effect remains.
18. **Path Boolean Combine.** Union, intersect, subtract or XOR selected vector contours. Controls: operand layers, operation, tolerance. Check existing shape operations; count once for all boolean modes.
19. **Skeleton Stroke.** Derive centerlines from a filled silhouette. Controls: minimum branch length, smoothing, width recovery. Useful for turning bold artwork into editable line structures.
20. **Contour Correspondence Morph.** Morph between two matched paths. Controls: target, progress, landmark pairs, winding. Resolve point correspondence explicitly rather than crossfading two images.
21. **Shape Medial Inflation.** Expand a silhouette according to its internal thickness, preserving narrow features differently from broad regions. Controls: inflation, thickness weighting, boundary smoothing.
22. **Silhouette Bridge.** Create controllable vector connections between nearby shapes. Controls: gap distance, bridge width, neck curvature. The result is actual connecting geometry.
23. **Path Weave.** Alternate which crossing stroke appears above or below. Controls: weave pattern, crossing clearance, gap softness. Determine crossings from geometry, not an arbitrary screen checkerboard.
24. **Stroke Knot Reveal.** Reveal intersecting paths while preserving the chosen crossing order. Controls: reveal position, crossing order, overlap clearance. Reject as a separate effect if Path Weave plus Drawing Progress fully covers it.
25. **Contour Travel Markers.** Move generated markers along a path at uniform distance or time intervals. Controls: marker shape, spacing, progress, tangent orientation. Preserve stable marker identities while animating.

## B. Compositing, channels and mattes — 25 proposed additions

These require explicit source layers, alpha conventions and coordinate spaces. Several use a reusable signed-distance-field implementation. Matte previews must distinguish the mask from the final image.

26. **Copy Background.** Copy the composited layers below into this layer's region for further processing. Controls: sampling space, bounds, opacity. It is a true scene input, not another duplicate image file.
27. **Difference Matte.** Compare footage with a clean background plate to isolate changed areas. Controls: reference frame/layer, tolerance, softness, despill. Camera alignment and noise strongly affect results.
28. **Clean Plate Builder.** Estimate an unobstructed background from multiple frames. Controls: time range, motion exclusion, statistic, quality. Requires temporal analysis and cancellable baking.
29. **Alpha Distance Field.** Convert transparency into signed distance from the silhouette edge. Controls: distance range, inside/outside display, precision. This is a reusable mask output for downstream effects.
30. **Distance Bands.** Generate evenly spaced bands around a silhouette. Controls: spacing, band width, phase, inside/outside. Unlike a decorative outline preset, bands use real edge distance.
31. **Variable Distance Outline.** Expand or contract a silhouette with width driven by another image. Controls: width map, range, direction, smoothing. Audit against existing Border and Minimax before acceptance.
32. **Matte Hole Fill.** Fill enclosed holes below a chosen size without expanding the external boundary. Controls: hole area, connectivity, feather. Preserve intentionally large openings.
33. **Matte Island Filter.** Remove isolated connected mask regions by area or selected component. Controls: minimum area, largest-only, connectivity. Useful for cleaning speckled keys.
34. **Matte Topology Guard.** Clean a mask while resisting accidental merging of separate regions or closure of important holes. Controls: cleanup radius, topology protection, strength.
35. **Temporal Matte Stabilizer.** Reduce frame-to-frame mask chatter using motion-aligned history. Controls: history, responsiveness, motion rejection. A static blur cannot substitute for temporal stability.
36. **Motion-Aware Edge Fill.** Reconstruct thin missing edges from neighboring frames after motion alignment. Controls: search range, confidence, edge width. Require rejection of unreliable motion.
37. **Foreground Color Recovery.** Estimate foreground colors at translucent keyed edges. Controls: background color/plate, recovery strength, edge region. Separate color recovery from merely shrinking alpha.
38. **Alpha-Aware Decontamination.** Remove background contamination using nearby solid foreground colors. Controls: sample radius, edge width, strength. Audit existing Remove Color Matting and Edge Refine first.
39. **Matte Frequency Split.** Separate broad silhouette structure from fine details such as hair. Controls: separation scale, detail gain, base gain. Recombine without making alpha values invalid.
40. **Channel Route.** Route any input channel into any output channel, including alpha and constants. Controls: source per output, inversion, premultiplication. Existing Channel Mixer overlap requires a gap check.
41. **Channel Math.** Apply selected arithmetic operations between channels from two sources. Controls: channel pair, operation, scale, clamp. One effect covers its arithmetic modes.
42. **Alpha Premultiplication Repair.** Correct mismatched straight/premultiplied input interpretation. Controls: input convention, output convention, edge handling. Expose as a repair utility rather than an artistic look.
43. **Luminance-Preserving Composite.** Blend color from one source while constraining luminance changes. Controls: blend amount, luminance reference, gamut limit. Compare against existing luminosity/color blend modes.
44. **Local Contrast Matte.** Select details by contrast against their local neighborhood. Controls: radius, contrast range, polarity, softness. This differs from selecting absolute brightness.
45. **Texture Similarity Matte.** Select regions resembling a reference texture patch. Controls: reference patch, feature scale, tolerance, cleanup. Preview matching confidence before applying alpha.
46. **Depth Range Matte.** Select a near/far interval from a supplied depth map. Controls: near, far, feather, depth convention. Do not imply ordinary photos contain measured depth automatically.
47. **Normal Direction Matte.** Select surfaces facing a chosen direction from a normal map. Controls: direction, angular range, softness. Useful for selective lighting and material masks.
48. **Object ID Matte.** Select explicit object/material IDs from a supplied ID image. Controls: selected IDs, tolerance, edge treatment. Genuine support requires stable IDs and defined anti-aliasing behavior.
49. **Guided Matte Upscale.** Upscale a low-resolution mask using image edges as guidance. Controls: guidance layer, edge strength, radius. Preserve fine boundaries without simply sharpening the mask.
50. **Occlusion Composite.** Use explicit depth maps to decide which of two layers is in front per pixel. Controls: depth sources, bias, softness. It cannot infer reliable 3D occlusion from Z sorting alone.

## C. Light and optics — 25 proposed additions

Use linear-light processing, explicit highlight thresholds and adequate transparent margins. Existing ray, glow, flare and chromatic effects must be compared at the algorithm level.

51. **Edge-Derived Rays.** Emit rays from detected contours instead of all bright pixels. Controls: edge scale, source point, ray length, falloff. Compare against existing Shine and God Rays.
52. **Diffraction Aperture.** Spread bright points according to an aperture shape's diffraction pattern. Controls: aperture, blade count, rotation, wavelength spread. It must differ from fixed star streaks.
53. **Spectral Prism Dispersion.** Refract multiple wavelength bands through a configurable prism field. Controls: prism angle, dispersion, thickness. More than independent RGB position offsets.
54. **Thin-Film Interference.** Create view/thickness-dependent interference colors on a supplied surface field. Controls: film thickness, index, angle map, roughness. Compare existing Holographic Foil.
55. **Caustic Projector.** Project concentrated light patterns produced by a configurable refractive surface. Controls: surface field, light direction, focus, animation. Avoid relabeling generic noise as caustics.
56. **Light-Field Occlusion Rays.** Attenuate rays using an explicit occluder layer. Controls: source, occluder, sampling quality, softness. Occlusion must change the light path.
57. **Anamorphic Flare Ghosts.** Generate linked lens ghosts and directional flare response from tracked highlights. Controls: lens layout, squeeze, coatings, threshold. Audit existing Lens Flare modes.
58. **Lens Ghost Model.** Place internal reflection images according to a configurable lens element layout. Controls: element positions, reflectance, aperture mask. Combine with entry 57 if the implementations coincide.
59. **Sensor Microlens Bloom.** Model highlight charge spreading with directional sensor behavior. Controls: saturation threshold, spill direction, radius, recovery. Differentiate from existing Glow before counting.
60. **Rolling Shutter Exposure.** Integrate motion at different times for different image rows. Controls: scan duration, direction, shutter angle. Requires time samples, not a static slant warp.
61. **Chromatic Focus Shift.** Blur wavelength bands according to distinct focus distances. Controls: focus map, channel focal offsets, aperture. This is focus-dependent blur rather than RGB Split.
62. **Cat-Eye Bokeh.** Shape out-of-focus highlights differently toward frame edges. Controls: aperture, optical vignetting, depth/focus map. Extend existing Bokeh if it already supports this behavior.
63. **Split Diopter.** Simulate two independently focused image regions with a transition boundary. Controls: regions, focus distances, aperture, seam softness. Requires a depth map for convincing focus behavior.
64. **Tilted Focal Plane.** Compute focus from a tilted plane and supplied depth. Controls: plane angle, distance, aperture. A geometric focal plane differs from a simple Tilt-Shift blur band.
65. **Lens Breathing.** Change image magnification and optical center as focus changes. Controls: focus animation, breathing curve, center shift. Match blur changes only when focus inputs are available.
66. **Anisotropic Surface Reflection.** Shade supplied normals with directionally stretched highlights. Controls: tangent direction, roughness axes, light. Compare existing specular/material effects.
67. **Subsurface Light Spread.** Spread incident light through a thickness map, preserving a sharper surface component. Controls: thickness, scattering color, radius. Do not present a single tinted blur as full subsurface simulation.
68. **Transmission Shadow Color.** Tint projected shadows using a translucent occluder's color and alpha. Controls: light, projection, absorption, softness. Needs explicit receiver and occluder inputs.
69. **Contact Light Spill.** Restrict light spill to the gap between nearby source and receiver silhouettes. Controls: source, receiver, distance falloff. Differentiate from existing Light Wrap.
70. **Polarization Response.** Attenuate highlights according to orientation from supplied reflection/normal data. Controls: filter angle, polarization strength, surface selection. Without those inputs, label the result an approximation.
71. **Spectral Absorption.** Attenuate wavelength bands according to a thickness map. Controls: absorption spectrum/preset, thickness, density. Useful for colored glass and liquids.
72. **Optical Vignetting Map.** Generate aperture-dependent falloff from lens geometry and view position. Controls: aperture, pupil offset, projection. Reject as new if existing Vignette fully covers the intended result.
73. **Depth Fog Integration.** Accumulate colored scattering through supplied depth. Controls: density, height, falloff, light direction. Differentiate from the existing Clouds & Fog generator.
74. **Relight from Normal and Depth.** Apply controllable lights to supplied normal/depth inputs. Controls: light type, position, color, shadow approximation. Ordinary image luminance is not a substitute for real normals.
75. **Environment Reflection Lookup.** Reflect an environment image using surface normals and a view model. Controls: environment, roughness, orientation, Fresnel. Compare existing Glass Material and Chrome Metal.

## D. Distortion and field operations — 25 proposed additions

Use inverse sampling to avoid holes where possible. Controls must define source space, interpolation, edge modes and maximum displacement. Shared mapping modes count as one effect when appropriate.

76. **Vector Field Advection.** Carry pixels through a supplied velocity field for a chosen integration time. Controls: field, strength, steps, boundary mode. Temporal accumulation is optional and explicitly separate.
77. **Curl Field Warp.** Generate swirling displacement from a divergence-free curl field. Controls: scale, strength, seed, evolution. Audit existing Fractal Warp and Liquid Warp first.
78. **Reaction-Diffusion Warp.** Use a baked reaction-diffusion simulation as the displacement field. Controls: feed, kill, diffusion, simulation time. Deterministic playback requires cached simulation states.
79. **Harmonic Cage Warp.** Deform artwork from an enclosing editable cage with smooth interior interpolation. Controls: cage points, influence, quality. Compare existing Puppet Pins.
80. **Rigid Region Deform.** Preserve selected rigid patches while deforming the surrounding image. Controls: pins, rigid regions, stiffness. Requires a constrained solver, not ordinary mesh interpolation.
81. **Content-Aware Retarget.** Resize while protecting important image regions. Controls: target size, protection/removal masks, quality. Bake expensive analysis; avoid promising perfect reconstruction.
82. **Seam Insertion Stretch.** Expand an image through computed low-cost seams rather than uniform scaling. Controls: seam direction, count, energy map. Combine with entry 81 if implemented as its resize mode.
83. **Conformal Region Warp.** Deform a region while minimizing local angle changes. Controls: boundary handles, constraints, solver quality. Useful for bending graphic elements without severe local skew.
84. **Perspective Surface Reproject.** Map a source between calibrated planar camera views. Controls: source/target corners or cameras, crop, filtering. Existing Corner Pin may make this a tool rather than a new effect.
85. **Depth Reprojection.** Reproject an image using supplied depth and a virtual camera movement. Controls: depth scale, camera, hole-fill policy. Newly exposed areas require explicit reconstruction or transparency.
86. **Stereo Disparity Shift.** Produce or adjust a stereo view from a disparity map. Controls: convergence, separation, eye, hole handling. Does not create reliable stereo depth from no input data.
87. **Equirectangular View Extract.** Render a perspective view from a 360-degree image. Controls: yaw, pitch, roll, field of view. Compare current Sphere Map and Skybox behavior.
88. **Projection Converter.** Convert between supported spherical, cylindrical, cubemap and fisheye projections. Controls: input/output projection, orientation, coverage. Count projection modes once.
89. **Lens Calibration Warp.** Apply or undo calibrated radial and tangential distortion coefficients. Controls: calibration coefficients, optical center, inverse mode. Existing Lens Distortion must be audited first.
90. **Mesh UV Distortion.** Sample an image with a supplied UV-coordinate map. Controls: UV source, channel layout, wrap, filtering. Useful for authored surfaces and reusable deformation maps.
91. **Flow Map Painter.** Paint directional vectors that drive local distortion. Controls: field brush, strength, integration, smoothing. Requires an editable vector field asset and a clear bake workflow.
92. **Distance-Gradient Warp.** Move pixels along the gradient of a silhouette distance field. Controls: source matte, displacement, falloff, sign. Creates contour-following deformation rather than radial bulging.
93. **Voronoi Cell Reassemble.** Split an image into stable Voronoi cells and move each cell independently. Controls: seeds, transform field, gaps, seed. Compare existing Shatter and Crystallize.
94. **Topology-Preserving Melt.** Deform a silhouette with constraints that resist tearing or unwanted merging. Controls: gravity, viscosity approximation, anchors, duration. Requires mesh/field constraints and may need baking.
95. **Directional Compression Field.** Compress image regions according to a painted or supplied field. Controls: direction map, compression, protected areas. Compare Stretch Segment and Squeeze.
96. **Elastic Sheet Solver.** Treat the layer as an elastic sheet with pins and forces. Controls: stiffness, damping, force field, pin mask. Audit Physics Studio overlap before assigning an effect slot.
97. **Shock Refraction Field.** Refract the background through a moving, thickness-defined shock front. Controls: front path, width, refractive strength, dispersion. Differentiate from a simple Shockwave Ring generator.
98. **Gradient-Domain Warp Repair.** Blend seams created by a warp using a gradient-domain reconstruction. Controls: repair mask, boundary source, solver quality. This is a compositing repair stage, not another warp shape.
99. **Barycentric Triangle Morph.** Morph matched triangulations between source and target landmarks. Controls: landmark pairs, progress, triangle constraints. Preserve correct texture correspondence across triangles.
100. **Folded Surface Refraction.** Refract an underlying image through a user-defined folded transparent sheet. Controls: crease paths, fold angle, thickness, index. Compare Page Curl and Accordion Fold to avoid duplication.

## E. Illustration and print processes — 20 proposed additions

These should model distinguishable processes. Existing watercolor, oil, sketch, hatch, halftone, risograph and screen-print effects are already present; new entries need a demonstrated behavioral gap.

101. **Anisotropic Kuwahara.** Smooth within locally oriented regions while retaining strong boundaries. Controls: radius, anisotropy, sector weighting. Audit Oil Paint's underlying filter before adding.
102. **Flow-Guided Line Extraction.** Detect and connect lines along a smoothed image orientation field. Controls: flow scale, edge threshold, continuity. Compare current Find Edges and Cartoon Outline.
103. **Coherent Line Hatching.** Lay strokes along the image's local structure rather than fixed screen angles. Controls: density, tone response, flow smoothing. Distinguish from existing Cross Hatch.
104. **Engraving Plate Simulation.** Convert tone into etched grooves with relief and ink retention. Controls: groove profile, spacing, pressure, paper. Compare Woodcut and Halftone Lines.
105. **Lithographic Grain Transfer.** Simulate grease/pigment pickup from a textured plate. Controls: plate texture, ink density, pressure, tone threshold. Compare existing Risograph and Screen Print.
106. **Mezzotint Scrape.** Form lighter areas by removing marks from a dense dark texture. Controls: scrape radius, grain density, tonal response. Preserve the subtractive process rather than applying generic noise.
107. **Drypoint Burr Ink.** Add soft ink accumulation beside etched line grooves. Controls: burr width, ink amount, line source. Differentiate from ordinary blur or Ink Bleed.
108. **Monotype Transfer.** Transfer uneven paint from a plate with pressure and residual pigment. Controls: plate texture, pressure map, lift, residual amount. A second pull should differ predictably if history is enabled.
109. **Gouache Coverage.** Approximate opaque pigment deposition with thickness and edge texture. Controls: coverage, thickness, dry brush, surface. Compare existing Oil Paint and Watercolor.
110. **Granulating Pigment.** Settle pigment into low parts of a paper-height map. Controls: grain size, settling, pigment separation, paper. Differentiate from simply overlaying paper noise.
111. **Wet-Pigment Separation.** Separate multiple pigment components according to different diffusion rates. Controls: pigment palette, wetness, diffusion, duration. Simulation requires deterministic baking.
112. **Backrun Bloom Simulation.** Create watercolor backruns as a wetter region pushes pigment into an edge. Controls: wetness source, timing, diffusion, drying. Compare existing Ink Bleed's behavior.
113. **Scratchboard Removal.** Reveal a light substrate by scraping a dark coating along paths. Controls: scratch paths, width, pressure, substrate. Requires stroke geometry or recorded input.
114. **Sgraffito Layers.** Scratch through stacked color coatings to reveal lower layers. Controls: coating stack, scratch depth, paths, roughness. Differentiate from a single alpha erase.
115. **Needle-Felt Texture Synthesis.** Construct oriented fibers whose packing follows tone and direction. Controls: fiber length, direction field, density, depth shading. Avoid static texture overlays as the entire implementation.
116. **Thread Embroidery.** Fill regions with discrete stitches following a direction field. Controls: stitch length, density, border, thread relief. Count stitch patterns as modes, not separate effects.
117. **Woven Image Reconstruction.** Rebuild an image using interlaced colored warp and weft threads. Controls: weave pattern, yarn width, palette, lighting. Geometry/occlusion must reflect crossings.
118. **Mosaic Grout Solver.** Fit irregular tiles to contours and fill their gaps with grout. Controls: tile size, contour following, grout, material. Compare existing Mosaic Tiles and Crystallize.
119. **Vector Region Simplify.** Convert image regions into simplified editable filled contours. Controls: palette, contour tolerance, small-region merge. This needs vector output support, not merely a flattened preview.
120. **Palette Error-Diffusion Mapper.** Quantize to a user palette while distributing color error spatially. Controls: palette, diffusion method, strength, serpentine scan. Compare existing Retro Dither and Pixel Art modes.

## F. Temporal and motion processing — 20 proposed additions

These genuinely read multiple frames or motion data. Frame caches must have byte budgets. Reverse seeking, random seeking, trimming and export must reproduce the same result. Expensive analysis is cancellable and bakeable.

121. **Motion-Compensated Temporal Denoise.** Align neighboring frames before averaging noise. Controls: history, motion confidence, detail retention. Reject ghosting near occlusions.
122. **Temporal Median Cleanup.** Replace short-lived outliers using the median across a time window. Controls: window, motion compensation, rejection mask. Useful for transient speckles and flashes.
123. **Temporal Percentile Composite.** Select a configurable temporal brightness percentile per pixel. Controls: window, percentile, channel, motion alignment. Median/min/max are modes within this effect.
124. **Motion Vector Display.** Visualize actual estimated or supplied motion vectors. Controls: vector source, scale, color encoding, grid. A useful diagnostic and data output for later effects.
125. **Motion Vector Remap.** Modify motion vectors before a reconstruction stage. Controls: scale, rotation, threshold, region mask. Existing optical-flow interpolation must be checked for overlap.
126. **Motion-Compensated Frame Interpolation.** Synthesize intermediate frames using forward/backward flow and occlusion handling. Controls: interpolation time, quality, confidence. Audit Twixtor/Time Remap first; improve them instead if already supported.
127. **Temporal Slice Scan.** Sample different times along a configurable spatial scan. Controls: time span, scan curve, direction, boundary policy. Different from a single-frame Scan Distort.
128. **Temporal Depth Scan.** Choose sample time using a depth map. Controls: depth/time mapping, range, interpolation. Requires valid depth and temporal source frames.
129. **Temporal Texture Advection.** Move an applied texture along scene motion over time. Controls: texture, flow source, persistence, reinitialization. Resist slipping and handle newly visible surfaces.
130. **Motion-Tracked Paint Accumulation.** Accumulate paint in tracked scene space. Controls: motion source, deposition, decay, confidence. This must follow the object rather than the screen.
131. **Long Exposure Integrator.** Integrate actual frames over a shutter interval. Controls: duration, weighting, exposure normalization, sample count. Compare existing Echo and motion-blur tools.
132. **Selective Motion Freeze.** Freeze regions with little motion while preserving moving areas, or the reverse. Controls: motion threshold, reference time, feather. Motion classification must be temporally stable.
133. **Temporal Background Hold.** Keep a reference background while updating selected moving foreground. Controls: clean plate, motion mask, update rate. Handle camera motion explicitly.
134. **Motion Cadence Converter.** Resample footage into a deliberate exposure cadence with frame holds or blends. Controls: cadence pattern, phase, blending. Compare Posterize Time; count only a real missing cadence feature.
135. **Field Order Repair.** Detect or explicitly correct interlaced field ordering and reconstruct progressive frames. Controls: field order, deinterlace method, motion threshold. Keep original timing correct.
136. **Duplicate Frame Repair.** Detect repeated frames and reconstruct or retime the affected interval. Controls: detection threshold, repair strategy, range. Never silently alter clip duration.
137. **Flash Exposure Equalizer.** Detect short exposure spikes and balance them against nearby frames. Controls: detection, correction strength, protected flashes. Expose detected events for review.
138. **Temporal Color Stabilizer.** Reduce unwanted color-temperature and exposure drift while preserving intended changes. Controls: analysis range, smoothing, reference, exclusion mask. Bake analysis separately from rendering.
139. **Occlusion-Aware Motion Trails.** Accumulate moving subjects while respecting foreground occluders. Controls: trail duration, spacing, depth/matte input, decay. Ordinary Echo without occlusion does not qualify.
140. **Flow-Aligned Motion Texture.** Stretch procedural texture along measured motion paths. Controls: flow, length, density, lifespan. Compare existing Wind Streaks and Light Trails for a genuine gap.

## G. Editorial A/B transitions — 15 proposed additions

These require a transition stage that receives outgoing A and incoming B, handles missing source frames, and integrates with clip duration and easing. A single layer fading out is insufficient. Modes that share one algorithm stay in one effect.

141. **Flow Morph Transition.** Warp matched A/B content toward an intermediate image before blending. Controls: progress, correspondences, flow quality, occlusion. Unrelated shots may require manual landmarks.
142. **Depth Portal Transition.** Move through a masked opening while A/B layers are placed at supplied depths. Controls: portal matte, depth, camera path, edge treatment. It must composite both sources correctly.
143. **Distance-Matte Transition.** Reveal B according to distance from an arbitrary matte boundary. Controls: seed matte, progress, band width, edge shading. Differentiate from simple linear/radial wipes.
144. **Object-Matched Transition.** Align a selected object in A with a selected object in B and transition around it. Controls: landmarks/tracks, alignment, progress, background treatment. This needs correspondence data.
145. **Motion-Continuation Cut.** Match incoming movement to outgoing motion around the cut. Controls: tracked direction, velocity matching, blend interval, crop. Expose correction strength rather than promising automatic perfect cuts.
146. **Luminance-Ordered A/B Reveal.** Reveal B using a brightness ordering derived from A or a supplied map. Controls: map source, threshold progression, feather, preservation. Audit existing Luma Key plus transitions for overlap.
147. **Frequency-Separated Dissolve.** Transition broad structure and fine detail at different rates. Controls: separation scale, phase offset, progress. The decomposition must be real, not two opacity presets.
148. **Gradient-Domain A/B Blend.** Blend images by reconstructing their gradients across a transition boundary. Controls: boundary, progress, solver quality, color anchoring. Requires explicit boundary conditions.
149. **Shared-Edge Peel Transition.** Peel A away along a guide to reveal B beneath it with consistent contact shadow. Controls: guide, curl radius, progress, lighting. Audit Page Curl and use a transition mode if sufficient.
150. **Volume Slice Transition.** Treat A/B and intermediate samples as a time volume, then reveal a moving slice. Controls: slice orientation, thickness, progress, interpolation. Requires defined intermediate data.
151. **Tracked Surface Replacement Transition.** Introduce B on a tracked plane in A and expand to the new shot. Controls: planar track, expansion, perspective, timing. Reuse existing tracking rather than duplicating it.
152. **Particle Correspondence Transition.** Sample A/B into particles with stable matched identities and animate between them. Controls: particle spacing, correspondence, trajectory, progress. Audit existing particle morph capabilities.
153. **Silhouette Interlock Transition.** Grow complementary boundaries from A/B mattes until the new shot fills the frame. Controls: mattes, growth ordering, gap, progress. Require consistent coverage with no unintended transparent cracks.
154. **Seam-Optimized Transition.** Move a low-visibility seam through A/B according to image differences. Controls: progress, seam cost, protected regions, softness. Bake optimization when needed.
155. **Audio-Driven Transition Timing.** Drive an actual chosen A/B transition's progress with a user-approved beat/envelope curve. Controls: analysis source, event selection, easing, manual override. This may belong as a transition timing controller rather than a counted visual effect.

## Drawing Progress: exact first-batch contract

- Provide a visible catalog entry linked to the existing path renderer.
- Corrected against the supplied AM drawing-progress.xml: Start defaults to 0 and End to 100. Build 7 uses the visible interval [Start, End]. Animate End 0 to 100 to draw on; the earlier removed-from-end wording was inaccurate.
- At no trim, show the complete stroke. At complete trim, show no stroke. Define what happens when the trimmed intervals meet or overlap.
- Use arc length for progress; repeated or unevenly spaced input points must not cause changes in drawing speed.
- Preserve open-path caps, closed-path wrapping, stroke joins and per-stroke order.
- Offer explicit filled-shape handling. Partially revealed filled contours can create unwanted closing edges; preview this rather than hide it.
- Store raster brush history for new replayable paintings. For existing flattened drawings, offer an authored reveal path and explain the limitation in the workflow.
- Test multiple paths, holes, reverse progress, negative/pre-roll keyframes, speed changes, undo, save/reopen, effect ordering and export parity.

## Architecture and performance

**Geometry stage:** paths, distance tables, topology and stroke journals; rasterize only after geometry effects. Cache by geometry revision and evaluated parameters.

**Image stage:** Metal passes with declared margins, edge rules, alpha convention and linear/display-light requirements. Avoid allocating a new large texture for every parameter update.

**Multi-input stage:** resolve explicit layer/background/depth/normal/ID inputs. Reject cycles and missing dependencies visibly. Keep composition-space and layer-space sampling consistent.

**Temporal stage:** versioned analysis caches keyed by media, timing, parameters and quality. Bound memory in bytes. Cancellation must stop expensive work and prevent stale results from replacing newer edits.

**Simulation stage:** fixed timesteps, explicit initial conditions, reproducible baking and cache invalidation. Preview and export consume the same simulation results.

**Transition stage:** two source frames, source handles, progress, timeline timing and separate audio crossfade controls. Avoid silently repeating unavailable frames unless that policy is selected.

For every accepted effect, write a short algorithm note and input/output contract before implementation. Distinguish a mobile approximation from a physical simulation. Share kernels where sensible without disguising parameter variations as separate effects.

## Batch gates and completion tracking

Use batches of roughly 8–15 accepted additions, adjusted for complexity. Drawing Progress and stroke history are a foundation task and may need their own batch. Temporal analysis, solvers and A/B transitions should not be promised as equally quick shader work.

Each candidate moves through: **proposed → overlap audit → specification → prototype → validated → accepted**. Only accepted distinct registered IDs advance the count. A rejected duplicate must be replaced with a new researched candidate, not renamed.

Required checks:

- Every visible control has a defined effect and produces a meaningful parameter response.
- Defaults, zero amounts, extreme values and invalid inputs behave predictably.
- Alpha, transparent margins, edge modes and mixed layer sizes are correct.
- Keyframing, trimming, speed changes, seeking and reverse playback work where supported.
- Representative image/video/path fixtures show the intended result; assertions must measure behavior, not merely pipeline existence.
- Preview and export agree within documented precision/quality differences.
- Old projects retain compatible behavior; new fields receive deliberate defaults.
- Memory, long editing sessions, cancellation and background/foreground transitions are checked.
- Simulator capability skips are recorded. Physical iPhone testing remains necessary for performance, touch controls and memory pressure.

## Research sources and limits

- [Alight Motion Drawing Progress](https://support.alightmotion.com/hc/en-us/articles/10537114872337-Drawing-Progress): stroke trimming, fills and contour-order caveats.
- [Adobe path operations and Trim Paths](https://helpx.adobe.com/after-effects/desktop/drawing-painting-and-paths/shapes-and-shape-attributes/shape-attributes-paint-operations-path.html): geometry-stage operations and animated reveal controls.
- [Boris FX Sapphire EdgeRays](https://borisfx.com/documentation/sapphire/ofx/edgerays/): edge-derived ray behavior and controls.
- [Maxon tools locator](https://help.maxon.net/rg/en-us/Content/html/universe-tools-locator.html): effect families and linked per-tool documentation.
- [Premiere transitions](https://helpx.adobe.com/premiere/desktop/add-video-effects/apply-video-transitions/transitions-overview.html): editorial transition model.
- [Historical Blender Grease Pencil Build](https://docs.blender.org/manual/en/3.0/grease_pencil/modifiers/generate/build.html): stroke construction reference; verify current-version details before implementing.
- [Blender Kuwahara reference](https://docs.blender.org/manual/en/4.4/compositing/types/filter/kuwahara.html): research lead; the full manual page could not be fetched during this pass.

These sources inform selected behaviors and architecture. They do not individually specify all 155 proposals. Uncited candidates are original engineering proposals requiring further algorithm-specific research during their specification stage. No proprietary plugin code or assets are included.


# Effects expansion — larger batch and text research

This supplements the original 155-proposal roadmap. Build 7 is the baseline: ordinary Halftone, Lit Ripple, Time Slice Mask and Draw Progress are not being remade again. Prototypes below are not accepted until the final batch validates.

## Current image batch

| Entry | How it works | Main controls |
|---|---|---|
| Alpha Distance Field (#29) | Jump flooding finds the nearest alpha boundary; grayscale encodes signed distance, including holes | Range, Bias |
| Distance Bands (#30) | Draw contour bands at measured distances from the alpha silhouette | Range, spacing, width, phase, color, side |
| Distance-Gradient Warp (#92) | Move sampling along the silhouette distance gradient with edge falloff | Range, displacement |
| Matte Frequency Split (#39) | Gaussian alpha base plus independent high-frequency residual, recombined with valid premultiplication | Radius, base gain, detail gain |
| Local Contrast Matte (#44) | Select brightness differences relative to a local Gaussian average | Radius, threshold, softness, polarity, mix |
| Height to Normal Map | Encode luminance-height derivatives as RGB normals; the existing Normal Map Lighting instead bakes illumination | Strength, derivative radius, green convention |
| Lens Calibration Warp (#89) | Brown–Conrady radial and tangential distortion with bounded iterative inversion | K1/K2, P1/P2, optical center, inverse, mix |
| Spectral Prism Dispersion (#53) | Seven wavelength bands sampled along a prism axis; neutral reconstruction at zero separation | Separation, axis, spectral curve, mix |

Distance fields use approximate jump flooding plus an extra unit-step refinement. Two RG32Float buffers are reused, not a new buffer per step. The working grid is capped at 2048 on its longest side, bounding those buffers to 64 MiB combined. Sub-grid features can be lost at very large resolutions. Spectral Prism is an artistic seven-band approximation, not a physical optical solver.

## Older effect remakes

- **CMYK Halftone:** retain the current ID and Legacy mode. Add AM-style plate-center sampling, Amount, Strength, Black Weight and staggered Phase. Four plate angles follow the bundled reference. Existing Dot Size/Angle/Mix remain available in Legacy mode.
- **Halftone Lines:** retain the current ID and Legacy mode. Add line-center sampling, Amount, Strength and Phase. Existing line-spacing/contrast/color behavior remains in Legacy mode.
- New mode selection must initialize missing settings from defaults when switching an older effect. Irrelevant controls are hidden. These are two remakes, not two new counted effects.

## Text section missing from the original plan

These reuse Core Text layout, cached glyphs, Text Studio selectors/animators, keyframes and the common preview/export renderer. They do not append saved animators or alter source text. Based On selects character/word/line units; it does not change the glyph-centered transform pivot.

| ID | Effect and behavior | Controls | Current status / overlap |
|---|---|---|---|
| T01 | Text Transform: transform a selected unit range | Start/End, units, X/Y, rotation, scale, opacity | Prototype; uses existing selector engine |
| T02 | Text Progress: reveal without reflowing the remaining layout | Start/End, units, reverse | Prototype; exposes existing opacity-selector capability |
| T03 | Text Wave: travelling sinusoidal glyph displacement and rotation | X/Y amplitude, rotation, frequency, units per wave, phase, units | Prototype; builds on existing wave math |
| T04 | Text Jitter: coherent per-unit noise, deterministic on seeking | X/Y, rotation, frequency, seed, units | Prototype; shares existing Wiggle |
| T05 | Text Arc: bend each line onto a circular arc while retaining advance length | Bend, orient letters | Prototype; new layout operation |
| T06 | Text Color Ramp: color interpolation through unit order | Colors, repeats, phase, mix, units | Prototype; direct ordered color mapping |
| T07 | Character Offset: shift Latin letters and digits, preserve other scripts | Start/End, units, offset | Prototype; existing animator capability exposed directly |
| T08 | Text Line Spacing: multiply existing baseline spacing | Spacing | Prototype; existing layout control exposed, not new algorithm |
| T09 | Text Outline: animate hollow glyph width; zero is solid | Width | Prototype; existing glyph-outline renderer exposed, not new algorithm |
| T10 | Word Spacing: measure real space clusters instead of tracking every glyph | Space advance, anchor, tabs | Proposed |
| T11 | Paragraph Reflow: wrap within a shaped text frame | Box width, wrapping, overflow | Proposed; needs Core Text paragraph support |
| T12 | Intra-Glyph Gradient: vary color inside each letter | Gradient stops, axis, coordinate space | Proposed; differs from per-letter color spans |
| T13 | Font Contour Draw: reveal glyph outlines by contour length | Start/End, contour order, fill policy | Proposed; needs font contours, not a rectangular wipe |
| T14 | Fit Text to Box: shaping-aware font size solver | Width/height, size limits, overflow | Proposed; layout utility |
| T15 | Typewriter Caret: actual caret at reveal boundary | Caret style, blink, progress | Proposed extension of T02, not another reveal effect |
| T16 | Text Repeater | Copies, transform, phase | Audit generic repeater first; don't count duplicates |
| T17 | Text Follow Path | Offset, orientation, alignment | Already in Text Studio; discoverability improvement |
| T18 | Text Counter | Formatting, separators, units | Already present; optional catalog exposure |
| T19 | Variable Font Axes | Font-defined weight, width, optical size | Proposed; axis discovery and layout-cache changes needed |
| T20 | Paragraph Justification | Target width, gap limits, final-line policy | Proposed; preserve shaping, bidi and combining marks |
| T21 | Per-Word Pivot | Group anchor and word transforms | Proposed T01 extension; selection units aren't pivots |
| T22 | Per-Glyph 3D | X/Y rotation, depth, selector | Existing animators; extend T01 without inventing another 3D renderer |

Nine text catalog entries and eight image entries are prototyped. Several text entries expose existing functionality and are not claimed as nine new animation algorithms. Reworks and presets do not advance the 600-unique-capability target. The original backlog still needs overlap audits and infrastructure-heavy temporal/simulation work; this batch does not complete it.

## Batch validation

Use the existing table-driven registry, effect visibility, control-response, disabled-identity and extreme-setting tests for the entire catalog in one full run. Mode-dependent controls are tested in their relevant mode. Text uses multiline fixtures; alpha-detail operations use alpha-shape fixtures. Grouped batch checks cover zero-operation identity, alpha, distance sign/holes, normal-map output, source-text preservation, seeking, old project modes/defaults and save/reopen. Export actual Metal previews plus the runtime manifest. Physical iPhone checks remain necessary.

## Primary references

- [Adobe animating text](https://helpx.adobe.com/after-effects/desktop/animating-text/text-animation/animating-text.html)
- [Adobe text animation examples](https://helpx.adobe.com/after-effects/desktop/animating-text/text-animation-examples/examples-resources-text-animation.html)
- [AM Text Transform](https://guide.alightmotion.com/effects/text-transform)
- [AM Text Progress](https://support.alightmotion.com/hc/en-us/articles/10537154109841-Text-Progress)
- [AM Halftone Lines](https://guide.alightmotion.com/effects/halftone-lines)
- The user's bundled `halftonecmyk.xml` and `halftonelines.xml`, compared with the existing Swift/Metal implementations.
- [Rong/Tan jump flooding paper](https://www.comp.nus.edu.sg/~tants/jfa/i3d06-submitted.pdf)
- [OpenCV calibration equations](https://docs.opencv.org/4.12.0/dc/dbb/tutorial_py_calibration.html)
- [Blender bump/height-to-normal reference](https://docs.blender.org/manual/en/latest/render/shader_nodes/displacement/bump.html)
