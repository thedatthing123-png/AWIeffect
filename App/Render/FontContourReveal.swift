import Foundation
import CoreText
import CoreGraphics
import Metal
import simd

extension EffectRegistry {
    static let fontContourReveal = EffectDefinition(
        id: "awi24.fontContourReveal", name: "Font Contour Reveal", category: .text, aeMatchNames: [],
        summary: "Trace the actual outlines within each glyph by path length. Letters trace in parallel; Text Studio still owns letter visibility and animation. Bitmap/color glyphs remain unchanged.",
        params: [.number("start", "Start", 0, 0, 100, unit: "%"), .number("end", "End", 100, 0, 100, unit: "%"),
                 .number("width", "Trace Width", 2, 0.25, 12, unit: "px"),
                 .toggle("reverse", "Reverse Direction", false), .toggle("together", "Trace Contours Together", false)],
        margin: { e, t in min(12,max(0.25,e.number("width",t))) + 4 },
        stage: .transform { _, _ in (0, 0, 0, 1) })
}

/// Core Text contours, centered like the existing glyph texture. Cache geometry, not every animation frame.
enum FontContourGeometry {
    private static let lock = NSLock()
    private static var cache: [String: [BezierPath]] = [:]
    static func paths(_ glyph: LaidGlyph) -> [BezierPath]? {
        let key = "\(CTFontCopyPostScriptName(glyph.font))|\(CTFontGetSize(glyph.font))|\(glyph.glyph)"
        lock.lock(); let saved = cache[key]; lock.unlock()
        if let saved { return saved.isEmpty ? nil : saved }
        guard let path = CTFontCreatePathForGlyph(glyph.font, glyph.glyph, nil) else { return nil }
        let centerX = glyph.center.x-glyph.origin.x, centerY = glyph.origin.y-glyph.center.y
        let result = convert(path) { CGPoint(x: Double($0.x)-centerX, y: centerY-Double($0.y)) }
        lock.lock()
        if cache.count >= 128 { cache.removeAll() }
        cache[key] = result; lock.unlock()
        return result.isEmpty ? nil : result
    }

    static func convert(_ path: CGPath, map: @escaping (CGPoint) -> CGPoint = { $0 }) -> [BezierPath] {
        var result: [BezierPath] = [], vertices: [PathVertex] = []
        func point(_ p: CGPoint) -> Vec2 { let q = map(p); return Vec2(Double(q.x),Double(q.y)) }
        func finish(_ closed: Bool) {
            if closed, vertices.count > 1, vertices.last!.point == vertices.first!.point {
                vertices[0].inTangent = vertices.last!.inTangent; vertices.removeLast()
            }
            if vertices.count >= 2 { result.append(BezierPath(vertices:vertices,closed:closed)) }
            vertices = []
        }
        path.applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint: finish(false); vertices = [PathVertex(point:point(element.points[0]))]
            case .addLineToPoint: vertices.append(PathVertex(point:point(element.points[0])))
            case .addQuadCurveToPoint:
                guard let last = vertices.last else { return }
                let control = point(element.points[0]), end = point(element.points[1])
                vertices[vertices.count-1].outTangent = (control-last.point)*(2.0/3.0)
                vertices.append(PathVertex(point:end,inTangent:(control-end)*(2.0/3.0)))
            case .addCurveToPoint:
                guard let last = vertices.last else { return }
                let end = point(element.points[2])
                vertices[vertices.count-1].outTangent = point(element.points[0])-last.point
                vertices.append(PathVertex(point:end,inTangent:point(element.points[1])-end))
            case .closeSubpath: finish(true)
            @unknown default: break
            }
        }
        finish(false)
        return result
    }

    static func trimmed(_ paths: [BezierPath], effects: [EffectInstance], time: Double) -> [BezierPath] {
        var current = paths
        for effect in effects where effect.isEnabled && effect.typeID == "awi24.fontContourReveal" {
            if effect.bool("reverse") {
                current = current.reversed().map { path in
                    BezierPath(vertices:path.vertices.reversed().map { PathVertex(point:$0.point,inTangent:$0.outTangent,outTangent:$0.inTangent) },closed:path.closed)
                }
            }
            let start = min(100,max(0,effect.number("start",time))), end = min(100,max(0,effect.number("end",time)))
            guard end > start else { return [] }
            let segments = current.map { $0.segments(stepsPerCurve:24) }
            let lengths = segments.map { $0.reduce(0.0) { sum, s in sum + hypot(Double(s.z-s.x),Double(s.w-s.y)) } }
            let total = lengths.reduce(0,+)
            guard total > 0 else { return [] }
            var prefix = 0.0, output: [BezierPath] = []
            for (index, lines) in segments.enumerated() {
                let length = lengths[index]
                defer { prefix += length }
                guard length > 0 else { continue }
                let low = effect.bool("together") ? start : max(0,(start/100*total-prefix)/length*100)
                let high = effect.bool("together") ? end : min(100,(end/100*total-prefix)/length*100)
                guard high > low else { continue }
                let visible = PathGPU.trimmed(lines,start:low,end:high,offset:0,closed:false)
                guard let first = visible.first else { continue }
                var vertices = [PathVertex(point:Vec2(Double(first.x),Double(first.y)))]
                vertices += visible.map { PathVertex(point:Vec2(Double($0.z),Double($0.w))) }
                output.append(BezierPath(vertices:vertices,closed:false))
            }
            current = output
        }
        return current
    }
}
