import SwiftUI

struct PixelMotionBlurControls: View {
    @ObservedObject var state: EditorState
    let layer: Layer
    private var supported: Bool {
        if case .video = layer.content { return true }
        if case .precomp = layer.content { return true }
        return false
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PIXEL MOTION BLUR").font(.caption.bold()).foregroundStyle(Theme.text)
            Text("Blurs motion inside footage or a precomp using estimated pixel movement. Layer Motion Blur above handles transforms, camera and linked motion.")
                .font(.caption).foregroundStyle(Theme.textDim)
            if supported {
                let fx = layer.timeFX ?? LayerTimeFX()
                Toggle("Pixel Motion Blur", isOn: Binding(get: { fx.pixelMotionBlur > 0 }, set: { enabled in
                    edit { $0.pixelMotionBlur = enabled ? 100 : 0 }
                })).tint(Theme.accent).foregroundStyle(Theme.text)
                row("Amount", fx.pixelMotionBlur, 0...400, "%") { value in edit { $0.pixelMotionBlur = value } }
                row("Samples", Double(fx.pixelBlurSamples ?? 12), 6...48, "") { value in edit { $0.pixelBlurSamples = Int(value.rounded()) } }
                row("Maximum trail", (fx.pixelBlurLimit ?? 0.15) * 100, 1...50, "%") { value in edit { $0.pixelBlurLimit = value / 100 } }
            } else {
                Text("Select a video, or precompose animated layers, to blur motion within the image.").font(.caption).foregroundStyle(Theme.textDim)
            }
        }
    }
    private func edit(_ change: (inout LayerTimeFX) -> Void) {
        state.coalescedEdit("Pixel Motion Blur") { layer in
            var fx = layer.timeFX ?? LayerTimeFX(); change(&fx)
            layer.timeFX = fx.isEmpty ? nil : fx
        }
    }
    private func row(_ title: String, _ value: Double, _ range: ClosedRange<Double>, _ unit: String, _ commit: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.text).frame(width: 100, alignment: .leading)
            ValueScrubber(value: value, range: range, step: 1, unit: unit, onChange: commit)
        }
    }
}
