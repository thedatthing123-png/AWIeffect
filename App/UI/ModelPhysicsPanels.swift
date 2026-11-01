import SwiftUI
import UniformTypeIdentifiers

/// 3D model / 3D text controls.
struct ModelPanel: View {
    @ObservedObject var state: EditorState
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "3D Model")
            if let o = state.selectedLayer?.model3D {
                let t = state.currentTime
                ScrollView {
                    VStack(spacing: 8) {
                        if o.fileName == nil {
                            if o.shapePath == nil && o.imageFile == nil {
                                HStack {
                                    TextField("3D text", text: $draft).padding(8).glass(radius: 10).foregroundStyle(Theme.text)
                                        // Live: the 3D text updates as you type.
                                        .onChange(of: draft) { _, d in edit("3D Text") { $0.text = d } }
                                }
                            }
                            slider("Extrude", o.extrusion, 1...400) { v in cont { $0.extrusion = v } }
                            slider("Bevel", o.chamfer, 0...60) { v in cont { $0.chamfer = v } }
                            AWIColorWell("Color", selection: Binding(get: { Color(o.color.value(at: t)) }, set: { c in
                                edit("3D Color") { $0.color.set(c.rgba, at: t) }
                            })).foregroundStyle(Theme.text)
                            slider("Metal", o.metalness, 0...1) { v in cont { $0.metalness = v } }
                            slider("Roughness", o.roughness, 0...1) { v in cont { $0.roughness = v } }
                        }
                        animRow("Yaw", o.yaw.value(at: t), -360...360, set: { v in cont { $0.yaw.set(v, at: t) } }, key: { edit("Yaw Key") { $0.yaw.toggleKeyframe(at: t) } })
                        animRow("Pitch", o.pitch.value(at: t), -180...180, set: { v in cont { $0.pitch.set(v, at: t) } }, key: { edit("Pitch Key") { $0.pitch.toggleKeyframe(at: t) } })
                        animRow("Roll", o.roll.value(at: t), -180...180, set: { v in cont { $0.roll.set(v, at: t) } }, key: { edit("Roll Key") { $0.roll.toggleKeyframe(at: t) } })
                        slider("Auto Spin °/s", o.spin, -360...360) { v in cont { $0.spin = v } }
                        animRow("Light Angle", o.lightAngle.value(at: t), -180...180, set: { v in cont { $0.lightAngle.set(v, at: t) } }, key: { edit("Light Key") { $0.lightAngle.toggleKeyframe(at: t) } })
                        animRow("Light", o.lightIntensity.value(at: t), 0...4000, set: { v in cont { $0.lightIntensity.set(v, at: t) } }, key: { edit("Light Key") { $0.lightIntensity.toggleKeyframe(at: t) } })
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
                .onAppear { draft = o.text }
            }
        }
    }

    private func edit(_ label: String, _ f: (inout Model3DOptions) -> Void) {
        state.beginEdit(label); state.mutateLayer { l in if l.model3D != nil { f(&l.model3D!) } }; state.endEdit()
    }
    private func cont(_ f: (inout Model3DOptions) -> Void) {
        state.beginEdit("Edit 3D"); state.mutateLayer { l in if l.model3D != nil { f(&l.model3D!) } }
    }
    private func slider(_ title: String, _ v: Double, _ r: ClosedRange<Double>, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 90, alignment: .leading)
            Slider(value: Binding(get: { min(max(v, r.lowerBound), r.upperBound) }, set: set), in: r) { e in if !e { state.endEdit() } }
            Text(String(format: "%.1f", v)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accentGlow).frame(width: 44)
        }
    }
    private func animRow(_ title: String, _ v: Double, _ r: ClosedRange<Double>, set: @escaping (Double) -> Void, key: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Button(action: key) { Image(systemName: "diamond").foregroundStyle(Theme.keyframe).frame(width: 28, height: 28) }
            slider(title, v, r, set)
        }
    }
}

