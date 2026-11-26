import Foundation
import Metal

extension EffectRegistry {
    static let remadeEffects = [edgeCurrent, syncRoll]

    static let edgeCurrent = EffectDefinition(
        id: "awi.edgeCurrent", name: "Edge Current", category: .color, aeMatchNames: [],
        summary: "Send a moving highlight around the silhouette of text or transparent artwork. Keyframe the starting angle or let it travel on its own.",
        params: [
            .point("center", "Pivot", Vec2(0.5, 0.5)),
            .angle("angle", "Starting Angle", -40),
            .number("speed", "Revolutions / Second", 0.55, -8, 8, step: 0.01),
            .number("arc", "Arc Length", 25, 2, 95, unit: "%"),
            .number("width", "Edge Width", 7, 1, 60, unit: "px"),
            .number("intensity", "Intensity", 100, 0, 300, unit: "%"),
            .color("tint", "Light Color", RGBA(0.66, 0.88, 1))
        ],
        margin: { effect, time in effect.value("width")?.number(at: time) ?? 7 },
        stage: .pixels { context in
            let amount = effectNumber(context, "intensity", 100) / 100
            guard amount > 0 else { return context.input }
            let center = context.effect.value("center")?.point(at: context.time) ?? Vec2(0.5, 0.5)
            let tint = context.effect.value("tint")?.color(at: context.time) ?? RGBA(0.66, 0.88, 1)
            let rect = layerRect(context)
            let phase = effectNumber(context, "angle", -40) / 360
                + EffectRate.phase(context.effect, key: "speed", time: context.time, range: -8...8, fallback: 0.55)
            var params = EffectParams()
            params.a = SIMD4(rect.x + Float(center.x) * rect.z, rect.y + Float(center.y) * rect.w,
                             Float(phase.truncatingRemainder(dividingBy: 1)), Float(effectNumber(context, "arc", 25) / 200))
            params.b = SIMD4(Float(effectNumber(context, "width", 7) * context.unit), Float(amount), 0, 0)
            params.c = tint.simd
            return renderRemadeEffect("fxEdgeCurrent", context, params)
        })

    static let syncRoll = EffectDefinition(
        id: "awi.syncRoll", name: "Sync Roll", category: .glitch, aeMatchNames: [],
        summary: "Roll the picture vertically through its own frame. A dark sync seam and sideways pull travel with the wrapped edge.",
        params: [
            .number("mix", "Mix", 100, 0, 100, unit: "%"),
            .number("offset", "Roll Offset", 14, -100, 100, unit: "%"),
            .number("speed", "Rolls / Second", 0.7, -8, 8, step: 0.01),
            .number("seam", "Seam Width", 6, 0, 30, unit: "%"),
            .number("darkness", "Seam Darkness", 78, 0, 100, unit: "%"),
            .number("pull", "Side Pull", 18, -200, 200, unit: "px")
        ],
        stage: .pixels { context in
            let mix = effectNumber(context, "mix", 100) / 100
            guard mix > 0 else { return context.input }
            let phase = effectNumber(context, "offset", 14) / 100
                + EffectRate.phase(context.effect, key: "speed", time: context.time, range: -8...8, fallback: 0.7)
            var params = EffectParams()
            params.a = layerRect(context)
            params.b = SIMD4(Float(phase.truncatingRemainder(dividingBy: 1)), Float(effectNumber(context, "seam", 6) / 200),
                             Float(effectNumber(context, "darkness", 78) / 100), Float(mix))
            params.c.x = Float(effectNumber(context, "pull", 18) * context.unit)
            return renderRemadeEffect("fxSyncRoll", context, params)
        })

    private static func effectNumber(_ context: EffectContext, _ key: String, _ fallback: Double) -> Double {
        context.effect.value(key)?.number(at: context.time) ?? fallback
    }

    private static func renderRemadeEffect(_ kernel: String, _ context: EffectContext, _ params: EffectParams) -> MTLTexture {
        let output = context.temp()
        context.gpu.run(kernel, context.cb, textures: [context.input, output], params: params, grid: output)
        return output
    }
}
