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
    let positionProjection: simd_double3x3
    let rawPosition: Vec2
    /// The layer's own (unparented) transform at drag start: edits write these values.
    var raw: LayerTransform? = nil
    var is3D = false
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

    /// Pan Behind (AE): the position that keeps the layer exactly where it is when its anchor moves to `newAnchor`.
    /// Works in the layer's own (parent) space, so parenting, 3D rotation and cameras don't make it jump.
    static func pivotCompensated(_ tr: LayerTransform, is3D: Bool, newAnchor: Vec2, time: Double) -> (position: Vec2, z: Double) {
        let p = tr.position.value(at: time), a = tr.anchor.value(at: time), sc = tr.scale.value(at: time)
        let d = SIMD4<Double>(newAnchor.x - a.x, newAnchor.y - a.y, 0, 0)
        let S = simd_double4x4(diagonal: SIMD4<Double>(sc.x / 100, sc.y / 100, 1, 1))
        let R = is3D ? CameraState.rotation(x: tr.rotationX.value(at: time), y: tr.rotationY.value(at: time), z: tr.rotation.value(at: time))
                     : CameraState.rotation(x: 0, y: 0, z: tr.rotation.value(at: time))
        let w = R * S * d
        return (Vec2(p.x + w.x, p.y + w.y), tr.positionZ.value(at: time) + (is3D ? w.z : 0))
    }
}

extension EditorState {
    /// Starts a canvas drag: handles win over the tool mode (corner = scale, edge = stretch, knob = rotate).
    func beginCanvasDrag(at screen: CGPoint, comp: Vec2, fit: CGRect) -> CanvasDrag? {
        guard let raw = selectedLayer, !raw.isLocked else { return nil }
        // A selected camera is moved with camera gestures (the scene follows the finger), not like a layer.
        if raw.content == .camera { return nil }
        let t = currentTime
        // Free view shows the scene without the camera: handles and projections must use the same view.
        let view = canvasViewProject(project)
        // Handles are where the layer is drawn (parenting baked); edits still go to its own values.
        let l = Renderer.resolveParenting(view, time: t).layers.first { $0.id == raw.id } ?? raw
        let h = CanvasHandles.handles(l, project: view, time: t, fit: fit)
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
        let M = Renderer.placementMatrix(l, camera: Renderer.activeCamera(view, time: t), time: t, renderScale: 1)
        let tr = raw.transform
        let projection = LayerPlacement.positionMatrix(raw, project: view, time: t)
        // Scale / rotate turn around the anchor where it is drawn (the same projection the Move tool uses).
        let screenAnchor = LayerPlacement.projected(tr.position.value(at: t), by: projection) ?? tr.position.value(at: t)
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
        if motionSketch, case .move = kind { beginMotionSketch() }
        // `rotation` is the drawn rotation (stretch axes follow what you see); scale and `raw` are the values edits write.
        return CanvasDrag(kind: kind, startComp: comp, pivot: screenAnchor, position: tr.position.value(at: t),
                          scale: tr.scale.value(at: t), rotation: l.transform.rotation.value(at: t), anchor: tr.anchor.value(at: t), inverse: M.inverse,
                          positionProjection: projection, rawPosition: tr.position.value(at: t), raw: tr, is3D: raw.is3D)
    }

    /// Screen distance from `screen` to the nearest transform handle of the selected layer (nil without one).
    func nearestHandleDistance(at screen: CGPoint, fit: CGRect) -> CGFloat? {
        guard let raw = selectedLayer, raw.content != .camera else { return nil }
        let view = canvasViewProject(project)
        guard let l = Renderer.resolveParenting(view, time: currentTime).layers.first(where: { $0.id == raw.id }) else { return nil }
        let h = CanvasHandles.handles(l, project: view, time: currentTime, fit: fit)
        return ([h.rotate] + h.corners + h.edges).map { hypot($0.x - screen.x, $0.y - screen.y) }.min()
    }

    /// The project as the canvas shows it: free view hides cameras (you look at the scene itself).
    func canvasViewProject(_ p: Project) -> Project { cameraView ? p : freeViewProject(p) }

