import Foundation

/// Converts After Effects text animators (from .ffx presets and .aep text layers) into AWIeffect animators,
/// so downloaded AE text presets play here as real per-character animation.
enum TextAnimatorImport {
    /// Finds every "ADBE Text Animator" under `props` and converts it.
    static func animators(in props: [AEProp], timebase: Double, layerStart: Double) -> [TextAnimator] {
        var out: [TextAnimator] = []
        func walk(_ ps: [AEProp]) {
            for p in ps {
                if p.matchName == "ADBE Text Animator" { if let a = animator(p, timebase: timebase, layerStart: layerStart) { out.append(a) } }
                else { walk(p.children) }
            }
        }
        walk(props)
        return out
    }

    private static func value(_ p: AEProp?, _ tb: Double, _ start: Double) -> AEValue? {
        if case .value(let c)? = p?.kind { return AEPImporter.readValue(c, timebase: tb, layerStart: start) }
        return nil
    }

    /// First match anywhere under a group.
    private static func deep(_ p: AEProp, _ name: String) -> AEProp? {
        if p.matchName == name { return p }
        for c in p.children { if let f = deep(c, name) { return f } }
        return nil
    }

    static func animator(_ g: AEProp, timebase tb: Double, layerStart s: Double) -> TextAnimator? {
        var a = TextAnimator(name: "AE Animator")
        // Properties.
        if let props = deep(g, "ADBE Text Animator Properties") {
            for p in props.children {
                guard let v = value(p, tb, s) else { continue }
                switch p.matchName {
                case "ADBE Text Position 3D", "ADBE Text Position":
                    a.properties.position = AEPImporter.animated(v, fallback: Vec2.zero) { Array($0.prefix(2)) }
                case "ADBE Text Scale 3D", "ADBE Text Scale":
                    a.properties.scale = AEPImporter.animated(v, fallback: Vec2(100, 100)) { Array($0.prefix(2)) }
                case "ADBE Text Rotation":
                    a.properties.rotation = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Opacity":
                    a.properties.opacity = AEPImporter.animated(v, fallback: 100.0)
                case "ADBE Text Tracking Amount":
                    a.properties.tracking = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Skew":
                    a.properties.skew = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Fill Color":
                    a.properties.fill = AEPImporter.animated(v, fallback: RGBA.white)
                default: break
                }
            }
        }
        let used = a.properties
        guard used.position != nil || used.scale != nil || used.rotation != nil || used.opacity != nil
                || used.tracking != nil || used.skew != nil || used.fill != nil else { return nil }

        // Selector (first one; AE stacks several, the first usually drives the animation).
        if let sel = deep(g, "ADBE Text Selector") {
            var t = TextSelector()
            if let v = value(deep(sel, "ADBE Text Percent Start"), tb, s) { t.start = AEPImporter.animated(v, fallback: 0.0) }
            if let v = value(deep(sel, "ADBE Text Percent End"), tb, s) { t.end = AEPImporter.animated(v, fallback: 100.0) }
            if let v = value(deep(sel, "ADBE Text Percent Offset"), tb, s) { t.offset = AEPImporter.animated(v, fallback: 0.0) }
            if let v = value(deep(sel, "ADBE Text Selector Max Amount"), tb, s) { t.amount = AEPImporter.animated(v, fallback: 100.0) }
            if let v = value(deep(sel, "ADBE Text Range Shape"), tb, s), let k = v.staticValue.first {
                t.shape = [.square, .rampUp, .rampDown, .triangle, .round, .smooth][max(0, min(5, Int(k) - 1))]
            }
            if let v = value(deep(sel, "ADBE Text Range Type2"), tb, s), let k = v.staticValue.first {
                t.basedOn = [.characters, .charactersExcludingSpaces, .words, .lines][max(0, min(3, Int(k) - 1))]
            }
            if let v = value(deep(sel, "ADBE Text Levels Max Ease"), tb, s), let k = v.staticValue.first { t.easeHigh = k }
            if let v = value(deep(sel, "ADBE Text Levels Min Ease"), tb, s), let k = v.staticValue.first { t.easeLow = k }
            if let v = value(deep(sel, "ADBE Text Randomize Order"), tb, s), let k = v.staticValue.first { t.randomize = k > 0.5 }
            if let v = value(deep(sel, "ADBE Text Random Seed"), tb, s), let k = v.staticValue.first { t.seed = Int(k) }
            a.selector = t
        } else if let w = deep(g, "ADBE Text Wiggly Selector") {
            var t = TextSelector()
            t.kind = .wiggly
            if let v = value(deep(w, "ADBE Text Wiggly Max Amount"), tb, s), let k = v.staticValue.first { t.maxAmount = k }
            if let v = value(deep(w, "ADBE Text Wiggly Min Amount"), tb, s), let k = v.staticValue.first { t.minAmount = k }
            if let v = value(deep(w, "ADBE Text Temporal Freq"), tb, s) { t.frequency = AEPImporter.animated(v, fallback: 2.0) }
            a.selector = t
        }
        return a
    }
}
