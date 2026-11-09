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
    /// IK / FK blend 0...1 (nil = 1, full IK). Below 1 the limb's own rotation keys mix back in.
    var blend: Double? = nil
    /// Animated replacement; old projects retain their legacy constant blend until it is edited.
    var mix: Animated<Double>? = nil
    /// Authored skeletons solve in their artwork's plane; nil preserves legacy composition-space rigs.
    var spaceID: UUID? = nil
    /// Explicit local wrist/ankle endpoint. Optional so saved Build 25 rigs remain readable.
    var restTip: Vec2? = nil
    func mixValue(at time: Double) -> Double { mix?.value(at: time) ?? blend ?? 1 }
}

enum IKSolver {
    /// Every layer linked (directly or down the chain) under `id`.
    static func descendants(of id: UUID, in p: Project) -> Set<UUID> {
        var out = Set<UUID>(), frontier = [id]
        while let cur = frontier.popLast() {
            for l in p.layers where l.parentID == cur && !out.contains(l.id) && l.id != id {
                out.insert(l.id); frontier.append(l.id)
            }
        }
        return out
    }

    /// FK rotation mixed toward the IK one (shortest way round), `w` 0 = FK, 1 = IK.
    static func blendAngle(fk: Double, ik: Double, w: Double) -> Double {
        let w = min(1, max(0, w.isFinite ? w : 1))
        var d = (ik - fk).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        return fk + d * w
    }

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
                  let ctrl = q.layers.first(where: { $0.id == rig.controllerID }),
                  rig.l1.isFinite, rig.l2.isFinite, rig.l1 > 0, rig.l2 > 0 else { continue }
            let upper = q.layers[ui]
            let space = rig.spaceID.flatMap { Renderer.parentAffine($0, in: q, time: time) }
            if rig.spaceID != nil && space == nil { continue }
            let spaceMatrix = space?.m ?? matrix_identity_double3x3
            guard abs(spaceMatrix.determinant) > 1e-10,
                  let s = LayerPlacement.projected(world(upper, in: q, time: time).pos, by: spaceMatrix.inverse),
                  let target = LayerPlacement.projected(collide(world(ctrl, in: q, time: time).pos, in: q, time: time), by: spaceMatrix.inverse) else { continue }
            let parentRot = (upper.parentID.flatMap { Renderer.parentAffine($0, in: q, time: time)?.rot } ?? 0) - (space?.rot ?? 0)
            let dv = target - s
            let d = min(max(hypot(dv.x, dv.y), max(1e-6, abs(rig.l1 - rig.l2))), rig.l1 + rig.l2)
            let base = atan2(dv.y, dv.x)
            let cosA = min(1, max(-1, (rig.l1 * rig.l1 + d * d - rig.l2 * rig.l2) / (2 * rig.l1 * max(d, 1e-6))))
            let a1 = base + (rig.flip ? -acos(cosA) : acos(cosA))
            let elbow = s + Vec2(cos(a1), sin(a1)) * rig.l1
            let tipDir = target - elbow
            let a2 = atan2(tipDir.y, tipDir.x)
            let upperWorld = a1 * 180 / .pi - rig.rest1
            let lowerWorld = a2 * 180 / .pi - rig.rest2
            guard upperWorld.isFinite, lowerWorld.isFinite else { continue }
            // FK/IK blend: at 100 % the solve wins; below that the limbs' own rotation keys show through.
            let w = rig.mixValue(at: time)
            let fkUpper = upper.transform.rotation.value(at: time), fkLower = q.layers[li].transform.rotation.value(at: time)
            q.layers[ui].transform.rotation = Animated(blendAngle(fk: fkUpper, ik: upperWorld - parentRot, w: w))
            q.layers[li].transform.rotation = Animated(blendAngle(fk: fkLower, ik: lowerWorld - upperWorld, w: w))
        }
        return q
    }
}

extension EditorState {
    /// Endpoint lives in artwork space so moving the camera does not change the bind pose.
    func ikRestTip(for layer: Layer) -> Vec2 {
        if let draft = ikDraftTip, draft.layerID == layer.id { return draft.point }
        return layer.bone?.tip ?? Vec2(0, Renderer.layerHalfSize(layer, time: currentTime).y)
    }

