import SwiftUI
import simd

/// Editor viewport mode: the normal comp view, or a free 3D orbit view of the whole scene (like Blender's viewport).
enum ViewMode: String { case comp, orbit }

/// Orbit "editor camera" around the comp center. `distance` is in multiples of the comp's default camera distance.
struct OrbitCamera: Equatable {
    var yaw = -35.0
    var pitch = -22.0
    var distance = 1.6
    var pan = Vec2.zero

    static let home = OrbitCamera()
}

/// Re-reads a value on every playback tick without invalidating the rest of the editor.
struct ClockReader<Content: View>: View {
    @ObservedObject var clock: PlayClock
    @ViewBuilder let content: (Double) -> Content
    var body: some View { content(clock.time) }
}

enum OrbitView {
    /// Camera world position + rotation for the orbit.
    static func eye(_ p: Project, orbit o: OrbitCamera) -> (pos: SIMD3<Double>, rx: Double, ry: Double) {
        let d = CameraState.defaultZoom(p) * o.distance
        let target = SIMD3(Double(p.width) / 2 + o.pan.x, Double(p.height) / 2 + o.pan.y, 0)
        let R = CameraState.rotation(x: o.pitch, y: o.yaw, z: 0)
        let back = R * SIMD4(0, 0, -d, 0)
        return (target + SIMD3(back.x, back.y, back.z), o.pitch, o.yaw)
    }

    /// The comp as seen from the orbit camera: every visual layer becomes a plane in space; the comp's own cameras
    /// stay out of the way (they're drawn as gizmos by `OrbitGrid`).
    static func scene(_ p: Project, orbit o: OrbitCamera, time: Double) -> Project {
        var s = p
        s.layers.removeAll { $0.content == .camera }
        for i in s.layers.indices {
            switch s.layers[i].content {
            case .audio: break
            case .adjustment: s.layers[i].isVisible = false
            default: s.layers[i].is3D = true
            }
        }
        let e = eye(p, orbit: o)
        var cam = s.makeLayer(name: "Orbit View", content: .camera, size: Vec2(1, 1))
        cam.inPoint = 0; cam.outPoint = max(p.duration, 1) + 1
        cam.transform.position = Animated(Vec2(e.pos.x, e.pos.y))
        cam.transform.positionZ = Animated(e.pos.z)
        cam.transform.rotationX = Animated(e.rx)
        cam.transform.rotationY = Animated(e.ry)
        let z = CameraState.defaultZoom(p)
        cam.camera = CameraOptions(zoom: Animated(z), focusDistance: Animated(z))
        s.layers.insert(cam, at: 0)
        return s
    }
}

/// Floor grid, comp frame and the real camera, projected through the orbit camera.
struct OrbitGrid: View {
    let project: Project
    let orbit: OrbitCamera
    let time: Double
    let fit: CGRect

    var body: some View {
        Canvas { ctx, _ in
            let view = OrbitView.scene(project, orbit: orbit, time: time)
            let cam = Renderer.activeCamera(view, time: time)
            let s = Double(fit.width) / Double(project.width)
            func proj(_ p: SIMD3<Double>) -> CGPoint? {
                let c = cam.view * SIMD4(p.x, p.y, p.z, 1)
                guard c.z > 1 else { return nil }
                return CGPoint(x: fit.minX + (cam.zoom * c.x / c.z + cam.center.x) * s, y: fit.minY + (cam.zoom * c.y / c.z + cam.center.y) * s)
            }
            func line(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ color: Color, _ w: CGFloat) {
                guard let p = proj(a), let q = proj(b) else { return }
                var path = Path(); path.move(to: p); path.addLine(to: q)
                ctx.stroke(path, with: .color(color), lineWidth: w)
            }
            let W = Double(project.width), H = Double(project.height)
            let step = max(W, H) / 8
            let floorY = H
            for k in -8...16 {
                let x = Double(k) * step
                line(SIMD3(x, floorY, -max(W, H)), SIMD3(x, floorY, 2 * max(W, H)), .white.opacity(k == 4 ? 0.35 : 0.12), 1)
                let z = Double(k) * step - max(W, H) * 0.5
                line(SIMD3(-W, floorY, z), SIMD3(2 * W, floorY, z), .white.opacity(0.12), 1)
            }
            // Comp frame at z = 0.
            let c = [SIMD3(0, 0, 0.0), SIMD3(W, 0, 0), SIMD3(W, H, 0), SIMD3(0, H, 0)]
            for i in 0..<4 { line(c[i], c[(i + 1) % 4], Theme.accentGlow, 1.5) }
            // The comp's real camera as a little pyramid pointing at the frame.
            let real = Renderer.activeCamera(project, time: time)
            let eye = real.world * SIMD4(0, 0, 0, 1)
            let e3 = SIMD3(eye.x, eye.y, eye.z)
            for corner in c { line(e3, e3 + (corner - e3) * 0.12, Theme.warning, 1.5) }
            if let p = proj(e3) {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(Theme.warning))
            }
        }
    }
}

/// 2D / 3D switch for the viewport top bar.
struct ViewModeSwitch: View {
    @ObservedObject var state: EditorState
    var body: some View {
        HStack(spacing: 0) {
            ForEach([ViewMode.comp, .orbit], id: \.self) { m in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { state.viewMode = m }
                    if m == .orbit && state.viewMode == .orbit { UISelectionFeedbackGenerator().selectionChanged() }
                } label: {
                    Text(m == .comp ? "2D" : "3D").font(.system(size: 12, weight: .bold))
                        .frame(width: 34, height: 26)
                        .background(Capsule().fill(state.viewMode == m ? Theme.accent : .clear))
                        .foregroundStyle(state.viewMode == m ? Color.white : Theme.textDim)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(m == .comp ? "2D view" : "3D view")
            }
            if state.viewMode == .orbit {
                Button { withAnimation { state.orbit = .home } } label: {
                    Image(systemName: "scope").font(.system(size: 12, weight: .bold)).frame(width: 28, height: 26)
                }
                .buttonStyle(.plain).foregroundStyle(Theme.text)
                .accessibilityLabel("Reset 3D view")
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.raised))
    }
}
