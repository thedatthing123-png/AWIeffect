import SwiftUI
import simd

@MainActor final class CutoutSession: ObservableObject {
    @Published var model: CutoutStudioModel?
    func close() { model?.finish(); model = nil }
}

extension EditorState {
    func cutoutDisplayProject(_ base: Project) -> Project {
        guard cutoutPreview != nil || cutoutPeekOriginal != nil else { return base }
        var p = base
        if let preview = cutoutPreview, let i = p.layers.firstIndex(where: { $0.id == preview.layer }) { p.layers[i].cutout = preview.settings }
        if let id = cutoutPeekOriginal, let i = p.layers.firstIndex(where: { $0.id == id }) { p.layers[i].cutout = nil }
        return p
    }
}

struct InlineCutoutControls: View {
    @ObservedObject var model: CutoutStudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                mode("Keep", icon: "paintbrush.pointed", on: model.tool == .brush && model.keepBrush) { model.tool = .brush; model.keepBrush = true }
                mode("Cut", icon: "scissors", on: model.tool == .brush && !model.keepBrush) { model.tool = .brush; model.keepBrush = false }
                mode("Auto Box", icon: "viewfinder", on: model.tool == .box) { model.tool = .box }
            }
            if let progress = model.autoProgress {
                HStack {
                    ProgressView(value: progress).tint(Theme.accent)
                    Text("\(Int(progress * 100))%").font(.caption.monospacedDigit())
                    Button("Stop") { model.cancelAuto() }.frame(minWidth: 60, minHeight: 44)
                }
            }
            HStack {
                Text("Brush Size").font(.caption).frame(width: 88, alignment: .leading)
                ValueScrubber(value: model.brushSize, range: 4...180, step: 1, onChange: { model.brushSize = $0 })
            }.frame(minHeight: 44)
            HStack(spacing: 8) {
                Toggle("Smart Edges", isOn: $model.snapEdges).toggleStyle(.button).frame(maxWidth: .infinity, minHeight: 44)
                Text("Hold Original").font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised)).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { _ in model.state.cutoutPeekOriginal = model.layer.id }
                        .onEnded { _ in model.state.cutoutPeekOriginal = nil })
                    .accessibilityLabel("Hold Original")
            }
            Text(model.tool == .box ? "Drag a box around the subject. Video adapts across frames and keeps your manual fixes." : "Paint to \(model.keepBrush ? "keep" : "remove"). The canvas shows the cut result as you work.")
                .font(.caption).foregroundStyle(Theme.textDim)
            Picker("Subject", selection: Binding(get: { model.settings.mode }, set: { mode in model.edge("Cutout Subject") { $0.mode = mode } })) {
                ForEach(CutoutMode.allCases) { mode in Text(mode.title).tag(mode) }
            }.frame(minHeight: 44).pickerStyle(.menu)
            edge("Choke / Grow", model.settings.choke, -20...20) { $0.choke = $1 }
            edge("Edge Feather", model.settings.feather, 0...20) { $0.feather = $1 }
            edge("Edge Contrast", model.settings.edgeContrast, 0...100) { $0.edgeContrast = $1 }
            Toggle("Hair-safe Edge", isOn: Binding(get: { model.settings.edgeContrast <= 5 }, set: { on in
                model.edge("Hair-safe Edge") { $0.edgeContrast = on ? 0 : 40; if on { $0.feather = max(1, $0.feather) } }
            })).frame(minHeight: 44)
            Toggle("Invert", isOn: Binding(get: { model.settings.invert }, set: { value in model.edge("Invert Cutout") { $0.invert = value } })).frame(minHeight: 44)
            if model.isVideo {
                edge("Stability", model.settings.stability, 0...100) { $0.stability = $1 }
                FrameMarks(last: model.lastFrame, baked: model.bakedFrames, manual: model.manualFrames, current: model.frame).frame(height: 10)
                HStack {
                    Button { model.state.stepFrame(-1); model.followPlayhead() } label: { Label("Frame", systemImage: "chevron.left").frame(maxWidth: .infinity, minHeight: 44) }
                        .accessibilityLabel("Previous Cutout Frame")
                    Text("\(model.frame + 1) / \(model.lastFrame + 1)").font(.caption.monospacedDigit()).frame(maxWidth: .infinity)
                    Button { model.state.stepFrame(1); model.followPlayhead() } label: { Label("Frame", systemImage: "chevron.right").frame(maxWidth: .infinity, minHeight: 44) }
                        .accessibilityLabel("Next Cutout Frame")
                }
                Menu("Frame Actions") {
                    Button("Copy Previous Matte") { model.copyPrevious() }.disabled(model.frame == 0)
                    Button("Reset to Automatic") { model.resetFrame() }
                }.frame(minHeight: 44)
            }
        }.foregroundStyle(Theme.text).tint(Theme.accent).disabled(model.autoProgress != nil && model.tool == .box)
            .accessibilityIdentifier("remove-bg-tools")
    }
    private func mode(_ title: String, icon: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 9).fill(on ? Theme.accent : Theme.raised))
        }.buttonStyle(.plain).disabled(model.autoProgress != nil)
    }
    private func edge(_ title: String, _ value: Double, _ range: ClosedRange<Double>, _ set: @escaping (inout CutoutSettings, Double) -> Void) -> some View {
        HStack {
            Text(title).font(.caption).frame(width: 96, alignment: .leading)
            ValueScrubber(value: value, range: range, onChange: { value in model.edge(title) { set(&$0, value) } }, onEnd: { model.state.endEdit() })
        }.frame(minHeight: 44)
    }
}

