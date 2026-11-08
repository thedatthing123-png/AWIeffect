import SwiftUI
import simd

// MARK: - R2 canvas overlays: guides, camera point of interest, light gizmo, IK bones, marquee

/// User guides: thin lines across the comp; each has a 44 pt tab on the comp edge to drag it (drag off to delete).
struct GuidesOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var dragging: UUID?

    private var scale: CGFloat { fit.width / CGFloat(max(state.project.width, 1)) }

    var body: some View {
        if state.showGuides, !state.guides.isEmpty {
            ZStack {
                Canvas { ctx, _ in
                    for g in state.guides {
                        var p = Path()
                        if g.vertical {
                            let x = fit.minX + CGFloat(g.value) * scale
                            p.move(to: CGPoint(x: x, y: fit.minY)); p.addLine(to: CGPoint(x: x, y: fit.maxY))
                        } else {
                            let y = fit.minY + CGFloat(g.value) * scale
                            p.move(to: CGPoint(x: fit.minX, y: y)); p.addLine(to: CGPoint(x: fit.maxX, y: y))
                        }
                        ctx.stroke(p, with: .color(Color.cyan.opacity(g.id == dragging ? 1 : 0.7)), lineWidth: 1)
                    }
                }
                .allowsHitTesting(false)
                ForEach(state.guides) { g in
                    let at = g.vertical ? CGPoint(x: fit.minX + CGFloat(g.value) * scale, y: fit.minY + 11)
                                        : CGPoint(x: fit.minX + 11, y: fit.minY + CGFloat(g.value) * scale)
                    Capsule().fill(Color.cyan)
                        .frame(width: g.vertical ? 8 : 20, height: g.vertical ? 20 : 8)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                        .position(at)
                        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("guides"))
                            .onChanged { v in
                                if dragging == nil { dragging = g.id; state.beginEdit("Move Guide") }
                                let value = g.vertical ? Double((v.location.x - fit.minX) / scale) : Double((v.location.y - fit.minY) / scale)
                                state.moveGuide(g.id, to: value)
                            }
                            .onEnded { _ in state.finishGuideDrag(g.id); dragging = nil })
                        .accessibilityLabel(g.vertical ? "Vertical guide" : "Horizontal guide")
                }
            }
            .coordinateSpace(name: "guides")
        }
    }
}

/// A 3D camera's or light's aim on the canvas: where it points on the z = 0 plane (drag it to re-aim), a line from
/// the light, and a spot light's cone. Cameras show it in free view (in camera view the aim is the frame centre).
struct AimGizmoOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var dragging = false

    private var scale: CGFloat { fit.width / CGFloat(max(state.project.width, 1)) }
    private func screen(_ p: Vec2) -> CGPoint { CGPoint(x: fit.minX + CGFloat(p.x) * scale, y: fit.minY + CGFloat(p.y) * scale) }
    private func comp(_ p: CGPoint) -> Vec2 { Vec2(Double((p.x - fit.minX) / scale), Double((p.y - fit.minY) / scale)) }

    var body: some View {
        let t = state.currentTime
        let view = state.canvasViewProject(state.project)
        if let l = state.selectedLayer, l.content == .light || (l.content == .camera && EditorState.cameraIs3D(l) && !state.cameraView) {
            // A copy at depth 0 projects plane points (the aim) through the same view.
            let plane: Layer = { var d = l; d.transform.positionZ = Animated(0); return d }()
            let hit = Aim.planeHit(l, time: t)
            let hitScreen = hit.flatMap { MotionPathMath.screenPoint(plane, value: $0, project: view, time: t) }.map(screen)
            let source = l.content == .light ? MotionPathMath.screenPoint(l, value: l.transform.position.value(at: t), project: view, time: t).map(screen) : nil
            let aims = l.content == .camera || [LightType.spot, .parallel].contains(l.light?.type ?? .point)
            ZStack {
                Canvas { ctx, _ in
                    if let s = source {
                        let r: CGFloat = 9
                        ctx.fill(Path(ellipseIn: CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)), with: .color(Theme.warning))
                        ctx.stroke(Path(ellipseIn: CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)), with: .color(.black), lineWidth: 1.5)
                        if aims, let h = hitScreen {
                            var line = Path(); line.move(to: s); line.addLine(to: h)
                            ctx.stroke(line, with: .color(Theme.warning), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        }
                    }
                    // Spot cone where it lands (approximate: radius = distance × tan(cone / 2)).
                    if l.content == .light, l.light?.type == .spot, let o = l.light, let h = hitScreen, let hp = hit {
                        let p = l.transform.position.value(at: t)
                        let dist = simd_length(SIMD3(hp.x - p.x, hp.y - p.y, -l.transform.positionZ.value(at: t)))
                        let r = CGFloat(dist * tan(o.coneAngle.value(at: t) / 2 * .pi / 180)) * scale
                        if r.isFinite, r > 2, r < 4000 {
                            ctx.stroke(Path(ellipseIn: CGRect(x: h.x - r, y: h.y - r, width: r * 2, height: r * 2)),
                                       with: .color(Theme.warning.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                    }
                }
                .allowsHitTesting(false)
                if aims, let h = hitScreen {
                    ZStack {
                        Circle().stroke(Theme.warning, lineWidth: 2).frame(width: 18, height: 18)
                        Rectangle().fill(Theme.warning).frame(width: 2, height: 26)
                        Rectangle().fill(Theme.warning).frame(width: 26, height: 2)
                    }
                    .frame(width: 44, height: 44).contentShape(Rectangle())
                    .position(h)
                    .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("aimGizmo"))
                        .onChanged { v in
                            if !dragging { dragging = true; state.beginEdit(l.content == .camera ? "Point of Interest" : "Aim Light"); state.beginLiveGesture() }
                            guard let target = MotionPathMath.value(plane, at: comp(v.location), project: view, time: t) else { return }
                            state.aimSelected(atComp: target)
                        }
                        .onEnded { _ in dragging = false; state.endLiveGesture(); state.endEdit() })
                    .accessibilityLabel(l.content == .camera ? "Camera point of interest" : "Light aim")
                }
            }
            .coordinateSpace(name: "aimGizmo")
        }
    }
}

