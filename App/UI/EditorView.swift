import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct EditorView: View {
    @StateObject var state: EditorState
    let close: () -> Void
    @ObservedObject private var canvasPicker = CanvasColorPicker.shared
    @State private var showExport = false
    @State private var showPasteStyle = false
    @State private var showKeyframeMover = false
    @ObservedObject private var layerClipboard = LayerClipboard.shared
    @ObservedObject private var textStudio = TextStudioSession.shared
    @State private var layerOptionsOpen = false
    @State private var showLayerRename = false
    @State private var renameText = ""
    @State private var showHistory = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var canvasDragState: CanvasDrag?
    /// Viewport zoom / pan (view only — doesn't change the comp). Pinch to zoom, drag empty canvas to pan, double-tap to reset.
    @State private var viewZoom: CGFloat = 1
    @State private var zoomBase: CGFloat = 1
    @State private var viewPan: CGSize = .zero
    @State private var panBase: CGSize?
    @State private var penSession = PenSession()
    @State private var pen: (target: PenTarget, style: PenStyle)?
    @StateObject private var drawLauncher = DrawLauncher()
    @StateObject private var mediaLauncher = MediaLauncher()
    @State private var audioVideoItem: PhotosPickerItem?
    @StateObject private var trackLauncher = TrackLauncher()
    @StateObject private var cutoutSession = CutoutSession()
    @State private var videoItem: PhotosPickerItem?
    @State private var replaceItem: PhotosPickerItem?

    init(state: EditorState, close: @escaping () -> Void) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-cutoutInline") {
            state.select(state.project.layers.first?.id); state.panel = .cutout
            let destination = state.mediaURL("cutout-fixture.png")
            try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: destination.path) { try? FileManager.default.copyItem(at: PreviewImage.url(), to: destination) }
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-shapeContents") {
            state.select(state.project.layers.first?.id); state.panel = .shape
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-animationTiming") {
            state.select(state.project.layers.first?.id); state.currentTime = 1; state.panel = .clip
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-graph") { state.panel = .graph }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-letterAuthoring") {
            state.select(state.project.layers.first?.id); state.panel = .text
            TextStudioSession.shared.follow(state.selectedLayerID)
            if let text = state.selectedLayer?.text { TextStudioSession.shared.selectedIDs = TextStudioLogic.ids(text, range: 0..<2) }
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-rigAuthoring") {
            state.select(state.project.layers.first?.id)
            state.ikDraftUpper = state.project.layers.last?.id
            state.panel = .rig
        }
        #endif
        _state = StateObject(wrappedValue: state)
        self.close = close
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            preview
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            if state.textTyping {
                // Typing: the timeline and panels step aside so the canvas (your text) stays above the keyboard.
                TypeBar(state: state)
            } else if textStudio.expanded, state.panel == .text, state.selectedLayer?.text != nil {
                // Expanded Text Studio: the canvas stays live on top, the studio takes the rest of the screen.
                TextPanel(state: state)
                    .frame(height: UIScreen.main.bounds.height * 0.56)
                    .background(Theme.background)
            } else {
                TransportBar(state: state, showHistory: $showHistory, viewZoom: $viewZoom, zoomBase: $zoomBase, viewPan: $viewPan)
                    // Tap the empty bar to get out of a selection.
                    .background(Color.black.opacity(0.001).onTapGesture { if state.isMultiSelecting { state.endMultiSelect() } else { state.select(nil) } })
                timelineGrip
                // A panel open on a layer: the timeline shows just that layer's row, so the canvas stays big.
                let compact = state.panel != .none && state.panel != .add && state.selectedLayerID != nil && !state.isMultiSelecting
                TimelineView(state: state, compact: compact).equatable()
                    .frame(height: compact ? 92 : timelineHeight)
                TrimStrip(state: state, clock: state.clock)
                if let pen {
                    PenOverlay(state: state, target: pen.target, style: pen.style, fit: penSession.fit,
                               done: { self.pen = nil }, session: penSession, controlsOnly: true)
                        .accessibilityIdentifier("pen-tool-panel")
                } else {
                    BottomPanel(state: state, showPhotoPicker: $showPhotoPicker) { target, style in
                        state.pause(); penSession.reset()
                        pen = (target, style)
                    }
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .environmentObject(drawLauncher)
        .environmentObject(cutoutSession)
        // Every slider in the editor keeps its edits live while dragging (smooth, no full-editor rebuilds).
        .environment(\.scrubSession, ScrubSession(begin: { [weak state] in state?.beginScrub() }, end: { [weak state] in state?.endScrub() }))
        .onAppear {
            canvasPicker.available = true
            AILink.shared.editor = state
            EffectRegistry.softMeshURL = { [weak state] f in state?.mediaURL(f) ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(f) }
            // The eyedropper samples the edit itself (current frame), never the app UI.
            ScreenEyedropper.sceneProvider = { [weak state] in
                guard let state else { return nil }
                return Renderer.shared?.renderImage(project: state.project, time: state.currentTime, maxDimension: 1600, mediaURL: { state.mediaURL($0) })
            }
        }
        .onChange(of: canvasPicker.active) { _, active in if active { state.pause() } }
        .onDisappear { cutoutSession.close(); canvasPicker.available = false; canvasPicker.finish(nil); if AILink.shared.editor === state { AILink.shared.editor = nil } }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let message = state.recoveryNotice {
                HStack {
                    Text(message).font(.caption)
                    Button("Dismiss") { state.recoveryNotice = nil }.font(.caption.bold())
                }.foregroundStyle(Theme.text).padding(10).background(Theme.surface)
            }
            if let message = state.saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    Button("Retry") { state.saveNow() }.font(.caption.bold())
                }.foregroundStyle(.white).padding(10).background(Color.red.opacity(0.85))
                    .accessibilityIdentifier("save-error")
            }
        }
        .awiSheet(isPresented: $showKeyframeMover) { KeyframeMoverSheet(state: state).presentationDetents([.medium, .large]) }
        .awiSheet(isPresented: $showPasteStyle) { PasteLayerStyleSheet(state: state).presentationDetents([.medium, .large]) }
        .awiSheet(isPresented: $state.showLightBrowser) { LightBrowser(state: state).presentationDetents([.large]) }
        .environmentObject(mediaLauncher)
        .environmentObject(trackLauncher)
        .awiSheet(isPresented: $mediaLauncher.pickVideo) { MediaPickerView(state: state, isPresented: $mediaLauncher.pickVideo) }
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
        // Each file importer sits on its own view: SwiftUI only honours one .fileImporter per view.
        .background(Color.clear.fileImporter(isPresented: $mediaLauncher.pickAudioFile, allowedContentTypes: [.audio, .movie]) { r in
            guard case .success(let url) = r else { return }
            if UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true { state.addAudioFromVideo(url) }
            else { state.addAudio(from: url) }
        })
        .background(Color.clear.fileImporter(isPresented: $mediaLauncher.pickModel, allowedContentTypes: [.usdz, .usdzModel, .objModel, .data]) { r in
            if case .success(let url) = r { state.addModelLayer(text: nil, fileURL: url) }
        })
        .confirmationDialog("Add music or sound", isPresented: $mediaLauncher.pickAudio, titleVisibility: .visible) {
            Button("From Files (music, sound effects)") { mediaLauncher.pickAudioFile = true }
            Button("Sound from a video in Photos") { mediaLauncher.pickAudioVideo = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $mediaLauncher.pickAudioVideo, selection: $audioVideoItem, matching: .videos)
        .onChange(of: audioVideoItem) { _, item in
            guard let item else { return }
            Task {
                if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    await MainActor.run { state.addAudioFromVideo(movie.url) }
                }
                await MainActor.run { audioVideoItem = nil }
            }
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
        .awiSheet(isPresented: $showExport) {
            ExportSheet(state: state).presentationDetents([.medium, .large])
        }
        .awiSheet(isPresented: $showHistory) {
            HistorySheet(state: state).presentationDetents([.medium])
        }
        .awiSheet(isPresented: $showPhotoPicker) { MediaPickerView(state: state, isPresented: $showPhotoPicker) }
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
    /// Alight Motion-style: the timeline gets a real share of the screen (≈30%, less while a panel is open),
    /// and the user can drag its top edge to make it taller or shorter.
    @AppStorage("awi.timelineShare") private var timelineShare: Double = 0.30
    @State private var timelineDragBase: Double?
    private var timelineHeight: CGFloat {
        let screen = UIScreen.main.bounds.height
        let share = state.panel == .none ? timelineShare : max(0.16, timelineShare * 0.62)
        return CGFloat(max(150, min(Double(screen) * 0.5, Double(screen) * share)))
    }

    private var timelineGrip: some View {
        Capsule().fill(Theme.textDim.opacity(0.35)).frame(width: 36, height: 4)
            .frame(maxWidth: .infinity).frame(height: 12)
            .background(Theme.surface)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { g in
                    if timelineDragBase == nil { timelineDragBase = timelineShare }
                    let screen = Double(UIScreen.main.bounds.height)
                    timelineShare = min(0.5, max(0.18, (timelineDragBase ?? 0.3) - Double(g.translation.height) / screen))
                }
                .onEnded { _ in timelineDragBase = nil })
            .accessibilityLabel("Resize timeline")
    }

    /// Alight Motion-style: with a layer selected the top bar becomes that layer's bar (name, duplicate, delete, ⋯).
    @ViewBuilder private var topBar: some View {
        if let l = state.selectedLayer, !state.isMultiSelecting {
            layerBar(l)
        } else {
            projectBar
        }
    }

    private func layerBar(_ l: Layer) -> some View {
        HStack(spacing: 6) {
            Button { state.select(nil) } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).frame(width: 36, height: 36)
            }
            .accessibilityLabel("Deselect Layer")
            Button { renameText = l.name; showLayerRename = true } label: {
                Text(l.name).font(.system(size: 17, weight: .semibold)).lineLimit(1).truncationMode(.tail)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(-1)
            .accessibilityLabel("Rename Layer")
            Button { state.duplicateSelected() } label: {
                Image(systemName: "plus.square.on.square").font(.system(size: 18, weight: .semibold)).frame(width: 40, height: 40)
            }
            .accessibilityLabel("Duplicate Layer")
            Button(role: .destructive) { state.deleteSelected() } label: {
                Image(systemName: "trash").font(.system(size: 18, weight: .semibold)).frame(width: 40, height: 40)
            }
            .accessibilityLabel("Delete Layer")
            Button { layerOptionsOpen = true } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 22, weight: .regular)).frame(width: 40, height: 40)
            }.accessibilityLabel("Layer Options")
            .popover(isPresented: $layerOptionsOpen) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {

                Button { renameText = l.name; showLayerRename = true } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
                Button(role: .destructive) { state.rippleDeleteSelected() } label: { Label("Ripple Delete", systemImage: "delete.backward") }
                Button { state.closeGapAtPlayhead() } label: { Label("Close Gap at Playhead", systemImage: "arrow.right.and.line.vertical.and.arrow.left") }.disabled(state.gapAtPlayhead() == nil)
                Button { state.splitSelected() } label: { Label("Split at Playhead", systemImage: "scissors") }
                Button { showKeyframeMover = true } label: { Label("Move Keyframes…", systemImage: "diamond") }
                Button { state.copyKeyframes() } label: { Label("Copy Keyframes", systemImage: "doc.on.doc") }
                Button { state.pasteKeyframes() } label: { Label("Paste Keyframes", systemImage: "doc.on.clipboard") }
                Button { state.copyLayer() } label: { Label(layerClipboard.busy ? "Copying…" : "Copy Layer", systemImage: "doc.on.doc") }.disabled(layerClipboard.busy)
                if layerClipboard.payload != nil {
                    Button { state.pasteLayer() } label: { Label("Paste Layer", systemImage: "plus.square.on.square") }.disabled(layerClipboard.busy)
                    Button { showPasteStyle = true } label: { Label("Paste Style…", systemImage: "paintbrush") }.disabled(layerClipboard.busy || l.isLocked)
                    Button { state.pasteLayer(contentOnly: true) } label: { Label("Replace Content from Copy", systemImage: "photo.on.rectangle") }.disabled(layerClipboard.busy || l.isLocked)
                }
                Button { state.copyEffects() } label: { Label("Copy Effects", systemImage: "sparkles.rectangle.stack") }
                if !state.effectClipboard.isEmpty { Button { state.pasteEffects() } label: { Label("Paste Effects", systemImage: "sparkles") } }
                Divider()
                if case .precomp = l.content {
                    Button { state.openPrecomp() } label: { Label("Open Precomp", systemImage: "arrow.down.right.and.arrow.up.left") }
                    Button { state.unpackSelectedPrecomp() } label: { Label("Un-precompose", systemImage: "square.stack.3d.down.right") }
                } else {
                    Button { state.precomposeSelected() } label: { Label("Pre-compose", systemImage: "square.stack.3d.up") }
                }
                if l.isGroup {
                    Button { state.openGroup() } label: { Label("Open Group", systemImage: "folder") }
                    Button { state.ungroupSelected() } label: { Label("Ungroup", systemImage: "folder.badge.minus") }
                } else {
                    Button { state.groupSelected() } label: { Label("Group Layers", systemImage: "folder.badge.plus") }
                }
                Button { state.moveSelected(up: true) } label: { Label("Move Up", systemImage: "arrow.up") }
                Button { state.moveSelected(up: false) } label: { Label("Move Down", systemImage: "arrow.down") }
                Button { state.toggleVisibility(l.id) } label: { Label(l.isVisible ? "Hide" : "Show", systemImage: l.isVisible ? "eye.slash" : "eye") }
                Button { state.mutate("Lock Layer") { p in if let i = state.selectedIndex { p.layers[i].isLocked.toggle() } } } label: {
                    Label(l.isLocked ? "Unlock" : "Lock", systemImage: l.isLocked ? "lock.open" : "lock")
                }
                Button { state.mutate("Solo Layer") { p in if let i = state.selectedIndex { p.layers[i].isSolo.toggle() } } } label: {
                    Label(l.isSolo ? "Unsolo" : "Solo", systemImage: "s.circle")
                }
                Button { state.panel = .layerMenu } label: { Label("Parent, Tag & More…", systemImage: "ellipsis.circle") }
                Divider()
                Button { state.beginMultiSelect(l.id) } label: { Label("Select Multiple", systemImage: "checklist") }
                Button(role: .destructive) { state.deleteSelected() } label: { Label("Delete", systemImage: "trash") }

                    }.buttonStyle(OpaqueMenuActionStyle { layerOptionsOpen = false })
                }.padding(12).frame(width: 290, height: 440).foregroundStyle(Theme.text).background(Theme.background)
                    .presentationBackground(Theme.background).presentationCompactAdaptation(.popover)
            }
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 10)
        .frame(height: 50)
        .alert("Rename Layer", isPresented: $showLayerRename) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                let n = renameText.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { state.mutate("Rename Layer") { p in if let i = state.selectedIndex { p.layers[i].name = n } } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var projectBar: some View {
        HStack(spacing: 10) {
            Button {
                state.pause()
                state.saveNow(thumbnail: true)
                if state.saveError == nil { close() }
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).frame(width: 36, height: 36)
            }
            if state.isInPrecomp {
                Button { state.closePrecomp() } label: {
                    Label(state.compStack.last?.project.name ?? "Back", systemImage: "arrow.turn.left.up")
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1).frame(maxWidth: 110)
                        .padding(.horizontal, 8).padding(.vertical, 5).background(Capsule().fill(Theme.accent.opacity(0.3)))
                }
                .accessibilityLabel(state.compStack.last?.groupID == nil ? "Close Pre-comp" : "Close Group")
            }
            Button { state.panel = .scene } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(state.project.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text("\(state.project.width)×\(state.project.height) · \(Int(state.project.fps))fps")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Theme.textDim).lineLimit(1)
            }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(-1)
            .accessibilityLabel("Scene Settings")
            PreviewQualityMenu(state: state)
            QuickMenu(state: state)
            ViewModeSwitch(state: state).fixedSize()

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
                LiveReader(live: state.live) { lp in
                ClockReader(clock: state.clock) { t in
                    let cutProject = state.cutoutDisplayProject(lp ?? state.project)
                    MetalPreview(project: state.viewMode == .orbit && !state.looksThroughCamera ? OrbitView.scene(cutProject, orbit: state.orbit, time: t)
                                    : (state.cameraView ? cutProject : state.freeViewProject(cutProject)),
                                 time: t, redrawToken: state.redrawToken, mediaURL: { state.mediaURL($0) },
                                 viewZoom: state.canvasMode == .comp ? viewZoom : 1, viewPan: state.canvasMode == .comp ? viewPan : .zero,
                                 qualityCap: state.previewQuality.rawValue, isPlaying: state.isPlaying,
                                 // No RAM-cache writes mid-gesture: every frame changes, caching only churned memory.
                                 cacheEnabled: state.canvasMode == .comp && lp == nil && state.cutoutPreview == nil && state.cutoutPeekOriginal == nil)
                }
                }
                if state.viewMode == .orbit && !state.looksThroughCamera {
                    LiveReader(live: state.live) { lp in
                        ClockReader(clock: state.clock) { t in OrbitGrid(project: lp ?? state.project, orbit: state.orbit, time: t, fit: fit) }
                    }
                    .allowsHitTesting(false)
                    LiveReader(live: state.live) { lp in
                        ClockReader(clock: state.clock) { t in
                            OrbitGizmo(state: state, project: lp ?? state.project, time: t, fit: fit, mode: $gizmoMode)
                        }
                    }
                    // The app's existing two-finger watcher slides the 3D view.
                    TwoFingerPan(onBegan: { orbitPanStart = nil }, onChanged: { d in orbitPan(CGPoint(x: d.width, y: d.height), fit: fit) },
                                 onEnded: { orbitPanStart = nil })
                    VStack { OrbitToolbar(state: state, mode: $gizmoMode); Spacer() }
                }
                if state.canvasMode == .comp, !state.cameraView {
                    LiveReader(live: state.live) { lp in
                        ClockReader(clock: state.clock) { t in CameraFrameOverlay(project: lp ?? state.project, time: t, fit: fit) }
                    }
                }
                if state.showGrid { CompGrid(fit: fit, divisions: state.gridDivisions) }
                if state.canvasMode == .comp { GuidesOverlay(state: state, fit: fit) }
                // 3D camera: two fingers dragged together slide the camera.
                if state.canvasMode == .comp, state.cameraView, let cam = state.activeCameraLayer, EditorState.cameraIs3D(cam) {
                    TwoFingerPan(onBegan: { panCamera = state.beginCameraGesture() }, onChanged: { d in
                        guard let c = panCamera else { return }
                        let k = Double(state.project.width) / Double(max(fit.width, 1))
                        state.updateCameraPan(c, delta: Vec2(Double(d.width) * k, Double(d.height) * k))
                    }, onEnded: { if panCamera != nil { panCamera = nil; if pinchCamera == nil { state.endCameraGesture() } } })
                }
                if pen == nil, state.canvasMode == .comp, state.panel == .shape {
                    ShapePathOverlay(state: state, fit: fit)
                }
                if let pen {
                    PenOverlay(state: state, target: pen.target, style: pen.style, fit: fit,
                               done: { self.pen = nil }, session: penSession)
                }
                if state.panel == .cutout, state.canvasMode == .comp, let model = cutoutSession.model {
                    InlineCutoutOverlay(model: model, fit: fit)
                }
                if state.cutoutTool != .none, state.canvasMode == .comp {
                    CutoutBrushOverlay(state: state, fit: fit)
                }
                if canvasPicker.active {
                    ScreenEyedropper(snapshot: ScreenEyedropper.capture(), canvasRect: fit) { canvasPicker.finish($0) }
                        .zIndex(100)
                }
                if trackLauncher.active {
                    TrackOverlay(state: state, fit: fit) { trackLauncher.active = false }
                }
                if state.showMotionPath, state.canvasMode == .comp, state.panel == .transform || state.panel == .layerHome {
                    MotionPathOverlay(state: state, fit: fit)
                }
                if state.canvasMode == .comp, pen == nil, state.panel == .transform || state.panel == .threeD || state.panel == .layerHome {
                    ClockReader(clock: state.clock) { _ in AimGizmoOverlay(state: state, fit: fit) }
                }
                if state.panel == .rig, state.canvasMode == .comp {
                    ClockReader(clock: state.clock) { _ in
                        LiveReader(live: state.live) { _ in
                            ZStack {
                                BoneOverlay(state: state, fit: fit)
                                RigEndpointOverlay(state: state, fit: fit)
                                RigControllersOverlay(state: state, fit: fit)
                            }
                        }
                    }
                }
                if let r = marqueeRect { MarqueeOverlay(rect: r) }
                if state.panel == .puppet, state.canvasMode == .comp {
                    ClockReader(clock: state.clock) { _ in PuppetOverlay(state: state, fit: fit) }
                }
                if state.textTyping, let id = state.selectedLayerID {
                    LiveReader(live: state.live) { lp in
                        FocusDim(project: lp ?? state.project, layerID: id, time: state.currentTime, fit: fit)
                    }
                    .allowsHitTesting(false)
                }
                if pen == nil, state.canvasMode == .comp, state.panel == .text || state.textTyping, state.selectedLayer?.text != nil {
                    ClockReader(clock: state.clock) { _ in
                        LiveReader(live: state.live) { _ in TextCanvasOverlay(state: state, fit: fit) }
                    }
                }
                if state.linkPicking {
                    LinkPickOverlay(state: state, fit: fit)
                    VStack {
                        HStack {
                            Text(state.layerPickHandler != nil ? state.layerPickPrompt
                                 : (state.linkPickMatte != nil ? "Tap the layer to use as matte" : "Tap the layer to link to"))
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            Spacer()
                            Button("Cancel") { state.endLinkPick(parent: nil) }.font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(Theme.accent))
                        .padding(8)
                        Spacer()
                    }
                }
                if state.panel == .effects, state.canvasMode == .comp, !state.keyframeFocusEffects.isEmpty {
                    ClockReader(clock: state.clock) { _ in EffectPointOverlay(state: state, fit: fit) }
                }
                if state.panel == .masks, state.canvasMode == .comp {
                    ClockReader(clock: state.clock) { _ in
                        MaskPointsOverlay(state: state, fit: fit)
                        MaskSelectionOverlay(state: state, fit: fit)
                    }
                }
                if pen == nil, state.canvasMode == .comp,
                   !(state.panel == .text && textStudio.hasSelection), let id = state.selectedLayerID {
                    LiveReader(live: state.live) { lp in
                        ClockReader(clock: state.clock) { t in
                            let raw = lp ?? state.project
                            // Free view draws without the camera: handles must use the same view (a camera keeps its own).
                            let shown = raw.layers.first(where: { $0.id == id })?.content == .camera ? raw : state.canvasViewProject(raw)
                            if let layer = Renderer.resolveParenting(shown, time: t).layers.first(where: { $0.id == id }), layer.isActive(at: t) {
                                SelectionOverlay(layer: layer, time: t, fit: fit,
                                                 compWidth: shown.width, project: shown, tool: state.transformTool)
                            }
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
            .clipped()
            .contentShape(Rectangle())
            .gesture(canvasDrag(fit: fit), including: pen == nil && !canvasToolActive && state.canvasMode == .comp && state.panel != .rig ? .all : .subviews)
            // Two fingers, like Alight Motion: with a layer selected, pinch scales it and twisting rotates it (both at
            // once); with nothing selected the pinch zooms the canvas view.
            .simultaneousGesture(MagnificationGesture()
                .onChanged { m in
                    guard state.canvasMode == .comp else { return }
                    // Text Studio open: pinch sizes the selected letters (or the whole text).
                    if state.panel == .text, state.selectedLayer?.text != nil, !magActive {
                        TextStudioSession.shared.pinch(state, scale: Double(m)); return
                    }
                    pinchScale = Double(m); magActive = true
                    updatePinch()
                }
                .onEnded { _ in
                    if TextStudioSession.shared.isPinching { TextStudioSession.shared.endPinch(state); return }
                    magActive = false; finishPinch()
                }, including: pen == nil && !canvasToolActive ? .all : .subviews)
            .simultaneousGesture(RotationGesture()
                .onChanged { a in
                    guard state.canvasMode == .comp else { return }
                    pinchAngle = a.degrees; rotActive = true
                    updatePinch()
                }
                .onEnded { _ in rotActive = false; finishPinch() }, including: pen == nil && !canvasToolActive ? .all : .subviews)
            .simultaneousGesture(orbitDrag, including: state.canvasMode == .orbit ? .all : .subviews)
            .simultaneousGesture(orbitZoom, including: state.canvasMode == .orbit ? .all : .subviews)
            .simultaneousGesture(SpatialTapGesture().onEnded { v in
                if state.canvasMode == .orbit, pen == nil, !canvasToolActive { state.orbitSelect(at: v.location, fit: fit); return }
                guard pen == nil && !canvasToolActive && state.canvasMode == .comp else { return }
                // Link mode: the tapped layer becomes the parent.
                if state.linkPicking { state.endLinkPick(parent: layerAt(v.location, fit: fit)); return }
                // Rig handles own the canvas: a target/rest-joint gesture must not deselect the limb.
                if state.panel == .rig { return }
                // Puppet panel open: taps drop pins instead of selecting layers.
                if state.panel == .puppet, state.selectedLayerID != nil {
                    // Place on: a tap drops a pin (unless it lands on one). Place off: taps never add pins.
                    let reach = 30 * Double(state.project.width) / Double(max(fit.width, 1))
                    if state.puppetPlace, state.puppetPin(nearComp: toComp(v.location, fit: fit), reach: reach) == nil {
                        state.addPuppetPin(atComp: toComp(v.location, fit: fit))
                    }
                    return
                }
                // Masks panel open: taps select mask points or add one on the outline.
                if state.panel == .masks, state.selectedLayerID != nil {
                    let reach = 28 * Double(state.project.width) / Double(max(fit.width, 1))
                    if state.maskTap(atComp: toComp(v.location, fit: fit), reach: reach) { return }
                }
                tapSelect(at: v.location, fit: fit)
            })
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @State private var pinchScale: Double = 1
    @State private var pinchAngle: Double = 0
    /// nil = no pinch yet, true = transforming the selected layer, false = zooming the canvas.
    @State private var pinchOnLayer: Bool?
    /// The finger drag that was running when the second finger landed stops moving the layer (no jump).
    @State private var dragFrozen = false

    @State private var cameraStart: EditorState.CameraDragStart?
    @State private var pinchCamera: EditorState.CameraDragStart?
    @State private var panCamera: EditorState.CameraDragStart?

    private func updatePinch() {
        if pinchOnLayer == nil {
            let layer = state.selectedLayer
            let cameraMode = state.cameraView && state.activeCameraLayer != nil && (layer == nil || layer?.content == .camera)
            if cameraMode, let c = state.beginCameraGesture() {
                pinchCamera = c; pinchOnLayer = false; dragFrozen = true
            } else {
                pinchOnLayer = layer != nil && layer?.isLocked == false && layer?.content != .light && layer?.content != .camera
                if pinchOnLayer == true { state.beginLayerPinch(); dragFrozen = canvasDragState != nil }
            }
        }
        if let c = pinchCamera {
            state.updateCameraPinch(c, scale: pinchScale, rotation: pinchAngle)
        } else if pinchOnLayer == true {
            state.updateLayerPinch(scale: pinchScale, rotation: pinchAngle)
        } else {
            viewZoom = min(8, max(0.25, zoomBase * CGFloat(pinchScale)))
        }
    }

    @State private var magActive = false
    @State private var rotActive = false

    /// Pinch and twist are two gestures that end separately: finish once both are done (values hold until then).
    private func finishPinch() {
        guard !magActive, !rotActive, let onLayer = pinchOnLayer else { return }
        if pinchCamera != nil { state.endCameraGesture(); pinchCamera = nil; cameraStart = nil }
        else if onLayer { state.endLayerPinch(ownsEdit: canvasDragState == nil) } else { zoomBase = viewZoom }
        pinchOnLayer = nil; pinchScale = 1; pinchAngle = 0
    }

    private func toComp(_ p: CGPoint, fit: CGRect) -> Vec2 {
        let s = Double(fit.width) / Double(state.project.width)
        return Vec2(Double(p.x - fit.minX) / s, Double(p.y - fit.minY) / s)
    }

    @State private var orbitStart: OrbitCamera?
    @State private var orbitPanStart: Vec2?
    @State private var gizmoMode = GizmoMode.move

    /// Two fingers slide the 3D view (screen movement turned into scene movement at the pivot's distance).
    private func orbitPan(_ t: CGPoint, fit: CGRect) {
        if orbitPanStart == nil { orbitPanStart = state.orbit.pan; orbitStart = nil }
        guard let p = orbitPanStart else { return }
        let k = state.orbit.distance * Double(state.project.width) / Double(max(1, fit.width))
        let yaw = state.orbit.yaw * .pi / 180
        state.orbit.pan = Vec2(p.x - Double(t.x) * k * cos(yaw), p.y - Double(t.y) * k)
    }
    @State private var puppetDragPin: Int?
    @State private var maskDrag: MaskDragSession?
    @State private var marqueeStart: CGPoint?
    @State private var marqueeEnd: CGPoint?
    /// Last canvas tap (screen): tapping the same spot again steps to the layer underneath.
    @State private var lastTapPoint: CGPoint?
    private var marqueeRect: CGRect? {
        guard let a = marqueeStart, let b = marqueeEnd else { return nil }
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// Marquee: every visible layer the rectangle touches. Two or more become a multi-selection.
    private func finishMarquee(fit: CGRect) {
        defer { marqueeStart = nil; marqueeEnd = nil }
        guard let r = marqueeRect, r.width > 6 || r.height > 6 else { return }
        let a = toComp(CGPoint(x: r.minX, y: r.minY), fit: fit), b = toComp(CGPoint(x: r.maxX, y: r.maxY), fit: fit)
        let compRect = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        let view = state.canvasViewProject(state.project), t = state.currentTime
        let bounds = view.layers.filter { $0.isActive(at: t) && !$0.isLocked && $0.content != .camera && $0.content != .light && !$0.isAudioOnly }
            .compactMap { l in LayerPlacement.bounds(l, project: view, time: t).map { (l.id, $0) } }
        let ids = CanvasPick.marquee(compRect, bounds: bounds)
        guard let first = ids.first else { return }
        if ids.count == 1 { state.select(first); return }
        state.beginMultiSelect(first)
        state.multiSelection = Set(ids)
    }
    @State private var orbitZoomStart: Double?

    /// 3D view: one finger orbits (two fingers pan via the pinch's drift), pinch dollies.
    private var orbitDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                guard !state.orbitHandleDrag, orbitPanStart == nil else { orbitStart = nil; return }
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
                if orbitZoomStart == nil { orbitZoomStart = state.orbit.distance }
                state.orbit.distance = max(0.15, min(8, (orbitZoomStart ?? 1.6) / Double(m)))
            }
            .onEnded { _ in orbitZoomStart = nil }
    }

    private var canvasToolActive: Bool { canvasPicker.active || trackLauncher.active || state.cutoutTool != .none || state.panel == .cutout }

    private func canvasDrag(fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                guard !canvasToolActive else { return }
                // Puppet: drag the nearest pin.
                // Masks panel: drag a mask point.
                if state.panel == .masks, canvasDragState == nil, panBase == nil {
                    if maskDrag == nil {
                        let reach = 28 * Double(state.project.width) / Double(max(fit.width, 1))
                        let start = toComp(v.startLocation, fit: fit)
                        // A transform handle closer to the finger than any mask point wins (masks don't cover handles).
                        var blocked = false
                        if let hd = state.nearestHandleDistance(at: v.startLocation, fit: fit), hd < 20,
                           state.maskCanvasHit(atComp: start, reach: Double(hd) * Double(state.project.width) / Double(max(fit.width, 1))) == nil {
                            blocked = true
                        }
                        maskDrag = blocked ? MaskDragSession(hit: nil, base: nil, startComp: start) : state.beginMaskDrag(atComp: start, reach: reach)
                    }
                    if let m = maskDrag, m.hit != nil { state.updateMaskDrag(m, toComp: toComp(v.location, fit: fit)); return }
                }
                if state.panel == .puppet, canvasDragState == nil, panBase == nil {
                    if puppetDragPin == nil {
                        let reach = 30 * Double(state.project.width) / Double(max(fit.width, 1))
                        puppetDragPin = state.puppetPin(nearComp: toComp(v.startLocation, fit: fit), reach: reach) ?? -1
                        if puppetDragPin! >= 0 { state.beginEdit("Move Pin") }
                    }
                    if let k = puppetDragPin, k >= 0 { state.movePuppetPin(k, toComp: toComp(v.location, fit: fit)); return }
                    // Like AE's Puppet tool: dragging off a pin never moves the layer by accident.
                    if state.selectedLayer?.effects.contains(where: { $0.typeID == EffectRegistry.puppet18.id }) == true { return }
                }
                if canvasDragState == nil && panBase == nil && cameraStart == nil,
                   state.selectedLayer?.content == .camera, state.activeCameraLayer != nil, let c = state.beginCameraGesture() {
                    cameraStart = c
                }
                if canvasDragState == nil && panBase == nil && cameraStart == nil && marqueeStart == nil {
                    canvasDragState = state.beginCanvasDrag(at: v.startLocation, comp: toComp(v.startLocation, fit: fit), fit: fit)
                    if canvasDragState == nil {
                        // Nothing to move: in Camera view the camera moves (the scene follows the finger). Nothing
                        // selected and the finger starts on empty canvas: drag a marquee to select. Otherwise the view
                        // pans (two fingers always pan; free view never changes the export).
                        if state.cameraView, state.activeCameraLayer != nil, let c = state.beginCameraGesture() { cameraStart = c }
                        else if state.selectedLayerID == nil, !state.isMultiSelecting, state.canvasMode == .comp,
                                layerAt(v.startLocation, fit: fit) == nil { marqueeStart = v.startLocation }
                        else { panBase = viewPan }
                    }
                }
                if marqueeStart != nil { marqueeEnd = v.location; return }
                if let c = cameraStart {
                    guard !dragFrozen, pinchOnLayer == nil else { return }
                    let s = Double(state.project.width) / Double(max(fit.width, 1))
                    state.updateCameraDrag(c, delta: Vec2(Double(v.translation.width) * s, Double(v.translation.height) * s))
                    return
                }
                if let b = panBase {
                    viewPan = CGSize(width: b.width + v.translation.width, height: b.height + v.translation.height)
                    return
                }
                guard let d = canvasDragState, !dragFrozen, pinchOnLayer != true else { return }
                state.updateCanvasDrag(d, comp: toComp(v.location, fit: fit))
            }
            .onEnded { _ in
                dragFrozen = false
                if cameraStart != nil { if pinchOnLayer == nil { state.endCameraGesture() }; cameraStart = nil }
                if let k = puppetDragPin { if k >= 0 { state.endEdit() }; puppetDragPin = nil }
                if let m = maskDrag { state.endMaskDrag(m); maskDrag = nil }
                if canvasDragState != nil { state.endCanvasDrag() }
                if marqueeStart != nil { finishMarquee(fit: fit) }
                canvasDragState = nil
                panBase = nil
            }
    }

    /// Top-most layer under a point (other than the selected one).
    private func layerAt(_ point: CGPoint, fit: CGRect) -> UUID? {
        let c = toComp(point, fit: fit)
        for layer in state.displayProject.layers where layer.isActive(at: state.currentTime) && layer.id != state.selectedLayerID
            && (!state.linkPicking || state.layerPickAllows(layer.id))
            && layer.content != .camera && layer.content != .light && !layer.isAudioOnly {
            let M = Renderer.placementMatrix(layer, camera: Renderer.activeCamera(state.canvasViewProject(state.project), time: state.currentTime),
                                             time: state.currentTime, renderScale: 1)
            let h = M.inverse * SIMD3(c.x, c.y, 1)
            let hs = Renderer.layerHalfSize(layer, time: state.currentTime)
            if abs(h.x / h.z) <= hs.x && abs(h.y / h.z) <= hs.y { return layer.id }
        }
        return nil
    }

    /// Selects the top-most layer whose bounds contain the tap; tapping the same spot again steps to the next one below.
    private func tapSelect(at point: CGPoint, fit: CGRect) {
        let c = toComp(point, fit: fit)
        var hits: [UUID] = []
        for layer in state.displayProject.layers where layer.isActive(at: state.currentTime) && !layer.isLocked
            && layer.content != .adjustment && layer.content != .camera && layer.content != .light && !layer.isAudioOnly {
            let M = Renderer.placementMatrix(layer, camera: Renderer.activeCamera(state.canvasViewProject(state.project), time: state.currentTime),
                                             time: state.currentTime, renderScale: 1)
            let h = M.inverse * SIMD3(c.x, c.y, 1)
            let local = SIMD3(h.x / h.z, h.y / h.z, 1)
            let hs = Renderer.layerHalfSize(layer, time: state.currentTime)
            if abs(local.x) <= hs.x && abs(local.y) <= hs.y { hits.append(layer.id) }
        }
        let same = lastTapPoint.map { hypot($0.x - point.x, $0.y - point.y) < 14 } ?? false
        lastTapPoint = point
        state.select(CanvasPick.next(hits: hits, current: state.selectedLayerID, sameSpot: same))
    }
}

