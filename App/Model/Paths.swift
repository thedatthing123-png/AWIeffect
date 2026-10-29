import Foundation

/// One bezier vertex. Tangents are relative to the point (AE/Lottie convention).
struct PathVertex: Codable, Equatable {
    var point: Vec2
    var inTangent: Vec2 = .zero
    var outTangent: Vec2 = .zero
}

/// A cubic bezier path in layer-local pixels (origin = layer center). Animatable when vertex counts match.
struct BezierPath: Interpolatable {
    var vertices: [PathVertex]
    var closed: Bool = true

    static func lerp(_ a: BezierPath, _ b: BezierPath, _ t: Double) -> BezierPath {
        guard a.vertices.count == b.vertices.count else { return t < 0.5 ? a : b }
        let v = zip(a.vertices, b.vertices).map { x, y in
            PathVertex(point: .lerp(x.point, y.point, t), inTangent: .lerp(x.inTangent, y.inTangent, t),
                       outTangent: .lerp(x.outTangent, y.outTangent, t))
        }
        return BezierPath(vertices: v, closed: t < 0.5 ? a.closed : b.closed)
    }

    /// Flattens to line segments (x0, y0, x1, y1) for GPU rasterization.
    func segments(stepsPerCurve: Int = 16) -> [SIMD4<Float>] {
        guard vertices.count >= 2 else { return [] }
        var out: [SIMD4<Float>] = []
        let n = vertices.count
        let count = closed ? n : n - 1
        for i in 0..<count {
            let a = vertices[i], b = vertices[(i + 1) % n]
            let p0 = a.point, p1 = a.point + a.outTangent, p2 = b.point + b.inTangent, p3 = b.point
            let straight = a.outTangent == .zero && b.inTangent == .zero
            let steps = straight ? 1 : stepsPerCurve
            var prev = p0
            for s in 1...steps {
                let t = Double(s) / Double(steps), u = 1 - t
                let q = p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
                out.append(SIMD4(Float(prev.x), Float(prev.y), Float(q.x), Float(q.y)))
                prev = q
            }
        }
        return out
    }

    var bounds: (min: Vec2, max: Vec2) {
        var lo = Vec2(.infinity, .infinity), hi = Vec2(-.infinity, -.infinity)
        for s in segments(stepsPerCurve: 8) {
            lo = Vec2(min(lo.x, Double(min(s.x, s.z))), min(lo.y, Double(min(s.y, s.w))))
            hi = Vec2(max(hi.x, Double(max(s.x, s.z))), max(hi.y, Double(max(s.y, s.w))))
        }
        if !lo.x.isFinite { return (.zero, .zero) }
        return (lo, hi)
    }

    // MARK: Builders

    /// Bezier circle/ellipse (4 vertices, kappa tangents).
    static func ellipse(size: Vec2) -> BezierPath {
        let rx = size.x / 2, ry = size.y / 2, k = 0.5522847498
        return BezierPath(vertices: [
            PathVertex(point: Vec2(0, -ry), inTangent: Vec2(-rx * k, 0), outTangent: Vec2(rx * k, 0)),
            PathVertex(point: Vec2(rx, 0), inTangent: Vec2(0, -ry * k), outTangent: Vec2(0, ry * k)),
            PathVertex(point: Vec2(0, ry), inTangent: Vec2(rx * k, 0), outTangent: Vec2(-rx * k, 0)),
            PathVertex(point: Vec2(-rx, 0), inTangent: Vec2(0, ry * k), outTangent: Vec2(0, -ry * k)),
        ])
    }

    static func rectangle(size: Vec2) -> BezierPath {
        let x = size.x / 2, y = size.y / 2
        return BezierPath(vertices: [Vec2(-x, -y), Vec2(x, -y), Vec2(x, y), Vec2(-x, y)].map { PathVertex(point: $0) })
    }

    /// Smooths freehand points into a bezier path (Catmull-Rom -> bezier).
    static func smoothed(_ pts: [Vec2], closed: Bool, tolerance: Double = 3) -> BezierPath {
        // Drop points closer than `tolerance` to keep the path light.
        var p: [Vec2] = []
        for q in pts where p.last.map({ hypot($0.x - q.x, $0.y - q.y) >= tolerance }) ?? true { p.append(q) }
        guard p.count >= 2 else { return BezierPath(vertices: p.map { PathVertex(point: $0) }, closed: closed) }
        var v: [PathVertex] = []
        let n = p.count
        for i in 0..<n {
            let prev = p[closed ? (i - 1 + n) % n : max(0, i - 1)]
            let next = p[closed ? (i + 1) % n : min(n - 1, i + 1)]
            let t = (next - prev) * (1.0 / 6.0)
            v.append(PathVertex(point: p[i], inTangent: t * -1, outTangent: t))
        }
        return BezierPath(vertices: v, closed: closed)
    }
}

enum MaskMode: String, Codable, CaseIterable, Identifiable {
    case add, subtract, intersect, lighten, darken, difference, none
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var shaderIndex: UInt32 { UInt32(Self.allCases.firstIndex(of: self)!) }
}

struct LayerMask: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String = "Mask"
    var path: Animated<BezierPath>
    var mode: MaskMode = .add
    var inverted = false
    var feather = Animated(0.0)       // px
    var opacity = Animated(100.0)     // %
    var expansion = Animated(0.0)     // px
}

/// Stroke for shape/path layers.
struct ShapeStroke: Codable, Equatable {
    var enabled = false
    var color = Animated(RGBA.white)
    var width = Animated(8.0)
    /// Trim Paths (AE "ADBE Vector Filter - Trim"): start/end in %, offset in degrees.
    var trimStart = Animated(0.0)
    var trimEnd = Animated(100.0)
    var trimOffset = Animated(0.0)
}
