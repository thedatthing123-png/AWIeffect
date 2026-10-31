import SwiftUI
import simd

extension EditorState {
    func setCutout(_ c: CutoutSettings?) {
        guard let i = selectedIndex else { return }
        mutate(c == nil ? "Remove Cutout" : "AI Cutout") { $0.layers[i].cutout = c }
        CutoutEngine.shared.clear()
    }

    /// Tracks the object in `compRect` on the selected video layer and makes `targetID` follow it.
    func trackMotion(compRect: CGRect, targetID: UUID, progress: @escaping (Double) -> Void, done: @escaping (Int) -> Void) {
        guard let vi = selectedIndex, case .video(let file, _, _, _) = project.layers[vi].content,
              let ti = project.layers.firstIndex(where: { $0.id == targetID }) else { done(0); return }
        let video = project.layers[vi]
        let t0 = currentTime
        // Comp rect -> normalized source rect (top-left origin).
        let M0 = Renderer.layerMatrix(video, time: t0, renderScale: 1, includeEffects: false)
        let inv = M0.inverse
        let hs = Renderer.layerHalfSize(video, time: t0)
        func toUV(_ p: CGPoint) -> CGPoint {
            let q = inv * SIMD3(Double(p.x), Double(p.y), 1)
            return CGPoint(x: q.x / (2 * hs.x) + 0.5, y: q.y / (2 * hs.y) + 0.5)
        }
        let a = toUV(CGPoint(x: compRect.minX, y: compRect.minY)), b = toUV(CGPoint(x: compRect.maxX, y: compRect.maxY))
        let box = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
        let url = mediaURL(file)
        let s0 = video.sourceTime(at: t0), s1 = video.sourceTime(at: video.outPoint)
        let fps = project.fps
        let targetStart = project.layers[ti].transform.position.value(at: t0)
        Task.detached(priority: .userInitiated) {
            let samples = MotionTracker.track(url: url, box: box, start: s0, end: s1, fps: fps) { p in
                Task { @MainActor in progress(p) }
            }
            await MainActor.run {
                guard let first = samples.first else { done(0); return }
                func compPoint(_ uv: CGPoint, at t: Double) -> Vec2 {
                    let M = Renderer.layerMatrix(video, time: t, renderScale: 1, includeEffects: false)
                    let q = M * SIMD3((Double(uv.x) - 0.5) * 2 * hs.x, (Double(uv.y) - 0.5) * 2 * hs.y, 1)
                    return Vec2(q.x, q.y)
                }
                let origin = compPoint(first.1, at: t0)
                let offset = targetStart - origin
                self.mutate("Track Motion") { p in
                    var pos = p.layers[ti].transform.position
                    for (s, uv) in samples {
                        let t = video.inPoint + (s - video.sourceStart) / max(video.speed, 0.01)
                        pos.insertKeyframe(Keyframe(time: p.snapToFrame(t), value: compPoint(uv, at: t) + offset, interpolation: .linear))
                    }
                    p.layers[ti].transform.position = pos
                }
                done(samples.count)
            }
        }
    }
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
                    Menu {
                        ForEach(state.project.layers.filter { $0.id != state.selectedLayerID }) { l in Button(l.name) { target = l.id } }
                    } label: {
                        Text(target.flatMap { id in state.project.layers.first { $0.id == id }?.name } ?? "Follower layer…")
                            .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Theme.raised)).foregroundStyle(Theme.text)
                    }
                    Button("Cancel") { done() }.buttonStyle(.bordered).tint(Theme.danger)
                    Button("Track") { run() }.buttonStyle(.borderedProminent).tint(Theme.accent)
                        .disabled(rectView == nil || target == nil || progress != nil)
                }
            }
            .padding(.top, 6)
        }
    }

    private func run() {
        guard let r = rectView, let target else { return }
        let comp = CGRect(x: (r.minX - fit.minX) / scale, y: (r.minY - fit.minY) / scale, width: r.width / scale, height: r.height / scale)
        progress = 0
        state.trackMotion(compRect: comp, targetID: target, progress: { progress = $0 }) { n in
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
