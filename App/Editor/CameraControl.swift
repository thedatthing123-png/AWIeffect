import SwiftUI
import simd

/// Moving the camera with your fingers on the canvas (Camera view). A move saves a keyframe only when the camera
/// already has keyframes on that property; otherwise it just moves the camera.
extension EditorState {
    /// The camera the shot uses right now (top-most active camera layer).
    var activeCameraLayer: Layer? { canvasProject.layers.first { $0.content == .camera && $0.isActive(at: currentTime) } }

    static func cameraIs3D(_ l: Layer) -> Bool { !(l.camera?.affects2D ?? false) }

    struct CameraDragStart {
        let id: UUID
        let position: Vec2
        let z: Double
        let rx: Double, ry: Double, rz: Double
        let scale: Vec2
    }

    func beginCameraGesture() -> CameraDragStart? {
        guard let cam = activeCameraLayer else { return nil }
        pause()
        beginEdit("Move Camera")
        if !isLiveGesture { beginLiveGesture() }
        let t = currentTime, tr = cam.transform
        return CameraDragStart(id: cam.id, position: tr.position.value(at: t), z: tr.positionZ.value(at: t),
                               rx: tr.rotationX.value(at: t), ry: tr.rotationY.value(at: t), rz: tr.rotation.value(at: t),
                               scale: tr.scale.value(at: t))
    }

    private func mutateCamera(_ id: UUID, _ change: (inout Layer) -> Void) {
        guard var lp = live.project, let i = lp.layers.firstIndex(where: { $0.id == id }) else { return }
        change(&lp.layers[i])
        lp.modifiedAt = Date()
        live.project = lp
    }

