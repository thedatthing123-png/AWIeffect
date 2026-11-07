import SwiftUI

// MARK: - Scene (project) settings

/// Comp settings after creation: name, size, frame rate, duration, background, motion blur.
struct ScenePanel: View {
    @ObservedObject var state: EditorState
    @State private var name = ""

    private static let sizes: [(String, Int, Int)] = [("9:16", 1080, 1920), ("16:9", 1920, 1080), ("1:1", 1080, 1080), ("4:5", 1080, 1350),
                                                     ("4:3", 1440, 1080), ("21:9", 2560, 1080), ("4K", 2160, 3840)]

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Scene Settings", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Project name", text: $name).padding(9).glass(radius: 10).foregroundStyle(Theme.text)
                            .onSubmit(rename)
                        Button("Rename", action: rename).font(.system(size: 13, weight: .semibold))
                    }
                    label("Size  \(state.project.width)×\(state.project.height)")
                    chips(Self.sizes.map(\.0), selected: Self.sizes.first { $0.1 == state.project.width && $0.2 == state.project.height }?.0) { k in
                        if let s = Self.sizes.first(where: { $0.0 == k }) { state.resizeComp(width: s.1, height: s.2) }
                    }
                    // Custom size: type any width × height.
                    HStack(spacing: 8) {
                        Text("Custom").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textDim)
                        NumberField(value: Double(state.project.width), label: "W") { v in
                            state.resizeComp(width: min(8192, max(16, Int(v) / 2 * 2)), height: state.project.height)
                        }
                        NumberField(value: Double(state.project.height), label: "H") { v in
                            state.resizeComp(width: state.project.width, height: min(8192, max(16, Int(v) / 2 * 2)))
                        }
                    }
                    label("Frame Rate  \(Int(state.project.fps)) fps")
                    chips(["24", "25", "30", "50", "60", "120"], selected: "\(Int(state.project.fps))") { v in
                        state.mutate("Frame Rate") { $0.fps = Double(v) ?? 30 }
                    }
                    Text(String(format: "Length  %.1fs  (follows your clips — drag a layer's end to make it longer)", state.project.duration))
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textDim)
                    AWIColorWell("Background", selection: Binding(get: { Color(state.project.background) }, set: { c in
                        state.coalescedProjectEdit("Background") { $0.background = c.rgba }
                    }), supportsOpacity: true).foregroundStyle(Theme.text)
                    Toggle("Motion Blur (whole scene)", isOn: Binding(get: { state.project.motionBlurEnabled }, set: { b in
                        state.mutate("Motion Blur") { $0.motionBlurEnabled = b }
                    }))
                    .tint(Theme.accent).foregroundStyle(Theme.text)
                    Toggle("Smooth Motion (auto blur on shakes & motion effects)", isOn: Binding(get: { state.project.smoothMotion }, set: { b in
                        state.mutate("Smooth Motion") { $0.smoothMotion = b }
                    }))
                    .tint(Theme.accent).foregroundStyle(Theme.text)
                    Text("Other layers blur when their own Motion Blur switch is on too (like After Effects).")
                        .font(.caption).foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
        .onAppear { name = state.project.name }
    }

    private func rename() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        state.mutate("Rename Project") { $0.name = n }
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textDim)
    }

    private func chips(_ items: [String], selected: String?, pick: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { it in
                    Button { pick(it) } label: {
                        Text(it).font(.system(size: 12, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(it == selected ? Theme.accent : Theme.raised))
                            .foregroundStyle(it == selected ? Color.white : Theme.text)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

extension EditorState {
    /// Changes the comp size, keeping every layer where it was relative to the frame center.
    func resizeComp(width: Int, height: Int) {
        guard width != project.width || height != project.height else { return }
        let dx = Double(width - project.width) / 2, dy = Double(height - project.height) / 2
        mutate("Scene Size") { p in
            p.width = width; p.height = height
            for i in p.layers.indices where p.layers[i].parentID == nil {
                p.layers[i].transform.position = p.layers[i].transform.position.mapped { $0 + Vec2(dx, dy) }
            }
        }
    }

    /// Duration = end of the last layer.
    func fitDurationToLayers() {
        let end = project.layers.map(\.outPoint).max() ?? project.duration
        mutate("Fit Duration") { $0.duration = max(0.5, end) }
    }
}

extension Animated {
    /// Same keyframes with every value transformed.
    func mapped(_ f: (Value) -> Value) -> Animated<Value> {
        var a = self
        a.staticValue = f(a.staticValue)
        a.keyframes = a.keyframes.map { var k = $0; k.value = f(k.value); return k }
        return a
    }
}

// MARK: - Border & Shadow

/// Layer styles: an outline border and a drop shadow, stored as normal effects so they also show in the stack.
struct StylePanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Border & Shadow")
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    section("Border", typeID: EffectRegistry.border.id, def: EffectRegistry.border)
                    Divider().overlay(Theme.stroke)
                    section("Shadow", typeID: EffectRegistry.dropShadow.id, def: EffectRegistry.dropShadow)
                    Divider().overlay(Theme.stroke)
                    section("Inner Shadow", typeID: EffectRegistry.innerShadow10.id, def: EffectRegistry.innerShadow10)
                    Divider().overlay(Theme.stroke)
                    section("Outer Glow", typeID: EffectRegistry.outerGlow.id, def: EffectRegistry.outerGlow)
                    Divider().overlay(Theme.stroke)
                    section("Inner Glow", typeID: EffectRegistry.innerGlow.id, def: EffectRegistry.innerGlow)
                    Text("Gradient fills and overlays are in Color & Fill.").font(.caption).foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder private func section(_ title: String, typeID: String, def: EffectDefinition) -> some View {
        let all = state.selectedLayer?.effects.filter { $0.typeID == typeID } ?? []
        // The switch reflects every border / shadow on the layer (a second, active one used to be hidden).
        let fx = Self.shown(all)
        Toggle(title, isOn: Binding(get: { Self.isOn(all) }, set: { on in
            let current = state.selectedLayer?.effects.filter { $0.typeID == typeID } ?? []
            if current.isEmpty { if on { state.addEffect(def); state.panel = .style }; return }
            let targets = Self.toggleTargets(current, on: on)
            guard !targets.isEmpty else { return }
            state.beginEdit(on ? "Enable \(title)" : "Disable \(title)")
            for id in targets { state.toggleEffect(id) }
            state.endEdit()
        }))
        .font(.system(size: 14, weight: .semibold)).tint(Theme.accent).foregroundStyle(Theme.text)
        .frame(minHeight: 44)
        if let fx, fx.isEnabled {
            ForEach(def.params) { pd in ParamRow(state: state, effect: fx, def: pd) }
            if all.filter(\.isEnabled).count > 1 {
                Text("This layer has \(all.filter(\.isEnabled).count) \(title.lowercased()) effects; the first active one is shown. Edit the others in Effects.")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
        }
    }

    /// On when any of them is active.
    static func isOn(_ effects: [EffectInstance]) -> Bool { effects.contains(where: \.isEnabled) }
    /// The one whose controls show: the first active one, else the first.
    static func shown(_ effects: [EffectInstance]) -> EffectInstance? { effects.first(where: \.isEnabled) ?? effects.first }
    /// Switching off turns every active one off; switching on turns the first one on.
    static func toggleTargets(_ effects: [EffectInstance], on: Bool) -> [UUID] {
        if on { return effects.contains(where: \.isEnabled) ? [] : effects.prefix(1).map(\.id) }
        return effects.filter(\.isEnabled).map(\.id)
    }
}

// MARK: - Motion blur

struct MotionBlurPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Motion Blur", showKeyNav: false)
            if let l = state.selectedLayer {
                let p = state.project
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Motion Blur", isOn: Binding(get: { p.motionBlurEnabled }, set: { b in
                            state.mutate("Motion Blur") { $0.motionBlurEnabled = b }
                        }))
                        .font(.system(size: 15, weight: .bold)).tint(Theme.accent).foregroundStyle(Theme.text)
                        Text("The master switch for this scene. Off, nothing blurs.").font(.caption).foregroundStyle(Theme.textDim)
                        Toggle("Every layer", isOn: Binding(get: { p.blurAllLayers }, set: { b in
                            state.mutate("Blur Every Layer") { $0.blurAllLayers = b; if b { $0.motionBlurEnabled = true } }
                        }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                        if l.content != .camera { layerRow(l, p) }
                        if !p.motionBlurEnabled {
                            Text("Turn Motion Blur on to see it. Camera moves, parents, nulls and shake effects all count as motion.")
                                .font(.caption).foregroundStyle(Theme.warning)
                        }
                        Divider().overlay(Theme.stroke)
                        slider("Shutter Angle", p.shutterAngle, 0...1440, "°") { v in state.mutate("Shutter Angle") { $0.shutterAngle = v } }
                        slider("Shutter Phase", p.shutterPhase, -720...720, "°") { v in state.mutate("Shutter Phase") { $0.shutterPhase = v } }
                        HStack(spacing: 6) {
                            preset("Film 180°", 180, -90); preset("Smooth 360°", 360, -180); preset("Velocity 720°", 720, -360)
                        }
                        slider("Quality (samples)", Double(p.blurSamples), 2...64, "") { v in state.mutate("Blur Samples") { $0.blurSamples = Int(v) } }
                        Text("Shutter Angle sets the trail length (180° is film, past 360° exaggerates for velocity edits). Phase sets where it starts: half the angle, negative, centers the trail on the frame like AE. Preview uses fewer samples while you scrub; export uses all of them.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                        if l.content != .camera {
                            Divider().overlay(Theme.stroke)
                            PixelMotionBlurControls(state: state, layer: l)
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
        }
    }

    /// With "Every layer" on, a layer can stay sharp; otherwise it opts in on its own.
    @ViewBuilder private func layerRow(_ l: Layer, _ p: Project) -> some View {
        if p.blurAllLayers {
            Toggle("Keep this layer sharp", isOn: Binding(get: { (p.sharpLayerIDs ?? []).contains(l.id) }, set: { b in
                state.mutate("Keep Layer Sharp") { proj in
                    var ids = proj.sharpLayerIDs ?? []
                    ids.removeAll { $0 == l.id }
                    if b { ids.append(l.id) }
                    proj.sharpLayerIDs = ids.isEmpty ? nil : ids
                    if let i = state.selectedIndex, b { proj.layers[i].motionBlur = false }
                }
            }))
            .tint(Theme.accent).foregroundStyle(Theme.text)
        } else {
            Toggle("This layer", isOn: Binding(get: { l.motionBlur }, set: { b in
                state.mutate("Layer Motion Blur") { proj in
                    if let i = state.selectedIndex { proj.layers[i].motionBlur = b }
                    if b { proj.motionBlurEnabled = true }
                }
            }))
            .tint(Theme.accent).foregroundStyle(Theme.text)
        }
    }

    private func preset(_ title: String, _ angle: Double, _ phase: Double) -> some View {
        Button {
            state.mutate("Shutter Preset") { $0.shutterAngle = angle; $0.shutterPhase = phase; $0.motionBlurEnabled = true }
        } label: {
            Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 8).padding(.vertical, 7).frame(maxWidth: .infinity)
                .background(Capsule().fill(Theme.raised)).foregroundStyle(Theme.text)
        }
    }

    private func slider(_ t: String, _ v: Double, _ r: ClosedRange<Double>, _ unit: String, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(t).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 120, alignment: .leading)
            ValueScrubber(value: v, range: r, step: 1, unit: unit, onBegin: { state.beginEdit(t) }, onChange: set, onEnd: { state.endEdit() })
        }
    }
}

