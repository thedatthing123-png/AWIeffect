import Foundation
import Metal
import simd

// MARK: - R4 grade controls (offset wheel, wheel luminance, add/remove curve points, hue curves, qualifier)

extension EffectRegistry {
    /// Added controls of the CC Studio Grade. Their defaults change nothing, and a grade that leaves every one of them
    /// at its default renders through the original kernel, so saved projects look exactly the same.
    static let gradeR4Params: [ParamDef] = {
        var p: [ParamDef] = [
            .number("offR", "Offset Red", 0, -100, 100), .number("offG", "Offset Green", 0, -100, 100), .number("offB", "Offset Blue", 0, -100, 100),
            .number("liftY", "Lift Luminance", 0, -100, 100), .number("gammaY", "Gamma Luminance", 0, -100, 100),
            .number("gainY", "Gain Luminance", 0, -100, 100), .number("offY", "Offset Luminance", 0, -100, 100),
        ]
        for (c, cn) in [("m", "Curve"), ("r", "Red"), ("g", "Green"), ("b", "Blue")] {
            for (s, sn) in [("25", "Shadows"), ("50", "Mids"), ("75", "Highs")] {
                p.append(.toggle(c + s + "on", "\(cn) \(sn) Point", true))
            }
            for k in 1...3 {
                p.append(.number("\(c)e\(k)x", "\(cn) Point \(k + 3) Input", 50, 2, 98))
                p.append(.number("\(c)e\(k)y", "\(cn) Point \(k + 3)", 50, 0, 100))
                p.append(.toggle("\(c)e\(k)on", "\(cn) Point \(k + 3) On", false))
            }
        }
        for (i, n) in GradeR4.vectorNames.enumerated() {
            p.append(.number("hueHue\(i)", "Hue vs Hue \(n)", 0, -180, 180, unit: "°"))
            p.append(.number("hueSat\(i)", "Hue vs Sat \(n)", 0, -100, 100))
            p.append(.number("hueLum\(i)", "Hue vs Lum \(n)", 0, -100, 100))
        }
        for (i, n) in GradeR4.lumaKnotNames.enumerated() {
            p.append(.number("lumSat\(i)", "Luma vs Sat \(n)", 0, -100, 100))
        }
        p += [
            .number("qSoft", "Hue Softness", 50, 0, 100, unit: "%"),
            .number("qSatLo", "Sat Low", 0, 0, 100, unit: "%"), .number("qSatHi", "Sat High", 100, 0, 100, unit: "%"),
            .number("qLumLo", "Luma Low", 0, 0, 100, unit: "%"), .number("qLumHi", "Luma High", 100, 0, 100, unit: "%"),
            .toggle("qShow", "Show Mask", false),
        ]
        return p
    }()
}

enum GradeR4 {
    /// The 8 hue vectors (Hue vs Hue / Sat / Lum knots), in degrees.
    static let vectorNames = ["Red", "Orange", "Yellow", "Green", "Aqua", "Blue", "Purple", "Magenta"]
    static let vectorHues: [Double] = [0, 30, 60, 120, 180, 240, 270, 300]
    static let lumaKnotNames = ["Black", "Shadows", "Mids", "Highs", "White"]
    static let lumaKnots: [Double] = [0, 0.25, 0.5, 0.75, 1]

    private static let defaults: [String: ParamValue] = Dictionary(
        EffectRegistry.gradeParams.map { ($0.id, $0.defaultValue) }, uniquingKeysWith: { a, _ in a })
    private static let r4IDs: [String] = EffectRegistry.gradeR4Params.map(\.id)

    /// A grade control's number, falling back to its default (older grades lack the R4 controls).
    static func num(_ e: EffectInstance, _ k: String, _ t: Double) -> Double {
        (e.params[k] ?? defaults[k])?.number(at: t) ?? 0
    }
    static func flag(_ e: EffectInstance, _ k: String) -> Bool {
        if case .toggle(let b)? = e.params[k] ?? defaults[k] { return b }
        return false
    }
    static func defaultNumber(_ k: String) -> Double { defaults[k]?.number(at: 0) ?? 0 }

    /// True when any R4 control differs from its default (or is animated).
    static func isActive(_ e: EffectInstance) -> Bool {
        for k in r4IDs {
            guard let v = e.params[k], let d = defaults[k] else { continue }
            switch (v, d) {
            case (.number(let a), .number(let b)): if a.isAnimated || a.value(at: 0) != b.value(at: 0) { return true }
            case (.toggle(let a), .toggle(let b)): if a != b { return true }
            default: if v != d { return true }
            }
        }
        return false
    }

