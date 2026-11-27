import SwiftUI
import simd

/// Puppet Pins editing: pins live on the selected layer's "Puppet Pins" effect, in layer pixels
/// (rest point + dragged point). The canvas adds / drags pins while the Puppet panel is open.
extension EditorState {
    var puppetEffectIndex: Int? { selectedLayer?.effects.firstIndex { $0.typeID == EffectRegistry.puppet18.id } }
    var puppetEffect: EffectInstance? {
        guard let id = selectedLayerID else { return nil }
        return (live.project ?? project).layers.first(where: { $0.id == id })?.effects.first { $0.typeID == EffectRegistry.puppet18.id }
    }

    var puppetUsesLocalDeformation: Bool { puppetEffect?.bool("localDeform") ?? true }

    func puppetKind(_ index: Int) -> EffectRegistry.PuppetPinKind {
        puppetEffect.map { EffectRegistry.puppetKind($0, index, currentTime) } ?? .position
    }

    var puppetDefaultRadius: Double {
        let size = selectedLayer?.size.value(at: currentTime) ?? Vec2(256, 256)
        return max(8, min(size.x, size.y) * 0.23)
    }

    /// Pins of the selected layer at the playhead: (rest, dragged) in layer px.
    var puppetPins: [(rest: Vec2, current: Vec2)] {
        guard let id = selectedLayerID,
              let l = (live.project ?? project).layers.first(where: { $0.id == id }),
              let j = l.effects.firstIndex(where: { $0.typeID == EffectRegistry.puppet18.id }) else { return [] }
        return EffectRegistry.puppetPins(l.effects[j], currentTime).map { (Vec2(Double($0.x), Double($0.y)), Vec2(Double($0.z), Double($0.w))) }
    }

    var puppetDisplayPoints: [Vec2] {
        guard let effect = puppetEffect else { return [] }
        let pins = EffectRegistry.puppetPins(effect, currentTime)
        if !puppetUsesLocalDeformation { return pins.map { Vec2(Double($0.z), Double($0.w)) } }
        let data = EffectRegistry.localPuppetData(effect, currentTime, pins)
        return pins.indices.map { Vec2(Double(data[$0 * 2].z), Double(data[$0 * 2].w)) }
    }

    func ensurePuppet() {
        guard puppetEffectIndex == nil, let i = selectedIndex else { return }
        guard selectedLayer?.isLocked == false else { return }
        mutate("Add Puppet Pins") { $0.layers[i].effects.insert(Self.newPuppetEffect(), at: 0) }
    }

    private static func newPuppetEffect() -> EffectInstance {
        var effect = EffectRegistry.puppet18.makeInstance()
        effect.params["localDeform"] = .toggle(true)
        return effect
    }

    /// Comp point -> the selected layer's local px (where its pixels are, before the puppet warp).
    func layerLocal(fromComp c: Vec2) -> Vec2? {
        guard let id = selectedLayerID, let M = displayPlacement(of: id), abs(M.determinant) > 1e-12 else { return nil }
        let h = M.inverse * SIMD3(c.x, c.y, 1)
        guard abs(h.z) > 1e-9 else { return nil }
        return Vec2(h.x / h.z, h.y / h.z)
    }

