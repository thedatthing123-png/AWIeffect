import SwiftUI
import UniformTypeIdentifiers
import simd

/// Effect stacks saved as presets, kept for every project (the project carries its own copies too).
enum EffectStackLibrary {
    private static let key = "awi.effectStacks"
    private static func all() -> [String: [EffectInstance]] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let v = try? JSONDecoder().decode([String: [EffectInstance]].self, from: d) else { return [:] }
        return v
    }
    private static func write(_ v: [String: [EffectInstance]]) {
        if let d = try? JSONEncoder().encode(v) { UserDefaults.standard.set(d, forKey: key) }
    }
    static func names() -> [String] { all().keys.sorted() }
    static func save(_ name: String, _ stack: [EffectInstance]) { var a = all(); a[name] = stack; write(a) }
    static func remove(_ name: String) { var a = all(); a[name] = nil; write(a) }
    static func allNames(project: Project) -> [String] { Set(names()).union((project.effectStackPresets ?? [:]).keys).sorted() }
    static func stack(_ name: String, project: Project) -> [EffectInstance]? { project.effectStackPresets?[name] ?? all()[name] }

    /// The stack as stored: solo / group marks removed (a preset never arrives soloed or tied to an old group).
    static func cleaned(_ stack: [EffectInstance]) -> [EffectInstance] {
        stack.map { e in
            var o = e
            var t = e.text ?? [:]
            for k in ["solo", "soloMute", "stack"] { t[k] = nil }
            o.text = t.isEmpty ? nil : t
            return o
        }
    }

    /// Copies for applying: fresh ids, all marked with one group tag ("name|uuid") so they can be removed together.
    static func instances(_ stack: [EffectInstance], name: String) -> [EffectInstance] {
        let tag = "\(name)|\(UUID().uuidString)"
        return cleaned(stack).map { e in
            var o = e
            o.id = UUID()
            var t = o.text ?? [:]
            t["stack"] = tag
            o.text = t
            return o
        }
    }
    static func groupName(_ e: EffectInstance) -> String? {
        e.text?["stack"].map { String($0.split(separator: "|", maxSplits: 1).first ?? "") }
    }
}

@MainActor
extension EditorState {
    private func editEffect(_ id: UUID, _ change: (inout EffectInstance) -> Void) {
        mutateLayer { l in if let j = l.effects.firstIndex(where: { $0.id == id }) { change(&l.effects[j]) } }
    }

    // MARK: Mix

    /// Sets a number that may be missing from the effect (Mix), keyed at the playhead when animated.
    func setEffectNumberR4(_ id: UUID, _ key: String, default d: Double, _ v: Double) {
        let t = currentTime
        editEffect(id) { e in
            guard case .number(var a) = e.params[key] ?? .number(Animated(d)) else { return }
            a.set(v, at: t); e.params[key] = .number(a)
        }
    }

    func toggleEffectNumberKeyR4(_ id: UUID, _ key: String, default d: Double) {
        let t = currentTime
        beginEdit("Keyframe")
        editEffect(id) { e in
            guard case .number(var a) = e.params[key] ?? .number(Animated(d)) else { return }
            a.toggleKeyframe(at: t); e.params[key] = .number(a)
        }
        endEdit()
    }

    // MARK: Hold keys (switches and menus)

    /// Changes a switch / menu. When it has hold keys, the value is keyed at the playhead instead.
    func setHeldParamR4(_ id: UUID, _ key: String, value: Int, asParam: ParamValue, label: String) {
        let t = currentTime
        beginEdit(label)
        editEffect(id) { e in
            if !EffectStackR4.holdKeys(e, key).isEmpty { e = EffectStackR4.settingHold(e, key, value: value, at: t) }
            e.params[key] = asParam
        }
        endEdit()
    }

    /// Adds (or removes) a hold key at the playhead holding the current value.
    func toggleHoldKeyR4(_ id: UUID, _ key: String, current: Int) {
        let t = currentTime
        beginEdit("Keyframe")
        editEffect(id) { e in
            let keys = EffectStackR4.holdKeys(e, key)
            if keys.contains(where: { abs($0.time - t) < 1e-4 }) { e = EffectStackR4.removingHold(e, key, at: t) }
            else { e = EffectStackR4.settingHold(e, key, value: current, at: t) }
        }
        endEdit()
    }

