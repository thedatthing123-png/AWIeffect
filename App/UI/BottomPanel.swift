import SwiftUI

/// Context-sensitive bottom panel (changes with selection), like Alight Motion's tool area.
struct BottomPanel: View {
    @ObservedObject var state: EditorState
    @Binding var showPhotoPicker: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.stroke)
            Group {
                switch state.panel {
                case .add: AddPanel(state: state, showPhotoPicker: $showPhotoPicker)
                case .transform: TransformPanel(state: state)
                case .fill: FillPanel(state: state)
                case .blending: BlendingPanel(state: state)
                case .shape: ShapePanel(state: state)
                case .layerMenu: LayerMenuPanel(state: state)
                case .none: idle
                }
            }
            .frame(height: 236)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: state.panel)
        }
        .background(Theme.background)
    }

    private var idle: some View {
        VStack(spacing: 14) {
            Spacer()
            Button { state.panel = .add } label: {
                Label("Add Layer", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 60)
            Text("Tap a layer in the timeline or on the canvas to edit it.")
                .font(.footnote).foregroundStyle(Theme.textDim)
            Spacer()
        }
    }
}

/// Header row shared by panels: back + title + keyframe nav.
struct PanelHeader: View {
    @ObservedObject var state: EditorState
    let title: String
    var showKeyNav = true

    var body: some View {
        HStack(spacing: 4) {
            Button { state.panel = state.selectedLayer == nil ? .none : .transform } label: {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).frame(width: 34, height: 34)
            }
            .opacity(state.panel == .transform || state.panel == .add ? 0 : 1)
            .disabled(state.panel == .transform || state.panel == .add)
            Text(title).font(.system(size: 14, weight: .semibold))
            Spacer()
            if showKeyNav, state.selectedLayer != nil {
                Button { state.jumpKeyframe(forward: false) } label: { Image(systemName: "chevron.left.to.line").frame(width: 32, height: 32) }
                Button { state.jumpKeyframe(forward: true) } label: { Image(systemName: "chevron.right.to.line").frame(width: 32, height: 32) }
            }
            Button { state.select(nil) } label: { Image(systemName: "xmark").frame(width: 32, height: 32) }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 8)
        .frame(height: 40)
    }
}

// MARK: - Add

struct AddPanel: View {
    @ObservedObject var state: EditorState
    @Binding var showPhotoPicker: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Layer").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Button { state.panel = .none } label: { Image(systemName: "xmark").frame(width: 32, height: 32) }
                    .foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 14).frame(height: 40)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(ShapeKind.allCases) { k in
                        ToolTile(icon: k.symbol, title: k.title) { state.addShape(k) }
                    }
                    ToolTile(icon: "rectangle.fill", title: "Solid") { state.addSolid() }
                    ToolTile(icon: "photo.on.rectangle", title: "Image") { showPhotoPicker = true }
                }
                .padding(.horizontal, 12)
                Text("Video, audio, text, drawing and 3D layers arrive in later stages.")
                    .font(.caption).foregroundStyle(Theme.textDim).padding(.top, 10)
            }
        }
    }
}

// MARK: - Transform

struct TransformPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: state.selectedLayer?.name ?? "Layer")
            ScrollView {
                VStack(spacing: 6) {
                    tileRow
                    if let layer = state.selectedLayer {
                        let t = state.currentTime
                        let pos = layer.transform.position.value(at: t)
                        let sc = layer.transform.scale.value(at: t)
                        PropertyRow(state: state, key: .position) {
                            NumberField(value: pos.x, label: "X") { v in set { $0.transform.position.set(Vec2(v, pos.y), at: t) } }
                            NumberField(value: pos.y, label: "Y") { v in set { $0.transform.position.set(Vec2(pos.x, v), at: t) } }
                        }
                        PropertyRow(state: state, key: .scale) {
                            NumberField(value: sc.x, label: "%", step: 1) { v in
                                set { $0.transform.scale.set(Vec2(v, v * (sc.x == 0 ? 1 : sc.y / sc.x)), at: t) }
                            }
                        }
                        SliderRow(state: state, key: .rotation, value: layer.transform.rotation.value(at: t), range: -360...360, unit: "°") { v in
                            state.mutateLayer { $0.transform.rotation.set(v, at: t) }
                        }
                        SliderRow(state: state, key: .opacity, value: layer.transform.opacity.value(at: t), range: 0...100, unit: "%") { v in
                            state.mutateLayer { $0.transform.opacity.set(v, at: t) }
                        }
                        easingRow
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    private var tileRow: some View {
        HStack(spacing: 8) {
            ToolTile(icon: "paintpalette", title: "Color & Fill") { state.panel = .fill }
            ToolTile(icon: "square.stack.3d.down.right", title: "Blending") { state.panel = .blending }
            if case .shape = state.selectedLayer?.content {
                ToolTile(icon: "skew", title: "Edit Shape") { state.panel = .shape }
            }
            ToolTile(icon: "scissors", title: "Split") { state.splitSelected() }
            ToolTile(icon: "ellipsis", title: "More") { state.panel = .layerMenu }
        }
    }

    private var easingRow: some View {
        HStack {
            Text("Keyframe easing").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textDim)
            Spacer()
            ForEach(Interpolation.allCases, id: \.self) { i in
                Button(i.rawValue.capitalized) { state.setInterpolation(i) }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Theme.raised))
                    .foregroundStyle(Theme.text)
            }
        }
        .padding(.top, 4)
    }

    private func set(_ change: (inout Layer) -> Void) {
        state.beginEdit("Edit Transform")
        state.mutateLayer(change)
        state.endEdit()
    }
}

