import SwiftUI
import UIKit

/// Fail vertical pans before recognition, so scrubbing cannot capture the layer list's scroll.
struct TimelineHorizontalPan: UIGestureRecognizerRepresentable {
    var canBegin: () -> Bool
    var onChange: (CGFloat) -> Void
    var onEnd: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator(canBegin: canBegin) }
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.minimumNumberOfTouches = 1; pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false; pan.delegate = context.coordinator
        return pan
    }
    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) { context.coordinator.canBegin = canBegin }
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onChange(recognizer.translation(in: recognizer.view).x)
        case .ended, .cancelled, .failed: onEnd()
        default: break
        }
    }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var canBegin: () -> Bool
        init(canBegin: @escaping () -> Bool) { self.canBegin = canBegin }
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard canBegin(), let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
