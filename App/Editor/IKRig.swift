import SwiftUI
import simd

/// Two-bone IK (Duik-style) stored on the LOWER limb layer (forearm / shin): the upper limb rotates at its pivot,
/// the lower limb rotates at the elbow, so the tip reaches the controller. Colliders keep the tip out of walls.
struct IKRig: Codable, Equatable {
    var upperID: UUID
    var controllerID: UUID
    /// Bend the joint the other way (elbow up / down, knee forward / back).
    var flip = false
    /// Bone lengths (comp px) and rest angle offsets (degrees), captured when the rig is made.
    var l1: Double
    var l2: Double
    var rest1: Double
    var rest2: Double
}

enum IKSolver {
    /// World (comp) position and rotation of a layer's pivot this frame, through its parent chain.
    private static func world(_ l: Layer, in p: Project, time: Double) -> (pos: Vec2, rot: Double) {
        let local = l.transform.position.value(at: time), r = l.transform.rotation.value(at: time)
        guard let pid = l.parentID, let a = Renderer.parentAffine(pid, in: p, time: time) else { return (local, r) }
        let w = a.m * SIMD3(local.x, local.y, 1)
        return (Vec2(w.x, w.y), r + a.rot)
    }

    /// Pushes a point out of every collider layer it is inside (to the nearest edge).
    static func collide(_ c: Vec2, in p: Project, time: Double) -> Vec2 {
        var pt = c
        for l in p.layers where l.isCollider && l.isActive(at: time) {
            let M = Renderer.layerMatrix(l, time: time, renderScale: 1)
            let inv = M.inverse
            let q = inv * SIMD3(pt.x, pt.y, 1)
            let hs = Renderer.layerHalfSize(l, time: time)
            guard abs(q.x) < hs.x, abs(q.y) < hs.y else { continue }
            // Nearest edge in the collider's own space.
            let dx = hs.x - abs(q.x), dy = hs.y - abs(q.y)
            var out = Vec2(q.x, q.y)
            if dx < dy { out.x = q.x < 0 ? -hs.x : hs.x } else { out.y = q.y < 0 ? -hs.y : hs.y }
            let w = M * SIMD3(out.x, out.y, 1)
            pt = Vec2(w.x, w.y)
        }
        return pt
    }

    /// Sets the rotations of every rigged limb for this frame (before parenting is baked).
    static func apply(_ p: Project, time: Double) -> Project {
        guard p.layers.contains(where: { $0.ik != nil }) else { return p }
        var q = p
        for li in q.layers.indices {
            guard let rig = q.layers[li].ik,
                  let ui = q.layers.firstIndex(where: { $0.id == rig.upperID }),
                  let ctrl = q.layers.first(where: { $0.id == rig.controllerID }) else { continue }
            let upper = q.layers[ui]
            let s = world(upper, in: q, time: time).pos
            let parentRot = upper.parentID.flatMap { Renderer.parentAffine($0, in: q, time: time)?.rot } ?? 0
            let target = collide(world(ctrl, in: q, time: time).pos, in: q, time: time)
            let dv = target - s
            let d = min(max(hypot(dv.x, dv.y), abs(rig.l1 - rig.l2) + 0.01), rig.l1 + rig.l2 - 0.01)
            let base = atan2(dv.y, dv.x)
            let cosA = min(1, max(-1, (rig.l1 * rig.l1 + d * d - rig.l2 * rig.l2) / (2 * rig.l1 * max(d, 1e-6))))
            let a1 = base + (rig.flip ? -acos(cosA) : acos(cosA))
            let elbow = s + Vec2(cos(a1), sin(a1)) * rig.l1
            let tipDir = target - elbow
            let a2 = atan2(tipDir.y, tipDir.x)
            let upperWorld = a1 * 180 / .pi - rig.rest1
            let lowerWorld = a2 * 180 / .pi - rig.rest2
            guard upperWorld.isFinite, lowerWorld.isFinite else { continue }
            q.layers[ui].transform.rotation = Animated(upperWorld - parentRot)
            q.layers[li].transform.rotation = Animated(lowerWorld - upperWorld)
        }
        return q
    }
}

