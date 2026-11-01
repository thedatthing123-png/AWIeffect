# Motion Design Craft for Short-Form Edits: Typography, Design, Animation Principles, 3D

Note: Adobe helpx pages (animating-text, 3d-cameras-lights) returned HTTP 403, and the Alight Creative techniques blog returned 404, so primary-doc details come from secondary sources. Items in "Inferences" that come from general AE practitioner knowledge, not a fetched source, are marked [practitioner knowledge].

## 1. What text animation recipes are most used in edits and how are they built (selectors, offsets, timing)?

### Takeaway
Most text reveals are one animator (Opacity / Position / Scale / Character Offset) driven by a Range Selector whose Start/End/Offset is keyframed, with Smoothness and Ease High/Low shaping how each character transitions. Lyric edits time words to beats (beat = 60/BPM seconds) and count read time from when a word stops moving.

### Cited Findings
- Typewriter: add Character Offset (or Opacity) animator, keyframe Range Selector Start/End 0 to 100, align keys to audio markers — [CapCut resource](https://www.capcut.com/resource/typewriter-effects-in-after-effects)
- Set Range Selector > Advanced > Smoothness to 0 for a crisp typewriter look; Ease High/Low add slight speed variation per character; animate Opacity to hide characters; add a small rectangle as a cursor — [Pixel Bakery](https://pixelbakery.com/education/tutorials/how-to-add-typewriter-effect)
- Ease High/Low shape each character's transition between fully selected (high) and unselected (low). This is different from easing the Start/End/Offset keys, which only changes how fast the selector sweeps across — [ProVideo Coalition](https://www.provideocoalition.com/cmg_hidden_gems_chapter_21_textacy/)
- Per-character 3D: enable it from the text Animate menu, then add Position and Rotation animators. This is how 3D letter flips and fly-ins are built — [Adobe text animation examples](https://helpx.adobe.com/after-effects/using/examples-resources-text-animation.html)
- Combining three text animators with per-character 3D, simple camera moves and DOF — [Layers Magazine](https://layersmagazine.com/3d-motion-and-position-of-text-characters-with-after-effects.html)
- Stagger can be applied per character, per word or per line — [Ross XPression](https://www.rossvideo.com/gallery/xpression-u/stagger-animations-in-xpression/); [VideoGen](https://help.videogen.io/en/articles/16607613-stagger-animations)
- Lyric timing: count hold time from when the word stops moving. Netflix subtitle events run 5/6 s to 7 s. Rough guide: 1-3 letter word about 1 s, 4-8 word phrase 2-3 s, 10-15 word sentence 3-5 s. One beat = 60/BPM s (0.5 s at 120 BPM). Set a rule such as one word per beat or a scale-up on the chorus — [Morphic lyric videos](https://morphic.com/resources/videos/lyric-videos); [Oakgen](https://oakgen.ai/blog/kinetic-typography-without-after-effects) (vendor sources, medium reliability)
- Fast chorus style: plain cuts plus squash and stretch on the hook, with words landing on beats; quotes use calmer type — [Editframe typography personalities](https://editframe.com/skills/brand-video-generator/typography-personalities)

### Inferences
- [practitioner knowledge] Standard "pop-in per letter" recipe: Scale 0% + Opacity 0% animator, Range Selector Offset from 0 to 100% (or End keyed), Shape = Ramp Up, Ease Low around 50-100. Sweep about 0.4-0.8 s (12-24 f at 30 fps) for a word, and add an overshoot (inertial bounce) on Scale.
- [practitioner knowledge] Typical per-character stagger is 1-2 frames per character. For word-by-word lyric pops, use 2-4 frames per word, or snap each word to the beat (15 f at 120 BPM / 30 fps).
- [practitioner knowledge] Common edit styles: blur-in (Blur 20-40 + Opacity + Tracking) and slide-up masked reveal (Position Y about +100% of cap height inside a track matte). Others include glitch/scramble (Character Offset with Randomize Order), word-by-word captions with an accent-color active word, and a 3D letter flip (per-character 3D, Rotation X -90 to 0).
- Beat sync at 30 fps: frames per beat = 1800/BPM (for example 128 BPM gives about 14 f).

### Gaps
- Exact Adobe docs on Range Selector Shape options and the Wiggly / Expression selector were not retrieved (403).
- I found no sourced numeric Ease High/Low presets for specific looks.
- I found no Alight Motion-specific text-stagger tutorial with settings.

## 2. What design and composition rules make edits look clean and pro, especially 9:16?

### Takeaway
On a 1080x1920 frame, keep titles and faces inside a central box. Clear roughly 130 px at the top, 400-480 px at the bottom and 150-180 px on the right. Use one loud display face plus one quiet face, one or two accent colors, a simple background and bold weights.

### Cited Findings
- No official pixel safe zone exists. A measured estimate for TikTok on 1080x1920 is about 130 px off the top, 480 px off the bottom and 150 px off the right, leaving about 870x1310. Reels reserves about 180 px on the right — [Moda safe-zone checker](https://moda.app/tools/story-safe-zone-checker)
- Percentage rules: avoid the bottom 20% (captions) and the right edge (icons); another guide says avoid the top and bottom 10%. A Meta-focused guide gives top 14%, bottom 35% and sides 6% — [Picc](https://explore.picc.co/safe-zone-templates-social-media-videos/); [House of Marketers](https://houseofmarketers.com/guide-to-safe-zones-tiktok-facebook-instagram-stories-reels/)
- A brand system for 1080x1920 uses 48 px side margins, a 984 px graphic-safe width, and an 896x1264 type-safe area centered 260 px from the top — [Canadian Tire design system](https://brand-qa2.canadiantire.ca/en/ctr/design-system/omni-channel/motion/margins-and-safe-space.html)
- Keep the background simple so motion stays readable, and use 1-2 accent colors on key words. Pair one loud face with one quiet face. Bold weights survive fast scaling. Mobile minimum is about 24 px for body text and 36 px or more for headlines. Line breaks change in 9:16 (one 16:9 line can become three) — [Morphic](https://morphic.com/resources/videos/lyric-videos); [Oakgen](https://oakgen.ai/blog/kinetic-typography-without-after-effects)

### Inferences
- [practitioner knowledge] Hierarchy: there is one focal element per frame. The headline is at least 2x the secondary text size. Contrast comes from value first, then color. Place the subject on thirds or dead center for impact frames.
- For anime edits, a limited palette sampled from the source (2-3 hues plus white or black) gives a clean look. Accent colors should follow lyric emphasis.
- Headlines in a 9:16 edit should use 80-160 px cap height to read at phone size (extrapolated from the 36 px minimum).

### Gaps
- No primary platform-published safe-zone spec was found. Figures are measured estimates and conflict between sources.

## 3. Which animation principles matter most for motion graphics and how are they expressed in easing/keyframes?

### Takeaway
Ease-out on entrances, ease-in on exits, and overshoot or inertial bounce for snappy lands carry most of the pro feel. Overshoot is expressed with the inertial bounce expression (amp/freq/decay) or with an extra keyframe past the target, and speed-graph influence controls the snap.

### Cited Findings
- Speed graph shows velocity, value graph shows values. Open it with Shift+F3 and edit with "Edit Speed Graph". Handle length is keyframe influence. Easy Ease is F9 and puts peak speed mid-move — [School of Motion](https://schoolofmotion.com/blog/intro-to-the-graph-editor-in-after-effects); [AEJuice](https://aejuice.com/blog/how-to-use-the-speed-graph-in-after-effects)
- For a bouncing ball, set the floor-contact keyframes' influence to 0 (a hard contact) — [Adobe Community](https://community.adobe.com/t5/after-effects-discussions/help-with-speed-animation-in-graph-editor/m-p/11757827)
- Inertial bounce defaults (Animoplex): amp 5, freq 2, decay 4. Other values in use: amp 0.1 / freq 2 / decay 2 (Tuts+), amp 8 / freq 2 / decay 3 (Lester Banks), amp 0.05 / freq 4 / decay 8 for a fast bounce. Raise decay to 5-6 if the overshoot lingers. Scaling differs between versions (amp/100 versus amp), so values are not portable — [Animoplex gist](https://gist.github.com/jexchan/bbff1a3c9701ce5fd4db6f07b2f78d6d); [Tuts+](https://photography.tutsplus.com/tutorials/how-to-animate-inertial-bounce-expressions-in-after-effects--cms-41469); [Adobe Community](https://community.adobe.com/t5/after-effects-discussions/inertial-bounce-multiple-times-on-the-same-property/m-p/13578026); reference: [motionscript bounce & overshoot](http://www.motionscript.com/articles/bounce-and-overshoot.html)
- UI timing guidance: 100-150 ms for feedback, 200-300 ms for state changes, 300-500 ms for larger moves. Exits run about 75% of the entrance duration. Ease-out feels faster than ease-in at equal duration. Bounce and elastic curves suit playful styles — [impeccable motion-design reference](https://cdn.jsdelivr.net/npm/@nqlib/nqui@0.6.3/docs/nqui-skills/impeccable/reference/motion-design.md); [playbooks slow-in/out](https://playbooks.com/skills/dylantarre/animation-principles/slow-in-out-mastery) (practitioner opinion)
- Alight Motion's blog recommends overshoot with motion blur, staggered follow-on elements and a parallax background — [Alight Creative blog](https://alightcreative.com/blog/top-animation-techniques) (page now 404; summary from search snippet)

### Inferences
- At 30 fps, 200-300 ms is 6-9 f, and 300-500 ms is 9-15 f. Typical title entrances in edits run 8-15 f, and exits 6-10 f.
- [practitioner knowledge] AE Easy Ease is 33.33% influence. A pro "snap" ease uses about 70-90% influence on the landing key (long tail) and 0-30% on the launch key. Manual overshoot: go 5-15% past the target (for example scale 0 to 110 to 97 to 100) over about 4-6 f per segment.
- [practitioner knowledge] Anticipation is a 2-4 f pull-back of 3-10% before the main move. Follow-through means secondary elements land 2-4 f after the primary (offset keyframes). Motion blur uses a 180-degree shutter.

### Gaps
- The "70% influence" figure was not confirmed by any fetched source. No authoritative School of Motion numeric influence values were retrieved.

## 4. How are 2.5D/3D parallax and camera moves built and timed for edits?

### Takeaway
Cut the image into depth layers, set them at different Z values, and move a camera (usually a 50 mm preset with DOF enabled). Focus is driven by Focus Distance, linked to a layer, while Aperture sets blur strength. A dolly zoom pushes the camera position against zoom or scale.

### Cited Findings
- Create a camera with the 50 mm preset and enable Depth of Field. A higher Aperture gives a stronger blur, and changing it updates F-Stop. Focus Distance is the distance to the sharp plane. Use "Link Focus to Layer" to track a subject — [AEJuice DOF](https://aejuice.com/blog/how-to-create-depth-of-field-in-after-effects); [Dartmouth 3D cameras and lighting PDF](https://film-media.dartmouth.edu/sites/department_film.prod/files/department_film/wysiwyg/3d_cameras_and_lighting.docx.pdf); [Motion Array DOF](https://motionarray.com/learn/after-effects/after-effects-depth-of-field-tutorial/)
- Parallax: separate the image into layers, set Z-positions, animate the camera, then tune Focus Distance and Aperture so far layers blur — [AEJuice parallax](https://aejuice.com/blog/how-to-create-parallax-effect-in-after-effects)
- DOF craft across tools — [School of Motion DOF](https://schoolofmotion.com/blog/depth-of-field-cinema-4d-nuke-after-effects)
- Dolly zoom in post: stabilize, then keyframe scale and position against real camera motion. It does not work on a static shot. A scale-based fake works on tracking shots — [Lester Banks](https://lesterbanks.com/2012/07/creating-a-dolly-zoom-vertigo-effect-in-a-timelapse-shot-using-after-effects/); [PetaPixel](https://petapixel.com/2016/10/11/create-dolly-zoom-effect-post-no-zoom-lens-required/)

### Inferences
- [practitioner knowledge] For layers to keep their on-screen size, compensate each layer's scale: scale = 100 x (Z distance from camera) / (camera Zoom). Typical depth spacing for a manga panel split is BG at Z +1000-3000, mid at 0, FG at -300 to -600.
- [practitioner knowledge] A camera push of 200-600 px in Z over 1-3 s (30-90 f) with ease-in-out gives a subtle drift. Impact pushes cover 100-300 px in 4-8 f with a hard ease-out plus shake. Orbits use a null parent rotated 10-30 degrees in Y over 1-2 s.
- [practitioner knowledge] For DOF, focus on the subject layer (link focus), then set Aperture so the BG blur is visible but not mush (about 20-60 px blur at 1080p). Light DOF reads more "pro" than heavy DOF.
- [practitioner knowledge] For a dolly zoom in a 3D camera, keyframe Camera Position Z and Zoom in opposite directions so the subject's size stays constant. Zoom/distance stays constant (zoom_new = zoom_old x d_new/d_old) over 1-2 s.
- [practitioner knowledge] For 3D text, AE's Cinema 4D / Advanced 3D renderer offers extrusion depth (about 20-80 px for titles), bevels and lights. Lights cast shadows only when the light's "Casts Shadows" option and the layer's Accepts Shadows are both on.

### Gaps
- Adobe camera and light docs (exact preset focal lengths, shadow darkness/diffusion values, Advanced 3D extrusion) were not retrievable (403).
- I found no numeric Alight Motion 3D camera or parallax tutorial.
- I found no sourced dolly-zoom expression.
