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
                    label("Frame Rate  \(Int(state.project.fps)) fps")
                    chips(["24", "25", "30", "50", "60", "120"], selected: "\(Int(state.project.fps))") { v in
                        state.mutate("Frame Rate") { $0.fps = Double(v) ?? 30 }
                    }
                    Toggle("Auto length (follows your layers)", isOn: Binding(get: { state.project.autoLength }, set: { b in
                        state.mutate("Auto Length") { $0.autoLength = b }
                    }))
                    .tint(Theme.accent).foregroundStyle(Theme.text)
                    label(String(format: "Duration  %.1fs", state.project.duration))
                    HStack {
                        ValueScrubber(value: state.project.duration, range: 1...180, step: 0.1, unit: "s",
                                      onBegin: { state.beginEdit("Duration") },
                                      onChange: { v in state.mutate("Duration") { $0.duration = max(0.1, v) } }, onEnd: { state.endEdit() })
                        Button("Fit") { state.fitDurationToLayers() }.font(.system(size: 12, weight: .semibold))
                    }
                    AWIColorWell("Background", selection: Binding(get: { Color(state.project.background) }, set: { c in
                        state.mutate("Background") { $0.background = c.rgba }
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
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder private func section(_ title: String, typeID: String, def: EffectDefinition) -> some View {
        let fx = state.selectedLayer?.effects.first { $0.typeID == typeID }
        Toggle(title, isOn: Binding(get: { fx?.isEnabled ?? false }, set: { on in
            if let fx { state.toggleEffect(fx.id) } else if on { state.addEffect(def); state.panel = .style }
        }))
        .font(.system(size: 14, weight: .semibold)).tint(Theme.accent).foregroundStyle(Theme.text)
        if let fx, fx.isEnabled {
            ForEach(def.params) { pd in ParamRow(state: state, effect: fx, def: pd) }
        }
    }
}

// MARK: - Motion blur

struct MotionBlurPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Motion Blur", showKeyNav: false)
            if let l = state.selectedLayer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Motion blur on this layer", isOn: Binding(get: { l.motionBlur }, set: { b in
                            state.mutate("Layer Motion Blur") { p in
                                if let i = state.selectedIndex { p.layers[i].motionBlur = b }
                                if b { p.motionBlurEnabled = true }
                            }
                        }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                        Toggle("Enable for the whole scene", isOn: Binding(get: { state.project.motionBlurEnabled }, set: { b in
                            state.mutate("Motion Blur") { $0.motionBlurEnabled = b }
                        }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                        slider("Shutter Angle", state.project.shutterAngle, 0...720, "%.0f°") { v in state.mutate("Shutter Angle") { $0.shutterAngle = v } }
                        slider("Quality (samples)", Double(state.project.blurSamples), 3...32, "%.0f") { v in
                            state.mutate("Blur Samples") { $0.blurSamples = Int(v) }
                        }
                        Text("Real motion blur: the layer is rendered at several moments inside the shutter and averaged, so fast moves, spins and zooms smear naturally. 180° is the film standard; 360°+ exaggerates for velocity edits.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
        }
    }

    private func slider(_ t: String, _ v: Double, _ r: ClosedRange<Double>, _ fmt: String, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(t).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 120, alignment: .leading)
            ValueScrubber(value: v, range: r, step: 1, unit: fmt.hasSuffix("°") ? "°" : "", onBegin: { state.beginEdit(t) }, onChange: set, onEnd: { state.endEdit() })
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
                        Text("PIXEL MOTION BLUR (footage)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                        slider("Amount", fx.pixelMotionBlur, 0...200, "%.0f%%") { v in set { $0.pixelMotionBlur = v } }
                        Text("Blurs movement inside the clip itself (fast punches, camera whips), like RSMB. 100% = one frame of motion.")
                            .font(.caption).foregroundStyle(Theme.textDim)
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
