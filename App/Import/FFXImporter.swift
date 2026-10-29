import Foundation

/// Imports After Effects animation presets (.ffx). Presets are RIFX files holding property groups;
/// every effect inside whose match name AWIeffect knows is rebuilt with its saved settings and keyframes.
enum FFXImporter {
    struct Result {
        var effects: [EffectInstance]
        var report: ImportReport
    }

    static func load(url: URL, layerSize: Vec2) throws -> Result {
        try importData(Data(contentsOf: url), name: url.deletingPathExtension().lastPathComponent, layerSize: layerSize)
    }

    static func importData(_ data: Data, name: String, layerSize: Vec2) throws -> Result {
        let root = try RIFXParser.parse(data, form: nil)
        var report = ImportReport()
        report.compName = name
        var effects: [EffectInstance] = []
        // Presets store values with keyframe times relative to the layer; 24576 units/s is AE's 24 fps default timebase.
        func visit(_ chunk: RIFXChunk) {
            if chunk.key == "tdgp" {
                for prop in AEPImporter.walkGroup(chunk) { collect(prop) }
                return
            }
            for c in chunk.children { visit(c) }
        }
        func collect(_ prop: AEProp) {
            if prop.matchName == "ADBE Effect Parade" {
                for e in prop.children { addEffect(e) }
                return
            }
            if EffectRegistry.definition(aeMatchName: prop.matchName) != nil, !prop.children.isEmpty {
                addEffect(prop)
                return
            }
            for c in prop.children { collect(c) }
        }
        func addEffect(_ e: AEProp) {
            report.effectUsage[e.matchName, default: 0] += 1
            guard let def = EffectRegistry.definition(aeMatchName: e.matchName) else {
                report.add(name, e.matchName, .missing, "Not built yet.")
                return
            }
            effects.append(AEPImporter.effectInstance(def, from: e, timebase: 24576, layerStart: 0))
            report.add(name, def.name, def.id.hasPrefix("awi.") ? .approximate : .native, e.matchName)
        }
        visit(root)
        return Result(effects: effects, report: report)
    }
}
