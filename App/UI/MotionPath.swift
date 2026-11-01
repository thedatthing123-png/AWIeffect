import SwiftUI

/// Motion Sketch (AE): hold Record and move the layer with your finger; the playhead runs in real time and every move
/// becomes position keyframes along your exact path. Then Simplify keeps the shape with far fewer keys.
extension EditorState {
    func beginMotionSketch() {
        sketchStartTime = currentTime
        sketchStartClock = CACurrentMediaTime()
        sketchSamples = []
    }

    /// Called from the move drag: records where the layer is now and moves the playhead with real time.
    func recordMotionSketch(_ p: Vec2) {
        guard let t0 = sketchStartTime else { return }
        let t = t0 + (CACurrentMediaTime() - sketchStartClock)
        sketchSamples.append((t, p))
        seek(min(t, project.duration))
    }

    func endMotionSketch() {
        guard let i = selectedIndex, let first = sketchSamples.first else { sketchStartTime = nil; return }
        let fps = max(1, project.fps)
        // One key per frame (the last sample in each frame), like AE's Capture Speed 100%.
        var perFrame: [Int: Vec2] = [:]
        for (t, p) in sketchSamples { perFrame[Int((t * fps).rounded())] = p }
        let keys = perFrame.keys.sorted().map { (Double($0) / fps, perFrame[$0]!) }
        mutate("Motion Sketch") { pr in
            var a = pr.layers[i].transform.position
            for (t, p) in keys where t >= first.0 - 0.001 {
                a.insertKeyframe(Keyframe(time: t, value: p, interpolation: .linear))
            }
            pr.layers[i].transform.position = a
        }
        sketchStartTime = nil
        sketchSamples = []
    }

    /// Smoother (AE): drops position keys the path doesn't need (keeps the shape within `tolerance` px) and eases
    /// what is left, so a sketched move becomes a few clean keyframes.
    func simplifyPositionKeys(tolerance: Double) {
        guard let i = selectedIndex else { return }
        let ks = project.layers[i].transform.position.keyframes
        guard ks.count > 3 else { return }
        var keep = Set([0, ks.count - 1])
        func rdp(_ a: Int, _ b: Int) {
            guard b > a + 1 else { return }
            let pa = ks[a].value, pb = ks[b].value
            var best = -1.0, idx = -1
            for k in (a + 1)..<b {
                // Distance from the straight interpolation between a and b at the same time (shape + timing).
                let f = (ks[k].time - ks[a].time) / max(1e-6, ks[b].time - ks[a].time)
                let q = Vec2(pa.x + (pb.x - pa.x) * f, pa.y + (pb.y - pa.y) * f)
                let d = hypot(ks[k].value.x - q.x, ks[k].value.y - q.y)
                if d > best { best = d; idx = k }
            }
            if best > tolerance { keep.insert(idx); rdp(a, idx); rdp(idx, b) }
        }
        rdp(0, ks.count - 1)
        mutate("Simplify Keys") { pr in
            var a = pr.layers[i].transform.position
            a.keyframes = keep.sorted().map { var k = ks[$0]; k.interpolation = .bezier; return k }
            pr.layers[i].transform.position = a
        }
    }
}

/// The selected layer's motion path on the canvas: the route it travels, dots at its position keyframes (drag a dot
/// to reshape the path), and the current spot.
struct MotionPathOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var dragKey: Int?

    private var scale: CGFloat { fit.width / CGFloat(max(state.project.width, 1)) }
    private func screen(_ p: Vec2) -> CGPoint { CGPoint(x: fit.minX + CGFloat(p.x) * scale, y: fit.minY + CGFloat(p.y) * scale) }
    private func comp(_ p: CGPoint) -> Vec2 { Vec2(Double((p.x - fit.minX) / scale), Double((p.y - fit.minY) / scale)) }

    var body: some View {
        if let l = state.selectedLayer, l.parentID == nil, l.transform.position.keyframes.count >= 2 {
            let ks = l.transform.position.keyframes
            let t0 = max(l.inPoint, ks.first!.time), t1 = min(l.outPoint, ks.last!.time)
            ZStack {
                Canvas { ctx, _ in
                    var path = Path()
                    let n = max(2, Int((t1 - t0) * 60))
                    for k in 0...n {
                        let t = t0 + (t1 - t0) * Double(k) / Double(n)
                        let p = screen(l.transform.position.value(at: t))
                        if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    ctx.stroke(path, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    // Ticks every frame show speed (close together = slow).
                    let fps = max(1, state.project.fps)
                    var t = t0
                    while t <= t1 {
                        let p = screen(l.transform.position.value(at: t))
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)), with: .color(.white.opacity(0.6)))
                        t += 1 / fps
                    }
                }
                .allowsHitTesting(false)
                ForEach(ks.indices, id: \.self) { k in
                    let p = screen(ks[k].value)
                    Rectangle()
                        .fill(abs(ks[k].time - state.currentTime) < 0.5 / max(1, state.project.fps) ? Theme.accentGlow : Color.white)
                        .frame(width: 10, height: 10).rotationEffect(.degrees(45))
                        .overlay(Rectangle().stroke(.black, lineWidth: 1).frame(width: 10, height: 10).rotationEffect(.degrees(45)))
                        .frame(width: 30, height: 30).contentShape(Rectangle())
                        .position(p)
                        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("motionPath"))
                            .onChanged { v in
                                if dragKey == nil { dragKey = k; state.beginEdit("Move Path Point"); state.beginLiveGesture() }
                                let c = comp(v.location)
                                state.mutateLayer { $0.transform.position.keyframes[k].value = Vec2((c.x * 10).rounded() / 10, (c.y * 10).rounded() / 10) }
                            }
                            .onEnded { _ in dragKey = nil; state.endLiveGesture(); state.endEdit() })
                }
            }
            .coordinateSpace(name: "motionPath")
        }
    }
}
