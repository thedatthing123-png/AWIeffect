import SwiftUI

// MARK: - Clip editing model

/// Editable speed curve: relative speed weights at evenly spaced points across the clip. Applying it writes Time
/// Remap keys that keep the clip's first and last source frames (the curve only redistributes time).
enum SpeedCurve {
    struct Preset: Identifiable, Hashable { let name: String; let speeds: [Double]; var id: String { name } }
    static let presets: [Preset] = [
        Preset(name: "Constant", speeds: [1, 1, 1, 1, 1]),
        Preset(name: "Velocity", speeds: [2.5, 1.6, 0.25, 1.6, 2.5]),
        Preset(name: "Ramp Up", speeds: [0.3, 0.6, 1, 1.6, 2.2]),
        Preset(name: "Ramp Down", speeds: [2.2, 1.6, 1, 0.6, 0.3]),
        Preset(name: "Hero", speeds: [0.3, 1.4, 2.6, 1.4, 0.3]),
        Preset(name: "Flash Hit", speeds: [3, 3, 0.15, 0.5, 1.2]),
    ]
    static let minSpeed = 0.1, maxSpeed = 4.0

    /// Time Remap keys for `speeds` (≥ 2 weights) spread over `start…end`, mapping `sourceStart…sourceEnd`.
    /// Returns the keys and the real playback speed at each point.
    static func remap(speeds raw: [Double], start: Double, end: Double, sourceStart: Double, sourceEnd: Double) -> (Animated<Double>, [Double])? {
        let speeds = raw.map { max(minSpeed / 10, $0.isFinite ? $0 : 1) }
        guard speeds.count >= 2, end > start, sourceEnd.isFinite, sourceStart.isFinite else { return nil }
        let n = speeds.count
        let times = (0..<n).map { start + (end - start) * Double($0) / Double(n - 1) }
        var areas: [Double] = []
        for k in 0..<(n - 1) { areas.append((speeds[k] + speeds[k + 1]) * 0.5 * (times[k + 1] - times[k])) }
        let scale = (sourceEnd - sourceStart) / max(areas.reduce(0, +), 1e-9)
        var a = Animated(sourceStart), value = sourceStart
        for k in 0..<n {
            if k > 0 { value += areas[k - 1] * scale }
            a.insertKeyframe(Keyframe(time: times[k], value: k == n - 1 ? sourceEnd : value, interpolation: .bezier))
        }
        for k in 0..<(n - 1) {
            let dt = times[k + 1] - times[k], dv = a.keyframes[k + 1].value - a.keyframes[k].value
            if abs(dv) < 1e-9 { a.keyframes[k].interpolation = .hold; continue }
            // Handles set the slope at each key to that point's speed, so speed changes smoothly through the key.
            a.keyframes[k].easeOut = EaseHandle(x: 1.0 / 3, y: speeds[k] * scale * dt / (3 * dv))
            a.keyframes[k + 1].easeIn = EaseHandle(x: 2.0 / 3, y: 1 - speeds[k + 1] * scale * dt / (3 * dv))
        }
        return (a, speeds.map { $0 * scale })
    }
}

/// BPM grid (with subdivisions) used to place or quantize beat markers, which are what the editor snaps to.
enum BeatGrid {
    static func times(bpm: Double, offset: Double, subdivision: Int, duration: Double) -> [Double] {
        guard bpm.isFinite, bpm >= 20, duration > 0 else { return [] }
        let step = 60 / bpm / Double(max(1, subdivision))
        var first = offset.truncatingRemainder(dividingBy: step)
        if first < 0 { first += step }
        var out: [Double] = []
        var t = first
        while t <= duration + 1e-9 && out.count < 20_000 { out.append(t); t += step }
        return out
    }

    /// Each marker moved to its nearest grid line (duplicates merged).
    static func quantize(_ markers: [Double], bpm: Double, offset: Double, subdivision: Int) -> [Double] {
        guard bpm.isFinite, bpm >= 20 else { return markers }
        let step = 60 / bpm / Double(max(1, subdivision))
        let snapped = markers.map { max(0, offset + (($0 - offset) / step).rounded() * step) }
        var out: [Double] = []
        for t in snapped.sorted() where out.last.map({ abs($0 - t) > 1e-6 }) ?? true { out.append(t) }
        return out
    }
}

