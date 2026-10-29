import Foundation

enum TextAlignment: String, Codable, CaseIterable { case left, center, right }

/// A colored span inside the text (per-letter / per-word color).
struct TextColorSpan: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Character range [start, end) in the string's Character indices.
    var start: Int
    var end: Int
    var color: RGBA
}

struct TextData: Codable, Equatable {
    var string: String
    var fontName: String = "Helvetica-Bold"
    var fontSize: Double = 120
    var fill = Animated(RGBA.white)
    var tracking = Animated(0.0)
    var lineSpacing = Animated(1.15)
    var alignment: TextAlignment = .center
    var colorSpans: [TextColorSpan] = []
    var animators: [TextAnimator] = []

    func baseColor(forCharacter i: Int, time: Double) -> RGBA {
        if let span = colorSpans.last(where: { i >= $0.start && i < $0.end }) { return span.color }
        return fill.value(at: time)
    }
}

// MARK: - Animators (AE Text Animator model)

/// Units a selector counts in (AE "Based On").
enum TextUnit: String, Codable, CaseIterable, Identifiable {
    case characters, charactersExcludingSpaces, words, lines
    var id: String { rawValue }
    var title: String {
        switch self {
        case .characters: return "Characters"
        case .charactersExcludingSpaces: return "Characters Excl. Spaces"
        case .words: return "Words"
        case .lines: return "Lines"
        }
    }
}

/// AE Range Selector shapes.
enum SelectorShape: String, Codable, CaseIterable, Identifiable {
    case square, rampUp, rampDown, triangle, round, smooth
    var id: String { rawValue }
    var title: String {
        switch self {
        case .square: return "Square"
        case .rampUp: return "Ramp Up"
        case .rampDown: return "Ramp Down"
        case .triangle: return "Triangle"
        case .round: return "Round"
        case .smooth: return "Smooth"
        }
    }
}

enum SelectorKind: String, Codable, CaseIterable {
    /// AE Range Selector.
    case range
    /// AE Wiggly Selector: per-unit random amount that drifts over time.
    case wiggly
    /// Sine wave travelling across units (common "wave" text, AE does it with an Expression Selector).
    case wave
}

struct TextSelector: Codable, Equatable {
    var kind: SelectorKind = .range
    var basedOn: TextUnit = .characters
    // Range
    var start = Animated(0.0)          // percent
    var end = Animated(100.0)          // percent
    var offset = Animated(0.0)         // percent
    var shape: SelectorShape = .square
    var easeHigh = 0.0                 // percent, -100...100
    var easeLow = 0.0
    var randomize = false
    var seed = 0
    var amount = Animated(100.0)       // percent
    // Wiggly / wave
    var frequency = Animated(2.0)      // wiggles or waves per second
    var spread = Animated(3.0)         // wave: units per cycle; wiggly: correlation (unused = 0)
    var minAmount = -100.0
    var maxAmount = 100.0
}

/// Properties an animator offsets. nil = not used (like AE's "Add Property" list).
struct TextAnimatorProperties: Codable, Equatable {
    var position: Animated<Vec2>? = nil
    var scale: Animated<Vec2>? = nil      // percent, absolute target (100 = no change)
    var rotation: Animated<Double>? = nil // degrees
    var opacity: Animated<Double>? = nil  // percent target (100 = no change)
    var fill: Animated<RGBA>? = nil
    var tracking: Animated<Double>? = nil // px added between units
    var skew: Animated<Double>? = nil     // degrees
}

struct TextAnimator: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var isEnabled = true
    var selector = TextSelector()
    var properties = TextAnimatorProperties()
}

// MARK: - Selector math

enum SelectorMath {
    /// Selection amount (−1...1, usually 0...1) for unit `index` of `count` at `time`.
    static func amount(_ s: TextSelector, index: Int, count: Int, time: Double) -> Double {
        guard count > 0 else { return 0 }
        let amt = s.amount.value(at: time) / 100
        switch s.kind {
        case .range:
            let order = s.randomize ? randomOrder(count: count, seed: s.seed)[index] : index
            return rangeCoverage(s, unit: order, count: count, time: time) * amt
        case .wiggly:
            let f = s.frequency.value(at: time)
            let n = Wiggle.value(t: time, freq: max(0.01, f), octaves: 1, seed: Double(index) * 7.13 + Double(s.seed))
            let lo = s.minAmount / 100, hi = s.maxAmount / 100
            return (lo + (n * 0.5 + 0.5) * (hi - lo)) * amt
        case .wave:
            let f = s.frequency.value(at: time)
            let spread = max(0.1, s.spread.value(at: time))
            return sin(2 * .pi * (time * f - Double(index) / spread)) * amt
        }
    }

