import SwiftUI
import simd

/// Projects scene points through the 3D view's camera onto the screen.
struct OrbitProjector {
    let camera: CameraState
    let fit: CGRect
    let scale: Double

    init(project: Project, orbit: OrbitCamera, time: Double, fit: CGRect) {
        camera = Renderer.activeCamera(OrbitView.scene(project, orbit: orbit, time: time), time: time)
        self.fit = fit
        scale = Double(fit.width) / Double(max(1, project.width))
    }

    func point(_ w: SIMD3<Double>) -> CGPoint? {
        let c = camera.view * SIMD4(w.x, w.y, w.z, 1)
        guard c.z > 1 else { return nil }
        return CGPoint(x: fit.minX + (camera.zoom * c.x / c.z + camera.center.x) * scale,
                       y: fit.minY + (camera.zoom * c.y / c.z + camera.center.y) * scale)
    }

    func depth(_ w: SIMD3<Double>) -> Double { (camera.view * SIMD4(w.x, w.y, w.z, 1)).z }
}

/// What the on-object handles change.
enum GizmoMode: String, CaseIterable, Identifiable {
    case move, rotate, scale
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotate: return "arrow.triangle.2.circlepath"
        case .scale: return "arrow.up.left.and.arrow.down.right"
        }
    }
}

extension EditorState {
    /// A layer's pivot in the scene (its anchor point, after position, rotation and depth).
    static func scenePivot(_ l: Layer, time: Double) -> SIMD3<Double> {
        let a = l.transform.anchor.value(at: time)
        let p = Renderer.layerWorld(l, time: time) * SIMD4(a.x, a.y, 0, 1)
        return SIMD3(p.x, p.y, p.z)
    }

    /// Tap in the 3D view: picks the front-most layer under the finger (or clears the selection).
    func orbitSelect(at point: CGPoint, fit: CGRect) {
        let t = currentTime
        let view = OrbitView.scene(project, orbit: orbit, time: t)
        let projector = OrbitProjector(project: project, orbit: orbit, time: t, fit: fit)
        var best: (id: UUID, depth: Double)?
        for l in view.layers where l.isVisible && l.isActive(at: t) && project.layers.contains(where: { $0.id == l.id }) {
            if l.isAudioOnly { continue }
            switch l.content { case .camera, .light, .adjustment: continue; default: break }
            let hs = Renderer.layerHalfSize(l, time: t), W = Renderer.layerWorld(l, time: t), a = l.transform.anchor.value(at: t)
            let corners = [(-hs.x, -hs.y), (hs.x, -hs.y), (hs.x, hs.y), (-hs.x, hs.y)].map { c -> SIMD3<Double> in
                let q = W * SIMD4(a.x + c.0, a.y + c.1, 0, 1); return SIMD3(q.x, q.y, q.z)
            }
            let screen = corners.compactMap(projector.point)
            guard screen.count == 4, Self.contains(screen, point) else { continue }
            let d = projector.depth(Self.scenePivot(l, time: t))
            if best == nil || d < best!.depth { best = (l.id, d) }
        }
        selectedLayerID = best?.id
    }

    private static func contains(_ poly: [CGPoint], _ p: CGPoint) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    /// Moves the 3D view's pivot onto the selected layer.
    func frameSelectedInOrbit() {
        guard let l = selectedLayer else { orbit = .home; return }
        let c = Self.scenePivot(l, time: currentTime)
        orbit.pan = Vec2(c.x - Double(project.width) / 2, c.y - Double(project.height) / 2)
    }

    /// Applies a handle drag to the layer as it was when the drag started. Keyframed properties get a key at the playhead.
    func applyGizmo(_ mode: GizmoMode, axis: Int, amount: Double, from start: Layer) {
        let t = currentTime
        mutateLayer { l in
            switch mode {
            case .move:
                if axis == 2 {
                    l.transform.positionZ.set(start.transform.positionZ.value(at: t) + amount, at: t)
                } else {
                    var p = start.transform.position.value(at: t)
                    if axis == 0 { p.x += amount } else { p.y += amount }
                    l.transform.position.set(p, at: t)
                }
            case .rotate:
                switch axis {
                case 0: l.transform.rotationX.set(start.transform.rotationX.value(at: t) + amount, at: t)
                case 1: l.transform.rotationY.set(start.transform.rotationY.value(at: t) + amount, at: t)
                default: l.transform.rotation.set(start.transform.rotation.value(at: t) + amount, at: t)
                }
            case .scale:
                let s = start.transform.scale.value(at: t), k = max(0.01, 1 + amount)
                l.transform.scale.set(Vec2(s.x * k, s.y * k), at: t)
            }
            // Moving something in depth only shows if the layer lives in 3D.
            if mode != .scale, axis == 2 || mode == .rotate { l.is3D = true }
        }
    }
}

/// Move / rotate / scale handles on the selected layer in the 3D view, like Blender's gizmo.
struct OrbitGizmo: View {
    @ObservedObject var state: EditorState
    let project: Project
    let time: Double
    let fit: CGRect
    @Binding var mode: GizmoMode
    @State private var start: Layer?

    private let colors: [Color] = [Color(red: 1, green: 0.32, blue: 0.36), Color(red: 0.42, green: 0.9, blue: 0.4), Color(red: 0.35, green: 0.6, blue: 1)]

