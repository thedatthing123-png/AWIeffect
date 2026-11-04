import Foundation
import Metal

extension EffectRegistry {
    private static func image24(_ id: String, _ name: String, _ category: EffectCategory, _ summary: String,
                                _ params: [ParamDef], mode: UInt32, distance: Bool = false, blur: Bool = false) -> EffectDefinition {
        EffectDefinition(id: "awi24." + id, name: name, category: category, aeMatchNames: [], summary: summary, params: params,
            margin: { e, t in distance ? e.number("range", t) : 0 }, stage: .pixels { ctx in
                let out = ctx.temp()
                let auxiliary = distance ? distanceField24(ctx) : (blur ? ctx.gpu.gaussian(ctx, input: ctx.input, sigma: ctx.num("radius") * ctx.unit, repeatEdges: true) : ctx.input)
                var p = EffectParams(); p.i.x = mode; p.d = layerRect(ctx); p.c = SIMD4(Float(ctx.width), Float(ctx.height), 0, 0)
                switch mode {
                case 0: p.a = SIMD4(Float(ctx.num("range") * ctx.unit), Float(ctx.num("bias")), 0, 0)
                case 1:
                    p.a = SIMD4(Float(ctx.num("spacing") * ctx.unit), Float(ctx.num("width") * ctx.unit), Float(ctx.num("phase")), Float(ctx.num("range") * ctx.unit))
                    let color = ctx.effect.color("color", ctx.time); p.b = SIMD4(Float(color.r), Float(color.g), Float(color.b), Float(color.a))
                    p.i.y = UInt32(clamping: ctx.effect.choice("side"))
                case 2: p.a = SIMD4(Float(ctx.num("amount") * ctx.unit), Float(ctx.num("range") * ctx.unit), 0, 0)
                case 3: p.a = SIMD4(Float(ctx.num("base") / 100), Float(ctx.num("detail") / 100), 0, 0)
                case 4: p.a = SIMD4(Float(ctx.num("threshold") / 100), Float(ctx.num("softness") / 100), Float(ctx.num("mix") / 100), 0); p.i.y = ctx.effect.bool("dark") ? 1 : 0
                default: break
                }
                ctx.gpu.run("fx24Image", ctx.cb, textures: [ctx.input, out, auxiliary], params: p, grid: out)
                return out
            })
    }
    static let imageBatch24: [EffectDefinition] = [
        image24("alphaDistance", "Alpha Distance Field", .keying, "Signed silhouette distance: mid-gray is the boundary, white inside and black outside. Very fine details may be lost on inputs larger than 2048 px.", [
            .number("range", "Distance Range", 32, 1, 128, unit: "px"), .number("bias", "Boundary Bias", 0, -1, 1, step: 0.01)], mode: 0, distance: true),
        image24("distanceBands", "Distance Bands", .stylize, "Contour-following bands measured from the actual alpha boundary, including holes; choose inside, outside or both.", [
            .number("range", "Range", 32, 1, 128, unit: "px"), .number("spacing", "Band Spacing", 8, 2, 64, unit: "px"),
            .number("width", "Band Width", 2, 0.25, 16, unit: "px"), .number("phase", "Phase", 0, 0, 1, step: 0.001),
            .color("color", "Band Color", RGBA(0.2, 0.8, 1)), .choice("side", "Side", ["Both", "Inside", "Outside"], 0)], mode: 1, distance: true),
        image24("distanceWarp", "Distance-Gradient Warp", .distort, "Displace along a silhouette’s distance gradient, with finite edge falloff. Uses alpha shape, not a radial center.", [
            .number("range", "Falloff Range", 32, 1, 128, unit: "px"), .number("amount", "Displacement", 12, -64, 64, unit: "px")], mode: 2, distance: true),
        image24("matteFrequency", "Matte Frequency Split", .keying, "Separate broad alpha structure from fine edge detail with a Gaussian base; independently adjust and recombine both.", [
            .number("radius", "Separation Radius", 4, 0.5, 32, unit: "px"), .number("base", "Base Gain", 80, 0, 200, unit: "%"),
            .number("detail", "Detail Gain", 150, 0, 300, unit: "%")], mode: 3, blur: true),
        image24("localContrastMatte", "Local Contrast Matte", .keying, "Select details relative to local average brightness instead of absolute luma. Choose bright or dark detail and blend the matte.", [
            .number("radius", "Neighborhood", 6, 0.5, 32, unit: "px"), .number("threshold", "Threshold", 5, 0, 100, unit: "%"),
            .number("softness", "Softness", 10, 0.1, 100, unit: "%"), .number("mix", "Mix", 100, 0, 100, unit: "%"), .toggle("dark", "Dark Detail", false)], mode: 4, blur: true)
    ]

    private static func distanceField24(_ ctx: EffectContext) -> MTLTexture {
        let scale = min(1, 2048 / Double(max(ctx.width, ctx.height)))
        let width = max(1, Int(Double(ctx.width) * scale)), height = max(1, Int(Double(ctx.height) * scale))
        var a = ctx.pool.acquire(width: width, height: height, format: .rg32Float)
        var b = ctx.pool.acquire(width: width, height: height, format: .rg32Float)
        var setup = EffectParams(); setup.a = SIMD4(Float(ctx.width) / Float(width), Float(ctx.height) / Float(height), 0, 0)
        ctx.gpu.run("fx24Seed", ctx.cb, textures: [ctx.input, a], params: setup, grid: a)
        var step = 1
        while step < max(width, height) { step *= 2 }
        step /= 2
        while step >= 1 {
            var p = setup; p.i.x = UInt32(step)
            ctx.gpu.run("fx24Jump", ctx.cb, textures: [a, b], params: p, grid: b)
            swap(&a, &b); step /= 2
        }
        var p = setup; p.i.x = 1
        ctx.gpu.run("fx24Jump", ctx.cb, textures: [a, b], params: p, grid: b)
        return b
    }
}
