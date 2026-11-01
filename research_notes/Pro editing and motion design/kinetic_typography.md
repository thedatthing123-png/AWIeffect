# Kinetic Typography and Text Animation (AE / Alight Motion, anime edits, AMVs)

Note: Web sources for AMV-specific text technique were weak (mostly SEO/template pages). Core numbers below come from Adobe, subtitle standards, Butterick and motion-design guides; AMV-specific items are flagged.

## Per-character / per-word animators and common recipes

### Takeaway
The AE text animator model is: animator properties (position/scale/opacity/blur/tracking/fill) + a Range Selector that sweeps across characters/words/lines. Using the Ramp shape with Ease High/Low around 50% (or Ease Low 100%) turns blocky cascades into smooth ones. Randomize Order and the Wiggly selector add the "decode/glitch" look.

### Cited Findings
- Add with Animate > Add Text Selector > Range. Main controls are Start, End and Offset. Advanced > Based On sets characters, words or lines. Keyframing Offset sweeps the effect — [PremiumBeat](https://www.premiumbeat.com/blog/animate-individual-letters-in-after-effects/)
- The default Square shape "gives a choppy, blocky look". Switch to Ramp Up and set Ease High and Ease Low to about 50% — [PremiumBeat](https://www.premiumbeat.com/blog/animate-individual-letters-in-after-effects/)
- Ease High/Low set how each character moves between fully selected (high) and unselected (low). Ease Low 100% gives a soft landing. Easing the Start/End/Offset keyframes is different: it changes how fast the selector sweeps, not how each character moves — [ProVideo Coalition, CMG Hidden Gems ch.21](https://www.provideocoalition.com/cmg_hidden_gems_chapter_21_textacy/)
- Randomize Order keeps the same timing but shuffles which characters go in what order. Random Seed picks a different shuffle — [ProVideo Coalition](https://www.provideocoalition.com/cmg_hidden_gems_chapter_21_textacy/)
- Forum recipe: Ease Low 100%, Ease High -100%, Randomize Order on, plus motion blur — [Creative COW](https://creativecow.net/?p=127128)
- Decode/scramble: animate Character Offset under a Range Selector so random characters resolve into the word. Add a Wiggly selector for randomness. Expression selector (selectorValue) + Wiggly makes characters flash on and off at random — [Adobe text animation examples](https://helpx.adobe.com/au/after-effects/desktop/animating-text/text-animation-examples/examples-resources-text-animation.html) (page returned 403 to fetch; summary from the search snippet); [Adobe Community](https://community.adobe.com/t5/after-effects/decoder-expression-linear-to-random-resolution/td-p/11033156)
- Scale pop with overshoot: scale 0 → about 110% in about 10 frames → 100% a few frames later, eased — [Creative COW](https://creativecow.net/?p=224621). In Alight Motion, use a custom easing curve that passes the end value and settles back. Stagger lines by a few frames — [Alight Creative blog via search snippet](https://alightcreative.com/blog/top-animation-techniques) (page now 404)
- Text reveal timing guide: 15–25 frames with ease-out. Secondary elements settle 4–8 frames after the main one — [skillsdirectory guide](https://www.skillsdirectory.com/skills/nodetool-ai-motion-principles) (secondary source)
- Easing rule: ease-out for things entering, ease-in for things leaving, ease-in-out for moves between points — [CodePen, Rach Smith](https://codepen.io/rachsmith/post/lets-talk-about-ease-please)

### Inferences
- Recipes as animator + selector settings (my synthesis, not from one source):
  - Rise: Position Y +40–80px and Opacity 0, Ramp Up, Ease Low 100%, Offset 0→100%.
  - Cascade: the same, plus Based On Words.
  - Typewriter: Opacity 0, Square shape, no ease, Offset stepped.
  - Blur in: Blur 20–40 + Opacity 0 + Tracking +.
  - Tracking expand: keyframe Tracking Amount on a slow ease across the whole hold.
  - Decode: Character Offset 10–30 + Randomize Order.
- Glitch text: a Wiggly selector driving Position X and Character Offset, with Temporal Phase high so it flickers fast.

### Gaps
- No official Adobe numbers for Wiggly defaults (Wiggles/sec etc.) were retrieved. Ben Marriott and Jake in Motion pages were not found in searches.

## Reveals, mattes, text behind objects, path, flicker, glitch, 3D

### Takeaway
To put text behind a subject, cut the subject out (a rotoscope or a duplicate layer) and set it as an Alpha Inverted matte on the text. For a wipe reveal, use a shape-layer matte while the text slides in from inside it.

### Cited Findings
- Behind object: set the text layer's Track Matte to Alpha Matte Inverted with the object layer as the source. If the object moves, a moving layer works as the matte — [AEJuice](https://aejuice.com/blog/how-to-make-transparent-text-in-after-effects); [Adobe Community](https://community.adobe.com/t5/after-effects-discussions/text-reveal-with-an-object-and-text/m-p/15056235)
- Matte reveal: the text hides behind a shape-layer matte until it slides out — [Noble Desktop](https://www.nobledesktop.com/learn/after-effects/text-reveal); [Photofocus](https://photofocus.com/software/tutorials-software/after-effects-easy-text-reveal/); [PremiumBeat matte text](https://www.premiumbeat.com/blog/matte-text-animations-in-after-effects/)
- Alpha vs luma track mattes overview — [Motion Array](https://blog.motionarray.com/?p=12316)
- In AM edits, flicker is often an overlay asset blended at 5–10% with grain at 15–25% — [low-quality SEO page](https://www.posersoftware.com/users/presets-alight-motion) (treat as a lead only)

### Inferences
- Font flicker/swap: toggle 3–5 font variants every 1–2 frames over a 6–12-frame burst on a hit, then land on the final font. This is common AMV practice but I found no source for it.

### Gaps
- No reliable sources for text on path, split-text, 3D text, or flicker frame counts.

## Typography choices, safe areas, readability timing, lyric sync

### Takeaway
Keep text inside the inner 80% (title safe). Give all-caps 5–12% extra tracking. Hold text long enough to read: about 2–3 words per second at most, 20 characters per second for subtitles, and at least 5/6 s (20 frames at 24fps) for any phrase.

### Cited Findings
- Title-safe is the inner 80%, action-safe 90%. AE guides default to the 10% and 20% marks — [ProVideo Coalition](https://www.provideocoalition.com/unsafe_areas/amp/)
- All caps: add 5–12% letterspacing. Lowercase does not need it — [Butterick, Practical Typography](https://practicaltypography.com/letterspacing.html)
- Netflix subtitles: minimum 5/6 s (20 frames at 24fps), maximum 7 s per event — [Netflix Timed Text Style Guide](https://backlothelp.netflix.com/hc/en-us/articles/215758617). At 30fps, scale the frame rules (12 frames → 15) — [Netflix timing guidelines](https://backlothelp.netflix.com/hc/en-us/articles/360051554394-Timed-Text-Style-Guide-Subtitle-Timing-Guidelines)
- English reading-speed limit is reported as 20 cps for adults and 17 for children (third-party reading of the Netflix guide). Japanese guide minimum is 0.5 s — [Netflix Japanese guide](https://backlothelp.netflix.com/hc/en-us/articles/215767517)
- Kinetic type pace: at most about 3 words/s, and hold key actions about 3 s — [SBCC lecture](https://soma.sbcc.edu/Users/Russotti/113/113lect_typeinmotion.html); [SRJC](https://canvas.santarosa.edu/courses/28549/pages/week-11-page-7-kinetic-typography)
- Mobile: use fewer type styles, heavy sans-serif, and intentional line breaks. Cut text by about 30%. Check it muted at phone size — [Hera guide](https://hera.video/blog/kinetic-typography-video-generator-guide)
- Sans-serif reads better in motion than serif — [RMCAD](https://www.rmcad.edu/?p=87077)

### Inferences
- Lyric sync: land the word's first frame on the syllable onset, or 1–2 frames early. Timing it like a subtitle (≥20 frames) keeps it readable, and single-word hits can be shorter because they are read as images.
- Pairing: one heavy display face plus one light or condensed face. JP katakana in a big outline with small EN tracked caps is a common edit look (no source found).

### Gaps
- No sourced rules for JP/EN mixed typesetting in edits.

## Popular edit text styles

### Takeaway
Sourcing here is poor. "Velocity text" is mostly a beat-synced speed-ramped hit or blast animation.

### Cited Findings
- The "Velocity" caption style: bold text that fires onto the screen with blast animations — [Captions.ai](https://captions.ai/styles/velocity)
- AMV vocabulary (Flow, Raw, Typography/Lyrical edits) and "flash + velocity combo" with beat-synced shake in AM presets — [Wikipedia AMV](https://en.wikipedia.org/wiki/Anime_music_video); [preset listing](https://www.posersoftware.com/users/presets-alight-motion/slideshows) (low quality)

### Gaps
- No credible sources on the "aesthetic", outline + fill, or chromatic text recipes.

## Common mistakes

### Takeaway
Too many different animations, type too small for phone, motion that hurts reading, and text that runs too long.

### Cited Findings
- Giving every word a different effect, small type in vertical video, and pretty text that is hard to read — [Hera](https://hera.video/blog/kinetic-typography-video-generator-guide)
- Motion that makes the message harder to understand — [Digital Silk](https://www.digitalsilk.com/web-design/web-trends/kinetic-typography/)
- Constant text motion tires viewers after about 30–90 s — [Pexo](https://pexo.ai/tutorial/how-to-make-a-kinetic-typography-explainer-video)
- Square shape without ease looks blocky — [PremiumBeat](https://www.premiumbeat.com/blog/animate-individual-letters-in-after-effects/)
- All caps without extra tracking — [Butterick](https://practicaltypography.com/letterspacing.html)

### Inferences
- Other likely mistakes: linear keyframes, no motion blur on fast text, text outside the 80% safe area, and holds under 20 frames.

### Gaps
- Pexo's full list of five mistakes was not retrieved.
