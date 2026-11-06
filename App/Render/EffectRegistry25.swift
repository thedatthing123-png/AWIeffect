import Foundation
import Metal
import simd

/// The shared photographic light engine (Effects25.metal) the remade Glow & Light effects run on:
/// threshold extraction with a soft knee, a tight-core + wide-halo blur pyramid, hue-keeping composite,
/// falloff streaks and generated light (sweep, flare, leak). Each effect keeps its own id and settings.
extension EffectRegistry {
    enum LightSource25: UInt32 { case color = 0, alpha = 1, hue = 2, solid = 3 }

    /// Emission from the layer: only parts above `threshold` (0...1) emit, growing smoothly through `knee`.
    static func lightPrep25(_ ctx: EffectContext, src: MTLTexture? = nil, source: LightSource25 = .color,
                            threshold: Double, knee: Double = 0.12, saturation: Double = 1, gain: Double = 1,
                            tint: SIMD4<Float> = SIMD4(1, 1, 1, 1), tintAmount: Double = 0,
                            hueKey: SIMD3<Float> = SIMD3(0, 0, 0)) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        p.a = SIMD4(Float(threshold), Float(knee), Float(saturation), Float(gain))
        p.b = SIMD4(tint.x, tint.y, tint.z, Float(tintAmount))
        p.c = SIMD4(hueKey.x, hueKey.y, hueKey.z, 0)
        p.i.y = source.rawValue
        ctx.gpu.run("fxLightPrep25", ctx.cb, textures: [src ?? ctx.input, out], params: p, grid: out)
        return out
    }

    /// Sums up to four textures with weights (negative weights subtract; the result never goes below zero).
    static func lightSum25(_ ctx: EffectContext, _ levels: [MTLTexture], _ weights: [Double]) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        var w = SIMD4<Float>(0, 0, 0, 0)
        for k in 0..<min(4, weights.count, levels.count) { w[k] = Float(weights[k]) }
        p.a = w
        let t = (0..<4).map { $0 < levels.count ? levels[$0] : levels[0] }
        ctx.gpu.run("fxLightSum25", ctx.cb, textures: t + [out], params: p, grid: out)
        return out
    }

    /// Glow pyramid: four blur levels from a tight core to the full radius (layer px already scaled by ctx.unit).
    /// `falloff` 0 = core heavy (crisp, AE Glow), 1 = halo heavy (dreamy, wide).
    static func lightBloom25(_ ctx: EffectContext, _ light: MTLTexture, radius: Double, falloff: Double = 0.45) -> MTLTexture {
        guard radius > 0.5 else { return light }
        let fr = [0.05, 0.16, 0.42, 1.0]
        let levels = fr.map { ctx.gpu.gaussian(ctx, input: light, sigma: max(0.6, radius * $0 / 2)) }
        let f = min(max(falloff, 0), 1)
        let w = [1.0 - 0.5 * f, 0.8, 0.55 + 0.25 * f, 0.35 + 0.5 * f]
        let total = w.reduce(0, +)
        return lightSum25(ctx, levels, w.map { $0 * 1.6 / total })
    }

    enum LightOp25: UInt32 { case add = 0, screen = 1 }
    enum LightComposite25: UInt32 { case over = 0, behind = 1, glowOnly = 2 }
    enum LightMask25: UInt32 { case none = 0, outside = 1, inside = 2 }

    /// Adds `glow` onto `base` with the hue-keeping soft shoulder (no channel clipping to white).
    static func lightComp25(_ ctx: EffectContext, base: MTLTexture, glow: MTLTexture, intensity: Double,
                            tint: SIMD4<Float> = SIMD4(1, 1, 1, 1), saturation: Double = 1, burn: Double = 0.3,
                            prism: Double = 0, op: LightOp25 = .add, composite: LightComposite25 = .over,
                            colors: (SIMD4<Float>, SIMD4<Float>)? = nil, mask: LightMask25 = .none,
                            maskTexture: MTLTexture? = nil) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        p.a = SIMD4(Float(intensity), Float(saturation), Float(burn), Float(prism))
        p.b = tint
        if let colors { p.c = colors.0; p.d = colors.1; p.i.z = 1 }
        p.i.x = op.rawValue; p.i.y = composite.rawValue; p.i.w = mask.rawValue
        ctx.gpu.run("fxLightComp25", ctx.cb, textures: [base, out, glow, maskTexture ?? ctx.input], params: p, grid: out)
        return out
    }

    /// Extract → pyramid → composite in one call (the standard photographic glow).
    static func glow25(_ ctx: EffectContext, threshold: Double, radius: Double, intensity: Double, falloff: Double = 0.45,
                       saturation: Double = 1, tint: SIMD4<Float> = SIMD4(1, 1, 1, 1), tintAmount: Double = 0,
                       burn: Double = 0.3, prism: Double = 0, op: LightOp25 = .add) -> MTLTexture {
        let light = lightPrep25(ctx, threshold: threshold, saturation: saturation, tint: tint, tintAmount: tintAmount)
        let g = lightBloom25(ctx, light, radius: radius, falloff: falloff)
        return lightComp25(ctx, base: ctx.input, glow: g, intensity: intensity, burn: burn, prism: prism, op: op)
    }

    enum StreakMode25: UInt32 { case star = 0, linear = 1, zoom = 2, godRays = 3 }

    /// Streak light from an emission texture. For star / linear, `length` is in layer px (already scaled);
    /// for zoom / god rays it is a 0...1 fraction of the way to `center` (texture px).
    static func streak25(_ ctx: EffectContext, light: MTLTexture, mode: StreakMode25, length: Double, rays: Int = 4,
                         rotation: Double = 0, center: SIMD2<Float> = .zero, decay: Double = 1, intensity: Double = 1,
                         tintA: SIMD4<Float> = SIMD4(1, 1, 1, 1), tintB: SIMD4<Float>? = nil, rainbow: Bool = false) -> MTLTexture {
        // Pre-soften the emission by the sample spacing so rays read as smooth light, not dotted taps.
        var src = light
        if mode == .star || mode == .linear {
            let step = length / 24 * 0.6
            if step > 0.8 { src = ctx.gpu.gaussian(ctx, input: light, sigma: min(step, 12)) }
        }
        let out = ctx.temp()
        var p = EffectParams()
        p.a = SIMD4(center.x, center.y, Float(length), Float(rotation))
        p.b = SIMD4(Float(decay), Float(intensity), tintB == nil ? 0 : 1, Float(ctx.time))
        p.c = tintA
        p.d = tintB ?? tintA
        p.i = SIMD4(mode.rawValue, UInt32(max(2, min(16, rays))), rainbow ? 1 : 0, 0)
        ctx.gpu.run("fxStreak25", ctx.cb, textures: [src, out], params: p, grid: out)
        // A light final soften removes any remaining step pattern and gives the ray a glowing body.
        return ctx.gpu.gaussian(ctx, input: out, sigma: 0.9 * ctx.unit)
    }

    /// Generated light (0 light sweep, 1 lens flare, 2 light leak).
    static func lightGen25(_ ctx: EffectContext, _ mode: UInt32, sub: UInt32 = 0, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode; p.i.y = sub
        p.d.x = Float(ctx.time)
        ctx.gpu.run("fxLightGen25", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }

    static func pt25(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    static func col25(_ ctx: EffectContext, _ key: String) -> SIMD4<Float> { ctx.effect.color(key, ctx.time).simd }
    /// A control added by the remake: projects saved before it existed read its default instead of 0.
    static func opt25(_ ctx: EffectContext, _ key: String, _ def: Double) -> Double {
        ctx.effect.params[key] != nil ? ctx.num(key) : def
    }
    static func optColor25(_ ctx: EffectContext, _ key: String, _ def: RGBA) -> SIMD4<Float> {
        (ctx.effect.params[key]?.color(at: ctx.time) ?? def).simd
    }
}
