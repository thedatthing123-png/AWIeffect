import SwiftUI
import simd

extension EditorState {
    var rigArtwork: Layer? { rigArtworkID.flatMap { id in project.layers.first { $0.id == id } } }

    func bindBoneMesh() {
        guard let art = rigArtwork, !art.isLocked else { return }
        let time = currentTime
        let posed = AutoOrient.apply(IKSolver.apply(ExpressionResolver.resolve(project, time: time), time: time), time: time)
        var sources = [BoneMeshSource(id: art.id, matrix: matrix_identity_double3x3, tip: .zero)]
        for bone in posed.layers where bone.bone?.artworkID == art.id {
            guard let parent = Self.rigParentToArtwork(bone, artworkID: art.id, project: posed, time: time), let tip = bone.bone?.tip else { continue }
            sources.append(BoneMeshSource(id: bone.id, matrix: parent * Renderer.layerMatrix(bone, time: time, renderScale: 1), tip: tip))
        }
        guard sources.count > 1 else { recoveryNotice = "Draw a bone chain before binding the mesh."; return }
        guard let mesh = BoneMeshBinding.localized(halfSize: Renderer.layerHalfSize(art,time: time),detail: Int(boneMeshDetail),
            artworkID: art.id,bones: Array(sources.dropFirst()),radius: meshInfluenceRadius) else {
            recoveryNotice = "Check the artwork size and skeleton scale before binding."; return
        }
        mutate("Bind Mesh") { p in if let i = p.layers.firstIndex(where: { $0.id == art.id }) { p.layers[i].boneMesh = mesh; p.layers[i].boneSkin = nil } }
    }

    func unbindBoneMesh() {
        guard let art = rigArtwork, art.boneMesh != nil, !art.isLocked else { return }
        finishBoneWeights()
        mutate("Unbind Mesh") { p in if let i = p.layers.firstIndex(where: { $0.id == art.id }) { p.layers[i].boneMesh = nil } }
    }

    func beginBoneWeights() {
        guard let art = rigArtwork, let mesh = art.boneMesh, !art.isLocked else { return }
        pause(); finishBoneDrawing()
        boneWeightBoneID = mesh.boneIDs.contains(selectedLayerID ?? UUID()) ? selectedLayerID : mesh.boneIDs.dropFirst().first ?? mesh.boneIDs.first
        boneWeightArtworkID = art.id
    }
    func finishBoneWeights() { finishBoneWeightStroke(commit: false); boneWeightArtworkID = nil; boneWeightBoneID = nil }

    func toggleBoneWeightLock(_ id: UUID) {
        guard let owner = boneWeightArtworkID else { return }
        mutate("Lock Bone Weights") { p in
            guard let i = p.layers.firstIndex(where: { $0.id == owner }), var mesh = p.layers[i].boneMesh else { return }
            var locked = Set(mesh.lockedBoneIDs ?? [])
            if locked.contains(id) { locked.remove(id) } else { locked.insert(id) }
            mesh.lockedBoneIDs = locked.isEmpty ? nil : locked.sorted { $0.uuidString < $1.uuidString }
            p.layers[i].boneMesh = mesh
        }
    }

    /// A stroke is a preview transaction. A second finger cancels it without changing document or history.
    @discardableResult
    func paintBoneWeights(_ dabs: [BoneWeightDab], beginStroke: Bool) -> Bool {
        guard let owner = boneWeightArtworkID, let selected = boneWeightBoneID,
              let art = project.layers.first(where: { $0.id == owner }), !art.isLocked,
              var mesh = boneWeightPreview ?? art.boneMesh, let index = mesh.boneIDs.firstIndex(of: selected),
              mesh.paint(dabs, selected: index, radius: boneWeightRadius, mode: boneWeightBrush) else { return false }
        boneWeightPreview = mesh; redrawToken &+= 1
        return true
    }

