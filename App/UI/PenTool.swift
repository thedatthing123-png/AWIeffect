import SwiftUI
import simd

/// What a pen session creates.
enum PenTarget: Equatable {
    case newShape
    case shapePath(UUID, UUID)
    case mask(UUID)
}

enum PenStyle: Equatable { case points, freehand }

extension EditorState {
    /// Creates a path shape layer from comp-space vertices.
    func addPathLayer(_ compPath: BezierPath) {
        let b = compPath.bounds
        let center = Vec2((b.min.x + b.max.x) / 2, (b.min.y + b.max.y) / 2)
        var local = compPath
        for i in local.vertices.indices { local.vertices[i].point = local.vertices[i].point - center }
        mutate("Add Path") { p in
            var l = p.makeLayer(name: "Path \(p.layers.count + 1)", content: .shape(.path),
                                size: Vec2(max(1, b.max.x - b.min.x), max(1, b.max.y - b.min.y)))
            l.transform.position = Animated(center)
            l.path = Animated(local)
            l.fill = Animated(compPath.closed ? RGBA(hex: 0x9B5CFF) : RGBA(0, 0, 0, 0))
            l.stroke.enabled = !compPath.closed
            l.stroke.color = Animated(RGBA(hex: 0xB98CFF))
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .shape
    }

    /// Adds a mask (comp-space path) to the layer with `id`, converting into that layer's local space.
    func addMask(_ compPath: BezierPath, to id: UUID) {
        guard let i = project.layers.firstIndex(where: { $0.id == id }) else { return }
        // Where the layer is drawn (parenting, 3D, camera of the current view), like puppet pins: the mask lands
        // exactly where it was drawn on the canvas.
        let M = displayPlacement(of: id)
            ?? Renderer.layerMatrix(project.layers[i], time: currentTime, renderScale: 1, includeEffects: false)
        var local = Self.maskLocal(compPath, placement: M)
        local.closed = true
        mutate("Add Mask") { p in
            p.layers[i].masks.append(LayerMask(name: "Mask \(p.layers[i].masks.count + 1)", path: Animated(local)))
        }
        selectedLayerID = id
        panel = .masks
    }

    /// Comp-space path -> layer-local, through a (possibly projective) placement. Tangent ends are mapped as points,
    /// so curves survive perspective too.
    nonisolated static func maskLocal(_ compPath: BezierPath, placement M: simd_double3x3) -> BezierPath {
        let inv = M.inverse
        func toLocal(_ v: Vec2) -> Vec2 {
            let q = inv * SIMD3(v.x, v.y, 1)
            return abs(q.z) > 1e-12 ? Vec2(q.x / q.z, q.y / q.z) : Vec2(q.x, q.y)
        }
        var local = compPath
        for k in local.vertices.indices {
            let v = compPath.vertices[k]
            let p = toLocal(v.point)
            local.vertices[k].point = p
            local.vertices[k].inTangent = toLocal(v.point + v.inTangent) - p
            local.vertices[k].outTangent = toLocal(v.point + v.outTangent) - p
        }
        return local
    }

    func addPrimitiveMask(ellipse: Bool) {
        guard let l = selectedLayer else { return }
        let hs = Renderer.layerHalfSize(l, time: currentTime)
        let size = Vec2(hs.x * 1.2, hs.y * 1.2)
        let path: BezierPath = ellipse ? .ellipse(size: size) : .rectangle(size: size)
        mutate("Add Mask") { p in
            guard let i = p.layers.firstIndex(where: { $0.id == l.id }) else { return }
            p.layers[i].masks.append(LayerMask(name: "Mask \(p.layers[i].masks.count + 1)", path: Animated(path)))
        }
        panel = .masks
    }

    func editMask(_ id: UUID, _ label: String, continuous: Bool = false, _ change: (inout LayerMask) -> Void) {
        guard let i = selectedIndex, let j = project.layers[i].masks.firstIndex(where: { $0.id == id }) else { return }
        if continuous {
            beginEdit(label)
            var p = project
            change(&p.layers[i].masks[j])
            project = p
        } else {
            mutate(label) { change(&$0.layers[i].masks[j]) }
        }
    }
}

/// Canvas overlay for drawing bezier paths, Alight Motion style:
/// - A cursor sits on the canvas. Move it with the swipe pad (your finger never covers the art), then Add Point.
/// - Or tap the canvas to drop a point right there; drag while dropping to pull a curve.
/// - Tap a point to select it: the pad then moves that point (or its curve handle in Curve mode), Delete removes it.
/// - Drag a point on the canvas to move it. Points are unlimited; the path only closes when you press Close.
@MainActor final class PenSession: ObservableObject {
    @Published var fit: CGRect = .zero
    var loaded = false
    @Published var vertices: [PathVertex] = []
    @Published var closed: Bool = false
    @Published var selected: Int? = nil
    @Published var cursor: Vec2? = nil
    @Published var curveMode: Bool = false
    @Published var dragStart: CGPoint? = nil
    @Published var dragVertex: Int? = nil
    @Published var dragVertexStart: Vec2? = nil
    @Published var freehand: [Vec2] = []
    @Published var broken: Bool = false
    @Published var dragHandle: MaskHandleSide? = nil
    func reset() {
        loaded = false
        vertices = []
        closed = false
        selected = nil
        cursor = nil
        curveMode = false
        dragStart = nil
        dragVertex = nil
        dragVertexStart = nil
        freehand = []
        broken = false
        dragHandle = nil
    }
}

struct PenOverlay: View {
    @ObservedObject var state: EditorState
    let target: PenTarget
    let style: PenStyle
    let fit: CGRect
    let done: () -> Void
    @ObservedObject var session: PenSession
    var controlsOnly = false
    private var vertices: [PathVertex] { get { session.vertices } nonmutating set { session.vertices = newValue } }
    private var closed: Bool { get { session.closed } nonmutating set { session.closed = newValue } }
    private var selected: Int? { get { session.selected } nonmutating set { session.selected = newValue } }
    private var cursor: Vec2? { get { session.cursor } nonmutating set { session.cursor = newValue } }
    private var curveMode: Bool { get { session.curveMode } nonmutating set { session.curveMode = newValue } }
    private var dragStart: CGPoint? { get { session.dragStart } nonmutating set { session.dragStart = newValue } }
    private var dragVertex: Int? { get { session.dragVertex } nonmutating set { session.dragVertex = newValue } }
    private var dragVertexStart: Vec2? { get { session.dragVertexStart } nonmutating set { session.dragVertexStart = newValue } }
    private var freehand: [Vec2] { get { session.freehand } nonmutating set { session.freehand = newValue } }
    private var broken: Bool { get { session.broken } nonmutating set { session.broken = newValue } }
    private var dragHandle: MaskHandleSide? { get { session.dragHandle } nonmutating set { session.dragHandle = newValue } }