struct InlineCutoutOverlay: View {
    @ObservedObject var model: CutoutStudioModel
    let fit: CGRect
    @State private var points: [CGPoint] = []
    @State private var boxStart: CGPoint?
    @State private var end: CGPoint?
    var body: some View {
        if let m = model.state.displayPlacement(of: model.layer.id) {
            let hs = Renderer.layerHalfSize(model.layer, time: model.state.currentTime)
            let scale = Double(fit.width) / Double(model.state.project.width)
            ZStack(alignment: .topLeading) {
                Color.clear.contentShape(Rectangle())
                Canvas { context, _ in
                    if !points.isEmpty {
                        var p = Path(); p.addLines(points)
                        context.stroke(p, with: .color((model.keepBrush ? Theme.ok : Theme.danger).opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                    if let a = boxStart, let b = end {
                        context.stroke(Path(CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y))), with: .color(Theme.ok), lineWidth: 2)
                    }
                }.allowsHitTesting(false)
            }.contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                guard model.autoProgress == nil else { return }
                if points.isEmpty && boxStart == nil { model.state.pause(); model.followPlayhead() }
                if model.tool == .brush {
                    points.append(g.location)
                    model.previewStroke(points.map { uv($0, matrix: m, half: hs, scale: scale) }, radius: model.brushSize / 2 / max(1, max(hs.x, hs.y) * 2 * scale))
                } else { boxStart = g.startLocation; end = g.location }
            }.onEnded { g in
                guard model.autoProgress == nil else { points = []; boxStart = nil; end = nil; return }
                if model.tool == .brush {
                    model.endStroke(points.map { uv($0, matrix: m, half: hs, scale: scale) }, radius: model.brushSize / 2 / max(1, max(hs.x,hs.y) * 2 * scale))
                    points = []
                } else {
                    let a = uv(boxStart ?? g.startLocation, matrix: m, half: hs, scale: scale), b = uv(g.location, matrix: m, half: hs, scale: scale)
                    boxStart = nil; end = nil
                    let box = CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y))
                    if box.width > 0.02 && box.height > 0.02 { model.runAuto(box: box) }
                }
            })
            .accessibilityIdentifier("inline-cutout-canvas")
        }
    }
    private func uv(_ p: CGPoint, matrix: simd_double3x3, half: Vec2, scale: Double) -> CGPoint {
        let q = matrix.inverse * SIMD3(Double(p.x - fit.minX) / scale, Double(p.y - fit.minY) / scale, 1)
        return CGPoint(x: min(1,max(0,q.x/q.z/max(1,half.x*2)+0.5)), y: min(1,max(0,q.y/q.z/max(1,half.y*2)+0.5)))
    }
}
