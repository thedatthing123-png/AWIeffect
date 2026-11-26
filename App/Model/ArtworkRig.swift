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
    var rootBoneID: UUID? = nil
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
        constraints = constraints?.filter { item in
            item.rootBoneID == nil || !chain(for: item).isEmpty
        }
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

    func validIKRoots(for tip: UUID) -> [ArtworkBone] {
        var options: [ArtworkBone] = []
        let occupied = Set((constraints ?? []).flatMap { chain(for: $0).map(\.id) })
        guard var current = bones.first(where: { $0.id == tip }), !occupied.contains(tip) else { return [] }
        var seen = Set([tip])
        while let id = current.parentID, seen.insert(id).inserted,
              let parent = bones.first(where: { $0.id == id }),
              !occupied.contains(id), current.length >= 0.1, parent.length >= 0.1,
              hypot(parent.end.x - current.start.x, parent.end.y - current.start.y) < 1 {
            options.append(parent)
            current = parent
        }
        return options
    }

    private func chain(for ik: ArtworkIK) -> [ArtworkBone] {
        let index = Dictionary(bones.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard var current = index[ik.tipBoneID], let root = ik.rootBoneID ?? current.parentID else { return [] }
        var members = [current], seen = Set([current.id])
        while let id = current.parentID, seen.insert(id).inserted, let parent = index[id],
              hypot(parent.end.x - current.start.x, parent.end.y - current.start.y) < 1 {
            members.append(parent)
            if id == root { return Array(members.reversed()) }
            current = parent
        }
        return []
    }

    mutating func enableIK(on lowerID: UUID, root rootID: UUID? = nil, time: Double) -> Bool {
        let roots = validIKRoots(for: lowerID)
        guard let upper = rootID.flatMap({ id in roots.first { $0.id == id } }) ?? (rootID == nil ? roots.first : nil),
              let lower = bones.first(where: { $0.id == lowerID }) else { return false }
        var item = ArtworkIK(tipBoneID: lowerID, rootBoneID: upper.id, target: Animated(Vec2.zero))
        let members = chain(for: item)
        guard members.count >= 2 else { return false }
        let frames = pose(at: time)
        let target = (frames[lowerID] ?? .identity).apply(lower.end)
        let origin = (frames[upper.id] ?? .identity).apply(upper.start)
        let elbow = (frames[members[1].id] ?? .identity).apply(members[1].start) - origin
        let direction = target - origin
        item.target = Animated(target)
        item.flipped = direction.x * elbow.y - direction.y * elbow.x < 0
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
        let chains = constraints.map { ($0, chain(for: $0)) }.sorted {
            depth($0.1.first?.id ?? $0.0.tipBoneID) < depth($1.1.first?.id ?? $1.0.tipBoneID)
        }
        for (ik, members) in chains {
            guard let upper = members.first, let lower = members.last, members.count >= 2,
                  let upperFrame = frames[upper.id], let lowerFrame = frames[lower.id] else { continue }
            if members.count == 2 {
                guard let solution = Self.solve(ik, at: time, upper: upper, lower: lower,
                                                upperFrame: upperFrame, lowerFrame: lowerFrame) else { continue }
                turns[upper.id] = solution.upper
                turns[lower.id] = solution.lower
                stretch[upper.id] = solution.stretch
            } else if let solution = Self.solveChain(ik, at: time, members: members, frames: frames) {
                for (bone, turn) in zip(members, solution.turns) { turns[bone.id] = turn }
                stretch[upper.id] = solution.stretch
            }
            frames = evaluate(turns, stretch: stretch)
        }
        return frames
    }

    /// Forward and backward reaching, seeded from FK so existing bends guide the solution.
    private static func solveChain(_ ik: ArtworkIK, at time: Double, members: [ArtworkBone],
                                   frames: [UUID: RigAffine]) -> (turns: [Double], stretch: Double)? {
        guard let tip = members.last else { return nil }
        let rest = members.map { (frames[$0.id] ?? .identity).apply($0.start) }
            + [(frames[tip.id] ?? .identity).apply(tip.end)]
        let origin = rest[0], end = rest.count - 1, target = ik.target.value(at: time)
        func length(_ p: Vec2) -> Double { hypot(p.x, p.y) }
        func unit(_ p: Vec2, fallback: Vec2) -> Vec2 {
            let distance = length(p)
            return distance > 1e-8 ? p * (1 / distance) : fallback
        }
        let mix = min(1, max(0, ik.mix.value(at: time) / 100))
        let distance = length(target - origin)
        let vectors = (0..<end).map { rest[$0 + 1] - rest[$0] }
        let sizes = vectors.map(length)
        let total = sizes.reduce(0, +)
        guard distance.isFinite, mix.isFinite, mix > 0, sizes.allSatisfy({ $0.isFinite && $0 >= 0.1 }),
              length(rest[end] - target) > 1e-7 else { return nil }
        let limit = ik.stretchLimit.isFinite ? min(2, max(1, ik.stretchLimit)) : 1
        let scale = min(limit, max(1, distance / total))
        let axis = unit(target - origin, fallback: unit(rest[end] - origin, fallback: Vec2(1, 0)))
        let normal = Vec2(-axis.y, axis.x)
        let sign = ik.flipped ? -1.0 : 1.0
        var points = rest
        if distance >= total * scale {
            for i in 0..<end { points[i + 1] = points[i] + axis * (sizes[i] * scale) }
        } else {
            for i in 1..<end {
                let p = rest[i] - origin
                let along = p.x * axis.x + p.y * axis.y
                let off = p.x * normal.x + p.y * normal.y
                // Seed straight chains off-axis so a shorter target can bend them.
                let seed = max(abs(off), total * 0.02 * sin(.pi * Double(i) / Double(end)))
                points[i] = origin + axis * along + normal * (sign * seed)
            }
            for _ in 0..<24 {
                points[end] = target
                for i in (0..<end).reversed() {
                    points[i] = points[i + 1] + unit(points[i] - points[i + 1], fallback: axis * -1) * (sizes[i] * scale)
                }
                points[0] = origin
                for i in 0..<end {
                    points[i + 1] = points[i] + unit(points[i + 1] - points[i], fallback: axis) * (sizes[i] * scale)
                }
                if length(points[end] - target) < 0.05 { break }
            }
        }
        var previous = 0.0
        var turns: [Double] = []
        for i in 0..<end {
            let vector = points[i + 1] - points[i]
            let turn = atan2(vector.y, vector.x) - atan2(vectors[i].y, vectors[i].x)
            let local = turn - previous
            turns.append(atan2(sin(local), cos(local)) * 180 / .pi * mix)
            previous = turn
        }
        return (turns, 1 + (scale - 1) * mix)
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
