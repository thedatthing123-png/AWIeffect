import SwiftUI

/// AE "Keyframe Velocity": at the playhead's keyframe, type the incoming / outgoing influence and speed.
/// Influence = how long the ease reaches along the segment; speed 0% = full ease (stops), 100% = linear.
struct KeyframeVelocitySheet: View {
    @ObservedObject var state: EditorState
    var property: PropertyKey? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var inInfluence = 33.33
    @State private var inSpeed = 0.0
    @State private var outInfluence = 33.33
    @State private var outSpeed = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(canApply ? "Applies to \(property?.title ?? "all transform") keyframes at the playhead."
                                                     : "Move the playhead onto a keyframe first.")
                        .font(.caption)
                }
                Section("Incoming (before the keyframe)") {
                    row("Influence", $inInfluence, 0.1...100, "%")
                    row("Speed", $inSpeed, -1000...1000, "%")
                }
                Section("Outgoing (after the keyframe)") {
                    row("Influence", $outInfluence, 0.1...100, "%")
                    row("Speed", $outSpeed, -1000...1000, "%")
                }
                Section {
                    HStack {
                        Button("Easy Ease") { inInfluence = 33.33; outInfluence = 33.33; inSpeed = 0; outSpeed = 0 }
                        Spacer()
                        Button("Strong Ease") { inInfluence = 80; outInfluence = 80; inSpeed = 0; outSpeed = 0 }
                        Spacer()
                        Button("Linear") { inInfluence = 33.33; outInfluence = 33.33; inSpeed = 100; outSpeed = 100 }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .navigationTitle("Keyframe Velocity")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        state.applyKeyframeVelocity(inInfluence: inInfluence / 100, inSpeed: inSpeed / 100,
                                                    outInfluence: outInfluence / 100, outSpeed: outSpeed / 100, property: property)
                        dismiss()
                    }
                    .disabled(!canApply)
                }
            }
        }
        .onAppear {
            if let v = state.keyframeVelocity(property: property) {
                inInfluence = v.inInfluence * 100; outInfluence = v.outInfluence * 100
                inSpeed = v.inSpeed * 100; outSpeed = v.outSpeed * 100
            }
        }
    }

    private var canApply: Bool { property.map { state.hasKeyframe($0) } ?? state.hasKeyframeAtPlayhead }

    private func row(_ t: String, _ v: Binding<Double>, _ r: ClosedRange<Double>, _ unit: String) -> some View {
        HStack {
            Text(t).frame(width: 80, alignment: .leading)
            ValueScrubber(value: v.wrappedValue, range: r, step: 0.01, unit: unit, onChange: { v.wrappedValue = $0 })
        }
    }
}

extension Animated {
    /// Sets the bezier handles around the keyframe at `t` (AE influence + speed, speed relative to linear).
    mutating func setVelocity(at t: Double, inInfluence: Double, inSpeed: Double, outInfluence: Double, outSpeed: Double) {
        guard let k = keyframes.firstIndex(where: { abs($0.time - t) < 1e-4 }) else { return }
        let oi = min(max(outInfluence, 0.001), 1), ii = min(max(inInfluence, 0.001), 1)
        keyframes[k].curve = nil
        keyframes[k].reversedSegment = nil
        keyframes[k].interpolation = .bezier
        keyframes[k].easeOut = EaseHandle(x: oi, y: oi * outSpeed)
        if k > 0 {
            keyframes[k - 1].curve = nil
            keyframes[k - 1].reversedSegment = nil
            keyframes[k - 1].interpolation = .bezier
            keyframes[k].easeIn = EaseHandle(x: 1 - ii, y: 1 - ii * inSpeed)
        } else {
            keyframes[k].easeIn = EaseHandle(x: 1 - ii, y: 1 - ii * inSpeed)
        }
    }
}