    /// AE range selector coverage for one unit, with shape and ease.
    static func rangeCoverage(_ s: TextSelector, unit: Int, count: Int, time: Double) -> Double {
        let off = s.offset.value(at: time)
        var a = s.start.value(at: time) + off
        var b = s.end.value(at: time) + off
        if a > b { swap(&a, &b) }
        let u0 = Double(unit) / Double(count) * 100, u1 = Double(unit + 1) / Double(count) * 100
        let uc = (u0 + u1) / 2
        switch s.shape {
        case .square:
            // Fraction of the unit's span inside [a, b].
            let overlap = max(0, min(b, u1) - max(a, u0))
            return overlap / max(u1 - u0, 1e-9)
        case .rampUp, .rampDown, .triangle, .round, .smooth:
            let span = max(b - a, 1e-9)
            let t = (uc - a) / span
            var v: Double
            switch s.shape {
            case .rampUp: v = t <= 0 ? 0 : (t >= 1 ? 1 : t)
            case .rampDown: v = t <= 0 ? 1 : (t >= 1 ? 0 : 1 - t)
            case .triangle: v = (t <= 0 || t >= 1) ? 0 : 1 - abs(2 * t - 1)
            case .round: v = (t <= 0 || t >= 1) ? 0 : (1 - pow(2 * t - 1, 2)).squareRoot()
            default: v = (t <= 0 || t >= 1) ? 0 : 0.5 - 0.5 * cos(2 * .pi * t)
            }
            return ease(v, high: s.easeHigh / 100, low: s.easeLow / 100)
        }
    }

    /// Ease High flattens the top of the curve, Ease Low the bottom (AE semantics: positive = slower).
    static func ease(_ v: Double, high: Double, low: Double) -> Double {
        guard high != 0 || low != 0 else { return v }
        let p1 = EaseHandle(x: max(0, low) / 3, y: 0)
        let p2 = EaseHandle(x: 1 - max(0, high) / 3, y: 1)
        return BezierTiming.progress(x: v, p1: low >= 0 ? p1 : EaseHandle(x: 1.0 / 3, y: 1.0 / 3 - low / 3),
                                     p2: high >= 0 ? p2 : EaseHandle(x: 2.0 / 3, y: 2.0 / 3 + high / 3))
    }

    static func randomOrder(count: Int, seed: Int) -> [Int] {
        var idx = Array(0..<count)
        var state = UInt64(truncatingIfNeeded: seed &* 2654435761 &+ 1)
        for i in stride(from: count - 1, to: 0, by: -1) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let j = Int((state >> 33) % UInt64(i + 1))
            idx.swapAt(i, j)
        }
        return idx
    }
}

// MARK: - Presets (premade text animations — each one built from real animators)

struct TextPreset: Identifiable {
    let id: String
    let name: String
    let make: (_ start: Double, _ duration: Double) -> [TextAnimator]
}

enum TextPresets {
    private static func kf<V: Interpolatable>(_ pairs: [(Double, V)], interp: Interpolation = .bezier) -> Animated<V> {
        var a = Animated(pairs[0].1)
        for (t, v) in pairs { a.insertKeyframe(Keyframe(time: t, value: v, interpolation: interp)) }
        return a
    }

    /// A range-selector reveal: a soft window [start, start+soft] sweeps across the text.
    /// Units before the window are finished (amount 0), units after it are still fully offset (amount 1),
    /// units inside it are in transition. With `.triangle` the window itself is selected (overshoot accents).
    private static func sweep(_ s: Double, _ d: Double, shape: SelectorShape = .rampUp, basedOn: TextUnit = .characters,
                              soft: Double = 30, easeHigh: Double = 0) -> TextSelector {
        var sel = TextSelector()
        sel.basedOn = basedOn
        sel.shape = shape
        sel.easeHigh = easeHigh
        sel.start = kf([(s, -soft), (s + d, 100.0)])
        sel.end = kf([(s, 0.0), (s + d, 100.0 + soft)])
        return sel
    }

