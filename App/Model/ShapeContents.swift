import Foundation
import CoreGraphics
import simd

enum MergePathsMode: String, Codable, CaseIterable, Identifiable {
    case merge = "Merge", add = "Add", subtract = "Subtract", intersect = "Intersect", exclude = "Exclude"
    var id: String { rawValue }
}

enum ShapeTrimMode: String, Codable, CaseIterable, Identifiable {
    case simultaneous = "Simultaneously", individual = "Individually"
    var id: String { rawValue }
}

/// Coordinates are in path-local pixels, so gradients follow the path transform.
struct ShapeGradient: Codable, Equatable {
    var radial = false
    var start = Animated(Vec2(-100, 0))
    var end = Animated(Vec2(100, 0))
    var first = Animated(RGBA(hex: 0xB98CFF))
    var last = Animated(RGBA(hex: 0x38DCD0))
    mutating func traverse(_ v: inout AnimationTraversal) {
        v.apply(&start); v.apply(&end); v.apply(&first); v.apply(&last)
    }
}

/// A complete editable path, not a second layer. Primitive properties remain animated after migration.
struct ShapeComponent: Codable, Equatable {
    var kind: ShapeKind = .path
    var path = Animated(BezierPath(vertices: []))
    var size = Animated(Vec2(200, 200))
    var roundness = Animated(0.0)
    var sides = Animated(6.0)
    var innerRatio = Animated(0.45)
    var position = Animated(Vec2.zero)
    var scale = Animated(Vec2(100, 100))
    var rotation = Animated(0.0)
    var opacity = Animated(100.0)
    var fillOn = true
    var fill = Animated(RGBA(hex: 0x9B5CFF))
    var stroke = ShapeStroke()
    var fillGradient: ShapeGradient? = nil
    var strokeGradient: ShapeGradient? = nil
    var trimMode: ShapeTrimMode = .simultaneous
    var ops: ShapeOps? = nil

    func base(at t: Double) -> BezierPath {
        switch kind {
        case .path: return path.value(at: t)
        case .ellipse: return .ellipse(size: size.value(at: t))
        case .rectangle:
            return ShapeOpsMath.roundCorners(.rectangle(size: size.value(at: t)), radius: roundness.value(at: t))
        case .polygon: return .polygon(size: size.value(at: t), sides: Int(sides.value(at: t).rounded()), inner: nil)
        case .star: return .polygon(size: size.value(at: t), sides: Int(sides.value(at: t).rounded()), inner: innerRatio.value(at: t))
        }
    }
    func matrix(at t: Double) -> simd_double3x3 {
        let a = rotation.value(at: t) * .pi / 180, s = scale.value(at: t) * 0.01, p = position.value(at: t)
        return simd_double3x3(columns: (SIMD3(cos(a) * s.x, sin(a) * s.x, 0),
                                        SIMD3(-sin(a) * s.y, cos(a) * s.y, 0), SIMD3(p.x, p.y, 1)))
    }
    mutating func traverse(_ v: inout AnimationTraversal) {
        v.apply(&path); v.apply(&size); v.apply(&roundness); v.apply(&sides); v.apply(&innerRatio)
        v.apply(&position); v.apply(&scale); v.apply(&rotation); v.apply(&opacity); v.apply(&fill)
        stroke.traverse(&v); fillGradient?.traverse(&v); strokeGradient?.traverse(&v); ops?.traverse(&v)
    }
}

/// Paths and Merge Paths share one stack. A merge consumes only the entries above it, never entries below.
struct ShapeContent: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var visible = true
    var component: ShapeComponent? = nil
    var merge: MergePathsMode? = nil
}

extension Layer {
    /// Stable virtual identity for a legacy single path; no document mutation merely from opening the panel.
    var editableShapeContents: [ShapeContent] {
        if let shapeContents { return shapeContents }
        guard case .shape(let kind) = content else { return [] }
        var c = ShapeComponent()
        c.kind = kind; c.path = path ?? c.path; c.size = size; c.roundness = cornerRadius
        c.sides = sides; c.innerRatio = innerRatio; c.fill = fill; c.stroke = stroke
        return [ShapeContent(id: id, name: "Path 1", component: c)]
    }
}

extension ShapeStroke {
    mutating func traverse(_ v: inout AnimationTraversal) {
        v.apply(&color); v.apply(&width); v.apply(&trimStart); v.apply(&trimEnd); v.apply(&trimOffset)
    }
}

extension ShapeOps {
    mutating func traverse(_ v: inout AnimationTraversal) {
        v.apply(&offset); v.apply(&pucker); v.apply(&roundCorners)
        if twist != nil { v.apply(&twist!.angle); v.apply(&twist!.center) }
        if repeater != nil {
            v.apply(&repeater!.copies); v.apply(&repeater!.position); v.apply(&repeater!.scale)
            v.apply(&repeater!.rotation); v.apply(&repeater!.startOpacity); v.apply(&repeater!.endOpacity)
        }
        if wiggle != nil { v.apply(&wiggle!.size); v.apply(&wiggle!.detail); v.apply(&wiggle!.speed) }
        if zigzag != nil { v.apply(&zigzag!.size); v.apply(&zigzag!.ridges) }
    }
}

