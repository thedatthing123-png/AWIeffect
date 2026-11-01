# Motion Design Principles and Easing (AE / Alight Motion practitioner reference)

## How are Disney's 12 principles applied to motion graphics?

### Takeaway
The 12 principles come from character animation. In motion graphics, the ones that matter most are easing (slow in/out), timing, follow-through/overlap and anticipation. Follow-through means parts trailing and settling after the lead part stops. Timing (how many frames) and spacing (how those frames are spread) can't be separated.

### Cited Findings
- The principles are credited to Frank Thomas and Ollie Johnston's *The Illusion of Life* (1981). Some sources date their development to 1930s Disney instead — [Binus DKV](https://binus.ac.id/bandung/dkv/2025/11/03/the-12-principles-of-animation-disneys-secret-formula-for-believable-motion/); [Bloop Animation](https://www.bloopanimation.com/the-12-principles-of-animation/)
- The ones that carry most weight for motion graphics and UI are easing, timing, follow-through/overlap and anticipation (a studio blog, not a primary source) — [Fable blog](https://www.fable.app/blog/12-animation-principles-every-aspiring-motion-designer-should-know) (from search snippet; the page did not load)
- Follow-through and overlap: one part starts first and the others trail. In School of Motion's drummer example, the arm moves, then the hand, then the stick. Parts can keep moving after the lead motion has stopped — [School of Motion: Follow Through](https://schoolofmotion.com/blog/follow-through-tutorial)
- Follow-through shows rigidity and environment. Wobbly objects sway several times before settling. Under water there is more resistance and parts float, while on land they settle faster. Continued motion after a stop tells the viewer how fast the object was going and how hard it stopped — [School of Motion](https://schoolofmotion.com/blog/follow-through-tutorial)
- Overlap in practice: offset the trailing parts so they drag and settle behind the main action — [Animation Mentor](https://www.animationmentor.com/?p=87279)
- Timing is the number of frames, which sets perceived speed and weight. Spacing is how the motion is spread across those frames, which sets acceleration and deceleration — [Animator Survival Kit summary PDF](https://secondnaturejournal.com/ProductPdf/mL178D/600783/Animator%20Survival%20Kit.pdf); [Full Frontal](https://fullfrontal.moe/animation-fundamentals-timing-and-spacing/)
- Richard Williams's book has chapters on timing and spacing, weight, anticipation, "Timing, staggers, wave and whip" and "The Great Ones and Twos Battle" — [UTB catalog TOC](https://vufind.katalog.k.utb.cz/Record/82711/TOC); [Spokane library](https://catalog.spokanelibrary.org/catalog/Record/2a621ae7-9fdb-5380-8b6a-994d5e0f4e5a?lng=ar)
- Motion on curved paths reads as more natural than straight linear paths, even for UI elements (community skill page) — [playbooks.com motion-designer](https://playbooks.com/skills/dylantarre/animation-principles/motion-designer)
- A stepped, hand-animated feel: Posterize Time at 12 fps, holding each frame for about 3 frames in the example — [School of Motion: 3 pro tips](https://www.schoolofmotion.com/blog/3-pro-tips-after-effects-beginners)

### Inferences
- How the principles map to mograph:
  - Anticipation: a small move the opposite way before the main move.
  - Squash/stretch: scale non-uniformly along the direction of motion when it hits and when it is moving fastest.
  - Arcs: give the motion path curved bezier handles.
  - Secondary action: shadows, labels, particles and shakes that react to the main hit.
  - Exaggeration: overshoot amplitude.
- Underwater versus on-land follow-through maps to an inertia or overshoot expression: lower decay means a floatier, "heavier medium" feel.

### Gaps
- No primary School of Motion or Ben Marriott source turned up that gives frame counts for anticipation or squash/stretch percentages.
- Appeal and solid drawing have no concrete mograph-specific rules in the sources found.

## Graph editor practice: speed vs value graphs, influence values, ease shapes, overshoot, when to use linear

### Takeaway
Always ease. Linear keyframes look "stiff and robotic." Start with Easy Ease (F9), then shape the curve:
- Speed 0 with about 75–80% influence gives a slow start, a snappy middle and a soft settle.
- For an exponential "fast out, long settle", use roughly 0% outgoing and 80% incoming, or the reverse depending on direction.
- Keep linear for continuous loops and for keyframes that feed expressions.

### Cited Findings
- School of Motion: linear keyframes move at constant speed, and "your movement will look stiff and robotic if you don't learn the art of easing." Apply Easy Ease with F9 — [SoM: 3 pro tips](https://www.schoolofmotion.com/blog/3-pro-tips-after-effects-beginners)
- In the hidden-swap example, handles were set to about 90% influence instead of 100%, and the change was cut at the fastest point of the move. Abrupt changes hide best at peak speed, not while the motion is slow — [SoM: 3 pro tips](https://www.schoolofmotion.com/blog/3-pro-tips-after-effects-beginners)
- For a thrown object, put the peak speed at the start of the move. Easing the start of something that should launch fast is a beginner mistake — [SoM: 3 pro tips](https://www.schoolofmotion.com/blog/3-pro-tips-after-effects-beginners)
- Joey Korenman (SoM) prefers the value graph to the speed graph because it is easier to read. In the value graph, steeper means faster and flat means still. He eases every keyframe first, separates dimensions for position so X and Y can be shaped independently, holds Shift to lock handle direction, and pulls handles longer for gradual ramps or a "fling". He uses the fewest keyframes possible (two for most moves) and Alt-drags the end keyframes to retime — [SoM: Intro to the Graph Editor](https://schoolofmotion.com/blog/intro-to-the-graph-editor-in-after-effects)
- SoM bounce rule: each bounce reaches about half the height of the previous one. In the example, the fall took 8 frames and the bounces 4, 3 and 2 frames, each a scaled copy of the previous curve — [SoM: Intro to the Graph Editor](https://schoolofmotion.com/blog/intro-to-the-graph-editor-in-after-effects)
- 80% influence starts very slowly and peaks fast near the next key. The recommended starting point is 0 px/s in and out with 75% influence, for a slow start, snappy middle and gentle settle — [Creative Cow thread](https://creativecow.net/forums/thread/easy-ease-adjusting-softness/)
- Speed-graph handles control only entry and exit speed plus influence, not general bezier curvature — [Adobe Community](https://community.adobe.com/t5/after-effects-discussions/speed-graph-handle-curves/td-p/13036613)
- Material Design (v1) gives the After Effects equivalents of its curves as outgoing/incoming influence:

  | Curve | Outgoing / incoming influence | cubic-bezier |
  |---|---|---|
  | Standard | 40% / 80% | (0.4, 0, 0.2, 1) |
  | Deceleration | 0% / 80% | (0, 0, 0.2, 1) |
  | Acceleration | 40% / 0% | (0.4, 0, 1, 1) |
  | Sharp | 40% / 40% | (0.4, 0, 0.6, 1) |

  — [Material Design 1: Duration & easing](https://m1.material.io/motion/duration-easing.html)
- Material 3 standard curve: cubic-bezier(0.2, 0, 0, 1). The M3 "emphasized" curve is two segments and cannot be expressed exactly as one cubic bezier (secondary source) — [hydrolysis-m3 tokens](https://docs.rs/crate/hydrolysis-m3/latest/source/src/theme/motion/tokens.rs)
- Overshoot by hand: for Scale 50 to 100, add a middle key at about 150, or shape the end key's bezier. For a bounce, add a rebound key at 75, then 100 again. Repeat with shorter durations and smaller amplitudes so it settles — [Mt. Mograph: Bounce and Overshoot](https://mtmograph.com/blogs/tools/the-bounce-and-overshoot-animation-trick-every-motion-designer-should-know)
- Bounce and overshoot expressions:
  - Mt. Mograph's sample uses freq = 3 and decay = 5. It works best on Linear base keys, because Easy Ease confuses the velocity the expression reads. Expose freq and decay on sliders so they can be keyframed — [Mt. Mograph](https://mtmograph.com/blogs/tools/the-bounce-and-overshoot-animation-trick-every-motion-designer-should-know)
  - Inertial overshoot scales with the velocity coming into the keyframe, so it can produce "wild" overshoots on fast moves — [Mt. Mograph](https://mtmograph.com/blogs/tools/the-bounce-and-overshoot-animation-trick-every-motion-designer-should-know); [Adobe Community](https://community.adobe.com/t5/after-effects-discussions/scale-down-bounce-expression/m-p/13189984)
  - A community example of starting values: amplitude 0.04, frequency 2, decay 5 — [yuelili](https://www.yuelili.com/ae/ae-expression-damping-and-elasticity/)
  - Higher frequency gives more oscillations. Higher decay settles sooner — [zimoby Elastic](https://zimoby.notion.site/Elastic-52c0634e63264aefb985185507bfaa93)
- When to use linear: continuous loops (spinners, marquees, infinite scroll). Stiff entrances usually come from linear or symmetric easing, and switching to ease-out fixes them. Over-easing (too long, or too gentle an ease-out) feels floaty or sluggish; fix it by shortening the move and sharpening the curve (community skill pages) — [playbooks.com slow-in-out](https://playbooks.com/skills/dylantarre/animation-principles/slow-in-out-mastery)

### Inferences
- The idea of "ease in fast, settle slow" is supported by the Material deceleration curve (0% out / 80% in) and the 75–80% influence advice. An app preset at about 0/80 to 0/90 should match the "pro AE look". Symmetric 33/33 Easy Ease is the generic default that pros move away from.
- Overshoot presets should key off incoming velocity and be clamped, so fast moves don't wildly overshoot.

### Gaps
- None of the sources fetched confirmed 33/66/90 as "standard" influence values, beyond Easy Ease's default 33.33% (training knowledge, unsourced here) and SoM's 90% example.
- Ben Marriott's and Jake in Motion's own easing videos were not reachable as text, so their specific values are not captured.

## Typical durations and frame counts (24/30/60 fps) and readability holds

### Takeaway
- UI-like moves take about 150–400 ms: 4–10 frames at 24 fps, 5–12 at 30, 9–24 at 60. Entrances are slightly longer than exits.
- Allow about 3 words per second of readable hold, with a 1.5–2 s floor for short lines.

### Cited Findings
- Material Design (v1) durations:
  - Mobile: about 300 ms typical; large full-screen moves about 375 ms; entering about 225 ms; exiting about 195 ms.
  - Anything over 400 ms feels slow.
  - Tablet: about 30% longer. Wearables: about 30% shorter. Desktop: 150–200 ms.
  - [Material Design 1](https://m1.material.io/motion/duration-easing.html)
- Material 3 secondary sources: the 50 ms "short1" token for micro-feedback, and 400–700 ms for full-screen transitions — [hydrolysis-m3 tokens](https://docs.rs/crate/hydrolysis-m3/latest/source/src/theme/motion/tokens.rs); [skills.sh M3 motion](https://skills.sh/shelbeely/shelbeely-agent-skills/material-design-3-motion)
- SoM example: a 15-frame move — [SoM: 3 pro tips](https://www.schoolofmotion.com/blog/3-pro-tips-after-effects-beginners). SoM bounce timing: 8-frame fall, then 4, 3 and 2-frame bounces — [SoM Graph Editor](https://schoolofmotion.com/blog/intro-to-the-graph-editor-in-after-effects)
- Text entrance defaults from a frame-based motion library (tool defaults, not a standard):
  - 30-frame word entry, 3-frame stagger and 72-frame hold: 7 words come to 120 frames (4 s at 30 fps).
  - Per-character mode: 12-frame fades spaced 3 frames apart.
  - [fframes word_by_word](https://docs.rs/crate/fframes-components/latest/source/src/components/word_by_word.README.md); [bottom_up_letters](https://docs.rs/crate/fframes-components/latest/source/src/components/bottom_up_letters.README.md)
- Editframe's guide: a 0.6 s entrance, a 0.25 s snap, and a 0.5 s reveal with a 0.15 s delay — [Editframe motion design](https://editframe.com/skills/motion-design.md)
- Reading speed:
  - Adults read about 200–250 wpm. Biteable suggests about 1 s per 2–3 words — [Biteable](https://new.biteable.com/blog/video-word-count/)
  - Keep text up long enough to be read twice at 200 wpm — [SSW rules](https://www.ssw.com.au/rules/post-production-do-you-give-enough-time-to-read-texts-in-your-videos)
  - Subtitles run at about 12–15 characters per second — [titlevision](https://titlevision.dk/sm/reading_speed.htm)
  - Fast-paced content: at least 1.5–2 s; educational content: 3–4 s (vendor guidance) — [Opus Pro](https://www.opus.pro/blog/video-captions-for-maximum-readability)
  - Rule used by one kinetic-type checking tool: at least 0.3 s per word plus 0.5 s — [Complete AI Training](https://completeaitraining.com/ai-agents/agent/kinetic-type-readability-check/)

### Inferences
- Frame conversion: frames = ms × fps / 1000.
  - 225 ms is about 5 frames at 24 fps, 7 at 30, 14 at 60.
  - 300 ms is about 7, 9 and 18 frames.
- For AMV and manga edits, impact hits are probably shorter than UI moves (2–6 frames), with the hold carrying readability. This is unsourced and should be treated as a hypothesis.

### Gaps
- No authoritative source found for logo reveal lengths (convention is about 3–5 s total, unsourced) or for hit/impact frame counts in AMV-style edits.

## Staggering, offsets, rhythm, hierarchy, weight

### Takeaway
- Offset sibling elements by a constant 2–4 frames: the common default is 3 frames, or 40–80 ms for trailing details.
- Settle secondary elements 4–8 frames after the primary stops.
- Cap a group's total stagger at about 600–800 ms by shrinking the offset as the number of items grows.

### Cited Findings
- Constant per-item stagger of 3 frames by default; word *i* starts at *i* × stagger — [fframes](https://docs.rs/crate/fframes-components/latest/source/src/components/word_by_word.README.md)
- Keep offsets consistent and delays short for a steady rhythm. Subtle motion keeps text readable — [Framer Text Entrance](https://www.framer.com/marketplace/components/text-entrance/)
- Trailing parts such as shadows and labels lag 40–80 ms. A group's total reveal stays around 600–800 ms; reduce the per-item offset when there are many items (community guidance) — [claudemarket animation-principles](https://www.claudemarket.ai/skills/iart-ai/motion-design-skills/animation-principles)
- Secondary elements settle about 4–8 frames after the primary stops (community guidance) — [agentskills video-motion-graphics](https://agentskills.so/skills/dylantarre-animation-principles-video-motion-graphics)
- Vary timing to create rhythm — [Editframe](https://editframe.com/skills/motion-design.md)
- AE workflow: Sequence Layers builds staggers quickly — [Frame.io](https://blog.frame.io/2023/12/13/insider-tips-how-to-create-a-staggered-layer-sequence-in-after-effects). The Overlap plugin adds offset, random and driver/driven controls — [Lesterbanks](https://lesterbanks.com/?p=35455)
- Weight comes from timing: more frames and a slower settle read as heavier. A faster settle reads as rigid or light — [Survival Kit summary](https://secondnaturejournal.com/ProductPdf/mL178D/600783/Animator%20Survival%20Kit.pdf); [SoM Follow Through](https://schoolofmotion.com/blog/follow-through-tutorial)

### Inferences
- Primary motion gets the biggest amplitude and the sharpest curve. Secondary motion follows 2–4 frames later with smaller amplitude. Tertiary motion (particles, shake) reacts to the primary's peak velocity.
- Adding a small random variation (±1 frame) to staggers avoids a mechanical cascade. This is supported only by the Overlap plugin offering a randomize control.

### Gaps
- No primary source from SoM, Ben Marriott or Jake in Motion with explicit stagger frame numbers. The figures above come from tool defaults and community pages.

## How pros teach avoiding stiff or generic motion; common beginner mistakes

### Takeaway
The recurring lessons:
- Never leave keyframes linear.
- Match the ease to the physics: a thrown object starts fast, a falling one accelerates.
- Use few keyframes and shape them in the graph editor.
- Separate dimensions.
- Add follow-through and overlap.
- Hide changes at peak speed.
- Avoid both robotic linear motion and floaty over-easing.

### Cited Findings
- Beginner mistakes:
  - Leaving keyframes linear.
  - Easing the start of something that should start fast.
  - Applying effects per layer instead of on an adjustment layer (which affects only the layers below it).
  - Making abrupt changes during slow parts of a move.
  - [SoM: 3 pro tips](https://www.schoolofmotion.com/blog/3-pro-tips-after-effects-beginners)
- Linear is "not what we want" for a falling object, which should accelerate. Use the fewest keyframes and copy/paste curves to reuse shapes at a smaller scale — [SoM Graph Editor](https://schoolofmotion.com/blog/intro-to-the-graph-editor-in-after-effects)
- Ben Marriott teaches breaking complex animations into simple elements (Adobe MAX session) — [Adobe MAX 2022 S907](https://www.adobe.com/max/2022/sessions/apac-behind-the-magic-engaging-animation-and-motio-s907.html); course: [Motion Practice with Ben Marriott](https://motiondesign.school/courses/motion-practice-with-ben-marriott)
- Stiff motion usually means linear or symmetric easing. Floaty motion means the move is too long or the ease-out too gentle — [playbooks slow-in-out](https://playbooks.com/skills/dylantarre/animation-principles/slow-in-out-mastery)
- Inertial overshoot driven by velocity can misfire, so check fast moves — [Mt. Mograph](https://mtmograph.com/blogs/tools/the-bounce-and-overshoot-animation-trick-every-motion-designer-should-know)

### Inferences
- "Generic" motion is mostly default 33% Easy Ease on every key, identical timing for every element, and no offsets. The fix is asymmetric eases, staggered offsets and a single hero move per beat.

### Gaps
- Jake in Motion, Ukramedia and Ben Marriott content is video-only. No text transcripts with specific rules were retrievable in this pass. The "less is more" guidance has no direct citation from these creators.
