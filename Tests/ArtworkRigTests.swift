import XCTest
@testable import AWIeffect

final class ArtworkRigTests: XCTestCase {
    func testFKCarriesChildAndReparentPreservesCurrentPose() throws {
        let shoulder = ArtworkBone(name: "Shoulder", start: .zero, end: Vec2(40, 0), rotation: Animated(90))
        let elbow = ArtworkBone(name: "Elbow", start: shoulder.end, end: Vec2(80, 0), parentID: shoulder.id)
        var rig = ArtworkRig(bones: [shoulder, elbow])
        let posed = try XCTUnwrap(rig.pose(at: 0)[elbow.id]).apply(elbow.end)
        assertPoint(posed, Vec2(0, 80))
        rig.reparent(elbow.id, to: nil)
        assertPoint(try XCTUnwrap(rig.pose(at: 0)[elbow.id]).apply(elbow.end), posed)
    }

    func testIKBendsConnectedArtworkAndCanBlendBackToFK() throws {
        let shoulder = ArtworkBone(name: "Shoulder", start: .zero, end: Vec2(40, 0))
        let elbow = ArtworkBone(name: "Elbow", start: shoulder.end, end: Vec2(80, 0), parentID: shoulder.id)
        var rig = ArtworkRig(bones: [shoulder, elbow])
        XCTAssertTrue(rig.enableIK(on: elbow.id, time: 0))
        assertPoint(try XCTUnwrap(rig.pose(at: 0)[elbow.id]).apply(elbow.end), elbow.end)
        let target = Vec2(36, 16)
        rig.editIK(on: elbow.id) { $0.target = Animated(target) }
        let frames = rig.pose(at: 0)
        assertPoint(try XCTUnwrap(frames[elbow.id]).apply(elbow.end), target)
        assertPoint(try XCTUnwrap(frames[shoulder.id]).apply(shoulder.end),
                    try XCTUnwrap(frames[elbow.id]).apply(elbow.start))
        rig.editIK(on: elbow.id) { $0.mix = Animated(0) }
        assertPoint(try XCTUnwrap(rig.pose(at: 0)[elbow.id]).apply(elbow.end), elbow.end)
    }

    func testLocalBindKeepsFarArtworkStationaryAndWeightsSurviveSave() throws {
        let bone = ArtworkBone(name: "Wrist", start: .zero, end: Vec2(20, 0), rotation: Animated(45))
        var rig = ArtworkRig(bones: [bone])
        rig.bind(halfSize: Vec2(60, 60), artworkID: UUID(), detail: 20, radius: 24, amount: 1)
        var mesh = try XCTUnwrap(rig.mesh)
        XCTAssertEqual(mesh.vertices.first?.weights, [BoneMeshWeight(bone: 0, amount: 1)])
        XCTAssertTrue(mesh.paint([BoneWeightDab(center: Vec2(12, 12), amount: 1)], selected: 1, radius: 18, mode: .paint))
        rig.mesh = mesh
        let restored = try JSONDecoder().decode(ArtworkRig.self, from: JSONEncoder().encode(rig))
        XCTAssertEqual(restored.mesh?.vertices, mesh.vertices)
        XCTAssertEqual(restored.palette(for: mesh, at: 0)[0], .identity)
        assertPoint(restored.palette(for: mesh, at: 0)[1].apply(bone.end),
                    Vec2(sqrt(200.0), sqrt(200.0)))
    }

    func testAlphaMeshOmitsTransparentCellsAndKeepsPaintGrid() throws {
        let bone = ArtworkBone(name: "Bone", start: Vec2(-12, -12), end: .zero)
        var rig = ArtworkRig(bones: [bone])
        rig.bind(halfSize: Vec2(32, 32), artworkID: UUID(), detail: 8, radius: nil, amount: 1)
        let full = try XCTUnwrap(rig.mesh)
        var alpha = Array(repeating: UInt8(0), count: 64 * 64)
        alpha[16 * 64 + 16] = 255
        rig.trimTransparentCells(alpha: alpha, width: 64, height: 64)
        let trimmed = try XCTUnwrap(rig.mesh)
        XCTAssertTrue(trimmed.isValid)
        XCTAssertLessThan(trimmed.indices.count, full.indices.count)
        XCTAssertEqual(trimmed.vertices, full.vertices)
    }

    func testArtworkBoneRotationUsesNormalTimelineGraphLane() throws {
        var project = Project.new(name: "Rig", width: 100, height: 100, fps: 30, duration: 2)
        var artwork = project.makeLayer(name: "Artwork", content: .solid, size: Vec2(100, 100))
        var rotation = Animated(0.0)
        rotation.insertKeyframe(Keyframe(time: 0, value: 0))
        rotation.insertKeyframe(Keyframe(time: 1, value: 45))
        let bone = ArtworkBone(name: "Wrist", start: .zero, end: Vec2(20, 0), rotation: rotation)
        artwork.artworkRig = ArtworkRig(bones: [bone])
        let lane = try XCTUnwrap(artwork.propertyLanes().first { $0.id == "artworkRig.\(bone.id).rotation" })
        XCTAssertEqual(lane.times, [0, 1])
        guard case .scalar(let get, let set) = lane.values else { return XCTFail("Expected a rotation graph") }
        rotation.keyframes[1].value = 90
        set(&artwork, rotation)
        XCTAssertEqual(get(artwork)?.value(at: 1), 90)
    }

    private func assertPoint(_ point: Vec2, _ expected: Vec2, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(point.x, expected.x, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(point.y, expected.y, accuracy: 1e-6, file: file, line: line)
    }

    func testArtworkRigRoundTripsWithoutAddingTimelineLayers() throws {
        var project = Project.new(name: "Rig", width: 200, height: 200, fps: 30, duration: 2)
        var artwork = project.makeLayer(name: "Artwork", content: .image(fileName: "arm.png", pixelWidth: 200, pixelHeight: 200), size: Vec2(200, 200))
        let upper = ArtworkBone(name: "Upper arm", start: Vec2(0, 0), end: Vec2(0, 40))
        let lower = ArtworkBone(name: "Forearm", start: Vec2(0, 40), end: Vec2(20, 70))
        var rig = ArtworkRig(bones: [upper, lower])
        rig.reparent(lower.id, to: upper.id)
        XCTAssertFalse(rig.canParent(upper.id, to: lower.id))
        artwork.artworkRig = rig
        project.layers = [artwork]
        let restored = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(restored.layers.count, 1)
        XCTAssertEqual(restored.layers.first?.artworkRig, rig)
    }
}
