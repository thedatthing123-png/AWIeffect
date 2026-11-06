import Foundation
import Metal
import simd

/// Batch 27: print screens (halftone family), manga ink, film / TV looks and the remaining glitch looks.
/// Kernels live in Effects27.metal: fxPrint27, fxInk27, fxFilm27, fxGlitch27.
extension EffectRegistry {
    /// Dot shapes of the print screens (index = kernel shape id).
    static let printShapes27 = ["Round", "Square", "Diamond", "Line", "Ellipse", "Cross"]

    /// A setting older saved instances may not have yet: falls back to `def` instead of 0.
    static func v27(_ ctx: EffectContext, _ key: String, _ def: Double) -> Double {
        ctx.effect.params[key] != nil ? ctx.num(key) : def
    }

    static func col27(_ ctx: EffectContext, _ key: String, _ def: RGBA) -> SIMD4<Float> {
        (ctx.effect.params[key]?.color(at: ctx.time) ?? def).simd
    }

    /// One print-screen pass. `cell` is in texture px. Tone comes from a light blur (about a third of a cell) so
    /// dots follow the picture smoothly and never alias.
    static func print27(_ ctx: EffectContext, mode: UInt32, cell: Double, angle: Double, contrast: Double = 1, mix: Double = 1,
                        ink: SIMD4<Float>, paper: SIMD4<Float>, shape: Int = 0, colorDots: Bool = false, levels: Int = 0,
                        bias: Double = 0, keep: Double = 0, extra: SIMD2<Float> = .zero) -> MTLTexture {
        let cellPx = max(1, cell)
        let tone = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: min(8, max(0.6, cellPx * 0.3)), repeatEdges: true)
        let out = ctx.temp()
        var p = EffectParams()
        p.a = SIMD4(Float(cellPx), Float(angle), Float(max(0, contrast)), Float(min(max(mix, 0), 1)))
        p.b = ink
        p.c = paper
        p.d = SIMD4(Float(bias), Float(keep), extra.x, extra.y)
        p.i = SIMD4(mode, UInt32(min(max(shape, 0), printShapes27.count - 1)), colorDots ? 1 : 0, UInt32(max(0, levels)))
        ctx.gpu.run("fxPrint27", ctx.cb, textures: [ctx.input, out, tone], params: p, grid: out)
        return out
    }

    /// Ink pass: two Gaussian blurs (sigma and 1.6 x sigma, texture px) feed the DoG line detector.
    static func ink27(_ ctx: EffectContext, mode: UInt32, sigma: Double, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let s = max(0.5, sigma)
        let a = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: s, repeatEdges: true)
        let b = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: s * 1.6, repeatEdges: true)
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        ctx.gpu.run("fxInk27", ctx.cb, textures: [ctx.input, out, a, b], params: p, grid: out)
        return out
    }

    /// Film / TV pass. `aux` defaults to the input (CRT passes a blurred copy for halation).
    static func film27(_ ctx: EffectContext, mode: UInt32, aux: MTLTexture? = nil, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d = SIMD4(Float(ctx.time), Float(ctx.unit), Float((ctx.time * 30).rounded(.down)), 0)
        ctx.gpu.run("fxFilm27", ctx.cb, textures: [ctx.input, out, aux ?? ctx.input], params: p, grid: out)
        return out
    }

    /// Same timing controls as the glitch pack (ids and defaults match EffectRegistry19's `timing`).
    static let timing27: [ParamDef] = [
        .number("base", "Always On", 25, 0, 100, unit: "%"),
        .number("rate", "Bursts Per Second", 3, 0.2, 20, step: 0.05),
        .number("length", "Burst Length", 50, 2, 100, unit: "%"),
        .number("seed", "Random Seed", 1, 0, 1000, step: 1),
    ]

    /// Glitch pass on fxGlitch27 with the shared burst timing in `b`.
    static func glitch27(_ ctx: EffectContext, mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.b = SIMD4(Float(v27(ctx, "base", 25) / 100), Float(v27(ctx, "rate", 3)), Float(v27(ctx, "length", 50) / 100), Float(v27(ctx, "seed", 1)))
        p.i.x = mode
        p.d = SIMD4(Float(ctx.time), Float(ctx.unit), 0, 0)
        ctx.gpu.run("fxGlitch27", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }

    /// A glitch-pack effect ("awi19." + id) rendered by fxGlitch27.
    static func g27(_ id: String, _ name: String, _ summary: String, _ params: [ParamDef],
                    margin: @escaping (EffectInstance, Double) -> Double = { _, _ in 0 },
                    _ mode: UInt32, _ fill: @escaping (EffectContext, inout EffectParams) -> Void) -> EffectDefinition {
        EffectDefinition(id: "awi19." + id, name: name, category: .glitch, aeMatchNames: [], summary: summary, params: params + timing27,
                         margin: margin, stage: .pixels { ctx in glitch27(ctx, mode: mode) { fill(ctx, &$0) } })
    }
}
