import SwiftUI

struct SmoothSceneControls: View {
    @ObservedObject var state: EditorState
    let layer: Layer

    private var strength: Double { min(100, max(0, layer.smoothSceneStrength ?? 0)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Smooth Scene", isOn: Binding(get: { strength > 0 }, set: { on in
                state.mutate("Smooth Scene") { project in
                    guard let index = project.layers.firstIndex(where: { $0.id == layer.id }) else { return }
                    project.layers[index].smoothSceneStrength = on ? 65 : nil
                }
            }))
            .frame(minHeight: 44)
            .font(.system(size: 14, weight: .semibold))
            .tint(Theme.accent)
            .accessibilityIdentifier("smooth-scene-toggle")

            if strength > 0 {
                HStack(spacing: 8) {
                    Text("Strength").font(.caption)
                    ValueScrubber(value: strength, range: 1...100, step: 1, unit: "%",
                                  onBegin: { state.beginEdit("Smooth Scene Strength") },
                                  onChange: { next in
                                      guard state.selectedLayer?.id == layer.id else { return }
                                      state.mutateLayer { $0.smoothSceneStrength = next }
                                  },
                                  onEnd: { state.endEdit() })
                        .frame(height: 44)
                        .accessibilityLabel("Smooth Scene strength")
                }
                .frame(minHeight: 44)
                Text(layer.content == .camera
                     ? "Eases supported motion during this cameraâ€™s active shot."
                     : "Eases supported motion on layers below during this layerâ€™s span.")
                    .font(.caption)
                    .foregroundStyle(Theme.textDim)
            }
        }
        .foregroundStyle(Theme.text)
    }
}
