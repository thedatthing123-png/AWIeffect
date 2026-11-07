import SwiftUI
import simd

/// Puppet Pins editing: pins live on the selected layer's "Puppet Pins" effect, in layer pixels
/// (rest point + dragged point). The canvas adds / drags pins while the Puppet panel is open.
extension EditorState {
    var puppetEffectIndex: Int? { selectedLayer?.effects.firstIndex { $0.typeID == EffectRegistry.puppet18.id } }

    /// Pins of the selected layer at the playhead: (rest, dragged) in layer px.
    var puppetPins: [(rest: Vec2, current: Vec2)] {
        guard let l = selectedLayer, let j = puppetEffectIndex else { return [] }
        return EffectRegistry.puppetPins(l.effects[j], currentTime).map { (Vec2(Double($0.x), Double($0.y)), Vec2(Double($0.z), Double($0.w))) }
    }

    func ensurePuppet() {
        guard puppetEffectIndex == nil, let i = selectedIndex else { return }
        mutate("Add Puppet Pins") { $0.layers[i].effects.insert(EffectRegistry.puppet18.makeInstance(), at: 0) }
    }

    /// Comp point -> the selected layer's local px (where its pixels are, before the puppet warp).
    func layerLocal(fromComp c: Vec2) -> Vec2? {
        guard let id = selectedLayerID, let M = displayPlacement(of: id) else { return nil }
        let h = M.inverse * SIMD3(c.x, c.y, 1)
        guard abs(h.z) > 1e-9 else { return nil }
        return Vec2(h.x / h.z, h.y / h.z)
    }

    /// Local -> canvas placement of a layer as it is drawn: parenting, 3D and the camera of the current view
    /// (free view has none), so taps and handles line up with the picture.
    func displayPlacement(of id: UUID) -> simd_double3x3? {
        let view = canvasViewProject(project)
        guard let l = Renderer.resolveParenting(view, time: currentTime).layers.first(where: { $0.id == id }) else { return nil }
        let M = Renderer.placementMatrix(l, camera: Renderer.activeCamera(view, time: currentTime), time: currentTime, renderScale: 1)
        return abs(M.determinant) > 1e-12 ? M : nil
    }

    func compPoint(fromLocal p: Vec2) -> Vec2? {
        guard let id = selectedLayerID, let M = displayPlacement(of: id) else { return nil }
        let h = M * SIMD3(p.x, p.y, 1)
        guard abs(h.z) > 1e-9 else { return nil }
        return Vec2(h.x / h.z, h.y / h.z)
    }

