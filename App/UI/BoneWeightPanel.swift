import SwiftUI

struct BoneSkinControls: View {
    @ObservedObject var state: EditorState
    let workflow: BoneSkinWorkflow
    @State private var advanced = false
    var body: some View {
        LiveReader(live: state.live) { live in
            if let id = state.skinArtworkID,let art = (live ?? state.project).layers.first(where: { $0.id == id }) {
                VStack(alignment: .leading,spacing: 6) {
                    if art.boneMesh != nil {
                        BoneMeshControls(state: state)
                        if state.boneWeightArtworkID == nil,let mesh = art.boneMesh {
                            HStack {
                                Text("Deform").font(.caption).frame(width: 65,alignment: .leading)
                                ValueScrubber(value: (mesh.amount ?? 1)*100,range: 0...100,unit: "%",
                                    onBegin: { state.beginPanelGesture("Deformation") },onChange: { value in
                                        state.mutate("Deformation") { p in
                                            if let i = p.layers.firstIndex(where: { $0.id == id }) { p.layers[i].boneMesh?.amount = value/100 }
                                        }
                                    },onEnd: { state.endPanelGesture() }).frame(height: 44)
                            }
                        }
                    } else {
                        bindingCoverage
                        Button { state.bindBoneMesh() } label: {
                            Label(art.boneSkin == nil ? "Bind Mesh" : "Upgrade to Mesh",systemImage: "square.grid.3x3")
                                .frame(maxWidth: .infinity,minHeight: 44)
                        }.buttonStyle(.bordered)
                        if let legacy = art.boneSkin {
                            Text("Existing Puppet-based deformation is preserved until you rebind.").font(.caption2).foregroundStyle(Theme.textDim)
                            HStack {
                                Text("Deform").font(.caption)
                                ValueScrubber(value: legacy.deformation*100,range: 0...100,unit: "%",
                                    onBegin: { state.beginPanelGesture("Legacy Deformation") },onChange: { value in
                                        state.mutate("Legacy Deformation") { p in if let i = p.layers.firstIndex(where: { $0.id == id }) { p.layers[i].boneSkin?.deformation = value/100 } }
                                    },onEnd: { state.endPanelGesture() }).frame(height: 44)
                            }
                        }
                    }
                    if state.boneWeightArtworkID == nil {
                        DisclosureGroup("Binding options",isExpanded: $advanced) {
                            if art.boneMesh != nil { bindingCoverage }
                            HStack {
                                Text("Mesh detail").font(.caption).frame(width: 65,alignment: .leading)
                                ValueScrubber(value: state.boneMeshDetail,range: 4...128,step: 1,onChange: { state.boneMeshDetail = $0 })
                                    .frame(height: 44).environment(\.scrubSession,ScrubSession())
                            }
                            if state.boneMeshCoverage == .localized,state.project.layers.contains(where: { $0.bone?.artworkID == id }) {
                            HStack {
                                Text("Reach").font(.caption).frame(width: 65,alignment: .leading)
                                ValueScrubber(value: state.meshInfluenceRadius,range: 2...1000,unit: " px",onChange: { state.meshInfluenceRadius = $0 })
                                    .frame(height: 44).environment(\.scrubSession,ScrubSession())
                            }
                            Text("Pixels beyond Reach stay fixed to the base artwork. Reset Auto Weights applies this value.")
                                .font(.caption2).foregroundStyle(Theme.textDim)
                            }
                            if art.boneMesh != nil { Button("Reset Auto Weights") { state.bindBoneMesh() }.frame(minHeight: 44) }
                        }
                    }
                }
                .onChange(of: id,initial: true) { _,_ in state.boneMeshCoverage = art.boneMesh?.coverage ?? .localized }
            }
        }
    }
    @ViewBuilder private var bindingCoverage: some View {
        if let id = state.skinArtworkID,state.project.layers.contains(where: { $0.bone?.artworkID == id }) {
        VStack(alignment: .leading,spacing: 4) {
            Picker("Auto weight coverage",selection: $state.boneMeshCoverage) {
                Text("Near bones").tag(BoneMeshCoverage.localized)
                Text("Whole artwork").tag(BoneMeshCoverage.wholeArtwork)
            }.pickerStyle(.segmented).frame(minHeight: 44)
            Text(state.boneMeshCoverage == .wholeArtwork
                ? "For a cutout limb: all pixels follow the skeleton. Bind or Reset Auto Weights applies this choice."
                : "For part of a character: areas beyond Reach stay fixed. Bind or Reset Auto Weights applies this choice.")
                .font(.caption2).foregroundStyle(Theme.textDim)
        }
        } else {
            Text("This piece follows its joints. Optional weights refine how it bends where the pieces meet.")
                .font(.caption2).foregroundStyle(Theme.textDim)
        }
    }

}

struct BoneWeightPanel: View {
    @ObservedObject var state: EditorState
    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state,title: "Bone / Weight",showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading,spacing: 8) {
                    if let owner = state.selectedIKLayer,owner.bone == nil {
                        if state.boneWeightArtworkID == nil {
                            Text("Artwork controlled by this rig").font(.caption.bold()).foregroundStyle(Theme.textDim)
                            ForEach(state.project.layers.filter { IKSolver.drivenIDs(owner: owner).contains($0.id) && !$0.isNull }) { piece in
                                Button { state.select(piece.id); state.panel = .boneWeight } label: {
                                    HStack { Text(piece.name).lineLimit(1); Spacer(); Image(systemName: state.rigArtworkID == piece.id ? "checkmark.circle.fill" : "circle") }.frame(minHeight: 44)
                                }.buttonStyle(.plain)
                            }
                        }
                        BoneSkinControls(state: state,workflow: .rigPieces)
                        if state.boneWeightArtworkID == nil { RigPositionControls(state: state) }
                    } else {
                        if state.boneWeightArtworkID == nil {
                            BoneAuthoringControls(state: state)
                            RigPositionControls(state: state)
                        }
                        BoneSkinControls(state: state,workflow: .boneWeight)
                    }
                }.padding(.horizontal,12).padding(.bottom,12)
            }.accessibilityIdentifier("bone-weight-panel-scroll")
        }
    }
}