    private var isMask: Bool { if case .mask = target { return true }; return false }
    private var scale: Double { Double(fit.width) / Double(state.project.width) }
    private func comp(_ p: CGPoint) -> Vec2 { Vec2(Double(p.x - fit.minX) / scale, Double(p.y - fit.minY) / scale) }
    private func view(_ v: Vec2) -> CGPoint { CGPoint(x: fit.minX + v.x * scale, y: fit.minY + v.y * scale) }
    private var cursorPoint: Vec2 { cursor ?? Vec2(Double(state.project.width) / 2, Double(state.project.height) / 2) }

    var body: some View {
        Group {
        if controlsOnly {
            VStack(spacing: 6) {
                topBar
                if style == .points { controls }
            }.padding(.vertical, 6).background(Theme.background)
        } else {
        ZStack(alignment: .top) {
            Color.black.opacity(0.001)
                .gesture(style == .points ? AnyGesture(pointsGesture.map { _ in () }) : AnyGesture(freehandGesture.map { _ in () }))
            Path { path in
                if style == .freehand {
                    path.addLines(freehand.map(view))
                } else if let first = vertices.first {
                    path.move(to: view(first.point))
                    for i in 1..<max(1, vertices.count) where i < vertices.count {
                        let a = vertices[i - 1], b = vertices[i]
                        path.addCurve(to: view(b.point), control1: view(a.point + a.outTangent), control2: view(b.point + b.inTangent))
                    }
                    if closed, vertices.count > 2, let last = vertices.last {
                        path.addCurve(to: view(first.point), control1: view(last.point + last.outTangent), control2: view(first.point + first.inTangent))
                    }
                }
            }
            .stroke(Theme.accentGlow, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .allowsHitTesting(false)
            if style == .points {
                ForEach(Array(vertices.enumerated()), id: \.offset) { i, v in
                    if v.outTangent != .zero || v.inTangent != .zero {
                        Path { p in p.move(to: view(v.point + v.inTangent)); p.addLine(to: view(v.point)); p.addLine(to: view(v.point + v.outTangent)) }
                            .stroke(i == selected ? Theme.accentGlow : Theme.textDim, lineWidth: 1).allowsHitTesting(false)
                        // The selected point's handle ends are big enough to drag; others stay small.
                        ForEach([v.inTangent, v.outTangent].filter { $0 != .zero }, id: \.self) { tan in
                            Circle().fill(i == selected ? Theme.accent : Theme.textDim)
                                .frame(width: i == selected ? 12 : 6, height: i == selected ? 12 : 6)
                                .position(view(v.point + tan)).allowsHitTesting(false)
                        }
                    }
                    Circle().fill(i == selected ? Theme.accent : (i == 0 ? Theme.accent.opacity(0.6) : .white)).frame(width: i == selected ? 16 : 12, height: i == selected ? 16 : 12)
                        .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
                        .position(view(v.point)).allowsHitTesting(false)
                }
                // The cursor: where Add Point drops the next point.
                if selected == nil {
                    let c = view(cursorPoint)
                    ZStack {
                        Circle().stroke(Color.white, lineWidth: 1.5).frame(width: 22, height: 22)
                        Rectangle().fill(Color.white).frame(width: 1.5, height: 30)
                        Rectangle().fill(Color.white).frame(width: 30, height: 1.5)
                    }
                    .shadow(color: .black.opacity(0.8), radius: 1.5)
                    .position(c).allowsHitTesting(false)
                }
            }
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Pen canvas").accessibilityIdentifier("pen-canvas")
        .onAppear { session.fit = fit; loadShapePath() }
        .onChange(of: fit) { _, value in session.fit = value }
        }
        }
    }

    private func loadShapePath() {
        guard !session.loaded else { return }; session.loaded = true
        if case .shapePath(let layer, let content) = target,
           let p = state.shapePenPath(layer: layer, content: content) {
            vertices = p.vertices; closed = p.closed
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Text(style == .freehand ? "Draw with your finger" : hint)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                .padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(.black.opacity(0.6)))
            Button("Cancel") { done() }.buttonStyle(.bordered).tint(Theme.danger)
            Button("Done") { finish() }
                .buttonStyle(.borderedProminent).tint(Theme.accent)
                .disabled(style == .points ? vertices.count < 2 : freehand.count < 3)
        }
        .padding(.top, 6)
    }

    private var hint: String {
        if let s = selected { return curveMode ? "Swipe: shape point \(s + 1)'s curve" : "Swipe: move point \(s + 1) · drag its handles" }
        return "Swipe to aim · Add Point · tap the line to insert a point"
    }

    /// Swipe pad + point buttons along the bottom of the canvas.
    private var controls: some View {
        VStack(spacing: 6) {
            SwipePad(hint: selected == nil ? "Swipe to move the cursor" : (curveMode ? "Swipe to bend the curve" : "Swipe to move the point"),
                     gain: Double(state.project.width) * 0.8) { d in padMoved(Vec2(Double(d.width), Double(d.height))) }
                .frame(height: 70)
            // Three per row: build the path, then shape the point.
            HStack(spacing: 6) {
                penButton(selected == nil ? "Add Point" : "Done Editing", selected == nil ? "plus.circle.fill" : "checkmark.circle") {
                    if selected == nil { addPoint(at: cursorPoint) } else { selected = nil; curveMode = false }
                }
                penButton("Curve", curveMode ? "point.topleft.down.curvedto.point.bottomright.up.fill" : "point.topleft.down.curvedto.point.bottomright.up", on: curveMode) {
                    if selected == nil, !vertices.isEmpty { selected = vertices.count - 1 }
                    curveMode.toggle()
                }
                .disabled(vertices.isEmpty)
                penButton(closed ? "Open" : "Close", closed ? "lasso" : "circle.dashed", on: closed) { closed.toggle() }
                    .disabled(vertices.count < 3)
            }
            HStack(spacing: 6) {
                penButton(broken ? "Broken" : "Linked", broken ? "line.diagonal" : "link", on: broken) { broken.toggle() }
                penButton("Corner", "square") { makeCorner() }
                    .disabled(vertices.isEmpty)
                penButton("Delete", "trash") { deletePoint() }
                    .disabled(vertices.isEmpty)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.55)))
        .padding(.horizontal, 8).padding(.bottom, 6)
    }

