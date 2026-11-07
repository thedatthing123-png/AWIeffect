import SwiftUI
import simd

// MARK: - Mask editing model (R2)
//
// Masks are edited right on the canvas while the Masks panel is open:
// - tap a point to select it (its curve handles appear), drag it to move it;
// - drag a curve handle: smooth points keep both sides in line, broken (corner) points move one side only;
// - tap on the outline to add a point there (the curve keeps its shape), drag the outline to move the whole mask;
// - the mask card edits the selected point (Corner / Smooth / Broken, Delete) and scales / rotates the whole mask.

/// The mask point being edited (selected layer's mask `maskID`, vertex index). `broken` = handles move independently.
struct MaskSelection: Equatable {
    var maskID: UUID
    var vertex: Int
    var broken: Bool = false
}

enum MaskHandleSide: Equatable { case inTangent, outTangent }

/// What a finger landed on, in mask-index space of the selected layer.
enum MaskCanvasHit: Equatable {
    case point(mask: Int, vertex: Int)
    case handle(mask: Int, vertex: Int, side: MaskHandleSide)
    case segment(mask: Int, segment: Int, t: Double)
}

/// One canvas drag on a mask. `hit == nil`: the finger missed every mask, so the drag goes to the layer.
struct MaskDragSession {
    var hit: MaskCanvasHit?
    var base: BezierPath?
    var startComp: Vec2
}

