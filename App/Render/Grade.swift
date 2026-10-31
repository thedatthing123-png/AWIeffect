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
        .number("hslHue", "HSL Target Hue", 0, 0, 360, unit: "°"),
        .number("hslRange", "HSL Range", 30, 5, 180, unit: "°"),
        .number("hslShift", "HSL Hue Shift", 0, -180, 180, unit: "°"),
        .number("hslSat", "HSL Saturation", 0, -100, 100),
        .number("hslLight", "HSL Lightness", 0, -100, 100),
        .number("lutStrength", "LUT Strength", 100, 0, 100, unit: "%"),
        .number("split", "Before / After Split", 0, 0, 100, unit: "%"),
    ]

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
            let w: [SIMD4<Float>] = [
                SIMD4(Float(ctx.num("liftR") / 100), Float(ctx.num("liftG") / 100), Float(ctx.num("liftB") / 100), 0),
                SIMD4(Float(ctx.num("gammaR") / 100), Float(ctx.num("gammaG") / 100), Float(ctx.num("gammaB") / 100), 0),
                SIMD4(Float(ctx.num("gainR") / 100), Float(ctx.num("gainG") / 100), Float(ctx.num("gainB") / 100), 0),
            ]
            ctx.gpu.run("fxGrade", ctx.cb, textures: [ctx.input, out, curve, lut3D], params: p, extra: w, grid: out)
            return out
        })
}

/// Curves -> a 256x1 lookup (r, g, b = channel curve applied after the master curve), cached by settings.
enum GradeCurves {
    private static var cache: [String: MTLTexture] = [:]
    private static let lock = NSLock()

    /// Smooth monotone curve through (0, black), (.25, a), (.5, b), (.75, c), (1, white).
    static func curve(_ pts: [Double]) -> [Double] {
        let xs = [0, 0.25, 0.5, 0.75, 1.0]
        return (0..<256).map { i in
            let x = Double(i) / 255
            let k = min(3, Int(x * 4))
            let t = (x - xs[k]) / 0.25
            // Catmull-Rom between neighbours, clamped (keeps it smooth without overshoot at the ends).
            let p0 = pts[max(0, k - 1)], p1 = pts[k], p2 = pts[k + 1], p3 = pts[min(4, k + 2)]
            let v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
            return min(1, max(0, v))
        }
    }

    static func texture(_ e: EffectInstance, _ t: Double, device: MTLDevice) -> MTLTexture? {
        func n(_ k: String, _ d: Double) -> Double { (e.params[k]?.number(at: t) ?? d) / 100 }
        let black = n("mBlack", 0), white = n("mWhite", 100)
        let master = [black, n("m25", 25), n("m50", 50), n("m75", 75), white]
        let r = [0, n("r25", 25), n("r50", 50), n("r75", 75), 1], g = [0, n("g25", 25), n("g50", 50), n("g75", 75), 1]
        let b = [0, n("b25", 25), n("b50", 50), n("b75", 75), 1]
        let key = (master + r + g + b).map { String(format: "%.4f", $0) }.joined(separator: ",")
        lock.lock(); defer { lock.unlock() }
        if let c = cache[key] { return c }
        let m = curve(master), cr = curve(r), cg = curve(g), cb = curve(b)
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
        let name = url.lastPathComponent
        let dest = Self.folder.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: url, to: dest)
        _ = try Self.parse(String(contentsOf: dest, encoding: .utf8))
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
        values.reserveCapacity(33 * 33 * 33 * 3)
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.uppercased().hasPrefix("LUT_3D_SIZE") {
                size = Int(line.split(separator: " ").last ?? "") ?? 0
                continue
            }
            if let c = line.first, c.isLetter { continue }
            let parts = line.split(separator: " ").compactMap { Float($0) }
            if parts.count == 3 { values.append(contentsOf: parts) }
        }
        guard size >= 2, size <= 128, values.count == size * size * size * 3 else { throw CubeError.invalid }
        return (size, values)
    }

    func texture(named name: String, device: MTLDevice) -> MTLTexture? {
        lock.lock()
        if let t = cache[name] { lock.unlock(); return t }
        lock.unlock()
        guard let text = try? String(contentsOf: Self.folder.appendingPathComponent(name), encoding: .utf8),
              let (n, v) = try? Self.parse(text) else { return nil }
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
