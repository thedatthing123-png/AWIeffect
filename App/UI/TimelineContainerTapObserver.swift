import SwiftUI
import UIKit

/// A window-level recognizer survives the panel reflow caused by selecting a
/// clip. It observes simultaneous taps without delaying the row's first tap.
struct TimelineContainerTapObserver: UIViewRepresentable {
    var resolve: (CGPoint) -> UUID?
    var open: (UUID) -> Void
    func makeUIView(context: Context) -> Anchor { Anchor() }
    func updateUIView(_ view: Anchor, context: Context) { view.resolve=resolve; view.open=open }
    static func dismantleUIView(_ view: Anchor, coordinator: Void) { view.detach() }

    final class Anchor: UIView, UIGestureRecognizerDelegate {
        var resolve: (CGPoint) -> UUID? = { _ in nil }
        var open: (UUID) -> Void = { _ in }
        private weak var observedWindow: UIWindow?
        private var observer: UITapGestureRecognizer?
        private var first: (id: UUID, time: TimeInterval)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard observedWindow !== window else { return }
            detach()
            guard let window else { return }
            let tap=UITapGestureRecognizer(target:self,action:#selector(openContainer))
            tap.numberOfTapsRequired=2
            tap.cancelsTouchesInView=false; tap.delaysTouchesBegan=false; tap.delaysTouchesEnded=false
            tap.delegate=self
            observedWindow=window; observer=tap; window.addGestureRecognizer(tap)
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // Capture the first hit before SwiftUI selects the row and moves it.
            if let first, touch.timestamp-first.time < 0.5 { return true }
            guard let id=resolve(touch.location(in:observedWindow)) else { first=nil; return false }
            first=(id,touch.timestamp)
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
        @objc private func openContainer() {
            guard observer?.state == .ended, let first else { return }
            self.first=nil
            open(first.id)
        }
        func detach() {
            if let observer { observedWindow?.removeGestureRecognizer(observer) }
            observer=nil; observedWindow=nil; first=nil
        }
    }
}

struct TimelineContainerFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
