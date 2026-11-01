import SwiftUI

/// One keyframe segment's easing, independent of the value type.
struct EaseSegment: Equatable {
    var t0: Double
    var t1: Double
    var interpolation: Interpolation
    var out: EaseHandle
    var into: EaseHandle
    var curve: EaseCurve? = nil
}

/// Easing presets (handle pairs in normalized segment space).
struct EasePreset: Identifiable {
    let id: String
    let name: String
    let out: EaseHandle
    let into: EaseHandle
    var interpolation: Interpolation = .bezier

    static let all: [EasePreset] = [
        .init(id: "linear", name: "Linear", out: .linearOut, into: .linearIn, interpolation: .linear),
        .init(id: "easy", name: "Easy Ease", out: EaseHandle(x: 0.33, y: 0), into: EaseHandle(x: 0.67, y: 1)),
        .init(id: "in", name: "Ease In", out: EaseHandle(x: 0.33, y: 0), into: EaseHandle(x: 0.67, y: 0.67)),
        .init(id: "out", name: "Ease Out", out: EaseHandle(x: 0.33, y: 0.33), into: EaseHandle(x: 0.67, y: 1)),
        .init(id: "snap", name: "Snap", out: EaseHandle(x: 0.9, y: 0), into: EaseHandle(x: 0.1, y: 1)),
        .init(id: "velocity", name: "Velocity", out: EaseHandle(x: 0.95, y: 0), into: EaseHandle(x: 0.05, y: 1)),
        .init(id: "smash", name: "Smash In", out: EaseHandle(x: 0.05, y: 1), into: EaseHandle(x: 0.6, y: 1)),
        .init(id: "back", name: "Overshoot", out: EaseHandle(x: 0.3, y: 0), into: EaseHandle(x: 0.6, y: 1.35)),
        .init(id: "anticipate", name: "Anticipate", out: EaseHandle(x: 0.4, y: -0.35), into: EaseHandle(x: 0.7, y: 1)),
        .init(id: "hold", name: "Hold", out: .linearOut, into: .linearIn, interpolation: .hold),
    ]
}

extension EditorState {
    /// Applies `f` to the Animated property behind `key` on the selected layer.
    private func editKeyframes(_ key: PropertyKey, label: String, curves: ((inout [EaseCurve?]) -> Void)? = nil,
                               _ f: (inout [Double], inout [Interpolation], inout [EaseHandle], inout [EaseHandle]) -> Void) {
        guard let i = selectedIndex else { return }
        func apply<V>(_ a: inout Animated<V>) {
            var times = a.keyframes.map(\.time), interps = a.keyframes.map(\.interpolation)
            var outs = a.keyframes.map(\.easeOut), ins = a.keyframes.map(\.easeIn)
            var cs = a.keyframes.map(\.curve)
            f(&times, &interps, &outs, &ins)
            curves?(&cs)
            for k in a.keyframes.indices {
                a.keyframes[k].interpolation = interps[k]
                a.keyframes[k].easeOut = outs[k]
                a.keyframes[k].easeIn = ins[k]
                a.keyframes[k].curve = cs[k]
            }
        }
        mutate(label) { p in
            switch key {
            case .position: apply(&p.layers[i].transform.position)
            case .scale: apply(&p.layers[i].transform.scale)
            case .rotation: apply(&p.layers[i].transform.rotation)
            case .opacity: apply(&p.layers[i].transform.opacity)
            case .anchor: apply(&p.layers[i].transform.anchor)
            case .size: apply(&p.layers[i].size)
            case .fill: apply(&p.layers[i].fill)
            case .cornerRadius: apply(&p.layers[i].cornerRadius)
            case .positionZ: apply(&p.layers[i].transform.positionZ)
            case .rotationX: apply(&p.layers[i].transform.rotationX)
            case .rotationY: apply(&p.layers[i].transform.rotationY)
            }
        }
    }

