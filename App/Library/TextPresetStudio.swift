import Foundation

/// Hand-designed text animations: each one combines several properties with real easing (soft ramps, overshoot,
/// settle) instead of one property swept across the letters. They are normal animators, so everything stays editable.
enum TextPresetStudio {
    // MARK: Helpers

    private static func kf<V: Interpolatable>(_ pairs: [(Double, V)], interp: Interpolation = .bezier) -> Animated<V> {
        var a = Animated(pairs[0].1)
        for (t, v) in pairs { a.insertKeyframe(Keyframe(time: t, value: v, interpolation: interp)) }
        return a
    }

    /// Reveal window sweeping across units. `soft` = how many % of the text are moving at once (bigger = smoother
    /// overlap), `easeHigh` / `easeLow` shape each unit's own move (AE Ease High / Low).
    private static func reveal(_ s: Double, _ d: Double, _ unit: TextUnit = .characters, soft: Double = 35,
                               easeHigh: Double = 60, easeLow: Double = 0, random: Bool = false, out: Bool = false) -> TextSelector {
        var sel = TextSelector()
        sel.basedOn = unit
        sel.shape = out ? .rampDown : .rampUp
        sel.easeHigh = easeHigh
        sel.easeLow = easeLow
        sel.randomize = random
        sel.seed = 7
        sel.start = kf([(s, -soft), (s + d, 100.0)])
        sel.end = kf([(s, 0.0), (s + d, 100.0 + soft)])
        return sel
    }

    /// A moving accent window (triangle) that trails the reveal: overshoot / squash that settles.
    private static func accent(_ s: Double, _ d: Double, _ unit: TextUnit = .characters, delay: Double = 0.12, soft: Double = 30, random: Bool = false) -> TextSelector {
        var sel = reveal(s + d * delay, d, unit, soft: soft, easeHigh: 0, random: random)
        sel.shape = .triangle
        return sel
    }

    private static func anim(_ name: String, _ sel: TextSelector, _ set: (inout TextAnimatorProperties) -> Void) -> TextAnimator {
        var a = TextAnimator(name: name)
        a.selector = sel
        set(&a.properties)
        return a
    }

    private static func p(_ id: String, _ name: String, _ cat: String, _ make: @escaping (Double, Double) -> [TextAnimator]) -> TextPreset {
        TextPreset(id: "studio.\(id)", name: name, category: cat, make: make)
    }

    private static func loopSel(_ kind: SelectorKind, freq: Double, spread: Double = 4, unit: TextUnit = .characters) -> TextSelector {
        var sel = TextSelector()
        sel.kind = kind
        sel.basedOn = unit
        sel.frequency = Animated(freq)
        sel.spread = Animated(spread)
        return sel
    }

    // MARK: Library