extension BezierPath {
    func mapped(_ m: simd_double3x3) -> BezierPath {
        func map(_ p: Vec2) -> Vec2 { let q = m * SIMD3(p.x, p.y, 1); return Vec2(q.x / q.z, q.y / q.z) }
        var p = self
        for i in vertices.indices {
            let v = vertices[i], q = map(v.point)
            p.vertices[i] = PathVertex(point: q, inTangent: map(v.point + v.inTangent) - q, outTangent: map(v.point + v.outTangent) - q)
        }
        return p
    }
}

/// Polygon clipping uses the system's robust Core Graphics boolean engine on adaptively flattened Béziers.
/// Compound contours stay separate: holes must never acquire a synthetic connecting edge.
enum ShapeBoolean {
    static func cgPath(_ paths: [BezierPath]) -> CGPath {
        let out = CGMutablePath()
        for p in paths {
            guard let first = p.vertices.first else { continue }
            out.move(to: CGPoint(x: first.point.x, y: first.point.y))
            let n = p.vertices.count
            guard n > 1 else { continue }
            for i in 0..<(p.closed ? n : n - 1) {
                let a = p.vertices[i], b = p.vertices[(i + 1) % n]
                out.addCurve(to: CGPoint(x: b.point.x, y: b.point.y),
                             control1: CGPoint(x: a.point.x + a.outTangent.x, y: a.point.y + a.outTangent.y),
                             control2: CGPoint(x: b.point.x + b.inTangent.x, y: b.point.y + b.inTangent.y))
            }
            if p.closed { out.closeSubpath() }
        }
        return out
    }
    static func contours(_ p: CGPath) -> [BezierPath] {
        var out: [BezierPath] = [], vertices: [PathVertex] = []
        func flush(_ closed: Bool) {
            if vertices.count > 1 {
                if closed, vertices.first?.point == vertices.last?.point { vertices.removeLast() }
                out.append(BezierPath(vertices: vertices, closed: closed))
            }
            vertices = []
        }
        p.flattened(threshold: 0.25).applyWithBlock { ptr in
            let e = ptr.pointee
            switch e.type {
            case .moveToPoint: flush(false); vertices.append(PathVertex(point: Vec2(Double(e.points[0].x), Double(e.points[0].y))))
            case .addLineToPoint: vertices.append(PathVertex(point: Vec2(Double(e.points[0].x), Double(e.points[0].y))))
            case .closeSubpath: flush(true)
            default: break // flattened() only emits lines, moves and closes.
            }
        }
        flush(false); return out
    }
    static func combine(_ groups: [[BezierPath]], mode: MergePathsMode) -> [BezierPath] {
        guard let bottom = groups.last else { return [] }
        if mode == .merge { return groups.flatMap { $0 } }
        let inputs = groups.map { cgPath($0).flattened(threshold: 0.25).normalized(using: .winding) }
        guard var result = inputs.last else { return [] }
        // AE Subtract: bottom path minus the union of the paths above it.
        for p in inputs.dropLast().reversed() {
            switch mode {
            case .add: result = result.union(p, using: .winding)
            case .subtract: result = result.subtracting(p, using: .winding)
            case .intersect: result = result.intersection(p, using: .winding)
            case .exclude: result = result.symmetricDifference(p, using: .winding)
            case .merge: break
            }
        }
        _ = bottom
        return contours(result)
    }
}

struct ShapeDraw {
    var paths: [BezierPath]
    var style: ShapeComponent
    var matrix = matrix_identity_double3x3
    var opacity: Double = 1
}

enum ShapeContentsRenderer {
    static func evaluate(_ items: [ShapeContent], time t: Double) -> [ShapeDraw] {
        var out: [ShapeDraw] = []
        for item in items where item.visible {
            if let c = item.component {
                let base = c.ops.map { ShapeOpsMath.apply($0, to: c.base(at: t), time: t) } ?? c.base(at: t)
                let copies = c.ops?.repeater.map { ShapeOpsMath.copies($0, time: t) } ?? [(matrix_identity_double3x3, 1.0)]
                for (m, o) in copies.reversed() {
                    out.append(ShapeDraw(paths: [base], style: c, matrix: c.matrix(at: t) * m, opacity: o * c.opacity.value(at: t) / 100))
                }
            } else if let mode = item.merge, let last = out.last {
                let groups = out.map { draw in draw.paths.map { $0.mapped(draw.matrix) } }
                var combined = last
                combined.paths = ShapeBoolean.combine(groups, mode: mode)
                combined.matrix = matrix_identity_double3x3
                // Merge inherits the bottom path's style, measured in that path's original coordinates.
                combined.style.fillGradient = last.style.fillGradient.map { g in var g = g; g.start = Animated(Self.point(g.start.value(at: t), last.matrix)); g.end = Animated(Self.point(g.end.value(at: t), last.matrix)); return g }
                combined.style.strokeGradient = last.style.strokeGradient.map { g in var g = g; g.start = Animated(Self.point(g.start.value(at: t), last.matrix)); g.end = Animated(Self.point(g.end.value(at: t), last.matrix)); return g }
                out = [combined]
            }
        }
        return out
    }
    static func point(_ p: Vec2, _ m: simd_double3x3) -> Vec2 { let q = m * SIMD3(p.x, p.y, 1); return Vec2(q.x, q.y) }
}
