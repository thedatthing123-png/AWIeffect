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

/// Source time is the value; its signed derivative is playback speed. Uses the same remap as audio/export.
struct TimeRemapEditor: View {
    @ObservedObject var state: EditorState
    @Environment(\.dismiss) private var dismiss
    @State private var speedGraph = false
    @State private var selected: UUID?
    @State private var original: Animated<Double>?
    @State private var dragRange: ClosedRange<Double>?
    @State private var slow = 0.25
    @State private var fast = 1.6
    @State private var window = 0.4

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let layer = state.selectedLayer, layer.supportsSourceTiming {
                        if let remap = layer.timeRemap {
                            plot(layer, remap: remap).frame(height: 220)
                            Text(speedGraph ? "Speed in ×: positive plays forward, zero holds, negative reverses. Change easing to shape speed between keys."
                                 : "Horizontal = composition time; vertical = source time in seconds. Drag a key to change its timing and source frame.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                            HStack {
                                Button { state.toggleRemapKey() } label: {
                                    Image(systemName: remap.hasKeyframe(at: state.currentTime) ? "diamond.fill" : "diamond")
                                }.accessibilityLabel("Toggle source time keyframe")
                                NumberField(value: layer.sourceTime(at: state.currentTime), label: "Source seconds", step: state.project.frameDuration, precision: 3) { state.setRemapValue($0) }
                                Text(String(format: "%+.2f×", layer.playbackRate(at: state.currentTime))).monospacedDigit()
                            }
                            ForEach(remap.keyframes) { key in
                                HStack {
                                    Button { selected = key.id; state.seek(key.time) } label: {
                                        Text(String(format: "%.3fs → %.3fs", key.time, key.value)).monospacedDigit()
                                    }
                                    Spacer()
                                    Button("−1f") { nudge(key, in: layer, delta: -state.project.frameDuration) }
                                    Button("+1f") { nudge(key, in: layer, delta: state.project.frameDuration) }
                                }.font(.caption).buttonStyle(.bordered)
                            }
                            Button("Edit Segment Easing") {
                                state.graphTimeRemap = true; state.graphEffect = nil; state.panel = .graph; dismiss()
                            }.buttonStyle(.borderedProminent)
                            Button("Reverse Playback") { state.reversePlayback() }.buttonStyle(.bordered)
                        } else {
                            Button("Enable Time Remap") { state.enableTimeRemap() }.buttonStyle(.borderedProminent)
                        }
                        Divider()
                        Text("Velocity Ramp").font(.headline)
                        Text("Creates a smooth fast–slow–fast ramp around the playhead, keeping the current source start/end frames and clip length. Fast and slow set the relative speed shape.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                        NumberField(value: slow, label: "Slow weight", step: 0.01, precision: 2) { slow = min(16, max(0.01, $0)) }
                        NumberField(value: fast, label: "Fast weight", step: 0.01, precision: 2) { fast = min(16, max(0.01, $0)) }
                        NumberField(value: window, label: "Half window (seconds)", step: state.project.frameDuration, precision: 3) { window = min(30, max(0.02, $0)) }
                        Button("Apply Ramp") { state.applySpeedRamp(slow: slow, fast: fast, window: window) }.buttonStyle(.bordered)
                    } else {
                        Text("Select video, audio or a precomp to edit source timing.")
                    }
                }.padding()
            }.scrollDisabled(original != nil)
            .safeAreaInset(edge: .top, spacing: 0) {
                // Pinned so scrolled content can't slide the picker under the title.
                if state.selectedLayer?.timeRemap != nil {
                    Picker("Graph", selection: $speedGraph) {
                        Text("Source Time").tag(false); Text("Playback Speed").tag(true)
                    }.pickerStyle(.segmented).padding(.horizontal).padding(.vertical, 8).background(Theme.background)
                }
            }
            .navigationTitle("Time & Velocity").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onDisappear { original = nil; dragRange = nil; state.endEdit() }
    }

    private func nudge(_ key: Keyframe<Double>, in layer: Layer, delta: Double) {
        guard var a = layer.timeRemap, let index = a.keyframes.firstIndex(where: { $0.id == key.id }) else { return }
        let t = state.project.snapToFrame(key.time + delta)
        guard t >= layer.inPoint, t <= layer.outPoint,
              !a.keyframes.contains(where: { $0.id != key.id && abs($0.time - t) < keyframeTimeEpsilon }) else { return }
        a.keyframes[index].time = t; a.keyframes.sort { $0.time < $1.time }
        state.coalescedEdit("Move Remap Key") { $0.timeRemap = a }
        state.seek(t); AudioPreview.shared.invalidate()
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
                if !speedGraph {
                    ForEach(remap.keyframes) { key in
                        Circle().fill(selected == key.id ? Theme.keyframe : .white)
                            .frame(width: 12, height: 12).frame(width: 36, height: 36).contentShape(Circle())
                            .position(x: box.minX + CGFloat((key.time - layer.inPoint) / duration) * box.width,
                                      y: box.maxY - CGFloat((key.value - lower) / (upper - lower)) * box.height)
                            .onTapGesture { selected = key.id; state.seek(key.time) }
                            .accessibilityLabel(String(format: "Source key at %.3f seconds", key.time))
                            .highPriorityGesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("remapPlot"))
                                .onChanged { drag in
                                    if original == nil { original = remap; dragRange = lower...upper; selected = key.id; state.pause(); state.beginEdit("Move Remap Key") }
                                    guard var a = original, let k = a.keyframes.firstIndex(where: { $0.id == key.id }) else { return }
                                    let base = a.keyframes[k]
                                    let first = k > 0 ? a.keyframes[k - 1].time + state.project.frameDuration : layer.inPoint
                                    let last = k + 1 < a.keyframes.count ? a.keyframes[k + 1].time - state.project.frameDuration : layer.outPoint
                                    guard first <= last else { return }
                                    a.keyframes[k].time = min(last, max(first, state.project.snapToFrame(base.time + Double(drag.translation.width / box.width) * duration)))
                                    a.keyframes[k].value = max(0, base.value - Double(drag.translation.height / box.height) * (upper - lower))
                                    state.mutateLayer { $0.timeRemap = a }
                                }.onEnded { _ in original = nil; dragRange = nil; state.endEdit(); AudioPreview.shared.invalidate() })
                    }
                }
                VStack { HStack { Text(String(format: "%.2f", upper) + (speedGraph ? "×" : "s")); Spacer() }; Spacer()
                    HStack { Text(String(format: "%.2f", lower)); Spacer(); Text(String(format: "%.2fs", layer.outPoint)) }
                }.font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.textDim).padding(5).allowsHitTesting(false)
            }.coordinateSpace(name: "remapPlot")
        }
    }
}
