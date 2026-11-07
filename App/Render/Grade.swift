import Foundation
import Metal
import simd

/// CC Studio's Grade effect: basics, lift/gamma/gain wheels, curves, HSL secondary, a .cube LUT and a
/// before/after split — all in one GPU pass, keyframeable like any other effect.
extension EffectRegistry {
    static let gradeParams: [ParamDef] = [
        .number("exposure", "Exposure", 0, -5, 5, step: 0.01, unit: " EV"),
        .number("contrast", "Contrast", 0, -100, 100),
        .number("highlights", "Highlights", 0, -100, 100),
        .number("shadows", "Shadows", 0, -100, 100),
        .number("temp", "Temperature", 0, -100, 100),
        .number("tint", "Tint", 0, -100, 100),
        .number("vibrance", "Vibrance", 0, -100, 100),
        .number("saturation", "Saturation", 0, -100, 100),
        .number("liftR", "Lift Red", 0, -100, 100), .number("liftG", "Lift Green", 0, -100, 100), .number("liftB", "Lift Blue", 0, -100, 100),
        .number("gammaR", "Gamma Red", 0, -100, 100), .number("gammaG", "Gamma Green", 0, -100, 100), .number("gammaB", "Gamma Blue", 0, -100, 100),
        .number("gainR", "Gain Red", 0, -100, 100), .number("gainG", "Gain Green", 0, -100, 100), .number("gainB", "Gain Blue", 0, -100, 100),
        .number("mBlack", "Curve Black", 0, 0, 50), .number("m25", "Curve Shadows", 25, 0, 100),
        .number("m50", "Curve Mids", 50, 0, 100), .number("m75", "Curve Highs", 75, 0, 100), .number("mWhite", "Curve White", 100, 50, 100),
        .number("r25", "Red Shadows", 25, 0, 100), .number("r50", "Red Mids", 50, 0, 100), .number("r75", "Red Highs", 75, 0, 100),
        .number("g25", "Green Shadows", 25, 0, 100), .number("g50", "Green Mids", 50, 0, 100), .number("g75", "Green Highs", 75, 0, 100),
        .number("b25", "Blue Shadows", 25, 0, 100), .number("b50", "Blue Mids", 50, 0, 100), .number("b75", "Blue Highs", 75, 0, 100),
        // Curve point input positions (drag a point sideways); kept in order.
        .number("m25x", "Curve Shadows Input", 25, 2, 94), .number("m50x", "Curve Mids Input", 50, 4, 96), .number("m75x", "Curve Highs Input", 75, 6, 98),
        .number("r25x", "Red Shadows Input", 25, 2, 94), .number("r50x", "Red Mids Input", 50, 4, 96), .number("r75x", "Red Highs Input", 75, 6, 98),
        .number("g25x", "Green Shadows Input", 25, 2, 94), .number("g50x", "Green Mids Input", 50, 4, 96), .number("g75x", "Green Highs Input", 75, 6, 98),
        .number("b25x", "Blue Shadows Input", 25, 2, 94), .number("b50x", "Blue Mids Input", 50, 4, 96), .number("b75x", "Blue Highs Input", 75, 6, 98),
        .number("hslHue", "HSL Target Hue", 0, 0, 360, unit: "°"),
        .number("hslRange", "HSL Range", 30, 5, 180, unit: "°"),
        .number("hslShift", "HSL Hue Shift", 0, -180, 180, unit: "°"),
        .number("hslSat", "HSL Saturation", 0, -100, 100),
        .number("hslLight", "HSL Lightness", 0, -100, 100),
        .number("lutStrength", "LUT Strength", 100, 0, 100, unit: "%"),
        .number("split", "Before / After Split", 0, 0, 100, unit: "%"),
    ] + gradeR4Params

