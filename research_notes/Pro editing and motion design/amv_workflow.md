# Pro AMV / anime / manga edit workflow (song to finished edit)

Scope note: this file adds to `reports/Manga edit and AMV craft.md`, which already covers frames-per-beat math, velocity 200%/20% with scale 100-130-100, the 1 sec/sec at 33.33% influence fix for time-remap stalls, S_Shake defaults, the 4-5 frame white flash, groups-of-4 phrasing, parallax and the Haiko/Gokuponch gap. The focus here is workflow order, decision rules, vibe translation and reference study. Web sources on AMV craft are thin and many search hits were SEO spam pages, which I excluded. r/amv wiki pages and the kh-vids help thread returned 502/403/404, so community material comes from search snippets only. Anything without a URL is under Inferences or Gaps.

## Song mapping (BPM, beats, sections, drops, which beats get cuts vs effects, half/double time)

### Takeaway
Map the song before any clips go in: split it into sections, mark beats and off-beats, then decide which moments need exact sync. Sources agree the music should guide cuts but not dictate every one.

### Cited Findings
- Recommended order: make a "sync map" first instead of relying on a beat-detect button. Mark the visual anchors, identify the track's beats and phrases, then decide which moments need exact alignment — [Sonilo](https://sonilo.com/blog/guides/how-to-make-video-sync-with-music)
- Breaking the song into its basic structure with rough cuts gives "a quick overview of its dynamic differences". Add markers to beats and off-beats while listening — [Filmdaft](https://filmdaft.com/how-to-edit-video-clips-to-the-beat-of-music-the-easy-way/)
- Automatic tools: BeatEdit (mamoworld) detects beats, writes markers in Premiere and passes them to After Effects — [aescripts](https://aescripts.com/learn/tag/BeatEdit-for-Premiere-Pro/); [Toolfarm](https://www.toolfarm.com/?p=29233). Premiere's marker workflow is "drop markers... Automate to Sequence" — [Adobe](https://www.adobe.com/learn/premiere-pro/web/edit-music-video)
- Hybrid method: mark beats by hand, let an auto-cut tool propose cuts, then adjust by ear — [Splice blog](https://spliceapp.com/blog/what-is-good-for-beat-synced-edits)
- Music is "a guide" and should not control every cut. A borrowed EDM shape: build, add layers, crescendo, breakdown, rebuild — [Dream Engine](https://www.dreamengine.com.au/tips-and-resources/learning-the-art-of-video-editing/)
- Most AMVs time their visuals to the lyrics, because lyrics are an easier reference to cut against — [Utrecht thesis on AMV/animemusicvideos.org](https://studenttheses.uu.nl/handle/20.500.12932/37631)

### Inferences
- Workflow order: (1) listen 3+ times, (2) write section timestamps (intro/verse/build/drop/break/outro), (3) mark downbeats on bar 1 of each phrase, (4) mark accents such as snares, vocal hits and risers separately from beats, (5) only then cut.
- Decision rule from the sources' "decide which moments need exact alignment": cuts go on downbeats and phrase starts, effects go on accents and off-beats. A drop gets both.
- Half-time and double-time follow from the frames-per-beat formula. At 24 fps and 140 BPM a beat is about 10.3 frames, so cutting every beat runs about 10 frames per shot, half-time about 21, and double-time about 5 (practical only as strobe flashes).

### Gaps
- I found no sourced numbers for how many beats or bars named editors give each shot per section.

## Clip selection and scene choice (energy match, match cuts, motion direction, overused clips, organization)

### Takeaway
Clip choice follows motion continuity. Cut during movement, keep the eye-trace point in the same screen area, and continue the outgoing trajectory. Footage that is mismatched in framing or motion can't be rescued with effects.

### Cited Findings
- Cutting during motion lowers how much viewers notice the edit, and motion after the cut matters more than motion before it — [Smith & Martin-Portugues Santacreu, UAL](https://ualresearchonline.arts.ac.uk/id/eprint/21152/2/4592cb6f-bad6-4ef9-a488-be3cb33fee43.pdf)
- For a motion match the incoming shot continues the outgoing trajectory. Editing can refine a match but can't rescue incompatible framing or motion. Test a few neighboring frames and keep the best one — [CapCut match cut](https://www.capcut.com/create/match-cuts-seamless-scene-transitions)
- Eye trace means keeping the key detail in the same screen area across a cut (a term from Murch's tradition) — [CineD](https://cined.com/mastering-match-cuts-a-deep-dive-into-seamless-storytelling/); [Adobe continuity](https://www.adobe.com/creativecloud/video/hub/ideas/what-is-continuity-editing-in-film)
- Pick a song that fits the clips, ideally with lyrics that relate to them — [Kanzenshuu forum](https://www.kanzenshuu.com/forum/viewtopic.php?p=8463)
- "Not being original" is listed as music video mistake #1 — [No Film School](https://nofilmschool.com/2017/09/5-music-video-editing-mistakes-and-how-fix-them)
- Organize media into groups in Alight Motion — [low-quality page, treat with caution](https://postecards.poste.it/bold-stats/timli-video-editing-with-alight-motion-easy-steps-1767648835)

### Inferences
- Rule: tag clips by motion direction (L→R, R→L, toward or away from camera), energy (still, mid, explosive) and shot size. Pull drop clips only from the explosive bin and cut them on matching or opposing vectors.
- Avoid overused clips by skipping the series' most famous fight frames, or by recontextualizing them with a speed ramp or crop.

### Gaps
- I found no source on scenepack conventions, clip-bin naming, or a list of which anime clips the community considers overused.

## Velocity / speed ramps, Twixtor, frame holds

### Takeaway
The earlier report covers velocity graphs. Twixtor's settings are documented: input fps equal to source fps, Time Remap Mode set to Speed (or Frame Number for per-frame keys), Speed% = 100 / duration factor, and Motion Sensitivity traded between warping and blending.

### Cited Findings
- Twixtor: set Display to Twixtored Output and Input Frame Rate to the comp/source fps (a wrong value causes stutter). Time Remap Mode = Speed. Speed 50% gives half speed. Lower Motion Sensitivity to reduce warping, raise it to reduce blending, and keyframe it if you have both problems. Twixtor Pro allows up to 12 track points. When speeding up, extend comp length or the last frame repeats — [Boris FX](https://borisfx.com/blog/twixtor-after-effects-how-to-step-by-step-guide/); [Videomaker](https://www.videomaker.com/how-to/editing/visual-effects/how-to-use-twixtor-to-slow-down-your-footage/)
- Speed% = 100/2 = 50% for 2x duration and 100/0.5 = 200% for 0.5x. Frame Number mode is for frame-by-frame keying — [Twixtor reference via Creative Cow/Scribd](https://es.scribd.com/document/125743717/Twixtor-FCP-X)
- Conversion example: 60p footage in a 23.976 comp, input slider 59.94 — [Creative Cow](https://creativecow.net/?p=1301009)
- Ghosting is hard to fix with settings alone — [Creative Cow](https://creativecow.net/forums/thread/twixtor-problem-3/)

### Inferences
- Anime is often animated on 2s or 3s, so the source has about 12 or 8 unique frames per second. Interpolators then warp between held drawings. Pick clips with camera pans or animation on 1s for Twixtor, and use frame holds plus shake on limited-animation clips. This is unsourced practitioner reasoning, so verify it.

### Gaps
- I found no sourced numbers on hold lengths for freeze-frame hits.

## Cut types, transitions, shakes, flashes, overlays, overuse

### Takeaway
Community consensus is that sync and timing outrank effect count. Effects need a reason, beginners should learn the basics before stacking presets, and deliberate excess is fine when it builds an aesthetic.

### Cited Findings
- "Don't use too much effects": when you are new, effects "will just spoil it all" — [Fanlore, How to be a PERFECT VIDDER](https://fanlore.org/wiki/How_to_be_a_PERFECT_VIDDER)
- VHS effects "just distract" when there is no reason for them — [r/amv feedback megathread 2020 (mirror)](https://redlib.ssps.io/r/amv/comments/gbe7nq/feedback_megathread_may_2020)
- There is no requirement to "compensate" for anything with effects. Most AE AMV tutorials "just show one effect" and don't teach the software — [r/amv Q2 2024 megathread (mirror)](https://lr.sudovanilla.org/r/amv/comments/1d4z9ky/feedback_megathread_q2_2024); [r/amv help (mirror)](https://nyc1.lr.ggtyler.dev/r/amv/comments/1h915gn/amv_help)
- Overdone effects and overdone grades are both listed as mistakes, and either is acceptable if intentional (e.g. "All of the Lights") — [No Film School](https://nofilmschool.com/2017/09/5-music-video-editing-mistakes-and-how-fix-them)
- Smoothing velocity stutter: smooth the curve, reduce scale jumps, add light motion blur — [low-quality aggregator](https://postecards.poste.it/bold-stats/timli-video-editing-with-alight-motion-easy-steps-1767648835)

### Inferences
- Budget rule: save the heaviest effect stack for the drop, so the drop contrasts with the build.

### Gaps
- Typical frame lengths for whip, spin and zoom transitions, glitch cuts and shake decay are not in any reachable source beyond the earlier report's flash (4-5 frames) and S_Shake defaults.

## Manga edit specifics

### Takeaway
I found nothing new beyond the earlier report (parallax depth planes, paper texture, per-beat panel life).

### Cited Findings
- None new.

### Gaps
- Speed-line, halftone and panel-push recipes with numbers: searches returned only template and spam pages.

## Translating vibe into pacing, color, effects

### Takeaway
Shot length and tension/release are the main levers. Short shots, tight framing and rising intensity build tension. Long shots, soft sound and negative space release it. Slow pacing reads as drama or reflection, fast pacing as action.

### Cited Findings
- Build tension with faster cuts, tighter framing and more sound intensity. Release with a longer shot, softer sound or negative space. Holding one energetic pitch too long loses attention — [Dream Engine](https://www.dreamengine.com.au/tips-and-resources/learning-the-art-of-video-editing/)
- Slower pacing for drama or reflection, faster for action or energy — [Mubert](https://mubert.com/blog/how-to-match-music-with-video-pacing)

### Inferences
- A starting mapping (unsourced): sad means half-time cuts, long dissolves, desaturated or cool grade, sparse soft shakes. Hype means beat or double-time cuts, flashes, impact shakes, high contrast. Dreamy means slow push-ins, glow and bloom, light leaks, pastel lift. Dark means crushed blacks, red or teal accents, glitch and RGB split on accents.

### Gaps
- I found no source tying moods to specific grade values or effect frequencies.

## Studying reference edits frame by frame; personal style; amateur vs pro

### Takeaway
Check the edit by watching it once muted, for visual rhythm, then again with sound. Make a few videos before asking for critique, and learn the software instead of copying single-effect tutorials.

### Cited Findings
- Watch once muted to judge visual rhythm, then with sound, and confirm viewers have time to absorb key details — [Dream Engine](https://www.dreamengine.com.au/tips-and-resources/learning-the-art-of-video-editing/)
- After about 3-4 videos, ask for advice. Learn the software rather than single-effect tutorials — [r/amv help (mirror)](https://nyc1.lr.ggtyler.dev/r/amv/comments/1h915gn/amv_help)
- Feedback megathreads are r/amv's main critique venue — [r/amv Q2 2024 (mirror)](https://lr.sudovanilla.org/r/amv/comments/1d4z9ky/feedback_megathread_q2_2024)
- Work within a familiar structure and add an unexpected moment — [Dream Engine](https://www.dreamengine.com.au/tips-and-resources/learning-the-art-of-video-editing/)

### Inferences
- Frame-by-frame study method (unsourced): import the reference, add a marker at every cut and hit, export the marker list, and compute frames between hits and their position relative to the beat grid. This is how to recover the creator signatures the earlier report flagged as missing.

### Gaps
- I found no written breakdowns of named editors' styles, and no documented pro study routine. Real tutorials are video-only on YouTube or TikTok and can't be indexed here.