    /// Rigs the selected layer as the lower limb: `upper` must be its parent; the controller sits at the limb's tip.
    /// Makes a controller null at the tip when none is given.
    func makeIK(upper: UUID, controller: UUID?, hand: UUID? = nil) {
        guard let lower = selectedLayer, upper != lower.id else { return }
        // A bone cannot be solved twice in the same frame. Show the existing rig instead of
        // quietly accumulating a second controller that overwrites the same rotations.
        if let conflict = project.layers.first(where: { layer in
            guard let rig = layer.ik else { return false }
            return layer.id == lower.id || rig.upperID == upper ||
                   layer.id == upper || (controller != nil && rig.controllerID == controller)
        }) {
            recoveryNotice = "This joint already belongs to the rig on \(conflict.name). Select its controller or remove that IK before binding again."
            return
        }
        if let hand {
            guard let art = project.layers.first(where: { $0.id == hand }), !art.isLocked,
                  hand != lower.id, hand != upper, hand != controller,
                  !IKSolver.descendants(of: hand, in: project).contains(lower.id),
                  !IKSolver.descendants(of: hand, in: project).contains(upper) else {
                recoveryNotice = "Choose a separate, unlocked hand/foot layer that is not a parent of this limb."
                return
            }
        }
        // No link loops: the upper limb (and the controller) can't hang under the lower limb.
        let below = IKSolver.descendants(of: lower.id, in: project)
        guard !below.contains(upper), controller.map({ $0 != lower.id && !below.contains($0) }) ?? true else { return }
        if let controller {
            let constrained = IKSolver.descendants(of: upper, in: project).union([upper, lower.id])
            guard project.layers.contains(where: { $0.id == controller }), !constrained.contains(controller) else { return }
        }
        let t = currentTime
        let disp = displayProject
        guard let up = disp.layers.first(where: { $0.id == upper }), let lo = disp.layers.first(where: { $0.id == lower.id }) else { return }
        // Bind endpoint in comp space; its rest handle is authored in artwork coordinates.
        let capture = IKSolver.apply(project, time: t)
        var M = Renderer.layerMatrix(lo, time: t, renderScale: 1)
        if lower.bone != nil, let frame = Renderer.parentAffine(lower.id, in: capture, time: t) {
            let anchor = lower.transform.anchor.value(at: t)
            let fromPivot = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-anchor.x, -anchor.y, 1)))
            M = frame.m * fromPivot
        }
        let localTip = ikRestTip(for: lower)
        let tipW = M * SIMD3(localTip.x, localTip.y, 1)
        // A picked controller defines the end joint at bind time, rather than silently using the image edge.
        let tip = controller.flatMap { id in disp.layers.first(where: { $0.id == id }) }
            .map { $0.transform.position.value(at: t) } ?? Vec2(tipW.x, tipW.y)
        guard tip.x.isFinite, tip.y.isFinite else { return }
        let rawUpper = project.layers.first(where: { $0.id == upper })
        let spaceID = lower.bone?.artworkID ?? rawUpper?.parentID
        if let artworkID = lower.bone?.artworkID, rawUpper?.bone?.artworkID != artworkID { return }
        let space = spaceID.flatMap { Renderer.parentAffine($0, in: capture, time: t) }
        let matrix = space?.m ?? matrix_identity_double3x3
        guard abs(matrix.determinant) > 1e-10,
              let s = LayerPlacement.projected(up.transform.position.value(at: t), by: matrix.inverse),
              let e = LayerPlacement.projected(lo.transform.position.value(at: t), by: matrix.inverse),
              let end = LayerPlacement.projected(tip, by: matrix.inverse) else { return }
        let l1 = hypot(e.x - s.x, e.y - s.y), l2 = hypot(end.x - e.x, end.y - e.y)
        guard l1 > 1, l2 > 1 else { return }
        // Preserve the authored elbow side. Always choosing the positive branch can flip a limb on bind.
        let bend = (end.x - s.x) * (e.y - s.y) - (end.y - s.y) * (e.x - s.x) < 0
        let rest1 = atan2(e.y - s.y, e.x - s.x) * 180 / .pi - (up.transform.rotation.value(at: t) - (space?.rot ?? 0))
        let rest2 = atan2(end.y - e.y, end.x - e.x) * 180 / .pi - (lo.transform.rotation.value(at: t) - (space?.rot ?? 0))
        if let spaceID, let controller {
            guard controller != spaceID, !IKSolver.descendants(of: controller, in: project).contains(spaceID) else { return }
        }
        var ctrlID = controller ?? UUID()
        // One undo step: the link and the rig.
        let ownsEdit = !editGroupOpen
        if ownsEdit { beginEdit("Make IK") }
        defer { if ownsEdit { endEdit() } }
        // The lower limb follows the upper one. Linking converts every keyframe (it used to replace them).
        if lower.parentID != upper {
            setParent(upper)
            guard project.layers.first(where: { $0.id == lower.id })?.parentID == upper else { return }
        }
        if let spaceID, let controller, project.layers.first(where: { $0.id == controller })?.parentID != spaceID {
            selectedLayerID = controller
            setParent(spaceID)
            selectedLayerID = lower.id
            guard project.layers.first(where: { $0.id == controller })?.parentID == spaceID else { return }
        }
        // Optional final artwork is a wrist/ankle attachment, not a second competing IK.
        // Link first (preserving its existing animation), then offset its anchor to the
        // authored end joint. The offset applies to every key to retain local motion.
        if let hand {
            if project.layers.first(where: { $0.id == hand })?.parentID != lower.id {
                selectedLayerID = hand
                setParent(lower.id)
                selectedLayerID = lower.id
            }
            guard project.layers.first(where: { $0.id == hand })?.parentID == lower.id,
                  let frame = Renderer.parentAffine(lower.id, in: project, time: t),
                  abs(frame.m.determinant) > 1e-10,
                  let wrist = LayerPlacement.projected(tip, by: frame.m.inverse) else {
                recoveryNotice = "Couldn't attach the end piece to the wrist. Check the hierarchy and layer transforms."
                return
            }
            mutate("Attach Hand") { p in
                guard let i = p.layers.firstIndex(where: { $0.id == hand }) else { return }
                var position = p.layers[i].transform.position
                let offset = wrist - position.value(at: t)
                position.staticValue = position.staticValue + offset
                position.keyframes = position.keyframes.map { key in
                    var moved = key; moved.value = moved.value + offset; return moved
                }
                p.layers[i].transform.position = position
            }
        }
        mutate("Make IK") { p in
            if controller == nil {
                var n = p.makeLayer(name: "\(lower.name) Controller", content: .solid, size: Vec2(40, 40))
                n.isNull = true
                n.tag = .amber
                n.parentID = spaceID
                n.groupID = lower.groupID
                n.transform.position = Animated(spaceID == nil ? tip : end)
                ctrlID = n.id
                p.layers.insert(n, at: 0)
            }
            if let li2 = p.layers.firstIndex(where: { $0.id == lower.id }) {
                p.layers[li2].ik = IKRig(upperID: upper, controllerID: ctrlID, flip: bend, l1: l1, l2: l2, rest1: rest1, rest2: rest2, spaceID: spaceID, restTip: localTip)
            }
        }
        ikDraftTip = nil
        selectedLayerID = ctrlID
        panel = .rig
    }

    /// Direct controller posing shares the normal position tracks and paired depth keys.
    func poseIKController(_ id: UUID, atCanvas target: Vec2) {
        let source = live.project ?? project
        guard source.layers.contains(where: { $0.ik?.controllerID == id }),
              let controller = source.layers.first(where: { $0.id == id }), !controller.isLocked else { return }
        let rig = source.layers.first { $0.ik?.controllerID == id }?.ik
        let local: Vec2?
        if let artworkID = rig?.spaceID {
            local = rigPointInParent(controller, artworkID: artworkID, atCanvas: target, project: source)
        } else {
            local = MotionPathMath.value(controller, at: target, project: canvasViewProject(source), time: currentTime)
        }
        guard let local, local.x.isFinite, local.y.isFinite else { return }
        let time = currentTime
        mutate("Pose IK") { p in
            guard let i = p.layers.firstIndex(where: { $0.id == id }) else { return }
            let before = p.layers[i].transform
            p.layers[i].transform.position.set(local, at: time)
            p.layers[i].transform.pairPositionKeys(previous: before, at: time)
        }
    }

    var selectedIKLayer: Layer? {
        guard let selected = selectedLayer else { return nil }
        return selected.ik != nil ? selected : project.layers.first { $0.ik?.controllerID == selected.id }
    }

    func removeIK() {
        guard let owner = selectedIKLayer else { return }
        mutate("Remove IK") { p in
            if let i = p.layers.firstIndex(where: { $0.id == owner.id }) { p.layers[i].ik = nil }
        }
    }
}

