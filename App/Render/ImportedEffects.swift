import Foundation

extension EffectRegistry {
    /// Documented Alight Motion Oscillate (v3). The layer clock starts at the
    /// source in-point and advances through the integrated frequency track.
    static let importedOscillate = EffectDefinition(
        id: "source.am.oscillate.v1", name: "Oscillate", category: .motion, aeMatchNames: [],
        summary: "Alight Motion oscillation with cumulative frequency and its own source clock.",
        params: [
            .angle("direction", "Angle", 45),
            .number("frequency", "Frequency", 2, 0, 16, unit: " Hz"),
            .number("distance", "Magnitude", 25, 0, 4000, unit: " px"),
            .choice("wave", "Wave", ["Sine", "Triangle"], 0),
            .number("phase", "Phase", 0, 0, 1000)
        ],
        stage: .transform { effect, time in
            let origin = effect.imported?.phaseOrigin ?? 0
            let speed = effect.imported?.rateScale ?? 1
            let cycles = EffectRate.phase(effect, key: "frequency", time: time, range: 0...16, fallback: 2, origin: origin)
                * speed + effect.number("phase", time)
            let fraction = cycles - cycles.rounded(.down)
            let wave = effect.choice("wave") == 1
                ? 1 - 4 * abs((fraction + 0.25 - (fraction + 0.25).rounded(.down)) - 0.5)
                : sin(fraction * 2 * .pi)
            let angle = effect.number("direction", time) * .pi / 180
            let distance = max(0, min(4000, effect.number("distance", time))) * wave
            return (distance * cos(angle), distance * sin(angle), 0, 1)
        })
}
