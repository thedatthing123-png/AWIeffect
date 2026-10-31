import Foundation

/// The big premade text animation pack: In, Out, Loop, Glitch, Typewriter, Kinetic / Impact, Neon and 3D.
/// Every preset is built from ordinary animators (range / wiggly / wave selectors), so after applying one you can
/// open the Animators section and tweak every part.
enum TextPresetPack {
    static let categories = ["In", "Out", "Loop", "Glitch", "Typewriter", "Kinetic", "Neon", "3D"]

    // MARK: Helpers

    private static func kf<V: Interpolatable>(_ pairs: [(Double, V)], interp: Interpolation = .bezier, curve: EaseCurve? = nil) -> Animated<V> {
        var a = Animated(pairs[0].1)
        for (t, v) in pairs {
            var k = Keyframe(time: t, value: v, interpolation: interp)
            k.curve = curve
            a.insertKeyframe(k)
        }
        return a
    }

    enum Order: String { case chars = "", random = " (Random)", words = " (Words)", lines = " (Lines)" }

    /// Units before the soft window are done, units after it still offset. `out` flips it (units leave).
    private static func sweep(_ s: Double, _ d: Double, order: Order, out: Bool = false, soft: Double = 35, curve: EaseCurve? = nil) -> TextSelector {
        var sel = TextSelector()
        sel.basedOn = order == .words ? .words : (order == .lines ? .lines : .characters)
        sel.randomize = order == .random
        sel.seed = 3
        sel.shape = out ? .rampDown : .rampUp
        sel.start = kf([(s, -soft), (s + d, 100.0)], curve: curve)
        sel.end = kf([(s, 0.0), (s + d, 100.0 + soft)], curve: curve)
        return sel
    }

    /// What a unit looks like while it's still "away".
    struct Recipe {
        let id: String
        let name: String
        let apply: (inout TextAnimatorProperties) -> Void
        var curve: EaseCurve? = nil
    }

    private static let recipes: [Recipe] = [
        Recipe(id: "fade", name: "Fade") { $0.opacity = Animated(0) },
        Recipe(id: "fadeUp", name: "Fade Up") { $0.opacity = Animated(0); $0.position = Animated(Vec2(0, 70)) },
        Recipe(id: "fadeDown", name: "Fade Down") { $0.opacity = Animated(0); $0.position = Animated(Vec2(0, -70)) },
        Recipe(id: "slideL", name: "Slide From Left") { $0.opacity = Animated(0); $0.position = Animated(Vec2(-200, 0)) },
        Recipe(id: "slideR", name: "Slide From Right") { $0.opacity = Animated(0); $0.position = Animated(Vec2(200, 0)) },
        Recipe(id: "scaleUp", name: "Grow") { $0.scale = Animated(Vec2(0, 0)) },
        Recipe(id: "scaleDown", name: "Shrink Down") { $0.scale = Animated(Vec2(320, 320)); $0.opacity = Animated(0) },
        Recipe(id: "blur", name: "Blur Reveal") { $0.blur = Animated(24); $0.opacity = Animated(0) },
        Recipe(id: "spin", name: "Spin") { $0.rotation = Animated(-200); $0.scale = Animated(Vec2(0, 0)) },
        Recipe(id: "drop", name: "Drop", apply: { $0.position = Animated(Vec2(0, -320)); $0.opacity = Animated(0) }, curve: EaseCurve(.bounceOut)),
        Recipe(id: "rise", name: "Rise", apply: { $0.position = Animated(Vec2(0, 260)); $0.opacity = Animated(0) }, curve: EaseCurve(.backOut)),
        Recipe(id: "stretch", name: "Stretch") { $0.scale = Animated(Vec2(340, 0)); $0.opacity = Animated(0) },
        Recipe(id: "skew", name: "Skew In") { $0.skew = Animated(45); $0.position = Animated(Vec2(-120, 0)); $0.opacity = Animated(0) },
        Recipe(id: "track", name: "Spread In") { $0.tracking = Animated(90); $0.opacity = Animated(0) },
        Recipe(id: "scramble", name: "Scramble") { $0.characterOffset = Animated(24); $0.opacity = Animated(0) },
        Recipe(id: "colorPop", name: "Color Pop", apply: { $0.fill = Animated(RGBA(hex: 0xFF3D7F)); $0.scale = Animated(Vec2(170, 170)); $0.opacity = Animated(0) }, curve: EaseCurve(.elasticOut)),
        Recipe(id: "pop", name: "Pop", apply: { $0.scale = Animated(Vec2(0, 0)) }, curve: EaseCurve(.backOut)),
        Recipe(id: "elastic", name: "Elastic", apply: { $0.scale = Animated(Vec2(0, 0)); $0.position = Animated(Vec2(0, 40)) }, curve: EaseCurve(.elasticOut)),
    ]

