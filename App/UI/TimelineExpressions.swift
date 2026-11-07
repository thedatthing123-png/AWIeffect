import Foundation

/// A property another expression can reference (pick-whip target).
struct ExpressionRefProperty: Identifiable {
    let id: String
    let title: String
    /// Path after `thisComp.layer("Name").`
    let path: String
}

extension ExpressionResolver {
    static let referenceProperties: [ExpressionRefProperty] = [
        .init(id: "position", title: "Position", path: "transform.position"),
        .init(id: "scale", title: "Scale", path: "transform.scale"),
        .init(id: "rotation", title: "Rotation", path: "transform.rotation"),
        .init(id: "opacity", title: "Opacity", path: "transform.opacity"),
        .init(id: "anchor", title: "Anchor Point", path: "transform.anchorPoint"),
        .init(id: "positionZ", title: "Position Z", path: "transform.zPosition"),
        .init(id: "rotationX", title: "Rotation X", path: "transform.xRotation"),
        .init(id: "rotationY", title: "Rotation Y", path: "transform.yRotation"),
    ]

    /// Every layer's (pre-expression) values at `time`, by name and by index, for `thisComp.layer(...)`.
    static func layerReferences(_ project: Project, time: Double) -> (byName: [String: Any], byIndex: [Any]) {
        var byName: [String: Any] = [:]
        var byIndex: [Any] = []
        for (i, l) in project.layers.enumerated() {
            let t = l.transform
            let p = t.position.value(at: time), s = t.scale.value(at: time), a = t.anchor.value(at: time)
            let transform: [String: Any] = [
                "position": [p.x, p.y], "scale": [s.x, s.y], "rotation": t.rotation.value(at: time),
                "opacity": t.opacity.value(at: time), "anchorPoint": [a.x, a.y],
                "zPosition": t.positionZ.value(at: time), "xRotation": t.rotationX.value(at: time),
                "yRotation": t.rotationY.value(at: time),
            ]
            var entry = transform
            entry["transform"] = transform
            entry["name"] = l.name
            entry["index"] = i + 1
            entry["inPoint"] = l.inPoint
            entry["outPoint"] = l.outPoint
            byIndex.append(entry)
            if byName[l.name] == nil { byName[l.name] = entry }
        }
        return (byName, byIndex)
    }
}

extension EditorState {
    /// AE-style reference to another layer's property (what the pick-whip inserts).
    static func expressionReference(layerName: String, property: ExpressionRefProperty) -> String {
        let escaped = layerName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "thisComp.layer(\"\(escaped)\").\(property.path)"
    }

    /// Runs `code` on the selected layer's property at the playhead without applying it. nil = it works.
    func validateExpression(_ key: PropertyKey, code: String) -> String? {
        guard let i = selectedIndex else { return nil }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let l = project.layers[i]
        let refs = ExpressionResolver.layerReferences(project, time: currentTime)
        let scope = ExpressionScope(time: currentTime, fps: project.fps, compWidth: project.width, compHeight: project.height,
                                    compDuration: project.duration, layerIndex: i + 1, layerName: l.name,
                                    inPoint: l.inPoint, outPoint: l.outPoint, seed: 1, layerCount: project.layers.count,
                                    layerRefs: refs.byName, layerRefsByIndex: refs.byIndex)
        let engine = ExpressionEngine.shared
        let probe = "__live/\(l.id)/\(key.rawValue)"
        func run<V: ExpressionValue>(_ a: Animated<V>) -> String? {
            var copy = a
            copy.expression = code
            return engine.evaluate(copy, scope: scope, key: probe) == nil ? (engine.error(for: probe) ?? "Expression error") : nil
        }
        switch key {
        case .position: return run(l.transform.position)
        case .scale: return run(l.transform.scale)
        case .rotation: return run(l.transform.rotation)
        case .opacity: return run(l.transform.opacity)
        case .anchor: return run(l.transform.anchor)
        case .size: return run(l.size)
        case .fill: return run(l.fill)
        case .cornerRadius: return run(l.cornerRadius)
        case .positionZ: return run(l.transform.positionZ)
        case .rotationX: return run(l.transform.rotationX)
        case .rotationY: return run(l.transform.rotationY)
        }
    }

    /// Every property in this comp that has an expression (layer + property).
    func expressionInventory() -> [(layerID: UUID, layerName: String, key: PropertyKey, enabled: Bool)] {
        var out: [(layerID: UUID, layerName: String, key: PropertyKey, enabled: Bool)] = []
        for l in project.layers {
            let t = l.transform
            let pairs: [(PropertyKey, String?, Bool)] = [
                (.position, t.position.expression, t.position.expressionEnabled),
                (.scale, t.scale.expression, t.scale.expressionEnabled),
                (.rotation, t.rotation.expression, t.rotation.expressionEnabled),
                (.opacity, t.opacity.expression, t.opacity.expressionEnabled),
                (.anchor, t.anchor.expression, t.anchor.expressionEnabled),
                (.size, l.size.expression, l.size.expressionEnabled),
                (.fill, l.fill.expression, l.fill.expressionEnabled),
                (.cornerRadius, l.cornerRadius.expression, l.cornerRadius.expressionEnabled),
                (.positionZ, t.positionZ.expression, t.positionZ.expressionEnabled),
                (.rotationX, t.rotationX.expression, t.rotationX.expressionEnabled),
                (.rotationY, t.rotationY.expression, t.rotationY.expressionEnabled),
            ]
            for (key, code, enabled) in pairs where !(code ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                out.append((l.id, l.name, key, enabled))
            }
        }
        return out
    }
}
