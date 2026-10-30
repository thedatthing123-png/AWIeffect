import SwiftUI
import PhotosUI

struct EditorView: View {
    @StateObject var state: EditorState
    let close: () -> Void
    @State private var showExport = false
    @State private var showHistory = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var canvasDragState: CanvasDrag?
    /// Viewport zoom / pan (view only — doesn't change the comp). Pinch to zoom, drag empty canvas to pan, double-tap to reset.
    @State private var viewZoom: CGFloat = 1
    @State private var zoomBase: CGFloat = 1
    @State private var viewPan: CGSize = .zero
    @State private var panBase: CGSize?
    @State private var pen: (target: PenTarget, style: PenStyle)?
    @StateObject private var drawLauncher = DrawLauncher()
    @StateObject private var mediaLauncher = MediaLauncher()
    @StateObject private var trackLauncher = TrackLauncher()
    @State private var videoItem: PhotosPickerItem?
    @State private var replaceItem: PhotosPickerItem?

    init(state: EditorState, close: @escaping () -> Void) {
        _state = StateObject(wrappedValue: state)
        self.close = close
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            preview
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            TransportBar(state: state, showHistory: $showHistory)
            TimelineView(state: state)
                .frame(height: timelineHeight)
            BottomPanel(state: state, showPhotoPicker: $showPhotoPicker) { target, style in
                state.pause()
                pen = (target, style)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .environmentObject(drawLauncher)
        .environmentObject(mediaLauncher)
        .environmentObject(trackLauncher)
        .photosPicker(isPresented: $mediaLauncher.pickVideo, selection: $videoItem, matching: .videos)
        .onChange(of: videoItem) { _, item in
            guard let item else { return }
            Task {
                if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    await MainActor.run { state.addVideo(from: movie.url) }
                }
                videoItem = nil
            }
        }
        .photosPicker(isPresented: Binding(get: { mediaLauncher.replaceTarget != nil },
                                           set: { if !$0 && replaceItem == nil { mediaLauncher.replaceTarget = nil } }),
                      selection: $replaceItem, matching: .any(of: [.images, .videos]))
        .onChange(of: replaceItem) { _, item in
            guard let item, let target = mediaLauncher.replaceTarget else { return }
            Task {
                if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    await MainActor.run { state.replaceMedia(layerID: target, url: movie.url, imageData: nil) }
                } else if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { state.replaceMedia(layerID: target, url: nil, imageData: data) }
                }
                await MainActor.run { replaceItem = nil; mediaLauncher.replaceTarget = nil }
            }
        }
        .fileImporter(isPresented: $mediaLauncher.pickAudio, allowedContentTypes: [.audio]) { r in
            if case .success(let url) = r { state.addAudio(from: url) }
        }
        .fileImporter(isPresented: $mediaLauncher.pickModel, allowedContentTypes: [.usdz, .usdzModel, .objModel, .data]) { r in
            if case .success(let url) = r { state.addModelLayer(text: nil, fileURL: url) }
        }
        .fullScreenCover(item: $drawLauncher.session) { s in
            DrawStudioView(engine: s.engine, onDone: { engine in
                state.finishDrawing(engine, editing: s.layerID)
                drawLauncher.session = nil
            }, onCancel: { drawLauncher.session = nil })
        }
        .onChange(of: drawLauncher.request) { _, req in
            guard let req else { return }
            state.pause()
            let layer = req.layerID.flatMap { id in state.project.layers.first { $0.id == id } }
            if let e = state.makeDrawEngine(editing: layer) {
                drawLauncher.session = DrawLauncher.Session(engine: e, layerID: req.layerID)
            }
            drawLauncher.request = nil
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(state: state).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHistory) {
            HistorySheet(state: state).presentationDetents([.medium])
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "png"
                    state.addImage(data: data, ext: ext)
                }
                photoItem = nil
            }
        }
        .onDisappear { state.pause(); state.saveNow(thumbnail: true) }
    }

    /// Timeline grows with layer count, capped so the preview keeps most of the screen.
    private var timelineHeight: CGFloat {
        let rows = CGFloat(max(1, min(state.project.layers.count, 5)))
        return 34 + rows * 34
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                state.pause()
                state.saveNow(thumbnail: true)
                close()
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).frame(width: 36, height: 36)
            }
            if state.isInPrecomp {
                Button { state.closePrecomp() } label: {
                    Label(state.compStack.last?.project.name ?? "Back", systemImage: "arrow.turn.left.up")
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 5).background(Capsule().fill(Theme.accent.opacity(0.3)))
                }
                .accessibilityLabel("Close Pre-comp")
            }
            Button { state.panel = .scene } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(state.project.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text("\(state.project.width)×\(state.project.height) · \(Int(state.project.fps))fps")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Theme.textDim).lineLimit(1)
            }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scene Settings")
            Spacer()
            ViewModeSwitch(state: state)

            Button { showExport = true } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
            }
            .accessibilityLabel("Export")
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 12)
        .frame(height: 50)
    }

    private var preview: some View {
        GeometryReader { geo in
            let base = fitRect(compWidth: state.project.width, compHeight: state.project.height, in: geo.size)
            let fit = CGRect(x: base.midX - base.width * viewZoom / 2 + viewPan.width, y: base.midY - base.height * viewZoom / 2 + viewPan.height,
                             width: base.width * viewZoom, height: base.height * viewZoom)
            ZStack(alignment: .topLeading) {
                ClockReader(clock: state.clock) { t in
                    MetalPreview(project: state.viewMode == .orbit ? OrbitView.scene(state.project, orbit: state.orbit, time: t) : state.project,
                                 time: t, redrawToken: state.redrawToken, mediaURL: { state.mediaURL($0) },
                                 viewZoom: state.viewMode == .comp ? viewZoom : 1, viewPan: state.viewMode == .comp ? viewPan : .zero)
                }
                if state.viewMode == .orbit {
                    ClockReader(clock: state.clock) { t in OrbitGrid(project: state.project, orbit: state.orbit, time: t, fit: fit) }
                        .allowsHitTesting(false)
                }
                if let pen {
                    PenOverlay(state: state, target: pen.target, style: pen.style, fit: fit) { self.pen = nil }
                }
                if trackLauncher.active {
                    TrackOverlay(state: state, fit: fit) { trackLauncher.active = false }
                }
                if pen == nil, state.viewMode == .comp, let layer = state.selectedLayer {
                    ClockReader(clock: state.clock) { t in
                        if layer.isActive(at: t) {
                            SelectionOverlay(layer: layer, time: t, fit: fit,
                                             compWidth: state.project.width, project: state.project, tool: state.transformTool)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .overlay {
                // Snap guides.
                let g = state.snapGuides
                Canvas { ctx, _ in
                    let s = fit.width / CGFloat(state.project.width)
                    if let x = g.x {
                        var p = Path(); p.move(to: CGPoint(x: fit.minX + CGFloat(x) * s, y: fit.minY)); p.addLine(to: CGPoint(x: fit.minX + CGFloat(x) * s, y: fit.maxY))
                        ctx.stroke(p, with: .color(Theme.warning), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    if let y = g.y {
                        var p = Path(); p.move(to: CGPoint(x: fit.minX, y: fit.minY + CGFloat(y) * s)); p.addLine(to: CGPoint(x: fit.maxX, y: fit.minY + CGFloat(y) * s))
                        ctx.stroke(p, with: .color(Theme.warning), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                if viewZoom != 1 || viewPan != .zero {
                    Button { withAnimation(.easeOut(duration: 0.2)) { viewZoom = 1; zoomBase = 1; viewPan = .zero } } label: {
                        Text("\(Int(viewZoom * 100))%").font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Theme.raised.opacity(0.9)))
                    }
                    .foregroundStyle(Theme.text).padding(8)
                    .accessibilityLabel("Reset canvas zoom")
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(canvasDrag(fit: fit), including: pen == nil && state.viewMode == .comp ? .all : .subviews)
            .simultaneousGesture(MagnificationGesture()
                .onChanged { m in if state.viewMode == .comp && canvasDragState == nil { viewZoom = min(8, max(0.4, zoomBase * m)) } }
                .onEnded { _ in zoomBase = viewZoom }, including: pen == nil ? .all : .subviews)
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                withAnimation(.easeOut(duration: 0.2)) { viewZoom = 1; zoomBase = 1; viewPan = .zero }
            }, including: pen == nil && state.viewMode == .comp ? .all : .subviews)
            .simultaneousGesture(orbitDrag, including: state.viewMode == .orbit ? .all : .subviews)
            .simultaneousGesture(orbitZoom, including: state.viewMode == .orbit ? .all : .subviews)
            .simultaneousGesture(SpatialTapGesture().onEnded { v in if pen == nil && state.viewMode == .comp { tapSelect(at: v.location, fit: fit) } })
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func toComp(_ p: CGPoint, fit: CGRect) -> Vec2 {
        let s = Double(fit.width) / Double(state.project.width)
        return Vec2(Double(p.x - fit.minX) / s, Double(p.y - fit.minY) / s)
    }

    @State private var orbitStart: OrbitCamera?

    /// 3D view: one finger orbits (two fingers pan via the pinch's drift), pinch dollies.
    private var orbitDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                if orbitStart == nil { orbitStart = state.orbit }
                guard let o = orbitStart else { return }
                state.orbit.yaw = o.yaw - Double(v.translation.width) * 0.4
                state.orbit.pitch = max(-89, min(89, o.pitch - Double(v.translation.height) * 0.4))
            }
            .onEnded { _ in orbitStart = nil }
    }

    private var orbitZoom: some Gesture {
        MagnificationGesture()
            .onChanged { m in
                if orbitStart == nil { orbitStart = state.orbit }
                guard let o = orbitStart else { return }
                state.orbit.distance = max(0.15, min(8, o.distance / Double(m)))
            }
            .onEnded { _ in orbitStart = nil }
    }

    private func canvasDrag(fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                if canvasDragState == nil && panBase == nil {
                    canvasDragState = state.beginCanvasDrag(at: v.startLocation, comp: toComp(v.startLocation, fit: fit), fit: fit)
                    if canvasDragState == nil { panBase = viewPan }
                }
                if let b = panBase {
                    viewPan = CGSize(width: b.width + v.translation.width, height: b.height + v.translation.height)
                    return
                }
                guard let d = canvasDragState else { return }
                state.updateCanvasDrag(d, comp: toComp(v.location, fit: fit))
            }
            .onEnded { _ in
                if canvasDragState != nil { state.endCanvasDrag() }
                canvasDragState = nil
                panBase = nil
            }
    }

    /// Selects the top-most layer whose bounds contain the tap.
    private func tapSelect(at point: CGPoint, fit: CGRect) {
        let c = toComp(point, fit: fit)
        for layer in state.project.layers where layer.isActive(at: state.currentTime) && !layer.isLocked {
            let M = Renderer.placementMatrix(layer, camera: Renderer.activeCamera(state.project, time: state.currentTime),
                                             time: state.currentTime, renderScale: 1)
            let h = M.inverse * SIMD3(c.x, c.y, 1)
            let local = SIMD3(h.x / h.z, h.y / h.z, 1)
            let hs = Renderer.layerHalfSize(layer, time: state.currentTime)
            if abs(local.x) <= hs.x && abs(local.y) <= hs.y {
                state.select(layer.id)
                return
            }
        }
        state.select(nil)
    }
}

/// Bounding box + handles of the selected layer drawn over the preview.
struct SelectionOverlay: View {
    let layer: Layer
    let time: Double
    let fit: CGRect
    let compWidth: Int
    let project: Project
    var tool: TransformTool = .move

    var body: some View {
        let s = Double(fit.width) / Double(compWidth)
        let M = Renderer.placementMatrix(layer, camera: Renderer.activeCamera(project, time: time), time: time, renderScale: s)
        let hs = Renderer.layerHalfSize(layer, time: time)
        let corners = [(-hs.x, -hs.y), (hs.x, -hs.y), (hs.x, hs.y), (-hs.x, hs.y)].map { c -> CGPoint in
            let p = M * SIMD3(c.0, c.1, 1)
            let z = max(p.z, 1e-6)
            return CGPoint(x: fit.minX + p.x / z, y: fit.minY + p.y / z)
        }
        let anchor = layer.transform.anchor.value(at: time)
        let ap0 = M * SIMD3(anchor.x, anchor.y, 1)
        let ap = SIMD3(ap0.x / max(ap0.z, 1e-6), ap0.y / max(ap0.z, 1e-6), 1)
        let h = CanvasHandles.handles(layer, project: project, time: time, fit: fit)
        ZStack {
            Path { path in
                path.addLines(corners)
                path.closeSubpath()
            }
            .stroke(Theme.accentGlow, style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
            Path { p in p.move(to: h.edges[0]); p.addLine(to: h.rotate) }.stroke(Theme.accentGlow.opacity(0.7), lineWidth: 1)
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(.white).frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Theme.accent, lineWidth: 1.5))
                    .position(corners[i])
                RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 9, height: 9)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.accent, lineWidth: 1.5))
                    .position(h.edges[i])
            }
            Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white, Theme.accent)
                .position(h.rotate)
            Image(systemName: tool == .pivot ? "scope" : "plus.circle")
                .font(.system(size: tool == .pivot ? 22 : 14, weight: .bold))
                .foregroundStyle(tool == .pivot ? Theme.warning : Theme.accentGlow)
                .position(x: fit.minX + ap.x, y: fit.minY + ap.y)
        }
    }
}

