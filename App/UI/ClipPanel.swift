import SwiftUI

/// Speed, trim, time remap, volume and beat tools for video/audio layers.
struct ClipPanel: View {
    @ObservedObject var state: EditorState
    @EnvironmentObject private var trackLauncher: TrackLauncher
    @State private var sensitivity = 0.5
    @State private var slowMoProgress: Double?
    @State private var slowMoMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Clip")
            if let l = state.selectedLayer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if l.timeRemap == nil {
                            row("Speed", value: l.speed, range: 0.1...4, fmt: "%.2fx") { v in
                                let srcLen = mediaDuration(l)
                                state.mutateLayer { layer in
                                    let oldLen = layer.outPoint - layer.inPoint
                                    layer.speed = v
                                    if srcLen > 0.05 {
                                        let fits = max(0.1, (srcLen - layer.sourceStart) / v)
                                        layer.outPoint = layer.inPoint + min(fits, max(oldLen * 4, fits))
                                    }
                                }
                            }
                        } else {
                            HStack {
                                Label("Time Remap is on", systemImage: "timer").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ok)
                                Spacer()
                                Button("Turn Off", role: .destructive) { state.mutate("Disable Time Remap") { p in
                                    if let i = state.selectedIndex { p.layers[i].timeRemap = nil }
                                } }
                            }
                        }
                        if case .video = l.content {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SMOOTH SLOW-MO (AI in-between frames, like Twixtor)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                                if let pr = slowMoProgress {
                                    ProgressView(value: pr).tint(Theme.accent)
                                    Text("Rendering smooth frames… \(Int(pr * 100))%").font(.caption).foregroundStyle(Theme.textDim)
                                } else {
                                    HStack(spacing: 6) {
                                        ForEach([2, 4, 8], id: \.self) { f in
                                            Button("\(f)x") { smoothSlowMo(f) }
                                                .font(.system(size: 13, weight: .bold)).frame(maxWidth: .infinity, minHeight: 34)
                                                .background(Capsule().fill(Theme.surface)).foregroundStyle(Theme.text)
                                        }
                                    }
                                }
                                if let m = slowMoMessage { Text(m).font(.caption).foregroundStyle(Theme.textDim) }
                            }
                        }
                        row("Trim Start", value: l.sourceStart, range: 0...max(1, mediaDuration(l)), fmt: "%.2fs") { v in state.mutateLayer { $0.sourceStart = v } }
                        if l.hasAudio {
                            row("Volume", value: l.volume.value(at: state.currentTime), range: 0...200, fmt: "%.0f%%") { v in
                                let t = state.currentTime
                                state.mutateLayer { $0.volume.set(v, at: t) }
                            }
                        }
                        HStack(spacing: 8) {
                            ToolTile(icon: "speedometer", title: "Velocity Ramp") { state.applySpeedRamp() }
                            if l.hasAudio {
                                ToolTile(icon: "speaker.wave.1", title: "Fade In") { state.audioFade(in: true) }
                                ToolTile(icon: "speaker.slash", title: "Fade Out") { state.audioFade(in: false) }
                            }
                            ToolTile(icon: "timer", title: "Time Remap") { state.enableTimeRemap() }
                            ToolTile(icon: "scissors", title: "Split") { state.splitSelected() }
                        }
                        if l.timeRemap != nil {
                            Text("Time Remap keyframes are on the timeline; edit their easing in the Graph Editor for smooth velocity edits.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                        }
                        Toggle("Frame Blending", isOn: Binding(get: { l.frameBlending }, set: { b in state.mutate("Frame Blending") { p in
                            if let i = state.selectedIndex { p.layers[i].frameBlending = b }
                        } }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                        if case .video = l.content {
                            Button { trackLauncher.active = true } label: {
                                Label("Track Motion", systemImage: "scope")
                                    .frame(maxWidth: .infinity).padding(.vertical, 10).glass(radius: 12).foregroundStyle(Theme.text)
                            }
                        }
                        CutoutSection(state: state)
                        Divider().overlay(Theme.stroke)
                        Text("Beat Sync").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                        if l.hasAudio {
                            HStack {
                                Text("Sensitivity").font(.system(size: 12)).foregroundStyle(Theme.textDim)
                                Slider(value: $sensitivity, in: 0...1)
                            }
                            Button { state.detectBeats(sensitivity: sensitivity) } label: {
                                Label("Detect Beats", systemImage: "waveform.badge.magnifyingglass")
                            }.buttonStyle(PrimaryButtonStyle())
                        }
                        HStack(spacing: 8) {
                            ToolTile(icon: "hand.tap", title: "Tap Beat") { state.tapMarker() }
                            ToolTile(icon: "bolt.fill", title: "Punch on Beats") { state.punchOnBeats() }
                            ToolTile(icon: "xmark.circle", title: "Clear Beats") { state.clearMarkers() }
                        }
                        Text("\(state.project.markers.count) beat markers").font(.caption).foregroundStyle(Theme.textDim)
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
        }
    }

    private func smoothSlowMo(_ factor: Int) {
        state.pause()
        slowMoProgress = 0; slowMoMessage = nil
        Task {
            do {
                try await state.applySmoothSlowMo(factor: factor) { p in Task { @MainActor in slowMoProgress = p } }
                slowMoMessage = "Done: the clip is now \(factor)x slower with smooth in-between frames."
            } catch {
                // No AI interpolation here (older device / simulator): fall back to AE-style frame blending.
                state.coalescedEdit("Frame Blending") { l in
                    var fx = l.timeFX ?? LayerTimeFX(); fx.frameBlend = true; l.timeFX = fx
                    l.speed = l.speed / Double(factor)
                    l.outPoint = l.inPoint + (l.outPoint - l.inPoint) * Double(factor)
                }
                slowMoMessage = "\(error.localizedDescription) Used frame blending instead."
            }
            slowMoProgress = nil
        }
    }

    private func mediaDuration(_ l: Layer) -> Double {
        switch l.content {
        case .video(let f, _, _, _): return VideoSources.shared.duration(state.mediaURL(f))
        case .audio(_, let d): return d
        default: return 1
        }
    }

    private func row(_ title: String, value: Double, range: ClosedRange<Double>, fmt: String, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
            ValueScrubber(value: value, range: range, unit: fmt.contains("%%") ? "%" : (fmt.hasSuffix("x") ? "×" : (fmt.hasSuffix("s") ? "s" : "")),
                          onBegin: { state.beginEdit(title) }, onChange: set, onEnd: { state.endEdit(); AudioPreview.shared.invalidate() })
        }
    }
}

