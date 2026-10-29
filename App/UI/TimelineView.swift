import SwiftUI

/// Alight Motion-style layer timeline: fixed playhead in the center, content scrolls under it.
struct TimelineView: View {
    @ObservedObject var state: EditorState
    /// Points per second.
    @State private var zoom: CGFloat = 90
    @State private var zoomBase: CGFloat = 90
    @State private var scrubStart: Double?

    private let rowHeight: CGFloat = 34
    private let headerWidth: CGFloat = 52
    private let rulerHeight: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width - headerWidth
            let playheadX = trackWidth / 2
            HStack(spacing: 0) {
                // Layer header column (visibility + icon), stays fixed.
                VStack(spacing: 0) {
                    Text(formatTimecode(state.currentTime, fps: state.project.fps))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.accentGlow)
                        .frame(height: rulerHeight)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(state.project.layers) { layer in
                                HStack(spacing: 6) {
                                    Button { state.toggleVisibility(layer.id) } label: {
                                        Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                                            .font(.system(size: 11))
                                            .foregroundStyle(layer.isVisible ? Theme.textDim : Theme.textDim.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                    Image(systemName: layer.content.symbol)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.tagColor(layer.tag))
                                }
                                .frame(width: headerWidth, height: rowHeight)
                            }
                        }
                    }
                }
                .frame(width: headerWidth)

                // Scrolling track area.
                ZStack(alignment: .topLeading) {
                    let offset = playheadX - CGFloat(state.currentTime) * zoom
                    VStack(spacing: 0) {
                        ruler(width: trackWidth, offset: offset)
                            .frame(height: rulerHeight)
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(state.project.layers) { layer in
                                    layerRow(layer, offset: offset)
                                        .frame(height: rowHeight)
                                }
                            }
                        }
                    }
                    // Playhead.
                    Rectangle().fill(.white).frame(width: 1.5)
                        .offset(x: playheadX - 0.75)
                        .allowsHitTesting(false)
                }
                .frame(width: trackWidth)
                .clipped()
                .contentShape(Rectangle())
                .gesture(scrub)
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { zoom = min(600, max(15, zoomBase * $0)) }
                        .onEnded { _ in zoomBase = zoom }
                )
            }
        }
        .background(Theme.surface)
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                if scrubStart == nil { state.pause(); scrubStart = state.currentTime }
                let t = (scrubStart ?? 0) - Double(v.translation.width / zoom)
                let snapped = state.project.snapToFrame(min(max(t, 0), state.project.duration))
                if snapped != state.currentTime {
                    state.currentTime = snapped
                    if state.selectedLayer?.keyframeTimes.contains(where: { abs($0 - snapped) < 1e-4 }) == true {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
            }
            .onEnded { _ in scrubStart = nil }
    }

    private func ruler(width: CGFloat, offset: CGFloat) -> some View {
        Canvas { ctx, size in
            let dur = state.project.duration
            // Choose a tick step that keeps labels readable.
            let steps: [Double] = [0.1, 0.25, 0.5, 1, 2, 5, 10, 30, 60]
            let step = steps.first { CGFloat($0) * zoom >= 60 } ?? 60
            var t = 0.0
            while t <= dur + 1e-9 {
                let x = offset + CGFloat(t) * zoom
                if x >= -40 && x <= size.width + 40 {
                    ctx.fill(Path(CGRect(x: x, y: size.height - 8, width: 1, height: 8)), with: .color(Theme.textDim.opacity(0.6)))
                    let label = step < 1 ? String(format: "%.2fs", t) : "\(Int(t))s"
                    ctx.draw(Text(label).font(.system(size: 9, design: .monospaced)).foregroundColor(Theme.textDim),
                             at: CGPoint(x: x + 3, y: 8), anchor: .leading)
                }
                // Minor ticks at frame-ish resolution.
                let minor = step / 5
                for k in 1..<5 {
                    let mx = offset + CGFloat(t + Double(k) * minor) * zoom
                    if t + Double(k) * minor <= dur, mx >= 0, mx <= size.width {
                        ctx.fill(Path(CGRect(x: mx, y: size.height - 4, width: 1, height: 4)), with: .color(Theme.textDim.opacity(0.3)))
                    }
                }
                t += step
            }
            // Comp end marker.
            let endX = offset + CGFloat(dur) * zoom
            ctx.fill(Path(CGRect(x: endX, y: 0, width: 2, height: size.height)), with: .color(Theme.danger.opacity(0.7)))
        }
    }

    private func layerRow(_ layer: Layer, offset: CGFloat) -> some View {
        let selected = layer.id == state.selectedLayerID
        let color = Theme.tagColor(layer.tag)
        let x0 = offset + CGFloat(layer.inPoint) * zoom
        let w = max(4, CGFloat(layer.outPoint - layer.inPoint) * zoom)
        return ZStack(alignment: .topLeading) {
            Color.clear
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(layer.isVisible ? (selected ? 0.95 : 0.6) : 0.25))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(selected ? Color.white : .clear, lineWidth: 1.5))
                .overlay(alignment: .leading) {
                    Text(layer.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        .lineLimit(1).padding(.leading, 8)
                        .offset(x: max(0, -x0))
                }
                .frame(width: w, height: rowHeight - 8)
                .offset(x: x0, y: 4)
            ForEach(layer.keyframeTimes, id: \.self) { t in
                Image(systemName: "diamond.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .position(x: offset + CGFloat(t) * zoom, y: rowHeight / 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { state.select(selected ? nil : layer.id) }
        .onLongPressGesture {
            state.select(layer.id)
            state.panel = .layerMenu
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}
