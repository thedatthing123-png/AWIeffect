import SwiftUI
import UIKit

/// A quick vertical pan belongs to scrolling; only a stationary hold starts editing.
struct TimelineHold: UIGestureRecognizerRepresentable {
    var onMove: (CGPoint, CGPoint) -> Void
    var onEnd: (CGPoint) -> Void
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }
    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let hold = UILongPressGestureRecognizer()
        hold.minimumPressDuration = 0.3; hold.allowableMovement = 6
        return hold
    }
    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {}
    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let point = recognizer.location(in: recognizer.view?.window)
        switch recognizer.state {
        case .began: context.coordinator.origin = point; onMove(point, .zero)
        case .changed:
            let start = context.coordinator.origin ?? point
            onMove(point, CGPoint(x: point.x - start.x, y: point.y - start.y))
        case .ended, .cancelled, .failed:
            let start = context.coordinator.origin ?? point
            if context.coordinator.origin != nil { onEnd(CGPoint(x: point.x - start.x, y: point.y - start.y)) }
            context.coordinator.origin = nil
        default: break
        }
    }
    final class Coordinator { var origin: CGPoint? }
}
