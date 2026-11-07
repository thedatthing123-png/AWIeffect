import SwiftUI
import simd

/// What a pen session creates.
enum PenTarget: Equatable {
    case newShape
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
        let M = Renderer.layerMatrix(project.layers[i], time: currentTime, renderScale: 1, includeEffects: false)
        let inv = M.inverse
        // Points transform as positions, tangents as directions.
        func toLocal(_ v: Vec2) -> Vec2 { let q = inv * SIMD3(v.x, v.y, 1); return Vec2(q.x, q.y) }
        func dirLocal(_ v: Vec2) -> Vec2 { let q = inv * SIMD3(v.x, v.y, 0); return Vec2(q.x, q.y) }
        var local = compPath
        for k in local.vertices.indices {
            local.vertices[k].point = toLocal(local.vertices[k].point)
            local.vertices[k].inTangent = dirLocal(local.vertices[k].inTangent)
            local.vertices[k].outTangent = dirLocal(local.vertices[k].outTangent)
        }
        local.closed = true
        mutate("Add Mask") { p in
            p.layers[i].masks.append(LayerMask(name: "Mask \(p.layers[i].masks.count + 1)", path: Animated(local)))
        }
        selectedLayerID = id
        panel = .masks
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
struct PenOverlay: View {
    @ObservedObject var state: EditorState
    let target: PenTarget
    let style: PenStyle
    let fit: CGRect
    let done: () -> Void
    @State private var vertices: [PathVertex] = []
    @State private var closed = false
    @State private var selected: Int?
    @State private var cursor: Vec2?
    @State private var curveMode = false
    @State private var dragStart: CGPoint?
    @State private var dragVertex: Int?
    @State private var dragVertexStart: Vec2?
    @State private var freehand: [Vec2] = []

    private var scale: Double { Double(fit.width) / Double(state.project.width) }
    private func comp(_ p: CGPoint) -> Vec2 { Vec2(Double(p.x - fit.minX) / scale, Double(p.y - fit.minY) / scale) }
    private func view(_ v: Vec2) -> CGPoint { CGPoint(x: fit.minX + v.x * scale, y: fit.minY + v.y * scale) }
    private var cursorPoint: Vec2 { cursor ?? Vec2(Double(state.project.width) / 2, Double(state.project.height) / 2) }

    var body: some View {
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
                        Path { p in p.move(to: view(v.point + v.inTangent)); p.addLine(to: view(v.point + v.outTangent)) }
                            .stroke(i == selected ? Theme.accentGlow : Theme.textDim, lineWidth: 1).allowsHitTesting(false)
                        Circle().fill(Theme.textDim).frame(width: 6, height: 6).position(view(v.point + v.outTangent)).allowsHitTesting(false)
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
            topBar
            if style == .points {
                VStack { Spacer(); controls }
            }
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
        if let s = selected { return curveMode ? "Swipe: shape point \(s + 1)'s curve" : "Swipe: move point \(s + 1)" }
        return "Swipe to aim · Add Point · tap a point to edit it"
    }

    /// Swipe pad + point buttons along the bottom of the canvas.
    private var controls: some View {
        VStack(spacing: 6) {
            SwipePad(hint: selected == nil ? "Swipe to move the cursor" : (curveMode ? "Swipe to bend the curve" : "Swipe to move the point"),
                     gain: Double(state.project.width) * 0.8) { d in padMoved(Vec2(Double(d.width), Double(d.height))) }
                .frame(height: 70)
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
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(RoundedRectangle(cornerRadius: 10).fill(on ? Theme.accent : Theme.surface))
            .foregroundStyle(on ? Color.white : Theme.text)
        }
        .buttonStyle(.plain)
    }

