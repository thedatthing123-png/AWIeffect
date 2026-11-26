import Foundation

extension EffectRegistry {
    static let ghostEffects: [EffectDefinition] = [ghost]

    private static let ghost = EffectDefinition(
        id: "awi.ghost", name: "Ghost", category: .stylize, aeMatchNames: [],
        summary: "Layers a scaled negative of the current frame over the original. Keyframe its opacity and scale for an impact.",
        params: [
            .number("opacity", "Opacity", 26, 0, 100, unit: "%"),
            .number("scale", "Scale", 114, 20, 200, unit: "%"),
            .point("position", "Ghost Position", Vec2(0.5, 0.5)),
            .angle("rotation", "Rotation", 0),
            .number("invert", "Invert", 100, 0, 100, unit: "%")
        ],
        expandedMargin: { effect, time, size in
            let ghost = GhostOverlaySettings(effect, at: time)
            guard ghost.opacity > 0 else { return 0 }
            let halfWidth = size.x / 2
            let halfHeight = size.y / 2
            let cosine = abs(cos(ghost.rotation))
            let sine = abs(sin(ghost.rotation))
            let extraX = (halfWidth * cosine + halfHeight * sine) * ghost.scale + abs(ghost.offset.x * size.x) - halfWidth
            let extraY = (halfWidth * sine + halfHeight * cosine) * ghost.scale + abs(ghost.offset.y * size.y) - halfHeight
            return max(0, extraX, extraY)
        },
        stage: .pixels { context in
            let ghost = GhostOverlaySettings(context.effect, at: context.time)
            guard ghost.opacity > 0 else { return context.input }
            let bufferSize = SIMD2(Double(context.width), Double(context.height))
            let layerSize = context.layerPixels ?? bufferSize
            let output = context.temp()
            var params = EffectParams()
            params.a = SIMD4(Float(ghost.opacity), Float(ghost.inversion), Float(1 / ghost.scale), 0)
            params.b = SIMD4(Float(cos(ghost.rotation)), Float(sin(ghost.rotation)),
                             Float(ghost.offset.x * layerSize.x), Float(ghost.offset.y * layerSize.y))
            context.gpu.run("fxGhostOverlay", context.cb, textures: [context.input, output], params: params, grid: output)
            return output
        })
}

private struct GhostOverlaySettings {
    let opacity: Double
    let inversion: Double
    let scale: Double
    let offset: Vec2
    let rotation: Double

    init(_ effect: EffectInstance, at time: Double) {
        func number(_ key: String, fallback: Double) -> Double {
            effect.value(key)?.number(at: time) ?? fallback
        }
        opacity = min(100, max(0, number("opacity", fallback: 26))) / 100
        inversion = min(100, max(0, number("invert", fallback: 100))) / 100
        scale = min(200, max(20, number("scale", fallback: 114))) / 100
        let position = effect.value("position")?.point(at: time) ?? Vec2(0.5, 0.5)
        offset = Vec2(min(1, max(0, position.x)) - 0.5, min(1, max(0, position.y)) - 0.5)
        rotation = number("rotation", fallback: 0).truncatingRemainder(dividingBy: 360) * .pi / 180
    }
}
