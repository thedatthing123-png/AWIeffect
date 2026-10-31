import Foundation
import SwiftUI
import simd

/// AE / Alight Motion layer parenting (2D): a child's position is stored in its parent's space, and its rotation and
/// scale add to the parent's. Rendering bakes the chain into plain values per frame (`Renderer.resolveParenting`).
extension Renderer {
    /// Parent's local -> comp affine at `time` (renderScale 1), following the parent's own parents.
    static func parentAffine(_ id: UUID, in p: Project, time: Double, depth: Int = 0) -> (m: simd_double3x3, rot: Double, scale: Vec2)? {
        guard depth < 16, let parent = p.layers.first(where: { $0.id == id }) else { return nil }
        let own = layerMatrix(parent, time: time, renderScale: 1)
        let rot = parent.transform.rotation.value(at: time)
        let sc = parent.transform.scale.value(at: time) * 0.01
        // The parent's anchor is its local origin for children (AE behaviour).
        let anc = parent.transform.anchor.value(at: time)
        let toAnchor = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(anc.x, anc.y, 1)))
        let m = own * toAnchor
        if let up = parent.parentID, let chain = parentAffine(up, in: p, time: time, depth: depth + 1) {
            return (chain.m * m, chain.rot + rot, Vec2(chain.scale.x * sc.x, chain.scale.y * sc.y))
        }
        return (m, rot, sc)
    }

    /// Bakes parenting into absolute keyframed transforms (each key evaluated at its own time), so time effects like
    /// echo see the parent's motion too.
    static func resolveParentingAnimated(_ p: Project) -> Project {
        guard p.layers.contains(where: { $0.parentID != nil }) else { return p }
        var q = p
        EditorState.unparentKeepingWorld(&q) { _ in true }
        // Children whose own position is static still move with an animated parent: sample the parent's keys.
        for i in q.layers.indices {
            guard let pid = p.layers[i].parentID, let parent = p.layers.first(where: { $0.id == pid }) else { continue }
            let keyTimes = Set(parent.keyframeTimes + p.layers[i].keyframeTimes).sorted()
            guard !keyTimes.isEmpty else { continue }
            var pos = Animated(q.layers[i].transform.position.staticValue), rot = Animated(q.layers[i].transform.rotation.staticValue)
            var sc = Animated(q.layers[i].transform.scale.staticValue)
            let fps = max(p.fps, 1)
            var t = max(0, (keyTimes.first ?? 0) - 1 / fps)
            let end = min(p.duration, (keyTimes.last ?? 0) + 1 / fps)
            while t <= end + 1e-9 {
                let single = resolveParenting(p, time: t).layers[i].transform
                pos.insertKeyframe(Keyframe(time: t, value: single.position.value(at: t), interpolation: .linear))
                rot.insertKeyframe(Keyframe(time: t, value: single.rotation.value(at: t), interpolation: .linear))
                sc.insertKeyframe(Keyframe(time: t, value: single.scale.value(at: t), interpolation: .linear))
                t += 1 / fps
            }
            q.layers[i].transform.position = pos; q.layers[i].transform.rotation = rot; q.layers[i].transform.scale = sc
        }
        return q
    }

    /// Bakes parenting into absolute transform values for this frame.
    static func resolveParenting(_ p: Project, time: Double) -> Project {
        guard p.layers.contains(where: { $0.parentID != nil }) else { return p }
        var q = p
        for i in q.layers.indices {
            guard let pid = q.layers[i].parentID, let a = parentAffine(pid, in: p, time: time) else { continue }
            var t = q.layers[i].transform
            let local = t.position.value(at: time)
            let w = a.m * SIMD3(local.x, local.y, 1)
            t.position = Animated(Vec2(w.x, w.y))
            t.rotation = Animated(t.rotation.value(at: time) + a.rot)
            let sc = t.scale.value(at: time)
            t.scale = Animated(Vec2(sc.x * a.scale.x, sc.y * a.scale.y))
            q.layers[i].transform = t
            q.layers[i].parentID = nil
        }
        return q
    }
}

