import SwiftUI

/// Alight Motion-style layer timeline: fixed playhead in the center, content scrolls under it.
struct TimelineView: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var clock: PlayClock

    init(state: EditorState) {
        self.state = state
        _clock = ObservedObject(wrappedValue: state.clock)
    }
    /// Points per second.
    @State private var zoom: CGFloat = 90
    @State private var zoomBase: CGFloat = 90
    @State private var scrubStart: Double?
    @State private var multiDragStart: CGPoint?

    private let rowHeight: CGFloat = 34
    private let headerWidth: CGFloat = 52
    private let rulerHeight: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let trackWidth = max(1, geo.size.width - headerWidth)
            // Playhead sits at the screen's horizontal center (track coordinates).
            let playheadX = geo.size.width / 2 - headerWidth
            let offset = playheadX - CGFloat(clock.time) * zoom
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text(formatTimecode(clock.time, fps: state.project.fps))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.accentGlow)
                            .frame(width: headerWidth, height: rulerHeight)
                        ruler(width: trackWidth, offset: offset)
                            .frame(width: trackWidth, height: rulerHeight)
                            .clipped()
                    }
                    // Header cells and track rows live in ONE scroll view so they always line up.
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(state.project.layers) { layer in
                                HStack(spacing: 0) {
                                    header(layer)
                                    layerRow(layer, offset: offset)
                                        .frame(width: trackWidth, height: rowHeight)
                                        .clipped()
                                }
                                .frame(height: rowHeight)
                            }
                        }
                        // Hold a row, then (without lifting) drag up/down to select a range.
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.35)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { v in
                                    guard case .second(true, let drag) = v, let drag else { return }
                                    if multiDragStart == nil {
                                        let row = Int(drag.startLocation.y / rowHeight)
                                        if state.project.layers.indices.contains(row) {
                                            if !state.isMultiSelecting { state.beginMultiSelect(state.project.layers[row].id) }
                                            else { state.multiAnchor = state.project.layers[row].id }
                                        }
                                        multiDragStart = drag.startLocation
                                    }
                                    state.extendMultiSelect(toRow: Int(drag.location.y / rowHeight))
                                }
                                .onEnded { _ in multiDragStart = nil }
                        )
                    }
                    .scrollDisabled(multiDragStart != nil)
                }
                // Playhead.
                Rectangle().fill(.white).frame(width: 1.5)
                    .offset(x: headerWidth + playheadX - 0.75)
                    .allowsHitTesting(false)
                // Tap the playhead head to drop / remove a beat marker (works while playing: tap along to the music).
                Button { state.toggleBeatMarker() } label: {
                    let onBeat = state.project.markers.contains { abs($0 - clock.time) < state.project.frameDuration * 1.5 }
                    Image(systemName: onBeat ? "diamond.fill" : "plus.diamond.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(onBeat ? Theme.warning : .white)
                        .frame(width: 34, height: rulerHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: headerWidth + playheadX - 17)
                .accessibilityLabel("Add beat marker")
            }
            .contentShape(Rectangle())
            .gesture(scrub)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { zoom = min(600, max(15, zoomBase * $0)) }
                    .onEnded { _ in zoomBase = zoom }
            )
        }
        .background(Theme.surface)
    }

    private func header(_ layer: Layer) -> some View {
        HStack(spacing: 6) {
            Button { state.toggleVisibility(layer.id) } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(layer.isVisible ? Theme.textDim : Theme.textDim.opacity(0.4))
                    .frame(width: 20, height: rowHeight)
            }
            .buttonStyle(.plain)
            Image(systemName: state.multiSelection?.contains(layer.id) == true ? "checkmark.circle.fill" : layer.content.symbol)
                .font(.system(size: 11))
                .foregroundStyle(state.multiSelection?.contains(layer.id) == true ? Theme.accentGlow : Theme.tagColor(layer.tag))
        }
        .frame(width: headerWidth, height: rowHeight)
        .background(Theme.surface)
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                if multiDragStart != nil || state.isMultiSelecting { return }
                if scrubStart == nil { state.pause(); scrubStart = state.currentTime }
                let t = (scrubStart ?? 0) - Double(v.translation.width / zoom)
                // Snap to beat markers within ~6 pt.
                let clamped = min(max(t, 0), state.project.duration)
                let snapped = state.project.snapToFrame(state.snapToMarker(clamped, tolerance: Double(6 / zoom)))
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
            // Beat markers.
            for m in state.project.markers {
                let x = offset + CGFloat(m) * zoom
                guard x >= -6, x <= size.width + 6 else { continue }
                var tri = Path()
                tri.move(to: CGPoint(x: x - 4, y: size.height - 9)); tri.addLine(to: CGPoint(x: x + 4, y: size.height - 9))
                tri.addLine(to: CGPoint(x: x, y: size.height - 2)); tri.closeSubpath()
                ctx.fill(tri, with: .color(Theme.warning))
            }
            // Comp end marker.
            let endX = offset + CGFloat(dur) * zoom
            ctx.fill(Path(CGRect(x: endX, y: 0, width: 2, height: size.height)), with: .color(Theme.danger.opacity(0.7)))
        }
    }

    private func layerRow(_ layer: Layer, offset: CGFloat) -> some View {
        let selected = state.multiSelection.map { $0.contains(layer.id) } ?? (layer.id == state.selectedLayerID)
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
                .overlay {
                    if layer.hasAudio, let file = layer.mediaFile {
                        WaveformStrip(url: state.mediaURL(file), speed: layer.speed, sourceStart: layer.sourceStart,
                                      pointsPerSecond: zoom)
                            .allowsHitTesting(false)
                    }
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
        .onTapGesture {
            if state.isMultiSelecting { state.toggleInMulti(layer.id) } else { state.select(selected ? nil : layer.id) }
        }
    }
}
