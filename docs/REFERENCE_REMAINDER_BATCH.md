# Reference remainder batch

This batch adds 51 public candidates: the 17 previously internal review candidates plus 34 further reference effects. The resulting browser count is 533 (452 recovery + 3 initial references + 76 curated references + 2 original transitions). They are integrated, not release-approved, until the full native batch and visual review succeed.

All 547 available fragment programs remain in the internal audit, including 34 private legacy dependencies. Compilation and the previous full native shader audit passed on the prior source checkpoint; this batch must validate the new public controls, changed defaults and two small shader adapters.

## Inclusion decisions

The complete reference graphs, typed parameters, image resources and dependency stages are reused. No duplicate entry is added for blend operations, pass-only blurs, internal borders, existing AWI operators or the generic aeMotion_native/aeMotion_s template variants. A source title alone does not establish a distinct implemented capability. Examples inspected: Polytrace Sampler is a contour-tint template; Free Palette Color is a two-color spatial gradient template; the native Hexagon Tile Shift template quantizes cells instead of implementing the full hex-cell shift shader. The original hexshift.xml and hexrotate.xml are used instead.

Additional concrete exclusions: 3adbg.xml duplicates the 3D city shader, for a purpose already covered by City Skyline; Quality Enhancer combines three named controls into one sharpening gain; Luma Stamper is a luminance tint rather than geometric stamping. Material-only sphere variations do not become new effects.

## Boundaries

The 47 native/host-stage definitions remain separately tracked in REFERENCE_NATIVE_WORKFLOWS.md; they cannot be supplied by registering fragment functions. Image LUT also needs an intentional image/reference routing workflow, and the source audio-spectrum shader takes a synthetic audio_level rather than a live soundtrack. Neither is mislabeled as a complete new working feature. Existing CC Studio LUT and audio-reactive tools remain available. A claim of exact feature parity for every excluded reference has not been made.

## Integration repairs

- Near-empty utility/transition review fixtures are configured explicitly; neutral defaults stay legitimate.
- Aperture Split endpoints are normalized instead of hardcoded for 1920x1080, with canvas-compatible point bounds.
- Fractal Displace Fade fades alpha rather than flattening over black; its unused Time Scale knob is not exposed.
- Grass compositing, small 3D forms and trail visibility receive intentional initial settings for the new review.
- Global numeric assertions retain their 0.05 response threshold and try selector/toggle modes for inactive reference controls. No failing effect is exempted.
- The full audit writes default/configured stills, eight-frame motion GIFs, review settings and numeric-control reports for all 76 candidates.

## New in this batch