    private func padMoved(_ d: Vec2) {
        if let s = selected, vertices.indices.contains(s) {
            if curveMode {
                // Pull the handle out from the point; both sides stay mirrored (smooth point).
                let t = vertices[s].outTangent + d
                vertices[s].outTangent = t
                vertices[s].inTangent = t * -1
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
                    if let hit = vertexHit(v.startLocation) {
                        dragVertex = hit; dragVertexStart = vertices[hit].point
                        selected = hit
                        UISelectionFeedbackGenerator().selectionChanged()
                        return
                    }
                    selected = nil; curveMode = false
                    addPoint(at: comp(v.startLocation))
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
            .onEnded { _ in dragStart = nil; dragVertex = nil; dragVertexStart = nil }
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
            let autoClose = target != .newShape || hypot(first.x - last.x, first.y - last.y) < 30 / scale
            path = BezierPath.smoothed(freehand, closed: autoClose, tolerance: 4 / scale)
        } else {
            guard vertices.count >= 2 else { done(); return }
            // Masks are always closed; shapes close only when you chose Close.
            path = BezierPath(vertices: vertices, closed: target != .newShape ? true : closed)
        }
        switch target {
        case .newShape: state.addPathLayer(path)
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
            maskSlider("Feather", m.feather.value(at: t), 0...400) { v in state.editMask(m.id, "Feather", continuous: true) { $0.feather.set(v, at: t) } }
            maskSlider("Opacity", m.opacity.value(at: t), 0...100) { v in state.editMask(m.id, "Mask Opacity", continuous: true) { $0.opacity.set(v, at: t) } }
            maskSlider("Expansion", m.expansion.value(at: t), -300...300) { v in state.editMask(m.id, "Expansion", continuous: true) { $0.expansion.set(v, at: t) } }
            HStack {
                KeyframeDiamond(filled: m.path.hasKeyframe(at: t), animated: m.path.isAnimated) {
                    state.editMask(m.id, "Mask Path Keyframe") { $0.path.toggleKeyframe(at: t) }
                }
                Text("Mask Path").font(.system(size: 12)).foregroundStyle(Theme.text)
                Spacer()
            }
        }
        .padding(10).glass(radius: 12)
    }

    private func maskSlider(_ title: String, _ v: Double, _ r: ClosedRange<Double>, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 74, alignment: .leading)
            ValueScrubber(value: v, range: r, step: 1, onChange: set, onEnd: { state.endEdit() })
        }
    }
}

/// Stroke + Trim Paths controls for shape layers.
struct StrokeSection: View {
    @ObservedObject var state: EditorState

    var body: some View {
        if let l = state.selectedLayer, case .shape(let k) = l.content, k == .path || k == .rectangle || k == .ellipse {
            let t = state.currentTime
            VStack(spacing: 6) {
                Toggle("Stroke", isOn: Binding(get: { l.stroke.enabled }, set: { b in edit("Stroke") { $0.stroke.enabled = b } }))
                    .tint(Theme.accent).foregroundStyle(Theme.text)
                if l.stroke.enabled {
                    AWIColorWell("Stroke Color", selection: Binding(get: { Color(l.stroke.color.value(at: t)) }, set: { c in
                        edit("Stroke Color") { $0.stroke.color.set(c.rgba, at: t) }
                    })).foregroundStyle(Theme.text)
                    row("Width", l.stroke.width.value(at: t), 0...200) { v in cont { $0.stroke.width.set(v, at: t) } }
                    Text("Trim Paths").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    row("Start", l.stroke.trimStart.value(at: t), 0...100) { v in cont { $0.stroke.trimStart.set(v, at: t) } }
                    row("End", l.stroke.trimEnd.value(at: t), 0...100) { v in cont { $0.stroke.trimEnd.set(v, at: t) } }
                    row("Offset", l.stroke.trimOffset.value(at: t), -360...360) { v in cont { $0.stroke.trimOffset.set(v, at: t) } }
                    HStack {
                        Button("Keyframe Trim End") {
                            edit("Trim Keyframe") { $0.stroke.trimEnd.toggleKeyframe(at: t) }
                        }
                        .font(.system(size: 12, weight: .semibold)).tint(Theme.accent)
                        Spacer()
                    }
                }
            }
        }
    }

    private func edit(_ label: String, _ change: (inout Layer) -> Void) {
        state.beginEdit(label); state.mutateLayer(change); state.endEdit()
    }

    private func cont(_ change: (inout Layer) -> Void) { state.beginEdit("Edit Stroke"); state.mutateLayer(change) }

    private func row(_ title: String, _ v: Double, _ r: ClosedRange<Double>, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 60, alignment: .leading)
            ValueScrubber(value: v, range: r, step: 1, onChange: set, onEnd: { state.endEdit() })
        }
    }
}

