import SwiftUI
import MetalKit
import PhotosUI

enum DrawTool: String, CaseIterable, Identifiable {
    case brush, eraser, smudge, blur, quickSelect, selectBrush, lasso, rectSelect, ellipseSelect, wand, fill, shape, pen, move, eyedropper
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .eraser: return "eraser.fill"
        case .smudge: return "hand.point.up.left.fill"
        case .blur: return "drop.circle"
        case .shape: return "square.on.circle"
        case .pen: return "point.topleft.down.to.point.bottomright.curvepath"
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
        case .selectBrush: return "AI Brush"
        case .quickSelect: return "Quick"
        case .move: return "Transform"
        case .pen: return "Vector"
        case .rectSelect: return "Rect"
        case .ellipseSelect: return "Ellipse"
        case .eyedropper: return "Picker"
        default: return rawValue.capitalized
        }
    }
    /// Strokes that use the size and opacity sliders.
    var usesBrush: Bool { [.brush, .eraser, .smudge, .blur, .selectBrush, .shape, .pen].contains(self) }
    static let selectionTools: [DrawTool] = [.wand, .lasso, .quickSelect, .selectBrush, .rectSelect, .ellipseSelect]
    var isSelection: Bool { [.quickSelect, .selectBrush, .lasso, .rectSelect, .ellipseSelect, .wand].contains(self) }
}

/// What the AI Brush does when the stroke ends.
enum SelectBrushSnap: String, CaseIterable, Identifiable {
    case edges, subject, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .edges: return "Snap to Edges"
        case .subject: return "Whole Subject"
        case .none: return "Exact Stroke"
        }
    }
}

enum DrawShapeKind: String, CaseIterable, Identifiable {
    case line, rectangle, ellipse
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        }
    }
}

