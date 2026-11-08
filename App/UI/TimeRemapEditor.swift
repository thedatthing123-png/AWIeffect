import SwiftUI

extension EditorState {
    var remapSegments: [EaseSegment] {
        guard let a = selectedLayer?.timeRemap, a.keyframes.count >= 2 else { return [] }
        return (0..<(a.keyframes.count - 1)).map { k in
            EaseSegment(t0: a.keyframes[k].time, t1: a.keyframes[k + 1].time,
                        interpolation: a.keyframes[k].interpolation, out: a.keyframes[k].easeOut,
                        into: a.keyframes[k + 1].easeIn, curve: a.keyframes[k].curve,
                        reversedSegment: a.keyframes[k].reversedSegment)
        }
    }

    func setRemapEase(segment: Int?, ease: SavedEase, continuous: Bool = false) {
        guard let i = selectedIndex, var a = project.layers[i].timeRemap, a.keyframes.count >= 2 else { return }
        if continuous { beginEdit("Remap Easing") }
        for k in segment.map({ [$0] }) ?? Array(0..<(a.keyframes.count - 1)) where k >= 0 && k + 1 < a.keyframes.count {
            a.keyframes[k].interpolation = ease.interpolation
            a.keyframes[k].easeOut = ease.out
            a.keyframes[k + 1].easeIn = ease.into
            a.keyframes[k].curve = ease.curve
            a.keyframes[k].reversedSegment = ease.reversedSegment
        }
        mutate("Remap Easing") { $0.layers[i].timeRemap = a }
        AudioPreview.shared.invalidate()
    }
}

/// One inline editor, one source-time track. Source and speed graphs are views of the same editable keys.
struct TimeRemapEditor: View {
    @ObservedObject var state: EditorState
    @State private var speedGraph = true
    @State private var selected: UUID?
    @State private var original: Animated<Double>?
    @State private var dragRange: ClosedRange<Double>?
    @GestureState private var draggingKey = false
    @State private var showEase = false
    @State private var slow = 0.25
    @State private var fast = 1.6
    @State private var window = 0.4

