import Foundation
import simd

struct ArtworkBone: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var start: Vec2
    var end: Vec2
    var parentID: UUID?
    var rotation: Animated<Double>? = nil
    var offset: Animated<Vec2>? = nil

    var length: Double { hypot(end.x - start.x, end.y - start.y) }
}

struct ArtworkIK: Codable, Equatable {
    var tipBoneID: UUID
    var target: Animated<Vec2>
    var flipped = false
    var mix = Animated(100.0)
    var stretchLimit = 1.0
}

struct ArtworkRig: Codable, Equatable {
    var bones: [ArtworkBone] = []
    var mesh: BoneMeshBinding? = nil
    var constraints: [ArtworkIK]? = nil

    func constraint(on bone: UUID) -> ArtworkIK? {
        constraints?.first { $0.tipBoneID == bone }
    }

    mutating func editIK(on bone: UUID, _ change: (inout ArtworkIK) -> Void) {
        guard let index = constraints?.firstIndex(where: { $0.tipBoneID == bone }),
              var item = constraints?[index] else { return }
        change(&item)
        constraints?[index] = item
    }

    func canParent(_ boneID: UUID, to parentID: UUID?) -> Bool {
        guard bones.contains(where: { $0.id == boneID }) else { return false }
        var next = parentID
        var visited: Set<UUID> = [boneID]
        while let id = next {
            guard visited.insert(id).inserted, let parent = bones.first(where: { $0.id == id }) else { return false }
            next = parent.parentID
        }
        return true
    }

    mutating func reparent(_ boneID: UUID, to parentID: UUID?, at time: Double = 0) {
        guard canParent(boneID, to: parentID),
              let index = bones.firstIndex(where: { $0.id == boneID }),
              bones[index].parentID != parentID else { return }
        let oldPose = pose(at: time, solveIK: false)
        let old = oldPose[boneID]?.matrix ?? matrix_identity_double3x3
        let parent = parentID.flatMap { oldPose[$0]?.matrix } ?? matrix_identity_double3x3
        let local = parent.inverse * old
        let start = bones[index].start
        let position = RigAffine(local).apply(start) - start
        let rotation = atan2(local[0].y, local[0].x) * 180 / .pi
        bones[index].parentID = parentID
        constraints?.removeAll { $0.tipBoneID == boneID }
        if bones[index].offset != nil { bones[index].offset?.set(position, at: time) }
        else if hypot(position.x, position.y) > 1e-8 { bones[index].offset = Animated(position) }
        if bones[index].rotation != nil { bones[index].rotation?.set(rotation, at: time) }
        else if abs(rotation) > 1e-8 { bones[index].rotation = Animated(rotation) }
    }

    mutating func bind(halfSize: Vec2, artworkID: UUID, detail: Int, radius: Double?, amount: Double) {
        let segments = bones.map { bone in
            BoneMeshSource(id: bone.id, matrix: Self.translation(bone.start), tip: bone.end - bone.start)
        }
        if let radius {
            mesh = BoneMeshBinding.localized(halfSize: halfSize, detail: detail, artworkID: artworkID,
                                             bones: segments, radius: radius)
        } else {
            mesh = BoneMeshBinding.wholeArtwork(halfSize: halfSize, detail: detail, artworkID: artworkID, bones: segments)
        }
        mesh?.amount = amount
    }

