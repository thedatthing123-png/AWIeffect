import SwiftUI
import UniformTypeIdentifiers

/// Multi-composition AEPs need one explicit choice before the editor opens.
struct ImportCompositionSheet: View {
    let result: AEPImportResult
    let open: (UInt32) -> Void
    @State private var selectedID: UInt32?
    @State private var search = ""

    private var compositions: [ImportReport.Composition] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = result.report.compositions
        return query.isEmpty ? all : all.filter { $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(compositions) { composition in
                        Button {
                            selectedID = composition.id
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(composition.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                                    Text("\(composition.width)×\(composition.height) · \(Int(composition.fps.rounded())) fps")
                                        .font(.caption).foregroundStyle(Theme.textDim)
                                }
                                Spacer()
                                if selectedID == composition.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accentGlow)
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedID == composition.id ? .isSelected : [])
                    }
                } header: {
                    Text(result.project.name)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Choose Composition")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find composition")
            .safeAreaInset(edge: .bottom) {
                Button("Open Project") {
                    if let selectedID { open(selectedID) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedID == nil)
                .padding(16)
                .background(Theme.background)
            }
        }
        .onAppear { selectedID = result.report.selectedCompositionID }
    }
}

extension UTType {
    static let aep = UTType(filenameExtension: "aep") ?? .data
    static let aepx = UTType(filenameExtension: "aepx") ?? .xml
    static let ffx = UTType(filenameExtension: "ffx") ?? .data
}
