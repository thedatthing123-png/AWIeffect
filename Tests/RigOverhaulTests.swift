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
    func testFrameMapMatchesIndividualHierarchyAndRejectsCycles() throws {
        let (s,art) = editor(); var parent = art
        for _ in 0..<40 { parent = try XCTUnwrap(s.addBone(artworkID: art,parentID: parent == art ? nil : parent,start: .zero,end: Vec2(100,100))) }
        let frames = Renderer.parentAffineMap(s.project,time: 0)
        for node in s.project.layers {
            let a = try XCTUnwrap(frames[node.id]),b = try XCTUnwrap(Renderer.parentAffine(node.id,in: s.project,time: 0))
            XCTAssertEqual(a.m[2].x,b.m[2].x,accuracy: 1e-7); XCTAssertEqual(a.m[2].y,b.m[2].y,accuracy: 1e-7)
        }
    }
}
