import SwiftUI

/// The lane a value / speed graph shows.
struct GraphTarget: Identifiable, Equatable {
    let layerID: UUID
    let laneID: String
    var id: String { "\(layerID)/\(laneID)" }
}

/// Value-graph math on one numeric channel (a scalar property, or one component of a 2D one).
enum ValueGraph {
    /// One component of a 2D property as a scalar track (same keys, ids and easing).
    static func channel(_ a: Animated<Vec2>, dim: Int) -> Animated<Double> {
        var out = Animated(dim == 0 ? a.staticValue.x : a.staticValue.y)
        out.keyframes = a.keyframes.map { k in
            Keyframe(id: k.id, time: k.time, value: dim == 0 ? k.value.x : k.value.y, interpolation: k.interpolation,
                     easeOut: k.easeOut, easeIn: k.easeIn, curve: k.curve, reversedSegment: k.reversedSegment)
        }
        return out
    }

    /// Writes an edited channel back into the 2D property (matched by key id; the other component is kept).
    static func merge(_ channel: Animated<Double>, into a: inout Animated<Vec2>, dim: Int) {
        for k in channel.keyframes {
            guard let j = a.keyframes.firstIndex(where: { $0.id == k.id }) else { continue }
            a.keyframes[j].time = k.time
            if dim == 0 { a.keyframes[j].value.x = k.value } else { a.keyframes[j].value.y = k.value }
            a.keyframes[j].interpolation = k.interpolation
            a.keyframes[j].easeOut = k.easeOut
            a.keyframes[j].easeIn = k.easeIn
            a.keyframes[j].curve = k.curve
        }
        a.keyframes.sort { $0.time < $1.time }
    }

    /// Moves a key to a new time and value. Refused (false) when another key already sits at that time.
    @discardableResult
    static func moveKey(_ a: inout Animated<Double>, id: UUID, time: Double, value: Double) -> Bool {
        guard let j = a.keyframes.firstIndex(where: { $0.id == id }), time.isFinite, value.isFinite else { return false }
        if a.keyframes.contains(where: { $0.id != id && abs($0.time - time) < keyframeTimeEpsilon }) { return false }
        a.keyframes[j].time = max(0, time)
        a.keyframes[j].value = value
        a.keyframes.sort { $0.time < $1.time }
        return true
    }

    /// Graph position (time, value) of key `k`'s outgoing (`out`) or incoming handle; nil when there's no segment.
    static func handlePoint(_ a: Animated<Double>, key k: Int, out: Bool) -> (t: Double, v: Double)? {
        let ks = a.keyframes
        let s = out ? k : k - 1
        guard s >= 0, s + 1 < ks.count else { return nil }
        let a0 = ks[s], a1 = ks[s + 1]
        let span = a1.time - a0.time, dv = a1.value - a0.value
        let bez = a0.interpolation == .bezier && a0.curve == nil
        let h = out ? (bez ? a0.easeOut : .linearOut) : (bez ? a1.easeIn : .linearIn)
        return (a0.time + h.x * span, a0.value + h.y * dv)
    }

    /// Drags a handle to a graph position: the segment becomes a bezier with that influence (x) and speed (y).
    static func setHandle(_ a: inout Animated<Double>, key k: Int, out: Bool, t: Double, v: Double) {
        let s = out ? k : k - 1
        guard s >= 0, s + 1 < a.keyframes.count else { return }
        let a0 = a.keyframes[s], a1 = a.keyframes[s + 1]
        let span = max(a1.time - a0.time, 1e-9), dv = a1.value - a0.value
        let wasBezier = a0.interpolation == .bezier && a0.curve == nil
        let old = out ? (wasBezier ? a0.easeOut : .linearOut) : (wasBezier ? a1.easeIn : .linearIn)
        let x = min(1, max(0, (t - a0.time) / span))
        let y = abs(dv) < 1e-9 ? old.y : min(4, max(-3, (v - a0.value) / dv))
        if !wasBezier {
            // Keep the other handle where it was drawn (linear) so only the dragged side changes.
            a.keyframes[s].easeOut = .linearOut
            a.keyframes[s + 1].easeIn = .linearIn
        }
        a.keyframes[s].interpolation = .bezier
        a.keyframes[s].curve = nil
        if out { a.keyframes[s].easeOut = EaseHandle(x: x, y: y) } else { a.keyframes[s + 1].easeIn = EaseHandle(x: x, y: y) }
    }

