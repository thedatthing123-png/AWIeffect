import Foundation
import Metal

extension EffectRegistry {
    static let remadeEffects = [edgeCurrent, syncRoll, lineHold, inkOverprint, sortBands, panelFlash]

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
        summary: "Roll the left and right sides of the picture out of sync. Keyframe the split and phase gap to line them back up.",
        params: [
            .number("mix", "Mix", 100, 0, 100, unit: "%"),
            .number("offset", "Roll Offset", 14, -100, 100, unit: "%"),
            .number("speed", "Rolls / Second", 0.7, -8, 8, step: 0.01),
            .number("seam", "Seam Width", 6, 0, 30, unit: "%"),
            .number("darkness", "Seam Darkness", 78, 0, 100, unit: "%"),
            .number("split", "Split Position", 55, 0, 100, unit: "%"),
            .number("phaseGap", "Right Phase Offset", 24, -100, 100, unit: "%"),
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
            params.c = SIMD4(Float(effectNumber(context, "pull", 18) * context.unit),
                             Float(effectNumber(context, "split", 55) / 100), Float(effectNumber(context, "phaseGap", 24) / 100), 0)
            return renderRemadeEffect("fxSyncRoll", context, params)
        })

    static let lineHold = EffectDefinition(
        id: "awi.lineHold", name: "Line Hold", category: .glitch, aeMatchNames: [],
        summary: "Pull one scanline out into a vertical band. Animate the sampled line and destination separately to make a frozen stripe track across moving footage.",
        params: [
            .number("source", "Source Line", 32, 0, 100, unit: "%"),
            .number("position", "Band Position", 62, 0, 100, unit: "%"),
            .number("height", "Band Height", 16, 1, 100, unit: "%"),
            .number("feather", "Edge Feather", 3, 0, 25, unit: "%"),
            .number("skew", "Horizontal Shear", 16, -200, 200, unit: "px"),
            .number("mix", "Mix", 85, 0, 100, unit: "%")
        ],
        stage: .pixels { context in
            let mix = effectNumber(context, "mix", 85) / 100
            guard mix > 0 else { return context.input }
            var params = EffectParams()
            params.a = layerRect(context)
            params.b = SIMD4(Float(effectNumber(context, "source", 32) / 100), Float(effectNumber(context, "position", 62) / 100),
                             Float(effectNumber(context, "height", 16) / 200), Float(effectNumber(context, "feather", 3) / 100))
            params.c = SIMD4(Float(effectNumber(context, "skew", 16) * context.unit), Float(mix), 0, 0)
            return renderRemadeEffect("fxLineHold", context, params)
        })

    static let inkOverprint = EffectDefinition(
        id: "awi.inkOverprint", name: "Ink Overprint", category: .stylize, aeMatchNames: [],
        summary: "Print shadows and midtones as two separate inks. Shift the second plate to misregister it, or line both plates up for a clean two-ink print.",
        params: [
            .number("threshold", "Shadow Threshold", 35, 1, 95, unit: "%"),
            .number("tone", "Midtone Threshold", 76, 5, 99, unit: "%"),
            .number("pitch", "Screen Spacing", 6, 2, 50, unit: "px"),
            .angle("angle", "Screen Angle", 32),
            .number("offsetX", "Plate Offset X", 2, -60, 60, step: 0.25, unit: "px"),
            .number("offsetY", "Plate Offset Y", 1, -60, 60, step: 0.25, unit: "px"),
            .color("ink", "Shadow Ink", RGBA(0.11, 0.08, 0.19)),
            .color("midtone", "Midtone Ink", RGBA(0.47, 0.18, 0.31)),
            .color("paper", "Paper", RGBA(0.98, 0.92, 0.82)),
            .number("mix", "Mix", 100, 0, 100, unit: "%")
        ],
        stage: .pixels { context in
            let mix = effectNumber(context, "mix", 100) / 100
            guard mix > 0 else { return context.input }
            let offset = Vec2(effectNumber(context, "offsetX", 2), effectNumber(context, "offsetY", 1))
            let angle = effectNumber(context, "angle", 32) * .pi / 180
            var params = EffectParams()
            params.a = SIMD4(Float(effectNumber(context, "threshold", 35) / 100), Float(effectNumber(context, "tone", 76) / 100),
                             Float(effectNumber(context, "pitch", 6) * context.unit), Float(mix))
            params.b = (context.effect.value("ink")?.color(at: context.time) ?? RGBA(0.11, 0.08, 0.19)).simd
            params.c = (context.effect.value("midtone")?.color(at: context.time) ?? RGBA(0.47, 0.18, 0.31)).simd
            params.d = (context.effect.value("paper")?.color(at: context.time) ?? RGBA(0.98, 0.92, 0.82)).simd
            let plate = SIMD4(Float(offset.x * context.unit), Float(offset.y * context.unit), Float(cos(angle)), Float(sin(angle)))
            params.i = SIMD4(plate.x.bitPattern, plate.y.bitPattern, plate.z.bitPattern, plate.w.bitPattern)
            return renderRemadeEffect("fxInkOverprint", context, params)
        })

    static let sortBands = EffectDefinition(
        id: "awi.sortBands", name: "Sort Bands", category: .glitch, aeMatchNames: [],
        summary: "Reorder pixels by brightness inside short horizontal or vertical runs. Dark gaps break each run and stay in place.",
        params: [
            .number("length", "Max Run Length", 20, 4, 32, step: 1, unit: "px"),
            .number("threshold", "Brightness Floor", 22, 0, 100, unit: "%"),
            .choice("axis", "Axis", ["Horizontal", "Vertical"], 0),
            .toggle("reverse", "Brightest First", false),
            .number("mix", "Mix", 100, 0, 100, unit: "%")
        ],
        stage: .pixels { context in
            let mix = effectNumber(context, "mix", 100) / 100
            guard mix > 0 else { return context.input }
            var params = EffectParams()
            let length = effectNumber(context, "length", 20) * context.unit
            params.i.x = UInt32(min(32, max(2, length.rounded())))
            params.i.y = context.effect.choice("axis") == 1 ? 1 : 0
            params.i.z = context.effect.bool("reverse") ? 1 : 0
            params.a = SIMD4(Float(effectNumber(context, "threshold", 22) / 100), Float(mix), 0, 0)
            return renderRemadeEffect("fxSortBands", context, params)
        })

    static let panelFlash = EffectDefinition(
        id: "awi.panelFlash", name: "Panel Flash", category: .stylize, aeMatchNames: [],
        summary: "Punch a graphic flash through a shaped panel. The moving panel maps highlights and shadows to two inks while the rest of the frame stays intact.",
        params: [
            .point("center", "Panel Center", Vec2(0.5, 0.5)),
            .angle("angle", "Angle", -22),
            .number("width", "Panel Width", 56, 1, 160, unit: "%"),
            .number("edge", "Edge Softness", 2, 0, 40, unit: "%"),
            .number("threshold", "Tone Split", 48, 1, 99, unit: "%"),
            .color("dark", "Shadow Color", RGBA(0.93, 0.89, 0.78)),
            .color("light", "Light Color", RGBA(0.07, 0.06, 0.13)),
            .number("mix", "Mix", 100, 0, 100, unit: "%")
        ],
        stage: .pixels { context in
            let mix = effectNumber(context, "mix", 100) / 100
            guard mix > 0 else { return context.input }
            let rect = layerRect(context)
            let center = context.effect.value("center")?.point(at: context.time) ?? Vec2(0.5, 0.5)
            let angle = effectNumber(context, "angle", -22) * .pi / 180
            var params = EffectParams()
            params.a = SIMD4(rect.x + Float(center.x) * rect.z, rect.y + Float(center.y) * rect.w, Float(cos(angle)), Float(sin(angle)))
            params.b = SIMD4(rect.z * Float(effectNumber(context, "width", 56) / 200),
                             rect.z * Float(effectNumber(context, "edge", 2) / 100),
                             Float(effectNumber(context, "threshold", 48) / 100), Float(mix))
            params.c = (context.effect.value("dark")?.color(at: context.time) ?? RGBA(0.93, 0.89, 0.78)).simd
            params.d = (context.effect.value("light")?.color(at: context.time) ?? RGBA(0.07, 0.06, 0.13)).simd
            return renderRemadeEffect("fxPanelFlash", context, params)
        })


    private static func effectNumber(_ context: EffectContext, _ key: String, _ fallback: Double) -> Double {
        context.effect.value(key) == nil ? fallback : context.num(key)
    }

    private static func renderRemadeEffect(_ kernel: String, _ context: EffectContext, _ params: EffectParams) -> MTLTexture {
        let output = context.temp()
        context.gpu.run(kernel, context.cb, textures: [context.input, output], params: params, grid: output)
        return output
    }
}
