import Foundation
import CoreGraphics

extension EffectRegistry {
    private static func textFX(_ id: String, _ name: String, _ summary: String, _ params: [ParamDef]) -> EffectDefinition {
        EffectDefinition(id: "awi24." + id, name: name, category: .text, aeMatchNames: [], summary: summary,
                         params: params, stage: .transform { _, _ in (0, 0, 0, 1) })
    }
    private static let textUnits: ParamDef = .choice("units", "Based On", ["Characters", "Words", "Lines"], 0)
    private static let textRange: [ParamDef] = [.number("start", "Start", 0, 0, 100, unit: "%"), .number("end", "End", 100, 0, 100, unit: "%"), textUnits]
    static let textBatch24: [EffectDefinition] = [
        textFX("textTransform", "Text Transform", "Offset, rotate, scale and fade a selected range of characters, words or lines. Uses the existing text selector engine.", textRange + [
            .number("x", "Position X", 0, -200, 200, unit: "px"), .number("y", "Position Y", 20, -200, 200, unit: "px"),
            .angle("rotation", "Rotation", 0), .number("scale", "Scale", 100, 10, 300, unit: "%"), .number("opacity", "Opacity", 100, 0, 100, unit: "%")]),
        textFX("textProgress", "Text Progress", "Reveal a range without reflowing the remaining text. Animate End from 0 to 100 for typing; preserves glyph clusters.", [
            .number("start", "Start", 0, 0, 100, unit: "%"), .number("end", "End", 60, 0, 100, unit: "%"), textUnits, .toggle("reverse", "Reverse Order", false)]),
        textFX("textWave", "Text Wave", "A travelling sine wave through glyph positions and rotation, evaluated from composition time for repeatable seeking.", [
            .number("x", "Horizontal", 0, 0, 100, unit: "px"), .number("y", "Vertical", 20, 0, 100, unit: "px"),
            .number("rotation", "Rotation", 5, 0, 90, unit: "°"), .number("frequency", "Frequency", 1, 0, 10, step: 0.01),
            .number("wavelength", "Units per Wave", 4, 0.5, 30, step: 0.1), .number("phase", "Phase", 0, 0, 1, step: 0.001), textUnits]),
        textFX("textJitter", "Text Jitter", "Smooth seeded per-unit noise changes letter position and rotation. Stable when seeking or exporting the same frame.", [
            .number("x", "Horizontal", 8, 0, 80, unit: "px"), .number("y", "Vertical", 8, 0, 80, unit: "px"),
            .number("rotation", "Rotation", 5, 0, 45, unit: "°"), .number("frequency", "Frequency", 3, 0.1, 20, step: 0.01),
            .number("seed", "Seed", 1, 0, 10000, step: 1), textUnits]),
        textFX("textArc", "Text Arc", "Bend each line onto a circular arc while preserving its measured advance length. Zero bend restores the original layout.", [
            .number("bend", "Bend Angle", 90, -180, 180, unit: "°"), .toggle("orient", "Orient Letters", true)]),
        textFX("textColorRamp", "Text Color Ramp", "Interpolate color across character, word or line order, with repeat and phase controls. Does not rasterize the text.", [
            .color("from", "First Color", RGBA(0.2, 0.5, 1)), .color("to", "Last Color", RGBA(1, 0.2, 0.5)),
            .number("repeat", "Repeats", 1, 0.25, 5, step: 0.01), .number("phase", "Phase", 0, 0, 1, step: 0.001),
            .number("mix", "Mix", 100, 0, 100, unit: "%"), textUnits]),
        textFX("characterOffset", "Character Offset", "Shift letters through A–Z/a–z and digits through 0–9 in a selected range. Leaves other scripts and emoji intact.", textRange + [
            .number("offset", "Character Offset", 5, -26, 26, step: 1)]),
        textFX("textLineSpacing", "Text Line Spacing", "Multiply the text layer’s existing baseline spacing. Reuses Text Studio layout; affects multiline text.", [
            .number("spacing", "Line Spacing", 140, 25, 300, unit: "%")]),
        textFX("textOutline", "Text Outline", "Animate whole-text hollow glyph outlines using Text Studio’s glyph rasterizer. Width zero returns solid text.", [
            .number("width", "Outline Width", 2, 0, 24, unit: "px")])
    ]
}

