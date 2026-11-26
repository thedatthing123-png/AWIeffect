import SwiftUI

/// A scene inspector below the composition, with setup separate from placement and camera motion.
struct Scene3DPanel: View {
    @ObservedObject var state: EditorState
    @State private var tab: Tab = .scene
    @State private var depth = 600.0
    @State private var push = 30.0
    @State private var duration = 2.5
    @State private var drift = 3.0
    @State private var turn = 2.0
    @State private var keepFraming = false

    private enum Tab: String, CaseIterable { case scene = "Scene", layers = "Layers", move = "Camera Move" }

    private var artwork: [Layer] { state.project.layers.filter(EditorState.isSceneArtwork) }
    private var subjects: [Layer] {
        state.project.layers.filter { $0.content == .camera || $0.content == .light }
    }
    private var targetCount: Int {
        artwork.filter { !$0.isLocked && (state.multiSelection?.contains($0.id) ?? true) }.count
    }

    var body: some View {
        VStack(spacing: 4) {
            PanelHeader(state: state, title: "3D Scene", showKeyNav: false)
            TSSegmented(options: Tab.allCases.map { ($0, $0.rawValue) }, selection: tab, label: "3D Scene") { tab = $0 }
                .padding(.horizontal, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    switch tab {
                    case .scene: scene
                    case .layers: layers
                    case .move: movement
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 16)
                .foregroundStyle(Theme.text)
            }
            .id(tab)
            .accessibilityIdentifier("scene-workspace-scroll")
        }
    }

