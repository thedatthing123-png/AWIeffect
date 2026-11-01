import Foundation
import Metal

/// Must match EffectParams in Effects.metal.
struct EffectParams {
    var a = SIMD4<Float>(repeating: 0)
    var b = SIMD4<Float>(repeating: 0)
    var c = SIMD4<Float>(repeating: 0)
    var d = SIMD4<Float>(repeating: 0)
    var i = SIMD4<UInt32>(repeating: 0)
}

/// Everything an effect needs to encode its GPU passes.
struct EffectContext {
    let gpu: EffectGPU
    let cb: MTLCommandBuffer
    let input: MTLTexture
    let effect: EffectInstance
    let time: Double
    /// Texture pixels per layer pixel (params are authored in layer pixels, like AE).
    let unit: Double
    let pool: TexturePool
    /// Another layer rendered into this layer's buffer space (for effects that read a layer: displacement map, set matte).
    var reference: MTLTexture? = nil

    var width: Int { input.width }
    var height: Int { input.height }
    /// A number setting, kept inside its defined range (imported or typed values can't stall the GPU).
    func num(_ k: String) -> Double {
        let v = effect.number(k, time)
        guard let r = EffectRegistry.paramRanges[effect.typeID]?[k] else { return v }
        return min(max(v, r.lowerBound), r.upperBound)
    }
    func temp() -> MTLTexture { pool.acquire(width: width, height: height) }
}

/// How an effect participates in rendering.
enum EffectStage {
    /// Processes the layer's pixels (blur, color, glow, keying...).
    case pixels((EffectContext) -> MTLTexture)
    /// Modifies the layer transform (shake/wiggle). Returns (dx, dy, dRotation, scaleMul).
    case transform((EffectInstance, Double) -> (Double, Double, Double, Double))
}

struct EffectDefinition: Identifiable {
    let id: String
    let name: String
    let category: EffectCategory
    /// After Effects match names this effect imports from (for the .aep importer).
    let aeMatchNames: [String]
    let summary: String
    let params: [ParamDef]
    /// Extra pixels (layer space) the effect may draw outside the layer bounds.
    var margin: (EffectInstance, Double) -> Double = { _, _ in 0 }
    let stage: EffectStage

    func makeInstance() -> EffectInstance {
        EffectInstance(typeID: id, params: Dictionary(params.map { ($0.id, $0.defaultValue) }, uniquingKeysWith: { a, _ in a }))
    }

    var isTransformEffect: Bool { if case .transform = stage { return true }; return false }
}

/// Reusable textures, recycled per frame (triple-buffered so in-flight frames are never overwritten).
final class TexturePool {
    private let device: MTLDevice
    private var free: [String: [MTLTexture]] = [:]
    private var used: [MTLTexture] = []
    /// Recycle count when each size was last handed out (sizes nobody asks for any more are released).
    private var lastUse: [String: Int] = [:]
    private var generation = 0
    /// Spare-texture budget per pool; beyond it the least recently used sizes are released.
    static var budgetBytes = 96 * 1024 * 1024
    init(device: MTLDevice) { self.device = device }

    private static func bytes(_ t: MTLTexture) -> Int { t.width * t.height * 8 }

    /// Largest side the pool hands out (Metal's limit is 16384; real layers are capped far below this).
    static let maxSide = 8192
    private var fallback: MTLTexture?

