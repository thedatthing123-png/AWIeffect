import Foundation

/// The library's newer animation presets, built on the full engine (multiple selectors, random / beat selectors,
/// glow, hue, directional blur, scramble, anchor, stroke, real per-letter 3D). Each one is a set of ordinary
/// animators, so after applying it every part stays editable in the Animate tab.
enum TextPresetLibraryAnimations {
    static var all: [TextPreset] {
        TPB.ins + TPB.outs + TPB.loops + TPB.emphasis + TPB.glitches + TPB.typewriters + TPB.kinetics
            + TPB.manga + TPB.lyrics + TPB.impacts + TPB.ins3D + TPB.outs3D + TPB.loops3D
    }
}

extension TPB {
    // MARK: In

    static let ins: [TextPreset] = [
        p("glowRise", "Glow Rise", "In") { s, d in [
            anim("Glow Rise", reveal(s, d, soft: 45, curve: .quintOut)) { $0.position = v(0, 60); $0.opacity = n(0); $0.glow = n(140); $0.blur = n(8) },
        ] },
        p("hueBloom", "Hue Bloom", "In") { s, d in [
            anim("Bloom", reveal(s, d, soft: 50, curve: .expoOut)) { $0.scale = v(55, 55); $0.opacity = n(0); $0.hueShift = n(180); $0.glow = n(90) },
        ] },
        p("smearSlide", "Smear Slide In", "In") { s, d in [
            anim("Smear", reveal(s, d, soft: 40, curve: .expoOut)) { $0.position = v(-260, 0); $0.directionalBlur = n(70); $0.directionalBlurAngle = n(0); $0.opacity = n(0) },
        ] },
        p("anchorSwing", "Hinge Swing In", "In") { s, d in [
            anim("Hinge", reveal(s, d, soft: 35, curve: .backOut)) { $0.anchor = v(0, -60); $0.rotation = n(-95); $0.opacity = n(0) },
        ] },
        p("strokeDraw", "Outline Then Fill", "In") { s, d in [
            anim("Outline", reveal(s, d * 0.6, soft: 30, curve: .cubicOut)) { $0.opacity = n(0); $0.strokeWidth = n(10) },
            anim("Fill", reveal(s + d * 0.4, d * 0.6, soft: 30, curve: .sineInOut)) { $0.fillOpacity = n(0) },
        ] },
        p("baselineHop", "Baseline Hop", "In") { s, d in [
            anim("Hop", reveal(s, d, soft: 25, curve: .backOut)) { $0.baselineShift = n(90); $0.opacity = n(0) },
        ] },
        p("inkBleed", "Ink Bleed", "In") { s, d in [
            anim("Bleed", reveal(s, d, soft: 70, curve: .sineOut)) { $0.blur = n(22); $0.scale = v(130, 130); $0.fillOpacity = n(0); $0.opacity = n(0) },
        ] },
        p("letterRain", "Letter Rain", "In") { s, d in [
            anim("Rain", reveal(s, d, soft: 20, curve: .bounceOut, order: .random, seed: 11)) { $0.position = v(0, -420); $0.opacity = n(0) },
        ] },
        p("splitCenter", "Split From Center", "In") { s, d in [
            anim("Left Half", part(0, 50, amount: kf([(s, 100.0), (s + d, 0.0)], .expoOut))) { $0.position = v(-320, 0); $0.opacity = n(0); $0.directionalBlur = n(40) },
            anim("Right Half", part(50, 100, amount: kf([(s, 100.0), (s + d, 0.0)], .expoOut))) { $0.position = v(320, 0); $0.opacity = n(0); $0.directionalBlur = n(40) },
        ] },
        p("squashPop", "Squash Pop", "In") { s, d in [
            anim("Squash", reveal(s, d, soft: 25, curve: .backOut)) { $0.scale = v(190, 15); $0.opacity = n(0) },
            anim("Rebound", accent(s, d, delay: 0.15)) { $0.scale = v(90, 118) },
        ] },
        p("pixelSettle", "Pixel Settle", "In") { s, d in [
            anim("Settle", reveal(s, d, soft: 45, curve: .quartOut)) { $0.scramble = n(100); $0.blur = n(6); $0.opacity = n(30) },
        ] },
        p("curtainLines", "Line Curtain", "In") { s, d in [
            anim("Curtain", reveal(s, d, .lines, soft: 60, curve: .expoOut)) { $0.position = v(0, 80); $0.opacity = n(0); $0.blur = n(6) },
        ] },
        p("wordZoomBlur", "Word Zoom Blur", "In") { s, d in [
            anim("Zoom", reveal(s, d, .words, soft: 25, curve: .expoOut)) { $0.scale = v(300, 300); $0.blur = n(18); $0.opacity = n(0) },
        ] },
        p("trackGlow", "Tracking Glow In", "In") { s, d in [
            anim("Track Glow", whole(s, d, curve: .expoOut)) { $0.tracking = n(120); $0.glow = n(110); $0.opacity = n(0) },
        ] },
        p("randomFadeBlur", "Random Soft Blur", "In") { s, d in [
            anim("Soft Blur", reveal(s, d, soft: 20, curve: .sineOut, order: .random, seed: 5)) { $0.opacity = n(0); $0.blur = n(12) },
        ] },
        p("skewSettle", "Skew Settle", "In") { s, d in [
            anim("Skew", reveal(s, d, soft: 30, curve: .quintOut)) { $0.skew = n(-40); $0.position = v(80, 0); $0.opacity = n(0) },
            anim("Settle", accent(s, d, delay: 0.1)) { $0.skew = n(12) },
        ] },
        p("reverseRise", "Rise From End", "In") { s, d in [
            anim("Rise", reveal(s, d, soft: 35, curve: .backOut, order: .reverse)) { $0.position = v(0, 70); $0.opacity = n(0); $0.rotation = n(12) },
        ] },
        p("lightLeakIn", "Light Leak In", "In") { s, d in [
            anim("Leak", reveal(s, d, soft: 60, curve: .sineInOut)) { $0.opacity = n(0); $0.fill = c(0xFFE7B0); $0.glow = n(200); $0.hueShift = n(-30) },
        ] },
    ]

    // MARK: Out

