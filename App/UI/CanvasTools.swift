import SwiftUI
import simd

// MARK: - R2 canvas tools: guides, snapping math, orient along path, arrange, picking, aiming

/// A user guide line on the canvas (comp px). `vertical` = a line at x = value.
struct CanvasGuide: Codable, Equatable, Identifiable {
    var id = UUID()
    var vertical: Bool
    var value: Double
}

enum CanvasSnap {
    /// Lines of an n-division grid over `length` (both edges included).
    static func gridLines(divisions n: Int, length: Double) -> [Double] {
        let n = max(1, n)
        return (0...n).map { Double($0) * length / Double(n) }
    }

    /// Scale snaps to whole 5 % steps when it is within `grab` % of one (100 %, 150 %…); otherwise free.
    static func snapScale(_ s: Double, grab: Double = 1.0) -> Double {
        let r = (s / 5).rounded() * 5
        return abs(s - r) < grab ? r : s
    }

    /// Rotation in fixed steps (15 degrees by default) while rotation snapping is on.
    static func snapRotation(_ r: Double, step: Double = 15) -> Double { (r / step).rounded() * step }
}

/// Orient Along Path (AE Auto-Orient): the layer turns with the direction it travels along its position path.
enum AutoOrient {
    /// Travel direction (degrees, 0 = moving right, clockwise like Rotation) at `t`; nil without a moving path.
    static func angle(_ pos: Animated<Vec2>, at t: Double) -> Double? {
        let ks = pos.keyframes
        guard ks.count >= 2, let lo = ks.first?.time, let hi = ks.last?.time, hi > lo else { return nil }
        let tc = min(max(t, lo), hi)
        let h = 1.0 / 240
        func dir(_ w: Double) -> Vec2 { pos.value(at: min(hi, tc + w)) - pos.value(at: max(lo, tc - w)) }
        var d = dir(h)
        // Holding still (or at an end): widen the look until it finds the direction it came from / goes to.
        var w = h
        while hypot(d.x, d.y) < 1e-6 && w < hi - lo { w *= 2; d = dir(w) }
        guard hypot(d.x, d.y) > 1e-6 else { return nil }
        return atan2(d.y, d.x) * 180 / .pi
    }

    /// Bakes orientation into Rotation for this frame (runs before parenting, so a parent's turn still adds on).
    static func apply(_ p: Project, time: Double) -> Project {
        guard p.layers.contains(where: { $0.transform.autoOrient }) else { return p }
        var q = p
        for i in q.layers.indices where q.layers[i].transform.autoOrient {
            guard let a = angle(q.layers[i].transform.position, at: time) else { continue }
            q.layers[i].transform.rotation = Animated(q.layers[i].transform.rotation.value(at: time) + a)
        }
        return q
    }
}

/// Motion path handles: where a key's spatial handles sit when it has none yet (a smooth pass through the key).
enum MotionPathHandles {
    static func defaultTangent(_ ks: [Keyframe<Vec2>], _ k: Int) -> Vec2 {
        guard ks.indices.contains(k), ks.count > 1 else { return Vec2(40, 0) }
        let prev = ks[max(0, k - 1)].value, next = ks[min(ks.count - 1, k + 1)].value
        var d = (next - prev) * (k == 0 || k == ks.count - 1 ? 1.0 / 3.0 : 1.0 / 6.0)
        if hypot(d.x, d.y) < 1e-6 { d = Vec2(40, 0) }
        return d
    }

    /// Sets one side of key k's spatial handle; the other side mirrors it (keeping its own length). A handle dragged
    /// back onto the key (shorter than `clear` px) removes both: that key's path is straight again.
    static func setHandle(_ a: inout Animated<Vec2>, key k: Int, out: Bool, tangent: Vec2, clear: Double = 2) {
        guard a.keyframes.indices.contains(k) else { return }
        let len = hypot(tangent.x, tangent.y)
        if len < clear { a.keyframes[k].spatialIn = nil; a.keyframes[k].spatialOut = nil; return }
        let other = out ? a.keyframes[k].spatialIn : a.keyframes[k].spatialOut
        let ol = other.map { hypot($0.x, $0.y) } ?? len
        let mirrored = tangent * (-(ol > 1e-6 ? ol : len) / len)
        if out { a.keyframes[k].spatialOut = tangent; a.keyframes[k].spatialIn = mirrored }
        else { a.keyframes[k].spatialIn = tangent; a.keyframes[k].spatialOut = mirrored }
    }
}

