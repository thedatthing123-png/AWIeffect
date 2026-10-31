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

/// Canvas overlay for drawing bezier paths: tap = corner, drag = smooth point, tap first point = close.
struct PenOverlay: View {
    @ObservedObject var state: EditorState
    let target: PenTarget
    let style: PenStyle
    let fit: CGRect
    let done: () -> Void
    @State private var vertices: [PathVertex] = []
    @State private var dragStart: CGPoint?
    @State private var freehand: [Vec2] = []

    private var scale: Double { Double(fit.width) / Double(state.project.width) }
    private func comp(_ p: CGPoint) -> Vec2 { Vec2(Double(p.x - fit.minX) / scale, Double(p.y - fit.minY) / scale) }
    private func view(_ v: Vec2) -> CGPoint { CGPoint(x: fit.minX + v.x * scale, y: fit.minY + v.y * scale) }

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
                }
            }
            .stroke(Theme.accentGlow, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .allowsHitTesting(false)
            ForEach(Array(vertices.enumerated()), id: \.offset) { i, v in
                Circle().fill(i == 0 ? Theme.accent : .white).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
                    .position(view(v.point)).allowsHitTesting(false)
                if v.outTangent != .zero {
                    Path { p in p.move(to: view(v.point + v.inTangent)); p.addLine(to: view(v.point + v.outTangent)) }
                        .stroke(Theme.textDim, lineWidth: 1).allowsHitTesting(false)
                }
            }
            HStack(spacing: 10) {
                Text(style == .freehand ? "Draw with your finger" : "Tap = corner · drag = curve · tap first point = close")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(.black.opacity(0.6)))
                Button("Cancel") { done() }.buttonStyle(.bordered).tint(Theme.danger)
                Button("Done") { finish(closed: target != .newShape ? true : false) }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .disabled(style == .points ? vertices.count < 2 : freehand.count < 3)
            }
            .padding(.top, 6)
        }
    }

    private var pointsGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if dragStart == nil {
                    dragStart = v.startLocation
                    let p = comp(v.startLocation)
                    // Close when tapping the first point.
                    if vertices.count >= 3, let f = vertices.first, hypot(view(f.point).x - v.startLocation.x, view(f.point).y - v.startLocation.y) < 22 {
                        finish(closed: true)
                        return
                    }
                    vertices.append(PathVertex(point: p))
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                guard !vertices.isEmpty else { return }
                let d = comp(v.location) - comp(v.startLocation)
                if hypot(d.x, d.y) > 3 {
                    vertices[vertices.count - 1].outTangent = d
                    vertices[vertices.count - 1].inTangent = d * -1
                }
            }
            .onEnded { _ in dragStart = nil }
    }

    private var freehandGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in freehand.append(comp(v.location)) }
            .onEnded { _ in }
    }

    private func finish(closed: Bool) {
        let path: BezierPath
        if style == .freehand {
            guard freehand.count >= 3 else { done(); return }
            let first = freehand.first!, last = freehand.last!
            let autoClose = target != .newShape || hypot(first.x - last.x, first.y - last.y) < 30 / scale
            path = BezierPath.smoothed(freehand, closed: autoClose, tolerance: 4 / scale)
        } else {
            guard vertices.count >= 2 else { done(); return }
            path = BezierPath(vertices: vertices, closed: closed)
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
                    ColorPicker("Stroke Color", selection: Binding(get: { Color(l.stroke.color.value(at: t)) }, set: { c in
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
