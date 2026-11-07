import SwiftUI
import simd

/// Motion Sketch (AE): hold Record and move the layer with your finger; the playhead runs in real time and every move
/// becomes position keyframes along your exact path. Then Simplify keeps the shape with far fewer keys.
extension EditorState {
    func beginMotionSketch() {
        sketchStartTime = currentTime
        sketchStartClock = CACurrentMediaTime()
        sketchSamples = [:]
        sketchBase = [:]
        // Every layer the drag can move (the selection, or the whole multi-selection).
        let ids = (multiSelection?.count ?? 0) > 1 ? multiSelection! : Set(selectedLayerID.map { [$0] } ?? [])
        for l in project.layers where ids.contains(l.id) { sketchBase[l.id] = l.transform.position }
    }

    /// Called from the move drag: records where the layer is now and moves the playhead with real time.
    func recordMotionSketch(_ p: Vec2, layer id: UUID) {
        guard let t0 = sketchStartTime else { return }
        let t = t0 + (CACurrentMediaTime() - sketchStartClock)
        sketchSamples[id, default: []].append((t, p))
        if abs(currentTime - min(t, project.duration)) > 1e-6 { seek(min(t, project.duration)) }
    }

    /// Ends the sketch inside the drag's undo step (call before `endEdit`).
    func endMotionSketch() {
        let fps = max(1, project.fps), samples = sketchSamples, bases = sketchBase
        sketchStartTime = nil
        sketchSamples = [:]
        sketchBase = [:]
        guard !samples.isEmpty else { return }
        mutate("Motion Sketch") { pr in
            for i in pr.layers.indices {
                let id = pr.layers[i].id
                guard let s = samples[id], !s.isEmpty else { continue }
                let base = bases[id] ?? pr.layers[i].transform.position
                pr.layers[i].transform.position = Self.sketchedPosition(base: base, samples: s, fps: fps,
                                                                         maxTime: pr.layers[i].outPoint)
            }
        }
    }

