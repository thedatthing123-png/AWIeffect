import SwiftUI
import simd

/// Alight Motion-style groups: parts stay editable in the project and are shown inside the group, and
/// the group's transform, masks, effects, blend mode and matte apply to all of them together.
extension EditorState {
    /// Groups the multi-selection (or the selected layer). Parts move right under the new group, in order.
    func groupSelected() {
        let ids = multiSelection ?? selectedLayerID.map { Set([$0]) } ?? []
        let roots = project.layers.filter { ids.contains($0.id) && $0.content != .camera && $0.content != .light }
        var included = Set(roots.map(\.id))
        for group in roots where group.isGroup { included.formUnion(Self.descendantIDs(of: group.id, in: project)) }
        let members = project.layers.filter { included.contains($0.id) }
        guard !members.isEmpty, let top = project.layers.firstIndex(where: { ids.contains($0.id) }) else { return }
        var gid = UUID()
        mutate("Group \(members.count) Layers") { p in
            var g = p.makeLayer(name: "Group \(p.layers.filter(\.isGroup).count + 1)", content: .solid,
                                size: Vec2(Double(p.width), Double(p.height)))
            g.isGroup = true
            g.fill = Animated(RGBA(0, 0, 0, 0))
            g.tag = p.nextContainerTag()
            g.inPoint = members.map(\.inPoint).min() ?? 0
            g.outPoint = members.map(\.outPoint).max() ?? p.duration
            gid = g.id
            let memberIDs = Set(members.map(\.id))
            var rest = p.layers.filter { !memberIDs.contains($0.id) }
            let insertAt = min(top, rest.count)
            let parts = members.map { m -> Layer in
                var c = m
                if c.groupID == nil || !included.contains(c.groupID!) { c.groupID = g.id }
                return c
            }
            rest.insert(contentsOf: [g] + parts, at: insertAt)
            p.layers = rest
        }
        multiSelection = nil; multiAnchor = nil
        selectedLayerID = gid
        panel = .transform
    }

