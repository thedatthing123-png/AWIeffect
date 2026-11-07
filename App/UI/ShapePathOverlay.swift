import SwiftUI
import simd

/// Path-space controls sit inside the layer's existing placement, including camera/parent transforms.
struct ShapePathOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var original: ShapeComponent?
    var body: some View {
        if let l = state.selectedLayer, let item = state.selectedShapeContent, item.visible,
           let c = item.component, let placement = state.displayPlacement(of: l.id),
           abs(c.matrix(at: state.currentTime).determinant) > 1e-10 {
            let t = state.currentTime
            let base = c.base(at: t), m = placement * c.matrix(at: t)
            let scale = Double(fit.width) / Double(state.project.width)
            let map: (Vec2) -> CGPoint = { p in
                let q = m * SIMD3(p.x, p.y, 1)
                return CGPoint(x: fit.minX + q.x / q.z * scale, y: fit.minY + q.y / q.z * scale)
            }
            let b = base.bounds, center = map(.zero)
            Path { p in
                for seg in base.segments() {
                    p.move(to: map(Vec2(Double(seg.x), Double(seg.y))))
                    p.addLine(to: map(Vec2(Double(seg.z), Double(seg.w))))
                }
            }.stroke(Theme.accentGlow, lineWidth: 1).allowsHitTesting(false)
            handle("Move Path", "plus", at: center)
                .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global).onChanged { g in
                    let old = begin(c), inv = placement.inverse
                    let d = Vec2(Double(g.translation.width) / scale, Double(g.translation.height) / scale)
                    let origin = placement * SIMD3(old.position.value(at: t).x, old.position.value(at: t).y, 1)
                    let start = origin / origin.z
                    let end = inv * SIMD3(start.x + d.x, start.y + d.y, 1)
                    edit(item.id) { $0.position.set(Vec2(end.x / end.z, end.y / end.z), at: t) }
                }.onEnded { _ in finish() })
            handle("Scale Path", "arrow.up.left.and.arrow.down.right", at: map(b.max))
                .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global).onChanged { g in
                    let old = begin(c)
                    let fixed = placement * old.matrix(at: t)
                    let a = fixed * SIMD3(0.0, 0, 1), z = fixed * SIMD3(b.max.x, b.max.y, 1)
                    let dx = (z.x / z.z - a.x / a.z) * scale, dy = (z.y / z.z - a.y / a.z) * scale
                    let factor = max(0.01, 1 + (Double(g.translation.width) * dx + Double(g.translation.height) * dy) / max(400, dx * dx + dy * dy))
                    edit(item.id) { $0.scale.set(old.scale.value(at: t) * factor, at: t) }
                }.onEnded { _ in finish() })
            handle("Rotate Path", "arrow.clockwise", at: map(Vec2(0, b.min.y - 32 / max(scale, 0.01))))
                .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global).onChanged { g in
                    let old = begin(c)
                    let delta = Double(g.translation.width) * 0.4
                    edit(item.id) { $0.rotation.set(old.rotation.value(at: t) + delta, at: t) }
                }.onEnded { _ in finish() })
            if let gradient = c.fillGradient ?? c.strokeGradient {
                let stroke = c.fillGradient == nil
                gradientHandle(gradient.start.value(at: t), end: false, stroke: stroke, id: item.id, matrix: m, map: map, scale: scale)
                gradientHandle(gradient.end.value(at: t), end: true, stroke: stroke, id: item.id, matrix: m, map: map, scale: scale)
            }
        }
    }
    private func handle(_ label: String, _ icon: String, at point: CGPoint) -> some View {
        Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            .frame(width: 24, height: 24).background(Circle().fill(Theme.accent))
            .frame(width: 44, height: 44).contentShape(Rectangle()).position(point).accessibilityLabel(label)
    }
    private func begin(_ c: ShapeComponent) -> ShapeComponent {
        if original == nil { original = c; state.beginEdit("Transform Path") }
        return original ?? c
    }
    private func edit(_ id: UUID, _ change: (inout ShapeComponent) -> Void) {
        state.editShapeContent(id, "Transform Path", continuous: true) { item in
            guard var c = item.component else { return }; change(&c); item.component = c
        }
    }
    private func finish() { original = nil; state.endEdit() }
    private func gradientHandle(_ p: Vec2, end: Bool, stroke: Bool, id: UUID, matrix: simd_double3x3,
                                map: @escaping (Vec2) -> CGPoint, scale: Double) -> some View {
        handle(end ? "Gradient End" : "Gradient Start", end ? "circle.fill" : "circle", at: map(p))
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global).onChanged { g in
                guard let c = state.selectedShapeContent?.component else { return }
                let old = begin(c), grad = (stroke ? old.strokeGradient : old.fillGradient) ?? ShapeGradient()
                let start = end ? grad.end.value(at: state.currentTime) : grad.start.value(at: state.currentTime)
                let q = matrix * SIMD3(start.x, start.y, 1)
                let local = matrix.inverse * SIMD3(q.x / q.z + Double(g.translation.width) / scale, q.y / q.z + Double(g.translation.height) / scale, 1)
                let point = Vec2(local.x / local.z, local.y / local.z), t = state.currentTime
                edit(id) { c in
                    var value = (stroke ? c.strokeGradient : c.fillGradient) ?? ShapeGradient()
                    if end { value.end.set(point, at: t) } else { value.start.set(point, at: t) }
                    if stroke { c.strokeGradient = value } else { c.fillGradient = value }
                }
            }.onEnded { _ in finish() })
    }
}
