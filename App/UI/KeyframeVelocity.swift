import SwiftUI

/// AE "Keyframe Velocity": at the playhead's keyframe, type the incoming / outgoing influence and speed.
/// Influence = how long the ease reaches along the segment; speed 0% = full ease (stops), 100% = linear.
struct KeyframeVelocitySheet: View {
    @ObservedObject var state: EditorState
    @Environment(\.dismiss) private var dismiss
    @State private var inInfluence = 33.33
    @State private var inSpeed = 0.0
    @State private var outInfluence = 33.33
    @State private var outSpeed = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(state.hasKeyframeAtPlayhead ? "Applies to every transform keyframe of this layer at the playhead."
                                                     : "Move the playhead onto a keyframe first.")
                        .font(.caption)
                }
                Section("Incoming (before the keyframe)") {
                    row("Influence", $inInfluence, 0.1...100, "%")
                    row("Speed", $inSpeed, 0...300, "%")
                }
                Section("Outgoing (after the keyframe)") {
                    row("Influence", $outInfluence, 0.1...100, "%")
                    row("Speed", $outSpeed, 0...300, "%")
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        state.applyKeyframeVelocity(inInfluence: inInfluence / 100, inSpeed: inSpeed / 100,
                                                    outInfluence: outInfluence / 100, outSpeed: outSpeed / 100)
                        dismiss()
                    }
                    .disabled(!state.hasKeyframeAtPlayhead)
                }
            }
        }
    }

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
        keyframes[k].interpolation = .bezier
        keyframes[k].easeOut = EaseHandle(x: oi, y: oi * outSpeed)
        if k > 0 {
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
    }

    func applyKeyframeVelocity(inInfluence: Double, inSpeed: Double, outInfluence: Double, outSpeed: Double) {
        guard let i = selectedIndex else { return }
        let t = currentTime
        mutate("Keyframe Velocity") { p in
            func v<V: Interpolatable>(_ a: inout Animated<V>) {
                a.setVelocity(at: t, inInfluence: inInfluence, inSpeed: inSpeed, outInfluence: outInfluence, outSpeed: outSpeed)
            }
            v(&p.layers[i].transform.position); v(&p.layers[i].transform.scale); v(&p.layers[i].transform.rotation)
            v(&p.layers[i].transform.opacity); v(&p.layers[i].transform.anchor); v(&p.layers[i].transform.positionZ)
            v(&p.layers[i].transform.rotationX); v(&p.layers[i].transform.rotationY)
        }
    }
}