extension EditorState {
    private var clipBase: Project { live.project ?? project }

    /// Trim the clip's start: the in point moves with the source start, so the rest of the clip stays in place.
    func trimClipStart(toSource v: Double) {
        guard let i = selectedIndex, clipBase.layers.indices.contains(i) else { return }
        let l = clipBase.layers[i]
        guard l.timeRemap == nil, l.speed > 0 else { return }
        let fd = clipBase.frameDuration
        let newIn = min(l.outPoint - fd, max(l.inPoint - l.sourceStart / l.speed, l.inPoint + (v - l.sourceStart) / l.speed))
        let source = l.sourceStart + (newIn - l.inPoint) * l.speed
        mutateLayer { $0.inPoint = newIn; $0.sourceStart = max(0, source) }
    }

    /// Trim the clip's end to a source time (the in point and start frame stay put).
    func trimClipEnd(toSource v: Double) {
        guard let i = selectedIndex, clipBase.layers.indices.contains(i) else { return }
        let l = clipBase.layers[i]
        guard l.timeRemap == nil, l.speed > 0 else { return }
        let out = max(l.inPoint + clipBase.frameDuration, l.inPoint + (v - l.sourceStart) / l.speed)
        mutateLayer { $0.outPoint = out }
    }

    /// Slip: different source frames inside the same clip position and length.
    func slipClip(toSource v: Double) {
        mutateLayer { l in
            guard l.timeRemap == nil else { return }
            l.sourceStart = max(0, v)
        }
    }

    /// Freeze frame: the clip is cut at the playhead, the current frame holds for `hold` seconds, then the clip
    /// continues (pushed later by the hold). One undo step.
    func freezeFrame(hold: Double) {
        guard let i = selectedIndex, hold > 0, hold.isFinite else { return }
        let t = currentTime
        let l = project.layers[i]
        guard !l.isGroup, t > l.inPoint + project.frameDuration / 2, t < l.outPoint - project.frameDuration / 2 else { return }
        mutate("Freeze Frame") { p in
            var freeze = p.layers[i]
            freeze.id = UUID()
            freeze.name = l.name + " Freeze"
            freeze.inPoint = t
            freeze.outPoint = t + hold
            var fx = freeze.timeFX ?? LayerTimeFX()
            fx.freezeAt = t
            freeze.timeFX = fx
            var rest = p.layers[i]
            rest.id = UUID()
            if rest.timeRemap == nil { rest.sourceStart += (t - rest.inPoint) * rest.speed }
            rest.inPoint = t
            var visit = AnimationTraversal(operation: .shift(hold))
            rest.traverseAnimations(&visit)
            rest.inPoint += hold
            rest.outPoint += hold
            if var fx = rest.audioFX { fx.fadeIn = 0; rest.audioFX = fx }
            if var fx = freeze.audioFX { fx.fadeIn = 0; fx.fadeOut = 0; freeze.audioFX = fx }
            if var fx = p.layers[i].audioFX { fx.fadeOut = 0; p.layers[i].audioFX = fx }
            p.layers[i].outPoint = t
            p.layers.insert(rest, at: i)
            p.layers.insert(freeze, at: i + 1)
            selectedLayerID = freeze.id
        }
        AudioPreview.shared.invalidate()
    }

    /// Writes an editable speed curve as Time Remap keys (one undo step).
    func applySpeedCurve(_ speeds: [Double]) {
        guard let i = selectedIndex, project.layers[i].supportsSourceTiming else { return }
        let l = project.layers[i]
        guard l.outPoint - l.inPoint >= project.frameDuration * 3,
              let result = SpeedCurve.remap(speeds: speeds, start: l.inPoint, end: l.outPoint,
                                            sourceStart: l.sourceTime(at: l.inPoint), sourceEnd: l.sourceTime(at: l.outPoint)) else { return }
        mutate("Speed Curve") { $0.layers[i].timeRemap = result.0 }
        AudioPreview.shared.invalidate()
    }

