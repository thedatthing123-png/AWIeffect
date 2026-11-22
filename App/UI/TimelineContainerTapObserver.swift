import SwiftUI
import UIKit

/// Observes the stationary window without intercepting its controls. A clip's
/// first tap can resize the entire editor before the second touch arrives.
struct TimelineContainerTapObserver:UIViewRepresentable {
    var complete:(CGPoint,TimeInterval)->Void
    func makeUIView(context:Context)->Anchor { Anchor() }
    func updateUIView(_ view:Anchor,context:Context) { view.complete=complete }
    static func dismantleUIView(_ view:Anchor,coordinator:Void) { view.detach();view.complete={_,_ in} }

    final class Anchor:UIView,UIGestureRecognizerDelegate {
        var complete:(CGPoint,TimeInterval)->Void={_,_ in}
        private weak var observedWindow:UIWindow?
        private var observer:UITapGestureRecognizer?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard observedWindow !== window else { return }
            detach()
            guard let window else { return }
            let tap=UITapGestureRecognizer(target:self,action:#selector(tapped))
            tap.numberOfTapsRequired=1
            tap.cancelsTouchesInView=false;tap.delaysTouchesBegan=false;tap.delaysTouchesEnded=false
            tap.delegate=self
            observedWindow=window;observer=tap;window.addGestureRecognizer(tap)
        }
        func detach() {
            if let observer { observedWindow?.removeGestureRecognizer(observer) }
            observer=nil;observedWindow=nil
        }
        @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let observedWindow else { return }
            let point = recognizer.location(in: observedWindow)
            let timestamp = ProcessInfo.processInfo.systemUptime
            // Row actions finish first. Touch history lives in EditorState,
            // so replacing this anchor during selection cannot lose tap one.
            let complete = self.complete
            DispatchQueue.main.async { complete(point, timestamp) }
        }
        func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith otherGestureRecognizer:UIGestureRecognizer)->Bool { true }
    }
}
