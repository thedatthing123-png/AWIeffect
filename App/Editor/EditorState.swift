import Foundation
import SwiftUI
import QuartzCore

/// Which transform-ish property a panel edits (drives keyframe diamonds).
enum PropertyKey: String, CaseIterable, Identifiable {
    case position, scale, rotation, opacity, anchor, size, fill, cornerRadius, positionZ, rotationX, rotationY
    var id: String { rawValue }
    var title: String {
        switch self {
        case .position: return "Position"
        case .scale: return "Scale"
        case .rotation: return "Rotation"
        case .opacity: return "Opacity"
        case .anchor: return "Anchor"
        case .size: return "Size"
        case .fill: return "Fill"
        case .cornerRadius: return "Roundness"
        case .positionZ: return "Position Z"
        case .rotationX: return "Rotation X"
        case .rotationY: return "Rotation Y"
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
    case multi
    case beats
    case cutout
    case style
    case motionBlur
    case scene
    case time
    case scene3D
    case puppet
    case ccStudio
    case rig
    case boneWeight
    /// Tile grid for the selected layer (opened by tapping its clip).
    case layerHome
    /// Flow-style easing / graph editor for the selected layer's keyframes.
    case graph
}

/// The project as it looks mid-gesture. While a finger drags a layer on the canvas only the preview and the
/// selection box watch this; the rest of the editor (timeline, panels) updates once when the finger lifts.
@MainActor
final class LiveCanvas: ObservableObject {
    private(set) var revision: UInt64 = 0
    @Published var project: Project? { didSet { revision &+= 1 } }
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
        didSet { geometryRevision &+= 1; propertyLaneCache.invalidate(old: oldValue, new: project); scheduleAutosave() }
    }
    private(set) var geometryRevision: UInt64 = 0
    var rigGeometryCache: RigGeometryFrame?
    let propertyLaneCache = PropertyLaneCache()
    let clock = PlayClock()
    let live = LiveCanvas()
    /// Puppet: drags keyframe pins at the playhead.
    @Published var remapDragging = false
    @Published var puppetAnimate = true
    /// Puppet: taps add pins only while Place is on; off = pins stay put and drags only move them.
    @Published var puppetPlace = true
    /// Selected pin for the indirect X/Y position pad. UI-only; never serialized.
    @Published var selectedPuppetPin: Int? = nil
    /// Motion Sketch: moving the layer records position keyframes in real time.
    @Published var motionSketch = false
    /// Show the selected layer's motion path on the canvas.
    @Published var showMotionPath = true
    @Published var snappingEnabled = true
    /// R2 snapping options: grid lines (when the grid is shown), rotation in 15 degree steps, user guides.
    @Published var snapToGrid = true
    @Published var gridDivisions = 3
    @Published var rotationSnap = false
    @Published var showGuides = true
    /// Tap-a-layer pick for something other than parenting (IK limbs, camera focus). nil = Link (parent).
    var layerPickHandler: ((UUID?) -> Void)?
    var layerPickReturnPanel: ToolPanel = .transform
    var layerPickPrompt = "Tap a layer"
    /// Make-IK picks (kept here: the Rig panel closes while you tap a layer on the canvas).
    @Published var boneParentPicking: UUID?
    @Published var boneRestEditing = false { didSet { if boneRestEditing && !oldValue { boneRestDirty = false } } }
    var boneRestDirty = false
    @Published var boneMeshDetail = 32.0
    @Published var boneWeightArtworkID: UUID? { didSet { redrawToken &+= 1 } }
    @Published var boneWeightBoneID: UUID? { didSet { redrawToken &+= 1 } }
    @Published var boneWeightPreview: BoneMeshBinding?
    @Published var boneWeightRadius = 40.0
    @Published var boneWeightStrength = 25.0
    @Published var boneWeightHardness = 0.0
    @Published var boneWeightBrush: BoneWeightBrush = .paint
    @Published var boneViewportGesture = false
    @Published var meshInfluenceRadius = 60.0
    @Published var boneMeshCoverage: BoneMeshCoverage = .localized
    @Published var boneDrawingArtworkID: UUID?
    @Published var boneDrawingParentID: UUID?
    @Published var ikDraftUpper: UUID?
    @Published var ikDraftController: UUID?
    /// Optional artwork that should attach to the solved wrist/ankle joint on bind.
    @Published var ikDraftHand: UUID?
    /// Rest endpoint in artwork coordinates, owned by one layer; changing selection cannot reuse another limb's tip.
    @Published var ikDraftTip: (layerID: UUID, point: Vec2)?
    var sketchStartTime: Double?
    var sketchStartClock: CFTimeInterval = 0
    /// Motion Sketch samples per layer (multi-selection records every moved layer).
    var sketchSamples: [UUID: [(Double, Vec2)]] = [:]
    /// Position tracks as they were when the sketch began (the live drag writes into them).
    var sketchBase: [UUID: Animated<Vec2>] = [:]
    /// The searchable Add Light browser.
    @Published var showLightBrowser = false
    /// Cutout refine tools on the canvas.
    /// Ephemeral cutout preview: never autosaved or exported until an actual action commits.
    @Published var cutoutPreview: (layer: UUID, settings: CutoutSettings)? = nil
    @Published var cutoutPeekOriginal: UUID? = nil
    @Published var cutoutTool: CutoutTool = .none
    @Published var cutoutBrushSubtract = false
    @Published var cutoutBrushSize = 40.0
    @Published var cutoutWholeClip = false
    @Published var cutoutFixSpan = 0.5
    /// Smart brush: strokes snap to the edges of the part they're painted on.
    @Published var cutoutSmart = true
    /// Link mode: the panel steps aside and the next tap on a layer makes it this layer's parent.
    @Published var linkPicking = false
    /// Link pick is choosing a track matte layer (Blending) instead of a parent.
    @Published var linkPickMatte: TrackMatte?
    @Published var isDetectingBeats = false
    @Published var recoveryNotice: String?
    @Published var saveError: String?
    @Published var beatStatus: String?
    var preRenderTask: Task<Void, Never>?
    var preRenderExporter: Exporter?
    @Published var preRenderProgress: Double?
    var motionTrackingTask: Task<Void, Never>?
    private var beatTask: Task<Void, Never>?
    /// Typing on the canvas: the timeline and panels step aside for the keyboard, the rest is dimmed.
    @Published var textTyping = false
    /// Camera view (what the export sees) vs free view (look around without the camera; the camera shows as a frame).
    @Published var cameraView = true
    /// Grid over the canvas.
    @Published var showGrid = false
    /// Effect setting the Graph is showing (nil = transform properties).
    @Published var graphTimeRemap = false
    @Published var graphEffect: GraphEffectTarget? { didSet { if graphEffect != nil { graphTimeRemap = false } } }
    /// True while a canvas drag writes to `live` instead of `project`.
    private(set) var liveGesture = false
    var isLiveGesture: Bool { liveGesture }
    private var scrubbing = false
    /// Scale / rotation when a two-finger pinch began.
    var pinchStart: (scale: Vec2, rotation: Double)?
    /// Start positions of every selected layer while a multi-selection is dragged on the canvas.
    var multiDragStarts: [UUID: Vec2] = [:]
    /// What the canvas should draw right now (the live gesture copy, else the project).
    var canvasProject: Project { boneMeshDisplayProject(live.project ?? project) }
    var rigRestArtworkID: UUID? { boneWeightArtworkID ?? (boneRestEditing ? rigArtworkID : nil) }
    func boneMeshDisplayProject(_ original: Project) -> Project {
        var shown = original
        if let artwork = rigRestArtworkID {
            for i in shown.layers.indices where shown.layers[i].bone?.artworkID == artwork { shown.layers[i].ik = nil }
            for i in shown.layers.indices where shown.layers[i].id == artwork { if let count = shown.layers[i].boneMesh?.boneIDs.count {
                shown.layers[i].boneMesh?.frameMatrices = Array(repeating: .identity,count: count)
                shown.layers[i].boneMesh?.frameTime = currentTime
            } }
        }
        if let id = boneWeightArtworkID,let i = shown.layers.firstIndex(where: { $0.id == id }),var mesh = boneWeightPreview ?? shown.layers[i].boneMesh {
            mesh.frameMatrices = Array(repeating: .identity,count: mesh.boneIDs.count); mesh.frameTime = currentTime
            mesh.previewWeightIndex = boneWeightBoneID.flatMap { mesh.boneIDs.firstIndex(of: $0) }
            shown.layers[i].boneMesh = mesh
            shown.layers[i].effects.removeAll { !(EffectRegistry.definition($0.typeID)?.isTransformEffect ?? false) }
            shown.motionBlurEnabled = false; shown.smoothMotion = false
        }
        return shown
    }
    var currentTime: Double = 0 {
        willSet { if !isPlaying && newValue != currentTime { objectWillChange.send() } }
        didSet { if clock.time != currentTime { clock.time = currentTime } }
    }
    @Published var isPlaying = false {
        didSet { if isPlaying != oldValue { CrashReporter.note(isPlaying ? "Play" : "Pause") } }
    }
    @Published var loop = true
    @Published var selectedShapeContentID: UUID? = nil
    @Published var selectedLayerID: UUID? {
        willSet {
            if newValue != selectedLayerID,boneRestEditing {
                let nextArtwork = project.layers.first(where: { $0.id == newValue })?.bone?.artworkID
                if nextArtwork == nil || nextArtwork != rigArtworkID {
                    finishBoneRestEditing(); boneRestEditing = false
                }
            }
        }
        didSet { if selectedLayerID != oldValue { keyframeFocusEffects = []; maskSelection = nil; selectedShapeContentID = nil } }
    }
    /// Mask point being edited on the canvas (Masks panel). R2.
    @Published var maskSelection: MaskSelection?
    @Published var panel: ToolPanel = .none {
        didSet {
            if panel != oldValue { CrashReporter.note("Opened \(panel)"); endScrub() }
            if (oldValue == .rig || oldValue == .boneWeight),panel != .rig,panel != .boneWeight {
                if liveGesture { endPanelGesture() }
                if boneRestEditing { finishBoneRestEditing(); boneRestEditing = false }
                boneParentPicking = nil; finishBoneDrawing(); finishBoneWeights()
            }
            if panel != .effects && panel != .graph { keyframeFocusEffects = [] }
        }
    }
    /// Open effects, in the order they were opened: the timeline shows only their keyframes, each effect in its own
    /// color, and only those can be dragged.
    @Published var keyframeFocusEffects: [UUID] = []
    static let focusColors: [Color] = [Theme.ok, Color(red: 0.35, green: 0.75, blue: 1), Theme.warning, Color(red: 1, green: 0.45, blue: 0.75), Color(red: 0.75, green: 0.55, blue: 1)]
    @Published private(set) var undoStack: [(label: String, project: Project)] = []
    @Published private(set) var redoStack: [(label: String, project: Project)] = []
    @Published var redrawToken = 0
    /// Canvas drag mode (Move / Scale / Rotate / Pivot) and whether scale keeps proportions.
    @Published var transformTool: TransformTool = .move
    @Published var scaleLinked = true
    /// Viewport: comp view or free 3D orbit view.
    @Published var viewMode: ViewMode = .comp
    /// Multi-select set (nil = normal single selection) and the row the range drag started from.
    @Published var multiSelection: Set<UUID>?
    var multiAnchor: UUID?
    /// Transform values copied with "Copy Keys".
    @Published var keyClipboard: KeyClipboard?
    /// Effect stack copied with "Copy Effects" (pasted onto any layer).
    @Published var effectClipboard: [EffectInstance] = []
    /// Where the copied effects' layer started, so pasted keyframes keep their place relative to the new layer.
    var effectClipboardStart = 0.0
    @Published var snapGuides = SnapGuides()
    @Published var previewQuality: PreviewQuality = .full
    @Published var orbit = OrbitCamera.home
    /// A 3D-view handle is being dragged (the view itself must not orbit meanwhile).
    @Published var orbitHandleDrag = false
    /// Parents of the currently open pre-comp (empty at the top level).
    @Published var compStack: [CompositionEditContext] = []

    let store: ProjectStore
    private var displayLink: CADisplayLink?
    private var playStartWall: CFTimeInterval = 0
    private var playStartTime: Double = 0
    private var autosaveTask: Task<Void, Never>?
    private var lastVersionSnapshot = Date.distantPast
    /// Coalesces continuous edits (slider drags) into one undo step.
    private(set) var editGroupOpen = false
    private var coalesceWork: DispatchWorkItem?
    private var savedUndo: [(undo: [(label: String, project: Project)], redo: [(label: String, project: Project)])] = []

    init(project: Project, store: ProjectStore = .shared) {
        var initial = project
        initial.distinguishContainerTags()
        self.project = initial
        self.store = store
        if store.recoveredVersions[project.id] != nil {
            recoveryNotice = "Opened the latest readable saved version. The damaged project file has been kept in its project folder."
        }
    }

    // MARK: Selection

    var selectedIndex: Int? {
        guard let id = selectedLayerID else { return nil }
        return project.layers.firstIndex { $0.id == id }
    }

    var selectedLayer: Layer? { selectedIndex.map { project.layers[$0] } }

    func select(_ id: UUID?) {
        if linkPicking { endLinkPick(parent: id); return }
        selectedLayerID = id
        if id == nil { panel = .none } else if panel == .none || panel == .add { panel = .transform }
    }

    /// Tap on a clip or its row: select it and show its menu (the tile grid of everything that layer has).
    func openLayer(_ id: UUID) {
        if linkPicking { endLinkPick(parent: id); return }
        selectedLayerID = id
        panel = .layerHome
    }

    // MARK: Undo

    func beginEdit(_ label: String) {
        guard !editGroupOpen else { return }
        editGroupOpen = true
        pushUndo(label)
    }

    func endEdit() {
        editGroupOpen = false
        coalesceWork?.cancel(); coalesceWork = nil
    }

    private func pushUndo(_ label: String) {
        CrashReporter.note(label)
        undoStack.append((label, project))
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    /// One-shot mutation with its own undo step.
    func mutate(_ label: String, _ change: (inout Project) -> Void) {
        if !editGroupOpen { pushUndo(label) }
        // Mid-gesture (slider / pad / canvas drag): edit the live copy so only the preview redraws.
        if liveGesture, var lp = live.project {
            change(&lp)
            lp.modifiedAt = Date()
            live.project = lp
            return
        }
        var p = project
        change(&p)
        p.fitAutoLength()
        p.modifiedAt = Date()
        project = p
    }

    /// Continuous mutation (slider drag / canvas drag): call beginEdit first, endEdit after.
    func mutateLayer(_ change: (inout Layer) -> Void) {
        guard let i = selectedIndex else { return }
        let before = liveGesture ? (live.project ?? project) : project
        guard before.layers.indices.contains(i) else { return }
        var p = before
        change(&p.layers[i])
        let old = before.layers[i].transform
        if p.layers[i].transform.position != old.position || p.layers[i].transform.positionZ != old.positionZ {
            p.layers[i].transform.pairPositionKeys(previous: old, at: currentTime)
        }
        propagateSelectionTransform(before: before, into: &p, primary: before.layers[i].id)
        p.modifiedAt = Date()
        if liveGesture { live.project = p }
        else { p.fitAutoLength(); project = p }
    }

    /// The project as it was when the open edit group (drag) began; nil outside a drag.
    var editStartProject: Project? { editGroupOpen ? undoStack.last?.project : nil }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Panel controls (swipe pad, dial, rulers): one undo step, live edits until the finger lifts.
    func beginPanelGesture(_ label: String) {
        pause()
        beginEdit(label)
        if !liveGesture { beginLiveGesture() }
    }

    func endPanelGesture() {
        endLiveGesture()
        endEdit()
    }

    /// Slider drags anywhere in the app: edits stay in the live copy while the finger is down, so the rest of the
    /// editor doesn't rebuild on every tiny move (that made sliders lag).
    func beginScrub() {
        guard !liveGesture else { return }
        scrubbing = true
        beginLiveGesture()
    }

    func endScrub() {
        guard scrubbing else { return }
        scrubbing = false
        endLiveGesture()
        endEdit()
    }

    /// Canvas drags: edits go to the lightweight live copy until `endLiveGesture`.
    func beginLiveGesture() {
        liveGesture = true
        live.project = project
    }

    func endLiveGesture() {
        guard liveGesture else { return }
        liveGesture = false
        if var p = live.project {
            p.fitAutoLength()
            p.modifiedAt = Date()
            project = p
        }
        live.project = nil
    }

    func undo() {
        endLiveGesture()
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
        if let m = multiSelection {
            let alive = m.filter { id in project.layers.contains { $0.id == id } }
            if alive.isEmpty { endMultiSelect() } else if alive != m { multiSelection = alive }
        }
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
        guard let name = try? store.importMedia(data: data, ext: ext, into: rootProject.id) else { return }
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
        let id = project.layers[i].id
        if project.layers[i].isGroup { deleteGroup(id); return }
        mutate("Delete Layer") { p in
            Self.unparentKeepingWorld(&p) { $0.parentID == id }
            p.layers.remove(at: i)
        }
        select(nil)
    }

    func duplicateSelected() {
        guard let i = selectedIndex else { return }
        if project.layers[i].isGroup { duplicateGroup(project.layers[i].id); return }
        let selectedID = project.layers[i].id
        let transferred = rigTransferIDs([selectedID])
        if transferred.count > 1 {
            let oldMulti = multiSelection
            multiSelection = [selectedID]; duplicateMulti()
            selectedLayerID = multiSelection?.first; multiSelection = oldMulti
            return
        }
        mutate("Duplicate Layer") { p in
            var copy = p.layers[i]
            copy.id = UUID()
            copy.name += " copy"
            if copy.isContainer { copy.tag = p.nextContainerTag() }
            p.layers.insert(copy, at: i)
            selectedLayerID = copy.id
        }
    }

    func moveSelected(up: Bool) {
        guard let id = selectedLayerID, let i = project.timelineLayers.firstIndex(where: { $0.id == id }) else { return }
        reorderTimelineLayer(id, to: up ? i - 1 : i + 1)
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
        if l.isGroup {
            mutate("Split Group") { p in
                if let id = Self.splitGroup(l.id, at: t, in: &p) { selectedLayerID = id }
            }
            return
        }
        mutate("Split Layer") { p in
            var second = p.layers[i]
            second.id = UUID()
            if second.timeRemap == nil { second.sourceStart += (t - second.inPoint) * second.speed }
            second.inPoint = t
            p.layers[i].outPoint = t
            p.layers.insert(second, at: i)
            selectedLayerID = second.id
        }
    }

    /// Splits a group and every part inside it at `t`. Parts spanning `t` are cut in two, parts that start after `t`
    /// move to the second group, parts that end before it stay in the first. Nested groups and parent links inside
    /// the group are remapped to the second half's copies. Returns the second group's id.
    nonisolated static func splitGroup(_ gid: UUID, at t: Double, in p: inout Project) -> UUID? {
        guard let gi = p.layers.firstIndex(where: { $0.id == gid }) else { return nil }
        let members = descendantIDs(of: gid, in: p)
        let ids = members.union([gid])
        // Everything still running after t gets a second-half copy (the group itself, nested groups, parts).
        let copied = p.layers.filter { ids.contains($0.id) && $0.outPoint > t }
        let remap = Dictionary(uniqueKeysWithValues: copied.map { ($0.id, UUID()) })
        var seconds: [Layer] = []
        for layer in copied {
            var second = layer
            second.id = remap[layer.id]!
            if let g = layer.groupID, let mapped = remap[g] { second.groupID = mapped }
            if let parent = layer.parentID, let mapped = remap[parent] { second.parentID = mapped }
            second.remapRigReferences(remap)
            if layer.isGroup { second.tag = p.nextContainerTag() }
            if layer.inPoint < t {
                if second.timeRemap == nil { second.sourceStart += (t - layer.inPoint) * layer.speed }
                second.inPoint = t
            }
            seconds.append(second)
        }
        // First half: spanning layers end at t; layers that start at/after t live only in the second half.
        let movedOut = Set(copied.filter { $0.id != gid && $0.inPoint >= t }.map(\.id))
        p.layers.removeAll { movedOut.contains($0.id) }
        for k in p.layers.indices where ids.contains(p.layers[k].id) && p.layers[k].outPoint > t { p.layers[k].outPoint = t }
        // Links to a layer that moved wholly to the second half follow it.
        for k in p.layers.indices {
            if let parent = p.layers[k].parentID, movedOut.contains(parent) { p.layers[k].parentID = remap[parent] }
        }
        let insertAt = p.layers.firstIndex(where: { $0.id == gid }) ?? min(gi, p.layers.count)
        p.layers.insert(contentsOf: seconds, at: insertAt)
        return remap[gid]
    }

    // MARK: Effects

    func addEffect(_ def: EffectDefinition) {
        endScrub()
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

    /// Copied effects (one or a whole stack), pasted onto any layer with fresh ids.
    func copyEffects(_ ids: [UUID]? = nil) {
        guard let l = selectedLayer else { return }
        effectClipboard = ids.map { set in l.effects.filter { set.contains($0.id) } } ?? l.effects
        effectClipboardStart = l.inPoint
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func pasteEffects() {
        guard let i = selectedIndex, !effectClipboard.isEmpty else { return }
        let items = effectClipboard.map { e -> EffectInstance in var c = e; c.id = UUID(); return c }
        // Keyframes move with the effect: a key 0.5 s into the copied layer lands 0.5 s into this one.
        let delta = project.layers[i].inPoint - effectClipboardStart
        mutate(items.count == 1 ? "Paste Effect" : "Paste \(items.count) Effects") { p in
            var carrier = p.layers[i]
            carrier.effects = items
            if abs(delta) > 1e-9 {
                var shift = AnimationTraversal(operation: .shift(delta))
                carrier.traverseAnimations(&shift)
            }
            p.layers[i].effects.append(contentsOf: carrier.effects)
        }
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
        // Reads / writes the live copy mid-drag, so the preview follows the slider without rebuilding the editor.
        let src = canvasProject
        guard let i = selectedIndex, src.layers.indices.contains(i),
              let j = src.layers[i].effects.firstIndex(where: { $0.id == effectID }) else { return }
        // Imported / older effects may lack a control: start it from the effect's default instead of ignoring the edit.
        let e = src.layers[i].effects[j]
        guard var v = e.params[key] ?? EffectRegistry.definition(e.typeID)?.params.first(where: { $0.id == key })?.defaultValue else { return }
        change(&v, currentTime)
        mutateLayer { l in if l.effects.indices.contains(j) { l.effects[j].params[key] = v } }
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
        case .position: return l.transform.position.hasKeyframe(at: t) || l.transform.positionZ.hasKeyframe(at: t)
        case .scale: return l.transform.scale.hasKeyframe(at: t)
        case .rotation: return l.transform.rotation.hasKeyframe(at: t)
        case .opacity: return l.transform.opacity.hasKeyframe(at: t)
        case .anchor: return l.transform.anchor.hasKeyframe(at: t)
        case .size: return l.size.hasKeyframe(at: t)
        case .fill: return l.fill.hasKeyframe(at: t)
        case .cornerRadius: return l.cornerRadius.hasKeyframe(at: t)
        case .positionZ: return l.transform.positionZ.hasKeyframe(at: t)
        case .rotationX: return l.transform.rotationX.hasKeyframe(at: t)
        case .rotationY: return l.transform.rotationY.hasKeyframe(at: t)
        }
    }

    func isAnimated(_ key: PropertyKey) -> Bool {
        guard let l = selectedLayer else { return false }
        switch key {
        case .position: return l.transform.position.isAnimated || l.transform.positionZ.isAnimated
        case .scale: return l.transform.scale.isAnimated
        case .rotation: return l.transform.rotation.isAnimated
        case .opacity: return l.transform.opacity.isAnimated
        case .anchor: return l.transform.anchor.isAnimated
        case .size: return l.size.isAnimated
        case .fill: return l.fill.isAnimated
        case .cornerRadius: return l.cornerRadius.isAnimated
        case .positionZ: return l.transform.positionZ.isAnimated
        case .rotationX: return l.transform.rotationX.isAnimated
        case .rotationY: return l.transform.rotationY.isAnimated
        }
    }

    func toggleKeyframe(_ key: PropertyKey) {
        guard let i = selectedIndex else { return }
        let t = currentTime
        mutate("Keyframe \(key.title)") { p in
            switch key {
            case .position, .positionZ:
                var tr = p.layers[i].transform
                let remove = tr.position.hasKeyframe(at: t) || tr.positionZ.hasKeyframe(at: t)
                if remove {
                    if tr.position.hasKeyframe(at: t) { tr.position.toggleKeyframe(at: t) }
                    if tr.positionZ.hasKeyframe(at: t) { tr.positionZ.toggleKeyframe(at: t) }
                } else {
                    tr.position.toggleKeyframe(at: t); tr.positionZ.toggleKeyframe(at: t)
                    tr.pairPositionKeys(previous: p.layers[i].transform, at: t)
                }
                p.layers[i].transform = tr
            case .scale: p.layers[i].transform.scale.toggleKeyframe(at: t)
            case .rotation: p.layers[i].transform.rotation.toggleKeyframe(at: t)
            case .opacity: p.layers[i].transform.opacity.toggleKeyframe(at: t)
            case .anchor: p.layers[i].transform.anchor.toggleKeyframe(at: t)
            case .size: p.layers[i].size.toggleKeyframe(at: t)
            case .fill: p.layers[i].fill.toggleKeyframe(at: t)
            case .cornerRadius: p.layers[i].cornerRadius.toggleKeyframe(at: t)
            case .rotationX: p.layers[i].transform.rotationX.toggleKeyframe(at: t)
            case .rotationY: p.layers[i].transform.rotationY.toggleKeyframe(at: t)
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
        let pid = rootProject.id, st = store
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

    static let saveQueue = DispatchQueue(label: "awi.autosave", qos: .utility)

    private var saveGeneration = 0
    private func scheduleAutosave() {
        autosaveTask?.cancel(); saveGeneration += 1
        let generation = saveGeneration
        autosaveTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 800_000_000) } catch { return }
            guard !Task.isCancelled, let self, self.saveGeneration == generation else { return }
            let project = self.rootProject, store = self.store
            let snapshot = Date().timeIntervalSince(self.lastVersionSnapshot) > AppSettings.versionInterval
            let failure = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                Self.saveQueue.async {
                    do { try store.save(project, snapshotVersion: snapshot); continuation.resume(returning: nil) }
                    catch { continuation.resume(returning: "Changes could not be saved: " + error.localizedDescription) }
                }
            }
            guard !Task.isCancelled, self.saveGeneration == generation else { return }
            self.saveError = failure
            if failure == nil && snapshot { self.lastVersionSnapshot = Date() }
            // Keep the home-screen card current while editing (not only on close), at most every 30 s.
            if failure == nil, !self.isPlaying, Date().timeIntervalSince(self.lastThumbnailSave) > 30 { self.saveThumbnail(project) }
        }
    }

    private var lastThumbnailSave = Date.distantPast

    /// Time the thumbnail shows: the playhead, kept inside the comp (the very end frame is often empty/black).
    nonisolated static func thumbnailTime(current: Double, project: Project) -> Double {
        let last = max(0, project.duration - project.frameDuration)
        return min(max(0, current), last)
    }

    /// Renders the root comp at the playhead's root time into thumb.jpg.
    func saveThumbnail(_ project: Project) {
        guard let r = Renderer.shared else { return }
        lastThumbnailSave = Date()
        let pid = project.id, st = store
        let t = Self.thumbnailTime(current: rootTime(currentTime), project: project)
        if let img = r.renderImage(project: project, time: t, maxDimension: 360, mediaURL: { st.mediaURL($0, projectID: pid) }) {
            store.saveThumbnail(img, for: project.id)
        }
    }

    /// Undo history belongs to one comp; switching comps starts a fresh history.
    func undoBarrier() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Entering a pre-comp parks the parent's history; leaving it brings the history back.
    func pushUndoContext() {
        savedUndo.append((undoStack, redoStack))
        undoStack.removeAll(); redoStack.removeAll()
    }

    func popUndoContext() {
        guard let s = savedUndo.popLast() else { undoBarrier(); return }
        undoStack = s.undo; redoStack = s.redo
    }

    /// Leaving a group / pre-comp: brings the parent's history back and, when anything changed inside, records the
    /// whole inside session as ONE undo step on the parent (undo returns to `before`, redo re-applies the edits).
    func popUndoContext(committing label: String, before: Project, after: Project) {
        popUndoContext()
        guard before != after else { return }
        CrashReporter.note(label)
        undoStack.append((label, before))
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    /// Value scrubbing / color dragging: one undo step per gesture (closes after a short pause), not one per event.
    func coalescedEdit(_ label: String, _ change: (inout Layer) -> Void) {
        beginEdit(label)
        mutateLayer(change)
        coalesceWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.endEdit() }
        coalesceWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }

    /// Project-level twin of `coalescedEdit` (scene background color drags etc.): one undo step per drag.
    func coalescedProjectEdit(_ label: String, _ change: (inout Project) -> Void) {
        beginEdit(label)
        mutate(label, change)
        coalesceWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.endEdit() }
        coalesceWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }

    func saveNow(thumbnail: Bool = false) {
        autosaveTask?.cancel(); saveGeneration += 1
        let snapshot = Date().timeIntervalSince(lastVersionSnapshot) > AppSettings.versionInterval
        let project = rootProject
        do {
            // Drain older queued snapshots before writing the newest project on close/export/retry.
            try Self.saveQueue.sync { try store.save(project, snapshotVersion: snapshot) }
            if snapshot { lastVersionSnapshot = Date() }
            saveError = nil
        } catch {
            saveError = "Changes could not be saved: " + error.localizedDescription
            NSLog("AWIeffect autosave failed: \(error)")
        }
        if thumbnail { saveThumbnail(project) }
    }

    func mediaURL(_ name: String) -> URL { store.mediaURL(name, projectID: rootProject.id) }
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
        case .positionZ: return l.transform.positionZ.expression
        case .rotationX: return l.transform.rotationX.expression
        case .rotationY: return l.transform.rotationY.expression
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
            case .positionZ: p.layers[i].transform.positionZ.expression = e
            case .rotationX: p.layers[i].transform.rotationX.expression = e
            case .rotationY: p.layers[i].transform.rotationY.expression = e
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
        case .positionZ: name = "positionZ"
        case .rotationX: name = "rotationX"
        case .rotationY: name = "rotationY"
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
        if !r.textAnimators.isEmpty, project.layers[i].text != nil {
            let start = max(project.layers[i].inPoint, currentTime)
            mutate("Apply Text Preset \(url.deletingPathExtension().lastPathComponent)") { p in
                p.layers[i].text?.animators += r.textAnimators.map { a in
                    var a = a
                    a.selector.start.keyframes = a.selector.start.keyframes.map { var k = $0; k.time += start; return k }
                    a.selector.end.keyframes = a.selector.end.keyframes.map { var k = $0; k.time += start; return k }
                    a.selector.offset.keyframes = a.selector.offset.keyframes.map { var k = $0; k.time += start; return k }
                    a.selector.amount.keyframes = a.selector.amount.keyframes.map { var k = $0; k.time += start; return k }
                    return a
                }
            }
        }
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
        if let id = layer?.drawingID, let e = DrawEngine.load(doc: id, folder: store.mediaFolder(for: rootProject.id)) { return e }
        guard let e = DrawEngine(width: project.width, height: project.height) else { return nil }
        // Redraw on a photo / video frame: bring the layer in exactly where it sits in the scene.
        if let layer, layer.mediaFile != nil, let r = Renderer.shared {
            var solo = project
            solo.layers = Renderer.resolveParenting(project, time: currentTime).layers.filter { $0.id == layer.id }
            solo.background.a = 0
            let pid = rootProject.id, st = store
            if let img = r.renderImage(project: solo, time: currentTime, maxDimension: Double(max(project.width, project.height)),
                                       mediaURL: { st.mediaURL($0, projectID: pid) }) {
                e.importImage(img)
                if case .video = layer.content {
                    // Video frames are a tracing guide only: paint on the layer above.
                    e.referenceLayerID = e.layers.last?.id
                }
                e.addLayer(name: "Paint")
            }
        }
        return e
    }