    /// Continuous audio-effect edit on the selected layer (call between beginEdit / endEdit).
    func editAudioFX(_ change: (inout LayerAudioFX) -> Void) {
        mutateLayer { l in
            var fx = l.audioFX ?? LayerAudioFX()
            change(&fx)
            l.audioFX = fx.isNeutral ? nil : fx
        }
    }

    /// One-shot audio-effect change with its own undo step.
    func setAudioFX(_ label: String, _ change: (inout LayerAudioFX) -> Void) {
        guard let i = selectedIndex else { return }
        mutate(label) { p in
            var fx = p.layers[i].audioFX ?? LayerAudioFX()
            change(&fx)
            p.layers[i].audioFX = fx.isNeutral ? nil : fx
        }
        AudioPreview.shared.invalidate()
    }
}

// MARK: - Clip panel

/// Timing, speed curve, freeze, smooth slow-mo, fades, volume and sound for video/audio layers.
struct ClipPanel: View {
    @ObservedObject var state: EditorState
    @EnvironmentObject private var trackLauncher: TrackLauncher
    @State private var slowMoProgress: Double?
    @State private var slowMoMessage: String?
    @State private var twixtorFactor = 4.0
    @AppStorage("awi.freezeHold") private var freezeHold = 1.0

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Clip")
            if let l = state.selectedLayer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if l.supportsSourceTiming { TimeRemapEditor(state: state) }
                        timing(l)
                        if l.supportsSourceTiming && !l.isGroup { freeze(l) }
                        if case .video = l.content { twixtor(l) }
                        if l.hasAudio { sound(l) }
                        tools(l)
                        Divider().overlay(Theme.stroke)
                        Button { state.panel = .beats } label: {
                            Label("Beat Sync (\(state.project.markers.count) markers)", systemImage: "metronome")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered).foregroundStyle(Theme.text)
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }.scrollDisabled(state.remapDragging).accessibilityIdentifier("clip-settings-scroll")
            }
        }
    }

    // MARK: Sections

    @ViewBuilder private func timing(_ l: Layer) -> some View {
        sectionTitle("TIMING")
        if l.timeRemap == nil {
            row("Speed", value: abs(l.speed), range: 0.05...16, unit: "×") { state.setLayerSpeed($0) }
            if l.isMedia && l.speed > 0 {
                let media = mediaDuration(l)
                let clipSource = (l.outPoint - l.inPoint) * l.speed
                row("Trim Start", value: l.sourceStart, range: 0...max(0.01, l.sourceStart + (l.outPoint - l.inPoint - state.project.frameDuration) * l.speed),
                    unit: "s") { state.trimClipStart(toSource: $0) }
                row("Trim End", value: l.sourceTime(at: l.outPoint), range: (l.sourceStart + state.project.frameDuration * l.speed)...max(l.sourceStart + 0.02, media),
                    unit: "s") { state.trimClipEnd(toSource: $0) }
                row("Slip", value: l.sourceStart, range: 0...max(0.01, media - clipSource), unit: "s") { state.slipClip(toSource: $0) }
                Text("Trim moves a clip edge. Slip shows different footage inside the same clip position and length.")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
        }
        if l.hasAudio && l.timeRemap == nil {
            Toggle(isOn: Binding(get: { l.audioFX?.keepPitch ?? true }, set: { v in state.setAudioFX("Keep Pitch") { $0.keepPitch = v } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep Audio Pitch").font(.system(size: 13)).foregroundStyle(Theme.text)
                    Text("Off: slower sounds deeper, faster sounds higher (tape).").font(.caption2).foregroundStyle(Theme.textDim)
                }
            }
            .tint(Theme.accent).frame(minHeight: 44)
        }
    }

    @ViewBuilder private func freeze(_ l: Layer) -> some View {
        sectionTitle("FREEZE FRAME")
        row("Hold", value: freezeHold, range: 0.05...10, step: state.project.frameDuration, unit: "s", undo: false) { freezeHold = $0 }
        Button { state.freezeFrame(hold: freezeHold) } label: {
            Label("Freeze at Playhead", systemImage: "pause.rectangle").frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered).foregroundStyle(Theme.text)
        .disabled(!(state.currentTime > l.inPoint && state.currentTime < l.outPoint))
        Text("Holds the frame under the playhead for the chosen length; the rest of the clip continues after it.")
            .font(.caption).foregroundStyle(Theme.textDim)
    }

    @ViewBuilder private func twixtor(_ l: Layer) -> some View {
        sectionTitle("TWIXTOR · SMOOTH SLOW-MO")
        if let pr = slowMoProgress {
            ProgressView(value: pr).tint(Theme.accent)
            Text("Rendering smooth frames… \(Int(pr * 100))%").font(.caption).foregroundStyle(Theme.textDim)
        } else {
            row("Slower by", value: twixtorFactor, range: 2...8, step: 1, unit: "×", undo: false) { twixtorFactor = $0.rounded() }
            Button { smoothSlowMo(Int(twixtorFactor.rounded())) } label: {
                Label("Render \(Int(twixtorFactor.rounded()))× In-Between Frames", systemImage: "wand.and.stars").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered).foregroundStyle(Theme.text)
        }
        if let m = slowMoMessage { Text(m).font(.caption).foregroundStyle(Theme.textDim) }
        Toggle("Frame Blending", isOn: Binding(get: { l.usesFrameBlending }, set: { b in state.mutate("Frame Blending") { p in
            if let i = state.selectedIndex { p.layers[i].usesFrameBlending = b }
        } }))
        .tint(Theme.accent).foregroundStyle(Theme.text).frame(minHeight: 44)
        Text("Twixtor estimates new in-between frames. Frame Blending only cross-fades neighbouring frames (cheaper, can ghost).")
            .font(.caption).foregroundStyle(Theme.textDim)
    }

    @ViewBuilder private func sound(_ l: Layer) -> some View {
        sectionTitle("SOUND")
        if let file = l.mediaFile {
            ClipWaveformEditor(state: state, layer: l, url: state.mediaURL(file)).frame(height: 96)
        }
        let fx = l.audioFX ?? LayerAudioFX()
        let length = max(0.05, l.outPoint - l.inPoint)
        row("Fade In", value: fx.fadeIn, range: 0...length, unit: "s") { v in state.editAudioFX { $0.fadeIn = min(v, length - $0.fadeOut) } }
        row("Fade Out", value: fx.fadeOut, range: 0...length, unit: "s") { v in state.editAudioFX { $0.fadeOut = min(v, length - $0.fadeIn) } }
        HStack(spacing: 6) {
            ForEach(LayerAudioFX.FadeShape.allCases) { s in
                Button { state.setAudioFX("Fade Shape") { $0.fadeShape = s } } label: {
                    Text(s.title).font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(fx.fadeShape == s ? Theme.accent : Theme.raised))
                        .foregroundStyle(fx.fadeShape == s ? Color.white : Theme.text)
                }.buttonStyle(.plain)
            }
        }
        HStack(spacing: 4) {
            Text("Volume").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
            ValueScrubber(value: l.volume.value(at: state.currentTime), range: 0...200, unit: "%",
                          onBegin: { state.beginEdit("Volume") },
                          onChange: { v in let t = state.currentTime; state.mutateLayer { $0.volume.set(v, at: t) } },
                          onEnd: { state.endEdit(); AudioPreview.shared.invalidate() })
            KeyframeDiamond(filled: l.volume.hasKeyframe(at: state.currentTime), animated: l.volume.isAnimated) {
                let t = state.currentTime
                state.mutate("Keyframe Volume") { p in if let i = state.selectedIndex { p.layers[i].volume.toggleKeyframe(at: t) } }
                AudioPreview.shared.invalidate()
            }
            .frame(width: 44, height: 44)
        }
        AudioFXSection(state: state, layer: l)
    }

    @ViewBuilder private func tools(_ l: Layer) -> some View {
        sectionTitle("TOOLS")
        HStack(spacing: 8) {
            ToolTile(icon: "backward.end.alt", title: "Reverse Clip") { state.reversePlayback() }
                .disabled(!l.supportsSourceTiming)
            ToolTile(icon: "arrow.left.arrow.right", title: "Reverse Keys") {
                state.mutate("Reverse Animation") { p in
                    guard let i = state.selectedIndex else { return }
                    let remap = p.layers[i].timeRemap
                    var visit = AnimationTraversal(operation: .reverse(l.inPoint + l.outPoint))
                    p.layers[i].traverseAnimations(&visit)
                    p.layers[i].timeRemap = remap
                }
            }
            ToolTile(icon: "scissors", title: "Split") { state.splitSelected() }
        }
        Text("Reverse Clip plays the footage backwards. Reverse Keys flips every keyed property around the clip's start and end.")
            .font(.caption).foregroundStyle(Theme.textDim)
    }

    // MARK: Helpers

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim).padding(.top, 4)
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

    /// Label + scrubber (drag or tap to type). `undo: false` for panel-only settings.
    private func row(_ title: String, value: Double, range: ClosedRange<Double>, step: Double = 0, unit: String,
                     undo: Bool = true, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
            ValueScrubber(value: value, range: range, step: step, unit: unit,
                          onBegin: { if undo { state.beginEdit(title) } }, onChange: set,
                          onEnd: { if undo { state.endEdit(); AudioPreview.shared.invalidate() } })
        }
        .frame(minHeight: 44)
    }
}