    static let outs: [TextPreset] = [
        p("glowFadeOut", "Glow Fade Out", "Out") { s, d in [
            anim("Glow Out", reveal(s, d, soft: 45, curve: .quintIn, out: true)) { $0.opacity = n(0); $0.glow = n(160); $0.position = v(0, -50) },
        ] },
        p("smearExit", "Smear Exit", "Out") { s, d in [
            anim("Smear", reveal(s, d, soft: 35, curve: .expoIn, out: true)) { $0.position = v(320, 0); $0.directionalBlur = n(90); $0.opacity = n(0) },
        ] },
        p("hueBurn", "Hue Burn Out", "Out") { s, d in [
            anim("Burn", reveal(s, d, soft: 55, curve: .cubicIn, out: true)) { $0.hueShift = n(160); $0.opacity = n(0); $0.blur = n(10); $0.scale = v(120, 120) },
        ] },
        p("scrambleDissolve", "Scramble Dissolve", "Out") { s, d in [
            anim("Dissolve", reveal(s, d, soft: 40, curve: .quadIn, order: .random, out: true, seed: 9)) { $0.scramble = n(100); $0.opacity = n(0) },
        ] },
        p("riseBlurWords", "Rise Blur Out Words", "Out") { s, d in [
            anim("Rise", reveal(s, d, .words, soft: 40, curve: .quartIn, out: true)) { $0.position = v(0, -90); $0.blur = n(14); $0.opacity = n(0) },
        ] },
        p("floorDrop", "Drop Through Floor", "Out") { s, d in [
            anim("Drop", reveal(s, d, soft: 25, curve: .backIn, out: true)) { $0.position = v(0, 320); $0.opacity = n(0) },
        ] },
        p("spinAwayRandom", "Spin Away Random", "Out") { s, d in [
            anim("Spin", reveal(s, d, soft: 30, curve: .cubicIn, order: .random, out: true, seed: 4)) { $0.rotation = n(240); $0.scale = v(0, 0) },
        ] },
        p("zoomPast", "Zoom Past Lens", "Out") { s, d in [
            anim("Zoom", whole(s, d, from: 0, to: 100, curve: .expoIn)) { $0.scale = v(450, 450); $0.blur = n(24); $0.opacity = n(0) },
        ] },
        p("shrinkLine", "Collapse To Line", "Out") { s, d in [
            anim("Collapse", whole(s, d, from: 0, to: 100, curve: .backIn)) { $0.scale = v(130, 0); $0.glow = n(120) },
        ] },
        p("trackApart", "Track Apart Out", "Out") { s, d in [
            anim("Apart", whole(s, d, from: 0, to: 100, curve: .quintIn)) { $0.tracking = n(150); $0.opacity = n(0); $0.blur = n(8) },
        ] },
        p("hollowOut", "Hollow Out", "Out") { s, d in [
            anim("Hollow", reveal(s, d * 0.6, soft: 30, curve: .sineIn, out: true)) { $0.fillOpacity = n(0); $0.strokeWidth = n(6) },
            anim("Vanish", reveal(s + d * 0.4, d * 0.6, soft: 30, curve: .cubicIn, out: true)) { $0.opacity = n(0) },
        ] },
        p("linesSlideOut", "Lines Slide Out", "Out") { s, d in [
            anim("Slide", reveal(s, d, .lines, soft: 50, curve: .expoIn, out: true)) { $0.position = v(-300, 0); $0.opacity = n(0); $0.directionalBlur = n(50) },
        ] },
        p("evaporate", "Evaporate", "Out") { s, d in [
            anim("Evaporate", reveal(s, d, soft: 50, curve: .sineIn, order: .random, out: true, seed: 13)) { $0.position = v(0, -90); $0.blur = n(18); $0.opacity = n(0); $0.scale = v(140, 140) },
        ] },
        p("reverseWipeOut", "Reverse Wipe Out", "Out") { s, d in [
            anim("Wipe", reveal(s, d, soft: 30, curve: .cubicIn, order: .reverse, out: true)) { $0.opacity = n(0); $0.position = v(40, 0) },
        ] },
        p("baselineSink", "Baseline Sink", "Out") { s, d in [
            anim("Sink", reveal(s, d, soft: 25, curve: .backIn, out: true)) { $0.baselineShift = n(-80); $0.opacity = n(0); $0.scale = v(100, 40) },
        ] },
        p("hingeFall", "Hinge Fall Out", "Out") { s, d in [
            anim("Hinge", reveal(s, d, soft: 30, curve: .quadIn, out: true)) { $0.anchor = v(-30, -50); $0.rotation = n(110); $0.position = v(0, 160); $0.opacity = n(0) },
        ] },
    ]

    // MARK: Loop

    static let loops: [TextPreset] = [
        p("glowPulse", "Glow Pulse", "Loop") { s, _ in [
            anim("Glow", wave(s, freq: 0.8, spread: 30)) { $0.glow = n(90) },
        ] },
        p("hueCycle", "Hue Cycle", "Loop") { s, _ in [
            anim("Hue", wave(s, freq: 0.35, spread: 8)) { $0.hueShift = n(180) },
        ] },
        p("bobTilt", "Bob & Tilt", "Loop") { s, _ in [
            anim("Bob", wave(s, freq: 1.1, spread: 5)) { $0.position = v(0, -20); $0.rotation = n(7) },
        ] },
        p("rubberBand", "Rubber Band", "Loop") { s, _ in [
            anim("Rubber", wave(s, freq: 2, spread: 3)) { $0.scale = v(122, 84) },
        ] },
        p("driftBlur", "Dream Drift", "Loop") { s, _ in [
            anim("Drift", wiggly(s, freq: 0.7, seed: 3)) { $0.blur = n(5); $0.position = v(7, 7) },
        ] },
        p("swingFromTop", "Hanging Swing", "Loop") { s, _ in [
            anim("Hang", wave(s, freq: 0.7, spread: 10)) { $0.anchor = v(0, -55); $0.rotation = n(14) },
        ] },
        p("baselineWave", "Baseline Wave", "Loop") { s, _ in [
            anim("Baseline", wave(s, freq: 1.4, spread: 4)) { $0.baselineShift = n(22) },
        ] },
        p("trackBreathe", "Tracking Breathe", "Loop") { s, _ in [
            anim("Breathe", wave(s, freq: 0.5, spread: 200)) { $0.tracking = n(16) },
        ] },
        p("strokePulse", "Stroke Pulse", "Loop") { s, _ in [
            anim("Stroke", wave(s, freq: 1.2, spread: 60)) { $0.strokeWidth = n(7); $0.strokeColor = c(0xFF3D7F) },
        ] },
        p("shimmer", "Shimmer", "Loop") { s, _ in [
            anim("Shimmer", wave(s, freq: 2.2, spread: 2)) { $0.opacity = n(45); $0.glow = n(40) },
        ] },
        p("swayWords", "Sway Words", "Loop") { s, _ in [
            anim("Sway", wave(s, freq: 0.8, spread: 2, .words)) { $0.skew = n(14); $0.position = v(10, 0) },
        ] },
        p("twinkle", "Twinkle", "Loop") { s, _ in [
            anim("Twinkle", wiggly(s, freq: 3, min: 0, max: 100, seed: 8)) { $0.glow = n(150); $0.opacity = n(55) },
        ] },
        p("floatLines", "Float Lines", "Loop") { s, _ in [
            anim("Float", wave(s, freq: 0.4, spread: 2, .lines)) { $0.position = v(0, -16) },
        ] },
        p("wobbleHue", "Candy Wobble", "Loop") { s, _ in [
            anim("Wobble", wave(s, freq: 1.3, spread: 4)) { $0.rotation = n(10); $0.scale = v(108, 108) },
            anim("Candy", wave(s, freq: 0.5, spread: 6, offset: 25)) { $0.hueShift = n(60) },
        ] },
    ]

    // MARK: Emphasis