/// Canvas tap picking: tapping the same spot again steps down to the next layer under the finger.
enum CanvasPick {
    /// `hits` top first. Same spot and the current layer is among them: the one below it (wrapping). Else the top one.
    static func next(hits: [UUID], current: UUID?, sameSpot: Bool) -> UUID? {
        guard !hits.isEmpty else { return nil }
        if sameSpot, let c = current, let i = hits.firstIndex(of: c) { return hits[(i + 1) % hits.count] }
        return hits[0]
    }

    /// Layers whose drawn bounds meet the marquee rectangle (comp px), top first.
    static func marquee(_ rect: CGRect, bounds: [(UUID, CGRect)]) -> [UUID] {
        bounds.filter { $0.1.intersects(rect) }.map(\.0)
    }
}

/// Aiming a 3D camera / light at a point: rotation X/Y that make its +Z axis point at `target` (Z kept).
enum Aim {
    static func angles(from c: SIMD3<Double>, to target: SIMD3<Double>, rotationZ rz: Double) -> (x: Double, y: Double)? {
        var d = target - c
        let len = simd_length(d)
        guard len > 1e-6 else { return nil }
        d /= len
        // Undo the Z turn (applied last), then solve Y * X * (0, 0, 1) = (sin y cos x, -sin x, cos y cos x).
        let r = -rz * .pi / 180
        let dx = d.x * cos(r) - d.y * sin(r), dy = d.x * sin(r) + d.y * cos(r)
        let rx = -asin(max(-1, min(1, dy)))
        let ry = atan2(dx, d.z)
        return (rx * 180 / .pi, ry * 180 / .pi)
    }

    /// Where a camera / light looking along its +Z axis hits the z = 0 plane (comp px), if it looks toward it.
    static func planeHit(_ l: Layer, time t: Double) -> Vec2? {
        let tr = l.transform
        let p = tr.position.value(at: t)
        let c = SIMD3(p.x, p.y, tr.positionZ.value(at: t))
        let dir = CameraState.rotation(x: tr.rotationX.value(at: t), y: tr.rotationY.value(at: t), z: tr.rotation.value(at: t)) * SIMD4(0, 0, 1, 0)
        guard abs(dir.z) > 1e-6 else { return nil }
        let k = -c.z / dir.z
        guard k > 0 else { return nil }
        return Vec2(c.x + dir.x * k, c.y + dir.y * k)
    }
}

enum AlignEdge: Int, CaseIterable, Identifiable {
    case left, hCenter, right, top, vCenter, bottom
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .left: return "Left"
        case .hCenter: return "Horizontal Center"
        case .right: return "Right"
        case .top: return "Top"
        case .vCenter: return "Vertical Center"
        case .bottom: return "Bottom"
        }
    }
    var symbol: String {
        switch self {
        case .left: return "align.horizontal.left"
        case .hCenter: return "align.horizontal.center"
        case .right: return "align.horizontal.right"
        case .top: return "align.vertical.top"
        case .vCenter: return "align.vertical.center"
        case .bottom: return "align.vertical.bottom"
        }
    }

    /// Screen move that puts `rect` on this edge of `target`.
    func delta(_ rect: CGRect, to target: CGRect) -> Vec2 {
        switch self {
        case .left: return Vec2(Double(target.minX - rect.minX), 0)
        case .hCenter: return Vec2(Double(target.midX - rect.midX), 0)
        case .right: return Vec2(Double(target.maxX - rect.maxX), 0)
        case .top: return Vec2(0, Double(target.minY - rect.minY))
        case .vCenter: return Vec2(0, Double(target.midY - rect.midY))
        case .bottom: return Vec2(0, Double(target.maxY - rect.maxY))
        }
    }
}

enum Arrange {
    /// Even spacing of centres between the outermost two (sorted along the axis). Returns screen moves per layer.
    static func distribute(_ items: [(UUID, CGRect)], horizontal: Bool) -> [UUID: Vec2] {
        guard items.count >= 3 else { return [:] }
        let sorted = items.sorted { horizontal ? $0.1.midX < $1.1.midX : $0.1.midY < $1.1.midY }
        let first = Double(horizontal ? sorted.first!.1.midX : sorted.first!.1.midY)
        let last = Double(horizontal ? sorted.last!.1.midX : sorted.last!.1.midY)
        var out: [UUID: Vec2] = [:]
        for (k, item) in sorted.enumerated() {
            let want = first + (last - first) * Double(k) / Double(sorted.count - 1)
            let now = Double(horizontal ? item.1.midX : item.1.midY)
            out[item.0] = horizontal ? Vec2(want - now, 0) : Vec2(0, want - now)
        }
        return out
    }

