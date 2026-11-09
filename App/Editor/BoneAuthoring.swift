import SwiftUI
import simd

/// Bone transforms use the existing layer/keyframe system. Rest tips are expressed in bone-local pixels.
struct BoneSettings: Codable, Equatable {
    var artworkID: UUID
    var tip: Vec2
}

extension EditorState {
    var rigArtworkID: UUID? {
        guard let layer = selectedLayer else { return nil }
        if let bone = layer.bone { return bone.artworkID }
        if layer.isNull,let owner = project.layers.first(where: { $0.ik?.controllerID == layer.id }),
           let artwork = owner.bone?.artworkID { return artwork }
        guard !layer.isNull, !layer.isGroup, !layer.isAudioOnly,
              layer.content != .camera, layer.content != .light, layer.content != .adjustment else { return nil }
        return layer.id
    }

    /// End creation mode and retain the authoring surface when selecting an earlier joint.
    func selectAuthoringBone(_ id: UUID) {
        guard project.layers.contains(where: { $0.id == id && $0.bone != nil }) else { return }
        if let child = boneParentPicking { boneParentPicking = nil; reparentAuthoringBone(child,to: id); return }
        let previousPanel = panel
        if boneRestEditing,rigArtworkID != project.layers.first(where: { $0.id == id })?.bone?.artworkID { finishBoneRestEditing() }
        finishBoneDrawing()
        select(id)
        panel = previousPanel == .boneWeight ? .boneWeight : .rig
        if boneWeightArtworkID != nil { finishBoneWeightStroke(commit: false); boneWeightBoneID = id }
    }

    /// Rebind setup matrices once when leaving Rest; brush weights and pose key tracks are retained.
    func finishBoneRestEditing() {
        guard let artworkID = rigArtworkID else { return }
        var setup = project
        for i in setup.layers.indices { setup.layers[i].ik = nil }
        let frames = Renderer.parentAffineMap(setup,time: currentTime)
        guard let art = setup.layers.first(where: { $0.id == artworkID }),let artFrame = frames[artworkID],abs(artFrame.m.determinant)>1e-10 else { return }
        let anchor = art.transform.anchor.value(at: currentTime)
        let toImage = simd_double3x3(columns: (SIMD3(1,0,0),SIMD3(0,1,0),SIMD3(anchor.x,anchor.y,1)))
        let time = currentTime
        mutate("Update Rest Bindings") { p in
            if let i = p.layers.firstIndex(where: { $0.id == artworkID }),var mesh = p.layers[i].boneMesh {
                for j in mesh.boneIDs.indices {
                    let id = mesh.boneIDs[j]
                    if id == artworkID { mesh.inverseBinds[j] = .identity; continue }
                    guard let bone = setup.layers.first(where: { $0.id == id }),let frame = frames[id] else { continue }
                    let boneAnchor = bone.transform.anchor.value(at: time)
                    let fromAnchor = simd_double3x3(columns: (SIMD3(1,0,0),SIMD3(0,1,0),SIMD3(-boneAnchor.x,-boneAnchor.y,1)))
                    let matrix = toImage*artFrame.m.inverse*frame.m*fromAnchor
                    if abs(matrix.determinant)>1e-10 { mesh.inverseBinds[j] = RigAffine(matrix.inverse) }
                }
                mesh.changed(); p.layers[i].boneMesh = mesh
            }
            for i in p.layers.indices {
                guard var rig = p.layers[i].ik,p.layers[i].bone?.artworkID == artworkID,
                      let upper = setup.layers.first(where: { $0.id == rig.upperID }),let a = frames[upper.id],let b = frames[p.layers[i].id] else { continue }
                rig.restTip = p.layers[i].bone?.tip ?? rig.restTip
                if rig.chainIDs == nil,let tip = rig.restTip {
                    let space = rig.spaceID.flatMap { frames[$0]?.m } ?? matrix_identity_double3x3
                    guard abs(space.determinant)>1e-10,let start = LayerPlacement.projected(.zero,by: space.inverse*a.m),
                          let elbow = LayerPlacement.projected(.zero,by: space.inverse*b.m),
                          let end = LayerPlacement.projected(tip,by: space.inverse*b.m) else { continue }
                    let angle = atan2(space[0].y,space[0].x)*180/Double.pi
                    rig.l1 = hypot(elbow.x-start.x,elbow.y-start.y); rig.l2 = hypot(end.x-elbow.x,end.y-elbow.y)
                    rig.rest1 = atan2(elbow.y-start.y,elbow.x-start.x)*180/Double.pi-(a.rot-angle)
                    rig.rest2 = atan2(end.y-elbow.y,end.x-elbow.x)*180/Double.pi-(b.rot-angle)
                }
                p.layers[i].ik = rig
            }
        }
    }

