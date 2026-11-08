import SwiftUI
import UIKit
import simd

/// The normal canvas stays in place. Tool controls stay in Rig; only the brush cursor is drawn here.
struct BoneWeightCanvasOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var lastPoint: Vec2?
    @State private var cursor: Vec2?

    var body: some View {
        let scale = fit.width / CGFloat(max(1, state.project.width))
        let placement = state.boneWeightArtworkID.flatMap { state.displayPlacement(of: $0) }
        ZStack {
            Color.clear.contentShape(Rectangle())
                .gesture(BoneWeightStrokeGesture(onPoint: { point in
                    guard let placement, abs(placement.determinant) > 1e-10, scale > 0,
                          let local = LayerPlacement.projected(Vec2(Double((point.x-fit.minX)/scale), Double((point.y-fit.minY)/scale)), by: placement.inverse) else { return }
                    cursor = local
                    let step = max(1, state.boneWeightRadius * 0.2)
                    let strength = min(1,max(0,state.boneWeightStrength / 100))
                    var dabs: [BoneWeightDab] = []
                    if let previous = lastPoint {
                        let delta = local-previous, distance = hypot(delta.x,delta.y)
                        guard distance >= step else { return }
                        let count = min(64, max(1,Int(ceil(distance/step))))
                        let spacing = distance/Double(count)
                        let amount = 1-pow(1-strength,spacing/step)
                        for i in 1...count { dabs.append(BoneWeightDab(center: previous+delta*(Double(i)/Double(count)),amount: amount)) }
                    } else { dabs = [BoneWeightDab(center: local,amount: strength)] }
                    state.paintBoneWeights(dabs, beginStroke: lastPoint == nil)
                    lastPoint = local
                }, onEnd: { commit in
                    state.finishBoneWeightStroke(commit: commit); lastPoint = nil; cursor = nil
                }))
                .accessibilityElement().accessibilityLabel("Paint bone weights")
                .accessibilityValue(state.boneWeightPreview?.revision.uuidString ?? state.rigArtwork?.boneMesh?.revision.uuidString ?? "")
            if let cursor, let placement {
                Path { path in
                    for i in 0...48 {
                        let angle = Double(i)*Double.pi*2/48
                        let local = cursor+Vec2(cos(angle),sin(angle))*state.boneWeightRadius
                        if let point = LayerPlacement.projected(local,by: placement) {
                            let screen = CGPoint(x: fit.minX+CGFloat(point.x)*scale,y: fit.minY+CGFloat(point.y)*scale)
                            if i == 0 { path.move(to: screen) } else { path.addLine(to: screen) }
                        }
                    }
                }.stroke(.white,lineWidth: 1.5).allowsHitTesting(false)
            }
        }
        .onChange(of: state.boneWeightBoneID) { _, _ in cancel() }
        .onChange(of: state.selectedLayerID) { _, _ in
            if state.rigArtworkID != state.boneWeightArtworkID { state.finishBoneWeights(); cancel() }
        }
        .onDisappear { cancel(); state.finishBoneWeights() }
    }
    private func cancel() { state.finishBoneWeightStroke(commit: false); lastPoint = nil; cursor = nil }
}

/// Starts immediately for brush feedback, but rolls the preview back on multitouch or system cancellation.
/// It cannot prevent pinch/pan recognizers, so navigating the artwork never leaves an accidental painted dab.
struct BoneWeightStrokeGesture: UIGestureRecognizerRepresentable {
    var onPoint: (CGPoint) -> Void
    var onEnd: (Bool) -> Void
    func makeUIGestureRecognizer(context: Context) -> BoneWeightRecognizer { BoneWeightRecognizer() }
    func handleUIGestureRecognizerAction(_ recognizer: BoneWeightRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onPoint(recognizer.location(in: recognizer.view))
        case .ended: onEnd(true)
        case .cancelled, .failed: onEnd(false)
        default: break
        }
    }
}

final class BoneWeightRecognizer: UIGestureRecognizer {
    private var tracked: UITouch?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard tracked == nil, touches.count == 1 else { state = .cancelled; return }
        tracked = touches.first; state = .began
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if let tracked, touches.contains(tracked) { state = .changed }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let tracked, touches.contains(tracked) { state = .ended }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .cancelled }
    override func reset() { tracked = nil; super.reset() }
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}