    func acquire(width rawW: Int, height rawH: Int) -> MTLTexture {
        let width = min(Self.maxSide, max(1, rawW)), height = min(Self.maxSide, max(1, rawH))
        let key = "\(width)x\(height)"
        lastUse[key] = generation
        if var list = free[key], let t = list.popLast() {
            free[key] = list
            used.append(t)
            return t
        }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: max(1, width), height: max(1, height), mipmapped: false)
        d.usage = [.shaderRead, .shaderWrite, .renderTarget]
        d.storageMode = .private
        guard let t = device.makeTexture(descriptor: d) else {
            // Out of GPU memory: drop every spare and try once more rather than crashing.
            purge()
            if let t2 = device.makeTexture(descriptor: d) { used.append(t2); return t2 }
            // Still nothing: a tiny blank texture keeps the frame going (that layer just shows empty).
            if fallback == nil {
                let fd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 1, height: 1, mipmapped: false)
                fd.usage = [.shaderRead, .shaderWrite]
                fallback = device.makeTexture(descriptor: fd)
            }
            return fallback!
        }
        used.append(t)
        return t
    }

    /// Returns all textures handed out since the last recycle to the free list, then trims memory:
    /// sizes unused for a few frames are released and the spare total stays under the budget.
    func recycle() {
        generation += 1
        for t in used { free["\(t.width)x\(t.height)", default: []].append(t) }
        used.removeAll()
        for (k, v) in free {
            if generation - (lastUse[k] ?? 0) > 3 { free[k] = nil; lastUse[k] = nil; continue }
            if v.count > 6 { free[k] = Array(v.suffix(6)) }
        }
        var total = free.values.reduce(0) { $0 + $1.reduce(0) { $0 + Self.bytes($1) } }
        if total > Self.budgetBytes {
            for k in free.keys.sorted(by: { (lastUse[$0] ?? 0) < (lastUse[$1] ?? 0) }) {
                total -= free[k]?.reduce(0) { $0 + Self.bytes($1) } ?? 0
                free[k] = nil
                if total <= Self.budgetBytes { break }
            }
        }
    }

    /// Bytes held as spares (tests / diagnostics).
    var spareBytes: Int { free.values.reduce(0) { $0 + $1.reduce(0) { $0 + Self.bytes($1) } } }

    /// Releases every spare texture (memory warning).
    func purge() { free.removeAll(); lastUse.removeAll() }
}

/// Compute pipelines for effects.
final class EffectGPU {
    let device: MTLDevice
    private var psos: [String: MTLComputePipelineState] = [:]

    init(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device
        for name in ["fxCopy", "fxClear", "fxGaussian", "fxDirectional", "fxRadial", "fxColor", "fxGlowThreshold",
                     "fxGlowCombine", "fxFractalNoise", "fxChromaKey", "fxRGBSplit", "fxAdjustMix",
                     "fxWarp", "fxStylize", "fxGlitch", "fxColor2", "fxSaberCore", "fxShine", "fxParticles", "fxPixelSort",
                     "fxGenerate", "fxStylize2", "fxDistort2", "fxTransition", "fxColor3", "fxMatte", "fxGlow4", "fxLook5", "fxResample", "fxDistort6", "fxGen7", "fxStyle8", "fxTrans9", "fxLight10", "fxRepeat11", "fxAbstract12", "fxRetro13", "fxWarp14", "fxBlur15", "fxDraw16", "fx3D17", "fx18", "frameMix", "fxPuppet", "fxGrade", "maskMix", "fxLayerRef", "flowEstimate", "flowBlur", "fx19", "fx19GlowKeep", "fx19KeyInvert", "fx19AlphaOf", "fx19ColorSelect"] {
            guard let f = library.makeFunction(name: name) else { throw RenderError.pipeline(name) }
            psos[name] = try device.makeComputePipelineState(function: f)
        }
    }

