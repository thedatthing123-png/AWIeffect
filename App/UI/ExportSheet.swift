import SwiftUI
import Photos

struct ExportSheet: View {
    @ObservedObject var state: EditorState
    @State private var settings = ExportSettings()
    @State private var progress: Double = 0
    @State private var exporting = false
    @State private var exporter: Exporter?
    @State private var resultURL: URL?
    @State private var message: String?
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let (w, h) = Exporter.outputSize(state.project, scale: settings.scale)
                    HStack {
                        stat("Output", "\(w)×\(h)")
                        stat("Frame rate", "\(Int(state.project.fps)) fps")
                        stat("Est. size", estimatedSize)
                    }
                    section("Resolution") {
                        Picker("", selection: $settings.scale) {
                            Text("100%").tag(1.0); Text("75%").tag(0.75); Text("50%").tag(0.5)
                        }.pickerStyle(.segmented)
                    }
                    section("Codec") {
                        Picker("", selection: $settings.codec) {
                            ForEach(VideoCodec.allCases) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                    section("Bitrate \(Int(settings.bitrateMbps)) Mbps") {
                        Slider(value: $settings.bitrateMbps, in: 4...80, step: 1)
                    }

                    if exporting {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress).tint(Theme.accent)
                            Text("Rendering \(Int(progress * 100))%").font(.caption).foregroundStyle(Theme.textDim)
                            Button("Cancel", role: .destructive) { exporter?.cancel() }
                        }
                    } else {
                        Button("Export Video (MP4)") { start() }.buttonStyle(PrimaryButtonStyle())
                        Button("Save Current Frame as PNG") { saveFrame() }
                            .frame(maxWidth: .infinity).padding(.vertical, 12).glass(radius: 12)
                            .foregroundStyle(Theme.text)
                    }
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(Theme.textDim)
                    }
                    if let resultURL {
                        HStack(spacing: 10) {
                            Button { saveToPhotos(resultURL) } label: { Label("Save to Photos", systemImage: "photo.on.rectangle") }
                                .frame(maxWidth: .infinity).padding(.vertical, 12).glass(radius: 12)
                            ShareLink(item: resultURL) { Label("Share", systemImage: "square.and.arrow.up") }
                                .frame(maxWidth: .infinity).padding(.vertical, 12).glass(radius: 12)
                        }
                        .foregroundStyle(Theme.text)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Export & Share")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var estimatedSize: String {
        let mb = settings.bitrateMbps * state.project.duration / 8
        return mb < 1 ? "<1 MB" : "~\(Int(mb.rounded())) MB"
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.caption2).foregroundStyle(Theme.textDim)
            Text(v).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textDim)
            c()
        }
    }

    private func start() {
        state.pause()
        let ex = Exporter()
        exporter = ex
        exporting = true
        progress = 0
        message = nil
        resultURL = nil
        let project = state.project
        let pid = project.id
        let store = state.store
        let s = settings
        UIApplication.shared.isIdleTimerDisabled = true
        Task.detached {
            do {
                let url = try await ex.export(project: project, settings: s, mediaURL: { store.mediaURL($0, projectID: pid) }) { p in
                    Task { @MainActor in progress = p }
                }
                await MainActor.run {
                    resultURL = url
                    message = "Export finished."
                    exporting = false
                    UIApplication.shared.isIdleTimerDisabled = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    message = error.localizedDescription
                    exporting = false
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    private func saveToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in message = "Photos access was denied. Use Share instead." }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { ok, err in
                Task { @MainActor in message = ok ? "Saved to Photos." : (err?.localizedDescription ?? "Save failed.") }
            }
        }
    }

    private func saveFrame() {
        guard let r = Renderer.shared else { return }
        let pid = state.project.id
        let store = state.store
        guard let img = r.renderImage(project: state.project, time: state.currentTime,
                                      maxDimension: Double(max(state.project.width, state.project.height)),
                                      mediaURL: { store.mediaURL($0, projectID: pid) }),
              let data = img.pngData() else { message = "Couldn't render frame."; return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(state.project.name)-frame.png")
        try? data.write(to: url)
        resultURL = url
        message = "Frame ready."
    }
}