    static let all: [TextPreset] = [
        TextPreset(id: "typewriter", name: "Typewriter") { s, d in
            var a = TextAnimator(name: "Typewriter")
            a.selector = TextSelector(basedOn: .characters, start: kf([(s, 0.0), (s + d, 100.0)], interp: .linear), shape: .square)
            a.properties.opacity = Animated(0)
            // Selected = already typed, so invert: animate the start of the hidden range.
            a.selector.start = kf([(s, 0.0), (s + d, 100.0)], interp: .linear)
            a.selector.end = Animated(100)
            return [a]
        },
        TextPreset(id: "fadeUp", name: "Fade Up") { s, d in
            var a = TextAnimator(name: "Fade Up")
            a.selector = sweep(s, d, shape: .rampUp, soft: 40)
            a.properties.opacity = Animated(0)
            a.properties.position = Animated(Vec2(0, 60))
            return [a]
        },
        TextPreset(id: "bounceIn", name: "Bounce In") { s, d in
            var a = TextAnimator(name: "Bounce In")
            a.selector = sweep(s, d, shape: .rampUp, soft: 30)
            a.properties.scale = Animated(Vec2(0, 0))
            a.properties.opacity = Animated(0)
            a.properties.position = Animated(Vec2(0, -80))
            var b = TextAnimator(name: "Overshoot")
            b.selector = sweep(s + d * 0.15, d, shape: .triangle, soft: 30)
            b.properties.scale = Animated(Vec2(125, 125))
            return [a, b]
        },
        TextPreset(id: "scalePop", name: "Scale Pop") { s, d in
            var a = TextAnimator(name: "Scale Pop")
            a.selector.amount = kf([(s, 100.0), (s + d * 0.6, -18.0), (s + d, 0.0)])
            a.properties.scale = Animated(Vec2(0, 0))
            return [a]
        },
        TextPreset(id: "slideStagger", name: "Slide Stagger") { s, d in
            var a = TextAnimator(name: "Slide")
            a.selector = sweep(s, d, shape: .rampUp, basedOn: .words, soft: 50, easeHigh: 60)
            a.properties.position = Animated(Vec2(-220, 0))
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "wave", name: "Wave") { _, _ in
            var a = TextAnimator(name: "Wave")
            a.selector.kind = .wave
            a.selector.frequency = Animated(1.2)
            a.selector.spread = Animated(6)
            a.properties.position = Animated(Vec2(0, -28))
            return [a]
        },
        TextPreset(id: "glitch", name: "Glitch") { s, d in
            var a = TextAnimator(name: "Glitch Jitter")
            a.selector.kind = .wiggly
            a.selector.frequency = Animated(14)
            a.selector.amount = kf([(s, 100.0), (s + d, 0.0)], interp: .linear)
            a.properties.position = Animated(Vec2(24, 6))
            a.properties.skew = Animated(14)
            var b = TextAnimator(name: "Glitch Color")
            b.selector.kind = .wiggly
            b.selector.frequency = Animated(10)
            b.selector.seed = 7
            b.selector.minAmount = 0
            b.selector.amount = kf([(s, 100.0), (s + d, 0.0)], interp: .linear)
            b.properties.fill = Animated(RGBA(hex: 0x5CFFF0))
            return [a, b]
        },
        TextPreset(id: "flicker", name: "Flicker In") { s, d in
            var a = TextAnimator(name: "Flicker")
            a.selector.kind = .wiggly
            a.selector.frequency = Animated(18)
            a.selector.minAmount = 0
            a.selector.amount = kf([(s, 100.0), (s + d, 0.0)], interp: .linear)
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "trackingIn", name: "Tracking In") { s, d in
            var a = TextAnimator(name: "Tracking In")
            a.selector.amount = kf([(s, 100.0), (s + d, 0.0)])
            a.properties.tracking = Animated(80)
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "spinIn", name: "Spin In") { s, d in
            var a = TextAnimator(name: "Spin In")
            a.selector = sweep(s, d, shape: .rampUp, soft: 40)
            a.properties.rotation = Animated(-180)
            a.properties.scale = Animated(Vec2(0, 0))
            return [a]
        },
        TextPreset(id: "dropIn", name: "Drop In (Words)") { s, d in
            var a = TextAnimator(name: "Drop In")
            a.selector = sweep(s, d, shape: .rampUp, basedOn: .words, soft: 30)
            a.properties.position = Animated(Vec2(0, -300))
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "colorSweep", name: "Color Sweep") { s, d in
            var a = TextAnimator(name: "Color Sweep")
            var sel = TextSelector()
            sel.shape = .smooth
            sel.start = Animated(0)
            sel.end = Animated(35)
            sel.offset = kf([(s, -35.0), (s + d, 100.0)], interp: .linear)
            a.selector = sel
            a.properties.fill = Animated(RGBA(hex: 0xB98CFF))
            a.properties.scale = Animated(Vec2(118, 118))
            return [a]
        },
    ]
}