    /// Uniform scale (%) that fits (or fills) a layer's unscaled size into the comp.
    static func fitScale(halfSize hs: Vec2, comp: Vec2, fill: Bool) -> Double {
        guard hs.x > 1e-6, hs.y > 1e-6 else { return 100 }
        let kx = comp.x / (hs.x * 2), ky = comp.y / (hs.y * 2)
        return (fill ? max(kx, ky) : min(kx, ky)) * 100
    }
}

// MARK: - Editor actions

extension EditorState {
    private var arrangeIDs: Set<UUID> { multiSelection ?? selectedLayerID.map { Set([$0]) } ?? [] }

    /// Align: with two or more layers selected they line up with each other (the selection's bounds);
    /// one layer aligns to the comp. One undo step.
    func align(_ edge: AlignEdge) {
        let ids = arrangeIDs, original = project, t = currentTime
        let items = original.layers.filter { ids.contains($0.id) && !$0.isLocked }
            .compactMap { l in LayerPlacement.bounds(l, project: original, time: t).map { (l, $0) } }
        guard !items.isEmpty else { return }
        let comp = CGRect(x: 0, y: 0, width: Double(original.width), height: Double(original.height))
        let target = items.count > 1 ? items.map(\.1).reduce(items[0].1) { $0.union($1) } : comp
        mutate(items.count > 1 ? "Align Layers" : "Align to Canvas") { p in
            for (l, rect) in items {
                guard let i = p.layers.firstIndex(where: { $0.id == l.id }),
                      let v = LayerPlacement.movedPosition(l, project: original, time: t, screenDelta: edge.delta(rect, to: target)) else { continue }
                p.layers[i].transform.position.set(v, at: t)
            }
        }
    }

    /// Distribute three or more selected layers evenly (centres), horizontally or vertically.
    func distribute(horizontal: Bool) {
        let ids = arrangeIDs, original = project, t = currentTime
        let layers = original.layers.filter { ids.contains($0.id) && !$0.isLocked }
        let items = layers.compactMap { l in LayerPlacement.bounds(l, project: original, time: t).map { (l.id, $0) } }
        let moves = Arrange.distribute(items, horizontal: horizontal)
        guard !moves.isEmpty else { return }
        mutate("Distribute Layers") { p in
            for l in layers {
                guard let d = moves[l.id], let i = p.layers.firstIndex(where: { $0.id == l.id }),
                      let v = LayerPlacement.movedPosition(l, project: original, time: t, screenDelta: d) else { continue }
                p.layers[i].transform.position.set(v, at: t)
            }
        }
    }

    /// Fit (whole layer visible) or Fill (no empty edges) the comp, centred. One undo step.
    func fitToComp(fill: Bool) {
        guard let i = selectedIndex, !project.layers[i].isLocked else { return }
        let t = currentTime
        let l = project.layers[i]
        let k = Arrange.fitScale(halfSize: Renderer.layerHalfSize(l, time: t), comp: Vec2(Double(project.width), Double(project.height)), fill: fill)
        var scaled = project
        scaled.layers[i].transform.scale.set(Vec2(k, k), at: t)
        scaled.layers[i].transform.rotation.set(0, at: t)
        let comp = CGRect(x: 0, y: 0, width: Double(project.width), height: Double(project.height))
        var position = scaled.layers[i].transform.position.value(at: t)
        if let rect = LayerPlacement.bounds(scaled.layers[i], project: scaled, time: t),
           let v = LayerPlacement.movedPosition(scaled.layers[i], project: scaled, time: t, screenDelta: Vec2(Double(comp.midX - rect.midX), Double(comp.midY - rect.midY))) {
            position = v
        }
        mutate(fill ? "Fill Comp" : "Fit to Comp") { p in
            p.layers[i].transform.scale.set(Vec2(k, k), at: t)
            p.layers[i].transform.rotation.set(0, at: t)
            p.layers[i].transform.position.set(position, at: t)
        }
    }

    /// Pivot back to the layer's centre; the layer stays where it is (position compensates).
    func centerAnchor() {
        guard let i = selectedIndex else { return }
        let t = currentTime, l = project.layers[i]
        let moved = CanvasHandles.pivotCompensated(l.transform, is3D: l.is3D, newAnchor: .zero, time: t)
        mutate("Center Anchor") { p in
            p.layers[i].transform.anchor.set(.zero, at: t)
            p.layers[i].transform.position.set(moved.position, at: t)
            if l.is3D { p.layers[i].transform.positionZ.set(moved.z, at: t) }
        }
    }