    // MARK: Curve points

    struct Slot: Equatable { let y: String; let x: String; let on: String; let legacy: Bool }

    /// The 6 movable points of a channel: the original 25 / 50 / 75 % points, then 3 added ones.
    static func slots(_ c: String) -> [Slot] {
        ["25", "50", "75"].map { Slot(y: c + $0, x: c + $0 + "x", on: c + $0 + "on", legacy: true) }
            + (1...3).map { Slot(y: "\(c)e\($0)y", x: "\(c)e\($0)x", on: "\(c)e\($0)on", legacy: false) }
    }

    /// Curve points of a channel including added / removed ones, sorted by input. With only the original points it
    /// is exactly `GradeCurves.points` (older grades render the same).
    static func activePoints(_ e: EffectInstance, _ t: Double, channel c: String) -> (xs: [Double], ys: [Double]) {
        let on = slots(c).filter { flag(e, $0.on) }
        if on.count == 3 && on.allSatisfy(\.legacy) { return GradeCurves.points(e, t, channel: c) }
        let inner = on.map { (num(e, $0.x, t) / 100, num(e, $0.y, t) / 100) }.sorted { $0.0 < $1.0 }
        let y0 = c == "m" ? num(e, "mBlack", t) / 100 : 0, y1 = c == "m" ? num(e, "mWhite", t) / 100 : 1
        let xs = GradeCurves.orderedXsAny([0] + inner.map(\.0) + [1])
        return (xs, [y0] + inner.map(\.1) + [y1])
    }

    /// The point an "add" tap fills: the first switched-off slot (removed original points are reused first).
    static func freeSlot(_ e: EffectInstance, channel c: String) -> Slot? { slots(c).first { !flag(e, $0.on) } }

    // MARK: Hue curves

    /// Smooth periodic curve through knots at `xs` (0..<1, ascending, first at 0) — hue wraps around.
    static func periodic(xs: [Double], ys: [Double], at raw: Double) -> Double {
        let n = xs.count
        guard n >= 2, ys.count == n else { return ys.first ?? 0 }
        let x = raw - raw.rounded(.down)
        func wrap(_ j: Int) -> (Int, Double) {
            let q = Int((Double(j) / Double(n)).rounded(.down))
            return (j - q * n, Double(q))
        }
        func X(_ j: Int) -> Double { let w = wrap(j); return xs[w.0] + w.1 }
        func Y(_ j: Int) -> Double { ys[wrap(j).0] }
        var i = n - 1
        while i > 0 && xs[i] > x { i -= 1 }
        if x < xs[0] { i = -1 }
        let dx = max(1e-6, X(i + 1) - X(i))
        let t = min(1, max(0, (x - X(i)) / dx))
        let m1 = (Y(i + 1) - Y(i - 1)) / max(1e-6, X(i + 1) - X(i - 1)) * dx
        let m2 = (Y(i + 2) - Y(i)) / max(1e-6, X(i + 2) - X(i)) * dx
        let t2 = t * t, t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * Y(i) + (t3 - 2 * t2 + t) * m1 + (-2 * t3 + 3 * t2) * Y(i + 1) + (t3 - t2) * m2
    }

    /// Knot values of a hue curve ("hueHue", "hueSat", "hueLum") or the luma curve ("lumSat") at `t`.
    static func knots(_ e: EffectInstance, _ prefix: String, _ t: Double) -> [Double] {
        (0..<(prefix == "lumSat" ? 5 : 8)).map { num(e, "\(prefix)\($0)", t) }
    }
    static func knotXs(_ prefix: String) -> [Double] { prefix == "lumSat" ? lumaKnots : vectorHues.map { $0 / 360 } }
    static func value(_ e: EffectInstance, _ prefix: String, _ t: Double, at x: Double) -> Double {
        let k = knots(e, prefix, t)
        if prefix == "lumSat" { return GradeCurves.spline(xs: lumaKnots, ys: k, at: min(1, max(0, x))) }
        return periodic(xs: knotXs(prefix), ys: k, at: x)
    }

    private static var cache: [String: MTLTexture] = [:]
    private static let lock = NSLock()

