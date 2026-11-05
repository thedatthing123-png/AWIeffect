import SwiftUI
import AVFoundation

/// Frame-by-frame background removal: brush a selection, choose Keep or Cut, go to the next frame.
/// Auto: draw a box and it follows the subject through the clip. A bad frame gets fixed alone; no other frame changes.
@MainActor
final class CutoutStudioModel: ObservableObject, Identifiable {
    enum Tool { case brush, box }
    enum Show: String, CaseIterable { case cut = "Cutout", overlay = "Overlay", original = "Original" }

    let state: EditorState
    let layer: Layer
    let url: URL
    let isVideo: Bool
    let lastFrame: Int
    let rate: Double
    @Published var settings: CutoutSettings
    @Published var frame: Int
    @Published var picture: UIImage?
    private var pictureCG: CGImage?
    @Published var matteImage: UIImage?
    @Published var dimImage: UIImage?
    @Published var selectionImage: UIImage?
    @Published var tool = Tool.brush
    @Published var show = Show.overlay
    @Published var brushSize = 40.0
    @Published var snapEdges = true
    @Published var subtractStroke = false
    @Published var autoProgress: Double?
    @Published var bakedFrames: Set<Int> = []
    @Published var hasUndo = false
    private var matte: MatteFrame?
    private var selection: [UInt8]?
    private var undo: [(frame: Int, matte: MatteFrame?)] = []
    private var autoTask: Task<Void, Never>?
    private var loadID = 0

    var hasSelection: Bool { selection != nil }
    var manualFrames: Set<Int> { Set(settings.manualFrames) }
    var bakeID: String { settings.bakeID ?? "" }

    init(state: EditorState, layer: Layer, url: URL) {
        self.state = state; self.layer = layer; self.url = url
        var video = false
        if case .video = layer.content { video = true }
        isVideo = video
        var s = layer.cutout ?? CutoutSettings(mode: .drawn)
        if s.bakeID == nil { s.bakeID = UUID().uuidString }
        var fps = s.bakeRate ?? 30
        var duration = 0.0
        if video, s.bakeRate == nil {
            let asset = AVURLAsset(url: url)
            if let t = asset.tracks(withMediaType: .video).first, t.nominalFrameRate > 0 { fps = min(60, Double(t.nominalFrameRate)) }
        }
        if video { duration = AVURLAsset(url: url).duration.seconds }
        s.bakeRate = fps
        settings = s; rate = fps
        lastFrame = video ? max(0, Int(duration * fps) - 1) : 0
        frame = video ? min(max(0, Int(layer.sourceTime(at: state.currentTime) * fps)), max(0, Int(duration * fps) - 1)) : 0
        scanBaked()
        load()
    }

    private func path(_ f: Int) -> URL { state.mediaURL(CutoutBake.fileName(bakeID, frame: f)) }

    private func scanBaked() {
        let prefix = "matte-\(bakeID)-"
        let folder = path(0).deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        bakedFrames = Set(names.compactMap { n in
            guard n.hasPrefix(prefix), n.hasSuffix(".awimatte") else { return nil }
            return Int(n.dropFirst(prefix.count).dropLast(9))
        })
    }

    func go(to f: Int) {
        let target = min(max(0, f), lastFrame)
        guard target != frame else { return }
        frame = target
        selection = nil; selectionImage = nil
        load()
    }

    private func load() {
        loadID += 1
        let id = loadID, f = frame, url = url, video = isVideo, rate = rate
        let saved = path(f)
        Task.detached(priority: .userInitiated) {
            let cg: CGImage?
            if video { cg = VideoSources.shared.cgImage(url: url, time: (Double(f) + 0.5) / rate, maxSize: 1024) }
            else { cg = CIImage(contentsOf: url).flatMap { ci in
                let k = min(1, 1024 / max(ci.extent.width, ci.extent.height))
                let scaled = ci.transformed(by: CGAffineTransform(scaleX: k, y: k))
                return CIContext().createCGImage(scaled, from: scaled.extent)
            } }
            let stored = CutoutBake.load(saved)
            await MainActor.run {
                guard id == self.loadID else { return }
                self.pictureCG = cg
                self.picture = cg.map { UIImage(cgImage: $0) }
                if let cg { self.matte = stored ?? MatteFrame.filled(cg.width, cg.height, 255) }
                self.refreshMatte()
            }
        }
    }

    private func refreshMatte() {
        guard let matte else { matteImage = nil; dimImage = nil; return }
        matteImage = matte.image()
        var outside = matte
        for i in outside.bytes.indices { outside.bytes[i] = 255 - outside.bytes[i] }
        dimImage = outside.image(color: (230, 40, 70))
    }

