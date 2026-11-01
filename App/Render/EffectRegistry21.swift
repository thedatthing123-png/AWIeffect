import Foundation
import Metal
import simd

/// Batch 21: liquid distortions (glass, droplets, reflections, water).
extension EffectRegistry {
    static let batch21: [EffectDefinition] = [liquidGlass21, waterDroplets21, puddle21, waterWaves21]

    private static func run21(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        ctx.gpu.run("fx21", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }

    static let liquidGlass21 = EffectDefinition(
        id: "awi21.liquidGlass", name: "Liquid Glass", category: .distort, aeMatchNames: [],
        summary: "Thick moving glass over the layer: soft blobs bend the image and their edges catch the light.",
        params: [.number("refraction", "Refraction", 30, 0, 200, unit: "px"), .number("scale", "Blob Size", 80, 8, 600, unit: "px"),
                 .number("speed", "Flow Speed", 0.4, 0, 5, step: 0.01), .number("highlight", "Edge Light", 0.25, 0, 1, step: 0.01)],
        margin: { e, t in e.number("refraction", t) },
        stage: .pixels { ctx in run21(ctx, 0) { p in
            p.a = SIMD4(Float(ctx.num("refraction") * ctx.unit), Float(ctx.num("scale") * ctx.unit), Float(ctx.num("speed")), Float(ctx.num("highlight")))
            p.b.x = Float(ctx.time) } })

    static let waterDroplets21 = EffectDefinition(
        id: "awi21.waterDroplets", name: "Water Droplets", category: .distort, aeMatchNames: [],
        summary: "Raindrops on glass: each drop shows the image magnified and flipped, with a rim and a glint.",
        params: [.number("size", "Drop Size", 22, 3, 200, unit: "px"), .number("density", "Density", 55, 0, 100, unit: "%"),
                 .number("refraction", "Refraction", 12, 0, 80, unit: "px"), .number("glint", "Glint", 0.8, 0, 2, step: 0.01),
                 .number("seed", "Random Seed", 1, 0, 1000, step: 1)],
        stage: .pixels { ctx in run21(ctx, 1) { p in
            p.a = SIMD4(Float(ctx.num("size") * ctx.unit), Float(ctx.num("density") / 100), Float(ctx.num("refraction") * ctx.unit), Float(ctx.num("glint")))
            p.b.x = Float(ctx.num("seed")) } })

    static let puddle21 = EffectDefinition(
        id: "awi21.puddle", name: "Puddle Reflection", category: .distort, aeMatchNames: [],
        summary: "Mirrors the layer below a horizon line with rippling water and fade (wet street, lake).",
        params: [.number("horizon", "Horizon", 70, 0, 100, unit: "%"), .number("ripple", "Ripple", 6, 0, 80, unit: "px"),
                 .number("rippleScale", "Ripple Scale", 30, 2, 300, unit: "px"), .number("darkness", "Darken", 35, 0, 100, unit: "%"),
                 .number("speed", "Ripple Speed", 1, 0, 10, step: 0.01)],
        stage: .pixels { ctx in run21(ctx, 2) { p in
            let r = layerRect(ctx)
            p.a = SIMD4(r.y + r.w * Float(ctx.num("horizon") / 100), Float(ctx.num("ripple") * ctx.unit), Float(ctx.num("rippleScale") * ctx.unit), Float(ctx.num("darkness") / 100))
            p.b = SIMD4(Float(ctx.time), Float(ctx.num("speed")), 0, 0) } })

    static let waterWaves21 = EffectDefinition(
        id: "awi21.waterWaves", name: "Water Waves", category: .distort, aeMatchNames: [],
        summary: "Rolling ocean-style waves: crests sharpen with Choppiness, with a cross swell for natural water.",
        params: [.number("amplitude", "Amplitude", 8, 0, 120, unit: "px"), .number("wavelength", "Wavelength", 90, 4, 1000, unit: "px"),
                 .number("speed", "Speed", 0.6, -5, 5, step: 0.01), .number("chop", "Choppiness", 1, 0, 3, step: 0.01),
                 .angle("angle", "Direction", 0)],
        margin: { e, t in e.number("amplitude", t) * 2 },
        stage: .pixels { ctx in run21(ctx, 3) { p in
            p.a = SIMD4(Float(ctx.num("amplitude") * ctx.unit), Float(ctx.num("wavelength") * ctx.unit), Float(ctx.num("speed")), Float(ctx.num("chop")))
            p.b = SIMD4(Float(ctx.time), Float(ctx.num("angle") * .pi / 180), 0, 0) } })
}
