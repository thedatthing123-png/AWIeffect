import Foundation

extension EditorState {
    /// Bring editable members back to this timeline, retaining the container as a
    /// group so its transform, opacity, masks and effects are not silently discarded.
    func unpackSelectedPrecomp() {
        guard let layer = selectedLayer, case .precomp(let id) = layer.content,
              let comp = rootProject.precomps.first(where: { $0.id == id }) else { return }
        guard abs(layer.speed - 1) < 1e-8, layer.timeRemap == nil else {
            recoveryNotice = "Restore the precomp to normal speed and disable Time Remap before unpacking. Its editable layers will then retain their timing."
            return
        }
        let offset = layer.inPoint - layer.sourceStart
        let remap = Dictionary(uniqueKeysWithValues: comp.layers.map { ($0.id, UUID()) })
        let members = comp.layers.compactMap { original -> Layer? in
            var member = original
            let start = max(layer.inPoint, original.inPoint + offset)
            let end = min(layer.outPoint, original.outPoint + offset)
            guard end > start else { return nil }
            member.id = remap[original.id]!
            var shift = AnimationTraversal(operation: .shift(offset)); member.traverseAnimations(&shift)
            member.sourceStart += (start - original.inPoint - offset) * member.speed
            member.inPoint = start; member.outPoint = end
            member.parentID = original.parentID.flatMap { remap[$0] }
            member.groupID = original.groupID.flatMap { remap[$0] } ?? layer.id
            for index in member.effects.indices {
                member.effects[index].id = UUID()
                if let old = member.effects[index].text?["layer"].flatMap(UUID.init(uuidString:)), let new = remap[old] {
                    member.effects[index].text?["layer"] = new.uuidString
                }
            }
            return member
        }
        guard !members.isEmpty else { recoveryNotice = "This part of the precomp has no active layers to unpack."; return }
        mutate("Un-precompose") { project in
            guard let index = project.layers.firstIndex(where: { $0.id == layer.id }) else { return }
            var container = layer
            container.content = .solid; container.isGroup = true
            container.groupCanvasSize = Vec2(Double(comp.width), Double(comp.height))
            container.name = comp.name + " (Unpacked)"
            container.fill = Animated(RGBA(0, 0, 0, 0))
            container.sourceStart = 0; container.timeRemap = nil
            project.layers[index] = container
            project.layers.insert(contentsOf: members, at: index + 1)
        }
        panel = .layerHome
    }
}
