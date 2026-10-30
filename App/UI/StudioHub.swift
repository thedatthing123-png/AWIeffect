import SwiftUI

/// One place to reach every studio, library and lab — from the top bar (grid button) and the empty bottom panel.
struct StudioHub: View {
    @ObservedObject var state: EditorState
    @Binding var showPhotoPicker: Bool
    @ObservedObject var drawLauncher: DrawLauncher
    @ObservedObject var mediaLauncher: MediaLauncher
    var compact = false
    var startPen: ((PenTarget, PenStyle) -> Void)? = nil
    var done: () -> Void = {}
    @State private var needsLayerHint = false

    private struct Item: Identifiable {
        let id: String
        let icon: String
        let color: Color
        let action: () -> Void
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 10 : 18) {
                section("Studios", [
                    Item(id: "Draw Studio", icon: "paintbrush.pointed.fill", color: .pink) { go { drawLauncher.open(nil) } },
                    Item(id: "Text Studio", icon: "textformat", color: .orange) { go { openText() } },
                    Item(id: "3D Text", icon: "cube.transparent", color: .cyan) { go { state.addModelLayer(text: "AWI", fileURL: nil) } },
                    Item(id: "Pen Path", icon: "pencil.tip", color: .mint) { go { if let startPen { startPen(.newShape, .points) } else { state.panel = .add } } },
                ])
                section("Libraries", [
                    Item(id: "Effects", icon: "sparkles", color: .purple) { go { needLayer(.effects) } },
                    Item(id: "Presets", icon: "wand.and.rays", color: .indigo) { go { needLayer(.presets) } },
                    Item(id: "Overlays", icon: "sun.haze", color: .yellow) { go { state.panel = .overlays } },
                    Item(id: "Text Presets", icon: "character.textbox", color: .orange) { go { openText() } },
                ])
                section("Media", [
                    Item(id: "Image", icon: "photo.on.rectangle", color: .green) { go { showPhotoPicker = true } },
                    Item(id: "Video", icon: "film", color: .blue) { go { mediaLauncher.pickVideo = true } },
                    Item(id: "Music", icon: "music.note", color: .red) { go { mediaLauncher.pickAudio = true } },
                    Item(id: "3D Model", icon: "shippingbox", color: .teal) { go { mediaLauncher.pickModel = true } },
                ])
                section("Labs", [
                    Item(id: "Physics Lab", icon: "atom", color: .cyan) { go { needLayer(.physics, adjustment: false) } },
                    Item(id: "3D View", icon: "rotate.3d", color: .purple) { go { state.viewMode = .orbit } },
                    Item(id: "Camera", icon: "video", color: .orange) { go { state.addCamera() } },
                    Item(id: "Beat Sync", icon: "metronome", color: .pink) { go { state.panel = .beats } },
                ])
            }
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 8 : 16)
        }
    }

    private func go(_ f: @escaping () -> Void) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        done()
        // Let a presenting sheet close before opening the next screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + (compact ? 0 : 0.35)) { f() }
    }

    /// Effects / presets / physics act on a layer: use the selection, or add an adjustment layer to work on.
    private func needLayer(_ panel: ToolPanel, adjustment: Bool = true) {
        if state.selectedLayer != nil { state.panel = panel; return }
        if adjustment && !state.project.layers.isEmpty {
            // Effects on everything below: an adjustment layer is exactly what AE / Alight Motion users reach for.
            state.addAdjustmentLayer(); state.panel = panel
        } else if let first = state.project.layers.first(where: { $0.content != .camera }) {
            state.select(first.id); state.panel = panel
        } else {
            state.panel = .add
        }
    }

    private func openText() {
        if case .text = state.selectedLayer?.content {} else { state.addText() }
        state.panel = .text
    }

    private func section(_ title: String, _ items: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(items) { it in
                    Button(action: it.action) {
                        VStack(spacing: 6) {
                            Image(systemName: it.icon).font(.system(size: compact ? 18 : 22, weight: .semibold))
                                .foregroundStyle(it.color)
                                .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(it.color.opacity(0.15)))
                            Text(it.id).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.text)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(it.id)
                }
            }
        }
    }
}
