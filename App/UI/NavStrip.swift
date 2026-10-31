import SwiftUI

/// Alight Motion-style category strip at the bottom of the editor. With nothing selected it offers what you can add;
/// with a layer selected it lists only the property groups that layer type actually has. Tapping one opens its panel
/// above the strip (the panel is resizable, so nothing ever covers the canvas or timeline).
struct NavStrip: View {
    @ObservedObject var state: EditorState
    @Binding var showPhotoPicker: Bool
    var startPen: (PenTarget, PenStyle) -> Void
    @EnvironmentObject private var drawLauncher: DrawLauncher
    @EnvironmentObject private var mediaLauncher: MediaLauncher
    @State private var showGraph = false

    struct Item: Identifiable {
        let id: String
        let icon: String
        var panel: ToolPanel? = nil
        var action: (() -> Void)? = nil
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(items) { it in
                    let active = it.panel != nil && it.panel == state.panel
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if let p = it.panel { state.panel = active ? .none : p }
                        it.action?()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: it.icon).font(.system(size: 18, weight: .medium))
                            Text(it.id).font(.system(size: 9.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(active ? Theme.accentGlow : Theme.text)
                        .frame(width: 66, height: 54)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(active ? Theme.accent.opacity(0.22) : .clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(it.id)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 60)
        .background(Theme.surface)
        .sheet(isPresented: $showGraph) { GraphEditorSheet(state: state).presentationDetents([.large]) }
    }

    private var items: [Item] {
        if state.isMultiSelecting {
            return [Item(id: "Selection", icon: "checklist", panel: .multi)]
        }
        guard let l = state.selectedLayer else { return addItems }
        var out: [Item] = []
        let c = l.content
        let visual = c != .camera && c != .light && !l.isAudioOnly
        out.append(Item(id: c == .camera ? "Camera" : "Transform", icon: "arrow.up.and.down.and.arrow.left.and.right", panel: .transform))
        switch c {
        case .text: out.append(Item(id: "Text", icon: "textformat", panel: .text))
        case .shape: out.append(Item(id: "Edit Shape", icon: "skew", panel: .shape))
        case .model: out.append(Item(id: "3D Model", icon: "cube.transparent", panel: .model))
        case .precomp: out.append(Item(id: "Open Comp", icon: "arrow.down.right.and.arrow.up.left") { state.openPrecomp() })
        default: break
        }
        if l.drawingID != nil { out.append(Item(id: "Drawing", icon: "paintbrush.pointed.fill") { drawLauncher.open(state.selectedLayerID) }) }
        else if l.mediaFile != nil, !l.isAudioOnly { out.append(Item(id: "Redraw", icon: "paintbrush.pointed.fill") { drawLauncher.open(state.selectedLayerID) }) }
        if visual { out.append(Item(id: "Effects", icon: "sparkles", panel: .effects)) }
        if visual { out.append(Item(id: "Presets", icon: "wand.and.rays", panel: .presets)) }
        switch c {
        case .shape, .solid, .text: out.append(Item(id: "Color & Fill", icon: "paintpalette", panel: .fill))
        default: break
        }
        if visual && c != .adjustment {
            out.append(Item(id: "Border & Shadow", icon: "square.dashed", panel: .style))
            out.append(Item(id: "Blending", icon: "circle.lefthalf.filled", panel: .blending))
            out.append(Item(id: "Masks", icon: "theatermask.and.paintbrush", panel: .masks))
        }
        // Background removal right after Transform for photos and videos, so it's easy to find.
        if l.isImage || (l.isMedia && !l.isAudioOnly) { out.insert(Item(id: "Remove BG", icon: "person.crop.rectangle.badge.plus", panel: .cutout), at: 1) }
        if l.isMedia || l.isAudioOnly { out.append(Item(id: "Speed & Volume", icon: "speedometer", panel: .clip)) }
        if visual { out.append(Item(id: "Motion Blur", icon: "wind", panel: .motionBlur)) }
        if visual { out.append(Item(id: "Time", icon: "timer", panel: .time)) }
        if !l.isAudioOnly { out.append(Item(id: c == .camera ? "Lens" : (c == .light ? "Light" : "3D"), icon: c == .camera ? "camera.aperture" : (c == .light ? "lightbulb.fill" : "cube"), panel: .threeD)) }
        out.append(Item(id: "Easing", icon: "point.topleft.down.to.point.bottomright.curvepath") { showGraph = true })
        if visual && c != .adjustment { out.append(Item(id: "Physics", icon: "atom", panel: .physics)) }
        out.append(Item(id: "Layer", icon: "square.3.layers.3d", panel: .layerMenu))
        return out
    }

    private var addItems: [Item] {
        [Item(id: "Add", icon: "plus.circle.fill", panel: .add),
         Item(id: "Text", icon: "textformat") { state.addText() },
         Item(id: "Shapes", icon: "star.fill", panel: .add),
         Item(id: "Media", icon: "photo.on.rectangle") { showPhotoPicker = true },
         Item(id: "Video", icon: "film") { mediaLauncher.pickVideo = true },
         Item(id: "Draw", icon: "paintbrush.pointed.fill") { drawLauncher.open(nil) },
         Item(id: "Music", icon: "music.note") { mediaLauncher.pickAudio = true },
         Item(id: "Library", icon: "books.vertical.fill", panel: .overlays),
         Item(id: "3D Scene", icon: "square.3.layers.3d", panel: .scene3D),
         Item(id: "Beats", icon: "metronome", panel: .beats),
         Item(id: "Scene", icon: "gearshape", panel: .scene)]
    }
}
