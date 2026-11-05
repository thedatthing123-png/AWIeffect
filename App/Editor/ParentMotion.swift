import Foundation

extension Renderer {
    static func parentChainMoves(_ layer: Layer, in project: Project) -> Bool {
        var parent = layer.parentID, visited = Set<UUID>()
        while let id = parent, visited.insert(id).inserted,
              let next = (project.layers + (project.parentContext ?? [])).first(where: { $0.id == id }) {
            let t = next.transform
            if t.position.isAnimated || t.positionZ.isAnimated || t.rotation.isAnimated || t.scale.isAnimated || t.anchor.isAnimated
                || t.position.hasActiveExpression || t.positionZ.hasActiveExpression || t.rotation.hasActiveExpression || t.scale.hasActiveExpression
                || next.effects.contains(where: { $0.isEnabled && (EffectRegistry.definition($0.typeID)?.isTransformEffect ?? false) }) { return true }
            parent = next.parentID
        }
        return false
    }

    /// Detaching an animated carrier must retain inherited motion, even if the child has no keys.
    /// Samples every composition frame (bounded to 36k samples for unusually long layers), plus authored key times.
    static func detachedMotion(_ layer: Layer, in project: Project) -> Layer {
        var result = layer
        let start = max(0, layer.inPoint), end = max(start, layer.outPoint)
        let count = min(36000, max(1, Int(ceil(min(36000, (end - start) * max(1, project.fps))))))
        var times = Set((0...count).map { start + (end - start) * Double($0) / Double(count) })
        times.formUnion(layer.keyframeTimes.filter { $0 >= start && $0 <= end })
        var position = Animated(layer.transform.position.value(at: start))
        var rotation = Animated(layer.transform.rotation.value(at: start))
        var scale = Animated(layer.transform.scale.value(at: start))
        var depth = Animated(layer.transform.positionZ.value(at: start))
        for time in times.sorted() {
            guard let transform = resolveParenting(ExpressionResolver.resolve(project, time: time), time: time).layers.first(where: { $0.id == layer.id })?.transform else { continue }
            position.insertKeyframe(Keyframe(time: time, value: transform.position.value(at: time)))
            rotation.insertKeyframe(Keyframe(time: time, value: transform.rotation.value(at: time)))
            scale.insertKeyframe(Keyframe(time: time, value: transform.scale.value(at: time)))
            depth.insertKeyframe(Keyframe(time: time, value: transform.positionZ.value(at: time)))
        }
        result.transform.position = position; result.transform.rotation = rotation
        result.transform.scale = scale; result.transform.positionZ = depth
        result.parentID = nil
        return result
    }
}
