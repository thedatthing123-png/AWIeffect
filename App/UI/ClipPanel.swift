import SwiftUI

/// Speed, trim, time remap, volume and beat tools for video/audio layers.
struct ClipPanel: View {
    @ObservedObject var state: EditorState
    @EnvironmentObject private var trackLauncher: TrackLauncher
    @State private var showTiming = false
    @State private var slowMoProgress: Double?
    @State private var slowMoMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Clip")
            if let l = state.selectedLayer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if l.timeRemap == nil {
                            row("Speed", value: abs(l.speed), range: 0.05...16, fmt: "%.2fx") { v in
                                state.setLayerSpeed(v)
                            }
                        } else {
                            HStack {
                                Label("Time Remap is on", systemImage: "timer").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ok)
                                Spacer()
                                Button("Turn Off", role: .destructive) { state.disableTimeRemap() }
                            }
                        }
                        HStack {
                            Button("Reverse Playback") { state.reversePlayback() }.disabled(!l.supportsSourceTiming)
                            Button("Reverse Animation") {
                                state.mutate("Reverse Animation") { p in
                                    guard let i = state.selectedIndex else { return }
                                    let remap = p.layers[i].timeRemap
                                    var visit = AnimationTraversal(operation: .reverse(l.inPoint + l.outPoint))
                                    p.layers[i].traverseAnimations(&visit)
                                    p.layers[i].timeRemap = remap
                                }
                            }
                        }.font(.caption).buttonStyle(.bordered)
                        Text("Reverse Animation flips all keyed properties, including position, around this layer’s start and end. Use either control again to reverse it back.").font(.caption).foregroundStyle(Theme.textDim)
                        if case .video = l.content {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TWIXTOR · SMOOTH SLOW-MO (AI in-between frames)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
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
                            if l.supportsSourceTiming { ToolTile(icon: "speedometer", title: "Velocity Ramp") { showTiming = true } }
                            if l.hasAudio {
                                ToolTile(icon: "speaker.wave.1", title: "Fade In") { state.audioFade(in: true) }
                                ToolTile(icon: "speaker.slash", title: "Fade Out") { state.audioFade(in: false) }
                            }
                            if l.supportsSourceTiming { ToolTile(icon: "timer", title: "Time Remap") { state.enableTimeRemap(); showTiming = true } }
                            ToolTile(icon: "scissors", title: "Split") { state.splitSelected() }
                        }
                        if l.timeRemap != nil {
                            Text("Time Remap keyframes are on the timeline; edit their easing in the Graph Editor for smooth velocity edits.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                        }
                        Toggle("Frame Blending", isOn: Binding(get: { l.usesFrameBlending }, set: { b in state.mutate("Frame Blending") { p in
                            if let i = state.selectedIndex { p.layers[i].usesFrameBlending = b }
                        } }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                        Text("Frame Blending mixes neighboring footage frames at fractional times. It can soften slow motion but may produce ghosting; it does not estimate new motion.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                        CutoutSection(state: state)
                        Divider().overlay(Theme.stroke)
                        // Beat Sync lives in one place: the Beats panel (detect, tap, punch with strength / decay).
                        Button { state.panel = .beats } label: {
                            Label("Beat Sync (\(state.project.markers.count) markers)", systemImage: "metronome")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered).foregroundStyle(Theme.text)
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }.accessibilityIdentifier("clip-settings-scroll")
            }
        }
        .awiSheet(isPresented: $showTiming) { TimeRemapEditor(state: state) }
    }

    private func smoothSlowMo(_ factor: Int) {
        guard let original = state.selectedLayer else { return }
        let rootID = state.rootProject.id, scopeID = state.project.id
        state.pause()
        slowMoProgress = 0; slowMoMessage = nil
        Task {
            do {
                try await state.applySmoothSlowMo(factor: factor) { p in Task { @MainActor in slowMoProgress = p } }
                slowMoMessage = "Done: the clip is now \(factor)x slower with smooth in-between frames."
            } catch SlowMotion.Failure.unsupported {
                guard state.rootProject.id == rootID, state.project.id == scopeID, state.selectedLayer == original else {
                    slowMoMessage = "Cancelled: the editing context changed."; slowMoProgress = nil; return
                }
                state.coalescedEdit("Frame Blending") { l in
                    l.usesFrameBlending = true
                    var visit = AnimationTraversal(operation: .scaleTime(l.inPoint, Double(factor)))
                    l.traverseAnimations(&visit)
                    l.speed = l.speed / Double(factor)
                    l.outPoint = l.inPoint + (l.outPoint - l.inPoint) * Double(factor)
                }
                AudioPreview.shared.invalidate()
                slowMoMessage = "Motion interpolation is unavailable here. Used frame blending instead."
            } catch {
                slowMoMessage = error.localizedDescription
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
    @AppStorage("awi.punchStrength") private var punchStrength = 12.0
    @AppStorage("awi.punchDecay") private var punchDecay = 0.18
    @State private var automaticTempo = true
    @State private var tempo = 120.0

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
                        Toggle("Estimate tempo automatically", isOn: $automaticTempo).font(.footnote).tint(Theme.accent)
                        if !automaticTempo {
                            NumberField(value: tempo, label: "BPM") { tempo = min(300, max(30, $0)) }
                        }
                        if state.isDetectingBeats {
                            HStack { ProgressView(); Button("Cancel Analysis") { state.cancelBeatDetection() } }
                        } else {
                            Button { state.detectBeats(sensitivity: sensitivity, bpm: automaticTempo ? nil : tempo) } label: {
                                Label("Detect Beats from Music", systemImage: "waveform.badge.magnifyingglass")
                            }.buttonStyle(PrimaryButtonStyle())
                        }
                        if let status = state.beatStatus { Text(status).font(.caption).foregroundStyle(Theme.textDim) }
                    } else {
                        Text("Add music or a video with sound to auto-detect beats — or tap the ◆ on the playhead while it plays.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                    }
                    HStack(spacing: 8) {
                        ToolTile(icon: "diamond", title: "Beat Here") { state.toggleBeatMarker() }
                        ToolTile(icon: "bolt.fill", title: "Punch on Beats") { state.punchOnBeats(scaleAmount: punchStrength, decay: punchDecay) }
                        ToolTile(icon: "xmark.circle", title: "Clear Beats") { state.clearMarkers() }
                    }
                    // Punch adds on top of the layer's own scale animation.
                    HStack {
                        Text("Punch").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 64, alignment: .leading)
                        ValueScrubber(value: punchStrength, range: 1...100, unit: "%", onChange: { punchStrength = $0 })
                    }
                    HStack {
                        Text("Decay").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 64, alignment: .leading)
                        ValueScrubber(value: punchDecay, range: 0.03...1, step: 0.01, unit: "s", onChange: { punchDecay = $0 })
                    }
                    Text("\(state.project.markers.count) beat markers · scrubbing snaps to them").font(.caption).foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
    }
}
