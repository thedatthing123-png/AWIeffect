import Foundation
import SwiftUI

/// Pre-compose / open / close nested comps. While a pre-comp is open, `project` IS that comp;
/// the parents wait on `compStack` and get the edited comp written back on close.
extension EditorState {
    var isInPrecomp: Bool { !compStack.isEmpty }

    /// The top-level project (what gets saved).
    var rootProject: Project {
        guard var root = compStack.first?.project else { return project }
        // Write the open chain back into a copy of the root so saves always contain the latest edits.
        var child = project
        for entry in compStack.dropFirst().reversed() {
            var parent = entry.project
            parent.precomps = Self.replacing(child, in: parent.precomps)
            child = parent
        }
        root.precomps = Self.replacing(child, in: root.precomps)
        return root
    }

    private static func replacing(_ comp: Project, in list: [Project]) -> [Project] {
        var l = list
        if let i = l.firstIndex(where: { $0.id == comp.id }) { l[i] = comp } else { l.append(comp) }
        return l
    }

    /// Moves the selected layer into a new comp (same size/duration) and replaces it with a pre-comp layer.
    func precomposeSelected() {
        guard let i = selectedIndex else { return }
        let layer = project.layers[i]
        var comp = Project.new(name: "\(layer.name) Comp", width: project.width, height: project.height,
                               fps: project.fps, duration: project.duration, background: RGBA(0, 0, 0, 0))
        comp.layers = [layer]
        mutate("Pre-compose") { p in
            var all = p.precomps
            all.append(comp)
            p.precomps = all
            var pl = p.makeLayer(name: comp.name, content: .precomp(id: comp.id), size: Vec2(Double(p.width), Double(p.height)))
            pl.inPoint = layer.inPoint
            pl.outPoint = layer.outPoint
            pl.sourceStart = layer.inPoint
            pl.tag = .teal
            p.layers[i] = pl
            selectedLayerID = pl.id
        }
    }

    /// Opens the pre-comp behind the selected layer for editing.
    func openPrecomp() {
        guard let l = selectedLayer, case .precomp(let id) = l.content,
              var comp = (compStack.first?.project.precomps ?? project.precomps).first(where: { $0.id == id })
                ?? project.precomps.first(where: { $0.id == id }) else { return }
        pause()
        let library = rootProject.precomps
        compStack.append((project: project, time: currentTime, selected: selectedLayerID))
        comp.precompList = library.filter { $0.id != comp.id }
        undoBarrier()
        project = comp
        currentTime = 0
        select(nil)
    }

    /// Closes the open pre-comp, writing its edits back into the parent.
    func closePrecomp() {
        guard let entry = compStack.popLast() else { return }
        pause()
        var edited = project
        edited.precompList = nil
        var parent = entry.project
        parent.precomps = Self.replacing(edited, in: parent.precomps)
        undoBarrier()
        project = parent
        currentTime = entry.time
        selectedLayerID = entry.selected
        redrawToken += 1
    }
}
