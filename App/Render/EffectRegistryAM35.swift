import Foundation
import Metal
import simd

/// Reference-led additions. Existing saved effect IDs and implementations remain intact.
extension EffectRegistry {
    static let batchAM35: [EffectDefinition] = [fractalRidgesAM35]

    static let fractalRidgesAM35 = EffectDefinition(
        id: "awi.am35.fractalRidges", name: "Fractal Ridges", category: .generate, aeMatchNames: [],
        summary: "Two-color ridged fractal texture. Animate Evolution for changing ridges, Parallax for flow, or Offset for drift. The texture follows the layer's alpha.",
        params: [.point("parallax", "Parallax", Vec2(0, 0)), .point("offset", "Offset", Vec2(0, 0)),
                 .number("evolution", "Evolution", 0, -50, 50, step: 0.01),
                 .number("scale", "Scale", 1, 0.01, 50, step: 0.01),
                 .number("stretchX", "Stretch X", 1, 0.01, 10, step: 0.01),
                 .number("stretchY", "Stretch Y", 1, 0.01, 10, step: 0.01),
                 .number("intensity", "Intensity", 1, 0.1, 1.5, step: 0.01),
                 .number("seed", "Seed", 0, 0, 5, step: 0.01),
                 .color("color1", "Color 1", .black), .color("color2", "Color 2", .white),
                 .number("octaves", "Octaves", 6, 1, 9, step: 1),
                 .number("blend", "Blend", 100, 0, 100, unit: "%")],
        stage: .pixels { ctx in
            let output = ctx.temp()
            var p = EffectParams()
            func point(_ key: String) -> Vec2 {
                ctx.effect.params[key] != nil ? ctx.effect.point(key, ctx.time) : Vec2(0, 0)
            }
            func pack(_ key: String) -> UInt32 {
                let c = rgba29(ctx, key)
                func byte(_ x: Double) -> UInt32 { UInt32((max(0, min(1, x)) * 255).rounded()) }
                return (byte(c.r) << 24) | (byte(c.g) << 16) | (byte(c.b) << 8) | byte(c.a)
            }
            let offset = point("offset"), parallax = point("parallax")
            p.a = layerRect(ctx)
            p.b = SIMD4(Float(offset.x), Float(offset.y), Float(parallax.x), Float(parallax.y))
            p.c = SIMD4(f29(ctx, "scale"), f29(ctx, "stretchX"), f29(ctx, "stretchY"), f29(ctx, "evolution"))
            p.d = SIMD4(f29(ctx, "intensity"), 0, f29(ctx, "seed"), pc29(ctx, "blend"))
            p.i = SIMD4(UInt32(max(1, min(9, v29(ctx, "octaves")))), pack("color1"), pack("color2"), 0)
            ctx.gpu.run("fxFractalRidgesAM35", ctx.cb, textures: [ctx.input, output], params: p, grid: output)
            return output
        })
}
