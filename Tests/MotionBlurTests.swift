import XCTest
@testable import AWIeffect

final class MotionBlurTests: XCTestCase {
    /// A still white bar and a 2D camera that pans fast across it.
    private func panScene() -> Project {
        var p = Project.new(name: "pan", width: 160, height: 80, fps: 10, duration: 2, background: RGBA(0, 0, 0, 0))
        var bar = p.makeLayer(name: "bar", content: .solid, size: Vec2(6, 60))
        bar.fill = Animated(.white)
        bar.transform.position = Animated(Vec2(80, 40))
        var cam = p.makeLayer(name: "cam", content: .camera, size: Vec2(160, 80))
        cam.camera = CameraOptions(); cam.camera?.affects2D = true
        cam.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(40, 40)))
        cam.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(120, 40)))
        p.layers = [cam, bar]
        p.smoothMotion = false; p.shutterAngle = 360; p.blurSamples = 24
        return p
    }

    private func coverage(_ p: Project) throws -> (count: Int, columns: [Int]) {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let px = try XCTUnwrap(r.renderPixels(project: p, time: 0.5, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        var columns: [Int] = []
        for x in 0..<160 where (0..<80).contains(where: { px[($0 * 160 + x) * 4 + 3] > 8 }) { columns.append(x) }
        return (stride(from: 3, to: px.count, by: 4).filter { px[$0] > 8 }.count, columns)
    }

    func testCameraPanBlursAStillLayer() throws {
        var p = panScene()
        let sharp = try coverage(p).count
        p.layers[1].motionBlur = true; p.motionBlurEnabled = true
        XCTAssertGreaterThan(try coverage(p).count, sharp * 3, "the camera's move smears the bar")
    }

    /// The bug behind see-through blur: a layer that barely moves must stay solid where every sample covers it.
    func testBlurredLayerStaysSolidWhereItAlwaysCovers() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var p = Project.new(name: "solid", width: 120, height: 120, fps: 10, duration: 2, background: RGBA(0, 0, 0, 0))
        var sq = p.makeLayer(name: "sq", content: .solid, size: Vec2(60, 60))
        sq.fill = Animated(.white); sq.motionBlur = true
        sq.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(10, 60)))
        sq.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(110, 60)))
        p.layers = [sq]; p.motionBlurEnabled = true; p.smoothMotion = false; p.shutterAngle = 180; p.blurSamples = 16
        let px = try XCTUnwrap(r.renderPixels(project: p, time: 0.5, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let middle: Int = (60 * 120 + 60) * 4
        XCTAssertGreaterThan(px[middle + 3], 250, "the middle is covered by every sample, so it stays opaque")
        XCTAssertGreaterThan(px[middle], 250)
        let edgeIndex: Int = (60 * 120 + 30) * 4 + 3
        let edge: UInt8 = px[edgeIndex]
        XCTAssertTrue(edge > 10 && edge < 245, "the leading and trailing edges are where the blur lives (\(edge))")
    }

    func testMasterSwitchOffMeansNothingBlurs() throws {
        var p = panScene()
        let sharp = try coverage(p).count
        p.layers[1].motionBlur = true; p.motionBlurEnabled = false
        XCTAssertEqual(try coverage(p).count, sharp)
    }

    func testEveryLayerFromTheCameraAndKeepSharp() throws {
        var p = panScene()
        let sharp = try coverage(p).count
        p.motionBlurEnabled = true; p.blurAllLayers = true
        XCTAssertFalse(p.layers[1].motionBlur)
        XCTAssertGreaterThan(try coverage(p).count, sharp * 3, "no per-layer switch needed")
        p.sharpLayerIDs = [p.layers[1].id]
        XCTAssertEqual(try coverage(p).count, sharp, "a layer kept sharp stays sharp")
        XCTAssertFalse(p.blurs(p.layers[0]), "the camera itself never blurs")
    }

    func testShutterPhaseMovesTheTrail() throws {
        var p = panScene()
        p.motionBlurEnabled = true; p.blurAllLayers = true
        p.shutterPhase = -180
        let centered = try coverage(p).columns
        p.shutterPhase = 0
        let after = try coverage(p).columns
        XCTAssertFalse(centered.isEmpty); XCTAssertFalse(after.isEmpty)
        XCTAssertNotEqual(centered.first, after.first, "opening the shutter later moves where the trail sits")
        XCTAssertEqual(centered.count, after.count, accuracy: 3, "but keeps its length")
    }

    func testOldProjectsKeepTheirBlurBehavior() throws {
        let p = Project.new(name: "old", width: 10, height: 10, fps: 30, duration: 1, background: .black)
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertFalse(back.blurAllLayers)
        XCTAssertEqual(back.shutterPhase, -back.shutterAngle / 2)
        XCTAssertEqual(back.shutterOpen.start, -0.5 / 30 * back.shutterAngle / 360 * 2 / 2, accuracy: 1e-9)
    }
}
