import SwiftUI

/// Captions & lyrics: hear a video / audio layer's words on device, edit them, then Apply builds one
/// text layer per line with a per-word karaoke highlight (one undo step).
struct CaptionsStudio: View {
    @ObservedObject var state: EditorState
    let sourceLayerID: UUID
    var transcriber: CaptionTranscribing = SpeechTranscriber()
    @Environment(\.dismiss) private var dismiss

    @State private var track = CaptionTrack()
    @State private var loaded = false
    @State private var running: Task<Void, Never>?
    @State private var progress: Double = 0
    @State private var message: String?
    @State private var localeIDs: [String] = []

    private var source: Layer? { state.project.layers.first { $0.id == sourceLayerID } }

    private var mediaFile: String? {
        switch source?.content {
        case .some(.video(let f, _, _, let hasAudio)): return hasAudio ? f : nil
        case .some(.audio(let f, _)): return f
        default: return nil
        }
    }

    private var timeRange: ClosedRange<Double> {
        let l = source
        let a = l?.inPoint ?? 0
        return a...max(a + 0.1, l?.outPoint ?? state.project.duration)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    generateSection
                    if !track.lines.isEmpty {
                        lookSection
                        groupingSection
                        linesSection
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Captions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { running?.cancel(); dismiss() }.frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }
                        .fontWeight(.bold)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(track.lines.isEmpty || running != nil)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
        .onDisappear { running?.cancel() }
    }

    // MARK: Sections