/// The Rig position pad reuses the standard Move & Transform SwipePad.
///// The selected point, not the artwork layer, is its editing target.
enum RigPositionSelection: Equatable {
    case restEndpoint(UUID)
    case ikController(UUID)
    case fkBoneTip(UUID)

    var label: String {
        switch self {
        case .restEndpoint: return "Wrist / ankle (rest)"
        case .ikController: return "IK target"
        case .fkBoneTip: return "Bone tip"
        }
    }
    var editsPose: Bool {
        switch self {
        case .restEndpoint: return false
        case .ikController, .fkBoneTip: return true
        }
    }
}

extension EditorState {
    /// Keeping these roles distinct stops a wrist setup edit from turning into a layer move.
    var rigPositionSelection: RigPositionSelection? {
        if let owner = selectedIKLayer, let ik = owner.ik {
            return .ikController(ik.controllerID)
        }
        if let selected = selectedLayer, selected.bone != nil {
            // A bone already driven by another two-bone solve must be posed through its target.
            let constrained = project.layers.contains {
                guard let rig = $0.ik, rig.mixValue(at: currentTime) > 0.001 else { return false }
                return rig.upperID == selected.id || $0.id == selected.id
            }
            return constrained ? nil : .fkBoneTip(selected.id)
        }
        if let lower = selectedLayer, ikDraftUpper != nil, ikDraftController == nil {
            return .restEndpoint(lower.id)
        }
        return nil
    }