    /// A finished stroke (points in 0-1 picture coordinates) adds to or removes from the selection.
    func addStroke(_ points: [CGPoint], radius: CGFloat) {
        guard let matte, let cg = pictureCG, !points.isEmpty else { return }
        let w = matte.width, h = matte.height
        var sel = selection ?? [UInt8](repeating: 0, count: w * h)
        let r = max(1.5, Double(radius) * Double(max(w, h)))
        let pixelsPoints = points.map { (Double($0.x) * Double(w), Double($0.y) * Double(h)) }
        var region = [UInt8](repeating: 0, count: w * h)
        if snapEdges {
            var seeds: [(Int, Int)] = []
            for (a, b) in zip(pixelsPoints, pixelsPoints.dropFirst() + [pixelsPoints.last!]) {
                let n = max(1, Int(hypot(b.0 - a.0, b.1 - a.1) / 3))
                for k in 0..<n {
                    let t = Double(k) / Double(n)
                    seeds.append((Int(a.0 + (b.0 - a.0) * t), Int(a.1 + (b.1 - a.1) * t)))
                }
            }
            DrawEngine.floodRegion(CutoutBake.pixels(of: cg, width: w, height: h), w, h, seeds: seeds, tolerance: 0.1, reach: Int(r * 2.5)) { region[$0] = 255 }
            DrawEngine.soften(&region, w, h)
        } else {
            let stroke = CutoutStroke(points: points.map { Vec2(Double($0.x), Double($0.y)) }, radius: Double(radius), subtract: false)
            CutoutEngine.paint([stroke], into: &region, w: w, h: h)
        }
        for i in sel.indices { sel[i] = subtractStroke ? min(sel[i], 255 - region[i]) : max(sel[i], region[i]) }
        selection = sel.contains { $0 > 0 } ? sel : nil
        selectionImage = selection.map { MatteFrame(width: w, height: h, bytes: $0) }?.image(color: (155, 92, 255))
    }

    func clearSelection() { selection = nil; selectionImage = nil }

    private func remember() {
        undo.append((frame, CutoutBake.load(path(frame))))
        if undo.count > 30 { undo.removeFirst() }
        hasUndo = true
    }

    private func store(_ m: MatteFrame) {
        matte = m
        try? CutoutBake.save(m, to: path(frame))
        bakedFrames.insert(frame)
        if !settings.manualFrames.contains(frame) { settings.manualFrames.append(frame) }
        settings.bakeRevision = (settings.bakeRevision ?? 0) + 1
        refreshMatte()
    }

    /// Keep or Cut: only this frame changes.
    func commit(keep: Bool) {
        guard var m = matte, let sel = selection else { return }
        remember()
        m.apply(selection: sel, keep: keep)
        store(m)
        clearSelection()
    }

    func undoLast() {
        guard let last = undo.popLast() else { return }
        hasUndo = !undo.isEmpty
        let f = last.frame
        if let m = last.matte { try? CutoutBake.save(m, to: path(f)) } else {
            try? FileManager.default.removeItem(at: path(f))
            bakedFrames.remove(f)
        }
        settings.manualFrames.removeAll { $0 == f }
        settings.bakeRevision = (settings.bakeRevision ?? 0) + 1
        frame = f
        load()
    }

    /// Starts this frame from the previous one's matte.
    func copyPrevious() {
        guard frame > 0, let m = CutoutBake.load(path(frame - 1)) else { return }
        remember(); store(m)
    }

    /// Back to automatic for this frame.
    func resetFrame() {
        remember()
        try? FileManager.default.removeItem(at: path(frame))
        bakedFrames.remove(frame)
        settings.manualFrames.removeAll { $0 == frame }
        settings.bakeRevision = (settings.bakeRevision ?? 0) + 1
        load()
    }

    func runAuto(box: CGRect) {
        guard isVideo, autoTask == nil else { return }
        let job = CutoutBake.AutoJob(url: url, bakeID: bakeID, folder: { [state] in state.mediaURL($0) }, box: box,
                                     startFrame: frame, lastFrame: lastFrame, rate: rate, mode: settings.mode, locked: manualFrames)
        autoProgress = 0
        tool = .brush
        autoTask = Task.detached(priority: .userInitiated) { [weak self] in
            let written = CutoutBake.runAuto(job) { p in
                Task { @MainActor in self?.autoProgress = p }
            }
            await MainActor.run {
                guard let self else { return }
                self.bakedFrames.formUnion(written)
                self.settings.bakeRevision = (self.settings.bakeRevision ?? 0) + 1
                self.autoProgress = nil; self.autoTask = nil
                self.load()
            }
        }
    }