extension EditorState {
    /// Rigs the selected layer as the lower limb: `upper` must be its parent; the controller sits at the limb's tip.
    /// Makes a controller null at the tip when none is given.
    func makeIK(upper: UUID, controller: UUID?) {
        guard let lower = selectedLayer else { return }
        let t = currentTime
        let disp = displayProject
        guard let up = disp.layers.first(where: { $0.id == upper }), let lo = disp.layers.first(where: { $0.id == lower.id }) else { return }
        // Tip = bottom center of the lower limb (where a hand / foot attaches), in comp space.
        let M = Renderer.layerMatrix(lo, time: t, renderScale: 1)
        let hs = Renderer.layerHalfSize(lo, time: t)
        let tipW = M * SIMD3(0, hs.y, 1)
        let tip = Vec2(tipW.x, tipW.y)
        let s = up.transform.position.value(at: t), e = lo.transform.position.value(at: t)
        let l1 = hypot(e.x - s.x, e.y - s.y), l2 = hypot(tip.x - e.x, tip.y - e.y)
        guard l1 > 1, l2 > 1 else { return }
        let rest1 = atan2(e.y - s.y, e.x - s.x) * 180 / .pi - up.transform.rotation.value(at: t)
        let rest2 = atan2(tip.y - e.y, tip.x - e.x) * 180 / .pi - lo.transform.rotation.value(at: t)
        var ctrlID = controller ?? UUID()
        mutate("Make IK") { p in
            guard let li = p.layers.firstIndex(where: { $0.id == lower.id }) else { return }
            // The lower limb follows the upper one.
            if p.layers[li].parentID != upper, let ui = p.layers.firstIndex(where: { $0.id == upper }) {
                let upW = Renderer.resolveParenting(p, time: t).layers[ui]
                let inv = Renderer.layerMatrix(upW, time: t, renderScale: 1).inverse
                let local = inv * SIMD3(e.x, e.y, 1)
                p.layers[li].parentID = upper
                p.layers[li].transform.position = Animated(Vec2(local.x, local.y))
                p.layers[li].transform.rotation = Animated(lo.transform.rotation.value(at: t) - upW.transform.rotation.value(at: t))
            }
            if controller == nil {
                var n = p.makeLayer(name: "\(lower.name) Controller", content: .solid, size: Vec2(40, 40))
                n.isNull = true
                n.tag = .amber
                n.transform.position = Animated(tip)
                ctrlID = n.id
                p.layers.insert(n, at: 0)
            }
            if let li2 = p.layers.firstIndex(where: { $0.id == lower.id }) {
                p.layers[li2].ik = IKRig(upperID: upper, controllerID: ctrlID, l1: l1, l2: l2, rest1: rest1, rest2: rest2)
            }
        }
        selectedLayerID = ctrlID
        panel = .transform
    }

    func removeIK() {
        guard let i = selectedIndex else { return }
        mutate("Remove IK") { $0.layers[i].ik = nil }
    }
}

/// Rig panel: IK for limbs and collider switch.
struct RigPanel: View {
    @ObservedObject var state: EditorState
    @State private var upper: UUID?
    @State private var controller: UUID?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Rig", showKeyNav: false)
            if let l = state.selectedLayer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Collider (IK tips and physics bodies can't go through this layer)", isOn: Binding(get: { l.isCollider }, set: { b in
                            state.mutate("Collider") { p in if let i = state.selectedIndex { p.layers[i].isCollider = b } }
                        }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                        Divider().overlay(Theme.stroke)
                        Text("IK (TWO-BONE LIMB)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                        if let rig = l.ik {
                            Text("This layer is the lower limb. Move the controller to pose the limb.").font(.caption).foregroundStyle(Theme.textDim)
                            Toggle("Bend the other way", isOn: Binding(get: { rig.flip }, set: { b in
                                state.mutate("IK Bend") { p in if let i = state.selectedIndex { p.layers[i].ik?.flip = b } }
                            }))
                            .tint(Theme.accent).foregroundStyle(Theme.text)
                            HStack {
                                Button("Select Controller") { state.select(rig.controllerID) }
                                Spacer()
                                Button("Remove IK", role: .destructive) { state.removeIK() }
                            }
                        } else {
                            Text("Select the LOWER part (forearm / shin), pick its upper part (upper arm / thigh), then Make IK. A controller is created at the limb's tip unless you pick one.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                            picker("Upper Limb", selection: $upper, exclude: l.id)
                            picker("Controller (optional)", selection: $controller, exclude: l.id)
                            Button { if let u = upper { state.makeIK(upper: u, controller: controller) } } label: {
                                Label("Make IK", systemImage: "figure.arms.open").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(upper == nil)
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
        }
    }

    private func picker(_ title: String, selection: Binding<UUID?>, exclude: UUID) -> some View {
        let options = state.project.layers.filter { $0.id != exclude && $0.content != .camera && $0.content != .light && !$0.isAudioOnly }
        return HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 130, alignment: .leading)
            Menu {
                Button("None") { selection.wrappedValue = nil }
                ForEach(options) { o in Button(o.name) { selection.wrappedValue = o.id } }
            } label: {
                Text(options.first { $0.id == selection.wrappedValue }?.name ?? "Choose…").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentGlow).frame(maxWidth: .infinity, minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
            }
        }
    }
}
