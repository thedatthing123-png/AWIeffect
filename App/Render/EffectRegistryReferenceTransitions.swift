import Foundation
import Metal

/// Original transitions complement the reference imports. Completion always
/// removes this layer, revealing the actual layers beneath it, never a fake
/// black second image. All controls use the normal keyframe/graph system.
extension EffectRegistry {
    static let referenceTransitions: [EffectDefinition] = [liquidLensWipe, voronoiPeel]

    static let liquidLensWipe = EffectDefinition(
        id: "awi.ref.liquidLensWipe", name: "Liquid Lens Wipe", category: .transition, aeMatchNames: [],
        summary: "A refractive liquid boundary travels across the layer. Flow bends the boundary; Lens Width and Refraction shape its glass-like rim. Animate Progress from 0 to 100 to reveal the layers below.",
        params: [.number("progress", "Progress", 0, 0, 100, unit: "%"),
                 .angle("angle", "Direction", 0), .number("flow", "Flow", 0.45, 0, 1, step: 0.01),
                 .number("detail", "Flow Detail", 4, 0.5, 20, step: 0.1),
                 .number("refraction", "Refraction", 36, 0, 200, unit: "px"),
                 .number("width", "Lens Width", 30, 1, 200, unit: "px"),
                 .number("dispersion", "Dispersion", 20, 0, 100, unit: "%"),
                 .number("softness", "Edge Softness", 1, 0, 40, unit: "px"),
                 .number("evolution", "Evolution", 0, -100, 100, step: 0.01),
                 .number("seed", "Seed", 1, 0, 100, step: 0.1)],
        stage: .pixels { context in
            var p = EffectParams()
            p.a = SIMD4(f29(context, "progress") / 100, f29(context, "angle") * .pi / 180,
                        f29(context, "flow"), f29(context, "detail"))
            p.b = SIMD4(f29(context, "refraction") * Float(context.unit), f29(context, "width") * Float(context.unit),
                        f29(context, "dispersion") / 100, f29(context, "softness") * Float(context.unit))
            p.c = SIMD4(f29(context, "evolution"), f29(context, "seed"), 0, 0)
            p.d = layerRect(context)
            let output = context.temp()
            context.gpu.run("fxLiquidLensReference", context.cb, textures: [context.input, output], params: p, grid: output)
            return output
        })

    static let voronoiPeel = EffectDefinition(
        id: "awi.ref.voronoiPeel", name: "Voronoi Peel", category: .transition, aeMatchNames: [],
        summary: "The source contracts into independently turning Voronoi fragments. Order chooses random, radial or directional timing. Stagger changes the delay between cells; Progress 100 removes every fragment.",
        params: [.number("progress", "Progress", 0, 0, 100, unit: "%"),
                 .number("cells", "Cell Density", 9, 2, 40, step: 1),
                 .number("jitter", "Cell Irregularity", 0.8, 0, 1, step: 0.01),
                 .choice("order", "Order", ["Random", "From Origin", "Across", "Reverse Across"], 1),
                 .point("origin", "Origin", Vec2(0.5, 0.5)),
                 .angle("angle", "Direction", 0),
                 .number("stagger", "Stagger", 65, 0, 95, unit: "%"),
                 .number("peel", "Contraction", 100, 0, 100, unit: "%"),
                 .angle("turn", "Fragment Turn", 55),
                 .number("softness", "Edge Softness", 0.75, 0, 8, unit: "px"),
                 .number("seed", "Seed", 1, 0, 100, step: 0.1)],
        stage: .pixels { context in
            var p = EffectParams()
            p.a = SIMD4(f29(context, "progress") / 100, f29(context, "cells"), f29(context, "jitter"), f29(context, "stagger") / 100)
            let point = context.effect.params["origin"]?.point(at: context.time) ?? Vec2(0.5, 0.5)
            p.b = SIMD4(Float(point.x), Float(point.y), f29(context, "angle") * .pi / 180, f29(context, "turn") * .pi / 180)
            p.c = SIMD4(f29(context, "peel") / 100, f29(context, "softness") * Float(context.unit), f29(context, "seed"), 0)
            p.d = layerRect(context)
            p.i.x = UInt32(clamping: context.effect.choice("order"))
            if context.effect.params["order"] == nil { p.i.x = 1 }
            let output = context.temp()
            context.gpu.run("fxVoronoiPeelReference", context.cb, textures: [context.input, output], params: p, grid: output)
            return output
        })
}
