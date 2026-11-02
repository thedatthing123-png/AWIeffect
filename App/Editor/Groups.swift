import SwiftUI

/// Alight Motion-style groups: parts stay normal layers in the same timeline (indented under the group), and
/// the group's transform, masks, effects, blend mode and matte apply to all of them together.
extension EditorState {
    /// Groups the multi-selection (or the selected layer). Parts move right under the new group, in order.
    func groupSelected() {
        let ids = multiSelection ?? selectedLayerID.map { Set([$0]) } ?? []
        let members = project.layers.filter { ids.contains($0.id) && !$0.isGroup && $0.content != .camera && $0.content != .light }
        guard !members.isEmpty, let top = project.layers.firstIndex(where: { ids.contains($0.id) }) else { return }
        var gid = UUID()
        mutate("Group \(members.count) Layers") { p in
            var g = p.makeLayer(name: "Group \(p.layers.filter(\.isGroup).count + 1)", content: .solid,
                                size: Vec2(Double(p.width), Double(p.height)))
            g.isGroup = true
            g.fill = Animated(RGBA(0, 0, 0, 0))
            g.tag = .teal
            g.inPoint = members.map(\.inPoint).min() ?? 0
            g.outPoint = members.map(\.outPoint).max() ?? p.duration
            gid = g.id
            let memberIDs = Set(members.map(\.id))
            var rest = p.layers.filter { !memberIDs.contains($0.id) }
            let insertAt = min(top, rest.count)
            let parts = members.map { m -> Layer in var c = m; c.groupID = g.id; return c }
            rest.insert(contentsOf: [g] + parts, at: insertAt)
            p.layers = rest
        }
        multiSelection = nil; multiAnchor = nil
        selectedLayerID = gid
        panel = .transform
    }

    /// Removes the group container; parts stay where they are in the timeline.
    func ungroupSelected() {
        guard let l = selectedLayer, l.isGroup else { return }
        let gid = l.id
        mutate("Ungroup") { p in
            for i in p.layers.indices where p.layers[i].groupID == gid { p.layers[i].groupID = nil }
            p.layers.removeAll { $0.id == gid }
        }
        select(nil)
    }

    /// Parts of a group (top first).
    func parts(of group: Layer) -> [Layer] { project.layers.filter { $0.groupID == group.id } }

    /// Removes a group and everything inside it.
    func deleteGroup(_ gid: UUID) {
        mutate("Delete Group") { p in
            Self.unparentKeepingWorld(&p) { l in l.parentID == gid }
            let descendants = Self.descendantIDs(of: gid, in: p)
            p.layers.removeAll { $0.id == gid || descendants.contains($0.id) }
        }
        select(nil)
    }

    /// Duplicates a group with copies of all its parts.
    func duplicateGroup(_ gid: UUID) {
        guard let gi = project.layers.firstIndex(where: { $0.id == gid }) else { return }
        mutate("Duplicate Group") { p in
            let ids = Self.descendantIDs(of: gid, in: p).union([gid])
            let originals = p.layers.filter { ids.contains($0.id) }
            let remap = Dictionary(uniqueKeysWithValues: originals.map { ($0.id, UUID()) })
            let copies = originals.map { layer -> Layer in
                var copy = layer
                copy.id = remap[layer.id]!
                if layer.id == gid { copy.name += " copy" }
                if let parent = layer.parentID, let mapped = remap[parent] { copy.parentID = mapped }
                if let group = layer.groupID, let mapped = remap[group] { copy.groupID = mapped }
                return copy
            }
            p.layers.insert(contentsOf: copies, at: gi)
            selectedLayerID = remap[gid]
        }
    }
}