/// Shared tool state between the SwiftUI chrome and the UIKit canvas.
final class DrawSession: ObservableObject {
    let engine: DrawEngine
    @Published var selectionLayer = false
    @Published var tool: DrawTool = .brush {
        didSet {
            if oldValue == .move, tool != .move { engine.commitFloating() }
            if tool.isSelection { lastSelectionTool = tool }
            engine.strokeMode = tool == .smudge ? .smudge : (tool == .blur ? .blur : .paint)
            if tool == .smudge || tool == .blur { engine.brush = smudger }
            else if tool == .eraser { engine.brush = eraser }
            else { engine.brush = brush }
        }
    }
    var lastSelectionTool: DrawTool = .wand
    @Published var brushName = "Round"
    /// Smudge and blur share their own soft tip; opacity is their strength.
    @Published var smudger = Brush(kind: .pen, size: 40, opacity: 0.7, hardness: 0.3, stabilizer: 0.2) { didSet { if tool == .smudge || tool == .blur { engine.brush = smudger } } }
    @Published var shapeKind = DrawShapeKind.line
    @Published var shapeFilled = false
    /// Fit the canvas to the screen on the next frame.
    var fitRequested = false
    @Published var brush = Brush() { didSet { if tool == .eraser || tool == .smudge || tool == .blur { return }; engine.brush = brush } }
    /// The eraser keeps its own size / opacity / shape (like ibis Paint).
    @Published var eraser = Brush(kind: .pen, size: 30, opacity: 1, hardness: 0.8, stabilizer: 0.2) { didSet { if tool == .eraser { engine.brush = eraser } } }
    /// Size / opacity sliders edit whichever brush the current tool uses.
    var activeBrush: Brush {
        get { tool == .eraser ? eraser : (tool == .smudge || tool == .blur ? smudger : brush) }
        set {
            if newValue.size != activeBrush.size { sizeChangedAt = CACurrentMediaTime() }
            if tool == .eraser { eraser = newValue } else if tool == .smudge || tool == .blur { smudger = newValue } else { brush = newValue }
        }
    }
    /// When the size slider last moved (the size circle shows in the middle for a moment).
    var sizeChangedAt: CFTimeInterval = 0
    @Published var fillTolerance = 0.12
    @Published var gapClose = 2
    @Published var lassoPoints: [SIMD2<Double>] = []
    /// Select Brush: remove from the selection instead of adding; snap brushed areas to the AI-detected subject.
    @Published var selectSubtract = false
    @Published var selectSnap = SelectBrushSnap.edges
    @Published var penPath = PenPath()
    /// Lasso: freehand drag, or polygon (tap points, tap the first point to close).
    @Published var polygonLasso = false
    @Published var lassoFills = false
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
    private let handles = CAShapeLayer()
    private let penLine = CAShapeLayer()
    private let penOverlay = CAShapeLayer()
    private var shapeStart: SIMD2<Double>?
    private var shapeEnd: SIMD2<Double>?
    private let outline = CAShapeLayer()
    /// Brush / eraser size ring that follows the finger or Pencil.
    private let cursor = CAShapeLayer()
    private var cursorPoint: CGPoint?
    private var outlineView: [CGPoint] = []
    /// Transform handles.
    private enum TransformDrag { case move, scale, rotate }
    private var transformDrag: TransformDrag?
    private var transformStart: (translate: SIMD2<Double>, scale: SIMD2<Double>, rotation: Double, canvas: SIMD2<Double>)?
    /// Hold still on the canvas to pick a color (ibis Paint).
    private var holdPick: DispatchWorkItem?
    private var holdOrigin: CGPoint = .zero
    private func cancelHoldPick() { holdPick?.cancel(); holdPick = nil }

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
        handles.fillColor = UIColor.white.withAlphaComponent(0.9).cgColor
        handles.strokeColor = UIColor(Theme.accentGlow).cgColor
        handles.fillRule = .nonZero
        handles.lineWidth = 1.5
        layer.addSublayer(handles)
        penLine.fillColor = UIColor.clear.cgColor
        penLine.strokeColor = UIColor(Theme.accentGlow).cgColor
        penLine.lineWidth = 1.5
        penOverlay.fillColor = UIColor.white.cgColor
        penOverlay.strokeColor = UIColor(Theme.accent).cgColor
        penOverlay.lineWidth = 1.5
        layer.addSublayer(penLine); layer.addSublayer(penOverlay)
        cursor.fillColor = UIColor.clear.cgColor
        cursor.strokeColor = UIColor.white.cgColor
        cursor.lineWidth = 1.2
        cursor.shadowColor = UIColor.black.cgColor
        cursor.shadowOpacity = 0.8
        cursor.shadowRadius = 1
        cursor.shadowOffset = .zero
        layer.addSublayer(cursor)
        // Apple Pencil hover (iPad): show the ring before touching down.
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(onHover(_:)))
        addGestureRecognizer(hover)
    }
    required init(coder: NSCoder) { fatalError() }

    private var canvasSize: CGSize { CGSize(width: session.engine.width, height: session.engine.height) }

    private var userNavigated = false
    private var fittedBounds: CGSize = .zero

    private func fitIfNeeded() {
        if !userNavigated, fittedBounds != bounds.size { fitted = false }
        guard !fitted, bounds.width > 0 else { return }
        fittedBounds = bounds.size
        let s = min(bounds.width / canvasSize.width, bounds.height / canvasSize.height) * 0.94
        zoom = s
        offset = CGPoint(x: (bounds.width - canvasSize.width * s) / 2, y: (bounds.height - canvasSize.height * s) / 2)
        fitted = true
    }

    @objc private func onHover(_ g: UIHoverGestureRecognizer) {
        cursorPoint = (g.state == .began || g.state == .changed) ? g.location(in: self) : nil
    }

    /// The ring: brush size on screen, at the touch (or in the middle while the size slider moves).
    private func updateCursor() {
        let usesSize = session.tool.usesBrush && session.tool != .shape && session.tool != .pen
        let recent = CACurrentMediaTime() - session.sizeChangedAt < 0.9
        guard usesSize, let p = cursorPoint ?? (recent ? CGPoint(x: bounds.midX, y: bounds.midY) : nil) else { cursor.path = nil; return }
        let r = max(2, CGFloat(session.activeBrush.size / 2) * zoom)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        cursor.path = UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).cgPath
        cursor.strokeColor = (session.tool == .eraser ? UIColor.systemPink : UIColor.white).cgColor
        CATransaction.commit()
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

    private var viewport: DrawViewport { DrawViewport(size: canvasSize, zoom: zoom, rotation: rotation, offset: offset) }

    private func toCanvas(_ p: CGPoint) -> SIMD2<Double> { viewport.canvas(p) }

    private func updateShapeOutline() {
        guard let a = shapeStart, let b = shapeEnd else { return }
        let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
        let path = session.tool == .ellipseSelect ? UIBezierPath(ovalIn: rect) : UIBezierPath(rect: rect)
        path.apply(viewport.transform)
        outline.path = path.cgPath
    }

    private func finishLasso() {
        if session.lassoFills { session.engine.fillLasso(session.lassoPoints, color: session.brush.color, opacity: session.brush.opacity) }
        else { session.engine.selectLasso(session.lassoPoints) }
        session.lassoPoints = []; outlineView = []; outline.path = nil
    }

    // MARK: Touches (single finger / Pencil = draw)

    private weak var drawingTouch: UITouch?

    private func pressure(_ t: UITouch) -> Double {
        t.type == .pencil && t.maximumPossibleForce > 0 ? Double(t.force / t.maximumPossibleForce) : 1
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1, (event?.allTouches?.count ?? 1) == 1, let t = touches.first else { return }
        drawingTouch = t
        cursorPoint = t.location(in: self)
        let p = toCanvas(t.location(in: self))
        let e = session.engine
        if (session.tool == .brush || session.tool == .eraser), !session.selectionLayer {
            holdOrigin = t.location(in: self)
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.drawingTouch != nil else { return }
                self.session.engine.cancelStroke()
                self.drawingTouch = nil; self.cursorPoint = nil
                self.pickColor(at: p, returnTool: self.session.tool)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            holdPick = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        }
        switch session.tool {
        case .smudge, .blur:
            e.erasing = false
            e.beginStroke(at: p, pressure: 1)
        case .shape:
            shapeStart = p; shapeEnd = p
        case .brush, .eraser:
            if session.selectionLayer {
                e.beginSelectStroke(at: p, radius: session.activeBrush.size / 2, subtract: session.tool == .eraser)
                return
            }
            e.erasing = session.tool == .eraser
            e.brush = session.tool == .eraser ? session.eraser : session.brush
            e.beginStroke(at: p, pressure: pressure(t))
        case .rectSelect, .ellipseSelect:
            shapeStart = p; shapeEnd = p
        case .selectBrush: e.beginSelectStroke(at: p, radius: session.brush.size / 2, subtract: session.selectSubtract)
        case .quickSelect: e.beginQuickSelect(at: p, subtract: session.selectSubtract, reach: 60 / Double(zoom) + 40)
        case .pen: penBegan(at: t.location(in: self))
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
        case .move:
            guard e.beginFloating(), let f = e.floating else { return }
            let v = t.location(in: self)
            let corners = f.corners.map(viewport.view)
            let top = CGPoint(x: (corners[0].x + corners[1].x) / 2, y: (corners[0].y + corners[1].y) / 2)
            let center = viewport.view(f.pivot + f.translate)
            let away = hypot(top.x - center.x, top.y - center.y)
            let knob = away > 0 ? CGPoint(x: top.x + (top.x - center.x) / away * 34, y: top.y + (top.y - center.y) / away * 34) : top
            if hypot(v.x - knob.x, v.y - knob.y) < 30 { transformDrag = .rotate }
            else if corners.contains(where: { hypot(v.x - $0.x, v.y - $0.y) < 30 }) { transformDrag = .scale }
            else { transformDrag = .move }
            transformStart = (f.translate, f.scale, f.rotation, p)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first(where: { $0 === drawingTouch }), (event?.allTouches?.count ?? 1) == 1 else { return }
        cursorPoint = t.location(in: self)
        let moved = t.location(in: self)
        if hypot(moved.x - holdOrigin.x, moved.y - holdOrigin.y) > 8 { cancelHoldPick() }
        switch session.tool {
        case .smudge, .blur:
            for c in event?.coalescedTouches(for: t) ?? [t] { session.engine.continueStroke(to: toCanvas(c.location(in: self)), pressure: 1) }
        case .shape:
            shapeEnd = toCanvas(moved)
            showShapePreview()
        case .move:
            updateTransform(to: toCanvas(moved))
        case .pen:
            penMoved(to: moved)
        case .brush, .eraser:
            if session.selectionLayer {
                for c in event?.coalescedTouches(for: t) ?? [t] { session.engine.continueSelectStroke(to: toCanvas(c.location(in: self))) }
                return
            }
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
            shapeEnd = toCanvas(t.location(in: self))
            updateShapeOutline()
        case .selectBrush:
            for c in event?.coalescedTouches(for: t) ?? [t] { session.engine.continueSelectStroke(to: toCanvas(c.location(in: self))) }
        default: break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first(where: { $0 === drawingTouch }) else { return }
        drawingTouch = nil
        cursorPoint = nil
        cancelHoldPick()
        switch session.tool {
        case .smudge, .blur: session.engine.endStroke()
        case .shape:
            if let a = shapeStart {
                session.engine.brush = session.brush
                session.engine.erasing = false
                session.engine.drawShape(shapePoints(a, toCanvas(t.location(in: self))), filled: session.shapeFilled)
            }
            shapeStart = nil; shapeEnd = nil; outline.path = nil
        case .brush, .eraser:
            if session.selectionLayer { session.engine.endSelectStroke(snapToSubject: false) }
            else { session.engine.endStroke() }
        case .selectBrush: session.engine.endSelectStroke(snapToSubject: session.selectSnap == .subject && !session.selectSubtract, snapToEdges: session.selectSnap == .edges)
        case .lasso where session.polygonLasso:
            let v = t.location(in: self)
            // Tap near the first point (or with 2+ points, a quick second tap there) closes the shape.
            if let first = session.lassoPoints.first.map(viewport.view), session.lassoPoints.count >= 3, hypot(v.x - first.x, v.y - first.y) < 24 {
                finishLasso()
            } else {
                session.lassoPoints.append(toCanvas(v)); outlineView.append(v)
                showOutline(outlineView, closed: false)
            }
        case .lasso:
            finishLasso()
        case .quickSelect: session.engine.endQuickSelect()
        case .rectSelect, .ellipseSelect:
            if let a = shapeStart { session.engine.selectShape(a, toCanvas(t.location(in: self)), ellipse: session.tool == .ellipseSelect) }
            shapeStart = nil; shapeEnd = nil
            outline.path = nil
        case .move: transformDrag = nil; transformStart = nil
        case .pen: penDrag = nil
        default: break
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.contains(where: { $0 === drawingTouch }) else { return }
        drawingTouch = nil
        cancelHoldPick()
        transformDrag = nil; transformStart = nil
        if session.tool == .smudge || session.tool == .blur { session.engine.cancelStroke() }
        if session.tool == .brush || session.tool == .eraser { if session.selectionLayer { session.engine.cancelSelectStroke() } else { session.engine.cancelStroke() } }
        if session.tool == .selectBrush { session.engine.cancelSelectStroke() }
        if session.tool == .quickSelect { session.engine.cancelQuickSelect() }
        // Polygon points are committed taps and survive navigation gestures; their overlay is reprojected.
        if !session.polygonLasso { session.lassoPoints = [] }
        outlineView = []; outline.path = nil
        shapeStart = nil; shapeEnd = nil
    }

    // MARK: Vector path (tap for a corner, tap and pull for a curve, drag a point or handle to reshape)

    private enum PenDrag { case point(Int), handle(Int), newHandle(Int) }
    private var penDrag: PenDrag?

    private func penBegan(at v: CGPoint) {
        var path = session.penPath
        // Handles first: they sit on top of the points.
        for (i, a) in path.anchors.enumerated() where a.handle != .zero {
            let h = viewport.view(a.point + a.handle)
            if hypot(v.x - h.x, v.y - h.y) < 22 { penDrag = .handle(i); return }
        }
        for (i, a) in path.anchors.enumerated() {
            let q = viewport.view(a.point)
            if hypot(v.x - q.x, v.y - q.y) < 22 {
                if i == 0, path.anchors.count > 2, !path.closed { path.closed = true; session.penPath = path; return }
                penDrag = .point(i); return
            }
        }
        guard !path.closed else { return }
        path.anchors.append(PenAnchor(point: toCanvas(v)))
        session.penPath = path
        penDrag = .newHandle(path.anchors.count - 1)
    }

    private func penMoved(to v: CGPoint) {
        guard let drag = penDrag else { return }
        let p = toCanvas(v)
        var path = session.penPath
        switch drag {
        case .point(let i) where path.anchors.indices.contains(i): path.anchors[i].point = p
        case .handle(let i) where path.anchors.indices.contains(i): path.anchors[i].handle = p - path.anchors[i].point
        case .newHandle(let i) where path.anchors.indices.contains(i):
            let pull = p - path.anchors[i].point
            // A small wobble while tapping stays a sharp corner.
            path.anchors[i].handle = simd_length(pull) * Double(zoom) < 10 ? .zero : pull
        default: return
        }
        session.penPath = path
    }

    private func updatePenOverlay() {
        guard session.tool == .pen, !session.penPath.isEmpty else { if session.tool == .pen { penOverlay.path = nil; penLine.path = nil }; return }
        let line = UIBezierPath(), dots = UIBezierPath()
        let points = session.penPath.flattened(step: 6).map(viewport.view)
        if let f = points.first { line.move(to: f); points.dropFirst().forEach { line.addLine(to: $0) } }
        for a in session.penPath.anchors {
            let q = viewport.view(a.point)
            dots.append(UIBezierPath(rect: CGRect(x: q.x - 5, y: q.y - 5, width: 10, height: 10)))
            if a.handle != .zero {
                let h1 = viewport.view(a.point + a.handle), h2 = viewport.view(a.point - a.handle)
                line.move(to: h2); line.addLine(to: h1)
                dots.append(UIBezierPath(ovalIn: CGRect(x: h1.x - 6, y: h1.y - 6, width: 12, height: 12)))
            }
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        penLine.path = line.cgPath; penOverlay.path = dots.cgPath
        CATransaction.commit()
    }

    private func updateTransform(to p: SIMD2<Double>) {
        guard let f = session.engine.floating, let start = transformStart, let drag = transformDrag else { return }
        let pivot = f.pivot + start.translate
        switch drag {
        case .move: f.translate = start.translate + (p - start.canvas)
        case .scale:
            let from = simd_length(start.canvas - pivot), to = simd_length(p - pivot)
            if from > 1 { f.scale = start.scale * max(0.02, to / from) }
        case .rotate:
            let a = p - pivot, b = start.canvas - pivot
            f.rotation = start.rotation + atan2(a.y, a.x) - atan2(b.y, b.x)
        }
        session.engine.updateFloating()
    }

    private func updateTransformBox() {
        guard session.tool == .move, let f = session.engine.floating else { handles.path = nil; return }
        let c = f.corners.map(viewport.view)
        let top = CGPoint(x: (c[0].x + c[1].x) / 2, y: (c[0].y + c[1].y) / 2)
        let center = viewport.view(f.pivot + f.translate)
        let away = max(1, hypot(top.x - center.x, top.y - center.y))
        let knob = CGPoint(x: top.x + (top.x - center.x) / away * 34, y: top.y + (top.y - center.y) / away * 34)
        let path = UIBezierPath()
        path.move(to: c[0]); c.dropFirst().forEach { path.addLine(to: $0) }; path.close()
        path.move(to: top); path.addLine(to: knob)
        for q in c { path.append(UIBezierPath(rect: CGRect(x: q.x - 6, y: q.y - 6, width: 12, height: 12))) }
        path.append(UIBezierPath(ovalIn: CGRect(x: knob.x - 7, y: knob.y - 7, width: 14, height: 14)))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        handles.path = path.cgPath
        CATransaction.commit()
    }

    private func shapePoints(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> [SIMD2<Double>] {
        switch session.shapeKind {
        case .line: return [a, b]
        case .rectangle: return [a, SIMD2(b.x, a.y), b, SIMD2(a.x, b.y), a]
        case .ellipse:
            let c = (a + b) / 2, r = (b - a) / 2
            return (0...96).map { i in
                let t = Double(i) / 96 * 2 * .pi
                return c + SIMD2(cos(t) * r.x, sin(t) * r.y)
            }
        }
    }

    private func showShapePreview() {
        guard let a = shapeStart, let b = shapeEnd else { return }
        showOutline(shapePoints(a, b).map(viewport.view), closed: false)
    }

    private func pickColor(at p: SIMD2<Double>, returnTool: DrawTool = .brush) {
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
            self.session.tool = returnTool == .eraser ? .brush : returnTool
        }
    }

    // MARK: Navigation gestures

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        userNavigated = true
        let loc = g.location(in: self)
        let before = toCanvas(loc)
        zoom = min(max(zoom * g.scale, 0.05), 40)
        g.scale = 1
        // Keep the pinch point fixed.
        let projected = viewport.view(before)
        offset.x += loc.x - projected.x
        offset.y += loc.y - projected.y
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        userNavigated = true
        let t = g.translation(in: self)
        offset.x += t.x; offset.y += t.y
        g.setTranslation(.zero, in: self)
    }

    @objc private func onRotate(_ g: UIRotationGestureRecognizer) {
        let location = g.location(in: self), anchor = toCanvas(g.location(in: self))
        rotation += g.rotation
        g.rotation = 0
        let projected = viewport.view(anchor)
        offset.x += location.x - projected.x; offset.y += location.y - projected.y
    }

    // MARK: Rendering

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        if session.fitRequested { fitted = false; userNavigated = false; rotation = 0; session.fitRequested = false }
        fitIfNeeded()
        updateCursor()
        updateTransformBox()
        updatePenOverlay()
        if session.tool != .pen, penLine.path != nil { penLine.path = nil; penOverlay.path = nil }
        if session.tool == .rectSelect || session.tool == .ellipseSelect { updateShapeOutline() }
        if session.tool == .lasso, !session.lassoPoints.isEmpty {
            showOutline(session.lassoPoints.map(viewport.view), closed: false)
        }
        let e = session.engine
        guard let cb = e.queue.makeCommandBuffer(), let rpd = currentRenderPassDescriptor, let drawable = currentDrawable else { return }
        e.encodeComposite(cb)
        guard let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }
        // Canvas quad in NDC (rotation applied by rotating the viewport-sized quad corners on the CPU).
        let w = bounds.width, h = bounds.height
        func ndc(_ p: CGPoint) -> SIMD2<Float> { SIMD2(Float(p.x / w * 2 - 1), Float(1 - p.y / h * 2)) }
        let corners = [SIMD2(0.0, Double(canvasSize.height)), SIMD2(Double(canvasSize.width), Double(canvasSize.height)),
                       SIMD2(0.0, 0.0), SIMD2(Double(canvasSize.width), 0.0)].map { ndc(viewport.view($0)) }
        var opts = SIMD4<Float>(e.hasSelection ? 1 : 0, Float(session.bgMode), Float(session.selectionView),
                                Float(CACurrentMediaTime().truncatingRemainder(dividingBy: 1000)))
        var bg = session.bgColor.simd
        enc.setRenderPipelineState(e.displayPSO)
        corners.withUnsafeBufferPointer { enc.setVertexBytes($0.baseAddress!, length: MemoryLayout<SIMD2<Float>>.stride * 4, index: 0) }
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
    @State private var filtering = false
    @State private var filter = DrawFilter()
    @State private var filterControl = 0
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
                if session.tool.usesBrush { sideSliders.padding(.leading, 8) }
                if session.selectionLayer { selectionLayerBadge }
                if showLayers { HStack { Spacer(); LayersPanel(session: session, engine: engine).frame(width: 270).padding(8) }.transition(.move(edge: .trailing)) }
            }
            if engine.animating { animationBar }
            contextPanel
            dock
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showLayers)
        .awiSheet(isPresented: $showBrushes) { BrushPicker(session: session).presentationDetents([.medium, .large]) }
        .awiSheet(isPresented: $showRefine) { SelectionRefineSheet(session: session).presentationDetents([.medium, .large]) }
        .onDisappear { playTimer?.invalidate(); engine.cancelSubjectSelection() }
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

    private var selectionLayerBadge: some View {
        VStack {
            Button { session.selectionLayer = false } label: {
                Label("Painting the selection. Tap to leave", systemImage: "square.dashed.inset.filled")
                    .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.accent)).foregroundStyle(.white)
            }
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func send(_ configure: () -> Void) { engine.commitFloating(); configure(); onDone(engine) }

    private var topBar: some View {
        HStack(spacing: 2) {
            iconButton("xmark") { engine.cancelFloating(); onCancel() }.accessibilityLabel("Cancel")
            iconButton("arrow.uturn.backward", enabled: engine.canUndo) { engine.undo() }.accessibilityLabel("Undo")
            iconButton("arrow.uturn.forward", enabled: engine.canRedo) { engine.redo() }.accessibilityLabel("Redo")
            Spacer(minLength: 2)
            iconButton("square.3.layers.3d", active: showLayers) { engine.commitFloating(); showLayers.toggle() }.accessibilityLabel("Layers")
            moreMenu
            Menu {
                if engine.animating {
                    Button { send { engine.sendAsFrames = true; engine.sendAsParts = false } } label: {
                        Label("Send Animation (\(engine.frameLayers.count) frames)", systemImage: "film")
                    }
                }
                Button { send { engine.sendAsFrames = false; engine.sendAsParts = false } } label: { Label("Send as One Layer", systemImage: "square") }
                Button { send { engine.sendAsFrames = false; engine.sendAsParts = true } } label: {
                    Label("Send Parts as Separate Layers", systemImage: "square.3.layers.3d.down.right")
                }
            } label: {
                Label("Send", systemImage: "arrow.down.to.line")
                    .font(.system(size: 13, weight: .bold)).lineLimit(1).fixedSize()
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent)).foregroundStyle(.white)
            }
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 6).frame(height: 50)
    }

    private var moreMenu: some View {
        Menu {
            Button { showPhotos = true } label: { Label("Import Photo", systemImage: "photo.badge.plus") }
            Button { session.fitRequested = true } label: { Label("Fit Canvas to Screen", systemImage: "arrow.up.left.and.down.right.magnifyingglass") }
            Toggle(isOn: Binding(get: { engine.animating }, set: { engine.commitFloating(); engine.animating = $0; engine.touch() })) { Label("Frame Animation", systemImage: "film.stack") }
            Menu {
                Picker("Symmetry", selection: Binding(get: { engine.symmetry }, set: { engine.symmetry = $0; engine.touch() })) {
                    ForEach(DrawSymmetry.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Straight Line Ruler", isOn: Binding(get: { engine.ruler == .line }, set: { engine.ruler = $0 ? .line : .none; engine.touch() }))
            } label: { Label("Rulers & Symmetry", systemImage: "ruler") }
            Menu {
                Button { startFilter() } label: { Label("Adjust Color / Blur", systemImage: "slider.horizontal.3") }
                Button { engine.extractLines() } label: { Label("Extract Line Art", systemImage: "scribble") }
                Button { engine.flipActive(horizontal: true) } label: { Label("Flip Horizontal", systemImage: "arrow.left.and.right") }
                Button { engine.flipActive(horizontal: false) } label: { Label("Flip Vertical", systemImage: "arrow.up.and.down") }
                Button(role: .destructive) { engine.clearActiveLayer() } label: { Label("Clear Layer", systemImage: "trash") }
            } label: { Label("Layer Filters", systemImage: "wand.and.rays") }
            Menu {
                Button("Transparent") { session.bgMode = 0 }
                Button("White") { session.bgMode = 1; session.bgColor = .white }
                Button("Black") { session.bgMode = 1; session.bgColor = .black }
                Button("Gray") { session.bgMode = 1; session.bgColor = RGBA(0.5, 0.5, 0.5) }
                Text("Only shown while drawing. Drawings stay transparent.")
            } label: { Label("Canvas Background", systemImage: "checkerboard.rectangle") }
        } label: {
            Image(systemName: "ellipsis.circle").font(.system(size: 17, weight: .semibold)).frame(width: 38, height: 36).foregroundStyle(Theme.text)
        }
        .accessibilityLabel("More")
    }

    private var sideSliders: some View {
        VStack(spacing: 18) {
            VerticalSlider(value: Binding(get: { session.activeBrush.size }, set: { session.activeBrush.size = $0 }), range: 1...400, label: "\(Int(session.activeBrush.size))")
            VerticalSlider(value: Binding(get: { session.activeBrush.opacity * 100 }, set: { session.activeBrush.opacity = $0 / 100 }), range: 1...100, label: "\(Int(session.activeBrush.opacity * 100))%")
        }
        .padding(.vertical, 8).padding(.horizontal, 4).glass(radius: 14)
    }

    /// One place for whatever the current tool needs, directly above the dock.
    @ViewBuilder private var contextPanel: some View {
        VStack(spacing: 6) {
            if filtering { filterPanel } else {
            if session.tool.isSelection { selectionToolRow }
            toolOptions
            if engine.hasSelection || engine.isSelectingSubject || session.tool.isSelection { selectionBar }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private func startFilter() {
        engine.commitFloating()
        engine.beginFilter()
        filter = DrawFilter(); filterControl = 0; filtering = true
    }

    /// One slider at a time, so the canvas stays in view while you adjust.
    private var filterPanel: some View {
        let controls: [(String, WritableKeyPath<DrawFilter, Double>, ClosedRange<Double>)] = [
            ("Bright", \.brightness, -0.5...0.5), ("Contrast", \.contrast, 0.5...1.8), ("Satur.", \.saturation, 0...2),
            ("Hue", \.hue, -3.14...3.14), ("Blur", \.blur, 0...40), ("Sharpen", \.sharpen, 0...2)]
        let current = controls[filterControl]
        return VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(controls.indices, id: \.self) { i in
                        Button { filterControl = i } label: {
                            Text(controls[i].0).font(.system(size: 12, weight: .semibold)).lineLimit(1).fixedSize()
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Capsule().fill(filterControl == i ? Theme.accent : Theme.raised))
                                .foregroundStyle(filterControl == i ? Color.white : Theme.text)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            Slider(value: Binding(get: { filter[keyPath: current.1] }, set: { filter[keyPath: current.1] = $0; engine.updateFilter(filter) }), in: current.2)
                .tint(Theme.accent).padding(.horizontal, 12)
            HStack {
                chip("Cancel", "xmark") { engine.cancelFilter(); filtering = false }
                Spacer()
                chip("Reset", "arrow.counterclockwise") { filter = DrawFilter(); engine.updateFilter(filter) }
                chip("Apply", "checkmark") { engine.commitFilter(filter); filtering = false }
            }
            .padding(.horizontal, 10)
        }
    }

    private var selectionToolRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DrawTool.selectionTools) { t in
                    Button { session.tool = t } label: {
                        Label(t.title, systemImage: t.symbol).font(.system(size: 12, weight: .semibold)).lineLimit(1).fixedSize()
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Capsule().fill(session.tool == t ? Theme.accent : Theme.raised))
                            .foregroundStyle(session.tool == t ? Color.white : Theme.text)
                    }
                    .accessibilityLabel(t.title)
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func labeledPicker<T: Hashable>(_ selection: Binding<T>, _ options: [(String, T)]) -> some View {
        Picker("", selection: selection) { ForEach(options, id: \.1) { Text($0.0).tag($0.1) } }.pickerStyle(.segmented)
    }

    /// Per-tool options.
    @ViewBuilder private var toolOptions: some View {
        switch session.tool {
        case .brush:
            HStack(spacing: 8) {
                Button { showBrushes = true } label: {
                    Label(session.brushName, systemImage: session.brush.kind.symbol).font(.system(size: 13, weight: .semibold)).lineLimit(1).fixedSize()
                        .padding(.horizontal, 12).padding(.vertical, 7).background(Capsule().fill(Theme.raised)).foregroundStyle(Theme.text)
                }
                .accessibilityLabel("Choose Brush")
                optionSlider("Smooth", value: $session.brush.stabilizer, range: 0...1)
            }
            .padding(.horizontal, 10)
        case .eraser:
            HStack(spacing: 8) {
                Menu {
                    ForEach(BrushKind.allCases.filter { $0 != .eraser }) { k in Button { session.eraser.kind = k } label: { Label(k.title, systemImage: k.symbol) } }
                } label: {
                    Label(session.eraser.kind.title, systemImage: session.eraser.kind.symbol).font(.system(size: 13, weight: .semibold)).lineLimit(1).fixedSize()
                        .padding(.horizontal, 12).padding(.vertical, 7).background(Capsule().fill(Theme.raised)).foregroundStyle(Theme.text)
                }
                optionSlider("Soft", value: Binding(get: { 1 - session.eraser.hardness }, set: { session.eraser.hardness = 1 - $0 }), range: 0...1)
            }
            .padding(.horizontal, 10)
        case .smudge, .blur:
            optionSlider("Soft", value: Binding(get: { 1 - session.smudger.hardness }, set: { session.smudger.hardness = 1 - $0 }), range: 0...1).padding(.horizontal, 10)
        case .shape:
            HStack(spacing: 8) {
                Picker("", selection: $session.shapeKind) {
                    ForEach(DrawShapeKind.allCases) { Image(systemName: $0.symbol).tag($0) }
                }.pickerStyle(.segmented)
                labeledPicker($session.shapeFilled, [("Line", false), ("Filled", true)]).frame(width: 130)
            }
            .padding(.horizontal, 10)
        case .quickSelect:
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    labeledPicker($session.selectSubtract, [("Add", false), ("Remove", true)]).frame(width: 140)
                    optionSlider("Edge", value: Binding(get: { engine.quickTolerance }, set: { engine.quickTolerance = $0 }), range: 0.02...0.5)
                    sourcePicker
                }
            }
            .padding(.horizontal, 10)
        case .selectBrush:
            HStack(spacing: 8) {
                labeledPicker($session.selectSubtract, [("Add", false), ("Remove", true)]).frame(width: 140)
                Menu {
                    Picker("When you lift", selection: $session.selectSnap) { ForEach(SelectBrushSnap.allCases) { Text($0.title).tag($0) } }
                } label: { menuChip(session.selectSnap.title) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
        case .pen:
            penBar
        case .wand:
            VStack(spacing: 6) {
                optionSlider("Tolerance", value: $session.fillTolerance, range: 0...0.6)
                HStack(spacing: 6) {
                    selectionModePicker
                    sourcePicker
                    Toggle("Connected", isOn: $session.wandContiguous).toggleStyle(.button).tint(Theme.accent).font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(Theme.text).padding(.horizontal, 10)
        case .fill:
            VStack(spacing: 6) {
                labeledPicker($session.fillErase, [("Fill", false), ("Erase Area", true)])
                optionSlider("Tolerance", value: $session.fillTolerance, range: 0...0.6)
                HStack(spacing: 8) {
                    Stepper("Gaps \(session.gapClose)", value: $session.gapClose, in: 0...10).font(.system(size: 12, weight: .semibold))
                    sourcePicker
                }
            }
            .foregroundStyle(Theme.text).padding(.horizontal, 10)
        case .lasso:
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    labeledPicker($session.lassoFills, [("Select", false), ("Draw", true)])
                    labeledPicker($session.polygonLasso, [("Freehand", false), ("Points", true)])
                }
                if !session.lassoFills { HStack { selectionModePicker; Spacer(minLength: 0) } }
            }
            .padding(.horizontal, 10)
        case .rectSelect, .ellipseSelect:
            HStack { selectionModePicker; Spacer(minLength: 0) }.padding(.horizontal, 10)
        case .move:
            transformBar
        case .eyedropper:
            Text("Tap the canvas to pick a color. You can also hold still on the canvas with the brush.")
                .font(.system(size: 12)).foregroundStyle(Theme.textDim).padding(.horizontal, 10)
        }
    }

    private func menuChip(_ title: String) -> some View {
        HStack(spacing: 3) { Text(title); Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .bold)) }
            .font(.system(size: 12, weight: .semibold)).lineLimit(1).fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 7).background(Capsule().fill(Theme.raised)).foregroundStyle(Theme.text)
    }

    private var sourcePicker: some View {
        Menu {
            Picker("Look at", selection: Binding(get: { engine.sampleSource }, set: { engine.sampleSource = $0; engine.touch() })) {
                ForEach(SampleSource.allCases) { Text($0.title).tag($0) }
            }
        } label: { menuChip(engine.sampleSource.title) }
    }

    private var penBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if session.penPath.isEmpty {
                    Text("Tap for a corner. Tap and pull for a curve. Tap the first point to close.").font(.system(size: 12)).foregroundStyle(Theme.textDim)
                } else {
                    chip("Draw Line", "scribble") { finishPen { engine.applyPath($0, filled: false) } }
                    chip("Fill", "drop.fill") { finishPen { engine.applyPath($0, filled: true) } }
                    chip("Select", "lasso") { finishPen { engine.selectPath($0) } }
                    chip("Back", "arrow.uturn.backward") {
                        if session.penPath.closed { session.penPath.closed = false } else { _ = session.penPath.anchors.popLast() }
                    }
                    chip("Clear", "xmark") { session.penPath = PenPath() }
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func finishPen(_ apply: (PenPath) -> Void) {
        engine.brush = session.brush
        engine.erasing = false
        apply(session.penPath)
        session.penPath = PenPath()
    }

    private var transformBar: some View {
        HStack(spacing: 8) {
            if engine.isFloating {
                chip("Flip H", "arrow.left.and.right") { engine.flipFloating(horizontal: true) }
                chip("Flip V", "arrow.up.and.down") { engine.flipFloating(horizontal: false) }
                Spacer(minLength: 0)
                chip("Cancel", "xmark") { engine.cancelFloating() }
                chip("Done", "checkmark") { engine.commitFloating() }
            } else {
                Text(engine.hasSelection ? "Drag to move the selection. Corners scale, the top knob rotates." : "Drag to move this layer. Corners scale, the top knob rotates.")
                    .font(.system(size: 12)).foregroundStyle(Theme.textDim)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10)
    }

    private var selectionModePicker: some View {
        Menu {
            Picker("Mode", selection: Binding(get: { engine.selectionMode }, set: { engine.selectionMode = $0; engine.touch() })) {
                ForEach(SelectionMode.allCases) { Text($0.title).tag($0) }
            }
        } label: { menuChip(engine.selectionMode.title) }
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

    private var selectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
            if let message = engine.selectionMessage { Text(message).font(.caption).foregroundStyle(Theme.textDim) }
            chip("Refine Edge", "slider.horizontal.below.square.and.square.filled") { showRefine = true }
            chip("Remove Background", "person.crop.rectangle.badge.xmark") { engine.deleteOutsideSelection() }
            chip("AI Subject", "person.crop.rectangle") {
                engine.selectSubjectAsync()
            }
            chip("Select Layer", "square.dashed") { engine.selectOpaque() }
            chip("To New Layer", "square.on.square") { engine.liftSelectionToLayer() }
            chip("Cut", "scissors") { engine.cutSelection() }
            chip("Copy", "doc.on.doc") { engine.copySelection() }
            chip("Paste", "doc.on.clipboard") { engine.paste() }
            chip("Delete", "trash") { engine.deleteSelection() }
            chip("Invert", "circle.lefthalf.filled") { engine.invertSelection() }
            if engine.isSelectingSubject {
                ProgressView().tint(Theme.accentGlow)
                chip("Cancel AI", "xmark") { engine.cancelSubjectSelection() }
            }
            chip("Clear", "xmark") { engine.clearSelection(recordUndo: true) }
        }
        .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
    }

    private func dockButton(_ title: String, _ symbol: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).frame(height: 22)
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(active ? Theme.accentGlow : Theme.text)
            .background(RoundedRectangle(cornerRadius: 11).fill(active ? Theme.accent.opacity(0.22) : .clear))
        }
        .accessibilityLabel(title)
    }

    private var dock: some View {
        HStack(spacing: 2) {
            dockButton("Brush", session.brush.kind.symbol, active: session.tool == .brush) {
                if session.tool == .brush { showBrushes = true } else { session.tool = .brush }
            }
            dockButton("Eraser", DrawTool.eraser.symbol, active: session.tool == .eraser) { session.tool = .eraser }
            dockButton("Fill", DrawTool.fill.symbol, active: session.tool == .fill) { session.tool = .fill }
            dockButton("Select", "lasso", active: session.tool.isSelection) { session.tool = session.lastSelectionTool }
            dockButton("Transform", DrawTool.move.symbol, active: session.tool == .move) { session.tool = .move }
            Menu {
                ForEach([DrawTool.smudge, .blur, .shape, .pen, .eyedropper]) { t in
                    Button { session.tool = t } label: { Label(t.title, systemImage: t.symbol) }
                }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: [.smudge, .blur, .shape, .pen, .eyedropper].contains(session.tool) ? session.tool.symbol : "square.grid.2x2").font(.system(size: 18, weight: .semibold)).frame(height: 22)
                    Text([.smudge, .blur, .shape, .pen, .eyedropper].contains(session.tool) ? session.tool.title : "More").font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle([.smudge, .blur, .shape, .pen, .eyedropper].contains(session.tool) ? Theme.accentGlow : Theme.text)
            }
            .accessibilityLabel("More Tools")
            AWIColorWell("", selection: Binding(get: { Color(session.brush.color) }, set: { session.brush.color = $0.rgba }), supportsOpacity: false)
                .labelsHidden().frame(width: 44)
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
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
    @ObservedObject var session: DrawSession
    @ObservedObject var engine: DrawEngine
    @State private var showRename = false
    @State private var renaming = ""
    @State private var picking = false
    @State private var picked: Set<UUID> = []
    @State private var dragged: UUID?
    @State private var dragOffset: CGFloat = 0
    private let rowHeight: CGFloat = 54

    var body: some View {
        VStack(spacing: 8) {
            header
            Button { session.selectionLayer = true; session.tool = .brush } label: {
                HStack {
                    Image(systemName: "square.dashed.inset.filled")
                    Text("Selection Layer").font(.system(size: 12, weight: .semibold))
                    Spacer(); Image(systemName: "lock.fill").font(.system(size: 10))
                }
                .padding(.horizontal, 10).frame(height: 38)
                .foregroundStyle(Theme.text)
                .background(RoundedRectangle(cornerRadius: 9).fill(session.selectionLayer ? Theme.accent.opacity(0.3) : Theme.surface))
            }
            .accessibilityIdentifier("drawing-selection-layer")
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(engine.layers.enumerated().reversed()), id: \.element.id) { i, l in row(i, l) }
                }
            }
            .scrollDisabled(dragged != nil)
            if picking { pickActions } else if let l = engine.activeLayer { settings(l) }
        }
        .padding(10).glass(radius: 14)
        .alert("Rename Layer", isPresented: $showRename) {
            TextField("Name", text: $renaming)
            Button("OK") { engine.renameActive(renaming) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Layers").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
            Spacer()
            Button { picking.toggle(); picked = [] } label: { Text(picking ? "Done" : "Select").font(.system(size: 13, weight: .semibold)) }
            Button { engine.addLayer() } label: { Image(systemName: "plus") }.accessibilityLabel("Add Layer")
            Button { engine.duplicateActiveLayer() } label: { Image(systemName: "plus.square.on.square") }.accessibilityLabel("Duplicate Layer")
        }
        .foregroundStyle(Theme.accentGlow)
    }

    private func row(_ i: Int, _ l: DrawLayer) -> some View {
        let active = i == engine.activeIndex && !session.selectionLayer
        return HStack(spacing: 8) {
            if picking {
                Image(systemName: picked.contains(l.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(Theme.accentGlow).frame(width: 24)
            } else {
                Button { l.visible.toggle(); engine.touch() } label: {
                    Image(systemName: l.visible ? "eye" : "eye.slash").frame(width: 24, height: 40)
                }
                .accessibilityLabel(l.visible ? "Hide \(l.name)" : "Show \(l.name)")
            }
            LayerThumb(engine: engine, layer: l)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(Int(l.opacity * 100))%")
                    if l.blend != .normal { Text(l.blend.title) }
                    if l.clipping { Image(systemName: "arrow.turn.left.down") }
                    if l.alphaLock { Image(systemName: "lock.fill") }
                }
                .font(.system(size: 10)).foregroundStyle(Theme.textDim)
            }
            Spacer(minLength: 0)
            if !picking {
                Image(systemName: "line.3.horizontal").foregroundStyle(Theme.textDim).frame(width: 32, height: 44).contentShape(Rectangle())
                    .accessibilityLabel("Reorder \(l.name)")
                    .gesture(DragGesture(minimumDistance: 2).onChanged { g in
                        dragged = l.id; dragOffset = g.translation.height
                    }.onEnded { g in
                        // The list is drawn top layer first, so dragging down lowers the layer.
                        let to = min(max(i - Int((g.translation.height / rowHeight).rounded()), 0), engine.layers.count - 1)
                        dragged = nil; dragOffset = 0
                        engine.moveLayer(from: i, to: to)
                    })
            }
        }
        .foregroundStyle(Theme.text)
        .padding(.leading, 6).frame(height: rowHeight - 4)
        .background(RoundedRectangle(cornerRadius: 9).fill(active ? Theme.accent.opacity(0.3) : Theme.surface))
        .offset(y: dragged == l.id ? dragOffset : 0)
        .zIndex(dragged == l.id ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            if picking {
                if picked.contains(l.id) { picked.remove(l.id) } else { picked.insert(l.id) }
            } else {
                engine.commitFloating(); session.selectionLayer = false; engine.activeIndex = i; engine.touch()
            }
        }
        .contextMenu {
            Button("Rename") { renaming = l.name; engine.activeIndex = i; showRename = true }
            Button("Duplicate") { engine.activeIndex = i; engine.duplicateActiveLayer() }
            Button("Merge Down") { engine.activeIndex = i; engine.mergeDown() }
            Button("Clear") { engine.activeIndex = i; engine.clearActiveLayer() }
            Button("Delete", role: .destructive) { engine.activeIndex = i; engine.deleteActiveLayer() }
        }
    }

    private var pickActions: some View {
        HStack {
            Button("Merge") { engine.mergeLayers(picked); picked = []; picking = false }.disabled(picked.count < 2)
            Spacer()
            Button("Hide") { for l in engine.layers where picked.contains(l.id) { l.visible = false }; engine.touch() }.disabled(picked.isEmpty)
            Spacer()
            Button("Delete", role: .destructive) { engine.deleteLayers(picked); picked = []; picking = false }.disabled(picked.isEmpty)
        }
        .font(.system(size: 13, weight: .semibold))
    }

    private func settings(_ l: DrawLayer) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("Opacity").font(.caption)
                Slider(value: Binding(get: { l.opacity }, set: { l.opacity = $0; engine.touch() }), in: 0...1)
            }
            HStack(spacing: 8) {
                Menu {
                    Picker("Blend", selection: Binding(get: { l.blend }, set: { l.blend = $0; engine.touch() })) {
                        ForEach(BlendMode.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Text(l.blend.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 6).background(Capsule().fill(Theme.raised))
                }
                Toggle("Clip", isOn: Binding(get: { l.clipping }, set: { l.clipping = $0; engine.touch() })).toggleStyle(.button)
                Toggle("Lock", isOn: Binding(get: { l.alphaLock }, set: { l.alphaLock = $0; engine.touch() })).toggleStyle(.button)
            }
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
    }
}

/// Tiny live preview of a layer (refreshes with the engine revision).
struct LayerThumb: View {
    @ObservedObject var engine: DrawEngine
    let layer: DrawLayer
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.45))
            if let image { Image(uiImage: image).resizable().scaledToFit() }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task(id: engine.revision) { image = engine.thumbnail(of: layer) }
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