    static let grade = EffectDefinition(
        id: "awi18.grade", name: "CC Studio Grade", category: .color,
        aeMatchNames: [],
        summary: "Full color grade: exposure, contrast, highlights/shadows, white balance, vibrance, lift/gamma/gain, curves, HSL secondary and .cube LUTs. Edit it in CC Studio.",
        params: gradeParams,
        stage: .pixels { ctx in
            let out = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(Float(ctx.num("exposure")), Float(ctx.num("contrast") / 100), Float(ctx.num("highlights") / 100), Float(ctx.num("shadows") / 100))
            p.b = SIMD4(Float(ctx.num("temp") / 100), Float(ctx.num("tint") / 100), Float(ctx.num("vibrance") / 100), Float(ctx.num("saturation") / 100))
            p.c = SIMD4(Float(ctx.num("hslHue") / 360), Float(ctx.num("hslRange") / 360), Float(ctx.num("hslShift") / 360), Float(ctx.num("split") / 100))
            p.d = SIMD4(Float(ctx.num("hslSat") / 100), Float(ctx.num("hslLight") / 100), Float(ctx.num("lutStrength") / 100), 0)
            let lut = ctx.effect.text?["lut"].flatMap { LUTLibrary.shared.texture(named: $0, device: ctx.gpu.device) }
            p.i = SIMD4(lut != nil ? 1 : 0, 0, 0, 0)
            guard let curve = GradeCurves.texture(ctx.effect, ctx.time, device: ctx.gpu.device),
                  let lut3D = lut ?? LUTLibrary.shared.identity(device: ctx.gpu.device) else { return ctx.input }
            // Wheels go in as extra data: lift / gamma / gain rgb.
            var w: [SIMD4<Float>] = [
                SIMD4(Float(ctx.num("liftR") / 100), Float(ctx.num("liftG") / 100), Float(ctx.num("liftB") / 100), 0),
                SIMD4(Float(ctx.num("gammaR") / 100), Float(ctx.num("gammaG") / 100), Float(ctx.num("gammaB") / 100), 0),
                SIMD4(Float(ctx.num("gainR") / 100), Float(ctx.num("gainG") / 100), Float(ctx.num("gainB") / 100), 0),
            ]
            // Grades that use none of the R4 controls run the original kernel: saved projects render exactly as before.
            guard GradeR4.isActive(ctx.effect),
                  let hue = GradeR4.hueTexture(ctx.effect, ctx.time, device: ctx.gpu.device) else {
                ctx.gpu.run("fxGrade", ctx.cb, textures: [ctx.input, out, curve, lut3D], params: p, extra: w, grid: out)
                return out
            }
            w += GradeR4.extra(ctx.effect, ctx.time)
            ctx.gpu.run("fxGradeR4", ctx.cb, textures: [ctx.input, out, curve, lut3D, hue], params: p, extra: w, grid: out)
            return out
        })
}

/// Curves -> a 256x1 lookup (r, g, b = channel curve applied after the master curve), cached by settings.
enum GradeCurves {
    private static var cache: [String: MTLTexture] = [:]
    private static let lock = NSLock()

    /// Smooth monotone curve through (0, black), (.25, a), (.5, b), (.75, c), (1, white).
    static func curve(_ pts: [Double]) -> [Double] { curve(xs: [0, 0.25, 0.5, 0.75, 1.0], ys: pts) }

    /// Smooth curve through 5 points whose inner x positions can move (kept in order). Non-uniform Catmull-Rom:
    /// with evenly spaced points it is exactly the original curve. Any other count of points (added / removed
    /// curve points, ends included) uses the same spline.
    static func curve(xs rawXs: [Double], ys pts: [Double]) -> [Double] {
        guard pts.count >= 2, rawXs.count == pts.count else { return (0..<256).map { Double($0) / 255 } }
        let xs = pts.count == 5 ? orderedXs(rawXs) : orderedXsAny(rawXs)
        return (0..<256).map { i in min(1, max(0, spline(xs: xs, ys: pts, at: Double(i) / 255))) }
    }

    /// Unclamped non-uniform Catmull-Rom through ordered points (virtual outer neighbours mirror the end spacing).
    static func spline(xs: [Double], ys pts: [Double], at xv: Double) -> Double {
        let last = xs.count - 1
        guard last >= 1, pts.count == xs.count else { return xv }
        func x(_ i: Int) -> Double { i < 0 ? 2 * xs[0] - xs[1] : i > last ? 2 * xs[last] - xs[last - 1] : xs[i] }
        func p(_ i: Int) -> Double { pts[min(last, max(0, i))] }
        var k = 0
        while k < last - 1 && xv > xs[k + 1] { k += 1 }
        let dx = max(1e-6, xs[k + 1] - xs[k])
        let t = min(1, max(0, (xv - xs[k]) / dx))
        let m1 = (p(k + 1) - p(k - 1)) / max(1e-6, x(k + 1) - x(k - 1)) * dx
        let m2 = (p(k + 2) - p(k)) / max(1e-6, x(k + 2) - x(k)) * dx
        let t2 = t * t, t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * p(k) + (t3 - 2 * t2 + t) * m1 + (-2 * t3 + 3 * t2) * p(k + 1) + (t3 - t2) * m2
    }

    /// Any number of points: ends pinned at 0 / 1, inner points kept in order with a small gap.
    static func orderedXsAny(_ xs: [Double]) -> [Double] {
        guard xs.count >= 2 else { return [0, 1] }
        var o = xs.map { $0.isFinite ? $0 : 0.5 }
        let n = o.count - 1
        o[0] = 0; o[n] = 1
        let gap = min(0.02, 1 / Double(n * 2))
        if n >= 2 { for i in 1..<n { o[i] = min(1 - gap * Double(n - i), max(o[i - 1] + gap, o[i])) } }
        return o
    }

