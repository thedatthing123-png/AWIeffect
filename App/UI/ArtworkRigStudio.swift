import SwiftUI

struct ArtworkRigStudio: View {
    @ObservedObject var state: EditorState
    let layer: Layer
    @State private var start: Vec2?
    @State private var selectedID: UUID?
    @State private var editingStart = false

    private var rig: ArtworkRig { layer.artworkRig ?? ArtworkRig() }
    private var selected: ArtworkBone? { rig.bones.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Rig Studio", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        NumberField(value: state.rigCursor.x, label: "X", step: 0.1) { setCursor(Vec2($0, state.rigCursor.y)) }
                        NumberField(value: state.rigCursor.y, label: "Y", step: 0.1) { setCursor(Vec2(state.rigCursor.x, $0)) }
                    }
                    SwipePad(hint: "Position crosshair on the artwork",
                             gain: max(1, layer.size.value(at: state.currentTime).x), steady: true) { delta in
                        setCursor(state.rigCursor + Vec2(delta.width, delta.height))
                    } begin: { if selectedID != nil { state.beginEdit("Place Bone Endpoint") } }
                      end: { state.endEdit() }
                    HStack {
                        Button(start == nil ? "Add Bone" : "Place Endpoint") { place() }
                            .frame(minHeight: 44)
                        if start != nil {
                            Button("Cancel") { start = nil }.frame(minHeight: 44)
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
        .onAppear { state.rigCursor = .zero }
    }

    private func select(_ bone: ArtworkBone, atStart: Bool) {
        start = nil
        selectedID = bone.id
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

    private func place() {
        guard let start else {
            selectedID = nil
            self.start = state.rigCursor
            return
        }
        let end = state.rigCursor
        guard hypot(end.x - start.x, end.y - start.y) >= 0.1 else { return }
        let bone = ArtworkBone(name: "Bone \(rig.bones.count + 1)", start: start, end: end)
        update("Add Artwork Bone") { $0.bones.append(bone) }
        select(bone, atStart: false)
    }

    private func changeParent(of bone: UUID, to parent: UUID?) {
        update("Parent Artwork Bone") { $0.reparent(bone, to: parent) }
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

    var body: some View {
        if let placement = state.displayPlacement(of: layer.id) {
            Canvas { context, _ in
                let scale = fit.width / CGFloat(max(1, state.project.width))
                func screen(_ value: Vec2) -> CGPoint? {
                    LayerPlacement.projected(value, by: placement).map {
                        CGPoint(x: fit.minX + $0.x * scale, y: fit.minY + $0.y * scale)
                    }
                }
                for bone in layer.artworkRig?.bones ?? [] {
                    guard let a = screen(bone.start), let b = screen(bone.end) else { continue }
                    var path = Path()
                    path.move(to: a)
                    path.addLine(to: b)
                    context.stroke(path, with: .color(.black), lineWidth: 5)
                    context.stroke(path, with: .color(Theme.accentGlow), lineWidth: 2)
                    for joint in [a, b] {
                        context.fill(Path(ellipseIn: CGRect(x: joint.x-4, y: joint.y-4, width: 8, height: 8)), with: .color(.white))
                    }
                }
                if let cursor = screen(state.rigCursor) {
                    var cross = Path()
                    cross.move(to: CGPoint(x: cursor.x-11, y: cursor.y))
                    cross.addLine(to: CGPoint(x: cursor.x+11, y: cursor.y))
                    cross.move(to: CGPoint(x: cursor.x, y: cursor.y-11))
                    cross.addLine(to: CGPoint(x: cursor.x, y: cursor.y+11))
                    context.stroke(cross, with: .color(.black), lineWidth: 4)
                    context.stroke(cross, with: .color(.white), lineWidth: 2)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
