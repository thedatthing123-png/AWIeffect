import SwiftUI
import AVFoundation
import Metal
import CoreImage
import CoreVideo

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
    @Published var show = Show.cut
    @Published var brushSize = 40.0
    @Published var snapEdges = true
    @Published var subtractStroke = false
    @Published var keepBrush = true
    @Published var autoProgress: Double?
    @Published var bakedFrames: Set<Int> = []
    @Published var hasUndo = false
    private var matte: MatteFrame?
    private var selection: [UInt8]?
    private var undo: [(frame: Int, matte: MatteFrame?)] = []
    private var autoTask: Task<Void, Never>?
    private var loadID = 0
    private var closed = false
    private let previewID = UUID().uuidString
    private var previewRevision = 0
    private var previewTime: TimeInterval = 0
    private let projectID: UUID

    var hasSelection: Bool { selection != nil }
    var manualFrames: Set<Int> { Set(settings.manualFrames) }
    var bakeID: String { settings.bakeID ?? "" }

    init(state: EditorState, layer: Layer, url: URL) {
        self.state = state; self.layer = layer; self.url = url; projectID = state.project.id
        var video = false
        if case .video = layer.content { video = true }
        isVideo = video
        var s = layer.cutout ?? CutoutSettings(mode: .drawn)
        if layer.cutout == nil { s.manualOnly = true }
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

    private func path(_ f: Int) -> URL {
        let id = settings.bakeOverrides?[String(f)] ?? bakeID
        return state.mediaURL(CutoutBake.fileName(id.isEmpty ? "none" : id, frame: f))
    }
    private var active: Bool { !closed && state.project.id == projectID && state.selectedLayerID == layer.id && state.project.layers.first(where: { $0.id == layer.id })?.content == layer.content }

    func followPlayhead() {
        guard isVideo else { return }
        go(to: Int(layer.sourceTime(at: state.currentTime) * rate))
        if autoProgress != nil { state.cutoutPreview = (layer.id, settings) }
    }
    func sync(_ value: CutoutSettings?) {
        guard autoProgress == nil else { return }
        let missing = value == nil
        var value = value ?? CutoutSettings(mode: .drawn)
        if missing { value.manualOnly = true }
        if value.bakeID == nil { value.bakeID = UUID().uuidString }
        value.bakeRate = value.bakeRate ?? rate
        settings = value; scanBaked(); load()
    }
    private func publish(_ label: String) {
        guard active else { return }
        let id = layer.id, value = settings
        state.mutate(label) { p in if let i = p.layers.firstIndex(where: { $0.id == id }) { p.layers[i].cutout = value } }
        state.cutoutPreview = nil
    }
    func edge(_ label: String, _ change: (inout CutoutSettings) -> Void) {
        change(&settings)
        guard active, state.project.layers.first(where: { $0.id == layer.id })?.cutout != nil else { return }
        let value = settings
        state.coalescedEdit(label) { $0.cutout = value }
    }

    private func scanBaked() {
        let prefix = "matte-\(bakeID)-"
        let folder = path(0).deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        bakedFrames = Set(names.compactMap { n in
            guard n.hasPrefix(prefix), n.hasSuffix(".awimatte") else { return nil }
            return Int(n.dropFirst(prefix.count).dropLast(9))
        })
        for (frame, id) in settings.bakeOverrides ?? [:] {
            guard let f = Int(frame) else { continue }
            if id.isEmpty { bakedFrames.remove(f) } else { bakedFrames.insert(f) }
        }
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
        let saved = path(f), existing = state.project.layers.first(where: { $0.id == layer.id }), renderer = Renderer.shared
        let media: (String) -> URL = { [state] in state.mediaURL($0) }
        Task.detached(priority: .userInitiated) {
            let cg: CGImage?
            if video { cg = VideoSources.shared.cgImage(url: url, time: (Double(f) + 0.5) / rate, maxSize: 1024) }
            else { cg = CIImage(contentsOf: url).flatMap { ci in
                let k = min(1, 1024 / max(ci.extent.width, ci.extent.height))
                let scaled = ci.transformed(by: CGAffineTransform(scaleX: k, y: k))
                return CIContext().createCGImage(scaled, from: scaled.extent)
            } }
            var stored = CutoutBake.load(saved)
            if stored == nil, let existing, existing.cutout != nil, let renderer,
               let tex = CutoutEngine.shared.matte(for: existing, sourceTime: Double(f) / rate, mediaURL: media, device: renderer.device) {
                var bytes = [UInt8](repeating: 0, count: tex.width * tex.height)
                tex.getBytes(&bytes, bytesPerRow: tex.width, from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
                stored = MatteFrame(width: tex.width, height: tex.height, bytes: bytes)
            }
            await MainActor.run {
                guard id == self.loadID, !self.closed else { return }
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

    /// A temporary plain-brush matte follows the finger; the finished stroke uses Smart Edges and commits once.
    func previewStroke(_ points: [CGPoint], radius: CGFloat) {
        let now = Date.timeIntervalSinceReferenceDate
        guard active, now - previewTime > 0.05, var m = matte else { return }
        previewTime = now
        var sel = [UInt8](repeating: 0, count: m.width * m.height)
        let stroke = CutoutStroke(points: points.map { Vec2(Double($0.x), Double($0.y)) }, radius: Double(radius), subtract: false)
        CutoutEngine.paint([stroke], into: &sel, w: m.width, h: m.height)
        if keepBrush, !bakedFrames.contains(frame), state.selectedLayer?.cutout == nil { m = .filled(m.width, m.height, 0) }
        m.apply(selection: sel, keep: keepBrush)
        guard (try? CutoutBake.save(m, to: state.mediaURL(CutoutBake.fileName(previewID, frame: frame)))) != nil else { return }
        var s = settings
        if s.bakeOverrides == nil { s.bakeOverrides = [:] }
        s.bakeOverrides?[String(frame)] = previewID
        previewRevision += 1; s.bakeRevision = (s.bakeRevision ?? 0) + previewRevision
        state.cutoutPreview = (layer.id, s)
    }
    func endStroke(_ points: [CGPoint], radius: CGFloat) {
        addStroke(points, radius: radius); commit(keep: keepBrush)
        state.cutoutPreview = nil
    }

    func clearSelection() { selection = nil; selectionImage = nil }

    private func remember() {
        undo.append((frame, CutoutBake.load(path(frame))))
        if undo.count > 30 { undo.removeFirst() }
        hasUndo = true
    }

    private func store(_ m: MatteFrame, label: String = "Edit Cutout") {
        guard active else { return }
        let namespace = UUID().uuidString
        do { try CutoutBake.save(m, to: state.mediaURL(CutoutBake.fileName(namespace, frame: frame))) }
        catch { state.recoveryNotice = "Could not save cutout: " + error.localizedDescription; return }
        matte = m
        if settings.bakeOverrides == nil { settings.bakeOverrides = [:] }
        settings.bakeOverrides?[String(frame)] = namespace
        bakedFrames.insert(frame)
        if !settings.manualFrames.contains(frame) { settings.manualFrames.append(frame) }
        settings.bakeRevision = (settings.bakeRevision ?? 0) + 1
        refreshMatte(); publish(label)
    }

    /// Keep or Cut: only this frame changes.
    func commit(keep: Bool) {
        guard var m = matte, let sel = selection else { return }
        if keep, !bakedFrames.contains(frame), state.selectedLayer?.cutout == nil { m = .filled(m.width, m.height, 0) }
        m.apply(selection: sel, keep: keep)
        store(m, label: keep ? "Keep Brush" : "Cut Brush")
        clearSelection()
    }

    func undoLast() {
        guard active else { return }; state.undo(); sync(state.selectedLayer?.cutout)
    }

    /// Starts this frame from the previous one's matte.
    func copyPrevious() {
        guard frame > 0, let m = CutoutBake.load(path(frame - 1)) else { return }
        store(m, label: "Copy Previous Matte")
    }

    /// Back to automatic for this frame.
    func resetFrame() {
        guard active else { return }
        if settings.bakeOverrides == nil { settings.bakeOverrides = [:] }
        settings.bakeOverrides?[String(frame)] = ""
        settings.manualOnly = false
        bakedFrames.remove(frame); settings.manualFrames.removeAll { $0 == frame }
        settings.bakeRevision = (settings.bakeRevision ?? 0) + 1
        publish("Reset Cutout Frame"); load()
    }

    func runAuto(box: CGRect) {
        guard active, autoTask == nil else { return }
        let namespace = UUID().uuidString
        autoProgress = 0; tool = .brush
        if !isVideo {
            guard let cg = pictureCG else { autoProgress = nil; return }
            let mode = settings.mode
            autoTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let pb = CutoutEngine.mask(cg, mode: mode, pick: CGPoint(x: box.midX, y: box.midY)) ?? CutoutEngine.mask(cg, mode: mode) else {
                    await MainActor.run { self?.autoProgress = nil; self?.autoTask = nil }; return
                }
                let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
                var bytes = [UInt8](repeating: 0, count: w * h)
                CIContext().render(CIImage(cvPixelBuffer: pb), toBitmap: &bytes, rowBytes: w, bounds: CGRect(x: 0, y: 0, width: w, height: h), format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
                var matte = MatteFrame(width: w, height: h, bytes: bytes)
                CutoutBake.isolate(&matte, box: box.insetBy(dx: -box.width * 0.2, dy: -box.height * 0.2))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.active else { return }
                    self.autoProgress = nil; self.autoTask = nil; self.store(matte, label: "Auto Cutout")
                }
            }
            return
        }
        let mode: CutoutMode = settings.mode
        var job = CutoutBake.AutoJob(url: url, bakeID: namespace, folder: { [state] in state.mediaURL($0) }, box: box,
                                    startFrame: frame, lastFrame: lastFrame, rate: rate, mode: mode, locked: manualFrames)
        job.didWrite = { [weak self] f in
            Task { @MainActor in
                guard let self, self.active, self.autoProgress != nil else { return }
                if self.settings.bakeOverrides == nil { self.settings.bakeOverrides = [:] }
                self.settings.bakeOverrides?[String(f)] = namespace
                self.settings.bakeRevision = (self.settings.bakeRevision ?? 0) + 1
                self.bakedFrames.insert(f)
                if f == self.frame { self.state.cutoutPreview = (self.layer.id, self.settings) }
            }
        }
        autoTask = Task.detached(priority: .userInitiated) { [weak self] in
            let written = CutoutBake.runAuto(job) { p in Task { @MainActor in if self?.active == true { self?.autoProgress = p } } }
            await MainActor.run {
                guard let self, self.active else { return }
                if self.settings.bakeOverrides == nil { self.settings.bakeOverrides = [:] }
                for f in written { self.settings.bakeOverrides?[String(f)] = namespace }
                self.bakedFrames.formUnion(written)
                self.settings.bakeRevision = (self.settings.bakeRevision ?? 0) + 1
                self.autoProgress = nil; self.autoTask = nil
                if !written.isEmpty { self.publish("Auto Cutout Clip") }
                self.load()
            }
        }
    }

    func cancelAuto() { autoTask?.cancel() }

    /// Leaving the tool never applies draft settings, nor commits a late-running automatic operation.
    func finish() {
        closed = true; loadID += 1; autoTask?.cancel()
        if state.cutoutPreview?.layer == layer.id { state.cutoutPreview = nil }
        if state.cutoutPeekOriginal == layer.id { state.cutoutPeekOriginal = nil }
    }

}

/// Which frames are done: blue = automatic, green = fixed by hand.
struct FrameMarks: View {
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
