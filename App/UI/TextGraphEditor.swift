import SwiftUI

/// What the text graph edits: an animator property, or one of a selector's timing values.
enum TextEaseTarget: Hashable {
    case property(TextPropKey)
    case selector(Int, SelectorValue)

    enum SelectorValue: String, CaseIterable, Hashable {
        case start = "Start", end = "End", offset = "Offset", amount = "Amount"
        var path: WritableKeyPath<TextSelector, Animated<Double>> {
            switch self { case .start: return \.start; case .end: return \.end; case .offset: return \.offset; case .amount: return \.amount }
        }
    }

    var title: String {
        switch self {
        case .property(let k): return k.title
        case .selector(_, let v): return v.rawValue
        }
    }
}

/// Easing for a text animator property: same curve editor and presets as the layer graph editor, applied to the
/// property's keyframes (position, glow, tracking…) inside one animator.
extension EditorState {
    private func withTextAnimated(_ animatorID: UUID, _ target: TextEaseTarget,
                                  _ f: (inout [Interpolation], inout [EaseHandle], inout [EaseHandle], inout [EaseCurve?]) -> Void,
                                  label: String, continuous: Bool) {
        func apply<V>(_ a: inout Animated<V>) {
            var interps = a.keyframes.map(\.interpolation), outs = a.keyframes.map(\.easeOut)
            var ins = a.keyframes.map(\.easeIn), curves = a.keyframes.map(\.curve)
            f(&interps, &outs, &ins, &curves)
            for k in a.keyframes.indices {
                a.keyframes[k].interpolation = interps[k]
                a.keyframes[k].easeOut = outs[k]
                a.keyframes[k].easeIn = ins[k]
                a.keyframes[k].curve = curves[k]
            }
        }
        let change: (inout TextData) -> Void = { td in
            guard let i = td.animators.firstIndex(where: { $0.id == animatorID }) else { return }
            switch target {
            case .property(let key):
                switch key.access {
                case .scalar(let kp): if var a = td.animators[i].properties[keyPath: kp] { apply(&a); td.animators[i].properties[keyPath: kp] = a }
                case .vector(let kp): if var a = td.animators[i].properties[keyPath: kp] { apply(&a); td.animators[i].properties[keyPath: kp] = a }
                case .color(let kp): if var a = td.animators[i].properties[keyPath: kp] { apply(&a); td.animators[i].properties[keyPath: kp] = a }
                }
            case .selector(let k, let v):
                td.animators[i].setSelector(k) { sel in
                    var a = sel[keyPath: v.path]
                    apply(&a)
                    sel[keyPath: v.path] = a
                }
            }
        }
        if continuous { beginEdit(label); editTextContinuous(change) } else { editText(label, change) }
    }

    func textEaseSegments(_ animatorID: UUID, _ target: TextEaseTarget) -> [EaseSegment] {
        guard let td = selectedLayer?.text, let an = td.animators.first(where: { $0.id == animatorID }) else { return [] }
        func segs<V>(_ a: Animated<V>?) -> [EaseSegment] {
            guard let a, a.keyframes.count >= 2 else { return [] }
            return (0..<(a.keyframes.count - 1)).map { k in
                EaseSegment(t0: a.keyframes[k].time, t1: a.keyframes[k + 1].time, interpolation: a.keyframes[k].interpolation,
                            out: a.keyframes[k].easeOut, into: a.keyframes[k + 1].easeIn, curve: a.keyframes[k].curve)
            }
        }
        switch target {
        case .property(let key):
            switch key.access {
            case .scalar(let kp): return segs(an.properties[keyPath: kp])
            case .vector(let kp): return segs(an.properties[keyPath: kp])
            case .color(let kp): return segs(an.properties[keyPath: kp])
            }
        case .selector(let k, let v):
            let sels = an.allSelectors
            return sels.indices.contains(k) ? segs(sels[k][keyPath: v.path]) : []
        }
    }

    /// Segment k = keyframe k -> k+1; nil = every segment.
    func setTextEase(_ animatorID: UUID, _ target: TextEaseTarget, segment: Int?, interpolation: Interpolation,
                     out: EaseHandle, into: EaseHandle, continuous: Bool = false) {
        withTextAnimated(animatorID, target, { interps, outs, ins, curves in
            let n = interps.count
            guard n >= 2 else { return }
            for k in segment.map({ [$0] }) ?? Array(0..<(n - 1)) where k >= 0 && k + 1 < n {
                interps[k] = interpolation; outs[k] = out; ins[k + 1] = into; curves[k] = nil
            }
        }, label: "Ease \(target.title)", continuous: continuous)
    }
}

struct TextGraphEditorSheet: View {
    @ObservedObject var state: EditorState
    let animatorID: UUID
    /// What can be edited here (a picker shows when there is more than one).
    let targets: [TextEaseTarget]
    @State private var picked: TextEaseTarget?
    @State private var segment = 0
    @State private var applyToAll = false

    private var key: TextEaseTarget { picked ?? targets.first ?? .selector(0, .start) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if targets.count > 1 {
                    Picker("Value", selection: Binding(get: { key }, set: { picked = $0; segment = 0 })) {
                        ForEach(targets, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
                }
                let segs = state.textEaseSegments(animatorID, key)
                if segs.isEmpty {
                    ContentUnavailableView("Needs two keyframes", systemImage: "diamond",
                                           description: Text("Add at least two keyframes on \(key.title) to shape its easing."))
                } else {
                    let k = min(segment, segs.count - 1)
                    HStack(spacing: 10) {
                        Text("Segment").foregroundStyle(Theme.textDim)
                        Picker("", selection: $segment) {
                            ForEach(segs.indices, id: \.self) { i in
                                Text(String(format: "%.2fs → %.2fs", segs[i].t0, segs[i].t1)).tag(i)
                            }
                        }
                        Spacer()
                        Toggle("All", isOn: $applyToAll).tint(Theme.accent).fixedSize()
                    }
                    .font(.system(size: 14)).frame(minHeight: 44)
                    CurveEditor(segment: segs[k]) { out, into, done in
                        state.setTextEase(animatorID, key, segment: applyToAll ? nil : k, interpolation: .bezier,
                                          out: out, into: into, continuous: true)
                        if done { state.endEdit() }
                    }
                    .frame(height: 280)
                    Text("Presets").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textDim)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(EasePreset.all) { p in
                            Button {
                                state.setTextEase(animatorID, key, segment: applyToAll ? nil : k, interpolation: p.interpolation,
                                                  out: p.out, into: p.into)
                            } label: {
                                VStack(spacing: 4) {
                                    CurveThumb(preset: p).frame(height: 34)
                                    Text(p.name).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .foregroundStyle(Theme.text)
                                .padding(6).glass(radius: 9)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(Theme.background)
            .navigationTitle("\(key.title) Easing")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
