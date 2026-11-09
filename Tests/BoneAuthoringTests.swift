import XCTest
import simd
@testable import AWIeffect

@MainActor
final class BoneAuthoringTests: XCTestCase {
    private func state() -> (EditorState, UUID) {
        var p = Project.new(name: "Bones", width: 600, height: 600, fps: 30, duration: 4)
        let art = p.makeLayer(name: "Artwork", content: .solid, size: Vec2(400, 400))
        p.layers = [art]
        return (EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))), art.id)
    }

    func testThreeImagePiecesFollowShoulderAndIKWithoutMesh() throws {
        var p = Project.new(name: "Three-piece arm",width: 600,height: 600,fps: 30,duration: 4)
        var root = p.makeLayer(name: "Character",content: .solid,size: Vec2(20,20)); root.isNull = true
        var upper = p.makeLayer(name: "Upper arm",content: .solid,size: Vec2(120,36))
        upper.parentID = root.id; upper.transform.position = Animated(Vec2(-120,0)); upper.transform.anchor = Animated(Vec2(-60,0))
        var lower = p.makeLayer(name: "Forearm",content: .solid,size: Vec2(100,32))
        lower.parentID = upper.id; lower.transform.position = Animated(Vec2(120,0)); lower.transform.anchor = Animated(Vec2(-50,0))
        var hand = p.makeLayer(name: "Hand",content: .solid,size: Vec2(36,26))
        hand.parentID = lower.id; hand.transform.position = Animated(Vec2(100,0)); hand.transform.anchor = Animated(Vec2(-18,0))
        p.layers = [hand,lower,upper,root]
        let s = EditorState(project: p,store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.select(lower.id); s.ikDraftTip = (lower.id,Vec2(50,0)); s.makeIK(upper: upper.id,controller: nil)
        let rig = try XCTUnwrap(s.project.layers.first { $0.id == lower.id }?.ik)
        XCTAssertEqual(rig.spaceID,root.id)
        let ri = try XCTUnwrap(s.project.layers.firstIndex { $0.id == root.id })
        let ci = try XCTUnwrap(s.project.layers.firstIndex { $0.id == rig.controllerID })
        // Move the whole character, including its depth, without needing skinning or a 3D model.
        s.project.layers[ri].transform.rotation = Animated(25)
        s.project.layers[ri].transform.scale = Animated(Vec2(150,75))
        s.project.layers[ri].transform.positionZ = Animated(200)
        s.project.layers[ci].transform.position = Animated(Vec2(30,100))
        let resolved = Renderer.resolveParenting(s.project,time: 0)
        let drawnLower = try XCTUnwrap(resolved.layers.first { $0.id == lower.id })
        let drawnHand = try XCTUnwrap(resolved.layers.first { $0.id == hand.id })
        // Evaluate full affine hierarchy, retaining the scaled parent's shear instead of decomposing it.
        let posed = IKSolver.apply(s.project,time: 0)
        let parent = try XCTUnwrap(Renderer.parentAffine(lower.id,in: posed,time: 0))
        let wrist = parent.m*SIMD3(100.0,0,1)
        let target = try XCTUnwrap(Renderer.parentAffine(rig.controllerID,in: posed,time: 0)).m*SIMD3(0.0,0,1)
        XCTAssertEqual(wrist.x,target.x,accuracy: 1e-6); XCTAssertEqual(wrist.y,target.y,accuracy: 1e-6)
        XCTAssertEqual(drawnHand.transform.position.value(at: 0).x,target.x,accuracy: 1e-6)
        XCTAssertEqual(drawnHand.transform.position.value(at: 0).y,target.y,accuracy: 1e-6)
        XCTAssertEqual(drawnLower.transform.positionZ.value(at: 0),200,accuracy: 1e-6)
        XCTAssertEqual(drawnHand.transform.positionZ.value(at: 0),200,accuracy: 1e-6)
        XCTAssertNil(drawnHand.bone); XCTAssertNil(drawnLower.bone)
        let saved = try JSONDecoder().decode(Project.self,from: JSONEncoder().encode(s.project))
        XCTAssertEqual(saved.layers.first { $0.id == hand.id }?.parentID,lower.id)
    }

    func testConnectedBonesUseExistingTransformsAndPoseHierarchy() throws {
        let (s, art) = state()
        s.select(art); s.beginBoneDrawing()
        let first = try XCTUnwrap(s.addBone(artworkID: art, parentID: nil, start: .zero, end: Vec2(100, 0)))
        let second = try XCTUnwrap(s.addBone(artworkID: art, parentID: first, start: .zero, end: Vec2(100, 100)))
        XCTAssertEqual(s.project.layers.first { $0.id == first }?.parentID, art)
        XCTAssertEqual(s.project.layers.first { $0.id == second }?.parentID, first)
        s.beginPanelGesture("Pose Bone")
        s.poseBone(first, atCanvas: Vec2(300, 400))
        s.endPanelGesture()
        let posed = Renderer.resolveParenting(s.project, time: 0)
        let root = try XCTUnwrap(posed.layers.first { $0.id == first })
        let child = try XCTUnwrap(posed.layers.first { $0.id == second })
        XCTAssertEqual(root.transform.rotation.value(at: 0), 90, accuracy: 1e-8)
        XCTAssertEqual(child.transform.position.value(at: 0).x, 300, accuracy: 1e-8)
        XCTAssertEqual(child.transform.position.value(at: 0).y, 400, accuracy: 1e-8)
        let tip = Renderer.layerMatrix(child, time: 0, renderScale: 1) * SIMD3(100.0, 0, 1)
        XCTAssertEqual(tip.x, 200, accuracy: 1e-8)
        XCTAssertEqual(tip.y, 400, accuracy: 1e-8)
        let saved = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(s.project))
        XCTAssertEqual(saved.layers.first { $0.id == first }?.bone?.artworkID, art)
    }

    func testSkeletonIKStaysInArtworkPlaneThroughScaleAndCameraTilt() throws {
        let (s, artID) = state()
        s.project.layers[0].is3D = true
        s.project.layers[0].transform.rotation = Animated(30)
        s.project.layers[0].transform.rotationX = Animated(25)
        s.project.layers[0].transform.rotationY = Animated(-20)
        s.project.layers[0].transform.positionZ = Animated(180)
        s.project.layers[0].transform.scale = Animated(Vec2(140, 70))
        let upper = try XCTUnwrap(s.addBone(artworkID: artID, parentID: nil, start: .zero, end: Vec2(100, 0)))
        let lower = try XCTUnwrap(s.addBone(artworkID: artID, parentID: upper, start: .zero, end: Vec2(100, 100)))
        s.select(lower); s.makeIK(upper: upper, controller: nil)
        let rig = try XCTUnwrap(s.project.layers.first { $0.id == lower }?.ik)
        XCTAssertEqual(rig.spaceID, artID)
        XCTAssertEqual(rig.l1, 100, accuracy: 1e-7)
        XCTAssertEqual(rig.l2, 100, accuracy: 1e-7)
        XCTAssertEqual(s.selectedLayer?.parentID, artID)
        let target = Vec2(70, 110)
        let screen = try XCTUnwrap(LayerPlacement.projected(target, by: XCTUnwrap(s.displayPlacement(of: artID))))
        s.poseIKController(rig.controllerID, atCanvas: screen)
        for scale in [Vec2(140, 70), Vec2(80, 180)] {
            let ai = try XCTUnwrap(s.project.layers.firstIndex { $0.id == artID })
            s.project.layers[ai].transform.scale = Animated(scale)
            let solved = IKSolver.apply(s.project, time: 0)
            let art = try XCTUnwrap(Renderer.resolveParenting(s.project, time: 0).layers.first { $0.id == artID })
            let bone = try XCTUnwrap(solved.layers.first { $0.id == lower })
            let matrix = try XCTUnwrap(EditorState.bonePlacement(bone, artwork: art, project: solved, time: 0))
            let actual = try XCTUnwrap(LayerPlacement.projected(Vec2(100, 0), by: matrix))
            let expected = try XCTUnwrap(LayerPlacement.projected(target, by: XCTUnwrap(s.displayPlacement(of: artID))))
            XCTAssertEqual(actual.x, expected.x, accuracy: 1e-6)
            XCTAssertEqual(actual.y, expected.y, accuracy: 1e-6)
            let controller = try XCTUnwrap(s.project.layers.first { $0.id == rig.controllerID })
            let positioned = try XCTUnwrap(MotionPathMath.screenPoint(controller, value: controller.transform.position.value(at: 0), project: s.project, time: 0))
            XCTAssertEqual(positioned.x, expected.x, accuracy: 1e-6)
            XCTAssertEqual(positioned.y, expected.y, accuracy: 1e-6)
        }
    }

    func testBoneRootHonorsArtworkAnchorWithoutMovingTheImage() throws {
        let (s, art) = state()
        s.project.layers[0].transform.anchor = Animated(Vec2(40, -30))
        let artwork = s.project.layers[0]
        let before = Renderer.layerMatrix(artwork, time: 0, renderScale: 1)
        let start = Vec2(20, 10)
        let id = try XCTUnwrap(s.addBone(artworkID: art, parentID: nil, start: start, end: Vec2(120, 10)))
        let resolved = Renderer.resolveParenting(s.project, time: 0)
        let bone = try XCTUnwrap(resolved.layers.first { $0.id == id })
        let expected = before * SIMD3(start.x, start.y, 1)
        XCTAssertEqual(bone.transform.position.value(at: 0).x, expected.x, accuracy: 1e-8)
        XCTAssertEqual(bone.transform.position.value(at: 0).y, expected.y, accuracy: 1e-8)
        XCTAssertEqual(s.project.layers.first { $0.id == art }?.transform, artwork.transform)
    }

    func testDrawingEachBoneIsOneUndoAndInvalidSegmentsDoNothing() throws {
        let (s, art) = state()
        let before = s.project
        let count = s.undoStack.count
        XCTAssertNil(s.addBone(artworkID: art, parentID: nil, start: .zero, end: .zero))
        XCTAssertNil(s.addBone(artworkID: art, parentID: nil, start: .zero, end: Vec2(.nan, 0)))
        XCTAssertEqual(s.undoStack.count, count)
        _ = try XCTUnwrap(s.addBone(artworkID: art, parentID: nil, start: .zero, end: Vec2(80, 0)))
        XCTAssertEqual(s.undoStack.count, count + 1)
        s.undo()
        XCTAssertEqual(s.project, before)
    }

    func testRigReferencesRemapWithCopiedArtworkAndJoints() throws {
        let (s, art) = state()
        let id = try XCTUnwrap(s.addBone(artworkID: art, parentID: nil, start: .zero, end: Vec2(80, 0)))
        var bone = try XCTUnwrap(s.project.layers.first { $0.id == id })
        let copyArt = UUID()
        bone.remapRigReferences([art: copyArt])
        XCTAssertEqual(bone.bone?.artworkID, copyArt)
        bone.remapRigReferences([:], keepExternal: false)
        XCTAssertNil(bone.bone, "A cross-project paste cannot retain a reference to absent artwork")
    }
}
