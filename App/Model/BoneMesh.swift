import Foundation
import simd

/// Affine storage stays portable in projects; Metal receives a packed float palette at render time.
struct RigAffine: Codable, Equatable {
    var a: Double; var b: Double; var c: Double; var d: Double; var x: Double; var y: Double
    init(_ m: simd_double3x3) { a = m[0].x; b = m[0].y; c = m[1].x; d = m[1].y; x = m[2].x; y = m[2].y }
    var matrix: simd_double3x3 { simd_double3x3(columns: (SIMD3(a,b,0), SIMD3(c,d,0), SIMD3(x,y,1))) }
    var isFinite: Bool { [a,b,c,d,x,y].allSatisfy(\.isFinite) }
    static let identity = RigAffine(matrix_identity_double3x3)
    func apply(_ p: Vec2) -> Vec2 { Vec2(a*p.x + c*p.y + x, b*p.x + d*p.y + y) }
}

struct BoneMeshWeight: Codable, Equatable {
    var bone: Int
    var amount: Double
}

struct BoneMeshVertex: Codable, Equatable {
    var rest: Vec2
    var weights: [BoneMeshWeight]
}

struct BoneMeshSource {
    var id: UUID
    var matrix: simd_double3x3
    var tip: Vec2
}

/// A frame source is shared by every binding in the frame. Mesh fields are stripped to avoid recursive snapshots.
final class BoneMeshFrameSource {
    let project: Project
    init(_ original: Project) {
        var copy = original
        for i in copy.layers.indices { copy.layers[i].boneMesh = nil }
        if copy.parentContext != nil { for i in copy.parentContext!.indices { copy.parentContext![i].boneMesh = nil } }
        copy.precomps = []; copy.precompList = []
        project = copy
    }
}

enum BoneMeshCoverage: String, Codable, CaseIterable {
    case localized = "Near bones"
    case wholeArtwork = "Whole artwork"
}

/// Bind topology and weights are document data. Evaluated poses are transient and never serialized.
struct BoneMeshBinding: Codable, Equatable {
    var id = UUID()
    var revision = UUID()
    var halfSize: Vec2
    var columns: Int
    var rows: Int
    var boneIDs: [UUID]
    var inverseBinds: [RigAffine]
    var vertices: [BoneMeshVertex]
    var indices: [UInt32]
    var amount: Double? = nil
    var radius: Double? = nil
    var coverage: BoneMeshCoverage? = nil
    var lockedBoneIDs: [UUID]? = nil
    var previewWeightIndex: Int? = nil
    var frameMatrices: [RigAffine]? = nil
    var frameTime: Double? = nil
    var frameSource: BoneMeshFrameSource? = nil

    private enum CodingKeys: String, CodingKey { case id, revision, halfSize, columns, rows, boneIDs, inverseBinds, vertices, indices, lockedBoneIDs, amount, radius, coverage }
    static func == (a: Self, b: Self) -> Bool {
        a.id == b.id && a.revision == b.revision && a.halfSize == b.halfSize && a.columns == b.columns && a.rows == b.rows
            && a.boneIDs == b.boneIDs && a.inverseBinds == b.inverseBinds && a.vertices == b.vertices && a.indices == b.indices && a.lockedBoneIDs == b.lockedBoneIDs && a.amount == b.amount && a.radius == b.radius && a.coverage == b.coverage
    }

    var isValid: Bool {
        guard halfSize.x.isFinite, halfSize.y.isFinite, halfSize.x > 0, halfSize.y > 0,
              (1...128).contains(columns), (1...128).contains(rows),
              vertices.count == (columns+1)*(rows+1), indices.count == columns*rows*6,
              !boneIDs.isEmpty, boneIDs.count <= 512, Set(boneIDs).count == boneIDs.count,
              inverseBinds.count == boneIDs.count, inverseBinds.allSatisfy({ $0.isFinite }),
              indices.allSatisfy({ Int($0) < vertices.count }) else { return false }
        return vertices.allSatisfy { v in
            v.rest.x.isFinite && v.rest.y.isFinite && !v.weights.isEmpty && v.weights.count <= 4
                && v.weights.allSatisfy { boneIDs.indices.contains($0.bone) && $0.amount.isFinite && $0.amount >= 0 && $0.amount <= 1 }
                && Set(v.weights.map(\.bone)).count == v.weights.count
                && abs(v.weights.reduce(0, { $0 + $1.amount })-1) < 1e-5
        }
    }

    static func distanceSquared(_ p: Vec2, from a: Vec2, to b: Vec2) -> Double {
        let d = b-a, length = d.x*d.x + d.y*d.y
        let t = length > 1e-12 ? min(1, max(0, ((p.x-a.x)*d.x + (p.y-a.y)*d.y)/length)) : 0
        let q = p - (a + d*t)
        return q.x*q.x + q.y*q.y
    }

