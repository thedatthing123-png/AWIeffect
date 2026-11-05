import SwiftUI

/// One saved / copied ease (bezier handles or a math curve).
struct SavedEase: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var interpolation: Interpolation
    var out: EaseHandle
    var into: EaseHandle
    var curve: EaseCurve?
    var reversedSegment: Bool? = nil

    func velocity(at x: Double, valueDelta: Double, duration: Double) -> Double {
        guard duration > 1e-9, interpolation != .hold else { return 0 }
        let a = max(0, x - 0.0001), b = min(1, x + 0.0001)
        guard b > a else { return 0 }
        return (progress(b) - progress(a)) / (b - a) * valueDelta / duration
    }

    func progress(_ x: Double) -> Double {
        switch interpolation {
        case .hold: return x >= 1 ? 1 : (reversedSegment == true && x > 0 ? 1 : 0)
        case .linear: return x
        case .bezier:
            if let curve { return reversedSegment == true ? 1 - curve.progress(1 - x) : curve.progress(x) }
            return BezierTiming.progress(x: x, p1: out, p2: into)
        }
    }
}

/// Flow-style graph editor, inside the bottom panel: pick a property (or All), the segment under the playhead,
/// then tap a curve or drag the handles. Changes apply live; the dot replays the motion so you feel the timing.
struct FlowGraphPanel: View {
    @ObservedObject var state: EditorState
    @State private var key: PropertyKey?            // nil = all animated properties
    @State private var speedView = false
    @AppStorage("awi.myCurves") private var savedData = Data()
    private static var clipboard: SavedEase?

