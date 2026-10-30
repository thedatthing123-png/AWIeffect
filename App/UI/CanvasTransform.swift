import SwiftUI
import simd

/// Alight Motion-style transform modes for dragging on the canvas.
enum TransformTool: String, CaseIterable, Identifiable {
    case move, scale, rotate, pivot
    var id: String { rawValue }
    var title: String { self == .pivot ? "Pivot" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .scale: return "arrow.up.left.and.arrow.down.right"
        case .rotate: return "arrow.clockwise"
        case .pivot: return "scope"
        }
    }
}

/// One canvas drag: what it changes and the values it started from.
struct CanvasDrag {
    enum Kind { case move, scale, stretch(x: Bool, y: Bool), rotate, pivot }
    let kind: Kind
    let startComp: Vec2
    let pivot: Vec2            // anchor in comp space at drag start
    let position: Vec2
    let scale: Vec2
    let rotation: Double
    let anchor: Vec2
    let inverse: simd_double3x3   // comp -> layer local at drag start
}

enum CanvasHandles {
    /// Screen positions of the selection handles (corners, edge midpoints, rotate knob) for a 2D/3D layer.
    static func handles(_ layer: Layer, project: Project, time: Double, fit: CGRect) -> (corners: [CGPoint], edges: [CGPoint], rotate: CGPoint, anchor: CGPoint) {
        let s = Double(fit.width) / Double(project.width)
        let M = Renderer.placementMatrix(layer, camera: Renderer.activeCamera(project, time: time), time: time, renderScale: s)
        let hs = Renderer.layerHalfSize(layer, time: time)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            let p = M * SIMD3(x, y, 1); let z = max(p.z, 1e-6)
            return CGPoint(x: fit.minX + p.x / z, y: fit.minY + p.y / z)
        }
        let corners = [pt(-hs.x, -hs.y), pt(hs.x, -hs.y), pt(hs.x, hs.y), pt(-hs.x, hs.y)]
        let edges = [pt(0, -hs.y), pt(hs.x, 0), pt(0, hs.y), pt(-hs.x, 0)]    // top, right, bottom, left
        let top = edges[0], center = pt(0, 0)
        // Rotate knob sits 28 pt beyond the top edge, along the layer's up direction.
        let dx = top.x - center.x, dy = top.y - center.y, len = max(hypot(dx, dy), 1)
        let rotate = CGPoint(x: top.x + dx / len * 28, y: top.y + dy / len * 28)
        let a = layer.transform.anchor.value(at: time)
        return (corners, edges, rotate, pt(a.x, a.y))
    }
}

extension EditorState {
    /// Starts a canvas drag: handles win over the tool mode (corner = scale, edge = stretch, knob = rotate).
    func beginCanvasDrag(at screen: CGPoint, comp: Vec2, fit: CGRect) -> CanvasDrag? {
        guard let l = selectedLayer, !l.isLocked else { return nil }
        let t = currentTime
        let h = CanvasHandles.handles(l, project: project, time: t, fit: fit)
        // Nearest handle within reach wins (small layers have handles close together).
        func dist(_ p: CGPoint) -> CGFloat { hypot(p.x - screen.x, p.y - screen.y) }
        var best: (d: CGFloat, kind: CanvasDrag.Kind)?
        func consider(_ p: CGPoint, _ k: CanvasDrag.Kind) { let d = dist(p); if d < 24, d < (best?.d ?? .infinity) { best = (d, k) } }
        consider(h.rotate, .rotate)
        for c in h.corners { consider(c, scaleLinked ? .scale : .stretch(x: true, y: true)) }
        for (i, e) in h.edges.enumerated() { consider(e, .stretch(x: i % 2 == 1, y: i % 2 == 0)) }
        var kind: CanvasDrag.Kind
        if let b = best { kind = b.kind }
        else {
            switch transformTool {
            case .move: kind = .move
            case .scale: kind = scaleLinked ? .scale : .stretch(x: true, y: true)
            case .rotate: kind = .rotate
            case .pivot: kind = .pivot
            }
        }
        let M = Renderer.layerMatrix(l, time: t, renderScale: 1, includeEffects: false)
        let tr = l.transform
        let label: String
        switch kind {
        case .move: label = "Move Layer"
        case .scale, .stretch: label = "Scale Layer"
        case .rotate: label = "Rotate Layer"
        case .pivot: label = "Move Pivot"
        }
        pause()
        beginEdit(label)
        UISelectionFeedbackGenerator().selectionChanged()
        return CanvasDrag(kind: kind, startComp: comp, pivot: tr.position.value(at: t), position: tr.position.value(at: t),
                          scale: tr.scale.value(at: t), rotation: tr.rotation.value(at: t), anchor: tr.anchor.value(at: t), inverse: M.inverse)
    }

