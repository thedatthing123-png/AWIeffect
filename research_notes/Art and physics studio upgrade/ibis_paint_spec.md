# ibis Paint X: Feature Spec for Rebuilding a Drawing Studio (2025-2026)

Primary source: the official ibisPaint online manual, index at https://ibispaint.com/lecture/index.jsp (202 chapters). Each chapter is at `https://ibispaint.com/lecture/index.jsp?no=NN`. Version notes come from App Store and APK mirror listings.

## Canvas UI layout, tool list and gestures

### Takeaway
The app has a bottom main toolbar of 9 buttons, an upper-right strip of 6 buttons, and a Tool Select window with 15 tools. Two-finger tap is undo and three-finger tap is redo. Two fingers pan, pinch-zoom and rotate the canvas.

### Cited Findings
- Tool Select window, in order: Transform, Magic Wand, Lasso, Filter, Brush, Eraser, Smudge, Blur, Special Pen, Bucket, Vector, Text, Frame Divider, Eyedropper, Canvas. In Popup position the window can show 1, 2 or 3 columns. — [Toolbar & Tool Selection](https://ibispaint.com/lecture/index.jsp?no=04)
- Main toolbar, left to right: Brush/Eraser toggle, Tool Selector, Properties, Color, Fullscreen, Undo, Redo, Layer, Back. — [same](https://ibispaint.com/lecture/index.jsp?no=04)
- Upper-right buttons: View menu, Selection Area, Stabilizer, Shape, Ruler, Material. — [same](https://ibispaint.com/lecture/index.jsp?no=04)
- Two-finger drag moves the canvas, pinch zooms, and two fingers moving in a circle rotate it. Two-finger tap undoes and three-finger tap redoes. Tapping with a second finger while the drawing finger is still down cancels the current stroke (brush, eraser or finger tool). — [Gestures iOS](https://ibispaint.com/lecture/index.jsp?no=151)
- With a keyboard: Z+pen drag zooms, R+pen drag rotates, Alt+Ctrl+pen drag changes brush size, [ and ] change size, Shift+/ shows the shortcut list. A Bluetooth mouse right-click picks a color while the Brush is active. — [same](https://ibispaint.com/lecture/index.jsp?no=151)
- The manual has a separate chapter on setting the delay before Quick Eyedropper starts (press-and-hold to pick a color). Version 13.0 added this timing setting. — [Manual index](https://ibispaint.com/lecture/index.jsp) (no=198); [App Store](https://apps.apple.com/us/app/%EC%9D%B4%EB%B9%84%EC%8A%A4-%ED%8E%98%EC%9D%B8%ED%8A%B8-x/id450722833?l=pt-BR)
- On tablets and PCs the Layer window can float over the canvas. It can be moved by a move bar, resized by its edges and corners, and closed. — [Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156)

### Inferences
- In ibis Paint, brush size and opacity sit on vertical sliders on the left edge of the canvas. I know this from familiarity with the app. The fetched page did not describe it, so verify against a screenshot before building it.
- Build the gesture recognizer first: pan, pinch and rotate together, plus 2-tap undo, 3-tap redo and second-finger stroke cancel. It is cheap and it is the core of the ibis feel.

### Gaps
- The exact long-press delay default and the eyedropper sample-source options (canvas vs. layer) were not fetched. The manual chapters are no=15 and no=198.
- Canvas-side slider layout is not documented on the pages I fetched.

## Brush tool: parameters, stabilizer and custom brushes

### Takeaway
ibis exposes a very deep per-brush parameter set: Fade, Shape, Jitter, Scatter, Type, Texture, Dynamics and Settings. On top of that there is a global or per-brush Stabilizer (Real Time or After) and a Force Fade that controls taper length.

### Cited Findings (all from [Details of Brush Parameters](https://ibispaint.com/lecture/index.jsp?no=118) unless noted)
- **Basic:** Thickness, Opacity.
- **Fade:**
  - Thickness of Start / End and Opacity of Start / End, each as a ratio of the base value.
  - Force Fade Out.
  - Blurring Shape (Off disables the blur parameters), Blurring Degree, Blurring of Start / Middle / End, Jitter Blurring.
- **Shape:**
  - Brush Pattern (the stamp image), Spacing (% of Thickness), Pattern Opacity.
  - Opacity Saturation: overlapping within one stroke cannot go past Opacity.
  - Decrease Opacity.
  - Initial Angle, and Following Rotation (stamp angle follows stroke direction).
  - Aspects: squash or stretch the stamp; 0% = equal.
  - Antialias, Separate Each Stroke, Dots, Add Opacity, Constant Opacity, Spacing for <3 px.
  - MSAA (High Quality Edge).
  - Ruler options: Bind Center on Elliptical Ruler, Billboard Display on Array Ruler, Fixed Thickness, Array in Perspective, Max Spacing for 30 px.
- **Jitter:** Position, Thickness, Opacity, Spacing, Angle.
- **Scatter:** on/off, Absolute Particle Size, Particle Size (px), Particle Density, Particle Deviation (negative = outward, positive = inward), Angle Based on Center.
- **Brush Type:**
  - Mono: whiteness of the stamp becomes opacity.
  - Water: mixes with the colors below. Settings: Color Mix, Wetness, Dragging.
  - Double: outline or shadow. Settings: Select Shadow Color, Body Color, Absolute Shadow Size, Shadow Size, Shadow Angle, Shadow Distance, Apply Texture Shadow.
  - Color: for color stamps only.
- **Texture:** Texture Pattern, Opacity, Lower Limit, Absolute Texture Size, Scale, Angle, Moving (follows the stroke vs. fixed), Texture Antialiasing (off for pixel art), Invert.
- **Dynamic:** Speed→Thickness, Speed→Opacity, Speed→Blurring, Pressure→Thickness, Pressure→Opacity, Pressure→Blurring. These are signed response amounts, not curve editors.
- **Settings:** Min/Max Thickness (the slider range), Blending Mode, Rename, Reset.
- Version 13.1.1 added a "Flat" blending mode for brushes. — [App Store KR](https://apps.apple.com/kr/app/%EC%9D%B4%EB%B9%84%EC%8A%A4-%ED%8E%98%EC%9D%B8%ED%8A%B8-x/id450722833)
- **Stabilizer:**
  - Method **Real Time** has two sub-settings: Constant (same strength at any speed) and Fast Strokes (stronger when moving faster). OFF disables it. "Use Legacy Stabilization" restores the method from before 14.0.11.
  - Method **After** smooths the whole line when the pen lifts, with one strength slider.
  - **Force Fade** has Start Length, End Length and Fade Shape (Smooth = rounded tip, Linear = pointed tip).
  - All of this can apply to every brush or to the current brush only ("Set for Current Brush", or Custom Stabilizer and Custom Force Fade inside a brush).
  - — [Stabilizer](https://ibispaint.com/lecture/index.jsp?no=50)
- The "legacy ≤14.0.11" wording means the app is at v14.x in the current period. — [Stabilizer](https://ibispaint.com/lecture/index.jsp?no=50)
- **Custom brushes:** make a custom brush, create original brush patterns (v13.0), edit a brush shape (v13.1 added Bézier handles), import and export brushes, publish to and search the online gallery. — [Manual index](https://ibispaint.com/lecture/index.jsp) (no=104, 200, 201, 137, 152, 155, 175); [App Store](https://apps.apple.com/us/app/%EC%9D%B4%EB%B9%84%EC%8A%A4-%ED%8E%98%EC%9D%B8%ED%8A%B8-x/id450722833?l=pt-BR)

### Inferences
- A practical subset to build first is the stamp engine: pattern, spacing, angle and follow-rotation, aspect, jitter, scatter, texture, start/end taper, speed and pressure dynamics, the Real Time and After stabilizers, and a blend mode. This covers most of what users notice.
- "Water" brush = smudge-style color pickup from below. "Double" = a stamp with an offset outline or shadow pass.

### Gaps
- Numeric ranges and defaults are not documented. The full catalog of brush categories (Dip Pen, Felt Tip, Airbrush and so on, roughly 40+ default brushes) was not fetched.
- I found no pressure curve editor. Pressure appears to be signed scalars only.

## Eraser

### Takeaway
The eraser uses the same settings window and the same brush patterns as the brush, so any brush shape can erase. Erasing sets pixels to transparent on whatever the current layer is, imported photos included.

### Cited Findings
- The Eraser Setting window is almost the same as the Brush Setting window and offers the same patterns. The page recommends Dip Pen (Soft) and Dip Pen (Hard). Erasing returns pixels to transparent; it only looks white because of the layer underneath. A Brush/Eraser toggle in the toolbar switches between them. — [Undo and Eraser](https://ibispaint.com/lecture/index.jsp?no=08)
- Other erasers:
  - Eraser Bucket (no=13).
  - Surrounding Eraser, added in v13.0: erases closed regions inside a traced loop.
  - Lasso Eraser Special Pen (no=140).
  - Vector Eraser, added in v13.1.
  - — [Manual index](https://ibispaint.com/lecture/index.jsp); [Bucket details](https://ibispaint.com/lecture/index.jsp?no=82); [App Store](https://apps.apple.com/us/app/%EC%9D%B4%EB%B9%84%EC%8A%A4-%ED%8E%98%EC%9D%B8%ED%8A%B8-x/id450722833?l=pt-BR)
- A vector layer cannot be erased by the pixel eraser until it is Rasterized. — [Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156)

### Inferences
- Implement the eraser as the brush engine with a destination-out composite, sharing the parameter set. Imported photos are ordinary raster layers, so they erase the same way.

### Gaps
- None significant.

## Layers

### Takeaway
The Layer window has rows for selection layer, visibility, reorder, folders, editing (clear, invert, move, flip, merge down, delete), add/import, and clipping, alpha lock and opacity. It also has a command menu, a special-add menu (folder, vector, 3D, adjustment, duplicate, merge to new) and 28 blend modes.

### Cited Findings (from [Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156) unless noted)
- **Selection Layer:** a special pink-backed layer at the top that holds the selection mask. Painting on it adds blue (selected) areas, and colors cannot be picked while it is active. — also [Selection Layer](https://ibispaint.com/lecture/index.jsp?no=24)
- **Per-layer controls:** visibility eye, drag reorder handle, folders.
- **Editing buttons:**
  - Clear Layer and Invert Color; both respect the selection.
  - Move Layer, which opens Transform.
  - Flip Horizontal / Vertical.
  - Merge Down, Delete, Edit Adjustment Layer.
- **Add row:** Add Layer, Import from Photo Library (adds as a new layer), Flip Canvas H/V (all layers).
- **Properties:**
  - Clipping: clips to the layer below.
  - Alpha Lock: edits only opaque pixels and keeps their alpha. Not available for folders or vector layers.
  - Opacity.
- **Command menu:**
  - White to Transparent (Grayscale) and White to Transparent (Color).
  - Select Opacity: selection from the layer's alpha.
  - Rename, Lock Layer, Solo Mode, Rasterize, Save Layer as Transparent PNG.
- **Special add menu:**
  - Add Folder, Add Vector Layer, Add 3D Layer, Add Adjustment Layer.
  - Duplicate Layer or Folder.
  - Add Layer from Folder (merged copy) and Add Layer from Canvas (merged copy of everything).
- **Background:** solid color, transparent (light or dark checker), Paper Canvas texture.
- **Blend mode list** also includes a Screentone option.
- **Blend modes (28):**
  - Normal
  - Darken, Multiply, Color Burn, Linear Burn, Darker Color
  - Lighten, Screen, Color Dodge, Linear Dodge, Add, Lighter Color
  - Overlay, Soft Light, Hard Light, Vivid Light, Linear Light, Pin Light, Hard Mix
  - Invert, Difference, Exclusion, Subtract, Divide
  - Hue, Saturation, Color, Luminosity
  - — [Blend mode details](https://ibispaint.com/lecture/index.jsp?no=83)
- **Line extraction:** the Filter "Extract Line Drawing" turns a photo of paper line art into transparent lines. It has White, Black and Middle (about 50%) sliders. Close black/white values give a binary look; far apart gives an analog look. — [Extract Line Drawing](https://ibispaint.com/lecture/index.jsp?no=56)
- Related filters: Find Edges and Find Edges (Handwriting). — [Manual index](https://ibispaint.com/lecture/index.jsp) (no=142, 147)
- **Reference layer:** the Bucket and Magic Wand "Reference Layer" option (Canvas, Current, or Specific Layer) plays this role. The fetched pages show no separate "reference layer" flag. — [Bucket details](https://ibispaint.com/lecture/index.jsp?no=82)

### Inferences
- Minimum parity: a layer stack with folders, clipping, alpha lock, opacity, the 28 blend modes, a selection-as-layer mask, merge down, merged-copy-from-canvas, and flips.

### Gaps
- Not fetched: adjustment layer types (no=173), vector layer behavior (no=191) and 3D layer details.

## Selection

### Takeaway
Selection is mask-based and editable as a layer. Lasso and Magic Wand have Set/Add/Subtract modes. Invert, Clear and Transform are available, along with Color Range and Expand/Contract. Transform has Translate-Scale, Perspective and Mesh modes, with 6 interpolation methods.

### Cited Findings
- Lasso modes are Set (replace), Add and Subtract. The selection window has Invert, Clear and Transform. In Transform, one finger moves, pinch scales, and two-finger rotation works once Rotate is enabled. — [Lasso](https://ibispaint.com/lecture/index.jsp?no=09)
- Separate tools: Selection Color Range, Expand/Contract Selection, and Contents Layer Selection. — [Manual index](https://ibispaint.com/lecture/index.jsp) (no=162, 169, 195)
- Cut, Copy and Paste have their own chapter (no=52). — [Manual index](https://ibispaint.com/lecture/index.jsp)
- Magic Wand settings are "similar" to the Bucket settings: Strength, Expansion, Reference Layer, Boundary RGBA vs. Opacity. — [Bucket details](https://ibispaint.com/lecture/index.jsp?no=82)
- **Transform tool modes:**
  - **Translate Scale:**
    - Scaling and Rotation toggles, Repeat.
    - Numeric Move X/Y, Zoom and Angle.
    - Target: current layer or whole canvas.
    - Show Frame around Object. When on, touches outside the frame move the canvas instead of the object.
  - **Perspective Form:** Perspective on/off; Repeat Off/Inner/Horizon/Full; Repeat X/Y; Phase X/Y; Interpolation.
  - **Mesh Form:** Draw Order, Division X/Y, Smoothness.
  - **Interpolation:** Nearest Neighbor, Average Pixel, Bilinear, Bicubic, Lanczos2, Lanczos3.
  - **Gestures:** drag a corner knob to scale, drag inside the box to move, drag the rotation knob to rotate.
  - — [Transform details](https://ibispaint.com/lecture/index.jsp?no=154)

### Inferences
- Store the selection as an 8-bit mask layer. Then the lasso, the wand, and painting on the selection layer all write to the same mask.

### Gaps
- Not confirmed on fetched pages: rectangle and ellipse selection shapes, a polygonal lasso, an intersect mode, and Magic Wand anti-alias. The Shape button next to Selection Area likely provides the rectangle and ellipse shapes.

## Fill (Bucket)

### Takeaway
The Bucket has Strength (tolerance), Expansion (default 1.5 px; can be negative), Unpainted Recognition, Gap Recognition, Continuous Filling (swipe), Under Line, Boundary (RGBA vs. Opacity), and Reference Layer (Canvas, Current or Specific). Lasso Fill and Surrounding Fill cover lasso-style filling.

### Cited Findings
- All settings above are from [Bucket tool details](https://ibispaint.com/lecture/index.jsp?no=82). Expansion at 0 px leaves gaps at anti-aliased edges, and negative values suit speech balloons.
- Lasso Fill Special Pen (no=139), and Surrounding Fill (v13.0), which fills enclosed areas within a traced loop. — [Manual index](https://ibispaint.com/lecture/index.jsp); [Surrounding Fill](https://ibispaint.com/lecture/index.jsp?no=196)
- A v13.0.2 fix addressed drawing corruption during fill undo/redo. — [APKMirror 13.0.2](https://apkmirror.com/apk/ibis-inc/ibis-paint-x/ibis-paint-x-13-0-2-release)

### Gaps
- No explicit fill anti-alias toggle is documented.

## Filters, smudge/blur/liquify, rulers, shapes, text

### Takeaway
There are roughly 75 filters in categories: Adjust Color, Blur, Style, Draw, Smart, Artistic, Pixelate, Transform, Frame and Movie. There are Smudge and Blur tools, and a Special Pen group (Liquify, Copy Pen, Lasso Fill, Lasso Eraser). There are 8 ruler types, a Shape/Drawing tool family, Text, and Frame Divider.

### Cited Findings (from the [Manual index](https://ibispaint.com/lecture/index.jsp) unless noted)
- **Adjust Color:** Brightness & Contrast, Tone Curve, HSL, Color Balance, Extract Line Drawing, Find Edges (and Handwriting), Change Drawing Color, Mono Color, Grayscale, Black & White, Posterize, Invert, Gradation Map, Levels, Replace Color.
- **Blur:** Gaussian, Zooming, Moving, Spin, Lens, Mosaic, Unsharp Mask, Frosted Glass.
- **Style:** Stroke (Both and Outer), Stained Glass, Wet Edge, Glow (Inner and Outer), Bevel (Inner and Outer), Emboss, Relief, Relief HQ, Waterdrop, Satin, Drop Shadow, Extrude, God Rays.
- **Draw:** Parallel, Concentric and Radial Line Gradation; Radial Line; Speed Line; Clouds; QR Code.
- **Smart:** Watercolor, Background Removal.
- **Artistic:** Anime Background, Manga Background, Chromatic Aberration, Glitch, Noise, Retro Game, Chrome, Bloom, Cross Filter, Sheer.
- **Pixelate:** Crystallize, Hexagonal, Square, Triangular, Pointillize, Dots (Hexagonal and Square).
- **Transform:** Expansion, Fisheye, Sphere, Wave, Ripple, Twirl, Polar Coordinates.
- **Frame:** Table, Blur Frame.
- **Movie:** Rain.
- v13.1.1 added undo/redo for changes to Filter parameters. — [App Store KR](https://apps.apple.com/kr/app/%EC%9D%B4%EB%B9%84%EC%8A%A4-%ED%8E%98%EC%9D%B8%ED%8A%B8-x/id450722833)
- **Liquify Pen modes:** Drag, Shrink, Expand, Smoothen, Revert. Settings: Thickness and Strength. — [Liquify Pen](https://ibispaint.com/lecture/index.jsp?no=138)
- **Rulers:** Straight, Circular, Elliptical, Radial, Mirror, Kaleidoscope, Array, Perspective Array. The Mirror ruler has a Phase slider for the axis angle and a draggable position handle. — [Mirror Ruler](https://ibispaint.com/lecture/index.jsp?no=47)
- **Drawing and Shape tools:**
  - Straight Line, Rectangle, Circle, Ellipse, Regular Polygon, Bézier Curve, Polyline.
  - Rounded Rectangle (v13.1.1), Thin Arrow, Speech Bubble.
  - Text tool, Frame Divider (manga panels), Material tool, Canvas Papers, Grid.

### Gaps
- Per-ruler settings beyond Mirror were not fetched (no=43–48, 89, 90). Smudge and Blur tool settings and Text tool options were also not fetched.

## Animation (frame-by-frame and Video Mode)

### Takeaway
An animation canvas has an fps setting, a frame bar (+ to add, long-press and drag to reorder), per-frame duration, duplicate and delete, and onion skin (count, first/last opacity, color, display mode). Playback is Loop, Ping-pong or One-shot. Video Mode is a one-way conversion to a 60 fps timeline with drawing and audio tracks.

### Cited Findings
- **Frame animation:**
  - fps is set at creation and can be changed later in Animation Settings.
  - Onion skin: Display Mode, Number of Onion Skins, First Opacity and Last Opacity (the furthest skin's opacity is their product), Color.
  - Play options: Loop, Ping pong, One-shot.
  - Frame Settings: Duration, Duplicate, Delete.
  - Export with Save Animation Video.
  - — [Create an animation](https://ibispaint.com/lecture/index.jsp?no=182)
- **Video Mode:**
  - Convert with ⋮ → Add Audio Track. The conversion cannot be undone.
  - After conversion: 60 fps, zero-duration clips are deleted, and ping-pong is not supported.
  - The bottom timeline has a fixed center playhead. Pinch zooms the time scale, and dragging the ruler resizes the panel.
  - Drawing tracks hold clips packed left with no gaps (an empty clip makes a pause). Audio clips can sit anywhere, with per-clip and per-track volume.
  - Export as MOV or MP4. IPVZ keeps the editable project.
  - — [Video Mode](https://ibispaint.com/lecture/index.jsp?no=210)

### Inferences
- In an iOS video editor, the drawing studio's animation can map directly onto the host timeline. ibis's Video Mode already uses the clip-on-track model.

### Gaps
- Onion skin Display Mode options and the fps range are not enumerated.

## AI / Smart features

### Takeaway
"Smart" features use credits. Premium members get a monthly refill and paid credits do not expire. The documented Smart features are the Watercolor filter (1.50 credits), Relief HQ (1.00) and Background Removal. Background Removal is tap-guided: tap the object to keep, and tap with minus to mark background. Other AI items: AI upscaling for high-resolution output, and "AI Disturbance" (anti-AI-training noise).

### Cited Findings
- Credits: Watercolor costs 1.50 and Relief HQ costs 1.00. Premium Credits refill on the 1st of each month up to a limit. Paid Credits do not expire and are spent after Premium Credits. — [Smart Features & Credits](https://ibispaint.com/lecture/index.jsp?no=209)
- Background Removal is at Filter → Smart. Tap the object to place a blue keep point. Use the minus button to switch to background mode and place red points. Show Mask can be toggled, and OK confirms. — [Background Removal](https://ibispaint.com/lecture/index.jsp?no=177)
- Manual chapters: "Output High-Resolution Images with AI" (no=174) and "AI Disturbance" (no=192). — [Manual index](https://ibispaint.com/lecture/index.jsp)

### Inferences
- Background Removal behaves like a point-prompted segmentation model (SAM-like). On iOS, Vision's subject-lifting (VNGenerateForegroundInstanceMaskRequest), refined with positive and negative points, is a close native match.

### Gaps
- I found no documented "AI line art" or AI auto-colorize feature. I did not confirm the cost of Background Removal or AI upscaling. Release notes for v14.x (2026) were not retrieved; the official news page on ibispaint.com would be the source.