    private func penButton(_ title: String, _ icon: String, on: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(on ? Theme.accent : Theme.surface))
            .foregroundStyle(on ? Color.white : Theme.text)
        }
        .buttonStyle(.plain)
    }

    private func padMoved(_ d: Vec2) {
        if let s = selected, vertices.indices.contains(s) {
            if curveMode {
                // Pull the handle out from the point; both sides stay mirrored (smooth point).
                // Linked: both sides mirrored (smooth). Broken: only the outgoing side bends.
                let t = vertices[s].outTangent + d
                vertices[s].outTangent = t
                if !broken { vertices[s].inTangent = t * -1 }
            } else {
                vertices[s].point = vertices[s].point + d
            }
        } else {
            let w = Double(state.project.width), h = Double(state.project.height)
            let n = cursorPoint + d
            cursor = Vec2(min(max(n.x, -w * 0.5), w * 1.5), min(max(n.y, -h * 0.5), h * 1.5))
        }
    }

    private func addPoint(at p: Vec2) {
        vertices.append(PathVertex(point: p))
        cursor = p
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Selected (or last) point loses its handles: a sharp corner.
    private func makeCorner() {
        let i = selected ?? vertices.count - 1
        guard vertices.indices.contains(i) else { return }
        vertices[i].inTangent = .zero; vertices[i].outTangent = .zero
        curveMode = false
    }

    /// Handle end of the selected point under a touch.
    private func handleHit(_ loc: CGPoint) -> MaskHandleSide? {
        guard let s = selected, vertices.indices.contains(s) else { return nil }
        let v = vertices[s]
        var best: (MaskHandleSide, CGFloat)?
        for (side, tan) in [(MaskHandleSide.outTangent, v.outTangent), (.inTangent, v.inTangent)] where tan != .zero {
            let p = view(v.point + tan)
            let d = hypot(p.x - loc.x, p.y - loc.y)
            if d < 22, d < (best?.1 ?? .infinity) { best = (side, d) }
        }
        return best?.0
    }

    /// A touch on the drawn line (not on a point): segment index and position along it.
    private func segmentHit(_ loc: CGPoint) -> (Int, Double)? {
        guard vertices.count >= 2 else { return nil }
        let path = BezierPath(vertices: vertices, closed: closed && vertices.count > 2)
        guard let (seg, t, d) = path.nearestSegment(to: comp(loc), map: { $0 }), d * scale < 14, t > 0.02, t < 0.98 else { return nil }
        return (seg, t)
    }

    private func deletePoint() {
        guard !vertices.isEmpty else { return }
        let i = selected ?? vertices.count - 1
        guard vertices.indices.contains(i) else { return }
        vertices.remove(at: i)
        selected = nil; curveMode = false
        if vertices.count < 3 { closed = false }
    }

    /// Index of the point under a touch (view space), if any.
    private func vertexHit(_ loc: CGPoint) -> Int? {
        var best: (Int, CGFloat)?
        for (i, v) in vertices.enumerated() {
            let p = view(v.point)
            let d = hypot(p.x - loc.x, p.y - loc.y)
            if d < 24, d < (best?.1 ?? .infinity) { best = (i, d) }
        }
        return best?.0
    }

    private var pointsGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if dragStart == nil {
                    dragStart = v.startLocation
                    // Touching an existing point grabs it (select + drag to move). It never closes the path.
                    // A handle of the selected point: drag bends that side (both when Linked).
                    if let side = handleHit(v.startLocation) { dragHandle = side; return }
                    if let hit = vertexHit(v.startLocation) {
                        dragVertex = hit; dragVertexStart = vertices[hit].point
                        selected = hit
                        UISelectionFeedbackGenerator().selectionChanged()
                        return
                    }
                    // On the line: insert a point there; the curve keeps its shape.
                    if let (seg, t) = segmentHit(v.startLocation) {
                        var path = BezierPath(vertices: vertices, closed: closed && vertices.count > 2)
                        if let j = path.insertVertex(onSegment: seg, t: t) {
                            vertices = path.vertices
                            selected = j; curveMode = false
                            dragVertex = j; dragVertexStart = vertices[j].point
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        return
                    }
                    selected = nil; curveMode = false
                    addPoint(at: comp(v.startLocation))
                }
                if let side = dragHandle, let s = selected, vertices.indices.contains(s) {
                    var path = BezierPath(vertices: vertices, closed: closed)
                    path.moveHandle(s, side: side, toLocal: comp(v.location), broken: broken)
                    vertices = path.vertices
                    return
                }
                let d = comp(v.location) - comp(v.startLocation)
                if let i = dragVertex, let start = dragVertexStart, vertices.indices.contains(i) {
                    if hypot(d.x, d.y) > 2 { vertices[i].point = start + d }
                    return
                }
                guard !vertices.isEmpty else { return }
                if hypot(d.x, d.y) > 3 {
                    vertices[vertices.count - 1].outTangent = d
                    vertices[vertices.count - 1].inTangent = d * -1
                }
            }
            .onEnded { _ in dragStart = nil; dragVertex = nil; dragVertexStart = nil; dragHandle = nil }
    }

    private var freehandGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in freehand.append(comp(v.location)) }
            .onEnded { _ in }
    }

    private func finish() {
        let path: BezierPath
        if style == .freehand {
            guard freehand.count >= 3 else { done(); return }
            let first = freehand.first!, last = freehand.last!
            let autoClose = isMask || hypot(first.x - last.x, first.y - last.y) < 30 / scale
            path = BezierPath.smoothed(freehand, closed: autoClose, tolerance: 4 / scale)
        } else {
            guard vertices.count >= 2 else { done(); return }
            // Masks are always closed; shapes close only when you chose Close.
            path = BezierPath(vertices: vertices, closed: isMask ? true : closed)
        }
        switch target {
        case .newShape: state.addPathLayer(path)
        case .shapePath(let layer, let content): state.commitShapePen(path, layer: layer, content: content)
        case .mask(let id): state.addMask(path, to: id)
        }
        done()
    }
}