    /// Keep the grid for smooth brush neighbourhoods, but omit cells that are entirely transparent.
    mutating func trimTransparentCells(alpha: [UInt8], width: Int, height: Int) {
        guard var mesh, width > 0, height > 0, alpha.count == width * height else { return }
        var indices: [UInt32] = []
        for row in 0..<mesh.rows {
            let y0 = max(0, row * height / mesh.rows - 1)
            let y1 = min(height, ((row + 1) * height + mesh.rows - 1) / mesh.rows + 1)
            for column in 0..<mesh.columns {
                let x0 = max(0, column * width / mesh.columns - 1)
                let x1 = min(width, ((column + 1) * width + mesh.columns - 1) / mesh.columns + 1)
                let visible = (y0..<y1).contains { y in
                    alpha[(y * width + x0)..<(y * width + x1)].contains { $0 > 0 }
                }
                guard visible else { continue }
                let a = UInt32(row * (mesh.columns + 1) + column)
                let b = a + 1
                let c = a + UInt32(mesh.columns + 1)
                indices += [a, b, c, b, c + 1, c]
            }
        }
        guard !indices.isEmpty, indices != mesh.indices else { return }
        mesh.indices = indices
        mesh.changed()
        self.mesh = mesh
    }

    mutating func enableIK(on lowerID: UUID, time: Double) -> Bool {
        guard constraint(on: lowerID) == nil,
              let lower = bones.first(where: { $0.id == lowerID }),
              let upper = bones.first(where: { $0.id == lower.parentID }),
              hypot(upper.end.x - lower.start.x, upper.end.y - lower.start.y) < 1,
              upper.length >= 0.1, lower.length >= 0.1 else { return false }
        let occupied = (constraints ?? []).contains { constraint in
            let otherParent = bones.first { $0.id == constraint.tipBoneID }?.parentID
            return constraint.tipBoneID == upper.id || otherParent == lower.id || otherParent == upper.id
        }
        guard !occupied else { return false }
        let frames = pose(at: time)
        let target = (frames[lowerID] ?? .identity).apply(lower.end)
        let origin = (frames[upper.id] ?? .identity).apply(upper.start)
        let elbow = (frames[lowerID] ?? .identity).apply(lower.start) - origin
        let direction = target - origin
        let item = ArtworkIK(tipBoneID: lowerID, target: Animated(target),
                             flipped: direction.x * elbow.y - direction.y * elbow.x < 0)
        constraints = (constraints ?? []) + [item]
        return true
    }

    func palette(for binding: BoneMeshBinding, at time: Double) -> [RigAffine] {
        let frames = pose(at: time)
        let mix = min(1, max(0, binding.amount ?? 1))
        return binding.boneIDs.map { id in
            guard let frame = frames[id] else { return .identity }
            return RigAffine(matrix_identity_double3x3 + (frame.matrix - matrix_identity_double3x3) * mix)
        }
    }

