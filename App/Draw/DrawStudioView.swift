import SwiftUI
import MetalKit
import PhotosUI

enum DrawTool: String, CaseIterable, Identifiable {
    case brush, eraser, lasso, wand, fill, move, eyedropper
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .eraser: return "eraser.fill"
        case .lasso: return "lasso"
        case .wand: return "wand.and.stars"
        case .fill: return "drop.fill"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .eyedropper: return "eyedropper"
        }
    }
    var title: String { rawValue.capitalized }
}

/// Shared tool state between the SwiftUI chrome and the UIKit canvas.
final class DrawSession: ObservableObject {
    let engine: DrawEngine
    @Published var tool: DrawTool = .brush
    @Published var brush = Brush() { didSet { engine.brush = brush } }
    @Published var fillTolerance = 0.12
    @Published var gapClose = 2
    @Published var lassoPoints: [SIMD2<Double>] = []
    var lastBrushKind: BrushKind = .pen

    init(engine: DrawEngine) {
        self.engine = engine
        engine.brush = brush
    }
}

// MARK: - Canvas (UIKit for pressure + multi-touch)

final class DrawCanvasView: MTKView, MTKViewDelegate {
    var session: DrawSession!
    /// Canvas -> view transform.
    private var zoom: CGFloat = 1
    private var offset: CGPoint = .zero
    private var rotation: CGFloat = 0
    private var fitted = false
    private var movingStart: CGPoint?

