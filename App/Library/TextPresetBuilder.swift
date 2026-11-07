import Foundation

/// Small builder for library presets: eased keyframes, reveal / accent / loop / beat selectors and animators.
/// Every keyframe gets a real ease curve (no linear motion unless asked for).
enum TPB {
    typealias Ease = EaseCurve.Kind

    /// Keyframes that all leave with `curve` (nil = the default bezier ease, `linear` = straight on purpose).
    static func kf<V: Interpolatable>(_ pairs: [(Double, V)], _ curve: Ease? = .cubicOut, linear: Bool = false) -> Animated<V> {
        var a = Animated(pairs[0].1)
        for (t, v) in pairs {
            var k = Keyframe(time: t, value: v, interpolation: linear ? .linear : .bezier)
            if !linear { k.curve = curve.map { EaseCurve($0) } }
            a.insertKeyframe(k)
        }
        return a
    }

    /// Keyframes with a curve per segment (the curve leaving each key).
    static func kfs<V: Interpolatable>(_ keys: [(Double, V, Ease?)]) -> Animated<V> {
        var a = Animated(keys[0].1)
        for (t, v, c) in keys {
            var k = Keyframe(time: t, value: v, interpolation: .bezier)
            k.curve = c.map { EaseCurve($0) }
            a.insertKeyframe(k)
        }
        return a
    }

    /// Hold keys (hard cuts: strobes, impact frames).
    static func hold<V: Interpolatable>(_ pairs: [(Double, V)]) -> Animated<V> {
        var a = Animated(pairs[0].1)
        for (t, v) in pairs { a.insertKeyframe(Keyframe(time: t, value: v, interpolation: .hold)) }
        return a
    }

    static func n(_ v: Double) -> Animated<Double> { Animated(v) }
    static func v(_ x: Double, _ y: Double) -> Animated<Vec2> { Animated(Vec2(x, y)) }
    static func c(_ hex: UInt32) -> Animated<RGBA> { Animated(RGBA(hex: hex)) }

    enum Order { case forward, reverse, random }

    /// Reveal window sweeping across units. In: units behind the window are done (amount 0), units ahead are still
    /// "away" (amount 1). `out` flips it (units leave). `soft` = % of the text moving at once.
    static func reveal(_ s: Double, _ d: Double, _ unit: TextUnit = .characters, soft: Double = 35, curve: Ease? = .cubicOut,
                       linear: Bool = false, order: Order = .forward, out: Bool = false, seed: Int = 7, easeHigh: Double = 0, easeLow: Double = 0) -> TextSelector {
        var sel = TextSelector()
        sel.basedOn = unit
        sel.randomize = order == .random
        sel.seed = seed
        sel.easeHigh = easeHigh
        sel.easeLow = easeLow
        let backward = order == .reverse
        sel.shape = (out != backward) ? .rampDown : .rampUp
        if backward {
            sel.start = kf([(s, 100.0), (s + d, -soft)], curve, linear: linear)
            sel.end = kf([(s, 100.0 + soft), (s + d, 0.0)], curve, linear: linear)
        } else {
            sel.start = kf([(s, -soft), (s + d, 100.0)], curve, linear: linear)
            sel.end = kf([(s, 0.0), (s + d, 100.0 + soft)], curve, linear: linear)
        }
        return sel
    }

    /// A narrow selected window (triangle) travelling across the text: accents, overshoots, highlights.
    static func accent(_ s: Double, _ d: Double, _ unit: TextUnit = .characters, delay: Double = 0.12, soft: Double = 30,
                       curve: Ease? = .sineInOut, linear: Bool = false, order: Order = .forward, shape: SelectorShape = .triangle, seed: Int = 7) -> TextSelector {
        var sel = TextSelector()
        sel.basedOn = unit
        sel.shape = shape
        sel.randomize = order == .random
        sel.seed = seed
        sel.start = Animated(0)
        sel.end = Animated(soft)
        let t0 = s + d * delay
        if order == .reverse {
            sel.offset = kf([(t0, 100.0), (t0 + d, -soft)], curve, linear: linear)
        } else {
            sel.offset = kf([(t0, -soft), (t0 + d, 100.0)], curve, linear: linear)
        }
        return sel
    }

    /// Whole text, amount animated by keys (percent).
    static func amount(_ keys: [(Double, Double, Ease?)], _ unit: TextUnit = .characters) -> TextSelector {
        var sel = TextSelector()
        sel.basedOn = unit
        sel.amount = kfs(keys)
        return sel
    }