    /// Values are labelled in their real coordinate space: rig rest artwork-local,
    /// controllers parent-local, and FK tips projected into the composition.
    func rigPositionValue(_ selection: RigPositionSelection) -> Vec2? {
        let source = live.project ?? project
        switch selection {
        case .restEndpoint(let id):
            guard let layer = source.layers.first(where: { $0.id == id }) else { return nil }
            if let draft = ikDraftTip, draft.layerID == id { return draft.point }
            return layer.bone?.tip ?? Vec2(0, Renderer.layerHalfSize(layer, time: currentTime).y)
        case .ikController(let id):
            return source.layers.first(where: { $0.id == id })?.transform.position.value(at: currentTime)
        case .fkBoneTip(let id):
            guard let bone = source.layers.first(where: { $0.id == id }), let settings = bone.bone else { return nil }
            let viewed = canvasViewProject(source)
            let posed = IKSolver.apply(viewed, time: currentTime)
            let resolved = Renderer.resolveParenting(viewed, time: currentTime)
            guard let liveBone = posed.layers.first(where: { $0.id == id }),
                  let art = resolved.layers.first(where: { $0.id == settings.artworkID }),
                  let placement = Self.bonePlacement(liveBone, artwork: art, project: posed,
                      time: currentTime, camera: Renderer.activeCamera(resolved, time: currentTime)) else { return nil }
            return LayerPlacement.projected(settings.tip, by: placement)
        }
    }

    func moveRigPosition(_ selection: RigPositionSelection, to point: Vec2) {
        guard point.x.isFinite, point.y.isFinite else { return }
        switch selection {
        case .restEndpoint(let id):
            guard selectedLayerID == id, selectedIKLayer == nil, ikDraftUpper != nil else { return }
            // Transient bind setup: moving a rest marker must not create a timeline key or undo step.
            ikDraftTip = (id, point)
        case .ikController(let id):
            let source = live.project ?? project
            guard source.layers.contains(where: { $0.ik?.controllerID == id }),
                  source.layers.contains(where: { $0.id == id && !$0.isLocked }) else { return }
            let time = currentTime
            mutate("Pose IK") { p in
                guard let index = p.layers.firstIndex(where: { $0.id == id }) else { return }
                let before = p.layers[index].transform
                p.layers[index].transform.position.set(point, at: time)
                p.layers[index].transform.pairPositionKeys(previous: before, at: time)
            }
        case .fkBoneTip(let id):
            guard selectedLayerID == id else { return }
            poseBone(id, atCanvas: point)
        }
    }
}

