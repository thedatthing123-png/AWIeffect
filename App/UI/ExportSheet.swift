import SwiftUI
import Photos
import AVFoundation
import AVKit
import UniformTypeIdentifiers

/// After export: the finished video plays first (like Alight Motion's showcase), then save, share or go back to editing.
struct ExportPreview: View {
    let url: URL
    let onSave: () -> Void
    let onClose: () -> Void
    let message: String?
    var saving = false
    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button { onClose() } label: { Label("Keep Editing", systemImage: "chevron.left").font(.system(size: 15, weight: .semibold)) }
                Spacer()
            }
            .foregroundStyle(Theme.text).padding(.horizontal, 16).padding(.top, 8)
            if PhotoLibrarySaver.resourceType(for: url) == .photo, let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: .infinity)
            } else {
                VideoPlayer(player: player).frame(maxHeight: .infinity)
            }
            if let message { Text(message).font(.footnote).foregroundStyle(Theme.textDim) }
            HStack(spacing: 10) {
                if PhotoLibrarySaver.resourceType(for: url) != nil {
                    Button { onSave() } label: { Label("Save to Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle()).disabled(saving)
                }
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .frame(maxWidth: .infinity).padding(.vertical, 12).glass(radius: 12).foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            let isAudio = UTType(filenameExtension: url.pathExtension.lowercased())?.conforms(to: .audio) == true
            guard PhotoLibrarySaver.resourceType(for: url) == .video || isAudio else { return }
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
    @State private var saving = false
    @State private var exporter: Exporter?
    @State private var resultURL: URL?
    @State private var message: String?
    @State private var rangeMode = "All"
    @State private var preset: String?
    @State private var frameFormat: FrameFormat = .pngAlpha
    @State private var showPreview = false
    @Environment(\.dismiss) private var dismissSheet

    private static let videoFormats: [ExportFormat] = [.mp4, .transparent, .prores422, .prores4444, .gif, .pngSequence]
    private static let audioFormats: [ExportFormat] = [.audioM4A, .audioWAV]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let root = state.rootProject
                    let (w, h) = outputDims(root)
                    HStack {
                        stat("Output", settings.format.isAudioOnly ? "Sound only" : "\(w)×\(h)")
                        stat("Frame rate", settings.format.isAudioOnly ? "—" : "\(Int(settings.format == .gif ? Exporter.gifOutput(root, settings: settings).fps : (settings.fps ?? root.fps))) fps")
                        stat("Est. size", estimatedSize)
                    }
                    section("Presets") {
                        chips(ExportPreset.all, selected: ExportPreset.all.first { $0.name == preset }, title: { $0.name }) { p in
                            settings = p.apply(to: settings, project: root); preset = p.name
                        }
                        if let p = ExportPreset.all.first(where: { $0.name == preset }), p.aspectMismatch(root) {
                            Text("This project isn't \(p.vertical ? "9:16 vertical" : "landscape"). The preset keeps your frame; the platform may add bars or crop.")
                                .font(.caption).foregroundStyle(Theme.warning)
                        }
                    }
                    section("Format") {
                        chips(Self.videoFormats, selected: settings.format, title: { $0.rawValue }) { settings.format = $0; preset = nil }
                        chips(Self.audioFormats, selected: settings.format, title: { $0.rawValue }) { settings.format = $0; preset = nil }
                        if settings.format == .mp4 {
                            Picker("Codec", selection: $settings.codec) {
                                ForEach(VideoCodec.allCases) { Text($0.rawValue).tag($0) }
                            }.pickerStyle(.segmented).frame(minHeight: 44)
                        }
                        Label(settings.format.codecName(settings.codec), systemImage: "cpu")
                            .font(.caption).foregroundStyle(Theme.textDim)
                        if settings.format.keepsAlpha {
                            Text("Empty background stays transparent. Add a background layer for an opaque frame.").font(.caption).foregroundStyle(Theme.textDim)
                        }
                        if settings.format == .gif {
                            Text("GIF is limited to \(Int(Exporter.gifMaxDimension)) px on the long side and \(Int(Exporter.gifMaxFPS)) fps, with no sound.")
                                .font(.caption).foregroundStyle(Theme.warning)
                        }
                    }
                    if !settings.format.isAudioOnly {
                        section("Resolution") {
                            let shortSide = Double(min(root.width, root.height))
                            chips([480.0, 720, 1080, 1440, 2160], selected: (shortSide * settings.scale).rounded(),
                                  title: { [480: "480p", 720: "720p", 1080: "1080p", 1440: "2K", 2160: "4K"][$0] ?? "" }) { v in
                                settings.scale = v / shortSide; preset = nil
                            }
                            HStack(spacing: 8) {
                                Text("Custom").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 64, alignment: .leading)
                                ValueScrubber(value: (shortSide * settings.scale).rounded(), range: 64...4320, step: 2, unit: " px", onChange: { v in
                                    settings.scale = min(4, max(0.05, v / shortSide)); preset = nil
                                })
                            }.frame(minHeight: 44)
                        }
                        section("Frame Rate") {
                            chips([0.0, 24, 25, 30, 50, 60], selected: settings.fps ?? 0, title: { $0 == 0 ? "Project" : "\(Int($0))" }) { v in
                                settings.fps = v == 0 ? nil : v; preset = nil
                            }
                        }
                    }
                    section("Range") {
                        chips(["All", "From Playhead", "Selected Layer", "Custom"], selected: rangeMode, title: { $0 }) { pickRange($0) }
                        if rangeMode == "Custom" {
                            let dur = root.duration
                            HStack {
                                Text("In").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 64, alignment: .leading)
                                ValueScrubber(value: settings.start, range: 0...max(0.01, dur), step: root.frameDuration, unit: "s", onChange: { v in
                                    settings.start = min(max(0, v), (settings.end ?? dur) - root.frameDuration)
                                })
                            }.frame(minHeight: 44)
                            HStack {
                                Text("Out").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 64, alignment: .leading)
                                ValueScrubber(value: settings.end ?? dur, range: 0...max(0.01, dur), step: root.frameDuration, unit: "s", onChange: { v in
                                    settings.end = min(dur, max(settings.start + root.frameDuration, v))
                                })
                            }.frame(minHeight: 44)
                            HStack(spacing: 8) {
                                Button("In at Playhead") { settings.start = min(state.rootTime(state.currentTime), (settings.end ?? dur) - root.frameDuration) }
                                    .frame(maxWidth: .infinity, minHeight: 44).glass(radius: 12)
                                Button("Out at Playhead") { settings.end = max(settings.start + root.frameDuration, state.rootTime(state.currentTime)) }
                                    .frame(maxWidth: .infinity, minHeight: 44).glass(radius: 12)
                            }
                            .foregroundStyle(Theme.text)
                        }
                        Text(String(format: "%.2fs → %.2fs", settings.start, settings.end ?? root.duration))
                            .font(.caption.monospaced()).foregroundStyle(Theme.textDim)
                    }
                    if settings.format.usesBitrate {
                        // The one quality control: drag or tap to type the Mbps (for 1080p30; scaled to your size and rate).
                        section("Quality · \(qualityName)") {
                            ValueScrubber(value: settings.bitrateMbps, range: 4...120, step: 1, unit: " Mbps", onChange: { settings.bitrateMbps = $0; preset = nil })
                                .frame(minHeight: 44)
                        }
                    }

                    if exporting {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress).tint(Theme.accent)
                            Text("Rendering \(Int(progress * 100))%").font(.caption).foregroundStyle(Theme.textDim)
                            Button("Cancel", role: .destructive) { exporter?.cancel() }.frame(minHeight: 44)
                        }
                    } else {
                        Button("Export \(settings.format.rawValue)") { start() }.buttonStyle(PrimaryButtonStyle())
                        section("Current Frame") {
                            chips(FrameFormat.allCases, selected: frameFormat, title: { $0.rawValue }) { frameFormat = $0 }
                            Button("Save Current Frame as \(frameFormat == .jpg ? "JPG" : "PNG")") { saveFrame() }
                                .frame(maxWidth: .infinity, minHeight: 44).glass(radius: 12)
                                .foregroundStyle(Theme.text)
                        }
                    }
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(Theme.textDim)
                    }
                    if let resultURL {
                        HStack(spacing: 10) {
                            if PhotoLibrarySaver.resourceType(for: resultURL) != nil {
                                Button { saveToPhotos(resultURL) } label: { Label(saving ? "Saving…" : "Save to Photos", systemImage: "photo.on.rectangle") }
                                    .disabled(saving)
                                    .frame(maxWidth: .infinity, minHeight: 44).glass(radius: 12)
                            }
                            ShareLink(item: resultURL) { Label("Share / Save to Files", systemImage: "square.and.arrow.up") }
                                .frame(maxWidth: .infinity, minHeight: 44).glass(radius: 12)
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
                                  message: message, saving: saving)
                }
            }
            .navigationTitle("Export & Share")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var qualityName: String {
        switch settings.bitrateMbps {
        case ..<12: return "Low"
        case ..<30: return "Good"
        case ..<60: return "High"
        default: return "Max"
        }
    }

    private func pickRange(_ m: String) {
        rangeMode = m
        switch m {
        // Export always renders the root comp, so times inside an open group / pre-comp are mapped out.
        case "From Playhead": settings.start = state.rootTime(state.currentTime); settings.end = nil
        case "Selected Layer":
            if let l = state.selectedLayer {
                let a = state.rootTime(l.inPoint), b = state.rootTime(l.outPoint)
                settings.start = max(0, min(a, b)); settings.end = min(state.rootProject.duration, max(a, b))
            }
        case "Custom": settings.end = settings.end ?? state.rootProject.duration
        default: settings.start = 0; settings.end = nil
        }
    }

    private func outputDims(_ root: Project) -> (Int, Int) {
        if settings.format == .gif { let g = Exporter.gifOutput(root, settings: settings); return (g.width, g.height) }
        return Exporter.outputSize(root, scale: settings.scale)
    }

    private var estimatedSize: String {
        let mb = Exporter.estimatedBytes(state.rootProject, settings: settings) / 1_000_000
        return mb < 1 ? "<1 MB" : mb >= 1000 ? String(format: "~%.1f GB", mb / 1000) : "~\(Int(mb.rounded())) MB"
    }

    private func chips<T: Hashable>(_ items: [T], selected: T?, title: @escaping (T) -> String, pick: @escaping (T) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { it in
                    Button { pick(it) } label: {
                        Text(title(it)).font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14).frame(minHeight: 44)
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
                    showPreview = PhotoLibrarySaver.resourceType(for: url) != nil || s.format.isAudioOnly
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
        guard !saving else { return }
        saving = true
        message = "Saving to Photos…"
        Task { @MainActor in
            defer { saving = false }
            do {
                try await PhotoLibrarySaver.save(url)
                message = "Saved to Photos."
            } catch { message = error.localizedDescription }
        }
    }

    private func saveFrame() {
        let root = state.rootProject
        let store = state.store
        let pid = root.id
        // The root comp at the matching root time (inside a group the open comp is only part of the picture).
        do {
            resultURL = try Exporter.renderFrame(project: root, time: state.rootTime(state.currentTime), scale: settings.scale,
                                                 format: frameFormat, mediaURL: { store.mediaURL($0, projectID: pid) })
            message = "Frame ready."
        } catch { message = error.localizedDescription }
    }
}