/// IK bones while the Rig panel is open: upper joint → elbow / knee → controller, for every rig.
struct BoneOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect

    var body: some View {
        let s = fit.width / CGFloat(max(state.project.width, 1))
        // Read the editor on the main actor; the Canvas drawing closure isn't main-actor isolated.
        let t = state.currentTime
        let view = state.canvasViewProject(state.live.project ?? state.project)
        let posed = IKSolver.apply(view, time: t)
        let selectedID = state.selectedLayerID
        let fit = self.fit
        Canvas { ctx, _ in
            let resolved = Renderer.resolveParenting(view, time: t)
            let camera = Renderer.activeCamera(view, time: t)
            let layers = Dictionary(resolved.layers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            func joint(_ id: UUID, spaceID: UUID?) -> CGPoint? {
                guard let l = layers[id] else { return nil }
                let matrix: simd_double3x3
                if let spaceID, let art = layers[spaceID],
                   let projected = EditorState.bonePlacement(l, artwork: art, project: posed, time: t, camera: camera) { matrix = projected }
                else { matrix = Renderer.placementMatrix(l, camera: camera, time: t, renderScale: 1) }
                guard let p = LayerPlacement.projected(l.transform.anchor.value(at: t), by: matrix) else { return nil }
                return CGPoint(x: fit.minX + CGFloat(p.x) * s, y: fit.minY + CGFloat(p.y) * s)
            }
            for l in view.layers {
                guard let rig = l.ik, let a = joint(rig.upperID, spaceID: rig.spaceID), let b = joint(l.id, spaceID: rig.spaceID), let c = joint(rig.controllerID, spaceID: rig.spaceID) else { continue }
                let on = l.id == selectedID
                var bone = Path(); bone.move(to: a); bone.addLine(to: b); bone.addLine(to: c)
                ctx.stroke(bone, with: .color(.black.opacity(0.6)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                ctx.stroke(bone, with: .color(on ? Theme.accentGlow : .white), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                for (k, p) in [a, b, c].enumerated() {
                    let r: CGFloat = k == 2 ? 8 : 6
                    let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                    ctx.fill(dot, with: .color(k == 2 ? Theme.warning : .white))
                    ctx.stroke(dot, with: .color(.black), lineWidth: 1.5)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Rubber band while drag-selecting on an empty canvas.
struct MarqueeOverlay: View {
    let rect: CGRect
    var body: some View {
        Rectangle().fill(Theme.accent.opacity(0.12))
            .overlay(Rectangle().stroke(Theme.accentGlow, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }
}


/// A rest endpoint is a canvas handle, not another tool drawer. Draft changes do not touch the project.
struct RigEndpointOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var dragStart: Vec2?
    @GestureState private var dragging = false

    var body: some View {
        if let layer = state.selectedLayer, state.selectedIKLayer == nil, state.ikDraftController == nil,
           state.ikDraftUpper != nil,
           let placement = state.displayPlacement(of: layer.id),
           let tip = LayerPlacement.projected(state.ikRestTip(for: layer), by: placement) {
            let scale = fit.width / CGFloat(max(1, state.project.width))
            let point = CGPoint(x: fit.minX + CGFloat(tip.x) * scale, y: fit.minY + CGFloat(tip.y) * scale)
            ZStack {
                Circle().fill(Theme.warning).frame(width: 14, height: 14)
                Circle().stroke(.black, lineWidth: 2).frame(width: 18, height: 18)
                Image(systemName: "plus").font(.system(size: 24, weight: .light)).foregroundStyle(Theme.warning)
            }
            .frame(width: 44, height: 44).contentShape(Rectangle())
            .position(point)
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .updating($dragging) { _, active, _ in active = true }
                .onChanged { value in
                    if dragStart == nil { dragStart = tip }
                    guard let start = dragStart else { return }
                    let canvas = start + Vec2(Double(value.translation.width / scale), Double(value.translation.height / scale))
                    guard let local = state.layerLocal(fromComp: canvas), local.x.isFinite, local.y.isFinite else { return }
                    state.ikDraftTip = (layer.id, local)
                }
                .onEnded { _ in dragStart = nil })
            .onChange(of: dragging) { _, active in if !active { dragStart = nil } }
            .onChange(of: layer.id) { _, _ in dragStart = nil }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Limb end joint")
            .accessibilityValue(String(format: "%.1f, %.1f", state.ikRestTip(for: layer).x, state.ikRestTip(for: layer).y))
            .accessibilityHint("Drag onto the wrist or ankle before making IK")
        }
    }
}


/// Targets stay on the character while the Rig panel is open. Only targets have hit areas; bones remain visual.
struct RigControllersOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect

    var body: some View {
        let source = state.live.project ?? state.project
        let view = state.canvasViewProject(source)
        let time = state.currentTime
        let posed = IKSolver.apply(view, time: time)
        let resolved = Renderer.resolveParenting(view, time: time)
        let camera = Renderer.activeCamera(view, time: time)
        let world = Dictionary(resolved.layers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ids = Set(source.layers.compactMap { $0.ik?.controllerID })
        let spaces = Dictionary(source.layers.compactMap { layer -> (UUID, UUID)? in
            guard let ik = layer.ik, let space = ik.spaceID else { return nil }
            return (ik.controllerID, space)
        }, uniquingKeysWith: { first, _ in first })
        func placement(_ layer: Layer) -> simd_double3x3 {
            if let id = spaces[layer.id], let art = world[id],
               let matrix = EditorState.bonePlacement(layer, artwork: art, project: posed, time: time, camera: camera) { return matrix }
            return Renderer.placementMatrix(layer, camera: camera, time: time, renderScale: 1)
        }
        // Resolve the hierarchy once for the overlay, not once for every hand/foot handle.
        return ForEach(source.layers.filter { ids.contains($0.id) }) { controller in
            if let layer = world[controller.id],
               let point = LayerPlacement.projected(layer.transform.anchor.value(at: time),
                   by: placement(layer)) {
                RigControllerHandle(state: state, controllerID: controller.id, name: controller.name,
                                    point: point, fit: fit)
                    .allowsHitTesting(!controller.isLocked)
            }
        }
    }
}

private struct RigControllerHandle: View {
    @ObservedObject var state: EditorState
    let controllerID: UUID
    let name: String
    let point: Vec2
    let fit: CGRect
    @State private var start: Vec2?
    @GestureState private var dragging = false

    var body: some View {
        let scale = fit.width / CGFloat(max(1, state.project.width))
        Group {
            Circle().stroke(Theme.warning, lineWidth: 2)
                .background(Circle().fill(.black.opacity(0.35)))
                .frame(width: 22, height: 22)
                .frame(width: 44, height: 44).contentShape(Rectangle())
                .position(x: fit.minX + CGFloat(point.x) * scale, y: fit.minY + CGFloat(point.y) * scale)
                .onTapGesture {
                    state.select(controllerID)
                }
                .highPriorityGesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .updating($dragging) { _, active, _ in active = true }
                    .onChanged { value in
                        if start == nil {
                            start = point
                            if state.selectedLayerID != controllerID { state.select(controllerID) }
                            state.pause()
                            state.beginEdit("Pose IK")
                            state.beginLiveGesture()
                        }
                        guard let start else { return }
                        let target = start + Vec2(Double(value.translation.width / scale), Double(value.translation.height / scale))
                        state.poseIKController(controllerID, atCanvas: target)
                    }
                    .onEnded { _ in finish() })
                .onChange(of: dragging) { _, active in if !active { finish() } }
                .onDisappear { finish() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Pose \(name)")
                .accessibilityValue(String(format: "%.1f, %.1f", point.x, point.y))
                .accessibilityHint("Drag the target to pose its connected limb")
        }
    }

    private func finish() {
        guard start != nil else { return }
        start = nil
        state.endLiveGesture()
        state.endEdit()
    }
}
