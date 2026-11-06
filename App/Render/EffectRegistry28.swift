import Foundation
import Metal
import simd

/// Batch 28: Distort & Transitions remakes (Turbulent Displace, Wave Warp, Polar Coordinates, Ripple, Magnify,
/// antialiased pattern wipes and eased transition progress). Kernels live in Effects28.metal.
extension EffectRegistry {
    /// Edge behavior options when the old look sampled transparent outside the layer.
    static let edgeOptions28 = ["Transparent", "Repeat Edge Pixels", "Tile", "Mirror"]
    /// Edge behavior options when the old look repeated edge pixels (Turbulent Displace).
    static let edgeRepeatFirst28 = ["Repeat Edge Pixels", "Transparent", "Tile", "Mirror"]
    static let aaOptions28 = ["Low", "Medium", "High"]
    static let easeOptions28 = ["Linear", "Ease In", "Ease Out", "Ease In-Out"]

    /// Kernel edge-mode code (0 transparent, 1 repeat, 2 tile, 3 mirror) for a choice from `edgeOptions28`.
    static func edgeCode28(_ ctx: EffectContext, _ key: String = "edge") -> UInt32 {
        UInt32(min(3, max(0, ctx.effect.choice(key))))
    }
    /// Kernel edge-mode code for a choice from `edgeRepeatFirst28`.
    static func edgeRepeatCode28(_ ctx: EffectContext, _ key: String = "edge") -> UInt32 {
        [1, 0, 2, 3][min(3, max(0, ctx.effect.choice(key)))]
    }
    /// Supersampling grid (1, 2 or 3 per axis) for an Antialiasing choice.
    static func aaGrid28(_ ctx: EffectContext, _ key: String = "aa") -> UInt32 {
        UInt32(min(2, max(0, ctx.effect.choice(key))) + 1)
    }

    /// A number control that older saved instances may lack: falls back to the pre-remake behavior.
    static func num28(_ ctx: EffectContext, _ key: String, _ fallback: Double) -> Double {
        ctx.effect.params[key] == nil ? fallback : ctx.num(key)
    }
    /// A choice control that older saved instances may lack.
    static func choice28(_ ctx: EffectContext, _ key: String, _ fallback: Int) -> Int {
        ctx.effect.params[key] == nil ? fallback : ctx.effect.choice(key)
    }

    /// Transition progress easing (completion 0..1 in and out).
    static func ease28(_ x: Double, _ mode: Int) -> Double {
        let t = min(1, max(0, x))
        switch mode {
        case 1: return t * t * t
        case 2: let u = 1 - t; return 1 - u * u * u
        case 3: return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        default: return t
        }
    }

    /// Transition modes whose masks are rendered by the antialiased fxTrans28 kernel.
    static let trans28Modes: Set<UInt32> = [0, 7, 15, 16, 17]

    static func run28(_ kernel: String, _ ctx: EffectContext, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        ctx.gpu.run(kernel, ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }

    // MARK: Turbulent Displace

    static func turbulent28(_ ctx: EffectContext) -> MTLTexture {
        run28("fxTurbulent28", ctx) { p in
            func value(_ key: String, _ fallback: Double) -> Double { ctx.effect.params[key] == nil ? fallback : ctx.num(key) }
            p.a = SIMD4(Float(ctx.num("amount") * ctx.unit), Float(ctx.num("size") * ctx.unit),
                        Float(ctx.num("complexity")), Float(ctx.num("evolution") / 360))
            p.b = SIMD4(Float(value("stretchX", 100) / 100), Float(value("stretchY", 100) / 100),
                        Float(value("offsetX", 0) * ctx.unit), Float(value("offsetY", 0) * ctx.unit))
            let cycle = ctx.effect.bool("cycle") ? max(1, ctx.num("cycleLen")) : 0
            p.c = SIMD4(Float(cycle), Float(ctx.num("pinSoft") / 100), 0, 0)
            p.d = layerRect(ctx)
            p.i = SIMD4(UInt32(max(0, ctx.effect.choice("dispType"))), UInt32(max(0, ctx.effect.choice("axis"))),
                        edgeRepeatCode28(ctx) | (aaGrid28(ctx) << 4), UInt32(max(0, ctx.effect.choice("pinning"))))
        }
    }

    // MARK: Wave Warp

    static func waveWarp28(_ ctx: EffectContext) -> MTLTexture {
        run28("fxWaveWarp28", ctx) { p in
            p.a = SIMD4(Float(ctx.num("height") * ctx.unit), Float(ctx.num("width") * ctx.unit), Float(ctx.num("direction")),
                        Float(ctx.time * ctx.num("speed") * 2 * .pi + ctx.num("phase") * .pi / 180))
            p.b = layerRect(ctx)
            p.c = SIMD4(Float(ctx.num("pinSoft") / 100), 0, 0, 0)
            p.i = SIMD4(UInt32(max(0, ctx.effect.choice("type"))), UInt32(max(0, ctx.effect.choice("pinning"))),
                        aaGrid28(ctx), edgeCode28(ctx))
        }
    }

    // MARK: Polar Coordinates

    static func polar28(_ ctx: EffectContext) -> MTLTexture {
        run28("fxPolar28", ctx) { p in
            p.a = SIMD4(Float(ctx.num("interp") / 100), 0, 0, 0)
            p.i = SIMD4(ctx.effect.choice("type") == 0 ? 0 : 1, aaGrid28(ctx), 0, 0)
        }
    }

    // MARK: Ripple

    static func ripple28(_ ctx: EffectContext) -> MTLTexture {
        run28("fxRipple28", ctx) { p in
            let v = ctx.effect.point("center", ctx.time)
            p.a = SIMD4(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)),
                        Float(ctx.num("radius") / 100 * Double(max(ctx.width, ctx.height))), Float(ctx.num("width") * ctx.unit))
            p.b = SIMD4(Float(ctx.num("height") * ctx.unit),
                        Float(ctx.time * ctx.num("speed") * 2 * .pi + ctx.num("phase") * .pi / 180),
                        choice28(ctx, "conversion", 1) == 1 ? 1 : 0, Float(aaGrid28(ctx)))
            p.i = SIMD4(edgeCode28(ctx), 0, 0, 0)
        }
    }

    // MARK: Magnify

    static func magnify28(_ ctx: EffectContext) -> MTLTexture {
        run28("fxMagnify28", ctx) { p in
            let v = ctx.effect.point("center", ctx.time)
            p.a = SIMD4(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)), Float(ctx.num("mag") / 100),
                        Float(ctx.num("size") * ctx.unit))
            p.b = SIMD4(Float(ctx.num("feather") * ctx.unit), Float(num28(ctx, "opacity", 100) / 100),
                        Float(max(0, ctx.effect.choice("shape"))), Float(max(0, ctx.effect.choice("blend"))))
        }
    }
}