    private static func inPreset(_ r: Recipe, _ order: Order) -> TextPreset {
        TextPreset(id: "pack.in.\(r.id)\(order == .chars ? "" : "." + String(describing: order))", name: r.name + order.rawValue, category: "In") { s, d in
            var a = TextAnimator(name: r.name)
            a.selector = sweep(s, d, order: order, curve: r.curve)
            r.apply(&a.properties)
            return [a]
        }
    }

    private static func outPreset(_ r: Recipe) -> TextPreset {
        TextPreset(id: "pack.out.\(r.id)", name: r.name + " Out", category: "Out") { s, d in
            var a = TextAnimator(name: r.name + " Out")
            a.selector = sweep(s, d, order: .chars, out: true)
            r.apply(&a.properties)
            return [a]
        }
    }

    private static func loop(_ id: String, _ name: String, kind: SelectorKind, freq: Double, spread: Double = 6, cat: String = "Loop",
                             _ props: @escaping (inout TextAnimatorProperties) -> Void) -> TextPreset {
        TextPreset(id: "pack.loop.\(id)", name: name, category: cat) { _, _ in
            var a = TextAnimator(name: name)
            a.selector.kind = kind
            a.selector.frequency = Animated(freq)
            a.selector.spread = Animated(spread)
            props(&a.properties)
            return [a]
        }
    }

    /// Glitch / flicker that hits hard then settles (wiggly selector fading out).
    private static func burst(_ id: String, _ name: String, cat: String, freq: Double, seed: Int = 1, minAmount: Double = -100,
                              _ props: @escaping (inout TextAnimatorProperties) -> Void) -> TextPreset {
        TextPreset(id: "pack.burst.\(id)", name: name, category: cat) { s, d in
            var a = TextAnimator(name: name)
            a.selector.kind = .wiggly
            a.selector.frequency = Animated(freq)
            a.selector.seed = seed
            a.selector.minAmount = minAmount
            a.selector.amount = kf([(s, 100.0), (s + d, 0.0)], interp: .linear)
            props(&a.properties)
            return [a]
        }
    }

    // MARK: The pack