/// Darkens everything except the layer being edited (typing focus).
struct FocusDim: View {
    let project: Project
    let layerID: UUID
    let time: Double
    let fit: CGRect

    var body: some View {
        Canvas { ctx, size in
            var path = Path(CGRect(origin: .zero, size: size))
            if let l = Renderer.resolveParenting(project, time: time).layers.first(where: { $0.id == layerID }) {
                let s = Double(fit.width) / Double(max(project.width, 1))
                let M = Renderer.placementMatrix(l, camera: Renderer.activeCamera(project, time: time), time: time, renderScale: s)
                let hs = Renderer.layerHalfSize(l, time: time)
                let pad = 14.0
                let pts = [(-hs.x - pad, -hs.y - pad), (hs.x + pad, -hs.y - pad), (hs.x + pad, hs.y + pad), (-hs.x - pad, hs.y + pad)].map { c -> CGPoint in
                    let q = M * SIMD3(c.0, c.1, 1)
                    return CGPoint(x: fit.minX + CGFloat(q.x / max(q.z, 1e-6)), y: fit.minY + CGFloat(q.y / max(q.z, 1e-6)))
                }
                var hole = Path(); hole.addLines(pts); hole.closeSubpath()
                path.addPath(hole)
                ctx.stroke(hole, with: .color(Theme.accentGlow.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            ctx.fill(path, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
        }
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
        // Small layers (short text, tiny shapes): lighter handles so the content stays visible.
        let shortSide = min(hypot(corners[1].x - corners[0].x, corners[1].y - corners[0].y),
                            hypot(corners[3].x - corners[0].x, corners[3].y - corners[0].y))
        let compact = shortSide < 56
        ZStack {
            Path { path in
                path.addLines(corners)
                path.closeSubpath()
            }
            .stroke(Theme.accentGlow, style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
            Path { p in p.move(to: h.edges[0]); p.addLine(to: h.rotate) }.stroke(Theme.accentGlow.opacity(0.7), lineWidth: 1)
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(.white).frame(width: compact ? 6 : 11, height: compact ? 6 : 11)
                    .overlay(Circle().stroke(Theme.accent, lineWidth: compact ? 1 : 1.5))
                    .position(corners[i])
                if !compact {
                    RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 9, height: 9)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.accent, lineWidth: 1.5))
                        .position(h.edges[i])
                }
            }
            Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white, Theme.accent)
                .position(h.rotate)
            if !compact || tool == .pivot {
                Image(systemName: tool == .pivot ? "scope" : "plus.circle")
                    .font(.system(size: tool == .pivot ? 22 : 14, weight: .bold))
                    .foregroundStyle(tool == .pivot ? Theme.warning : Theme.accentGlow)
                    .position(x: fit.minX + ap.x, y: fit.minY + ap.y)
            }
        }
    }
}

