import SwiftUI

/// Shared deformation controls. The authoring modes stay separate, while their
/// weight/sensitivity data and GPU playback are identical.
struct BoneSkinControls: View {
    @ObservedObject var state: EditorState
    let workflow: BoneSkinWorkflow

    var body: some View {
        if let artworkID = state.skinArtworkID,
           let art = state.project.layers.first(where: { $0.id == artworkID }) {
            VStack(alignment: .leading, spacing: 10) {
                Text("WEIGHTS & DEFORMATION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textDim)
                Text(art.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(workflow == .boneWeight
                     ? "Draw connected and branching bones inside one image or shape, then auto-bind. The same continuous artwork bends when the joints move."
                     : "Your existing connected pieces still work. Add smooth deformation per image, or auto-bind the entire linked piece chain.")
                    .font(.caption)
                    .foregroundStyle(Theme.textDim)

                Button {
                    state.autoBindSkin(artworkID: artworkID, workflow: workflow)
                } label: {
                    Label(art.boneSkin == nil ? "Auto Bind Deformation" : "Rebind to Current Skeleton",
                          systemImage: "point.3.connected.trianglepath.dotted")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("bone-weight-auto-bind")

                if workflow == .rigPieces {
                    Button {
                        state.autoBindRigPieces(from: artworkID)
                    } label: {
                        Label("Auto Bind Linked Pieces", systemImage: "square.stack.3d.up")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("rig-auto-bind-pieces")
                }

                if let skin = art.boneSkin {
                    Toggle("Deform Artwork", isOn: Binding(
                        get: { state.project.layers.first(where: { $0.id == artworkID })?.boneSkin?.enabled ?? false },
                        set: { value in edit(artworkID, title: "Deform Artwork") { $0.enabled = value } }
                    ))
                    .tint(Theme.accent)

                    HStack {
                        Text("Deformation")
                        Spacer()
                        Text("\(Int(skin.deformation * 100))%").foregroundStyle(Theme.textDim)
                    }.font(.system(size: 12))
                    Slider(value: Binding(
                        get: { state.project.layers.first(where: { $0.id == artworkID })?.boneSkin?.deformation ?? 1 },
                        set: { value in edit(artworkID, title: "Deformation") { $0.deformation = value } }
                    ), in: 0...1, onEditingChanged: handleGesture)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("bone-weight-deformation")

                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text(String(format: "%.2f", skin.sensitivity)).foregroundStyle(Theme.textDim)
                    }.font(.system(size: 12))
                    Slider(value: Binding(
                        get: { state.project.layers.first(where: { $0.id == artworkID })?.boneSkin?.sensitivity ?? 1.2 },
                        set: { value in edit(artworkID, title: "Skin Sensitivity") { $0.sensitivity = value } }
                    ), in: 0.5...3, onEditingChanged: handleGesture)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("bone-weight-sensitivity")
                    Text("Low = smooth and broad bends. High = tighter, more localized influence.")
                        .font(.caption2).foregroundStyle(Theme.textDim)

                    Divider().overlay(Theme.stroke)
                    HStack {
                        Text("JOINT INFLUENCE")
                            .font(.system(size: 11, weight: .bold))
                        Spacer()
                        Text("\(skin.bindings.count) joints")
                            .font(.caption2)
                    }.foregroundStyle(Theme.textDim)
                    Text("Each influence adjusts how much the attached artwork responds to that joint. Zero holds the sampled area at rest.")
                        .font(.caption2).foregroundStyle(Theme.textDim)
                    ForEach(skin.bindings) { link in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(state.project.layers.first(where: { $0.id == link.jointID })?.name ?? "Missing Joint")
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(link.influence * 100))%")
                            }
                            .font(.system(size: 12))
                            Slider(value: Binding(
                                get: {
                                    state.project.layers.first(where: { $0.id == artworkID })?
                                        .boneSkin?.bindings.first(where: { $0.jointID == link.jointID })?.influence ?? 1
                                },
                                set: { value in
                                    edit(artworkID, title: "Joint Influence") { settings in
                                        guard let i = settings.bindings.firstIndex(where: { $0.jointID == link.jointID }) else { return }
                                        settings.bindings[i].influence = value
                                    }
                                }
                            ), in: 0...1, onEditingChanged: handleGesture)
                            .tint(Theme.accent)
                        }
                        .accessibilityIdentifier("bone-weight-influence-\(link.jointID.uuidString)")
                    }

                    Button(role: .destructive) {
                        state.mutate("Remove Bone Skin") { project in
                            guard let i = project.layers.firstIndex(where: { $0.id == artworkID }) else { return }
                            project.layers[i].boneSkin = nil
                        }
                    } label: {
                        Label("Remove Deformation", systemImage: "trash")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.5)))
        } else {
            Text("Select an image, vector shape, or its authoring bone to set up deformation.")
                .font(.caption)
                .foregroundStyle(Theme.textDim)
                .padding(12)
        }
    }

    private func handleGesture(_ dragging: Bool) {
        if dragging { state.beginPanelGesture("Edit Bone Weights") }
        else { state.endPanelGesture() }
    }

    private func edit(_ id: UUID, title: String, change: @escaping (inout BoneSkinSettings) -> Void) {
        state.mutate(title) { p in
            guard let index = p.layers.firstIndex(where: { $0.id == id }),
                  var value = p.layers[index].boneSkin else { return }
            change(&value)
            p.layers[index].boneSkin = value
        }
    }
}

/// Continuous-artwork authoring remains a distinct workflow from cutout Rig.
struct BoneWeightPanel: View {
    @ObservedObject var state: EditorState
    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Bone / Weight", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ONE ARTWORK · BRANCHING BONES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                    Text("Select one transparent PNG or vector shape. Draw bones from its root to tip. To create another finger, wing branch or tail strand, select an earlier bone and extend it again.")
                        .font(.caption).foregroundStyle(Theme.textDim)
                    BoneAuthoringControls(state: state)
                    BoneSkinControls(state: state, workflow: .boneWeight)
                    Text("Bone rotations and IK targets use the normal keyframe timeline. Deformation is evaluated from those joints each frame.")
                        .font(.caption2).foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }
        }
    }
}
