import SwiftUI
import simd

extension EditorState {
    func setCutout(_ c: CutoutSettings?) {
        guard let i = selectedIndex else { return }
        // The AI matte cache is keyed by mode / stability, so slider moves reuse it (smooth, no re-running the AI).
        mutate(c == nil ? "Remove Cutout" : "AI Cutout") { $0.layers[i].cutout = c }
    }

    /// Tracks the object in `compRect` on the selected video layer and makes `targetID` follow it.
    func trackMotion(compRect: CGRect, targetID: UUID, smoothing: Double = 0, progress: @escaping (Double) -> Void, done: @escaping (Int) -> Void) {
        guard let vi = selectedIndex, case .video(let file, _, _, _) = project.layers[vi].content,
              let ti = project.layers.firstIndex(where: { $0.id == targetID }) else { done(0); return }
        motionTrackingTask?.cancel()
        let snapshot = project, video = project.layers[vi], target = project.layers[ti]
        let t0 = max(video.inPoint, currentTime), t1 = min(video.outPoint, project.duration)
        guard t1 > t0 else { done(0); return }
        let initial = Self.trackingMatrix(video, in: snapshot, time: t0)
        guard abs(initial.determinant) > 1e-10 else { done(0); return }
        let inverse = initial.inverse, hs = Renderer.layerHalfSize(video, time: t0)
        let corners = [CGPoint(x: compRect.minX, y: compRect.minY), CGPoint(x: compRect.maxX, y: compRect.minY), CGPoint(x: compRect.maxX, y: compRect.maxY), CGPoint(x: compRect.minX, y: compRect.maxY)].map { point -> CGPoint in
            let q = inverse * SIMD3(Double(point.x), Double(point.y), 1)
            return CGPoint(x: q.x / q.z / max(1, 2 * hs.x) + 0.5, y: q.y / q.z / max(1, 2 * hs.y) + 0.5)
        }
        guard corners.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { done(0); return }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        let box = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        let url = mediaURL(file), fps = project.fps
        let targetStart = (Renderer.resolveParenting(snapshot, time: t0).layers.first(where: { $0.id == target.id }) ?? target).transform.position.value(at: t0)
        motionTrackingTask = Task.detached(priority: .userInitiated) { [weak self] in
            let rawSamples = MotionTracker.track(url: url, box: box, start: t0, end: t1, fps: fps, sourceTime: { t in
                video.sourceTime(at: video.timeFX?.localTime(t) ?? t)
            }) { p in
                guard !Task.isCancelled else { return }
                Task { @MainActor in progress(p) }
            }
            let samples = MotionTracker.smoothed(rawSamples, radius: Int(smoothing.rounded()))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.project.id == snapshot.id,
                      self.project.layers.first(where: { $0.id == video.id }) == video,
                      self.project.layers.first(where: { $0.id == target.id }) == target,
                      let index = self.project.layers.firstIndex(where: { $0.id == target.id }),
                      samples.count > 1, let first = samples.first else { done(0); return }
                func compPoint(_ uv: CGPoint, at t: Double) -> Vec2 {
                    let q = Self.trackingMatrix(video, in: snapshot, time: t) * SIMD3((Double(uv.x) - 0.5) * 2 * hs.x, (Double(uv.y) - 0.5) * 2 * hs.y, 1)
                    return Vec2(q.x / q.z, q.y / q.z)
                }
                let offset = targetStart - compPoint(first.1, at: t0)
                self.mutate("Track Motion") { p in
                    var pos = p.layers[index].transform.position
                    for (t, uv) in samples {
                        var value = compPoint(uv, at: t) + offset
                        if let parent = target.parentID, let parentSpace = Renderer.parentAffine(parent, in: snapshot, time: t) {
                            let local = parentSpace.m.inverse * SIMD3(value.x, value.y, 1)
                            value = Vec2(local.x, local.y)
                        }
                        guard value.x.isFinite, value.y.isFinite else { continue }
                        pos.insertKeyframe(Keyframe(time: p.snapToFrame(t), value: value, interpolation: .linear))
                    }
                    p.layers[index].transform.position = pos
                }
                done(samples.count)
            }
        }
    }
    nonisolated static func trackingMatrix(_ video: Layer, in project: Project, time: Double) -> simd_double3x3 {
        let resolved = Renderer.resolveParenting(ExpressionResolver.resolve(project, time: time), time: time)
        let layer = resolved.layers.first(where: { $0.id == video.id }) ?? video
        return Renderer.placementMatrix(layer, camera: Renderer.activeCamera(resolved, time: time), time: time, renderScale: 1)
    }
    func cancelMotionTracking() { motionTrackingTask?.cancel(); motionTrackingTask = nil }

}