struct TransportBar: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var clipboard = LayerClipboard.shared
    @State private var showStylePaste = false
    @State private var clipboardOpen = false
    @Binding var showHistory: Bool
    @Binding var viewZoom: CGFloat
    @Binding var zoomBase: CGFloat
    @Binding var viewPan: CGSize

    var body: some View {
        HStack(spacing: 0) {
            button("arrow.uturn.backward", enabled: state.canUndo) { state.undo() }.accessibilityLabel("Undo")
            button("arrow.uturn.forward", enabled: state.canRedo) { state.redo() }.accessibilityLabel("Redo")
            ViewMenuButton(state: state, viewZoom: $viewZoom, zoomBase: $zoomBase, viewPan: $viewPan)
            Spacer()
            button("backward.end.fill") { state.pause(); state.seek(0) }.accessibilityLabel("Go to Start")
            button("chevron.left") { state.stepFrame(-1) }.accessibilityLabel("Previous Frame")
            Button { state.togglePlay() } label: {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 38, height: 44)
            }
            .accessibilityLabel(state.isPlaying ? "Pause" : "Play")
            button("chevron.right") { state.stepFrame(1) }.accessibilityLabel("Next Frame")
            button("forward.end.fill") { state.pause(); state.seek(state.project.duration) }.accessibilityLabel("Go to End")
            Spacer()
            button("diamond.fill", enabled: state.selectedLayer != nil, tint: state.selectedLayer != nil ? Theme.keyframe : nil) { state.keyAllTransform() }
                .accessibilityLabel("Key All")
            button(state.loop ? "repeat" : "repeat.1", tint: state.loop ? Theme.accentGlow : Theme.textDim) { state.loop.toggle() }.accessibilityLabel("Loop")
            button("checklist", tint: state.isMultiSelecting ? Theme.accentGlow : nil) {
                if state.isMultiSelecting { state.endMultiSelect() }
                else if let id = state.selectedLayerID ?? state.project.layers.first?.id { state.beginMultiSelect(id) }
            }
            .accessibilityLabel(state.isMultiSelecting ? "Done Selecting" : "Select Multiple")
            Button { clipboardOpen = true } label: { Image(systemName: "doc.on.clipboard").frame(width: 27, height: 44) }
                .accessibilityLabel("Layer Clipboard")
                .popover(isPresented: $clipboardOpen) {
                    VStack(alignment: .leading, spacing: 0) {
                        clipboardAction("Copy Layer", disabled: state.selectedLayer == nil || clipboard.busy) { state.copyLayer() }
                        clipboardAction("Paste Layer", disabled: clipboard.payload == nil || clipboard.busy) { state.pasteLayer() }
                        clipboardAction("Paste Style…", disabled: state.selectedLayer == nil || clipboard.payload == nil || clipboard.busy) { showStylePaste = true }
                        clipboardAction("Replace Content from Copy", disabled: state.selectedLayer == nil || clipboard.payload == nil || clipboard.busy) { state.pasteLayer(contentOnly: true) }
                        Divider()
                        clipboardAction("Ripple Delete", disabled: state.selectedLayer == nil || state.selectedLayer?.isLocked == true) { state.rippleDeleteSelected() }
                        clipboardAction("Close Gap at Playhead", disabled: state.gapAtPlayhead() == nil) { state.closeGapAtPlayhead() }
                    }.padding(12).frame(width: 280).foregroundStyle(Theme.text).background(Theme.background)
                        .presentationBackground(Theme.background).presentationCompactAdaptation(.popover)
                }
            button("clock.arrow.circlepath") { showHistory = true }.accessibilityLabel("History")
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .awiSheet(isPresented: $showStylePaste) { PasteLayerStyleSheet(state: state).presentationDetents([.medium, .large]) }
    }

    private func clipboardAction(_ title: String, disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button { clipboardOpen = false; action() } label: {
            Text(title).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(disabled)
    }

    private func button(_ icon: String, enabled: Bool = true, tint: Color? = nil, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .frame(width: 27, height: 44)
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.label).foregroundStyle(Theme.text)
                                    Text(state.historyDate(at: i), format: .dateTime.hour().minute().second())
                                        .font(.caption.monospacedDigit()).foregroundStyle(Theme.textDim)
                                }
                                Spacer()
                                Text("Undo to here").font(.caption).foregroundStyle(Theme.textDim)
                            }
                            .frame(minHeight: 44)
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
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
