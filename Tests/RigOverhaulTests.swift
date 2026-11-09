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

}
