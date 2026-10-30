import SwiftUI

/// Context-sensitive bottom panel (changes with selection), like Alight Motion's tool area.
struct BottomPanel: View {
    @ObservedObject var state: EditorState
    @Binding var showPhotoPicker: Bool
    var startPen: (PenTarget, PenStyle) -> Void = { _, _ in }

    /// Panel height is the user's: drag the grabber to give the panel or the canvas more room.
    @AppStorage("awi.panelHeight") private var panelHeight: Double = 250
    @State private var dragBase: Double?

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.stroke)
            if state.panel != .none {
                grabber
                panelContent
                    .id(state.panel)                       // swap panels instantly: no overlapping cross-fade
                    .transaction { $0.animation = nil }
                    .frame(height: CGFloat(panelHeight), alignment: .top)
                    .clipped()
                Divider().overlay(Theme.stroke)
            }
            NavStrip(state: state, showPhotoPicker: $showPhotoPicker, startPen: startPen)
        }
        .background(Theme.background)
        .animation(.spring(response: 0.3, dampingFraction: 0.88), value: state.panel == .none)
    }

    private var grabber: some View {
        Capsule().fill(Theme.textDim.opacity(0.5)).frame(width: 40, height: 5)
            .frame(maxWidth: .infinity).frame(height: 16)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { g in
                    if dragBase == nil { dragBase = panelHeight }
                    panelHeight = min(520, max(150, (dragBase ?? 250) - Double(g.translation.height)))
                }
                .onEnded { _ in dragBase = nil })
            .accessibilityLabel("Resize panel")
    }

    @ViewBuilder private var panelContent: some View {
            Group {
                switch state.panel {
                case .add: AddPanel(state: state, showPhotoPicker: $showPhotoPicker, startPen: startPen)
                case .transform: TransformPanel(state: state)
                case .fill: FillPanel(state: state)
                case .blending: BlendingPanel(state: state)
                case .shape: ShapePanel(state: state)
                case .layerMenu: LayerMenuPanel(state: state)
                case .effects: EffectsPanel(state: state)
                case .text: TextPanel(state: state)
                case .masks: MasksPanel(state: state, startPen: startPen)
                case .clip: ClipPanel(state: state)
                case .threeD: ThreeDPanel(state: state)
                case .model: ModelPanel(state: state)
                case .physics: PhysicsPanel(state: state)
                case .presets: PresetsPanel(state: state)
                case .overlays: OverlaysPanel(state: state)
                case .multi: MultiSelectPanel(state: state)
                case .beats: BeatsPanel(state: state)
                case .cutout:
                    VStack(spacing: 0) {
                        PanelHeader(state: state, title: "AI Cutout", showKeyNav: false)
                        ScrollView { CutoutSection(state: state).padding(.horizontal, 12).padding(.bottom, 12) }
                    }
                case .style: StylePanel(state: state)
                case .motionBlur: MotionBlurPanel(state: state)
                case .scene: ScenePanel(state: state)
                case .time: TimePanel(state: state)
                case .none: EmptyView()
                }
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
            Button { state.panel = .none } label: {
                Image(systemName: "chevron.down").font(.system(size: 15, weight: .semibold)).frame(width: 34, height: 34)
            }
            .accessibilityLabel("Panel Back")
            Text(title).font(.system(size: 14, weight: .semibold))
            Spacer()
            if showKeyNav, state.selectedLayer != nil {
                Button { state.jumpKeyframe(forward: false) } label: { Image(systemName: "chevron.left.to.line").frame(width: 32, height: 32) }
                Button { state.jumpKeyframe(forward: true) } label: { Image(systemName: "chevron.right.to.line").frame(width: 32, height: 32) }
            }
            Button { state.select(nil) } label: { Image(systemName: "xmark").frame(width: 32, height: 32) }
                .accessibilityLabel("Deselect")
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
    var startPen: (PenTarget, PenStyle) -> Void = { _, _ in }
    @EnvironmentObject private var drawLauncher: DrawLauncher
    @EnvironmentObject private var mediaLauncher: MediaLauncher

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Add", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    section("Basic") {
                        ToolTile(icon: "textformat", title: "Text") { state.addText() }
                        ForEach(ShapeKind.allCases.filter { $0 != .path }) { k in
                            ToolTile(icon: k.symbol, title: k.title) { state.addShape(k) }
                        }
                        ToolTile(icon: "rectangle.fill", title: "Solid") { state.addSolid() }
                        ToolTile(icon: "slider.horizontal.below.rectangle", title: "Adjustment") { state.addAdjustmentLayer() }
                    }
                    section("Draw") {
                        ToolTile(icon: "paintbrush.pointed.fill", title: "Draw Studio") { drawLauncher.open(nil) }
                        ToolTile(icon: "pencil.tip", title: "Pen Path") { startPen(.newShape, .points) }
                        ToolTile(icon: "scribble", title: "Draw Path") { startPen(.newShape, .freehand) }
                    }
                    section("Media") {
                        ToolTile(icon: "photo.on.rectangle", title: "Image") { showPhotoPicker = true }
                        ToolTile(icon: "film", title: "Video") { mediaLauncher.pickVideo = true }
                        ToolTile(icon: "music.note", title: "Audio") { mediaLauncher.pickAudio = true }
                        ToolTile(icon: "sun.haze", title: "Overlays") { state.panel = .overlays }
                    }
                    section("3D") {
                        ToolTile(icon: "cube.transparent", title: "3D Text") { state.addModelLayer(text: "AWI", fileURL: nil) }
                        ToolTile(icon: "shippingbox", title: "3D Model") { mediaLauncher.pickModel = true }
                        ToolTile(icon: "video", title: "Camera") { state.addCamera() }
                        ToolTile(icon: "lightbulb.fill", title: "Light") { state.addLight() }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) { c() }
        }
    }
}