/// AE shape operators for the selected shape layer: Repeater, Offset Paths, Wiggle Paths, Zig Zag, Pucker & Bloat.
struct ShapeOpsSection: View {
    @ObservedObject var state: EditorState

    var body: some View {
        if let l = state.selectedLayer, case .shape = l.content {
            let ops = l.shapeOps ?? ShapeOps()
            let t = state.currentTime
            VStack(alignment: .leading, spacing: 6) {
                Text("SHAPE OPERATORS").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                toggle("Repeater", ops.repeater != nil) { on in edit { $0.repeater = on ? RepeaterOp() : nil } }
                if let r = ops.repeater {
                    row("Copies", r.copies.value(at: t), 1...50, 1) { v in edit { $0.repeater?.copies.set(v, at: t) } }
                    row("Offset X", r.position.value(at: t).x, -1000...1000, 1) { v in edit { $0.repeater?.position.set(Vec2(v, r.position.value(at: t).y), at: t) } }
                    row("Offset Y", r.position.value(at: t).y, -1000...1000, 1) { v in edit { $0.repeater?.position.set(Vec2(r.position.value(at: t).x, v), at: t) } }
                    row("Scale %", r.scale.value(at: t).x, 0...200, 1) { v in edit { $0.repeater?.scale.set(Vec2(v, v), at: t) } }
                    row("Rotation", r.rotation.value(at: t), -360...360, 1) { v in edit { $0.repeater?.rotation.set(v, at: t) } }
                    row("Start Opacity", r.startOpacity.value(at: t), 0...100, 1) { v in edit { $0.repeater?.startOpacity.set(v, at: t) } }
                    row("End Opacity", r.endOpacity.value(at: t), 0...100, 1) { v in edit { $0.repeater?.endOpacity.set(v, at: t) } }
                }
                toggle("Offset Paths", ops.offset != nil) { on in edit { $0.offset = on ? Animated(10) : nil } }
                if let o = ops.offset { row("Amount", o.value(at: t), -300...300, 1) { v in edit { $0.offset?.set(v, at: t) } } }
                toggle("Wiggle Paths", ops.wiggle != nil) { on in edit { $0.wiggle = on ? WiggleOp() : nil } }
                if let w = ops.wiggle {
                    row("Size", w.size.value(at: t), 0...200, 1) { v in edit { $0.wiggle?.size.set(v, at: t) } }
                    row("Detail", w.detail.value(at: t), 0...20, 1) { v in edit { $0.wiggle?.detail.set(v, at: t) } }
                    row("Wiggles/s", w.speed.value(at: t), 0...20, 0.1) { v in edit { $0.wiggle?.speed.set(v, at: t) } }
                }
                toggle("Zig Zag", ops.zigzag != nil) { on in edit { $0.zigzag = on ? ZigZagOp() : nil } }
                if let z = ops.zigzag {
                    row("Size", z.size.value(at: t), -200...200, 1) { v in edit { $0.zigzag?.size.set(v, at: t) } }
                    row("Ridges", z.ridges.value(at: t), 1...40, 1) { v in edit { $0.zigzag?.ridges.set(v, at: t) } }
                }
                toggle("Pucker & Bloat", ops.pucker != nil) { on in edit { $0.pucker = on ? Animated(30) : nil } }
                if let pk = ops.pucker { row("Amount", pk.value(at: t), -100...100, 1) { v in edit { $0.pucker?.set(v, at: t) } } }
            }
            .padding(10).glass(radius: 12)
        }
    }

    private func edit(_ change: (inout ShapeOps) -> Void) {
        state.coalescedEdit("Shape Operator") { l in
            var o = l.shapeOps ?? ShapeOps()
            change(&o)
            l.shapeOps = o.isEmpty ? nil : o
        }
    }

    private func toggle(_ title: String, _ on: Bool, _ set: @escaping (Bool) -> Void) -> some View {
        Toggle(title, isOn: Binding(get: { on }, set: set)).tint(Theme.accent).foregroundStyle(Theme.text).font(.system(size: 13, weight: .semibold))
    }

    private func row(_ title: String, _ v: Double, _ r: ClosedRange<Double>, _ step: Double, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 90, alignment: .leading)
            ValueScrubber(value: v, range: r, step: step, onChange: set)
        }
    }
}