    /// Runs one kernel: textures bound in order at indices 0..n, params at buffer 0, grid = out size.
    func run(_ name: String, _ cb: MTLCommandBuffer, textures: [MTLTexture], params: EffectParams? = nil, grid: MTLTexture) {
        guard let pso = psos[name], let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(pso)
        for (i, t) in textures.enumerated() { enc.setTexture(t, index: i) }
        if var p = params { enc.setBytes(&p, length: MemoryLayout<EffectParams>.stride, index: 0) }
        let tw = pso.threadExecutionWidth
        let th = max(1, pso.maxTotalThreadsPerThreadgroup / tw)
        enc.dispatchThreadgroups(MTLSize(width: (grid.width + tw - 1) / tw, height: (grid.height + th - 1) / th, depth: 1),
                                 threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
        enc.endEncoding()
    }

    /// Like `run`, plus an array of float4 bound at buffer 1 (variable-length data such as puppet pins).
    func run(_ name: String, _ cb: MTLCommandBuffer, textures: [MTLTexture], params: EffectParams, extra: [SIMD4<Float>], grid: MTLTexture) {
        guard let pso = psos[name], let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(pso)
        for (i, t) in textures.enumerated() { enc.setTexture(t, index: i) }
        var p = params
        enc.setBytes(&p, length: MemoryLayout<EffectParams>.stride, index: 0)
        var data = extra.isEmpty ? [SIMD4<Float>(repeating: 0)] : extra
        enc.setBytes(&data, length: MemoryLayout<SIMD4<Float>>.stride * data.count, index: 1)
        let tw = pso.threadExecutionWidth
        let th = max(1, pso.maxTotalThreadsPerThreadgroup / tw)
        enc.dispatchThreadgroups(MTLSize(width: (grid.width + tw - 1) / tw, height: (grid.height + th - 1) / th, depth: 1),
                                 threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
        enc.endEncoding()
    }

    /// Separable Gaussian, `sigma` in texture px. Returns the output texture.
    func gaussian(_ ctx: EffectContext, input: MTLTexture, sigma rawSigma: Double, horizontal: Bool = true, vertical: Bool = true, repeatEdges: Bool = false) -> MTLTexture {
        // Past the image's own size more blur looks the same (a flat average), so stop there.
        let sigma = min(rawSigma, Double(max(input.width, input.height)) * 0.6)
        guard sigma > 0.05 else { return input }
        // Big blurs run on a smaller copy (halved until the blur is ~4 px wide there), then scale back up:
        // same look, a fraction of the samples. Edge-repeat blurs stay full-res so edges don't smear.
        if sigma > 6, !repeatEdges, horizontal, vertical, input.width > 8, input.height > 8 {
            var small = input, f = 1.0
            while sigma / f > 4, small.width > 16, small.height > 16, f < 16 {
                let half = ctx.pool.acquire(width: max(1, small.width / 2), height: max(1, small.height / 2))
                run("fxResample", ctx.cb, textures: [small, half], grid: half)
                small = half; f *= 2
            }
            let blurred = gaussian(ctx, input: small, sigma: sigma / f, horizontal: true, vertical: true, repeatEdges: true)
            let out = ctx.pool.acquire(width: input.width, height: input.height)
            run("fxResample", ctx.cb, textures: [blurred, out], grid: out)
            return out
        }
        var current = input
        // Very large blurs: downsample is the next optimization; for now cap radius and widen sigma steps.
        let radius = Float(min(400, ceil(sigma * 3)))
        for (on, dir) in [(horizontal, SIMD2<Float>(1, 0)), (vertical, SIMD2<Float>(0, 1))] where on {
            let out = ctx.pool.acquire(width: input.width, height: input.height)
            var p = EffectParams()
            p.a = SIMD4(dir.x, dir.y, Float(sigma), radius)
            p.i = SIMD4(repeatEdges ? 1 : 0, 0, 0, 0)
            run("fxGaussian", ctx.cb, textures: [current, out], params: p, grid: out)
            current = out
        }
        return current
    }
}

// MARK: - Registry

enum EffectRegistry {
    /// effect id -> number param id -> allowed range.
    static let paramRanges: [String: [String: ClosedRange<Double>]] = {
        var out: [String: [String: ClosedRange<Double>]] = [:]
        for d in all {
            var m: [String: ClosedRange<Double>] = [:]
            for p in d.params { if case .number(let lo, let hi, _, _) = p.kind, lo <= hi { m[p.id] = lo...hi } }
            out[d.id] = m
        }
        return out
    }()

    static let all: [EffectDefinition] = [
        gaussianBlur, directionalBlur, radialBlur,
        exposure, brightnessContrast, hueSaturation, tint, levels, invert, fill, vignette,
        glow, rgbSplit, fractalNoise, chromaKey, shake,
    ] + batch2 + batch3 + batch4 + batch5 + batch6 + batch7 + batch8 + batch9 + batch10 + batch11 + batch12 + batch13 + batch14 + batch15 + batch16 + batch17 + batch18 + batch19

    private static let byID: [String: EffectDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    private static let byMatchName: [String: EffectDefinition] = {
        var m: [String: EffectDefinition] = [:]
        for d in all { for n in d.aeMatchNames { m[n] = d } }
        return m
    }()

    static func definition(_ id: String) -> EffectDefinition? { byID[id] }
    static func definition(aeMatchName: String) -> EffectDefinition? { byMatchName[aeMatchName] }

    // MARK: Blur

    static let gaussianBlur = EffectDefinition(
        id: "ae.gaussianBlur", name: "Gaussian Blur", category: .blur,
        aeMatchNames: ["ADBE Gaussian Blur 2", "ADBE Gaussian Blur"],
        summary: "Smooth, soft blur.",
        params: [
            .number("blurriness", "Blurriness", 10, 0, 500, unit: "px", ae: 1),
            .choice("dimensions", "Blur Dimensions", ["Horizontal and Vertical", "Horizontal", "Vertical"], 0, ae: 2),
            .toggle("repeatEdges", "Repeat Edge Pixels", false, ae: 3),
        ],
        margin: { e, t in e.bool("repeatEdges") ? 0 : e.number("blurriness", t) * 1.5 },
        stage: .pixels { ctx in
            // Calibration placeholder: AE Blurriness ≈ 2σ. Tuned against AE reference renders later.
            let sigma = ctx.num("blurriness") / 2 * ctx.unit
            let dim = ctx.effect.choice("dimensions")
            return ctx.gpu.gaussian(ctx, input: ctx.input, sigma: sigma, horizontal: dim != 2, vertical: dim != 1,
                                    repeatEdges: ctx.effect.bool("repeatEdges"))
        })

    static let directionalBlur = EffectDefinition(
        id: "ae.directionalBlur", name: "Directional Blur", category: .blur,
        aeMatchNames: ["ADBE Motion Blur"],
        summary: "Streaks the image along an angle, like fast motion.",
        params: [
            .angle("direction", "Direction", 0, ae: 1),
            .number("length", "Blur Length", 20, 0, 1000, unit: "px", ae: 2),
        ],
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in
            let len = ctx.num("length") * ctx.unit
            guard len > 0.5 else { return ctx.input }
            // AE: 0° = vertical streak.
            let a = ctx.num("direction") * .pi / 180
            let v = SIMD2<Float>(Float(sin(a) * len), Float(-cos(a) * len))
            let out = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(v.x, v.y, 0, 0)
            p.i = SIMD4(UInt32(min(256, max(8, Int(len * 1.5)))), 0, 0, 0)
            ctx.gpu.run("fxDirectional", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            return out
        })

    static let radialBlur = EffectDefinition(
        id: "ae.radialBlur", name: "Radial Blur", category: .blur,
        aeMatchNames: ["ADBE Radial Blur", "CC Radial Fast Blur", "CC Radial Blur"],
        summary: "Spin or zoom blur around a center point.",
        params: [
            .number("amount", "Amount", 10, 0, 100, ae: 1),
            .point("center", "Center", Vec2(0.5, 0.5), ae: 2),
            .choice("type", "Type", ["Spin", "Zoom"], 1, ae: 3),
        ],
        margin: { e, t in e.number("amount", t) * 4 },
        stage: .pixels { ctx in
            let amount = ctx.num("amount")
            guard amount > 0.01 else { return ctx.input }
            let c = ctx.effect.point("center", ctx.time)
            let out = ctx.temp()
            var p = EffectParams()
            let type = ctx.effect.choice("type")
            p.a = SIMD4(Float(c.x * Double(ctx.width)), Float(c.y * Double(ctx.height)), Float(type == 0 ? amount : amount * 0.6), 0)
            p.i = SIMD4(UInt32(type), UInt32(min(96, 16 + Int(amount * 2))), 0, 0)
            ctx.gpu.run("fxRadial", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            return out
        })

    // MARK: Color

    private static func colorOp(_ op: UInt32, _ fill: @escaping (EffectContext, inout EffectParams) -> Void) -> EffectStage {
        .pixels { ctx in
            let out = ctx.temp()
            var p = EffectParams()
            fill(ctx, &p)
            p.i.x = op
            ctx.gpu.run("fxColor", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            return out
        }
    }

    static let exposure = EffectDefinition(
        id: "ae.exposure", name: "Exposure", category: .color,
        aeMatchNames: ["ADBE Exposure2", "ADBE Exposure"],
        summary: "Brighten or darken in camera stops.",
        params: [
            .number("exposure", "Exposure", 0, -10, 10, step: 0.01, ae: 3),
            .number("offset", "Offset", 0, -1, 1, step: 0.001, ae: 4),
            .number("gamma", "Gamma Correction", 1, 0.1, 5, step: 0.01, ae: 5),
        ],
        stage: colorOp(0) { ctx, p in p.a = SIMD4(Float(ctx.num("exposure")), Float(ctx.num("offset")), Float(ctx.num("gamma")), 0) })

    static let brightnessContrast = EffectDefinition(
        id: "ae.brightnessContrast", name: "Brightness & Contrast", category: .color,
        aeMatchNames: ["ADBE Brightness & Contrast 2", "ADBE Brightness & Contrast"],
        summary: "Classic brightness and contrast controls.",
        params: [
            .number("brightness", "Brightness", 0, -150, 150, ae: 1),
            .number("contrast", "Contrast", 0, -100, 100, ae: 2),
        ],
        stage: colorOp(1) { ctx, p in p.a = SIMD4(Float(ctx.num("brightness")), Float(ctx.num("contrast")), 0, 0) })

    static let hueSaturation = EffectDefinition(
        id: "ae.hueSaturation", name: "Hue/Saturation", category: .color,
        aeMatchNames: ["ADBE HUE SATURATION"],
        summary: "Shift hue, saturation and lightness, or colorize.",
        params: [
            .angle("hue", "Master Hue", 0, ae: 3),
            .number("saturation", "Master Saturation", 0, -100, 100, ae: 4),
            .number("lightness", "Master Lightness", 0, -100, 100, ae: 5),
            .toggle("colorize", "Colorize", false, ae: 6),
            .number("colorizeSat", "Colorize Saturation", 25, 0, 100, ae: 8),
        ],
        stage: colorOp(2) { ctx, p in
            p.a = SIMD4(Float(ctx.num("hue")), Float(ctx.num("saturation")), Float(ctx.num("lightness")), 0)
            p.b = SIMD4(Float(ctx.num("colorizeSat")), 0, 0, 0)
            p.i.y = ctx.effect.bool("colorize") ? 1 : 0
        })

    static let tint = EffectDefinition(
        id: "ae.tint", name: "Tint", category: .color,
        aeMatchNames: ["ADBE Tint"],
        summary: "Maps dark and light tones to two colors.",
        params: [
            .color("black", "Map Black To", .black, ae: 1),
            .color("white", "Map White To", .white, ae: 2),
            .number("amount", "Amount to Tint", 100, 0, 100, unit: "%", ae: 3),
        ],
        stage: colorOp(3) { ctx, p in
            p.a = SIMD4(Float(ctx.num("amount") / 100), 0, 0, 0)
            p.b = ctx.effect.color("black", ctx.time).simd
            p.c = ctx.effect.color("white", ctx.time).simd
        })

    static let levels = EffectDefinition(
        id: "ae.levels", name: "Levels", category: .color,
        aeMatchNames: ["ADBE Easy Levels2", "ADBE Easy Levels"],
        summary: "Input/output black and white points with gamma.",
        params: [
            .number("inBlack", "Input Black", 0, 0, 255),
            .number("inWhite", "Input White", 255, 0, 255),
            .number("gamma", "Gamma", 1, 0.1, 10, step: 0.01),
            .number("outBlack", "Output Black", 0, 0, 255),
            .number("outWhite", "Output White", 255, 0, 255),
        ],
        stage: colorOp(4) { ctx, p in
            p.a = SIMD4(Float(ctx.num("inBlack") / 255), Float(ctx.num("inWhite") / 255), Float(ctx.num("gamma")), Float(ctx.num("outBlack") / 255))
            p.b = SIMD4(Float(ctx.num("outWhite") / 255), 0, 0, 0)
        })

    static let invert = EffectDefinition(
        id: "ae.invert", name: "Invert", category: .color,
        aeMatchNames: ["ADBE Invert"],
        summary: "Inverts colors.",
        params: [.number("blend", "Blend With Original", 0, 0, 100, unit: "%", ae: 2)],
        stage: colorOp(5) { ctx, p in p.a = SIMD4(Float(1 - ctx.num("blend") / 100), 0, 0, 0) })

    static let fill = EffectDefinition(
        id: "ae.fill", name: "Fill", category: .color,
        aeMatchNames: ["ADBE Fill"],
        summary: "Fills the layer with a solid color, keeping its shape.",
        params: [
            .color("color", "Color", RGBA(1, 0, 0), ae: 3),
            .number("opacity", "Opacity", 100, 0, 100, unit: "%", ae: 7),
        ],
        stage: colorOp(6) { ctx, p in
            p.a = SIMD4(Float(ctx.num("opacity") / 100), 0, 0, 0)
            p.b = ctx.effect.color("color", ctx.time).simd
        })

    static let vignette = EffectDefinition(
        id: "awi.vignette", name: "Vignette", category: .color,
        aeMatchNames: ["CC Vignette"],
        summary: "Darkens (or brightens) the edges.",
        params: [
            .number("amount", "Amount", 60, -100, 100, unit: "%"),
            .number("size", "Size", 40, 0, 100, unit: "%"),
            .number("softness", "Softness", 50, 1, 100, unit: "%"),
        ],
        stage: colorOp(7) { ctx, p in
            p.a = SIMD4(Float(ctx.num("amount") / 100), Float(ctx.num("size") / 100), Float(ctx.num("softness") / 100), 0)
            p.b = SIMD4(Float(ctx.width), Float(ctx.height), 0, 0)
        })

    // MARK: Light / stylize

    static let glow = EffectDefinition(
        id: "ae.glow", name: "Glow", category: .color,
        aeMatchNames: ["ADBE Glo2", "ADBE Glow"],
        summary: "Finds bright areas and makes them glow (multi-radius, HDR).",
        params: [
            .choice("basedOn", "Glow Based On", ["Color Channels", "Alpha Channel"], 0, ae: 1),
            .number("threshold", "Glow Threshold", 60, 0, 100, unit: "%", ae: 2),
            .number("radius", "Glow Radius", 10, 0, 1000, unit: "px", ae: 3),
            .number("intensity", "Glow Intensity", 1, 0, 10, step: 0.01, ae: 4),
            .choice("composite", "Composite Original", ["On Top", "Behind", "None"], 1, ae: 5),
            .choice("operation", "Glow Operation", ["Add", "Screen"], 0, ae: 6),
            .choice("colors", "Glow Colors", ["Original Colors", "A & B Colors"], 0, ae: 7),
            .color("colorA", "Color A", .white, ae: 11),
            .color("colorB", "Color B", RGBA(hex: 0x9B5CFF), ae: 12),
        ],
        margin: { e, t in e.number("radius", t) * 2 },
        stage: .pixels { ctx in
            var tp = EffectParams()
            tp.a = SIMD4(Float(ctx.num("threshold") / 100), 0.05, 0, 0)
            tp.i.x = UInt32(ctx.effect.choice("basedOn"))
            let bright = ctx.temp()
            ctx.gpu.run("fxGlowThreshold", ctx.cb, textures: [ctx.input, bright], params: tp, grid: bright)
            // Multi-scale: sum of blurs at r, r/2, r/4 gives AE-like tight core + wide falloff.
            let r = ctx.num("radius") * ctx.unit
            let g1 = ctx.gpu.gaussian(ctx, input: bright, sigma: r / 2)
            let g2 = ctx.gpu.gaussian(ctx, input: bright, sigma: r / 5)
            let g3 = ctx.gpu.gaussian(ctx, input: bright, sigma: r / 12)
            let sum1 = ctx.temp(), sum2 = ctx.temp()
            var add = EffectParams()
            add.a = SIMD4(1, 0, 0, 0)
            ctx.gpu.run("fxGlowCombine", ctx.cb, textures: [g1, g2, sum1], params: add, grid: sum1)
            ctx.gpu.run("fxGlowCombine", ctx.cb, textures: [sum1, g3, sum2], params: add, grid: sum2)
            let out = ctx.temp()
            var cp = EffectParams()
            cp.a = SIMD4(Float(ctx.num("intensity") / 2), 0, 0, 0)
            cp.i = SIMD4(UInt32(ctx.effect.choice("operation")), UInt32(ctx.effect.choice("composite") == 2 ? 2 : 0),
                         UInt32(ctx.effect.choice("colors")), 0)
            cp.b = ctx.effect.color("colorA", ctx.time).simd
            cp.c = ctx.effect.color("colorB", ctx.time).simd
            ctx.gpu.run("fxGlowCombine", ctx.cb, textures: [ctx.input, sum2, out], params: cp, grid: out)
            return out
        })

    static let rgbSplit = EffectDefinition(
        id: "awi.rgbSplit", name: "RGB Split", category: .stylize,
        aeMatchNames: [],
        summary: "Chromatic aberration: shifts red and blue apart.",
        params: [
            .number("amount", "Amount", 8, 0, 200, unit: "px"),
            .angle("angle", "Angle", 0),
        ],
        margin: { e, t in e.number("amount", t) },
        stage: .pixels { ctx in
            let amt = ctx.num("amount") * ctx.unit
            guard amt > 0.01 else { return ctx.input }
            let a = ctx.num("angle") * .pi / 180
            let out = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(Float(cos(a) * amt), Float(sin(a) * amt), 0, 0)
            ctx.gpu.run("fxRGBSplit", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            return out
        })

    static let fractalNoise = EffectDefinition(
        id: "ae.fractalNoise", name: "Fractal Noise", category: .generate,
        aeMatchNames: ["ADBE Fractal Noise"],
        summary: "Animated organic noise for textures, smoke and flicker.",
        params: [
            .choice("type", "Noise Type", ["Basic", "Turbulent"], 0, ae: 1),
            .toggle("invert", "Invert", false, ae: 3),
            .number("contrast", "Contrast", 100, 0, 1000, ae: 4),
            .number("brightness", "Brightness", 0, -200, 200, ae: 5),
            .number("scale", "Scale", 100, 10, 2000, ae: 9),
            .number("complexity", "Complexity", 6, 1, 10, step: 1, ae: 14),
            .number("subInfluence", "Sub Influence", 70, 0, 100, unit: "%", ae: 16),
            .number("subScaling", "Sub Scaling", 56, 10, 100, unit: "%", ae: 17),
            .number("evolution", "Evolution", 0, -3600, 3600, unit: "°", ae: 21),
            .toggle("keepAlpha", "Use Layer Alpha", true),
        ],
        stage: .pixels { ctx in
            let out = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(Float(ctx.num("contrast")), Float(ctx.num("brightness")), Float(ctx.num("scale") * ctx.unit), Float(ctx.num("complexity")))
            p.b = SIMD4(Float(ctx.num("subInfluence")), Float(ctx.num("subScaling")), Float(ctx.num("evolution") / 360), 0)
            p.i = SIMD4(UInt32(ctx.effect.choice("type")), ctx.effect.bool("invert") ? 1 : 0, ctx.effect.bool("keepAlpha") ? 1 : 0, 0)
            ctx.gpu.run("fxFractalNoise", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            return out
        })

    static let chromaKey = EffectDefinition(
        id: "awi.chromaKey", name: "Chroma Key", category: .keying,
        aeMatchNames: ["Keylight 906", "ADBE Color Key"],
        summary: "Keylight-style green/blue screen removal with despill.",
        params: [
            .color("key", "Screen Color", RGBA(0.13, 0.78, 0.22)),
            .number("tolerance", "Screen Gain", 25, 0, 90, unit: "%"),
            .number("softness", "Edge Softness", 20, 1, 100, unit: "%"),
            .number("spill", "Despill", 100, 0, 100, unit: "%"),
            .number("balance", "Screen Balance", 50, 0, 100, unit: "%"),
            .toggle("viewMatte", "View Matte", false),
            .toggle("invert", "Invert (keep the screen color)", false),
        ],
        stage: .pixels { ctx in
            let out = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(Float(ctx.num("tolerance") / 100), Float(ctx.num("softness") / 100), Float(ctx.num("spill") / 100),
                        Float(ctx.num("balance") / 100))
            p.b = ctx.effect.color("key", ctx.time).simd
            p.i.x = ctx.effect.bool("viewMatte") ? 1 : 0
            ctx.gpu.run("fxChromaKey", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            // Invert: keep only what the key removed (cut out the green thing itself).
            if ctx.effect.bool("invert") && !ctx.effect.bool("viewMatte") {
                let inv = ctx.temp()
                ctx.gpu.run("fx19KeyInvert", ctx.cb, textures: [ctx.input, inv, out], params: EffectParams(), grid: inv)
                return inv
            }
            return out
        })

    // MARK: Motion

    static let shake = EffectDefinition(
        id: "awi.shake", name: "Shake", category: .motion,
        aeMatchNames: [],
        summary: "Wiggle-style camera/layer shake (position, rotation, zoom).",
        params: [
            .number("frequency", "Frequency", 8, 0, 60, step: 0.1, unit: "/s"),
            .number("amplitude", "Position Amount", 30, 0, 1000, unit: "px"),
            .number("rotation", "Rotation Amount", 2, 0, 180, unit: "°"),
            .number("zoom", "Zoom Amount", 0, 0, 100, unit: "%"),
            .number("octaves", "Detail", 2, 1, 6, step: 1),
            .number("seed", "Random Seed", 1, 0, 1000, step: 1),
        ],
        stage: .transform { e, t in
            let f = e.number("frequency", t), oct = Int(e.number("octaves", t)), seed = e.number("seed", t)
            let dx = Wiggle.value(t: t, freq: f, octaves: oct, seed: seed * 13 + 1) * e.number("amplitude", t)
            let dy = Wiggle.value(t: t, freq: f, octaves: oct, seed: seed * 13 + 2) * e.number("amplitude", t)
            let dr = Wiggle.value(t: t, freq: f, octaves: oct, seed: seed * 13 + 3) * e.number("rotation", t)
            let ds = 1 + Wiggle.value(t: t, freq: f, octaves: oct, seed: seed * 13 + 4) * e.number("zoom", t) / 100
            return (dx, dy, dr, ds)
        })
}

/// AE-like wiggle: smooth fractal noise in [-1, 1].
enum Wiggle {
    static func value(t: Double, freq: Double, octaves: Int, ampMult: Double = 0.5, seed: Double) -> Double {
        var sum = 0.0, amp = 1.0, norm = 0.0, f = freq
        for o in 0..<max(1, octaves) {
            sum += noise1(t * f + Double(o) * 17.17, seed: seed + Double(o) * 31) * amp
            norm += amp
            amp *= ampMult
            f *= 2
        }
        return sum / norm
    }

    private static func hash(_ i: Double, _ seed: Double) -> Double {
        let x = sin(i * 127.1 + seed * 311.7) * 43758.5453
        return (x - floor(x)) * 2 - 1
    }

    /// 1D gradient-ish value noise with quintic smoothing.
    static func noise1(_ x: Double, seed: Double) -> Double {
        let i = floor(x), f = x - i
        let u = f * f * f * (f * (f * 6 - 15) + 10)
        return hash(i, seed) * (1 - u) + hash(i + 1, seed) * u
    }
}