    /// One finger: 2D = the scene follows the finger; 3D = orbit around the point the camera looks at.
    func updateCameraDrag(_ s: CameraDragStart, delta d: Vec2) {
        let t = currentTime
        guard let cam = live.project?.layers.first(where: { $0.id == s.id }) else { return }
        if Self.cameraIs3D(cam) {
            let zoom = cam.camera?.zoom.value(at: t) ?? CameraState.defaultZoom(project)
            let ry = s.ry + d.x * 0.25, rx = max(-89, min(89, s.rx - d.y * 0.25))
            // Orbit: keep the point `zoom` in front of the camera fixed.
            let f0 = CameraState.rotation(x: s.rx, y: s.ry, z: s.rz) * SIMD4(0, 0, 1, 0)
            let poi = SIMD3(s.position.x, s.position.y, s.z) + SIMD3(f0.x, f0.y, f0.z) * zoom
            let f1 = CameraState.rotation(x: rx, y: ry, z: s.rz) * SIMD4(0, 0, 1, 0)
            let p = poi - SIMD3(f1.x, f1.y, f1.z) * zoom
            mutateCamera(s.id) { l in
                l.transform.rotationX.set((rx * 10).rounded() / 10, at: t)
                l.transform.rotationY.set((ry * 10).rounded() / 10, at: t)
                l.transform.position.set(Vec2((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10), at: t)
                l.transform.positionZ.set((p.z * 10).rounded() / 10, at: t)
            }
        } else {
            // view2D = scale · rotate(-r) · (world − pos): moving the scene by d means pos −= (S·R)⁻¹ d.
            let r = s.rz * .pi / 180
            let sx = max(abs(s.scale.x), 0.01) / 100, sy = max(abs(s.scale.y), 0.01) / 100
            let ux = d.x / sx, uy = d.y / sy
            let wx = ux * cos(r) - uy * sin(r), wy = ux * sin(r) + uy * cos(r)
            let p = Vec2(s.position.x - wx, s.position.y - wy)
            mutateCamera(s.id) { l in l.transform.position.set(Vec2((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10), at: t) }
        }
    }

    /// Two fingers: pinch = zoom (2D scale / 3D dolly), twist = roll.
    func updateCameraPinch(_ s: CameraDragStart, scale k: Double, rotation deg: Double) {
        let t = currentTime
        guard let cam = live.project?.layers.first(where: { $0.id == s.id }), k.isFinite, deg.isFinite else { return }
        if Self.cameraIs3D(cam) {
            let zoom = cam.camera?.zoom.value(at: t) ?? CameraState.defaultZoom(project)
            let f = CameraState.rotation(x: s.rx, y: s.ry, z: s.rz) * SIMD4(0, 0, 1, 0)
            let move = zoom * (1 - 1 / max(k, 0.05))
            let p = SIMD3(s.position.x, s.position.y, s.z) + SIMD3(f.x, f.y, f.z) * move
            mutateCamera(s.id) { l in
                l.transform.position.set(Vec2((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10), at: t)
                l.transform.positionZ.set((p.z * 10).rounded() / 10, at: t)
                l.transform.rotation.set(((s.rz - deg) * 10).rounded() / 10, at: t)
            }
        } else {
            let kk = max(0.05, k)
            mutateCamera(s.id) { l in
                l.transform.scale.set(Vec2((s.scale.x * kk * 10).rounded() / 10, (s.scale.y * kk * 10).rounded() / 10), at: t)
                l.transform.rotation.set(((s.rz - deg) * 10).rounded() / 10, at: t)
            }
        }
    }

    func endCameraGesture() {
        endLiveGesture()
        endEdit()
    }

    /// The project as the free view shows it: no camera (you look at the scene itself).
    func freeViewProject(_ p: Project) -> Project {
        guard p.layers.contains(where: { $0.content == .camera }) else { return p }
        var q = p
        for i in q.layers.indices where q.layers[i].content == .camera { q.layers[i].isVisible = false }
        return q
    }
}

/// In free view: where the active camera looks, drawn as a white frame with an X.
struct CameraFrameOverlay: View {
    let project: Project
    let time: Double
    let fit: CGRect

    var body: some View {
        Canvas { ctx, _ in
            guard let cam = project.layers.first(where: { $0.content == .camera && $0.isActive(at: time) }) else { return }
            let w = Double(project.width), h = Double(project.height)
            let s = Double(fit.width) / max(w, 1)
            var pts: [CGPoint] = []
            if EditorState.cameraIs3D(cam) {
                // Where the camera's view hits the z = 0 plane (the plane the free view shows at 100%).
                let st = Renderer.activeCamera(project, time: time)
                let camPos = st.world * SIMD4(0, 0, 0, 1)
                for c in [(0.0, 0.0), (w, 0.0), (w, h), (0.0, h)] {
                    let dir = st.world * SIMD4((c.0 - st.center.x) / st.zoom, (c.1 - st.center.y) / st.zoom, 1, 0)
                    guard abs(dir.z) > 1e-6 else { return }
                    let k = -camPos.z / dir.z
                    guard k > 0 else { return }
                    let x = camPos.x + dir.x * k, y = camPos.y + dir.y * k
                    pts.append(CGPoint(x: fit.minX + CGFloat(x * s), y: fit.minY + CGFloat(y * s)))
                }
            } else {
                let v = Renderer.view2D(cam, project: project, time: time)
                let inv = v.inverse
                for c in [(0.0, 0.0), (w, 0.0), (w, h), (0.0, h)] {
                    let q = inv * SIMD3(c.0, c.1, 1)
                    pts.append(CGPoint(x: fit.minX + CGFloat(q.x / q.z * s), y: fit.minY + CGFloat(q.y / q.z * s)))
                }
            }
            guard pts.count == 4, pts.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return }
            var frame = Path(); frame.addLines(pts); frame.closeSubpath()
            var cross = Path()
            cross.move(to: pts[0]); cross.addLine(to: pts[2])
            cross.move(to: pts[1]); cross.addLine(to: pts[3])
            ctx.stroke(cross, with: .color(.white.opacity(0.35)), lineWidth: 1)
            ctx.stroke(frame, with: .color(.white), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}

/// Rule-of-thirds grid over the comp.
struct CompGrid: View {
    let fit: CGRect
    var body: some View {
        Canvas { ctx, _ in
            var p = Path()
            for k in 1...2 {
                let x = fit.minX + fit.width * CGFloat(k) / 3, y = fit.minY + fit.height * CGFloat(k) / 3
                p.move(to: CGPoint(x: x, y: fit.minY)); p.addLine(to: CGPoint(x: x, y: fit.maxY))
                p.move(to: CGPoint(x: fit.minX, y: y)); p.addLine(to: CGPoint(x: fit.maxX, y: y))
            }
            ctx.stroke(p, with: .color(.white.opacity(0.28)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Canvas side rail (Alight Motion-style): camera view switch, grid, and the view zoom.
struct CanvasRail: View {
    @ObservedObject var state: EditorState
    @Binding var viewZoom: CGFloat
    @Binding var zoomBase: CGFloat
    @Binding var viewPan: CGSize

    var body: some View {
        VStack(spacing: 10) {
            if state.project.layers.contains(where: { $0.content == .camera }) {
                railButton(state.cameraView ? "video.fill" : "video.slash.fill", tint: state.cameraView ? Theme.ok : Theme.text,
                           label: state.cameraView ? "Camera view (tap for free view)" : "Free view (tap for camera view)") {
                    state.cameraView.toggle()
                }
            }
            railButton("grid", tint: state.showGrid ? Theme.accentGlow : Theme.text, label: "Grid") { state.showGrid.toggle() }
            VStack(spacing: 2) {
                Button { setZoom(viewZoom * 1.25) } label: { Image(systemName: "plus").frame(width: 34, height: 26) }
                    .accessibilityLabel("Zoom in")
                Button { setZoom(1); viewPan = .zero } label: {
                    Text("\(Int((viewZoom * 100).rounded()))%").font(.system(size: 10, weight: .bold, design: .monospaced)).frame(width: 40, height: 18)
                }
                .accessibilityLabel("Reset zoom")
                Button { setZoom(viewZoom / 1.25) } label: { Image(systemName: "minus").frame(width: 34, height: 26) }
                    .accessibilityLabel("Zoom out")
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.text)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised.opacity(0.92)))
        }
        .padding(6)
    }

    private func setZoom(_ z: CGFloat) {
        withAnimation(.easeOut(duration: 0.18)) { viewZoom = min(8, max(0.25, z)); zoomBase = viewZoom }
    }

    private func railButton(_ icon: String, tint: Color, label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 36)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised.opacity(0.92)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension EditorState {
    /// Two fingers dragged together on a 3D camera: slide it sideways / up-down (the scene follows the fingers).
    func updateCameraPan(_ s: CameraDragStart, delta d: Vec2) {
        let t = currentTime
        let R = CameraState.rotation(x: s.rx, y: s.ry, z: s.rz)
        let r = R * SIMD4(1, 0, 0, 0), u = R * SIMD4(0, 1, 0, 0)
        let p = SIMD3(s.position.x, s.position.y, s.z) - SIMD3(r.x, r.y, r.z) * d.x - SIMD3(u.x, u.y, u.z) * d.y
        guard var lp = live.project, let i = lp.layers.firstIndex(where: { $0.id == s.id }) else { return }
        lp.layers[i].transform.position.set(Vec2((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10), at: t)
        lp.layers[i].transform.positionZ.set((p.z * 10).rounded() / 10, at: t)
        lp.modifiedAt = Date()
        live.project = lp
    }
}

/// Two-finger pan (UIKit, works alongside SwiftUI's pinch / twist). Watches touches inside its own frame.
struct TwoFingerPan: UIViewRepresentable {
    var onBegan: () -> Void
    var onChanged: (CGSize) -> Void
    var onEnded: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WatchView {
        let v = WatchView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        v.coordinator = context.coordinator
        return v
    }

    func updateUIView(_ v: WatchView, context: Context) {
        context.coordinator.onBegan = onBegan
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    final class WatchView: UIView {
        weak var coordinator: Coordinator?
        private var recognizer: UIPanGestureRecognizer?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let r = recognizer { r.view?.removeGestureRecognizer(r); recognizer = nil }
            guard let w = window, let c = coordinator else { return }
            let g = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handle(_:)))
            g.minimumNumberOfTouches = 2
            g.maximumNumberOfTouches = 2
            g.cancelsTouchesInView = false
            g.delegate = c
            c.area = self
            w.addGestureRecognizer(g)
            recognizer = g
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onBegan: () -> Void = {}
        var onChanged: (CGSize) -> Void = { _ in }
        var onEnded: () -> Void = {}
        weak var area: UIView?
        private var active = false

        @objc func handle(_ g: UIPanGestureRecognizer) {
            guard let area else { return }
            switch g.state {
            case .began:
                active = area.bounds.contains(g.location(in: area))
                if active { onBegan() }
            case .changed:
                if active { let t = g.translation(in: area); onChanged(CGSize(width: t.x, height: t.y)) }
            default:
                if active { onEnded() }
                active = false
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