// MARK: - Transform

struct TransformPanel: View {
    @ObservedObject var state: EditorState
    @State private var showGraph = false
    @EnvironmentObject private var drawLauncher: DrawLauncher

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: state.selectedLayer?.name ?? "Layer")
            ScrollView {
                VStack(spacing: 6) {
                    if state.selectedLayer != nil { TransformToolBar(state: state) }
                    if let layer = state.selectedLayer {
                        let t = state.currentTime
                        let pos = layer.transform.position.value(at: t)
                        let sc = layer.transform.scale.value(at: t)
                        PropertyRow(state: state, key: .position) {
                            NumberField(value: pos.x, label: "X") { v in set { $0.transform.position.set(Vec2(v, pos.y), at: t) } }
                            NumberField(value: pos.y, label: "Y") { v in set { $0.transform.position.set(Vec2(pos.x, v), at: t) } }
                        }
                        PropertyRow(state: state, key: .scale) {
                            if state.scaleLinked {
                                NumberField(value: sc.x, label: "%", step: 1) { v in
                                    set { $0.transform.scale.set(Vec2(v, v * (sc.x == 0 ? 1 : sc.y / sc.x)), at: t) }
                                }
                            } else {
                                NumberField(value: sc.x, label: "W%", step: 1) { v in set { $0.transform.scale.set(Vec2(v, sc.y), at: t) } }
                                NumberField(value: sc.y, label: "H%", step: 1) { v in set { $0.transform.scale.set(Vec2(sc.x, v), at: t) } }
                            }
                        }
                        PropertyRow(state: state, key: .anchor) {
                            let a = layer.transform.anchor.value(at: t)
                            NumberField(value: a.x, label: "X") { v in set { $0.transform.anchor.set(Vec2(v, a.y), at: t) } }
                            NumberField(value: a.y, label: "Y") { v in set { $0.transform.anchor.set(Vec2(a.x, v), at: t) } }
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

    private var easingRow: some View {
        HStack {
            Button { showGraph = true } label: {
                Label("Graph", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent.opacity(0.25)))
                    .foregroundStyle(Theme.accentGlow)
            }
            .sheet(isPresented: $showGraph) { GraphEditorSheet(state: state).presentationDetents([.large]) }
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
        state.coalescedEdit("Edit Transform", change)
    }
}

/// Label + keyframe diamond + controls.
struct PropertyRow<Content: View>: View {
    @ObservedObject var state: EditorState
    let key: PropertyKey
    @ViewBuilder let content: () -> Content
    @State private var showExpression = false

    var body: some View {
        let hasExpr = state.expression(key) != nil
        HStack(spacing: 6) {
            KeyframeDiamond(filled: state.hasKeyframe(key), animated: state.isAnimated(key)) { state.toggleKeyframe(key) }
            Button { showExpression = true } label: {
                Text("={}").font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(hasExpr ? (state.expressionError(key) == nil ? Theme.ok : Theme.danger) : Theme.textDim)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Expression")
            Text(key.title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
                .frame(width: 76, alignment: .leading)
            content()
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showExpression) {
            ExpressionSheet(state: state, key: key).presentationDetents([.medium, .large])
        }
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
                            state.coalescedEdit("Edit Fill") { l in
                                if l.text != nil { l.text?.fill.set(col.rgba, at: t) } else { l.fill.set(col.rgba, at: t) }
                            }
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
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TRACK MATTE (uses the layer above)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(TrackMatte.allCases) { m in
                                        Button {
                                            state.mutate("Track Matte") { p in if let i = state.selectedIndex { p.layers[i].trackMatte = m } }
                                        } label: {
                                            Text(m.title).font(.system(size: 12, weight: .semibold))
                                                .padding(.horizontal, 10).padding(.vertical, 7)
                                                .background(Capsule().fill(layer.trackMatte == m ? Theme.accent : Theme.surface))
                                                .foregroundStyle(layer.trackMatte == m ? Color.white : Theme.text)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(m != .none && state.selectedIndex == 0)
                                    }
                                }
                            }
                            if state.selectedIndex == 0 && layer.trackMatte == .none {
                                Text("Move a matte layer (text, shape, image…) above this one to use it as a track matte.")
                                    .font(.caption).foregroundStyle(Theme.textDim)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12).padding(.bottom, 12)
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
                        StrokeSection(state: state)
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
        state.coalescedEdit("Edit Shape", change)
    }
}

// MARK: - Layer menu

struct LayerMenuPanel: View {
    @ObservedObject var state: EditorState
    @EnvironmentObject private var mediaLauncher: MediaLauncher
    @State private var showRename = false
    @State private var renaming = ""
    @State private var showParent = false

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Layer", showKeyNav: false)
            ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ToolTile(icon: "character.cursor.ibeam", title: "Rename") { renaming = state.selectedLayer?.name ?? ""; showRename = true }
                ToolTile(icon: state.selectedLayer?.isLocked == true ? "lock.fill" : "lock.open", title: state.selectedLayer?.isLocked == true ? "Unlock" : "Lock",
                         active: state.selectedLayer?.isLocked == true) {
                    state.mutate("Lock Layer") { p in if let i = state.selectedIndex { p.layers[i].isLocked.toggle() } }
                }
                ToolTile(icon: "s.circle", title: "Solo", active: state.selectedLayer?.isSolo == true) {
                    state.mutate("Solo Layer") { p in if let i = state.selectedIndex { p.layers[i].isSolo.toggle() } }
                }
                ToolTile(icon: "plus.square.on.square", title: "Duplicate") { state.duplicateSelected() }
                ToolTile(icon: "link", title: state.selectedLayer?.parentID == nil ? "Parent" : "Parented", active: state.selectedLayer?.parentID != nil) { showParent = true }
                ToolTile(icon: "doc.on.doc", title: "Copy Keys") { state.copyKeyframes() }
                ToolTile(icon: "doc.on.clipboard", title: "Paste Keys") { state.pasteKeyframes() }
                ToolTile(icon: "checklist", title: "Select Many") { if let id = state.selectedLayerID { state.beginMultiSelect(id) } }
                if case .precomp = state.selectedLayer?.content {
                    ToolTile(icon: "arrow.down.right.and.arrow.up.left", title: "Open Pre-comp") { state.openPrecomp() }
                } else {
                    ToolTile(icon: "square.stack.3d.up", title: "Pre-compose") { state.precomposeSelected() }
                }
                if state.selectedLayer?.isMedia == true || state.selectedLayer?.isImage == true {
                    ToolTile(icon: "arrow.triangle.2.circlepath", title: "Replace Media") { mediaLauncher.replaceTarget = state.selectedLayerID }
                }
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
            .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showParent) { ParentPicker(state: state) }
        .alert("Rename Layer", isPresented: $showRename) {
            TextField("Name", text: $renaming)
            Button("Rename") {
                let n = renaming.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { state.mutate("Rename Layer") { p in if let i = state.selectedIndex { p.layers[i].name = n } } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