    func easeSegments(_ key: PropertyKey) -> [EaseSegment] {
        guard let l = selectedLayer else { return [] }
        func segs<V>(_ a: Animated<V>) -> [EaseSegment] {
            guard a.keyframes.count >= 2 else { return [] }
            return (0..<(a.keyframes.count - 1)).map { k in
                EaseSegment(t0: a.keyframes[k].time, t1: a.keyframes[k + 1].time, interpolation: a.keyframes[k].interpolation,
                            out: a.keyframes[k].easeOut, into: a.keyframes[k + 1].easeIn, curve: a.keyframes[k].curve)
            }
        }
        switch key {
        case .position: return segs(l.transform.position)
        case .scale: return segs(l.transform.scale)
        case .rotation: return segs(l.transform.rotation)
        case .opacity: return segs(l.transform.opacity)
        case .anchor: return segs(l.transform.anchor)
        case .size: return segs(l.size)
        case .fill: return segs(l.fill)
        case .cornerRadius: return segs(l.cornerRadius)
        case .positionZ: return segs(l.transform.positionZ)
        case .rotationX: return segs(l.transform.rotationX)
        case .rotationY: return segs(l.transform.rotationY)
        }
    }

    /// Sets one segment's easing (segment index k = keyframe k -> k+1). `nil` index = all segments.
    func setEase(_ key: PropertyKey, segment: Int?, interpolation: Interpolation, out: EaseHandle, into: EaseHandle,
                 curve: EaseCurve? = nil, continuous: Bool = false) {
        let body: (inout [Double], inout [Interpolation], inout [EaseHandle], inout [EaseHandle]) -> Void = { _, interps, outs, ins in
            let n = interps.count
            guard n >= 2 else { return }
            let range = segment.map { [$0] } ?? Array(0..<(n - 1))
            for k in range where k + 1 < n {
                interps[k] = interpolation
                outs[k] = out
                ins[k + 1] = into
            }
        }
        let setCurves: (inout [EaseCurve?]) -> Void = { cs in
            let n = cs.count
            guard n >= 2 else { return }
            for k in segment.map({ [$0] }) ?? Array(0..<(n - 1)) where k + 1 < n { cs[k] = curve }
        }
        if continuous {
            beginEdit("Edit Easing")
            editKeyframes(key, label: "Edit Easing", curves: setCurves, body)
        } else {
            editKeyframes(key, label: "Easing", curves: setCurves, body)
        }
    }

    /// Same ease on every animated property of the selected layer (one undo step).
    func setEaseAll(segmentAt time: Double?, interpolation: Interpolation, out: EaseHandle, into: EaseHandle, curve: EaseCurve?) {
        beginEdit("Easing")
        for key in animatedKeys {
            let segs = easeSegments(key)
            let k = time.flatMap { t in segs.firstIndex { t >= $0.t0 - 1e-4 && t < $0.t1 - 1e-4 } }
            if time != nil && k == nil { continue }
            setEase(key, segment: k, interpolation: interpolation, out: out, into: into, curve: curve, continuous: true)
        }
        endEdit()
    }

    var animatedKeys: [PropertyKey] { PropertyKey.allCases.filter { isAnimated($0) } }
}