    func reparentAuthoringBone(_ id: UUID,to parent: UUID) {
        guard let child = project.layers.first(where: { $0.id == id }),let owner = child.bone?.artworkID,!child.isLocked,
              id != parent,!IKSolver.descendants(of: id,in: project).contains(parent),
              parent == owner || project.layers.first(where: { $0.id == parent })?.bone?.artworkID == owner else {
            recoveryNotice = "Choose a parent in this skeleton outside the selected branch."; return
        }
        let previous = panel
        select(id); setParent(parent); panel = previous == .boneWeight ? .boneWeight : .rig
    }

    func deleteAuthoringBone(_ id: UUID) {
        guard let bone = project.layers.first(where: { $0.id == id }),bone.bone != nil,!bone.isLocked else { return }
        let previous = panel,parent = bone.parentID
        beginEdit("Delete Bone")
        for child in project.layers.filter({ $0.parentID == id }) { selectedLayerID = child.id; setParent(parent) }
        mutate("Delete Bone") { p in
            p.layers.removeAll { $0.id == id }
            for i in p.layers.indices {
                if p.layers[i].ik.map({ $0.upperID == id || $0.controllerID == id || ($0.chainIDs ?? []).contains(id) }) == true { p.layers[i].ik = nil }
                if var mesh = p.layers[i].boneMesh,let deleted = mesh.boneIDs.firstIndex(of: id) {
                    mesh.boneIDs.remove(at: deleted); mesh.inverseBinds.remove(at: deleted)
                    mesh.lockedBoneIDs?.removeAll { $0 == id }
                    for vertex in mesh.vertices.indices {
                        var weights = mesh.vertices[vertex].weights.filter { $0.bone != deleted }
                        let removed = mesh.vertices[vertex].weights.filter { $0.bone == deleted }.reduce(0.0) { $0+$1.amount }
                        for j in weights.indices { if weights[j].bone>deleted { weights[j].bone -= 1 } }
                        if removed>0 {
                            if let root = weights.firstIndex(where: { $0.bone == 0 }) { weights[root].amount += removed }
                            else { weights.append(BoneMeshWeight(bone: 0,amount: removed)) }
                        }
                        mesh.vertices[vertex].weights = weights
                    }
                    mesh.changed(); p.layers[i].boneMesh = mesh
                }
            }
        }
        endEdit(); selectedLayerID = parent; panel = previous
    }

    /// Move a setup joint without adding keys. Child pivots retain their world position at this frame.
    func moveBoneRestJoint(_ id: UUID,to point: Vec2) {
        let source = live.project ?? project
        guard boneRestEditing,let bone = source.layers.first(where: { $0.id == id }),bone.bone != nil,!bone.isLocked,
              let oldFrame = Renderer.parentAffine(id,in: source,time: currentTime),abs(oldFrame.m.determinant)>1e-10 else { return }
        let delta = point-bone.transform.position.value(at: currentTime)
        guard hypot(delta.x,delta.y)>1e-10 else { return }
        let time = currentTime
        mutate("Move Rest Joint") { p in
            guard let index = p.layers.firstIndex(where: { $0.id == id }) else { return }
            p.layers[index].transform.position = p.layers[index].transform.position.mapped { $0+delta }
            guard let newFrame = Renderer.parentAffine(id,in: p,time: time),abs(newFrame.m.determinant)>1e-10 else { return }
            let compensation = newFrame.m.inverse*oldFrame.m
            if let tip = p.layers[index].bone?.tip,let fixed = LayerPlacement.projected(tip,by: compensation) { p.layers[index].bone?.tip = fixed }
            for child in p.layers.indices where p.layers[child].parentID == id {
                let original = p.layers[child].transform.position.value(at: time)
                if let fixed = LayerPlacement.projected(original,by: compensation) {
                    let correction = fixed-original
                    p.layers[child].transform.position = p.layers[child].transform.position.mapped { $0+correction }
                }
            }
        }
    }

