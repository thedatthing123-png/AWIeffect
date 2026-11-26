import Foundation

extension EffectRegistry {
    static let motionFinishEffects = [shapedLightSweep, lightIris]

    private static let shapedLightSweep = EffectDefinition(
        id: "awi.shapedLightSweep", name: "Shaped Light Sweep", category: .color, aeMatchNames: [],
        summary: "Place and keyframe a light band with a solid core, shaped falloff, and adjustable response to the image.",
        params: [
            .point("center", "Beam Center", Vec2(0.5, 0.5)),
            .angle("angle", "Sweep Angle", 28),
            .number("width", "Beam Width", 120, 1, 2000, unit: "px"),
            .number("core", "Solid Core", 18, 0, 90, unit: "%"),
            .number("falloff", "Falloff", 1.25, 0.25, 4, step: 0.05),
            .number("intensity", "Intensity", 65, 0, 200, unit: "%"),
            .number("response", "Image Response", 45, 0, 100, unit: "%"),
            .color("tint", "Light Color", RGBA(1, 0.91, 0.78)),
            .choice("blend", "Blend", ["Screen", "Add"], 0)
        ],
        stage: .pixels { context in
            func number(_ key: String, _ fallback: Double) -> Double {
                context.effect.value(key) == nil ? fallback : context.num(key)
            }
            let intensity = number("intensity", 65) / 100
            guard intensity > 0 else { return context.input }
            let center = context.effect.value("center")?.point(at: context.time) ?? Vec2(0.5, 0.5)
            let rect = layerRect(context)
            let angle = number("angle", 28) * .pi / 180
            let tint = context.effect.value("tint")?.color(at: context.time) ?? RGBA(1, 0.91, 0.78)
            var params = EffectParams()
            params.a = SIMD4(rect.x + Float(center.x) * rect.z, rect.y + Float(center.y) * rect.w,
                             Float(cos(angle)), Float(sin(angle)))
            params.b = SIMD4(Float(number("width", 120) * context.unit * 0.5),
                             Float(number("core", 18) / 100), Float(number("falloff", 1.25)), Float(intensity))
            params.c = SIMD4(Float(tint.r), Float(tint.g), Float(tint.b), Float(tint.a))
            params.d.x = Float(number("response", 45) / 100)
            params.i.x = UInt32(clamping: context.effect.choice("blend"))
            let output = context.temp()
            context.gpu.run("fxShapedLightSweep", context.cb, textures: [context.input, output], params: params, grid: output)
            return output
        })

    private static let lightIris = EffectDefinition(
        id: "awi.lightIris", name: "Light Iris Wipe", category: .transition, aeMatchNames: [],
        summary: "A ring of light follows an expanding cut as it reveals the layers beneath. Keyframe Progress to time the reveal.",
        params: [
            .number("progress", "Progress", 38, 0, 100, unit: "%"),
            .point("center", "Center", Vec2(0.5, 0.5)),
            .number("feather", "Feather", 4, 0, 200, unit: "px"),
            .number("radius", "Light Width", 28, 1, 300, unit: "px"),
            .number("intensity", "Light Intensity", 90, 0, 300, unit: "%"),
            .color("tint", "Light Color", RGBA(0.52, 0.78, 1)),
            .toggle("sourceColor", "Use Image Color", false)
        ],
        stage: .pixels { context in
            func number(_ key: String, _ fallback: Double) -> Double {
                context.effect.value(key) == nil ? fallback : context.num(key)
            }
            let progress = number("progress", 38) / 100
            guard progress > 0 else { return context.input }
            let center = context.effect.value("center")?.point(at: context.time) ?? Vec2(0.5, 0.5)
            let rect = layerRect(context)
            let tint = context.effect.value("tint")?.color(at: context.time) ?? RGBA(0.52, 0.78, 1)
            var params = EffectParams()
            params.a = SIMD4(rect.x + Float(center.x) * rect.z, rect.y + Float(center.y) * rect.w,
                             Float(progress), Float(number("feather", 4) * context.unit))
            params.b = SIMD4(Float(number("radius", 28) * context.unit), Float(number("intensity", 90) / 100), 0, 0)
            params.c = SIMD4(Float(tint.r), Float(tint.g), Float(tint.b), Float(tint.a))
            params.i.x = context.effect.bool("sourceColor") ? 1 : 0
            let output = context.temp()
            context.gpu.run("fxLightIrisWipe", context.cb, textures: [context.input, output], params: params, grid: output)
            return output
        })
}
