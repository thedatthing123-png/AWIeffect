import SwiftUI

struct ShapeContentsSection: View {
    @ObservedObject var state: EditorState
    let startPen: (PenTarget, PenStyle) -> Void
    @State private var renameID: UUID?
    @State private var name = ""
    @State private var rename = false
    @State private var wholeLayerOps = false

    var body: some View {
        if let l = state.selectedLayer, case .shape = l.content {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("CONTENTS").font(.caption.bold()).foregroundStyle(Theme.textDim)
                    Spacer()
                    Menu {
                        Button("Rectangle") { state.addShapeContent(.rectangle) }
                        Button("Ellipse") { state.addShapeContent(.ellipse) }
                        Button("Star") { state.addShapeContent(.star) }
                        Button("Polygon") { state.addShapeContent(.polygon) }
                        Button("Pen Path") {
                            state.addShapeContent(.path)
                            if let id = state.selectedShapeContentID { startPen(.shapePath(l.id, id), .points) }
                        }
                        Menu("Merge Paths") {
                            ForEach(MergePathsMode.allCases) { mode in Button(mode.rawValue) { state.addMergePaths(mode) } }
                        }
                    } label: { Label("Add", systemImage: "plus.circle.fill").frame(minWidth: 88, minHeight: 44) }
                    .accessibilityLabel("Add Shape Content")
                }
                ForEach(l.editableShapeContents) { item in
                    HStack(spacing: 4) {
                        Button {
                            state.selectedShapeContentID = item.id
                        } label: {
                            HStack {
                                Image(systemName: item.component == nil ? "square.on.square" : "line.3.horizontal")
                                Text(item.name).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("Select \(item.name)")
                        Button {
                            state.editShapeContent(item.id, "Path Visibility") { $0.visible.toggle() }
                        } label: { Image(systemName: item.visible ? "eye" : "eye.slash").frame(width: 44, height: 44) }
                        .accessibilityLabel("Visibility \(item.name)")
                        Menu {
                            Button("Rename") { renameID = item.id; name = item.name; rename = true }
                            if item.component != nil {
                                Button("Edit Points") { state.selectedShapeContentID = item.id; startPen(.shapePath(l.id, item.id), .points) }
                            }
                            Button("Move Up") { move(item.id, in: l.editableShapeContents, by: -1) }
                            Button("Move Down") { move(item.id, in: l.editableShapeContents, by: 1) }
                            Button("Delete", role: .destructive) { state.removeShapeContent(item.id) }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("Options \(item.name)")
                    }
                    .foregroundStyle(Theme.text).padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(state.selectedShapeContent?.id == item.id ? Theme.accent.opacity(0.25) : Theme.surface))
                    .draggable(item.id.uuidString)
                    .dropDestination(for: String.self) { values, _ in
                        guard let value = values.first, let id = UUID(uuidString: value) else { return false }
                        state.moveShapeContent(id, before: item.id); return true
                    }
                }
                Text("Drag rows to reorder. Merge Paths uses the paths above it; Subtract cuts them out of the bottom path.")
                    .font(.caption).foregroundStyle(Theme.textDim)
                if let item = state.selectedShapeContent {
                    if let mode = item.merge {
                        Picker("Merge Mode", selection: Binding(get: { mode }, set: { m in state.editShapeContent(item.id, "Merge Mode") { $0.merge = m } })) {
                            ForEach(MergePathsMode.allCases) { m in Text(m.rawValue).tag(m) }
                        }.pickerStyle(.menu).frame(minHeight: 44)
                    }
                    if let c = item.component {
                        HStack {
                            if c.kind == .path {
                                KeyframeDiamond(filled: c.path.hasKeyframe(at: state.currentTime), animated: c.path.isAnimated) {
                                    state.editShapeContent(item.id, "Path Keyframe") { $0.component?.path.toggleKeyframe(at: state.currentTime) }
                                }
                            }
                            Button { startPen(.shapePath(l.id, item.id), .points) } label: {
                                Label("Edit Points", systemImage: "point.topleft.down.curvedto.point.bottomright.up").frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(.bordered)
                        }
                        ShapeComponentControls(state: state, id: item.id, component: c)
                        StrokeSection(state: state, contentID: item.id)
                        Picker("Trim Multiple Paths", selection: Binding(get: { c.trimMode }, set: { mode in
                            state.editShapeContent(item.id, "Trim Mode") { $0.component?.trimMode = mode }
                        })) {
                            ForEach(ShapeTrimMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                        }.pickerStyle(.menu).frame(minHeight: 44)
                    }
                    Picker("Operators", selection: $wholeLayerOps) {
                        Text("Selected Path").tag(false); Text("Whole Layer").tag(true)
                    }.pickerStyle(.segmented).frame(minHeight: 44)
                    if wholeLayerOps || item.component != nil {
                        ShapeOpsSection(state: state, contentID: wholeLayerOps ? nil : item.id)
                    }
                }
            }
            .alert("Rename Path", isPresented: $rename) {
                TextField("Name", text: $name)
                Button("Cancel", role: .cancel) { }
                Button("Save") { if let id = renameID { state.editShapeContent(id, "Rename Path") { $0.name = name.isEmpty ? "Path" : name } } }
            }
        }
    }

    private func move(_ id: UUID, in items: [ShapeContent], by delta: Int) {
        guard let i = items.firstIndex(where: { $0.id == id }), items.indices.contains(i + delta) else { return }
        state.beginEdit("Reorder Shape Contents")
        state.mutateLayer { l in var all = l.editableShapeContents; all.swapAt(i, i + delta); l.shapeContents = all }
        state.endEdit()
    }
}

struct ShapeComponentControls: View {
    @ObservedObject var state: EditorState
    let id: UUID
    let component: ShapeComponent
    var fillOnly = false
    private var t: Double { state.currentTime }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !fillOnly {
            DisclosureGroup("Path Transform") {
                vector("Position", component.position, \.position, -2000...2000)
                vector("Scale %", component.scale, \.scale, -500...500)
                scalar("Rotation", component.rotation, \.rotation, -720...720)
                scalar("Opacity", component.opacity, \.opacity, 0...100)
            }
            if component.kind != .path {
                vector("Size", component.size, \.size, 1...2000)
                if component.kind == .rectangle { scalar("Roundness", component.roundness, \.roundness, 0...500) }
                if component.kind == .star || component.kind == .polygon { scalar("Points", component.sides, \.sides, 3...50) }
                if component.kind == .star { scalar("Inner Radius", component.innerRatio, \.innerRatio, 0.01...1, step: 0.01) }
            }
            }
            Toggle("Fill", isOn: Binding(get: { component.fillOn }, set: { value in edit("Fill") { $0.fillOn = value } })).frame(minHeight: 44)
            if component.fillOn {
                HStack {
                    KeyframeDiamond(filled: component.fill.hasKeyframe(at: t), animated: component.fill.isAnimated) { edit("Fill Keyframe") { $0.fill.toggleKeyframe(at: t) } }
                    AWIColorWell("Fill Color", selection: Binding(get: { Color(component.fill.value(at: t)) }, set: { color in edit("Fill Color") { $0.fill.set(color.rgba, at: t) } }))
                }.frame(minHeight: 44)
                ShapeGradientControls(state: state, id: id, gradient: component.fillGradient, stroke: false)
            }
            if component.stroke.enabled { ShapeGradientControls(state: state, id: id, gradient: component.strokeGradient, stroke: true) }
        }.foregroundStyle(Theme.text).tint(Theme.accent)
    }