/// Physics Studio: pick what falls and what's solid, set up the world, throw, then bake to normal keyframes.
/// Grouped into Bodies · World · Throw & Wind · Bake, all in one scroll.
struct PhysicsPanel: View {
    @ObservedObject var state: EditorState
    @State private var settings = PhysicsSettings()
    @State private var dynamic: Set<UUID> = []
    @State private var obstacles: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Physics Studio", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SoftPhysicsSection(state: state)
                    Divider().overlay(Theme.stroke)
                    Text("RIGID BODIES").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accentGlow)
                    group("Bodies", "Tap a layer to switch it: Falls → Solid → Off. Colliders from Rig are solid automatically.") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                            ForEach(state.project.layers.filter { l in
                                switch l.content { case .audio, .camera, .adjustment, .light: return false; default: return true }
                            }) { l in
                                let mode = dynamic.contains(l.id) ? 1 : (obstacles.contains(l.id) ? 2 : 0)
                                Button {
                                    if mode == 0 { dynamic.insert(l.id) } else if mode == 1 { dynamic.remove(l.id); obstacles.insert(l.id) } else { obstacles.remove(l.id) }
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: mode == 1 ? "arrow.down.circle.fill" : (mode == 2 ? "square.fill" : "circle.dashed"))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(l.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                            Text(mode == 1 ? "Falls" : (mode == 2 ? "Solid" : "Off")).font(.system(size: 10)).foregroundStyle(Theme.textDim)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(mode == 0 ? Theme.raised : (mode == 1 ? Theme.accent.opacity(0.4) : Theme.warning.opacity(0.35))))
                                    .foregroundStyle(Theme.text)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        slider("Bounciness", $settings.bounciness, 0...1)
                        slider("Friction", $settings.friction, 0...1)
                        slider("Air Drag", $settings.airDrag, 0...0.5)
                    }
                    group("World", nil) {
                        slider("Gravity", $settings.gravity, -3000...5000)
                        HStack(spacing: 6) {
                            toggleTile("Floor", "rectangle.bottomhalf.filled", $settings.floor)
                            toggleTile("Walls", "rectangle.split.3x1", $settings.walls)
                            toggleTile("Ceiling", "rectangle.tophalf.filled", $settings.ceiling)
                        }
                    }
                    group("Throw & Wind", nil) {
                        slider("Throw X", Binding(get: { settings.launch.x }, set: { settings.launch.x = $0 }), -3000...3000)
                        slider("Throw Y", Binding(get: { settings.launch.y }, set: { settings.launch.y = $0 }), -4000...2000)
                        slider("Spin °/s", $settings.spin, -1440...1440)
                        slider("Wind X", Binding(get: { settings.wind.x }, set: { settings.wind.x = $0 }), -3000...3000)
                        slider("Wind Y", Binding(get: { settings.wind.y }, set: { settings.wind.y = $0 }), -3000...3000)
                        Toggle("Keep current motion (keyframed speed carries on)", isOn: $settings.keepMotion)
                            .tint(Theme.accent).foregroundStyle(Theme.text).font(.system(size: 13))
                    }
                    group("Bake", "Results become normal keyframes from the playhead: ease them with Graph, edit or delete them.") {
                        slider("Duration s", $settings.duration, 0.5...10)
                        slider("Accuracy", Binding(get: { Double(settings.substeps) }, set: { settings.substeps = Int($0.rounded()) }), 1...32)
                        Button {
                            state.bakePhysics(dynamicIDs: Array(dynamic), staticIDs: Array(obstacles), settings: settings)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Label("Simulate & Bake Keyframes", systemImage: "play.circle.fill").font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(RoundedRectangle(cornerRadius: 12).fill(dynamic.isEmpty ? Theme.raised : Theme.accent))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(dynamic.isEmpty)
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
        .onAppear { if let id = state.selectedLayerID { dynamic.insert(id) } }
    }

    private func group<C: View>(_ title: String, _ hint: String?, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accentGlow)
            if let hint { Text(hint).font(.caption).foregroundStyle(Theme.textDim) }
            content()
        }
    }

    private func toggleTile(_ title: String, _ icon: String, _ on: Binding<Bool>) -> some View {
        Button { on.wrappedValue.toggle() } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 10).fill(on.wrappedValue ? Theme.accent.opacity(0.35) : Theme.raised))
            .foregroundStyle(on.wrappedValue ? Theme.accentGlow : Theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func slider(_ title: String, _ v: Binding<Double>, _ r: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 86, alignment: .leading)
            ValueScrubber(value: v.wrappedValue, range: r, onChange: { v.wrappedValue = $0 })
        }
    }
}

extension UTType {
    static let usdzModel = UTType(filenameExtension: "usdz") ?? .data
    static let objModel = UTType(filenameExtension: "obj") ?? .data
}
