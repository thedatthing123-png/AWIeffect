import Foundation
import simd

// MARK: - Interpolatable values

protocol Interpolatable: Codable, Equatable {
    static func lerp(_ a: Self, _ b: Self, _ t: Double) -> Self
}

extension Double: Interpolatable {
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}

struct Vec2: Interpolatable, Hashable {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    static let zero = Vec2(0, 0)
    static func lerp(_ a: Vec2, _ b: Vec2, _ t: Double) -> Vec2 {
        Vec2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    }
    static func + (l: Vec2, r: Vec2) -> Vec2 { Vec2(l.x + r.x, l.y + r.y) }
    static func - (l: Vec2, r: Vec2) -> Vec2 { Vec2(l.x - r.x, l.y - r.y) }
    static func * (l: Vec2, r: Double) -> Vec2 { Vec2(l.x * r, l.y * r) }
}

/// Straight (non-premultiplied) sRGB color, components 0...1.
struct RGBA: Interpolatable, Hashable {
    var r: Double, g: Double, b: Double, a: Double
    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    init(hex: UInt32, alpha: Double = 1) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255, alpha)
    }
    static func lerp(_ a: RGBA, _ b: RGBA, _ t: Double) -> RGBA {
        RGBA(Double.lerp(a.r, b.r, t), Double.lerp(a.g, b.g, t), Double.lerp(a.b, b.b, t), Double.lerp(a.a, b.a, t))
    }
    static let black = RGBA(0, 0, 0)
    static let white = RGBA(1, 1, 1)
    var simd: SIMD4<Float> { SIMD4(Float(r), Float(g), Float(b), Float(a)) }
}

// MARK: - Keyframes

enum Interpolation: String, Codable, CaseIterable {
    case linear, bezier, hold
}

/// Temporal ease handle in normalized segment space (x = time fraction, y = value fraction).
struct EaseHandle: Codable, Equatable {
    var x: Double
    var y: Double
    /// AE "Easy Ease" ≈ 33.33% influence, zero speed.
    static let easyOut = EaseHandle(x: 1.0 / 3.0, y: 0)
    static let easyIn = EaseHandle(x: 2.0 / 3.0, y: 1)
    static let linearOut = EaseHandle(x: 1.0 / 3.0, y: 1.0 / 3.0)
    static let linearIn = EaseHandle(x: 2.0 / 3.0, y: 2.0 / 3.0)
}

struct Keyframe<Value: Interpolatable>: Codable, Equatable, Identifiable {
    var id = UUID()
    var time: Double
    var value: Value
    /// Interpolation used for the segment leaving this keyframe.
    var interpolation: Interpolation = .linear
    /// Outgoing handle (used when interpolation == .bezier).
    var easeOut: EaseHandle = .easyOut
    /// Incoming handle for the segment arriving at this keyframe.
    var easeIn: EaseHandle = .easyIn
    /// Flow-style math curve for the segment leaving this keyframe (bounce, elastic, back, expo…). When set it
    /// replaces the bezier handles; nil = use the handles.
    var curve: EaseCurve? = nil
}