    private var saved: [SavedEase] { (try? JSONDecoder().decode([SavedEase].self, from: savedData)) ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Graph")
            if state.animatedKeys.isEmpty && state.effectGraphTargets.isEmpty && state.selectedLayer?.timeRemap == nil {
                VStack(spacing: 8) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").font(.system(size: 28)).foregroundStyle(Theme.textDim)
                    Text("Add two keyframes on a property, then shape its motion here.")
                        .font(.system(size: 13)).foregroundStyle(Theme.textDim).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            } else {
                propertyChips
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 6) {
                        graph
                        controls
                    }
                    presetColumn.frame(width: 118)
                }
                .padding(.horizontal, 10).padding(.bottom, 8)
            }
        }
        .onAppear {
            if let k = key, !state.animatedKeys.contains(k) { key = nil }
            if state.graphTimeRemap && state.selectedLayer?.timeRemap == nil { state.graphTimeRemap = false }
            if !state.graphTimeRemap, state.graphEffect == nil, state.animatedKeys.isEmpty {
                if state.selectedLayer?.timeRemap != nil { state.graphTimeRemap = true }
                else { state.graphEffect = state.effectGraphTargets.first?.target }
            }
        }
    }

    // MARK: Current segment

    /// The property the graph shows (the chosen one, else the first animated).
    private var shownKey: PropertyKey? { key ?? state.animatedKeys.first }

    /// Segments of what the graph shows: a keyframed effect setting, else a transform property.
    private var shownSegs: [EaseSegment] {
        if state.graphTimeRemap { return state.remapSegments }
        if let g = state.graphEffect { return state.effectSegments(g) }
        return shownKey.map { state.easeSegments($0) } ?? []
    }

    private var segmentIndex: Int? {
        let segs = shownSegs
        guard !segs.isEmpty else { return nil }
        let t = state.currentTime
        return segs.firstIndex { t >= $0.t0 - 1e-4 && t < $0.t1 - 1e-4 } ?? (t < segs[0].t0 ? 0 : segs.count - 1)
    }

    private var current: SavedEase? {
        guard let i = segmentIndex else { return nil }
        let s = shownSegs[i]
        return SavedEase(name: "", interpolation: s.interpolation, out: s.out, into: s.into, curve: s.interpolation == .bezier ? s.curve : nil, reversedSegment: s.reversedSegment)
    }

    private func apply(_ e: SavedEase, continuous: Bool = false) {
        if state.graphTimeRemap {
            state.setRemapEase(segment: segmentIndex, ease: e, continuous: continuous)
        } else if let g = state.graphEffect {
            state.setEffectEase(g, segment: segmentIndex, interpolation: e.interpolation, out: e.out, into: e.into, curve: e.curve, reversedSegment: e.reversedSegment, continuous: continuous)
        } else if let k = key {
            state.setEase(k, segment: segmentIndex, interpolation: e.interpolation, out: e.out, into: e.into, curve: e.curve, reversedSegment: e.reversedSegment, continuous: continuous)
        } else {
            let t = shownKey.flatMap { k in segmentIndex.map { state.easeSegments(k)[$0].t0 } }
            state.setEaseAll(segmentAt: t, interpolation: e.interpolation, out: e.out, into: e.into, curve: e.curve, reversedSegment: e.reversedSegment, continuous: continuous)
        }
        if !continuous { UISelectionFeedbackGenerator().selectionChanged() }
    }

    // MARK: Pieces

    private var propertyChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if !state.animatedKeys.isEmpty {
                    chip("All", selected: key == nil && state.graphEffect == nil && !state.graphTimeRemap) { key = nil; state.graphEffect = nil; state.graphTimeRemap = false }
                }
                ForEach(state.animatedKeys) { k in chip(k.title, selected: key == k && state.graphEffect == nil && !state.graphTimeRemap) { key = k; state.graphEffect = nil; state.graphTimeRemap = false } }
                ForEach(state.effectGraphTargets, id: \.target) { e in
                    chip(e.title, selected: state.graphEffect == e.target && !state.graphTimeRemap) { state.graphEffect = e.target; state.graphTimeRemap = false }
                }
                if state.selectedLayer?.timeRemap != nil {
                    chip("Time Remap", selected: state.graphTimeRemap) { state.graphTimeRemap = true; state.graphEffect = nil }
                }
                Divider().frame(height: 20)
                Button { state.jumpKeyframe(forward: false) } label: { Image(systemName: "chevron.left.to.line") }
                    .accessibilityLabel("Previous keyframe")
                Text(segmentLabel).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.textDim)
                Button { state.jumpKeyframe(forward: true) } label: { Image(systemName: "chevron.right.to.line") }
                    .accessibilityLabel("Next keyframe")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10)
        }
        .frame(height: 36)
    }

    private var currentSegmentDuration: Double {
        guard let k = segmentIndex, shownSegs.indices.contains(k) else { return 1 }
        return shownSegs[k].t1 - shownSegs[k].t0
    }

    private var remapValueDelta: Double? {
        guard state.graphTimeRemap, let k = segmentIndex, let a = state.selectedLayer?.timeRemap,
              k + 1 < a.keyframes.count else { return nil }
        return a.keyframes[k + 1].value - a.keyframes[k].value
    }

    private var segmentLabel: String {
        guard let i = segmentIndex else { return "" }
        let s = shownSegs[i]
        return String(format: "%.2fs → %.2fs", s.t0, s.t1)
    }

    private func chip(_ title: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(selected ? Theme.accent : Theme.raised))
                .foregroundStyle(selected ? .white : Theme.text)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var graph: some View {
        if let e = current {
            ZStack(alignment: .topTrailing) {
                if e.curve == nil && e.interpolation == .bezier && !speedView {
                    CurveEditor(segment: EaseSegment(t0: 0, t1: 1, interpolation: .bezier, out: e.out, into: e.into)) { out, into, done in
                        var n = e; n.out = out; n.into = into; n.curve = nil; n.reversedSegment = nil
                        apply(n, continuous: true)
                        if done { state.endEdit() }
                    }
                } else {
                    CurvePlot(ease: e, speed: speedView, valueDelta: remapValueDelta,
                              segmentDuration: currentSegmentDuration)
                }
                ReplayDot(ease: e).allowsHitTesting(false)
            }
            .frame(minHeight: 120)
        }
    }

    @ViewBuilder private var controls: some View {
        if let e = current {
            VStack(spacing: 6) {
                if let c = e.curve, let pa = c.kind.paramA {
                    paramRow(pa.0, value: c.a, range: pa.1) { v in var n = e; n.curve?.a = v; apply(n, continuous: true) }
                }
                if let c = e.curve, let pb = c.kind.paramB {
                    paramRow(pb.0, value: c.b, range: pb.1) { v in var n = e; n.curve?.b = v; apply(n, continuous: true) }
                }
                HStack(spacing: 6) {
                    small(speedView ? "Value" : "Speed", "speedometer") { speedView.toggle() }
                    small("Copy", "doc.on.doc") { Self.clipboard = e }
                    small("Paste", "doc.on.clipboard") { if let c = Self.clipboard { apply(c) } }
                    small("Save", "star") {
                        var list = saved
                        var n = e; n.id = UUID(); n.name = "My Curve \(list.count + 1)"
                        list.append(n)
                        savedData = (try? JSONEncoder().encode(list)) ?? savedData
                    }
                }
            }
        }
    }

    private func paramRow(_ label: String, value: Double, range: ClosedRange<Double>, _ set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textDim).frame(width: 74, alignment: .leading)
            ValueScrubber(value: value, range: range, onChange: set, onEnd: { state.endEdit() })
        }
    }

    private func small(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 9, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
    }

    private var presetColumn: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                if !saved.isEmpty {
                    section("My Curves")
                    ForEach(saved) { s in presetTile(s.name, ease: s) }
                }
                section("Basic")
                ForEach(EasePreset.all) { p in
                    presetTile(p.name, ease: SavedEase(name: p.name, interpolation: p.interpolation, out: p.out, into: p.into, curve: nil))
                }
                section("Bounce & Spring")
                ForEach([EaseCurve.Kind.bounceOut, .bounceIn, .elasticOut, .elasticIn, .backOut, .backIn, .backInOut, .overshoot], id: \.self) { k in
                    curveTile(k)
                }
                section("Ease")
                ForEach(EaseCurve.Kind.allCases.filter { ![.bounceOut, .bounceIn, .elasticOut, .elasticIn, .backOut, .backIn, .backInOut, .overshoot].contains($0) }) { k in
                    curveTile(k)
                }
            }
        }
    }

    private func section(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textDim).padding(.top, 4)
    }

    private func curveTile(_ k: EaseCurve.Kind) -> some View {
        presetTile(k.title, ease: SavedEase(name: k.title, interpolation: .bezier, out: .easyOut, into: .easyIn, curve: EaseCurve(k)))
    }

    private func presetTile(_ title: String, ease: SavedEase) -> some View {
        let on = current.map { $0.interpolation == ease.interpolation && $0.curve?.kind == ease.curve?.kind
            && (ease.curve != nil || ($0.out == ease.out && $0.into == ease.into)) } ?? false
        return Button { apply(ease) } label: {
            HStack(spacing: 6) {
                CurvePlot(ease: ease, speed: false, thumb: true).frame(width: 30, height: 22)
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 8).fill(on ? Theme.accent.opacity(0.35) : Theme.raised))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Read-only curve (value or speed view); also used for thumbnails.
struct CurvePlot: View {
    let ease: SavedEase
    var speed: Bool
    var thumb = false
    var valueDelta: Double? = nil
    var segmentDuration: Double = 1

    var body: some View {
        Canvas { ctx, size in
            let inset: CGFloat = thumb ? 2 : 24
            let box = CGRect(x: inset, y: size.height * (thumb ? 0.12 : 0.2), width: size.width - inset * 2, height: size.height * (thumb ? 0.76 : 0.6))
            if !thumb {
                ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14), with: .color(Theme.surface))
                var grid = Path()
                for i in 0...4 {
                    let y = box.minY + box.height * CGFloat(i) / 4
                    grid.move(to: CGPoint(x: box.minX, y: y)); grid.addLine(to: CGPoint(x: box.maxX, y: y))
                }
                ctx.stroke(grid, with: .color(Theme.stroke), lineWidth: 1)
            }
            let n = thumb ? 40 : 160
            var ys: [Double] = (0...n).map { ease.progress(Double($0) / Double(n)) }
            if speed {
                let rates = (0...n).map { ease.velocity(at: Double($0) / Double(n), valueDelta: valueDelta ?? 1, duration: segmentDuration) }
                if valueDelta != nil {
                    let low = min(0, rates.min() ?? 0), high = max(0.01, rates.max() ?? 0)
                    ys = rates.map { ($0 - low) / (high - low) }
                    let y = box.maxY - CGFloat(-low / (high - low)) * box.height
                    var zero = Path(); zero.move(to: CGPoint(x: box.minX, y: y)); zero.addLine(to: CGPoint(x: box.maxX, y: y))
                    ctx.stroke(zero, with: .color(Theme.textDim), style: StrokeStyle(lineWidth: 1, dash: [3,3]))
                    ctx.draw(Text(String(format: "%+.2f× / %+.2f×", low, high)).font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.textDim),
                             at: CGPoint(x: box.minX, y: 4), anchor: .topLeading)
                } else {
                    let peak = max(rates.map { abs($0) }.max() ?? 1, 1e-6)
                    ys = rates.map { abs($0) / peak }
                }
            }
            var path = Path()
            for (i, y) in ys.enumerated() {
                let p = CGPoint(x: box.minX + CGFloat(i) / CGFloat(n) * box.width, y: box.maxY - CGFloat(y) * box.height)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            ctx.stroke(path, with: .color(Theme.accentGlow), style: StrokeStyle(lineWidth: thumb ? 1.6 : 3, lineCap: .round, lineJoin: .round))
        }
    }
}

/// A dot that keeps replaying the eased motion (left → right), so the timing can be felt at a glance.
struct ReplayDot: View {
    let ease: SavedEase

    var body: some View {
        if isUITesting {
            EmptyView()
        } else {
            SwiftUI.TimelineView(.animation) { tl in
                let cycle = 1.4
                let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
                let x = min(1, t / 0.75)
                let p = ease.progress(x)
                GeometryReader { geo in
                    let w = geo.size.width - 48
                    Circle().fill(Theme.keyframe).frame(width: 12, height: 12)
                        .shadow(color: Theme.keyframe.opacity(0.7), radius: 5)
                        .position(x: 24 + CGFloat(p) * w, y: 10)
                }
            }
            .frame(height: 20)
        }
    }
}