/// Beat markers for any layer: auto-detect from the music, tap along, or punch the selected layer on every beat.
struct BeatsPanel: View {
    @ObservedObject var state: EditorState
    @State private var sensitivity = 0.5

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Beats", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    let hasMusic = state.project.layers.contains { $0.hasAudio }
                    if hasMusic {
                        HStack {
                            Text("Sensitivity").font(.system(size: 12)).foregroundStyle(Theme.textDim)
                            Slider(value: $sensitivity, in: 0...1).tint(Theme.accent)
                        }
                        Button { state.detectBeats(sensitivity: sensitivity) } label: {
                            Label("Detect Beats from Music", systemImage: "waveform.badge.magnifyingglass")
                        }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        Text("Add music or a video with sound to auto-detect beats — or tap the ◆ on the playhead while it plays.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                    }
                    HStack(spacing: 8) {
                        ToolTile(icon: "diamond", title: "Beat Here") { state.toggleBeatMarker() }
                        ToolTile(icon: "bolt.fill", title: "Punch on Beats") { state.punchOnBeats() }
                        ToolTile(icon: "xmark.circle", title: "Clear Beats") { state.clearMarkers() }
                    }
                    Text("\(state.project.markers.count) beat markers · scrubbing snaps to them").font(.caption).foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
    }
}