    init(session: DrawSession) {
        self.session = session
        super.init(frame: .zero, device: session.engine.device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        clearColor = MTLClearColor(red: 0.13, green: 0.12, blue: 0.15, alpha: 1)
        delegate = self
        isMultipleTouchEnabled = true
        preferredFramesPerSecond = 120
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.minimumNumberOfTouches = 2
        let rot = UIRotationGestureRecognizer(target: self, action: #selector(onRotate(_:)))
        for g in [pinch, pan, rot] as [UIGestureRecognizer] {
            g.delegate = self
            g.cancelsTouchesInView = true
            addGestureRecognizer(g)
        }
    }
    required init(coder: NSCoder) { fatalError() }

    private var canvasSize: CGSize { CGSize(width: session.engine.width, height: session.engine.height) }

    private func fitIfNeeded() {
        guard !fitted, bounds.width > 0 else { return }
        let s = min(bounds.width / canvasSize.width, bounds.height / canvasSize.height) * 0.94
        zoom = s
        offset = CGPoint(x: (bounds.width - canvasSize.width * s) / 2, y: (bounds.height - canvasSize.height * s) / 2)
        fitted = true
    }

    private func toCanvas(_ p: CGPoint) -> SIMD2<Double> {
        // Inverse of: translate(offset) * rotate(about center) * scale(zoom)
        let c = CGPoint(x: offset.x + canvasSize.width * zoom / 2, y: offset.y + canvasSize.height * zoom / 2)
        let dx = p.x - c.x, dy = p.y - c.y
        let rx = dx * cos(-rotation) - dy * sin(-rotation), ry = dx * sin(-rotation) + dy * cos(-rotation)
        return SIMD2(Double((rx + canvasSize.width * zoom / 2) / zoom), Double((ry + canvasSize.height * zoom / 2) / zoom))
    }

    // MARK: Touches (single finger / Pencil = draw)

    private func pressure(_ t: UITouch) -> Double {
        t.maximumPossibleForce > 0 ? Double(t.force / t.maximumPossibleForce) : 0.6
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1, (event?.allTouches?.count ?? 1) == 1, let t = touches.first else { return }
        let p = toCanvas(t.location(in: self))
        let e = session.engine
        switch session.tool {
        case .brush, .eraser:
            e.brush.kind = session.tool == .eraser ? .eraser : session.brush.kind
            e.beginStroke(at: p, pressure: pressure(t))
        case .lasso: session.lassoPoints = [p]
        case .wand: e.selectWand(at: p, tolerance: session.fillTolerance)
        case .fill: e.fill(at: p, tolerance: session.fillTolerance, gapClose: session.gapClose)
        case .eyedropper: pickColor(at: p)
        case .move: movingStart = t.location(in: self)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, (event?.allTouches?.count ?? 1) == 1 else { return }
        switch session.tool {
        case .brush, .eraser:
            for c in event?.coalescedTouches(for: t) ?? [t] {
                session.engine.continueStroke(to: toCanvas(c.location(in: self)), pressure: pressure(c))
            }
        case .lasso: session.lassoPoints.append(toCanvas(t.location(in: self)))
        default: break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        switch session.tool {
        case .brush, .eraser: session.engine.endStroke()
        case .lasso:
            session.engine.selectLasso(session.lassoPoints)
            session.lassoPoints = []
        case .move:
            if let s = movingStart {
                let e = t.location(in: self)
                let d = SIMD2(Double(e.x - s.x) / Double(zoom), Double(e.y - s.y) / Double(zoom))
                session.engine.transformActive(translate: d, scale: 1, rotation: 0,
                                               pivot: SIMD2(Double(canvasSize.width) / 2, Double(canvasSize.height) / 2))
            }
            movingStart = nil
        default: break
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        session.engine.endStroke()
        session.lassoPoints = []
    }

    private func pickColor(at p: SIMD2<Double>) {
        let e = session.engine
        guard let cb = e.queue.makeCommandBuffer() else { return }
        e.encodeComposite(cb)
        cb.commit(); cb.waitUntilCompleted()
        let x = min(max(Int(p.x), 0), e.width - 1), y = min(max(Int(p.y), 0), e.height - 1)
        var px = [UInt8](repeating: 0, count: 4)
        e.canvas.getBytes(&px, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
        let a = Double(px[3]) / 255
        guard a > 0 else { return }
        DispatchQueue.main.async {
            self.session.brush.color = RGBA(Double(px[0]) / 255 / a, Double(px[1]) / 255 / a, Double(px[2]) / 255 / a)
            self.session.tool = .brush
        }
    }

    // MARK: Navigation gestures

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        let loc = g.location(in: self)
        let before = toCanvas(loc)
        zoom = min(max(zoom * g.scale, 0.05), 40)
        g.scale = 1
        // Keep the pinch point fixed.
        let after = toCanvas(loc)
        offset.x += CGFloat(after.x - before.x) * zoom
        offset.y += CGFloat(after.y - before.y) * zoom
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: self)
        offset.x += t.x; offset.y += t.y
        g.setTranslation(.zero, in: self)
    }

    @objc private func onRotate(_ g: UIRotationGestureRecognizer) {
        rotation += g.rotation
        g.rotation = 0
    }

    // MARK: Rendering

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        fitIfNeeded()
        let e = session.engine
        guard let cb = e.queue.makeCommandBuffer(), let rpd = currentRenderPassDescriptor, let drawable = currentDrawable else { return }
        e.encodeComposite(cb)
        guard let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }
        // Canvas quad in NDC (rotation applied by rotating the viewport-sized quad corners on the CPU).
        let w = bounds.width, h = bounds.height
        func ndc(_ p: CGPoint) -> SIMD2<Float> { SIMD2(Float(p.x / w * 2 - 1), Float(1 - p.y / h * 2)) }
        let x0 = offset.x, y0 = offset.y, x1 = offset.x + canvasSize.width * zoom, y1 = offset.y + canvasSize.height * zoom
        var rect = SIMD4<Float>(ndc(CGPoint(x: x0, y: y1)).x, ndc(CGPoint(x: x0, y: y1)).y, ndc(CGPoint(x: x1, y: y0)).x, ndc(CGPoint(x: x1, y: y0)).y)
        var opts = SIMD4<Float>(e.hasSelection ? 1 : 0, 0, 0, 0)
        enc.setRenderPipelineState(e.displayPSO)
        enc.setVertexBytes(&rect, length: 16, index: 0)
        enc.setFragmentTexture(e.canvas, index: 0)
        enc.setFragmentTexture(e.selection, index: 1)
        enc.setFragmentBytes(&opts, length: 16, index: 0)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        enc.endEncoding()
        cb.present(drawable)
        cb.commit()
    }
}

extension DrawCanvasView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

struct DrawCanvas: UIViewRepresentable {
    let session: DrawSession
    func makeUIView(context: Context) -> DrawCanvasView { DrawCanvasView(session: session) }
    func updateUIView(_ v: DrawCanvasView, context: Context) {}
}

// MARK: - Studio chrome

struct DrawStudioView: View {
    @StateObject var session: DrawSession
    @ObservedObject var engine: DrawEngine
    let onDone: (DrawEngine) -> Void
    let onCancel: () -> Void
    @State private var showLayers = false
    @State private var showBrushes = false
    @State private var photo: PhotosPickerItem?
    @State private var showPhotos = false

    init(engine: DrawEngine, onDone: @escaping (DrawEngine) -> Void, onCancel: @escaping () -> Void) {
        _session = StateObject(wrappedValue: DrawSession(engine: engine))
        self.engine = engine
        self.onDone = onDone
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack(alignment: .leading) {
                DrawCanvas(session: session)
                sideSliders.padding(.leading, 8)
                if showLayers { HStack { Spacer(); LayersPanel(engine: engine).frame(width: 250).padding(8) }.transition(.move(edge: .trailing)) }
            }
            if engine.hasSelection || session.tool == .lasso || session.tool == .wand { selectionBar }
            bottomBar
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showLayers)
        .sheet(isPresented: $showBrushes) { BrushPicker(session: session).presentationDetents([.medium]) }
        .photosPicker(isPresented: $showPhotos, selection: $photo, matching: .images)
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    await MainActor.run { engine.importImage(img) }
                }
                photo = nil
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            Button("Cancel", role: .cancel, action: onCancel).foregroundStyle(Theme.textDim)
            Spacer()
            iconButton("arrow.uturn.backward", enabled: engine.canUndo) { engine.undo() }
            iconButton("arrow.uturn.forward", enabled: engine.canRedo) { engine.redo() }
            iconButton("photo.badge.plus") { showPhotos = true }
            iconButton("square.3.layers.3d", active: showLayers) { showLayers.toggle() }
            Spacer()
            Button { onDone(engine) } label: {
                Label("Send to Timeline", systemImage: "arrow.down.to.line")
                    .font(.system(size: 13, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 12).frame(height: 50)
    }

    private var sideSliders: some View {
        VStack(spacing: 18) {
            VerticalSlider(value: Binding(get: { session.brush.size }, set: { session.brush.size = $0 }), range: 1...300, label: "\(Int(session.brush.size))")
            VerticalSlider(value: Binding(get: { session.brush.opacity * 100 }, set: { session.brush.opacity = $0 / 100 }), range: 1...100, label: "\(Int(session.brush.opacity * 100))%")
        }
        .padding(.vertical, 8).padding(.horizontal, 4).glass(radius: 14)
    }

    private var selectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
            chip("AI Subject", "person.crop.rectangle") {
                if !engine.selectSubject() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
            }
            chip("Select Layer", "square.dashed") { engine.selectOpaque() }
            chip("To New Layer", "square.on.square") { engine.liftSelectionToLayer() }
            chip("Cut", "scissors") { engine.cutSelection() }
            chip("Copy", "doc.on.doc") { engine.copySelection() }
            chip("Paste", "doc.on.clipboard") { engine.paste() }
            chip("Delete", "trash") { engine.deleteSelection() }
            chip("Invert", "circle.lefthalf.filled") { engine.invertSelection() }
            chip("Clear", "xmark") { engine.clearSelection() }
        }
        .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
    }

