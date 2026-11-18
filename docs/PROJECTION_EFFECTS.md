# Spherical projection tools: batch 42

Twelve tools add spherical camera extraction and environment-format processing.
These are actual coordinate conversions, not fisheye look presets or generated
rotating solids. They use the owner's source image at their stack position.

| Tool | Input | Output |
| --- | --- | --- |
| Panorama View | Equirectangular sphere | Rectilinear camera view |
| Panorama Reorient | Equirectangular sphere | Rotated equirectangular sphere |
| Cube Atlas | Equirectangular sphere | 3x2 cube-face atlas |
| Cube to Panorama | 3x2 cube-face atlas | Equirectangular sphere |
| Octahedral Map | Equirectangular sphere | Folded octahedral square |
| Octahedral to Panorama | Octahedral square | Equirectangular sphere |
| Dual Fisheye Map | Equirectangular sphere | Side-by-side equidistant 180-degree discs |
| Dual Fisheye to Panorama | Side-by-side equidistant 180-degree discs | Equirectangular sphere |
| Cylindrical Panorama | Equirectangular sphere | Cylindrical view |
| Panini Panorama | Equirectangular sphere | Cylindrical stereographic view |
| Mercator Panorama | Equirectangular sphere | Log-latitude cylindrical view |
| Equal-Area Panorama | Equirectangular sphere | Cylindrical equal-area view |

Yaw, pitch and roll act on the actual 3D lookup ray. Camera projections expose
horizontal field of view; fixed-layout conversions do not add an inactive FOV
slider. Sampling is one bilinear lookup or four stratified subpixel lookups.
Each tool has Blend and preserves premultiplied input/empty pixels. No project
settings, layout panels, transport controls or AI Link settings are changed.

## Conventions and accuracy

- Cube order, left to right: **+X, -X, +Y / -Y, +Z, -Z**. A 3:2 image has square
  faces; normalized atlas coordinates also work when that layout is stretched.
- Octahedral mapping uses +Z at the center and folds the rear hemisphere through
  the four corners. The equator forms the central diamond.
- Dual-fisheye discs are front (+Z), then rear (-Z); they use equidistant angular
  radius. This is a defined image convention, not an automatic calibrated-camera
  stitcher. It does not infer real lens distortion or overlap from footage.
- Sphere sampling wraps longitude explicitly and clamps latitude. Cube/fisheye
  reads keep bilinear footprints within their own face/tile to avoid neighboring
  face colors bleeding across atlas borders.
- Equal-area latitude outside its valid domain becomes transparent; at 180-degree
  default coverage this is reduced on ordinary landscape images. Very wide
  fields and portrait aspect ratios can still expose the domain boundary.
- Formats do not resize a layer or its composition. Use an appropriate layer
  aspect ratio when exporting an atlas for another application.
- Conversion is lossy at finite resolution, particularly near poles, octahedral
  folds and fisheye rims. Four samples reduce pixel aliasing, not all minification.
  Full seamless cubemap/corner filtering and mipmapped anisotropic sampling are
  not claimed.

## Design and verification

Reference behavior was researched from Paul Bourke's projection descriptions,
Blender's panoramic-camera documentation, and Cigolle et al.'s octahedral-vector
survey. No third-party shader source was copied:

- [Mapping spherical and perspective images into a fisheye](https://paulbourke.net/dome/2fish/)
- [Blender panoramic cameras](https://docs.blender.org/manual/en/latest/render/cycles/object_settings/cameras.html)
- [A Survey of Efficient Representations for Independent Unit Vectors](https://jcgt.org/published/0003/02/01/paper-lowres.pdf)

An independent CPU reference sheet was visually inspected for angular layout,
face orientation and projection defaults. It prompted reducing the equal-area
default coverage from 300 to 180 degrees. A CPU Panini motion preview was also
generated. These are mathematical references, **not Metal render verification**.

`ProjectionEffectTests` generates real analytic directional-color/grid images in
each required source format. Tests cover default visibility on layers and
adjustments, old-instance parameter fallbacks, exact blend bypass, zero/full-turn
reorientation, and agreement of all three decoded formats with the independent
analytic spherical environment. The family is included in generic control checks,
contact sheets and moving previews. The combined release must still compile and
render on Metal, be visually reviewed, and be profiled on the phone.