    /// Drops a pin where the finger is (on the image as it currently looks).
    func addPuppetPin(atComp c: Vec2) {
        ensurePuppet()
        guard let i = selectedIndex, let j = puppetEffectIndex, let local = layerLocal(fromComp: c) else { return }
        let n = puppetPins.count
        guard n < 32 else { return }
        mutate("Add Pin") { p in
            p.layers[i].effects[j].params["pinR\(n)"] = .point(Animated(local))
            p.layers[i].effects[j].params["pinD\(n)"] = .point(Animated(local))
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Index of the pin nearest the finger (within reach), by its on-screen spot.
    func puppetPin(nearComp c: Vec2, reach: Double) -> Int? {
        var best: (Int, Double)?
        for (k, pin) in puppetPins.enumerated() {
            guard let s = compPoint(fromLocal: pin.current) else { continue }
            let d = hypot(s.x - c.x, s.y - c.y)
            if d < reach, d < (best?.1 ?? .infinity) { best = (k, d) }
        }
        return best?.0
    }

    /// Drags pin `k` to a comp point (keyframed at the playhead when Animate is on). Use inside beginEdit/endEdit.
    func movePuppetPin(_ k: Int, toComp c: Vec2) {
        guard let local = layerLocal(fromComp: c) else { return }
        setPuppetPin(k, local: local)
    }

    func setPuppetPin(_ k: Int, local: Vec2) {
        guard selectedIndex != nil, let j = puppetEffectIndex, local.x.isFinite, local.y.isFinite else { return }
        let t = currentTime, animate = puppetAnimate
        mutateLayer { l in
            guard case .point(var a) = l.effects[j].params["pinD\(k)"] else { return }
            if animate || a.isAnimated { a.insertKeyframe(Keyframe(time: t, value: local, interpolation: .bezier, easeOut: .easyOut, easeIn: .easyIn)) }
            else { a = Animated(local) }
            l.effects[j].params["pinD\(k)"] = .point(a)
        }
    }

    /// Starch pin: holds the area around it rigid (AE's Starch pin).
    func isPuppetStarch(_ k: Int) -> Bool {
        guard let l = selectedLayer, let j = puppetEffectIndex else { return false }
        return (l.effects[j].params["pinS\(k)"]?.number(at: currentTime) ?? 0) > 0.5
    }

    func togglePuppetStarch(_ k: Int) {
        guard let i = selectedIndex, let j = puppetEffectIndex else { return }
        let on = !isPuppetStarch(k)
        mutate(on ? "Starch Pin" : "Bend Pin") { p in p.layers[i].effects[j].params["pinS\(k)"] = .number(Animated(on ? 1 : 0)) }
    }

    func removePuppetPin(_ k: Int) {
        guard let i = selectedIndex, let j = puppetEffectIndex else { return }
        let pins = project.layers[i].effects[j].params
        mutate("Remove Pin") { p in
            var params = pins.filter { !$0.key.hasPrefix("pinR") && !$0.key.hasPrefix("pinD") && !$0.key.hasPrefix("pinS") }
            var n = 0, src = 0
            while let r = pins["pinR\(src)"] {
                if src != k {
                    params["pinR\(n)"] = r
                    params["pinD\(n)"] = pins["pinD\(src)"] ?? r
                    if let s = pins["pinS\(src)"] { params["pinS\(n)"] = s }
                    n += 1
                }
                src += 1
            }
            p.layers[i].effects[j].params = params
        }
    }

    /// Puts every pin back to rest at the playhead (keeps the pins).
    func resetPuppetPose() {
        guard let i = selectedIndex, let j = puppetEffectIndex else { return }
        let t = currentTime
        mutate("Reset Pose") { p in
            var k = 0
            while case .point(let r)? = p.layers[i].effects[j].params["pinR\(k)"] {
                if case .point(var d)? = p.layers[i].effects[j].params["pinD\(k)"], d.isAnimated {
                    d.insertKeyframe(Keyframe(time: t, value: r.staticValue, interpolation: .bezier))
                    p.layers[i].effects[j].params["pinD\(k)"] = .point(d)
                } else {
                    p.layers[i].effects[j].params["pinD\(k)"] = .point(r)
                }
                k += 1
            }
        }
    }
}

/// Puppet panel: how-to, Animate switch, pins list.
struct PuppetPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Puppet Pins")
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tap the layer to drop pins (e.g. hair root, hair tip, shoulder, hand). Drag a pin to bend the image around it. Pins you don't move hold their area still.")
                        .font(.caption).foregroundStyle(Theme.textDim)
                    Picker("", selection: $state.puppetPlace) {
                        Label("Place Pins", systemImage: "pin.fill").tag(true)
                        Label("Move Pins", systemImage: "hand.draw.fill").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Text(state.puppetPlace ? "Tap the layer to drop pins. Switch to Move when you're done so you can drag them without adding new ones."
                         : "Pins stay where they are: drag any pin to bend the layer. Taps never add pins here.")
                        .font(.caption2).foregroundStyle(Theme.textDim)
                    Toggle("Animate (each drag sets a keyframe at the playhead)", isOn: $state.puppetAnimate)
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                    if let j = state.puppetEffectIndex, let e = state.selectedLayer?.effects[j] {
                        HStack {
                            Text("Stiffness").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 80, alignment: .leading)
                            ValueScrubber(value: e.number("stiffness", state.currentTime), range: 0.5...3, step: 0.05,
                                          onBegin: { state.beginEdit("Stiffness") },
                                          onChange: { v in state.setEffectParam(e.id, "stiffness") { pv, t in if case .number(var a) = pv { a.set(v, at: t); pv = .number(a) } } },
                                          onEnd: { state.endEdit() })
                        }
                    }
                    let pins = state.puppetPins
                    HStack {
                        Text("\(pins.count) pin\(pins.count == 1 ? "" : "s")").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                        Spacer()
                        Button("Reset Pose") { state.resetPuppetPose() }.disabled(pins.isEmpty)
                    }
                    ForEach(pins.indices, id: \.self) { k in
                        VStack(spacing: 4) {
                        HStack {
                            if let j = state.puppetEffectIndex, let effect = state.selectedLayer?.effects[j] {
                                let status = state.effectParamHasKeyframe(effect.id, "pinD\(k)")
                                KeyframeDiamond(filled: status.filled, animated: status.animated) {
                                    state.toggleEffectKeyframe(effect.id, "pinD\(k)")
                                }.accessibilityLabel("Pin \(k + 1) keyframe")
                                Button {
                                    state.graphEffect = GraphEffectTarget(effect: effect.id, key: "pinD\(k)"); state.panel = .graph
                                } label: { Image(systemName: "point.topleft.down.to.point.bottomright.curvepath") }
                                .disabled((effect.params["pinD\(k)"]?.keyframeTimes.count ?? 0) < 2)
                                .accessibilityLabel("Pin \(k + 1) easing")
                            }
                            Image(systemName: "pin.fill").foregroundStyle(Theme.warning)
                            Text("Pin \(k + 1)").font(.system(size: 13)).foregroundStyle(Theme.text)
                            Spacer()
                            Button { state.togglePuppetStarch(k) } label: {
                                Text(state.isPuppetStarch(k) ? "Starch" : "Bend")
                                    .font(.system(size: 11, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(state.isPuppetStarch(k) ? Theme.accent : Theme.raised))
                                    .foregroundStyle(state.isPuppetStarch(k) ? Color.white : Theme.text)
                            }
                            .buttonStyle(.plain)
                            Button(role: .destructive) { state.removePuppetPin(k) } label: { Image(systemName: "trash") }
                        }
                        HStack {
                            NumberField(value: pins[k].current.x, label: "X") { value in
                                state.beginEdit("Move Pin"); state.setPuppetPin(k, local: Vec2(value,pins[k].current.y)); state.endEdit()
                            }
                            NumberField(value: pins[k].current.y, label: "Y") { value in
                                state.beginEdit("Move Pin"); state.setPuppetPin(k, local: Vec2(pins[k].current.x,value)); state.endEdit()
                            }
                        }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
        .onAppear {
            state.ensurePuppet()
            // Open in Move when the layer already has pins, so the first touch never adds one by accident.
            state.puppetPlace = state.puppetPins.isEmpty
        }
    }
}

/// Pins drawn on the canvas while the Puppet panel is open.
struct PuppetOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect

    var body: some View {
        let s = fit.width / CGFloat(max(state.project.width, 1))
        Canvas { ctx, _ in
            for pin in state.puppetPins {
                guard let c = state.compPoint(fromLocal: pin.current) else { continue }
                let pt = CGPoint(x: fit.minX + CGFloat(c.x) * s, y: fit.minY + CGFloat(c.y) * s)
                let r: CGFloat = 9
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(Theme.warning))
                ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(.black), lineWidth: 1.5)
            }
        }
        .allowsHitTesting(false)
    }
}