    /// Every Art Studio layer becomes its own image layer, cropped tight and placed exactly where it was drawn
    /// (pivot at the part's center), ready to rotate / bend / wave — no exporting parts one by one.
    func finishDrawingParts(_ engine: DrawEngine) {
        let parts = engine.partPNGs()
        guard !parts.isEmpty else { return }
        var made: [(String, String, CGRect)] = []
        for part in parts {
            guard let name = try? store.importMedia(data: part.png, ext: "png", into: rootProject.id) else { continue }
            made.append((part.name, name, part.rect))
        }
        Renderer.shared?.clearImageCache()
        var newIDs = Set<UUID>()
        mutate("Add \(made.count) Parts") { p in
            var insert: [Layer] = []
            for (title, file, r) in made {
                var l = p.makeLayer(name: title, content: .image(fileName: file, pixelWidth: Int(r.width), pixelHeight: Int(r.height)),
                                    size: Vec2(Double(r.width), Double(r.height)))
                l.fill = Animated(.white)
                // Canvas == comp size, so the crop's center is where the part sits in the comp.
                l.transform.position = Animated(Vec2(Double(r.midX), Double(r.midY)))
                l.tag = .teal
                insert.append(l)
                newIDs.insert(l.id)
            }
            p.layers.insert(contentsOf: insert, at: 0)
        }
        if let first = newIDs.first { selectedLayerID = first }
        redrawToken += 1
    }

