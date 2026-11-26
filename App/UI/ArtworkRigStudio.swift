import SwiftUI
import simd

struct ArtworkRigStudio: View {
    @ObservedObject var state: EditorState
    let layer: Layer
    private enum Mode: String, CaseIterable { case setup = "Setup", weights = "Weights", animate = "Animate" }
    @State private var mode: Mode = .setup
    @State private var brush: BoneWeightBrush = .paint
    @State private var weightRadius = 40.0
    @State private var bindRadius = 90.0
    @State private var local = true
    @State private var showMessage = false
    @State private var message = ""
    @State private var editingStart = false

    private var rig: ArtworkRig { layer.artworkRig ?? ArtworkRig() }
    private var start: Vec2? { state.artworkRigDraftStart }
    private var selectedID: UUID? { state.artworkRigSelectedBone }
    private var selected: ArtworkBone? { rig.bones.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Rig Studio", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    TSSegmented(options: Mode.allCases.map { ($0, $0.rawValue) }, selection: mode, label: "Rig Studio") { mode = $0 }
                    switch mode {
                    case .setup: setupControls
                    case .weights: weightControls
                    case .animate: poseControls
                    }
                    ForEach(rig.bones) { bone in
                        Button { select(bone, atStart: false) } label: {
                            HStack {
                                Text(bone.name).foregroundStyle(bone.id == selectedID ? Theme.accentGlow : Theme.text)
                                Spacer()
                                Text(rig.bones.first { $0.id == bone.parentID }?.name ?? "Root")
                                    .font(.caption).foregroundStyle(Theme.textDim)
                            }
                            .frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    Button("Existing Rig Tools") { state.showArtworkRig = false }
                        .font(.caption).frame(minHeight: 44)
                }.padding(12)
            }
        }
        .onAppear {
            state.rigCursor = .zero
            if let bone = rig.bones.first { select(bone, atStart: false) }
        }
        .onChange(of: brush) { _, value in state.artworkRigBrush = value }
        .onChange(of: weightRadius) { _, value in state.artworkRigBrushRadius = value }
        .onChange(of: mode) { _, value in
            state.artworkRigDraftStart = nil
            state.artworkRigWeightBone = value == .weights ? selectedID : nil
            state.artworkRigAnimating = value == .animate
            state.artworkRigSettingUp = value == .setup
        }
        .onDisappear {
            state.artworkRigWeightBone = nil
            state.artworkRigSelectedBone = nil
            state.artworkRigDraftStart = nil
            state.artworkRigAnimating = false
            state.artworkRigSettingUp = true
        }
        .alert("Rig Studio", isPresented: $showMessage) { Button("OK", role: .cancel) {} } message: { Text(message) }
    }

    private var setupControls: some View {
        VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        NumberField(value: state.rigCursor.x, label: "X", step: 0.1) { setCursor(Vec2($0, state.rigCursor.y)) }
                        NumberField(value: state.rigCursor.y, label: "Y", step: 0.1) { setCursor(Vec2(state.rigCursor.x, $0)) }
                    }
                    SwipePad(hint: "Position crosshair on the artwork",
                             gain: max(1, layer.size.value(at: state.currentTime).x), steady: true) { delta in
                        setCursor(nudgedCursor(delta))
                    } begin: { if selectedID != nil { state.beginEdit("Place Bone Endpoint") } }
                      end: { state.endEdit() }
                    HStack {
                        Button(start == nil ? "Add Bone" : "Place Endpoint") { place() }
                            .frame(minHeight: 44)
                        if start != nil {
                            Button("Cancel") { state.artworkRigDraftStart = nil }.frame(minHeight: 44)
                        } else if let selected {
                            Button(editingStart ? "Edit End" : "Edit Start") {
                                select(selected, atStart: !editingStart)
                            }.frame(minHeight: 44)
                            Spacer()
                            Menu {
                                Button("Make Root") { changeParent(of: selected.id, to: nil) }
                                ForEach(rig.bones.filter { rig.canParent(selected.id, to: $0.id) }) { candidate in
                                    Button(candidate.name) { changeParent(of: selected.id, to: candidate.id) }
                                }
                            } label: { Label("Set Parent", systemImage: "link").frame(minHeight: 44) }
                        }
                    }
                    if let bone = selected, start == nil {
                        Menu {
                            ForEach(state.project.layers.filter { state.canAttachToArtworkRig($0, owner: layer.id) }) { item in
                                Button(item.name) { state.attachArtworkLayer(item.id, owner: layer.id, bone: bone.id) }
                            }
                        } label: {
                            Label("Attach Layer", systemImage: "link.badge.plus").frame(minHeight: 44)
                        }
                    }
                    if !rig.bones.isEmpty {
                        TSButton(title: rig.mesh == nil ? "Bind Artwork" : "Rebind Artwork",
                                 icon: "point.3.connected.trianglepath.dotted") { bindArtwork() }
                    }
        }
    }

    private var weightControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            let mesh = rig.mesh
            TSSegmented(options: [(true, "Local Bind"), (false, "Whole Image")], selection: local, label: "Bind Coverage") { local = $0 }
            if local {
                ValueScrubber(value: bindRadius, range: 4...1200, step: 1, unit: " px",
                              onChange: { bindRadius = $0 })
                    .accessibilityLabel("Bind Radius")
            }
            TSButton(title: mesh == nil ? "Bind Artwork" : "Rebind Artwork", icon: "point.3.connected.trianglepath.dotted") {
                bindArtwork()
            }
            .disabled(rig.bones.isEmpty)
            if let mesh {
                ValueScrubber(value: (mesh.amount ?? 1) * 100, range: 0...100, step: 1, unit: "%",
                              onBegin: { state.beginEdit("Deformation") },
                              onChange: { v in update("Deformation") { $0.mesh?.amount = v / 100 } },
                              onEnd: { state.endEdit() })
                    .accessibilityLabel("Deformation Amount")
                if let id = selectedID, mesh.boneIDs.contains(id) {
                    TSSegmented(options: BoneWeightBrush.allCases.map { ($0, $0.rawValue) }, selection: brush, label: "Weight Brush") { brush = $0 }
                    ValueScrubber(value: weightRadius, range: 4...300, step: 1, unit: " px", onChange: { weightRadius = $0 })
                        .accessibilityLabel("Weight Brush Radius")
                    SwipePad(hint: "Move weight brush", gain: max(1, layer.size.value(at: state.currentTime).x), steady: true) {
                        state.rigCursor = nudgedCursor($0)
                    }
                    TSButton(title: "\(brush.rawValue) Weights Here", icon: "paintbrush.pointed") {
                        update("Brush Bone Weights") { rig in
                            guard let index = rig.mesh?.boneIDs.firstIndex(of: id) else { return }
                            _ = rig.mesh?.paint([BoneWeightDab(center: state.rigCursor, amount: 0.75)], selected: index,
                                                radius: weightRadius, mode: brush)
                        }
                    }
                    TSToggleRow(title: "Lock Bone Weights", isOn: mesh.lockedBoneIDs?.contains(id) ?? false) { locked in
                        update("Lock Bone Weights") { rig in
                            var ids = Set(rig.mesh?.lockedBoneIDs ?? [])
                            if locked { ids.insert(id) } else { ids.remove(id) }
                            rig.mesh?.lockedBoneIDs = ids.sorted { $0.uuidString < $1.uuidString }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var poseControls: some View {
        let time = state.currentTime
        if let bone = selected {
            let angle = bone.rotation ?? Animated(0)
            TSNumberRow(title: "Rotation", value: angle.value(at: time), range: -360...360, step: 0.1, unit: "deg",
                        allowBeyond: true, key: (angle.hasKeyframe(at: time), angle.isAnimated, {
                changeBone(bone.id, "Key Bone Rotation") { item in
                    var track = item.rotation ?? Animated(0)
                    track.toggleKeyframe(at: time)
                    item.rotation = track
                }
            }), onBegin: { state.beginEdit("Rotate Bone") }, onChange: { value in
                changeBone(bone.id, "Rotate Bone") { item in
                    var track = item.rotation ?? Animated(0)
                    track.set(value, at: time)
                    item.rotation = track
                }
            }, onEnd: { state.endEdit() })
            let offset = bone.offset ?? Animated(Vec2.zero)
            HStack {
                NumberField(value: offset.value(at: time).x, label: "X", step: 0.1) { setOffset(bone.id, x: $0, y: nil) }
                NumberField(value: offset.value(at: time).y, label: "Y", step: 0.1) { setOffset(bone.id, x: nil, y: $0) }
                KeyframeDiamond(filled: offset.hasKeyframe(at: time), animated: offset.isAnimated) {
                    changeBone(bone.id, "Key Bone Position") { item in
                        var track = item.offset ?? Animated(Vec2.zero)
                        track.toggleKeyframe(at: time)
                        item.offset = track
                    }
                }
                .accessibilityLabel("Key Bone Position")
            }
            if bone.parentID != nil && rig.constraint(on: bone.id) == nil {
                TSButton(title: "Add IK Target", icon: "scope") {
                    var added = false
                    update("Add IK Target") { added = $0.enableIK(on: bone.id, time: time) }
                    if !added { report("Connect the bone to its parent's endpoint and choose a pair that has no IK target yet.") }
                }
            }
        }
        if let id = selectedID, let ik = rig.constraint(on: id) {
            let target = ik.target.value(at: time)
            HStack {
                NumberField(value: target.x, label: "IK X", step: 0.1) { state.moveArtworkIK(layer.id, bone: id, x: $0, y: nil) }
                NumberField(value: target.y, label: "IK Y", step: 0.1) { state.moveArtworkIK(layer.id, bone: id, x: nil, y: $0) }
                KeyframeDiamond(filled: ik.target.hasKeyframe(at: time), animated: ik.target.isAnimated) {
                    update("Key IK Target") { $0.editIK(on: id) { $0.target.toggleKeyframe(at: time) } }
                }
                .accessibilityLabel("Key IK Target")
            }
            TSNumberRow(title: "IK Mix", value: ik.mix.value(at: time), range: 0...100, step: 1, unit: "%",
                        key: (ik.mix.hasKeyframe(at: time), ik.mix.isAnimated, {
                update("Key IK Mix") { $0.editIK(on: id) { $0.mix.toggleKeyframe(at: time) } }
            }), onBegin: { state.beginEdit("IK Mix") },
               onChange: { v in update("IK Mix") { $0.editIK(on: id) { $0.mix.set(v, at: time) } } },
               onEnd: { state.endEdit() })
            TSNumberRow(title: "Stretch Limit", value: ik.stretchLimit * 100, range: 100...200, step: 1, unit: "%",
                        onBegin: { state.beginEdit("Stretch Limit") },
                        onChange: { v in update("Stretch Limit") { $0.editIK(on: id) { $0.stretchLimit = v / 100 } } },
                        onEnd: { state.endEdit() })
            TSToggleRow(title: "Flip Bend", isOn: ik.flipped) { value in
                update("Flip IK Bend") { $0.editIK(on: id) { $0.flipped = value } }
            }
            Button("Remove IK") { update("Remove IK") { $0.constraints?.removeAll { $0.tipBoneID == id } } }.frame(minHeight: 44)
        }
        if let bone = selected { poseKeys(for: bone) }
    }

    @ViewBuilder private func poseKeys(for bone: ArtworkBone) -> some View {
        let ik = rig.constraint(on: bone.id)
        let tracks = [bone.rotation?.keyframeTimes, bone.offset?.keyframeTimes, ik?.target.keyframeTimes, ik?.mix.keyframeTimes]
        let keys = Set(tracks.compactMap { $0 }.flatMap { $0 }).sorted()
        if !keys.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(keys, id: \.self) { time in
                        Button { state.seek(time) } label: {
                            Label(String(format: "%.2fs", time), systemImage: "diamond.fill")
                                .font(.caption.monospacedDigit()).frame(minHeight: 44)
                        }
                    }
                }
            }
            .accessibilityLabel("Bone Keyframes")
        }
    }

    private func report(_ text: String) { message = text; showMessage = true }

    private func bindArtwork() {
        state.bindArtworkRig(layer, radius: local ? bindRadius : nil)
    }

    private func setOffset(_ id: UUID, x: Double?, y: Double?) {
        let time = state.currentTime
        changeBone(id, "Move Bone") { bone in
            var track = bone.offset ?? Animated(Vec2.zero)
            let value = track.value(at: time)
            track.set(Vec2(x ?? value.x, y ?? value.y), at: time)
            bone.offset = track
        }
    }

    private func changeBone(_ id: UUID, _ label: String, _ change: (inout ArtworkBone) -> Void) {
        update(label) { rig in
            guard let index = rig.bones.firstIndex(where: { $0.id == id }) else { return }
            change(&rig.bones[index])
        }
    }

    private func select(_ bone: ArtworkBone, atStart: Bool) {
        state.artworkRigDraftStart = nil
        state.artworkRigSelectedBone = bone.id
        state.artworkRigWeightBone = mode == .weights ? bone.id : nil
        editingStart = atStart
        state.rigCursor = atStart ? bone.start : bone.end
    }

    private func setCursor(_ point: Vec2) {
        guard point.x.isFinite, point.y.isFinite else { return }
        if let selected, start == nil {
            let opposite = editingStart ? selected.end : selected.start
            guard hypot(point.x - opposite.x, point.y - opposite.y) >= 0.1 else { return }
            update("Place Bone Endpoint") { rig in
                guard let index = rig.bones.firstIndex(where: { $0.id == selected.id }) else { return }
                if editingStart { rig.bones[index].start = point }
                else { rig.bones[index].end = point }
            }
        }
        state.rigCursor = point
    }

    private func nudgedCursor(_ delta: CGSize) -> Vec2 {
        let cursor = state.rigCursor
        let step = Vec2(Double(delta.width), Double(delta.height))
        guard let projection = state.displayPlacement(of: layer.id), abs(projection.determinant) > 1e-10,
              let point = LayerPlacement.projected(cursor, by: projection),
              let sample = LayerPlacement.projected(cursor + Vec2(1, 0), by: projection) else { return cursor + step }
        let unit = hypot(sample.x - point.x, sample.y - point.y)
        return LayerPlacement.projected(point + step * unit, by: projection.inverse) ?? cursor
    }

    private func place() {
        guard let start else {
            guard rig.bones.count < 128 else { return }
            state.artworkRigDraftStart = state.rigCursor
            return
        }
        state.addArtworkBone(layer.id, from: start, to: state.rigCursor)
        editingStart = false
    }

    private func changeParent(of bone: UUID, to parent: UUID?) {
        update("Parent Artwork Bone") { $0.reparent(bone, to: parent, at: state.currentTime) }
    }

    private func update(_ title: String, _ change: (inout ArtworkRig) -> Void) {
        state.mutate(title) { project in
            guard let index = project.layers.firstIndex(where: { $0.id == layer.id }),
                  !project.layers[index].isLocked else { return }
            var rig = project.layers[index].artworkRig ?? ArtworkRig()
            change(&rig)
            project.layers[index].artworkRig = rig
        }
    }
}

