import Foundation
import Metal
import simd

/// First researched expansion batch. Geometry effects reuse the vector path renderer.
extension EffectRegistry {
    static let batch23 = [litRipple23, timeSliceMask23, drawingProgress23]

    static func run23(_ ctx: EffectContext, mode: UInt32, fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams(); p.i.x = mode
        p.d = layerRect(ctx)
        fill(&p)
        ctx.gpu.run("fx23", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }

    static let litRipple23 = EffectDefinition(
        id: "awi23.litRipple", name: "Lit Ripple", category: .distort, aeMatchNames: [],
        summary: "Expanding water rings with bright white crests, radial refraction and adjustable lighting. Separate from ordinary Ripple.",
        params: [.number("strength", "Distortion", 0.02, 0, 0.2, step: 0.001),
                 .number("frequency", "Frequency", 20, 1, 100, step: 0.1),
                 .number("speed", "Speed", 1, -10, 10, step: 0.01),
                 .number("radius", "Radius Scale", 1, 0.1, 2, step: 0.01),
                 .number("decay", "Decay", 0.5, 0, 2, step: 0.01),
                 .point("center", "Center", Vec2(0.5, 0.5)),
                 .number("light", "Light Intensity", 0.6, 0, 2, step: 0.01),
                 .number("sharpness", "Light Sharpness", 2, 0.1, 10, step: 0.1),
                 .color("tint", "Light Color", .white),
                 .number("mix", "Effect Mix", 100, 0, 100, unit: "%")],
        stage: .pixels { ctx in run23(ctx, mode: 0) { p in
            p.a = SIMD4(Float(ctx.num("strength")), Float(ctx.num("frequency")), Float(ctx.time * ctx.num("speed")), Float(ctx.num("radius")))
            let center = ctx.effect.point("center", ctx.time)
            p.b = SIMD4(Float(center.x), Float(center.y), Float(ctx.num("decay")), Float(ctx.num("light")))
            let tint = ctx.effect.color("tint", ctx.time)
            p.c = SIMD4(Float(tint.r), Float(tint.g), Float(tint.b), Float(ctx.num("sharpness")))
            p.i.y = UInt32((ctx.num("mix") * 100).rounded())
        } })

    static let timeSliceMask23 = EffectDefinition(
        id: "awi23.timeSliceMask", name: "Time Slice Mask", category: .keying, aeMatchNames: [],
        summary: "Animated diagonal bands reveal and hide the layer. White Mask output can drive a track matte; this does not offset video time.",
        params: [.number("count", "Count", 10, 1, 200, step: 1),
                 .number("smoothness", "Smoothness", 0.5, 0, 1, step: 0.01),
                 .number("speed", "Speed", 1, -5, 5, step: 0.01),
                 .angle("angle", "Angle", 0),
                 .number("feather", "Feather", 0.02, 0, 1, step: 0.001),
                 .number("phase", "Phase", 0, 0, 1, step: 0.001),
                 .toggle("reverse", "Reverse", false),
                 .choice("output", "Output", ["Reveal Layer", "White Mask"], 0)],
        stage: .pixels { ctx in run23(ctx, mode: 1) { p in
            p.a = SIMD4(Float(ctx.num("count")), Float(ctx.num("smoothness")), Float(ctx.num("feather")), Float(ctx.num("angle") * .pi / 180))
            let phase = ctx.time * ctx.num("speed") + ctx.num("phase")
            p.b.x = Float(phase - floor(phase)); p.i.y = ctx.effect.bool("reverse") ? 1 : 0
            p.i.z = UInt32(clamping: ctx.effect.choice("output"))
        } })

    static let drawingProgress23 = EffectDefinition(
        id: "awi23.drawProgress", name: "Draw Progress", category: .stylize, aeMatchNames: [],
        summary: "Draws vector shapes and freehand vector strokes by path length. Start and End remove percentages from each end. Raster paintings have no editable stroke path.",
        params: [.number("start", "Start", 0, 0, 100, unit: "%"),
                 .number("end", "End", 0, 0, 100, unit: "%")],
        stage: .transform { _, _ in (0, 0, 0, 1) })

    /// Sequential effects trim the surviving geometry, without modifying saved path/keyframes.
    static func drawingSegments(_ segments: [SIMD4<Float>], effects: [EffectInstance], time: Double) -> [SIMD4<Float>] {
        var result = segments
        for effect in effects where effect.isEnabled && effect.typeID == drawingProgress23.id {
            let start = min(100, max(0, effect.number("start", time)))
            let end = min(100, max(0, effect.number("end", time)))
            guard start + end < 100 else { return [] }
            result = PathGPU.trimmed(result, start: start, end: 100 - end, offset: 0, closed: false)
        }
        return result
    }
}