    /// Saves the drawing and adds (or live-updates) its image layer so it sits exactly where it was drawn.
    /// Frame-by-frame drawing -> a pre-comp where each frame is an image held 1/fps (loops by extending it).
    func finishDrawingFrames(_ engine: DrawEngine) {
        let pngs = engine.framePNGs()
        guard !pngs.isEmpty else { return }
        let fps = max(1, engine.fps)
        let files = pngs.compactMap { try? store.importMedia(data: $0, ext: "png", into: rootProject.id) }
        guard !files.isEmpty else { return }
        Renderer.shared?.clearImageCache()
        let w = engine.width, h = engine.height
        let dur = Double(files.count) / fps
        var comp = Project.new(name: "Animation \(project.precomps.count + 1)", width: project.width, height: project.height,
                               fps: project.fps, duration: dur, background: RGBA(0, 0, 0, 0))
        for (k, f) in files.enumerated() {
            var l = comp.makeLayer(name: "Frame \(k + 1)", content: .image(fileName: f, pixelWidth: w, pixelHeight: h), size: Vec2(Double(w), Double(h)))
            l.fill = Animated(.white)
            l.inPoint = Double(k) / fps
            l.outPoint = Double(k + 1) / fps
            comp.layers.insert(l, at: 0)
        }
        let start = currentTime
        var newID = UUID()
        mutate("Add Animation") { p in
            var all = p.precomps; all.append(comp); p.precomps = all
            var pl = p.makeLayer(name: comp.name, content: .precomp(id: comp.id), size: Vec2(Double(p.width), Double(p.height)))
            pl.inPoint = start
            pl.outPoint = min(max(p.duration, start + dur), start + dur)
            if start + dur > p.duration { p.duration = start + dur }
            pl.sourceStart = 0
            pl.tag = p.nextContainerTag()
            newID = pl.id
            p.layers.insert(pl, at: 0)
        }
        selectedLayerID = newID
        redrawToken += 1
    }

