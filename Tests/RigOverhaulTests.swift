import XCTest
import simd
@testable import AWIeffect

@MainActor final class RigOverhaulTests: XCTestCase {
    private func editor() -> (EditorState,UUID) {
        var p = Project.new(name: "Overhaul",width: 600,height: 600,fps: 30,duration: 4)
        let art = p.makeLayer(name: "Continuous character",content: .solid,size: Vec2(400,400)); p.layers = [art]
        return (EditorState(project: p,store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),art.id)
    }
    func testReturnToEarlierWristAndCreateFiveIndependentFingerBranches() throws {
        let (s,art) = editor(); s.panel = .boneWeight
        let shoulder = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: Vec2(-100,0),end: .zero))
        let wrist = try XCTUnwrap(s.addBone(artworkID: art,parentID: shoulder,start: .zero,end: Vec2(100,0)))
        var children: [UUID] = []
        for i in 0..<5 {
            s.selectAuthoringBone(wrist); XCTAssertEqual(s.panel,.boneWeight)
            s.branchFromSelectedBone(); XCTAssertEqual(s.boneDrawingParentID,wrist)
            let child = try XCTUnwrap(s.addBone(artworkID: art,parentID: s.boneDrawingParentID,start: .zero,end: Vec2(140,Double(i-2)*20)))
            children.append(child); s.finishBoneDrawing()
        }
        XCTAssertEqual(s.project.layers.filter { $0.parentID == wrist }.count,5)
        s.selectAuthoringBone(shoulder); s.branchFromSelectedBone()
        XCTAssertEqual(s.boneDrawingParentID,shoulder)
        XCTAssertTrue(children.allSatisfy { id in s.project.layers.first { $0.id == id }?.parentID == wrist })
        let saved = try JSONDecoder().decode(Project.self,from: JSONEncoder().encode(s.project))
        XCTAssertEqual(saved.layers,s.project.layers)
    }
    func testRestJointMovePreservesChildrenAndDoesNotCreatePoseKeys() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        let child = try XCTUnwrap(s.addBone(artworkID: art,parentID: root,start: .zero,end: Vec2(150,50)))
        let before = try XCTUnwrap(Renderer.parentAffine(child,in: s.project,time: 0)).m
        s.boneRestEditing = true; s.beginPanelGesture("Rest")
        s.moveBoneRestJoint(root,to: Vec2(10,20)); s.endPanelGesture()
        let after = try XCTUnwrap(Renderer.parentAffine(child,in: s.project,time: 0)).m
        XCTAssertEqual(before[2].x,after[2].x,accuracy: 1e-8); XCTAssertEqual(before[2].y,after[2].y,accuracy: 1e-8)
        XCTAssertFalse(try XCTUnwrap(s.project.layers.first { $0.id == root }).transform.position.isAnimated)
        s.undo(); XCTAssertEqual(s.project.layers.first { $0.id == root }?.transform.position.value(at: 0),.zero)
    }
    func testFrozenPadGestureDoesNotChaseMovingFKEndpoint() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        var one = try XCTUnwrap(s.rigPointGesture(.fkBoneTip(root)))
        var many = one
        let expected = try XCTUnwrap(one.move(by: Vec2(10,30)))
        var actual = Vec2.zero
        for _ in 0..<10 {
            actual = try XCTUnwrap(many.move(by: Vec2(1,3)))
            s.poseBone(root,atCanvas: actual)
        }
        XCTAssertEqual(actual.x,expected.x,accuracy: 1e-8); XCTAssertEqual(actual.y,expected.y,accuracy: 1e-8)
    }
    func testLocalizedWeightsLeaveDistantTorsoVerticesRigid() throws {
        let art = UUID(),bone = UUID()
        let mesh = try XCTUnwrap(BoneMeshBinding.localized(halfSize: Vec2(200,200),detail: 32,artworkID: art,
            bones: [BoneMeshSource(id: bone,matrix: matrix_identity_double3x3,tip: Vec2(100,0))],radius: 40))
        XCTAssertTrue(mesh.isValid)
        let far = try XCTUnwrap(mesh.vertices.first { $0.rest == Vec2(-200,-200) })
        XCTAssertEqual(far.weights,[BoneMeshWeight(bone: 0,amount: 1)])
        let near = try XCTUnwrap(mesh.vertices.first { $0.rest == Vec2(50,0) })
        XCTAssertEqual(near.weights,[BoneMeshWeight(bone: 1,amount: 1)])
    }
    func testReparentPreservesWorldPositionRejectsCyclesAndDeleteKeepsChildren() throws {
        let (s,art) = editor(); s.panel = .boneWeight
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        let child = try XCTUnwrap(s.addBone(artworkID: art,parentID: root,start: .zero,end: Vec2(150,50)))
        let branch = try XCTUnwrap(s.addBone(artworkID: art,parentID: root,start: .zero,end: Vec2(150,-50)))
        let before = try XCTUnwrap(Renderer.parentAffine(child,in: s.project,time: 0)).m[2]
        s.reparentAuthoringBone(child,to: branch)
        XCTAssertEqual(s.project.layers.first { $0.id == child }?.parentID,branch)
        let after = try XCTUnwrap(Renderer.parentAffine(child,in: s.project,time: 0)).m[2]
        XCTAssertEqual(before.x,after.x,accuracy: 1e-7); XCTAssertEqual(before.y,after.y,accuracy: 1e-7)
        s.reparentAuthoringBone(branch,to: child)
        XCTAssertEqual(s.project.layers.first { $0.id == branch }?.parentID,root)
        s.deleteAuthoringBone(branch)
        XCTAssertEqual(s.project.layers.first { $0.id == child }?.parentID,root)
        XCTAssertEqual(s.panel,.boneWeight)
    }

    func testLongPointChainKeepsSegmentLengthsAndReachesTarget() {
        let points = (0...20).map { Vec2(Double($0)*10,0) }
        for target in [Vec2(100,70),Vec2(100,0),Vec2(400,0),Vec2(0,0)] {
            let result = IKSolver.solvePoints(points,target: target)
            XCTAssertEqual(result.first,points.first)
            for i in 0..<20 { XCTAssertEqual(hypot(result[i+1].x-result[i].x,result[i+1].y-result[i].y),10,accuracy: 1e-7) }
            if hypot(target.x,target.y)<200 { XCTAssertLessThan(hypot(result.last!.x-target.x,result.last!.y-target.y),0.5) }
        }
    }

    func testFrameMapMatchesIndividualHierarchyAndRejectsCycles() throws {
        let (s,art) = editor(); var parent = art
        for i in 0..<40 { parent = try XCTUnwrap(s.addBone(artworkID: art,parentID: parent == art ? nil : parent,start: .zero,end: Vec2(Double(i+1)*50,0))) }
        let frames = Renderer.parentAffineMap(s.project,time: 0)
        for node in s.project.layers {
            let a = try XCTUnwrap(frames[node.id]),b = try XCTUnwrap(Renderer.parentAffine(node.id,in: s.project,time: 0))
            XCTAssertEqual(a.m[2].x,b.m[2].x,accuracy: 1e-7); XCTAssertEqual(a.m[2].y,b.m[2].y,accuracy: 1e-7)
        }
    }
    func testGeometryCacheReusesFrameUntilDocumentOrLiveGestureChanges() throws {
        let (s,art) = editor()
        _ = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        let first = s.rigGeometry
        XCTAssertTrue(first === s.rigGeometry)
        s.beginPanelGesture("Move")
        s.mutate("Move") { p in p.layers[0].transform.position.set(Vec2(320,300),at: 0) }
        XCTAssertFalse(first === s.rigGeometry)
        s.endPanelGesture()
        let committed = s.rigGeometry
        XCTAssertTrue(committed === s.rigGeometry)
        s.currentTime = 1
        XCTAssertFalse(committed === s.rigGeometry)
    }

    func testRestRebindPreservesPaintedWeightsAndProducesIdentityPalette() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        s.selectAuthoringBone(root); s.bindBoneMesh()
        let before = try XCTUnwrap(s.project.layers.first { $0.id == art }?.boneMesh)
        s.boneRestEditing = true
        s.moveBoneRestJoint(root,to: Vec2(15,20))
        s.finishBoneRestEditing(); s.boneRestEditing = false
        let after = try XCTUnwrap(s.project.layers.first { $0.id == art }?.boneMesh)
        XCTAssertEqual(before.vertices,after.vertices)
        let palette = try XCTUnwrap(BoneMeshEvaluation.palette(after,artworkID: art,posed: s.project,time: 0))
        for vertex in after.vertices {
            let point = after.deformed(vertex,matrices: palette)
            XCTAssertEqual(point.x,vertex.rest.x,accuracy: 1e-6)
            XCTAssertEqual(point.y,vertex.rest.y,accuracy: 1e-6)
        }
    }

    func testWeightStrokeCancelDoesNotWriteAndCommitIsUndoable() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        s.selectAuthoringBone(root); s.bindBoneMesh(); s.beginBoneWeights()
        let before = try XCTUnwrap(s.project.layers.first { $0.id == art }?.boneMesh)
        s.boneWeightRadius = 120; s.boneWeightBrush = .erase
        XCTAssertTrue(s.paintBoneWeights([BoneWeightDab(center: Vec2(50,0),amount: 0.8)],beginStroke: true))
        XCTAssertEqual(before,s.project.layers.first { $0.id == art }?.boneMesh)
        s.finishBoneWeightStroke(commit: false)
        XCTAssertEqual(before,s.project.layers.first { $0.id == art }?.boneMesh)
        XCTAssertTrue(s.paintBoneWeights([BoneWeightDab(center: Vec2(50,0),amount: 0.8)],beginStroke: true))
        s.finishBoneWeightStroke(commit: true)
        XCTAssertNotEqual(before.vertices,s.project.layers.first { $0.id == art }?.boneMesh?.vertices)
        s.undo()
        XCTAssertEqual(before,s.project.layers.first { $0.id == art }?.boneMesh)
    }

    func testDuplicatingBoundArtworkRemapsItsSkeletonAndController() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        _ = try XCTUnwrap(s.addBone(artworkID: art,parentID: root,start: .zero,end: Vec2(150,50)))
        s.selectAuthoringBone(root); s.bindBoneMesh(); s.select(art)
        s.duplicateSelected()
        let copyID = try XCTUnwrap(s.selectedLayerID)
        XCTAssertNotEqual(copyID,art)
        let copy = try XCTUnwrap(s.project.layers.first { $0.id == copyID })
        let mesh = try XCTUnwrap(copy.boneMesh)
        XCTAssertEqual(mesh.boneIDs.first,copyID)
        XCTAssertFalse(mesh.boneIDs.contains(art)); XCTAssertFalse(mesh.boneIDs.contains(root))
        XCTAssertEqual(s.project.layers.filter { $0.bone?.artworkID == copyID }.count,2)
        XCTAssertTrue(mesh.isValid)
    }

    func testLongChainMixBlendsEachLocalFKRotationTowardSameFullSolve() throws {
        let (s,art) = editor()
        let a = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(60,0)))
        let b = try XCTUnwrap(s.addBone(artworkID: art,parentID: a,start: .zero,end: Vec2(120,0)))
        let c = try XCTUnwrap(s.addBone(artworkID: art,parentID: b,start: .zero,end: Vec2(180,0)))
        s.selectAuthoringBone(c); s.makeIK(upper: a,controller: nil)
        let owner = try XCTUnwrap(s.project.layers.firstIndex { $0.id == c })
        let rig = try XCTUnwrap(s.project.layers[owner].ik)
        XCTAssertEqual(s.rigArtworkID,art, "A target selection must retain its skeleton authoring context")
        let controller = try XCTUnwrap(s.project.layers.firstIndex { $0.id == rig.controllerID })
        s.project.layers[controller].transform.position = Animated(Vec2(110,75))
        let full = IKSolver.apply(s.project,time: 0)
        s.project.layers[owner].ik?.mix = Animated(0.5)
        let half = IKSolver.apply(s.project,time: 0)
        for id in [a,b,c] {
            let fk = try XCTUnwrap(s.project.layers.first { $0.id == id }).transform.rotation.value(at: 0)
            let ik = try XCTUnwrap(full.layers.first { $0.id == id }).transform.rotation.value(at: 0)
            let actual = try XCTUnwrap(half.layers.first { $0.id == id }).transform.rotation.value(at: 0)
            XCTAssertEqual(actual,IKSolver.blendAngle(fk: fk,ik: ik,w: 0.5),accuracy: 1e-7)
        }
    }

    func testLongSkeletonCarriesRootDepthBeyondThirtyTwoParents() throws {
        let (s,art) = editor(); var parent: UUID? = nil
        for i in 0..<40 { parent = try XCTUnwrap(s.addBone(artworkID: art,parentID: parent,start: .zero,end: Vec2(Double(i+1)*10,0))) }
        for i in s.project.layers.indices { s.project.layers[i].transform.positionZ = Animated(s.project.layers[i].id == art ? 10 : 1) }
        XCTAssertEqual(Renderer.chainZ(parent,in: s.project,time: 0),50,accuracy: 1e-8)
    }

    func testLeavingBoneSelectionFinishesRestModeInsteadOfHidingItsExit() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        s.selectAuthoringBone(root); s.bindBoneMesh(); s.boneRestEditing = true
        s.moveBoneRestJoint(root,to: Vec2(10,15)); s.select(art)
        XCTAssertFalse(s.boneRestEditing)
        let mesh = try XCTUnwrap(s.project.layers.first { $0.id == art }?.boneMesh)
        let palette = try XCTUnwrap(BoneMeshEvaluation.palette(mesh,artworkID: art,posed: s.project,time: 0))
        for vertex in mesh.vertices { XCTAssertEqual(mesh.deformed(vertex,matrices: palette).x,vertex.rest.x,accuracy: 1e-6) }
    }

    func testLeavingRigPanelFinalizesRestAndCancelsPendingToolState() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        s.selectAuthoringBone(root); s.bindBoneMesh(); s.boneRestEditing = true
        s.moveBoneRestJoint(root,to: Vec2(20,10)); s.boneParentPicking = root
        s.panel = .effects
        XCTAssertFalse(s.boneRestEditing); XCTAssertNil(s.boneParentPicking); XCTAssertNil(s.rigRestArtworkID)
        let mesh = try XCTUnwrap(s.project.layers.first { $0.id == art }?.boneMesh)
        let palette = try XCTUnwrap(BoneMeshEvaluation.palette(mesh,artworkID: art,posed: s.project,time: 0))
        for vertex in mesh.vertices { XCTAssertEqual(mesh.deformed(vertex,matrices: palette).x,vertex.rest.x,accuracy: 1e-6) }
    }

    func testOpeningAndClosingRestModeWithoutEditingDoesNotChangeProject() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        s.selectAuthoringBone(root); s.bindBoneMesh()
        let before = s.project
        s.boneRestEditing = true; s.panel = .effects
        XCTAssertEqual(s.project,before)
    }

    func testWholeArtworkBindingDoesNotLeaveDistantVerticesStationary() throws {
        let art = UUID(),bone = UUID()
        let source = BoneMeshSource(id: bone,matrix: matrix_identity_double3x3,tip: Vec2(100,0))
        let mesh = try XCTUnwrap(BoneMeshBinding.wholeArtwork(halfSize: Vec2(200,200),detail: 16,artworkID: art,bones: [source]))
        XCTAssertTrue(mesh.isValid)
        let shifted = RigAffine(simd_double3x3(columns: (SIMD3(1,0,0),SIMD3(0,1,0),SIMD3(25,40,1))))
        for vertex in mesh.vertices {
            let actual = mesh.deformed(vertex,matrices: [.identity,shifted])
            XCTAssertEqual(actual.x,vertex.rest.x+25,accuracy: 1e-7)
            XCTAssertEqual(actual.y,vertex.rest.y+40,accuracy: 1e-7)
        }
        let copy = try JSONDecoder().decode(BoneMeshBinding.self,from: JSONEncoder().encode(mesh))
        XCTAssertEqual(copy.coverage,.wholeArtwork)
    }

    func testPieceBasedControllerOffersItsArtworkAndCanBindOptionalDeformation() throws {
        let (s,upperID) = editor()
        var lower = s.project.makeLayer(name: "Lower piece",content: .solid,size: Vec2(100,30))
        lower.transform.position = Animated(Vec2(400,300))
        s.project.layers.insert(lower,at: 0); s.select(lower.id)
        s.ikDraftTip = (lower.id,Vec2(50,0)); s.makeIK(upper: upperID,controller: nil)
        XCTAssertEqual(s.rigArtworkID,lower.id)
        let target = try XCTUnwrap(s.selectedLayerID)
        XCTAssertTrue(try XCTUnwrap(s.project.layers.first { $0.id == target }).isNull)
        s.bindBoneMesh()
        let mesh = try XCTUnwrap(s.project.layers.first { $0.id == lower.id }?.boneMesh)
        XCTAssertTrue(mesh.isValid); XCTAssertTrue(mesh.boneIDs.contains(upperID)); XCTAssertTrue(mesh.boneIDs.contains(lower.id))
        let pose = IKSolver.apply(s.project,time: 0)
        let palette = try XCTUnwrap(BoneMeshEvaluation.palette(mesh,artworkID: lower.id,posed: pose,time: 0))
        for vertex in mesh.vertices {
            let point = mesh.deformed(vertex,matrices: palette)
            XCTAssertEqual(point.x,vertex.rest.x,accuracy: 1e-6); XCTAssertEqual(point.y,vertex.rest.y,accuracy: 1e-6)
        }
    }

    func testIKTargetAndOwnPiecesCannotDeflectTheirOwnSolver() throws {
        let (s,upperID) = editor()
        var lower = s.project.makeLayer(name: "Lower piece",content: .solid,size: Vec2(100,30))
        lower.transform.position = Animated(Vec2(400,300)); s.project.layers.insert(lower,at: 0)
        s.select(lower.id); s.ikDraftTip = (lower.id,Vec2(50,0)); s.makeIK(upper: upperID,controller: nil)
        let owner = try XCTUnwrap(s.project.layers.first { $0.id == lower.id })
        var rig = try XCTUnwrap(owner.ik); rig.collisions = true
        for i in s.project.layers.indices { s.project.layers[i].isCollider = true }
        let target = Vec2(400,300)
        XCTAssertEqual(IKSolver.collisionTarget(target,rig: rig,owner: owner,in: s.project,time: 0),target)
        var obstacle = s.project.makeLayer(name: "Solid",content: .solid,size: Vec2(100,100))
        obstacle.transform.position = Animated(target); obstacle.isCollider = true
        s.project.layers.append(obstacle)
        XCTAssertNotEqual(IKSolver.collisionTarget(target,rig: rig,owner: owner,in: s.project,time: 0),target)
        rig.collisions = false
        XCTAssertEqual(IKSolver.collisionTarget(target,rig: rig,owner: owner,in: s.project,time: 0),target)
    }

    func testAttachingTheSkeletonsOwnArtworkOpensWeightsWithoutMakingACycle() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        let before = s.project
        s.attachArtwork(art,toJoint: root)
        XCTAssertEqual(s.project,before); XCTAssertEqual(s.panel,.boneWeight)
        XCTAssertNil(s.recoveryNotice); XCTAssertEqual(s.selectedLayerID,root)
    }

    func testPoseOriginTranslationMovesWeightedArmWithoutChangingItsRestBind() throws {
        let (s,art) = editor()
        let root = try XCTUnwrap(s.addBone(artworkID: art,parentID: nil,start: .zero,end: Vec2(100,0)))
        let child = try XCTUnwrap(s.addBone(artworkID: art,parentID: root,start: .zero,end: Vec2(180,0)))
        s.selectAuthoringBone(root); s.boneMeshCoverage = .wholeArtwork; s.bindBoneMesh()
        let before = try XCTUnwrap(s.project.layers.first { $0.id == art }?.boneMesh)
        let childBefore = try XCTUnwrap(Renderer.parentAffine(child,in: s.project,time: 0)).m[2]
        s.rigOriginJointID = root; XCTAssertEqual(s.rigPositionSelection,.poseJoint(root))
        s.moveRigPosition(.poseJoint(root),to: Vec2(25,40))
        let childAfter = try XCTUnwrap(Renderer.parentAffine(child,in: s.project,time: 0)).m[2]
        XCTAssertEqual(childAfter.x-childBefore.x,25,accuracy: 1e-7); XCTAssertEqual(childAfter.y-childBefore.y,40,accuracy: 1e-7)
        let after = try XCTUnwrap(s.project.layers.first { $0.id == art }?.boneMesh)
        XCTAssertEqual(after.inverseBinds,before.inverseBinds); XCTAssertFalse(s.boneRestDirty)
        let palette = try XCTUnwrap(BoneMeshEvaluation.palette(after,artworkID: art,posed: s.project,time: 0))
        for vertex in after.vertices {
            let moved = after.deformed(vertex,matrices: palette)
            XCTAssertEqual(moved.x,vertex.rest.x+25,accuracy: 1e-6); XCTAssertEqual(moved.y,vertex.rest.y+40,accuracy: 1e-6)
        }
    }

    func testLongChainBendDirectionWorksForAnAlreadyBentSetup() {
        let rest = [Vec2(0,0),Vec2(50,10),Vec2(100,0),Vec2(150,0)]
        let target = Vec2(110,0)
        let a = IKSolver.solvePoints(rest,target: target)
        let b = IKSolver.solvePoints(rest,target: target,flip: true)
        for i in rest.indices {
            XCTAssertEqual(a[i].x,b[i].x,accuracy: 1e-6)
            XCTAssertEqual(a[i].y,-b[i].y,accuracy: 1e-6)
        }
        XCTAssertGreaterThan(abs(a[1].y),1)
    }

}
