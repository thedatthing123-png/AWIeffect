import Foundation
import SwiftUI

struct CompositionEditContext {
    var project: Project
    var time: Double
    var selected: UUID?
    var groupID: UUID? = nil
    /// Root-comp time represented by local time zero while editing a group.
    var timelineOffset: Double = 0
    /// The comp as it was opened; closing compares against it to decide whether an undo step is needed.
    var opened: Project? = nil
}

/// Pre-compose / open / close nested comps. While a pre-comp is open, `project` IS that comp;
/// the parents wait on `compStack` and get the edited comp written back on close.
extension EditorState {
    var isInPrecomp: Bool { !compStack.isEmpty }

    /// Maps a time in the open comp to the root comp's time. Group timelines are local to their container;
    /// a pre-comp maps back through its layer timing (time remap falls back to the time it was opened at).
    func rootTime(_ t: Double) -> Double {
        var time = t
        for entry in compStack.reversed() {
            if entry.groupID != nil {
                time += entry.timelineOffset
                continue
            }
            guard let id = entry.selected, let l = entry.project.layers.first(where: { $0.id == id }),
                  case .precomp = l.content, l.timeRemap == nil, abs(l.speed) > 1e-6 else { time = entry.time; continue }
            time = l.inPoint + (time - l.sourceStart) / l.speed
        }
        return time
    }

    /// Color of the bar on a group part's timeline row: the tag of the group it belongs to. Inside an open group its
    /// direct parts carry no `groupID`, so they take the open group's tag. nil = not a group part.
    func groupMemberTag(of layer: Layer) -> LayerTag? {
        if let gid = layer.groupID {
            return project.layers.first(where: { $0.id == gid })?.tag ?? .teal
        }
        if let entry = compStack.last, let gid = entry.groupID {
            return entry.project.layers.first(where: { $0.id == gid })?.tag ?? .teal
        }
        return nil
    }

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
            let worldChild = offsettingGroupTimeline(child, by: entry.timelineOffset)
            let old = descendantIDs(of: gid, in: parent)
            let oldLayers = parent.layers.filter { old.contains($0.id) }
            parent.layers.removeAll { old.contains($0.id) }
            let nestedGroups = Set(worldChild.layers.filter(\.isGroup).map(\.id))
            let members = worldChild.layers.map { layer -> Layer in
                var l = layer
                if l.groupID == nil || !nestedGroups.contains(l.groupID!) { l.groupID = gid }
                return l
            }
            let at = (parent.layers.firstIndex(where: { $0.id == gid }) ?? index) + 1
            parent.layers.insert(contentsOf: members, at: at)
            if let i = parent.layers.firstIndex(where: { $0.id == gid }) {
                parent.layers[i].name = worldChild.name
                if let oldEnd = oldLayers.map(\.outPoint).max(), let newEnd = members.map(\.outPoint).max() {
                    parent.layers[i].outPoint += newEnd - oldEnd
                }
                if let oldStart = oldLayers.map(\.inPoint).min(), let newStart = members.map(\.inPoint).min() {
                    parent.layers[i].inPoint += newStart - oldStart
                }
            }
            let start = entry.timelineOffset
            let end = start + child.duration
            parent.markers = parent.markers.filter { $0 < start || $0 > end } + worldChild.markers
            let keptBeats = (parent.detectedBeatTimes ?? []).filter { $0 < start || $0 > end }
            let beats = keptBeats + (worldChild.detectedBeatTimes ?? [])
            parent.detectedBeatTimes = beats.isEmpty ? nil : beats.sorted()
            let keptCompMarkers = (parent.compMarkers ?? []).filter { $0.time < start || $0.time > end }
            let named = keptCompMarkers + (worldChild.compMarkers ?? [])
            parent.compMarkers = named.isEmpty ? nil : named.sorted { $0.time < $1.time }
            parent.fitAutoLength()
            parent.precomps = worldChild.precomps
            // A group shares its composition's shutter settings. Closing its local editing timeline
            // must not discard the master gate opened by an individual member's blur switch.
            parent.motionBlurOn = child.motionBlurOn
            parent.blurAllLayersStore = child.blurAllLayersStore; parent.sharpLayerIDs = child.sharpLayerIDs
            parent.shutterAngleStore = child.shutterAngleStore; parent.shutterPhaseStore = child.shutterPhaseStore
            parent.blurSamplesStore = child.blurSamplesStore; parent.smoothMotionStore = child.smoothMotionStore
        } else {
            parent.precomps = closing(child, into: parent.precomps)
        }
        return parent
    }

    /// Translates a scoped group between root time and its local zero-based timeline. Source media time and
    /// layer-relative markers stay unchanged; only composition-time values move.
    private static func offsettingGroupTimeline(_ input: Project, by delta: Double) -> Project {
        guard delta.isFinite, abs(delta) > 1e-12 else { return input }
        var output = input
        func offset(_ layers: inout [Layer]) {
            for i in layers.indices {
                layers[i].inPoint += delta
                layers[i].outPoint += delta
                var visit = AnimationTraversal(operation: .shift(delta))
                layers[i].traverseAnimations(&visit)
            }
        }
        offset(&output.layers)
        if var context = output.parentContext {
            offset(&context)
            output.parentContext = context
        }
        output.markers = output.markers.map { $0 + delta }
        output.detectedBeatTimes = output.detectedBeatTimes.map { $0.map { $0 + delta } }
        output.compMarkers = output.compMarkers.map { list in
            list.map { marker in var m = marker; m.time += delta; return m }
        }
        return output
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
        let offset = group.inPoint
        let length = max(project.frameDuration, group.outPoint - group.inPoint)
        child.markers = project.markers.filter { $0 >= group.inPoint && $0 <= group.outPoint }
        child.detectedBeatTimes = project.detectedBeatTimes.map { $0.filter { $0 >= group.inPoint && $0 <= group.outPoint } }
        child.compMarkers = project.compMarkers.map { $0.filter { $0.time >= group.inPoint && $0.time <= group.outPoint } }
        child = Self.offsettingGroupTimeline(child, by: -offset)
        child.duration = length
        child.autoLength = false
        child.distinguishContainerTags()
        compStack.append(CompositionEditContext(project: project, time: currentTime, selected: selectedLayerID,
                                                groupID: group.id, timelineOffset: offset, opened: child))
        pushUndoContext()
        project = child
        currentTime = child.snapToFrame(max(0, min(length, currentTime - offset)))
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
        comp.parentContext = nil
        comp.distinguishContainerTags()
        comp.precompList = library.filter { $0.id != comp.id }
        compStack.append(CompositionEditContext(project: project, time: currentTime, selected: selectedLayerID, opened: comp))
        pushUndoContext()
        project = comp
        currentTime = comp.snapToFrame(inner)
        select(nil)
    }

    /// True when nothing was edited inside (modification dates don't count).
    private static func sameContent(_ a: Project, _ b: Project) -> Bool {
        var x = a, y = b
        x.modifiedAt = y.modifiedAt
        return x == y
    }

    /// Closes the open pre-comp, writing its edits back into the parent.
    func closePrecomp() {
        endLiveGesture(); endEdit()
        guard let entry = compStack.popLast() else { return }
        pause()
        let parent = Self.applying(project, to: entry)
        // The inside work becomes one undo step on the parent, so it can be undone after closing.
        popUndoContext(committing: entry.groupID != nil ? "Edit Group" : "Edit Pre-comp", before: entry.project,
                             after: entry.opened.map { Self.sameContent($0, project) } == true ? entry.project : parent)
        project = parent
        currentTime = entry.time
        selectedLayerID = entry.selected
        redrawToken += 1
    }
}
