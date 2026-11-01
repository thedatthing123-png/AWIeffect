import SwiftUI

extension EditorState {
    /// 2D camera (films every layer like Alight Motion) or 3D camera (orbit / dolly / fly through 3D layers).
    /// Switching to 3D makes the visual layers 3D so the camera actually sees them in depth.
    func setCamera3D(_ on: Bool) {
        guard let i = selectedIndex, project.layers[i].content == .camera else { return }
        mutate(on ? "3D Camera" : "2D Camera") { p in
            p.layers[i].camera?.affects2D = !on
            if on {
                for k in p.layers.indices where !p.layers[k].isAudioOnly && p.layers[k].content != .camera
                    && p.layers[k].content != .light && p.layers[k].content != .adjustment { p.layers[k].is3D = true }
            }
        }
        cameraView = true
    }
}

/// Big 2D | 3D switch for the selected camera.
struct CameraModeSwitch: View {
    @ObservedObject var state: EditorState
    let layer: Layer

    var body: some View {
        let is3D = EditorState.cameraIs3D(layer)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                seg("2D Camera", "rectangle", !is3D) { state.setCamera3D(false) }
                seg("3D Camera", "cube", is3D) { state.setCamera3D(true) }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.surface))
            Text(is3D ? "3D: one finger orbits, pinch moves closer / farther, two fingers slide, twist rolls."
                      : "2D: drag the canvas to move the shot, pinch to zoom, twist to turn.")
                .font(.system(size: 11)).foregroundStyle(Theme.textDim)
        }
    }

    private func seg(_ title: String, _ icon: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(on ? Theme.accent : .clear))
                .foregroundStyle(on ? .white : Theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Bottom-bar camera button: a small menu for Camera view / Free view, the grid and the view zoom.
struct ViewMenuButton: View {
    @ObservedObject var state: EditorState
    @Binding var viewZoom: CGFloat
    @Binding var zoomBase: CGFloat
    @Binding var viewPan: CGSize
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Image(systemName: state.cameraView ? "video.fill" : "video.slash.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 31, height: 38)
                .foregroundStyle(state.cameraView && state.project.layers.contains { $0.content == .camera } ? Theme.ok : Theme.text)
        }
        .accessibilityLabel("View options")
        .popover(isPresented: $open) {
            VStack(alignment: .leading, spacing: 10) {
                Text("VIEW").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                HStack(spacing: 6) {
                    pick("Camera View", "video.fill", state.cameraView) { state.cameraView = true }
                    pick("Free View", "video.slash.fill", !state.cameraView) { state.cameraView = false }
                }
                Text(state.cameraView ? "You see what the camera films (what you export)." : "Look around freely; the camera shows as a white frame.")
                    .font(.system(size: 11)).foregroundStyle(Theme.textDim)
                Toggle("Grid", isOn: $state.showGrid).tint(Theme.accent).foregroundStyle(Theme.text).font(.system(size: 13, weight: .semibold))
                HStack(spacing: 8) {
                    Text("Zoom").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    Spacer()
                    Button { setZoom(viewZoom / 1.25) } label: { Image(systemName: "minus").frame(width: 34, height: 30) }
                    Button { setZoom(1); viewPan = .zero } label: {
                        Text("\(Int((viewZoom * 100).rounded()))%").font(.system(size: 12, weight: .bold, design: .monospaced)).frame(width: 52, height: 30)
                    }
                    Button { setZoom(viewZoom * 1.25) } label: { Image(systemName: "plus").frame(width: 34, height: 30) }
                }
                .foregroundStyle(Theme.text)
            }
            .padding(14)
            .frame(width: 290)
            .background(Theme.background)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func setZoom(_ z: CGFloat) { withAnimation(.easeOut(duration: 0.18)) { viewZoom = min(8, max(0.25, z)); zoomBase = viewZoom } }

    private func pick(_ title: String, _ icon: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 10).fill(on ? Theme.accent : Theme.raised))
            .foregroundStyle(on ? .white : Theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
