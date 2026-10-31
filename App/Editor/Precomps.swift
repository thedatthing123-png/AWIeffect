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
            parent.precomps = Self.closing(child, into: parent.precomps)
            child = parent
        }
        root.precomps = Self.closing(child, into: root.precomps)
        return root
    }

    /// Writes an edited nested comp back into a library: strips its working copy of the library and keeps any
    /// comps that were created while it was open (pre-composing inside a pre-comp).
    private static func closing(_ comp: Project, into list: [Project]) -> [Project] {
        var edited = comp
        let extras = edited.precomps
        edited.precompList = nil
        var l = replacing(edited, in: list)
        for e in extras where e.id != edited.id && !l.contains(where: { $0.id == e.id }) {
            var c = e; c.precompList = nil; l.append(c)
        }
        return l
    }

    private static func replacing(_ comp: Project, in list: [Project]) -> [Project] {
        var l = list
        if let i = l.firstIndex(where: { $0.id == comp.id }) { l[i] = comp } else { l.append(comp) }
        return l
    }

    /// Moves the selected layer into a new comp (same size/duration) and replaces it with a pre-comp layer.
    func precomposeSelected() {
        guard let i0 = selectedIndex else { return }
        let sid = project.layers[i0].id
        var clean = project
        Self.unparentKeepingWorld(&clean) { $0.id == sid || $0.parentID == sid }
        if clean != project { mutate("Unlink Parents") { $0 = clean } }
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
              var comp = rootProject.precomps.first(where: { $0.id == id }) ?? project.precomps.first(where: { $0.id == id }) else { return }
        pause()
        let library = rootProject.precomps
        let inner = max(0, min(comp.duration, l.sourceTime(at: currentTime)))
        compStack.append((project: project, time: currentTime, selected: selectedLayerID))
        comp.precompList = library.filter { $0.id != comp.id }
        pushUndoContext()
        project = comp
        currentTime = comp.snapToFrame(inner)
        select(nil)
    }

    /// Closes the open pre-comp, writing its edits back into the parent.
    func closePrecomp() {
        guard let entry = compStack.popLast() else { return }
        pause()
        var parent = entry.project
        parent.precomps = Self.closing(project, into: parent.precomps)
        popUndoContext()
        project = parent
        currentTime = entry.time
        selectedLayerID = entry.selected
        redrawToken += 1
    }
}
