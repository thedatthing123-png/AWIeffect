import SwiftUI
import UniformTypeIdentifiers

/// Shows what an After Effects import brought in: native / approximate / missing, plus the effect scanner.
struct ImportReportSheet: View {
    let result: AEPImportResult
    let open: (Project) -> Void
    let reimport: (String) -> Void
    @State private var filter: ImportReport.Status?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        stat("Native", result.report.nativeCount, Theme.ok)
                        stat("Approx.", result.report.approximateCount, Theme.warning)
                        stat("Missing", result.report.missingCount, Theme.danger)
                    }
                    .listRowBackground(Color.clear)
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
                    Picker("Show", selection: $filter) {
                        Text("All").tag(ImportReport.Status?.none)
                        Text("Native").tag(ImportReport.Status?.some(.native))
                        Text("Approx.").tag(ImportReport.Status?.some(.approximate))
                        Text("Missing").tag(ImportReport.Status?.some(.missing))
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
                } header: { Text("Import report") }
                if !result.report.effectUsage.isEmpty {
                    Section("Effect scanner (whole file)") {
                        ForEach(result.report.effectUsage.sorted { $0.value > $1.value }, id: \.key) { k, v in
                            HStack {
                                Text(EffectRegistry.definition(aeMatchName: k)?.name ?? k).foregroundStyle(Theme.text)
                                Spacer()
                                Text("×\(v)").foregroundStyle(Theme.textDim)
                                Image(systemName: EffectRegistry.definition(aeMatchName: k) == nil ? "xmark.circle" : "checkmark.circle.fill")
                                    .foregroundStyle(EffectRegistry.definition(aeMatchName: k) == nil ? Theme.danger : Theme.ok)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("After Effects Import")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Open Project") { open(result.project) }
                    .buttonStyle(PrimaryButtonStyle()).padding(16)
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