    private var scene: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(state.activeCameraLayer?.name ?? "Default Camera", systemImage: "viewfinder")
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                Toggle("Camera View", isOn: $state.cameraView)
                    .fixedSize(horizontal: true, vertical: false)
                    .font(.caption).tint(Theme.accent)
            }
            .padding(.horizontal, 10).frame(minHeight: 44)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                tile("Camera", "video.fill") { state.addCamera(spatial: true); state.panel = .scene3D }
                    .accessibilityIdentifier("scene-add-camera")
                tile("Spot Light", "light.cylindrical.ceiling") { addLight(.spot) }
                tile("Point Light", "lightbulb.fill") { addLight(.point) }
                tile("Sun Light", "sun.max.fill") { addLight(.parallel) }
                tile("Ambient", "circle.hexagongrid.fill") { addLight(.ambient) }
                tile("More Lights", "plus.circle.fill") { state.showLightBrowser = true }
            }

            ForEach(subjects) { layer in
                HStack(spacing: 8) {
                    selectionRow(layer, detail: subjectDetail(layer))
                    Button {
                        state.select(layer.id)
                        state.panel = .threeD
                    } label: {
                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.accentGlow)
                    .accessibilityLabel(layer.content == .light ? "Open Lighting Studio for \(layer.name)" : "Edit \(layer.name)")
                }
            }
        }
    }

    private var layers: some View {
        VStack(alignment: .leading, spacing: 8) {
            if artwork.isEmpty {
                Text("Add artwork to place it in the scene.").font(.caption).foregroundStyle(Theme.textDim)
            }
            ForEach(artwork) { layer in
                VStack(alignment: .leading, spacing: 6) {
                    let chosen = state.selectedLayerID == layer.id
                    let depth = layer.transform.positionZ.value(at: state.currentTime)
                    selectionRow(layer, detail: layer.is3D ? String(format: "Z %.1f", depth) : "Flat")
                    if chosen {
                        placement(layer)
                    }
                }
                .padding(8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func placement(_ layer: Layer) -> some View {
        let time = state.currentTime
        let pos = layer.transform.position.value(at: time)
        let tr = layer.transform
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                NumberField(value: pos.x, label: "X", step: 0.1, controlHeight: 44,
                            onDragBegin: { state.beginPanelGesture("Scene X") },
                            onDragEnd: { state.endPanelGesture() }) { x in
                    setXY(layer.id, x: x, y: nil)
                }
                NumberField(value: pos.y, label: "Y", step: 0.1, controlHeight: 44,
                            onDragBegin: { state.beginPanelGesture("Scene Y") },
                            onDragEnd: { state.endPanelGesture() }) { y in
                    setXY(layer.id, x: nil, y: y)
                }
            }
            HStack(spacing: 8) {
                KeyframeDiamond(filled: tr.position.hasKeyframe(at: time) || tr.positionZ.hasKeyframe(at: time),
                                animated: tr.position.isAnimated || tr.positionZ.isAnimated) {
                    state.toggleKeyframe(.positionZ)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Keyframe Scene Position")
                Text("Depth Z").font(.subheadline)
                ValueScrubber(value: tr.positionZ.value(at: time), range: -6000...6000, step: 0.1, unit: " px",
                              onBegin: { state.beginEdit("Layer Depth") },
                              onChange: { state.setSceneDepth($0, for: layer.id, keepFraming: keepFraming) },
                              onEnd: { state.endEdit() }, allowBeyond: true, precisionTravel: 240)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Layer Depth Z")
            }
            Toggle("Keep Framing", isOn: $keepFraming)
                .font(.subheadline)
                .tint(Theme.accent)
                .frame(minHeight: 44)
            Toggle("3D Layer", isOn: Binding(get: { layer.is3D }, set: { enabled in
                state.mutate("3D Layer") { project in
                    guard let index = project.layers.firstIndex(where: { $0.id == layer.id }), !project.layers[index].isLocked else { return }
                    project.layers[index].is3D = enabled
                }
            })).tint(Theme.accent)
        }
        .disabled(layer.isLocked)
    }

    private var movement: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let camera = state.activeCameraLayer, EditorState.cameraIs3D(camera) {
                let end = state.project.snapToFrame(state.currentTime + duration)
                TSButton(title: "Key Move on \(camera.name)", icon: "video.badge.waveform") {
                    state.keySceneCameraMove(push: push / 100, duration: duration, drift: drift / 100, roll: turn)
                }
                .accessibilityIdentifier("scene-key-camera-move")
                .disabled(camera.isLocked || end > camera.outPoint - state.project.frameDuration + 1e-6)
            }
            Text(state.isMultiSelecting ? "\(targetCount) selected layers" : "\(targetCount) scene layers")
                .font(.subheadline.weight(.semibold))
            row("Layer Spacing", depth, 0...3000, " px") { depth = $0 }
            TSButton(title: "Make 3D Scene", icon: "square.3.layers.3d") {
                state.mangaPanelPush(depth: depth, addCamera: false)
            }.disabled(targetCount == 0)
            TSButton(title: "All Layers 3D", icon: "cube.fill") {
                state.mutate("All 3D") { project in
                    for i in project.layers.indices where EditorState.isSceneArtwork(project.layers[i]) && !project.layers[i].isLocked {
                        project.layers[i].is3D = true
                    }
                }
            }
            Divider()
            row("Push In", push, -80...80, "%") { push = $0 }
            row("Length", duration, 0.3...10, " s") { duration = $0 }
            row("Drift", drift, -20...20, "%") { drift = $0 }
            row("Roll", turn, -30...30, " deg") { turn = $0 }
            TSButton(title: "Make 3D Scene + Camera Move", icon: "camera.viewfinder", filled: true) {
                state.mangaPanelPush(depth: depth, push: push / 100, duration: duration, drift: drift / 100, turn: turn)
                tab = .scene
            }.disabled(targetCount == 0)
        }
    }

    private func addLight(_ type: LightType) {
        state.addLight(type)
        state.panel = .scene3D
    }

    private func subjectDetail(_ layer: Layer) -> String {
        if state.activeCameraLayer?.id == layer.id { return "Active" }
        if layer.content == .camera { return EditorState.cameraIs3D(layer) ? "3D Camera" : "2D Camera" }
        return layer.light?.type.title ?? "Light"
    }

    private func selectionRow(_ layer: Layer, detail: String) -> some View {
        Button { state.select(layer.id) } label: {
            HStack(spacing: 8) {
                Image(systemName: layer.content.symbol).frame(width: 22)
                Text(layer.name).lineLimit(1)
                Spacer(minLength: 4)
                Text(detail).font(.caption).lineLimit(1).foregroundStyle(Theme.textDim)
                if state.selectedLayerID == layer.id { Image(systemName: "checkmark").foregroundStyle(Theme.accentGlow) }
            }
            .font(.subheadline)
            .padding(.horizontal, 8)
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(layer.name)")
    }

    private func setXY(_ id: UUID, x: Double?, y: Double?) {
        updatePlacement(id, label: "Layer Position") { layer, time in
            let pos = layer.transform.position.value(at: time)
            layer.transform.position.set(Vec2(x ?? pos.x, y ?? pos.y), at: time)
        }
    }

    private func updatePlacement(_ id: UUID, label: String, _ change: (inout Layer, Double) -> Void) {
        let t = state.currentTime
        state.mutate(label) { project in
            guard let i = project.layers.firstIndex(where: { $0.id == id }), !project.layers[i].isLocked else { return }
            let previous = project.layers[i].transform
            change(&project.layers[i], t)
            project.layers[i].transform.pairPositionKeys(previous: previous, at: t)
        }
    }

    private func row(_ title: String, _ value: Double, _ range: ClosedRange<Double>, _ unit: String,
                     _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.subheadline).frame(width: 112, alignment: .leading)
            ValueScrubber(value: value, range: range, unit: unit, onChange: set)
                .frame(minHeight: 44)
        }
    }

    private func tile(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
