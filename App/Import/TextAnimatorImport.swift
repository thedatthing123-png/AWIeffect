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
                    if p.matchName == "ADBE Text Position 3D", v.staticValue.count > 2 || v.keys.contains(where: { $0.value.count > 2 }) {
                        let z: Animated<Double> = AEPImporter.animated(v, fallback: 0.0) { [$0.count > 2 ? $0[2] : 0] }
                        if z.staticValue != 0 || !z.keyframes.isEmpty { a.properties.positionZ = z }
                    }
                case "ADBE Text Anchor Point 3D", "ADBE Text Anchor Point":
                    a.properties.anchor = AEPImporter.animated(v, fallback: Vec2.zero) { Array($0.prefix(2)) }
                case "ADBE Text Scale 3D", "ADBE Text Scale":
                    a.properties.scale = AEPImporter.animated(v, fallback: Vec2(100, 100)) { Array($0.prefix(2)) }
                case "ADBE Text Rotation":
                    a.properties.rotation = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Rotation X":
                    a.properties.rotationX = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Rotation Y":
                    a.properties.rotationY = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Opacity":
                    a.properties.opacity = AEPImporter.animated(v, fallback: 100.0)
                case "ADBE Text Fill Opacity":
                    a.properties.fillOpacity = AEPImporter.animated(v, fallback: 100.0)
                case "ADBE Text Tracking Amount":
                    a.properties.tracking = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Line Spacing":
                    a.properties.lineSpacing = AEPImporter.animated(v, fallback: 0.0) { [$0.count > 1 ? $0[1] : ($0.first ?? 0)] }
                case "ADBE Text Skew":
                    a.properties.skew = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Blur":
                    a.properties.blur = AEPImporter.animated(v, fallback: 0.0) { [($0.first ?? 0)] }
                case "ADBE Text Character Offset":
                    a.properties.characterOffset = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Fill Color":
                    a.properties.fill = AEPImporter.animated(v, fallback: RGBA.white)
                case "ADBE Text Fill Hue":
                    a.properties.hueShift = AEPImporter.animated(v, fallback: 0.0)
                case "ADBE Text Stroke Color":
                    a.properties.strokeColor = AEPImporter.animated(v, fallback: RGBA.black)
                case "ADBE Text Stroke Width":
                    a.properties.strokeWidth = AEPImporter.animated(v, fallback: 0.0)
                default: break
                }
            }
        }
        let used = a.properties
        guard used.position != nil || used.scale != nil || used.rotation != nil || used.opacity != nil
                || used.tracking != nil || used.skew != nil || used.fill != nil || used.blur != nil || used.characterOffset != nil
                || used.positionZ != nil || used.rotationX != nil || used.rotationY != nil || used.anchor != nil
                || used.fillOpacity != nil || used.lineSpacing != nil || used.hueShift != nil || used.strokeColor != nil
                || used.strokeWidth != nil else { return nil }

        // Every selector, in AE order (each combines with the ones above by its Mode).
        var found: [AEProp] = []
        func collect(_ p: AEProp) {
            if p.matchName == "ADBE Text Selector" || p.matchName == "ADBE Text Wiggly Selector" { found.append(p); return }
            if p.matchName == "ADBE Text Animator Properties" { return }
            for c in p.children { collect(c) }
        }
        for c in g.children { collect(c) }
        let selectors = found.map { selector($0, tb, s) }
        if !selectors.isEmpty { a.allSelectors = selectors }
        return a
    }

    private static func selector(_ sel: AEProp, _ tb: Double, _ s: Double) -> TextSelector {
        var t = TextSelector()
        if let v = value(deep(sel, "ADBE Text Selector Mode"), tb, s), let k = v.staticValue.first {
            t.mode = [SelectorMode.add, .add, .subtract, .intersect, .min, .max, .difference][max(0, min(6, Int(k)))]
        }
        if sel.matchName == "ADBE Text Wiggly Selector" {
            t.kind = .wiggly
            if let v = value(deep(sel, "ADBE Text Wiggly Max Amount"), tb, s) {
                t.maxAmountAnim = AEPImporter.animated(v, fallback: 100.0)
                t.maxAmount = t.maxAmountAnim?.staticValue ?? 100
            }
            if let v = value(deep(sel, "ADBE Text Wiggly Min Amount"), tb, s) {
                t.minAmountAnim = AEPImporter.animated(v, fallback: -100.0)
                t.minAmount = t.minAmountAnim?.staticValue ?? -100
            }
            if let v = value(deep(sel, "ADBE Text Temporal Freq"), tb, s) { t.frequency = AEPImporter.animated(v, fallback: 2.0) }
            if let v = value(deep(sel, "ADBE Text Random Seed"), tb, s), let k = v.staticValue.first { t.seed = Int(k) }
            if let v = value(deep(sel, "ADBE Text Range Type2"), tb, s), let k = v.staticValue.first {
                t.basedOn = [.characters, .charactersExcludingSpaces, .words, .lines][max(0, min(3, Int(k) - 1))]
            }
            return t
        }
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
        if let v = value(deep(sel, "ADBE Text Levels Max Ease"), tb, s) {
            t.easeHighAnim = AEPImporter.animated(v, fallback: 0.0)
            t.easeHigh = t.easeHighAnim?.staticValue ?? 0
        }
        if let v = value(deep(sel, "ADBE Text Levels Min Ease"), tb, s) {
            t.easeLowAnim = AEPImporter.animated(v, fallback: 0.0)
            t.easeLow = t.easeLowAnim?.staticValue ?? 0
        }
        if let v = value(deep(sel, "ADBE Text Randomize Order"), tb, s), let k = v.staticValue.first { t.randomize = k > 0.5 }
        if let v = value(deep(sel, "ADBE Text Random Seed"), tb, s), let k = v.staticValue.first { t.seed = Int(k) }
        return t
    }
}