    func branchFromSelectedBone() {
        guard selectedLayer?.bone != nil else { return }
        beginBoneDrawing()
    }

    func beginBoneDrawing() {
        guard let id = rigArtworkID else { return }
        pause()
        ikDraftUpper = nil; ikDraftController = nil; ikDraftTip = nil
        boneDrawingArtworkID = id
        boneDrawingParentID = selectedLayer?.bone == nil ? nil : selectedLayerID
    }

    func finishBoneDrawing() { boneDrawingArtworkID = nil; boneDrawingParentID = nil }

    /// Parent-space coordinates into the artwork's image plane (before its camera projection).
    nonisolated static func rigParentToArtwork(_ node: Layer, artworkID: UUID, project: Project, time: Double) -> simd_double3x3? {
        guard let art = project.layers.first(where: { $0.id == artworkID }),
              let artFrame = Renderer.parentAffine(artworkID, in: project, time: time), abs(artFrame.m.determinant) > 1e-10 else { return nil }
        let parent = node.parentID.flatMap { Renderer.parentAffine($0, in: project, time: time)?.m } ?? matrix_identity_double3x3
        let anchor = art.transform.anchor.value(at: time)
        let toImage = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(anchor.x, anchor.y, 1)))
        return toImage * artFrame.m.inverse * parent
    }

    /// Use the full local chain before projecting the image, preserving nonuniform scales and camera tilt.
    nonisolated static func bonePlacement(_ bone: Layer, artwork: Layer, project: Project, time: Double, camera: CameraState? = nil) -> simd_double3x3? {
        guard let raw = project.layers.first(where: { $0.id == bone.id }),
              let parentToArt = rigParentToArtwork(raw, artworkID: artwork.id, project: project, time: time) else { return nil }
        return Renderer.placementMatrix(artwork, camera: camera ?? Renderer.activeCamera(project, time: time), time: time, renderScale: 1)
            * parentToArt * Renderer.layerMatrix(raw, time: time, renderScale: 1)
    }

    /// A drag authors a segment in artwork-local coordinates. The new joint is connected to the previous tip.
    @discardableResult
    func addBone(artworkID: UUID, parentID: UUID?, start: Vec2, end: Vec2) -> UUID? {
        guard [start.x, start.y, end.x, end.y].allSatisfy(\.isFinite),
              let artwork = project.layers.first(where: { $0.id == artworkID }), !artwork.isLocked else { return nil }
        var authored = project
        if boneRestEditing { for i in authored.layers.indices where authored.layers[i].bone?.artworkID == artworkID { authored.layers[i].ik = nil } }
        let resolved = Renderer.resolveParenting(authored, time: currentTime)
        guard let art = resolved.layers.first(where: { $0.id == artworkID }) else { return nil }
        var a = start, b = end
        let parent: UUID
        if let parentID {
            guard let rawParent = project.layers.first(where: { $0.id == parentID }), !rawParent.isLocked,
                  rawParent.bone?.artworkID == artworkID,
                  resolved.layers.contains(where: { $0.id == parentID }) else { return nil }
            let evaluated = IKSolver.apply(authored, time: currentTime)
            guard let parentToArt = Self.rigParentToArtwork(rawParent, artworkID: artworkID, project: evaluated, time: currentTime) else { return nil }
            let matrix = parentToArt * Renderer.layerMatrix(evaluated.layers.first(where: { $0.id == parentID }) ?? rawParent, time: currentTime, renderScale: 1)
            guard abs(matrix.determinant) > 1e-10,
                  let localEnd = LayerPlacement.projected(end, by: matrix.inverse) else { return nil }
            let anchor = rawParent.transform.anchor.value(at: currentTime)
            a = rawParent.bone!.tip - anchor; b = localEnd - anchor; parent = parentID
        } else {
            let anchor = art.transform.anchor.value(at: currentTime)
            a = start - anchor; b = end - anchor; parent = artworkID
        }
        let delta = b - a, length = hypot(delta.x, delta.y)
        guard length.isFinite, length >= 2 else { return nil }
        let count = project.layers.filter { $0.bone?.artworkID == artworkID }.count
        var bone = project.makeLayer(name: "Bone \(count + 1)", content: .solid, size: Vec2(24, 24))
        bone.isNull = true; bone.tag = .amber; bone.parentID = parent; bone.groupID = artwork.groupID
        bone.inPoint = artwork.inPoint; bone.outPoint = artwork.outPoint
        bone.transform.position = Animated(a)
        bone.transform.rotation = Animated(atan2(delta.y, delta.x) * 180 / .pi)
        bone.bone = BoneSettings(artworkID: artworkID, tip: Vec2(length, 0))
        let id = bone.id
        mutate("Draw Bone") { $0.layers.insert(bone, at: 0) }
        select(id)
        if panel != .boneWeight { panel = .rig }
        boneDrawingParentID = id
        return id
    }
}