    func finishDrawing(_ engine: DrawEngine, editing existing: UUID?) {
        if engine.sendAsFrames { finishDrawingFrames(engine); return }
        if engine.sendAsParts { finishDrawingParts(engine); return }
        let docID = existing.flatMap { id in project.layers.first { $0.id == id }?.drawingID } ?? UUID()
        let folder = store.mediaFolder(for: rootProject.id)
        guard (try? engine.save(doc: docID, folder: folder)) != nil, let png = engine.flattenedPNG() else { return }
        let file = "draw-\(docID.uuidString)-flat-\(UUID().uuidString.prefix(6)).png"
        guard (try? png.write(to: folder.appendingPathComponent(file), options: .atomic)) != nil else { return }
        Renderer.shared?.clearImageCache()
        let w = engine.width, h = engine.height
        if let id = existing, let i = project.layers.firstIndex(where: { $0.id == id }), project.layers[i].drawingID != nil {
            mutate("Edit Drawing") { $0.layers[i].content = .image(fileName: file, pixelWidth: w, pixelHeight: h) }
        } else if let id = existing, let i = project.layers.firstIndex(where: { $0.id == id }), case .image = project.layers[i].content {
            // A redrawn photo: becomes an editable drawing at canvas (= comp) placement.
            mutate("Redraw Image") { p in
                p.layers[i].content = .image(fileName: file, pixelWidth: w, pixelHeight: h)
                p.layers[i].drawingID = docID
                p.layers[i].size = Animated(Vec2(Double(w), Double(h)))
                p.layers[i].transform = LayerTransform(position: Animated(p.center))
                p.layers[i].parentID = nil
            }
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
    func detectBeats(sensitivity: Double = 0.5, bpm: Double? = nil) {
        guard let layer = (selectedLayer?.hasAudio == true ? selectedLayer : nil) ?? project.layers.first(where: { $0.hasAudio }),
              let file = layer.mediaFile else { return }
        beatTask?.cancel()
        isDetectingBeats = true; beatStatus = "Analyzing audio..."
        let url = mediaURL(file), projectID = project.id
        beatTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                var bounded = layer
                bounded.outPoint = min(layer.outPoint, layer.inPoint + 600)
                let source = try RetimedAudio.source(for: bounded, source: url, isCancelled: { Task.isCancelled })
                let samples = AudioAnalysis.samples(url: source.asset.url, sampleRate: 22050)
                let result = BeatDetector.analyze(samples: samples, sampleRate: 22050, sensitivity: sensitivity, bpm: bpm)
                withExtendedLifetime(source) {}
                guard !Task.isCancelled else { return }
                let times = result.times.map { layer.inPoint + $0 }.filter { $0 >= max(0, layer.inPoint) && $0 < layer.outPoint }
                await MainActor.run {
                    guard !Task.isCancelled, let self else { return }
                    self.isDetectingBeats = false
                    guard self.project.id == projectID, self.project.layers.first(where: { $0.id == layer.id }) == layer else {
                        self.beatStatus = "The clip changed during analysis. Detect again to update its markers."
                        return
                    }
                    self.mutate("Detect Beats") { p in
                        let oldAuto = Set((p.detectedBeatTimes ?? []).map { Int(($0 * 1000).rounded()) })
                        let manual = p.markers.filter { !oldAuto.contains(Int(($0 * 1000).rounded())) }
                        let manualSet = Set(manual.map { Int(($0 * 1000).rounded()) })
                        let automatic = Array(Set(times.map { ($0 * 1000).rounded() / 1000 })).filter { !manualSet.contains(Int(($0 * 1000).rounded())) }.sorted()
                        p.markers = manual + automatic
                        p.detectedBeatTimes = automatic.isEmpty ? nil : automatic
                    }
                    let tempo = result.bpm.map { "Suggested tempo: \(Int($0.rounded())) BPM. " } ?? ""
                    let limit = layer.outPoint - layer.inPoint > 600 ? " First 10 minutes analyzed." : ""
                    self.beatStatus = tempo + "\(times.count) beats detected." + limit
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.isDetectingBeats = false; self?.beatStatus = error.localizedDescription }
            }
        }
    }