    static let emphasis: [TextPreset] = [
        p("popAccent", "Pop Accent", "Emphasis") { s, d in [
            anim("Pop", accent(s, d, delay: 0, soft: 30)) { $0.scale = v(145, 145) },
        ] },
        p("glowSweep", "Glow Sweep", "Emphasis") { s, d in [
            anim("Glow", accent(s, d, delay: 0, soft: 35, shape: .smooth)) { $0.glow = n(170); $0.fill = c(0xFFFFFF) },
        ] },
        p("hueSweep", "Hue Sweep", "Emphasis") { s, d in [
            anim("Hue", accent(s, d, delay: 0, soft: 45, shape: .smooth)) { $0.hueShift = n(140); $0.scale = v(110, 110) },
        ] },
        p("bounceWords", "Bounce Highlight Words", "Emphasis") { s, d in [
            anim("Bounce", accent(s, d, .words, delay: 0, soft: 40)) { $0.position = v(0, -40); $0.fill = c(0xFFD25C) },
        ] },
        p("shinePass", "Shine Pass", "Emphasis") { s, d in [
            anim("Shine", accent(s, d, delay: 0, soft: 18, curve: .cubicInOut, shape: .smooth)) { $0.fill = c(0xFFFFFF); $0.scale = v(106, 106); $0.glow = n(60) },
        ] },
        p("strokeFlash", "Stroke Flash", "Emphasis") { s, d in [
            anim("Flash", amount([(s, 0, .expoOut), (s + d * 0.2, 100, .cubicInOut), (s + d, 0, nil)])) { $0.strokeWidth = n(12); $0.strokeColor = c(0xFFE14D) },
        ] },
        p("jumpLetters", "Jump Letters", "Emphasis") { s, d in [
            anim("Jump", accent(s, d, delay: 0, soft: 25, curve: .quadInOut)) { $0.position = v(0, -60); $0.rotation = n(-8) },
        ] },
        p("wiggleAttention", "Wiggle Attention", "Emphasis") { s, d in [
            anim("Wiggle", wiggly(s, freq: 7, amount: kfs([(s, 0.0, .expoOut), (s + d * 0.15, 100.0, .sineInOut), (s + d, 0.0, nil)]))) { $0.position = v(10, 6); $0.rotation = n(10) },
        ] },
        p("goldWipe", "Gold Wipe", "Emphasis") { s, d in [
            anim("Gold", reveal(s, d, soft: 25, curve: .cubicInOut, out: true)) { $0.fill = c(0xFFC94A); $0.glow = n(50) },
        ] },
        p("blurPulse", "Focus Pulse", "Emphasis") { s, d in [
            anim("Focus", amount([(s, 0, .sineOut), (s + d * 0.4, 100, .sineInOut), (s + d, 0, nil)])) { $0.blur = n(10); $0.scale = v(112, 112); $0.opacity = n(70) },
        ] },
        p("nod", "Nod", "Emphasis") { s, d in [
            anim("Nod", amount([(s, 0, .backOut), (s + d * 0.3, 100, .elasticOut), (s + d, 0, nil)])) { $0.anchor = v(0, 40); $0.rotation = n(-10) },
        ] },
        p("growWordSweep", "Grow Word Sweep", "Emphasis") { s, d in [
            anim("Grow", accent(s, d, .words, delay: 0, soft: 34)) { $0.scale = v(132, 132); $0.baselineShift = n(12) },
        ] },
        p("beatPump", "Beat Pump", "Emphasis") { s, _ in [
            anim("Pump", beat(s, attack: 0.02, decay: 0.2)) { $0.scale = v(124, 124); $0.glow = n(70) },
        ] },
        p("underlineGlow", "Neon Underline Pass", "Emphasis") { s, d in [
            anim("Stroke", accent(s, d, delay: 0, soft: 40, shape: .round)) { $0.strokeWidth = n(5); $0.strokeColor = c(0x00E5FF); $0.glow = n(120) },
        ] },
    ]

    // MARK: Glitch

    static let glitches: [TextPreset] = [
        p("scrambleRGB", "Scramble RGB Reveal", "Glitch") { s, d in [
            anim("Scramble", [reveal(s, d, soft: 30, curve: .quartOut), random(seed: 3, min: 40, amount: n(100)).combined(.intersect)],
                 fx: fx("awi.rgbSplit", ["amount": 14])) { $0.scramble = n(100); $0.opacity = n(25) },
        ] },
        p("dataCorrupt", "Data Corrupt In", "Glitch") { s, d in [
            anim("Corrupt", random(seed: 7, min: -100, max: 100, amount: kf([(s, 100.0), (s + d, 0.0)], .expoOut))) { $0.position = v(45, 0); $0.scramble = n(60); $0.hueShift = n(90) },
            anim("Show", reveal(s, d * 0.5, soft: 10, curve: .expoOut, order: .random)) { $0.opacity = n(0) },
        ] },
        p("blockTear", "Block Tear", "Glitch") { s, d in [
            anim("Tear", wiggly(s, freq: 20, seed: 4, amount: kf([(s, 100.0), (s + d, 0.0)], .expoOut)), fx: fx("awi6.glitchBlocks", ["amount": 24])) { $0.position = v(55, 0); $0.scale = v(100, 60) },
        ] },
        p("signalLoss", "Signal Loss Out", "Glitch") { s, d in [
            anim("Loss", [reveal(s, d, soft: 25, curve: .quadIn, order: .random, out: true), wiggly(s, freq: 18, min: 0, max: 100, seed: 6, amount: n(100)).combined(.max)],
                 fx: fx("awi.glitch", ["amount": 60])) { $0.opacity = n(0); $0.position = v(-30, 0); $0.directionalBlur = n(40) },
        ] },
        p("chromaJitter", "Chroma Jitter Loop", "Glitch") { s, _ in [
            anim("Jitter", wiggly(s, freq: 11, seed: 2), fx: fx("awi.rgbSplit", ["amount": 10])) { $0.position = v(6, 2); $0.skew = n(5) },
        ] },
        p("hueGlitchBurst", "Hue Glitch Burst", "Glitch") { s, d in [
            anim("Hue Burst", wiggly(s, freq: 16, seed: 5, amount: kf([(s, 100.0), (s + d, 0.0)], .expoOut))) { $0.hueShift = n(180); $0.position = v(16, 0) },
        ] },
        p("glitchType", "Glitch Type", "Glitch") { s, d in [
            anim("Type", reveal(s, d, soft: 4, curve: nil, linear: true)) { $0.opacity = n(0) },
            anim("Front", accent(s, d, delay: -0.04, soft: 14, curve: nil, linear: true)) { $0.scramble = n(100); $0.fill = c(0x2FF6FF); $0.position = v(10, 0) },
        ] },
        p("staticFlicker", "Static Flicker In", "Glitch") { s, d in [
            anim("Static", [whole(s, d, curve: .expoOut), wiggly(s, freq: 24, min: 0, max: 100, seed: 9, amount: n(100)).combined(.intersect)]) { $0.opacity = n(0); $0.blur = n(4) },
        ] },
        p("digitalSmear", "Digital Smear", "Glitch") { s, d in [
            anim("Smear", wiggly(s, freq: 9, seed: 12, amount: kf([(s, 100.0), (s + d, 0.0)], .quartOut))) { $0.directionalBlur = n(90); $0.position = v(40, 0) },
        ] },
        p("beatGlitch", "Glitch On Beat", "Glitch") { s, _ in [
            anim("Beat Hit", [beat(s, attack: 0.01, decay: 0.12), random(seed: 21, min: -100, max: 100, amount: n(100)).combined(.intersect)],
                 fx: fx("awi.rgbSplit", ["amount": 18])) { $0.position = v(34, 0); $0.scramble = n(40) },
        ] },
        p("scanSlice", "Scanline Slice", "Glitch") { s, d in [
            anim("Slice", wiggly(s, freq: 14, .lines, seed: 3, amount: kf([(s, 100.0), (s + d, 0.0)], .cubicOut)), fx: fx("awi6.glitchLines", ["amount": 30])) { $0.position = v(80, 0); $0.skew = n(10) },
        ] },
        p("corruptWords", "Corrupt Decode Words", "Glitch") { s, d in [
            anim("Decode", reveal(s, d, .words, soft: 30, curve: .quartOut)) { $0.scramble = n(100); $0.opacity = n(40) },
            anim("Hue", [reveal(s, d, .words, soft: 30, curve: .quartOut), random(seed: 4, amount: n(100)).combined(.intersect)]) { $0.hueShift = n(-120) },
        ] },
        p("errorShakeOut", "Error Shake Out", "Glitch") { s, d in [
            anim("Shake", wiggly(s, freq: 22, seed: 7, amount: kf([(s, 0.0), (s + d, 100.0)], .expoIn))) { $0.position = v(30, 8); $0.skew = n(18) },
            anim("Gone", reveal(s + d * 0.3, d * 0.7, soft: 20, curve: .quadIn, order: .random, out: true)) { $0.opacity = n(0); $0.scramble = n(100) },
        ] },
        p("vhsRoll", "VHS Roll", "Glitch") { s, d in [
            anim("Roll", wave(s, freq: 3, spread: 2, .lines, amount: kf([(s, 100.0), (s + d, 0.0)], .cubicOut)), fx: fx("awi.vhs", ["amount": 70])) { $0.position = v(0, 24); $0.directionalBlur = n(30); $0.directionalBlurAngle = n(90) },
        ] },
    ]