extension EditorState {
    /// Links (or unlinks with nil) the selected layer to a parent, converting its transform so it doesn't jump.
    func setParent(_ parent: UUID?) {
        guard let i = selectedIndex else { return }
        let child = project.layers[i]
        guard parent != child.id else { return }
        // No cycles.
        var walk = parent
        var guardCount = 0
        while let w = walk, guardCount < 32 {
            if w == child.id { return }
            walk = project.layers.first { $0.id == w }?.parentID
            guardCount += 1
        }
        let now = currentTime
        mutate(parent == nil ? "Unparent" : "Parent Layer") { p in
            var tr = p.layers[i].transform
            func convert<V: Interpolatable>(_ a: Animated<V>, _ f: (V, Double) -> V) -> Animated<V> {
                var out = a
                out.staticValue = f(a.staticValue, now)
                out.keyframes = a.keyframes.map { var k = $0; k.value = f(k.value, k.time); return k }
                return out
            }
            // Old parent space -> comp.
            if let old = child.parentID {
                tr.position = convert(tr.position) { v, t in
                    guard let a = Renderer.parentAffine(old, in: p, time: t) else { return v }
                    let w = a.m * SIMD3(v.x, v.y, 1); return Vec2(w.x, w.y)
                }
                tr.rotation = convert(tr.rotation) { v, t in v + (Renderer.parentAffine(old, in: p, time: t)?.rot ?? 0) }
                tr.scale = convert(tr.scale) { v, t in let s = Renderer.parentAffine(old, in: p, time: t)?.scale ?? Vec2(1, 1); return Vec2(v.x * s.x, v.y * s.y) }
            }
            // Comp -> new parent space.
            if let new = parent {
                tr.position = convert(tr.position) { v, t in
                    guard let a = Renderer.parentAffine(new, in: p, time: t) else { return v }
                    let l = a.m.inverse * SIMD3(v.x, v.y, 1); return Vec2(l.x, l.y)
                }
                tr.rotation = convert(tr.rotation) { v, t in v - (Renderer.parentAffine(new, in: p, time: t)?.rot ?? 0) }
                tr.scale = convert(tr.scale) { v, t in
                    let s = Renderer.parentAffine(new, in: p, time: t)?.scale ?? Vec2(1, 1)
                    return Vec2(v.x / max(abs(s.x), 1e-6) * (s.x < 0 ? -1 : 1), v.y / max(abs(s.y), 1e-6) * (s.y < 0 ? -1 : 1))
                }
            }
            p.layers[i].transform = tr
            p.layers[i].parentID = parent
        }
    }

    /// Removes parent links for `ids` (or links pointing at them / across a boundary) keeping every keyframe's world placement.
    nonisolated static func unparentKeepingWorld(_ p: inout Project, where shouldUnlink: (Layer) -> Bool) {
        let snapshot = p
        for i in p.layers.indices where p.layers[i].parentID != nil && shouldUnlink(p.layers[i]) {
            guard let old = p.layers[i].parentID else { continue }
            var tr = p.layers[i].transform
            func convert<V: Interpolatable>(_ a: Animated<V>, _ f: (V, Double) -> V) -> Animated<V> {
                var out = a
                out.staticValue = f(a.staticValue, 0)
                out.keyframes = a.keyframes.map { var k = $0; k.value = f(k.value, k.time); return k }
                return out
            }
            tr.position = convert(tr.position) { v, t in
                guard let a = Renderer.parentAffine(old, in: snapshot, time: t) else { return v }
                let w = a.m * SIMD3(v.x, v.y, 1); return Vec2(w.x, w.y)
            }
            tr.rotation = convert(tr.rotation) { v, t in v + (Renderer.parentAffine(old, in: snapshot, time: t)?.rot ?? 0) }
            tr.scale = convert(tr.scale) { v, t in let s = Renderer.parentAffine(old, in: snapshot, time: t)?.scale ?? Vec2(1, 1); return Vec2(v.x * s.x, v.y * s.y) }
            p.layers[i].transform = tr
            p.layers[i].parentID = nil
        }
    }

    /// The comp as displayed (parenting baked) for hit-testing and handles.
    var displayProject: Project { Renderer.resolveParenting(project, time: currentTime) }
}

/// Pick-whip list: choose the parent for the selected layer.
struct ParentPicker: View {
    @ObservedObject var state: EditorState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button { state.setParent(nil); dismiss() } label: {
                    Label("None", systemImage: "link.badge.plus").foregroundStyle(Theme.text)
                }
                ForEach(state.project.layers.filter { $0.id != state.selectedLayerID && $0.content != .camera && !$0.isAudioOnly }) { l in
                    Button { state.setParent(l.id); dismiss() } label: {
                        HStack {
                            Image(systemName: l.content.symbol).foregroundStyle(Theme.tagColor(l.tag))
                            Text(l.name).foregroundStyle(Theme.text)
                            Spacer()
                            if state.selectedLayer?.parentID == l.id { Image(systemName: "checkmark").foregroundStyle(Theme.accentGlow) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Parent To").navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
