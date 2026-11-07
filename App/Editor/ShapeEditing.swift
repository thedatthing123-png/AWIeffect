import Foundation
import simd

extension EditorState {
    var selectedShapeContent: ShapeContent? {
        let items = selectedLayer?.editableShapeContents ?? []
        return items.first { $0.id == selectedShapeContentID } ?? items.first { $0.component != nil }
    }

    func editShapeContent(_ id: UUID, _ label: String, continuous: Bool = false, _ change: (inout ShapeContent) -> Void) {
        beginEdit(label)
        mutateLayer { l in
            guard case .shape = l.content, !l.isLocked else { return }
            var items = l.editableShapeContents
            guard let i = items.firstIndex(where: { $0.id == id }) else { return }
            change(&items[i]); l.shapeContents = items
        }
        if !continuous { endEdit() }
    }

    func addShapeContent(_ kind: ShapeKind) {
        guard let l = selectedLayer, case .shape = l.content else { return }
        var c = ShapeComponent(); c.kind = kind
        c.size = Animated(Vec2(180, 180))

        let item = ShapeContent(name: "Path \(l.editableShapeContents.filter { $0.component != nil }.count + 1)", component: c)
        beginEdit("Add Path")
        mutateLayer { $0.shapeContents = $0.editableShapeContents + [item] }
        endEdit(); selectedShapeContentID = item.id
    }

    func addMergePaths(_ mode: MergePathsMode) {
        let item = ShapeContent(name: "Merge Paths", merge: mode)
        beginEdit("Add Merge Paths")
        mutateLayer { $0.shapeContents = $0.editableShapeContents + [item] }
        endEdit(); selectedShapeContentID = item.id
    }

    func moveShapeContent(_ id: UUID, before target: UUID) {
        guard id != target else { return }
        beginEdit("Reorder Shape Contents")
        mutateLayer { l in
            var items = l.editableShapeContents
            guard let i = items.firstIndex(where: { $0.id == id }), let j = items.firstIndex(where: { $0.id == target }) else { return }
            let item = items.remove(at: i); items.insert(item, at: i < j ? j - 1 : j); l.shapeContents = items
        }
        endEdit()
    }

    func removeShapeContent(_ id: UUID) {
        beginEdit("Remove Shape Content")
        mutateLayer { l in l.shapeContents = l.editableShapeContents.filter { $0.id != id } }
        endEdit(); selectedShapeContentID = nil
    }

    /// Existing stroke controls use Layer key paths; route them to the selected path without duplicating the UI.
    func editShapeStyle(_ id: UUID?, _ change: (inout Layer) -> Void) {
        mutateLayer { l in
            guard let id else { change(&l); return }
            var items = l.editableShapeContents
            guard let i = items.firstIndex(where: { $0.id == id }), var c = items[i].component else { return }
            var proxy = l; proxy.stroke = c.stroke; proxy.fill = c.fill
            change(&proxy); c.stroke = proxy.stroke; c.fill = proxy.fill
            items[i].component = c; l.shapeContents = items
        }
    }

    func shapePenPath(layer id: UUID, content cid: UUID) -> BezierPath? {
        guard let l = displayProject.layers.first(where: { $0.id == id }),
              let c = l.editableShapeContents.first(where: { $0.id == cid })?.component,
              let m = displayPlacement(of: id) else { return nil }
        return c.base(at: currentTime).mapped(m * c.matrix(at: currentTime))
    }

    func commitShapePen(_ path: BezierPath, layer id: UUID, content cid: UUID) {
        guard selectedLayerID == id, let l = selectedLayer,
              let c = l.editableShapeContents.first(where: { $0.id == cid })?.component,
              let m = displayPlacement(of: id) else { return }
        let placement = m * c.matrix(at: currentTime)
        guard abs(placement.determinant) > 1e-10 else { return }
        let local = Self.maskLocal(path, placement: placement), t = currentTime
        editShapeContent(cid, "Edit Path") { item in
            guard var c = item.component else { return }
            c.kind = .path
            c.path.set(local, at: t)
            item.component = c
        }
    }
}