/// Label + keyframe diamond + controls.
struct PropertyRow<Content: View>: View {
    @ObservedObject var state: EditorState
    let key: PropertyKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            KeyframeDiamond(filled: state.hasKeyframe(key), animated: state.isAnimated(key)) { state.toggleKeyframe(key) }
            Text(key.title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
                .frame(width: 84, alignment: .leading)
            content()
        }
        .padding(.vertical, 2)
    }
}

struct SliderRow: View {
    @ObservedObject var state: EditorState
    let key: PropertyKey
    let value: Double
    let range: ClosedRange<Double>
    let unit: String
    let onChange: (Double) -> Void

    var body: some View {
        PropertyRow(state: state, key: key) {
            // One undo step per drag: beginEdit is idempotent until endEdit.
            Slider(value: Binding(get: { value }, set: { v in
                state.beginEdit("Edit \(key.title)")
                onChange(v)
            }), in: range) { editing in if !editing { state.endEdit() } }
            Text(String(format: "%.1f%@", value, unit))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.accentGlow)
                .frame(width: 62, alignment: .trailing)
        }
    }
}

/// Tappable number that edits by horizontal drag (like AE scrubby values) or by typing.
struct NumberField: View {
    let value: Double
    let label: String
    var step: Double = 1
    let onCommit: (Double) -> Void
    @State private var editing = false
    @State private var text = ""
    @State private var dragBase: Double?

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textDim)
            if editing {
                TextField("", text: $text, onCommit: {
                    if let v = Double(text) { onCommit(v) }
                    editing = false
                })
                .keyboardType(.numbersAndPunctuation)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.accentGlow)
            } else {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.accentGlow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { text = String(format: "%.1f", value); editing = true }
                    .gesture(DragGesture(minimumDistance: 3)
                        .onChanged { g in
                            if dragBase == nil { dragBase = value }
                            onCommit(((dragBase ?? value) + Double(g.translation.width) * step).rounded())
                        }
                        .onEnded { _ in dragBase = nil })
            }
        }
        .padding(.horizontal, 10).frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
    }
}

// MARK: - Fill

struct FillPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Color & Fill")
            if let layer = state.selectedLayer {
                let t = state.currentTime
                let c = layer.fill.value(at: t)
                VStack(spacing: 12) {
                    PropertyRow(state: state, key: .fill) {
                        ColorPicker("", selection: Binding(get: { Color(c) }, set: { col in
                            state.beginEdit("Edit Fill")
                            state.mutateLayer { $0.fill.set(col.rgba, at: t) }
                            state.endEdit()
                        }), supportsOpacity: true)
                        .labelsHidden()
                        Spacer()
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(swatches, id: \.self) { hex in
                                Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(Color.white.opacity(0.2)))
                                    .onTapGesture {
                                        state.beginEdit("Edit Fill")
                                        state.mutateLayer { $0.fill.set(RGBA(hex: hex, alpha: c.a), at: t) }
                                        state.endEdit()
                                    }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    if case .image = layer.content {
                        Text("Image layers use their own colors; fill tints arrive with Color effects.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                    }
                }
                .padding(.horizontal, 12)
                Spacer()
            }
        }
    }

    private let swatches: [UInt32] = [0xFFFFFF, 0x000000, 0x9B5CFF, 0xB98CFF, 0x5C8CFF, 0x3FD6C6, 0x5CD67A,
                                      0xFFC75C, 0xFF8A3D, 0xFF5C7A, 0xFF5CA8, 0x8A8A8A]
}

