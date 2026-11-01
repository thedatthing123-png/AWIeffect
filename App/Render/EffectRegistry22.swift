import Foundation
import Metal
import simd

/// Batch 22: tiny planet, shaped pixelates, ink bleed and wind streaks.
extension EffectRegistry {
    static let batch22: [EffectDefinition] = [tinyPlanet22, trianglePixelate22, brickPixelate22, diamondPixelate22, inkBleed22, windStreaks22]

    private static func run22(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        ctx.gpu.run("fx22", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }

    static let tinyPlanet22 = EffectDefinition(
        id: "awi22.tinyPlanet", name: "Tiny Planet", category: .distort, aeMatchNames: [],
        summary: "Wraps the layer into a little round world: the bottom edge becomes the ground in the middle.",
        params: [.number("zoom", "Zoom", 1.5, 0.1, 10, step: 0.01), .angle("rotation", "Rotation", 0)],
        stage: .pixels { ctx in run22(ctx, 0) { p in
            p.a = SIMD4(Float(ctx.num("zoom")), Float(ctx.num("rotation") * .pi / 180), 0, 0)
            p.b = layerRect(ctx) } })

    static let trianglePixelate22 = EffectDefinition(
        id: "awi22.trianglePixelate", name: "Triangle Pixelate", category: .stylize, aeMatchNames: [],
        summary: "Breaks the image into flat triangles (low-poly look).",
        params: [.number("size", "Cell Size", 30, 2, 400, unit: "px")],
        stage: .pixels { ctx in run22(ctx, 1) { p in p.a.x = Float(ctx.num("size") * ctx.unit) } })

    static let brickPixelate22 = EffectDefinition(
        id: "awi22.brickPixelate", name: "Brick Pixelate", category: .stylize, aeMatchNames: [],
        summary: "Pixelates into offset bricks with thin mortar lines.",
        params: [.number("size", "Brick Height", 24, 2, 400, unit: "px"), .number("offset", "Row Offset", 50, 0, 100, unit: "%")],
        stage: .pixels { ctx in run22(ctx, 2) { p in p.a = SIMD4(Float(ctx.num("size") * ctx.unit), Float(ctx.num("offset") / 100), 0, 0) } })

    static let diamondPixelate22 = EffectDefinition(
        id: "awi22.diamondPixelate", name: "Diamond Pixelate", category: .stylize, aeMatchNames: [],
        summary: "Pixelates into 45 degree diamonds.",
        params: [.number("size", "Cell Size", 26, 2, 400, unit: "px")],
        stage: .pixels { ctx in run22(ctx, 3) { p in p.a.x = Float(ctx.num("size") * ctx.unit) } })

    static let inkBleed22 = EffectDefinition(
        id: "awi22.inkBleed", name: "Ink Bleed", category: .stylize, aeMatchNames: [],
        summary: "Dark lines spread into the paper like wet manga ink.",
        params: [.number("spread", "Spread", 4, 1, 60, unit: "px"), .number("threshold", "Ink Threshold", 55, 1, 100, unit: "%")],
        margin: { e, t in e.number("spread", t) },
        stage: .pixels { ctx in run22(ctx, 4) { p in p.a = SIMD4(Float(ctx.num("spread") * ctx.unit), Float(ctx.num("threshold") / 100), 0, 0) } })

    static let windStreaks22 = EffectDefinition(
        id: "awi22.windStreaks", name: "Wind Streaks", category: .stylize, aeMatchNames: [],
        summary: "Bright parts blow into streaks along the wind (anime gusts, light trails).",
        params: [.number("length", "Length", 80, 1, 800, unit: "px"), .angle("angle", "Direction", 0),
                 .number("threshold", "Threshold", 50, 0, 100, unit: "%"), .number("intensity", "Intensity", 1, 0, 5, step: 0.01)],
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in run22(ctx, 5) { p in
            p.a = SIMD4(Float(ctx.num("length") * ctx.unit), Float(ctx.num("angle") * .pi / 180), Float(ctx.num("threshold") / 100), Float(ctx.num("intensity"))) } })
}