    var body: some View {
        if let layer = state.selectedLayer, layer.supportsSourceTiming {
            let remap = layer.timeRemap ?? baseMap(layer)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Speed Remap").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                    Spacer()
                    if layer.timeRemap != nil {
                        Button("Turn Off", role: .destructive) { state.disableTimeRemap(); selected = nil }.frame(minHeight: 44)
                    } else {
                        Button("Time Remap") { state.enableTimeRemap() }.frame(minHeight: 44)
                    }
                }
                presetButtons
                Picker("Graph", selection: $speedGraph) {
                    Text("Source Time").tag(false); Text("Playback Speed").tag(true)
                }.pickerStyle(.segmented).frame(minHeight: 44)
                plot(layer, remap: remap).frame(height: 180)
                Text(speedGraph ? "Speed in ×. Drag a key up/down for speed and sideways for timing; smooth both sides with segment easing."
                     : "Source time in seconds. Drag a key to choose its timing and source frame.")
                    .font(.caption).foregroundStyle(Theme.textDim)
                keyControls(layer, remap: remap)
                rampControls
            }.foregroundStyle(Theme.text).tint(Theme.accent)
            .awiSheet(isPresented: $showEase) { FlowGraphPanel(state: state, remapPopup: true).presentationDetents([.medium, .large]) }
            .onDisappear { original = nil; dragRange = nil; state.remapDragging = false; state.endEdit() }
            .onChange(of: draggingKey) { _, dragging in
                // SwiftUI may cancel a key gesture when its live value changes the plot.
                // GestureState resets on cancellation as well as a normal finger release.
                if !dragging {
                    original = nil; dragRange = nil; state.remapDragging = false; state.endEdit()
                }
            }
        }
    }
    private var presetButtons: some View {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SpeedCurve.presets) { preset in
                            Button(preset.name) { state.applySpeedCurve(preset.speeds); selected = nil }
                                .buttonStyle(.bordered).frame(minHeight: 44)
                        }
                    }
                }
    }
    private func keyControls(_ layer: Layer, remap: Animated<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Button { selected = state.addSourceTimeKey() } label: { Label("Add Key", systemImage: "plus.diamond").frame(maxWidth: .infinity, minHeight: 44) }
                        .accessibilityLabel("Add source time keyframe")
                    Button { removeKey() } label: { Label("Remove", systemImage: "minus.diamond").frame(maxWidth: .infinity, minHeight: 44) }
                        .disabled(selectedKey(remap) == nil || layer.timeRemap == nil).accessibilityLabel("Remove source time keyframe")
                    Button { state.graphTimeRemap = true; state.graphEffect = nil; showEase = true } label: {
                        Label("Easing", systemImage: "point.topleft.down.to.point.bottomright.curvepath").frame(maxWidth: .infinity, minHeight: 44)
                    }.disabled(remap.keyframes.count < 2 || layer.timeRemap == nil).accessibilityLabel("Edit Segment Easing")
                }.font(.system(size: 11, weight: .semibold)).buttonStyle(.bordered)
                HStack(spacing: 6) {
                    NumberField(value: state.currentTime, label: "Key time", step: state.project.frameDuration, precision: 3) { time in
                        if let key = selectedKey(remap) { nudge(key, in: layer, delta: time - key.time) } else { state.seek(time) }
                    }
                    NumberField(value: layer.sourceTime(at: state.currentTime), label: "Source seconds", step: state.project.frameDuration, precision: 3,
                                onDragBegin: { state.beginEdit("Source Time") }, onDragEnd: { state.endEdit() }) { value in
                        if state.selectedLayer?.timeRemap == nil { state.enableTimeRemap() }
                        state.setRemapValue(value)
                    }
                }.frame(minHeight: 44)
                HStack {
                    Text("Speed").font(.caption)
                    ValueScrubber(value: layer.playbackRate(at: state.currentTime), range: -16...16, step: 0.05, unit: "×",
                                  onBegin: { state.beginEdit("Remap Speed") }, onChange: { rate in state.setSourceKeyRate(rate) }, onEnd: { state.endEdit() }, allowBeyond: true)
                }.frame(minHeight: 44)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(layer.timeRemap?.keyframes ?? []) { key in
                            Button { selected = key.id; state.seek(key.time) } label: {
                                Text(String(format: "%.3fs → %.3fs", key.time, key.value)).font(.caption.monospacedDigit()).frame(minHeight: 44)
                            }.buttonStyle(.bordered).tint(selected == key.id ? Theme.keyframe : Theme.accent)
                        }
                    }
                }
                if let key = selectedKey(remap) {
                    HStack {
                        Button("−1 frame") { nudge(key, in: layer, delta: -state.project.frameDuration) }.frame(maxWidth: .infinity, minHeight: 44)
                        Button("+1 frame") { nudge(key, in: layer, delta: state.project.frameDuration) }.frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.bordered)
                }
        }
    }
    private var rampControls: some View {
        VStack(alignment: .leading, spacing: 8) {
                Text("Ramp Shape").font(.caption.bold()).foregroundStyle(Theme.textDim)
                HStack(spacing: 6) {
                    NumberField(value: slow, label: "Slow", step: 0.01, precision: 2) { slow = min(16, max(0.01, $0)) }
                    NumberField(value: fast, label: "Fast", step: 0.01, precision: 2) { fast = min(16, max(0.01, $0)) }
                    NumberField(value: window, label: "Window", step: state.project.frameDuration, precision: 2) { window = min(30,max(0.02,$0)) }
                }.frame(minHeight: 44)
                Button("Apply Ramp at Playhead") { state.applySpeedRamp(slow: slow, fast: fast, window: window) }
                    .buttonStyle(.bordered).frame(minHeight: 44)
        }
    }
    private func selectedKey(_ a: Animated<Double>) -> Keyframe<Double>? {
        a.keyframes.first { $0.id == selected } ?? a.keyframes.first { abs($0.time - state.currentTime) < keyframeTimeEpsilon }
    }
    private func removeKey() {
        guard var a = state.selectedLayer?.timeRemap, let key = selectedKey(a) else { return }
        a.keyframes.removeAll { $0.id == key.id }
        state.mutate("Remove Remap Key") { p in if let i = state.selectedIndex { p.layers[i].timeRemap = a.keyframes.isEmpty ? nil : a } }
        selected = nil; AudioPreview.shared.invalidate()
    }
    private func baseMap(_ l: Layer) -> Animated<Double> {
        var a = Animated(l.sourceTime(at: l.inPoint))
        a.insertKeyframe(Keyframe(time: l.inPoint, value: l.sourceTime(at: l.inPoint)))
        a.insertKeyframe(Keyframe(time: l.outPoint, value: l.sourceTime(at: l.outPoint)))
        return a
    }
    private func layerWithRemap(_ l: Layer, _ a: Animated<Double>) -> Layer { var l = l; l.timeRemap = a; return l }
    private func nudge(_ key: Keyframe<Double>, in layer: Layer, delta: Double) {
        guard var a = layer.timeRemap, let index = a.keyframes.firstIndex(where: { $0.id == key.id }) else { return }
        let t = state.project.snapToFrame(key.time + delta)
        guard t >= layer.inPoint, t <= layer.outPoint, !a.keyframes.contains(where: { $0.id != key.id && abs($0.time - t) < keyframeTimeEpsilon }) else { return }
        a.keyframes[index].time = t; a.keyframes.sort { $0.time < $1.time }
        state.coalescedEdit("Move Remap Key") { $0.timeRemap = a }; state.seek(t); AudioPreview.shared.invalidate()
    }

    private func plot(_ layer: Layer, remap: Animated<Double>) -> some View {
        GeometryReader { geo in
            let box = CGRect(x: 24, y: 22, width: max(1, geo.size.width - 48), height: max(1, geo.size.height - 48))
            let duration = max(state.project.frameDuration, layer.outPoint - layer.inPoint)
            let values = (0...160).map { i in
                let t = layer.inPoint + duration * Double(i) / 160
                return speedGraph ? layer.playbackRate(at: t) : remap.value(at: t)
            }
            let lower = dragRange?.lowerBound ?? min(0, values.min() ?? 0)
            let upper = dragRange?.upperBound ?? max(lower + 0.1, values.max() ?? 1)
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.surface)
                Canvas { ctx, _ in
                    var grid = Path()
                    for i in 0...4 {
                        let y = box.minY + box.height * CGFloat(i) / 4
                        grid.move(to: CGPoint(x: box.minX, y: y)); grid.addLine(to: CGPoint(x: box.maxX, y: y))
                    }
                    ctx.stroke(grid, with: .color(Theme.stroke), lineWidth: 1)
                    var path = Path()
                    for (i, value) in values.enumerated() {
                        let point = CGPoint(x: box.minX + box.width * CGFloat(i) / 160,
                                            y: box.maxY - box.height * CGFloat((value - lower) / (upper - lower)))
                        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    ctx.stroke(path, with: .color(Theme.accentGlow), lineWidth: 2)
                }
                    ForEach(remap.keyframes) { key in
                        Button { selected = key.id; state.seek(key.time) } label: {
                            Circle().fill(selected == key.id ? Theme.keyframe : .white)
                                .frame(width: 12, height: 12).frame(width: 44, height: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(String(format: "Source key at %.3f seconds", key.time))
                            .position(x: box.minX + CGFloat((key.time - layer.inPoint) / duration) * box.width,
                                      y: box.maxY - CGFloat(((speedGraph ? layer.playbackRate(at: key.time) : key.value) - lower) / (upper - lower)) * box.height)
                            .highPriorityGesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("remapPlot"))
                                .updating($draggingKey) { _, active, _ in active = true }
                                .onChanged { drag in
                                    if original == nil { original = remap; dragRange = lower...upper; selected = key.id; state.pause(); state.beginEdit("Move Remap Key"); state.remapDragging = true }
                                    guard var a = original, let k = a.keyframes.firstIndex(where: { $0.id == key.id }) else { return }
                                    let base = a.keyframes[k]
                                    let first = k > 0 ? a.keyframes[k - 1].time + state.project.frameDuration : layer.inPoint
                                    let last = k + 1 < a.keyframes.count ? a.keyframes[k + 1].time - state.project.frameDuration : layer.outPoint
                                    guard first <= last else { return }
                                    a.keyframes[k].time = min(last, max(first, state.project.snapToFrame(base.time + Double(drag.translation.width / box.width) * duration)))
                                    if speedGraph {
                                        let rate = layerWithRemap(layer, original!).playbackRate(at: base.time) - Double(drag.translation.height / box.height) * (upper - lower)
                                        a = RemapSpeedEditing.settingRate(rate, at: k, in: a)
                                    } else {
                                        a.keyframes[k].value = max(0, base.value - Double(drag.translation.height / box.height) * (upper - lower))
                                    }
                                    state.mutateLayer { $0.timeRemap = a }
                                }.onEnded { _ in
                                    original = nil; dragRange = nil; state.remapDragging = false; state.endEdit()
                                    if let selected, let key = state.selectedLayer?.timeRemap?.keyframes.first(where: { $0.id == selected }) { state.seek(key.time) }
                                    AudioPreview.shared.invalidate()
                                })
                    }
                VStack { HStack { Text(String(format: "%.2f", upper) + (speedGraph ? "×" : "s")); Spacer() }; Spacer()
                    HStack { Text(String(format: "%.2f", lower)); Spacer(); Text(String(format: "%.2fs", layer.outPoint)) }
                }.font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.textDim).padding(5).allowsHitTesting(false)
            }.coordinateSpace(name: "remapPlot")
        }
    }
}
