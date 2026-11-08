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

    func testBoundArtworkCarriesAnIndependentRigWhenDuplicated() throws {
        let (s, art) = state()
        let bone = try XCTUnwrap(s.addBone(artworkID: art, parentID: nil, start: .zero, end: Vec2(100,0)))
        s.select(bone); s.bindBoneMesh(); s.select(art)
        let original = try XCTUnwrap(s.selectedLayer?.boneMesh)
        s.duplicateSelected()
        let copy = try XCTUnwrap(s.selectedLayer)
        let binding = try XCTUnwrap(copy.boneMesh)
        XCTAssertNotEqual(copy.id, art); XCTAssertNotEqual(binding.id, original.id)
        XCTAssertTrue(binding.boneIDs.contains(copy.id)); XCTAssertFalse(binding.boneIDs.contains(art))
        let newBone = try XCTUnwrap(s.project.layers.first { $0.bone?.artworkID == copy.id })
        XCTAssertEqual(newBone.parentID, copy.id); XCTAssertTrue(binding.boneIDs.contains(newBone.id))
        XCTAssertFalse(binding.boneIDs.contains(bone))
    }

    func testWeightStrokePreviewCommitCancelAndUndo() throws {
        let (s, art) = state()
        let bone = try XCTUnwrap(s.addBone(artworkID: art, parentID: nil, start: .zero, end: Vec2(100,0)))
        s.select(bone); s.bindBoneMesh(); s.beginBoneWeights()
        let original = try XCTUnwrap(s.rigArtwork?.boneMesh), history = s.undoStack.count
        s.boneWeightRadius = 180; s.boneWeightStrength = 100; s.boneWeightBoneID = art
        XCTAssertTrue(s.paintBoneWeights([BoneWeightDab(center: .zero,amount: 1)],beginStroke: true))
        XCTAssertEqual(s.rigArtwork?.boneMesh,original); XCTAssertEqual(s.undoStack.count,history)
        XCTAssertNotEqual(s.canvasProject.layers.first { $0.id == art }?.boneMesh,original)
        s.finishBoneWeightStroke(commit: false)
        XCTAssertEqual(s.rigArtwork?.boneMesh,original); XCTAssertEqual(s.undoStack.count,history)
        XCTAssertTrue(s.paintBoneWeights([BoneWeightDab(center: .zero,amount: 1)],beginStroke: true))
        s.finishBoneWeightStroke(commit: true)
        XCTAssertNotEqual(s.rigArtwork?.boneMesh,original); XCTAssertEqual(s.undoStack.count,history+1)
        s.undo(); XCTAssertEqual(s.rigArtwork?.boneMesh,original)
        s.redo(); XCTAssertNotEqual(s.rigArtwork?.boneMesh,original)
        s.finishBoneWeights(); XCTAssertNil(s.boneWeightPreview)
    }

    func testBonePaletteSurvivesNestedRenderingAndGlobalArtworkMotion() throws {
        let (s, art) = state()
        let bone = try XCTUnwrap(s.addBone(artworkID: art, parentID: nil, start: .zero, end: Vec2(100,0)))
        s.select(bone); s.bindBoneMesh()
        let index = try XCTUnwrap(s.project.layers.firstIndex { $0.id == bone })
        s.project.layers[index].transform.rotation = Animated(90)
        let resolved = Renderer.resolveParenting(s.project,time: 0)
        let mesh = try XCTUnwrap(resolved.layers.first { $0.id == art }?.boneMesh)
        let palette = try XCTUnwrap(mesh.frameMatrices), bi = try XCTUnwrap(mesh.boneIDs.firstIndex(of: bone))
        let point = palette[bi].apply(Vec2(100,0))
        XCTAssertEqual(point.x,0,accuracy: 1e-8); XCTAssertEqual(point.y,100,accuracy: 1e-8)
        let nested = Renderer.resolveParenting(resolved,time: 0)
        XCTAssertEqual(nested.layers.first { $0.id == art }?.boneMesh?.frameMatrices,palette)
        let ai = try XCTUnwrap(s.project.layers.firstIndex { $0.id == art })
        s.project.layers[ai].transform.scale = Animated(Vec2(190,60))
        s.project.layers[ai].transform.rotation = Animated(35)
        let changed = Renderer.resolveParenting(s.project,time: 0)
        let after = try XCTUnwrap(changed.layers.first { $0.id == art }?.boneMesh?.frameMatrices)
        for (a,b) in zip(palette,after) {
            XCTAssertEqual(a.a,b.a,accuracy: 1e-8); XCTAssertEqual(a.b,b.b,accuracy: 1e-8)
            XCTAssertEqual(a.x,b.x,accuracy: 1e-8); XCTAssertEqual(a.y,b.y,accuracy: 1e-8)
        }
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
