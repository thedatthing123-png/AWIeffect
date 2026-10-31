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
        guard let raw = selectedLayer, !raw.isLocked else { return nil }
        let t = currentTime
        // Handles are where the layer is drawn (parenting baked); edits still go to its own values.
        let l = displayProject.layers.first { $0.id == raw.id } ?? raw
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
        let M = Renderer.placementMatrix(l, camera: Renderer.activeCamera(project, time: t), time: t, renderScale: 1)
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
        beginLiveGesture()
        multiDragStarts = [:]
        if case .move = kind, let ids = multiSelection, ids.count > 1 {
            for o in project.layers where ids.contains(o.id) && !o.isLocked { multiDragStarts[o.id] = o.transform.position.value(at: t) }
        }
        UISelectionFeedbackGenerator().selectionChanged()
        return CanvasDrag(kind: kind, startComp: comp, pivot: tr.position.value(at: t), position: tr.position.value(at: t),
                          scale: tr.scale.value(at: t), rotation: tr.rotation.value(at: t), anchor: tr.anchor.value(at: t), inverse: M.inverse)
    }

    func updateCanvasDrag(_ d: CanvasDrag, comp c: Vec2) {
        let t = currentTime
        switch d.kind {
        case .move where multiDragStarts.count > 1:
            // Multi-selection: everything selected moves together (each in its own parent's space is skipped
            // for simplicity: children follow their parents anyway).
            let delta = c - d.startComp
            guard liveGesture, var lp = live.project else { return }
            for i in lp.layers.indices {
                guard let s = multiDragStarts[lp.layers[i].id] else { continue }
                if let pid = lp.layers[i].parentID, multiDragStarts[pid] != nil { continue }
                let p = s + delta
                lp.layers[i].transform.position.set(Vec2((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10), at: t)
            }
            lp.modifiedAt = Date()
            live.project = lp
        case .move:
            var delta = c - d.startComp
            // Under a 2D camera the finger moves in what the camera shows: undo the camera's zoom / turn.
            if let l = selectedLayer, !l.is3D {
                let v = Renderer.activeCamera(project, time: t).view2D
                if v != matrix_identity_double3x3 {
                    let inv = v.inverse
                    delta = Vec2(inv[0][0] * delta.x + inv[1][0] * delta.y, inv[0][1] * delta.x + inv[1][1] * delta.y)
                }
            }
            if let pid = selectedLayer?.parentID, let a = Renderer.parentAffine(pid, in: project, time: t) {
                // Finger moves in comp space; the child's position lives in its parent's space.
                let inv = a.m.inverse
                delta = Vec2(inv[0][0] * delta.x + inv[1][0] * delta.y, inv[0][1] * delta.x + inv[1][1] * delta.y)
                let p = d.position + delta
                mutateLayer { $0.transform.position.set(Vec2((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10), at: t) }
                return
            }
            var p = d.position + delta
            // Snap to the frame center / edges and to other layers' positions (guides show while snapped).
            // Small grab zone + stickiness: it grabs only when really close and lets go once you clearly pull
            // away, so the layer never flickers between snapped and free.
            let grab = Double(project.width) * 0.005, release = grab * 2.2
            var gx: Double?, gy: Double?
            var xs = [Double(project.width) / 2, 0, Double(project.width)], ys = [Double(project.height) / 2, 0, Double(project.height)]
            for o in project.layers where o.id != selectedLayerID && o.isActive(at: t) && o.content != .camera && !o.isAudioOnly {
                let op = o.transform.position.value(at: t); xs.append(op.x); ys.append(op.y)
            }
            if let held = snapGuides.x, abs(held - p.x) < release { p.x = held; gx = held }
            else if let x = xs.min(by: { abs($0 - p.x) < abs($1 - p.x) }), abs(x - p.x) < grab { p.x = x; gx = x }
            if let held = snapGuides.y, abs(held - p.y) < release { p.y = held; gy = held }
            else if let y = ys.min(by: { abs($0 - p.y) < abs($1 - p.y) }), abs(y - p.y) < grab { p.y = y; gy = y }
            if (gx, gy) != (snapGuides.x, snapGuides.y) {
                if gx != nil || gy != nil { UISelectionFeedbackGenerator().selectionChanged() }
                snapGuides = SnapGuides(x: gx, y: gy)
            }
            // Sub-pixel positions: smooth motion under the finger (no whole-pixel stepping).
            mutateLayer { $0.transform.position.set(Vec2((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10), at: t) }
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

    func endCanvasDrag() { endLiveGesture(); endEdit(); snapGuides = SnapGuides(); multiDragStarts = [:] }

    // MARK: Two-finger pinch / twist on the selected layer

    func beginLayerPinch() {
        guard let l = selectedLayer else { return }
        if !isLiveGesture { pause(); beginEdit("Transform Layer"); beginLiveGesture() }
        let t = currentTime
        let src = live.project?.layers.first { $0.id == l.id } ?? l
        pinchStart = (src.transform.scale.value(at: t), src.transform.rotation.value(at: t))
    }

    func updateLayerPinch(scale k: Double, rotation deg: Double) {
        guard let s = pinchStart, k.isFinite, deg.isFinite else { return }
        let t = currentTime
        let kk = max(0.01, k)
        mutateLayer {
            $0.transform.scale.set(Vec2((s.scale.x * kk * 10).rounded() / 10, (s.scale.y * kk * 10).rounded() / 10), at: t)
            $0.transform.rotation.set(((s.rotation + deg) * 10).rounded() / 10, at: t)
        }
    }

    func endLayerPinch(ownsEdit: Bool) {
        pinchStart = nil
        if ownsEdit { endLiveGesture(); endEdit() }
    }
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

/// Guide lines (comp px) shown while a move snaps.
struct SnapGuides: Equatable { var x: Double? = nil; var y: Double? = nil }