/// Only X/Y from Move & Transform belongs here. No layer-move, Z, camera pan, or second gesture engine.
private struct RigPositionControls: View {
    @ObservedObject var state: EditorState
    @State private var fine = true

    var body: some View {
        if let selected = state.rigPositionSelection {
            LiveReader(live: state.live) { _ in
                if let value = state.rigPositionValue(selected) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(selected.label).font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer(minLength: 8)
                            Toggle("Fine", isOn: $fine)
                                .labelsHidden()
                                .accessibilityLabel("Fine joint positioning")
                            Text("Fine").font(.caption).foregroundStyle(Theme.textDim)
                        }
                        HStack(spacing: 8) {
                            NumberField(value: value.x, label: "X",
                                onDragBegin: { begin(selected) },
                                onDragEnd: { finish(selected) },
                                onCommit: { x in setAxis(selected, x: x) })
                            NumberField(value: value.y, label: "Y",
                                onDragBegin: { begin(selected) },
                                onDragEnd: { finish(selected) },
                                onCommit: { y in setAxis(selected, y: y) })
                        }
                        SwipePad(hint: "Swipe to position selected joint", gain: Double(state.project.width) * (fine ? 0.25 : 1)) { change in
                            guard let p = state.rigPositionValue(selected) else { return }
                            state.moveRigPosition(selected, to: p + Vec2(Double(change.width), Double(change.height)))
                        } begin: { begin(selected) } end: { finish(selected) }
                        .frame(height: 110)
                        .accessibilityIdentifier("rig-position-swipe-pad")
                        Text(selected.editsPose
                             ? "Moves this joint/controller only. Use the timeline to animate its existing transform."
                             : "Places the rest wrist/ankle before binding; does not add a keyframe.")
                            .font(.caption2).foregroundStyle(Theme.textDim)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.5)))
                }
            }
        }
    }

    private func begin(_ target: RigPositionSelection) {
        if target.editsPose { state.beginPanelGesture("Move Rig Point") }
    }
    private func finish(_ target: RigPositionSelection) {
        if target.editsPose { state.endPanelGesture() }
    }
    private func setAxis(_ target: RigPositionSelection, x: Double? = nil, y: Double? = nil) {
        guard let old = state.rigPositionValue(target) else { return }
        let next = Vec2(x ?? old.x, y ?? old.y)
        guard next != old else { return }
        if target.editsPose { state.beginEdit("Position Joint") }
        state.moveRigPosition(target, to: next)
        if target.editsPose { state.endEdit() }
    }
}