    // MARK: Typewriter

    static let typewriters: [TextPreset] = [
        p("cursorType", "Typewriter Cursor", "Typewriter") { s, d in [
            anim("Type", reveal(s, d, soft: 2, curve: nil, linear: true)) { $0.opacity = n(0) },
            anim("Cursor", accent(s, d, delay: 0, soft: 6, curve: nil, linear: true, shape: .square)) { $0.fill = c(0x9B5CFF); $0.glow = n(150); $0.strokeWidth = n(4); $0.strokeColor = c(0xFFFFFF) },
        ] },
        p("softInk", "Soft Ink Type", "Typewriter") { s, d in [
            anim("Ink", reveal(s, d, soft: 6, curve: .sineInOut)) { $0.opacity = n(0); $0.blur = n(7) },
        ] },
        p("typeBounce", "Typewriter Bounce", "Typewriter") { s, d in [
            anim("Type", reveal(s, d, soft: 3, curve: nil, linear: true)) { $0.opacity = n(0) },
            anim("Bounce", accent(s, d, delay: 0.02, soft: 12, curve: nil, linear: true)) { $0.position = v(0, -16); $0.scale = v(115, 115) },
        ] },
        p("terminal", "Terminal Type", "Typewriter") { s, d in [
            anim("Type", reveal(s, d, soft: 3, curve: nil, linear: true)) { $0.opacity = n(0) },
            anim("Green", reveal(s, d, soft: 3, curve: nil, linear: true, out: true)) { $0.fill = c(0x39FF7A); $0.glow = n(60) },
            anim("Noise", accent(s, d, delay: 0, soft: 10, curve: nil, linear: true)) { $0.scramble = n(100) },
        ] },
        p("lineTyper", "Line Typer", "Typewriter") { s, d in [
            anim("Lines", reveal(s, d, .lines, soft: 4, curve: nil, linear: true)) { $0.opacity = n(0); $0.position = v(-14, 0) },
        ] },
        p("randomTyper", "Scattered Typer", "Typewriter") { s, d in [
            anim("Scatter", reveal(s, d, soft: 3, curve: nil, linear: true, order: .random, seed: 17)) { $0.opacity = n(0); $0.scale = v(130, 130) },
        ] },
        p("backspace", "Backspace Out", "Typewriter") { s, d in [
            anim("Backspace", reveal(s, d, soft: 3, curve: nil, linear: true, order: .reverse, out: true)) { $0.opacity = n(0) },
        ] },
        p("teletype", "Retro Teletype", "Typewriter") { s, d in [
            anim("Type", reveal(s, d, soft: 4, curve: nil, linear: true)) { $0.opacity = n(0) },
            anim("Jitter", random(seed: 8, min: -100, max: 100, amount: kf([(s, 100.0), (s + d + 0.3, 0.0)], .cubicOut))) { $0.baselineShift = n(5); $0.rotation = n(3) },
        ] },
        p("decodeLock", "Decode Lock", "Typewriter") { s, d in [
            anim("Decode", reveal(s, d, soft: 50, curve: .quartOut)) { $0.scramble = n(100); $0.hueShift = n(90) },
        ] },
        p("stampType", "Stamp Type", "Typewriter") { s, d in [
            anim("Stamp", reveal(s, d, soft: 8, curve: .backOut)) { $0.scale = v(220, 220); $0.opacity = n(0) },
        ] },
        p("ghostType", "Ghost Type", "Typewriter") { s, d in [
            anim("Ghost", reveal(s, d, soft: 5, curve: .sineOut)) { $0.opacity = n(0) },
            anim("Glow Trail", accent(s, d, delay: -0.05, soft: 20, curve: nil)) { $0.glow = n(140); $0.blur = n(4) },
        ] },
        p("wordTyperPop", "Word Typer Pop", "Typewriter") { s, d in [
            anim("Words", reveal(s, d, .words, soft: 3, curve: nil, linear: true)) { $0.opacity = n(0) },
            anim("Pop", accent(s, d, .words, delay: 0, soft: 18, curve: nil, linear: true)) { $0.scale = v(120, 120) },
        ] },
    ]

    // MARK: Kinetic

