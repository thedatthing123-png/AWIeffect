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

    func testBuild26LongChainIKControlsSixJointsAndPreservesFK() throws {
        var p = Project.new(name: "Long chain", width: 1000, height: 700, fps: 30, duration: 4)
        var previous: UUID?
        var ids: [UUID] = []
        for index in 0..<6 {
            var bone = p.makeLayer(name: "Joint \(index + 1)", content: .solid, size: Vec2(24, 24))
            bone.isNull = true
            bone.transform.anchor = Animated(.zero)
            bone.transform.position = Animated(index == 0 ? Vec2(170, 170) : Vec2(60, 0))
            bone.parentID = previous
            ids.append(bone.id)
            previous = bone.id
            p.layers.append(bone)
        }
        let state = EditorState(project: p, store: ProjectStore(root:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        let tipID = try XCTUnwrap(ids.last)
        state.select(tipID)
        state.ikDraftTip = (tipID, Vec2(60, 0))
        XCTAssertEqual(IKSolver.connectedPath(root: ids[0], end: tipID, in: state.project), ids)
        state.makeIK(upper: ids[0], controller: nil)
        let rig = try XCTUnwrap(state.project.layers.first(where: { $0.id == tipID })?.ik)
        XCTAssertEqual(rig.chainIDs, ids)
        XCTAssertEqual(rig.restTip, Vec2(60, 0))
        let controllerIndex = try XCTUnwrap(state.project.layers.firstIndex(where: { $0.id == rig.controllerID }))
        let target = Vec2(355, 330)
        state.project.layers[controllerIndex].transform.position = Animated(target)
        let posed = IKSolver.apply(state.project, time: 0)
        let owner = try XCTUnwrap(posed.layers.first(where: { $0.id == tipID }))
        let reached = try XCTUnwrap(IKSolver.tipWorld(owner, rig: rig, in: posed, time: 0))
        XCTAssertLessThan(hypot(reached.x - target.x, reached.y - target.y), 3.0,
                          "Every connected bone should contribute to reaching one controller")
        let jointsRotated = ids.filter { id in
            let bone = posed.layers.first(where: { $0.id == id })!
            return abs(bone.transform.rotation.value(at: 0)) > 0.1
        }
        XCTAssertGreaterThan(jointsRotated.count, 2)

        // FK blend is preserved, not overwritten by the new solver.
        let ownerIndex = try XCTUnwrap(state.project.layers.firstIndex(where: { $0.id == tipID }))
        state.project.layers[ownerIndex].ik?.mix = Animated(0)
        let fk = IKSolver.apply(state.project, time: 0)
        for id in ids {
            let raw = try XCTUnwrap(state.project.layers.first(where: { $0.id == id }))
            let after = try XCTUnwrap(fk.layers.first(where: { $0.id == id }))
            XCTAssertEqual(after.transform.rotation.value(at: 0),
                           raw.transform.rotation.value(at: 0), accuracy: 1e-8)
        }
        let saved = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(state.project))
        XCTAssertEqual(saved.layers.first(where: { $0.id == tipID })?.ik?.chainIDs, ids)
    }

    func testBuild26VeryLongHierarchyRetainsJointPlacementBeyondSixteenAncestors() throws {
        var p = Project.new(name: "25 joint skeleton", width: 2000, height: 800, fps: 30, duration: 4)
        var previous: UUID?
        for i in 0..<25 {
            var layer = p.makeLayer(name: "Bone \(i)", content: .solid, size: Vec2(20, 20))
            layer.isNull = true
            layer.transform.anchor = Animated(.zero)
            layer.transform.position = Animated(Vec2(i == 0 ? 100 : 15, i == 0 ? 100 : 0))
            layer.parentID = previous
            previous = layer.id
            p.layers.append(layer)
        }
        let last = try XCTUnwrap(previous)
        let world = try XCTUnwrap(Renderer.parentAffine(last, in: p, time: 0))
        let origin = try XCTUnwrap(LayerPlacement.projected(.zero, by: world.m))
        XCTAssertEqual(origin.x, 100 + 24 * 15, accuracy: 1e-7)
        XCTAssertEqual(origin.y, 100, accuracy: 1e-7)
    }

    func testBuild26MultipleArtworkPiecesCanAttachToOneJoint() throws {
        var p = Project.new(name: "Repeated artwork attachment", width: 600, height: 600, fps: 30, duration: 4)
        var joint = p.makeLayer(name: "Head joint", content: .solid, size: Vec2(24, 24))
        joint.isNull = true
        joint.transform.anchor = Animated(.zero)
        joint.transform.position = Animated(Vec2(230, 180))
        var accessoryA = p.makeLayer(name: "Hair", content: .solid, size: Vec2(60, 80))
        accessoryA.transform.position = Animated(Vec2(420, 100))
        var accessoryB = p.makeLayer(name: "Earring", content: .solid, size: Vec2(24, 24))
        accessoryB.transform.position = Animated(Vec2(390, 420))
        p.layers = [joint, accessoryA, accessoryB]
        let state = EditorState(project: p, store: ProjectStore(root:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        state.select(joint.id)
        state.attachArtwork(accessoryA.id, toJoint: joint.id)
        state.attachArtwork(accessoryB.id, toJoint: joint.id)
        XCTAssertEqual(state.project.layers.first(where: { $0.id == accessoryA.id })?.parentID, joint.id)
        XCTAssertEqual(state.project.layers.first(where: { $0.id == accessoryB.id })?.parentID, joint.id)
        let resolved = Renderer.resolveParenting(state.project, time: 0)
        for id in [accessoryA.id, accessoryB.id] {
            let positioned = try XCTUnwrap(resolved.layers.first(where: { $0.id == id }))
            XCTAssertEqual(positioned.transform.position.value(at: 0).x, 230, accuracy: 1e-6)
            XCTAssertEqual(positioned.transform.position.value(at: 0).y, 180, accuracy: 1e-6)
        }
        // The underlying artwork's parent doesn't change; no extra IK controller is required.
        XCTAssertEqual(state.project.layers.filter { $0.ik != nil }.count, 0)
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
        s.project.layers[ri].transform.scale = Animated(Vec2(150,150))
        s.project.layers[ri].transform.positionZ = Animated(200)
        s.project.layers[ci].transform.position = Animated(Vec2(30,100))
        let resolved = Renderer.resolveParenting(s.project,time: 0)
        let drawnLower = try XCTUnwrap(resolved.layers.first { $0.id == lower.id })
        let drawnHand = try XCTUnwrap(resolved.layers.first { $0.id == hand.id })
        // The linked hand and the rendered forearm endpoint must both meet the target.
        let posed = IKSolver.apply(s.project,time: 0)
        let parent = try XCTUnwrap(Renderer.parentAffine(lower.id,in: posed,time: 0))
        let wrist = parent.m*SIMD3(100.0,0,1)
        let target = try XCTUnwrap(Renderer.parentAffine(rig.controllerID,in: posed,time: 0)).m*SIMD3(0.0,0,1)
        XCTAssertEqual(wrist.x,target.x,accuracy: 1e-6); XCTAssertEqual(wrist.y,target.y,accuracy: 1e-6)
        let renderedWrist = Renderer.layerMatrix(drawnLower,time: 0,renderScale: 1)*SIMD3(50.0,0,1)
        XCTAssertEqual(renderedWrist.x,target.x,accuracy: 1e-6); XCTAssertEqual(renderedWrist.y,target.y,accuracy: 1e-6)
        XCTAssertEqual(drawnHand.transform.position.value(at: 0).x,target.x,accuracy: 1e-6)
        XCTAssertEqual(drawnHand.transform.position.value(at: 0).y,target.y,accuracy: 1e-6)
        XCTAssertEqual(drawnLower.transform.positionZ.value(at: 0),200,accuracy: 1e-6)
        XCTAssertEqual(drawnHand.transform.positionZ.value(at: 0),200,accuracy: 1e-6)
        XCTAssertNil(drawnHand.bone); XCTAssertNil(drawnLower.bone)
        let saved = try JSONDecoder().decode(Project.self,from: JSONEncoder().encode(s.project))
        XCTAssertEqual(saved.layers.first { $0.id == hand.id }?.parentID,lower.id)
    }

    func testBuild26HandAttachmentFollowsWristAndRefusesOverlappingRig() throws {
        var p = Project.new(name: "Bind three parts", width: 600, height: 600, fps: 30, duration: 4)
        var upper = p.makeLayer(name: "Upper", content: .solid, size: Vec2(120, 36))
        upper.transform.position = Animated(Vec2(200, 200))
        upper.transform.anchor = Animated(Vec2(-60, 0))
        var lower = p.makeLayer(name: "Lower", content: .solid, size: Vec2(100, 32))
        lower.transform.position = Animated(Vec2(320, 200))
        lower.transform.anchor = Animated(Vec2(-50, 0))
        var hand = p.makeLayer(name: "Hand", content: .solid, size: Vec2(36, 26))
        hand.transform.position = Animated(Vec2(450, 300)) // deliberately detached
        hand.transform.anchor = Animated(Vec2(-18, 0))
        p.layers = [hand, lower, upper]
        let state = EditorState(project: p, store: ProjectStore(root:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        state.select(lower.id)
        state.ikDraftTip = (lower.id, Vec2(50, 0))
        state.makeIK(upper: upper.id, controller: nil, hand: hand.id)

        let rig = try XCTUnwrap(state.project.layers.first(where: { $0.id == lower.id })?.ik)
        XCTAssertEqual(rig.restTip, Vec2(50, 0))
        XCTAssertEqual(state.project.layers.first(where: { $0.id == hand.id })?.parentID, lower.id)
        let posed = IKSolver.apply(state.project, time: 0)
        let parent = try XCTUnwrap(Renderer.parentAffine(lower.id, in: posed, time: 0))
        let wrist = parent.m * SIMD3(100.0, 0, 1)
        let visibleHand = try XCTUnwrap(Renderer.resolveParenting(state.project, time: 0)
            .layers.first(where: { $0.id == hand.id }))
        XCTAssertEqual(visibleHand.transform.position.value(at: 0).x, wrist.x, accuracy: 1e-6)
        XCTAssertEqual(visibleHand.transform.position.value(at: 0).y, wrist.y, accuracy: 1e-6)

        // A second attempt cannot silently attach another IK controller to these joints.
        let controllerCount = state.project.layers.filter { $0.isNull && $0.name.contains("Controller") }.count
        state.select(lower.id)
        state.makeIK(upper: upper.id, controller: nil, hand: hand.id)
        XCTAssertEqual(state.project.layers.filter { $0.isNull && $0.name.contains("Controller") }.count, controllerCount)
        XCTAssertEqual(state.project.layers.filter { $0.ik != nil }.count, 1)
    }

    func testBuild26RepairsDetachedLegacyHandWithoutNewController() throws {
        var p = Project.new(name: "Repair legacy rig", width: 600, height: 600, fps: 30, duration: 4)
        var upper = p.makeLayer(name: "Upper", content: .solid, size: Vec2(120, 36))
        upper.transform.position = Animated(Vec2(200, 200))
        upper.transform.anchor = Animated(Vec2(-60, 0))
        var lower = p.makeLayer(name: "Lower", content: .solid, size: Vec2(100, 32))
        lower.parentID = upper.id
        lower.transform.position = Animated(Vec2(120, 0))
        lower.transform.anchor = Animated(Vec2(-50, 0))
        var hand = p.makeLayer(name: "Hand", content: .solid, size: Vec2(36, 26))
        hand.transform.position = Animated(Vec2(460, 320))
        p.layers = [hand, lower, upper]
        let s = EditorState(project: p, store: ProjectStore(root:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.select(lower.id); s.ikDraftTip = (lower.id, Vec2(50, 0))
        s.makeIK(upper: upper.id, controller: nil)
        let rig = try XCTUnwrap(s.project.layers.first(where: { $0.id == lower.id })?.ik)
        // Simulate old saved rigs that have the lengths but did not store a local tip.
        let index = try XCTUnwrap(s.project.layers.firstIndex(where: { $0.id == lower.id }))
        s.project.layers[index].ik?.restTip = nil
        let existingCount = s.project.layers.count
        s.select(rig.controllerID)
        s.repairIKEndAttachment(hand.id)
        XCTAssertEqual(s.project.layers.count, existingCount)
        XCTAssertEqual(s.project.layers.first(where: { $0.id == hand.id })?.parentID, lower.id)
        let owner = try XCTUnwrap(s.project.layers.first(where: { $0.id == lower.id }))
        let reached = try XCTUnwrap(s.reachedIKWrist(owner: owner, in: s.project, at: 0))
        let shown = try XCTUnwrap(Renderer.resolveParenting(s.project, time: 0)
            .layers.first(where: { $0.id == hand.id }))
        XCTAssertEqual(shown.transform.position.value(at: 0).x, reached.x, accuracy: 1e-6)
        XCTAssertEqual(shown.transform.position.value(at: 0).y, reached.y, accuracy: 1e-6)
    }

    func testBuild26RigPositionPadChangesOnlySelectedJoint() throws {
        let (s, art) = state()
        var upper = s.project.makeLayer(name: "Upper", content: .solid, size: Vec2(120, 32))
        upper.transform.position = Animated(Vec2(250, 200))
        var lower = s.project.makeLayer(name: "Lower", content: .solid, size: Vec2(100, 32))
        lower.transform.position = Animated(Vec2(350, 200))
        s.project.layers += [upper, lower]

        s.select(lower.id)
        s.ikDraftUpper = upper.id
        let undoBefore = s.undoStack.count
        s.moveRigPosition(.restEndpoint(lower.id), to: Vec2(50, 0))
        XCTAssertEqual(s.ikDraftTip?.point, Vec2(50, 0))
        XCTAssertEqual(s.undoStack.count, undoBefore, "Rest point movement is not a keyframe or undo")
        s.makeIK(upper: upper.id, controller: nil)
        let rig = try XCTUnwrap(s.project.layers.first(where: { $0.id == lower.id })?.ik)
        let unchangedArtPosition = try XCTUnwrap(s.project.layers.first(where: { $0.id == art })?.transform.position)
        s.select(rig.controllerID)
        s.beginPanelGesture("Move Rig Point")
        s.moveRigPosition(.ikController(rig.controllerID), to: Vec2(305, 95))
        s.endPanelGesture()
        XCTAssertEqual(s.rigPositionValue(.ikController(rig.controllerID)), Vec2(305, 95))
        XCTAssertEqual(s.project.layers.first(where: { $0.id == art })?.transform.position, unchangedArtPosition)
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