// MARK: - Time effects

struct TimePanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Time", showKeyNav: false)
            if let l = state.selectedLayer {
                let fx = l.timeFX ?? LayerTimeFX()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ECHO / TRAILS").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                        slider("Copies", Double(fx.echoCount), 0...16, "%.0f") { v in set { $0.echoCount = Int(v) } }
                        slider("Delay", fx.echoDelay, 0.01...0.5, "%.2fs") { v in set { $0.echoDelay = v } }
                        slider("Keep", fx.echoDecay * 100, 5...100, "%.0f%%") { v in set { $0.echoDecay = v / 100 } }
                        Divider().overlay(Theme.stroke)
                        Toggle("Frame Blending (smooth slow motion)", isOn: Binding(get: { fx.frameBlend }, set: { b in set { $0.frameBlend = b } }))
                            .tint(Theme.accent).foregroundStyle(Theme.text)
                        Text("Slowed-down video blends between frames instead of repeating them, like After Effects' Frame Blending.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                        Divider().overlay(Theme.stroke)
                        Text("POSTERIZE TIME (choppy anime look)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                        HStack(spacing: 6) {
                            ForEach([0.0, 6, 8, 12, 15, 24], id: \.self) { f in
                                Button { set { $0.posterizeFPS = f } } label: {
                                    Text(f == 0 ? "Off" : "\(Int(f))").font(.system(size: 12, weight: .bold))
                                        .frame(maxWidth: .infinity, minHeight: 32)
                                        .background(Capsule().fill(fx.posterizeFPS == f ? Theme.accent : Theme.surface))
                                        .foregroundStyle(fx.posterizeFPS == f ? Color.white : Theme.text)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Divider().overlay(Theme.stroke)
                        HStack {
                            Button { let t = state.currentTime; set { $0.freezeAt = fx.freezeAt == nil ? t : nil } } label: {
                                Label(fx.freezeAt == nil ? "Freeze Frame at Playhead" : "Unfreeze", systemImage: fx.freezeAt == nil ? "pause.rectangle" : "play.rectangle")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        if let f = fx.freezeAt {
                            Text(String(format: "Holding %.2fs", f)).font(.caption).foregroundStyle(Theme.textDim)
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
        }
    }

    private func set(_ change: (inout LayerTimeFX) -> Void) {
        state.coalescedEdit("Time Effects") { l in
            var fx = l.timeFX ?? LayerTimeFX()
            change(&fx)
            l.timeFX = fx.isEmpty ? nil : fx
        }
    }

    private func slider(_ t: String, _ v: Double, _ r: ClosedRange<Double>, _ fmt: String, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(t).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 70, alignment: .leading)
            ValueScrubber(value: v, range: r, step: fmt.contains(".2f") ? 0.01 : 1, unit: fmt.hasSuffix("s") ? "s" : (fmt.contains("%%") ? "%" : ""), onChange: set)
        }
    }
}
