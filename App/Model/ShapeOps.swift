import Foundation
import simd

/// AE shape-layer operators for shape layers: Repeater, Offset Paths, Wiggle Paths, Zig Zag, Pucker & Bloat.
/// Each is optional and animatable; they work on every shape kind (primitives are turned into paths first).
struct RepeaterOp: Codable, Equatable {
    var copies = Animated(3.0)
    var position = Animated(Vec2(100, 0))   // px offset per copy
    var scale = Animated(Vec2(100, 100))    // % per copy (compounds)
    var rotation = Animated(0.0)            // ° per copy
    var startOpacity = Animated(100.0)      // first copy %
    var endOpacity = Animated(100.0)        // last copy %
}

struct WiggleOp: Codable, Equatable {
    var size = Animated(10.0)               // px
    var detail = Animated(4.0)              // points added per segment
    var speed = Animated(2.0)               // wiggles / s
    var seed = 1.0
}

struct ZigZagOp: Codable, Equatable {
    var size = Animated(10.0)               // px
    var ridges = Animated(5.0)              // per segment
    var smooth = false
}

/// Twist: rotates the path more at the centre than at the edges (AE "Twist").
struct TwistOp: Codable, Equatable {
    var angle = Animated(90.0)              // ° at the centre
    var center = Animated(Vec2(0, 0))       // layer px
}

/// The geometry operators, in the order a stack can run them. Repeater always runs last (it copies the result).
enum ShapeOpKind: String, Codable, CaseIterable, Identifiable {
    case pucker, roundCorners, offset, zigzag, twist, wiggle
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pucker: return "Pucker & Bloat"
        case .roundCorners: return "Round Corners"
        case .offset: return "Offset Paths"
        case .zigzag: return "Zig Zag"
        case .twist: return "Twist"
        case .wiggle: return "Wiggle Paths"
        }
    }
    /// Works on straight segments (the path is flattened once before the first of these).
    var flattens: Bool { self == .offset || self == .zigzag || self == .wiggle || self == .twist }
}

struct ShapeOps: Codable, Equatable {
    var repeater: RepeaterOp? = nil
    var offset: Animated<Double>? = nil     // px (+ grows, - shrinks)
    var wiggle: WiggleOp? = nil
    var zigzag: ZigZagOp? = nil
    var pucker: Animated<Double>? = nil     // % (- pucker, + bloat)
    /// R2 additions (nil in older projects).
    var roundCorners: Animated<Double>? = nil   // px radius
    var twist: TwistOp? = nil
    /// User order of the geometry operators (nil = the classic AE order).
    var order: [ShapeOpKind]? = nil

    static let defaultOrder: [ShapeOpKind] = [.pucker, .roundCorners, .offset, .zigzag, .twist, .wiggle]

    func has(_ k: ShapeOpKind) -> Bool {
        switch k {
        case .pucker: return pucker != nil
        case .roundCorners: return roundCorners != nil
        case .offset: return offset != nil
        case .zigzag: return zigzag != nil
        case .twist: return twist != nil
        case .wiggle: return wiggle != nil
        }
    }

    /// Operators that are on, in the order they run (every kind exactly once).
    var activeOrder: [ShapeOpKind] {
        var seen = Set<ShapeOpKind>()
        var out: [ShapeOpKind] = []
        for k in (order ?? []) + Self.defaultOrder where !seen.contains(k) { seen.insert(k); out.append(k) }
        return out.filter(has)
    }

    /// Moves an active operator one step earlier (-1) or later (+1) in the stack.
    mutating func move(_ k: ShapeOpKind, by d: Int) {
        var list = activeOrder
        guard let i = list.firstIndex(of: k) else { return }
        let j = i + d
        guard list.indices.contains(j) else { return }
        list.swapAt(i, j)
        // Inactive kinds keep their slot after the active ones (turning them on later appends them in classic order).
        order = list + Self.defaultOrder.filter { !list.contains($0) }
    }

    mutating func setEnabled(_ k: ShapeOpKind, _ on: Bool) {
        switch k {
        case .pucker: pucker = on ? (pucker ?? Animated(30)) : nil
        case .roundCorners: roundCorners = on ? (roundCorners ?? Animated(20)) : nil
        case .offset: offset = on ? (offset ?? Animated(10)) : nil
        case .zigzag: zigzag = on ? (zigzag ?? ZigZagOp()) : nil
        case .twist: twist = on ? (twist ?? TwistOp()) : nil
        case .wiggle: wiggle = on ? (wiggle ?? WiggleOp()) : nil
        }
        if on, var o = order, !o.contains(k) { o.append(k); order = o }
    }

    var changesGeometry: Bool { ShapeOpKind.allCases.contains(where: has) }
    var isEmpty: Bool { !changesGeometry && repeater == nil }
}