struct TransportBar: View {
    @ObservedObject var state: EditorState
    @Binding var showHistory: Bool

    var body: some View {
        HStack(spacing: 0) {
            button("arrow.uturn.backward", enabled: state.canUndo) { state.undo() }
            button("arrow.uturn.forward", enabled: state.canRedo) { state.redo() }
            Spacer()
            button("backward.end.fill") { state.pause(); state.seek(0) }
            button("chevron.left") { state.stepFrame(-1) }
            Button { state.togglePlay() } label: {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 48, height: 40)
            }
            .accessibilityLabel(state.isPlaying ? "Pause" : "Play")
            button("chevron.right") { state.stepFrame(1) }
            button("forward.end.fill") { state.pause(); state.seek(state.project.duration) }
            Spacer()
            button("diamond.fill", enabled: state.selectedLayer != nil, tint: state.selectedLayer != nil ? Theme.keyframe : nil) { state.keyAllTransform() }
                .accessibilityLabel("Key All")
            button(state.loop ? "repeat" : "repeat.1", tint: state.loop ? Theme.accentGlow : Theme.textDim) { state.loop.toggle() }
            button("clock.arrow.circlepath") { showHistory = true }
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 6)
        .frame(height: 44)
    }

    private func button(_ icon: String, enabled: Bool = true, tint: Color? = nil, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .foregroundStyle(tint ?? (enabled ? Theme.text : Theme.textDim.opacity(0.4)))
        }
        .disabled(!enabled)
    }
}

struct HistorySheet: View {
    @ObservedObject var state: EditorState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(state.undoStack.enumerated()).reversed(), id: \.offset) { i, entry in
                        Button {
                            state.jumpToHistory(index: i)
                            dismiss()
                        } label: {
                            HStack {
                                Text(entry.label).foregroundStyle(Theme.text)
                                Spacer()
                                Text("Undo to here").font(.caption).foregroundStyle(Theme.textDim)
                            }
                        }
                    }
                } header: { Text("History") }
                if state.undoStack.isEmpty {
                    Text("No changes yet").foregroundStyle(Theme.textDim)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Undo History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