extension EditorState {
    var hasKeyframeAtPlayhead: Bool {
        guard let l = selectedLayer else { return false }
        let t = currentTime, tr = l.transform
        return tr.position.hasKeyframe(at: t) || tr.scale.hasKeyframe(at: t) || tr.rotation.hasKeyframe(at: t)
            || tr.opacity.hasKeyframe(at: t) || tr.anchor.hasKeyframe(at: t) || tr.positionZ.hasKeyframe(at: t)
            || tr.rotationX.hasKeyframe(at: t) || tr.rotationY.hasKeyframe(at: t)
    }

    func applyKeyframeVelocity(inInfluence: Double, inSpeed: Double, outInfluence: Double, outSpeed: Double, property: PropertyKey? = nil) {
        guard let i = selectedIndex else { return }
        let t = currentTime
        mutate("Keyframe Velocity") { p in
            func v<V: Interpolatable>(_ a: inout Animated<V>) {
                a.setVelocity(at: t, inInfluence: inInfluence, inSpeed: inSpeed, outInfluence: outInfluence, outSpeed: outSpeed)
            }
            switch property {
            case .position?, .positionZ?: v(&p.layers[i].transform.position); v(&p.layers[i].transform.positionZ)
            case .scale?: v(&p.layers[i].transform.scale)
            case .rotation?: v(&p.layers[i].transform.rotation)
            case .opacity?: v(&p.layers[i].transform.opacity)
            case .anchor?: v(&p.layers[i].transform.anchor)
            case .rotationX?: v(&p.layers[i].transform.rotationX)
            case .rotationY?: v(&p.layers[i].transform.rotationY)
            case .size?: v(&p.layers[i].size)
            case .fill?: v(&p.layers[i].fill)
            case .cornerRadius?: v(&p.layers[i].cornerRadius)
            case nil:
                v(&p.layers[i].transform.position); v(&p.layers[i].transform.positionZ)
                v(&p.layers[i].transform.scale); v(&p.layers[i].transform.rotation)
                v(&p.layers[i].transform.opacity); v(&p.layers[i].transform.anchor)
                v(&p.layers[i].transform.rotationX); v(&p.layers[i].transform.rotationY)
            }
        }
    }
}

struct KeyframeVelocityValues {
    var inInfluence: Double, inSpeed: Double, outInfluence: Double, outSpeed: Double
}

extension EditorState {
    func keyframeVelocity(property: PropertyKey?) -> KeyframeVelocityValues? {
        guard let layer = selectedLayer else { return nil }
        func read<V>(_ a: Animated<V>) -> KeyframeVelocityValues? {
            guard let k = a.keyframeIndex(at: currentTime) else { return nil }
            let incoming = k > 0 && a.keyframes[k - 1].interpolation == .bezier ? a.keyframes[k].easeIn : .linearIn
            let outgoing = a.keyframes[k].interpolation == .bezier ? a.keyframes[k].easeOut : .linearOut
            let ii = max(0.001, 1 - incoming.x), oi = max(0.001, outgoing.x)
            return KeyframeVelocityValues(inInfluence: ii, inSpeed: (1 - incoming.y) / ii, outInfluence: oi, outSpeed: outgoing.y / oi)
        }
        switch property {
        case .position?, .positionZ?: return read(layer.transform.position) ?? read(layer.transform.positionZ)
        case .scale?: return read(layer.transform.scale)
        case .rotation?: return read(layer.transform.rotation)
        case .opacity?: return read(layer.transform.opacity)
        case .anchor?: return read(layer.transform.anchor)
        case .rotationX?: return read(layer.transform.rotationX)
        case .rotationY?: return read(layer.transform.rotationY)
        case .size?: return read(layer.size)
        case .fill?: return read(layer.fill)
        case .cornerRadius?: return read(layer.cornerRadius)
        case nil: return read(layer.transform.position) ?? read(layer.transform.scale) ?? read(layer.transform.rotation)
        }
    }
}