extension BezierPath {
    /// Regular polygon / star (outer radius = half the size; `inner` = inner radius ratio for stars, nil = polygon).
    static func polygon(size: Vec2, sides: Int, inner: Double?) -> BezierPath {
        let n = max(3, sides)
        let count = inner == nil ? n : n * 2
        var v: [PathVertex] = []
        for i in 0..<count {
            let a = -Double.pi / 2 + Double(i) * 2 * .pi / Double(count)
            let r = (inner != nil && i % 2 == 1) ? inner! : 1
            v.append(PathVertex(point: Vec2(cos(a) * size.x / 2 * r, sin(a) * size.y / 2 * r)))
        }
        return BezierPath(vertices: v, closed: true)
    }

    /// Flattened to straight segments (so geometry operators work on any curve).
    func flattened(steps: Int = 8) -> BezierPath {
        let segs = segments(stepsPerCurve: steps)
        guard !segs.isEmpty else { return self }
        var pts = segs.map { PathVertex(point: Vec2(Double($0.x), Double($0.y))) }
        if !closed, let last = segs.last { pts.append(PathVertex(point: Vec2(Double(last.z), Double(last.w)))) }
        return BezierPath(vertices: pts, closed: closed)
    }

    /// Outward normal at vertex i (average of neighbouring edges; y-down, clockwise paths point outward).
    func normal(at i: Int) -> Vec2 {
        let n = vertices.count
        guard n >= 2 else { return .zero }
        let p = vertices[i].point
        let a = vertices[closed ? (i - 1 + n) % n : max(0, i - 1)].point
        let b = vertices[closed ? (i + 1) % n : min(n - 1, i + 1)].point
        let d = b - a
        let len = max(1e-9, hypot(d.x, d.y))
        var nrm = Vec2(d.y / len, -d.x / len)
        // Point away from the centroid so "+" always grows the shape.
        let c = vertices.reduce(Vec2.zero) { $0 + $1.point } * (1 / Double(n))
        if (p.x - c.x) * nrm.x + (p.y - c.y) * nrm.y < 0 { nrm = nrm * -1 }
        return nrm
    }
}

enum ShapeOpsMath {
    /// Applies the geometry operators in the stack's order (classic AE order: pucker, offset, zig zag, wiggle).
    static func apply(_ ops: ShapeOps, to base: BezierPath, time t: Double) -> BezierPath {
        guard ops.changesGeometry else { return base }
        var p = base
        var flat = false
        for k in ops.activeOrder {
            // Flatten once, before the first straight-segment operator (as before, so old projects look the same).
            if k.flattens, !flat { p = p.flattened(); flat = true }
            switch k {
            case .pucker: if let pk = ops.pucker { p = pucker(p, amount: pk.value(at: t)) }
            case .roundCorners: if let r = ops.roundCorners { p = roundCorners(p, radius: r.value(at: t)) }
            case .offset: if let off = ops.offset { p = offset(p, by: off.value(at: t)) }
            case .zigzag: if let z = ops.zigzag { p = zigzag(p, z, time: t) }
            case .twist: if let tw = ops.twist { p = twist(p, angle: tw.angle.value(at: t), center: tw.center.value(at: t)) }
            case .wiggle: if let w = ops.wiggle { p = wiggle(p, w, time: t) }
            }
        }
        return p
    }

    static func pucker(_ base: BezierPath, amount: Double) -> BezierPath {
        var p = base
        let amt = amount / 100
        let c = p.vertices.reduce(Vec2.zero) { $0 + $1.point } * (1 / Double(max(1, p.vertices.count)))
        for i in p.vertices.indices {
            // Pucker pulls points in and pushes curve handles out (and the reverse for bloat).
            p.vertices[i].point = p.vertices[i].point + (c - p.vertices[i].point) * (-amt)
            let tangentPush = (p.vertices[i].point - c) * (amt * 0.5)
            p.vertices[i].outTangent = p.vertices[i].outTangent + tangentPush
            p.vertices[i].inTangent = p.vertices[i].inTangent + tangentPush
        }
        return p
    }

    static func offset(_ base: BezierPath, by d: Double) -> BezierPath {
        var p = base
        let normals = p.vertices.indices.map { p.normal(at: $0) }
        for i in p.vertices.indices { p.vertices[i].point = p.vertices[i].point + normals[i] * d }
        return p
    }

    static func zigzag(_ p: BezierPath, _ z: ZigZagOp, time t: Double) -> BezierPath {
        let size = z.size.value(at: t), ridges = max(1, Int(z.ridges.value(at: t).rounded()))
        var out: [PathVertex] = []
        let n = p.vertices.count, count = p.closed ? n : n - 1
        guard n > 1 else { return p }
        var k = 0
        for i in 0..<count {
            let a = p.vertices[i].point, b = p.vertices[(i + 1) % n].point
            let d = b - a, len = max(1e-9, hypot(d.x, d.y))
            let nrm = Vec2(d.y / len, -d.x / len)
            for s in 0..<(ridges * 2) {
                let f = Double(s) / Double(ridges * 2)
                out.append(PathVertex(point: a + d * f + nrm * (k % 2 == 0 ? 0 : size)))
                k += 1
            }
        }
        if !p.closed, let last = p.vertices.last { out.append(last) }
        return BezierPath(vertices: out, closed: p.closed)
    }