    static let all: [TextPreset] = [
        // ---------- In ----------
        p("dropSettle", "Drop & Settle", "In") { s, d in [
            anim("Drop", reveal(s, d)) { $0.position = Animated(Vec2(0, -140)); $0.opacity = Animated(0) },
            anim("Land", accent(s, d)) { $0.position = Animated(Vec2(0, 18)); $0.scale = Animated(Vec2(112, 86)) },
        ] },
        p("riseFocus", "Rise Into Focus", "In") { s, d in [
            anim("Rise", reveal(s, d, soft: 45, easeHigh: 80)) { $0.position = Animated(Vec2(0, 70)); $0.blur = Animated(16); $0.opacity = Animated(0) },
        ] },
        p("swingIn", "Swing In", "In") { s, d in [
            anim("Swing", reveal(s, d)) { $0.position = Animated(Vec2(-160, 170)); $0.rotation = Animated(-70); $0.opacity = Animated(0) },
            anim("Overswing", accent(s, d)) { $0.position = Animated(Vec2(14, -30)); $0.rotation = Animated(10) },
        ] },
        p("scaleSlam", "Scale Slam", "In") { s, d in [
            anim("Slam", reveal(s, d * 0.8, soft: 20, easeHigh: 85)) { $0.scale = Animated(Vec2(280, 280)); $0.blur = Animated(12); $0.opacity = Animated(0) },
            anim("Squash", accent(s, d * 0.8, delay: 0.1, soft: 18)) { $0.scale = Animated(Vec2(118, 82)) },
        ] },
        p("elasticPop", "Elastic Pop", "In") { s, d in [
            anim("Pop", reveal(s, d, soft: 28, easeHigh: 20)) { $0.scale = Animated(Vec2(0, 0)) },
            anim("Stretch", accent(s, d, delay: 0.1)) { $0.scale = Animated(Vec2(132, 70)) },
            anim("Rebound", accent(s, d, delay: 0.22)) { $0.scale = Animated(Vec2(88, 112)) },
        ] },
        p("springUp", "Spring Up", "In") { s, d in [
            anim("Up", reveal(s, d, soft: 30, easeHigh: 40)) { $0.position = Animated(Vec2(0, 120)); $0.scale = Animated(Vec2(60, 140)); $0.opacity = Animated(0) },
            anim("Hop", accent(s, d, delay: 0.1)) { $0.position = Animated(Vec2(0, -34)) },
            anim("Settle", accent(s, d, delay: 0.24)) { $0.position = Animated(Vec2(0, 8)); $0.scale = Animated(Vec2(108, 92)) },
        ] },
        p("spinAssemble", "Spin Assemble", "In") { s, d in [
            anim("Spin", reveal(s, d, soft: 50, random: true)) { $0.rotation = Animated(220); $0.scale = Animated(Vec2(30, 30)); $0.opacity = Animated(0) },
        ] },
        p("scatter", "Scatter Assemble", "In") { s, d in [
            anim("Scatter", reveal(s, d, soft: 55, easeHigh: 75, random: true)) {
                $0.position = Animated(Vec2(90, -180)); $0.rotation = Animated(-45); $0.blur = Animated(10); $0.opacity = Animated(0)
            },
        ] },
        p("trackCollapse", "Tracking Collapse", "In") { s, d in
            var sel = TextSelector()
            sel.amount = kf([(s, 100.0), (s + d, 0.0)])
            return [anim("Collapse", sel) { $0.tracking = Animated(90); $0.blur = Animated(14); $0.opacity = Animated(0) }]
        },
        p("skewWhip", "Skew Whip", "In") { s, d in [
            anim("Whip", reveal(s, d, soft: 30, easeHigh: 85)) { $0.position = Animated(Vec2(220, 0)); $0.skew = Animated(-45); $0.opacity = Animated(0) },
            anim("Snap", accent(s, d)) { $0.skew = Animated(14) },
        ] },
        p("focusPullWords", "Focus Pull (Words)", "In") { s, d in [
            anim("Focus", reveal(s, d, .words, soft: 60, easeHigh: 70)) { $0.blur = Animated(28); $0.scale = Animated(Vec2(125, 125)); $0.opacity = Animated(0) },
        ] },
        p("slideWords", "Slide Words", "In") { s, d in [
            anim("Slide", reveal(s, d, .words, soft: 45, easeHigh: 90)) { $0.position = Animated(Vec2(-240, 0)); $0.opacity = Animated(0) },
        ] },
        p("lineRise", "Line Rise", "In") { s, d in [
            anim("Rise", reveal(s, d, .lines, soft: 60, easeHigh: 85)) { $0.position = Animated(Vec2(0, 90)); $0.opacity = Animated(0) },
        ] },
        p("dominoFall", "Domino", "In") { s, d in [
            anim("Fall", reveal(s, d, soft: 25, easeHigh: 30)) { $0.rotationX = Animated(-90); $0.opacity = Animated(0) },
            anim("Wobble", accent(s, d)) { $0.rotationX = Animated(18) },
        ] },
        p("softStagger", "Soft Stagger", "In") { s, d in [
            anim("Fade", reveal(s, d, soft: 70, easeHigh: 60, easeLow: 40)) { $0.opacity = Animated(0); $0.position = Animated(Vec2(0, 14)) },
        ] },
        p("colorFlood", "Color Flood In", "In") { s, d in [
            anim("Ink", reveal(s, d, soft: 40)) { $0.opacity = Animated(0); $0.scale = Animated(Vec2(80, 80)) },
            anim("Flash", accent(s, d, delay: 0.05, soft: 45)) { $0.fill = Animated(RGBA(hex: 0x9B5CFF)) },
        ] },

        // ---------- Kinetic ----------
        p("punchWords", "Punch Words", "Kinetic") { s, d in [
            anim("Punch", reveal(s, d, .words, soft: 18, easeHigh: 90)) { $0.scale = Animated(Vec2(190, 190)); $0.opacity = Animated(0) },
            anim("Recoil", accent(s, d, .words, delay: 0.06, soft: 16)) { $0.scale = Animated(Vec2(90, 90)) },
        ] },
        p("bounceLetters", "Bounce Letters", "Kinetic") { s, d in [
            anim("Fall", reveal(s, d, soft: 25, easeHigh: 10)) { $0.position = Animated(Vec2(0, -110)); $0.opacity = Animated(0) },
            anim("Bounce 1", accent(s, d, delay: 0.1, soft: 20)) { $0.position = Animated(Vec2(0, -36)) },
            anim("Bounce 2", accent(s, d, delay: 0.24, soft: 16)) { $0.position = Animated(Vec2(0, -12)) },
        ] },
        p("slamShake", "Slam + Shake", "Kinetic") { s, d in
            var shake = loopSel(.wiggly, freq: 18)
            shake.amount = kf([(s + d * 0.4, 100.0), (s + d * 1.2, 0.0)])
            return [
                anim("Slam", reveal(s, d * 0.5, soft: 10, easeHigh: 90)) { $0.scale = Animated(Vec2(320, 320)); $0.opacity = Animated(0) },
                anim("Shake", shake) { $0.position = Animated(Vec2(10, 8)); $0.rotation = Animated(4) },
            ]
        },
        p("stretchSnap", "Stretch Snap", "Kinetic") { s, d in [
            anim("Stretch", reveal(s, d, soft: 20, easeHigh: 85)) { $0.scale = Animated(Vec2(20, 260)); $0.position = Animated(Vec2(0, -60)); $0.opacity = Animated(0) },
            anim("Snap", accent(s, d, delay: 0.08)) { $0.scale = Animated(Vec2(125, 80)) },
        ] },
        p("wordPopRandom", "Pop Random Words", "Kinetic") { s, d in [
            anim("Pop", reveal(s, d, .words, soft: 22, easeHigh: 40, random: true)) { $0.scale = Animated(Vec2(0, 0)); $0.rotation = Animated(-20) },
            anim("Over", accent(s, d, .words, delay: 0.1, random: true)) { $0.scale = Animated(Vec2(122, 122)) },
        ] },

        // ---------- Typewriter ----------
        p("typeClean", "Typewriter Clean", "Typewriter") { s, d in
            var sel = TextSelector()
            sel.shape = .square
            sel.start = kf([(s, 0.0), (s + d, 100.0)], interp: .linear)
            return [anim("Type", sel) { $0.opacity = Animated(0) }]
        },
        p("decode", "Decode", "Typewriter") { s, d in [
            anim("Hide", reveal(s, d, soft: 10, easeHigh: 0)) { $0.opacity = Animated(0) },
            anim("Scramble", accent(s, d, delay: -0.1, soft: 30, random: true)) { $0.characterOffset = Animated(24); $0.fill = Animated(RGBA(hex: 0x7CFFB2)) },
        ] },
        p("hacker", "Hacker Reveal", "Typewriter") { s, d in [
            anim("Chars", reveal(s, d, soft: 50, easeHigh: 0)) { $0.characterOffset = Animated(40) },
            anim("Green", reveal(s, d, soft: 50, easeHigh: 0)) { $0.fill = Animated(RGBA(hex: 0x39FF6A)) },
        ] },

        // ---------- Glitch ----------
        p("glitchIn", "Glitch Slice In", "Glitch") { s, d in [
            anim("Show", reveal(s, d, soft: 15, easeHigh: 0, random: true)) { $0.opacity = Animated(0) },
            anim("Slice", accent(s, d, delay: -0.05, soft: 25, random: true)) { $0.position = Animated(Vec2(46, 0)); $0.skew = Animated(25); $0.fill = Animated(RGBA(hex: 0xFF2D6F)) },
        ] },
        p("glitchLoop", "Glitch Jitter (loop)", "Glitch") { _, _ in [
            anim("Jitter", loopSel(.wiggly, freq: 9)) { $0.position = Animated(Vec2(14, 0)); $0.skew = Animated(10) },
        ] },
        p("glitchOut", "Glitch Out", "Glitch") { s, d in [
            anim("Slice", reveal(s, d, soft: 25, easeHigh: 0, random: true, out: true)) { $0.position = Animated(Vec2(-60, 0)); $0.skew = Animated(-30); $0.opacity = Animated(0) },
        ] },

        // ---------- Neon ----------
        p("neonFlicker", "Neon Flicker On", "Neon") { s, d in [
            anim("Flicker", reveal(s, d, soft: 8, easeHigh: 0, random: true)) { $0.opacity = Animated(0) },
            anim("Dim", accent(s, d, delay: 0.15, soft: 12, random: true)) { $0.opacity = Animated(30) },
        ] },
        p("neonBuzz", "Neon Buzz (loop)", "Neon") { _, _ in [
            anim("Buzz", loopSel(.wiggly, freq: 4)) { $0.opacity = Animated(55) },
        ] },

        // ---------- 3D ----------
        p("flipUp", "Flip Up", "3D") { s, d in [
            anim("Flip", reveal(s, d, soft: 35, easeHigh: 70)) { $0.rotationX = Animated(95); $0.positionZ = Animated(240); $0.opacity = Animated(0) },
        ] },
        p("turnY", "Turn In", "3D") { s, d in [
            anim("Turn", reveal(s, d, soft: 40, easeHigh: 70)) { $0.rotationY = Animated(-100); $0.opacity = Animated(0) },
            anim("Over", accent(s, d)) { $0.rotationY = Animated(14) },
        ] },
        p("depthFly", "Fly From Depth", "3D") { s, d in [
            anim("Fly", reveal(s, d, soft: 45, easeHigh: 85, random: true)) { $0.positionZ = Animated(-900); $0.blur = Animated(12); $0.opacity = Animated(0) },
        ] },

        // ---------- Loop ----------
        p("waveGentle", "Gentle Wave", "Loop") { _, _ in [
            anim("Wave", loopSel(.wave, freq: 0.9, spread: 7)) { $0.position = Animated(Vec2(0, -18)) },
        ] },
        p("breathe", "Breathe", "Loop") { _, _ in [
            anim("Breathe", loopSel(.wave, freq: 0.5, spread: 30)) { $0.scale = Animated(Vec2(106, 106)) },
        ] },
        p("floatRock", "Float & Rock", "Loop") { _, _ in [
            anim("Float", loopSel(.wave, freq: 0.45, spread: 9)) { $0.position = Animated(Vec2(0, -14)); $0.rotation = Animated(6) },
        ] },
        p("jelly", "Jelly Wobble", "Loop") { _, _ in [
            anim("Jelly", loopSel(.wave, freq: 1.6, spread: 3)) { $0.scale = Animated(Vec2(116, 88)) },
        ] },

        // ---------- Out ----------
        p("fallAway", "Fall Away", "Out") { s, d in [
            anim("Fall", reveal(s, d, soft: 35, easeHigh: 0, easeLow: 80, out: true)) { $0.position = Animated(Vec2(0, 160)); $0.rotation = Animated(35); $0.opacity = Animated(0) },
        ] },
        p("blurAway", "Blur Away", "Out") { s, d in [
            anim("Blur", reveal(s, d, soft: 55, easeHigh: 0, easeLow: 70, out: true)) { $0.blur = Animated(24); $0.position = Animated(Vec2(0, -40)); $0.opacity = Animated(0) },
        ] },
        p("shrinkSpin", "Shrink & Spin Out", "Out") { s, d in [
            anim("Shrink", reveal(s, d, soft: 30, easeHigh: 0, easeLow: 80, random: true, out: true)) { $0.scale = Animated(Vec2(0, 0)); $0.rotation = Animated(-160) },
        ] },
        p("flyUpOut", "Fly Up Out (Words)", "Out") { s, d in [
            anim("Fly", reveal(s, d, .words, soft: 45, easeHigh: 0, easeLow: 85, out: true)) { $0.position = Animated(Vec2(0, -200)); $0.opacity = Animated(0) },
        ] },
    ]
}
