import Foundation
import SwiftUI
import QuartzCore

/// Which transform-ish property a panel edits (drives keyframe diamonds).
enum PropertyKey: String, CaseIterable, Identifiable {
    case position, scale, rotation, opacity, anchor, size, fill, cornerRadius
    var id: String { rawValue }
    var title: String {
        switch self {
        case .position: return "Position"
        case .scale: return "Scale"
        case .rotation: return "Rotation"
        case .opacity: return "Opacity"
        case .anchor: return "Anchor Point"
        case .size: return "Size"
        case .fill: return "Fill"
        case .cornerRadius: return "Roundness"
        }
    }
}

enum ToolPanel: Equatable {
    case none
    case add
    case transform
    case fill
    case blending
    case shape
    case layerMenu
    case effects
    case text
    case masks
    case clip
    case threeD
    case model
    case physics
    case presets
    case overlays
}

/// Playback time on its own publisher: while playing only the preview and timeline redraw each frame,
/// not every panel in the editor.
@MainActor
final class PlayClock: ObservableObject {
    @Published var time: Double = 0
}

@MainActor
final class EditorState: ObservableObject {
    @Published var project: Project {
        didSet { scheduleAutosave() }
    }
    let clock = PlayClock()
    var currentTime: Double = 0 {
        willSet { if !isPlaying && newValue != currentTime { objectWillChange.send() } }
        didSet { if clock.time != currentTime { clock.time = currentTime } }
    }
    @Published var isPlaying = false
    @Published var loop = true
    @Published var selectedLayerID: UUID?
    @Published var panel: ToolPanel = .none
    @Published private(set) var undoStack: [(label: String, project: Project)] = []
    @Published private(set) var redoStack: [(label: String, project: Project)] = []
    @Published var redrawToken = 0
    /// Canvas drag mode (Move / Scale / Rotate / Pivot) and whether scale keeps proportions.
    @Published var transformTool: TransformTool = .move
    @Published var scaleLinked = true
    /// Viewport: comp view or free 3D orbit view.
    @Published var viewMode: ViewMode = .comp
    @Published var orbit = OrbitCamera.home
    /// Parents of the currently open pre-comp (empty at the top level).
    @Published var compStack: [(project: Project, time: Double, selected: UUID?)] = []

    let store: ProjectStore
    private var displayLink: CADisplayLink?
    private var playStartWall: CFTimeInterval = 0
    private var playStartTime: Double = 0
    private var autosaveWork: DispatchWorkItem?
    private var lastVersionSnapshot = Date.distantPast
    /// Coalesces continuous edits (slider drags) into one undo step.
    private var editGroupOpen = false

    init(project: Project, store: ProjectStore = .shared) {
        self.project = project
        self.store = store
    }

    // MARK: Selection

    var selectedIndex: Int? {
        guard let id = selectedLayerID else { return nil }
        return project.layers.firstIndex { $0.id == id }
    }

    var selectedLayer: Layer? { selectedIndex.map { project.layers[$0] } }

    func select(_ id: UUID?) {
        selectedLayerID = id
        if id == nil { panel = .none } else if panel == .none || panel == .add { panel = .transform }
    }

    // MARK: Undo

    func beginEdit(_ label: String) {
        guard !editGroupOpen else { return }
        editGroupOpen = true
        pushUndo(label)
    }

    func endEdit() { editGroupOpen = false }