    static let kinetics: [TextPreset] = [
        p("punchLeft", "Word Punch Left", "Kinetic") { s, d in [
            anim("Punch", reveal(s, d, .words, soft: 15, curve: .expoOut)) { $0.position = v(-300, 0); $0.scale = v(150, 150); $0.opacity = n(0); $0.directionalBlur = n(50) },
        ] },
        p("punchRight", "Word Punch Right", "Kinetic") { s, d in [
            anim("Punch", reveal(s, d, .words, soft: 15, curve: .expoOut)) { $0.position = v(300, 0); $0.scale = v(150, 150); $0.opacity = n(0); $0.directionalBlur = n(50); $0.directionalBlurAngle = n(180) },
        ] },
        p("stackDrop", "Word Stack Drop", "Kinetic") { s, d in [
            anim("Drop", reveal(s, d, .words, soft: 25, curve: .bounceOut)) { $0.position = v(0, -220); $0.opacity = n(0) },
        ] },
        p("zoomWords", "Kinetic Zoom Words", "Kinetic") { s, d in [
            anim("Zoom", reveal(s, d, .words, soft: 20, curve: .elasticOut)) { $0.scale = v(0, 0) },
        ] },
        p("whipSpinWords", "Whip Spin Words", "Kinetic") { s, d in [
            anim("Whip", reveal(s, d, .words, soft: 20, curve: .expoOut)) { $0.rotation = n(180); $0.directionalBlur = n(40); $0.opacity = n(0) },
        ] },
        p("slideSnapLines", "Slide Snap Lines", "Kinetic") { s, d in [
            anim("Slide", reveal(s, d, .lines, soft: 30, curve: .expoOut)) { $0.position = v(-500, 0); $0.opacity = n(0) },
            anim("Snap", accent(s, d, .lines, delay: 0.1)) { $0.skew = n(-16) },
        ] },
        p("flashSwap", "Word Flash", "Kinetic") { s, d in [
            anim("Show", reveal(s, d, .words, soft: 2, curve: nil, linear: true)) { $0.opacity = n(0) },
            anim("Flash", accent(s, d, .words, delay: 0, soft: 22, curve: nil, linear: true)) { $0.scale = v(125, 125); $0.fill = c(0xFFFFFF); $0.glow = n(110) },
        ] },
        p("tickWords", "Rotate Tick Words", "Kinetic") { s, d in [
            anim("Tick", reveal(s, d, .words, soft: 18, curve: .backOut)) { $0.rotation = n(-35); $0.anchor = v(-20, 30); $0.opacity = n(0) },
        ] },
        p("pendulum", "Pendulum Drop", "Kinetic") { s, d in [
            anim("Pendulum", reveal(s, d, soft: 40, curve: .elasticOut)) { $0.anchor = v(0, -70); $0.rotation = n(70); $0.opacity = n(0) },
        ] },
        p("squeeze", "Squeeze Through", "Kinetic") { s, d in [
            anim("Squeeze", reveal(s, d, .words, soft: 20, curve: .expoOut)) { $0.scale = v(0, 220); $0.opacity = n(0) },
        ] },
        p("ricochet", "Ricochet", "Kinetic") { s, d in [
            anim("Ricochet", reveal(s, d, soft: 30, curve: .bounceOut, order: .random, seed: 2)) { $0.position = v(220, -220); $0.rotation = n(45); $0.opacity = n(0) },
        ] },
        p("trackSnap", "Tracking Snap", "Kinetic") { s, d in [
            anim("Snap", whole(s, d, curve: .backOut)) { $0.tracking = n(-40); $0.scale = v(140, 80); $0.opacity = n(0) },
        ] },
        p("wordSlam3", "Scatter Slam Words", "Kinetic") { s, d in [
            anim("From Top", [reveal(s, d, .words, soft: 15, curve: .expoOut), random(seed: 5, min: 0, max: 100, .words, amount: n(100)).combined(.intersect)]) { $0.position = v(0, -260); $0.opacity = n(0) },
            anim("Fade", reveal(s, d, .words, soft: 15, curve: .expoOut)) { $0.opacity = n(0) },
        ] },
    ]

    // MARK: Manga / AMV

    static let manga: [TextPreset] = [
        p("speedLineBurst", "Speed Line Burst", "Manga/AMV") { s, d in [
            anim("Burst", reveal(s, d, soft: 20, curve: .expoOut)) { $0.position = v(-420, 0); $0.directionalBlur = n(130); $0.opacity = n(0) },
            anim("Streak", accent(s, d, delay: 0.05, soft: 30)) { $0.directionalBlur = n(40); $0.scale = v(130, 90) },
        ] },
        p("stickerSlap", "Sticker Slap", "Manga/AMV") { s, d in [
            anim("Slap", reveal(s, d, soft: 12, curve: .backOut, order: .random, seed: 6)) { $0.scale = v(170, 170); $0.rotation = n(-20); $0.opacity = n(0) },
            anim("Edge", accent(s, d, delay: 0.1, soft: 25)) { $0.strokeWidth = n(12); $0.strokeColor = c(0xFFFFFF) },
        ] },
        p("powerUp", "Shonen Power Up", "Manga/AMV") { s, d in [
            anim("Charge", whole(s, d, from: 0, to: 100, curve: .quadIn)) { $0.glow = n(220); $0.scale = v(112, 112); $0.fill = c(0xFFE14D) },
            anim("Tremble", wiggly(s, freq: 26, seed: 3, amount: kf([(s, 0.0), (s + d, 100.0)], .quadIn))) { $0.position = v(5, 5) },
        ] },
        p("chibiBounce", "Chibi Bounce", "Manga/AMV") { s, d in [
            anim("Bounce", reveal(s, d, soft: 25, curve: .bounceOut)) { $0.position = v(0, -160); $0.opacity = n(0) },
            anim("Squish", accent(s, d, delay: 0.18, soft: 22)) { $0.scale = v(125, 78) },
        ] },
        p("dramaticZoomShake", "Dramatic Zoom Shake", "Manga/AMV") { s, d in [
            anim("Zoom", whole(s, d * 0.5, curve: .expoOut)) { $0.scale = v(260, 260); $0.opacity = n(0); $0.blur = n(16) },
            anim("Shake", wiggly(s, freq: 24, seed: 9, amount: kfs([(s + d * 0.35, 100.0, .expoOut), (s + d, 0.0, nil)]))) { $0.position = v(16, 12); $0.rotation = n(4) },
        ] },
        p("kanjiStamp", "Kanji Stamp", "Manga/AMV") { s, d in [
            anim("Stamp", whole(s, d * 0.3, curve: .expoOut)) { $0.scale = v(320, 320); $0.opacity = n(0) },
            anim("Thud", wiggly(s, freq: 30, seed: 4, amount: kfs([(s + d * 0.28, 100.0, .cubicOut), (s + d * 0.8, 0.0, nil)]))) { $0.position = v(10, 10) },
        ] },
        p("auraFlicker", "Aura Flicker", "Manga/AMV") { s, _ in [
            anim("Aura", wiggly(s, freq: 9, min: 20, max: 100, seed: 5)) { $0.glow = n(160); $0.hueShift = n(30) },
        ] },
        p("panelSlide", "Panel Slide Tilt", "Manga/AMV") { s, d in [
            anim("Panel", reveal(s, d, .words, soft: 30, curve: .expoOut)) { $0.position = v(420, 0); $0.rotation = n(8); $0.skew = n(10); $0.opacity = n(0) },
        ] },
        p("sparklePop", "Sparkle Pop", "Manga/AMV") { s, d in [
            anim("Pop", reveal(s, d, soft: 18, curve: .backOut, order: .random, seed: 12)) { $0.scale = v(0, 0) },
            anim("Sparkle", accent(s, d, delay: 0.05, soft: 30, order: .random, seed: 12)) { $0.glow = n(220); $0.fill = c(0xFFF4B0) },
        ] },
        p("inkSplash", "Ink Splash In", "Manga/AMV") { s, d in [
            anim("Splash", reveal(s, d, soft: 40, curve: .quartOut, order: .random, seed: 14)) { $0.blur = n(30); $0.scale = v(150, 150); $0.opacity = n(0); $0.rotation = n(-15) },
        ] },
        p("velocityFlash", "Velocity Flash", "Manga/AMV") { s, d in [
            anim("Flash", whole(s, d, curve: .expoOut)) { $0.scale = v(140, 140); $0.glow = n(180); $0.directionalBlur = n(60); $0.fill = c(0xFFFFFF) },
        ] },
        p("heartBeatPop", "Heart Beat Pop", "Manga/AMV") { s, _ in [
            anim("Heart", beat(s, attack: 0.03, decay: 0.3)) { $0.scale = v(130, 130); $0.hueShift = n(-25); $0.glow = n(60) },
        ] },
        p("rageTremble", "Rage Tremble", "Manga/AMV") { s, _ in [
            anim("Tremble", wiggly(s, freq: 30, seed: 11)) { $0.position = v(6, 6); $0.rotation = n(4) },
            anim("Red Edge", wave(s, freq: 1.5, spread: 40)) { $0.strokeWidth = n(5); $0.strokeColor = c(0xFF1E3C) },
        ] },
        p("mangaSfxShake", "SFX Rattle Loop", "Manga/AMV") { s, _ in [
            anim("Rattle", wiggly(s, freq: 12, seed: 6)) { $0.rotation = n(9); $0.scale = v(108, 108); $0.anchor = v(0, 20) },
        ] },
    ]

