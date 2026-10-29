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

/// A property that is either static or keyframed (AE stopwatch semantics).
struct Animated<Value: Interpolatable>: Codable, Equatable {
    var staticValue: Value
    var keyframes: [Keyframe<Value>] = []

    init(_ value: Value) { staticValue = value }

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
        case .bezier: return Value.lerp(a.value, b.value, BezierTiming.progress(x: x, p1: a.easeOut, p2: b.easeIn))
        }
    }

    static let timeEpsilon = 1e-4

    func keyframeIndex(at time: Double) -> Int? {
        keyframes.firstIndex { abs($0.time - time) < Self.timeEpsilon }
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