// MARK: - Masks panel

struct MasksPanel: View {
    @ObservedObject var state: EditorState
    let startPen: (PenTarget, PenStyle) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Masks")
            ScrollView {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ToolTile(icon: "square.dashed", title: "Rectangle") { state.addPrimitiveMask(ellipse: false) }
                        ToolTile(icon: "circle.dashed", title: "Ellipse") { state.addPrimitiveMask(ellipse: true) }
                        ToolTile(icon: "pencil.tip", title: "Pen") { if let id = state.selectedLayerID { startPen(.mask(id), .points) } }
                        ToolTile(icon: "scribble", title: "Freehand") { if let id = state.selectedLayerID { startPen(.mask(id), .freehand) } }
                    }
                    ForEach(state.selectedLayer?.masks ?? []) { m in maskCard(m) }
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
    }

    private func maskCard(_ m: LayerMask) -> some View {
        let t = state.currentTime
        return VStack(spacing: 6) {
            HStack {
                Text(m.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Toggle("Invert", isOn: Binding(get: { m.inverted }, set: { b in state.editMask(m.id, "Invert Mask") { $0.inverted = b } }))
                    .toggleStyle(.button).tint(Theme.accent).font(.system(size: 12))
                Button(role: .destructive) {
                    state.mutate("Delete Mask") { p in
                        if let i = state.selectedIndex { p.layers[i].masks.removeAll { $0.id == m.id } }
                    }
                } label: { Image(systemName: "trash") }
            }
            // Alight Motion's three modes up front, After Effects' extras one tap away.
            HStack(spacing: 6) {
                ForEach([MaskMode.add, .subtract, .intersect]) { mode in
                    Button { state.editMask(m.id, "Mask Mode") { $0.mode = mode } } label: {
                        VStack(spacing: 3) {
                            Image(systemName: mode.symbol).font(.system(size: 16, weight: .semibold))
                            Text(mode.title).font(.system(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 10).fill(m.mode == mode ? Theme.accent : Theme.surface))
                        .foregroundStyle(m.mode == mode ? Color.white : Theme.text)
                    }
                    .buttonStyle(.plain)
                }
                Menu {
                    ForEach([MaskMode.lighten, .darken, .difference, .none]) { mode in
                        Button { state.editMask(m.id, "Mask Mode") { $0.mode = mode } } label: { Label(mode.title, systemImage: mode.symbol) }
                    }
                } label: {
                    let extra = [MaskMode.lighten, .darken, .difference, .none].contains(m.mode)
                    VStack(spacing: 3) {
                        Image(systemName: extra ? m.mode.symbol : "ellipsis.circle").font(.system(size: 16, weight: .semibold))
                        Text(extra ? m.mode.title : "More").font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(extra ? Theme.accent : Theme.surface))
                    .foregroundStyle(extra ? Color.white : Theme.text)
                }
            }
            Text(m.mode.help).font(.caption).foregroundStyle(Theme.textDim).frame(maxWidth: .infinity, alignment: .leading)
            Toggle("Effects Only (limit this layer's effects to the mask)", isOn: Binding(get: { m.effectsOnly }, set: { b in
                state.editMask(m.id, "Effects Only") { $0.effectsOnly = b }
            }))
            .tint(Theme.accent).foregroundStyle(Theme.text).font(.system(size: 13))
            // Every mask value is animatable: the diamond keys it at the playhead.
            maskSlider("Feather", m, 0...400, \.feather, t)
            maskSlider("Opacity", m, 0...100, \.opacity, t)
            maskSlider("Expansion", m, -300...300, \.expansion, t)
            HStack(spacing: 8) {
                KeyframeDiamond(filled: m.path.hasKeyframe(at: t), animated: m.path.isAnimated) {
                    state.editMask(m.id, "Mask Path Keyframe") { $0.path.toggleKeyframe(at: t) }
                }
                Text("Mask Path").font(.system(size: 12)).foregroundStyle(Theme.text)
                Spacer()
            }
            MaskPathEditSection(state: state, mask: m)
        }
        .padding(10).glass(radius: 12)
    }

    private func maskSlider(_ title: String, _ m: LayerMask, _ r: ClosedRange<Double>,
                            _ key: WritableKeyPath<LayerMask, Animated<Double>>, _ t: Double) -> some View {
        let a = m[keyPath: key]
        let id: UUID? = m.id
        return HStack(spacing: 8) {
            KeyframeDiamond(filled: a.hasKeyframe(at: t), animated: a.isAnimated) {
                if let id { state.editMask(id, "\(title) Keyframe") { $0[keyPath: key].toggleKeyframe(at: t) } }
            }
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 74, alignment: .leading)
            ValueScrubber(value: a.value(at: t), range: r, step: 1,
                          onChange: { v in if let id { state.editMask(id, title, continuous: true) { $0[keyPath: key].set(v, at: t) } } },
                          onEnd: { state.endEdit() })
        }
    }
}

