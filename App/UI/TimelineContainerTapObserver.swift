import SwiftUI
import UIKit

/// A window-level recognizer survives the panel reflow caused by selecting a
/// clip. It observes simultaneous taps without delaying the row's first tap.
final class TimelineContainerTapMonitor: NSObject, ObservableObject, UIGestureRecognizerDelegate {
    private var resolve: (CGPoint) -> UUID? = { _ in nil }
    private var open: (UUID) -> Void = { _ in }
    private weak var observedWindow: UIWindow?
    private var observer: UITapGestureRecognizer?
    private var first: (id: UUID, time: TimeInterval)?

    func attach(resolve: @escaping (CGPoint) -> UUID?, open: @escaping (UUID) -> Void) {
        self.resolve=resolve; self.open=open
        guard let window=UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) else { return }
        guard observedWindow !== window || observer == nil else { return }
        removeRecognizer()
        let tap=UITapGestureRecognizer(target:self,action:#selector(openContainer))
        tap.numberOfTapsRequired=2
        tap.cancelsTouchesInView=false; tap.delaysTouchesBegan=false; tap.delaysTouchesEnded=false
        tap.delegate=self
        observedWindow=window; observer=tap; window.addGestureRecognizer(tap)
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
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
    private func removeRecognizer() {
        if let observer { observedWindow?.removeGestureRecognizer(observer) }
        observer=nil; observedWindow=nil; first=nil
    }
    func detach() {
        removeRecognizer()
        resolve={ _ in nil }; open={ _ in }
    }
}

struct TimelineContainerFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