    /// Local -> canvas placement of a layer as it is drawn: parenting, 3D and the camera of the current view
    /// (free view has none), so taps and handles line up with the picture.
    func displayPlacement(of id: UUID) -> simd_double3x3? {
        if panel == .rig || panel == .boneWeight || panel == .puppet { return rigGeometry.matrices[id] }
        let view = canvasViewProject(live.project ?? project)
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
    func addPuppetPin(atComp c: Vec2, kind: EffectRegistry.PuppetPinKind = .position) {
        guard let i = selectedIndex, selectedLayer?.isLocked == false,
              let local = layerLocal(fromComp: c), local.x.isFinite, local.y.isFinite else { return }
        let n = puppetPins.count
        guard n < 32 else { return }
        let radius = puppetDefaultRadius
        mutate("Add Pin") { p in
            let j: Int
            if let existing = p.layers[i].effects.firstIndex(where: { $0.typeID == EffectRegistry.puppet18.id }) { j = existing }
            else { p.layers[i].effects.insert(Self.newPuppetEffect(), at: 0); j = 0 }
            p.layers[i].effects[j].params["pinR\(n)"] = .point(Animated(local))
            p.layers[i].effects[j].params["pinD\(n)"] = .point(Animated(local))
            if p.layers[i].effects[j].bool("localDeform") {
                p.layers[i].effects[j].params["pinK\(n)"] = .number(Animated(Double(kind.rawValue)))
                p.layers[i].effects[j].params["pinF\(n)"] = .number(Animated(radius))
                if kind.turns {
                    p.layers[i].effects[j].params["pinA\(n)"] = .number(Animated(0))
                    p.layers[i].effects[j].params["pinZ\(n)"] = .number(Animated(100))
                }
            } else if kind == .starch {
                p.layers[i].effects[j].params["pinS\(n)"] = .number(Animated(1))
            }
        }
        selectedPuppetPin = n
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Index of the pin nearest the finger (within reach), by its on-screen spot.
    func puppetPin(nearComp c: Vec2, reach: Double) -> Int? {
        var best: (Int, Double)?
        for (k, point) in puppetDisplayPoints.enumerated() {
            guard let s = compPoint(fromLocal: point) else { continue }
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
        guard selectedLayer?.isLocked == false, let j = puppetEffectIndex, local.x.isFinite, local.y.isFinite else { return }
        if puppetUsesLocalDeformation && !puppetKind(k).moves { return }
        let t = currentTime, animate = puppetAnimate
        mutateLayer { l in
            guard case .point(var a) = l.effects[j].params["pinD\(k)"] else { return }
            if a.isAnimated { a.set(local, at: t) }
            else if animate { a.insertKeyframe(Keyframe(time: t, value: local, interpolation: .bezier, easeOut: .easyOut, easeIn: .easyIn)) }
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

    func enableLocalPuppet() {
        guard let i = selectedIndex, let j = puppetEffectIndex, selectedLayer?.isLocked == false else { return }
        let radius = puppetDefaultRadius
        let count = puppetPins.count
        mutate("Enable Local Deformation") { project in
            project.layers[i].effects[j].params["localDeform"] = .toggle(true)
            for k in 0..<count { project.layers[i].effects[j].params["pinF\(k)"] = .number(Animated(radius)) }
        }
    }

    func setPuppetNumber(_ key: String, _ value: Double) {
        guard let j = puppetEffectIndex, value.isFinite, selectedLayer?.isLocked == false else { return }
        let time = currentTime
        let keys = puppetAnimate && (key.hasPrefix("pinA") || key.hasPrefix("pinZ"))
        mutateLayer { layer in
            var track: Animated<Double>
            if case .number(let saved) = layer.effects[j].params[key] { track = saved }
            else { track = Animated(key.hasPrefix("pinZ") ? 100 : 0) }
            if keys, !track.isAnimated {
                track.insertKeyframe(Keyframe(time: time, value: value))
            } else {
                track.set(value, at: time)
            }
            layer.effects[j].params[key] = .number(track)
        }
    }

    func removePuppetPin(_ k: Int) {
        guard let i = selectedIndex, let j = puppetEffectIndex else { return }
        let pins = project.layers[i].effects[j].params
        mutate("Remove Pin") { p in
            let prefixes = ["pinR", "pinD", "pinS", "pinK", "pinF", "pinA", "pinZ"]
            var params = pins.filter { entry in !prefixes.contains { entry.key.hasPrefix($0) } }
            var n = 0, src = 0
            while pins["pinR\(src)"] != nil {
                if src != k {
                    for prefix in prefixes { params["\(prefix)\(n)"] = pins["\(prefix)\(src)"] }
                    if params["pinD\(n)"] == nil { params["pinD\(n)"] = params["pinR\(n)"] }
                    n += 1
                }
                src += 1
            }
            p.layers[i].effects[j].params = params
        }
        if selectedPuppetPin == k { selectedPuppetPin = nil }
        else if let selected = selectedPuppetPin, selected > k { selectedPuppetPin = selected - 1 }
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
                for (prefix, neutral) in [("pinA", 0.0), ("pinZ", 100.0)] {
                    let key = "\(prefix)\(k)"
                    if case .number(var track) = p.layers[i].effects[j].params[key] {
                        track.set(neutral, at: t)
                        p.layers[i].effects[j].params[key] = .number(track)
                    }
                }
                k += 1
            }
        }
    }
}

/// The studio keeps rest placement and animation in separate modes.
struct PuppetPanel: View {
    @ObservedObject var state: EditorState
    @State private var fine = false
    @State private var pinInput: (origin: Vec2, inverse: simd_double3x3)?
    @State private var pinDelta = Vec2.zero

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Puppet Studio", showKeyNav: false)
            Picker("Puppet Workspace", selection: $state.puppetPlace) {
                Text("Place Pins").tag(true)
                Text("Pose").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 5)
            ScrollView {
                LiveReader(live: state.live) { _ in
                    VStack(alignment: .leading, spacing: 7) {
                        if state.puppetPlace { placeControls }
                        else { poseControls }
                        if let effect = state.puppetEffect {
                            VStack(alignment: .leading, spacing: 5) {
                                if !state.puppetUsesLocalDeformation {
                                    Button("Enable Local Deformation") { state.enableLocalPuppet() }
                                        .frame(minHeight: 44)
                                    Text("This layer uses the original Puppet warp. Switching changes how pins affect the artwork.")
                                        .font(.caption).foregroundStyle(Theme.textDim)
                                }
                                slider("Stiffness", effect: effect, key: "stiffness", fallback: 1.2, range: 0.5...3, step: 0.05)
                            }
                        }
                    }
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
            .accessibilityIdentifier("puppet-studio-scroll")
            .disabled(state.selectedLayer?.isLocked != false)
        }
        .onAppear { resetSelection() }
        .onChange(of: state.selectedLayerID) { _, _ in resetSelection() }
        .onDisappear { state.selectedPuppetPin = nil; state.puppetCursor = nil }
    }

    private var placeControls: some View {
        let local = state.puppetCursor.flatMap { state.layerLocal(fromComp: $0) } ?? .zero
        let types: [EffectRegistry.PuppetPinKind] = state.puppetUsesLocalDeformation ? [.position, .starch, .bend, .advanced] : [.position, .starch]
        return VStack(alignment: .leading, spacing: 6) {
            Picker("Pin Type", selection: $state.puppetPlacementKind) {
                ForEach(types, id: \.rawValue) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(pinPurpose).font(.caption).foregroundStyle(Theme.textDim)
            HStack(spacing: 6) {
                NumberField(value: local.x, label: "X", step: 0.1) { state.puppetCursor = state.compPoint(fromLocal: Vec2($0, local.y)) }
                NumberField(value: local.y, label: "Y", step: 0.1) { state.puppetCursor = state.compPoint(fromLocal: Vec2(local.x, $0)) }
                Button {
                    guard let point = state.puppetCursor ?? state.compPoint(fromLocal: .zero) else { return }
                    state.addPuppetPin(atComp: point, kind: state.puppetPlacementKind)
                } label: {
                    Label("Add Pin", systemImage: "plus").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 9).frame(minHeight: 44)
                }
                .buttonStyle(.plain).glass(radius: 8)
                .disabled(state.puppetPins.count >= 32)
            }
            SwipePad(hint: "Position the crosshair, then tap Add Pin",
                     gain: Double(state.project.width) * (fine ? 0.18 : 0.8), steady: true) { delta in
                guard let point = state.puppetCursor ?? state.compPoint(fromLocal: .zero) else { return }
                state.puppetCursor = point + Vec2(Double(delta.width), Double(delta.height))
            }
            .accessibilityIdentifier("puppet-placement-pad")
            Toggle("Fine Positioning", isOn: $fine).font(.subheadline).tint(Theme.accent)
        }
    }

    private var pinPurpose: String {
        switch state.puppetPlacementKind {
        case .position: "Move a point or leave it in place to anchor the artwork."
        case .starch: "Keep the area around this pin stiff."
        case .bend: "Follow nearby pins while adding rotation or scale."
        case .advanced: "Control this point’s position, rotation, and scale."
        }
    }

    @ViewBuilder private var poseControls: some View {
        let pins = state.puppetPins
        if pins.isEmpty {
            Text("Place a Position pin where you want the artwork to move.")
                .font(.caption).foregroundStyle(Theme.textDim)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(pins.indices, id: \.self) { index in
                        Button {
                            state.selectedPuppetPin = index
                        } label: {
                            Label("\(state.puppetKind(index).title) \(index + 1)", systemImage: pinIcon(for: index))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 9).frame(minHeight: 44)
                                .background(state.selectedPuppetPin == index ? Theme.accent.opacity(0.26) : Theme.surface,
                                            in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("puppet-pin-select-\(index)")
                        .accessibilityAddTraits(state.selectedPuppetPin == index ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
            if let k = state.selectedPuppetPin, pins.indices.contains(k), let effect = state.puppetEffect {
                let kind = state.puppetKind(k)
                let point = pins[k].current
                if !state.puppetUsesLocalDeformation || kind.moves {
                    HStack(spacing: 6) {
                        NumberField(value: point.x, label: "X", step: 0.1) { move(k, to: Vec2($0, point.y)) }
                        NumberField(value: point.y, label: "Y", step: 0.1) { move(k, to: Vec2(point.x, $0)) }
                        keyframe(effect, "pinD\(k)", "Position")
                    }
                    positionPad(k)
                }
                if state.puppetUsesLocalDeformation {
                    slider("Radius", effect: effect, key: "pinF\(k)", fallback: state.puppetDefaultRadius,
                           range: 1...max(20, state.puppetDefaultRadius * 5), step: 1, unit: " px")
                    if kind.turns {
                        slider("Rotation", effect: effect, key: "pinA\(k)", fallback: 0, range: -360...360, step: 0.1, unit: "°", animate: true)
                        slider("Scale", effect: effect, key: "pinZ\(k)", fallback: 100, range: 25...400, step: 1, unit: "%", animate: true)
                    }
                } else {
                    Button(state.isPuppetStarch(k) ? "Use Position Pin" : "Use Starch Pin") { state.togglePuppetStarch(k) }
                        .frame(minHeight: 44)
                }
                HStack {
                    if !state.puppetUsesLocalDeformation || kind.moves {
                        graphButton(effect, "pinD\(k)", title: "Position Graph")
                    }
                    Spacer()
                    Button(role: .destructive) { state.removePuppetPin(k) } label: {
                        Label("Delete Pin", systemImage: "trash").frame(minHeight: 44)
                    }
                }.font(.subheadline)
            }
            Toggle("Keyframe Pin Moves", isOn: $state.puppetAnimate).tint(Theme.accent)
            Toggle("Fine Positioning", isOn: $fine).tint(Theme.accent)
            Button("Reset Pose") { state.resetPuppetPose() }.frame(minHeight: 44)
        }
    }

    private func positionPad(_ index: Int) -> some View {
        SwipePad(hint: "Swipe to move the selected pin",
                 gain: Double(state.project.width) * (fine ? 0.18 : 0.8), steady: true) { delta in
            guard let input = pinInput else { return }
            pinDelta = pinDelta + Vec2(Double(delta.width), Double(delta.height))
            if let local = LayerPlacement.projected(input.origin + pinDelta, by: input.inverse) {
                state.setPuppetPin(index, local: local)
            }
        } begin: {
            guard let id = state.selectedLayerID, let matrix = state.displayPlacement(of: id),
                  abs(matrix.determinant) > 1e-10, state.puppetPins.indices.contains(index),
                  let origin = LayerPlacement.projected(state.puppetPins[index].current, by: matrix) else { return }
            pinInput = (origin, matrix.inverse); pinDelta = .zero
            state.beginPanelGesture("Move Puppet Pin")
        } end: {
            if pinInput != nil { state.endPanelGesture() }
            pinInput = nil; pinDelta = .zero
        }
        .accessibilityIdentifier("puppet-position-swipe-pad")
    }

    private func slider(_ title: String, effect: EffectInstance, key: String, fallback: Double,
                        range: ClosedRange<Double>, step: Double, unit: String = "", animate: Bool = false) -> some View {
        HStack(spacing: 7) {
            if animate { keyframe(effect, key, title) }
            Text(title).font(.caption.weight(.medium)).frame(width: 58, alignment: .leading)
            ValueScrubber(value: effect.params[key]?.number(at: state.currentTime) ?? fallback, range: range, step: step, unit: unit,
                          onBegin: { state.beginEdit(title) },
                          onChange: { state.setPuppetNumber(key, $0) },
                          onEnd: { state.endEdit() })
            if animate { graphButton(effect, key, title: "\(title) Graph", labeled: false) }
        }
    }

    private func keyframe(_ effect: EffectInstance, _ key: String, _ title: String) -> some View {
        let status = state.effectParamHasKeyframe(effect.id, key)
        return KeyframeDiamond(filled: status.filled, animated: status.animated) {
            state.toggleEffectKeyframe(effect.id, key)
        }.accessibilityLabel("Keyframe \(title)")
    }

    private func graphButton(_ effect: EffectInstance, _ key: String, title: String, labeled: Bool = true) -> some View {
        Button {
            state.graphEffect = GraphEffectTarget(effect: effect.id, key: key)
            state.panel = .graph
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                if labeled { Text(title) }
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(title)
        .disabled((effect.params[key]?.keyframeTimes.count ?? 0) < 2)
    }

    private func pinIcon(for index: Int) -> String {
        switch state.puppetKind(index) {
        case .position: "pin"
        case .starch: "lock"
        case .bend: "arrow.turn.up.right"
        case .advanced: "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    private func move(_ index: Int, to value: Vec2) {
        state.beginEdit("Move Puppet Pin")
        state.setPuppetPin(index, local: value)
        state.endEdit()
    }

    private func resetSelection() {
        state.puppetPlace = state.puppetPins.isEmpty
        state.selectedPuppetPin = state.puppetPins.isEmpty ? nil : 0
        state.puppetCursor = state.compPoint(fromLocal: .zero)
        state.puppetPlacementKind = .position
    }
}

/// Pins drawn on the canvas while the Puppet panel is open.
struct PuppetOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect

    var body: some View {
        let s = fit.width / CGFloat(max(state.project.width, 1))
        Canvas { ctx, _ in
            func screen(_ c: Vec2) -> CGPoint { CGPoint(x: fit.minX + CGFloat(c.x) * s, y: fit.minY + CGFloat(c.y) * s) }
            for (index, point) in state.puppetDisplayPoints.enumerated() {
                guard let c = state.compPoint(fromLocal: point) else { continue }
                let pt = screen(c)
                let selected = state.selectedPuppetPin == index
                let r: CGFloat = selected ? 4.5 : 3.5
                let marker = Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
                let color: Color = switch state.puppetKind(index) {
                case .position: Theme.warning
                case .starch: Theme.danger
                case .bend: .orange
                case .advanced: .cyan
                }
                ctx.fill(marker, with: .color(color))
                ctx.stroke(marker, with: .color(selected ? .white : .black), lineWidth: 1.3)
            }
            if state.puppetPlace, let cursor = state.puppetCursor {
                let c = screen(cursor)
                var cross = Path()
                cross.move(to: CGPoint(x: c.x - 8, y: c.y))
                cross.addLine(to: CGPoint(x: c.x + 8, y: c.y))
                cross.move(to: CGPoint(x: c.x, y: c.y - 8))
                cross.addLine(to: CGPoint(x: c.x, y: c.y + 8))
                ctx.stroke(cross, with: .color(.black), lineWidth: 3)
                ctx.stroke(cross, with: .color(.white), lineWidth: 1.3)
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