/// AI cutout controls (image/video layers).
struct CutoutSection: View {
    @ObservedObject var state: EditorState
    var body: some View {
        if let l = state.selectedLayer, l.mediaFile != nil, !(l.hasAudio && { if case .audio = l.content { return true }; return false }()) {
            let c = l.cutout
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Background Cutout").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                Picker("Mode", selection: Binding(get: { c?.mode }, set: { m in
                    if let m { var n = c ?? CutoutSettings(); n.mode = m; state.setCutout(n) } else { state.setCutout(nil) }
                })) {
                    Text("Off").tag(CutoutMode?.none)
                    ForEach(CutoutMode.allCases) { Text($0.title).tag(CutoutMode?.some($0)) }
                }
                .pickerStyle(.menu).tint(Theme.accentGlow)
                if let c {
                    slider("Choke / Grow", c.choke, -10...10) { v in var n = c; n.choke = v; state.setCutout(n) }
                    slider("Edge Feather", c.feather, 0...10) { v in var n = c; n.feather = v; state.setCutout(n) }
                    slider("Edge Contrast", c.edgeContrast, 0...100) { v in var n = c; n.edgeContrast = v; state.setCutout(n) }
                    if case .video = l.content {
                        slider("Stability", c.stability, 0...100) { v in var n = c; n.stability = v; state.setCutout(n) }
                    }
                    Toggle("Invert (keep background)", isOn: Binding(get: { c.invert }, set: { b in var n = c; n.invert = b; state.setCutout(n) }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                    CutoutRefineControls(state: state, c: c, isVideo: { if case .video = l.content { return true }; return false }())
                    Text("Runs on-device. Stability smooths the edge between video frames; Edge Contrast cleans soft edges (keep it low for hair). For exact part-by-part cuts use Redraw → Select Brush.").font(.caption).foregroundStyle(Theme.textDim)
                }
            }
            .padding(10).glass(radius: 12)
        }
    }

    private func slider(_ t: String, _ v: Double, _ r: ClosedRange<Double>, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(t).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 96, alignment: .leading)
            ValueScrubber(value: v, range: r, onChange: set)
        }
    }
}

/// Canvas overlay: drag a box around what to track, pick the layer that should follow it.
struct TrackOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    let done: () -> Void
    @State private var start: CGPoint?
    @State private var end: CGPoint?
    @State private var target: UUID?
    @State private var progress: Double?
    @State private var result: String?
    @State private var smoothing = 0.0

    private var scale: Double { Double(fit.width) / Double(state.project.width) }
    private var rectView: CGRect? {
        guard let s = start, let e = end else { return nil }
        return CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.001)
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in start = v.startLocation; end = v.location })
            if let r = rectView {
                Rectangle().stroke(Theme.ok, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY).allowsHitTesting(false)
            }
            VStack(spacing: 6) {
                Text(progress.map { "Tracking… \(Int($0 * 100))%" } ?? result ?? "Drag a box around what to track")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(.black.opacity(0.6)))
                HStack {
                    Text("Smoothing: \(Int(smoothing)) frames").font(.caption)
                    Slider(value: $smoothing, in: 0...15, step: 1).frame(width: 120)
                }.foregroundStyle(.white).disabled(progress != nil)
                HStack {
                    Menu {
                        ForEach(state.project.layers.filter { $0.id != state.selectedLayerID }) { l in Button(l.name) { target = l.id } }
                    } label: {
                        Text(target.flatMap { id in state.project.layers.first { $0.id == id }?.name } ?? "Follower layer…")
                            .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Theme.raised)).foregroundStyle(Theme.text)
                    }
                    Button("Cancel") { state.cancelMotionTracking(); done() }.buttonStyle(.bordered).tint(Theme.danger)
                    Button("Track") { run() }.buttonStyle(.borderedProminent).tint(Theme.accent)
                        .disabled(rectView == nil || target == nil || progress != nil)
                }
            }
            .padding(.top, 6)
        }
        .onDisappear { state.cancelMotionTracking() }
    }

    private func run() {
        guard let r = rectView, let target else { return }
        let comp = CGRect(x: (r.minX - fit.minX) / scale, y: (r.minY - fit.minY) / scale, width: r.width / scale, height: r.height / scale)
        progress = 0
        state.trackMotion(compRect: comp, targetID: target, smoothing: smoothing, progress: { progress = $0 }) { n in
            progress = nil
            result = n > 1 ? "Tracked \(n) frames ✓" : "Couldn't track that area. Try a bigger, more detailed box."
            if n > 1 { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { done() } }
        }
    }
}

/// Lets the clip panel start tracking on the canvas.
final class TrackLauncher: ObservableObject {
    @Published var active = false
}