    // MARK: Lyric

    static let lyrics: [TextPreset] = [
        p("karaokeGold", "Karaoke Gold Fill", "Lyric") { s, d in [
            anim("Sung", reveal(s, d, soft: 6, curve: .sineInOut, out: true)) { $0.fill = c(0xFFC94A); $0.glow = n(60) },
        ] },
        p("karaokeBounce", "Karaoke Bounce Words", "Lyric") { s, d in [
            anim("Sung", reveal(s, d, .words, soft: 4, curve: .sineInOut, out: true)) { $0.fill = c(0x5CE1FF) },
            anim("Bounce", accent(s, d, .words, delay: 0, soft: 25)) { $0.position = v(0, -22); $0.scale = v(112, 112) },
        ] },
        p("karaokeGlow", "Karaoke Glow Sweep", "Lyric") { s, d in [
            anim("Glow", accent(s, d, delay: 0, soft: 22, shape: .smooth)) { $0.glow = n(150); $0.fill = c(0xFFFFFF) },
            anim("Dim", reveal(s, d, soft: 20, curve: .sineInOut)) { $0.opacity = n(55) },
        ] },
        p("lyricRiseWords", "Lyric Rise Words", "Lyric") { s, d in [
            anim("Rise", reveal(s, d, .words, soft: 60, curve: .quintOut)) { $0.position = v(0, 40); $0.blur = n(8); $0.opacity = n(0) },
        ] },
        p("lyricFadeLines", "Lyric Fade Lines", "Lyric") { s, d in [
            anim("Fade", reveal(s, d, .lines, soft: 70, curve: .sineInOut)) { $0.opacity = n(0); $0.tracking = n(14) },
        ] },
        p("lyricBlurOut", "Lyric Blur Swap Out", "Lyric") { s, d in [
            anim("Swap", reveal(s, d, .words, soft: 40, curve: .sineIn, out: true)) { $0.blur = n(16); $0.opacity = n(0); $0.position = v(0, -24) },
        ] },
        p("singAlong", "Sing Along Scale", "Lyric") { s, d in [
            anim("Active", accent(s, d, .words, delay: 0, soft: 30)) { $0.scale = v(118, 118); $0.fill = c(0xFF7EB6) },
        ] },
        p("softFloatLyric", "Soft Float Lyric", "Lyric") { s, d in [
            anim("In", reveal(s, d, .words, soft: 50, curve: .cubicOut)) { $0.opacity = n(0); $0.position = v(0, 22) },
            anim("Drift", wave(s, freq: 0.4, spread: 3, .words)) { $0.position = v(0, -6) },
        ] },
        p("pillHighlight", "Word Pill Highlight", "Lyric") { s, d in [
            anim("Pill", accent(s, d, .words, delay: 0, soft: 26, shape: .square)) { $0.strokeWidth = n(16); $0.strokeColor = c(0xFF3D7F) },
        ] },
        p("echoLyric", "Echo Lyric", "Lyric") { s, d in [
            anim("Echo", reveal(s, d, .words, soft: 40, curve: .quartOut)) { $0.scale = v(160, 160); $0.opacity = n(0); $0.blur = n(10) },
            anim("Ghost", accent(s, d, .words, delay: 0.05, soft: 30)) { $0.glow = n(90); $0.opacity = n(70) },
        ] },
        p("lyricTypeWords", "Lyric Typewriter Words", "Lyric") { s, d in [
            anim("Words", reveal(s, d, .words, soft: 3, curve: .sineOut)) { $0.opacity = n(0) },
            anim("Glow", accent(s, d, .words, delay: 0, soft: 20, curve: nil)) { $0.glow = n(110) },
        ] },
        p("neonLyric", "Neon Lyric Sweep", "Lyric") { s, d in [
            anim("Neon", reveal(s, d, .words, soft: 20, curve: .sineInOut, out: true)) { $0.hueShift = n(200); $0.glow = n(90) },
        ] },
        p("breathLyric", "Breath Lyric", "Lyric") { s, _ in [
            anim("Breath", wave(s, freq: 0.3, spread: 1, .lines)) { $0.scale = v(96, 96); $0.opacity = n(72) },
        ] },
    ]

    // MARK: Impact

