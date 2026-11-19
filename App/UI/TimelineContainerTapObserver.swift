import SwiftUI
import UIKit

/// Observes the stationary window without intercepting its controls. A clip's
/// first tap can resize the entire editor before the second touch arrives.
struct TimelineContainerTapObserver:UIViewRepresentable {
    var complete:()->Void
    func makeUIView(context:Context)->Anchor { Anchor() }
    func updateUIView(_ view:Anchor,context:Context) { view.complete=complete }
    static func dismantleUIView(_ view:Anchor,coordinator:Void) { view.detach();view.complete={} }

    final class Anchor:UIView,UIGestureRecognizerDelegate {
        var complete:()->Void={}
        private weak var observedWindow:UIWindow?
        private var observer:UITapGestureRecognizer?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard observedWindow !== window else { return }
            detach()
            guard let window else { return }
            let tap=UITapGestureRecognizer(target:self,action:#selector(doubleTapped))
            tap.numberOfTapsRequired=2
            tap.cancelsTouchesInView=false;tap.delaysTouchesBegan=false;tap.delaysTouchesEnded=false
            tap.delegate=self
            observedWindow=window;observer=tap;window.addGestureRecognizer(tap)
        }
        func detach() {
            if let observer { observedWindow?.removeGestureRecognizer(observer) }
            observer=nil;observedWindow=nil
        }
        @objc private func doubleTapped() {
            // Let the controls finish processing the same touch first. The
            // state action rejects expired/non-container taps and duplicate opens.
            DispatchQueue.main.async { [weak self] in self?.complete() }
        }
        func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith otherGestureRecognizer:UIGestureRecognizer)->Bool { true }
    }
}
