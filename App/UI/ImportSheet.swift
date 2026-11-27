import SwiftUI
import UniformTypeIdentifiers

/// Shows what the selected source project brought in and which items need attention.
struct ImportReportSheet: View {
    let result: AEPImportResult
    let open: (Project) -> Void
    let reimport: (String) -> Void
    @State private var filter: ImportReport.Status?
    @State private var showsDetails = false
    private var format: ImportedProjectFormat { result.project.importedFormat ?? .afterEffects }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.project.name).font(.title2.weight(.semibold)).foregroundStyle(Theme.text)
                        Text("\(format.title) Project").font(.subheadline).foregroundStyle(Theme.accentGlow)
                    }
                    .accessibilityIdentifier("import-project-name")
                    LabeledContent("Composition", value: result.report.compName)
                    LabeledContent("Size", value: "\(result.project.width)×\(result.project.height) · \(Int(result.project.fps.rounded())) fps")
                    LabeledContent("Layers", value: "\(result.project.layers.count)")
                    if result.report.comps.count > 1 {
                        Menu("Import a different comp (\(result.report.comps.count))") {
                            ForEach(result.report.comps, id: \.self) { c in Button(c) { reimport(c) } }
                        }
                    }
                }
                Section {
                    Button {
                        showsDetails.toggle()
                    } label: {
                        HStack {
                            Text("Import Details").foregroundStyle(Theme.text)
                            Spacer()
                            Image(systemName: showsDetails ? "chevron.down" : "chevron.right")
                                .foregroundStyle(Theme.textDim)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if showsDetails {
                    importDetails
                }
                if showsDetails && !result.report.effectUsage.isEmpty {
                    Section("Effect scanner (whole file)") {
                        ForEach(result.report.effectUsage.sorted { $0.value > $1.value }, id: \.key) { k, v in
                            HStack {
                                Text(format == .afterEffects ? (EffectRegistry.definition(aeMatchName: k)?.name ?? k) : k)
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                Text("×\(v)").foregroundStyle(Theme.textDim)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("\(format.title) Import")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Open Project") { open(result.project) }
                    .buttonStyle(PrimaryButtonStyle()).padding(16)
            }
        }
    }

    private var importDetails: some View {
        Section {
            HStack(spacing: 10) {
                stat("Native", result.report.nativeCount, Theme.ok)
                stat("Compatible", result.report.approximateCount, Theme.warning)
                stat("Unresolved", result.report.missingCount, Theme.danger)
            }
            .listRowBackground(Color.clear)
            if result.report.missingCount > 0 {
                Text("Missing footage uses placeholders. Unresolved effects keep their source settings and stack position.")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
            Picker("Show", selection: $filter) {
                Text("All").tag(ImportReport.Status?.none)
                Text("Native").tag(ImportReport.Status?.some(.native))
                Text("Compatible").tag(ImportReport.Status?.some(.approximate))
                Text("Unresolved").tag(ImportReport.Status?.some(.missing))
            }
            .pickerStyle(.segmented)
            ForEach(result.report.entries.filter { filter == nil || $0.status == filter }) { e in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(color(e.status)).frame(width: 9, height: 9).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.item).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                        Text(e.layer).font(.caption).foregroundStyle(Theme.textDim)
                        if !e.detail.isEmpty { Text(e.detail).font(.caption2).foregroundStyle(Theme.textDim) }
                    }
                }
            }
        }
    }

    private func color(_ s: ImportReport.Status) -> Color {
        switch s { case .native: return Theme.ok; case .approximate: return Theme.warning; case .missing: return Theme.danger }
    }

    private func stat(_ t: String, _ n: Int, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.system(size: 22, weight: .bold)).foregroundStyle(c)
            Text(t).font(.caption2).foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).glass(radius: 12)
    }
}

extension UTType {
    static let aep = UTType(filenameExtension: "aep") ?? .data
    static let aepx = UTType(filenameExtension: "aepx") ?? .xml
    static let ffx = UTType(filenameExtension: "ffx") ?? .data
}