| Effect | Source | Intended operation |
|---|---|---|
| Dual Wave Warp | `s_warp_waves2.xml` | Combine two independent wave fields, each with its own wave and displacement directions, phase and speed. Choose transparent, tiled or reflected edges. |
| Line Boil | `hand_drawn.xml` | Animated hand-drawn jitter with an independently controlled outline and redraw frame rate. |
| Streak Strips | `streakstrips.xml` | Stretch the source through alternating angled strips. Animate Phase to move the strip pattern. |
| Fractal Blur | `warpblur.xml` | Blur along a fractal displacement field with radial, angular, X, Y and XY sampling directions, evolving noise, bias and octave control. |
| Opening Book | `mystery_book.xml` | A raymarched opening book with the source image mapped onto its pages. Animate Opening; adjust camera zoom and rotation. |
| Monitor Scene | `monitor_on_table.xml` | Map the source onto a monitor in a raymarched table scene, with camera zoom and orbit. |
| Color Transfer | `colormatch.xml` | Match the source color distribution to a selected reference layer, with adjustable strength and sampling region. |
| Hot Color | `colorhot.xml` | Map luminance through two hue-controlled tonal colors, with saturation, gamma, cutoff and bias controls. |
| Precision Glitch | `glitch_pro.xml` | Combine individually adjustable scanline tears, block corruption, static and color-band interference with controlled trigger timing. |
| Fractal Glitch | `skexnxxhardglitch.xml` | Displace channels through a fractal block field, with threshold selection, blockiness, narrowing and independent channel colors. |
| Holomatrix | `holomatrix2.xml` | An editable holographic signal stack: low resolution, scan lines, line drift, channel separation, static, flicker, distortion and threshold glow. |
| 2D Grass | `skexnxxinstantgrass.xml` | Wind-driven procedural grass blades with editable density, growth, stretch and colors, using the complete inherited shader stage. |
| Plexus Faces | `skexnxxplexustriangle.xml` | An evolving triangular plexus field with separate motion, rotation and color controls. |
| Glow Fibers | `skexnxxfibersglow.xml` | Flowing luminous strands with editable evolution, color and gradient mapping. |
| Hex Lens | `skexnxxhexagonlens.xml` | A raymarched hexagonal lens field with orientation, reflection highlights and flare controls. |
| Contour Strips | `contourstrips.xml` | Build strips from a smoothed source contour field, with independently adjustable strip appearance. |
| Grunge | `grunge.xml` | Extract and composite a textured surface treatment from a smoothed source, with color and contrast control. |
| Hexagon Tile Shift | `hexshift.xml` | Displace individual hexagonal cells with seeded offsets, stretch, screen-space placement and optional layer masking. |
| Hexagon Tile Rotate | `hexrotate.xml` | Rotate individual hexagonal cells with seeded variation, independent grid placement and editable cell proportions. |
| Raster Extrude | `s3d-extrude.xml` | Raymarch the source into a textured relief volume with depth, orientation, interior color, lighting and material shading. |
| Cross 3D | `s3d-plus.xml` | Map the source onto a three-axis cross with editable arm proportions, orientation, texture placement and lighting. |
| Star Polyhedron | `s3d-starpoly.xml` | A textured, lit star polyhedron with editable point count, point length, height and orientation. |
| Hexagonal Prism | `s3d-hexprism.xml` | Wrap the source around a raymarched hexagonal prism with editable dimensions, lighting and texture coordinates. |
| Triangular Prism | `s3d-triprism2.xml` | Wrap the source around a lit triangular prism with independent orientation, depth and texture transforms. |
| 360 Reorient | `360-reorient-sphere.xml` | Rotate an equirectangular panorama in three axes while keeping an equirectangular output. |
| 360 Viewport | `vr-player.xml` | Look into an equirectangular panorama with editable orientation, view scale and aspect ratio. |
| Beam Field | `skexnxxlightsaber.xml` | Generate a field of luminous line segments with editable count, spread, evolution and colors. |
| Wing Lines | `skexnxxwingsline.xml` | Generate curved, intersecting feather-like light lines with editable travel, placement, stretch and compositing. |
| Wire Mesh | `skexnxxfencingwire.xml` | A patterned wire field with editable scale, rotation, placement, brightness and compositing. |
| Dot Spinner | `skexnxxdotsloader.xml` | Generate a rotating sequence of luminous dots with editable count, dot shape and falloff. |
| Color Grid | `skexnxxnewcolorgrid.xml` | Animate a procedural grid field with editable evolution, color mapping, placement and compositing. |
| Cosine Flow | `cosuv.xml` | Generate flowing cosine filaments with independent horizontal and vertical frequencies, animation speed and opacity. |
| Arrow Tunnel | `3polygontun.xml` | Travel through a twisting polygon-arrow tunnel with separate arrow geometry, prewarp, grid phase and tonal controls. |
| Polar Displacement Map | `displacemap-radial.xml` | Use a reference layer to displace source pixels in angular and radial directions around an editable center. |
| Relief Glass | `omino-glass.xml` | Build a smoothed height surface and refract the source through it with chromatic dispersion, roughness, tint and lighting. |
| Fractal Displace Fade | `fbm_time_displace_fade.xml` | Animate Travel through a cyclical fractal displacement and fading matte. This displaces pixels, not source video time. |
| Dissolve Shake | `newdisshake.xml` | Combine an animated dissolve with independent random and wave motion for translation, zoom, tilt and color separation. |
| Pixel Wipe | `s_wipepixelate.xml` | Reveal or remove the source through an angled, pixelated boundary with editable cell frequency, chunkiness and edge width. |
| Plasma Wipe | `3wipeplasma.xml` | A flowing plasma-shaped wipe boundary with editable completion, softness, frequency, seed and fill color. |
| Textured Burn | `burning_texture_fade2.xml` | Remove the source through a noisy heated edge with adjustable feather, heat intensity and an optional moving background texture. |
| Rising Trails | `organic_particles_up.xml` | Generate rising organic particles with independent size, speed, trailing motion, tint and intensity. |
| Aperture Split | `eye_split_bend.xml` | Open a two-ended, curved aperture with editable endpoints, bend, upper and lower shape, tip sharpness and inside inversion. |
| Spot Exposure | `spot_exposure.xml` | Adjust exposure inside a movable circular region with independent radius, boost and falloff. |
| Fractal Contours | `skexnxxisolinev2.xml` | Generate evolving nested fractal contours with editable scale, stretch, color mapping and compositing. |
| Star Trails | `skexnxxnewtrails.xml` | Generate accumulating stellar trails with independent sample count, evolution, star shape and color controls. |
| Brush Sketch | `skexnxxbrushsketch.xml` | Reconstruct source detail through an editable brush-like field with placement, evolution and compositing controls. |
| 3D Particle Field | `skexnxxparticle3d.xml` | Generate particles through a projected depth field with editable motion, distribution, scale and colors. |
| Chromatic Vortex Blur | `chromatic-vortexblur.xml` | Accumulate rotational blur with independent color-channel sampling and an editable vortex center. |
| Flame Border | `firey_border.xml` | Generate an animated flame frame with independent border width, flame detail, tint and source distortion. |
| Four-Stop Gradient Map | `skexnxxmultigradmap.xml` | Remap source luminance through four editable colors with a movable tonal range, brightness and compositing controls. |
| Derivative Noise | `warped_noise_field.xml` | Warp a simplex noise field by its spatial derivatives, with editable sampling interval, warp distance, travel, scale and color. |

Orientation repair: the seven camera/raymarch scene shaders use paired Y-up screen/layer coordinates and CV sampling inversion, matching the reference wrapper contract. Other programs retain their established coordinates. Exact mixed-axis angle parity and projected-image orientation still require the native visual audit; host checks alone do not prove them. The source rays_edge_detect helper is excluded because it generates a bright-edge matte, not rays.
