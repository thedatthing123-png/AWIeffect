import SwiftUI

/// Per-layer audio effects inside the Clip panel: EQ (3 bands + low/high cut), compressor, pitch and ducking.
/// Every value is a scrubber (drag or tap to type); one undo step per drag. Preview and export use the same chain.
struct AudioFXSection: View {
    @ObservedObject var state: EditorState
    let layer: Layer

    var body: some View {
        let fx = layer.audioFX ?? LayerAudioFX()
        VStack(alignment: .leading, spacing: 8) {
            title("EQUALIZER")
            row("Low Cut", fx.lowCut, 0...500, step: 5, unit: fx.lowCut <= 0 ? " Off" : " Hz") { v in { $0.lowCut = v < 20 ? 0 : v } }
            row("Low", fx.lowGain, -18...18, step: 0.5, unit: " dB") { v in { $0.lowGain = v } }
            row("Mid", fx.midGain, -18...18, step: 0.5, unit: " dB") { v in { $0.midGain = v } }
            row("Mid Freq", fx.midFrequency, 200...6000, step: 10, unit: " Hz") { v in { $0.midFrequency = v } }
            row("High", fx.highGain, -18...18, step: 0.5, unit: " dB") { v in { $0.highGain = v } }
            row("High Cut", fx.highCut <= 0 ? 20_000 : fx.highCut, 1000...20_000, step: 50, unit: fx.highCut <= 0 ? " Off" : " Hz") { v in
                { $0.highCut = v >= 19_950 ? 0 : v }
            }

            title("COMPRESSOR")
            Toggle("Compressor", isOn: Binding(get: { fx.compressor }, set: { v in state.setAudioFX("Compressor") { $0.compressor = v } }))
                .font(.system(size: 13)).tint(Theme.accent).foregroundStyle(Theme.text).frame(minHeight: 44)
            if fx.compressor {
                row("Threshold", fx.threshold, -60...0, step: 0.5, unit: " dB") { v in { $0.threshold = v } }
                row("Make-up", fx.makeup, 0...24, step: 0.5, unit: " dB") { v in { $0.makeup = v } }
            }

            title("PITCH")
            row("Pitch", fx.pitch, -12...12, step: 0.1, unit: " st") { v in { $0.pitch = v } }

            title("DUCKING")
            Menu {
                Button("Off") { state.setAudioFX("Ducking") { $0.duckUnder = nil } }
                ForEach(state.project.layers.filter { $0.hasAudio && $0.id != layer.id }) { other in
                    Button(other.name) { state.setAudioFX("Ducking") { $0.duckUnder = other.id } }
                }
            } label: {
                HStack {
                    Text("Duck Under").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
                    Text(duckName(fx)).font(.system(size: 13, weight: .semibold)).foregroundStyle(fx.duckUnder == nil ? Theme.textDim : Theme.accentGlow)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 10).frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            }
            if fx.duckUnder != nil {
                row("Amount", fx.duckAmount, -40...0, step: 0.5, unit: " dB") { v in { $0.duckAmount = v } }
                row("Release", fx.duckRelease, 0.05...2, step: 0.01, unit: "s") { v in { $0.duckRelease = v } }
                Text("This layer turns down while the chosen layer is sounding (voice-over over music).")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
            if layer.audioFX?.needsProcessing == true || layer.audioFX?.duckUnder != nil {
                Button("Reset Audio Effects", role: .destructive) {
                    state.setAudioFX("Reset Audio Effects") { fx in
                        let keep = (fx.fadeIn, fx.fadeOut, fx.fadeShape, fx.keepPitch)
                        fx = LayerAudioFX()
                        fx.fadeIn = keep.0; fx.fadeOut = keep.1; fx.fadeShape = keep.2; fx.keepPitch = keep.3
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func duckName(_ fx: LayerAudioFX) -> String {
        guard let id = fx.duckUnder else { return "Off" }
        return state.project.layers.first { $0.id == id }?.name ?? "Missing layer"
    }

    private func title(_ s: String) -> some View {
        Text(s).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim).padding(.top, 4)
    }

    /// `make(v)` returns the change for value v.
    private func row(_ title: String, _ value: Double, _ range: ClosedRange<Double>, step: Double, unit: String,
                     _ make: @escaping (Double) -> (inout LayerAudioFX) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
            ValueScrubber(value: value, range: range, step: step, unit: unit,
                          onBegin: { state.beginEdit(title) },
                          onChange: { v in state.editAudioFX(make(v)) },
                          onEnd: { state.endEdit(); AudioPreview.shared.invalidate() })
        }
        .frame(minHeight: 44)
    }
}