// MARK: - Mask points on the canvas

extension EditorState {
    /// (mask index, vertex index) of the mask point nearest the finger, within reach.
    func maskPoint(nearComp c: Vec2, reach: Double) -> (Int, Int)? {
        guard let l = selectedLayer else { return nil }
        var best: (Int, Int, Double)?
        for (mi, m) in l.masks.enumerated() {
            for (vi, v) in m.path.value(at: currentTime).vertices.enumerated() {
                guard let s = compPoint(fromLocal: v.point) else { continue }
                let d = hypot(s.x - c.x, s.y - c.y)
                if d < reach, d < (best?.2 ?? .infinity) { best = (mi, vi, d) }
            }
        }
        return best.map { ($0.0, $0.1) }
    }

    /// Moves one mask point (keyframed at the playhead when the mask path is animated). Use inside beginEdit/endEdit.
    func moveMaskPoint(mask mi: Int, vertex vi: Int, toComp c: Vec2) {
        guard let local = layerLocal(fromComp: c) else { return }
        let t = currentTime
        mutateLayer { l in
            guard l.masks.indices.contains(mi) else { return }
            var path = l.masks[mi].path.value(at: t)
            guard path.vertices.indices.contains(vi) else { return }
            path.vertices[vi].point = local
            if l.masks[mi].path.isAnimated {
                l.masks[mi].path.insertKeyframe(Keyframe(time: t, value: path, interpolation: .bezier, easeOut: .easyOut, easeIn: .easyIn))
            } else {
                l.masks[mi].path = Animated(path)
            }
        }
    }
}

/// Mask outlines + draggable points while the Masks panel is open.
struct MaskPointsOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect

    var body: some View {
        let s = fit.width / CGFloat(max(state.project.width, 1))
        Canvas { ctx, _ in
            guard let l = state.selectedLayer, let id = state.selectedLayerID, let M = state.displayPlacement(of: id) else { return }
            func toScreen(_ v: Vec2) -> CGPoint { CGPoint(x: fit.minX + CGFloat(v.x) * s, y: fit.minY + CGFloat(v.y) * s) }
            let project: (Vec2) -> Vec2? = { LayerPlacement.projected($0, by: M) }
            for m in l.masks {
                let path = m.path.value(at: state.currentTime)
                let pts = path.vertices.compactMap { project($0.point) }.map(toScreen)
                // The outline follows the mask's curves (sampled through the layer's placement, so 3D is right too).
                let curve = Self.outline(path, project: project).map(toScreen)
                guard curve.count > 1 else { continue }
                var outline = Path(); outline.addLines(curve); if path.closed { outline.closeSubpath() }
                ctx.stroke(outline, with: .color(m.effectsOnly ? Theme.warning : Theme.accentGlow), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                for p in pts {
                    // Small squares: they must not hide the layer's transform handles.
                    let r: CGFloat = 5
                    ctx.fill(Path(CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white))
                    ctx.stroke(Path(CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.black), lineWidth: 1.5)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Mask path sampled along its bezier segments (local px -> `project`), closing back to the first point.
    static func outline(_ path: BezierPath, project: (Vec2) -> Vec2?, steps: Int = 16) -> [Vec2] {
        let v = path.vertices
        guard v.count > 1 else { return v.compactMap { project($0.point) } }
        var out: [Vec2] = []
        let segments = path.closed ? v.count : v.count - 1
        for i in 0..<segments {
            let a = v[i], b = v[(i + 1) % v.count]
            let p0 = a.point, p1 = a.point + a.outTangent, p2 = b.point + b.inTangent, p3 = b.point
            for k in 0..<steps {
                let t = Double(k) / Double(steps), u = 1 - t
                let q = p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
                if let w = project(q) { out.append(w) }
            }
        }
        if !path.closed, let last = v.last, let w = project(last.point) { out.append(w) }
        return out
    }
}
