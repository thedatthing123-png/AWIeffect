import SwiftUI
import UniformTypeIdentifiers

/// App-wide defaults (UserDefaults; read where projects are created and saved).
enum AppSettings {
    static let defaults = UserDefaults.standard
    static var defaultShortSide: Int { let v = defaults.integer(forKey: "awi.defaultShortSide"); return v > 0 ? v : 1080 }
    static var defaultFPS: Double { let v = defaults.double(forKey: "awi.defaultFPS"); return v > 0 ? v : 60 }
    static var defaultAspect: String { defaults.string(forKey: "awi.defaultAspect") ?? "9:16" }
    /// Seconds between automatic version snapshots while editing.
    static var versionInterval: TimeInterval { let v = defaults.double(forKey: "awi.versionInterval"); return v > 0 ? v : 120 }
}

/// Settings sections: new-project defaults, autosave versions, storage and caches, backup / restore.
struct ProjectSettingsSections: View {
    @AppStorage("awi.defaultShortSide") private var shortSide = 1080
    @AppStorage("awi.defaultFPS") private var fps = 60.0
    @AppStorage("awi.defaultAspect") private var aspect = "9:16"
    @AppStorage("awi.versionInterval") private var versionInterval = 120.0
    @State private var usage: (projects: Int64, deleted: Int64)?
    @State private var cache: Int64?
    @State private var busy: String?
    @State private var shareURL: URL?
    @State private var showRestore = false
    @State private var message: String?

    var body: some View {
        Section {
            Picker("Aspect", selection: $aspect) { ForEach(CreateProjectSheet.aspects) { Text($0.label).tag($0.label) } }
                .frame(minHeight: 44)
            Picker("Resolution", selection: $shortSide) { ForEach(CreateProjectSheet.resolutions, id: \.short) { Text($0.label).tag($0.short) } }
                .frame(minHeight: 44)
            Picker("Frame rate", selection: $fps) { ForEach(CreateProjectSheet.rates, id: \.self) { Text("\(Int($0)) fps").tag($0) } }
                .frame(minHeight: 44)
        } header: { Text("New project defaults") }

        Section {
            Picker("Save a version every", selection: $versionInterval) {
                Text("1 minute").tag(60.0); Text("2 minutes").tag(120.0); Text("5 minutes").tag(300.0); Text("10 minutes").tag(600.0)
            }
            .frame(minHeight: 44)
        } header: { Text("Autosave") } footer: {
            Text("Edits are saved a moment after every change. Versions are snapshots you can go back to from a project's menu (the last \(ProjectStore.maxVersions) are kept; named versions are kept forever).")
        }

        Section {
            LabeledContent("Projects", value: usage.map { bytes($0.projects) } ?? "…")
            LabeledContent("Recently Deleted", value: usage.map { bytes($0.deleted) } ?? "…")
            LabeledContent("Caches", value: cache.map(bytes) ?? "…")
            Button("Clear Caches") {
                run("Clearing…") { ProjectStore.clearCaches() }
            }
            .frame(minHeight: 44)
            .disabled(busy != nil)
        } header: { Text("Storage") } footer: {
            Text("Caches hold rebuildable render and audio files and old exports. Your projects and media are never touched.")
        }

        Section {
            Button("Back Up All Projects") {
                busy = "Packing backup…"
                Task.detached(priority: .userInitiated) {
                    let result = Result { try ProjectStore.shared.backupAll() }
                    await MainActor.run {
                        busy = nil
                        switch result {
                        case .success(let url): shareURL = url
                        case .failure(let e): message = e.localizedDescription
                        }
                    }
                }
            }
            .frame(minHeight: 44).disabled(busy != nil)
            Button("Restore from Backup…") { showRestore = true }.frame(minHeight: 44).disabled(busy != nil)
            if let busy { HStack { ProgressView(); Text(busy).foregroundStyle(Theme.textDim) } }
            if let message { Text(message).font(.footnote).foregroundStyle(Theme.textDim) }
        } header: { Text("Backup") } footer: {
            Text("One ZIP with every project, its media and versions. Save it to Files or iCloud Drive. Restoring adds the projects that aren't on this device.")
        }
        .onAppear(perform: measure)
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
            if let shareURL { ActivitySheet(items: [shareURL]) }
        }
        .fileImporter(isPresented: $showRestore, allowedContentTypes: [.zip]) { result in
            guard case .success(let url) = result else { return }
            busy = "Restoring…"
            Task.detached(priority: .userInitiated) {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let result = Result { try ProjectStore.shared.restoreBackup(url) }
                await MainActor.run {
                    busy = nil
                    switch result {
                    case .success(let r): message = "Restored \(r.restored) project\(r.restored == 1 ? "" : "s")" + (r.skipped > 0 ? ", \(r.skipped) already here." : ".")
                    case .failure(let e): message = e.localizedDescription
                    }
                    measure()
                }
            }
        }
    }

    private func bytes(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }

    private func measure() {
        Task.detached(priority: .utility) {
            let u = ProjectStore.shared.storageUsage(), c = ProjectStore.cacheBytes()
            await MainActor.run { usage = u; cache = c }
        }
    }

    private func run(_ label: String, _ work: @escaping @Sendable () -> Void) {
        busy = label
        Task.detached(priority: .utility) {
            work()
            await MainActor.run { busy = nil; measure() }
        }
    }
}