    /// Parent-relative pose deltas, expressed as matrices acting on artwork-local rest points.
    func pose(at time: Double, solveIK: Bool = true) -> [UUID: RigAffine] {
        guard bones.count <= 128 else { return [:] }
        let nodes = Dictionary(bones.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func evaluate(_ turns: [UUID: Double] = [:], stretch: [UUID: Double] = [:]) -> [UUID: RigAffine] {
            var results: [UUID: RigAffine] = [:]
            var visiting = Set<UUID>()
            func world(_ id: UUID) -> RigAffine {
                if let found = results[id] { return found }
                guard let bone = nodes[id], visiting.insert(id).inserted else { return .identity }
                defer { visiting.remove(id) }
                let parent = bone.parentID.map(world) ?? .identity
                let degrees = (bone.rotation?.value(at: time) ?? 0) + (turns[id] ?? 0)
                let offset = bone.offset?.value(at: time) ?? .zero
                let angle = degrees * .pi / 180
                let factor = stretch[id] ?? 1
                let c = cos(angle) * factor, s = sin(angle) * factor
                let rotation = simd_double3x3(columns: (SIMD3(c,s,0), SIMD3(-s,c,0), SIMD3(0,0,1)))
                let matrix = parent.matrix * Self.translation(bone.start + offset) * rotation * Self.translation(bone.start * -1)
                let frame = RigAffine(matrix)
                results[id] = frame.isFinite ? frame : .identity
                return results[id] ?? .identity
            }
            for bone in bones { _ = world(bone.id) }
            return results
        }

        var frames = evaluate()
        guard solveIK, let constraints, !constraints.isEmpty else { return frames }
        // Solve ancestors first so a linked limb starts from the already-posed shoulder or hip.
        func depth(_ id: UUID) -> Int {
            var current = nodes[id]?.parentID
            var count = 0
            while let parent = current, count < nodes.count {
                count += 1
                current = nodes[parent]?.parentID
            }
            return count
        }
        var turns: [UUID: Double] = [:], stretch: [UUID: Double] = [:]
        for ik in constraints.sorted(by: { depth($0.tipBoneID) < depth($1.tipBoneID) }) {
            guard let lower = nodes[ik.tipBoneID], let upperID = lower.parentID,
                  let upper = nodes[upperID], let upperFrame = frames[upperID], let lowerFrame = frames[lower.id],
                  let solution = Self.solve(ik, at: time, upper: upper, lower: lower,
                                            upperFrame: upperFrame, lowerFrame: lowerFrame) else { continue }
            turns[upperID] = solution.upper
            turns[lower.id] = solution.lower
            stretch[upperID] = solution.stretch
            frames = evaluate(turns, stretch: stretch)
        }
        return frames
    }

    private static func solve(_ ik: ArtworkIK, at time: Double, upper: ArtworkBone, lower: ArtworkBone,
                              upperFrame: RigAffine, lowerFrame: RigAffine) -> (upper: Double, lower: Double, stretch: Double)? {
        let mix = min(1, max(0, ik.mix.value(at: time) / 100))
        let origin = upperFrame.apply(upper.start), elbow = lowerFrame.apply(lower.start), tip = lowerFrame.apply(lower.end)
        let target = ik.target.value(at: time)
        let d = target - origin
        let goal = hypot(d.x, d.y)
        let l1 = hypot(elbow.x - origin.x, elbow.y - origin.y)
        let l2 = hypot(tip.x - elbow.x, tip.y - elbow.y)
        guard mix.isFinite, mix > 0, goal.isFinite, goal > 1e-6, min(l1,l2) >= 0.1 else { return nil }
        let maxStretch = ik.stretchLimit.isFinite ? min(2, max(1, ik.stretchLimit)) : 1
        let scale = min(maxStretch, max(1, goal / (l1 + l2)))
        let a = l1 * scale, b = l2 * scale
        let reach = min(a + b, max(abs(a - b), goal))
        let bearing = atan2(d.y, d.x)
        let bend = acos(min(1, max(-1, (a*a + reach*reach - b*b) / (2*a*reach))))
        let upperAngle = bearing + (ik.flipped ? -bend : bend)
        let joint = origin + Vec2(cos(upperAngle), sin(upperAngle)) * a
        let end = origin + Vec2(cos(bearing), sin(bearing)) * reach
        let lowerAngle = atan2(end.y - joint.y, end.x - joint.x)
        func turn(_ difference: Double) -> Double { atan2(sin(difference), cos(difference)) * 180 / .pi * mix }
        let upperDelta = upperAngle - atan2(elbow.y - origin.y, elbow.x - origin.x)
        let lowerDelta = lowerAngle - atan2(tip.y - elbow.y, tip.x - elbow.x) - upperDelta
        return (turn(upperDelta), turn(lowerDelta), 1 + (scale - 1) * mix)
    }

    static func translation(_ p: Vec2) -> simd_double3x3 {
        simd_double3x3(columns: (SIMD3(1,0,0), SIMD3(0,1,0), SIMD3(p.x,p.y,1)))
    }

    mutating func traverse(_ visitor: inout AnimationTraversal) {
        for i in bones.indices {
            visitor.apply(&bones[i].rotation)
            visitor.apply(&bones[i].offset)
        }
        if var items = constraints {
            for index in items.indices {
                visitor.apply(&items[index].target)
                visitor.apply(&items[index].mix)
            }
            constraints = items
        }
    }
}
