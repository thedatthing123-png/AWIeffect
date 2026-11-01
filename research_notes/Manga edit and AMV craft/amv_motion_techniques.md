# AMV / Edit Motion Techniques (After Effects + Alight Motion) — Recipe Book Notes

Note on sourcing: Primary/official docs (Boris FX Sapphire, Maxon Red Giant, Video Copilot, Alight Motion guide, Adobe forums) were reachable. Most YouTube/TikTok edit tutorials are video-only, and their numbers could not be pulled as text. Many reddit pages failed (502/403). Any value marked **[ESTIMATE]** is common practitioner convention from my background knowledge, not from a source fetched here. Treat those as starting points to tune by eye.

## How do pro AMV/edit makers structure an edit (intro, build, drop, outro) and sync to music?

### Takeaway
Editors mark beats on the audio waveform with layer markers, then nudge them, because markers tapped live land 2-3 frames late. Cuts alternate long and very short shots, and the hits (flash, shake, zoom) sit on the marker frame. Musical phrases usually line up to 4-beat groups, which gives the intro/build/drop/outro structure.

### Cited Findings
- Velocity workflow: expand the audio layer to show the waveform and add markers at beat peaks (Layer > Markers > Add Marker). Then key the speed and scale changes between markers. — [AEJuice: velocity edits](https://aejuice.com/blog/how-to-do-velocity-edits-after-effects)
- Markers tapped during playback tend to land 2-3 frames late unless the editor anticipates, so nudge them afterwards. — [Adobe community: keyframes on audio beats](https://community.adobe.com/t5/after-effects-discussions/key-frames-on-audio-beats/m-p/12538705/highlight/true)
- r/amv guide (2022) on "scene shifting": cuts alternate between long shots and very short ones. Still-frame cuts get hidden with a quick white flash. Beats often fall in groups of 4, which helps timing. — [r/amv scene shifting post (mirror)](https://reddit.rtrace.io/r/amv/comments/xjbhtg/scene_shifting_the_easiest_mistake_all_video) (full page could not be fetched; based on the search snippet)
- The r/amv wiki has guides on workflow, scene shifting, reaction time, and beat vs lyric scenes. — [r/amv wiki guides (mirror)](https://reddit.rtrace.io/r/amv/wiki/guides) (not opened)
- Some NLEs offer automatic beat detection that clips can snap to. — [Movavi beat detection](https://img.movavi.com/online-help/videosuite/20/beat_detection.htm)
- Udemy velocity course lists "Marking Audio Beats Precisely" as its own topic, alongside slow-mo plugins and velocity zooms. — [Udemy AE basic velocity course](https://www.udemy.com/course/after-effects-basic-velocity-course/)

### Inferences
- Frames per beat = fps × 60 / BPM. At 24 fps and 120 BPM that is 12 frames per beat, and 48 frames per 4-beat bar. Snapping markers to this grid fixes late taps. (This is plain arithmetic.)
- [ESTIMATE] Typical structure: intro is calm, with long shots and slow pushes and little or no FX. The build adds cuts per beat and small shakes, and its ramps speed up. The drop places a hit on every beat, with flashes, zoom punches, big shakes and velocity. The outro returns to slow, with a fade or freeze. Editors often place the visual hit 0-2 frames before the transient so it reads as on beat. A hard rule is to place cuts on the marker frame itself.

### Gaps
- No fetched source gave numeric structure templates (for example, bar counts per section) from named pro editors.

## What are the standard recipes (with numbers) for velocity edits, shakes, flashes, zoom punches, glitches, transitions?

### Takeaway
Velocity: fast (about 200%) into the beat and slow (about 20%) between beats, with scale moving 100 to 130 to 100 in sync. Ramps must hand off at 1 sec/sec with about 33% influence to avoid a stall. Shake: S_Shake defaults are Amp 1 / Freq 8. A wiggle equivalent is high freq + low amp for jitter, or low freq + high amp for sway. Flash: a white solid 4-5 frames long that fades out. Zoom transitions need Motion Tile with mirror edges plus motion blur.

### Cited Findings
**Velocity / speed ramps**
- Recipe from the source: Timewarp Speed is 200 at the marker, 20 between markers, and 200 again at the next marker. Scale is 100 at the marker, 130 between markers, and 100 at the next. Apply Easy Ease, refine in the Graph Editor, and turn on layer motion blur. — [AEJuice](https://aejuice.com/blog/how-to-do-velocity-edits-after-effects)
- With Time Remap, Easy Ease drops speed to 0 sec/sec and then jumps back to 1 sec/sec, which shows as a stall. The fix is to set the outgoing velocity of the first key and the incoming velocity of the second key to 1 sec/sec at 33.33% influence. — [Creative Cow thread](https://creativecow.net/?p=7479); [Creative Cow thread 2](https://creativecow.net/?p=35067)
- 1 sec/sec = 100% speed, and 0.2 sec/sec = 20%. — [Adobe community: precise speed ramping](https://community.adobe.com/t5/after-effects-discussions/how-to-get-precise-speed-ramping-in-after-effects/m-p/11778556/highlight/true)
- Twixtor: set Input Frame Rate to match the footage. Motion Sensitivity (0-100) trades warping against blending: lower it to reduce warp, raise it to fix blending. Vector Quality and Image Prep matter too. — [Boris FX Twixtor guide](https://borisfx.com/blog/twixtor-after-effects-how-to-step-by-step-guide/); [Post Magazine review](https://digital.copcomm.com/i/585189-october-2015/47)

**Shakes**
- S_Shake (Sapphire AE) defaults: Amplitude 1, Frequency 8, and Style = Normal / Twitchy / Jumpy.
  - Twitchy: Stillness 0.7, Twitch Freq 2.
  - Jumpy: Drift 0.3.
  - X Rand Amp 0.2, Y Rand Amp 0.1, Z and Tilt 0, and Rand Freq 1 per axis.
  - Wave Amp 0 and Wave Freq 0.5 cycles/sec (the periodic component).
  - Motion Blur toggle with Mo Blur Length 1. Wrap defaults to Reflect (mirror edges).
  - Per-channel R/G/B amplitude and phase, plus RGB Randomness 0 and RGB Frequency 2 (gives a chromatic shake).
  — [Boris FX S_Shake docs](https://borisfx.com/documentation/sapphire/ae/shake/)
- "Rand" params control random non-periodic shake, and "Wave" params control regular periodic shake. — [Boris FX Sapphire OFX Shake](https://borisfx.com/documentation/sapphire/ofx/shake/)
- Wiggle(freq, amp): freq is wiggles per second and amp is size in px. wiggle(2,40) is a dramatic but slow shake. wiggle(10,3) darts quickly with small movement. — [CG Director wiggle guide](https://www.cgdirector.com/after-effects-wiggle-expression); [School of Motion wiggle](https://schoolofmotion.com/blog/wiggle-expression)
- Alight Motion: the Oscillate effect makes a shake transition by keyframing Magnitude up from or down to 0. Angle sets the direction (0° horizontal, 90° vertical). — [Alight Motion guide: Oscillate](https://guide.alightmotion.com/effects/oscillate)
- [ESTIMATE] Impact shake on a beat: 4-8 frames. It starts at peak amplitude (about 20-60 px at 1080p, plus 1-4° rotation) and decays to 0 with ease-out. Frequency is about 12-24 Hz, roughly one move every 1-2 frames. A sustained "handheld" drift is about 1-3 Hz at 5-15 px. Add motion blur, and overscale or use mirror edges to hide borders.

**Flashes**
- Flash = a white solid starting on the beat marker, 4-5 frames long, fading out. Try different blend modes. — [DVinfo forum (Vegas, 2008)](https://www.dvinfo.net/forum/archive/index.php/t-125973.html)
- A quick white flash hides cuts to still frames. — [r/amv mirror](https://reddit.rtrace.io/r/amv/comments/xjbhtg/scene_shifting_the_easiest_mistake_all_video)
- [ESTIMATE] Variants: a 1-2 frame hard flash (100%, then cut) for strobe-like hits. A 4-8 frame Add/Screen flash with exposure +1 to +3 that decays. A black "dip" of 1-2 frames for heavy hits.

**Zoom punches / zoom transitions**
- Scaling reveals black edges. Fix it with Motion Tile: raise Output Width/Height (one user prefers 300) and enable Mirror Edges. Mirror edges plus motion blur hide the trick. — [Motion Array zoom blur transition](https://motionarray.com/learn/after-effects/zoom-blur-transition-after-effects/) (403 on fetch; from snippet); [AEJuice dynamic transitions](https://aejuice.com/blog/how-to-design-dynamic-transitions-between-clips-in-adobe-after-effects) (150 used there); [Adobe community Motion Tile](https://community.adobe.com/t5/after-effects-discussions/mirror-edges-not-working/m-p/11946662)
- [ESTIMATE] Zoom punch: scale 100 to 110-130% over 2-4 frames (snap) and back over 6-12 frames (ease out). Zoom transition: clip A goes 100 to about 200-400% over about 4-8 frames ending on the cut. Clip B goes about 30-50% (or 200%) to 100 over 4-8 frames. Use a hard exponential ease into the cut and shutter angle 180-360°.

**Glitches / RGB split**
- Twitch (Video Copilot) operators: Blur, Color, Light, Scale, Slide, Time.
  - Slide has direction, spread, motion blur, amount, tendency, and advanced RGB split (a color-glitch slide).
  - Blur has amount, tint, transfer mode, boost, seed, and a lens blur toggle.
  - Each operator has Speed, Amount and Seed, and a "twitch interval" sets how often it fires.
  — [Video Copilot Twitch features](https://www.videocopilot.net/products/twitch/features)
- Universe Glitch Transition: Mix (keyframe for duration), RGB Split Max (negative reverses), Size (bigger glitches), Displacement (pixel shift). — [Maxon Red Giant: Glitch Transition](https://help.maxon.net/rg/en-us/Content/html/glitch-transition.html)
- Universe Chromatic Aberration: per-channel R/G/B distortion, Reverse, and Passes. — [Maxon: Chromatic Aberration](https://help.maxon.net/rg/en-us/Content/html/chromatic-aberration.html)
- [ESTIMATE] A generic rebuild of an RGB split: split the clip into 3 channel copies set to Add (or use Shift Channels), offset R by +X and B by −X (about 5-30 px at 1080p), for 2-6 frames on the hit. Add a random block slice using a displacement map of random rectangles, re-seeded every 1-2 frames.

### Inferences
- A generic engine can rebuild S_Shake as random noise per axis (X/Y/Z/tilt) + a sine wave per axis + motion blur + an edge wrap mode, with a "twitchy" stillness gate (shake active only about 30% of the time). Twitch maps to "random operator fired at an interval, with amount and seed".

### Gaps
- No text source with exact zoom-transition keyframes, frame counts for whip/spin/shape transitions, or Twitch numeric defaults.

## How do editors use the graph editor/easing (which curves for which feel)?

### Takeaway
The speed graph is for shaping acceleration (best for position), and the value graph is for setting values (often better for scale). The AE Easy Ease default is speed 0 with 33.33% influence. Snappy, modern edits push influence to 60-75%+ for a fast start that settles slowly.

### Cited Findings
- Use the speed graph for acceleration and the value graph for values. Position works best in the speed graph, and scale is easier to judge in the value graph. — [Adobe community graph editor thread](https://community.adobe.com/t5/after-effects-discussions/after-effects-graph-editor-problem/m-p/10552536/highlight/true)
- Speed graph: gentle slopes give smooth acceleration, and steep slopes give abrupt changes. — [Noble Desktop speed graph](https://blog.nobledesktop.com/learn/after-effects/speed-graph)
- Easy Ease = speed 0, influence 33.33%, and there's no preference to change that default. One user switches to 60% for a snappier move. — [Adobe community: ease default](https://community.adobe.com/t5/after-effects-discussions/changing-the-ease-default-values/m-p/10906650); [Creative Cow](https://creativecow.net/?p=160300)
- Linear means constant speed (mechanical). Eases simulate momentum, and custom bezier handles give either smooth or sharp transitions. — [Motion Design School keyframe velocity](https://motiondesign.school/blog/keyframe-velocity/)
- School of Motion intro to the graph editor. — [School of Motion](https://www.schoolofmotion.com/tutorials/intro-to-the-graph-editor-in-after-effects/)

### Inferences
- [ESTIMATE] Curve to feel:
  - A tall, narrow speed-graph spike (both handles at about 80-100% influence) is the velocity/"whip" look, with almost all the motion in a few frames.
  - Ease-out heavy (fast start, 70-90% outgoing influence) suits punch-ins and impacts.
  - Ease-in heavy (slow start, fast end into the cut) suits zoom-into-cut transitions.
  - 33% both sides is a neutral, "default" look.
  - Overshoot/bounce (a value graph past target, then settle) suits elastic text and logo pops.
  - Velocity time-remap reads as a "mountain" or "valley" shape on the speed graph: fast at the beat markers and slow in between.

### Gaps
- No fetched source gave named-editor graph-handle values for velocity edits specifically.

## What CC/grading and glow recipes are standard for edits?

### Takeaway
Fix exposure with Levels first (shadows, midtones, highlights), then use curves for contrast and colour. Glow is usually stacked in two passes (tight + wide). Deep Glow suggests a radius of about 100-300 px and exposure tuned below the clipping point. Animating levels or curves per shot keeps clips consistent.

### Cited Findings
- AMV tutorial summary: edits look "weird" when adjustments are crude. Use Levels (shadows, midtones, highlights) as the first step rather than curves or exposure. — [YouTube summary of an AMV tutorial](https://youtubesummary.com/summary/DY14ugv1wd8)
- Animate Levels for brightness differences and Curves for colour differences between shots. — [Michael DeVowe, Vimeo](https://vimeo.com/14396098)
- Generic AE Glow starting point: threshold 30, radius about 5, plus an optional second glow pass. — [Tuts+ Stranger Things lesson](https://photography.tutsplus.com/courses/create-a-stranger-things-inspired-text-animation-in-adobe-after-effects/lessons/how-to-add-color-and-glow-effects)
- Deep Glow: radius controls spread (start at about 100-300 px; larger gives a softer falloff), and exposure controls brightness (watch for blown highlights). Adding noise or a wiggle on the controls gives neon flicker. — [Virgool glow guide](https://virgool.io/@gfxlove/what%E2%80%99s-the-secret-to-professional-glow-effects-in-after-effects-pxuwyayninuy) (unverified third party); [Tuts+ Deep Glow](https://cgi.tutsplus.com/how-to-achieve-realistic-glow-in-after-effects-with-deep-glow--cms-30582t)
- Deep Glow looks good even in non-linear colour. Glow won't extend past layer bounds, so add Grow Bounds of about 2× the glow extent first. — [Toolfarm Deep Glow](https://www.toolfarm.com/?p=22323); [Adobe community](https://community.adobe.com/t5/after-effects-discussions/glow-effect-don-t-spread-outside-of-the-object/m-p/14325580/highlight/true)
- For anime, avoid hue-only correctors when removing a colour cast; luminance matters. — [Doom9 forum](https://forum.doom9.org/archive/index.php/t-167027.html)

### Inferences
- [ESTIMATE] Common edit CC stack:
  1. Levels to set black and white points.
  2. Curves with a gentle S curve (+10-20% contrast).
  3. Vibrance/saturation +10-30.
  4. Optional LUT at 30-70% opacity (teal-orange, desaturated "cinematic", or a high-contrast "dark" look).
  5. Glow pass 1: threshold about 60-80%, small radius.
  6. Glow pass 2: wide radius with low intensity.
  7. Optional grain and vignette.
- On hits, editors often briefly animate exposure or glow intensity up.

### Gaps
- No 2024-2026 text source gave a definitive AMV CC preset with numbers. Most grading tutorials are video-only.
