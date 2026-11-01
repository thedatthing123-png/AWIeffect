# Manga Edit Styles (Haiko, Gokuponch, Bri, Mutioke + the "manga edit" genre)

Method note: I ran 8 web searches and 3 fetches. The open web indexes TikTok, YouTube and Instagram edit content poorly. Results were dominated by SEO mirror pages (old.fbpe.org and similar, one of which refused connection), Fiverr listings and CapCut template pages. I found **no indexable source for any of the four named creators**. Items under "Inferences" are practitioner genre knowledge that I could not source on the web, and they are labeled as unsourced. Treat them as hypotheses to check against the creators' actual videos.

## 1. What visual signatures distinguish Haiko vs Gokuponch vs Bri vs Mutioke?

### Takeaway
The web has no citable material on any of the four. Searches for "Gokuponch manga edit", "Haiko manga edit tiktok" and "Mutioke"/"Bri" manga edit returned only unrelated manga titles (Gokicha, Haikyuu) and book listings. Any comparison between these creators has to come from watching their profiles directly.

### Cited Findings
- A search for "Gokuponch manga edit" returned no creator match. The closest results were the manga titles *Gokicha* and *Gokujou Oyaji* — [MyAnimeList](https://myanimelist.net/manga/22597/_)
- A search for "Haiko manga edit" returned only Haikyuu CapCut templates — [CapCut Haikyuu templates](https://www.capcut.com/explore/haikyuu-edit?page=1)
- Searches for "Mutioke"/"Bri" plus manga edit returned nothing relevant (book listings only) — [Manga News](https://www.manga-news.com/index.php/auteur/MUTSUTAKE)
- Fanlore defines the genre loosely: a "TikTok edit" is a fan-made video edit set to music, posted to TikTok, Instagram or Twitter — [Fanlore](https://fanlore.org/wiki/TikTok_edit) (seen in search snippet only; the page returned 403 on fetch)

### Inferences
- Unsourced: the manga-edit scene usually splits into two camps. The "clean / cinematic" camp uses slow panel pushes, parallax, paper grain and soft glows. The "hype / velocity" camp uses dense shakes, negative flashes and impact frames on every beat. The named creators most likely sit at different points on that spectrum, but I cannot confirm which.

### Gaps
- No per-creator signatures, handles, apps or presets could be verified. Next step: open each creator's TikTok/YouTube profile directly (the app's built-in browser can do this) and log 3 to 5 edits each.

## 2. How do editors turn a static panel into motion?

### Takeaway
Sourced material confirms only the core idea: split the panel into multiple planes (characters, background, effects) and move them at different speeds for parallax. Tutorials exist for both Alight Motion (with Ibis Paint X for cutouts) and After Effects (with Photoshop), but I could only see their titles.

### Cited Findings
- A tutorial titled "How to animate MANGA PANELS on Alight Motion for FREE | Tutorial | Ibis Paint X & Alight Motion" pairs Ibis Paint for cutting out layers with Alight Motion for animating them — [fbpe link list](https://old.fbpe.org/manga-animation-tutorial-alight-motion.html)
- Other After Effects tutorial titles found: "Basic Manga compositing + animation | After Effects AMV Tutorial" and "Full In Depth Manga Animation Tutorial (After Effects & Photoshop)" — [fbpe link list](https://old.fbpe.org/tutorial-manga-animation-after-effects.html)
- Parallax principle: background elements move slower than foreground elements. A studio case study used "the multiple planes technique in After Effects" — [AEJuice](https://aejuice.com/blog/how-to-create-a-parallax-effect-in-after-effects); [ArtStation case](https://gustozoh.artstation.com/projects/n00DzE)
- AE puppet-style tools such as the iExpressions parallax for 2D backgrounds — [aescripts](https://aescripts.com/learn/iexpressions-2-character-animation-tutorial-series-bonus-part-8--parallax-effect-for-scrolling-2d-backgrounds)
- CapCut publishes "manga panel animation edit" templates — [Pippit/CapCut](https://pippit.capcut.com/templates/manga-panel-animation-edit)

### Inferences (unsourced genre workflow)
1. Clean or upscale the panel scan, and remove speech bubbles and text where needed.
2. Cut the character, the foreground effects (debris, speed lines) and the background into separate layers (Ibis Paint or Photoshop lasso/AI select). Fill the hole behind the character with content-aware fill or cloned screentone.
3. Stack the layers in 2.5D. A slow push-in or a scale of about 100 to 110% across the shot, with the foreground moving faster, gives parallax.
4. Add life with a puppet/mesh warp on hair and cloth, a small looping sway, eye glows, and particles or dust.
5. Overlay a scrolling speed-line or ink-line texture plus paper grain or halftone to keep the printed-manga feel.
6. Cut to the beat with shakes and flashes (section 3).

### Gaps
- No tutorial transcript with exact keyframe values was retrievable.

## 3. Shake, flash, glitch and velocity patterns on beats and drops (timing)

### Takeaway
The only sourced items are that impact frames last "a split second", flashes can be built from white solids or overlays, and shakes and velocity are applied per beat. No source gave exact frame counts.

### Cited Findings
- Impact frames are a 2D animation technique that "appear for a split second" and use sharp contrast and exaggerated poses. They are linked to Yutaka Nakamura. They went viral in January 2023 (Vincent Chansard, *One Piece* Wano) and again as a meme trend in July 2023 — [Know Your Meme](https://knowyourmeme.com/memes/cultures/impact-frames)
- An impact-frame preset pack lists "Darken Background" and "Flash Frame" as its filters, which suggests darken plus flash layering — [Panther Dynamics](https://pantherdynamics.yolasite.com/panther-dynamics-blog/page/2)
- One tutorial comment says impact frames "really should be short lived" unless they are detailed — [ccum mirror](https://new.ccum.net/impact-frames-tutorial-more.html)
- CapCut velocity: Edit > Speed > Curve presets (Montage, Hero, Bullet, Jump Cut, Flash In, Flash Out). The Custom curve has 5 adjustable beat points — [CapCut](https://www.capcut.com/resource/how-to-do-velocity-on-capcut); [Shotkit](https://shotkit.com/velocity-capcut/)
- CapCut flash: use a white stock clip, a flash overlay, or a contrast spike. Shake: split the clip at each beat and apply or copy the Shake effect on each segment — [FlexClip](https://www.flexclip.com/learn/how-to-do-the-shake-effect-on-capcut.html); [VideoProc](https://www.videoproc.com/video-editor/how-to-make-a-velocity-edit.htm)
- A common combined template trend is "velocity x flash x shake x reverse" — [CapCut](https://www.capcut.com/explore/velocity-x-flash-x-shake-x-reverse)
- Alight Motion shake presets circulate as shared links. One search result warns that "copy the link" schemes are a common malware vector — [search result via postecards mirror](https://postecards.poste.it/bold-stats/alight-motion-shakes-get-the-ialight-link-1767648748)

### Inferences (unsourced, practitioner norms)
- Hit shake: a sharp spike for 2 to 4 frames at 30fps (4 to 8 at 60fps) that decays over about 6 to 10 frames, with motion blur on.
- Negative or mono flash: 1 to 2 frames of inverted or pure black-and-white on the downbeat, often alternating with 1 normal frame (a "strobe") on drops.
- Impact frame: 2 to 4 frames of high-contrast red/black or inverted silhouette.
- Zoom punch: scale +10 to 20% on the beat, easing back over about 8 frames.

### Gaps
- No primary source gives frame-exact timings. These need to be measured from creator videos by stepping frame by frame.

## 4. Text, SFX and typography treatments

### Takeaway
I found no sourced specifics.

### Cited Findings
- None found in the sources I could index.

### Inferences (unsourced)
- Common treatments: original Japanese SFX kept and animated (scale pop, shake), bold condensed or brush fonts, single words revealed per beat, text with a thick stroke and a glow, and kanji overlays.

### Gaps
- Fonts and text presets used by the named creators are unknown.

## 5. Apps and effect stacks

### Takeaway
Alight Motion (mobile, with preset links and XML), CapCut (velocity, shake and flash presets and templates) and After Effects with Photoshop are all confirmed tools for manga and anime edits. Ibis Paint X is confirmed for cutouts.

### Cited Findings
- Alight Motion with Ibis Paint X for manga panels — [fbpe](https://old.fbpe.org/manga-animation-tutorial-alight-motion.html)
- After Effects with Photoshop for manga animation — [fbpe](https://old.fbpe.org/tutorial-manga-animation-after-effects.html)
- CapCut velocity, shake and flash plus manga templates — [CapCut](https://www.capcut.com/resource/how-to-do-velocity-on-capcut); [Pippit](https://pippit.capcut.com/templates/manga-panel-animation-edit)
- Freelance anime editors advertise "Advanced Effects (Shakes, Transitions, Overlays)" as their standard stack — [Fiverr](https://fiverr.com/flowzer410/do-clean-anime-edits-for-tiktok)

### Inferences
- Unsourced: a typical AE stack is S_Shake or a wiggle expression, Twixtor or a time remap for velocity, Deep Glow, CC Lens/Optics Compensation, Turbulent Displace for ink wobble, and grain or halftone overlays.

### Gaps
- Color treatment (black-and-white vs selective color, eye and hair glows) and music choice (phonk, slowed/sped audio) had no indexable sources.