/// Easing curves that a single bezier can't draw (Flow-style): real bounces, elastic wobbles, Penner families.
struct EaseCurve: Codable, Equatable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case sineIn, sineOut, sineInOut, quadIn, quadOut, quadInOut, cubicIn, cubicOut, cubicInOut
        case quartIn, quartOut, quartInOut, quintIn, quintOut, quintInOut, expoIn, expoOut, expoInOut
        case circIn, circOut, circInOut, backIn, backOut, backInOut, bounceOut, bounceIn, elasticOut, elasticIn
        case overshoot, smoothStop, snap
        var id: String { rawValue }

        var title: String {
            switch self {
            case .sineIn: return "Sine In"
            case .sineOut: return "Sine Out"
            case .sineInOut: return "Sine In-Out"
            case .quadIn: return "Quad In"
            case .quadOut: return "Quad Out"
            case .quadInOut: return "Quad In-Out"
            case .cubicIn: return "Cubic In"
            case .cubicOut: return "Cubic Out"
            case .cubicInOut: return "Cubic In-Out"
            case .quartIn: return "Quart In"
            case .quartOut: return "Quart Out"
            case .quartInOut: return "Quart In-Out"
            case .quintIn: return "Quint In"
            case .quintOut: return "Quint Out"
            case .quintInOut: return "Quint In-Out"
            case .expoIn: return "Expo In"
            case .expoOut: return "Expo Out"
            case .expoInOut: return "Expo In-Out"
            case .circIn: return "Circ In"
            case .circOut: return "Circ Out"
            case .circInOut: return "Circ In-Out"
            case .backIn: return "Back In"
            case .backOut: return "Back Out"
            case .backInOut: return "Back In-Out"
            case .bounceOut: return "Bounce"
            case .bounceIn: return "Bounce In"
            case .elasticOut: return "Elastic"
            case .elasticIn: return "Elastic In"
            case .overshoot: return "Overshoot"
            case .smoothStop: return "Smooth Stop"
            case .snap: return "Snap"
            }
        }

        /// Settings the curve has (labels for a and b); nil = none.
        var paramA: (String, ClosedRange<Double>, Double)? {
            switch self {
            case .bounceOut, .bounceIn: return ("Bounces", 1...8, 3)
            case .elasticOut, .elasticIn: return ("Wobbles", 1...10, 3)
            case .backIn, .backOut, .backInOut, .overshoot: return ("Overshoot", 0...4, 1.7)
            default: return nil
            }
        }
        var paramB: (String, ClosedRange<Double>, Double)? {
            switch self {
            case .bounceOut, .bounceIn: return ("Bounciness", 0.15...0.8, 0.45)
            case .elasticOut, .elasticIn: return ("Settle", 1...14, 6)
            default: return nil
            }
        }
    }

    var kind: Kind
    var a: Double
    var b: Double

    init(_ kind: Kind) {
        self.kind = kind
        a = kind.paramA?.2 ?? 0
        b = kind.paramB?.2 ?? 0
    }

    /// Progress 0…1 (may overshoot) at time fraction x 0…1.
    func progress(_ x: Double) -> Double {
        let x = min(max(x, 0), 1)
        func inOut(_ f: (Double) -> Double) -> Double { x < 0.5 ? f(x * 2) / 2 : 1 - f((1 - x) * 2) / 2 }
        func pow_(_ n: Double) -> (Double) -> Double { { pow($0, n) } }
        switch kind {
        case .sineIn: return 1 - cos(x * .pi / 2)
        case .sineOut: return sin(x * .pi / 2)
        case .sineInOut: return -(cos(.pi * x) - 1) / 2
        case .quadIn: return x * x
        case .quadOut: return 1 - (1 - x) * (1 - x)
        case .quadInOut: return inOut(pow_(2))
        case .cubicIn: return x * x * x
        case .cubicOut: return 1 - pow(1 - x, 3)
        case .cubicInOut: return inOut(pow_(3))
        case .quartIn: return pow(x, 4)
        case .quartOut: return 1 - pow(1 - x, 4)
        case .quartInOut: return inOut(pow_(4))
        case .quintIn: return pow(x, 5)
        case .quintOut: return 1 - pow(1 - x, 5)
        case .quintInOut: return inOut(pow_(5))
        case .expoIn: return x <= 0 ? 0 : pow(2, 10 * x - 10)
        case .expoOut: return x >= 1 ? 1 : 1 - pow(2, -10 * x)
        case .expoInOut: return inOut { $0 <= 0 ? 0 : pow(2, 10 * $0 - 10) }
        case .circIn: return 1 - sqrt(max(0, 1 - x * x))
        case .circOut: return sqrt(max(0, 1 - (x - 1) * (x - 1)))
        case .circInOut: return inOut { 1 - sqrt(max(0, 1 - $0 * $0)) }
        case .backIn: return (a + 1) * x * x * x - a * x * x
        case .backOut, .overshoot:
            let u = x - 1
            return 1 + (a + 1) * u * u * u + a * u * u
        case .backInOut:
            let s = a * 1.525
            return inOut { ($0 * $0) * ((s + 1) * $0 - s) }
        case .bounceOut: return Self.bounce(x, count: Int(a.rounded()), r: b)
        case .bounceIn: return 1 - Self.bounce(1 - x, count: Int(a.rounded()), r: b)
        case .elasticOut: return Self.elastic(x, wobbles: a, settle: b)
        case .elasticIn: return 1 - Self.elastic(1 - x, wobbles: a, settle: b)
        case .smoothStop: return 1 - pow(1 - x, 6)
        case .snap: return x < 0.5 ? 16 * pow(x, 5) : 1 - pow(-2 * x + 2, 5) / 2
        }
    }

    /// A ball dropped onto 1: falls, then `count` bounces, each `r` times as long as the one before (real
    /// gravity: heights scale with duration squared).
    static func bounce(_ x: Double, count: Int, r: Double) -> Double {
        let n = max(1, min(12, count)), r = min(max(r, 0.05), 0.95)
        var total = 1.0
        for k in 1...n { total += 2 * pow(r, Double(k)) }
        let t0 = 1 / total
        if x < t0 { let u = x / t0; return u * u }
        var start = t0
        for k in 1...n {
            let d = 2 * t0 * pow(r, Double(k))
            if x < start + d || k == n {
                let u = min(1, (x - start) / d) * 2 - 1      // -1…1 across the bounce
                let h = pow(r, Double(2 * k))
                return 1 - h * (1 - u * u)
            }
            start += d
        }
        return 1
    }

    /// Spring that overshoots and wobbles into place; always lands exactly on 1.
    static func elastic(_ x: Double, wobbles: Double, settle: Double) -> Double {
        let raw = 1 - exp(-settle * x) * cos(2 * .pi * wobbles * x)
        let land = pow(x, 6)
        return raw * (1 - land) + land
    }
}