    /// Deterministic initial weights; editable weights remain the authority after binding.
    static func bind(halfSize: Vec2, detail: Int, bones: [BoneMeshSource]) -> Self? {
        guard halfSize.x.isFinite, halfSize.y.isFinite, halfSize.x > 0, halfSize.y > 0,
              max(halfSize.x, halfSize.y) <= 1e7, !bones.isEmpty, bones.count <= 512,
              Set(bones.map(\.id)).count == bones.count,
              bones.allSatisfy({ $0.matrix.determinant.isFinite && abs($0.matrix.determinant) > 1e-10 && RigAffine($0.matrix).isFinite && $0.tip.x.isFinite && $0.tip.y.isFinite }) else { return nil }
        let cells = min(128, max(4, detail)), longest = max(halfSize.x, halfSize.y)
        let columns = max(1, Int((Double(cells)*halfSize.x/longest).rounded()))
        let rows = max(1, Int((Double(cells)*halfSize.y/longest).rounded()))
        let floorDistance = pow(longest / Double(cells), 2)
        let segments = bones.map { (RigAffine($0.matrix).apply(.zero), RigAffine($0.matrix).apply($0.tip)) }
        var vertices: [BoneMeshVertex] = []; vertices.reserveCapacity((columns+1)*(rows+1))
        for j in 0...rows { for i in 0...columns {
            let rest = Vec2(-halfSize.x + 2*halfSize.x*Double(i)/Double(columns), -halfSize.y + 2*halfSize.y*Double(j)/Double(rows))
            var distances: [(index: Int, distance: Double)] = []
            distances.reserveCapacity(segments.count)
            for (index,segment) in segments.enumerated() {
                distances.append((index: index,distance: distanceSquared(rest,from: segment.0,to: segment.1)))
            }
            distances.sort { lhs,rhs in
                if lhs.distance == rhs.distance { return lhs.index < rhs.index }
                return lhs.distance < rhs.distance
            }
            let nearest = distances.prefix(4)
            let raw = nearest.map { BoneMeshWeight(bone: $0.index, amount: 1/max(floorDistance, $0.distance)) }
            let total = raw.reduce(0) { $0+$1.amount }
            guard total.isFinite, total > 0 else { return nil }
            vertices.append(BoneMeshVertex(rest: rest, weights: raw.map { BoneMeshWeight(bone: $0.bone, amount: $0.amount/total) }))
        } }
        var indices: [UInt32] = []; indices.reserveCapacity(columns*rows*6)
        for j in 0..<rows { for i in 0..<columns {
            let a = UInt32(j*(columns+1)+i), b = a+1, c = a+UInt32(columns+1), d = c+1
            indices += [a,b,c,b,d,c]
        } }
        return Self(halfSize: halfSize, columns: columns, rows: rows, boneIDs: bones.map(\.id),
                    inverseBinds: bones.map { RigAffine($0.matrix.inverse) }, vertices: vertices, indices: indices)
    }

    func deformed(_ vertex: BoneMeshVertex, matrices: [RigAffine]) -> Vec2 {
        var sum = Vec2.zero, total = 0.0
        for w in vertex.weights where matrices.indices.contains(w.bone) && w.amount.isFinite && w.amount > 0 {
            sum = sum + matrices[w.bone].apply(vertex.rest)*w.amount; total += w.amount
        }
        return total > 0 ? sum*(1/total) : vertex.rest
    }

    mutating func changed() { revision = UUID(); frameMatrices = nil; frameTime = nil; frameSource = nil }
}


extension BoneMeshBinding {
    /// Conservative bounds of a convex weighted blend: every skinned vertex lies inside this union.
    func reach(matrices: [RigAffine]) -> Vec2 {
        // Only influenced vertices contribute. An unused controller far off-screen must not allocate a giant
        // texture and downsample the visible artwork. Linear triangles attain their bounds at their vertices.
        var result = halfSize
        for vertex in vertices {
            let point = deformed(vertex,matrices: matrices)
            if point.x.isFinite && point.y.isFinite { result.x = max(result.x,abs(point.x)); result.y = max(result.y,abs(point.y)) }
        }
        return result
    }
}


enum BoneWeightBrush: String, CaseIterable, Identifiable {
    case paint = "Paint", erase = "Erase", smooth = "Smooth"
    var id: String { rawValue }
}

struct BoneWeightDab { var center: Vec2; var amount: Double }