    static let all: [TextPreset] = {
        var out: [TextPreset] = []
        for r in recipes { out.append(inPreset(r, .chars)) }
        for r in recipes where ["fade", "fadeUp", "slideL", "scaleUp", "blur", "drop", "rise", "pop", "elastic", "scramble", "spin", "skew"].contains(r.id) {
            out.append(inPreset(r, .random)); out.append(inPreset(r, .words))
        }
        for r in recipes where !["colorPop", "scramble"].contains(r.id) { out.append(outPreset(r)) }

        // Loops
        out += [
            loop("waveY", "Wave", kind: .wave, freq: 1.2) { $0.position = Animated(Vec2(0, -30)) },
            loop("waveScale", "Pulse Wave", kind: .wave, freq: 1.5) { $0.scale = Animated(Vec2(130, 130)) },
            loop("waveRot", "Rock", kind: .wave, freq: 1, spread: 4) { $0.rotation = Animated(14) },
            loop("float", "Float", kind: .wave, freq: 0.45, spread: 10) { $0.position = Animated(Vec2(0, -16)) },
            loop("wiggle", "Jitter", kind: .wiggly, freq: 6) { $0.position = Animated(Vec2(8, 8)) },
            loop("wiggleRot", "Shiver", kind: .wiggly, freq: 9) { $0.rotation = Animated(10) },
            loop("jelly", "Jelly", kind: .wiggly, freq: 3) { $0.scale = Animated(Vec2(125, 80)) },
            loop("breathe", "Breathe (Words)", kind: .wave, freq: 0.6, spread: 2) { $0.scale = Animated(Vec2(112, 112)) },
            loop("colorWave", "Color Wave", kind: .wave, freq: 0.8, spread: 8) { $0.fill = Animated(RGBA(hex: 0x6CE7FF)) },
            loop("skewWave", "Lean Wave", kind: .wave, freq: 1.1, spread: 5) { $0.skew = Animated(18) },
        ]

        // Glitch
        out += [
            burst("glitchSkew", "Glitch Skew", cat: "Glitch", freq: 16) { $0.skew = Animated(28); $0.position = Animated(Vec2(30, 0)) },
            burst("glitchRGB", "RGB Glitch", cat: "Glitch", freq: 12, seed: 5, minAmount: 0) { $0.fill = Animated(RGBA(hex: 0xFF2F6E)); $0.position = Animated(Vec2(18, 0)) },
            burst("glitchCyan", "Cyan Glitch", cat: "Glitch", freq: 12, seed: 9, minAmount: 0) { $0.fill = Animated(RGBA(hex: 0x2FF6FF)); $0.position = Animated(Vec2(-18, 4)) },
            burst("glitchScramble", "Scramble Glitch", cat: "Glitch", freq: 14, minAmount: 0) { $0.characterOffset = Animated(30) },
            burst("glitchFlicker", "Flicker Glitch", cat: "Glitch", freq: 20, minAmount: 0) { $0.opacity = Animated(0) },
            burst("glitchSlice", "Slice Glitch (Words)", cat: "Glitch", freq: 10, seed: 13) { $0.position = Animated(Vec2(60, 0)); $0.scale = Animated(Vec2(100, 60)) },
            burst("glitchBlur", "Smear Glitch", cat: "Glitch", freq: 11, minAmount: 0) { $0.blur = Animated(18); $0.position = Animated(Vec2(26, 0)) },
            loop("cursed", "Cursed Loop", kind: .wiggly, freq: 14, cat: "Glitch") { $0.position = Animated(Vec2(6, 3)); $0.skew = Animated(6) },
        ]

        // Typewriter
        out += [
            TextPreset(id: "pack.type.words", name: "Type Words", category: "Typewriter") { s, d in
                var a = TextAnimator(name: "Type Words")
                a.selector = TextSelector(basedOn: .words, start: kf([(s, 0.0), (s + d, 100.0)], interp: .linear), shape: .square)
                a.selector.end = Animated(100)
                a.properties.opacity = Animated(0)
                return [a]
            },
            TextPreset(id: "pack.type.random", name: "Type Random", category: "Typewriter") { s, d in
                var a = TextAnimator(name: "Type Random")
                a.selector = TextSelector(basedOn: .characters, start: kf([(s, 0.0), (s + d, 100.0)], interp: .linear), shape: .square)
                a.selector.end = Animated(100)
                a.selector.randomize = true
                a.properties.opacity = Animated(0)
                return [a]
            },
            TextPreset(id: "pack.type.decode", name: "Decode", category: "Typewriter") { s, d in
                var a = TextAnimator(name: "Decode")
                a.selector = sweep(s, d, order: .chars, soft: 60)
                a.properties.characterOffset = Animated(40)
                return [a]
            },
            TextPreset(id: "pack.type.soft", name: "Soft Type", category: "Typewriter") { s, d in
                var a = TextAnimator(name: "Soft Type")
                a.selector = sweep(s, d, order: .chars, soft: 12)
                a.properties.opacity = Animated(0)
                a.properties.blur = Animated(8)
                return [a]
            },
            TextPreset(id: "pack.type.hack", name: "Hacker Type", category: "Typewriter") { s, d in
                var a = TextAnimator(name: "Hacker Type")
                a.selector = sweep(s, d, order: .chars, soft: 25)
                a.properties.characterOffset = Animated(60)
                a.properties.fill = Animated(RGBA(hex: 0x39FF7A))
                return [a]
            },
        ]

        // Kinetic / impact (manga + AMV hits)
        out += [
            TextPreset(id: "pack.kin.slam", name: "Slam", category: "Kinetic") { s, d in
                var a = TextAnimator(name: "Slam")
                a.selector.amount = kf([(s, 100.0), (s + d * 0.5, 0.0)], curve: EaseCurve(.backOut))
                a.properties.scale = Animated(Vec2(420, 420)); a.properties.opacity = Animated(0)
                return [a]
            },
            TextPreset(id: "pack.kin.punch", name: "Punch Words", category: "Kinetic") { s, d in
                var a = TextAnimator(name: "Punch Words")
                a.selector = sweep(s, d, order: .words, soft: 10, curve: EaseCurve(.backOut))
                a.properties.scale = Animated(Vec2(260, 260)); a.properties.opacity = Animated(0)
                return [a]
            },
            TextPreset(id: "pack.kin.stomp", name: "Stomp", category: "Kinetic") { s, d in
                var a = TextAnimator(name: "Stomp")
                a.selector = sweep(s, d, order: .chars, soft: 20, curve: EaseCurve(.bounceOut))
                a.properties.position = Animated(Vec2(0, -240)); a.properties.scale = Animated(Vec2(100, 160))
                return [a]
            },
            TextPreset(id: "pack.kin.shakeIn", name: "Shake In", category: "Kinetic") { s, d in
                var a = TextAnimator(name: "Shake")
                a.selector.kind = .wiggly
                a.selector.frequency = Animated(18)
                a.selector.amount = kf([(s, 100.0), (s + d, 0.0)], curve: EaseCurve(.expoOut))
                a.properties.position = Animated(Vec2(40, 30)); a.properties.rotation = Animated(12)
                return [a]
            },
            TextPreset(id: "pack.kin.zoomSmash", name: "Zoom Smash", category: "Kinetic") { s, d in
                var a = TextAnimator(name: "Zoom Smash")
                a.selector.amount = kf([(s, 100.0), (s + d * 0.4, 0.0)], curve: EaseCurve(.expoOut))
                a.properties.scale = Animated(Vec2(30, 30)); a.properties.blur = Animated(30)
                var b = TextAnimator(name: "Impact Kick")
                b.selector.amount = kf([(s + d * 0.4, 100.0), (s + d, 0.0)], curve: EaseCurve(.elasticOut))
                b.properties.scale = Animated(Vec2(118, 118))
                return [a, b]
            },
            TextPreset(id: "pack.kin.sfx", name: "Manga SFX Pop", category: "Kinetic") { s, d in
                var a = TextAnimator(name: "SFX Pop")
                a.selector = sweep(s, d * 0.6, order: .chars, soft: 15, curve: EaseCurve(.backOut))
                a.properties.scale = Animated(Vec2(0, 0)); a.properties.rotation = Animated(-25)
                var b = TextAnimator(name: "SFX Rattle")
                b.selector.kind = .wiggly
                b.selector.frequency = Animated(12)
                b.selector.amount = kf([(s + d * 0.5, 100.0), (s + d, 0.0)], interp: .linear)
                b.properties.rotation = Animated(8); b.properties.position = Animated(Vec2(5, 5))
                return [a, b]
            },
        ]

        // Neon
        out += [
            burst("neonFlicker", "Neon Flicker On", cat: "Neon", freq: 16, minAmount: 0) { $0.opacity = Animated(15); $0.fill = Animated(RGBA(hex: 0x3A1A4A)) },
            loop("neonBuzz", "Neon Buzz", kind: .wiggly, freq: 22, cat: "Neon") { $0.opacity = Animated(70) },
            TextPreset(id: "pack.neon.sweep", name: "Neon Sweep", category: "Neon") { s, d in
                var a = TextAnimator(name: "Neon Sweep")
                var sel = TextSelector(); sel.shape = .smooth; sel.start = Animated(0); sel.end = Animated(30)
                sel.offset = kf([(s, -30.0), (s + d, 100.0)], interp: .linear)
                a.selector = sel
                a.properties.fill = Animated(RGBA(hex: 0xFFFFFF)); a.properties.scale = Animated(Vec2(110, 110))
                return [a]
            },
        ]

        // 3D
        out += [
            TextPreset(id: "pack.3d.flipX", name: "Flip In (X)", category: "3D") { s, d in
                var a = TextAnimator(name: "Flip X")
                a.selector = sweep(s, d, order: .chars, curve: EaseCurve(.backOut))
                a.properties.rotationX = Animated(-90); a.properties.opacity = Animated(0)
                return [a]
            },
            TextPreset(id: "pack.3d.turnY", name: "Turn In (Y, Words)", category: "3D") { s, d in
                var a = TextAnimator(name: "Turn Y")
                a.selector = sweep(s, d, order: .words)
                a.properties.rotationY = Animated(90); a.properties.opacity = Animated(0)
                return [a]
            },
            TextPreset(id: "pack.3d.tumble", name: "Tumble", category: "3D") { s, d in
                var a = TextAnimator(name: "Tumble")
                a.selector = sweep(s, d, order: .random)
                a.properties.rotationX = Animated(180); a.properties.rotationY = Animated(120)
                a.properties.positionZ = Animated(-500); a.properties.opacity = Animated(0)
                return [a]
            },
            TextPreset(id: "pack.3d.flyThrough", name: "Fly Through", category: "3D") { s, d in
                var a = TextAnimator(name: "Fly Through")
                a.selector = sweep(s, d, order: .chars, soft: 50)
                a.properties.positionZ = Animated(-1400); a.properties.opacity = Animated(0); a.properties.blur = Animated(10)
                return [a]
            },
            TextPreset(id: "pack.3d.unfold", name: "Unfold", category: "3D") { s, d in
                var a = TextAnimator(name: "Unfold")
                a.selector = sweep(s, d, order: .lines, curve: EaseCurve(.cubicOut))
                a.properties.rotationX = Animated(-100)
                return [a]
            },
            TextPreset(id: "pack.3d.depthIn", name: "Depth Push", category: "3D") { s, d in
                var a = TextAnimator(name: "Depth Push")
                a.selector = sweep(s, d, order: .words, curve: EaseCurve(.expoOut))
                a.properties.positionZ = Animated(900); a.properties.opacity = Animated(0)
                return [a]
            },
            loop("spinY", "Spin Y Loop", kind: .wave, freq: 0.5, spread: 12, cat: "3D") { $0.rotationY = Animated(180) },
            loop("depthWave", "Depth Wave", kind: .wave, freq: 0.9, spread: 6, cat: "3D") { $0.positionZ = Animated(-260) },
        ]
        return out
    }()
}