    private func pushUndo(_ label: String) {
        undoStack.append((label, project))
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    /// One-shot mutation with its own undo step.
    func mutate(_ label: String, _ change: (inout Project) -> Void) {
        if !editGroupOpen { pushUndo(label) }
        var p = project
        change(&p)
        p.modifiedAt = Date()
        project = p
    }

    /// Continuous mutation (slider drag / canvas drag): call beginEdit first, endEdit after.
    func mutateLayer(_ change: (inout Layer) -> Void) {
        guard let i = selectedIndex else { return }
        var p = project
        change(&p.layers[i])
        p.modifiedAt = Date()
        project = p
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append((last.label, project))
        project = last.project
        validateSelection()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append((next.label, project))
        project = next.project
        validateSelection()
    }

    func jumpToHistory(index: Int) {
        while undoStack.count > index { undo() }
    }

    private func validateSelection() {
        if let id = selectedLayerID, !project.layers.contains(where: { $0.id == id }) { select(nil) }
    }

    // MARK: Layers

    func addShape(_ kind: ShapeKind) {
        let side = Double(min(project.width, project.height)) * 0.3
        mutate("Add \(kind.title)") { p in
            var l = p.makeLayer(name: "\(kind.title) \(p.layers.count + 1)", content: .shape(kind), size: Vec2(side, side))
            l.fill = Animated(RGBA(hex: [0x9B5CFF, 0x5CC8FF, 0xFF5CA8, 0xFFC75C, 0x5CFFB0][p.layers.count % 5]))
            if kind == .polygon { l.sides = Animated(6) }
            if kind == .star { l.sides = Animated(5) }
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .transform
    }

    func addSolid() {
        mutate("Add Solid") { p in
            var l = p.makeLayer(name: "Solid \(p.layers.count + 1)", content: .solid, size: Vec2(Double(p.width), Double(p.height)))
            l.fill = Animated(RGBA(hex: 0x211A2D))
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .transform
    }

    func addImage(data: Data, ext: String) {
        guard let ui = UIImage(data: data), let cg = ui.cgImage else { return }
        guard let name = try? store.importMedia(data: data, ext: ext, into: project.id) else { return }
        let pw = cg.width, ph = cg.height
        // Fit inside the comp like Alight Motion does.
        let fit = min(Double(project.width) / Double(pw), Double(project.height) / Double(ph), 1)
        mutate("Add Image") { p in
            var l = p.makeLayer(name: "Image \(p.layers.count + 1)", content: .image(fileName: name, pixelWidth: pw, pixelHeight: ph),
                                size: Vec2(Double(pw), Double(ph)))
            l.transform.scale = Animated(Vec2(fit * 100, fit * 100))
            l.fill = Animated(.white)
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .transform
    }

    func deleteSelected() {
        guard let i = selectedIndex else { return }
        mutate("Delete Layer") { $0.layers.remove(at: i) }
        select(nil)
    }

    func duplicateSelected() {
        guard let i = selectedIndex else { return }
        mutate("Duplicate Layer") { p in
            var copy = p.layers[i]
            copy.id = UUID()
            copy.name += " copy"
            p.layers.insert(copy, at: i)
            selectedLayerID = copy.id
        }
    }

    func moveSelected(up: Bool) {
        guard let i = selectedIndex else { return }
        let j = up ? i - 1 : i + 1
        guard project.layers.indices.contains(j) else { return }
        mutate(up ? "Move Layer Up" : "Move Layer Down") { $0.layers.swapAt(i, j) }
    }

    func toggleVisibility(_ id: UUID) {
        guard let i = project.layers.firstIndex(where: { $0.id == id }) else { return }
        mutate("Toggle Visibility") { $0.layers[i].isVisible.toggle() }
    }

    func splitSelected() {
        guard let i = selectedIndex else { return }
        let t = currentTime
        let l = project.layers[i]
        guard t > l.inPoint + project.frameDuration / 2, t < l.outPoint - project.frameDuration / 2 else { return }
        mutate("Split Layer") { p in
            var second = p.layers[i]
            second.id = UUID()
            second.inPoint = t
            p.layers[i].outPoint = t
            p.layers.insert(second, at: i)
            selectedLayerID = second.id
        }
    }

    // MARK: Effects

    func addEffect(_ def: EffectDefinition) {
        guard let i = selectedIndex else { return }
        mutate("Add \(def.name)") { $0.layers[i].effects.append(def.makeInstance()) }
        panel = .effects
    }

    func removeEffect(_ id: UUID) {
        guard let i = selectedIndex else { return }
        mutate("Remove Effect") { $0.layers[i].effects.removeAll { $0.id == id } }
    }

    func toggleEffect(_ id: UUID) {
        guard let i = selectedIndex, let j = project.layers[i].effects.firstIndex(where: { $0.id == id }) else { return }
        mutate("Toggle Effect") { $0.layers[i].effects[j].isEnabled.toggle() }
    }

    func moveEffect(_ id: UUID, up: Bool) {
        guard let i = selectedIndex, let j = project.layers[i].effects.firstIndex(where: { $0.id == id }) else { return }
        let k = up ? j - 1 : j + 1
        guard project.layers[i].effects.indices.contains(k) else { return }
        mutate("Reorder Effect") { $0.layers[i].effects.swapAt(j, k) }
    }

    func duplicateEffect(_ id: UUID) {
        guard let i = selectedIndex, let j = project.layers[i].effects.firstIndex(where: { $0.id == id }) else { return }
        mutate("Duplicate Effect") { p in
            var e = p.layers[i].effects[j]
            e.id = UUID()
            p.layers[i].effects.insert(e, at: j + 1)
        }
    }

    /// Continuous param edit (slider drag): wrap with beginEdit/endEdit.
    func setEffectParam(_ effectID: UUID, _ key: String, _ change: (inout ParamValue, Double) -> Void) {
        guard let i = selectedIndex, let j = project.layers[i].effects.firstIndex(where: { $0.id == effectID }),
              var v = project.layers[i].effects[j].params[key] else { return }
        change(&v, currentTime)
        var p = project
        p.layers[i].effects[j].params[key] = v
        p.modifiedAt = Date()
        project = p
    }

    func effectParamHasKeyframe(_ effectID: UUID, _ key: String) -> (filled: Bool, animated: Bool) {
        guard let e = selectedLayer?.effects.first(where: { $0.id == effectID }), let v = e.params[key] else { return (false, false) }
        switch v {
        case .number(let a): return (a.hasKeyframe(at: currentTime), a.isAnimated)
        case .point(let a): return (a.hasKeyframe(at: currentTime), a.isAnimated)
        case .color(let a): return (a.hasKeyframe(at: currentTime), a.isAnimated)
        default: return (false, false)
        }
    }

    func toggleEffectKeyframe(_ effectID: UUID, _ key: String) {
        beginEdit("Keyframe")
        setEffectParam(effectID, key) { v, t in
            switch v {
            case .number(var a): a.toggleKeyframe(at: t); v = .number(a)
            case .point(var a): a.toggleKeyframe(at: t); v = .point(a)
            case .color(var a): a.toggleKeyframe(at: t); v = .color(a)
            default: break
            }
        }
        endEdit()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func addAdjustmentLayer() {
        mutate("Add Adjustment Layer") { p in
            var l = p.makeLayer(name: "Adjustment \(p.layers.count + 1)", content: .adjustment,
                                size: Vec2(Double(p.width), Double(p.height)))
            l.fill = Animated(RGBA(1, 1, 1, 0))
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .effects
    }

    // MARK: Keyframes

    func hasKeyframe(_ key: PropertyKey) -> Bool {
        guard let l = selectedLayer else { return false }
        let t = currentTime
        switch key {
        case .position: return l.transform.position.hasKeyframe(at: t)
        case .scale: return l.transform.scale.hasKeyframe(at: t)
        case .rotation: return l.transform.rotation.hasKeyframe(at: t)
        case .opacity: return l.transform.opacity.hasKeyframe(at: t)
        case .anchor: return l.transform.anchor.hasKeyframe(at: t)
        case .size: return l.size.hasKeyframe(at: t)
        case .fill: return l.fill.hasKeyframe(at: t)
        case .cornerRadius: return l.cornerRadius.hasKeyframe(at: t)
        }
    }

    func isAnimated(_ key: PropertyKey) -> Bool {
        guard let l = selectedLayer else { return false }
        switch key {
        case .position: return l.transform.position.isAnimated
        case .scale: return l.transform.scale.isAnimated
        case .rotation: return l.transform.rotation.isAnimated
        case .opacity: return l.transform.opacity.isAnimated
        case .anchor: return l.transform.anchor.isAnimated
        case .size: return l.size.isAnimated
        case .fill: return l.fill.isAnimated
        case .cornerRadius: return l.cornerRadius.isAnimated
        }
    }

    func toggleKeyframe(_ key: PropertyKey) {
        guard let i = selectedIndex else { return }
        let t = currentTime
        mutate("Keyframe \(key.title)") { p in
            switch key {
            case .position: p.layers[i].transform.position.toggleKeyframe(at: t)
            case .scale: p.layers[i].transform.scale.toggleKeyframe(at: t)
            case .rotation: p.layers[i].transform.rotation.toggleKeyframe(at: t)
            case .opacity: p.layers[i].transform.opacity.toggleKeyframe(at: t)
            case .anchor: p.layers[i].transform.anchor.toggleKeyframe(at: t)
            case .size: p.layers[i].size.toggleKeyframe(at: t)
            case .fill: p.layers[i].fill.toggleKeyframe(at: t)
            case .cornerRadius: p.layers[i].cornerRadius.toggleKeyframe(at: t)
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func setInterpolation(_ interp: Interpolation) {
        guard let i = selectedIndex else { return }
        mutate("Easing") { p in
            p.layers[i].transform.position.setInterpolation(interp)
            p.layers[i].transform.scale.setInterpolation(interp)
            p.layers[i].transform.rotation.setInterpolation(interp)
            p.layers[i].transform.opacity.setInterpolation(interp)
            p.layers[i].transform.anchor.setInterpolation(interp)
            p.layers[i].size.setInterpolation(interp)
            p.layers[i].fill.setInterpolation(interp)
            p.layers[i].cornerRadius.setInterpolation(interp)
        }
    }

    /// Keyframe times of the selected layer for prev/next navigation.
    func jumpKeyframe(forward: Bool) {
        guard let l = selectedLayer else { return }
        let times = l.keyframeTimes
        let eps = 1e-4
        if forward, let t = times.first(where: { $0 > currentTime + eps }) { seek(t) }
        if !forward, let t = times.last(where: { $0 < currentTime - eps }) { seek(t) }
    }

    // MARK: Playback

    func seek(_ t: Double) {
        currentTime = project.snapToFrame(t)
    }

    func stepFrame(_ delta: Int) {
        pause()
        seek(currentTime + Double(delta) * project.frameDuration)
    }

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        guard !isPlaying else { return }
        if currentTime >= project.duration - project.frameDuration / 2 { currentTime = 0 }
        isPlaying = true
        playStartWall = CACurrentMediaTime()
        playStartTime = currentTime
        let pid = project.id, st = store
        AudioPreview.shared.play(project, from: currentTime, mediaURL: { st.mediaURL($0, projectID: pid) })
        let link = CADisplayLink(target: DisplayLinkProxy { [weak self] in self?.tick() }, selector: #selector(DisplayLinkProxy.fire))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: Float(min(120, max(30, project.fps))))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func pause() {
        AudioPreview.shared.pause()
        if isPlaying { objectWillChange.send() }
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
        currentTime = project.snapToFrame(currentTime)
    }

    private func tick() {
        var t = playStartTime + (CACurrentMediaTime() - playStartWall)
        if t >= project.duration {
            if loop {
                t = t.truncatingRemainder(dividingBy: max(project.duration, 0.001))
                playStartWall = CACurrentMediaTime()
                playStartTime = t
            } else {
                currentTime = project.duration
                pause()
                return
            }
        }
        // Quantize to project frames so playback shows exactly the frames export will.
        let q = (t * project.fps).rounded(.down) / project.fps
        if q != currentTime { currentTime = q }
    }

    // MARK: Saving

    private static let saveQueue = DispatchQueue(label: "awi.autosave", qos: .utility)

    private func scheduleAutosave() {
        autosaveWork?.cancel()
        // Encode + write off the main thread so edits never hitch.
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let project = self.rootProject, store = self.store
            let snapshot = Date().timeIntervalSince(self.lastVersionSnapshot) > 120
            if snapshot { self.lastVersionSnapshot = Date() }
            Self.saveQueue.async {
                do { try store.save(project, snapshotVersion: snapshot) } catch { NSLog("AWIeffect autosave failed: \(error)") }
            }
        }
        autosaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    /// Undo history belongs to one comp; switching comps starts a fresh history.
    func undoBarrier() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    func saveNow(thumbnail: Bool = false) {
        let snapshot = Date().timeIntervalSince(lastVersionSnapshot) > 120
        let project = rootProject
        do {
            try store.save(project, snapshotVersion: snapshot)
            if snapshot { lastVersionSnapshot = Date() }
        } catch {
            NSLog("AWIeffect autosave failed: \(error)")
        }
        if thumbnail, let r = Renderer.shared {
            let pid = project.id
            let st = store
            if let img = r.renderImage(project: project, time: min(currentTime, project.duration), maxDimension: 360,
                                       mediaURL: { st.mediaURL($0, projectID: pid) }) {
                store.saveThumbnail(img, for: project.id)
            }
        }
    }

    func mediaURL(_ name: String) -> URL { store.mediaURL(name, projectID: project.id) }
}

/// Breaks the CADisplayLink -> target retain cycle.
final class DisplayLinkProxy: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func fire() { action() }
}

// MARK: - Expressions

extension EditorState {
    func expression(_ key: PropertyKey) -> String? {
        guard let l = selectedLayer else { return nil }
        switch key {
        case .position: return l.transform.position.expression
        case .scale: return l.transform.scale.expression
        case .rotation: return l.transform.rotation.expression
        case .opacity: return l.transform.opacity.expression
        case .anchor: return l.transform.anchor.expression
        case .size: return l.size.expression
        case .fill: return l.fill.expression
        case .cornerRadius: return l.cornerRadius.expression
        }
    }

    func setExpression(_ key: PropertyKey, _ src: String?) {
        guard let i = selectedIndex else { return }
        let e = (src?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ? nil : src
        mutate(e == nil ? "Remove Expression" : "Expression") { p in
            switch key {
            case .position: p.layers[i].transform.position.expression = e
            case .scale: p.layers[i].transform.scale.expression = e
            case .rotation: p.layers[i].transform.rotation.expression = e
            case .opacity: p.layers[i].transform.opacity.expression = e
            case .anchor: p.layers[i].transform.anchor.expression = e
            case .size: p.layers[i].size.expression = e
            case .fill: p.layers[i].fill.expression = e
            case .cornerRadius: p.layers[i].cornerRadius.expression = e
            }
        }
    }

    func expressionError(_ key: PropertyKey) -> String? {
        guard let l = selectedLayer else { return nil }
        let name: String
        switch key {
        case .position, .scale, .rotation, .opacity, .anchor: name = key.rawValue
        case .size: name = "size"
        case .fill: name = "fill"
        case .cornerRadius: name = "cornerRadius"
        }
        return ExpressionEngine.shared.error(for: "\(l.id)/\(name)")
    }
}

// MARK: - AE presets (.ffx)

extension EditorState {
    /// Applies the effects inside an After Effects preset to the selected layer. Returns the import report.
    @discardableResult
    func applyFFX(url: URL) -> ImportReport? {
        guard let i = selectedIndex else { return nil }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = project.layers[i].size.staticValue
        guard let r = try? FFXImporter.load(url: url, layerSize: size) else { return nil }
        if !r.effects.isEmpty {
            let start = project.layers[i].inPoint
            mutate("Apply Preset \(url.deletingPathExtension().lastPathComponent)") { p in
                // Shift preset keyframes so they start at the layer's in point.
                var fx = r.effects
                for k in fx.indices {
                    for (key, v) in fx[k].params {
                        if case .number(var a) = v, a.isAnimated {
                            for j in a.keyframes.indices { a.keyframes[j].time += start }
                            fx[k].params[key] = .number(a)
                        }
                    }
                }
                p.layers[i].effects += fx
            }
        }
        return r.report
    }
}


// MARK: - Draw Studio

extension EditorState {
    /// Engine for a new drawing (canvas = composition size) or the selected drawing layer.
    func makeDrawEngine(editing layer: Layer?) -> DrawEngine? {
        if let id = layer?.drawingID, let e = DrawEngine.load(doc: id, folder: store.mediaFolder(for: project.id)) { return e }
        return DrawEngine(width: project.width, height: project.height)
    }

    /// Saves the drawing and adds (or live-updates) its image layer so it sits exactly where it was drawn.
    func finishDrawing(_ engine: DrawEngine, editing existing: UUID?) {
        let docID = existing.flatMap { id in project.layers.first { $0.id == id }?.drawingID } ?? UUID()
        let folder = store.mediaFolder(for: project.id)
        guard (try? engine.save(doc: docID, folder: folder)) != nil, let png = engine.flattenedPNG() else { return }
        let file = "draw-\(docID.uuidString)-flat-\(UUID().uuidString.prefix(6)).png"
        guard (try? png.write(to: folder.appendingPathComponent(file), options: .atomic)) != nil else { return }
        Renderer.shared?.clearImageCache()
        let w = engine.width, h = engine.height
        if let id = existing, let i = project.layers.firstIndex(where: { $0.id == id }) {
            mutate("Edit Drawing") { $0.layers[i].content = .image(fileName: file, pixelWidth: w, pixelHeight: h) }
        } else {
            mutate("Add Drawing") { p in
                var l = p.makeLayer(name: "Drawing \(p.layers.count + 1)", content: .image(fileName: file, pixelWidth: w, pixelHeight: h),
                                    size: Vec2(Double(w), Double(h)))
                // Canvas == comp size, so 100% scale at the comp center lands exactly where it was drawn.
                l.drawingID = docID
                l.fill = Animated(.white)
                p.layers.insert(l, at: 0)
                selectedLayerID = l.id
            }
        }
        redrawToken += 1
    }
}


// MARK: - Beats & markers

extension EditorState {
    /// Detects beats in the selected audio/video layer and adds them as markers (comp time).
    func detectBeats(sensitivity: Double = 0.5) {
        guard let l = selectedLayer, l.hasAudio, let file = l.mediaFile else { return }
        let url = mediaURL(file)
        let beats = BeatDetector.beats(url: url, sensitivity: sensitivity)
            .map { l.inPoint + ($0 - l.sourceStart) / max(l.speed, 0.01) }
            .filter { $0 >= l.inPoint && $0 <= l.outPoint }
        mutate("Detect Beats") { $0.markers = Array(Set($0.markers + beats.map { ($0 * 1000).rounded() / 1000 })) }
    }

    /// Manual beat tap (works while playing).
    func tapMarker() {
        let t = currentTime
        project.markers = project.markers + [t]
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    func clearMarkers() { mutate("Clear Markers") { $0.markers = [] } }

    /// Beat-sync script: a punch-in scale + shake hit on the selected layer at every marker.
    func punchOnBeats(scaleAmount: Double = 12, decay: Double = 0.18) {
        guard let i = selectedIndex, !project.markers.isEmpty else { return }
        mutate("Punch on Beats") { p in
            var s = p.layers[i].transform.scale
            let base = s.value(at: p.layers[i].inPoint)
            for m in p.markers where m >= p.layers[i].inPoint && m < p.layers[i].outPoint {
                s.insertKeyframe(Keyframe(time: max(0, m - 0.001), value: base, interpolation: .linear))
                s.insertKeyframe(Keyframe(time: m, value: base * (1 + scaleAmount / 100), interpolation: .bezier,
                                          easeOut: EaseHandle(x: 0.1, y: 0.9), easeIn: .easyIn))
                s.insertKeyframe(Keyframe(time: m + decay, value: base, interpolation: .linear))
            }
            p.layers[i].transform.scale = s
        }
    }

    /// Adds a beat marker at the playhead, or removes the one already there. While playing it never pauses,
    /// so you can tap along with the music.
    func toggleBeatMarker() {
        let t = isPlaying ? currentTime : project.snapToFrame(currentTime)
        let tol = project.frameDuration * 1.5
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        mutate("Beat Marker") { p in
            if let i = p.markers.firstIndex(where: { abs($0 - t) < tol }) { p.markers.remove(at: i) } else { p.markers.append(t) }
        }
    }

    /// Nearest marker to `t` within `tolerance` seconds (timeline snapping).
    func snapToMarker(_ t: Double, tolerance: Double) -> Double {
        guard let m = project.markers.min(by: { abs($0 - t) < abs($1 - t) }), abs(m - t) <= tolerance else { return t }
        return m
    }
}