/// Catalog controls operate on evaluated glyphs, never append saved animators to the project.
enum TextEffectMath {
    static func number(_ e: EffectInstance, _ key: String, _ time: Double) -> Double {
        let value = e.number(key, time)
        guard let range = EffectRegistry.paramRanges[e.typeID]?[key] else { return value }
        return min(range.upperBound, max(range.lowerBound, value))
    }
    static func apply(_ effects: [EffectInstance], states: inout [Renderer.GlyphState], layout: TextLayout, time: Double) {
        let lineBounds = Dictionary(grouping: layout.glyphs, by: \.lineIndex).mapValues { glyphs -> (Double, Double) in
            let lo = glyphs.map { $0.center.x - $0.halfSize.x }.min() ?? 0
            let hi = glyphs.map { $0.center.x + $0.halfSize.x }.max() ?? 1
            return ((lo + hi) / 2, max(1, hi - lo))
        }
        for effect in effects where effect.isEnabled && effect.typeID.hasPrefix("awi24.") {
            func n(_ key: String) -> Double { number(effect, key, time) }
            for (i, glyph) in layout.glyphs.enumerated() {
                let unit: Int, count: Int
                switch effect.choice("units") {
                case 1: unit = glyph.wordIndex; count = layout.wordCount
                case 2: unit = glyph.lineIndex; count = layout.lineCount
                default: unit = glyph.charIndex; count = layout.charCount
                }
                var selector = TextSelector(); selector.start = Animated(n("start")); selector.end = Animated(n("end"))
                switch effect.typeID {
                case "awi24.textTransform", "awi24.characterOffset":
                    let amount = SelectorMath.amount(selector, index: unit, count: count, time: time)
                    if effect.typeID == "awi24.characterOffset" { states[i].charOffset += n("offset") * amount; continue }
                    states[i].offset = states[i].offset + Vec2(n("x"), n("y")) * amount
                    states[i].rotation += n("rotation") * amount
                    let scale = 1 + (n("scale") / 100 - 1) * amount
                    states[i].scale = states[i].scale * scale
                    states[i].opacity *= 1 + (n("opacity") / 100 - 1) * amount
                case "awi24.textProgress":
                    guard n("start") < n("end") else { states[i].opacity = 0; continue }
                    let index = effect.bool("reverse") ? count - 1 - unit : unit
                    states[i].opacity *= SelectorMath.amount(selector, index: index, count: count, time: time)
                case "awi24.textWave":
                    let wave = sin(2 * Double.pi * (time * n("frequency") - Double(unit) / n("wavelength") + n("phase")))
                    states[i].offset = states[i].offset + Vec2(n("x"), n("y")) * wave
                    states[i].rotation += n("rotation") * wave
                case "awi24.textJitter":
                    func noise(_ channel: Double) -> Double { Wiggle.value(t: time, freq: n("frequency"), octaves: 1, seed: n("seed") + Double(unit) * 17.13 + channel) }
                    states[i].offset = states[i].offset + Vec2(noise(0) * n("x"), noise(71) * n("y"))
                    states[i].rotation += noise(143) * n("rotation")
                case "awi24.textArc":
                    let bend = n("bend") * Double.pi / 180
                    guard abs(bend) > 1e-6, let (center, width) = lineBounds[glyph.lineIndex] else { continue }
                    let x = glyph.center.x - center, theta = x / width * bend, radius = width / bend
                    states[i].offset = states[i].offset + Vec2(radius * sin(theta) - x, radius * (1 - cos(theta)))
                    if effect.bool("orient") { states[i].rotation += theta * 180 / Double.pi }
                case "awi24.textColorRamp":
                    let rank = Double(unit) / Double(max(1, count - 1))
                    let position = rank * n("repeat") + n("phase")
                    let phase = position - floor(position)
                    let weight = (n("repeat") == 1 && n("phase") == 0) ? rank : phase
                    let color = RGBA.lerp(effect.color("from", time), effect.color("to", time), weight)
                    states[i].color = RGBA.lerp(states[i].color, color, n("mix") / 100)
                default: break
                }
            }
        }
    }
}