    func holdState(_ e: EffectInstance, _ key: String) -> (filled: Bool, animated: Bool) {
        let k = EffectStackR4.holdKeys(e, key)
        return (k.contains { abs($0.time - currentTime) < 1e-4 }, !k.isEmpty)
    }

    // MARK: Solo, reorder

    func toggleEffectSolo(_ id: UUID) {
        guard let i = selectedIndex else { return }
        mutate("Solo Effect") { p in p.layers[i].effects = EffectStackR4.toggledSolo(p.layers[i].effects, id) }
    }

    /// Drag-to-reorder: moves the effect to sit where `target` is. One undo step.
    func moveEffect(_ id: UUID, to target: UUID) {
        guard id != target, let i = selectedIndex,
              let from = project.layers[i].effects.firstIndex(where: { $0.id == id }),
              let to = project.layers[i].effects.firstIndex(where: { $0.id == target }) else { return }
        mutate("Reorder Effect") { p in
            let e = p.layers[i].effects.remove(at: from)
            p.layers[i].effects.insert(e, at: to)
        }
    }

    // MARK: Stack presets

    func saveEffectStack(_ name: String) {
        guard let l = selectedLayer, !l.effects.isEmpty else { return }
        let stack = EffectStackLibrary.cleaned(l.effects)
        EffectStackLibrary.save(name, stack)
        mutate("Save Effect Preset") { p in var all = p.effectStackPresets ?? [:]; all[name] = stack; p.effectStackPresets = all }
    }

    func applyEffectStack(_ name: String) {
        guard let i = selectedIndex, let stack = EffectStackLibrary.stack(name, project: project) else { return }
        mutate("Apply \(name)") { p in p.layers[i].effects += EffectStackLibrary.instances(stack, name: name) }
        panel = .effects
    }

    /// Removes every effect that came in with one applied preset.
    func removeEffectGroup(_ tag: String) {
        guard let i = selectedIndex else { return }
        mutate("Remove Preset") { p in p.layers[i].effects.removeAll { $0.text?["stack"] == tag } }
    }

    // MARK: Track matte from any layer

    /// Any layer as this layer's matte (alpha / luma, inverted or not), through Set Matte; nil removes it.
    func setMatteSource(_ source: UUID?, mode: TrackMatte) {
        guard let i = selectedIndex else { return }
        mutate("Track Matte Layer") { p in
            p.layers[i].effects.removeAll { $0.typeID == "awi18.setMatte" && $0.text?["matteSource"] == "1" }
            guard let source, source != p.layers[i].id, mode != .none, let def = EffectRegistry.definition("awi18.setMatte") else { return }
            var e = def.makeInstance()
            e.params["mode"] = .choice(mode == .luma || mode == .lumaInverted ? 1 : 0)
            e.params["invert"] = .toggle(mode == .alphaInverted || mode == .lumaInverted)
            e.text = ["layer": source.uuidString, "matteSource": "1"]
            // First in the stack, like a matte (it cuts the layer before its effects draw outside it).
            p.layers[i].effects.insert(e, at: 0)
            p.layers[i].trackMatte = .none
        }
    }

    func matteSource(_ l: Layer) -> (UUID, TrackMatte)? {
        guard let e = l.effects.first(where: { $0.typeID == "awi18.setMatte" && $0.text?["matteSource"] == "1" }),
              let id = e.text?["layer"].flatMap(UUID.init(uuidString:)) else { return nil }
        let luma = e.choice("mode") == 1, inv = e.bool("invert")
        return (id, luma ? (inv ? .lumaInverted : .luma) : (inv ? .alphaInverted : .alpha))
    }
}