    func updateCanvasDrag(_ d: CanvasDrag, comp c: Vec2) {
        let t = currentTime
        switch d.kind {
        case .move:
            let p = d.position + (c - d.startComp)
            mutateLayer { $0.transform.position.set(Vec2(p.x.rounded(), p.y.rounded()), at: t) }
        case .scale:
            let r0 = hypot(d.startComp.x - d.pivot.x, d.startComp.y - d.pivot.y)
            let r1 = hypot(c.x - d.pivot.x, c.y - d.pivot.y)
            let k = r0 > 1 ? r1 / r0 : 1
            mutateLayer { $0.transform.scale.set(Vec2((d.scale.x * k * 10).rounded() / 10, (d.scale.y * k * 10).rounded() / 10), at: t) }
        case .stretch(let ax, let ay):
            // Measure along the layer's own (rotated) axes so stretching follows the layer.
            let rot = -d.rotation * .pi / 180
            func local(_ v: Vec2) -> Vec2 { Vec2(v.x * cos(rot) - v.y * sin(rot), v.x * sin(rot) + v.y * cos(rot)) }
            let a = local(d.startComp - d.pivot), b = local(c - d.pivot)
            let kx = ax && abs(a.x) > 2 ? b.x / a.x : 1
            let ky = ay && abs(a.y) > 2 ? b.y / a.y : 1
            mutateLayer { $0.transform.scale.set(Vec2((d.scale.x * kx * 10).rounded() / 10, (d.scale.y * ky * 10).rounded() / 10), at: t) }
        case .rotate:
            let a0 = atan2(d.startComp.y - d.pivot.y, d.startComp.x - d.pivot.x)
            let a1 = atan2(c.y - d.pivot.y, c.x - d.pivot.x)
            var r = d.rotation + (a1 - a0) * 180 / .pi
            // Gentle snapping to 45° steps.
            let snap = (r / 45).rounded() * 45
            if abs(r - snap) < 2.5 { r = snap }
            mutateLayer { $0.transform.rotation.set((r * 10).rounded() / 10, at: t) }
        case .pivot:
            // Move the anchor under the finger and compensate position so the layer stays put (AE Pan Behind).
            let q = d.inverse * SIMD3(c.x, c.y, 1)
            let newAnchor = d.anchor + Vec2(q.x, q.y) - d.anchor
            mutateLayer { l in
                l.transform.anchor.set(Vec2(newAnchor.x.rounded(), newAnchor.y.rounded()), at: t)
                l.transform.position.set(Vec2(c.x.rounded(), c.y.rounded()), at: t)
            }
        }
    }

    func endCanvasDrag() { endEdit() }
}

/// Mode buttons + scale link toggle shown above the transform properties.
struct TransformToolBar: View {
    @ObservedObject var state: EditorState
    var body: some View {
        HStack(spacing: 6) {
            ForEach(TransformTool.allCases) { tool in
                Button { state.transformTool = tool } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tool.symbol).font(.system(size: 14, weight: .semibold))
                        Text(tool.title).font(.system(size: 9, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .foregroundStyle(state.transformTool == tool ? Theme.accentGlow : Theme.text)
                    .background(RoundedRectangle(cornerRadius: 9).fill(state.transformTool == tool ? Theme.accent.opacity(0.25) : Theme.surface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tool.title) tool")
            }
            Button { state.scaleLinked.toggle() } label: {
                VStack(spacing: 2) {
                    Image(systemName: state.scaleLinked ? "link" : "link.badge.plus").font(.system(size: 14, weight: .semibold))
                    Text(state.scaleLinked ? "Linked" : "Stretch").font(.system(size: 9, weight: .semibold))
                }
                .frame(width: 58, height: 40)
                .foregroundStyle(state.scaleLinked ? Theme.text : Theme.warning)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.scaleLinked ? "Scale linked" : "Scale unlinked (stretch)")
        }
    }
}
