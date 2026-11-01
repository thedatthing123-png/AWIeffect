import SwiftUI
import Photos
import AVFoundation
import AVKit

/// After export: the finished video plays first (like Alight Motion's showcase), then save, share or go back to editing.
struct ExportPreview: View {
    let url: URL
    let onSave: () -> Void
    let onClose: () -> Void
    let message: String?
    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button { onClose() } label: { Label("Keep Editing", systemImage: "chevron.left").font(.system(size: 15, weight: .semibold)) }
                Spacer()
            }
            .foregroundStyle(Theme.text).padding(.horizontal, 16).padding(.top, 8)
            if url.pathExtension.lowercased() == "gif", let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: .infinity)
            } else {
                VideoPlayer(player: player).frame(maxHeight: .infinity)
            }
            if let message { Text(message).font(.footnote).foregroundStyle(Theme.textDim) }
            HStack(spacing: 10) {
                Button { onSave() } label: { Label("Save to Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryButtonStyle())
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .frame(maxWidth: .infinity).padding(.vertical, 12).glass(radius: 12).foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            let item = AVPlayerItem(url: url)
            let q = AVQueuePlayer()
            looper = AVPlayerLooper(player: q, templateItem: item)
            player = q
            q.play()
        }
        .onDisappear { player?.pause() }
    }
}

struct ExportSheet: View {
    @ObservedObject var state: EditorState
    @State private var settings = ExportSettings()
    @State private var progress: Double = 0
    @State private var exporting = false
    @State private var exporter: Exporter?
    @State private var resultURL: URL?
    @State private var message: String?
    @State private var showShare = false
    @State private var rangeMode = "All"
    @State private var showPreview = false
    @Environment(\.dismiss) private var dismissSheet

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let (w, h) = Exporter.outputSize(state.project, scale: settings.scale)
                    HStack {
                        stat("Output", "\(w)×\(h)")
                        stat("Frame rate", "\(Int(settings.fps ?? state.project.fps)) fps")
                        stat("Est. size", estimatedSize)
                    }
                    section("Format") {
                        chips(ExportFormat.allCases, selected: settings.format, title: { $0.rawValue }) { settings.format = $0 }
                    }
                    section("Resolution") {
                        let shortSide = Double(min(state.project.width, state.project.height))
                        chips([480.0, 720, 1080, 1440, 2160], selected: (shortSide * settings.scale).rounded(),
                              title: { [480: "480p", 720: "720p", 1080: "1080p", 1440: "2K", 2160: "4K"][$0] ?? "" }) { v in
                            settings.scale = v / shortSide
                        }
                        // Custom: any size (short side in px), keeps the project's shape.
                        HStack(spacing: 8) {
                            Text("Custom").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textDim)
                            NumberField(value: (shortSide * settings.scale).rounded(), label: "px") { v in
                                settings.scale = min(4, max(0.05, v / shortSide))
                            }
                            let (cw, ch) = Exporter.outputSize(state.project, scale: settings.scale)
                            Text("\(cw)×\(ch)").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textDim)
                        }
                    }
                    section("Frame Rate") {
                        chips([0.0, 24, 25, 30, 50, 60], selected: settings.fps ?? 0, title: { $0 == 0 ? "Project" : "\(Int($0))" }) { v in
                            settings.fps = v == 0 ? nil : v
                        }
                    }
                    section("Range") {
                        chips(["All", "From Playhead", "Selected Layer"], selected: rangeMode, title: { $0 }) { m in
                            rangeMode = m
                            switch m {
                            case "From Playhead": settings.start = state.currentTime; settings.end = nil
                            case "Selected Layer":
                                if let l = state.selectedLayer { settings.start = max(0, l.inPoint); settings.end = min(state.project.duration, l.outPoint) }
                            default: settings.start = 0; settings.end = nil
                            }
                        }
                        Text(String(format: "%.2fs → %.2fs", settings.start, settings.end ?? state.project.duration))
                            .font(.caption.monospaced()).foregroundStyle(Theme.textDim)
                    }
                    if settings.format == .mp4 {
                        section("Codec") {
                            Picker("", selection: $settings.codec) {
                                ForEach(VideoCodec.allCases) { Text($0.rawValue).tag($0) }
                            }.pickerStyle(.segmented)
                        }
                    }
                    if settings.format != .gif {
                        section("Quality \(Int(settings.bitrateMbps)) Mbps") {
                            chips([8.0, 20, 40, 80], selected: settings.bitrateMbps, title: { [8: "Low", 20: "Good", 40: "High", 80: "Max"][$0] ?? "" }) {
                                settings.bitrateMbps = $0
                            }
                            Slider(value: $settings.bitrateMbps, in: 4...120, step: 1).tint(Theme.accent)
                        }
                    }

                    if exporting {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress).tint(Theme.accent)
                            Text("Rendering \(Int(progress * 100))%").font(.caption).foregroundStyle(Theme.textDim)
                            Button("Cancel", role: .destructive) { exporter?.cancel() }
                        }
                    } else {
                        Button(settings.format == .gif ? "Export GIF" : "Export Video (\(settings.format.rawValue))") { start() }.buttonStyle(PrimaryButtonStyle())
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
            .fullScreenCover(isPresented: $showPreview) {
                if let resultURL {
                    ExportPreview(url: resultURL, onSave: { saveToPhotos(resultURL) },
                                  onClose: { showPreview = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismissSheet() } },
                                  message: message)
                }
            }
            .navigationTitle("Export & Share")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var estimatedSize: String {
        let dur = (settings.end ?? state.project.duration) - settings.start
        if settings.format == .gif { return "~\(max(1, Int(dur * 1.5))) MB" }
        let mb = settings.bitrateMbps * dur / 8
        return mb < 1 ? "<1 MB" : "~\(Int(mb.rounded())) MB"
    }

    private func chips<T: Hashable>(_ items: [T], selected: T, title: @escaping (T) -> String, pick: @escaping (T) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { it in
                    Button { pick(it) } label: {
                        Text(title(it)).font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(it == selected ? Theme.accent : Theme.raised))
                            .foregroundStyle(it == selected ? Color.white : Theme.text)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
        let project = state.rootProject
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
                    showPreview = true
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
            Self.addToPhotos(url) { ok, err in
                if ok || url.pathExtension == "gif" {
                    Task { @MainActor in message = ok ? "Saved to Photos." : (err?.localizedDescription ?? "Save failed.") }
                    return
                }
                // Photos refused the file: make a Photos-friendly copy and save that instead.
                Task { @MainActor in message = "Converting for Photos…" }
                Self.photosCopy(of: url) { copy in
                    guard let copy else { Task { @MainActor in message = "Couldn't save to Photos. Use Share instead." }; return }
                    Self.addToPhotos(copy) { ok2, err2 in
                        try? FileManager.default.removeItem(at: copy)
                        Task { @MainActor in message = ok2 ? "Saved to Photos." : (err2?.localizedDescription ?? "Save failed. Use Share instead.") }
                    }
                }
            }
        }
    }

    nonisolated private static func addToPhotos(_ url: URL, _ done: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            if url.pathExtension == "gif" {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: url, options: nil)
            } else {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            }
        }, completionHandler: done)
    }

    /// Re-encodes a video with Apple's own settings (always accepted by Photos).
    nonisolated private static func photosCopy(of url: URL, _ done: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: url)
        guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { done(nil); return }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        s.outputURL = out
        s.outputFileType = .mov
        s.exportAsynchronously { done(s.status == .completed ? out : nil) }
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
