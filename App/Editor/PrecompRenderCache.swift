import Foundation
import CryptoKit
import SwiftUI

struct PrecompProxy: Codable, Equatable {
    var file: String
    var signature: String
}

enum PrecompRenderCache {
    private static let lock = NSLock()
    private static var signatures: [UUID: (Project, String)] = [:]
    static func signature(_ comp: Project, library: [Project]) -> String {
        func clean(_ project: Project) -> Project {
            var value = project
            value.createdAt = Date(timeIntervalSince1970: 0); value.modifiedAt = Date(timeIntervalSince1970: 0)
            value.preRenderProxy = nil; value.precompList = nil
            value.precompDepth = nil; value.parentContext = nil
            return value
        }
        var value = clean(comp)
        value.precompList = library.map(clean).sorted { $0.id.uuidString < $1.id.uuidString }
        lock.lock(); defer { lock.unlock() }
        if let cached = signatures[comp.id], cached.0 == value { return cached.1 }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return "invalid" }
        let signature = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if signatures.count > 16 { signatures.removeAll() }
        signatures[comp.id] = (value, signature)
        return signature
    }
}

extension EditorState {
    func preRenderSelectedComp() {
        guard preRenderTask == nil, let selected = selectedLayer, case .precomp(let id) = selected.content,
              var comp = rootProject.precomps.first(where: { $0.id == id }) else { return }
        pause()
        let rootID = rootProject.id, library = rootProject.precomps
        let signature = PrecompRenderCache.signature(comp, library: library)
        comp.precompList = library; comp.preRenderProxy = nil
        let store = store, exporter = Exporter()
        preRenderExporter = exporter; preRenderProgress = 0
        preRenderTask = Task { [weak self] in
            defer { self?.preRenderTask = nil; self?.preRenderExporter = nil; self?.preRenderProgress = nil }
            do {
                var settings = ExportSettings(); settings.format = .transparent
                let output = try await exporter.export(project: comp, settings: settings, mediaURL: { store.mediaURL($0, projectID: rootID) }) { progress in
                    Task { @MainActor in self?.preRenderProgress = progress }
                }
                defer { try? FileManager.default.removeItem(at: output) }
                guard !Task.isCancelled, let self, self.rootProject.id == rootID,
                      let index = self.project.precomps.firstIndex(where: { $0.id == id }),
                      PrecompRenderCache.signature(self.project.precomps[index], library: self.rootProject.precomps) == signature else {
                    self?.recoveryNotice = "The precomp changed while rendering. Render it again to cache the new version."
                    return
                }
                let file = UUID().uuidString + ".mov"
                try FileManager.default.createDirectory(at: store.mediaFolder(for: rootID), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: output, to: store.mediaURL(file, projectID: rootID))
                self.mutate("Pre-render Precomp") { project in
                    var comps = project.precomps
                    comps[index].preRenderProxy = PrecompProxy(file: file, signature: signature)
                    project.precomps = comps
                }
                self.recoveryNotice = "Pre-render ready. Editing the precomp automatically invalidates it."
            } catch {
                if !Task.isCancelled { self?.recoveryNotice = "Pre-render failed: \(error.localizedDescription)" }
            }
        }
    }

    func cancelPreRender() { preRenderExporter?.cancel(); preRenderTask?.cancel() }

    func clearSelectedPreRender() {
        guard let selected = selectedLayer, case .precomp(let id) = selected.content else { return }
        mutate("Clear Pre-render") { project in
            var comps = project.precomps
            if let index = comps.firstIndex(where: { $0.id == id }) { comps[index].preRenderProxy = nil }
            project.precomps = comps
        }
    }
}

struct PrecompRenderControls: View {
    @ObservedObject var state: EditorState
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PRE-RENDER").font(.caption.bold()).foregroundStyle(Theme.text)
            if let progress = state.preRenderProgress {
                ProgressView(value: progress).tint(Theme.accent)
                Button("Cancel Pre-render") { state.cancelPreRender() }
            } else {
                HStack {
                    Button("Pre-render Precomp") { state.preRenderSelectedComp() }
                    Button("Clear Cache") { state.clearSelectedPreRender() }
                }.buttonStyle(.bordered)
            }
            Text("Caches this composition for smooth preview. Changes invalidate it automatically; final exports render the original layers.")
                .font(.caption2).foregroundStyle(Theme.textDim)
        }.padding(10).glass(radius: 12)
    }
}