struct ArtworkRigOverlay: View {
    @ObservedObject var state: EditorState
    let layer: Layer
    let fit: CGRect
    @GestureState private var draggingIK = false
    @State private var editingIK = false
    @GestureState private var painting = false
    @State private var lastDab: Vec2?
    @GestureState private var sketch: Vec2? = nil

    var body: some View {
        if let placement = state.displayPlacement(of: layer.id), fit.width > 0 {
            let scale = Double(fit.width) / Double(max(1, state.project.width))
            let rig = state.canvasProject.layers.first(where: { $0.id == layer.id })?.artworkRig
            let time = state.currentTime
            let animating = state.artworkRigAnimating
            let frames = animating ? rig?.pose(at: time) ?? [:] : [:]
            let ik = animating ? state.artworkRigSelectedBone.flatMap { rig?.constraint(on: $0) } : nil
            let weightBone = state.artworkRigWeightBone
            let cursor = state.rigCursor
            let draft = state.artworkRigDraftStart
            let selected = state.artworkRigSelectedBone
            let screen: (Vec2) -> CGPoint? = { value in
                LayerPlacement.projected(value, by: placement).map {
                    CGPoint(x: fit.minX + CGFloat($0.x * scale), y: fit.minY + CGFloat($0.y * scale))
                }
            }
            ZStack {
                Canvas { context, _ in
                    func line(_ a: CGPoint, _ b: CGPoint, color: Color) {
                        var path = Path()
                        path.move(to: a); path.addLine(to: b)
                        context.stroke(path, with: .color(.black), lineWidth: 5)
                        context.stroke(path, with: .color(color), lineWidth: 2)
                    }
                    for bone in rig?.bones ?? [] {
                        let pose = frames[bone.id] ?? .identity
                        guard let a = screen(pose.apply(bone.start)), let b = screen(pose.apply(bone.end)) else { continue }
                        line(a, b, color: bone.id == (weightBone ?? selected) ? Theme.warning : Theme.accentGlow)
                        for joint in [a, b] {
                            context.fill(Path(ellipseIn: CGRect(x: joint.x-4, y: joint.y-4, width: 8, height: 8)), with: .color(.white))
                        }
                    }
                    if !animating, let point = screen(cursor) {
                        if let initial = draft ?? sketch, let origin = screen(initial) { line(origin, point, color: Theme.warning) }
                        line(CGPoint(x: point.x-10, y: point.y), CGPoint(x: point.x+10, y: point.y), color: .white)
                        line(CGPoint(x: point.x, y: point.y-10), CGPoint(x: point.x, y: point.y+10), color: .white)
                    }
                }
                .allowsHitTesting(false)
                if let weightBone, rig?.mesh?.boneIDs.contains(weightBone) == true,
                   rig?.mesh?.lockedBoneIDs?.contains(weightBone) != true {
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .frame(width: fit.width, height: fit.height).position(x: fit.midX, y: fit.midY)
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("artwork-rig-canvas"))
                            .updating($painting) { _, active, _ in active = true }
                            .onChanged { move in
                                guard let value = local(move.location, placement: placement, scale: scale) else { return }
                                let radius = state.artworkRigBrushRadius
                                if let lastDab {
                                    let delta = value - lastDab
                                    guard hypot(delta.x, delta.y) >= max(1, radius * 0.15) else { return }
                                } else {
                                    state.beginPanelGesture("Brush Bone Weights")
                                }
                                state.paintArtworkWeights(layer.id, bone: weightBone, from: lastDab,
                                                          to: value, radius: radius, brush: state.artworkRigBrush)
                                lastDab = value
                                state.rigCursor = value
                            }
                            .onEnded { _ in finishWeightStroke() })
                        .accessibilityLabel("Paint Rig Weights")
                } else if state.artworkRigSettingUp, abs(placement.determinant) > 1e-10 {
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .frame(width: fit.width, height: fit.height).position(x: fit.midX, y: fit.midY)
                        .gesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("artwork-rig-canvas"))
                            .updating($sketch) { move, value, _ in
                                value = local(move.startLocation, placement: placement, scale: scale)
                            }
                            .onChanged { move in
                                if let value = local(move.location, placement: placement, scale: scale) { state.rigCursor = value }
                            }
                            .onEnded { move in
                                guard let value = local(move.location, placement: placement, scale: scale),
                                      let origin = draft ?? local(move.startLocation, placement: placement, scale: scale) else { return }
                                state.addArtworkBone(layer.id, from: origin, to: value)
                            })
                        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .named("artwork-rig-canvas")).onEnded { tap in
                            guard let value = local(tap.location, placement: placement, scale: scale) else { return }
                            state.rigCursor = value
                        })
                        .accessibilityLabel("Draw Artwork Bones")
                }
                if let ik, let point = screen(ik.target.value(at: time)) {
                    Image(systemName: "scope").font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.warning).frame(width: 44, height: 44)
                        .background(.black.opacity(0.35), in: Circle()).contentShape(Rectangle())
                        .position(point)
                        .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("artwork-rig-canvas"))
                            .updating($draggingIK) { _, active, _ in active = true }
                            .onChanged { move in
                                guard let value = local(move.location, placement: placement, scale: scale) else { return }
                                if !editingIK { state.beginPanelGesture("Move Artwork IK"); editingIK = true }
                                state.moveArtworkIK(layer.id, bone: ik.tipBoneID, x: value.x, y: value.y)
                            }
                            .onEnded { _ in finishIKDrag() })
                        .accessibilityLabel("Artwork IK Target")
                }
            }
            .coordinateSpace(name: "artwork-rig-canvas")
            .onChange(of: draggingIK) { _, active in if !active { finishIKDrag() } }
            .onChange(of: painting) { _, active in if !active { finishWeightStroke() } }
            .onDisappear { finishIKDrag(); finishWeightStroke() }
        }
    }

    private func local(_ point: CGPoint, placement: simd_double3x3, scale: Double) -> Vec2? {
        guard abs(placement.determinant) > 1e-10 else { return nil }
        return LayerPlacement.projected(Vec2(Double(point.x-fit.minX) / scale, Double(point.y-fit.minY) / scale), by: placement.inverse)
    }

    private func finishWeightStroke() {
        guard lastDab != nil else { return }
        lastDab = nil
        state.endPanelGesture()
    }

    private func finishIKDrag() {
        guard editingIK else { return }
        editingIK = false
        state.endPanelGesture()
    }
}
