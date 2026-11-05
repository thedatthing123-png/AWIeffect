import Foundation
import simd

/// One point of a vector path. Handles are offsets from the point and mirror each other while being pulled out.
struct PenAnchor: Equatable {
    var point: SIMD2<Double>
    var handle = SIMD2<Double>(0, 0)
}

/// An editable Bezier path. It stays editable until it's applied to the layer.
struct PenPath: Equatable {
    var anchors: [PenAnchor] = []
    var closed = false

    var isEmpty: Bool { anchors.isEmpty }

    /// Points along the curve, for drawing, filling or selecting.
    func flattened(step: Double = 3) -> [SIMD2<Double>] {
        guard let first = anchors.first else { return [] }
        var out = [first.point]
        let pairs = Array(zip(anchors, anchors.dropFirst())) + (closed && anchors.count > 2 ? [(anchors[anchors.count - 1], first)] : [])
        for (a, b) in pairs {
            let c1 = a.point + a.handle, c2 = b.point - b.handle
            let length = simd_length(c1 - a.point) + simd_length(c2 - c1) + simd_length(b.point - c2)
            let n = max(1, min(400, Int(length / step)))
            for i in 1...n {
                let t = Double(i) / Double(n), u = 1 - t
                let w0 = u * u * u, w1 = 3 * u * u * t, w2 = 3 * u * t * t, w3 = t * t * t
                out.append(a.point * w0 + c1 * w1 + c2 * w2 + b.point * w3)
            }
        }
        return out
    }
}

extension DrawEngine {
    /// Puts a vector path on the active layer with the current brush.
    func applyPath(_ path: PenPath, filled: Bool) {
        drawShape(path.flattened(), filled: filled)
    }

    /// Uses a vector path as the selection edge.
    func selectPath(_ path: PenPath) {
        var closed = path
        closed.closed = true
        selectLasso(closed.flattened())
    }
}