    static let impacts: [TextPreset] = [
        p("megaSlam", "Mega Slam", "Impact") { s, d in [
            anim("Slam", amount([(s, 100, .expoOut), (s + d * 0.25, -14, .elasticOut), (s + d, 0, nil)])) { $0.scale = v(500, 500); $0.blur = n(20) },
            anim("Fade", whole(s, d * 0.15, curve: .quadOut)) { $0.opacity = n(0) },
            anim("Shake", wiggly(s, freq: 28, seed: 3, amount: kfs([(s + d * 0.22, 100.0, .expoOut), (s + d, 0.0, nil)]))) { $0.position = v(18, 14); $0.rotation = n(3) },
            anim("Flash", amount([(s + d * 0.2, 100, .expoOut), (s + d * 0.7, 0, nil)])) { $0.glow = n(200) },
        ] },
        p("groundPound", "Ground Pound", "Impact") { s, d in [
            anim("Fall", amount([(s, 100, .bounceOut), (s + d * 0.7, 0, nil)])) { $0.position = v(0, -520) },
            anim("Shake", wiggly(s, freq: 26, seed: 5, amount: kfs([(s + d * 0.2, 100.0, .expoOut), (s + d, 0.0, nil)]))) { $0.position = v(0, 14) },
        ] },
        p("shockwave", "Shockwave Hit", "Impact") { s, d in [
            anim("Wave", accent(s, d * 0.6, delay: 0, soft: 40, curve: .expoOut)) { $0.scale = v(165, 165); $0.glow = n(200) },
            anim("Pop", amount([(s, 0, .expoOut), (s + d * 0.1, 100, .cubicOut), (s + d, 0, nil)])) { $0.scale = v(120, 120) },
        ] },
        p("crashZoom", "Crash Zoom", "Impact") { s, d in [
            anim("Crash", whole(s, d * 0.6, curve: .expoOut)) { $0.scale = v(15, 15); $0.blur = n(26); $0.opacity = n(0) },
            anim("Kick", amount([(s + d * 0.45, 100, .elasticOut), (s + d, 0, nil)])) { $0.scale = v(115, 115) },
        ] },
        p("hitStop", "Hit Stop Shake", "Impact") { s, d in [
            anim("Shake", wiggly(s, freq: 40, seed: 2, amount: kf([(s, 100.0), (s + d * 0.5, 0.0)], .expoOut))) { $0.position = v(32, 18) },
        ] },
        p("hammerWords", "Hammer Drop Words", "Impact") { s, d in [
            anim("Hammer", reveal(s, d, .words, soft: 12, curve: .quintIn)) { $0.position = v(0, -300); $0.scale = v(80, 150); $0.opacity = n(0) },
            anim("Squash", accent(s, d, .words, delay: 0.08, soft: 18)) { $0.scale = v(125, 75) },
        ] },
        p("explosive", "Explosive Reveal", "Impact") { s, d in [
            anim("Explode", reveal(s, d, soft: 30, curve: .expoOut, order: .random, seed: 23)) { $0.scale = v(300, 300); $0.blur = n(20); $0.rotation = n(60); $0.opacity = n(0); $0.glow = n(150) },
        ] },
        p("flashBang", "Flash Bang", "Impact") { s, d in [
            anim("Flash", whole(s, d, curve: .expoOut)) { $0.fill = c(0xFFFFFF); $0.glow = n(300); $0.scale = v(122, 122) },
        ] },
        p("recoil", "Recoil Kick", "Impact") { s, d in [
            anim("Recoil", amount([(s, 100, .elasticOut), (s + d, 0, nil)])) { $0.position = v(70, 0); $0.skew = n(-12) },
        ] },
        p("impactFrame", "Impact Frame", "Impact") { s, d in [
            anim("Invert", part(0, 100, amount: hold([(s, 100.0), (s + 0.06, 0.0), (s + 0.12, 100.0), (s + 0.18, 0.0)]))) { $0.hueShift = n(180); $0.fill = c(0x000000); $0.strokeWidth = n(8); $0.strokeColor = c(0xFFFFFF) },
            anim("Punch", amount([(s, 100, .backOut), (s + d * 0.5, 0, nil)])) { $0.scale = v(140, 140) },
        ] },
        p("stompWords", "Stomp Shake Words", "Impact") { s, d in [
            anim("Stomp", reveal(s, d, .words, soft: 10, curve: .expoOut)) { $0.scale = v(240, 240); $0.opacity = n(0) },
            anim("Rattle", wiggly(s, freq: 22, seed: 8, amount: kf([(s, 100.0), (s + d * 1.2, 0.0)], .cubicOut))) { $0.position = v(8, 8) },
        ] },
        p("overshootLines", "Overshoot Snap Lines", "Impact") { s, d in [
            anim("Snap", reveal(s, d, .lines, soft: 20, curve: .backOut)) { $0.scale = v(0, 0); $0.rotation = n(-10) },
        ] },
        p("thunderStrike", "Thunder Strike", "Impact") { s, d in [
            anim("Strike", part(0, 100, amount: hold([(s, 100.0), (s + 0.05, 0.0), (s + 0.1, 100.0), (s + 0.16, 0.0)]))) { $0.glow = n(300); $0.fill = c(0xCFE8FF) },
            anim("Drop", whole(s, d * 0.4, curve: .expoOut)) { $0.position = v(0, -120); $0.opacity = n(0); $0.directionalBlur = n(80); $0.directionalBlurAngle = n(90) },
        ] },
    ]

    // MARK: 3D In

    static let ins3D: [TextPreset] = [
        p("flipCascade", "Flip Cascade", "3D In") { s, d in [
            anim("Flip", reveal(s, d, soft: 35, curve: .backOut)) { $0.rotationX = n(-90); $0.positionZ = n(300); $0.opacity = n(0) },
        ] },
        p("doorSwing", "Door Swing", "3D In") { s, d in [
            anim("Door", reveal(s, d, soft: 40, curve: .expoOut)) { $0.anchor = v(-30, 0); $0.rotationY = n(-100); $0.opacity = n(0) },
        ] },
        p("flyDepthWords", "Fly From Depth Words", "3D In") { s, d in [
            anim("Fly", reveal(s, d, .words, soft: 40, curve: .quintOut)) { $0.positionZ = n(1500); $0.blur = n(10); $0.opacity = n(0) },
        ] },
        p("barrelRoll", "Barrel Roll In", "3D In") { s, d in [
            anim("Roll", reveal(s, d, soft: 40, curve: .cubicOut, order: .random, seed: 3)) { $0.rotationX = n(360); $0.opacity = n(0) },
        ] },
        p("cardFlipWords", "Card Flip Words", "3D In") { s, d in [
            anim("Card", reveal(s, d, .words, soft: 30, curve: .backOut)) { $0.rotationY = n(180); $0.opacity = n(0) },
        ] },
        p("unfoldTop", "Unfold From Top", "3D In") { s, d in [
            anim("Unfold", reveal(s, d, soft: 30, curve: .quartOut)) { $0.anchor = v(0, -40); $0.rotationX = n(95); $0.opacity = n(0) },
        ] },
        p("spiralPush", "Spiral Push In", "3D In") { s, d in [
            anim("Spiral", reveal(s, d, soft: 50, curve: .expoOut)) { $0.rotation = n(180); $0.positionZ = n(800); $0.rotationY = n(60); $0.opacity = n(0) },
        ] },
        p("tumbleAssemble", "Tumble Assemble", "3D In") { s, d in [
            anim("Tumble", reveal(s, d, soft: 45, curve: .quartOut, order: .random, seed: 19)) { $0.rotationX = n(140); $0.rotationY = n(-120); $0.rotation = n(60); $0.positionZ = n(600); $0.opacity = n(0) },
        ] },
        p("pushLines", "Push In Lines", "3D In") { s, d in [
            anim("Push", reveal(s, d, .lines, soft: 40, curve: .expoOut)) { $0.positionZ = n(900); $0.opacity = n(0) },
        ] },
        p("throughCamera", "Through The Camera", "3D In") { s, d in [
            anim("Through", whole(s, d, curve: .expoOut)) { $0.positionZ = n(-700); $0.blur = n(18); $0.opacity = n(0) },
        ] },
        p("orbitIn", "Orbit In", "3D In") { s, d in [
            anim("Orbit", reveal(s, d, soft: 50, curve: .cubicOut)) { $0.rotationY = n(270); $0.positionZ = n(400); $0.opacity = n(0) },
        ] },
        p("shatterAssemble", "Shatter Assemble", "3D In") { s, d in [
            anim("Shards", reveal(s, d, soft: 40, curve: .expoOut, order: .random, seed: 31)) { $0.position = v(180, -140); $0.rotationX = n(200); $0.rotationY = n(160); $0.rotation = n(90); $0.positionZ = n(500); $0.opacity = n(0) },
        ] },
        p("dominoStand", "Domino Stand Up", "3D In") { s, d in [
            anim("Stand", reveal(s, d, soft: 25, curve: .bounceOut)) { $0.anchor = v(0, 40); $0.rotationX = n(-90); $0.opacity = n(0) },
        ] },
        p("flipZoom", "Flip Zoom Words", "3D In") { s, d in [
            anim("Flip", reveal(s, d, .words, soft: 25, curve: .expoOut)) { $0.rotationX = n(180); $0.scale = v(200, 200); $0.opacity = n(0) },
        ] },
    ]