    func cancelAuto() { autoTask?.cancel() }

    func finish() {
        autoTask?.cancel()
        state.setCutout(settings)
    }
}

struct CutoutStudioView: View {
    @StateObject var model: CutoutStudioModel
    @Environment(\.dismiss) private var dismiss
    @State private var points: [CGPoint] = []
    @State private var boxStart: CGPoint?
    @State private var boxEnd: CGPoint?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvas.frame(maxWidth: .infinity, maxHeight: .infinity)
            controls
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { model.finish(); dismiss() } label: { Text("Done").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.accentGlow) }
            Text("Cutout Studio").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
            Spacer()
            Button { model.undoLast() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!model.hasUndo)
                .foregroundStyle(model.hasUndo ? Theme.text : Theme.textDim.opacity(0.4)).accessibilityLabel("Undo")
            Picker("", selection: $model.show) {
                ForEach(CutoutStudioModel.Show.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).frame(width: 210)
        }
        .padding(.horizontal, 12).frame(height: 48)
    }

    private var canvas: some View {
        GeometryReader { g in
            let rect = pictureRect(in: g.size)
            ZStack(alignment: .topLeading) {
                if let picture = model.picture {
                    Group {
                        switch model.show {
                        case .original:
                            Image(uiImage: picture).resizable()
                        case .overlay:
                            ZStack {
                                Image(uiImage: picture).resizable()
                                if let dim = model.dimImage { Image(uiImage: dim).resizable().opacity(0.55) }
                            }
                        case .cut:
                            ZStack {
                                Checker()
                                Image(uiImage: picture).resizable().mask { if let m = model.matteImage { Image(uiImage: m).resizable() } else { Color.white } }
                            }
                        }
                    }
                    .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                    if let sel = model.selectionImage {
                        Image(uiImage: sel).resizable().opacity(0.6).frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                    }
                } else {
                    ProgressView().tint(Theme.accentGlow).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Canvas { ctx, _ in
                    if points.count > 0 {
                        var p = Path(); p.addLines(points.count == 1 ? [points[0], points[0]] : points)
                        ctx.stroke(p, with: .color((model.subtractStroke ? Theme.danger : Theme.accentGlow).opacity(0.5)),
                                   style: StrokeStyle(lineWidth: model.brushSize, lineCap: .round, lineJoin: .round))
                    }
                    if let a = boxStart, let b = boxEnd {
                        ctx.stroke(Path(CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))),
                                   with: .color(Theme.ok), lineWidth: 2)
                    }
                }
                .allowsHitTesting(false)
                if let p = points.last, let picture = model.picture { loupe(picture, rect: rect, at: p, size: g.size) }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                if model.tool == .brush { points.append(v.location) } else { boxStart = v.startLocation; boxEnd = v.location }
            }.onEnded { v in
                if model.tool == .brush {
                    model.addStroke(points.map { uv($0, rect) }, radius: model.brushSize / 2 / max(rect.width, rect.height))
                    points = []
                } else if let a = boxStart {
                    let p = uv(a, rect), q = uv(v.location, rect)
                    let box = CGRect(x: min(p.x, q.x), y: min(p.y, q.y), width: abs(p.x - q.x), height: abs(p.y - q.y))
                    boxStart = nil; boxEnd = nil
                    if box.width > 0.02, box.height > 0.02 { model.runAuto(box: box) }
                }
            })
        }
        .clipped()
    }

    /// Shows what's under the finger, up and away from it.
    private func loupe(_ picture: UIImage, rect: CGRect, at p: CGPoint, size: CGSize) -> some View {
        let zoom: CGFloat = 3
        return Image(uiImage: picture).resizable()
            .frame(width: rect.width * zoom, height: rect.height * zoom)
            .offset(x: 56 - (p.x - rect.minX) * zoom, y: 56 - (p.y - rect.minY) * zoom)
            .frame(width: 112, height: 112, alignment: .topLeading)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .overlay(Image(systemName: "plus").foregroundStyle(.white).shadow(radius: 1))
            .position(x: min(max(62, p.x), size.width - 62), y: p.y > 150 ? p.y - 96 : p.y + 96)
            .allowsHitTesting(false)
    }

    private func pictureRect(in size: CGSize) -> CGRect {
        guard let p = model.picture, p.size.width > 0, p.size.height > 0 else { return CGRect(origin: .zero, size: size) }
        let k = min(size.width / p.size.width, size.height / p.size.height)
        let w = p.size.width * k, h = p.size.height * k
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private func uv(_ p: CGPoint, _ r: CGRect) -> CGPoint {
        CGPoint(x: min(max(0, (p.x - r.minX) / max(1, r.width)), 1), y: min(max(0, (p.y - r.minY) / max(1, r.height)), 1))
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if let progress = model.autoProgress {
                HStack(spacing: 10) {
                    ProgressView(value: progress).tint(Theme.accent)
                    Text("\(Int(progress * 100))%").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.text)
                    chip("Stop", "stop.fill") { model.cancelAuto() }
                }
            } else if model.hasSelection {
                HStack(spacing: 8) {
                    actionButton("Keep", "checkmark", Theme.ok) { model.commit(keep: true) }
                    actionButton("Cut", "scissors", Theme.danger) { model.commit(keep: false) }
                    chip("Clear", "xmark") { model.clearSelection() }
                }
            } else {
                brushRow
            }
            if model.isVideo { frameRow }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.surface)
    }

    private var brushRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Picker("", selection: $model.tool) {
                    Text("Brush").tag(CutoutStudioModel.Tool.brush)
                    if model.isVideo { Text("Auto Box").tag(CutoutStudioModel.Tool.box) }
                }.pickerStyle(.segmented)
                Toggle("Snap", isOn: $model.snapEdges).toggleStyle(.button).tint(Theme.accent).font(.system(size: 12, weight: .semibold))
                Toggle("Erase", isOn: $model.subtractStroke).toggleStyle(.button).tint(Theme.accent).font(.system(size: 12, weight: .semibold))
            }
            if model.tool == .brush {
                HStack {
                    Text("Size").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textDim)
                    Slider(value: $model.brushSize, in: 6...160).tint(Theme.accent)
                }
            } else {
                Text("Draw a box around the subject. It follows through the clip and leaves frames you fixed by hand alone.")
                    .font(.system(size: 12)).foregroundStyle(Theme.textDim).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var frameRow: some View {
        VStack(spacing: 4) {
            FrameMarks(last: model.lastFrame, baked: model.bakedFrames, manual: model.manualFrames, current: model.frame).frame(height: 8)
            Slider(value: Binding(get: { Double(model.frame) }, set: { model.go(to: Int($0)) }), in: 0...Double(max(1, model.lastFrame)), step: 1).tint(Theme.accent)
            HStack(spacing: 8) {
                Button { model.go(to: model.frame - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 36) }.accessibilityLabel("Previous Frame")
                Text("\(model.frame + 1) / \(model.lastFrame + 1)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.text)
                Button { model.go(to: model.frame + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 36) }.accessibilityLabel("Next Frame")
                Spacer()
                chip("Copy Prev", "doc.on.doc") { model.copyPrevious() }
                chip("Reset", "arrow.counterclockwise") { model.resetFrame() }
            }
            .foregroundStyle(Theme.text)
        }
    }

    private func actionButton(_ t: String, _ s: String, _ color: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Label(t, systemImage: s).font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 11).fill(color)).foregroundStyle(.white)
        }
        .accessibilityLabel(t)
    }

    private func chip(_ t: String, _ s: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Label(t, systemImage: s).font(.system(size: 12, weight: .semibold)).lineLimit(1).fixedSize()
                .padding(.horizontal, 10).padding(.vertical, 8).background(Capsule().fill(Theme.raised)).foregroundStyle(Theme.text)
        }
    }
}

/// Which frames are done: blue = automatic, green = fixed by hand.
private struct FrameMarks: View {
    let last: Int
    let baked: Set<Int>
    let manual: Set<Int>
    let current: Int
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.raised))
            let w = size.width / CGFloat(max(1, last + 1))
            for f in baked {
                ctx.fill(Path(CGRect(x: CGFloat(f) * w, y: 0, width: max(1, w), height: size.height)),
                         with: .color(manual.contains(f) ? Theme.ok : Theme.accent))
            }
            ctx.fill(Path(CGRect(x: CGFloat(current) * w, y: 0, width: max(2, w), height: size.height)), with: .color(.white))
        }
        .clipShape(Capsule())
    }
}

private struct Checker: View {
    var body: some View {
        Canvas { ctx, size in
            let cell: CGFloat = 12
            for y in 0...Int(size.height / cell) { for x in 0...Int(size.width / cell) {
                ctx.fill(Path(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)),
                         with: .color((x + y) % 2 == 0 ? Color(white: 0.85) : Color(white: 0.65)))
            } }
        }
    }
}