// MARK: - Blending

struct BlendingPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Blending & Opacity")
            if let layer = state.selectedLayer {
                ScrollView {
                    VStack(spacing: 10) {
                        SliderRow(state: state, key: .opacity, value: layer.transform.opacity.value(at: state.currentTime),
                                  range: 0...100, unit: "%") { v in
                            let t = state.currentTime
                            state.mutateLayer { $0.transform.opacity.set(v, at: t) }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(BlendMode.allCases) { m in
                                Button {
                                    state.mutate("Blend Mode") { p in
                                        if let i = state.selectedIndex { p.layers[i].blendMode = m }
                                    }
                                } label: {
                                    Text(m.title).font(.system(size: 12, weight: .semibold))
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .background(RoundedRectangle(cornerRadius: 9)
                                            .fill(layer.blendMode == m ? Theme.accent.opacity(0.3) : Theme.surface))
                                        .foregroundStyle(layer.blendMode == m ? Theme.accentGlow : Theme.text)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }
}

// MARK: - Shape

struct ShapePanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Edit Shape")
            if let layer = state.selectedLayer, case .shape(let kind) = layer.content {
                let t = state.currentTime
                let size = layer.size.value(at: t)
                ScrollView {
                    VStack(spacing: 8) {
                        PropertyRow(state: state, key: .size) {
                            NumberField(value: size.x, label: "W") { v in edit { $0.size.set(Vec2(max(1, v), size.y), at: t) } }
                            NumberField(value: size.y, label: "H") { v in edit { $0.size.set(Vec2(size.x, max(1, v)), at: t) } }
                        }
                        if kind == .rectangle {
                            SliderRow(state: state, key: .cornerRadius, value: layer.cornerRadius.value(at: t),
                                      range: 0...max(1, min(size.x, size.y) / 2), unit: "") { v in
                                state.mutateLayer { $0.cornerRadius.set(v, at: t) }
                            }
                        }
                        if kind == .polygon || kind == .star {
                            Stepper("Points: \(Int(layer.sides.value(at: t)))", value: Binding(
                                get: { Int(layer.sides.value(at: t)) },
                                set: { v in edit { $0.sides.set(Double(v), at: t) } }), in: 3...24)
                            .foregroundStyle(Theme.text)
                        }
                        if kind == .star {
                            HStack {
                                Text("Inner radius").font(.system(size: 13)).foregroundStyle(Theme.text)
                                Slider(value: Binding(get: { layer.innerRatio.value(at: t) }, set: { v in
                                    state.beginEdit("Inner Radius")
                                    state.mutateLayer { $0.innerRatio.set(v, at: t) }
                                }), in: 0.1...0.95) { e in if !e { state.endEdit() } }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    private func edit(_ change: (inout Layer) -> Void) {
        state.beginEdit("Edit Shape")
        state.mutateLayer(change)
        state.endEdit()
    }
}

// MARK: - Layer menu

struct LayerMenuPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Layer", showKeyNav: false)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ToolTile(icon: "plus.square.on.square", title: "Duplicate") { state.duplicateSelected() }
                ToolTile(icon: "arrow.up", title: "Move Up") { state.moveSelected(up: true) }
                ToolTile(icon: "arrow.down", title: "Move Down") { state.moveSelected(up: false) }
                ToolTile(icon: "scissors", title: "Split") { state.splitSelected() }
                ToolTile(icon: "eye", title: "Hide/Show") { if let id = state.selectedLayerID { state.toggleVisibility(id) } }
                ToolTile(icon: "paintpalette", title: "Tag Color") {
                    state.mutate("Tag Color") { p in
                        guard let i = state.selectedIndex else { return }
                        let all = LayerTag.allCases
                        let next = (all.firstIndex(of: p.layers[i].tag)! + 1) % all.count
                        p.layers[i].tag = all[next]
                    }
                }
                ToolTile(icon: "trash", title: "Delete") { state.deleteSelected() }
            }
            .padding(.horizontal, 12)
            Spacer()
        }
    }
}
