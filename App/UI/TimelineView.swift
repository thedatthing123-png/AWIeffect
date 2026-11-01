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
    /// Decided on the first movement: true = horizontal (scrub), false = vertical (the list scrolls instead).
    @State private var scrubAxis: Bool?
    @State private var multiDragStart: CGPoint?
    /// Layer as it was when a clip / trim / keyframe drag began.
    @State private var dragOriginal: Layer?
    @State private var reorderFrom: Int?
    /// A clip held and lifted: drag up / down to change its layer order, sideways to move it in time.
    @State private var liftLayer: UUID?
    @State private var liftOffset: CGFloat = 0

    private let rowHeight: CGFloat = 46
    private let headerWidth: CGFloat = 60
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
                    .contentShape(Rectangle())
                    .onTapGesture { if state.isMultiSelecting { state.endMultiSelect() } else { state.select(nil) } }
                    // Header cells and track rows live in ONE scroll view so they always line up.
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            if state.project.layers.isEmpty {
                                VStack(spacing: 6) {
                                    Image(systemName: "square.stack.3d.up").font(.system(size: 26)).foregroundStyle(Theme.textDim.opacity(0.6))
                                    Text("Your layers will appear here").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textDim)
                                    Text("Tap Add, Text, Shapes or Media below to start").font(.caption).foregroundStyle(Theme.textDim.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity).padding(.top, 26)
                            }
                            ForEach(state.project.layers) { layer in
                                let lifted = liftLayer == layer.id
                                HStack(spacing: 0) {
                                    header(layer)
                                    layerRow(layer, offset: offset)
                                        .frame(width: trackWidth, height: rowHeight, alignment: .topLeading)
                                        .clipped()
                                }
                                .frame(height: rowHeight)
                                .scaleEffect(lifted ? 1.03 : 1)
                                .shadow(color: .black.opacity(lifted ? 0.5 : 0), radius: 8, y: 4)
                                .offset(y: lifted ? liftOffset : 0)
                                .zIndex(lifted ? 1 : 0)
                                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: lifted)
                            }
                        }
                        // Hold a row, then (without lifting) drag up/down to select a range.
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.3)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { v in
                                    guard case .second(true, let drag) = v, let drag else { return }
                                    // Alight Motion: holding the left column (eye / icon) selects; holding a clip lifts it.
                                    guard drag.startLocation.x < headerWidth else { return }
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
                    .scrollDisabled(multiDragStart != nil || liftLayer != nil)
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
            .coordinateSpace(name: "timeline")
            // Simultaneous so the layer list can still scroll up / down with many layers.
            .simultaneousGesture(scrub)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { zoom = min(600, max(15, zoomBase * $0)) }
                    .onEnded { _ in zoomBase = zoom }
            )
        }
        .background(Theme.surface)
        .onDisappear { if dragOriginal != nil { dragOriginal = nil; state.endEdit() } }
    }

    private func header(_ layer: Layer) -> some View {
        HStack(spacing: 6) {
            // Parts of a group get a colored bar so you can see what's inside it.
            if layer.groupID != nil {
                RoundedRectangle(cornerRadius: 1).fill(Theme.tagColor(.teal)).frame(width: 3, height: rowHeight - 10)
            }
            Button { state.toggleVisibility(layer.id) } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(layer.isVisible ? Theme.textDim : Theme.textDim.opacity(0.4))
                    .frame(width: 20, height: rowHeight)
            }
            .buttonStyle(.plain)
            Image(systemName: state.multiSelection?.contains(layer.id) == true ? "checkmark.circle.fill" : (layer.isGroup ? "folder.fill" : layer.content.symbol))
                .font(.system(size: 11))
                .foregroundStyle(state.multiSelection?.contains(layer.id) == true ? Theme.accentGlow : Theme.tagColor(layer.tag))
                .frame(width: 22, height: rowHeight)
                .contentShape(Rectangle())

        }
        .frame(width: headerWidth, height: rowHeight, alignment: .leading)
        .background(Theme.surface)
        .contentShape(Rectangle())
        // Tap in multi-select toggles; otherwise the left column only reacts to a hold (multi-select).
        .onTapGesture { if state.isMultiSelecting { state.toggleInMulti(layer.id) } }
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                if multiDragStart != nil || liftLayer != nil || dragOriginal != nil { return }
                if scrubAxis == nil { scrubAxis = abs(v.translation.width) >= abs(v.translation.height) }
                guard scrubAxis == true else { return }
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
            .onEnded { _ in scrubStart = nil; scrubAxis = nil }
    }

    private func ruler(width: CGFloat, offset: CGFloat) -> some View {
        RulerCanvas(width: width, offset: offset, zoom: zoom, duration: state.project.duration, cache: PreviewCacheMonitor.shared) { ctx, size in
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
        let editable = selected && !state.isMultiSelecting && !layer.isLocked
        let color = Theme.tagColor(layer.tag)
        let x0 = offset + CGFloat(layer.inPoint) * zoom
        let w = max(4, CGFloat(layer.outPoint - layer.inPoint) * zoom)
        return ZStack(alignment: .topLeading) {
            Color.clear
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(layer.isVisible ? (selected ? 0.95 : 0.6) : 0.25))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(selected ? Color.white : .clear, lineWidth: 1.5))
                .overlay(alignment: .leading) {
                    HStack(spacing: 4) {
                        if layer.isLocked { Image(systemName: "lock.fill").font(.system(size: 8)) }
                        if layer.isSolo { Text("S").font(.system(size: 9, weight: .black)) }
                        if layer.motionBlur { Image(systemName: "wind").font(.system(size: 8)) }
                        Text(layer.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, editable ? 16 : 8)
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
                // Hold a clip to lift it: up / down reorders, sideways moves it in time (snaps to frames, beats, playhead).
                .simultaneousGesture(clipHold(layer), including: state.isMultiSelecting ? .subviews : .all)
                .simultaneousGesture(TapGesture().onEnded {
                    guard liftLayer == nil, !state.isMultiSelecting else { return }
                    state.openLayer(layer.id)
                })
                .offset(x: x0, y: 4)
            if editable {
                trimHandle(layer, start: true).offset(x: x0 - 13, y: 2)
                trimHandle(layer, start: false).offset(x: x0 + max(w, 14) - 13, y: 2)
            }
            ForEach(Array(layer.keyframeTimes.enumerated()), id: \.offset) { _, t in
                Image(systemName: "diamond.fill")
                    .font(.system(size: editable ? 12 : 9))
                    .foregroundStyle(editable && abs(t - clock.time) < 1e-3 ? Theme.keyframe : .white)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
                    .position(x: offset + CGFloat(t) * zoom, y: rowHeight / 2)
                    // Drag keyframes (every property keyed at that time moves together); tap jumps to it.
                    .highPriorityGesture(keyDrag(layer, t), including: editable ? .all : .subviews)
                    .onTapGesture { if editable { state.seek(t) } else { state.select(layer.id) } }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if state.isMultiSelecting { state.toggleInMulti(layer.id) } else { state.openLayer(layer.id) }
        }
    }

    private func clipHold(_ layer: Layer) -> some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline")))
            .onChanged { v in
                guard case .second(true, let drag) = v else { return }
                if liftLayer == nil {
                    liftLayer = layer.id
                    dragOriginal = layer
                    state.pause()
                    state.beginEdit("Move Clip")
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                guard let g = drag, let o = dragOriginal else { return }
                liftOffset = g.translation.height
                let raw = o.inPoint + Double(g.translation.width / zoom)
                state.moveClip(o, by: state.snapTime(raw, tolerance: Double(8 / zoom)) - o.inPoint)
            }
            .onEnded { v in
                defer { liftLayer = nil; liftOffset = 0; dragOriginal = nil; state.endEdit() }
                guard case .second(true, let drag) = v, let drag,
                      let from = state.project.layers.firstIndex(where: { $0.id == layer.id }) else { return }
                let to = from + Int((drag.translation.height / rowHeight).rounded())
                if to != from {
                    state.endEdit()
                    state.reorderLayer(from: from, to: to)
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }

    private func clipDrag(_ layer: Layer) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("timeline"))
            .onChanged { g in
                if multiDragStart != nil || state.isMultiSelecting { return }
                if dragOriginal == nil { dragOriginal = layer; state.pause(); state.beginEdit("Move Clip") }
                guard let o = dragOriginal else { return }
                let raw = o.inPoint + Double(g.translation.width / zoom)
                state.moveClip(o, by: state.snapTime(raw, tolerance: Double(8 / zoom)) - o.inPoint)
            }
            .onEnded { _ in dragOriginal = nil; state.endEdit() }
    }

    private func keyDrag(_ layer: Layer, _ t: Double) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
            .onChanged { g in
                if dragOriginal == nil { dragOriginal = layer; state.pause(); state.beginEdit("Move Keyframes") }
                guard let o = dragOriginal else { return }
                state.moveKeyframes(of: o, from: t, to: state.snapTime(t + Double(g.translation.width / zoom), tolerance: Double(8 / zoom)))
            }
            .onEnded { _ in dragOriginal = nil; state.endEdit() }
    }

    private func trimHandle(_ layer: Layer, start: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(.white)
            .frame(width: 8, height: rowHeight - 14)
            .frame(width: 26, height: rowHeight - 4)
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("timeline"))
                .onChanged { g in
                    if dragOriginal == nil { dragOriginal = layer; state.pause(); state.beginEdit("Trim Clip") }
                    guard let o = dragOriginal else { return }
                    let edge = start ? o.inPoint : o.outPoint
                    let snapped = state.snapTime(edge + Double(g.translation.width / zoom), tolerance: Double(8 / zoom))
                    state.trimClip(o, start: start, by: snapped - edge)
                }
                .onEnded { _ in dragOriginal = nil; state.endEdit() })
            .accessibilityLabel(start ? "Trim start" : "Trim end")
    }
}


/// The ruler plus the green "frames ready" bar of the RAM preview.
struct RulerCanvas: View {
    let width: CGFloat
    let offset: CGFloat
    let zoom: CGFloat
    let duration: Double
    @ObservedObject var cache: PreviewCacheMonitor
    let draw: (inout GraphicsContext, CGSize) -> Void

    var body: some View {
        Canvas { ctx, size in
            // Green bar: contiguous runs of cached frames.
            let fps = max(cache.fps, 1)
            for range in cache.frames.rangeView {
                let x0 = offset + CGFloat(Double(range.lowerBound) / fps) * zoom
                let x1 = offset + CGFloat(Double(range.upperBound) / fps) * zoom
                guard x1 >= 0, x0 <= size.width else { continue }
                ctx.fill(Path(CGRect(x: max(0, x0), y: 0, width: min(size.width, x1) - max(0, x0), height: 3)), with: .color(Color.green.opacity(0.85)))
            }
            draw(&ctx, size)
        }
    }
}