/// Stroke + Trim Paths controls for shape layers.
struct StrokeSection: View {
    @ObservedObject var state: EditorState
    var contentID: UUID? = nil
    private var layer: Layer? {
        guard var l = state.selectedLayer else { return nil }
        if let id = contentID, let c = l.editableShapeContents.first(where: { $0.id == id })?.component { l.stroke = c.stroke }
        return l
    }

    var body: some View {
        if let l = layer, case .shape = l.content {
            let t = state.currentTime
            VStack(spacing: 6) {
                Toggle("Stroke", isOn: Binding(get: { l.stroke.enabled }, set: { b in edit("Stroke") { $0.stroke.enabled = b } }))
                    .tint(Theme.accent).foregroundStyle(Theme.text)
                if l.stroke.enabled {
                    HStack {
                        KeyframeDiamond(filled: l.stroke.color.hasKeyframe(at: t), animated: l.stroke.color.isAnimated) {
                            edit("Stroke Color Keyframe") { $0.stroke.color.toggleKeyframe(at: t) }
                        }
                    AWIColorWell("Stroke Color", selection: Binding(get: { Color(l.stroke.color.value(at: t)) }, set: { c in
                        if let id = contentID {
                            state.coalescedShapeContent(id, "Stroke Color") { $0.stroke.color.set(c.rgba, at: t) }
                        } else { state.coalescedEdit("Stroke Color") { $0.stroke.color.set(c.rgba, at: t) } }
                    })).foregroundStyle(Theme.text)
                    }
                    row("Width", l.stroke.width, \.stroke.width, 0...200, t)
                    Text("Trim Paths").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    row("Start", l.stroke.trimStart, \.stroke.trimStart, 0...100, t)
                    row("End", l.stroke.trimEnd, \.stroke.trimEnd, 0...100, t)
                    row("Offset", l.stroke.trimOffset, \.stroke.trimOffset, -360...360, t)
                }
            }
        }
    }

