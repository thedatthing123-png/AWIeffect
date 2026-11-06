import Foundation
import Metal
import simd

/// Batch 29 helpers: Fractal Noise, domain-warped clouds/smoke/fire, crystal shards, depth-layered particles,
/// Luma / Color Range keys and gamut-safe color ops (kernels in Effects29.metal).
extension EffectRegistry {
    // MARK: Values with fallback to the definition default (older saved instances lack the newer controls).

    private static func def29(_ ctx: EffectContext, _ k: String) -> ParamDef? {
        EffectRegistry.definition(ctx.effect.typeID)?.params.first(where: { $0.id == k })
    }
    static func v29(_ ctx: EffectContext, _ k: String) -> Double {
        if ctx.effect.params[k] != nil { return ctx.num(k) }
        return def29(ctx, k)?.defaultValue.number(at: ctx.time) ?? 0
    }
    static func f29(_ ctx: EffectContext, _ k: String) -> Float { Float(v29(ctx, k)) }
    static func px29(_ ctx: EffectContext, _ k: String) -> Float { Float(v29(ctx, k) * ctx.unit) }
    static func pc29(_ ctx: EffectContext, _ k: String) -> Float { Float(v29(ctx, k) / 100) }
    static func b29(_ ctx: EffectContext, _ k: String) -> Bool {
        if ctx.effect.params[k] != nil { return ctx.effect.bool(k) }
        if case .toggle(let b)? = def29(ctx, k)?.defaultValue { return b }
        return false
    }
    static func ch29(_ ctx: EffectContext, _ k: String) -> Int {
        if ctx.effect.params[k] != nil { return ctx.effect.choice(k) }
        if case .choice(let i)? = def29(ctx, k)?.defaultValue { return i }
        return 0
    }
    static func rgba29(_ ctx: EffectContext, _ k: String) -> RGBA {
        if ctx.effect.params[k] != nil { return ctx.effect.color(k, ctx.time) }
        return def29(ctx, k)?.defaultValue.color(at: ctx.time) ?? .white
    }
    static func col29(_ ctx: EffectContext, _ k: String) -> SIMD4<Float> { rgba29(ctx, k).simd }
    static func pack29(_ ctx: EffectContext, _ k: String) -> UInt32 {
        let c = rgba29(ctx, k)
        func b(_ v: Double) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
        return (b(c.r) << 16) | (b(c.g) << 8) | b(c.b)
    }

    // MARK: Runners

    /// Generators: same Blend / Effect Only compositing as the batch 7 / 12 generators.
    static func gen29(_ ctx: EffectContext, _ mode: UInt32, over: Bool, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.i.y = over ? 1 : 0
        p.d.x = Float(ctx.time)
        p.d.y = Float(v29(ctx, "blend") / 100)
        p.d.z = b29(ctx, "only") ? 1 : 0
        ctx.gpu.run("fxGen29", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }
    static func key29(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        ctx.gpu.run("fxKey29", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }
    static func color29(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        ctx.gpu.run("fxColor29", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }

    /// After Effects-style Fractal Noise.
    static func fractalNoise29(_ ctx: EffectContext) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        let scale = max(v29(ctx, "scale"), 1) * ctx.unit
        let sw = max(v29(ctx, "scaleWidth"), 1) / 100, sh = max(v29(ctx, "scaleHeight"), 1) / 100
        let off = ctx.effect.params["offset"] != nil ? ctx.effect.point("offset", ctx.time) : Vec2(0.5, 0.5)
        let seed = v29(ctx, "seed")
        let ox = (off.x - 0.5) * Double(ctx.width) + seed * 137.1 * scale
        let oy = (off.y - 0.5) * Double(ctx.height) + seed * 71.3 * scale
        let evo = v29(ctx, "evolution") / 360 + v29(ctx, "evoSpeed") * ctx.time
        let cycles = b29(ctx, "cycle") ? max(1, v29(ctx, "cycles")) : 0
        p.a = SIMD4(f29(ctx, "contrast"), f29(ctx, "brightness"), Float(scale * sw), f29(ctx, "complexity"))
        p.b = SIMD4(pc29(ctx, "subInfluence"), pc29(ctx, "subScaling"), Float(evo), Float(v29(ctx, "rotation") * .pi / 180))
        p.c = SIMD4(Float(ox), Float(oy), Float(v29(ctx, "subRotation") * .pi / 180), pc29(ctx, "opacity"))
        p.d = SIMD4(px29(ctx, "subOffsetX"), px29(ctx, "subOffsetY"), Float(cycles), Float(sh / sw))
        let flags: UInt32 = (b29(ctx, "invert") ? UInt32(1) : 0) | (b29(ctx, "keepAlpha") ? UInt32(2) : 0) | (UInt32(ch29(ctx, "blend")) << 8)
        p.i = SIMD4(UInt32(ch29(ctx, "type")), UInt32(ch29(ctx, "noiseType")), UInt32(ch29(ctx, "overflow")), UInt32(flags))
        ctx.gpu.run("fxFractalNoise29", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }
}
