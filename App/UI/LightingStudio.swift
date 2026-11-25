import SwiftUI

/// The light inspector stays below the live composition and shares the normal timeline.
struct LightingStudio: View {
    @ObservedObject var state: EditorState
    let layer: Layer
    let light: LightOptions

    private enum Tab: String, CaseIterable {
        case light = "Light", placement = "Placement", layers = "Layers"
    }

    @State private var tab: Tab = .light
    private var time: Double { state.currentTime }

    var body: some View {
        VStack(spacing: 8) {
            PanelHeader(state: state, title: "Lighting Studio", showKeyNav: false)
            Picker("Lighting controls", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch tab {
                    case .light: lightControls
                    case .placement: placementControls
                    case .layers: layerControls
                    }
                }
                .padding(12)
                .foregroundStyle(Theme.text)
            }
            .defaultScrollAnchor(.top)
        }
    }

    private var lightControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Light Type", selection: Binding(get: { light.type }, set: { type in
                state.mutate("Light Type") { project in
                    guard let index = project.layers.firstIndex(where: { $0.id == layer.id }) else { return }
                    project.layers[index].light?.type = type
                }
            })) {
                ForEach(LightType.allCases) { type in
                    Text(type == .parallel ? "Sun" : type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                AWIColorWell("Color", selection: Binding(get: { Color(light.color.value(at: time)) }, set: { color in
                    state.coalescedEdit("Light Color") { $0.light?.color.set(color.rgba, at: time) }
                }))
                Spacer()
                KeyframeDiamond(filled: light.color.keyframes.contains { abs($0.time - time) < 1e-4 },
                                animated: light.color.isAnimated) {
                    state.mutate("Keyframe Light Color") { project in
                        guard let index = project.layers.firstIndex(where: { $0.id == layer.id }) else { return }
                        project.layers[index].light?.color.toggleKeyframe(at: time)
                    }
                }
                .accessibilityLabel("Keyframe Light Color")
            }
            lightRow("Intensity", \.intensity, 0...400, "%")
            if light.type == .spot {
                lightRow("Cone Angle", \.coneAngle, 1...180, "°")
                lightRow("Edge Hardness", \.coneFeather, 0...100, "%")
            }
            if light.type == .spot || light.type == .point {
                lightRow("Falloff Radius", \.falloffRadius, 0...6000, " px")
                Text("A radius of 0 gives the light unlimited reach.")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
            if light.type != .ambient {
                Divider()
                Toggle("Cast Shadows", isOn: Binding(
                    get: { light.castsShadows },
                    set: { value in state.mutateLayer { $0.light?.castsShadows = value } }
                ))
                .tint(Theme.accent)
                if light.castsShadows {
                    shadowRow("Darkness", value: light.shadowDarkness, range: 0...100, unit: "%") {
                        $0.shadowDarkness = $1
                    }
                    shadowRow("Edge Blur", value: light.shadowBlur, range: 0...60, unit: " px") {
                        $0.shadowBlur = $1
                    }
                }
            }
        }
    }

    private var placementControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if light.type == .point || light.type == .spot {
                positionRow("Position X", axis: \.x, limit: Double(state.project.width))
                positionRow("Position Y", axis: \.y, limit: Double(state.project.height))
                transformRow("Depth (Z)", \.positionZ, -6000...6000, " px")
            }
            if light.type == .spot || light.type == .parallel {
                transformRow("Aim X", \.rotationX, -360...360, "°")
                transformRow("Aim Y", \.rotationY, -360...360, "°")
            }
            if light.type == .ambient {
                Text("Ambient light fills the scene evenly. Set its color and intensity under Light.")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
        }
    }

    private var layerControls: some View {
        ForEach(state.project.layers.filter(EditorState.isLightingArtwork)) { artwork in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(artwork.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer()
                    Text(artwork.is3D ? "DEPTH" : "FLAT").font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textDim)
                }
                Toggle("Receive Light", isOn: artworkToggle(artwork, "Receive Light", get: { $0.receivesLight }) {
                    $0.receivesLightOverride = $1
                })
                if artwork.is3D {
                    Toggle("Cast Shadow", isOn: artworkToggle(artwork, "Cast Shadow", get: { $0.castsShadows }) {
                        $0.castsShadows = $1
                    })
                }
            }
            .font(.subheadline)
            .tint(Theme.accent)
            .padding(12)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func artworkToggle(_ layer: Layer, _ title: String, get: (Layer) -> Bool,
                               set: @escaping (inout Layer, Bool) -> Void) -> Binding<Bool> {
        let current = get(layer)
        let id = layer.id
        return Binding(get: { current }, set: { flag in
            state.mutate(title) { project in
                guard let index = project.layers.firstIndex(where: { $0.id == id }), !project.layers[index].isLocked else { return }
                set(&project.layers[index], flag)
            }
        })
    }

    private func positionRow(_ title: String, axis: WritableKeyPath<Vec2, Double>, limit: Double) -> some View {
        let anim = layer.transform.position
        return numberRow(title, anim.value(at: time)[keyPath: axis], -limit...(limit * 2), " px",
                         animated: anim.isAnimated, keyed: anim.keyframes.contains { abs($0.time - time) < 1e-4 },
                         set: { value in
            state.mutateLayer {
                var position = $0.transform.position.value(at: time)
                position[keyPath: axis] = value
                $0.transform.position.set(position, at: time)
            }
        }, toggle: { state.mutateLayer { $0.transform.position.toggleKeyframe(at: time) } })
    }

    private func transformRow(_ title: String, _ key: WritableKeyPath<LayerTransform, Animated<Double>>,
                              _ range: ClosedRange<Double>, _ unit: String) -> some View {
        let anim = layer.transform[keyPath: key]
        return numberRow(title, anim.value(at: time), range, unit, animated: anim.isAnimated,
                         keyed: anim.keyframes.contains { abs($0.time - time) < 1e-4 },
                         set: { value in state.mutateLayer { $0.transform[keyPath: key].set(value, at: time) } },
                         toggle: { state.mutateLayer { $0.transform[keyPath: key].toggleKeyframe(at: time) } })
    }

    private func lightRow(_ title: String, _ key: WritableKeyPath<LightOptions, Animated<Double>>,
                          _ range: ClosedRange<Double>, _ unit: String) -> some View {
        let anim = light[keyPath: key]
        return numberRow(title, anim.value(at: time), range, unit, animated: anim.isAnimated,
                         keyed: anim.keyframes.contains { abs($0.time - time) < 1e-4 },
                         set: { value in state.mutateLayer { $0.light?[keyPath: key].set(value, at: time) } },
                         toggle: { state.mutateLayer { $0.light?[keyPath: key].toggleKeyframe(at: time) } })
    }

    private func shadowRow(_ title: String, value: Double, range: ClosedRange<Double>, unit: String,
                           set: @escaping (inout LightOptions, Double) -> Void) -> some View {
        HStack {
            Text(title).font(.subheadline).frame(width: 100, alignment: .leading)
            ValueScrubber(value: value, range: range, step: 1, unit: unit,
                          onBegin: { state.beginEdit(title) }, onChange: { value in
                state.mutateLayer { layer in
                    guard var options = layer.light else { return }
                    set(&options, value)
                    layer.light = options
                }
            }, onEnd: { state.endEdit() })
        }
    }

    private func numberRow(_ title: String, _ value: Double, _ range: ClosedRange<Double>, _ unit: String,
                           animated: Bool, keyed: Bool, set: @escaping (Double) -> Void,
                           toggle: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            KeyframeDiamond(filled: keyed, animated: animated) {
                state.beginEdit("Keyframe \(title)")
                toggle()
                state.endEdit()
            }
            .accessibilityLabel("Keyframe \(title)")
            Text(title).font(.subheadline).frame(width: 104, alignment: .leading)
            ValueScrubber(value: value, range: range, step: 1, unit: unit,
                          onBegin: { state.beginEdit(title) }, onChange: set, onEnd: { state.endEdit() })
        }
    }
}
