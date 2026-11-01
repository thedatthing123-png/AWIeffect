import SwiftUI

/// Tapping a clip opens this: every section the layer has as big tiles, grouped by what you want to do,
/// so anything is one tap away (no long lists).
struct LayerHomePanel: View {
    @ObservedObject var state: EditorState
    @EnvironmentObject private var drawLauncher: DrawLauncher

    struct Tile: Identifiable {
        let id: String
        let icon: String
        var panel: ToolPanel? = nil
        var action: (() -> Void)? = nil
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: state.selectedLayer?.name ?? "Layer")
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(groups, id: \.0) { g in
                        if !g.1.isEmpty {
                            Text(g.0.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textDim)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                ForEach(g.1) { tile($0) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
    }

    private func tile(_ t: Tile) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if let p = t.panel { state.panel = p }
            t.action?()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: t.icon).font(.system(size: 19, weight: .medium))
                Text(t.id).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.raised))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.id)
    }

    private var groups: [(String, [Tile])] {
        guard let l = state.selectedLayer else { return [] }
        let c = l.content
        let visual = c != .camera && c != .light && !l.isAudioOnly
        var move: [Tile] = [Tile(id: c == .camera ? "Camera" : "Move & Transform", icon: "arrow.up.and.down.and.arrow.left.and.right", panel: .transform)]
        var look: [Tile] = []
        var fx: [Tile] = []
        var timing: [Tile] = []
        var layer: [Tile] = []
        switch c {
        case .text: look.append(Tile(id: "Text Studio", icon: "textformat", panel: .text))
        case .shape: look.append(Tile(id: "Edit Shape", icon: "skew", panel: .shape))
        case .model: look.append(Tile(id: "3D Model", icon: "cube.transparent", panel: .model))
        case .precomp: layer.append(Tile(id: "Open Comp", icon: "arrow.down.right.and.arrow.up.left") { state.openPrecomp() })
        default: break
        }
        switch c {
        case .shape, .solid, .text: look.append(Tile(id: "Color & Fill", icon: "paintpalette", panel: .fill))
        default: break
        }
        if visual && c != .adjustment {
            look.append(Tile(id: "Border & Shadow", icon: "square.dashed", panel: .style))
            look.append(Tile(id: "Blending", icon: "circle.lefthalf.filled", panel: .blending))
        }
        if l.isImage || (l.isMedia && !l.isAudioOnly) { look.append(Tile(id: "Remove BG", icon: "person.crop.rectangle.badge.plus", panel: .cutout)) }
        if l.drawingID != nil || (l.mediaFile != nil && !l.isAudioOnly) {
            look.append(Tile(id: l.drawingID != nil ? "Drawing" : "Redraw", icon: "paintbrush.pointed.fill") { drawLauncher.open(state.selectedLayerID) })
        }
        if visual { fx.append(Tile(id: "Effects", icon: "sparkles", panel: .effects)) }
        if visual || c == .adjustment { fx.append(Tile(id: "CC Studio", icon: "camera.filters", panel: .ccStudio)) }
        if visual { fx.append(Tile(id: "Presets", icon: "wand.and.rays", panel: .presets)) }
        if visual && c != .adjustment { fx.append(Tile(id: "Masks", icon: "theatermask.and.paintbrush", panel: .masks)) }
        if visual { fx.append(Tile(id: "Motion Blur", icon: "wind", panel: .motionBlur)) }
        move.append(Tile(id: "Graph", icon: "point.topleft.down.to.point.bottomright.curvepath", panel: .graph))
        if !l.isAudioOnly {
            move.append(Tile(id: c == .camera ? "Lens & 3D" : (c == .light ? "Light" : "3D"),
                             icon: c == .camera ? "camera.aperture" : (c == .light ? "lightbulb.fill" : "cube"), panel: .threeD))
        }
        if visual && c != .text { move.append(Tile(id: "Puppet", icon: "hand.point.up.braille", panel: .puppet)) }
        if visual { move.append(Tile(id: "Rig", icon: "figure.arms.open", panel: .rig)) }
        if visual && c != .adjustment { move.append(Tile(id: "Physics", icon: "atom", panel: .physics)) }
        if l.isMedia || l.isAudioOnly { timing.append(Tile(id: "Speed & Volume", icon: "speedometer", panel: .clip)) }
        if case .video = c { timing.append(Tile(id: "Twixtor", icon: "tortoise.fill", panel: .clip)) }
        if visual { timing.append(Tile(id: "Time", icon: "timer", panel: .time)) }
        layer.append(Tile(id: "Duplicate", icon: "plus.square.on.square") { state.duplicateSelected() })
        layer.append(Tile(id: "Parent & More", icon: "square.3.layers.3d", panel: .layerMenu))
        return [("Move", move), ("Look", look), ("Effects", fx), ("Timing", timing), ("Layer", layer)]
    }
}