    private func edit(_ label: String, _ change: (inout ShapeComponent) -> Void) {
        state.editShapeContent(id, label) { item in guard var c = item.component else { return }; change(&c); item.component = c }
    }
    private func scalar(_ title: String, _ a: Animated<Double>, _ kp: WritableKeyPath<ShapeComponent, Animated<Double>>, _ range: ClosedRange<Double>, step: Double = 1) -> some View {
        HStack(spacing: 8) {
            KeyframeDiamond(filled: a.hasKeyframe(at: t), animated: a.isAnimated) { edit("\(title) Keyframe") { $0[keyPath: kp].toggleKeyframe(at: t) } }
            Text(title).font(.caption).frame(width: 78, alignment: .leading)
            ValueScrubber(value: a.value(at: t), range: range, step: step, onBegin: { state.beginEdit(title) }, onChange: { value in
                state.editShapeContent(id, title, continuous: true) { $0.component?[keyPath: kp].set(value, at: t) }
            }, onEnd: { state.endEdit() })
        }.frame(minHeight: 44)
    }
    private func vector(_ title: String, _ a: Animated<Vec2>, _ kp: WritableKeyPath<ShapeComponent, Animated<Vec2>>, _ range: ClosedRange<Double>) -> some View {
        let v = a.value(at: t)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption)
            HStack(spacing: 8) {
                KeyframeDiamond(filled: a.hasKeyframe(at: t), animated: a.isAnimated) { edit("\(title) Keyframe") { $0[keyPath: kp].toggleKeyframe(at: t) } }
                ValueScrubber(value: v.x, range: range, unit: " X", onBegin: { state.beginEdit(title) }, onChange: { x in
                    state.editShapeContent(id, title, continuous: true) { $0.component?[keyPath: kp].set(Vec2(x, v.y), at: t) }
                }, onEnd: { state.endEdit() })
                ValueScrubber(value: v.y, range: range, unit: " Y", onBegin: { state.beginEdit(title) }, onChange: { y in
                    state.editShapeContent(id, title, continuous: true) { $0.component?[keyPath: kp].set(Vec2(v.x, y), at: t) }
                }, onEnd: { state.endEdit() })
            }.frame(minHeight: 44)
        }
    }
}