    /// Ends pinned at 0 / 1; inner points keep their order with a small gap.
    static func orderedXs(_ xs: [Double]) -> [Double] {
        guard xs.count == 5 else { return [0, 0.25, 0.5, 0.75, 1.0] }
        var o = xs.map { $0.isFinite ? $0 : 0.5 }
        o[0] = 0; o[4] = 1
        let gap = 0.02
        for i in 1...3 { o[i] = min(1 - gap * Double(4 - i), max(o[i - 1] + gap, o[i])) }
        return o
    }

    /// Curve points (x, y in 0...1) of a channel ("m", "r", "g", "b"). X positions default to 25 / 50 / 75 %
    /// (older grades have no x controls).
    static func points(_ e: EffectInstance, _ t: Double, channel c: String) -> (xs: [Double], ys: [Double]) {
        func n(_ k: String, _ d: Double) -> Double { (e.params[k]?.number(at: t) ?? d) / 100 }
        let ys = c == "m" ? [n("mBlack", 0), n("m25", 25), n("m50", 50), n("m75", 75), n("mWhite", 100)]
                          : [0, n(c + "25", 25), n(c + "50", 50), n(c + "75", 75), 1]
        let xs = orderedXs([0, n(c + "25x", 25), n(c + "50x", 50), n(c + "75x", 75), 1])
        return (xs, ys)
    }

    static func texture(_ e: EffectInstance, _ t: Double, device: MTLDevice) -> MTLTexture? {
        let pm = GradeR4.activePoints(e, t, channel: "m"), pr = GradeR4.activePoints(e, t, channel: "r")
        let pg = GradeR4.activePoints(e, t, channel: "g"), pb = GradeR4.activePoints(e, t, channel: "b")
        let key = [pm, pr, pg, pb].map { c in (c.xs + c.ys).map { String(format: "%.4f", $0) }.joined(separator: ",") }.joined(separator: "|")
        lock.lock(); defer { lock.unlock() }
        if let c = cache[key] { return c }
        let m = curve(xs: pm.xs, ys: pm.ys), cr = curve(xs: pr.xs, ys: pr.ys), cg = curve(xs: pg.xs, ys: pg.ys), cb = curve(xs: pb.xs, ys: pb.ys)
        func look(_ c: [Double], _ v: Double) -> Double { c[min(255, max(0, Int((v * 255).rounded())))] }
        var data = [Float16](repeating: 0, count: 256 * 4)
        for i in 0..<256 {
            let mv = m[i]
            data[i * 4] = Float16(look(cr, mv)); data[i * 4 + 1] = Float16(look(cg, mv)); data[i * 4 + 2] = Float16(look(cb, mv)); data[i * 4 + 3] = 1
        }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 256, height: 1, mipmapped: false)
        d.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        tex.replace(region: MTLRegionMake2D(0, 0, 256, 1), mipmapLevel: 0, withBytes: data, bytesPerRow: 256 * 8)
        if cache.count > 64 { cache.removeAll() }
        cache[key] = tex
        return tex
    }
}

/// .cube LUTs kept for every project (Documents/LUTs), loaded as 3D textures.
final class LUTLibrary {
    static let shared = LUTLibrary()
    private var cache: [String: MTLTexture] = [:]
    private var identityTex: MTLTexture?
    private let lock = NSLock()