    /// Whole text from `from`% to `to`% over [s, s+d].
    static func whole(_ s: Double, _ d: Double, from: Double = 100, to: Double = 0, curve: Ease? = .cubicOut, _ unit: TextUnit = .characters) -> TextSelector {
        amount([(s, from, curve), (s + d, to, nil)], unit)
    }

    /// Fixed range of the text (percent) with an animated amount.
    static func part(_ a: Double, _ b: Double, amount: Animated<Double>, _ unit: TextUnit = .characters, shape: SelectorShape = .square) -> TextSelector {
        var sel = TextSelector()
        sel.basedOn = unit
        sel.shape = shape
        sel.start = Animated(a)
        sel.end = Animated(b)
        sel.amount = amount
        return sel
    }

    /// Loop amount: eases in at the start so loops never pop on.
    static func loopAmount(_ s: Double, to: Double = 100) -> Animated<Double> { kf([(s, 0.0), (s + 0.35, to)], .sineInOut) }

    static func wave(_ s: Double, freq: Double, spread: Double = 6, _ unit: TextUnit = .characters, amount: Animated<Double>? = nil,
                     offset: Double = 0) -> TextSelector {
        var sel = TextSelector()
        sel.kind = .wave
        sel.basedOn = unit
        sel.frequency = Animated(freq)
        sel.spread = Animated(spread)
        sel.offset = Animated(offset)
        sel.amount = amount ?? loopAmount(s)
        return sel
    }

    static func wiggly(_ s: Double, freq: Double, _ unit: TextUnit = .characters, min: Double = -100, max: Double = 100, seed: Int = 1,
                       amount: Animated<Double>? = nil) -> TextSelector {
        var sel = TextSelector()
        sel.kind = .wiggly
        sel.basedOn = unit
        sel.frequency = Animated(freq)
        sel.minAmount = min
        sel.maxAmount = max
        sel.seed = seed
        sel.amount = amount ?? loopAmount(s)
        return sel
    }

    /// Per-unit random amount (steady per letter); the amount keys make it move.
    static func random(seed: Int, min: Double = 0, max: Double = 100, _ unit: TextUnit = .characters, amount: Animated<Double>) -> TextSelector {
        var sel = TextSelector()
        sel.kind = .random
        sel.basedOn = unit
        sel.seed = seed
        sel.minAmount = min
        sel.maxAmount = max
        sel.amount = amount
        return sel
    }

    /// Pulses on the project's beat markers.
    static func beat(_ s: Double, attack: Double = 0.03, decay: Double = 0.22, _ unit: TextUnit = .characters) -> TextSelector {
        var sel = TextSelector()
        sel.kind = .beat
        sel.basedOn = unit
        sel.beatAttack = Animated(attack)
        sel.beatDecay = Animated(decay)
        sel.amount = loopAmount(s)
        return sel
    }

    static func anim(_ name: String, _ sels: [TextSelector], fx: [EffectInstance] = [], _ set: (inout TextAnimatorProperties) -> Void) -> TextAnimator {
        var a = TextAnimator(name: name)
        if !sels.isEmpty { a.allSelectors = sels }
        set(&a.properties)
        a.letterEffects = fx.isEmpty ? nil : fx
        return a
    }

    static func anim(_ name: String, _ sel: TextSelector, fx: [EffectInstance] = [], _ set: (inout TextAnimatorProperties) -> Void) -> TextAnimator {
        anim(name, [sel], fx: fx, set)
    }

    /// A letter / layer effect with settings (nil when the effect id is unknown).
    static func fx(_ id: String, _ values: [String: Double] = [:]) -> [EffectInstance] {
        guard var e = EffectRegistry.definition(id)?.makeInstance() else { return [] }
        for (k, v) in values { e.params[k] = .number(Animated(v)) }
        return [e]
    }

    static func p(_ id: String, _ name: String, _ cat: String, _ make: @escaping (Double, Double) -> [TextAnimator]) -> TextPreset {
        TextPreset(id: "lib.\(id)", name: name, category: cat, make: make)
    }
}

extension TextSelector {
    /// Copy with a combine mode (for stacking under another selector).
    func combined(_ m: SelectorMode) -> TextSelector { var s = self; s.mode = m; return s }
}
