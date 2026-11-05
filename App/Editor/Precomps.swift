import Foundation
import SwiftUI

struct CompositionEditContext {
    var project: Project
    var time: Double
    var selected: UUID?
    var groupID: UUID? = nil
}

/// Pre-compose / open / close nested comps. While a pre-comp is open, `project` IS that comp;
/// the parents wait on `compStack` and get the edited comp written back on close.
extension EditorState {
    var isInPrecomp: Bool { !compStack.isEmpty }

    /// The top-level project (what gets saved).
    var rootProject: Project {
        guard !compStack.isEmpty else { return project }
        var child = project
        for entry in compStack.reversed() { child = Self.applying(child, to: entry) }
        return child
    }

    private static func applying(_ child: Project, to entry: CompositionEditContext) -> Project {
        var parent = entry.project
        if let gid = entry.groupID, let index = parent.layers.firstIndex(where: { $0.id == gid }) {
            let old = descendantIDs(of: gid, in: parent)
            let oldLayers = parent.layers.filter { old.contains($0.id) }
            parent.layers.removeAll { old.contains($0.id) }
            let nestedGroups = Set(child.layers.filter(\.isGroup).map(\.id))
            let members = child.layers.map { layer -> Layer in
                var l = layer
                if l.groupID == nil || !nestedGroups.contains(l.groupID!) { l.groupID = gid }
                return l
            }
            let at = (parent.layers.firstIndex(where: { $0.id == gid }) ?? index) + 1
            parent.layers.insert(contentsOf: members, at: at)
            if let i = parent.layers.firstIndex(where: { $0.id == gid }) {
                parent.layers[i].name = child.name
                if let oldEnd = oldLayers.map(\.outPoint).max(), let newEnd = members.map(\.outPoint).max() {
                    parent.layers[i].outPoint += newEnd - oldEnd
                }
                if let oldStart = oldLayers.map(\.inPoint).min(), let newStart = members.map(\.inPoint).min() {
                    parent.layers[i].inPoint += newStart - oldStart
                }
            }
            parent.markers = child.markers; parent.detectedBeatTimes = child.detectedBeatTimes
            parent.fitAutoLength()
            parent.precomps = child.precomps
        } else {
            parent.precomps = closing(child, into: parent.precomps)
        }
        return parent
    }

    nonisolated static func descendantIDs(of group: UUID, in project: Project) -> Set<UUID> {
        var result = Set<UUID>(), parents = Set([group])
        while true {
            let found = Set(project.layers.filter { $0.groupID.map(parents.contains) ?? false }.map(\.id)).subtracting(result).subtracting([group])
            if found.isEmpty { break }
            result.formUnion(found); parents = found
        }
        return result
    }

    func openGroup() {
        guard let group = selectedLayer, group.isGroup else { return }
        pause()
        let members = Self.descendantIDs(of: group.id, in: project)
        var child = project
        child.id = group.id; child.name = group.name; child.background = RGBA(0, 0, 0, 0)
        child.layers = project.layers.filter { members.contains($0.id) }.map { l in
            var value = l
            if value.groupID == group.id { value.groupID = nil }
            return value
        }
        child.parentContext = project.layers.filter { !members.contains($0.id) } + (project.parentContext ?? [])
        child.distinguishContainerTags()
        compStack.append(CompositionEditContext(project: project, time: currentTime, selected: selectedLayerID, groupID: group.id))
        pushUndoContext()
        project = child
        select(nil)
    }

    /// Writes an edited nested comp back into a library: strips its working copy of the library and keeps any
    /// comps that were created while it was open (pre-composing inside a pre-comp).
    private static func closing(_ comp: Project, into list: [Project]) -> [Project] {
        var edited = comp
        let extras = edited.precomps
        edited.precompList = nil
        edited.parentContext = nil
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
            pl.tag = p.nextContainerTag()
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
        compStack.append(CompositionEditContext(project: project, time: currentTime, selected: selectedLayerID))
        comp.parentContext = nil
        comp.distinguishContainerTags()
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
        let parent = Self.applying(project, to: entry)
        popUndoContext()
        project = parent
        currentTime = entry.time
        selectedLayerID = entry.selected
        redrawToken += 1
    }
}
