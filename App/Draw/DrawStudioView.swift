import SwiftUI
import MetalKit
import PhotosUI

enum DrawTool: String, CaseIterable, Identifiable {
    case brush, eraser, quickSelect, selectBrush, lasso, rectSelect, ellipseSelect, wand, fill, move, eyedropper
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .eraser: return "eraser.fill"
        case .selectBrush: return "sparkles"
        case .quickSelect: return "hand.draw"
        case .lasso: return "lasso"
        case .rectSelect: return "rectangle.dashed"
        case .ellipseSelect: return "circle.dashed"
        case .wand: return "wand.and.stars"
        case .fill: return "drop.fill"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .eyedropper: return "eyedropper"
        }
    }
    var title: String {
        switch self {
        case .selectBrush: return "AI Select"
        case .quickSelect: return "Quick Sel"
        case .rectSelect: return "Rect"
        case .ellipseSelect: return "Ellipse"
        case .eyedropper: return "Picker"
        default: return rawValue.capitalized
        }
    }
    var isSelection: Bool { [.quickSelect, .selectBrush, .lasso, .rectSelect, .ellipseSelect, .wand].contains(self) }
}

/// Shared tool state between the SwiftUI chrome and the UIKit canvas.
final class DrawSession: ObservableObject {
    let engine: DrawEngine
    @Published var tool: DrawTool = .brush
    @Published var brush = Brush() { didSet { if tool != .eraser { engine.brush = brush } } }
    /// The eraser keeps its own size / opacity / shape (like ibis Paint).
    @Published var eraser = Brush(kind: .pen, size: 30, opacity: 1, hardness: 0.8, stabilizer: 0.2) { didSet { if tool == .eraser { engine.brush = eraser } } }
    /// Size / opacity sliders edit whichever brush the current tool uses.
    var activeBrush: Brush {
        get { tool == .eraser ? eraser : brush }
        set { if tool == .eraser { eraser = newValue } else { brush = newValue } }
    }
    @Published var fillTolerance = 0.12
    @Published var gapClose = 2
    @Published var lassoPoints: [SIMD2<Double>] = []
    /// Select Brush: remove from the selection instead of adding; snap brushed areas to the AI-detected subject.
    @Published var selectSubtract = false
    @Published var selectSnap = false
    /// Lasso: freehand drag, or polygon (tap points, tap the first point to close).
    @Published var polygonLasso = false
    /// Fill tool: fill, or erase the tapped area (Eraser Bucket).
    @Published var fillErase = false
    /// Wand: only connected pixels, or every matching color.
    @Published var wandContiguous = true
    /// Canvas background while drawing (never saved): 0 transparent checker, 1 color.
    @Published var bgMode = 0
    @Published var bgColor: RGBA = .white
    /// Selection display: 0 dim outside, 1 red quick mask, 2 marching ants only.
    @Published var selectionView = 0
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
    private var shapeStart: SIMD2<Double>?
    private let outline = CAShapeLayer()
    private var outlineView: [CGPoint] = []

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
        // ibis Paint gestures: two-finger tap = undo, three-finger tap = redo.
        let undoTap = UITapGestureRecognizer(target: self, action: #selector(onUndoTap))
        undoTap.numberOfTouchesRequired = 2
        let redoTap = UITapGestureRecognizer(target: self, action: #selector(onRedoTap))
        redoTap.numberOfTouchesRequired = 3
        for g in [undoTap, redoTap] { g.delegate = self; addGestureRecognizer(g) }
        outline.fillColor = UIColor.clear.cgColor
        outline.strokeColor = UIColor.white.cgColor
        outline.lineWidth = 1.5
        outline.lineDashPattern = [6, 4]
        layer.addSublayer(outline)
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

    @objc private func onUndoTap() { session.engine.undo() }
    @objc private func onRedoTap() { session.engine.redo() }

    /// Live outline while making a lasso / rectangle / ellipse selection (view coordinates).
    private func showOutline(_ pts: [CGPoint], closed: Bool) {
        let path = UIBezierPath()
        guard let f = pts.first else { outline.path = nil; return }
        path.move(to: f)
        for p in pts.dropFirst() { path.addLine(to: p) }
        if closed { path.close() }
        outline.path = path.cgPath
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
            e.erasing = session.tool == .eraser
            e.brush = session.tool == .eraser ? session.eraser : session.brush
            e.beginStroke(at: p, pressure: pressure(t))
        case .rectSelect, .ellipseSelect:
            shapeStart = p
            outlineView = [t.location(in: self)]
        case .selectBrush: e.beginSelectStroke(at: p, radius: session.brush.size / 2, subtract: session.selectSubtract)
        case .quickSelect: e.beginQuickSelect(at: p, subtract: session.selectSubtract)
        case .lasso:
            if session.polygonLasso {
                // Polygon lasso: points are added on lift; nothing to start here.
                break
            }
            session.lassoPoints = [p]
            outlineView = [t.location(in: self)]
        case .wand: e.selectWand(at: p, tolerance: session.fillTolerance, contiguous: session.wandContiguous, gapClose: session.gapClose)
        case .fill:
            if session.fillErase { e.eraseFill(at: p, tolerance: session.fillTolerance, gapClose: session.gapClose) }
            else { e.fill(at: p, tolerance: session.fillTolerance, gapClose: session.gapClose) }
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
        case .lasso where !session.polygonLasso:
            session.lassoPoints.append(toCanvas(t.location(in: self)))
            outlineView.append(t.location(in: self))
            showOutline(outlineView, closed: false)
        case .quickSelect:
            for c in event?.coalescedTouches(for: t) ?? [t] { session.engine.continueQuickSelect(to: toCanvas(c.location(in: self))) }
        case .rectSelect, .ellipseSelect:
            guard let a = outlineView.first else { break }
            let b = t.location(in: self)
            let r = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
            outline.path = (session.tool == .ellipseSelect ? UIBezierPath(ovalIn: r) : UIBezierPath(rect: r)).cgPath
        case .selectBrush:
            for c in event?.coalescedTouches(for: t) ?? [t] { session.engine.continueSelectStroke(to: toCanvas(c.location(in: self))) }
        default: break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        switch session.tool {
        case .brush, .eraser: session.engine.endStroke()
        case .selectBrush: session.engine.endSelectStroke(snapToSubject: session.selectSnap && !session.selectSubtract)
        case .lasso where session.polygonLasso:
            let v = t.location(in: self)
            // Tap near the first point (or with 2+ points, a quick second tap there) closes the shape.
            if let first = outlineView.first, outlineView.count >= 3, hypot(v.x - first.x, v.y - first.y) < 24 {
                session.engine.selectLasso(session.lassoPoints)
                session.lassoPoints = []; outlineView = []; outline.path = nil
            } else {
                session.lassoPoints.append(toCanvas(v)); outlineView.append(v)
                showOutline(outlineView, closed: false)
            }
        case .lasso:
            session.engine.selectLasso(session.lassoPoints)
            session.lassoPoints = []
            outlineView = []
            outline.path = nil
        case .quickSelect: session.engine.endQuickSelect()
        case .rectSelect, .ellipseSelect:
            if let a = shapeStart { session.engine.selectShape(a, toCanvas(t.location(in: self)), ellipse: session.tool == .ellipseSelect) }
            shapeStart = nil
            outline.path = nil
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
        outline.path = nil
        shapeStart = nil
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
        var opts = SIMD4<Float>(e.hasSelection ? 1 : 0, Float(session.bgMode), Float(session.selectionView),
                                Float(CACurrentMediaTime().truncatingRemainder(dividingBy: 1000)))
        var bg = session.bgColor.simd
        enc.setRenderPipelineState(e.displayPSO)
        enc.setVertexBytes(&rect, length: 16, index: 0)
        enc.setFragmentTexture(e.canvas, index: 0)
        enc.setFragmentTexture(e.selection, index: 1)
        enc.setFragmentBytes(&opts, length: 16, index: 0)
        enc.setFragmentBytes(&bg, length: 16, index: 1)
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
    @State private var showAdjust = false
    @State private var showRefine = false
    @State private var playTimer: Timer?

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
            if engine.animating { animationBar }
            toolOptions
            if session.tool == .selectBrush { selectBrushBar }
            if engine.hasSelection || session.tool.isSelection { selectionBar }
            bottomBar
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showLayers)
        .awiSheet(isPresented: $showBrushes) { BrushPicker(session: session).presentationDetents([.medium, .large]) }
        .awiSheet(isPresented: $showAdjust) { DrawAdjustSheet(engine: engine).presentationDetents([.medium]) }
        .awiSheet(isPresented: $showRefine) { SelectionRefineSheet(session: session).presentationDetents([.medium, .large]) }
        .onDisappear { playTimer?.invalidate() }
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
        HStack(spacing: 2) {
            iconButton("xmark") { onCancel() }
            Spacer(minLength: 2)
            iconButton("arrow.uturn.backward", enabled: engine.canUndo) { engine.undo() }
            iconButton("arrow.uturn.forward", enabled: engine.canRedo) { engine.redo() }
            iconButton("photo.badge.plus") { showPhotos = true }
            iconButton("square.3.layers.3d", active: showLayers) { showLayers.toggle() }
            Menu {
                Picker("Symmetry", selection: Binding(get: { engine.symmetry }, set: { engine.symmetry = $0; engine.touch() })) {
                    ForEach(DrawSymmetry.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Straight Line Ruler", isOn: Binding(get: { engine.ruler == .line }, set: { engine.ruler = $0 ? .line : .none; engine.touch() }))
            } label: {
                Image(systemName: "ruler").font(.system(size: 16, weight: .semibold)).frame(width: 36, height: 36)
                    .foregroundStyle(engine.symmetry != .none || engine.ruler != .none ? Theme.accentGlow : Theme.text)
            }
            Menu {
                Button { showAdjust = true } label: { Label("Adjust Color / Blur", systemImage: "slider.horizontal.3") }
                Button { engine.extractLines() } label: { Label("Extract Line Art", systemImage: "scribble") }
                Button { engine.flipActive(horizontal: true) } label: { Label("Flip Horizontal", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
                Button { engine.flipActive(horizontal: false) } label: { Label("Flip Vertical", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down") }
                Button(role: .destructive) { engine.clearActiveLayer() } label: { Label("Clear Layer", systemImage: "trash") }
            } label: {
                Image(systemName: "wand.and.rays").font(.system(size: 16, weight: .semibold)).frame(width: 36, height: 36).foregroundStyle(Theme.text)
            }
            iconButton("film.stack", active: engine.animating) { engine.animating.toggle(); engine.touch() }
            Menu {
                Picker("Background", selection: $session.bgMode) {
                    Text("Transparent").tag(0)
                    Text("Color").tag(1)
                }
                Button("White") { session.bgMode = 1; session.bgColor = .white }
                Button("Black") { session.bgMode = 1; session.bgColor = .black }
                Button("Gray") { session.bgMode = 1; session.bgColor = RGBA(0.5, 0.5, 0.5) }
                Text("Only shown while drawing. Drawings stay transparent.")
            } label: {
                Image(systemName: "checkerboard.rectangle").font(.system(size: 15, weight: .semibold)).frame(width: 32, height: 36).foregroundStyle(Theme.text)
            }
            Spacer(minLength: 2)
            Menu {
                if engine.animating {
                    Button { engine.sendAsFrames = true; engine.sendAsParts = false; onDone(engine) } label: {
                        Label("Send Animation (\(engine.frameLayers.count) frames)", systemImage: "film")
                    }
                }
                Button { engine.sendAsFrames = false; engine.sendAsParts = false; onDone(engine) } label: { Label("Send as One Layer", systemImage: "square") }
                Button { engine.sendAsFrames = false; engine.sendAsParts = true; onDone(engine) } label: {
                    Label("Send Parts as Separate Layers (for animating)", systemImage: "square.3.layers.3d.down.right")
                }
            } label: {
                Label("Send", systemImage: "arrow.down.to.line")
                    .font(.system(size: 13, weight: .bold)).lineLimit(1).fixedSize()
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 6).frame(height: 50)
    }

    private var sideSliders: some View {
        VStack(spacing: 18) {
            VerticalSlider(value: Binding(get: { session.activeBrush.size }, set: { session.activeBrush.size = $0 }), range: 1...400, label: "\(Int(session.activeBrush.size))")
            VerticalSlider(value: Binding(get: { session.activeBrush.opacity * 100 }, set: { session.activeBrush.opacity = $0 / 100 }), range: 1...100, label: "\(Int(session.activeBrush.opacity * 100))%")
        }
        .padding(.vertical, 8).padding(.horizontal, 4).glass(radius: 14)
    }

    /// Per-tool options (ibis Paint style bar above the tools).
    @ViewBuilder private var toolOptions: some View {
        switch session.tool {
        case .eraser:
            HStack(spacing: 8) {
                Text("Eraser shape").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textDim)
                Menu {
                    ForEach(BrushKind.allCases.filter { $0 != .eraser }) { k in Button { session.eraser.kind = k } label: { Label(k.title, systemImage: k.symbol) } }
                } label: {
                    Label(session.eraser.kind.title, systemImage: session.eraser.kind.symbol).font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(Theme.raised)).foregroundStyle(Theme.text)
                }
                optionSlider("Soft", value: Binding(get: { 1 - session.eraser.hardness }, set: { session.eraser.hardness = 1 - $0 }), range: 0...1)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
        case .quickSelect:
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Picker("", selection: $session.selectSubtract) { Text("Add").tag(false); Text("Remove").tag(true) }
                        .pickerStyle(.segmented).frame(width: 150)
                    optionSlider("Edge", value: Binding(get: { engine.quickTolerance }, set: { engine.quickTolerance = $0 }), range: 0.02...0.5)
                }
                Picker("", selection: Binding(get: { engine.sampleSource }, set: { engine.sampleSource = $0 })) {
                    ForEach(SampleSource.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
        case .wand, .fill:
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    optionSlider("Tolerance", value: $session.fillTolerance, range: 0...0.6)
                    Picker("", selection: Binding(get: { engine.sampleSource }, set: { engine.sampleSource = $0 })) {
                        ForEach(SampleSource.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(width: 170)
                }
                if session.tool == .fill {
                    Picker("", selection: $session.fillErase) { Text("Fill").tag(false); Text("Erase Area").tag(true) }
                        .pickerStyle(.segmented)
                    HStack(spacing: 8) {
                        Stepper("Close gaps \(session.gapClose)px", value: $session.gapClose, in: 0...10).font(.system(size: 12))
                        Stepper("Expand \(engine.fillExpand)px", value: Binding(get: { engine.fillExpand }, set: { engine.fillExpand = $0; engine.touch() }), in: 0...6).font(.system(size: 12))
                    }
                } else {
                    HStack(spacing: 8) {
                        Toggle("Contiguous", isOn: $session.wandContiguous).toggleStyle(.button).tint(Theme.accent).font(.system(size: 12, weight: .semibold))
                        Stepper("Gap \(session.gapClose)px", value: $session.gapClose, in: 0...10).font(.system(size: 12))
                    }
                    selectionModePicker
                }
            }
            .foregroundStyle(Theme.text).padding(.horizontal, 10).padding(.vertical, 4)
        case .lasso:
            VStack(spacing: 4) {
                Picker("", selection: $session.polygonLasso) { Text("Freehand").tag(false); Text("Polygon (tap points)").tag(true) }
                    .pickerStyle(.segmented)
                selectionModePicker
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
        case .rectSelect, .ellipseSelect:
            selectionModePicker.padding(.horizontal, 10).padding(.vertical, 4)
        default:
            EmptyView()
        }
    }

    private var selectionModePicker: some View {
        Picker("", selection: Binding(get: { engine.selectionMode }, set: { engine.selectionMode = $0; engine.touch() })) {
            ForEach(SelectionMode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private func optionSlider(_ t: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 6) {
            Text(t).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textDim)
            Slider(value: value, in: range).tint(Theme.accent)
        }
    }

    /// Frame-by-frame animation controls (each layer is a frame).
    private var animationBar: some View {
        let frames = engine.frameLayers
        let cur = engine.activeLayer.flatMap { a in frames.firstIndex { $0.id == a.id } } ?? 0
        return HStack(spacing: 8) {
            iconButton("backward.frame.fill") { engine.stepFrame(-1) }
            Text("\(cur + 1) / \(max(1, frames.count))").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.text)
            iconButton("forward.frame.fill") { engine.stepFrame(1) }
            iconButton(playTimer == nil ? "play.fill" : "pause.fill") { togglePlay() }
            Menu {
                Button { engine.addFrame(copyCurrent: false) } label: { Label("New Empty Frame", systemImage: "plus.square") }
                Button { engine.addFrame(copyCurrent: true) } label: { Label("Duplicate Frame", systemImage: "plus.square.on.square") }
                Button(role: .destructive) { engine.deleteActiveLayer() } label: { Label("Delete Frame", systemImage: "trash") }
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle").font(.system(size: 16, weight: .semibold)).frame(width: 36, height: 36).foregroundStyle(Theme.text)
            }
            Toggle("Onion", isOn: Binding(get: { engine.onionSkin }, set: { engine.onionSkin = $0; engine.touch() })).toggleStyle(.button).tint(Theme.accent)
                .font(.system(size: 12, weight: .semibold))
            Stepper("\(Int(engine.fps)) fps", value: Binding(get: { engine.fps }, set: { engine.fps = $0; if playTimer != nil { togglePlay(); togglePlay() } }), in: 1...30)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 8).padding(.vertical, 2)
    }

    private func togglePlay() {
        if let t = playTimer { t.invalidate(); playTimer = nil; engine.playFrame = nil; engine.touch(); return }
        var k = 0
        engine.playFrame = 0
        playTimer = Timer.scheduledTimer(withTimeInterval: 1 / max(1, engine.fps), repeats: true) { _ in
            k += 1
            engine.playFrame = k
            engine.touch()
        }
    }

    /// Select Brush options, right above the selection actions.
    private var selectBrushBar: some View {
        HStack(spacing: 6) {
            Picker("", selection: $session.selectSubtract) {
                Text("Add").tag(false)
                Text("Remove").tag(true)
            }
            .pickerStyle(.segmented).frame(width: 150)
            Toggle("Snap to Subject (AI)", isOn: $session.selectSnap).toggleStyle(.button).tint(Theme.accent)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 10)
    }

    private var selectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
            chip("Refine Edge", "slider.horizontal.below.square.and.square.filled") { showRefine = true }
            chip("Remove Background", "person.crop.rectangle.badge.xmark") { engine.deleteOutsideSelection() }
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
            // Tools scroll sideways so every name stays readable; brushes + color stay pinned on the right.
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
            ForEach(DrawTool.allCases) { t in
                Button { session.tool = t } label: {
                    VStack(spacing: 2) {
                        Image(systemName: t.symbol).font(.system(size: 16, weight: .semibold))
                        Text(t.title).font(.system(size: 10, weight: .semibold)).lineLimit(1).fixedSize()
                    }
                        .frame(minWidth: 52, minHeight: 46).padding(.horizontal, 2)
                        .foregroundStyle(session.tool == t ? Theme.accentGlow : Theme.text)
                        .background(RoundedRectangle(cornerRadius: 10).fill(session.tool == t ? Theme.accent.opacity(0.22) : .clear))
                }
                .accessibilityLabel(t.title)
            }
            }
            }
            Button { showBrushes = true } label: {
                VStack(spacing: 2) {
                    Image(systemName: session.brush.kind.symbol).font(.system(size: 16))
                    Text("Brushes").font(.system(size: 9, weight: .semibold))
                }
                .frame(width: 46, height: 46).foregroundStyle(Theme.text)
            }
            AWIColorWell("", selection: Binding(get: { Color(session.brush.color) }, set: { session.brush.color = $0.rgba }), supportsOpacity: false)
                .labelsHidden().frame(width: 40)
        }
        .padding(.horizontal, 8).padding(.bottom, 4).frame(height: 56)
        .background(Theme.surface)
    }

    private func iconButton(_ s: String, enabled: Bool = true, active: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: s).font(.system(size: 15, weight: .semibold)).frame(width: 32, height: 36)
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
    @State private var showRename = false
    @State private var renaming = ""
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
                            LayerThumb(engine: engine, layer: l)
                            Text(l.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                            Spacer()
                            if l.clipping { Image(systemName: "arrow.turn.left.down").font(.system(size: 10)) }
                            if l.alphaLock { Image(systemName: "lock.fill").font(.system(size: 10)) }
                        }
                        .foregroundStyle(Theme.text)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(i == engine.activeIndex ? Theme.accent.opacity(0.3) : Theme.surface))
                        .onTapGesture { engine.activeIndex = i; engine.touch() }
                        .contextMenu {
                            Button("Rename") { renaming = l.name; engine.activeIndex = i; showRename = true }
                            Button("Duplicate") { engine.activeIndex = i; engine.duplicateActiveLayer() }
                            Button("Clear") { engine.activeIndex = i; engine.clearActiveLayer() }
                            Button("Delete", role: .destructive) { engine.activeIndex = i; engine.deleteActiveLayer() }
                        }
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
        .alert("Rename Layer", isPresented: $showRename) {
            TextField("Name", text: $renaming)
            Button("OK") { engine.renameActive(renaming) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// Tiny live preview of a layer (refreshes with the engine revision).
struct LayerThumb: View {
    @ObservedObject var engine: DrawEngine
    let layer: DrawLayer
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.9))
            if let image { Image(uiImage: image).resizable().scaledToFit() }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task(id: engine.revision) { image = engine.thumbnail(of: layer) }
    }
}

/// Color adjustments for the active layer.
struct DrawAdjustSheet: View {
    @ObservedObject var engine: DrawEngine
    @Environment(\.dismiss) private var dismiss
    @State private var brightness = 0.0
    @State private var contrast = 1.0
    @State private var saturation = 1.0
    @State private var hue = 0.0
    @State private var blur = 0.0
    var body: some View {
        NavigationStack {
            Form {
                HStack { Text("Brightness"); Slider(value: $brightness, in: -0.5...0.5) }
                HStack { Text("Contrast"); Slider(value: $contrast, in: 0.5...1.8) }
                HStack { Text("Saturation"); Slider(value: $saturation, in: 0...2) }
                HStack { Text("Hue"); Slider(value: $hue, in: -3.14...3.14) }
                HStack { Text("Blur"); Slider(value: $blur, in: 0...40) }
            }
            .navigationTitle("Adjust Layer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        engine.adjustActive(brightness: brightness, contrast: contrast, saturation: saturation, hue: hue, blur: blur)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Select and Mask: shape the selection edge, pick how it's shown, send it somewhere.
struct SelectionRefineSheet: View {
    @ObservedObject var session: DrawSession
    @Environment(\.dismiss) private var dismiss
    @State private var feather = 0.0
    @State private var shift = 0.0
    @State private var smooth = 0.0
    var body: some View {
        NavigationStack {
            Form {
                Section("View") {
                    Picker("Show selection as", selection: $session.selectionView) {
                        Text("Dim outside").tag(0)
                        Text("Red overlay").tag(1)
                        Text("Outline only").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Edge") {
                    HStack { Text("Smooth"); Slider(value: $smooth, in: 0...6, step: 1); Text("\(Int(smooth))").monospacedDigit() }
                    HStack { Text("Feather"); Slider(value: $feather, in: 0...12, step: 1); Text("\(Int(feather))").monospacedDigit() }
                    HStack { Text("Shift Edge"); Slider(value: $shift, in: -12...12, step: 1); Text("\(Int(shift))").monospacedDigit() }
                    Button("Apply to Selection") {
                        session.engine.refineSelection(feather: Int(feather), shift: Int(shift), smooth: Int(smooth))
                        feather = 0; shift = 0; smooth = 0
                    }
                }
                Section("Output") {
                    Button("To New Layer (cutout)") { session.engine.liftSelectionToLayer(); dismiss() }
                    Button("Remove Background on This Layer") { session.engine.deleteOutsideSelection(); dismiss() }
                    Button("Delete Selected") { session.engine.deleteSelection(); dismiss() }
                    Button("Invert Selection") { session.engine.invertSelection() }
                }
            }
            .navigationTitle("Refine Edge")
            .navigationBarTitleDisplayMode(.inline)
        }
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
                    HStack { Text("Spacing"); Slider(value: $session.brush.spacing, in: 0...1.5) }
                    HStack { Text("Start Taper"); Slider(value: $session.brush.taperStart, in: 0...300) }
                    HStack { Text("Size Jitter"); Slider(value: $session.brush.sizeJitter, in: 0...1) }
                    Toggle("Pressure controls size", isOn: $session.brush.pressureSize)
                    Toggle("Pressure controls opacity", isOn: $session.brush.pressureOpacity)
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