    // MARK: 3D Out

    static let outs3D: [TextPreset] = [
        p("flipAway", "Flip Away", "3D Out") { s, d in [
            anim("Flip", reveal(s, d, soft: 35, curve: .backIn, out: true)) { $0.rotationX = n(90); $0.positionZ = n(300); $0.opacity = n(0) },
        ] },
        p("doorClose", "Door Close", "3D Out") { s, d in [
            anim("Door", reveal(s, d, soft: 40, curve: .expoIn, out: true)) { $0.anchor = v(30, 0); $0.rotationY = n(100); $0.opacity = n(0) },
        ] },
        p("intoDepth", "Fly Into Depth", "3D Out") { s, d in [
            anim("Fly", reveal(s, d, soft: 45, curve: .quintIn, out: true)) { $0.positionZ = n(1500); $0.blur = n(10); $0.opacity = n(0) },
        ] },
        p("barrelOut", "Barrel Roll Out", "3D Out") { s, d in [
            anim("Roll", reveal(s, d, soft: 40, curve: .cubicIn, order: .random, out: true, seed: 3)) { $0.rotationX = n(-360); $0.opacity = n(0) },
        ] },
        p("cardOutWords", "Card Flip Out Words", "3D Out") { s, d in [
            anim("Card", reveal(s, d, .words, soft: 30, curve: .backIn, out: true)) { $0.rotationY = n(-180); $0.opacity = n(0) },
        ] },
        p("foldUp", "Fold Up Out", "3D Out") { s, d in [
            anim("Fold", reveal(s, d, soft: 30, curve: .quartIn, out: true)) { $0.anchor = v(0, -40); $0.rotationX = n(-95); $0.opacity = n(0) },
        ] },
        p("spiralPull", "Spiral Pull Out", "3D Out") { s, d in [
            anim("Spiral", reveal(s, d, soft: 50, curve: .expoIn, out: true)) { $0.rotation = n(-180); $0.positionZ = n(800); $0.rotationY = n(-60); $0.opacity = n(0) },
        ] },
        p("shatterOut", "Shatter Out", "3D Out") { s, d in [
            anim("Shards", reveal(s, d, soft: 40, curve: .expoIn, order: .random, out: true, seed: 29)) { $0.position = v(-200, 160); $0.rotationX = n(-220); $0.rotationY = n(180); $0.positionZ = n(-300); $0.opacity = n(0) },
        ] },
        p("pushAwayLines", "Push Away Lines", "3D Out") { s, d in [
            anim("Push", reveal(s, d, .lines, soft: 40, curve: .expoIn, out: true)) { $0.positionZ = n(1000); $0.opacity = n(0) },
        ] },
        p("rushPast", "Rush Past Camera", "3D Out") { s, d in [
            anim("Rush", whole(s, d, from: 0, to: 100, curve: .expoIn)) { $0.positionZ = n(-800); $0.blur = n(20); $0.opacity = n(0) },
        ] },
        p("orbitOut", "Orbit Out", "3D Out") { s, d in [
            anim("Orbit", reveal(s, d, soft: 50, curve: .cubicIn, order: .reverse, out: true)) { $0.rotationY = n(-270); $0.positionZ = n(400); $0.opacity = n(0) },
        ] },
        p("dominoFall", "Domino Fall", "3D Out") { s, d in [
            anim("Fall", reveal(s, d, soft: 25, curve: .quadIn, out: true)) { $0.anchor = v(0, 40); $0.rotationX = n(90); $0.opacity = n(0) },
        ] },
        p("toppleWords", "Topple Back Words", "3D Out") { s, d in [
            anim("Topple", reveal(s, d, .words, soft: 30, curve: .backIn, out: true)) { $0.anchor = v(0, 45); $0.rotationX = n(-100); $0.positionZ = n(200); $0.opacity = n(0) },
        ] },
    ]

    // MARK: 3D Loop

    static let loops3D: [TextPreset] = [
        p("spinYWords", "Swivel Words", "3D Loop") { s, _ in [
            anim("Swivel", wave(s, freq: 0.5, spread: 2, .words)) { $0.rotationY = n(50) },
        ] },
        p("zRipple", "Depth Ripple", "3D Loop") { s, _ in [
            anim("Ripple", wave(s, freq: 1.2, spread: 5)) { $0.positionZ = n(140) },
        ] },
        p("rockX", "Rocking X", "3D Loop") { s, _ in [
            anim("Rock", wave(s, freq: 0.8, spread: 8)) { $0.rotationX = n(28) },
        ] },
        p("coinSpin", "Coin Spin", "3D Loop") { s, _ in [
            anim("Spin", part(0, 100, amount: n(100))) { $0.rotationY = kf([(s, 0.0), (s + 2, 360.0), (s + 4, 720.0), (s + 30, 5400.0)], nil, linear: true) },
        ] },
        p("flagWave", "Flag Wave 3D", "3D Loop") { s, _ in [
            anim("Flag", wave(s, freq: 1, spread: 4)) { $0.rotationY = n(30); $0.positionZ = n(60) },
        ] },
        p("floatDepth", "Float In Depth", "3D Loop") { s, _ in [
            anim("Float", wiggly(s, freq: 0.6, seed: 4)) { $0.positionZ = n(220); $0.rotationX = n(10) },
        ] },
        p("tiltOrbit", "Tilt Orbit", "3D Loop") { s, _ in [
            anim("Tilt X", wave(s, freq: 0.5, spread: 100)) { $0.rotationX = n(16) },
            anim("Tilt Y", wave(s, freq: 0.5, spread: 100, offset: 25)) { $0.rotationY = n(22) },
        ] },
        p("breathDepthWords", "Breathing Depth Words", "3D Loop") { s, _ in [
            anim("Depth", wave(s, freq: 0.4, spread: 2, .words)) { $0.positionZ = n(-120); $0.glow = n(30) },
        ] },
        p("carousel", "Carousel", "3D Loop") { s, _ in [
            anim("Carousel", wave(s, freq: 0.35, spread: 3)) { $0.rotationY = n(80); $0.positionZ = n(180); $0.position = v(20, 0) },
        ] },
        p("flipLoop", "Flip Loop Letters", "3D Loop") { s, _ in [
            anim("Flip", accent(s, 1.6, delay: 0, soft: 25, curve: .sineInOut)) { $0.rotationX = n(360) },
            anim("Again", accent(s + 1.8, 1.6, delay: 0, soft: 25, curve: .sineInOut, order: .reverse)) { $0.rotationX = n(-360) },
        ] },
        p("jelly3D", "Jelly 3D", "3D Loop") { s, _ in [
            anim("Jelly", wave(s, freq: 1.6, spread: 3)) { $0.rotationX = n(20); $0.scale = v(110, 92) },
        ] },
        p("beatDepth", "Beat Depth Punch", "3D Loop") { s, _ in [
            anim("Punch", beat(s, attack: 0.02, decay: 0.18)) { $0.positionZ = n(-200); $0.scale = v(110, 110) },
        ] },
        p("hoverBob3D", "Hover Bob 3D", "3D Loop") { s, _ in [
            anim("Hover", wave(s, freq: 0.7, spread: 7)) { $0.position = v(0, -14); $0.rotationX = n(-14) },
        ] },
    ]
}