    private var bottomBar: some View {
        HStack(spacing: 4) {
            ForEach(DrawTool.allCases) { t in
                Button { session.tool = t } label: {
                    VStack(spacing: 2) {
                        Image(systemName: t.symbol).font(.system(size: 16, weight: .semibold))
                        Text(t.title).font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(session.tool == t ? Theme.accentGlow : Theme.text)
                        .background(RoundedRectangle(cornerRadius: 10).fill(session.tool == t ? Theme.accent.opacity(0.22) : .clear))
                }
                .accessibilityLabel(t.title)
            }
            Button { showBrushes = true } label: {
                VStack(spacing: 2) {
                    Image(systemName: session.brush.kind.symbol).font(.system(size: 16))
                    Text("Brushes").font(.system(size: 9, weight: .semibold))
                }
                .frame(width: 46, height: 46).foregroundStyle(Theme.text)
            }
            ColorPicker("", selection: Binding(get: { Color(session.brush.color) }, set: { session.brush.color = $0.rgba }), supportsOpacity: false)
                .labelsHidden().frame(width: 40)
        }
        .padding(.horizontal, 8).padding(.bottom, 4).frame(height: 56)
        .background(Theme.surface)
    }

    private func iconButton(_ s: String, enabled: Bool = true, active: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: s).font(.system(size: 16, weight: .semibold)).frame(width: 36, height: 36)
                .foregroundStyle(active ? Theme.accentGlow : (enabled ? Theme.text : Theme.textDim.opacity(0.4)))
        }
        .disabled(!enabled)
    }

    private func chip(_ t: String, _ s: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Label(t, systemImage: s).font(.system(size: 11, weight: .semibold)).labelStyle(.titleAndIcon)
                .padding(.horizontal, 8).padding(.vertical, 6).background(Capsule().fill(Theme.raised)).foregroundStyle(Theme.text)
        }
    }
}