    private func edit(_ label: String, _ change: (inout Layer) -> Void) {
        state.beginEdit(label); state.editShapeStyle(contentID, change); state.endEdit()
    }

    /// Diamond + label + scrubber: every stroke / trim value keys at the playhead.
    private func row(_ title: String, _ a: Animated<Double>, _ key: WritableKeyPath<Layer, Animated<Double>>,
                     _ r: ClosedRange<Double>, _ t: Double) -> some View {
        HStack(spacing: 8) {
            KeyframeDiamond(filled: a.hasKeyframe(at: t), animated: a.isAnimated) {
                edit("\(title) Keyframe") { $0[keyPath: key].toggleKeyframe(at: t) }
            }
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 60, alignment: .leading)
            ValueScrubber(value: a.value(at: t), range: r, step: 1,
                          onBegin: { state.beginEdit("Edit Stroke") },
                          onChange: { v in state.editShapeStyle(contentID) { $0[keyPath: key].set(v, at: t) } },
                          onEnd: { state.endEdit() })
        }
    }
}

/// AE shape operators for the selected shape layer, as a stack of cards: each card is one operator, in the order it
/// runs (move it up / down), every value has its keyframe diamond. Repeater always runs last (it copies the result).
struct ShapeOpsSection: View {
    @ObservedObject var state: EditorState
    var contentID: UUID? = nil