    var body: some View {
        if let l = project.layers.first(where: { $0.id == state.selectedLayerID }), !l.isAudioOnly {
            let projector = OrbitProjector(project: project, orbit: state.orbit, time: time, fit: fit)
            let pivot = EditorState.scenePivot(l, time: time)
            if let origin = projector.point(pivot) {
                // Handles stay the same size on screen at any distance.
                let reach = handleReach(projector, pivot)
                ZStack {
                    motionPath(l, projector)
                    ForEach(0..<3, id: \.self) { axis in
                        let dir = axisVector(axis)
                        if let tip = projector.point(pivot + dir * reach) {
                            Path { p in p.move(to: origin); p.addLine(to: tip) }
                                .stroke(colors[axis], lineWidth: 3).allowsHitTesting(false)
                            handle(axis: axis, at: tip, origin: origin, layer: l)
                        }
                    }
                    Circle().fill(.white).frame(width: 12, height: 12).position(origin).allowsHitTesting(false)
                }
            }
        }
    }

    /// Where the layer travels over its clip, through depth too, with a dot at each position keyframe.
    @ViewBuilder private func motionPath(_ l: Layer, _ projector: OrbitProjector) -> some View {
        let t = l.transform
        if t.position.isAnimated || t.positionZ.isAnimated {
            let span = max(1e-3, l.outPoint - l.inPoint)
            let points = (0...120).compactMap { k -> CGPoint? in
                projector.point(EditorState.scenePivot(l, time: l.inPoint + span * Double(k) / 120))
            }
            let keys = Set(t.position.keyframeTimes + t.positionZ.keyframeTimes).sorted().compactMap { k in
                projector.point(EditorState.scenePivot(l, time: k))
            }
            Path { p in if let f = points.first { p.move(to: f); points.dropFirst().forEach { p.addLine(to: $0) } } }
                .stroke(Theme.accentGlow.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [5, 4])).allowsHitTesting(false)
            ForEach(keys.indices, id: \.self) { i in
                Rectangle().fill(Theme.keyframe).frame(width: 9, height: 9).rotationEffect(.degrees(45)).position(keys[i]).allowsHitTesting(false)
            }
        }
    }

    private func axisVector(_ axis: Int) -> SIMD3<Double> {
        // Scene axes: x right, y down, z away. The Y handle points up, the way people expect "up".
        [SIMD3(1.0, 0, 0), SIMD3(0.0, -1, 0), SIMD3(0.0, 0, 1)][axis]
    }

    private func handleReach(_ projector: OrbitProjector, _ pivot: SIMD3<Double>) -> Double {
        guard let o = projector.point(pivot), let x = projector.point(pivot + SIMD3(100, 0, 0)) else { return 100 }
        let px = max(1, hypot(x.x - o.x, x.y - o.y))
        return 100 * 70 / Double(px)
    }

    @ViewBuilder private func handle(axis: Int, at tip: CGPoint, origin: CGPoint, layer: Layer) -> some View {
        ZStack {
            Circle().fill(colors[axis]).frame(width: 22, height: 22)
            Image(systemName: mode.symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
        }
        .frame(width: 44, height: 44).contentShape(Circle())
        .position(tip)
        .accessibilityLabel("\(["X", "Y", "Z"][axis]) \(mode.rawValue) handle")
        .highPriorityGesture(DragGesture(minimumDistance: 1)
            .onChanged { v in
                if start == nil { start = layer; state.orbitHandleDrag = true; state.pause(); state.beginEdit("\(mode.rawValue.capitalized) in 3D") }
                guard let s = start else { return }
                let screenAxis = CGVector(dx: tip.x - origin.x, dy: tip.y - origin.y)
                let length = max(1, hypot(screenAxis.dx, screenAxis.dy))
                // How far the finger travelled along the handle's direction on screen.
                let along = Double((v.translation.width * screenAxis.dx + v.translation.height * screenAxis.dy) / length)
                switch mode {
                case .move:
                    let projector = OrbitProjector(project: project, orbit: state.orbit, time: time, fit: fit)
                    let pivot = EditorState.scenePivot(s, time: time)
                    let reach = handleReach(projector, pivot)
                    let sign = axis == 1 ? -1.0 : 1.0
                    state.applyGizmo(.move, axis: axis, amount: sign * along / Double(length) * reach, from: s)
                case .rotate:
                    // Sideways drag across the handle turns around that axis.
                    let across = Double((v.translation.width * -screenAxis.dy + v.translation.height * screenAxis.dx) / length)
                    state.applyGizmo(.rotate, axis: axis, amount: across * 0.6, from: s)
                case .scale:
                    state.applyGizmo(.scale, axis: axis, amount: along / 150, from: s)
                }
            }
            .onEnded { _ in start = nil; state.orbitHandleDrag = false; state.endEdit() })
    }
}

/// View presets and handle mode for the 3D view.
struct OrbitToolbar: View {
    @ObservedObject var state: EditorState
    @Binding var mode: GizmoMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GizmoMode.allCases) { m in
                Button { mode = m } label: {
                    Image(systemName: m.symbol).font(.system(size: 13, weight: .bold)).frame(width: 34, height: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(mode == m ? Theme.accent : Theme.raised))
                        .foregroundStyle(mode == m ? Color.white : Theme.text)
                }
                .accessibilityLabel(m.rawValue.capitalized)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Front") { withAnimation { state.orbit.yaw = 0; state.orbit.pitch = 0 } }
                Button("Side") { withAnimation { state.orbit.yaw = -90; state.orbit.pitch = 0 } }
                Button("Top") { withAnimation { state.orbit.yaw = 0; state.orbit.pitch = -89 } }
                Button("Three-Quarter") { withAnimation { state.orbit.yaw = -35; state.orbit.pitch = -22 } }
                Divider()
                Button("Frame Selected") { withAnimation { state.frameSelectedInOrbit() } }
                Button("Reset View") { withAnimation { state.orbit = .home } }
            } label: {
                Label("View", systemImage: "eye").font(.system(size: 12, weight: .bold)).padding(.horizontal, 10).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised)).foregroundStyle(Theme.text)
            }
            .accessibilityLabel("3D View Presets")
        }
        .padding(8)
    }
}
