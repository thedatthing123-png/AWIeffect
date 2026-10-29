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
}

@MainActor
final class EditorState: ObservableObject {
    @Published var project: Project {
        didSet { scheduleAutosave() }
    }
    @Published var currentTime: Double = 0
    @Published var isPlaying = false
    @Published var loop = true
    @Published var selectedLayerID: UUID?
    @Published var panel: ToolPanel = .none
    @Published private(set) var undoStack: [(label: String, project: Project)] = []
    @Published private(set) var redoStack: [(label: String, project: Project)] = []
    @Published var redrawToken = 0

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
        let link = CADisplayLink(target: DisplayLinkProxy { [weak self] in self?.tick() }, selector: #selector(DisplayLinkProxy.fire))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: Float(min(120, max(30, project.fps))))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func pause() {
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

    private func scheduleAutosave() {
        autosaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        autosaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    func saveNow(thumbnail: Bool = false) {
        let snapshot = Date().timeIntervalSince(lastVersionSnapshot) > 120
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
