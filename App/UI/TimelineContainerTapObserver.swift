import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// SwiftUI's immediate single-tap and hold recognizers must not fail this
/// observer when the first tap selects a clip. It also cannot prevent theirs.
private final class ContainerDoubleTapRecognizer: UITapGestureRecognizer {
    override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }
}

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
        let tap=ContainerDoubleTapRecognizer(target:self,action:#selector(openContainer))
        tap.numberOfTapsRequired=2
        tap.cancelsTouchesInView=false; tap.delaysTouchesBegan=false; tap.delaysTouchesEnded=false
        tap.delegate=self
        observedWindow=window; observer=tap; window.addGestureRecognizer(tap)
        trace("attached window \(window.bounds)")
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        trace("touch \(touch.location(in:observedWindow)) resolved=\(String(describing:resolve(touch.location(in:observedWindow)))) first=\(String(describing:first))")
        if let first, touch.timestamp-first.time < 0.5 { return true }
        guard let id=resolve(touch.location(in:observedWindow)) else { first=nil; return false }
        first=(id,touch.timestamp)
        return true
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    @objc private func openContainer() {
        trace("recognized \(String(describing:observer?.state.rawValue)) first=\(String(describing:first))")
        guard observer?.state == .ended, let first else { return }
        self.first=nil
        open(first.id)
    }
    private func removeRecognizer() {
        if let observer { observedWindow?.removeGestureRecognizer(observer) }
        observer=nil; observedWindow=nil; first=nil
    }
    func detach() {
        trace("detached")
        removeRecognizer()
        resolve={ _ in nil }; open={ _ in }
    }
    func recordFrames(_ frames: [UUID: CGRect]) { trace("row frames \(frames)") }
    private func trace(_ message: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting-containerInteractions") else { return }
        let directory=URL(fileURLWithPath:"/tmp/awi-ui",isDirectory:true)
        try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let file=directory.appendingPathComponent("container-touch-trace.txt")
        let data=Data(("\(ProcessInfo.processInfo.systemUptime) \(message)\n").utf8)
        if !FileManager.default.fileExists(atPath:file.path) { try? data.write(to:file) }
        else if let handle=try? FileHandle(forWritingTo:file) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd(); try? handle.write(contentsOf:data)
        }
        #endif
    }
}

struct TimelineContainerFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
