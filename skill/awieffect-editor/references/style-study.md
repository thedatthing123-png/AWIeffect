# Style study: the user's reference edits

Four manga / anime edits the user (Awiliao) gave as targets, studied frame by frame (cut times detected
automatically at 30 fps). Use these as the house style.

## Shared traits (do these by default)
- **Fast, beat-locked cutting.** Long holds (1-4 s) on build-ups, then bursts of cuts 2-3 frames apart on the drop
  (one edit had ~14 cuts between 12.9 s and 13.9 s, i.e. a 1-3 frame strobe).
- **Every cut is "covered":** white flash, color-inverted flash, zoom-blur smear, or a glitch frame. Clean straight
  cuts are rare.
- **Hits = flash + zoom punch + shake together** on the same frame, then settle over 6-10 frames.
- **Cutout characters** sit over moved / blurred backgrounds (parallax), often with a soft drop shadow.
- **Debris and particles** (dark chunks, sparks) drifting across the frame during action.
- **Creator watermark** as glowing text, low in frame, present the whole edit.
- **Contrast is pushed hard**; manga panels stay black & white with **one accent color** (cyan eyes, yellow eyes,
  gold hair, green energy).

## Per edit
1. **Chibi / manga intro ("WHO WILL BE THE MOG")**: B&W manga, gray gradient background.
   - Opener: yellow hand-drawn style text that types in word by word with a smear (scramble / blur in).
   - Chibi heads pop in one by one (scale pop with bounce), then a panel split (slanted white border) reveals the
     main character.
   - **Full-frame color tints as hits:** a cyan wash, then an orange wash, 1-2 frames each.
   - Name captions glow on the reveal; eye glow on the character (selective color: cyan / yellow eyes, rest gray).
2. **haikoxpp (colored anime)**: clean anime clips, warm grade.
   - Object glow (green gem) added as an overlay with glow.
   - **Game-UI gag:** pixel-shatter glitch into a "You died / Respawn" screen, desaturated.
   - Red halftone flash frame before the shatter.
   - White-out flash into a high-contrast mono frame, then a hard cut to a green-lit corridor.
   - Ends on a character with chains (impact pose).
3. **xgokuponchx (heavy FX manga)**: the most effect-dense.
   - **Rainbow / chromatic distortion** frames (lens warp, prismatic edges), color-inverted psychedelic hits
     (magenta / green / orange), pixel-sort smears.
   - Manga panel in gray with film grain; letterbox bars.
   - Gold hair with glint; eye close-ups with speed-lines / light streaks.
   - Lens-flare sunburst behind the character with flying rocks.
   - Glowing watermark "GOKUPONCH".
4. **gokuponch (colored manga, Goku & Broly)**:
   - Title card on white: bold title "GOKU AND BROLY" + subtitle, colored stripes (green / cyan) sliding in
     behind the cutout fighters, debris flying.
   - Then zoom-blur transition into colored panels, a white radial flash (circle), and rapid zoom punches between
     close-ups with motion blur.
   - Sun flare and glints on impacts.

## How to rebuild these in AWIeffect
| Look | AWIeffect pieces |
|---|---|
| Hit (flash + punch + shake) | white Solid 2-4 frames, opacity 100→0 (expoOut) + `awi18.zoomPunch` or scale keys 100→115→100 (backOut) + `awi18.shakePro` mode Impact Hits |
| Strobe on the drop | split the clip every 2-3 frames; alternate `ae.invert` / Negative Flash `awi18.negativeFlash` on every other piece |
| Color-wash hit | Solid in cyan / orange, blend Color or Screen, 1-2 frames |
| Cutout character | Remove BG (cutoutSubject action) or Individual Chroma Key on a copy; drop shadow `ae.dropShadow` |
| Selective color eyes / hair | duplicate layer → `awi19.colorSelect` (Individual Chroma Key) on the eye color → `awi.deepGlow`; base layer `ae.blackWhite` (desaturate) |
| Rainbow distortion | `awi18.warpChroma` + `awi19.chromaShatter` / `awi19.pixelSort` on 1-3 frames |
| Pixel shatter / game glitch | `awi19.blockCorrupt` + `awi19.signalLoss` + `awi19.flash` burst |
| Zoom-blur transition | `ae.radialBlur` (zoom) keyed up over 3-4 frames + scale 100→140, next clip starts blurred → sharp |
| Debris | Particles layer (sprite chunks), gravity on, short life |
| Watermark | Text layer, fontSize ~6% of height, `awi.outerGlow`, low center, full length |
| Letterbox | two black Solids top / bottom |
| Grain on manga | `ae.noise` small amount + contrast up |
