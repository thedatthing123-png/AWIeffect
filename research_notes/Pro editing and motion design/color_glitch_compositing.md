# Color Grading, Glow, Glitch and Compositing for Anime Edits / AMVs / Motion Graphics

Note on sources: web results for this topic were dominated by vendor blogs, plugin docs and forum threads. Few pages gave hard numbers. Every number below that has a citation came from that source. Numbers under "Inferences" are practitioner rules of thumb that I could not source, so they are labeled as such.

## Color grading for edits (contrast, split toning, palettes, matching, LUTs, saturation, per-section CC)

### Takeaway
Grade in two passes. First, a correction pass: balance exposure and casts, and match shots using the waveform, RGB parade and vectorscope. Then a look pass: split toning or a limited palette such as teal/orange (cool shadows, warm highlights), with saturation held back. Oversaturation and over-contrast are the most common errors cited.

### Cited Findings
- Split toning adds one color to the shadows and another to the highlights, and leaves the midtones mostly untouched — [Darkroom guide](https://darkroom.co/help/guide/color-grading-mood.md); [Blender Split Toning node](https://docs.blender.org/manual/uk/dev/compositing/types/creative/split_toning.html)
- Teal/orange works because the two sit opposite each other on the color wheel. Teal goes in the shadows and orange in the highlights. Skin, which is warm, then stands out against cool surroundings — [Zoner: teal & orange](https://learn.zoner.com/color-grading-step-by-step-iii-how-to-get-the-popular-teal-orange-look/)
- Use the Balance control to choose how much of the image reads teal versus orange. Lower the saturation if the split feels aggressive. Watch skin tones — [Zoner](https://learn.zoner.com/color-grading-step-by-step-iii-how-to-get-the-popular-teal-orange-look/)
- Scope roles: waveform for exposure and clipping, RGB parade for color casts, vectorscope for hue, saturation and skin — [DaVinci Resolve Club](https://davinciresolveclub.com/davinci-resolve-scopes-explained/); [Larry Jordan](https://larryjordan.com/articles/how-to-read-video-scopes/)
- The skin tone line sits at about 11 o'clock on the vectorscope, between R and Y. A fast way to match shots is to mask the face and line up the skin cluster of each shot on that line — [Videomaker](https://www.videomaker.com/how-to/editing/color-correction/what-are-vectorscopes-and-why-are-they-important/); [Creative COW](https://creativecow.net/?p=379361)
- Caveat: the line is a convention, not a target. On an uncalibrated monitor, pushing skin exactly onto it read as green — [Creative COW](https://creativecow.net/?p=1982922); [pixls.us discussion](https://discuss.pixls.us/t/vectorscope-skin-tone-indicator-and-other-improvements/25446/33)
- Oversaturation is among the most frequent grading errors. It looks artificial and gives a "distracting and jarring" palette. It often comes paired with over-contrast — [c-istudios](https://c-istudios.com/common-color-correction-mistakes-and-how-to-avoid-them-in-tv-and-film); [TechBullion](https://techbullion.com/common-mistakes-in-color-grading-and-how-to-avoid-them-a-guide-for-video-editors/)
- Check neutrals and skin first, use reference images, and take a break before the final review because eyes adapt — [TechBullion](https://techbullion.com/common-mistakes-in-color-grading-and-how-to-avoid-them-a-guide-for-video-editors/); [Creative COW](https://creativecow.net/?p=1982922)
- Colorists handle out-of-gamut or oversaturated colors with targeted saturation compression rather than a global slider — [MixingLight: fixing oversaturated colours](https://mixinglight.com/color-grading-tutorials/fixing-saturation-baseligh-look/)

### Inferences
- For anime sources, which are flat-shaded and already saturated, the skin-line method still works on character faces. But most of the "look" should come from shadow/highlight tints and contrast curves, not from adding saturation.
- Pipeline (rule of thumb, unsourced): (1) normalize each clip with levels/curves and remove casts; (2) one adjustment layer for the global look (gentle S-curve, split tone); (3) per-section variants of that adjustment layer. For example: verse desaturated/cooler, build adds contrast, drop goes full palette or monochrome plus accent.
- Monochrome plus one accent color is a limited-palette version of the same idea. Desaturate everything except one hue range, such as the character's eyes or a red element. It reads strongly on drops.
- Apply LUTs as a look layer after correction, at reduced opacity. A LUT on uncorrected, mismatched clips magnifies the mismatch.

### Gaps
- I found no AMV-specific source on grading per song section, or on matching clips from different anime studios.
- No sourced numeric values for S-curve strength, split-tone hue angles or saturation limits. LUT best practice was not covered by a fetched source.
- Lowepost was not reached.

## Glow and light (deep glow, core + halo, light wrap, leaks, bloom)

### Takeaway
A good glow is a thresholded, desaturated, blurred copy added back over the untouched original. Pros layer a tight core with a wide halo and keep the source crisp. Glow everything, or glow without a threshold, and you get the blown-out amateur look.

### Cited Findings
- Manual glow: duplicate the layer. Use Levels to crush the blacks, which acts as the threshold. Add Fast Blur. Desaturate it with Hue/Saturation so it doesn't oversaturate the colors. Optionally mask it. Composite with CC Composite set to "Add" over the original — [School of Motion](https://www.schoolofmotion.com/blog/glows-after-effects)
- In 32-bit, enable "Clip to Output Black" in Levels so negative values don't darken the image — [School of Motion](https://www.schoolofmotion.com/blog/glows-after-effects)
- Inner (core) glow is driven by pixels above a Glow Threshold. Outer halo uses the alpha edge, so the core stays intact. Edges are about 1 px of anti-aliasing, so feather or blur first to give the halo material to work with — [ProVideo Coalition](https://www.provideocoalition.com/classic-course-glow-effect/)
- Deep Glow (Plugin Everything) is GPU-based with physically based falloff — [Toolfarm](https://toolfarm.com/buy/plugin_everything_deep_glow)
- If the glow clips at the layer bounds, put Grow Bounds above Deep Glow, at about 2x the glow radius — [Adobe Community](https://community.adobe.com/t5/after-effects-discussions/deep-glow-effects-extends-all-the-way-to-the-canvas-boundary/m-p/13858274)
- Light wrap: blur a strip of the background and feather it onto the subject's edges, using the subject's matte. This simulates background light spilling onto the subject. Overdoing it makes footage soft and unconvincing — [PremiumBeat](https://www.premiumbeat.com/blog/what-is-light-wrapping-tips-tutorials)
- Light wrap starting values from one vendor: wrap width 50%, intensity 100%, Screen blend, blur matched to the edge softness — [Vindral docs](https://composer.docs.vindral.com/docs/light-wrap)

### Inferences
- Core + halo stack (rule of thumb, unsourced): core blur radius about 5–15 px at high intensity, halo about 60–200 px at low intensity (10–30%). Both use a threshold so only highlights bloom. Tint the halo slightly toward the scene's light color.
- Light leaks and bloom go on top in Screen or Add, timed to accents, and fade out in about 8–20 frames instead of sitting static.

### Gaps
- None of the fetched sources gave exact blur or threshold numbers. Video Copilot / Red Giant pages were not reached.

## Glitch design (types, intentional timing, restraint, frame counts)

### Takeaway
Glitches read as intentional when they come in short bursts locked to audio accents, with clean frames between them. They read as accidental when they run continuously. Each type has its own mechanism: slice, RGB split, datamosh, pixel sort, VHS.

### Cited Findings
- Alternating clean frames with brief glitch bursts beats constant maximum distortion — [Videobolt](https://blog.videobolt.net/post/glitch-effect-in-your-videos)
- Red Giant Glitch exposes a frequency setting: 100% means glitches on almost every frame, 50% on half of them — [Maxon Universe Glitch docs](https://help.maxon.net/rg/en-us/Content/html/glitch.html.md)
- Random glitches on 60 fps footage changed every frame and felt twice as fast. The fix was holding each glitch state for several frames — [Adobe Community](https://community.adobe.com/t5/after-effects-bugs/single-frame-glitch/idi-p/15139320)
- What separates intentional from cheap is how the displacement ramps in and out (the timing curves) — [Freevisuals](https://www.freevisuals.net/templates/premium-dynamic-glitch-text-animations-and-modern-lower-thirds)
- Glitch templates are pre-timed, so retiming the clip breaks them — [Videobolt glossary](https://videobolt.net/motion-graphics-glossary/glitch-effect)
- Datamosh: delete the I-frame and the P-frame motion data smears onto the previous image, which gives a bleeding transition. Duplicating P-frames gives blooming trails. It needs motion-heavy footage. Mobile options: MoshUp (iOS), Supermosh (browser) — [SpotlightFX](https://spotlightfx.com/blog/what-is-datamoshing)
- Pixel sort sorts pixels along one axis above a threshold, and the threshold sets how much of the image is affected — [Superhive Pixel Sort docs](https://superhivemarket.com/products/pixel-sort/docs)
- RGB split separates the R, G and B channels. Slice shifts horizontal bands, often layered with chromatic aberration — [Boris FX](https://borisfx.com/blog/how-to-make-a-glitch-effect-in-photoshop/)

### Inferences
- Frame counts (rule of thumb, unsourced, assumes 24–30 fps): bursts of 2–6 frames on snares and hits. Hold each random state 2 frames ("on twos"). Allow up to about 8–12 frames on a big drop. At least about 1 second of clean picture between bursts in calm sections.
- Escalate by song section: subtle RGB offset of about 2–6 px in the verse, then slices plus RGB split at the build, then datamosh or pixel-sort transitions only at the drop.

### Gaps
- No sourced frame-count standards. VHS and digital-noise specifics were not fetched.

## Compositing (integrating cutouts, blend modes, adjustment layers, precomps)

### Takeaway
To make a cutout sit in a scene, degrade it to match the plate: match light direction, color, contrast, grain, edge softness, depth of field and shadows. Then add a light wrap. Keep the stack organized with adjustment layers and precomps.

### Cited Findings
- After a clean key or cutout: match grain, match depth of field, then light wrap — [Adobe Community](https://community.adobe.com/t5/after-effects-discussions/effect-s-to-use-for-my-greenscreen/m-p/10307681)
- Match light direction, intensity and color, and shadow softness. Lighting and shadows decide whether a composite reads as real — [Noble Desktop](https://nobledesktop.com/learn/after-effects/the-importance-of-lighting-and-shadows-on-compositing-in-adobe-after-effects)
- Clean CG and cutouts look fake because they lack microtexture and grain. Sample grain from the plate and add it last — [Vitrina](https://vitrina.ai/blog/advanced-compositing-techniques-seamless-vfx-integration/)
- Make the wrap stronger on edges facing bright background areas and weaker on dark sides — [Beverly Boy](https://beverlyboy.com/film-technology/light-wrap-problems-how-to-add-softness-without-flatness)
- Keyed or masked edges need softening and refinement to look real — [ProVideo Coalition](https://www.provideocoalition.com/tool-tip-tuesday-for-adobe-premiere-pro-getting-your-mask-key-to-look-real/)

### Inferences
- Blend modes (standard usage): Screen or Add for glows, leaks and light. Multiply for shadows and paper textures. Overlay or Soft Light for texture and grain. Color for tinting.
- Organization (unsourced): precomp per shot, or per character plus BG. Global grade on top as an adjustment layer. Grain as the very last layer, so everything shares one grain.

### Gaps
- School of Motion / Video Copilot compositing courses were not fetched. No numbers for edge feather.

## Amateur mistakes vs pro habits

### Takeaway
The amateur signals are oversaturation, crushed contrast, too many effects at once, a different grade on every clip, and untouched default effect settings. Pros use restraint, check on scopes, give each section one coherent look, and time effects to the music.

### Cited Findings
- Oversaturation and over-contrast are the most prevalent errors — [TechBullion](https://techbullion.com/common-mistakes-in-color-grading-and-how-to-avoid-them-a-guide-for-video-editors/)
- An overdone light wrap looks soft and fake — [PremiumBeat](https://www.premiumbeat.com/blog/what-is-light-wrapping-tips-tutorials)
- Constant glitching is weaker than bursts — [Videobolt](https://blog.videobolt.net/post/glitch-effect-in-your-videos)
- Rest your eyes before the final color decisions — [Creative COW](https://creativecow.net/?p=1982922)

### Inferences
- Pro habits: grade on an adjustment layer rather than per clip. A/B against the ungraded picture. Glow only the highlights. Use one grain pass. Escalate effects with the song structure.

### Gaps
- No r/AMV or r/AfterEffects threads were fetched. Community-specific critique norms are unsourced.