    var body: some View {
        if let l = state.selectedLayer, case .shape = l.content {
            let ops = (contentID.flatMap { id in l.editableShapeContents.first(where: { $0.id == id })?.component?.ops } ?? (contentID == nil ? l.shapeOps : nil)) ?? ShapeOps()
            let t = state.currentTime
            let active = ops.activeOrder
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SHAPE OPERATORS").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                    Spacer()
                    Menu {
                        ForEach(ShapeOpKind.allCases.filter { !ops.has($0) }) { k in
                            Button(k.title) { edit("Add \(k.title)") { $0.setEnabled(k, true) } }
                        }
                        if ops.repeater == nil {
                            Button("Repeater") { edit("Add Repeater") { $0.repeater = RepeaterOp() } }
                        }
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(minWidth: 88, minHeight: 44)
                            .foregroundStyle(Theme.accent)
                    }
                }
                if active.isEmpty && ops.repeater == nil {
                    Text("Add an operator to bend, round, twist or repeat this shape.")
                        .font(.caption).foregroundStyle(Theme.textDim)
                }
                ForEach(Array(active.enumerated()), id: \.element) { i, k in
                    card(k, first: i == 0, last: i == active.count - 1) { rows(k, ops, t) }
                }
                if let r = ops.repeater {
                    card(nil, first: true, last: true) { repeaterRows(r, t) }
                }
            }
            .padding(10).glass(radius: 12)
        }
    }

    // MARK: cards

    /// `k == nil` is the Repeater card (fixed at the end of the stack).
    private func card<Content: View>(_ k: ShapeOpKind?, first: Bool, last: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(k?.title ?? "Repeater").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let k {
                    // Order in the stack + remove: three controls on the title row.
                    iconButton("chevron.up", "Move Up") { edit("Reorder Operators") { $0.move(k, by: -1) } }.disabled(first)
                    iconButton("chevron.down", "Move Down") { edit("Reorder Operators") { $0.move(k, by: 1) } }.disabled(last)
                    iconButton("trash", "Remove") { edit("Remove \(k.title)") { $0.setEnabled(k, false) } }
                } else {
                    iconButton("trash", "Remove") { edit("Remove Repeater") { $0.repeater = nil } }
                }
            }
            content()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.6)))
    }

    @ViewBuilder
    private func rows(_ k: ShapeOpKind, _ ops: ShapeOps, _ t: Double) -> some View {
        switch k {
        case .pucker:
            if let a = ops.pucker { row("Amount", a, -100...100, 1, t, set: { o, v in o.pucker?.set(v, at: t) }, key: { $0.pucker?.toggleKeyframe(at: t) }) }
        case .roundCorners:
            if let a = ops.roundCorners { row("Radius", a, 0...500, 1, t, set: { o, v in o.roundCorners?.set(v, at: t) }, key: { $0.roundCorners?.toggleKeyframe(at: t) }) }
        case .offset:
            if let a = ops.offset { row("Amount", a, -300...300, 1, t, set: { o, v in o.offset?.set(v, at: t) }, key: { $0.offset?.toggleKeyframe(at: t) }) }
        case .zigzag:
            if let z = ops.zigzag {
                row("Size", z.size, -200...200, 1, t, set: { o, v in o.zigzag?.size.set(v, at: t) }, key: { $0.zigzag?.size.toggleKeyframe(at: t) })
                row("Ridges", z.ridges, 1...40, 1, t, set: { o, v in o.zigzag?.ridges.set(v, at: t) }, key: { $0.zigzag?.ridges.toggleKeyframe(at: t) })
            }
        case .twist:
            if let tw = ops.twist {
                row("Angle", tw.angle, -720...720, 1, t, set: { o, v in o.twist?.angle.set(v, at: t) }, key: { $0.twist?.angle.toggleKeyframe(at: t) })
                vecRow("Center", tw.center, t, set: { o, v in o.twist?.center.set(v, at: t) }, key: { $0.twist?.center.toggleKeyframe(at: t) })
            }
        case .wiggle:
            if let w = ops.wiggle {
                row("Size", w.size, 0...200, 1, t, set: { o, v in o.wiggle?.size.set(v, at: t) }, key: { $0.wiggle?.size.toggleKeyframe(at: t) })
                row("Detail", w.detail, 0...20, 1, t, set: { o, v in o.wiggle?.detail.set(v, at: t) }, key: { $0.wiggle?.detail.toggleKeyframe(at: t) })
                row("Wiggles/s", w.speed, 0...20, 0.1, t, set: { o, v in o.wiggle?.speed.set(v, at: t) }, key: { $0.wiggle?.speed.toggleKeyframe(at: t) })
            }
        }
    }

    @ViewBuilder
    private func repeaterRows(_ r: RepeaterOp, _ t: Double) -> some View {
        row("Copies", r.copies, 1...50, 1, t, set: { o, v in o.repeater?.copies.set(v, at: t) }, key: { $0.repeater?.copies.toggleKeyframe(at: t) })
        vecRow("Offset", r.position, t, set: { o, v in o.repeater?.position.set(v, at: t) }, key: { $0.repeater?.position.toggleKeyframe(at: t) })
        row("Scale %", Animated(r.scale.value(at: t).x), 0...200, 1, t, keyState: (r.scale.hasKeyframe(at: t), r.scale.isAnimated),
            set: { o, v in o.repeater?.scale.set(Vec2(v, v), at: t) }, key: { $0.repeater?.scale.toggleKeyframe(at: t) })
        row("Rotation", r.rotation, -360...360, 1, t, set: { o, v in o.repeater?.rotation.set(v, at: t) }, key: { $0.repeater?.rotation.toggleKeyframe(at: t) })
        row("Start Opacity", r.startOpacity, 0...100, 1, t, set: { o, v in o.repeater?.startOpacity.set(v, at: t) }, key: { $0.repeater?.startOpacity.toggleKeyframe(at: t) })
        row("End Opacity", r.endOpacity, 0...100, 1, t, set: { o, v in o.repeater?.endOpacity.set(v, at: t) }, key: { $0.repeater?.endOpacity.toggleKeyframe(at: t) })
    }

    // MARK: rows

    private func edit(_ label: String, _ change: (inout ShapeOps) -> Void) {
        state.beginEdit(label)
        apply(change)
        state.endEdit()
    }

    private func apply(_ change: (inout ShapeOps) -> Void) {
        state.mutateLayer { l in
            if let id = contentID {
                var items = l.editableShapeContents
                guard let i = items.firstIndex(where: { $0.id == id }), var c = items[i].component else { return }
                var o = c.ops ?? ShapeOps(); change(&o); c.ops = o.isEmpty ? nil : o
                items[i].component = c; l.shapeContents = items
            } else {
                var o = l.shapeOps ?? ShapeOps(); change(&o); l.shapeOps = o.isEmpty ? nil : o
            }
        }
    }

    /// Diamond + label + scrubber (one undo step per drag / typed value). `keyed` is the property the diamond shows
    /// when the value shown is derived from it (Repeater scale).
    private func row(_ title: String, _ a: Animated<Double>, _ r: ClosedRange<Double>, _ step: Double, _ t: Double,
                     keyState: (filled: Bool, animated: Bool)? = nil,
                     set: @escaping (inout ShapeOps, Double) -> Void,
                     key: @escaping (inout ShapeOps) -> Void) -> some View {
        let filled = keyState?.filled ?? a.hasKeyframe(at: t)
        let animated = keyState?.animated ?? a.isAnimated
        return HStack(spacing: 8) {
            KeyframeDiamond(filled: filled, animated: animated) { edit("\(title) Keyframe", key) }
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).lineLimit(1).fixedSize()
                .frame(width: 92, alignment: .leading)
            ValueScrubber(value: a.value(at: t), range: r, step: step,
                          onBegin: { state.beginEdit(title) },
                          onChange: { v in apply { set(&$0, v) } },
                          onEnd: { state.endEdit() })
        }
    }

    /// X and Y share one diamond (one property), each gets its own scrubber: diamond + X + Y, three per row.
    private func vecRow(_ title: String, _ a: Animated<Vec2>, _ t: Double,
                        set: @escaping (inout ShapeOps, Vec2) -> Void,
                        key: @escaping (inout ShapeOps) -> Void) -> some View {
        let v = a.value(at: t)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                KeyframeDiamond(filled: a.hasKeyframe(at: t), animated: a.isAnimated) { edit("\(title) Keyframe", key) }
                ValueScrubber(value: v.x, range: -1000...1000, step: 1, unit: " X",
                              onBegin: { state.beginEdit(title) },
                              onChange: { x in apply { set(&$0, Vec2(x, v.y)) } },
                              onEnd: { state.endEdit() }, allowBeyond: true)
                ValueScrubber(value: v.y, range: -1000...1000, step: 1, unit: " Y",
                              onBegin: { state.beginEdit(title) },
                              onChange: { y in apply { set(&$0, Vec2(v.x, y)) } },
                              onEnd: { state.endEdit() }, allowBeyond: true)
            }
        }
    }

    private func iconButton(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}
