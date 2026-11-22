import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Observes the stationary window without intercepting its controls. A clip's
/// first tap can resize the entire editor before the second touch arrives.
struct TimelineContainerTapObserver:UIViewRepresentable {
    var resolve:(CGPoint)->UUID?
    var complete:(CGPoint,TimeInterval,UUID?)->Void
    var cancel:()->Void
    func makeUIView(context:Context)->Anchor { Anchor() }
    func updateUIView(_ view:Anchor,context:Context) { view.resolve=resolve;view.complete=complete;view.cancel=cancel }
    static func dismantleUIView(_ view:Anchor,coordinator:Void) { view.detach();view.complete={_,_,_ in};view.resolve={_ in nil} }

    final class Anchor:UIView {
        var resolve:(CGPoint)->UUID?={_ in nil}
        var complete:(CGPoint,TimeInterval,UUID?)->Void={_,_,_ in}
        var cancel:()->Void={}
        private weak var observedWindow:UIWindow?
        private var observer:PassiveTimelineTap?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard observedWindow !== window else { return }
            detach()
            guard let window else { return }
            let tap=PassiveTimelineTap(target:nil,action:nil)
            tap.cancelsTouchesInView=false;tap.delaysTouchesBegan=false;tap.delaysTouchesEnded=false
            tap.resolve={ [weak self] point in self?.resolve(point) }
            tap.complete={ [weak self] point,time,container in
                guard let complete=self?.complete else { return }
                DispatchQueue.main.async { complete(point,time,container) }
            }
            tap.cancel={ [weak self] in self?.cancel() }
            observedWindow=window;observer=tap;window.addGestureRecognizer(tap)
        }
        func detach() {
            if let observer { observedWindow?.removeGestureRecognizer(observer) }
            observer=nil;observedWindow=nil
        }
    }
}

/// Observe raw completed taps without competing with SwiftUI's row, scroll,
/// hold or trim recognizers. It deliberately never claims recognition.
private final class PassiveTimelineTap:UIGestureRecognizer {
    var resolve:(CGPoint)->UUID?={_ in nil}
    var complete:(CGPoint,TimeInterval,UUID?)->Void={_,_,_ in}
    var cancel:()->Void={}
    private var tracked:UITouch?
    private var origin=CGPoint.zero
    private var began:TimeInterval=0
    private var container:UUID?
    override func canPrevent(_ preventedGestureRecognizer:UIGestureRecognizer)->Bool { false }
    override func canBePrevented(by preventingGestureRecognizer:UIGestureRecognizer)->Bool { false }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent) {
        guard tracked==nil,touches.count==1,let touch=touches.first,event.allTouches?.count==1 else { cancel();state = .failed;return }
        tracked=touch;origin=touch.location(in:view);began=touch.timestamp;container=resolve(origin)
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent) {
        guard let tracked else { return }
        let point=tracked.location(in:view)
        if hypot(point.x-origin.x,point.y-origin.y)>12 { cancel();state = .failed }
    }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent) {
        if let tracked,touches.contains(tracked),tracked.timestamp-began<0.3 {
            complete(origin,began,container)
        } else { cancel() }
        state = .failed
    }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent) { cancel();state = .failed }
    override func reset() { super.reset();tracked=nil;container=nil }
}

struct TimelineContainerFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