    func finishBoneWeightStroke(commit: Bool) {
        let mesh = boneWeightPreview; boneWeightPreview = nil
        guard commit, let mesh, let owner = boneWeightArtworkID,
              let art = project.layers.first(where: { $0.id == owner }), !art.isLocked, mesh != art.boneMesh else {
            if mesh != nil { redrawToken &+= 1 }; return
        }
        mutate("Paint Weights") { p in if let i = p.layers.firstIndex(where: { $0.id == owner }) { p.layers[i].boneMesh = mesh } }
    }

}

struct BoneMeshControls: View {
    @ObservedObject var state: EditorState
    @State private var influencesOpen = false
    var body: some View {
        if let art = state.rigArtwork {
            if let mesh = art.boneMesh {
                if state.boneWeightArtworkID == art.id {
                    HStack {
                        Text("Weights — rest pose").font(.subheadline.bold()).foregroundStyle(Theme.text)
                        Spacer()
                        Button("Done") { state.finishBoneWeights() }.frame(minWidth: 60,minHeight: 44)
                    }
                    Picker("Weight brush", selection: $state.boneWeightBrush) {
                        ForEach(BoneWeightBrush.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).frame(minHeight: 44)
                    HStack {
                        Text("Size").font(.caption).frame(width: 60,alignment: .leading)
                        ValueScrubber(value: state.boneWeightRadius,range: 2...1000,unit: " px",onChange: { state.boneWeightRadius = $0 }).frame(height: 44).environment(\.scrubSession, ScrubSession())
                    }
                    HStack {
                        Text("Strength").font(.caption).frame(width: 60,alignment: .leading)
                        ValueScrubber(value: state.boneWeightStrength,range: 1...100,unit: "%",onChange: { state.boneWeightStrength = $0 }).frame(height: 44).environment(\.scrubSession, ScrubSession())
                    }
                    DisclosureGroup("Influence: \(state.boneWeightBoneID == art.id ? "Artwork" : state.project.layers.first(where: { $0.id == state.boneWeightBoneID })?.name ?? "Choose bone")",isExpanded: $influencesOpen) {
                    ForEach(mesh.boneIDs,id: \.self) { id in
                        HStack(spacing: 8) {
                            Button {
                                state.finishBoneWeightStroke(commit: false); state.boneWeightBoneID = id
                            } label: {
                                HStack {
                                    Image(systemName: state.boneWeightBoneID == id ? "circle.inset.filled" : "circle")
                                    Text(id == art.id ? "Artwork" : state.project.layers.first(where: { $0.id == id })?.name ?? "Missing Bone").lineLimit(1)
                                    Spacer(minLength: 0)
                                }.frame(minHeight: 44)
                            }.buttonStyle(.plain).foregroundStyle(state.boneWeightBoneID == id ? Theme.accentGlow : Theme.text)
                            Button { state.toggleBoneWeightLock(id) } label: {
                                Image(systemName: (mesh.lockedBoneIDs ?? []).contains(id) ? "lock.fill" : "lock.open")
                                    .frame(width: 44,height: 44)
                            }.buttonStyle(.plain).accessibilityLabel("Lock weights for \(id == art.id ? "Artwork" : state.project.layers.first(where: { $0.id == id })?.name ?? "Bone")")
                        }
                    }
                    }
                } else {
                    HStack {
                        Button("Weights") { state.beginBoneWeights() }.frame(maxWidth: .infinity,minHeight: 44)
                        Button("Unbind Mesh",role: .destructive) { state.unbindBoneMesh() }.frame(maxWidth: .infinity,minHeight: 44)
                    }.buttonStyle(.bordered)
                }
            } else if state.project.layers.contains(where: { $0.bone?.artworkID == art.id }) && state.boneDrawingArtworkID == nil {
                HStack {
                    Text("Mesh Detail").font(.caption).frame(width: 84,alignment: .leading)
                    ValueScrubber(value: state.boneMeshDetail,range: 4...128,step: 1,onChange: { state.boneMeshDetail = $0 }).frame(height: 44).environment(\.scrubSession, ScrubSession())
                }
                Button { state.bindBoneMesh() } label: { Label("Bind Mesh",systemImage: "square.grid.3x3").frame(maxWidth: .infinity,minHeight: 44) }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}