    /// 256x1 lookup: r = hue shift (turns), g = saturation change, b = lightness change (by hue);
    /// a = saturation change by luma.
    static func hueTexture(_ e: EffectInstance, _ t: Double, device: MTLDevice) -> MTLTexture? {
        let hh = knots(e, "hueHue", t), hs = knots(e, "hueSat", t), hl = knots(e, "hueLum", t), ls = knots(e, "lumSat", t)
        let key = (hh + hs + hl + ls).map { String(format: "%.3f", $0) }.joined(separator: ",")
        lock.lock(); defer { lock.unlock() }
        if let c = cache[key] { return c }
        let hx = knotXs("hueHue")
        var data = [Float16](repeating: 0, count: 256 * 4)
        for i in 0..<256 {
            let x = Double(i) / 255
            data[i * 4] = Float16(periodic(xs: hx, ys: hh, at: x) / 360)
            data[i * 4 + 1] = Float16(max(-1, periodic(xs: hx, ys: hs, at: x) / 100))
            data[i * 4 + 2] = Float16(periodic(xs: hx, ys: hl, at: x) / 100)
            data[i * 4 + 3] = Float16(max(-1, GradeCurves.spline(xs: lumaKnots, ys: ls, at: x) / 100))
        }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 256, height: 1, mipmapped: false)
        d.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        tex.replace(region: MTLRegionMake2D(0, 0, 256, 1), mipmapLevel: 0, withBytes: data, bytesPerRow: 256 * 8)
        if cache.count > 64 { cache.removeAll() }
        cache[key] = tex
        return tex
    }

    /// Extra kernel data after lift / gamma / gain: offset rgb, wheel luminance, qualifier ranges, flags.
    static func extra(_ e: EffectInstance, _ t: Double) -> [SIMD4<Float>] {
        func n(_ k: String) -> Float { Float(num(e, k, t) / 100) }
        let all = knots(e, "hueHue", t) + knots(e, "hueSat", t) + knots(e, "hueLum", t) + knots(e, "lumSat", t)
        let hueOn = all.contains { abs($0) > 1e-6 }
        return [
            SIMD4(n("offR"), n("offG"), n("offB"), 0),
            SIMD4(n("liftY"), n("gammaY"), n("gainY"), n("offY")),
            SIMD4(n("qSatLo"), n("qSatHi"), n("qLumLo"), n("qLumHi")),
            SIMD4(n("qSoft"), flag(e, "qShow") ? 1 : 0, hueOn ? 1 : 0, 0),
        ]
    }

    // MARK: Wheels

    /// A wheel's 2D puck from its R / G / B balance (the mean is brightness and isn't part of the puck).
    /// x points toward red, y toward green / away from blue.
    static func puck(r: Double, g: Double, b: Double) -> (x: Double, y: Double) {
        ((2 * r - g - b) / 3, (g - b) / 3.0.squareRoot())
    }
    /// R / G / B from a puck position, keeping `mean`.
    static func rgb(puckX x: Double, y: Double, mean: Double) -> (r: Double, g: Double, b: Double) {
        let s3 = 3.0.squareRoot()
        return (mean + x, mean - x / 2 + y * s3 / 2, mean - x / 2 - y * s3 / 2)
    }

    // MARK: White balance

    /// Temperature / tint change (control units) that makes the picked color neutral. The kernel adds
    /// 0.12 per 100 of temperature to red (and takes it from blue), and of tint to green.
    static func whiteBalanceDelta(r: Double, g: Double, b: Double) -> (temp: Double, tint: Double) {
        let a = (b - r) / 2, k = (r + b) / 2 - g
        return (a / 0.12 * 100, k / 0.12 * 100)
    }

    // MARK: A / B

    /// Swaps the grade with its stored other version (a copy of the current one on first use). Same effect id.
    static func swapAB(_ e: EffectInstance) -> EffectInstance {
        var out = e
        var text = e.text ?? [:]
        let stored: [String: ParamValue]? = text["gradeAlt"].flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([String: ParamValue].self, from: $0) }
        let altLUT = stored == nil ? text["lut"] : text["gradeAltLUT"]
        if let d = try? JSONEncoder().encode(e.params), let s = String(data: d, encoding: .utf8) { text["gradeAlt"] = s }
        text["gradeAltLUT"] = text["lut"]
        text["lut"] = altLUT
        text["gradeSlot"] = slot(e) == "A" ? "B" : "A"
        out.params = stored ?? e.params
        out.text = text
        return out
    }
    static func slot(_ e: EffectInstance) -> String { e.text?["gradeSlot"] ?? "A" }
}
