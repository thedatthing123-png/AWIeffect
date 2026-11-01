import SwiftUI

/// Cutout refine tools on the canvas (AE Roto Brush style): paint to add / remove from the AI matte, or tap a subject
/// to keep only it.
enum CutoutTool: String { case none, brush, pick }

extension EditorState {
    /// Comp point -> the selected media layer's source UV (0-1, top-left).
    func sourceUV(fromComp c: Vec2) -> Vec2? {
        guard let l = selectedLayer, let local = layerLocal(fromComp: c) else { return nil }
        let hs = Renderer.layerHalfSize(l, time: currentTime)
        guard hs.x > 0, hs.y > 0 else { return nil }
        return Vec2(local.x / (2 * hs.x) + 0.5, local.y / (2 * hs.y) + 0.5)
    }

    /// Adds one refine stroke (comp points + brush radius in comp px).
    func addCutoutStroke(comp pts: [Vec2], radius r: Double) {
        guard let l = selectedLayer, var c = l.cutout, let first = pts.first else { return }
        let uv = pts.compactMap { sourceUV(fromComp: $0) }
        guard !uv.isEmpty, let a = sourceUV(fromComp: first), let b = sourceUV(fromComp: Vec2(first.x + r, first.y)) else { return }
        let hs = Renderer.layerHalfSize(l, time: currentTime)
        // Radius in UV of the longer side.
        let du = hypot((b.x - a.x) * 2 * hs.x, (b.y - a.y) * 2 * hs.y) / (2 * max(hs.x, hs.y))
        var isVideo = false
        if case .video = l.content { isVideo = true }
        let stroke = CutoutStroke(points: uv, radius: max(0.002, du), subtract: cutoutBrushSubtract,
                                  time: isVideo && !cutoutWholeClip ? l.sourceTime(at: currentTime) : nil,
                                  span: cutoutFixSpan)
        c.strokes.append(stroke)
        setCutout(c)
    }

    func pickCutoutSubject(atComp p: Vec2) {
        guard var c = selectedLayer?.cutout, let uv = sourceUV(fromComp: p) else { return }
        if c.mode == .realistic { c.mode = .object }
        c.pick = uv
        setCutout(c)
        cutoutTool = .none
    }
}

/// Captures canvas touches while a cutout tool is active.
struct CutoutBrushOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var points: [CGPoint] = []

    private var scale: Double { Double(fit.width) / Double(max(state.project.width, 1)) }
    private func comp(_ p: CGPoint) -> Vec2 { Vec2(Double(p.x - fit.minX) / scale, Double(p.y - fit.minY) / scale) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.001)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { v in
                        if state.cutoutTool == .brush { points.append(v.location) }
                    }
                    .onEnded { v in
                        if state.cutoutTool == .pick { state.pickCutoutSubject(atComp: comp(v.location)); return }
                        guard !points.isEmpty else { return }
                        state.addCutoutStroke(comp: points.map(comp), radius: state.cutoutBrushSize / 2 / scale)
                        points = []
                    })
            // The stroke being painted.
            Canvas { ctx, _ in
                guard points.count > 0 else { return }
                var path = Path(); path.addLines(points.count == 1 ? [points[0], points[0]] : points)
                ctx.stroke(path, with: .color((state.cutoutBrushSubtract ? Color.red : Theme.ok).opacity(0.45)),
                           style: StrokeStyle(lineWidth: state.cutoutBrushSize, lineCap: .round, lineJoin: .round))
            }
            .allowsHitTesting(false)
            Text(state.cutoutTool == .pick ? "Tap the subject to keep"
                 : (state.cutoutBrushSubtract ? "Paint over what to REMOVE" : "Paint over what to KEEP"))
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(.black.opacity(0.6)))
                .padding(.top, 6).allowsHitTesting(false)
        }
    }
}

/// Refine controls inside the cutout section.
struct CutoutRefineControls: View {
    @ObservedObject var state: EditorState
    let c: CutoutSettings
    let isVideo: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REFINE").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
            HStack(spacing: 6) {
                toolButton("Brush", "paintbrush.pointed.fill", .brush)
                toolButton("Tap Subject", "hand.tap.fill", .pick)
                if state.cutoutTool != .none {
                    Button("Done") { state.cutoutTool = .none }.font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accentGlow)
                }
            }
            if state.cutoutTool == .brush {
                Picker("", selection: $state.cutoutBrushSubtract) {
                    Text("Keep (+)").tag(false)
                    Text("Remove (−)").tag(true)
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Brush Size").font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 96, alignment: .leading)
                    ValueScrubber(value: state.cutoutBrushSize, range: 6...160, step: 1, unit: "pt", onChange: { state.cutoutBrushSize = $0 })
                }
                if isVideo {
                    Picker("", selection: $state.cutoutWholeClip) {
                        Text("Fix this moment").tag(false)
                        Text("Whole clip").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if !state.cutoutWholeClip {
                        HStack {
                            Text("Fix reaches").font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 96, alignment: .leading)
                            ValueScrubber(value: state.cutoutFixSpan, range: 0.05...3, step: 0.05, unit: "s", onChange: { state.cutoutFixSpan = $0 })
                        }
                    }
                }
            }
            HStack {
                Text("\(c.strokes.count) fix\(c.strokes.count == 1 ? "" : "es")\(c.pick != nil ? " · picked subject" : "")")
                    .font(.caption).foregroundStyle(Theme.textDim)
                Spacer()
                if !c.strokes.isEmpty {
                    Button("Undo Fix") { var n = c; n.strokes.removeLast(); state.setCutout(n) }.font(.caption)
                    Button("Clear") { var n = c; n.strokes = []; state.setCutout(n) }.font(.caption).foregroundStyle(Theme.danger)
                }
                if c.pick != nil { Button("All Subjects") { var n = c; n.pick = nil; state.setCutout(n) }.font(.caption) }
            }
        }
        .onDisappear { state.cutoutTool = .none }
    }

    private func toolButton(_ t: String, _ s: String, _ tool: CutoutTool) -> some View {
        Button { state.cutoutTool = state.cutoutTool == tool ? .none : tool } label: {
            Label(t, systemImage: s).font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Capsule().fill(state.cutoutTool == tool ? Theme.accent : Theme.raised))
                .foregroundStyle(state.cutoutTool == tool ? Color.white : Theme.text)
        }
        .buttonStyle(.plain)
    }
}
