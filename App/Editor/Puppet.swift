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
        guard let id = selectedLayerID, let l = displayProject.layers.first(where: { $0.id == id }) else { return nil }
        let M = Renderer.placementMatrix(l, camera: Renderer.activeCamera(project, time: currentTime), time: currentTime, renderScale: 1)
        let h = M.inverse * SIMD3(c.x, c.y, 1)
        guard abs(h.z) > 1e-9 else { return nil }
        return Vec2(h.x / h.z, h.y / h.z)
    }

    func compPoint(fromLocal p: Vec2) -> Vec2? {
        guard let id = selectedLayerID, let l = displayProject.layers.first(where: { $0.id == id }) else { return nil }
        let M = Renderer.placementMatrix(l, camera: Renderer.activeCamera(project, time: currentTime), time: currentTime, renderScale: 1)
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
        guard let i = selectedIndex, let j = puppetEffectIndex, let local = layerLocal(fromComp: c) else { return }
        let t = currentTime, animate = puppetAnimate
        mutateLayer { l in
            guard case .point(var a) = l.effects[j].params["pinD\(k)"] else { return }
            if animate || a.isAnimated { a.insertKeyframe(Keyframe(time: t, value: local, interpolation: .bezier, easeOut: .easyOut, easeIn: .easyIn)) }
            else { a = Animated(local) }
            l.effects[j].params["pinD\(k)"] = .point(a)
        }
        _ = i
    }

    func removePuppetPin(_ k: Int) {
        guard let i = selectedIndex, let j = puppetEffectIndex else { return }
        let pins = project.layers[i].effects[j].params
        mutate("Remove Pin") { p in
            var params = pins.filter { !$0.key.hasPrefix("pinR") && !$0.key.hasPrefix("pinD") }
            var n = 0, src = 0
            while let r = pins["pinR\(src)"] {
                if src != k {
                    params["pinR\(n)"] = r
                    params["pinD\(n)"] = pins["pinD\(src)"] ?? r
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
                        HStack {
                            Image(systemName: "pin.fill").foregroundStyle(Theme.warning)
                            Text("Pin \(k + 1)").font(.system(size: 13)).foregroundStyle(Theme.text)
                            Spacer()
                            Button(role: .destructive) { state.removePuppetPin(k) } label: { Image(systemName: "trash") }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
        .onAppear { state.ensurePuppet() }
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
