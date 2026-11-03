import SwiftUI

struct KeyframeMoverSheet: View {
    @ObservedObject var state: EditorState
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if let layer = state.selectedLayer {
                    if layer.keyframeTimes.isEmpty { Text("This layer has no keyframes yet.") }
                    ForEach(layer.keyframeTimes, id: \.self) { time in
                        HStack {
                            Button { state.seek(time) } label: { Text(String(format: "%.3f s", time)).monospacedDigit() }
                            Spacer()
                            Button { move(layer, from: time, to: time - state.project.frameDuration) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Move one frame earlier")
                            Button("To Playhead") { move(layer, from: time, to: state.currentTime) }
                            Button { move(layer, from: time, to: time + state.project.frameDuration) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Move one frame later")
                        }.buttonStyle(.borderless)
                    }
                }
            }
            .navigationTitle("Move Keyframes")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func move(_ layer: Layer, from: Double, to: Double) {
        guard to >= 0, abs(from - to) > state.project.frameDuration * 0.1 else { return }
        state.beginEdit("Move Keyframes")
        state.moveKeyframes(of: layer, from: from, to: to)
        state.endEdit()
    }
}
