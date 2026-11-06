import Foundation
import Metal
import simd

/// The shared glitch engine (fxGX in Effects24.metal) that the remade glitch, pixel and block effects run on.
/// Each effect keeps its own id and settings, so saved projects open with the new look.
extension EffectRegistry {
    /// - rate: how many times per second the damage pattern changes (pieces hold, then snap).
    /// - burst: (base, bursts/s, length, seed) for effects with designed burst timing; nil = always on.
    static func gx(_ ctx: EffectContext, _ mode: UInt32, rate: Double = 12, seed: Double = 0,
                   burst: SIMD4<Float>? = nil, option: UInt32 = 0, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.i.z = option
        if let burst { p.c = burst; p.i.y = 1 }
        p.d = SIMD4(Float(ctx.time), Float((ctx.time * max(rate, 0.01)).rounded(.down)), Float(seed), 0)
        ctx.gpu.run("fxGX", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }

    /// One pass of the paint / art kernel (fxArt24). `aux` is an earlier pass (defaults to the input).
    static func art(_ ctx: EffectContext, _ mode: UInt32, src: MTLTexture? = nil, aux: MTLTexture? = nil,
                    _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        let input = src ?? ctx.input
        ctx.gpu.run("fxArt24", ctx.cb, textures: [input, out, aux ?? input], params: p, grid: out)
        return out
    }

    /// Burst timing from the glitch pack's shared controls.
    static func gxBurst(_ ctx: EffectContext) -> SIMD4<Float> {
        SIMD4(Float(ctx.num("base") / 100), Float(ctx.num("rate")), Float(ctx.num("length") / 100), Float(ctx.num("seed")))
    }
}
