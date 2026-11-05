import Foundation
import Metal
import simd

/// Pixels lifted off the active layer while they're being moved, scaled, rotated or flipped.
final class FloatingPixels {
    let layer: DrawLayer
    let base: MTLTexture
    let pixels: MTLTexture
    let original: [UInt8]
    let mask: [UInt8]?
    /// The lifted pixels' bounds before any transform.
    let box: CGRect
    var translate = SIMD2<Double>(0, 0)
    var scale = SIMD2<Double>(1, 1)
    var rotation = 0.0

    init(layer: DrawLayer, base: MTLTexture, pixels: MTLTexture, original: [UInt8], mask: [UInt8]?, box: CGRect) {
        self.layer = layer; self.base = base; self.pixels = pixels
        self.original = original; self.mask = mask; self.box = box
    }

    var pivot: SIMD2<Double> { SIMD2(Double(box.midX), Double(box.midY)) }

    func forward(_ p: SIMD2<Double>) -> SIMD2<Double> {
        let d = (p - pivot) * scale
        let c = cos(rotation), s = sin(rotation)
        return pivot + translate + SIMD2(d.x * c - d.y * s, d.x * s + d.y * c)
    }

    func inverse(_ p: SIMD2<Double>) -> SIMD2<Double> {
        let d = p - pivot - translate
        let c = cos(rotation), s = sin(rotation)
        return pivot + SIMD2(d.x * c + d.y * s, -d.x * s + d.y * c) / scale
    }

    /// Corners on the canvas, clockwise from top left.
    var corners: [SIMD2<Double>] {
        [SIMD2(box.minX, box.minY), SIMD2(box.maxX, box.minY), SIMD2(box.maxX, box.maxY), SIMD2(box.minX, box.maxY)]
            .map { forward(SIMD2(Double($0.x), Double($0.y))) }
    }
}

extension DrawEngine {
    /// Lifts the selection (or the whole layer) so it can be transformed live. False when there's nothing to lift.
    @discardableResult
    func beginFloating() -> Bool {
        if isFloating { return true }
        guard let l = activeLayer else { return false }
        let original = bytes(of: l)
        let mask = hasSelection ? selectionBytes() : nil
        var moving = original
        var rest = [UInt8](repeating: 0, count: original.count)
        var x0 = width, y0 = height, x1 = -1, y1 = -1
        for y in 0..<height { for x in 0..<width {
            let i = y * width + x
            let m = UInt16(mask?[i] ?? 255)
            for c in 0..<4 {
                let v = UInt16(original[i * 4 + c]) * m / 255
                moving[i * 4 + c] = UInt8(v)
                rest[i * 4 + c] = original[i * 4 + c] - UInt8(v)
            }
            if moving[i * 4 + 3] > 0 { x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x); y1 = max(y1, y) }
        } }
        guard x1 >= x0, let base = Self.makeTexture(device, width, height, .rgba8Unorm),
              let pixels = Self.makeTexture(device, width, height, .rgba8Unorm) else { return false }
        let region = MTLRegionMake2D(0, 0, width, height)
        base.replace(region: region, mipmapLevel: 0, withBytes: rest, bytesPerRow: width * 4)
        pixels.replace(region: region, mipmapLevel: 0, withBytes: moving, bytesPerRow: width * 4)
        pushUndo(l)
        floating = FloatingPixels(layer: l, base: base, pixels: pixels, original: original, mask: mask,
                                  box: CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1))
        isFloating = true
        return true
    }

    /// Redraws the layer with the lifted pixels at their current placement.
    func updateFloating() {
        guard let f = floating, let cb = queue.makeCommandBuffer(), let enc = cb.makeComputeCommandEncoder() else { return }
        let o = f.inverse(SIMD2(0, 0)), ax = f.inverse(SIMD2(1, 0)) - o, ay = f.inverse(SIMD2(0, 1)) - o
        var params = (SIMD4<Float>(Float(ax.x), Float(ay.x), Float(o.x), 0), SIMD4<Float>(Float(ax.y), Float(ay.y), Float(o.y), 0))
        enc.setComputePipelineState(floatPSO)
        enc.setTexture(f.layer.texture, index: 0); enc.setTexture(f.base, index: 1); enc.setTexture(f.pixels, index: 2)
        enc.setBytes(&params, length: MemoryLayout<SIMD4<Float>>.stride * 2, index: 0)
        dispatch(enc, floatPSO)
        enc.endEncoding()
        cb.commit()
    }

    /// Keeps the result. The selection follows the pixels.
    func commitFloating() {
        guard let f = floating else { return }
        updateFloating()
        if let mask = f.mask {
            var moved = [UInt8](repeating: 0, count: width * height)
            for y in 0..<height { for x in 0..<width {
                let q = f.inverse(SIMD2(Double(x) + 0.5, Double(y) + 0.5))
                let sx = Int(q.x.rounded(.down)), sy = Int(q.y.rounded(.down))
                if sx >= 0, sy >= 0, sx < width, sy < height { moved[y * width + x] = mask[sy * width + sx] }
            } }
            restoreSelection(moved)
        }
        floating = nil; isFloating = false
        revision += 1
    }

    /// Puts everything back as it was.
    func cancelFloating() {
        guard let f = floating else { return }
        setBytes(f.original, of: f.layer)
        dropLastUndo()
        floating = nil; isFloating = false
        revision += 1
    }

    func flipFloating(horizontal: Bool) {
        guard let f = floating else { return }
        if horizontal { f.scale.x = -f.scale.x } else { f.scale.y = -f.scale.y }
        updateFloating()
    }

    /// Draws a shape with the current brush, or fills it.
    func drawShape(_ points: [SIMD2<Double>], filled: Bool) {
        guard points.count >= 2 else { return }
        if filled { fillLasso(points, color: brush.color, opacity: brush.opacity); return }
        let saved = brush.stabilizer
        brush.stabilizer = 0
        beginStroke(at: points[0], pressure: 1)
        for (a, b) in zip(points, points.dropFirst()) {
            let steps = max(1, Int(simd_length(b - a) / 4))
            for i in 1...steps { continueStroke(to: a + (b - a) * (Double(i) / Double(steps)), pressure: 1) }
        }
        endStroke()
        brush.stabilizer = saved
    }
}