    private func sectionTitle(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
    }

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Words")
            HStack(spacing: 10) {
                Menu {
                    Picker("Language", selection: $track.localeID) {
                        ForEach(localeIDs, id: \.self) { id in
                            Text(Locale.current.localizedString(forIdentifier: id) ?? id).tag(id)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "globe")
                        Text(Locale.current.localizedString(forIdentifier: track.localeID) ?? track.localeID)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11))
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
                }
                .foregroundStyle(Theme.text)
                if running == nil {
                    Button { generate() } label: {
                        Label(track.lines.isEmpty ? "Generate" : "Redo", systemImage: "waveform.badge.mic")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(minWidth: 120, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(mediaFile == nil)
                } else {
                    Button(role: .cancel) { running?.cancel() } label: {
                        Text("Stop").font(.system(size: 14, weight: .semibold))
                            .frame(minWidth: 120, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
                            .foregroundStyle(Theme.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
            if running != nil {
                ProgressView(value: progress).tint(Theme.accent)
                Text("Listening on device… \(Int(progress * 100))%").font(.system(size: 12)).foregroundStyle(Theme.textDim)
            }
            if mediaFile == nil {
                Text("This layer has no audio.").font(.system(size: 12)).foregroundStyle(Theme.warning)
            }
            if let message {
                Text(message).font(.system(size: 12)).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var lookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Look")
            HStack(spacing: 10) {
                menuButton(title: (CaptionStyle(rawValue: track.styleID) ?? .clean).title, icon: "textformat") {
                    ForEach(CaptionStyle.allCases) { s in Button(s.title) { track.styleID = s.rawValue } }
                }
                menuButton(title: track.highlight.title, icon: "highlighter") {
                    ForEach(CaptionHighlight.allCases) { h in Button(h.title) { track.highlight = h } }
                }
                AWIColorWell("", selection: Binding(get: { Color(track.highlightColor) },
                                                    set: { track.highlightColor = $0.rgba }))
                    .frame(width: 52, height: 44)
            }
            labeled("Height") {
                ValueScrubber(value: track.positionY * 100, range: 0...100, step: 1, unit: "%", onChange: { track.positionY = $0 / 100 })
                    .frame(height: 44)
            }
        }
    }

    private var groupingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Lines")
            labeled("Max letters") {
                ValueScrubber(value: Double(track.grouping.maxCharacters), range: 6...80, step: 1, onChange: {
                    track.grouping.maxCharacters = Int($0); track.regroup()
                }).frame(height: 44)
            }
            labeled("Max time") {
                ValueScrubber(value: track.grouping.maxDuration, range: 0.5...10, step: 0.1, unit: " s", onChange: {
                    track.grouping.maxDuration = $0; track.regroup()
                }).frame(height: 44)
            }
            labeled("Pause split") {
                ValueScrubber(value: track.grouping.pauseGap, range: 0.1...3, step: 0.05, unit: " s", onChange: {
                    track.grouping.pauseGap = $0; track.regroup()
                }).frame(height: 44)
            }
            labeled("Hold after") {
                ValueScrubber(value: track.grouping.linger, range: 0...2, step: 0.05, unit: " s", onChange: {
                    track.grouping.linger = $0
                }).frame(height: 44)
            }
        }
    }

    private var linesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Edit words")
            ForEach(Array(track.lines.enumerated()), id: \.element.id) { li, line in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button { state.seek(line.start) } label: {
                            Text("Line \(li + 1)  ·  " + String(format: "%.2f s", line.start))
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        if line.words.count > 1 {
                            Menu {
                                ForEach(1..<line.words.count, id: \.self) { wi in
                                    Button("Before \u{201C}\(line.words[wi].text)\u{201D}") { track.split(lineID: line.id, at: wi) }
                                }
                            } label: { smallLabel("Split", "scissors") }
                        }
                        if li + 1 < track.lines.count {
                            Button { track.mergeWithNext(lineID: line.id) } label: { smallLabel("Merge", "arrow.down.to.line") }
                                .buttonStyle(.plain)
                        }
                    }
                    ForEach(line.words) { w in wordRow(w) }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            }
        }
    }

    private func wordRow(_ w: CaptionWord) -> some View {
        HStack(spacing: 8) {
            TextField("word", text: Binding(get: { w.text }, set: { setText(w.id, $0) }))
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 10)
                .frame(minWidth: 80, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised))
            ValueScrubber(value: w.start, range: timeRange, step: 0.01, unit: "s", onChange: { track.setTimes(wordID: w.id, start: $0) })
                .frame(height: 44)
            ValueScrubber(value: w.end, range: timeRange, step: 0.01, unit: "s", onChange: { track.setTimes(wordID: w.id, end: $0) })
                .frame(height: 44)
        }
    }

    // MARK: Helpers

    private func labeled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                .frame(width: 96, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    private func smallLabel(_ t: String, _ icon: String) -> some View {
        Label(t, systemImage: icon).font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 10)
            .frame(minWidth: 44, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised))
            .foregroundStyle(Theme.text)
    }

    private func menuButton<Items: View>(title: String, icon: String, @ViewBuilder _ items: () -> Items) -> some View {
        Menu { items() } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title).lineLimit(1).minimumScaleFactor(0.75)
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
            .foregroundStyle(Theme.text)
        }
    }

    private func setText(_ id: UUID, _ s: String) {
        for li in track.lines.indices {
            if let wi = track.lines[li].words.firstIndex(where: { $0.id == id }) { track.lines[li].words[wi].text = s; return }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        localeIDs = SpeechTranscriber.supportedLocaleIDs
        if let existing = state.project.captionTrack(forSource: sourceLayerID) {
            track = existing
        } else {
            track.sourceLayerID = sourceLayerID
            let cur = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
            track.localeID = localeIDs.first { $0.replacingOccurrences(of: "_", with: "-") == cur } ?? localeIDs.first { $0.hasPrefix("en") } ?? "en-US"
        }
        if !localeIDs.contains(track.localeID) { localeIDs.insert(track.localeID, at: 0) }
    }

    private func generate() {
        guard let file = mediaFile, let layer = source else { return }
        message = nil
        progress = 0
        let url = state.mediaURL(file)
        let speed = max(0.01, abs(layer.speed))
        let srcRange = layer.sourceStart...(layer.sourceStart + max(0.1, (layer.outPoint - layer.inPoint) * speed))
        let locale = track.localeID
        let t = transcriber
        running = Task { @MainActor in
            do {
                let heard = try await t.transcribe(url: url, range: srcRange, localeID: locale) { p in
                    Task { @MainActor in progress = p }
                }
                let words = CaptionTrack.compWords(heard, for: layer)
                track.setWords(words)
                if words.isEmpty { message = "No words were heard in this clip." }
            } catch is CancellationError {
                message = "Stopped."
            } catch {
                message = error.localizedDescription
            }
            running = nil
        }
    }

    private func apply() {
        var t = track
        t.lines = t.lines.filter { !$0.words.isEmpty }
        state.mutate("Captions") { $0.applyCaptions(t) }
        dismiss()
    }
}