struct VerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { g in
                let f = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                ZStack(alignment: .bottom) {
                    Capsule().fill(Theme.surface)
                    Capsule().fill(Theme.accent).frame(height: g.size.height * CGFloat(f))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let t = 1 - min(max(v.location.y / g.size.height, 0), 1)
                    value = range.lowerBound + Double(t) * (range.upperBound - range.lowerBound)
                })
            }
            .frame(width: 22, height: 130)
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Theme.textDim)
        }
    }
}

struct LayersPanel: View {
    @ObservedObject var engine: DrawEngine
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Layers").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                Button { engine.addLayer() } label: { Label("Add", systemImage: "plus") }
                Button { engine.duplicateActiveLayer() } label: { Label("Copy", systemImage: "plus.square.on.square") }
                Button { engine.mergeDown() } label: { Label("Merge", systemImage: "arrow.down.to.line.compact") }
                Button(role: .destructive) { engine.deleteActiveLayer() } label: { Label("Delete", systemImage: "trash") }
            }
            .font(.system(size: 11, weight: .semibold)).labelStyle(.titleAndIcon)
            .foregroundStyle(Theme.text)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(engine.layers.enumerated().reversed()), id: \.element.id) { i, l in
                        HStack(spacing: 6) {
                            Button { l.visible.toggle(); engine.touch() } label: { Image(systemName: l.visible ? "eye" : "eye.slash") }
                            Text(l.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                            Spacer()
                            if l.clipping { Image(systemName: "arrow.turn.left.down").font(.system(size: 10)) }
                            if l.alphaLock { Image(systemName: "lock.fill").font(.system(size: 10)) }
                        }
                        .foregroundStyle(Theme.text)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(i == engine.activeIndex ? Theme.accent.opacity(0.3) : Theme.surface))
                        .onTapGesture { engine.activeIndex = i }
                    }
                }
            }
            if let l = engine.activeLayer {
                VStack(spacing: 4) {
                    HStack {
                        Text("Opacity").font(.caption)
                        Slider(value: Binding(get: { l.opacity }, set: { l.opacity = $0; engine.touch() }), in: 0...1)
                    }
                    Picker("Blend", selection: Binding(get: { l.blend }, set: { l.blend = $0; engine.touch() })) {
                        ForEach(BlendMode.allCases) { Text($0.title).tag($0) }
                    }
                    HStack {
                        Toggle("Clip", isOn: Binding(get: { l.clipping }, set: { l.clipping = $0; engine.touch() })).toggleStyle(.button)
                        Toggle("α Lock", isOn: Binding(get: { l.alphaLock }, set: { l.alphaLock = $0; engine.touch() })).toggleStyle(.button)
                        Button { engine.moveActiveLayer(up: true) } label: { Image(systemName: "arrow.up") }
                        Button { engine.moveActiveLayer(up: false) } label: { Image(systemName: "arrow.down") }
                    }
                    .font(.caption)
                }
                .foregroundStyle(Theme.text)
                .tint(Theme.accent)
            }
        }
        .padding(10).glass(radius: 14)
    }
}

struct BrushPicker: View {
    @ObservedObject var session: DrawSession
    var body: some View {
        NavigationStack {
            Form {
                Picker("Brush", selection: $session.brush.kind) {
                    ForEach(BrushKind.allCases.filter { $0 != .eraser }) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                .pickerStyle(.inline)
                Section("Feel") {
                    HStack { Text("Hardness"); Slider(value: $session.brush.hardness, in: 0...0.99) }
                    HStack { Text("Stabilizer"); Slider(value: $session.brush.stabilizer, in: 0...1) }
                    Toggle("Pressure controls size", isOn: $session.brush.pressureSize)
                }
                Section("Fill & Wand") {
                    HStack { Text("Tolerance"); Slider(value: $session.fillTolerance, in: 0...0.6) }
                    Stepper("Close gaps: \(session.gapClose) px", value: $session.gapClose, in: 0...8)
                }
            }
            .navigationTitle("Brush")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
