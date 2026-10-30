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
                                    Button("Apply") { edit("3D Text") { $0.text = draft } }.buttonStyle(.borderedProminent).tint(Theme.accent)
                                }
                            }
                            slider("Extrude", o.extrusion, 1...400) { v in cont { $0.extrusion = v } }
                            slider("Bevel", o.chamfer, 0...60) { v in cont { $0.chamfer = v } }
                            ColorPicker("Color", selection: Binding(get: { Color(o.color.value(at: t)) }, set: { c in
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

/// Physics Lab: pick bodies + obstacles, tune the world, simulate and bake to keyframes.
struct PhysicsPanel: View {
    @ObservedObject var state: EditorState
    @State private var settings = PhysicsSettings()
    @State private var dynamic: Set<UUID> = []
    @State private var obstacles: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Physics Lab", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap a layer: once = falls, twice = obstacle, three times = off.").font(.caption).foregroundStyle(Theme.textDim)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(state.project.layers.filter { l in
                                switch l.content { case .audio, .camera, .adjustment: return false; default: return true }
                            }) { l in
                                let mode = dynamic.contains(l.id) ? 1 : (obstacles.contains(l.id) ? 2 : 0)
                                Button {
                                    if mode == 0 { dynamic.insert(l.id) } else if mode == 1 { dynamic.remove(l.id); obstacles.insert(l.id) } else { obstacles.remove(l.id) }
                                } label: {
                                    Label(l.name, systemImage: mode == 1 ? "arrow.down.circle.fill" : (mode == 2 ? "square.fill" : "circle"))
                                        .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Capsule().fill(mode == 0 ? Theme.raised : (mode == 1 ? Theme.accent.opacity(0.4) : Theme.warning.opacity(0.35))))
                                        .foregroundStyle(Theme.text)
                                }
                            }
                        }
                    }
                    slider("Gravity", $settings.gravity, -3000...5000)
                    slider("Bounciness", $settings.bounciness, 0...1)
                    slider("Friction", $settings.friction, 0...1)
                    slider("Throw X", Binding(get: { settings.launch.x }, set: { settings.launch.x = $0 }), -3000...3000)
                    slider("Throw Y", Binding(get: { settings.launch.y }, set: { settings.launch.y = $0 }), -4000...2000)
                    slider("Spin °/s", $settings.spin, -1440...1440)
                    slider("Duration s", $settings.duration, 0.5...10)
                    HStack {
                        Toggle("Floor", isOn: $settings.floor); Toggle("Walls", isOn: $settings.walls); Toggle("Ceiling", isOn: $settings.ceiling)
                    }
                    .toggleStyle(.button).tint(Theme.accent).font(.caption)
                    Button("Simulate & Bake Keyframes") {
                        state.bakePhysics(dynamicIDs: Array(dynamic), staticIDs: Array(obstacles), settings: settings)
                    }
                    .buttonStyle(PrimaryButtonStyle()).disabled(dynamic.isEmpty)
                    Text("Results become normal keyframes from the playhead: edit, ease or delete them like any animation.")
                        .font(.caption).foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
        .onAppear { if let id = state.selectedLayerID { dynamic.insert(id) } }
    }

    private func slider(_ title: String, _ v: Binding<Double>, _ r: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 86, alignment: .leading)
            Slider(value: v, in: r)
            Text(String(format: "%.0f", v.wrappedValue)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accentGlow).frame(width: 48)
        }
    }
}

extension UTType {
    static let usdzModel = UTType(filenameExtension: "usdz") ?? .data
    static let objModel = UTType(filenameExtension: "obj") ?? .data
}