    static var folder: URL {
        let u = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("LUTs", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func names() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: Self.folder.path)) ?? []).filter { $0.lowercased().hasSuffix(".cube") }.sorted()
    }

    /// Copies a .cube file into the library; returns its name.
    @discardableResult
    func importFile(_ url: URL) throws -> String {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return try importData(Data(contentsOf: url), named: url.lastPathComponent)
    }

    @discardableResult
    func importData(_ data: Data, named name: String) throws -> String {
        guard name == (name as NSString).lastPathComponent, name.lowercased().hasSuffix(".cube"),
              let text = String(data: data, encoding: .utf8) else { throw CubeError.invalid }
        _ = try Self.parse(text)
        try data.write(to: Self.folder.appendingPathComponent(name), options: .atomic)
        lock.lock(); cache[name] = nil; lock.unlock()
        return name
    }

    func remove(_ name: String) {
        try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(name))
        lock.lock(); cache[name] = nil; lock.unlock()
    }

    enum CubeError: Error { case invalid }

    /// Parses an Adobe / Resolve .cube 3D LUT: (size, rgb values with red changing fastest).
    static func parse(_ text: String) throws -> (Int, [Float]) {
        var size = 0
        var values: [Float] = []
        var minimum: [Float] = [0, 0, 0], maximum: [Float] = [1, 1, 1]
        var sawMin = false, sawMax = false
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            let words = line.split(whereSeparator: \.isWhitespace)
            guard let first = words.first else { continue }
            let directive = first.uppercased()
            if directive == "TITLE" { continue }
            if directive == "LUT_3D_SIZE" {
                guard size == 0, values.isEmpty, words.count == 2,
                      let n = Int(words[1]), (2...128).contains(n) else { throw CubeError.invalid }
                size = n
            } else if directive == "DOMAIN_MIN" || directive == "DOMAIN_MAX" {
                let triple = words.dropFirst().compactMap { Float($0) }
                guard values.isEmpty, words.count == 4, triple.count == 3, triple.allSatisfy(\.isFinite) else { throw CubeError.invalid }
                if directive == "DOMAIN_MIN" {
                    guard !sawMin else { throw CubeError.invalid }; minimum = triple; sawMin = true
                } else {
                    guard !sawMax else { throw CubeError.invalid }; maximum = triple; sawMax = true
                }
            } else {
                let triple = words.compactMap { Float($0) }
                guard size > 0, words.count == 3, triple.count == 3,
                      triple.allSatisfy({ $0.isFinite && abs($0) <= 65504 }),
                      values.count < size * size * size * 3 else { throw CubeError.invalid }
                values.append(contentsOf: triple)
            }
        }
        guard size >= 2, values.count == size * size * size * 3,
              (0..<3).allSatisfy({ maximum[$0] > minimum[$0] }) else { throw CubeError.invalid }
        if minimum == [0, 0, 0] && maximum == [1, 1, 1] { return (size, values) }
        // Bake the declared input domain into our normalized GPU LUT. Red changes fastest.
        var normalized = values
        for b in 0..<size { for g in 0..<size { for r in 0..<size {
            let input = [r, g, b].enumerated().map { c, v -> Float in
                min(Float(size - 1), max(0, (Float(v) / Float(size - 1) - minimum[c]) / (maximum[c] - minimum[c]) * Float(size - 1)))
            }
            let lo = input.map { Int($0.rounded(.down)) }
            let hi = lo.map { min(size - 1, $0 + 1) }
            let f = (0..<3).map { input[$0] - Float(lo[$0]) }
            for c in 0..<3 {
                var value: Float = 0
                for z in 0...1 { for y in 0...1 { for x in 0...1 {
                    let ix = x == 0 ? lo[0] : hi[0], iy = y == 0 ? lo[1] : hi[1], iz = z == 0 ? lo[2] : hi[2]
                    let weight = (x == 0 ? 1 - f[0] : f[0]) * (y == 0 ? 1 - f[1] : f[1]) * (z == 0 ? 1 - f[2] : f[2])
                    value += values[((iz * size + iy) * size + ix) * 3 + c] * weight
                } } }
                normalized[((b * size + g) * size + r) * 3 + c] = value
            }
        } } }
        return (size, normalized)
    }

    func texture(named name: String, device: MTLDevice) -> MTLTexture? {
        lock.lock()
        if let t = cache[name] { lock.unlock(); return t }
        lock.unlock()
        var text = try? String(contentsOf: Self.folder.appendingPathComponent(name), encoding: .utf8)
        // A built-in look is rebuilt from its formula when its file is gone (moved project, cleared library).
        if text == nil, restoreBuiltIn(name) { text = try? String(contentsOf: Self.folder.appendingPathComponent(name), encoding: .utf8) }
        guard let text, let (n, v) = try? Self.parse(text) else { return nil }
        let tex = make3D(n, v, device: device)
        lock.lock(); cache[name] = tex; lock.unlock()
        return tex
    }

    /// 2x2x2 pass-through LUT bound when none is chosen.
    func identity(device: MTLDevice) -> MTLTexture? {
        lock.lock(); defer { lock.unlock() }
        if let t = identityTex { return t }
        var v: [Float] = []
        for b in 0..<2 { for g in 0..<2 { for r in 0..<2 { v += [Float(r), Float(g), Float(b)] } } }
        identityTex = make3D(2, v, device: device)
        return identityTex
    }

    private func make3D(_ n: Int, _ v: [Float], device: MTLDevice) -> MTLTexture? {
        let d = MTLTextureDescriptor()
        d.textureType = .type3D
        d.pixelFormat = .rgba16Float
        d.width = n; d.height = n; d.depth = n
        d.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        var data = [Float16](repeating: 1, count: n * n * n * 4)
        for i in 0..<(n * n * n) {
            data[i * 4] = Float16(v[i * 3]); data[i * 4 + 1] = Float16(v[i * 3 + 1]); data[i * 4 + 2] = Float16(v[i * 3 + 2])
        }
        tex.replace(region: MTLRegionMake3D(0, 0, 0, n, n, n), mipmapLevel: 0, slice: 0, withBytes: data,
                    bytesPerRow: n * 8, bytesPerImage: n * n * 8)
        return tex
    }
}