/// The clip's sound: waveform, the resulting volume line (keys × fades) and fade handles at the top corners.
struct ClipWaveformEditor: View {
    @ObservedObject var state: EditorState
    let layer: Layer
    let url: URL
    @State private var peaks: [Float] = []
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let fx = layer.audioFX ?? LayerAudioFX()
            let length = max(0.05, layer.outPoint - layer.inPoint)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Theme.surface)
                Canvas { ctx, size in
                    var bars = Path()
                    var line = Path()
                    var x: CGFloat = 0
                    while x < size.width {
                        let t = layer.inPoint + Double(x / max(size.width, 1)) * length
                        let src = layer.sourceTime(at: t)
                        let i = Int(src * 50)
                        let gain = max(0, layer.volume.value(at: t)) / 100 * fx.fadeGain(at: t, inPoint: layer.inPoint, outPoint: layer.outPoint)
                        if i >= 0, i < peaks.count {
                            let bh = CGFloat(peaks[i]) * size.height * 0.85 * CGFloat(min(2, gain))
                            bars.addRect(CGRect(x: x, y: (size.height - bh) / 2, width: 1.5, height: max(1, bh)))
                        }
                        let ly = size.height - CGFloat(min(2, gain) / 2) * size.height
                        if x == 0 { line.move(to: CGPoint(x: x, y: ly)) } else { line.addLine(to: CGPoint(x: x, y: ly)) }
                        x += 2
                    }
                    ctx.fill(bars, with: .color(Theme.accentGlow.opacity(0.55)))
                    ctx.stroke(line, with: .color(Theme.warning), lineWidth: 1.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                handle(x: CGFloat(fx.fadeIn / length) * w, w: w, length: length, isIn: true)
                handle(x: w - CGFloat(fx.fadeOut / length) * w, w: w, length: length, isIn: false)
            }
            .frame(width: w, height: h)
            .coordinateSpace(name: "clipWave")
        }
        .task(id: url) {
            let u = url
            peaks = await Task.detached(priority: .utility) { AudioAnalysis.peaks(url: u) }.value
        }
        .accessibilityLabel("Clip waveform with fade handles")
    }

    private func handle(x: CGFloat, w: CGFloat, length: Double, isIn: Bool) -> some View {
        Image(systemName: isIn ? "arrowtriangle.right.fill" : "arrowtriangle.left.fill")
            .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.warning)
            .frame(width: 44, height: 44).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("clipWave"))
                .onChanged { g in
                    if !dragging { dragging = true; state.beginEdit(isIn ? "Fade In" : "Fade Out") }
                    let frac = Double(min(w, max(0, g.location.x)) / max(w, 1))
                    state.editAudioFX { fx in
                        if isIn { fx.fadeIn = min(length - fx.fadeOut, frac * length) }
                        else { fx.fadeOut = min(length - fx.fadeIn, (1 - frac) * length) }
                    }
                }
                .onEnded { _ in dragging = false; state.endEdit(); AudioPreview.shared.invalidate() })
            .position(x: min(w - 22, max(22, x)), y: 22)
            .accessibilityLabel(isIn ? "Fade in handle" : "Fade out handle")
    }
}