    /// The position track after a sketch: one key per frame (AE Capture Speed 100%), and the old keys from the
    /// sketch start onward are cleared so they don't carry on (or interleave) after the recorded motion.
    nonisolated static func sketchedPosition(base: Animated<Vec2>, samples: [(Double, Vec2)], fps: Double, maxTime: Double = .infinity) -> Animated<Vec2> {
        let fps = max(1, fps)
        var perFrame: [Int: Vec2] = [:]
        for (t, p) in samples where t.isFinite && p.x.isFinite && p.y.isFinite { perFrame[Int((min(t, maxTime) * fps).rounded())] = p }
        guard let firstFrame = perFrame.keys.min() else { return base }
        let start = Double(firstFrame) / fps
        var a = base
        let before = a.value(at: start)
        a.keyframes.removeAll { $0.time >= start - 0.5 / fps }
        if a.keyframes.isEmpty { a.staticValue = before }
        for f in perFrame.keys.sorted() {
            a.insertKeyframe(Keyframe(time: Double(f) / fps, value: perFrame[f]!, interpolation: .linear))
        }
        return a
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

/// Where a layer's position value is drawn on the canvas (comp px): through parenting, 3D depth and the camera,
/// the same projection the Move tool uses. `nil` when it can't be projected.
enum MotionPathMath {
    static func screenPoint(_ layer: Layer, value: Vec2, project: Project, time: Double) -> Vec2? {
        LayerPlacement.projected(value, by: LayerPlacement.positionMatrix(layer, project: project, time: time))
    }
    /// Inverse: the position value (in the layer's parent space) that is drawn at comp point `c` at `time`.
    static func value(_ layer: Layer, at c: Vec2, project: Project, time: Double) -> Vec2? {
        let m = LayerPlacement.positionMatrix(layer, project: project, time: time)
        guard abs(m.determinant) > 1e-10 else { return nil }
        return LayerPlacement.projected(c, by: m.inverse)
    }
}

/// The selected layer's motion path on the canvas: the route it travels, dots at its position keyframes (drag a dot
/// to reshape the path), and the current spot. Drawn where the layer really is (parenting, 3D, camera).
struct MotionPathOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var dragKey: Int?
    @State private var dragHandle: Bool = false

    private var scale: CGFloat { fit.width / CGFloat(max(state.project.width, 1)) }
    private func screen(_ p: Vec2) -> CGPoint { CGPoint(x: fit.minX + CGFloat(p.x) * scale, y: fit.minY + CGFloat(p.y) * scale) }
    private func comp(_ p: CGPoint) -> Vec2 { Vec2(Double((p.x - fit.minX) / scale), Double((p.y - fit.minY) / scale)) }

    var body: some View {
        if let l = state.selectedLayer, l.content != .camera, l.transform.position.keyframes.count >= 2 {
            let view = state.canvasViewProject(state.project)
            let ks = l.transform.position.keyframes
            let t0 = max(l.inPoint, ks.first!.time), t1 = min(l.outPoint, ks.last!.time)
            let fps = max(1, state.project.fps)
            ZStack {
                Canvas { ctx, _ in
                    guard t1 > t0 else { return }
                    func drawn(_ t: Double) -> CGPoint? {
                        MotionPathMath.screenPoint(l, value: l.transform.position.value(at: t), project: view, time: t).map(screen)
                    }
                    var path = Path()
                    // Parenting/camera evaluation per sample is not free: cap the sample count.
                    let n = min(360, max(2, Int((t1 - t0) * 60)))
                    var started = false
                    for k in 0...n {
                        let t = t0 + (t1 - t0) * Double(k) / Double(n)
                        guard let p = drawn(t) else { started = false; continue }
                        if !started { path.move(to: p); started = true } else { path.addLine(to: p) }
                    }
                    ctx.stroke(path, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    // Ticks every frame show speed (close together = slow).
                    let step = max(1 / fps, (t1 - t0) / 360)
                    var t = t0
                    while t <= t1 {
                        if let p = drawn(t) {
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)), with: .color(.white.opacity(0.6)))
                        }
                        t += step
                    }
                }
                .allowsHitTesting(false)
                // Bezier handles: on the key nearest the playhead (pull them out to curve the path) and on every key
                // that is already curved. Drag a handle back onto its key to straighten that key again.
                let focus = ks.indices.min(by: { abs(ks[$0].time - state.currentTime) < abs(ks[$1].time - state.currentTime) })
                ForEach(ks.indices.filter { $0 == focus || ks[$0].spatialOut != nil || ks[$0].spatialIn != nil }, id: \.self) { k in
                    handles(l, ks, k, view: view)
                }
                ForEach(ks.indices, id: \.self) { k in
                    if let sp = MotionPathMath.screenPoint(l, value: ks[k].value, project: view, time: ks[k].time) {
                        Rectangle()
                            .fill(abs(ks[k].time - state.currentTime) < 0.5 / fps ? Theme.accentGlow : Color.white)
                            .frame(width: 10, height: 10).rotationEffect(.degrees(45))
                            .overlay(Rectangle().stroke(.black, lineWidth: 1).frame(width: 10, height: 10).rotationEffect(.degrees(45)))
                            .frame(width: 30, height: 30).contentShape(Rectangle())
                            .position(screen(sp))
                            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("motionPath"))
                                .onChanged { v in
                                    if dragKey == nil { dragKey = k; state.beginEdit("Move Path Point"); state.beginLiveGesture() }
                                    // Un-project through the placement at that key's time, so the dot lands under the finger.
                                    guard let value = MotionPathMath.value(l, at: comp(v.location), project: view, time: ks[k].time) else { return }
                                    let rounded = Vec2((value.x * 10).rounded() / 10, (value.y * 10).rounded() / 10)
                                    state.mutateLayer { layer in
                                        guard layer.transform.position.keyframes.indices.contains(k) else { return }
                                        layer.transform.position.keyframes[k].value = rounded
                                    }
                                }
                                .onEnded { _ in dragKey = nil; state.endLiveGesture(); state.endEdit() })
                    }
                }
            }
            .coordinateSpace(name: "motionPath")
        }
    }

    /// The two handle ends of key k (hollow = not curved yet), each 44 pt to grab.
    @ViewBuilder
    private func handles(_ l: Layer, _ ks: [Keyframe<Vec2>], _ k: Int, view: Project) -> some View {
        let key = ks[k]
        let curved = key.spatialOut != nil || key.spatialIn != nil
        let outT = key.spatialOut ?? MotionPathHandles.defaultTangent(ks, k)
        let inT = key.spatialIn ?? outT * -1
        if let c = MotionPathMath.screenPoint(l, value: key.value, project: view, time: key.time) {
            ForEach([true, false], id: \.self) { out in
                if let h = MotionPathMath.screenPoint(l, value: key.value + (out ? outT : inT), project: view, time: key.time) {
                    Path { p in p.move(to: screen(c)); p.addLine(to: screen(h)) }
                        .stroke(Theme.accentGlow.opacity(curved ? 0.9 : 0.45), style: StrokeStyle(lineWidth: 1, dash: curved ? [] : [3, 3]))
                        .allowsHitTesting(false)
                    Circle()
                        .fill(curved ? Theme.accent : Color.clear)
                        .overlay(Circle().stroke(Theme.accentGlow, lineWidth: 1.5))
                        .frame(width: 11, height: 11)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                        .position(screen(h))
                        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("motionPath"))
                            .onChanged { v in
                                if !dragHandle { dragHandle = true; state.beginEdit("Curve Motion Path"); state.beginLiveGesture() }
                                guard let value = MotionPathMath.value(l, at: comp(v.location), project: view, time: key.time) else { return }
                                let tangent = value - key.value
                                state.mutateLayer { layer in
                                    MotionPathHandles.setHandle(&layer.transform.position, key: k, out: out, tangent: tangent)
                                }
                            }
                            .onEnded { _ in dragHandle = false; state.endLiveGesture(); state.endEdit() })
                        .accessibilityLabel(out ? "Outgoing path handle" : "Incoming path handle")
                }
            }
        }
    }
}