/// Explicit branching and hierarchy selection are shared by both artwork workflows.
struct BoneAuthoringControls: View {
    @ObservedObject var state: EditorState
    @State private var hierarchyOpen = false
    var body: some View {
        if let artworkID = state.rigArtworkID ?? state.boneDrawingArtworkID {
            VStack(alignment: .leading,spacing: 6) {
                if state.boneDrawingArtworkID != nil {
                    HStack {
                        Text("Create · drag from selected tip").font(.caption).foregroundStyle(Theme.accentGlow)
                        Spacer()
                        Button("Done") { state.finishBoneDrawing() }.frame(minWidth: 60,minHeight: 44)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button { state.beginBoneDrawing() } label: {
                            Label(state.selectedLayer?.bone == nil ? "Draw Bones" : "Branch",systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                .frame(maxWidth: .infinity,minHeight: 44)
                        }.buttonStyle(.bordered)
                        if state.selectedLayer?.bone != nil {
                            Button(state.boneParentPicking == nil ? "Parent" : "Cancel") {
                                state.boneParentPicking = state.boneParentPicking == nil ? state.selectedLayerID : nil
                            }.frame(minWidth: 65,minHeight: 44)
                        }
                    }
                }
                if state.selectedLayer?.bone != nil {
                    if state.boneParentPicking != nil { Text("Select the new parent on canvas or in the hierarchy.").font(.caption).foregroundStyle(Theme.warning) }
                    Picker("Joint editing",selection: $state.boneRestEditing) {
                        Text("Pose").tag(false); Text("Edit Rest").tag(true)
                    }.pickerStyle(.segmented).frame(minHeight: 44)
                    .onChange(of: state.boneRestEditing) { _,rest in if !rest { state.finishBoneRestEditing() } }
                }
                DisclosureGroup("Bone hierarchy",isExpanded: $hierarchyOpen) {
                    let bones = state.project.layers.filter { $0.bone?.artworkID == artworkID }.reversed()
                    if let id = state.selectedLayerID,state.selectedLayer?.bone != nil {
                        Button("Delete Selected Bone",role: .destructive) { state.deleteAuthoringBone(id) }.frame(minHeight: 44)
                    }
                    ForEach(Array(bones)) { bone in
                        Button { state.selectAuthoringBone(bone.id) } label: {
                            HStack {
                                Image(systemName: state.selectedLayerID == bone.id ? "circle.inset.filled" : "circle")
                                Text(bone.name).lineLimit(1)
                                Spacer()
                                if let parent = state.project.layers.first(where: { $0.id == bone.parentID && $0.bone != nil }) {
                                    Text(parent.name).font(.caption).foregroundStyle(Theme.textDim).lineLimit(1)
                                }
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain).accessibilityIdentifier("bone-select-\(bone.id)").accessibilityLabel("Select bone \(bone.name)")
                    }
                }.foregroundStyle(Theme.accentGlow)
            }
        }
    }
}


extension EditorState {
    /// Convert through the image plane before the parent chain, so camera depth/tilt does not alter rig coordinates.
    func rigPointInParent(_ node: Layer, artworkID: UUID, atCanvas point: Vec2, project raw: Project) -> Vec2? {
        let geometry = rigGeometry
        guard let artPlacement = geometry.matrices[artworkID],abs(artPlacement.determinant)>1e-10,
              let imagePoint = LayerPlacement.projected(point,by: artPlacement.inverse),
              let art = geometry.posed.layers.first(where: { $0.id == artworkID }),
              let artFrame = geometry.parentFrames[artworkID],abs(artFrame.m.determinant)>1e-10 else { return nil }
        let anchor = art.transform.anchor.value(at: currentTime)
        let toImage = simd_double3x3(columns: (SIMD3(1,0,0),SIMD3(0,1,0),SIMD3(anchor.x,anchor.y,1)))
        let parent = node.parentID.flatMap { geometry.parentFrames[$0]?.m } ?? matrix_identity_double3x3
        let parentToImage = toImage*artFrame.m.inverse*parent
        guard abs(parentToImage.determinant)>1e-10 else { return nil }
        return LayerPlacement.projected(imagePoint,by: parentToImage.inverse)
    }

    /// Rotate the bone in its parent's plane. Camera projection is inverted only once; touch motion cannot feed back.
    func poseBone(_ id: UUID, atCanvas point: Vec2) {
        let raw = live.project ?? project, time = currentTime
        guard let bone = raw.layers.first(where: { $0.id == id }), !bone.isLocked, let settings = bone.bone,
              let local = rigPointInParent(bone, artworkID: settings.artworkID, atCanvas: point, project: raw) else { return }
        let delta = local - bone.transform.position.value(at: time)
        guard hypot(delta.x, delta.y) > 1e-6 else { return }
        let anchor = bone.transform.anchor.value(at: time), scale = bone.transform.scale.value(at: time)
        let base = Vec2((settings.tip.x - anchor.x) * scale.x, (settings.tip.y - anchor.y) * scale.y)
        guard hypot(base.x, base.y) > 1e-6 else { return }
        let desired = (atan2(delta.y, delta.x) - atan2(base.y, base.x)) * 180 / .pi
        let rotation = IKSolver.blendAngle(fk: bone.transform.rotation.value(at: time), ik: desired, w: 1)
        mutate("Pose Bone") { p in
            if let i = p.layers.firstIndex(where: { $0.id == id }) { p.layers[i].transform.rotation.set(rotation, at: time) }
        }
    }
}

struct SkeletonCanvasOverlay: View {
    @ObservedObject var state: EditorState
    let fit: CGRect
    @State private var drawing: (start: Vec2, end: Vec2)?
    @GestureState private var drawingTouch = false

    var body: some View {
        let project = state.live.project ?? state.project
        let geometry = state.rigGeometry
        let view = geometry.view
        let posed = geometry.posed
        let resolved = geometry.world
        let worlds = Dictionary(resolved.layers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let scale = fit.width / CGFloat(max(1, project.width))
        let camera = Renderer.activeCamera(resolved, time: state.currentTime)
        let constrained = Set(project.layers.flatMap { layer -> [UUID] in
            guard let ik = layer.ik, ik.mixValue(at: state.currentTime) > 0.001 else { return [] }
            return Array(IKSolver.drivenIDs(owner: layer))
        })
        ZStack {
            ForEach(project.layers.filter { $0.bone != nil }) { bone in
                if let settings = bone.bone, let world = worlds[bone.id], let art = worlds[settings.artworkID],
                   let matrix = geometry.matrices[bone.id],
                   let start = LayerPlacement.projected(world.transform.anchor.value(at: state.currentTime), by: matrix), let end = LayerPlacement.projected(settings.tip, by: matrix) {
                    BoneSegmentHandle(state: state, id: bone.id, name: bone.name, start: screen(start, scale),
                                      end: screen(end, scale), scale: scale, fit: fit,
                                      canPose: state.selectedLayerID == bone.id && !constrained.contains(bone.id) && !bone.isLocked && state.boneDrawingArtworkID == nil
                                        && !(state.selectedLayerID == bone.id && state.ikDraftUpper != nil))
                }
            }
            if let artID = state.boneDrawingArtworkID, worlds[artID] != nil,
               let placement = state.displayPlacement(of: artID) {
                let parent = state.boneDrawingParentID.flatMap { worlds[$0] }
                let fixedStart: Vec2? = parent.flatMap { bone in
                    guard let raw = posed.layers.first(where: { $0.id == bone.id }), let tip = raw.bone?.tip,
                          let parentToArt = EditorState.rigParentToArtwork(raw, artworkID: artID, project: posed, time: state.currentTime) else { return nil }
                    return LayerPlacement.projected(tip, by: parentToArt * Renderer.layerMatrix(raw, time: state.currentTime, renderScale: 1))
                }
                Color.clear.contentShape(Rectangle())
                    .highPriorityGesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("skeletonCanvas"))
                        .updating($drawingTouch) { _, active, _ in active = true }
                        .onChanged { value in
                            guard abs(placement.determinant) > 1e-10,
                                  let first = LayerPlacement.projected(comp(value.startLocation, scale), by: placement.inverse),
                                  let last = LayerPlacement.projected(comp(value.location, scale), by: placement.inverse) else { return }
                            drawing = (fixedStart ?? first, last)
                        }
                        .onEnded { _ in
                            if let segment = drawing {
                                state.addBone(artworkID: artID, parentID: state.boneDrawingParentID, start: segment.start, end: segment.end)
                            }
                            drawing = nil
                        })
                    .accessibilityLabel("Draw connected bones")
                if let segment = drawing,
                   let a = LayerPlacement.projected(segment.start, by: placement), let b = LayerPlacement.projected(segment.end, by: placement) {
                    Path { $0.move(to: screen(a, scale)); $0.addLine(to: screen(b, scale)) }
                        .stroke(Theme.warning, style: StrokeStyle(lineWidth: 3, dash: [5, 3])).allowsHitTesting(false)
                }
            }
        }
        .coordinateSpace(name: "skeletonCanvas")
        .onChange(of: drawingTouch) { _, active in if !active { drawing = nil } }
        .onChange(of: state.panel) { _, panel in
            if panel != .rig && panel != .boneWeight { drawing = nil; state.finishBoneDrawing() }
        }
        .onDisappear { drawing = nil; state.finishBoneDrawing() }
    }

    private func screen(_ p: Vec2, _ scale: CGFloat) -> CGPoint { CGPoint(x: fit.minX + CGFloat(p.x) * scale, y: fit.minY + CGFloat(p.y) * scale) }
    private func comp(_ p: CGPoint, _ scale: CGFloat) -> Vec2 { Vec2(Double((p.x - fit.minX) / scale), Double((p.y - fit.minY) / scale)) }
}

private struct BoneSegmentHandle: View {
    @ObservedObject var state: EditorState
    let id: UUID
    let name: String
    let start: CGPoint
    let end: CGPoint
    let scale: CGFloat
    let fit: CGRect
    let canPose: Bool
    @State private var restDrag: RigPointGesture?
    @State private var dragStart: CGPoint?
    @GestureState private var touching = false