extension BoneMeshBinding {
    /// Brush dabs are placed by distance, rather than event/frame rate. Locked influences retain their exact value.
    @discardableResult
    mutating func paint(_ dabs: [BoneWeightDab], selected: Int, radius: Double, mode: BoneWeightBrush, hardness: Double = 0) -> Bool {
        guard boneIDs.indices.contains(selected), radius.isFinite, radius > 0, !dabs.isEmpty,
              !(lockedBoneIDs ?? []).contains(boneIDs[selected]), isValid else { return false }
        let locked = Set((lockedBoneIDs ?? []).compactMap { boneIDs.firstIndex(of: $0) })
        let before = vertices, r2 = radius*radius
        var didChange = false
        for i in vertices.indices {
            let vertex = before[i]
            var flow = 0.0
            for dab in dabs where dab.amount.isFinite && dab.amount > 0 {
                let d = vertex.rest - dab.center, d2 = d.x*d.x + d.y*d.y
                if d2 < r2 {
                    let inner = min(0.95,max(0,hardness))
                    let edge = max(0,(sqrt(d2/r2)-inner)/(1-inner))
                    let falloff = pow(1-edge*edge,2)
                    flow = 1 - (1-flow)*(1-min(1,dab.amount)*falloff)
                }
            }
            guard flow > 1e-8 else { continue }
            let held = vertex.weights.filter { locked.contains($0.bone) && $0.amount > 0 }
            let room = max(0,1-held.reduce(0) { $0+$1.amount })
            let current = vertex.weights.first(where: { $0.bone == selected })?.amount ?? 0
            var desired: Double
            switch mode {
            case .paint: desired = current + (room-current)*flow
            case .erase: desired = current*(1-flow)
            case .smooth:
                let x = i%(columns+1), y = i/(columns+1)
                var neighbours: [Int] = []
                if x > 0 { neighbours.append(i-1) }; if x < columns { neighbours.append(i+1) }
                if y > 0 { neighbours.append(i-columns-1) }; if y < rows { neighbours.append(i+columns+1) }
                let average = neighbours.reduce(0.0) { $0+(before[$1].weights.first(where: { $0.bone == selected })?.amount ?? 0) }/Double(max(1,neighbours.count))
                desired = current + (average-current)*flow
            }
            desired = min(room,max(0,desired))
            let slots = max(0,4-held.count-(desired > 0 ? 1 : 0))
            var other = vertex.weights.filter { $0.bone != selected && !locked.contains($0.bone) && $0.amount > 0 }
                .sorted { $0.amount == $1.amount ? $0.bone < $1.bone : $0.amount > $1.amount }
            other = Array(other.prefix(slots))
            if other.isEmpty, slots > 0, room > desired,
               let fallback = boneIDs.indices.first(where: { $0 != selected && !locked.contains($0) }) {
                other = [BoneMeshWeight(bone: fallback,amount: 1)]
            }
            if other.isEmpty { desired = room }
            let remaining = max(0,room-desired), total = other.reduce(0) { $0+$1.amount }
            var weights = held
            if desired > 0 { weights.append(BoneMeshWeight(bone: selected,amount: desired)) }
            if total > 0 && remaining > 0 { weights += other.map { BoneMeshWeight(bone: $0.bone,amount: $0.amount/total*remaining) } }
            weights.sort { $0.bone < $1.bone }
            if !weights.isEmpty && weights != vertex.weights { vertices[i].weights = weights; didChange = true }
        }
        if didChange { changed() }
        return didChange
    }
}


extension BoneMeshBinding {
    /// A cutout limb has no stationary background: every vertex follows its bound skeleton.
    static func wholeArtwork(halfSize: Vec2,detail: Int,artworkID: UUID,bones: [BoneMeshSource]) -> Self? {
        guard bones.count < 512,!bones.contains(where: { $0.id == artworkID }),
              var mesh = bind(halfSize: halfSize,detail: detail,bones: bones) else { return nil }
        mesh.boneIDs.insert(artworkID,at: 0); mesh.inverseBinds.insert(.identity,at: 0)
        for i in mesh.vertices.indices { for j in mesh.vertices[i].weights.indices { mesh.vertices[i].weights[j].bone += 1 } }
        mesh.coverage = .wholeArtwork
        return mesh
    }

    static func localized(halfSize: Vec2,detail: Int,artworkID: UUID,bones: [BoneMeshSource],radius: Double) -> Self? {
        guard radius.isFinite,radius>0,!bones.isEmpty,bones.count < 512,
              !bones.contains(where: { $0.id == artworkID }),
              var mesh = bind(halfSize: halfSize,detail: detail,bones: bones) else { return nil }
        let segments = bones.map { (RigAffine($0.matrix).apply(.zero),RigAffine($0.matrix).apply($0.tip)) }
        mesh.boneIDs.insert(artworkID,at: 0); mesh.inverseBinds.insert(.identity,at: 0)
        mesh.radius = radius; mesh.coverage = .localized
        for i in mesh.vertices.indices {
            let point = mesh.vertices[i].rest
            var values: [BoneMeshWeight] = []
            for (bone,segment) in segments.enumerated() {
                let distance = distanceSquared(point,from: segment.0,to: segment.1)
                if distance < radius*radius {
                    let weight = pow(1-distance/(radius*radius),3)
                    values.append(BoneMeshWeight(bone: bone+1,amount: weight))
                }
            }
            values.sort { $0.amount == $1.amount ? $0.bone<$1.bone : $0.amount>$1.amount }
            let strongest = values.first?.amount ?? 0
            values = Array(values.prefix(strongest < 0.999 ? 3 : 4))
            if strongest < 0.999 { values.append(BoneMeshWeight(bone: 0,amount: 1-strongest)) }
            let total = values.reduce(0.0) { $0+$1.amount }
            mesh.vertices[i].weights = values.map { BoneMeshWeight(bone: $0.bone,amount: $0.amount/max(total,1e-12)) }
        }
        return mesh
    }
}