// MARK: - Beats

/// Beat markers for any layer: detect from the music, tap along, BPM grid, edit single markers, punch on beats.
struct BeatsPanel: View {
    @ObservedObject var state: EditorState
    @State private var sensitivity = 0.5
    @AppStorage("awi.punchStrength") private var punchStrength = 12.0
    @AppStorage("awi.punchDecay") private var punchDecay = 0.18
    @State private var automaticTempo = true
    @State private var tempo = 120.0
    @AppStorage("awi.gridBPM") private var gridBPM = 120.0
    @AppStorage("awi.gridOffset") private var gridOffset = 0.0
    @AppStorage("awi.gridSubdivision") private var gridSubdivision = 1

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Beats", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    BeatMarkerStrip(state: state).frame(height: 64)
                    Text("Drag a marker to move it, tap one to select it. \(state.project.markers.count) markers · scrubbing and clip edges snap to them.")
                        .font(.caption).foregroundStyle(Theme.textDim)
                    let hasMusic = state.project.layers.contains { $0.hasAudio }
                    sectionTitle("DETECT")
                    if hasMusic {
                        HStack {
                            Text("Sensitivity").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
                            ValueScrubber(value: sensitivity * 100, range: 0...100, unit: "%", onChange: { sensitivity = $0 / 100 })
                        }.frame(minHeight: 44)
                        Toggle("Estimate tempo automatically", isOn: $automaticTempo).font(.system(size: 13)).tint(Theme.accent).frame(minHeight: 44)
                        if !automaticTempo {
                            HStack {
                                Text("Tempo").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
                                ValueScrubber(value: tempo, range: 30...300, step: 1, unit: " BPM", onChange: { tempo = $0 })
                            }.frame(minHeight: 44)
                        }
                        if state.isDetectingBeats {
                            HStack { ProgressView(); Button("Cancel Analysis") { state.cancelBeatDetection() }.frame(minHeight: 44) }
                        } else {
                            Button { state.detectBeats(sensitivity: sensitivity, bpm: automaticTempo ? nil : tempo) } label: {
                                Label("Detect Beats from Music", systemImage: "waveform.badge.magnifyingglass")
                            }.buttonStyle(PrimaryButtonStyle())
                        }
                        if let status = state.beatStatus { Text(status).font(.caption).foregroundStyle(Theme.textDim) }
                    } else {
                        Text("Add music or a video with sound to auto-detect beats — or tap Beat Here while it plays.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                    }
                    sectionTitle("BPM GRID")
                    HStack {
                        Text("BPM").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
                        ValueScrubber(value: gridBPM, range: 40...300, step: 0.5, unit: "", onChange: { gridBPM = $0 })
                    }.frame(minHeight: 44)
                    HStack {
                        Text("First Beat").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
                        ValueScrubber(value: gridOffset, range: 0...max(1, 60 / max(gridBPM, 1)), step: state.project.frameDuration / 4, unit: "s",
                                      onChange: { gridOffset = $0 })
                    }.frame(minHeight: 44)
                    HStack(spacing: 6) {
                        ForEach([1, 2, 4], id: \.self) { d in
                            Button { gridSubdivision = d } label: {
                                Text(d == 1 ? "Beats" : "1/\(d * 4) notes").font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Capsule().fill(gridSubdivision == d ? Theme.accent : Theme.raised))
                                    .foregroundStyle(gridSubdivision == d ? Color.white : Theme.text)
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 8) {
                        ToolTile(icon: "square.grid.3x1.below.line.grid.1x2", title: "Fill Grid") {
                            let times = BeatGrid.times(bpm: gridBPM, offset: gridOffset, subdivision: gridSubdivision, duration: state.project.duration)
                            state.mutate("BPM Grid") { $0.markers = times }
                        }
                        ToolTile(icon: "arrow.right.to.line", title: "Snap to Grid") {
                            let q = BeatGrid.quantize(state.project.markers, bpm: gridBPM, offset: gridOffset, subdivision: gridSubdivision)
                            state.mutate("Quantize Beats") { $0.markers = q }
                        }
                        ToolTile(icon: "scope", title: "First = Playhead") { gridOffset = state.currentTime }
                    }
                    sectionTitle("MARKERS")
                    HStack(spacing: 8) {
                        ToolTile(icon: "diamond", title: "Beat Here") { state.toggleBeatMarker() }
                        ToolTile(icon: "bolt.fill", title: "Punch on Beats") { state.punchOnBeats(scaleAmount: punchStrength, decay: punchDecay) }
                        ToolTile(icon: "xmark.circle", title: "Clear Beats") { state.clearMarkers() }
                    }
                    HStack {
                        Text("Punch").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
                        ValueScrubber(value: punchStrength, range: 1...100, unit: "%", onChange: { punchStrength = $0 })
                    }.frame(minHeight: 44)
                    HStack {
                        Text("Decay").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
                        ValueScrubber(value: punchDecay, range: 0.03...1, step: 0.01, unit: "s", onChange: { punchDecay = $0 })
                    }.frame(minHeight: 44)
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim).padding(.top, 4)
    }
}

/// An 8-second window of beat markers around the playhead: tap empty space to seek, drag a marker to move it,
/// tap a marker to select it and delete it. One undo step per drag.
struct BeatMarkerStrip: View {
    @ObservedObject var state: EditorState
    @State private var selected: Double?
    @State private var dragValue: Double?
    static let span = 8.0

