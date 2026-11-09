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
                            HStack {
                                Text("Mesh detail").font(.caption).frame(width: 65,alignment: .leading)
                                ValueScrubber(value: state.boneMeshDetail,range: 4...128,step: 1,onChange: { state.boneMeshDetail = $0 })
                                    .frame(height: 44).environment(\.scrubSession,ScrubSession())
                            }
                            HStack {
                                Text("Reach").font(.caption).frame(width: 65,alignment: .leading)
                                ValueScrubber(value: state.meshInfluenceRadius,range: 2...1000,unit: " px",onChange: { state.meshInfluenceRadius = $0 })
                                    .frame(height: 44).environment(\.scrubSession,ScrubSession())
                            }
                            Text("Influence radius used when binding. Pixels beyond the bones' reach remain rigid. Rebind applies this value.")
                                .font(.caption2).foregroundStyle(Theme.textDim)
                            if art.boneMesh != nil { Button("Rebind Mesh") { state.bindBoneMesh() }.frame(minHeight: 44) }
                        }
                    }
                }
            }
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
                    if state.boneWeightArtworkID == nil {
                        BoneAuthoringControls(state: state)
                        RigPositionControls(state: state)
                    }
                    BoneSkinControls(state: state,workflow: .boneWeight)
                }.padding(.horizontal,12).padding(.bottom,12)
            }
        }
    }
}