    var body: some View {
        ZStack {
            Path { $0.move(to: start); $0.addLine(to: end) }
                .stroke(state.selectedLayerID == id ? Theme.warning : Theme.accentGlow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .contentShape(Path { $0.move(to: start); $0.addLine(to: end) }.strokedPath(StrokeStyle(lineWidth: 44)))
                .onTapGesture { state.selectAuthoringBone(id) }
            Circle().fill(Theme.surface).overlay(Circle().stroke(Theme.accentGlow, lineWidth: 2))
                .frame(width: 12, height: 12).frame(width: 44, height: 44).contentShape(Rectangle()).position(start)
                .onTapGesture { state.selectAuthoringBone(id) }.accessibilityLabel("Select \(name)")
                .highPriorityGesture(DragGesture(minimumDistance: 1,coordinateSpace: .global)
                    .updating($touching) { _,active,_ in active = true }
                    .onChanged { value in
                        if restDrag == nil { restDrag = state.rigPointGesture(.restJoint(id)); state.beginPanelGesture("Move Rest Joint") }
                        guard let input = restDrag,
                              let point = LayerPlacement.projected(input.origin+Vec2(Double(value.translation.width/scale),Double(value.translation.height/scale)),by: input.inverse) else { return }
                        state.moveBoneRestJoint(id,to: point)
                    }.onEnded { _ in finishRest() },including: state.boneRestEditing && state.selectedLayerID == id ? .all : .none)
                .onChange(of: touching) { _,active in if !active { finishRest() } }
                .onDisappear { finishRest() }
            if canPose && !state.boneRestEditing {
                Circle().fill(Theme.warning).frame(width: 14, height: 14)
                    .frame(width: 44, height: 44).contentShape(Rectangle()).position(end)
                    .highPriorityGesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .updating($touching) { _, active, _ in active = true }
                        .onChanged { value in
                            if dragStart == nil {
                                dragStart = end
                                if state.selectedLayerID != id { state.selectAuthoringBone(id) }
                                state.beginPanelGesture("Pose Bone")
                            }
                            guard let initial = dragStart else { return }
                            let point = CGPoint(x: initial.x + value.translation.width, y: initial.y + value.translation.height)
                            state.poseBone(id, atCanvas: Vec2(Double((point.x - fit.minX) / scale), Double((point.y - fit.minY) / scale)))
                        }
                        .onEnded { _ in finish() })
                    .onChange(of: touching) { _, active in if !active { finish() } }
                    .onDisappear { finish() }
                    .accessibilityElement(children: .ignore).accessibilityLabel("Pose \(name)")
                    .accessibilityValue(String(format: "%.1f degrees", Double(atan2(end.y - start.y, end.x - start.x)) * 180 / .pi))
            }
        }
    }
    private func finishRest() { guard restDrag != nil else { return }; restDrag = nil; state.endPanelGesture() }
    private func finish() { guard dragStart != nil else { return }; dragStart = nil; state.endPanelGesture() }
}


extension Layer {
    /// Cloning a composition must point its rig at the cloned artwork and joints.
    mutating func remapRigReferences(_ ids: [UUID: UUID], keepExternal: Bool = true) {
        if var mesh = boneMesh {
            let mapped = mesh.boneIDs.compactMap { ids[$0] ?? (keepExternal ? $0 : nil) }
            if mapped.count == mesh.boneIDs.count {
                mesh.id = UUID(); mesh.boneIDs = mapped
                mesh.lockedBoneIDs = mesh.lockedBoneIDs?.compactMap { ids[$0] ?? (keepExternal ? $0 : nil) }
                mesh.changed(); boneMesh = mesh
            } else { boneMesh = nil }
        }
        if let settings = bone {
            if let replacement = ids[settings.artworkID] { bone?.artworkID = replacement }
            else if !keepExternal { bone = nil }
        }
        if var rig = ik {
            let upper = ids[rig.upperID] ?? (keepExternal ? rig.upperID : nil)
            let target = ids[rig.controllerID] ?? (keepExternal ? rig.controllerID : nil)
            if let upper, let target {
                rig.upperID = upper; rig.controllerID = target
                if let space = rig.spaceID {
                    guard let mapped = ids[space] ?? (keepExternal ? space : nil) else { ik = nil; return }
                    rig.spaceID = mapped
                }
                if let chain = rig.chainIDs {
                    let remapped = chain.compactMap { id -> UUID? in
                        ids[id] ?? (keepExternal ? id : nil)
                    }
                    guard remapped.count == chain.count, Set(remapped).count == remapped.count else {
                        ik = nil
                        return
                    }
                    rig.chainIDs = remapped
                }
                ik = rig
            }
            else { ik = nil }
        }
        if var skin = boneSkin {
            skin.bindings = skin.bindings.compactMap { binding in
                guard let id = ids[binding.jointID] ?? (keepExternal ? binding.jointID : nil) else { return nil }
                var updated = binding
                updated.jointID = id
                return updated
            }
            boneSkin = skin.bindings.count >= 2 ? skin : nil
        }
    }
}