/// Alight Motion-style easing graph: pick a property and segment, drag the two bezier handles.
struct GraphEditorSheet: View {
    @ObservedObject var state: EditorState
    @State private var key: PropertyKey = .position
    @State private var segment = 0
    @State private var applyToAll = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if state.animatedKeys.isEmpty {
                    ContentUnavailableView("No keyframes", systemImage: "diamond",
                                           description: Text("Add at least two keyframes on a property to edit its easing."))
                } else {
                    Picker("Property", selection: $key) {
                        ForEach(state.animatedKeys) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    let segs = state.easeSegments(key)
                    if segs.isEmpty {
                        Text("This property needs two keyframes.").foregroundStyle(Theme.textDim)
                    } else {
                        let k = min(segment, segs.count - 1)
                        HStack {
                            Text("Segment").foregroundStyle(Theme.textDim)
                            Picker("", selection: $segment) {
                                ForEach(segs.indices, id: \.self) { i in
                                    Text(String(format: "%.2fs → %.2fs", segs[i].t0, segs[i].t1)).tag(i)
                                }
                            }
                            Spacer()
                            Toggle("All", isOn: $applyToAll).tint(Theme.accent).fixedSize()
                        }
                        .font(.system(size: 13))
                        CurveEditor(segment: segs[k]) { out, into, done in
                            state.setEase(key, segment: applyToAll ? nil : k, interpolation: .bezier, out: out, into: into, continuous: true)
                            if done { state.endEdit() }
                        }
                        .frame(height: 260)
                        Text("Presets").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textDim)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                            ForEach(EasePreset.all) { p in
                                Button {
                                    state.setEase(key, segment: applyToAll ? nil : k, interpolation: p.interpolation, out: p.out, into: p.into)
                                } label: {
                                    VStack(spacing: 4) {
                                        CurveThumb(preset: p).frame(height: 34)
                                        Text(p.name).font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                    .foregroundStyle(Theme.text)
                                    .padding(6).glass(radius: 9)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(Theme.background)
            .navigationTitle("Graph Editor")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { if let first = state.animatedKeys.first { key = first } }
    }
}

/// Draggable cubic-bezier easing curve (x = time, y = progress; y may overshoot).
struct CurveEditor: View {
    let segment: EaseSegment
    let onChange: (EaseHandle, EaseHandle, Bool) -> Void
    @State private var dragOut: EaseHandle?
    @State private var dragIn: EaseHandle?

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 24
            let box = CGRect(x: inset, y: geo.size.height * 0.2, width: geo.size.width - inset * 2, height: geo.size.height * 0.6)
            let out = dragOut ?? (segment.interpolation == .bezier ? segment.out : .linearOut)
            let into = dragIn ?? (segment.interpolation == .bezier ? segment.into : .linearIn)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Theme.surface)
                Path { p in
                    for i in 0...4 {
                        let y = box.minY + box.height * CGFloat(i) / 4
                        p.move(to: CGPoint(x: box.minX, y: y)); p.addLine(to: CGPoint(x: box.maxX, y: y))
                    }
                }
                .stroke(Theme.stroke, lineWidth: 1)
                Path { p in
                    p.move(to: CGPoint(x: box.minX, y: box.maxY))
                    for i in 1...80 {
                        let x = Double(i) / 80
                        let y = BezierTiming.progress(x: x, p1: out, p2: into)
                        p.addLine(to: CGPoint(x: box.minX + CGFloat(x) * box.width, y: box.maxY - CGFloat(y) * box.height))
                    }
                }
                .stroke(Theme.accentGlow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .shadow(color: Theme.accent.opacity(0.6), radius: 6)
                Path { p in
                    p.move(to: CGPoint(x: box.minX, y: box.maxY)); p.addLine(to: Self.pt(out, box))
                    p.move(to: CGPoint(x: box.maxX, y: box.minY)); p.addLine(to: Self.pt(into, box))
                }
                .stroke(Theme.textDim, lineWidth: 1)
                knob(Self.pt(out, box)).gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let h = Self.handle(from: v.location, box); dragOut = h; onChange(h, into, false)
                }.onEnded { v in
                    let h = Self.handle(from: v.location, box); dragOut = nil; onChange(h, into, true)
                })
                knob(Self.pt(into, box)).gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let h = Self.handle(from: v.location, box); dragIn = h; onChange(out, h, false)
                }.onEnded { v in
                    let h = Self.handle(from: v.location, box); dragIn = nil; onChange(out, h, true)
                })
                Text(String(format: "out %.2f, %.2f   in %.2f, %.2f", out.x, out.y, into.x, into.y))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.textDim)
                    .position(x: geo.size.width / 2, y: geo.size.height - 12)
            }
        }
    }

    static func pt(_ h: EaseHandle, _ box: CGRect) -> CGPoint {
        CGPoint(x: box.minX + CGFloat(h.x) * box.width, y: box.maxY - CGFloat(h.y) * box.height)
    }

    static func handle(from p: CGPoint, _ box: CGRect) -> EaseHandle {
        EaseHandle(x: Double(min(max((p.x - box.minX) / box.width, 0), 1)),
                   y: Double(min(max((box.maxY - p.y) / box.height, -0.8), 1.8)))
    }

    private func knob(_ p: CGPoint) -> some View {
        Circle().fill(.white).frame(width: 18, height: 18)
            .overlay(Circle().stroke(Theme.accent, lineWidth: 3))
            .frame(width: 44, height: 44).contentShape(Circle())
            .position(p)
    }
}

struct CurveThumb: View {
    let preset: EasePreset
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height * 0.85))
            for i in 1...30 {
                let x = Double(i) / 30
                let y: Double
                switch preset.interpolation {
                case .hold: y = x < 1 ? 0 : 1
                case .linear: y = x
                case .bezier: y = BezierTiming.progress(x: x, p1: preset.out, p2: preset.into)
                }
                path.addLine(to: CGPoint(x: CGFloat(x) * size.width, y: size.height * (0.85 - 0.7 * CGFloat(y))))
            }
            ctx.stroke(path, with: .color(Theme.accentGlow), lineWidth: 2)
        }
    }
}
