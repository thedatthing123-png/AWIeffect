import Foundation
import simd

/// Editor-only frame cache. Pixel warps and mesh weights are irrelevant to joint hit geometry.
@MainActor final class RigGeometryFrame {
    let revision: UInt64
    let liveRevision: UInt64
    let time: Double
    let cameraView: Bool
    let rest: Bool
    let restArtworkID: UUID?
    let view: Project
    let posed: Project
    let world: Project
    let matrices: [UUID:simd_double3x3]
    let parentFrames: [UUID:(m: simd_double3x3,rot: Double,scale: Vec2,z: Double)]
    init(state: EditorState) {
        revision = state.geometryRevision; liveRevision = state.live.revision
        time = state.currentTime; cameraView = state.cameraView; rest = state.boneRestEditing || state.boneWeightArtworkID != nil
        restArtworkID = state.rigRestArtworkID
        var source = state.canvasViewProject(state.live.project ?? state.project)
        for i in source.layers.indices {
            source.layers[i].boneMesh = nil; source.layers[i].boneSkin = nil
            source.layers[i].effects.removeAll { !(EffectRegistry.definition($0.typeID)?.isTransformEffect ?? false) }
            if let artwork = restArtworkID,source.layers[i].bone?.artworkID == artwork { source.layers[i].ik = nil }
        }
        view = source
        posed = AutoOrient.apply(IKSolver.apply(source,time: time),time: time)
        var snapshot = posed
        for i in snapshot.layers.indices { snapshot.layers[i].ik = nil; snapshot.layers[i].transform.autoOrient = false }
        world = Renderer.resolveParenting(snapshot,time: time)
        let frames = Renderer.parentAffineMap(posed,time: time)
        parentFrames = frames
        let worldNodes = Dictionary(world.layers.map { ($0.id,$0) },uniquingKeysWith: { a,_ in a })
        let camera = Renderer.activeCamera(world,time: time)
        let spaces = Dictionary(source.layers.compactMap { l -> (UUID,UUID)? in
            guard let rig = l.ik,let space = rig.spaceID else { return nil }; return (rig.controllerID,space)
        },uniquingKeysWith: { a,_ in a })
        var output: [UUID:simd_double3x3] = [:]
        for node in posed.layers {
            let artworkID = node.bone?.artworkID ?? spaces[node.id]
            if let id = artworkID,let art = worldNodes[id],let rawArt = posed.layers.first(where: { $0.id == id }),
               let frame = frames[id],abs(frame.m.determinant)>1e-10 {
                let anchor = rawArt.transform.anchor.value(at: time)
                let toImage = simd_double3x3(columns: (SIMD3(1,0,0),SIMD3(0,1,0),SIMD3(anchor.x,anchor.y,1)))
                let parent = node.parentID.flatMap { frames[$0]?.m } ?? matrix_identity_double3x3
                output[node.id] = Renderer.placementMatrix(art,camera: camera,time: time,renderScale: 1)*toImage*frame.m.inverse*parent*Renderer.layerMatrix(node,time: time,renderScale: 1)
            } else if let resolved = worldNodes[node.id] {
                output[node.id] = Renderer.placementMatrix(resolved,camera: camera,time: time,renderScale: 1)
            }
        }
        matrices = output
    }
}

extension EditorState {
    var rigGeometry: RigGeometryFrame {
        if let saved = rigGeometryCache,saved.revision == geometryRevision,saved.liveRevision == live.revision,
           saved.time == currentTime,saved.cameraView == cameraView,saved.rest == (boneRestEditing || boneWeightArtworkID != nil),saved.restArtworkID == rigRestArtworkID { return saved }
        let frame = RigGeometryFrame(state: self); rigGeometryCache = frame; return frame
    }
}