    /// Dissolve the container and its treatments; retain each child's own effects and editable transforms.
    func ungroupSelected() {
        guard let group = selectedLayer, group.isGroup else { return }
        let snapshot = project, gid = group.id
        let descendants = Self.descendantIDs(of: gid, in: snapshot)
        let roots = snapshot.layers.filter { $0.groupID == gid && !($0.parentID.map(descendants.contains) ?? false) }
        guard roots.allSatisfy({ max(0,min($0.outPoint,group.outPoint)-max($0.inPoint,group.inPoint))*max(1,snapshot.fps) <= 36000 }) else {
            recoveryNotice = "Trim this long group into shorter sections before ungrouping its animated transforms."
            return
        }
        var replacements: [UUID: Layer] = [:]
        for member in roots {
            var copy = member
            let start = max(member.inPoint, group.inPoint), end = min(member.outPoint, group.outPoint)
            guard end > start else { copy.isVisible = false; replacements[member.id] = copy; continue }
            let animated = !member.keyframeTimes.isEmpty || !group.keyframeTimes.isEmpty || member.parentID != nil || group.parentID != nil
            let count = animated ? min(36000, max(1, Int(ceil((end-start) * max(1, snapshot.fps))))) : 0
            func transform(at time: Double) -> LayerTransform {
                let resolved = Renderer.resolveParenting(snapshot, time: time)
                let carrier = resolved.layers.first { $0.id == gid } ?? group
                let child = resolved.layers.first { $0.id == member.id } ?? member
                let canvas = group.groupCanvasSize ?? group.size.value(at: time)
                let size = group.size.value(at: time)
                let ratio = Vec2(size.x / max(1, canvas.x), size.y / max(1, canvas.y))
                let position = child.transform.position.value(at: time)
                let local = Vec2((position.x-canvas.x/2)*ratio.x,(position.y-canvas.y/2)*ratio.y)
                let world = Renderer.layerMatrix(carrier, time: time, renderScale: 1) * SIMD3(local.x,local.y,1)
                var result = child.transform
                result.position = Animated(Vec2(world.x/world.z,world.y/world.z))
                let scale = child.transform.scale.value(at: time), parentScale = carrier.transform.scale.value(at: time)
                result.scale = Animated(Vec2(scale.x*parentScale.x/100*ratio.x,scale.y*parentScale.y/100*ratio.y))
                result.rotation = Animated(child.transform.rotation.value(at: time)+carrier.transform.rotation.value(at: time))
                result.opacity = Animated(child.transform.opacity.value(at: time)*carrier.transform.opacity.value(at: time)/100)
                result.positionZ = Animated(child.transform.positionZ.value(at: time)+carrier.transform.positionZ.value(at: time))
                return result
            }
            let base = transform(at: start)
            copy.transform.position = base.position; copy.transform.scale = base.scale
            copy.transform.rotation = base.rotation; copy.transform.opacity = base.opacity
            copy.transform.positionZ = base.positionZ
            if count > 0 {
                for frame in 0...count {
                    let time = min(end, start + Double(frame)/max(1,snapshot.fps)), value = transform(at: time)
                    copy.transform.position.insertKeyframe(Keyframe(time: time,value: value.position.staticValue,interpolation: .linear))
                    copy.transform.scale.insertKeyframe(Keyframe(time: time,value: value.scale.staticValue,interpolation: .linear))
                    copy.transform.rotation.insertKeyframe(Keyframe(time: time,value: value.rotation.staticValue,interpolation: .linear))
                    copy.transform.opacity.insertKeyframe(Keyframe(time: time,value: value.opacity.staticValue,interpolation: .linear))
                    copy.transform.positionZ.insertKeyframe(Keyframe(time: time,value: value.positionZ.staticValue,interpolation: .linear))
                }
            }
            copy.parentID = nil
            copy.isVisible = member.isVisible && group.isVisible
            replacements[member.id] = copy
        }
        mutate("Ungroup") { project in
            for index in project.layers.indices {
                let original = project.layers[index]
                if let replacement = replacements[original.id] { project.layers[index] = replacement }
                if original.groupID == gid {
                    if replacements[original.id] == nil {
                        project.layers[index].transform.opacity = original.transform.opacity.mapped { $0 * group.transform.opacity.value(at: currentTime) / 100 }
                        if group.transform.opacity.isAnimated {
                            var opacity = Animated(original.transform.opacity.value(at: original.inPoint) * group.transform.opacity.value(at: original.inPoint) / 100)
                            let count = min(36000, max(1,Int(ceil((original.outPoint-original.inPoint)*max(1,snapshot.fps)))))
                            for frame in 0...count {
                                let time = min(original.outPoint,original.inPoint+Double(frame)/max(1,snapshot.fps))
                                opacity.insertKeyframe(Keyframe(time: time,value: original.transform.opacity.value(at: time)*group.transform.opacity.value(at: time)/100,interpolation: .linear))
                            }
                            project.layers[index].transform.opacity = opacity
                        }
                    }
                    let start = max(original.inPoint,group.inPoint), end = min(original.outPoint,group.outPoint)
                    if project.layers[index].timeRemap == nil { project.layers[index].sourceStart += (start-original.inPoint)*original.speed }
                    project.layers[index].inPoint = start; project.layers[index].outPoint = max(start,end)
                    project.layers[index].isVisible = original.isVisible && group.isVisible && end > start
                    project.layers[index].groupID = group.groupID
                }
            }
            project.layers.removeAll { $0.id == gid }
        }
        recoveryNotice = nil
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
                if layer.id == gid { copy.name += " copy"; copy.tag = p.nextContainerTag() }
                if let parent = layer.parentID, let mapped = remap[parent] { copy.parentID = mapped }
                if let group = layer.groupID, let mapped = remap[group] { copy.groupID = mapped }
                copy.remapRigReferences(remap)
                return copy
            }
            p.layers.insert(contentsOf: copies, at: gi)
            selectedLayerID = remap[gid]
        }
    }
}