/// How a mask point's curve handles behave.
enum MaskPointKind: String, CaseIterable, Identifiable {
    case corner, smooth, broken
    var id: String { rawValue }
    var title: String {
        switch self {
        case .corner: return "Corner"
        case .smooth: return "Smooth"
        case .broken: return "Broken"
        }
    }
    var symbol: String {
        switch self {
        case .corner: return "square"
        case .smooth: return "circle"
        case .broken: return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

extension BezierPath {
    /// Cubic segment i (from vertex i to the next) as its four control points.
    func segmentControls(_ i: Int) -> (Vec2, Vec2, Vec2, Vec2)? {
        let n = vertices.count
        guard n > 1, i >= 0, i < (closed ? n : n - 1) else { return nil }
        let a = vertices[i], b = vertices[(i + 1) % n]
        return (a.point, a.point + a.outTangent, b.point + b.inTangent, b.point)
    }

    var segmentCount: Int { vertices.count < 2 ? 0 : (closed ? vertices.count : vertices.count - 1) }

    func point(onSegment i: Int, t: Double) -> Vec2? {
        guard let (p0, p1, p2, p3) = segmentControls(i) else { return nil }
        let u = 1 - t
        return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
    }

    /// Splits segment i at t (de Casteljau) so the outline keeps exactly its shape. Returns the new vertex index.
    @discardableResult
    mutating func insertVertex(onSegment i: Int, t rawT: Double) -> Int? {
        guard let (p0, p1, p2, p3) = segmentControls(i) else { return nil }
        let t = min(max(rawT, 0.001), 0.999)
        let q0 = Vec2.lerp(p0, p1, t), q1 = Vec2.lerp(p1, p2, t), q2 = Vec2.lerp(p2, p3, t)
        let r0 = Vec2.lerp(q0, q1, t), r1 = Vec2.lerp(q1, q2, t)
        let s = Vec2.lerp(r0, r1, t)
        let n = vertices.count
        let j = (i + 1) % n
        vertices[i].outTangent = q0 - p0
        vertices[j].inTangent = q2 - p3
        let v = PathVertex(point: s, inTangent: r0 - s, outTangent: r1 - s)
        vertices.insert(v, at: i + 1)
        return i + 1
    }

    /// Removes a point; closed paths keep at least 3, open ones 2. Returns false when it can't.
    @discardableResult
    mutating func removeVertex(_ i: Int) -> Bool {
        guard vertices.indices.contains(i), vertices.count > (closed ? 3 : 2) else { return false }
        vertices.remove(at: i)
        return true
    }

    static func isSmooth(_ v: PathVertex) -> Bool {
        let a = v.inTangent, b = v.outTangent
        let la = hypot(a.x, a.y), lb = hypot(b.x, b.y)
        guard la > 1e-6, lb > 1e-6 else { return false }
        // Anti-parallel within ~2 degrees.
        return (a.x * b.x + a.y * b.y) / (la * lb) < -0.9994
    }

    func kind(of i: Int) -> MaskPointKind {
        guard vertices.indices.contains(i) else { return .corner }
        let v = vertices[i]
        if v.inTangent == .zero && v.outTangent == .zero { return .corner }
        return Self.isSmooth(v) ? .smooth : .broken
    }

    /// Smooth tangents from the neighbours (Catmull-Rom: (next - prev) / 6 on each side).
    mutating func smoothVertex(_ i: Int) {
        let n = vertices.count
        guard vertices.indices.contains(i), n > 1 else { return }
        let prev = vertices[closed ? (i - 1 + n) % n : max(0, i - 1)].point
        let next = vertices[closed ? (i + 1) % n : min(n - 1, i + 1)].point
        var d = (next - prev) * (1.0 / 6.0)
        if hypot(d.x, d.y) < 1e-6 { d = Vec2(20, 0) }
        vertices[i].outTangent = d
        vertices[i].inTangent = d * -1
    }

    mutating func setKind(_ k: MaskPointKind, at i: Int) {
        guard vertices.indices.contains(i) else { return }
        switch k {
        case .corner:
            vertices[i].inTangent = .zero; vertices[i].outTangent = .zero
        case .smooth:
            let v = vertices[i]
            let lo = hypot(v.outTangent.x, v.outTangent.y), li = hypot(v.inTangent.x, v.inTangent.y)
            if lo < 1e-6 && li < 1e-6 { smoothVertex(i); return }
            // Keep the longer handle's direction, mirror it to the other side at that side's length (or the same).
            let main = lo >= li ? v.outTangent : v.inTangent * -1
            let len = max(lo, li)
            let u = main * (1 / len)
            vertices[i].outTangent = u * (lo > 1e-6 ? lo : len)
            vertices[i].inTangent = u * -(li > 1e-6 ? li : len)
        case .broken:
            // Handles stay where they are; a corner gets a pair to pull out independently.
            if vertices[i].inTangent == .zero && vertices[i].outTangent == .zero { smoothVertex(i) }
        }
    }

    /// Moves one curve handle to `local` (layer px). Unbroken points keep the opposite handle in line (its own length).
    mutating func moveHandle(_ i: Int, side: MaskHandleSide, toLocal local: Vec2, broken: Bool) {
        guard vertices.indices.contains(i) else { return }
        let t = local - vertices[i].point
        let len = hypot(t.x, t.y)
        switch side {
        case .outTangent: vertices[i].outTangent = t
        case .inTangent: vertices[i].inTangent = t
        }
        guard !broken, len > 1e-6 else { return }
        let other = side == .outTangent ? vertices[i].inTangent : vertices[i].outTangent
        var ol = hypot(other.x, other.y)
        if ol < 1e-6 { ol = len }
        let mirrored = t * (-ol / len)
        switch side {
        case .outTangent: vertices[i].inTangent = mirrored
        case .inTangent: vertices[i].outTangent = mirrored
        }
    }

    var vertexCentroid: Vec2 {
        guard !vertices.isEmpty else { return .zero }
        return vertices.reduce(Vec2.zero) { $0 + $1.point } * (1 / Double(vertices.count))
    }

    /// Whole-path move / scale (%) / rotation (degrees) about `center`. Handles scale and rotate with their points.
    func transformed(translate: Vec2 = .zero, scale: Double = 100, rotation: Double = 0, about center: Vec2) -> BezierPath {
        let s = scale / 100, a = rotation * .pi / 180
        let c = cos(a) * s, sn = sin(a) * s
        func lin(_ v: Vec2) -> Vec2 { Vec2(v.x * c - v.y * sn, v.x * sn + v.y * c) }
        var out = self
        for k in out.vertices.indices {
            let v = vertices[k]
            out.vertices[k].point = center + lin(v.point - center) + translate
            out.vertices[k].inTangent = lin(v.inTangent)
            out.vertices[k].outTangent = lin(v.outTangent)
        }
        return out
    }

    /// Closest point of the outline to `q` measured after `map` (local -> comp): (segment, t, distance).
    func nearestSegment(to q: Vec2, map: (Vec2) -> Vec2?, steps: Int = 24) -> (Int, Double, Double)? {
        var best: (Int, Double, Double)?
        for i in 0..<segmentCount {
            for k in 0...steps {
                let t = Double(k) / Double(steps)
                guard let p = point(onSegment: i, t: t), let m = map(p) else { continue }
                let d = hypot(m.x - q.x, m.y - q.y)
                if d < (best?.2 ?? .infinity) { best = (i, t, d) }
            }
        }
        // Refine around the best sample so the inserted point lands under the finger.
        if var b = best {
            let h = 1.0 / Double(steps)
            for k in 0...10 {
                let t = max(0, min(1, b.1 - h + 2 * h * Double(k) / 10))
                guard let p = point(onSegment: b.0, t: t), let m = map(p) else { continue }
                let d = hypot(m.x - q.x, m.y - q.y)
                if d < b.2 { b = (b.0, t, d) }
            }
            best = b
        }
        return best
    }
}

// MARK: - Editor state: mask point editing

extension EditorState {
    /// Index of the selected mask in the selected layer.
    var selectedMaskIndex: Int? {
        guard let s = maskSelection, let l = selectedLayer else { return nil }
        return l.masks.firstIndex { $0.id == s.maskID }
    }

    /// Writes a mask's path at the playhead (a keyframe when the path is animated). Use inside an edit group.
    func setMaskPath(mask mi: Int, _ path: BezierPath) {
        let t = currentTime
        mutateLayer { l in
            guard l.masks.indices.contains(mi) else { return }
            if l.masks[mi].path.isAnimated {
                if let k = l.masks[mi].path.keyframeIndex(at: t) {
                    l.masks[mi].path.keyframes[k].value = path
                } else {
                    l.masks[mi].path.insertKeyframe(Keyframe(time: t, value: path, interpolation: .bezier, easeOut: .easyOut, easeIn: .easyIn))
                }
            } else {
                l.masks[mi].path = Animated(path)
            }
        }
    }

    /// Adding or removing points changes the vertex count: every key of an animated mask gets the same edit,
    /// so the path keeps animating (keyframes with different counts would jump).
    func editMaskTopology(mask mi: Int, _ label: String, _ change: (inout BezierPath) -> Void) {
        beginEdit(label)
        mutateLayer { l in
            guard l.masks.indices.contains(mi) else { return }
            if l.masks[mi].path.isAnimated {
                for k in l.masks[mi].path.keyframes.indices { change(&l.masks[mi].path.keyframes[k].value) }
            } else {
                var p = l.masks[mi].path.value(at: 0)
                change(&p)
                l.masks[mi].path = Animated(p)
            }
        }
        endEdit()
    }

    private func maskComp(_ v: Vec2) -> Vec2? { compPoint(fromLocal: v) }

    /// What is under the finger: the selected point's handles first, then points, then the outline.
    func maskCanvasHit(atComp c: Vec2, reach: Double) -> MaskCanvasHit? {
        guard let l = selectedLayer else { return nil }
        let t = currentTime
        if let s = maskSelection, let mi = l.masks.firstIndex(where: { $0.id == s.maskID }) {
            let path = l.masks[mi].path.value(at: t)
            if path.vertices.indices.contains(s.vertex) {
                let v = path.vertices[s.vertex]
                var best: (MaskHandleSide, Double)?
                for (side, tan) in [(MaskHandleSide.outTangent, v.outTangent), (.inTangent, v.inTangent)] where tan != .zero {
                    guard let q = maskComp(v.point + tan) else { continue }
                    let d = hypot(q.x - c.x, q.y - c.y)
                    if d < reach, d < (best?.1 ?? .infinity) { best = (side, d) }
                }
                if let b = best { return .handle(mask: mi, vertex: s.vertex, side: b.0) }
            }
        }
        if let (mi, vi) = maskPoint(nearComp: c, reach: reach) { return .point(mask: mi, vertex: vi) }
        var best: (Int, Int, Double, Double)?
        for (mi, m) in l.masks.enumerated() {
            let path = m.path.value(at: t)
            if let (seg, st, d) = path.nearestSegment(to: c, map: { self.maskComp($0) }), d < reach * 0.6, d < (best?.3 ?? .infinity) {
                best = (mi, seg, st, d)
            }
        }
        return best.map { .segment(mask: $0.0, segment: $0.1, t: $0.2) }
    }

    /// Starts a canvas drag on a mask (selects the point it grabbed). Opens one undo step when something was hit.
    func beginMaskDrag(atComp c: Vec2, reach: Double) -> MaskDragSession {
        let hit = maskCanvasHit(atComp: c, reach: reach)
        var base: BezierPath?
        if let hit, let l = selectedLayer {
            let mi: Int
            switch hit {
            case .point(let m, let v):
                mi = m
                let path = l.masks[m].path.value(at: currentTime)
                maskSelection = MaskSelection(maskID: l.masks[m].id, vertex: v, broken: path.kind(of: v) == .broken)
                beginEdit("Move Mask Point")
            case .handle(let m, _, _):
                mi = m; beginEdit("Mask Curve")
            case .segment(let m, _, _):
                mi = m; beginEdit("Move Mask")
            }
            base = l.masks[mi].path.value(at: currentTime)
        }
        return MaskDragSession(hit: hit, base: base, startComp: c)
    }

    func updateMaskDrag(_ s: MaskDragSession, toComp c: Vec2) {
        guard let hit = s.hit, let base = s.base, let local = layerLocal(fromComp: c) else { return }
        switch hit {
        case .point(let mi, let vi):
            moveMaskPoint(mask: mi, vertex: vi, toComp: c)
        case .handle(let mi, let vi, let side):
            var p = base
            p.moveHandle(vi, side: side, toLocal: local, broken: maskSelection?.broken ?? false)
            setMaskPath(mask: mi, p)
        case .segment(let mi, _, _):
            guard let start = layerLocal(fromComp: s.startComp) else { return }
            setMaskPath(mask: mi, base.transformed(translate: local - start, about: base.vertexCentroid))
        }
    }

    func endMaskDrag(_ s: MaskDragSession) {
        if s.hit != nil { endEdit() }
    }

    /// Tap while the Masks panel is open. A point selects it; the outline gets a new point; else clears and returns false.
    @discardableResult
    func maskTap(atComp c: Vec2, reach: Double) -> Bool {
        guard let l = selectedLayer, let hit = maskCanvasHit(atComp: c, reach: reach) else {
            maskSelection = nil
            return false
        }
        switch hit {
        case .point(let mi, let vi), .handle(let mi, let vi, _):
            let path = l.masks[mi].path.value(at: currentTime)
            maskSelection = MaskSelection(maskID: l.masks[mi].id, vertex: vi, broken: path.kind(of: vi) == .broken)
        case .segment(let mi, let seg, let t):
            editMaskTopology(mask: mi, "Add Mask Point") { _ = $0.insertVertex(onSegment: seg, t: t) }
            maskSelection = MaskSelection(maskID: l.masks[mi].id, vertex: seg + 1)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        return true
    }

    func deleteSelectedMaskPoint() {
        guard let s = maskSelection, let mi = selectedMaskIndex else { return }
        let count = selectedLayer?.masks[mi].path.value(at: currentTime).vertices.count ?? 0
        guard count > 3 else { return }
        editMaskTopology(mask: mi, "Delete Mask Point") { _ = $0.removeVertex(s.vertex) }
        maskSelection = MaskSelection(maskID: s.maskID, vertex: max(0, s.vertex - 1))
    }

    /// Inserts a point halfway along the segment after the selected point.
    func insertMaskPointAfterSelection() {
        guard let s = maskSelection, let mi = selectedMaskIndex,
              let path = selectedLayer?.masks[mi].path.value(at: currentTime), s.vertex < path.segmentCount else { return }
        editMaskTopology(mask: mi, "Add Mask Point") { _ = $0.insertVertex(onSegment: s.vertex, t: 0.5) }
        maskSelection = MaskSelection(maskID: s.maskID, vertex: s.vertex + 1)
    }

    func setSelectedMaskPointKind(_ k: MaskPointKind) {
        guard let s = maskSelection, let mi = selectedMaskIndex,
              var path = selectedLayer?.masks[mi].path.value(at: currentTime) else { return }
        path.setKind(k, at: s.vertex)
        beginEdit("Mask Point Type")
        setMaskPath(mask: mi, path)
        endEdit()
        maskSelection?.broken = k == .broken
    }

    /// Steps the selection to the previous / next point of the selected mask (no tiny targets needed).
    func stepMaskSelection(_ d: Int) {
        guard let s = maskSelection, let mi = selectedMaskIndex,
              let n = selectedLayer?.masks[mi].path.value(at: currentTime).vertices.count, n > 0 else { return }
        let v = ((s.vertex + d) % n + n) % n
        let kind = selectedLayer?.masks[mi].path.value(at: currentTime).kind(of: v)
        maskSelection = MaskSelection(maskID: s.maskID, vertex: v, broken: kind == .broken)
    }
}

// MARK: - Overlay: selected point + its curve handles

/// Draws the selected mask point and its handles on top of `MaskPointsOverlay` (which draws every outline/point).
struct MaskSelectionOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect

    /// Screen points of the selected vertex and its handle ends, worked out on the main actor before drawing.
    private var points: (point: CGPoint, handles: [CGPoint])? {
        let s = fit.width / CGFloat(max(state.project.width, 1))
        guard let sel = state.maskSelection, let mi = state.selectedMaskIndex, let l = state.selectedLayer,
              l.masks.indices.contains(mi) else { return nil }
        let path = l.masks[mi].path.value(at: state.currentTime)
        guard path.vertices.indices.contains(sel.vertex) else { return nil }
        func scr(_ v: Vec2) -> CGPoint? {
            guard let c = state.compPoint(fromLocal: v) else { return nil }
            return CGPoint(x: fit.minX + CGFloat(c.x) * s, y: fit.minY + CGFloat(c.y) * s)
        }
        let v = path.vertices[sel.vertex]
        guard let p = scr(v.point) else { return nil }
        let handles = [v.inTangent, v.outTangent].filter { $0 != .zero }.compactMap { scr(v.point + $0) }
        return (p, handles)
    }

    var body: some View {
        let pts = points
        Canvas { ctx, _ in
            guard let pts else { return }
            let p = pts.point
            for h in pts.handles {
                var line = Path(); line.move(to: p); line.addLine(to: h)
                ctx.stroke(line, with: .color(Theme.accentGlow), lineWidth: 1.5)
                let r: CGFloat = 7
                let dot = Path(ellipseIn: CGRect(x: h.x - r, y: h.y - r, width: r * 2, height: r * 2))
                ctx.fill(dot, with: .color(Theme.accent))
                ctx.stroke(dot, with: .color(.white), lineWidth: 1.5)
            }
            let r: CGFloat = 8
            let box = Path(CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.fill(box, with: .color(Theme.accent))
            ctx.stroke(box, with: .color(.white), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Mask card sections

/// Selected point tools + whole-mask scale / rotation, shown inside a mask card.
struct MaskPathEditSection: View {
    @ObservedObject var state: EditorState
    let mask: LayerMask
    @State private var base: BezierPath?

    var body: some View {
        let t = state.currentTime
        let path = mask.path.value(at: t)
        VStack(spacing: 6) {
            if let sel = state.maskSelection, sel.maskID == mask.id, path.vertices.indices.contains(sel.vertex) {
                HStack(spacing: 6) {
                    squareButton("chevron.left", "Previous") { state.stepMaskSelection(-1) }
                    Text("Point \(sel.vertex + 1) of \(path.vertices.count)")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity)
                    squareButton("chevron.right", "Next") { state.stepMaskSelection(1) }
                }
                // Point type: three choices, one row.
                HStack(spacing: 6) {
                    let kind: MaskPointKind = sel.broken && path.kind(of: sel.vertex) != .corner ? .broken : path.kind(of: sel.vertex)
                    ForEach(MaskPointKind.allCases) { k in
                        tile(k.title, k.symbol, on: kind == k) { state.setSelectedMaskPointKind(k) }
                    }
                }
                HStack(spacing: 6) {
                    tile("Add After", "plus.circle", on: false) { state.insertMaskPointAfterSelection() }
                        .disabled(sel.vertex >= path.segmentCount)
                    tile("Delete Point", "trash", on: false) { state.deleteSelectedMaskPoint() }
                        .disabled(path.vertices.count <= 3)
                }
            } else {
                Text("Tap a point to edit it · tap the outline to add a point · drag the outline to move the mask")
                    .font(.caption).foregroundStyle(Theme.textDim).frame(maxWidth: .infinity, alignment: .leading)
            }
            // Whole mask: relative scale / rotation about its centre (the bar returns to 100 % / 0° after each move).
            relRow("Scale", 100, 1...400, "%") { v, b in b.transformed(scale: v, about: b.vertexCentroid) }
            relRow("Rotate", 0, -180...180, "°") { v, b in b.transformed(rotation: v, about: b.vertexCentroid) }
        }
    }

    private func relRow(_ title: String, _ neutral: Double, _ r: ClosedRange<Double>, _ unit: String,
                        _ apply: @escaping (Double, BezierPath) -> BezierPath) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 74, alignment: .leading)
            ValueScrubber(value: neutral, range: r, step: 1, unit: unit,
                          onBegin: {
                              guard let i = state.selectedLayer?.masks.firstIndex(where: { $0.id == mask.id }) else { return }
                              base = state.selectedLayer?.masks[i].path.value(at: state.currentTime)
                              state.beginEdit("Transform Mask")
                          },
                          onChange: { v in
                              guard let b = base, let i = state.selectedLayer?.masks.firstIndex(where: { $0.id == mask.id }) else { return }
                              state.setMaskPath(mask: i, apply(v, b))
                          },
                          onEnd: { base = nil; state.endEdit() },
                          allowBeyond: true)
        }
    }

    private func squareButton(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }

    private func tile(_ title: String, _ icon: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .bold)).lineLimit(1).fixedSize()
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(on ? Theme.accent : Theme.surface))
            .foregroundStyle(on ? Color.white : Theme.text)
        }
        .buttonStyle(.plain)
    }
}