/// Solves a CSS/AE-style timing curve: cubic bezier from (0,0) to (1,1) with control points p1, p2.
enum BezierTiming {
    static func progress(x: Double, p1: EaseHandle, p2: EaseHandle) -> Double {
        let x = min(max(x, 0), 1)
        func bx(_ t: Double) -> Double { bezier(t, 0, p1.x, p2.x, 1) }
        func by(_ t: Double) -> Double { bezier(t, 0, p1.y, p2.y, 1) }
        func dbx(_ t: Double) -> Double { derivative(t, 0, p1.x, p2.x, 1) }
        // Newton-Raphson, fall back to bisection.
        var t = x
        for _ in 0..<8 {
            let err = bx(t) - x
            if abs(err) < 1e-7 { return by(t) }
            let d = dbx(t)
            if abs(d) < 1e-6 { break }
            t -= err / d
        }
        var lo = 0.0, hi = 1.0
        t = x
        for _ in 0..<40 {
            let v = bx(t)
            if abs(v - x) < 1e-7 { break }
            if v < x { lo = t } else { hi = t }
            t = (lo + hi) / 2
        }
        return by(t)
    }

    static func bezier(_ t: Double, _ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        let u = 1 - t
        return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
    }

    static func derivative(_ t: Double, _ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * (b - a) + 6 * u * t * (c - b) + 3 * t * t * (d - c)
    }
}

/// Two keyframe times closer than this are the same keyframe.
let keyframeTimeEpsilon = 1e-4

/// A property that is either static or keyframed (AE stopwatch semantics).
struct Animated<Value: Interpolatable>: Codable, Equatable {
    var staticValue: Value
    var keyframes: [Keyframe<Value>] = []
    /// AE-style expression (JavaScript). Evaluated by ExpressionEngine before rendering; nil = none.
    var expression: String? = nil
    var expressionEnabled = true

    init(_ value: Value) { staticValue = value }

    private enum CodingKeys: String, CodingKey { case staticValue, keyframes, expression, expressionEnabled }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        staticValue = try c.decode(Value.self, forKey: .staticValue)
        keyframes = try c.decodeIfPresent([Keyframe<Value>].self, forKey: .keyframes) ?? []
        expression = try c.decodeIfPresent(String.self, forKey: .expression)
        expressionEnabled = try c.decodeIfPresent(Bool.self, forKey: .expressionEnabled) ?? true
    }

    var hasActiveExpression: Bool { expressionEnabled && !(expression ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var isAnimated: Bool { !keyframes.isEmpty }

    func value(at time: Double) -> Value {
        guard let first = keyframes.first else { return staticValue }
        if keyframes.count == 1 || time <= first.time { return first.value }
        let last = keyframes[keyframes.count - 1]
        if time >= last.time { return last.value }
        // Binary search for the segment.
        var lo = 0, hi = keyframes.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if keyframes[mid].time <= time { lo = mid } else { hi = mid }
        }
        let a = keyframes[lo], b = keyframes[hi]
        let span = b.time - a.time
        guard span > 0 else { return b.value }
        let x = (time - a.time) / span
        switch a.interpolation {
        case .hold: return a.value
        case .linear: return Value.lerp(a.value, b.value, x)
        case .bezier:
            if let c = a.curve { return Value.lerp(a.value, b.value, c.progress(x)) }
            return Value.lerp(a.value, b.value, BezierTiming.progress(x: x, p1: a.easeOut, p2: b.easeIn))
        }
    }

    func keyframeIndex(at time: Double) -> Int? {
        keyframes.firstIndex { abs($0.time - time) < keyframeTimeEpsilon }
    }

    func hasKeyframe(at time: Double) -> Bool { keyframeIndex(at: time) != nil }

    /// Sets the value at `time`: updates/inserts a keyframe when animated, else sets the static value.
    mutating func set(_ value: Value, at time: Double) {
        if isAnimated {
            if let i = keyframeIndex(at: time) {
                keyframes[i].value = value
            } else {
                insertKeyframe(Keyframe(time: time, value: value, interpolation: defaultInterpolation))
            }
        } else {
            staticValue = value
        }
    }

    private var defaultInterpolation: Interpolation { keyframes.last?.interpolation ?? .linear }

    mutating func insertKeyframe(_ kf: Keyframe<Value>) {
        if let i = keyframeIndex(at: kf.time) { keyframes[i] = kf; return }
        let idx = keyframes.firstIndex { $0.time > kf.time } ?? keyframes.count
        keyframes.insert(kf, at: idx)
    }

    /// Stopwatch-style toggle at `time`: adds a keyframe with the current value, or removes it.
    mutating func toggleKeyframe(at time: Double) {
        if let i = keyframeIndex(at: time) {
            let v = keyframes[i].value
            keyframes.remove(at: i)
            if keyframes.isEmpty { staticValue = v }
        } else {
            insertKeyframe(Keyframe(time: time, value: value(at: time), interpolation: defaultInterpolation))
        }
    }

    mutating func setInterpolation(_ interp: Interpolation) {
        for i in keyframes.indices { keyframes[i].interpolation = interp }
    }

    var keyframeTimes: [Double] { keyframes.map(\.time) }
}
