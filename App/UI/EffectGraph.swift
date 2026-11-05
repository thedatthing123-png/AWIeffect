import SwiftUI

/// A keyframed effect setting the Graph can shape (effect id + setting id).
struct GraphEffectTarget: Equatable, Hashable {
    let effect: UUID
    let key: String
}

extension EditorState {
    /// Every effect setting on the selected layer with at least two keyframes.
    var effectGraphTargets: [(target: GraphEffectTarget, title: String)] {
        guard let l = selectedLayer else { return [] }
        var out: [(GraphEffectTarget, String)] = []
        for e in l.effects {
            guard let d = EffectRegistry.definition(e.typeID) else { continue }
            for pd in d.params where Self.keyCount(e.params[pd.id]) >= 2 {
                out.append((GraphEffectTarget(effect: e.id, key: pd.id), "\(d.name) · \(pd.name)"))
            }
            if e.typeID == EffectRegistry.puppet18.id {
                for key in e.params.keys.filter({ $0.hasPrefix("pinD") && Self.keyCount(e.params[$0]) >= 2 }).sorted(by: { (Int($0.dropFirst(4)) ?? 0) < (Int($1.dropFirst(4)) ?? 0) }) {
                    out.append((GraphEffectTarget(effect: e.id, key: key), "Puppet · Pin \((Int(key.dropFirst(4)) ?? 0) + 1)"))
                }
            }
        }
        return out
    }

    private static func keyCount(_ v: ParamValue?) -> Int {
        switch v {
        case .number(let a)?: return a.keyframes.count
        case .point(let a)?: return a.keyframes.count
        case .color(let a)?: return a.keyframes.count
        default: return 0
        }
    }

    func effectSegments(_ g: GraphEffectTarget) -> [EaseSegment] {
        guard let e = selectedLayer?.effects.first(where: { $0.id == g.effect }) else { return [] }
        func segs<V>(_ a: Animated<V>) -> [EaseSegment] {
            guard a.keyframes.count >= 2 else { return [] }
            return (0..<(a.keyframes.count - 1)).map { k in
                EaseSegment(t0: a.keyframes[k].time, t1: a.keyframes[k + 1].time, interpolation: a.keyframes[k].interpolation,
                            out: a.keyframes[k].easeOut, into: a.keyframes[k + 1].easeIn, curve: a.keyframes[k].curve, reversedSegment: a.keyframes[k].reversedSegment)
            }
        }
        switch e.params[g.key] {
        case .number(let a)?: return segs(a)
        case .point(let a)?: return segs(a)
        case .color(let a)?: return segs(a)
        default: return []
        }
    }

    func setEffectEase(_ g: GraphEffectTarget, segment: Int?, interpolation: Interpolation, out: EaseHandle, into: EaseHandle,
                       curve: EaseCurve?, reversedSegment: Bool? = nil, continuous: Bool = false) {
        guard let i = selectedIndex else { return }
        func apply<V>(_ a: inout Animated<V>) {
            let n = a.keyframes.count
            guard n >= 2 else { return }
            for k in segment.map({ [$0] }) ?? Array(0..<(n - 1)) where k >= 0 && k + 1 < n {
                a.keyframes[k].interpolation = interpolation
                a.keyframes[k].easeOut = out
                a.keyframes[k + 1].easeIn = into
                a.keyframes[k].curve = curve
                a.keyframes[k].reversedSegment = reversedSegment
            }
        }
        if continuous { beginEdit("Edit Easing") }
        mutate("Easing") { p in
            guard let j = p.layers[i].effects.firstIndex(where: { $0.id == g.effect }) else { return }
            switch p.layers[i].effects[j].params[g.key] {
            case .number(var a)?: apply(&a); p.layers[i].effects[j].params[g.key] = .number(a)
            case .point(var a)?: apply(&a); p.layers[i].effects[j].params[g.key] = .point(a)
            case .color(var a)?: apply(&a); p.layers[i].effects[j].params[g.key] = .color(a)
            default: break
            }
        }
    }
}
