import Foundation
import Metal
import simd

/// Reference-led additions. Existing saved effect IDs and implementations remain intact.
extension EffectRegistry {
    static let batchAM35: [EffectDefinition] = [fractalRidgesAM35, psykoBlobsAM35, spectralMapAM35]

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
    static let psykoBlobsAM35 = EffectDefinition(
        id: "awi.am35.psykoBlobs", name: "PsykoBlobs", category: .color, aeMatchNames: [],
        summary: "Luminance-driven psychedelic color bands with a soft noise field. Preserve dark ink outlines while animating the band phase.",
        params: [.number("noiseFreq", "Blob Scale", 3.5, 0.1, 20, step: 0.1),
                 .number("sourceScale", "Luma Influence", 1.5, 0, 10, step: 0.01),
                 .number("freqColors", "Band Density", 4.5, 0.1, 50, step: 0.1),
                 .number("phaseSpeed", "Phase Speed", 0.5, -10, 10, step: 0.01),
                 .number("saturation", "Saturation", 1.8, 0, 5, step: 0.1),
                 .number("outlineStrength", "Preserve Outlines", 1, 0, 2, step: 0.01),
                 .number("mixWithSource", "Mix With Source", 0, 0, 1, step: 0.01)],
        stage: .pixels { ctx in
            let output = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(f29(ctx, "noiseFreq"), f29(ctx, "sourceScale"), f29(ctx, "freqColors"), f29(ctx, "phaseSpeed"))
            p.b = SIMD4(f29(ctx, "saturation"), f29(ctx, "outlineStrength"), f29(ctx, "mixWithSource"), Float(ctx.time))
            ctx.gpu.run("fxPsykoBlobsAM35", ctx.cb, textures: [ctx.input, output], params: p, grid: output)
            return output
        })

    static let spectralMapAM35 = EffectDefinition(
        id: "awi.am35.spectralMap", name: "Spectral Map", category: .color, aeMatchNames: [],
        summary: "Map brightness through three repeating color bands. Phase shifts the palette; Squeeze narrows the bands. Reverse and Scale Brightness control how the source drives the map.",
        params: [.number("phase", "Phase", 0, -99, 99, step: 0.005),
                 .number("repeat", "Repeat", 1, 0.1, 10, step: 0.01),
                 .number("alpha", "Mix", 1, 0, 1, step: 0.01),
                 .number("squeeze", "Squeeze", 0, 0, 1, step: 0.01),
                 .number("saturation", "Saturation", 0, -1, 1, step: 0.005),
                 .color("redColor", "Color 1", RGBA(1, 0, 0)),
                 .color("greenColor", "Color 2", RGBA(0, 1, 0)),
                 .color("blueColor", "Color 3", RGBA(0, 0, 1)),
                 .toggle("reverse", "Reverse", false), .toggle("scaleBrightness", "Scale Brightness", false)],
        stage: .pixels { ctx in
            let output = ctx.temp()
            var p = EffectParams()
            func pack(_ key: String) -> UInt32 {
                let c = rgba29(ctx, key)
                func byte(_ x: Double) -> UInt32 { UInt32((max(0, min(1, x)) * 255).rounded()) }
                return (byte(c.r) << 24) | (byte(c.g) << 16) | (byte(c.b) << 8) | byte(c.a)
            }
            p.a = SIMD4(f29(ctx, "phase"), f29(ctx, "repeat"), f29(ctx, "alpha"), f29(ctx, "squeeze"))
            p.b = SIMD4(f29(ctx, "saturation"), 0, 0, 0)
            let flags: UInt32 = (b29(ctx, "reverse") ? 1 : 0) | (b29(ctx, "scaleBrightness") ? 2 : 0)
            p.i = SIMD4(flags, pack("redColor"), pack("greenColor"), pack("blueColor"))
            ctx.gpu.run("fxSpectralMapAM35", ctx.cb, textures: [ctx.input, output], params: p, grid: output)
            return output
        })

}