    func updateCanvasDrag(_ d: CanvasDrag, comp c: Vec2) {
        let t = currentTime
        switch d.kind {
        case .move where multiDragStarts.count > 1:
            // Multi-selection: everything selected moves together (each in its own parent's space is skipped
            // for simplicity: children follow their parents anyway).
            let delta = c - d.startComp
            guard liveGesture, var lp = live.project else { return }
            let view = canvasViewProject(project)
            for i in lp.layers.indices {
                guard let s = multiDragStarts[lp.layers[i].id] else { continue }
                if let pid = lp.layers[i].parentID, multiDragStarts[pid] != nil { continue }
                var original = project.layers.first { $0.id == lp.layers[i].id } ?? lp.layers[i]
                original.transform.position = Animated(s)
                guard let p = LayerPlacement.movedPosition(original, project: view, time: t, screenDelta: delta) else { continue }
                let moved = Vec2((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10)
                if sketchStartTime != nil { recordMotionSketch(moved, layer: original.id) }
                lp.layers[i].transform.position.set(moved, at: t)
            }
            lp.modifiedAt = Date()
            live.project = lp
        case .move:
            let delta = c - d.startComp
            guard abs(d.positionProjection.determinant) > 1e-10,
                  let start = LayerPlacement.projected(d.rawPosition, by: d.positionProjection),
                  let candidate = LayerPlacement.projected(start + delta, by: d.positionProjection.inverse) else { return }
            var p = candidate
            // Depth, rotation and parenting are removed together so the layer follows the finger exactly.
            if selectedLayer?.is3D == true || !snappingEnabled {
                snapGuides = SnapGuides(x: nil, y: nil)
                let free = Vec2((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10)
                // Motion Sketch records here too (Snap off and 3D layers used to record nothing).
                if sketchStartTime != nil, let id = selectedLayerID { recordMotionSketch(free, layer: id) }
                mutateLayer { $0.transform.position.set(free, at: t) }; return
            }
            let view = canvasViewProject(project)
            // Snap to the frame center / edges and to other layers' positions (guides show while snapped).
            // Small grab zone + stickiness: it grabs only when really close and lets go once you clearly pull
            // away, so the layer never flickers between snapped and free.
            let grab = Double(project.width) * 0.005
            guard let projectedCandidate = LayerPlacement.projected(p, by: d.positionProjection) else { return }
            p = projectedCandidate
            var gx: Double?, gy: Double?
            var xs = [Double(project.width) / 2, 0, Double(project.width)], ys = [Double(project.height) / 2, 0, Double(project.height)]
            for o in view.layers where o.id != selectedLayerID && o.isActive(at: t) && o.content != .camera && !o.isAudioOnly {
                if let rect = LayerPlacement.bounds(o, project: view, time: t) {
                    xs += [rect.minX, rect.midX, rect.maxX]; ys += [rect.minY, rect.midY, rect.maxY]
                }
            }
            // Guides, the grid (when shown) and other layers' anchor points.
            let extra = extraSnapTargets(view: view, time: t)
            xs += extra.xs; ys += extra.ys
            var xFeatures = [p.x], yFeatures = [p.y]
            if let layer = selectedLayer, let rect = LayerPlacement.bounds(layer, project: view, time: t) {
                xFeatures += [rect.minX, rect.midX, rect.maxX].map { $0 + p.x - start.x }
                yFeatures += [rect.minY, rect.midY, rect.maxY].map { $0 + p.y - start.y }
            }
            let sx = LayerPlacement.snap(features: xFeatures, targets: xs, held: snapGuides.x, grab: grab)
            let sy = LayerPlacement.snap(features: yFeatures, targets: ys, held: snapGuides.y, grab: grab)
            p.x += sx.delta; p.y += sy.delta; gx = sx.guide; gy = sy.guide
            if (gx, gy) != (snapGuides.x, snapGuides.y) {
                if gx != nil || gy != nil { UISelectionFeedbackGenerator().selectionChanged() }
                snapGuides = SnapGuides(x: gx, y: gy)
            }
            // Sub-pixel positions: smooth motion under the finger (no whole-pixel stepping).
            guard let localPosition = LayerPlacement.projected(p, by: d.positionProjection.inverse) else { return }
            let rounded = Vec2((localPosition.x * 10).rounded() / 10, (localPosition.y * 10).rounded() / 10)
            if sketchStartTime != nil, let id = selectedLayerID { recordMotionSketch(rounded, layer: id) }
            mutateLayer { $0.transform.position.set(rounded, at: t) }
        case .scale:
            let r0 = hypot(d.startComp.x - d.pivot.x, d.startComp.y - d.pivot.y)
            let r1 = hypot(c.x - d.pivot.x, c.y - d.pivot.y)
            var k = r0 > 1 ? r1 / r0 : 1
            // Scale snapping: lands on whole 5 % steps (100 %, 150 %…) when close, free in between.
            if snappingEnabled, abs(d.scale.x) > 1e-6 { k = CanvasSnap.snapScale(d.scale.x * k) / d.scale.x }
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
            // Own rotation (a parent's turn is added on top when drawn).
            var r = (d.raw?.rotation.value(at: t) ?? d.rotation) + (a1 - a0) * 180 / .pi
            // Free rotation unless Rotation Snap is on (then 15° steps).
            if rotationSnap { r = CanvasSnap.snapRotation(r) }
            mutateLayer { $0.transform.rotation.set((r * 10).rounded() / 10, at: t) }
        case .pivot:
            // Move the anchor under the finger and compensate position so the layer stays put (AE Pan Behind).
            // The finger is un-projected through the drawn placement (parenting, 3D, camera) and the position is
            // compensated in the layer's own space, so nothing jumps.
            guard let raw = d.raw, let q = LayerPlacement.projected(c, by: d.inverse) else { return }
            let newAnchor = Vec2((q.x * 10).rounded() / 10, (q.y * 10).rounded() / 10)
            let moved = CanvasHandles.pivotCompensated(raw, is3D: d.is3D, newAnchor: newAnchor, time: t)
            mutateLayer { l in
                l.transform.anchor.set(newAnchor, at: t)
                l.transform.position.set(moved.position, at: t)
                if d.is3D { l.transform.positionZ.set(moved.z, at: t) }
            }
        }
    }

    func endCanvasDrag() {
        endLiveGesture()
        // The sketch's keys land in the drag's own undo step.
        if sketchStartTime != nil { endMotionSketch() }
        endEdit(); snapGuides = SnapGuides(); multiDragStarts = [:]
    }

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
            let r = self.rotationSnap ? CanvasSnap.snapRotation(s.rotation + deg) : s.rotation + deg
            $0.transform.rotation.set((r * 10).rounded() / 10, at: t)
        }
    }

    func endLayerPinch(ownsEdit: Bool) {
        pinchStart = nil
        if ownsEdit { endLiveGesture(); endEdit() }
    }
}

/// Guide lines (comp px) shown while a move snaps.
struct SnapGuides: Equatable { var x: Double? = nil; var y: Double? = nil }
