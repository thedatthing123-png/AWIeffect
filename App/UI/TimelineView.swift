import SwiftUI

/// Alight Motion-style layer timeline: fixed playhead in the center, content scrolls under it.
struct TimelineView: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var clock: PlayClock
    /// Only the selected layer's row (a panel is open).
    var compact = false

    init(state: EditorState, compact: Bool = false) {
        self.state = state
        self.compact = compact
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
    @State private var keyDragTime: Double?
    @State private var liftLayer: UUID?
    @State private var liftOffset: CGFloat = 0
    /// Clips moved together while several layers are selected.
    @State private var multiOriginals: [Layer] = []
    /// Layers twirled open (one lane per animated property under the row).
    @State private var expanded: Set<UUID> = []
    @State private var keySel: KeySelection?
    @State private var selDragBase: KeySelection?
    @State private var selDragOriginal: Layer?
    @State private var stretchShown = 100.0
    @State private var marquee: (layer: UUID, lane0: Int, t0: Double, lane1: Int, t1: Double)?
    @State private var graphTarget: GraphTarget?
    @State private var showMarkers = false
    @State private var slipOriginal: Layer?
    @AppStorage("awi.rulerFrames") private var rulerFrames = false

    private let rowHeight: CGFloat = 46
    private let laneHeight: CGFloat = 44
    private let headerWidth: CGFloat = 132
    private let rulerHeight: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let trackWidth = max(1, geo.size.width - headerWidth)
            // Playhead sits at the screen's horizontal center (track coordinates).
            let playheadX = geo.size.width / 2 - headerWidth
            let offset = playheadX - CGFloat(clock.time) * zoom
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Menu {
                            Button { state.addMarker(onLayer: false) } label: { Label("Add Comp Marker", systemImage: "flag.fill") }
                            if state.selectedLayer != nil {
                                Button { state.addMarker(onLayer: true) } label: { Label("Add Layer Marker", systemImage: "flag") }
                            }
                            Button { showMarkers = true } label: { Label("Markers…", systemImage: "list.bullet") }
                            Toggle("Frame Numbers", isOn: $rulerFrames)
                        } label: {
                            HStack(spacing: 4) {
                                Text(rulerFrames ? "\(Int((clock.time * state.project.fps).rounded()))f" : formatTimecode(clock.time, fps: state.project.fps))
                                    .accessibilityIdentifier("timeline-timecode")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.accentGlow)
                                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textDim)
                            }
                            .frame(width: headerWidth, height: rulerHeight)
                            .contentShape(Rectangle())
                        }
                        .frame(width: headerWidth, height: rulerHeight)
                        .accessibilityLabel("Ruler and markers")
                        ruler(width: trackWidth, offset: offset)
                            .frame(width: trackWidth, height: rulerHeight)
                            .gesture(TimelineHorizontalPan(
                canBegin: { multiDragStart == nil && liftLayer == nil && dragOriginal == nil },
                onChange: scrubHorizontal,
                onEnd: { scrubStart = nil; scrubAxis = nil }))
                            .clipped()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { if state.isMultiSelecting { state.endMultiSelect() } else { state.select(nil) } }
                    // Header cells and track rows live in ONE scroll view so they always line up.
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            if state.project.layers.isEmpty {
                                VStack(spacing: 6) {
                                    Image(systemName: "square.stack.3d.up").font(.system(size: 26)).foregroundStyle(Theme.textDim.opacity(0.6))
                                    Text("Your layers will appear here").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textDim)
                                    Text("Tap Add, Text, Shapes or Media below to start").font(.caption).foregroundStyle(Theme.textDim.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity).padding(.top, 26)
                            }
                            ForEach(compact ? state.project.layers.filter { $0.id == state.selectedLayerID } : state.project.timelineLayers) { layer in
                                let lifted = liftLayer == layer.id
                                HStack(spacing: 0) {
                                    header(layer)
                                    layerRow(layer, offset: offset)
                                        .frame(width: trackWidth, height: rowHeight, alignment: .topLeading)
                                        .clipped()
                                }
                                .frame(height: rowHeight)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("timeline-row-\(layer.name)")
                                .scaleEffect(lifted ? 1.03 : 1)
                                .shadow(color: .black.opacity(lifted ? 0.5 : 0), radius: 8, y: 4)
                                .offset(y: lifted ? liftOffset : 0)
                                .zIndex(lifted ? 1 : 0)
                                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: lifted)
                                if !compact, expanded.contains(layer.id) {
                                    lanes(layer, offset: offset, trackWidth: trackWidth)
                                }
                            }
                        }

                    }
                    .frame(maxHeight: .infinity)
                    .accessibilityIdentifier("layer-timeline-scroll")
                    .scrollDisabled(multiDragStart != nil || dragOriginal != nil || marquee != nil || selDragOriginal != nil)
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
                        .frame(width: 44, height: rulerHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: headerWidth + playheadX - 22)
                .accessibilityLabel("Add beat marker")
            }
            .contentShape(Rectangle())
            .coordinateSpace(name: "timeline")
            // Simultaneous so the layer list can still scroll up / down with many layers.

            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { zoom = min(600, max(15, zoomBase * $0)) }
                    .onEnded { _ in zoomBase = zoom }
            )
        }
        .background(Theme.surface)
        .onDisappear {
            if dragOriginal != nil || selDragOriginal != nil || slipOriginal != nil {
                dragOriginal = nil; selDragOriginal = nil; slipOriginal = nil; state.endEdit()
            }
        }
        .awiSheet(isPresented: Binding(get: { graphTarget != nil }, set: { if !$0 { graphTarget = nil } })) {
            if let g = graphTarget { TimelineGraphSheet(state: state, target: g) }
        }
        .awiSheet(isPresented: $showMarkers) { TimelineMarkersSheet(state: state) }
    }

    // MARK: Property lanes

    @ViewBuilder
    private func lanes(_ layer: Layer, offset: CGFloat, trackWidth: CGFloat) -> some View {
        let list = layer.propertyLanes()
        ForEach(Array(list.enumerated()), id: \.element.id) { index, lane in
            HStack(spacing: 0) {
                Button { if lane.graphable { graphTarget = GraphTarget(layerID: layer.id, laneID: lane.id) } } label: {
                    HStack(spacing: 4) {
                        Text(lane.title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.text)
                            .lineLimit(2).multilineTextAlignment(.leading).minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        if lane.graphable {
                            Image(systemName: "chart.xyaxis.line").font(.system(size: 10)).foregroundStyle(Theme.accentGlow)
                        }
                    }
                    .padding(.leading, 14).padding(.trailing, 6)
                    .frame(width: headerWidth, height: laneHeight, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Theme.background.opacity(0.6))
                .accessibilityLabel(lane.graphable ? "\(lane.title) graph" : lane.title)
                laneTrack(layer, lane, index: index, lanes: list, offset: offset)
                    .frame(width: trackWidth, height: laneHeight, alignment: .topLeading)
                    .clipped()
            }
            .frame(height: laneHeight)
            .accessibilityIdentifier("timeline-lane-\(lane.title)")
        }
        if let sel = keySel, sel.layerID == layer.id, !sel.isEmpty {
            HStack(spacing: 8) {
                Text("\(sel.count) keys").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textDim)
                    .frame(width: headerWidth - 8, alignment: .leading).padding(.leading, 8)
                ValueScrubber(value: stretchShown, range: 10...400, step: 1, unit: "%", onBegin: {
                    selDragBase = keySel; selDragOriginal = state.project.layers.first { $0.id == layer.id }
                    state.pause(); state.beginEdit("Stretch Keyframes")
                }, onChange: { pct in
                    stretchShown = pct
                    guard let o = selDragOriginal, let base = selDragBase else { return }
                    if let s = state.stretchKeySelection(of: o, base, factor: pct / 100) { keySel = s }
                }, onEnd: {
                    selDragBase = nil; selDragOriginal = nil; stretchShown = 100; state.endEdit()
                })
                .frame(height: 36)
                .accessibilityLabel("Stretch keyframes")
                Button {
                    if let l = state.project.layers.first(where: { $0.id == layer.id }), let s = keySel,
                       let r = state.reverseKeySelection(of: l, s) { keySel = r }
                } label: {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Reverse keyframes")
                Button { keySel = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Clear key selection")
            }
            .foregroundStyle(Theme.text)
            .padding(.trailing, 6)
            .frame(height: laneHeight)
            .background(Theme.raised)
        }
    }

    private func laneTrack(_ layer: Layer, _ lane: PropertyLane, index: Int, lanes: [PropertyLane], offset: CGFloat) -> some View {
        let x = { (t: Double) in offset + CGFloat(t) * zoom }
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.white.opacity(index % 2 == 0 ? 0.03 : 0.015))
            if let m = marquee, m.layer == layer.id, (min(m.lane0, m.lane1)...max(m.lane0, m.lane1)).contains(index) {
                let a = x(min(m.t0, m.t1)), b = x(max(m.t0, m.t1))
                Rectangle().fill(Theme.accent.opacity(0.22))
                    .overlay(Rectangle().stroke(Theme.accentGlow, lineWidth: 1))
                    .frame(width: max(1, b - a), height: laneHeight).offset(x: a)
                    .allowsHitTesting(false)
            }
            ForEach(lane.times, id: \.self) { t in
                let picked = keySel?.layerID == layer.id && keySel?.contains(lane.id, t) == true
                Image(systemName: "diamond.fill")
                    .font(.system(size: picked ? 14 : 11))
                    .foregroundStyle(picked ? Theme.keyframe : .white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .position(x: x(t), y: laneHeight / 2)
                    .onTapGesture {
                        var s = (keySel?.layerID == layer.id ? keySel : nil) ?? KeySelection(layerID: layer.id)
                        s.toggle(lane.id, t)
                        keySel = s.isEmpty ? nil : s
                    }
                    .highPriorityGesture(laneKeyDrag(layer, lane, t))
                    .accessibilityLabel("\(lane.title) key at \(String(format: "%.2f", t)) seconds\(picked ? ", selected" : "")")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { keySel = nil }
        .gesture(LongPressGesture(minimumDuration: 0.3).sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                let toT = { (px: CGFloat) in max(0, Double((px - offset) / zoom)) }
                let lane1 = max(0, min(lanes.count - 1, index + Int(floor(drag.location.y / laneHeight))))
                if marquee == nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                marquee = (layer.id, index, toT(drag.startLocation.x), lane1, toT(drag.location.x))
                if let m = marquee {
                    let s = KeySelection.marquee(layerID: layer.id, lanes: lanes, laneRange: min(m.lane0, m.lane1)...max(m.lane0, m.lane1), from: m.t0, to: m.t1)
                    keySel = s.isEmpty ? nil : s
                }
            }
            .onEnded { _ in marquee = nil })
    }

    /// Dragging a key moves the whole selection (an unselected key becomes the selection first).
    private func laneKeyDrag(_ layer: Layer, _ lane: PropertyLane, _ t: Double) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
            .onChanged { g in
                if selDragOriginal == nil {
                    guard let original = state.project.layers.first(where: { $0.id == layer.id }), !original.isLocked else { return }
                    var s = keySel ?? KeySelection(layerID: layer.id)
                    if s.layerID != layer.id || !s.contains(lane.id, t) { s = KeySelection(layerID: layer.id, keys: [lane.id: [t]]) }
                    keySel = s; selDragBase = s; selDragOriginal = original
                    state.pause(); state.beginEdit("Move Keyframes")
                }
                guard let o = selDragOriginal, let base = selDragBase, let earliest = base.allTimes.min() else { return }
                let target = state.snapTime(earliest + Double(g.translation.width / zoom), tolerance: Double(8 / zoom))
                if let moved = state.moveKeySelection(of: o, base, by: target - earliest) { keySel = moved }
            }
            .onEnded { _ in
                guard selDragOriginal != nil else { return }
                selDragOriginal = nil; selDragBase = nil; state.endEdit()
            }
    }

    private func header(_ layer: Layer) -> some View {
        let inMulti = state.multiSelection?.contains(layer.id) == true
        return HStack(spacing: 0) {
            headerToggle(layer.id, layer.isVisible ? "eye" : "eye.slash", on: layer.isVisible, tint: Theme.text,
                         label: layer.isVisible ? "Hide Layer" : "Show Layer") { state.toggleVisibility(layer.id) }
            headerToggle(layer.id, layer.isLocked ? "lock.fill" : "lock.open", on: layer.isLocked, tint: Theme.warning,
                         label: layer.isLocked ? "Unlock Layer" : "Lock Layer") { state.toggleLock(layer.id) }
            headerToggle("s.circle\(layer.isSolo ? ".fill" : "")", on: layer.isSolo, tint: Theme.ok,
                         label: layer.isSolo ? "Unsolo Layer" : "Solo Layer") { state.toggleSolo(layer.id) }
        }
        .frame(width: headerWidth, height: rowHeight, alignment: .leading)
        // Parts of a group get a colored bar so you can see what's inside it; the layer's own tag sits beside it.
        .overlay(alignment: .leading) {
            HStack(spacing: 1) {
                if let tag = state.groupMemberTag(of: layer) {
                    RoundedRectangle(cornerRadius: 1).fill(Theme.tagColor(tag)).frame(width: 3, height: rowHeight - 10)
                }
                RoundedRectangle(cornerRadius: 1).fill(inMulti ? Theme.accentGlow : Theme.tagColor(layer.tag)).frame(width: 3, height: rowHeight - 10)
            }
            .allowsHitTesting(false)
        }
        .background(inMulti ? Theme.accent.opacity(0.22) : Theme.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline-header-\(layer.name)")
        .accessibilityValue(state.multiSelection?.contains(layer.id) == true ? "Selected" : "Not selected")
        .contentShape(Rectangle())
        // Tap in multi-select toggles; otherwise the left column only reacts to a hold (multi-select).
        .onTapGesture { if state.isMultiSelecting { state.toggleInMulti(layer.id) } }
        .gesture(TimelineHold(onMove: { point, delta in
            guard !compact, let index = state.project.timelineLayers.firstIndex(where: { $0.id == layer.id }) else { return }
            if multiDragStart == nil {
                multiDragStart = point; state.beginMultiSelect(layer.id)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            state.extendMultiSelect(toRow: index + Int((delta.y / rowHeight).rounded()))
        }, onEnd: { _ in multiDragStart = nil }))
    }

    private func headerToggle(_ id: UUID, _ icon: String, on: Bool, tint: Color, label: String, _ action: @escaping () -> Void) -> some View {
        // A tap, not a Button: a Button swallows the header's hold, which starts range selection.
        Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            .foregroundStyle(on ? tint : Theme.textDim.opacity(0.55))
            .frame(width: 44, height: rowHeight)
            .contentShape(Rectangle())
            .onTapGesture { if state.isMultiSelecting { state.toggleInMulti(id) } else { action() } }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .accessibilityAction { if state.isMultiSelecting { state.toggleInMulti(id) } else { action() } }
    }

    private func scrubHorizontal(_ translation: CGFloat) {
        guard multiDragStart == nil, liftLayer == nil, dragOriginal == nil else { return }
        if scrubStart == nil { state.pause(); scrubStart = state.currentTime }
        let t = (scrubStart ?? 0) - Double(translation / zoom)
        let clamped = min(max(t, 0), state.project.duration)
        let snapped = state.project.snapToFrame(state.snapToMarker(clamped, tolerance: Double(6 / zoom)))
        if snapped != state.currentTime {
            state.currentTime = snapped
            if state.selectedLayer?.keyframeTimes.contains(where: { abs($0 - snapped) < 1e-4 }) == true {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    private func ruler(width: CGFloat, offset: CGFloat) -> some View {
        RulerCanvas(width: width, offset: offset, zoom: zoom, duration: state.project.duration, cache: PreviewCacheMonitor.shared) { ctx, size in
            let dur = state.project.duration
            // Choose a tick step that keeps labels readable.
            let fps = state.project.fps
            let step = TimelineRuler.step(zoom: zoom, fps: fps, frames: rulerFrames)
            var t = 0.0
            while t <= dur + 1e-9 {
                let x = offset + CGFloat(t) * zoom
                if x >= -40 && x <= size.width + 40 {
                    ctx.fill(Path(CGRect(x: x, y: size.height - 8, width: 1, height: 8)), with: .color(Theme.textDim.opacity(0.6)))
                    let label = TimelineRuler.label(t, step: step, fps: fps, frames: rulerFrames)
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
            // Named comp markers: colored flag with its name.
            for m in state.project.compMarkers ?? [] {
                let x = offset + CGFloat(m.time) * zoom
                guard x >= -80, x <= size.width + 6 else { continue }
                let c = Theme.tagColor(m.tag)
                ctx.fill(Path(CGRect(x: x - 0.75, y: 0, width: 1.5, height: size.height)), with: .color(c))
                var flag = Path()
                flag.move(to: CGPoint(x: x, y: 2)); flag.addLine(to: CGPoint(x: x + 8, y: 6)); flag.addLine(to: CGPoint(x: x, y: 10)); flag.closeSubpath()
                ctx.fill(flag, with: .color(c))
                if !m.name.isEmpty {
                    ctx.draw(Text(m.name).font(.system(size: 9, weight: .bold)).foregroundColor(c), at: CGPoint(x: x + 10, y: 6), anchor: .leading)
                }
            }
            // Comp end marker.
            let endX = offset + CGFloat(dur) * zoom
            ctx.fill(Path(CGRect(x: endX, y: 0, width: 2, height: size.height)), with: .color(Theme.danger.opacity(0.7)))
        }
        .overlay(alignment: .topLeading) {
            // Tap a comp marker to rename / recolor / move / delete it.
            ForEach(state.project.compMarkers ?? []) { m in
                Color.clear.frame(width: 44, height: rulerHeight).contentShape(Rectangle())
                    .position(x: offset + CGFloat(m.time) * zoom + 8, y: rulerHeight / 2)
                    .onTapGesture { showMarkers = true }
                    .accessibilityLabel("Marker \(m.name)")
            }
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
                        Image(systemName: state.multiSelection?.contains(layer.id) == true ? "checkmark.circle.fill" : (layer.isGroup ? "folder.fill" : layer.content.symbol))
                            .font(.system(size: 10))
                        if layer.motionBlur { Image(systemName: "wind").font(.system(size: 8)) }
                        Text(layer.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, (editable ? 24 : 8) + (canTwirl(layer) && w >= 120 ? 40 : 0))
                    .offset(x: max(0, -x0))
                    .allowsHitTesting(false)
                }
                .overlay {
                    if layer.hasAudio, let file = layer.mediaFile {
                        WaveformStrip(url: state.mediaURL(file), speed: layer.speed, sourceStart: layer.sourceStart,
                                      pointsPerSecond: zoom)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: w, height: rowHeight - 8)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(layer.name)
                .accessibilityIdentifier("timeline-clip-\(layer.name)")
                // Hold a clip to lift it: up / down reorders, sideways moves it in time (snaps to frames, beats, playhead).

                .offset(x: x0, y: 4)
            // Layer markers (they travel with the clip).
            ForEach(layer.layerMarkers ?? []) { m in
                let mx = x0 + CGFloat(m.time) * zoom
                Rectangle().fill(Theme.tagColor(m.tag)).frame(width: 2, height: rowHeight - 8)
                    .overlay(alignment: .topLeading) {
                        Text(m.name).font(.system(size: 8, weight: .bold)).foregroundStyle(.white).fixedSize()
                            .padding(.horizontal, 3).background(Theme.tagColor(m.tag)).offset(x: 2)
                    }
                    .offset(x: mx, y: 4).allowsHitTesting(false)
            }
            if editable {
                trimHandle(layer, start: true).offset(x: x0 - 22, y: 1)
                trimHandle(layer, start: false).offset(x: x0 + max(w, 14) - 22, y: 1)
                if layer.isMedia, layer.timeRemap == nil, w >= 170 { slipGrip(layer).offset(x: x0 + w / 2 - 22, y: 1) }
            }
            if canTwirl(layer) {
                // Twirl: one lane per animated property opens under the row.
                let open = expanded.contains(layer.id)
                Button {
                    if open { expanded.remove(layer.id) } else { expanded.insert(layer.id) }
                    if keySel?.layerID == layer.id && open { keySel = nil }
                } label: {
                    Image(systemName: open ? "chevron.down" : "chevron.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: rowHeight - 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: w >= 120 ? max(x0, 0) + (editable ? 22 : 2) : x0 + w + 22, y: 2)
                .accessibilityLabel(open ? "Close property lanes" : "Open property lanes")
            }
            // Open effects: each one's keys show in its own color and only those move; the rest fade back.
            let focused = editable ? state.keyframeFocusEffects.filter { id in layer.effects.contains { $0.id == id } } : []
            if focused.isEmpty {
                ForEach(layer.keyframeMarkers, id: \.id) { marker in
                    keyMarker(layer, marker.time, offset: offset, color: editable && abs(marker.time - clock.time) < 1e-3 ? Theme.keyframe : .white, effect: nil)
                }
            } else {
                ForEach(layer.keyframeMarkers, id: \.id) { marker in
                    Image(systemName: "diamond.fill").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                        .frame(width: 22, height: 22).position(x: offset + CGFloat(marker.time) * zoom, y: rowHeight / 2)
                        .allowsHitTesting(false)
                }
                ForEach(Array(focused.enumerated()), id: \.element) { k, effect in
                    ForEach(layer.keyframeMarkers(effect: effect), id: \.id) { marker in
                        keyMarker(layer, marker.time, offset: offset, color: EditorState.focusColors[k % EditorState.focusColors.count], effect: effect)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard !state.isMultiSelecting else { return }
            state.select(layer.id)
            if layer.isGroup { state.openGroup() }
            else if case .precomp = layer.content { state.openPrecomp() }
            else { state.openLayer(layer.id) }
        }
        .onTapGesture {
            if state.isMultiSelecting { state.toggleInMulti(layer.id) } else { state.openLayer(layer.id) }
        }
        .gesture(TimelineHold(onMove: { _, delta in
                    // Several layers selected: holding one of them moves them all in time together.
                    if let multi = state.multiSelection {
                        guard multi.contains(layer.id) else { return }
                        if multiOriginals.isEmpty {
                            multiOriginals = state.project.timelineLayers.filter { multi.contains($0.id) && !$0.isLocked }
                            guard !multiOriginals.isEmpty else { return }
                            liftLayer = layer.id; state.pause(); state.beginEdit("Move Clips")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        let start = multiOriginals.map(\.inPoint).min() ?? 0
                        state.moveClips(multiOriginals, by: state.snapTime(start + Double(delta.x / zoom), tolerance: Double(8 / zoom)) - start)
                        return
                    }
                    guard !layer.isLocked else { return }
                    if liftLayer == nil {
                        liftLayer = layer.id; dragOriginal = layer; state.pause(); state.beginEdit("Move Clip")
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    guard let original = dragOriginal else { return }
                    liftOffset = delta.y
                    let time = original.inPoint + Double(delta.x / zoom)
                    state.moveClip(original, by: state.snapTime(time, tolerance: Double(8 / zoom)) - original.inPoint)
                }, onEnd: { delta in
                    if !multiOriginals.isEmpty { multiOriginals = []; liftLayer = nil; state.endEdit(); return }
                    guard dragOriginal != nil else { return }
                    defer { liftLayer = nil; liftOffset = 0; dragOriginal = nil; state.endEdit() }
                    if let from = state.project.timelineLayers.firstIndex(where: { $0.id == layer.id }) {
                        let to = from + Int((delta.y / rowHeight).rounded())
                        if from != to { state.endEdit(); state.reorderTimelineLayer(layer.id, to: to) }
                    }
                }))
    }

    /// A keyframe diamond: drag moves every property keyed at that time (or just `effect`'s keys); tap jumps to it.
    private func keyMarker(_ layer: Layer, _ t: Double, offset: CGFloat, color: Color, effect: UUID?) -> some View {
        let editable = state.selectedLayerID == layer.id
        return Image(systemName: "diamond.fill")
            .font(.system(size: editable ? 12 : 9))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.5), radius: 1)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .position(x: offset + CGFloat(t) * zoom, y: rowHeight / 2)
            .highPriorityGesture(keyDrag(layer, t, effect: effect), including: editable ? .all : .subviews)
            .onTapGesture { if editable { state.seek(t) } else { state.select(layer.id) } }
            .accessibilityLabel(effect != nil ? "Effect keyframe at \(String(format: "%.2f", t)) seconds" : "Keyframe at \(String(format: "%.2f", t)) seconds")
    }

    private func keyDrag(_ layer: Layer, _ t: Double, effect: UUID? = nil) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
            .onChanged { g in
                if dragOriginal == nil { dragOriginal = layer; keyDragTime = t; state.pause(); state.beginEdit("Move Keyframes") }
                guard let o = dragOriginal else { return }
                let origin = keyDragTime ?? t
                state.moveKeyframes(of: o, from: origin, to: state.snapTime(origin + Double(g.translation.width / zoom), tolerance: Double(8 / zoom)), effect: effect)
            }
            .onEnded { _ in dragOriginal = nil; keyDragTime = nil; state.endEdit() }
    }

    private func canTwirl(_ layer: Layer) -> Bool { !compact && !layer.keyframeMarkers.isEmpty }

    /// Slip grip in the middle of a selected media clip: drag sideways to change which source frames play under
    /// the clip, without moving or resizing it.
    private func slipGrip(_ layer: Layer) -> some View {
        Image(systemName: "arrow.left.and.right")
            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            .frame(width: 30, height: 22)
            .background(Capsule().fill(.black.opacity(0.45)))
            .frame(width: 44, height: rowHeight - 2)
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("timeline"))
                .onChanged { g in
                    if slipOriginal == nil { slipOriginal = layer; state.pause(); state.beginEdit("Slip Clip") }
                    guard let o = slipOriginal else { return }
                    // Drag right = see earlier source frames (the footage slides right under the clip).
                    let frames = (Double(-g.translation.width / zoom) * state.project.fps).rounded()
                    state.slipClip(o, by: frames / state.project.fps)
                }
                .onEnded { _ in if slipOriginal != nil { slipOriginal = nil; state.endEdit() } })
            .accessibilityLabel("Slip clip")
    }

    private func trimHandle(_ layer: Layer, start: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(.white)
            .frame(width: 8, height: rowHeight - 14)
            .frame(width: 44, height: rowHeight - 2)
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
