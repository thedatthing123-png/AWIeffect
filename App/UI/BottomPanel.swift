import SwiftUI

/// Context-sensitive bottom panel (changes with selection), like Alight Motion's tool area.
struct BottomPanel: View {
    @ObservedObject var state: EditorState
    @Binding var showPhotoPicker: Bool
    var startPen: (PenTarget, PenStyle) -> Void = { _, _ in }

    /// Panel height is the user's: drag the grabber to give the panel or the canvas more room.
    @AppStorage("awi.panelHeight") private var panelHeight: Double = 250
    @State private var dragBase: Double?
    /// Height while the grabber is held (saved to panelHeight on release, so dragging never writes settings).
    @State private var liveHeight: Double?

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.stroke)
            if state.panel != .none {
                grabber
                panelContent
                    // Pinned to the leading edge: a slightly-too-wide row can never push the header's buttons off-screen.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(state.panel)                       // swap panels instantly: no overlapping cross-fade
                    .transaction { $0.animation = nil }
                    .frame(height: CGFloat(min(liveHeight ?? panelHeight, Double(UIScreen.main.bounds.height) * 0.42)), alignment: .top)
                    .clipped()
                Divider().overlay(Theme.stroke)
            }
            NavStrip(state: state, showPhotoPicker: $showPhotoPicker, startPen: startPen)
        }
        .background(Theme.background)
        .animation(.spring(response: 0.2, dampingFraction: 0.9), value: state.panel == .none)
    }

    private var grabber: some View {
        Capsule().fill(Theme.textDim.opacity(0.5)).frame(width: 40, height: 5)
            .frame(maxWidth: .infinity).frame(height: 16)
            .contentShape(Rectangle())
            // Screen coordinates: the grabber moves with the panel, so local coordinates fed back into the drag (twitch).
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { g in
                    if dragBase == nil { dragBase = panelHeight }
                    let cap = min(520, Double(UIScreen.main.bounds.height) * 0.42)
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { liveHeight = min(cap, max(150, (dragBase ?? 250) - Double(g.translation.height))) }
                }
                .onEnded { _ in
                    if let h = liveHeight { panelHeight = h }
                    liveHeight = nil; dragBase = nil
                })
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
                        PanelHeader(state: state, title: "Remove Background (AI)", showKeyNav: false)
                        ScrollView { CutoutSection(state: state).padding(.horizontal, 12).padding(.bottom, 12) }
                    }
                case .style: StylePanel(state: state)
                case .motionBlur: MotionBlurPanel(state: state)
                case .scene: ScenePanel(state: state)
                case .time: TimePanel(state: state)
                case .scene3D: Scene3DPanel(state: state)
                case .puppet: PuppetPanel(state: state)
                case .ccStudio: CCStudioPanel(state: state)
                case .rig: RigPanel(state: state)
                case .layerHome: LayerHomePanel(state: state)
                case .graph: FlowGraphPanel(state: state)
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
    /// Effects panel: Copy All / Paste All instead of the keyframe arrows.
    var effectTools = false

    var body: some View {
        HStack(spacing: 4) {
            Button { state.panel = .none } label: {
                Image(systemName: "chevron.down").font(.system(size: 15, weight: .semibold)).frame(width: 34, height: 34)
            }
            .accessibilityLabel("Panel Back")
            Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1).truncationMode(.middle)
            Spacer()
            if effectTools, state.selectedLayer != nil {
                Button { state.copyEffects() } label: { Label("Copy All", systemImage: "doc.on.doc").labelStyle(.iconOnly).frame(width: 32, height: 32) }
                    .disabled(state.selectedLayer?.effects.isEmpty ?? true)
                    .accessibilityLabel("Copy All Effects")
                Button { state.pasteEffects() } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "doc.on.clipboard").frame(width: 32, height: 32)
                        if !state.effectClipboard.isEmpty {
                            Text("\(state.effectClipboard.count)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                .padding(3).background(Circle().fill(Theme.accent)).offset(x: 4, y: -2)
                        }
                    }
                }
                .disabled(state.effectClipboard.isEmpty)
                .accessibilityLabel("Paste Effects")
            } else if showKeyNav, state.selectedLayer != nil {
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
                        ToolTile(icon: "sparkles", title: "Particles") { state.addParticleLayer() }
                    }
                    section("Draw") {
                        ToolTile(icon: "paintbrush.pointed.fill", title: "Draw Studio") { drawLauncher.open(nil) }
                        ToolTile(icon: "pencil.tip", title: "Pen Path") { startPen(.newShape, .points) }
                        ToolTile(icon: "scribble", title: "Draw Path") { startPen(.newShape, .freehand) }
                    }
                    section("Media") {
                        ToolTile(icon: "photo.on.rectangle", title: "Media") { showPhotoPicker = true }
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
        .awiSheet(isPresented: $showExpression) {
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
            // One undo step per drag / typed value.
            ValueScrubber(value: value, range: range, unit: unit, onBegin: { state.beginEdit("Edit \(key.title)") },
                          onChange: onChange, onEnd: { state.endEdit() }, allowBeyond: true)
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
                    .lineLimit(1).minimumScaleFactor(0.55)
                    .foregroundStyle(Theme.accentGlow)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
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
        .padding(.horizontal, 8).frame(minWidth: 0).frame(height: 34)
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
                let c = layer.text?.fill.value(at: t) ?? layer.fill.value(at: t)
                VStack(spacing: 12) {
                    PropertyRow(state: state, key: .fill) {
                        AWIColorWell("", selection: Binding(get: { Color(c) }, set: { col in
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
                                        state.mutateLayer { l in
                                            if l.text != nil { l.text?.fill.set(RGBA(hex: hex, alpha: c.a), at: t) } else { l.fill.set(RGBA(hex: hex, alpha: c.a), at: t) }
                                        }
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
                        ForEach(BlendMode.groups, id: \.self) { grp in
                        Text(grp.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(BlendMode.allCases.filter { $0.group == grp }) { m in
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
                        Toggle(isOn: Binding(get: { layer.clipToBelow }, set: { v in
                            state.mutate("Clip to Layer Below") { p in if let i = state.selectedIndex { p.layers[i].clipToBelow = v } }
                        })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clip to Layer Below").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                                Text("Only shows on the layer under this one").font(.caption).foregroundStyle(Theme.textDim)
                            }
                        }
                        .tint(Theme.accent)
                        .disabled(state.selectedIndex.map { $0 + 1 >= state.project.layers.count } ?? true)
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
                        ShapeOpsSection(state: state)
                        if kind == .star {
                            HStack {
                                Text("Inner radius").font(.system(size: 13)).foregroundStyle(Theme.text)
                                ValueScrubber(value: layer.innerRatio.value(at: t), range: 0.1...0.95, onBegin: { state.beginEdit("Inner Radius") },
                                              onChange: { v in state.mutateLayer { $0.innerRatio.set(v, at: t) } }, onEnd: { state.endEdit() })
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
                ToolTile(icon: "sparkles.rectangle.stack", title: "Copy Effects") { state.copyEffects() }
                if !state.effectClipboard.isEmpty {
                    ToolTile(icon: "sparkles", title: "Paste Effects (\(state.effectClipboard.count))") { state.pasteEffects() }
                }
                ToolTile(icon: "doc.on.clipboard", title: "Paste Keys") { state.pasteKeyframes() }
                ToolTile(icon: "checklist", title: "Select Many") { if let id = state.selectedLayerID { state.beginMultiSelect(id) } }
                if case .precomp = state.selectedLayer?.content {
                    ToolTile(icon: "arrow.down.right.and.arrow.up.left", title: "Open Pre-comp") { state.openPrecomp() }
                } else {
                    ToolTile(icon: "folder.badge.plus", title: "Group") { state.groupSelected() }
                    ToolTile(icon: "square.stack.3d.up", title: "Pre-compose") { state.precomposeSelected() }
                }
                if state.selectedLayer?.isMedia == true || state.selectedLayer?.isImage == true {
                    ToolTile(icon: "arrow.triangle.2.circlepath", title: "Replace Media") { mediaLauncher.replaceTarget = state.selectedLayerID }
                }
                if case .video(_, _, _, true)? = state.selectedLayer?.content {
                    ToolTile(icon: "waveform.badge.plus", title: "Extract Audio") { state.extractAudioFromSelected() }
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
        .awiSheet(isPresented: $showParent) { ParentPicker(state: state) }
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
