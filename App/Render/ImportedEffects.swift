import Foundation

/// Project files carry effect IDs and settings. Look up their installed
/// implementations within the source format, independently of browser names.
enum ImportedEffectRenderers {
    static let xmlFragments: [String: ReferenceFragmentDefinition] = Dictionary(
        uniqueKeysWithValues: ReferenceFragmentCatalog.all
            .filter { reference in
                !reference.sourceID.isEmpty &&
                !reference.sourceID.hasPrefix("com.alightcreative.internal.") &&
                !reference.sourceID.hasPrefix("com.alightcreative.blend.") &&
                reference.referenceBinding == nil
            }
            .map { ($0.sourceID, $0) }
    )

    static let importOnlyDefinitions: [EffectDefinition] = {
        let browserIDs = Set(ReferenceFragmentCatalog.promoted.map(\.id))
        return xmlFragments.values.filter { !browserIDs.contains($0.id) }.map(\.definition)
    }()

    static let importOnlyByID = Dictionary(uniqueKeysWithValues: importOnlyDefinitions.map { ($0.id, $0) })

    private static let alightMotionPrefix = "source.am.v1."
    private static let alightMotionAdapterPrefix = "source.am-adapter.v1."

    static func alightMotionTypeID(_ sourceID: String, adapterID: String? = nil) -> String {
        if let adapterID { return alightMotionAdapterPrefix + adapterID + "|" + sourceID }
        return alightMotionPrefix + sourceID
    }

    static func alightMotionRendererID(forTypeID id: String) -> String? {
        if id.hasPrefix(alightMotionPrefix) {
            let sourceID = String(id.dropFirst(alightMotionPrefix.count))
            if sourceID == "com.alightcreative.effects.oscillate3" { return EffectRegistry.importedOscillate.id }
            return xmlFragments[sourceID]?.id
        }
        guard id.hasPrefix(alightMotionAdapterPrefix),
              let separator = id.firstIndex(of: "|") else { return nil }
        return String(id[id.index(id.startIndex, offsetBy: alightMotionAdapterPrefix.count)..<separator])
    }

    private static let afterEffectsPrefix = "source.ae.v1."

    static func afterEffectsTypeID(_ matchName: String) -> String {
        afterEffectsPrefix + matchName
    }

    static func adapter(forTypeID id: String) -> EffectDefinition? {
        guard id.hasPrefix(afterEffectsPrefix) else { return nil }
        return afterEffects(String(id.dropFirst(afterEffectsPrefix.count)))
    }

    static func afterEffects(_ matchName: String) -> EffectDefinition? {
        // Match-name aliases that were added for FFX compatibility do not
        // establish renderer compatibility for a third-party desktop plugin.
        guard matchName.hasPrefix("ADBE ") || matchName.hasPrefix("CC ") else { return nil }
        return EffectRegistry.definition(aeMatchName: matchName)
    }
}

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