/// Rig panel: IK for limbs and collider switch.
struct RigPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Rig", showKeyNav: false)
            if let l = state.selectedLayer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        BoneAuthoringControls(state: state)
                        RigPositionControls(state: state)
                        Toggle("Collider (IK tips and physics bodies can't go through this layer)", isOn: Binding(get: { l.isCollider }, set: { b in
                            state.mutate("Collider") { p in if let i = state.selectedIndex { p.layers[i].isCollider = b } }
                        }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                        Divider().overlay(Theme.stroke)
                        Text("IK (TWO-BONE LIMB)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                        if let owner = state.selectedIKLayer, let rig = owner.ik {
                            Text("Move the controller to pose the limb. Its position keys use the normal timeline and graph.").font(.caption).foregroundStyle(Theme.textDim)
                            Toggle("Bend the other way", isOn: Binding(get: { rig.flip }, set: { b in
                                state.mutate("IK Bend") { p in if let i = p.layers.firstIndex(where: { $0.id == owner.id }) { p.layers[i].ik?.flip = b } }
                            }))
                            .tint(Theme.accent).foregroundStyle(Theme.text)
                            HStack {
                                Text("IK / FK").font(.system(size: 13)).foregroundStyle(Theme.text)
                                Button {
                                    let time = state.currentTime
                                    state.mutate("Key IK / FK") { p in
                                        guard let i = p.layers.firstIndex(where: { $0.id == owner.id }) else { return }
                                        var mix = p.layers[i].ik?.mix ?? Animated(rig.mixValue(at: time))
                                        mix.toggleKeyframe(at: time)
                                        p.layers[i].ik?.mix = mix
                                    }
                                } label: {
                                    Image(systemName: rig.mix?.hasKeyframe(at: state.currentTime) == true ? "diamond.fill" : "diamond")
                                        .foregroundStyle(Theme.keyframe).frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain).accessibilityLabel("Key IK / FK")
                                ValueScrubber(value: rig.mixValue(at: state.currentTime) * 100, range: 0...100, unit: "%",
                                    onBegin: { state.beginPanelGesture("IK Blend") }, onChange: { value in
                                        let time = state.currentTime
                                        state.mutate("IK Blend") { p in
                                            guard let i = p.layers.firstIndex(where: { $0.id == owner.id }) else { return }
                                            var mix = p.layers[i].ik?.mix ?? Animated(rig.mixValue(at: time))
                                            mix.set(min(1, max(0, value / 100)), at: time)
                                            p.layers[i].ik?.mix = mix
                                        }
                                    }, onEnd: { state.endPanelGesture() })
                                    .frame(height: 44)
                                    .accessibilityLabel("IK / FK Mix")
                            }
                            .frame(minHeight: 44)
                            HStack {
                                Button("Select Controller") { state.select(rig.controllerID); state.panel = .transform }
                                Spacer()
                                Button("Remove IK", role: .destructive) { state.removeIK() }
                            }
                        } else {
                            Text("Select the LOWER part (forearm / shin), pick its upper part (upper arm / thigh), then place the end joint on the canvas at the wrist or ankle. Make IK binds this pose; moving its controller poses the limb.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                            picker("Upper Limb", selection: state.ikDraftUpper, exclude: l.id) { state.pickIKUpper() } clear: { state.ikDraftUpper = nil }
                            picker("Controller (optional)", selection: state.ikDraftController, exclude: l.id) { state.pickIKController() } clear: { state.ikDraftController = nil }
                            picker("Hand / Foot", selection: state.ikDraftHand, exclude: l.id) {
                                state.beginLayerPick(returnTo: .rig, prompt: "Tap optional wrist/ankle artwork") { id in
                                    if let id { state.ikDraftHand = id }
                                }
                            } clear: { state.ikDraftHand = nil }
                            if state.ikDraftHand != nil {
                                Text("The selected hand/foot anchor will align with the end-joint marker when you bind. Position its anchor at the artwork's actual wrist/ankle first.")
                                    .font(.caption2).foregroundStyle(Theme.textDim)
                            }
                            Button {
                                if let u = state.ikDraftUpper, IKSolver.descendants(of: l.id, in: state.project).contains(u) == false, u != l.id {
                                    state.makeIK(upper: u, controller: state.ikDraftController, hand: state.ikDraftHand)
                                    if state.selectedIKLayer != nil {
                                        state.ikDraftUpper = nil; state.ikDraftController = nil; state.ikDraftHand = nil
                                    }
                                }
                            } label: {
                                Label("Make IK", systemImage: "figure.arms.open").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(state.ikDraftUpper == nil)
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
        }
    }

    /// Label + "tap a layer on the canvas" button + clear (three per row). Layers under the lower limb would make a
    /// link loop, so a pick of one is shown as invalid and Make IK refuses it.
    private func picker(_ title: String, selection: UUID?, exclude: UUID, pick: @escaping () -> Void, clear: @escaping () -> Void) -> some View {
        let below = IKSolver.descendants(of: exclude, in: state.project)
        let chosen = state.project.layers.first { $0.id == selection }
        let invalid = selection.map { below.contains($0) || $0 == exclude } ?? false
        return HStack(spacing: 6) {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 110, alignment: .leading)
            Button(action: pick) {
                Label(chosen?.name ?? "Tap a Layer", systemImage: "hand.tap").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    .foregroundStyle(invalid ? Theme.danger : Theme.accentGlow).frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
            }
            .buttonStyle(.plain)
            if selection != nil {
                Button(action: clear) { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(Theme.textDim).accessibilityLabel("Clear \(title)")
            }
        }
    }
}