    func cancelBeatDetection() {
        beatTask?.cancel(); isDetectingBeats = false; beatStatus = "Detection cancelled."
    }

    /// Manual beat tap (works while playing).
    func tapMarker() { toggleBeatMarker() }

    func clearMarkers() { mutate("Clear Markers") { $0.markers = []; $0.detectedBeatTimes = nil } }

    /// Beat-sync script: a punch-in scale + shake hit on the selected layer at every marker.
    /// Scale punch on every beat inside the selected layer, added on top of its existing scale animation.
    func punchOnBeats(scaleAmount: Double = 12, decay: Double = 0.18) {
        guard let i = selectedIndex, !project.markers.isEmpty else { return }
        mutate("Punch on Beats") { p in
            let l = p.layers[i]
            p.layers[i].transform.scale = Self.punched(l.transform.scale, beats: p.markers, inPoint: l.inPoint, outPoint: l.outPoint,
                                                       amount: scaleAmount, decay: decay)
        }
    }

    /// Adds a punch (×(1+amount%) on the beat, back to the underlying value after `decay`) to an existing scale
    /// animation: every value comes from the original curve, so earlier scale keys keep their motion.
    nonisolated static func punched(_ original: Animated<Vec2>, beats: [Double], inPoint: Double, outPoint: Double,
                                    amount: Double, decay: Double) -> Animated<Vec2> {
        let beats = beats.filter { $0 >= inPoint && $0 < outPoint }.sorted()
        let factor = 1 + max(0, amount) / 100, decay = max(0.01, decay)
        var s = original
        for (k, m) in beats.enumerated() {
            let next = k + 1 < beats.count ? beats[k + 1] : .infinity
            let back = min(m + decay, next - 0.002)
            if m - 0.001 >= inPoint, original.keyframeIndex(at: m - 0.001) == nil {
                s.insertKeyframe(Keyframe(time: m - 0.001, value: original.value(at: m - 0.001), interpolation: .linear))
            }
            s.insertKeyframe(Keyframe(time: m, value: original.value(at: m) * factor, interpolation: .bezier,
                                      easeOut: EaseHandle(x: 0.1, y: 0.9), easeIn: .easyIn))
            if back > m + 0.001 {
                s.insertKeyframe(Keyframe(time: back, value: original.value(at: back), interpolation: .linear))
            }
        }
        return s
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
