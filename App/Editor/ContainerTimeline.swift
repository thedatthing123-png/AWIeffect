import Foundation

extension Layer {
    var isContainer: Bool {
        if isGroup { return true }
        if case .precomp = content { return true }
        return false
    }
}

extension Project {
    /// Older builds assigned every container teal. Repair collisions without touching artwork colors.
    mutating func distinguishContainerTags() {
        var used = Set<LayerTag>()
        let palette: [LayerTag] = [.teal, .pink, .amber, .blue, .green, .purple]
        for index in layers.indices where layers[index].isContainer {
            if used.contains(layers[index].tag), let tag = palette.first(where: { !used.contains($0) }) {
                layers[index].tag = tag
            }
            used.insert(layers[index].tag)
        }
    }
    /// A group is one row. Its children become rows when that group is opened.
    var timelineLayers: [Layer] {
        let containers = Set(layers.filter(\.isGroup).map(\.id))
        return layers.filter { !($0.groupID.map(containers.contains) ?? false) }
    }

    /// Choose a different tag for each new container, preferring unused colors first.
    func nextContainerTag() -> LayerTag {
        let palette: [LayerTag] = [.teal, .pink, .amber, .blue, .green, .purple]
        let containers = layers.filter(\.isContainer)
        let counts = Dictionary(grouping: containers, by: \.tag).mapValues(\.count)
        let previous = containers.first?.tag
        return palette.enumerated().min { a, b in
            let ac = counts[a.element] ?? 0, bc = counts[b.element] ?? 0
            if ac != bc { return ac < bc }
            if (a.element == previous) != (b.element == previous) { return a.element != previous }
            return a.offset < b.offset
        }?.element ?? .teal
    }
}

extension EditorState {
    func expandedLayerIDs(_ ids: Set<UUID>) -> Set<UUID> {
        var result = ids
        for layer in project.layers where ids.contains(layer.id) && layer.isGroup {
            result.formUnion(Self.descendantIDs(of: layer.id, in: project))
        }
        return result
    }

    /// Reorder visible rows atomically, carrying a group's entire subtree with it.
    func reorderTimelineLayer(_ id: UUID, to row: Int) {
        let rows = project.timelineLayers
        guard let from = rows.firstIndex(where: { $0.id == id }), !rows.isEmpty else { return }
        let target = max(0, min(rows.count - 1, row))
        guard target != from else { return }
        let ids = expandedLayerIDs([id]), targetID = rows[target].id
        mutate("Reorder Layer") { p in
            let block = p.layers.filter { ids.contains($0.id) }
            p.layers.removeAll { ids.contains($0.id) }
            guard let at = p.layers.firstIndex(where: { $0.id == targetID }) else { return }
            let endIDs = rows[target].isGroup ? Self.descendantIDs(of: targetID, in: p).union([targetID]) : [targetID]
            let end = (p.layers.lastIndex(where: { endIDs.contains($0.id) }) ?? at) + 1
            p.layers.insert(contentsOf: block, at: target > from ? end : at)
        }
    }
}
