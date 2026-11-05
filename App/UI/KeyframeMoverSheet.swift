import SwiftUI

struct KeyframeMoverSheet: View {
    @ObservedObject var state: EditorState
    @Environment(\.dismiss) private var dismiss
    @State private var selection = Set<UUID>()
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let layer = state.selectedLayer {
                    if layer.keyframeTimes.isEmpty { Text("This layer has no keyframes yet.") }
                    ForEach(layer.keyframeMarkers, id: \.id) { marker in
                        HStack {
                            Button {
                                if selection.contains(marker.id) { selection.remove(marker.id) } else { selection.insert(marker.id) }
                                message = nil
                            } label: {
                                Image(systemName: selection.contains(marker.id) ? "checkmark.circle.fill" : "circle")
                                    .frame(width: 36, height: 36)
                            }.accessibilityLabel("Select keyframe at \(marker.time)")
                            Button { state.seek(marker.time) } label: {
                                Text(String(format: "%.3f s", marker.time)).monospacedDigit()
                            }
                            Spacer()
                        }.buttonStyle(.borderless)
                    }
                    Section {
                        let times = layer.keyframeMarkers.filter { selection.contains($0.id) }.map(\.time)
                        Text("\(times.count) selected · moves every property keyed at those times together")
                            .font(.caption).foregroundStyle(Theme.textDim)
                        HStack {
                            Button("−1 frame") { move(layer, times: times, delta: -state.project.frameDuration) }
                            Spacer()
                            Button("To Playhead") { move(layer, times: times, delta: state.currentTime - (times.min() ?? state.currentTime)) }
                            Spacer()
                            Button("+1 frame") { move(layer, times: times, delta: state.project.frameDuration) }
                        }.buttonStyle(.borderless).disabled(times.isEmpty)
                        if let message { Text(message).font(.caption).foregroundStyle(Theme.textDim) }
                    }
                }
            }
            .navigationTitle("Move Keyframes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(selection.isEmpty ? "Select All" : "Clear") {
                        selection = selection.isEmpty ? Set(state.selectedLayer?.keyframeMarkers.map(\.id) ?? []) : []
                        message = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func move(_ layer: Layer, times: [Double], delta: Double) {
        guard !times.isEmpty, abs(delta) > 1e-8 else { return }
        state.beginEdit("Move Keyframes")
        let result = state.moveKeyframeSelection(of: layer, times: times, by: delta)
        state.endEdit()
        message = result == nil ? "That destination is occupied. No keyframes were replaced." : nil
    }
}