/// Crosshair handles on the canvas for the open effect cards' point controls and particle emitters:
/// drag to move (one undo step per drag).
struct EffectPointOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var dragging: String?

    private struct Handle: Identifiable { let id: String; let effect: UUID; let key: String; let emitter: Bool; let at: CGPoint; let name: String }

    private func mapping(_ l: Layer, _ p: Project) -> (simd_double3x3, Vec2) {
        let s = Double(fit.width) / Double(max(p.width, 1))
        let M = Renderer.placementMatrix(l, camera: Renderer.activeCamera(p, time: state.currentTime), time: state.currentTime, renderScale: s)
        return (M, Renderer.layerHalfSize(l, time: state.currentTime))
    }

    private func screen(_ local: Vec2, _ M: simd_double3x3) -> CGPoint? {
        let q = M * SIMD3(local.x, local.y, 1)
        guard abs(q.z) > 1e-8 else { return nil }
        return CGPoint(x: fit.minX + q.x / q.z, y: fit.minY + q.y / q.z)
    }

    private func local(_ pt: CGPoint, _ M: simd_double3x3) -> Vec2? {
        guard abs(M.determinant) > 1e-10 else { return nil }
        return LayerPlacement.projected(Vec2(Double(pt.x - fit.minX), Double(pt.y - fit.minY)), by: M.inverse)
    }

    private func handles(_ l: Layer, _ p: Project) -> [Handle] {
        let (M, hs) = mapping(l, p), t = state.currentTime
        var out: [Handle] = []
        for e in l.effects where state.keyframeFocusEffects.contains(e.id) && e.isEnabled {
            guard let def = EffectRegistry.definition(e.typeID) else { continue }
            for pd in def.params {
                if case .point = pd.kind {
                    let v = e.params[pd.id]?.point(at: t) ?? pd.defaultValue.point(at: t)
                    if let s = screen(Vec2(-hs.x + 2 * hs.x * v.x, -hs.y + 2 * hs.y * v.y), M) {
                        out.append(Handle(id: "\(e.id)|\(pd.id)", effect: e.id, key: pd.id, emitter: false, at: s, name: pd.name))
                    }
                }
            }
            if e.typeID == EffectRegistry.particles18.id,
               let s = screen(Vec2(hs.x * e.number("emitX", t) / 100, hs.y * e.number("emitY", t) / 100), M) {
                out.append(Handle(id: "\(e.id)|emit", effect: e.id, key: "emit", emitter: true, at: s, name: "Emitter"))
            }
        }
        return out
    }

    var body: some View {
        let p = Renderer.resolveParenting(state.live.project ?? state.project, time: state.currentTime)
        if let l = p.layers.first(where: { $0.id == state.selectedLayerID }) {
            ZStack {
                ForEach(handles(l, p)) { h in
                    ZStack {
                        Circle().strokeBorder(dragging == h.id ? Theme.accentGlow : .white, lineWidth: 2).frame(width: 26, height: 26)
                        Path { q in q.move(to: CGPoint(x: 0, y: 22)); q.addLine(to: CGPoint(x: 44, y: 22)); q.move(to: CGPoint(x: 22, y: 0)); q.addLine(to: CGPoint(x: 22, y: 44)) }
                            .stroke(Color.white, lineWidth: 1.2)
                    }
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .contentShape(Rectangle())
                    .position(h.at)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { v in
                            if dragging == nil { dragging = h.id; state.beginEdit("Move \(h.name)") }
                            move(h, to: CGPoint(x: h.at.x + v.translation.width, y: h.at.y + v.translation.height), layer: l, project: p, start: v.translation == .zero)
                        }
                        .onEnded { _ in dragging = nil; base = nil; state.endEdit() })
                    .accessibilityLabel("\(h.name) handle")
                }
            }
        }
    }

    @State private var base: CGPoint?

    private func move(_ h: Handle, to rawPoint: CGPoint, layer l: Layer, project p: Project, start: Bool) {
        // The handle's start point stays fixed for the whole drag (the layer redraws while it moves).
        if base == nil { base = h.at }
        let origin = base ?? h.at
        let target = CGPoint(x: origin.x + (rawPoint.x - h.at.x), y: origin.y + (rawPoint.y - h.at.y))
        let (M, hs) = mapping(l, p)
        guard let q = local(target, M) else { return }
        if h.emitter {
            state.setEffectParam(h.effect, "emitX") { pv, time in if case .number(var a) = pv { a.set(min(100, max(-100, q.x / max(hs.x, 1e-6) * 100)), at: time); pv = .number(a) } }
            state.setEffectParam(h.effect, "emitY") { pv, time in if case .number(var a) = pv { a.set(min(100, max(-100, q.y / max(hs.y, 1e-6) * 100)), at: time); pv = .number(a) } }
        } else {
            let v = Vec2((q.x + hs.x) / max(2 * hs.x, 1e-6), (q.y + hs.y) / max(2 * hs.y, 1e-6))
            state.setEffectParam(h.effect, h.key) { pv, time in if case .point(var a) = pv { a.set(v, at: time); pv = .point(a) } }
        }
    }
}