    var body: some View {
        let duration = max(state.project.duration, 0.1)
        let start = min(max(0, state.currentTime - Self.span / 2), max(0, duration - Self.span))
        let span = min(Self.span, duration)
        HStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let toX = { (t: Double) -> CGFloat in CGFloat((t - start) / span) * w }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.surface)
                        .contentShape(Rectangle())
                        .onTapGesture { location in selected = nil; state.seek(min(duration, max(0, start + Double(location.x / max(w, 1)) * span))) }
                    Rectangle().fill(Theme.text).frame(width: 1.5, height: geo.size.height).position(x: toX(state.currentTime), y: geo.size.height / 2)
                    // Indexed (not keyed by time) so a marker keeps its gesture while its time changes.
                    ForEach(state.project.markers.indices, id: \.self) { idx in
                        let m = state.project.markers[idx]
                        if m >= start - 0.01 && m <= start + span + 0.01 {
                        let isSel = selected.map { abs($0 - m) < 1e-6 } ?? false
                        Image(systemName: isSel ? "diamond.fill" : "diamond")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(isSel ? Theme.warning : Theme.keyframe)
                            .frame(width: 28, height: 44).contentShape(Rectangle())
                            .onTapGesture { selected = m }
                            .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("beatStrip"))
                                .onChanged { g in
                                    let from = dragValue ?? m
                                    if dragValue == nil { state.beginEdit("Move Beat") }
                                    let to = state.project.snapToFrame(min(duration, max(0, start + Double(g.location.x / max(w, 1)) * span)))
                                    guard abs(to - from) > 1e-6 else { return }
                                    state.mutate("Move Beat") { p in p.markers = p.markers.filter { abs($0 - from) > 1e-6 } + [to] }
                                    dragValue = to; selected = to
                                }
                                .onEnded { _ in dragValue = nil; state.endEdit() })
                            .position(x: toX(m), y: geo.size.height / 2)
                        }
                    }
                }
                .coordinateSpace(name: "beatStrip")
            }
            Button {
                guard let s = selected else { return }
                state.mutate("Delete Beat") { p in p.markers = p.markers.filter { abs($0 - s) > 1e-6 } }
                selected = nil
            } label: {
                Image(systemName: "trash").font(.system(size: 16, weight: .semibold)).frame(width: 44, height: 44)
                    .foregroundStyle(selected == nil ? Theme.textDim : Theme.danger)
            }
            .disabled(selected == nil)
            .accessibilityLabel("Delete selected beat marker")
        }
    }
}
