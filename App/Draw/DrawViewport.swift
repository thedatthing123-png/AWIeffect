import CoreGraphics
import simd

/// The same transform drives GPU corners, input coordinates, and tool overlays.
struct DrawViewport {
    var size: CGSize
    var zoom: CGFloat
    var rotation: CGFloat
    var offset: CGPoint

    var transform: CGAffineTransform {
        CGAffineTransform(translationX: offset.x + size.width * zoom / 2,
                          y: offset.y + size.height * zoom / 2)
            .rotated(by: rotation).scaledBy(x: zoom, y: zoom)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
    }

    func canvas(_ point: CGPoint) -> SIMD2<Double> {
        let p = point.applying(transform.inverted())
        return SIMD2(Double(p.x), Double(p.y))
    }

    func view(_ point: SIMD2<Double>) -> CGPoint {
        CGPoint(x: point.x, y: point.y).applying(transform)
    }
}