    static func wiggle(_ base: BezierPath, _ w: WiggleOp, time t: Double) -> BezierPath {
        var p = base
        let size = w.size.value(at: t), detail = max(0, Int(w.detail.value(at: t).rounded())), speed = w.speed.value(at: t)
        if detail > 0, p.vertices.count > 1 {
            var out: [PathVertex] = []
            let n = p.vertices.count, count = p.closed ? n : n - 1
            for i in 0..<count {
                let a = p.vertices[i].point, b = p.vertices[(i + 1) % n].point
                for s in 0...detail { out.append(PathVertex(point: a + (b - a) * (Double(s) / Double(detail + 1)))) }
            }
            if !p.closed, let last = p.vertices.last { out.append(last) }
            p = BezierPath(vertices: out, closed: p.closed)
        }
        for i in p.vertices.indices {
            let dx = Wiggle.value(t: t, freq: max(0.01, speed), octaves: 1, seed: w.seed * 17 + Double(i) * 3.1)
            let dy = Wiggle.value(t: t, freq: max(0.01, speed), octaves: 1, seed: w.seed * 29 + Double(i) * 5.7)
            p.vertices[i].point = p.vertices[i].point + Vec2(dx, dy) * size
        }
        return p
    }

    /// Round Corners: every sharp point (no curve handles) becomes a circular-ish arc of `radius` px,
    /// clamped to half of each neighbouring edge. Curved points and open ends stay as they are.
    static func roundCorners(_ p: BezierPath, radius: Double) -> BezierPath {
        let n = p.vertices.count
        guard radius > 0.01, n > 2 else { return p }
        let kappa = 0.5523
        var out: [PathVertex] = []
        for i in 0..<n {
            let v = p.vertices[i]
            let isEnd = !p.closed && (i == 0 || i == n - 1)
            guard !isEnd, v.inTangent == .zero, v.outTangent == .zero else { out.append(v); continue }
            let prev = p.vertices[(i - 1 + n) % n].point, next = p.vertices[(i + 1) % n].point
            let dp = prev - v.point, dn = next - v.point
            let lp = hypot(dp.x, dp.y), ln = hypot(dn.x, dn.y)
            guard lp > 1e-6, ln > 1e-6 else { out.append(v); continue }
            let r = min(radius, lp / 2, ln / 2)
            let a = v.point + dp * (r / lp), b = v.point + dn * (r / ln)
            out.append(PathVertex(point: a, inTangent: .zero, outTangent: (v.point - a) * kappa))
            out.append(PathVertex(point: b, inTangent: (v.point - b) * kappa, outTangent: .zero))
        }
        return BezierPath(vertices: out, closed: p.closed)
    }

    /// Twist about `center`: full `angle` at the centre, fading to none at the farthest point.
    static func twist(_ base: BezierPath, angle: Double, center c: Vec2) -> BezierPath {
        var p = base
        let maxR = p.vertices.reduce(0.0) { max($0, hypot($1.point.x - c.x, $1.point.y - c.y)) }
        guard maxR > 1e-6, abs(angle) > 1e-6 else { return p }
        for i in p.vertices.indices {
            let d = p.vertices[i].point - c
            let r = hypot(d.x, d.y)
            let a = angle * .pi / 180 * (1 - r / maxR)
            p.vertices[i].point = c + Vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a))
        }
        return p
    }

    /// Per-copy transform (layer-local, about the layer center) and opacity for the repeater.
    static func copies(_ r: RepeaterOp, time t: Double) -> [(simd_double3x3, Double)] {
        let n = max(1, min(200, Int(r.copies.value(at: t).rounded())))
        let pos = r.position.value(at: t), sc = r.scale.value(at: t), rot = r.rotation.value(at: t) * .pi / 180
        let o0 = r.startOpacity.value(at: t) / 100, o1 = r.endOpacity.value(at: t) / 100
        var out: [(simd_double3x3, Double)] = []
        var m = matrix_identity_double3x3
        let step = simd_double3x3(columns: (SIMD3(cos(rot) * sc.x / 100, sin(rot) * sc.x / 100, 0),
                                            SIMD3(-sin(rot) * sc.y / 100, cos(rot) * sc.y / 100, 0),
                                            SIMD3(pos.x, pos.y, 1)))
        for k in 0..<n {
            let f = n > 1 ? Double(k) / Double(n - 1) : 0
            out.append((m, max(0, min(1, o0 + (o1 - o0) * f))))
            m = m * step
        }
        return out
    }

    /// How far the copies reach beyond the base shape (keeps effects from cutting them off).
    static func reach(_ r: RepeaterOp, base: Vec2, time t: Double) -> Vec2 {
        var mx = base
        for (m, _) in copies(r, time: t) {
            for c in [Vec2(-base.x, -base.y), Vec2(base.x, -base.y), Vec2(base.x, base.y), Vec2(-base.x, base.y)] {
                let q = m * SIMD3(c.x, c.y, 1)
                mx = Vec2(max(mx.x, abs(q.x)), max(mx.y, abs(q.y)))
            }
        }
        return mx
    }
}
