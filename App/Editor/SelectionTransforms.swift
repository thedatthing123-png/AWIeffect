import Foundation
import simd

extension EditorState {
    /// Apply one scale/rotation gesture to selected roots in composition space.
    /// Selected descendants inherit their ancestor once, rather than being transformed twice.
    func propagateSelectionTransform(before: Project, into after: inout Project, primary: UUID) {
        guard let ids = multiSelection, ids.count > 1,
              let original = before.layers.first(where: { $0.id == primary }),
              let index = after.layers.firstIndex(where: { $0.id == primary }) else { return }
        let time = currentTime, changed = after.layers[index]
        let oldScale = original.transform.scale.value(at: time), newScale = changed.transform.scale.value(at: time)
        let rotation = changed.transform.rotation.value(at: time) - original.transform.rotation.value(at: time)
        guard oldScale != newScale || abs(rotation) > 1e-9 else { return }
        let sx = abs(oldScale.x) > 1e-9 ? newScale.x / oldScale.x : 1
        let sy = abs(oldScale.y) > 1e-9 ? newScale.y / oldScale.y : 1
        guard sx.isFinite, sy.isFinite, rotation.isFinite else { return }
        func hasSelectedAncestor(_ layer: Layer) -> Bool {
            var pending = [layer.parentID, layer.groupID].compactMap { $0 }, visited = Set<UUID>()
            while let id = pending.popLast() {
                guard visited.insert(id).inserted else { continue }
                if ids.contains(id) { return true }
                if let parent = before.layers.first(where: { $0.id == id }) {
                    pending += [parent.parentID, parent.groupID].compactMap { $0 }
                }
            }
            return false
        }
        let roots = before.layers.filter { ids.contains($0.id) && !$0.isLocked && !hasSelectedAncestor($0) }
        let primaryMatrix = LayerPlacement.positionMatrix(original, project: before, time: time)
        guard let pivot = LayerPlacement.projected(original.transform.position.value(at: time), by: primaryMatrix) else { return }
        if hasSelectedAncestor(original) { after.layers[index].transform = original.transform }
        let angle = rotation * .pi / 180
        for layer in roots where layer.id != primary {
            guard let i = after.layers.firstIndex(where: { $0.id == layer.id }) else { continue }
            let matrix = LayerPlacement.positionMatrix(layer, project: before, time: time)
            guard abs(matrix.determinant) > 1e-10,
                  let screen = LayerPlacement.projected(layer.transform.position.value(at: time), by: matrix) else { continue }
            let delta = screen - pivot
            let x = delta.x * sx, y = delta.y * sy
            let target = pivot + Vec2(x * cos(angle) - y * sin(angle), x * sin(angle) + y * cos(angle))
            guard let position = LayerPlacement.projected(target, by: matrix.inverse) else { continue }
            let scale = layer.transform.scale.value(at: time)
            after.layers[i].transform.position.set(position, at: time)
            after.layers[i].transform.scale.set(Vec2(scale.x * sx, scale.y * sy), at: time)
            after.layers[i].transform.rotation.set(layer.transform.rotation.value(at: time) + rotation, at: time)
        }
    }
}

extension LayerTransform {
    /// Keep the saved XY/Z channels compatible while exposing one position-keyframe group.
    mutating func pairPositionKeys(previous: LayerTransform, at time: Double) {
        guard position.isAnimated || positionZ.isAnimated else { return }
        let times = Set(position.keyframeTimes + positionZ.keyframeTimes + [time]).sorted()
        for t in times {
            if !position.hasKeyframe(at: t) {
                position.insertKeyframe(Keyframe(time: t, value: abs(t - time) < 1e-6 ? position.value(at: t) : previous.position.value(at: t), interpolation: .linear))
            }
            if !positionZ.hasKeyframe(at: t) {
                positionZ.insertKeyframe(Keyframe(time: t, value: abs(t - time) < 1e-6 ? positionZ.value(at: t) : previous.positionZ.value(at: t), interpolation: .linear))
            }
        }
    }
}
