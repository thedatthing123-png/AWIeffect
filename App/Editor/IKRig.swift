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
    /// Root-to-tip connected bones for chain IK. Nil keeps Build 25's analytic two-bone solve.
    /// Stable layer IDs survive keyframes, save/load and copy/remap.
    var chainIDs: [UUID]? = nil
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

    /// Discover a complete parent-linked root-to-tip path; no arbitrary joint count.
    /// A disconnected selection returns nil instead of silently skipping pieces.
    static func connectedPath(root: UUID, end: UUID, in project: Project) -> [UUID]? {
        guard root != end else { return nil }
        let nodes = Dictionary(project.layers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var reversed: [UUID] = []
        var seen = Set<UUID>()
        var cursor: UUID? = end
        while let id = cursor, let layer = nodes[id] {
            guard seen.insert(id).inserted else { return nil }
            reversed.append(id)
            if id == root { return reversed.reversed() }
            cursor = layer.parentID
        }
        return nil
    }

    static func drivenIDs(owner: Layer) -> Set<UUID> {
        guard let rig = owner.ik else { return [] }
        return Set(rig.chainIDs ?? [rig.upperID, owner.id])
    }

    /// The evaluated tip is a geometric point on the END artwork, not the controller.
    /// Both a long chain and a two-bone rig can have targets beyond physical reach.
    static func tipWorld(_ owner: Layer, rig: IKRig, in project: Project, time: Double) -> Vec2? {
        let tip = rig.restTip ?? owner.bone?.tip ?? Vec2(0, Renderer.layerHalfSize(owner, time: time).y)
        let anchor = owner.transform.anchor.value(at: time)
        guard let frame = Renderer.parentAffine(owner.id, in: project, time: time),
              let point = LayerPlacement.projected(tip - anchor, by: frame.m) else { return nil }
        return point
    }

    /// Cyclic coordinate descent for arbitrary parent-linked joint chains. This does not
    /// rewrite/restretch the authored bones or require a fixed three-piece template.
    /// Keep legacy two-bone rigs on their exact analytic solver below.
    private static func solveChain(_ project: inout Project, ownerID: UUID, rig: IKRig, time: Double) {
        guard let ids = rig.chainIDs, ids.count >= 3, ids.last == ownerID,
              Set(ids).count == ids.count, ids.first == rig.upperID,
              connectedPath(root: ids[0], end: ownerID, in: project) == ids,
              let ctrl = project.layers.first(where: { $0.id == rig.controllerID }),
              let owner = project.layers.first(where: { $0.id == ownerID }),
              !ids.contains(rig.controllerID) else { return }
        let w = min(1, max(0, rig.mixValue(at: time)))
        if w <= 1e-8 { return }
        let bindSpace = rig.spaceID.flatMap { Renderer.parentAffine($0, in: project, time: time)?.m }
            ?? matrix_identity_double3x3
        guard abs(bindSpace.determinant) > 1e-10,
              let target = LayerPlacement.projected(collide(world(ctrl, in: project, time: time).pos,
                in: project, time: time), by: bindSpace.inverse) else { return }
        var solved = project
        // Fewer expensive passes when the target is reached; more passes for long chains.
        // This is an iteration budget, NOT a maximum number of bones.
        let iterations = min(36, max(12, ids.count * 2))
        for _ in 0..<iterations {
            guard let tipWorld = tipWorld(owner, rig: rig, in: solved, time: time),
                  let tip = LayerPlacement.projected(tipWorld, by: bindSpace.inverse) else { break }
            if hypot(tip.x - target.x, tip.y - target.y) < 0.05 { break }
            for id in ids.reversed() {
                guard let index = solved.layers.firstIndex(where: { $0.id == id }),
                      let frame = Renderer.parentAffine(id, in: solved, time: time),
                      let pivot = LayerPlacement.projected(.zero, by: bindSpace.inverse * frame.m),
                      let latestWorld = Self.tipWorld(owner, rig: rig, in: solved, time: time),
                      let effector = LayerPlacement.projected(latestWorld, by: bindSpace.inverse) else { continue }
                let a = effector - pivot, b = target - pivot
                let normA = hypot(a.x, a.y), normB = hypot(b.x, b.y)
                if normA < 1e-8 || normB < 1e-8 { continue }
                let cross = a.x * b.y - a.y * b.x
                let dot = a.x * b.x + a.y * b.y
                let delta = atan2(cross, dot)
                if abs(delta) < 1e-8 { continue }
                // A reflected parent reverses the direction of local-angle movement.
                let mirrored = (bindSpace.inverse * frame.m).determinant < 0
                let sign = mirrored ? -1.0 : 1.0
                let old = solved.layers[index].transform.rotation.value(at: time)
                let next = old + sign * delta * 180 / .pi
                if next.isFinite {
                    solved.layers[index].transform.rotation = Animated(next)
                }
            }
        }
        // Blend from genuine FK keyframes to the calculated IK pose, per joint.
        for id in ids {
            guard let i = project.layers.firstIndex(where: { $0.id == id }),
                  let solvedBone = solved.layers.first(where: { $0.id == id }) else { continue }
            let fk = project.layers[i].transform.rotation.value(at: time)
            let ik = solvedBone.transform.rotation.value(at: time)
            if ik.isFinite {
                project.layers[i].transform.rotation = Animated(blendAngle(fk: fk, ik: ik, w: w))
            }
        }
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
            if let chain = q.layers[li].ik?.chainIDs, chain.count >= 3,
               let rig = q.layers[li].ik {
                let ownerID = q.layers[li].id
                solveChain(&q, ownerID: ownerID, rig: rig, time: time)
                continue
            }
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

    /// Reusable rigid attachment: bind any number of artwork layers to any authored joint.
    /// The layer anchor is placed at that joint's endpoint, while its existing
    /// animation tracks and relative rotations/scales are kept.
    func attachArtwork(_ artworkID: UUID, toJoint jointID: UUID) {
        guard let piece = project.layers.first(where: { $0.id == artworkID }),
              let joint = project.layers.first(where: { $0.id == jointID }),
              !piece.isLocked, artworkID != jointID,
              !IKSolver.descendants(of: artworkID, in: project).contains(jointID) else {
            recoveryNotice = "Choose a separate, unlocked artwork that is not a parent of this joint."
            return
        }
        let t = currentTime
        let posed = IKSolver.apply(project, time: t)
        guard let jointPose = posed.layers.first(where: { $0.id == jointID }),
              let frame = Renderer.parentAffine(jointID, in: posed, time: t) else { return }
        let marker = jointPose.ik?.restTip ?? jointPose.bone?.tip ??
            jointPose.transform.anchor.value(at: t)
        let localMarker = marker - jointPose.transform.anchor.value(at: t)
        guard let reached = LayerPlacement.projected(localMarker, by: frame.m) else { return }
        let oldSelection = selectedLayerID
        let ownsEdit = !editGroupOpen
        if ownsEdit { beginEdit("Attach Artwork to Joint") }
        defer {
            selectedLayerID = oldSelection
            if ownsEdit { endEdit() }
        }
        if piece.parentID != jointID {
            selectedLayerID = artworkID
            setParent(jointID)
        }
        guard project.layers.first(where: { $0.id == artworkID })?.parentID == jointID,
              let posedNow = Renderer.parentAffine(jointID, in: IKSolver.apply(project, time: t), time: t),
              abs(posedNow.m.determinant) > 1e-10,
              let local = LayerPlacement.projected(reached, by: posedNow.m.inverse) else {
            recoveryNotice = "Couldn't attach the artwork. Check the parent chain and restore with Undo."
            return
        }
        mutate("Align Artwork to Joint") { p in
            guard let index = p.layers.firstIndex(where: { $0.id == artworkID }) else { return }
            var position = p.layers[index].transform.position
            let shift = local - position.value(at: t)
            position.staticValue = position.staticValue + shift
            position.keyframes = position.keyframes.map { key in
                var moved = key
                moved.value = moved.value + shift
                return moved
            }
            p.layers[index].transform.position = position
        }
    }

    /// Bind every joint along the existing hierarchy, from chosen root to selected tip.
    /// Drawing/parenting already creates these links; we do NOT collapse them to two bones.
    func makeChainIK(_ joints: [UUID], controller: UUID?, endArtwork: UUID?) {
        guard joints.count >= 3, let endID = joints.last, let rootID = joints.first,
              selectedLayerID == endID,
              IKSolver.connectedPath(root: rootID, end: endID, in: project) == joints else { return }
        let driven = Set(joints)
        if let conflict = project.layers.first(where: { layer in
            layer.ik != nil && !IKSolver.drivenIDs(owner: layer).isDisjoint(with: driven)
        }) {
            recoveryNotice = "Joint chain overlaps IK on \(conflict.name). Remove that constraint or select a different root."
            return
        }
        if let controller {
            guard let target = project.layers.first(where: { $0.id == controller }),
                  !target.isLocked, !driven.contains(controller),
                  !IKSolver.descendants(of: rootID, in: project).contains(controller) else {
                recoveryNotice = "The IK target must be outside its moving bone chain."
                return
            }
        }
        if let endArtwork {
            guard let art = project.layers.first(where: { $0.id == endArtwork }),
                  !art.isLocked, !driven.contains(endArtwork),
                  !IKSolver.descendants(of: endArtwork, in: project).contains(rootID) else {
                recoveryNotice = "The attachment must be a separate unlocked artwork layer."
                return
            }
        }
        let t = currentTime
        let posed = IKSolver.apply(project, time: t)
        guard let root = posed.layers.first(where: { $0.id == rootID }),
              let lower = posed.layers.first(where: { $0.id == endID }),
              let rootFrame = Renderer.parentAffine(rootID, in: posed, time: t),
              let lowerFrame = Renderer.parentAffine(endID, in: posed, time: t) else { return }
        let localTip = ikRestTip(for: lower)
        let lowerAnchor = lower.transform.anchor.value(at: t)
        guard let tipWorld = LayerPlacement.projected(localTip - lowerAnchor, by: lowerFrame.m) else { return }
        // All drawn bones in one artwork stay in that 2D plane even when camera tilts.
        let artID = lower.bone?.artworkID
        // The common coordinate space is the root bone's artwork or its parent.
        let spaceID = artID ?? root.parentID
        if let artID, joints.contains(where: { boneID in
            project.layers.first(where: { $0.id == boneID })?.bone?.artworkID != artID
        }) {
            recoveryNotice = "A bone chain must belong to the same artwork plane."
            return
        }
        let space = spaceID.flatMap { Renderer.parentAffine($0, in: posed, time: t)?.m }
            ?? matrix_identity_double3x3
        guard abs(space.determinant) > 1e-10 else { return }
        let chosenTarget: Vec2
        if let controller, let ctrl = posed.layers.first(where: { $0.id == controller }),
           let frame = Renderer.parentAffine(ctrl.id, in: posed, time: t),
           let point = LayerPlacement.projected(.zero, by: frame.m) {
            chosenTarget = point
        } else {
            chosenTarget = tipWorld
        }
        guard let targetInSpace = LayerPlacement.projected(chosenTarget, by: space.inverse),
              let start = LayerPlacement.projected(.zero, by: space.inverse * rootFrame.m),
              let nextID = joints.dropFirst().first,
              let nextFrame = Renderer.parentAffine(nextID, in: posed, time: t),
              let next = LayerPlacement.projected(.zero, by: space.inverse * nextFrame.m),
              let endPivot = LayerPlacement.projected(.zero, by: space.inverse * lowerFrame.m),
              let tip = LayerPlacement.projected(tipWorld, by: space.inverse) else { return }
        let l1 = hypot(next.x - start.x, next.y - start.y)
        let l2 = hypot(tip.x - endPivot.x, tip.y - endPivot.y)
        guard l1 > 0.0001, l2 > 0.0001, targetInSpace.x.isFinite,
              targetInSpace.y.isFinite else {
            recoveryNotice = "Give the bone chain nonzero segment lengths before binding IK."
            return
        }
        let ownsEdit = !editGroupOpen
        if ownsEdit { beginEdit("Bind Chain IK") }
        defer { if ownsEdit { endEdit() } }
        var targetID = controller ?? UUID()
        if let spaceID, let controller,
           project.layers.first(where: { $0.id == controller })?.parentID != spaceID {
            selectedLayerID = controller
            setParent(spaceID)
            selectedLayerID = endID
            guard project.layers.first(where: { $0.id == controller })?.parentID == spaceID else { return }
        }
        mutate("Bind Chain IK") { p in
            if controller == nil {
                var target = p.makeLayer(name: "Chain IK Controller", content: .solid, size: Vec2(40, 40))
                target.isNull = true
                target.tag = .amber
                target.parentID = spaceID
                target.groupID = lower.groupID
                target.transform.position = Animated(targetInSpace)
                targetID = target.id
                p.layers.insert(target, at: 0)
            }
            guard let index = p.layers.firstIndex(where: { $0.id == endID }) else { return }
            p.layers[index].ik = IKRig(
                upperID: rootID, controllerID: targetID, l1: l1, l2: l2,
                rest1: 0, rest2: 0, spaceID: spaceID,
                restTip: localTip, chainIDs: joints
            )
        }
        if let endArtwork {
            attachArtwork(endArtwork, toJoint: endID)
        }
        ikDraftTip = nil
        ikDraftUpper = nil
        ikDraftHand = nil
        selectedLayerID = targetID
        panel = .rig
    }

    /// Rigs the selected layer as the lower limb: `upper` must be its parent; the controller sits at the limb's tip.
    /// Makes a controller null at the tip when none is given.
    func makeIK(upper: UUID, controller: UUID?, hand: UUID? = nil) {
        guard let lower = selectedLayer, upper != lower.id else { return }
        if let path = IKSolver.connectedPath(root: upper, end: lower.id, in: project),
           path.count >= 3 {
            makeChainIK(path, controller: controller, endArtwork: hand)
            return
        }
        // A bone cannot be solved twice in the same frame. Show the existing rig instead of
        // quietly accumulating a second controller that overwrites the same rotations.
        if let conflict = project.layers.first(where: { layer in
            guard let rig = layer.ik else { return false }
            let driven = IKSolver.drivenIDs(owner: layer)
            return driven.contains(lower.id) || driven.contains(upper) ||
                (controller != nil && rig.controllerID == controller)
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

    /// Evaluated wrist in composition space, including for pre-Build-26 rigs that did not
    /// serialize their authored tip point. Uses the solved chain length, not the orange
    /// target location, so an unreachable target cannot detach a hand.
    func reachedIKWrist(owner: Layer, in source: Project, at time: Double) -> Vec2? {
        guard let rig = owner.ik else { return nil }
        let posed = IKSolver.apply(source, time: time)
        if let chain = rig.chainIDs, chain.count >= 3 {
            return IKSolver.tipWorld(owner, rig: rig, in: posed, time: time)
        }
        guard let lowerFrame = Renderer.parentAffine(owner.id, in: posed, time: time),
              let targetFrame = Renderer.parentAffine(rig.controllerID, in: posed, time: time) else { return nil }
        let space = rig.spaceID.flatMap { Renderer.parentAffine($0, in: posed, time: time)?.m }
            ?? matrix_identity_double3x3
        guard abs(space.determinant) > 1e-10 else { return nil }
        let eWorld = lowerFrame.m * SIMD3(0.0, 0.0, 1.0)
        let tWorld = targetFrame.m * SIMD3(0.0, 0.0, 1.0)
        guard let elbow = LayerPlacement.projected(Vec2(eWorld.x, eWorld.y), by: space.inverse),
              let target = LayerPlacement.projected(Vec2(tWorld.x, tWorld.y), by: space.inverse) else { return nil }
        let delta = target - elbow
        let length = hypot(delta.x, delta.y)
        guard length > 1e-8, rig.l2 > 0 else { return nil }
        let end = elbow + delta * (rig.l2 / length)
        return LayerPlacement.projected(end, by: space)
    }

    /// Explicit non-destructive repair for an existing two-bone IK. This never creates a
    /// new controller or changes the solver: it re-links the chosen end artwork and
    /// places its anchor at the reached wrist in one undo step.
    func repairIKEndAttachment(_ endArtworkID: UUID) {
        guard let owner = selectedIKLayer, let rig = owner.ik,
              let piece = project.layers.first(where: { $0.id == endArtworkID }),
              !piece.isLocked, endArtworkID != owner.id,
              endArtworkID != rig.upperID, endArtworkID != rig.controllerID,
              !IKSolver.descendants(of: endArtworkID, in: project).contains(owner.id),
              !IKSolver.descendants(of: endArtworkID, in: project).contains(rig.upperID) else {
            recoveryNotice = "Choose an unlocked end piece outside this rig's parent chain."
            return
        }
        let t = currentTime
        guard let wristWorld = reachedIKWrist(owner: owner, in: project, at: t) else {
            recoveryNotice = "Could not evaluate the wrist. Check the rig's controller and bone lengths."
            return
        }
        let previousSelection = selectedLayerID
        let ownsEdit = !editGroupOpen
        if ownsEdit { beginEdit("Repair IK Attachment") }
        defer { if ownsEdit { endEdit() }; selectedLayerID = previousSelection }

        if piece.parentID != owner.id {
            selectedLayerID = endArtworkID
            setParent(owner.id)
        }
        guard project.layers.first(where: { $0.id == endArtworkID })?.parentID == owner.id,
              let frame = Renderer.parentAffine(owner.id, in: IKSolver.apply(project, time: t), time: t),
              abs(frame.m.determinant) > 1e-10,
              let wristLocal = LayerPlacement.projected(wristWorld, by: frame.m.inverse) else {
            recoveryNotice = "The hand could not be linked to its forearm. Undo and check the layer parents."
            return
        }
        mutate("Align End Artwork") { p in
            guard let i = p.layers.firstIndex(where: { $0.id == endArtworkID }) else { return }
            var position = p.layers[i].transform.position
            let offset = wristLocal - position.value(at: t)
            position.staticValue = position.staticValue + offset
            position.keyframes = position.keyframes.map { k in
                var moved = k; moved.value = moved.value + offset; return moved
            }
            p.layers[i].transform.position = position
        }
        ikDraftHand = nil
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
        if selected.ik != nil { return selected }
        // Selecting any segment of a chain offers its common IK target.
        return project.layers.first { owner in
            guard let rig = owner.ik else { return false }
            return rig.controllerID == selected.id ||
                IKSolver.drivenIDs(owner: owner).contains(selected.id)
        }
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
            if let selected = selectedLayer, selected.bone != nil,
               ik.mixValue(at: currentTime) <= 0.001 {
                return .fkBoneTip(selected.id)
            }
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

    /// The pad travels in *visible composition* X/Y even under a rotated/scaled
    /// character or a 2.5D camera. Typed X/Y values still use the labelled local space.
    func nudgeRigPosition(_ target: RigPositionSelection, canvasDelta: Vec2) {
        guard canvasDelta.x.isFinite, canvasDelta.y.isFinite else { return }
        switch target {
        case .restEndpoint(let id):
            guard let local = rigPositionValue(target),
                  let frame = displayPlacement(of: id),
                  abs(frame.determinant) > 1e-10,
                  let origin = LayerPlacement.projected(local, by: frame),
                  let moved = LayerPlacement.projected(origin + canvasDelta, by: frame.inverse) else { return }
            moveRigPosition(target, to: moved)
        case .ikController(let id):
            let source = live.project ?? project
            let view = canvasViewProject(source), time = currentTime
            let posed = IKSolver.apply(view, time: time)
            let resolved = Renderer.resolveParenting(view, time: time)
            guard let controller = resolved.layers.first(where: { $0.id == id }) else { return }
            let rig = source.layers.first(where: { $0.ik?.controllerID == id })?.ik
            let camera = Renderer.activeCamera(resolved, time: time)
            let placement: simd_double3x3
            if let spaceID = rig?.spaceID,
               let art = resolved.layers.first(where: { $0.id == spaceID }),
               let projected = Self.bonePlacement(controller, artwork: art, project: posed,
                   time: time, camera: camera) {
                placement = projected
            } else {
                placement = Renderer.placementMatrix(controller, camera: camera, time: time, renderScale: 1)
            }
            guard let current = LayerPlacement.projected(controller.transform.anchor.value(at: time),
                                                        by: placement) else { return }
            poseIKController(id, atCanvas: current + canvasDelta)
        case .fkBoneTip:
            guard let current = rigPositionValue(target) else { return }
            moveRigPosition(target, to: current + canvasDelta)
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
                            state.nudgeRigPosition(selected, canvasDelta: Vec2(Double(change.width), Double(change.height)))
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
        let ownsEdit = target.editsPose && !state.editGroupOpen
        if ownsEdit { state.beginEdit("Position Joint") }
        state.moveRigPosition(target, to: next)
        if ownsEdit { state.endEdit() }
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
                        Text("IK (CONNECTED JOINT CHAINS)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                        if let owner = state.selectedIKLayer, let rig = owner.ik {
                            Text("Move the controller with the X/Y pad to pose connected joints. Position keys use the normal timeline and graph.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                            if let chain = rig.chainIDs, chain.count >= 3 {
                                Text("\(chain.count) connected joints · one IK controller")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.accentGlow)
                            } else {
                                Toggle("Bend the other way", isOn: Binding(get: { rig.flip }, set: { b in
                                    state.mutate("IK Bend") { p in if let i = p.layers.firstIndex(where: { $0.id == owner.id }) { p.layers[i].ik?.flip = b } }
                                }))
                                .tint(Theme.accent).foregroundStyle(Theme.text)
                            }
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
                            Divider().overlay(Theme.stroke)
                            Text("End artwork attachment").font(.system(size: 12, weight: .semibold))
                            picker("Hand / Foot", selection: state.ikDraftHand, exclude: owner.id) {
                                state.beginLayerPick(returnTo: .rig, prompt: "Tap the artwork to attach to this wrist") { id in
                                    if let id { state.ikDraftHand = id }
                                }
                            } clear: { state.ikDraftHand = nil }
                            if state.ikDraftHand != nil {
                                Text("The dashed canvas outline previews where the end piece will be aligned.")
                                    .font(.caption2).foregroundStyle(Theme.textDim)
                                Button {
                                    if let id = state.ikDraftHand { state.repairIKEndAttachment(id) }
                                } label: {
                                    Label("Repair / Attach End Piece", systemImage: "link")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                        } else {
                            Text("Select the END joint, then choose its ROOT / upper joint. If the layers already form a longer parent-linked chain, Make IK automatically includes every joint between them. Draw or link joints first; it won't flatten the chain.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                            if let root = state.ikDraftUpper,
                               let chain = IKSolver.connectedPath(root: root, end: l.id, in: state.project),
                               chain.count >= 3 {
                                Text("Ready: \(chain.count) connected joints")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.accentGlow)
                            }
                            picker("Root / Upper", selection: state.ikDraftUpper, exclude: l.id) { state.pickIKUpper() } clear: { state.ikDraftUpper = nil }
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
                        if l.bone != nil {
                            Divider().overlay(Theme.stroke)
                            Text("ARTWORK ATTACHMENTS").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.textDim)
                            Text("Attach multiple artwork layers to this bone's endpoint. Repeat for as many pieces as your character needs.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                            picker("Artwork", selection: state.ikDraftHand, exclude: l.id) {
                                state.beginLayerPick(returnTo: .rig, prompt: "Tap artwork to bind to this bone") { id in
                                    if let id { state.ikDraftHand = id }
                                }
                            } clear: { state.ikDraftHand = nil }
                            Button {
                                if let piece = state.ikDraftHand {
                                    state.attachArtwork(piece, toJoint: l.id)
                                    state.ikDraftHand = nil
                                }
                            } label: {
                                Label("Attach Artwork to Joint", systemImage: "link")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(state.ikDraftHand == nil)
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
