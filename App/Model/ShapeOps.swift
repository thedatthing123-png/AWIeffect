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

struct ShapeOps: Codable, Equatable {
    var repeater: RepeaterOp? = nil
    var offset: Animated<Double>? = nil     // px (+ grows, - shrinks)
    var wiggle: WiggleOp? = nil
    var zigzag: ZigZagOp? = nil
    var pucker: Animated<Double>? = nil     // % (- pucker, + bloat)

    var changesGeometry: Bool { offset != nil || wiggle != nil || zigzag != nil || pucker != nil }
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
    /// Applies the geometry operators (in AE order: pucker, offset, zig zag, wiggle).
    static func apply(_ ops: ShapeOps, to base: BezierPath, time t: Double) -> BezierPath {
        guard ops.changesGeometry else { return base }
        var p = base
        if let pk = ops.pucker {
            let amt = pk.value(at: t) / 100
            let c = p.vertices.reduce(Vec2.zero) { $0 + $1.point } * (1 / Double(max(1, p.vertices.count)))
            for i in p.vertices.indices {
                // Pucker pulls points in and pushes curve handles out (and the reverse for bloat).
                p.vertices[i].point = p.vertices[i].point + (c - p.vertices[i].point) * (-amt)
                let tangentPush = (p.vertices[i].point - c) * (amt * 0.5)
                p.vertices[i].outTangent = p.vertices[i].outTangent + tangentPush
                p.vertices[i].inTangent = p.vertices[i].inTangent + tangentPush
            }
        }
        if ops.offset != nil || ops.zigzag != nil || ops.wiggle != nil { p = p.flattened() }
        if let off = ops.offset {
            let d = off.value(at: t)
            let normals = p.vertices.indices.map { p.normal(at: $0) }
            for i in p.vertices.indices { p.vertices[i].point = p.vertices[i].point + normals[i] * d }
        }
        if let z = ops.zigzag {
            let size = z.size.value(at: t), ridges = max(1, Int(z.ridges.value(at: t).rounded()))
            var out: [PathVertex] = []
            let n = p.vertices.count, count = p.closed ? n : n - 1
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
            p = BezierPath(vertices: out, closed: p.closed)
        }
        if let w = ops.wiggle {
            let size = w.size.value(at: t), detail = max(0, Int(w.detail.value(at: t).rounded())), speed = w.speed.value(at: t)
            if detail > 0 {
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
