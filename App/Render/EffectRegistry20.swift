import Foundation
import Metal
import simd

/// Batch 20: 3D-feeling layer effects.
extension EffectRegistry {
    static let batch20: [EffectDefinition] = [flip20, softBody20, amWave20]

    /// Flip: turn the layer like a card in 3D (or flat 2D flips at 180°), around any pivot, with perspective and a
    /// chosen back side. Keyframe Angle for flips, card turns and coin spins.
    static let flip20 = EffectDefinition(
        id: "awi20.flip", name: "Flip", category: .motion, aeMatchNames: ["CC Basic 3D"],
        summary: "Flip or turn the layer like a 3D card: horizontal, vertical or free angle with perspective, pivot and back side. Keyframe Angle for flips, coin spins and card turns.",
        params: [
            .choice("axis", "Flip Axis", ["Horizontal (around Y)", "Vertical (around X)", "Both"], 0),
            .angle("angle", "Angle", 0),
            .angle("tilt", "Tilt", 0),
            .angle("spin", "Spin (Z)", 0),
            .number("perspective", "Perspective", 50, 0, 100, unit: "%"),
            .point("pivot", "Pivot", Vec2(0.5, 0.5)),
            .choice("back", "Back Side", ["Mirrored", "Same Way", "Hidden", "Solid Color"], 0),
            .color("backColor", "Back Color", RGBA(0.15, 0.15, 0.2)),
            .toggle("shade", "Shading", true),
        ],
        margin: { e, t in 300 * e.number("perspective", t) / 100 + 60 },
        stage: .pixels { ctx in
            let out = ctx.temp()
            let lp = ctx.layerPixels ?? SIMD2(Double(ctx.width), Double(ctx.height))
            let ox = (Double(ctx.width) - lp.x) / 2, oy = (Double(ctx.height) - lp.y) / 2
            let pv = ctx.effect.point("pivot", ctx.time)
            let px = ox + pv.x * lp.x, py = oy + pv.y * lp.y
            let rad = Double.pi / 180
            let a = ctx.num("angle") * rad
            let axis = ctx.effect.choice("axis")
            let yA = axis == 1 ? 0 : a, xA = axis == 0 ? 0 : a
            // Perspective 0 = flat (very far camera), 100 = strong (camera close to the card).
            let persp = ctx.num("perspective") / 100
            let dist = max(lp.x, lp.y) * (persp < 0.01 ? 400 : (0.8 + (1 - persp) * 6))
            var p = EffectParams()
            p.a = SIMD4(Float(yA), Float(xA + ctx.num("tilt") * rad), Float(ctx.num("spin") * rad), Float(dist))
            // Half size measured from the pivot so the card keeps its edges when the pivot moves.
            p.b = SIMD4(Float(px), Float(py), Float(lp.x / 2 + abs(px - (ox + lp.x / 2))), Float(lp.y / 2 + abs(py - (oy + lp.y / 2))))
            p.c = ctx.effect.color("backColor", ctx.time).simd
            p.i = SIMD4(UInt32(ctx.effect.choice("back")), ctx.effect.bool("shade") ? 1 : 0, 0, 0)
            ctx.gpu.run("fx20Flip", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            return out
        })

    /// Wave Warp, Alight Motion style (the one that animates hair and flags well): normalized spacing / magnitude,
    /// warp angle, and damping so one end stays still. Keyframe Phase; whole-number phases loop.
    static let amWave20 = EffectDefinition(
        id: "awi20.amWaveWarp", name: "Wave Warp (Alight Motion)", category: .distort, aeMatchNames: [],
        summary: "Alight Motion's Wave Warp: keyframe Phase for hair, cloth and flags. Damping keeps one end still (e.g. hair roots). Whole-number phases loop.",
        params: [
            .number("phase", "Phase", 0, 0, 500, step: 0.01),
            .angle("angle", "Angle", 0),
            .number("spacing", "Spacing", 20, 0, 500, step: 0.1),
            .number("magnitude", "Magnitude", 4, 0, 30, step: 0.1),
            .angle("warpAngle", "Warp Angle", 90),
            .number("damping", "Damping: Magnitude", 0, -100, 100, unit: "%"),
            .number("dampingSpacing", "Damping: Spacing", 0, -100, 100, unit: "%"),
            .number("dampingOrigin", "Damping: Anchor", 50, 0, 100, unit: "%"),
            .toggle("screenSpace", "Screen Space", false),
        ],
        margin: { e, t in e.number("magnitude", t) * 30 },
        stage: .pixels { ctx in
            let out = ctx.temp()
            let rad = Double.pi / 180
            var p = EffectParams()
            p.a = SIMD4(Float(ctx.num("angle") * rad), Float((ctx.num("angle") + ctx.num("warpAngle")) * rad), Float(ctx.num("spacing")), Float(ctx.num("magnitude")))
            p.b = layerRect(ctx)
            p.c = SIMD4(Float(ctx.num("phase")), Float(ctx.num("damping") / 100), Float(ctx.num("dampingSpacing") / 100), Float(ctx.num("dampingOrigin") / 100))
            p.i = SIMD4(ctx.effect.bool("screenSpace") ? 1 : 0, 0, 0, 0)
            ctx.gpu.run("fx20AMWave", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            return out
        })
}