    /// Speed in units per second at `t` (central difference of `sample`).
    static func speed(at t: Double, _ sample: (Double) -> Double) -> Double {
        let h = 1.0 / 240
        return (sample(t + h) - sample(t - h)) / (2 * h)
    }
}

/// Value and speed graph of one lane across all its keys: drag keys (time and value) and bezier handles, type exact
/// numbers below. The Graph panel stays the per-segment easing view.
struct TimelineGraphSheet: View {
    @ObservedObject var state: EditorState
    let target: GraphTarget
    @Environment(\.dismiss) private var dismiss
    @State private var speedMode = false
    @State private var dim = 0
    @State private var selectedKey: UUID?
    /// Channel and value range when a drag began (the range stays put while dragging).
    @State private var dragStart: Animated<Double>?
    @State private var frozenRange: ClosedRange<Double>?

    private var layer: Layer? { state.project.layers.first { $0.id == target.layerID } }
    private var lane: PropertyLane? { layer?.propertyLanes().first { $0.id == target.laneID } }

    private var isVector: Bool { if case .vector = lane?.values { return true }; return false }

    /// The edited channel (scalar property, or the chosen component).
    private func channel(_ l: Layer, _ lane: PropertyLane, dim: Int) -> Animated<Double>? {
        switch lane.values {
        case .scalar(let get, _): return get(l)
        case .vector(let get, _): return get(l).map { ValueGraph.channel($0, dim: dim) }
        case .none: return nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                if let l = layer, let lane, let ch = channel(l, lane, dim: dim), ch.keyframes.count >= 1 {
                    HStack(spacing: 8) {
                        Picker("Graph", selection: $speedMode) {
                            Text("Value").tag(false)
                            Text("Speed").tag(true)
                        }
                        .pickerStyle(.segmented)
                        if isVector {
                            Picker("Axis", selection: $dim) {
                                Text("X").tag(0)
                                Text("Y").tag(1)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .frame(minHeight: 44)
                    graph(l, lane, ch)
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                    keyFields(lane, ch)
                    Text(speedMode
                         ? "Speed in units per second. Flat at a key = the motion stops there; switch to Value to shape it."
                         : "Drag a key to change its time and value. Select a key to show its handles: drag them for influence and speed.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ContentUnavailableView("No keys to graph", systemImage: "chart.xyaxis.line",
                                           description: Text("This property has no number keys left."))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Theme.background)
            .navigationTitle(lane.map { "\($0.title)" } ?? "Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onDisappear { if dragStart != nil { dragStart = nil; state.endEdit() } }
    }

    // MARK: Graph

    private func sampler(_ l: Layer, _ lane: PropertyLane, _ ch: Animated<Double>) -> (Double) -> Double {
        if speedMode, case .vector(let get, _) = lane.values, let a = get(l) {
            // Speed of a 2D property is the length of its velocity (both axes together).
            return { t in
                let h = 1.0 / 240
                let p0 = a.value(at: t - h), p1 = a.value(at: t + h)
                return hypot(p1.x - p0.x, p1.y - p0.y) / (2 * h)
            }
        }
        if speedMode { return { t in ValueGraph.speed(at: t) { ch.value(at: $0) } } }
        return { ch.value(at: $0) }
    }

    private func graph(_ l: Layer, _ lane: PropertyLane, _ ch: Animated<Double>) -> some View {
        let keys = ch.keyframes
        let first = keys.first?.time ?? 0, last = keys.last?.time ?? 1
        let span = max(last - first, 0.5)
        let pad = span * 0.08
        let t0 = first - pad, t1 = first + span + pad
        let sample = sampler(l, lane, ch)
        let samples = (0...160).map { i -> Double in sample(t0 + (t1 - t0) * Double(i) / 160) }
        var lo = samples.min() ?? 0, hi = samples.max() ?? 1
        if !speedMode {
            for k in keys.indices {
                for out in [true, false] { if let p = ValueGraph.handlePoint(ch, key: k, out: out) { lo = min(lo, p.v); hi = max(hi, p.v) } }
            }
        }
        if hi - lo < 1e-6 { lo -= 1; hi += 1 }
        let margin = (hi - lo) * 0.12
        let range = frozenRange ?? (lo - margin)...(hi + margin)
        let selIndex = keys.firstIndex { $0.id == selectedKey }

        return GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let toX: (Double) -> CGFloat = { CGFloat(($0 - t0) / (t1 - t0)) * w }
            let toY: (Double) -> CGFloat = { h - CGFloat(($0 - range.lowerBound) / (range.upperBound - range.lowerBound)) * h }
            let toT: (CGFloat) -> Double = { t0 + Double($0 / max(w, 1)) * (t1 - t0) }
            let toV: (CGFloat) -> Double = { range.lowerBound + Double((h - $0) / max(h, 1)) * (range.upperBound - range.lowerBound) }
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    // Grid with value labels.
                    for g in 0...4 {
                        let y = size.height * CGFloat(g) / 4
                        ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) }, with: .color(Theme.stroke), lineWidth: 1)
                        let v = range.upperBound - (range.upperBound - range.lowerBound) * Double(g) / 4
                        ctx.draw(Text(String(format: abs(v) >= 100 ? "%.0f" : "%.2f", v)).font(.system(size: 9, design: .monospaced)).foregroundColor(Theme.textDim),
                                 at: CGPoint(x: 4, y: min(max(y, 8), size.height - 8)), anchor: .leading)
                    }
                    // Playhead.
                    let px = toX(state.currentTime)
                    ctx.fill(Path(CGRect(x: px - 0.75, y: 0, width: 1.5, height: size.height)), with: .color(.white.opacity(0.5)))
                    // Curve.
                    var curve = Path()
                    for i in 0...160 {
                        let p = CGPoint(x: CGFloat(i) / 160 * size.width, y: toY(samples[i]))
                        if i == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
                    }
                    ctx.stroke(curve, with: .color(Theme.accentGlow), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    // Handle lines of the selected key.
                    if !speedMode, let k = selIndex {
                        let kp = CGPoint(x: toX(keys[k].time), y: toY(keys[k].value))
                        for out in [true, false] {
                            guard let hp = ValueGraph.handlePoint(ch, key: k, out: out) else { continue }
                            let end = CGPoint(x: toX(hp.t), y: toY(hp.v))
                            ctx.stroke(Path { $0.move(to: kp); $0.addLine(to: end) }, with: .color(Theme.textDim), lineWidth: 1)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .allowsHitTesting(false)

                // Keys.
                ForEach(Array(keys.enumerated()), id: \.element.id) { k, key in
                    let y = speedMode ? toY(sample(key.time)) : toY(key.value)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(key.id == selectedKey ? Theme.keyframe : .white)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .position(x: toX(key.time), y: y)
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("valueGraph"))
                            .onChanged { g in
                                selectedKey = key.id
                                guard !speedMode else { return }
                                if dragStart == nil { dragStart = ch; frozenRange = range; state.pause(); state.beginEdit("Edit Graph") }
                                guard var a = dragStart, let start = a.keyframes.first(where: { $0.id == key.id }) else { return }
                                guard abs(g.translation.width) + abs(g.translation.height) > 2 else { return }
                                let newT = state.project.snapToFrame(start.time + Double(g.translation.width / max(w, 1)) * (t1 - t0))
                                let newV = start.value - Double(g.translation.height / max(h, 1)) * (range.upperBound - range.lowerBound)
                                if ValueGraph.moveKey(&a, id: key.id, time: newT, value: newV) { write(a) }
                            }
                            .onEnded { _ in finishDrag() })
                        .accessibilityLabel("Key \(k + 1) at \(String(format: "%.2f", key.time)) seconds")
                }

                // Handles of the selected key.
                if !speedMode, let k = selIndex {
                    ForEach([true, false], id: \.self) { out in
                        if let hp = ValueGraph.handlePoint(ch, key: k, out: out) {
                            Circle().fill(.white).frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Theme.accent, lineWidth: 2.5))
                                .frame(width: 44, height: 44).contentShape(Circle())
                                .position(x: toX(hp.t), y: toY(hp.v))
                                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("valueGraph"))
                                    .onChanged { g in
                                        if dragStart == nil { dragStart = ch; frozenRange = range; state.pause(); state.beginEdit("Edit Graph Handle") }
                                        guard var a = dragStart, let start = ValueGraph.handlePoint(a, key: k, out: out) else { return }
                                        let p = CGPoint(x: toX(start.t) + g.translation.width, y: toY(start.v) + g.translation.height)
                                        ValueGraph.setHandle(&a, key: k, out: out, t: toT(p.x), v: toV(p.y))
                                        write(a)
                                    }
                                    .onEnded { _ in finishDrag() })
                                .accessibilityLabel(out ? "Outgoing handle" : "Incoming handle")
                        }
                    }
                }
            }
            .coordinateSpace(name: "valueGraph")
        }
    }

    // MARK: Numbers

    @ViewBuilder private func keyFields(_ lane: PropertyLane, _ ch: Animated<Double>) -> some View {
        if let key = ch.keyframes.first(where: { $0.id == selectedKey }) {
            HStack(spacing: 8) {
                NumberField(value: key.time, label: "TIME", step: state.project.frameDuration, precision: 2,
                            onDragBegin: { dragStart = ch; state.beginEdit("Move Key") },
                            onDragEnd: { finishDrag() }) { t in
                    var a = dragStart ?? ch
                    let base = a.keyframes.first { $0.id == key.id }?.value ?? key.value
                    if ValueGraph.moveKey(&a, id: key.id, time: state.project.snapToFrame(t), value: base) { commit(a) }
                }
                NumberField(value: key.value, label: isVector ? (dim == 0 ? "X" : "Y") : "VALUE", step: 1, precision: 2,
                            onDragBegin: { dragStart = ch; state.beginEdit("Key Value") },
                            onDragEnd: { finishDrag() }) { v in
                    var a = dragStart ?? ch
                    let time = a.keyframes.first { $0.id == key.id }?.time ?? key.time
                    if ValueGraph.moveKey(&a, id: key.id, time: time, value: v) { commit(a) }
                }
            }
            .frame(minHeight: 44)
        } else {
            Text("Tap a key to select it.").font(.system(size: 13)).foregroundStyle(Theme.textDim).frame(minHeight: 44)
        }
    }

    // MARK: Writing

    private func finishDrag() {
        guard dragStart != nil else { return }
        dragStart = nil; frozenRange = nil
        state.endEdit()
    }

    /// One undo step: typed numbers make their own step; drags already have one open.
    private func commit(_ a: Animated<Double>) {
        if state.editGroupOpen { write(a); return }
        state.beginEdit("Edit Key")
        write(a)
        state.endEdit()
    }

    private func write(_ channel: Animated<Double>) {
        guard let i = state.project.layers.firstIndex(where: { $0.id == target.layerID }), let lane,
              !state.project.layers[i].isLocked else { return }
        let d = dim
        state.mutateLayer(at: i) { l in
            switch lane.values {
            case .scalar(_, let set): set(&l, channel)
            case .vector(let get, let set):
                guard var a = get(l) else { return }
                ValueGraph.merge(channel, into: &a, dim: d)
                set(&l, a)
            case .none: break
            }
        }
    }
}