struct ShapeGradientControls: View {
    @ObservedObject var state: EditorState
    let id: UUID
    let gradient: ShapeGradient?
    let stroke: Bool
    private var t: Double { state.currentTime }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(stroke ? "Stroke Style" : "Fill Style", selection: Binding(get: { gradient.map { $0.radial ? 2 : 1 } ?? 0 }, set: { mode in
                state.editShapeContent(id, "Gradient Style") { item in
                    var g = gradient ?? ShapeGradient(); g.radial = mode == 2
                    if stroke { item.component?.strokeGradient = mode == 0 ? nil : g }
                    else { item.component?.fillGradient = mode == 0 ? nil : g }
                }
            })) { Text("Solid").tag(0); Text("Linear").tag(1); Text("Radial").tag(2) }.pickerStyle(.segmented).frame(minHeight: 44)
            if let g = gradient {
                color("First Color", g.first, \.first)
                color("Last Color", g.last, \.last)
                point("Start", g.start, \.start)
                point("End", g.end, \.end)
            }
        }
    }
    private func edit(_ label: String, continuous: Bool = false, _ change: (inout ShapeGradient) -> Void) {
        state.editShapeContent(id, label, continuous: continuous) { item in
            var g = (stroke ? item.component?.strokeGradient : item.component?.fillGradient) ?? ShapeGradient()
            change(&g)
            if stroke { item.component?.strokeGradient = g } else { item.component?.fillGradient = g }
        }
    }
    private func color(_ title: String, _ a: Animated<RGBA>, _ kp: WritableKeyPath<ShapeGradient, Animated<RGBA>>) -> some View {
        HStack {
            KeyframeDiamond(filled: a.hasKeyframe(at: t), animated: a.isAnimated) { edit("Gradient Keyframe") { $0[keyPath: kp].toggleKeyframe(at: t) } }
            AWIColorWell(title, selection: Binding(get: { Color(a.value(at: t)) }, set: { c in edit(title) { $0[keyPath: kp].set(c.rgba, at: t) } }))
        }.frame(minHeight: 44)
    }
    private func point(_ title: String, _ a: Animated<Vec2>, _ kp: WritableKeyPath<ShapeGradient, Animated<Vec2>>) -> some View {
        let v = a.value(at: t)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption)
            HStack {
                KeyframeDiamond(filled: a.hasKeyframe(at: t), animated: a.isAnimated) { edit("Gradient Keyframe") { $0[keyPath: kp].toggleKeyframe(at: t) } }
                ValueScrubber(value: v.x, range: -2000...2000, unit: " X", onBegin: { state.beginEdit("Gradient Point") }, onChange: { x in edit("Gradient Point", continuous: true) { $0[keyPath: kp].set(Vec2(x, v.y), at: t) } }, onEnd: { state.endEdit() })
                ValueScrubber(value: v.y, range: -2000...2000, unit: " Y", onBegin: { state.beginEdit("Gradient Point") }, onChange: { y in edit("Gradient Point", continuous: true) { $0[keyPath: kp].set(Vec2(v.x, y), at: t) } }, onEnd: { state.endEdit() })
            }.frame(minHeight: 44)
        }
    }
}