    /// Reset Transform: centred, 100 %, no turn, pivot at the centre (keys of those properties cleared). Opacity stays.
    func resetTransform() {
        guard let i = selectedIndex else { return }
        let center = project.layers[i].parentID == nil ? Vec2(Double(project.width) / 2, Double(project.height) / 2) : .zero
        mutate("Reset Transform") { p in
            var tr = p.layers[i].transform
            tr.position = Animated(center)
            tr.anchor = Animated(.zero)
            tr.scale = Animated(Vec2(100, 100))
            tr.rotation = Animated(0)
            tr.rotationX = Animated(0); tr.rotationY = Animated(0)
            tr.positionZ = Animated(0)
            tr.autoOrient = false
            p.layers[i].transform = tr
        }
    }

    func setAutoOrient(_ on: Bool) {
        guard let i = selectedIndex else { return }
        mutate(on ? "Orient Along Path" : "Orient Off") { $0.layers[i].transform.autoOrient = on }
    }

    // MARK: guides

    var guides: [CanvasGuide] { project.guides ?? [] }

    func addGuide(vertical: Bool) {
        let v = vertical ? Double(project.width) / 2 : Double(project.height) / 2
        showGuides = true
        mutate("Add Guide") { p in p.guides = (p.guides ?? []) + [CanvasGuide(vertical: vertical, value: v)] }
    }

    func clearGuides() { mutate("Clear Guides") { $0.guides = nil } }

    /// Moves a guide while dragging (inside an edit group). Off the comp = removed when the drag ends.
    func moveGuide(_ id: UUID, to value: Double) {
        guard var g = project.guides, let k = g.firstIndex(where: { $0.id == id }) else { return }
        g[k].value = (value * 2).rounded() / 2
        var p = project
        p.guides = g
        project = p
    }

    func finishGuideDrag(_ id: UUID) {
        if var g = project.guides, let k = g.firstIndex(where: { $0.id == id }) {
            let limit = g[k].vertical ? Double(project.width) : Double(project.height)
            if g[k].value < 0 || g[k].value > limit {
                g.remove(at: k)
                var p = project
                p.guides = g.isEmpty ? nil : g
                project = p
            }
        }
        endEdit()
    }

    /// Snap targets that the move tool adds (guides, grid, other layers' anchors), comp px.
    func extraSnapTargets(view: Project, time t: Double) -> (xs: [Double], ys: [Double]) {
        var xs: [Double] = [], ys: [Double] = []
        if showGuides {
            for g in guides { if g.vertical { xs.append(g.value) } else { ys.append(g.value) } }
        }
        if showGrid && snapToGrid {
            xs += CanvasSnap.gridLines(divisions: gridDivisions, length: Double(project.width))
            ys += CanvasSnap.gridLines(divisions: gridDivisions, length: Double(project.height))
        }
        for o in view.layers where o.id != selectedLayerID && o.isActive(at: t) && o.content != .camera && !o.isAudioOnly
            && !(multiSelection?.contains(o.id) ?? false) {
            if let a = LayerPlacement.projected(o.transform.position.value(at: t), by: LayerPlacement.positionMatrix(o, project: view, time: t)) {
                xs.append(a.x); ys.append(a.y)
            }
        }
        return (xs, ys)
    }

    // MARK: aiming

    /// Points the selected camera / light at a comp point on the z = 0 plane (point of interest). Inside an edit group.
    func aimSelected(atComp c: Vec2) {
        guard let l = selectedLayer, l.content == .camera || l.content == .light else { return }
        let t = currentTime, tr = l.transform
        let p = tr.position.value(at: t)
        guard let a = Aim.angles(from: SIMD3(p.x, p.y, tr.positionZ.value(at: t)), to: SIMD3(c.x, c.y, 0), rotationZ: tr.rotation.value(at: t)) else { return }
        mutateLayer { layer in
            layer.transform.rotationX.set((a.x * 10).rounded() / 10, at: t)
            layer.transform.rotationY.set((a.y * 10).rounded() / 10, at: t)
        }
    }

    /// Canvas pick for the camera's Focus on a Layer.
    func pickCameraFocus() {
        beginLayerPick(returnTo: .threeD, prompt: "Tap the layer to focus on") { [weak self] id in
            guard let self, let id else { return }
            self.focusCamera(on: id)
        }
    }

    /// Canvas picks for Make IK (upper limb / controller).
    func pickIKUpper() {
        beginLayerPick(returnTo: .rig, prompt: "Tap the upper limb") { [weak self] id in self?.ikDraftUpper = id }
    }

    func pickIKController() {
        beginLayerPick(returnTo: .rig, prompt: "Tap the controller") { [weak self] id in self?.ikDraftController = id }
    }
}
