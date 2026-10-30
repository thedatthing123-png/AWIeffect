import XCTest
@testable import AWIeffect

@MainActor
final class MotionBlurSceneTests: XCTestCase {
    private func movingBox(blur: Bool) -> Project {
        var p = Project.new(name: "mb", width: 200, height: 100, fps: 30, duration: 2, background: .black)
        var l = p.makeLayer(name: "box", content: .solid, size: Vec2(20, 60))
        l.fill = Animated(.white)
        l.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(20, 50), interpolation: .linear))
        l.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(180, 50), interpolation: .linear))
        l.motionBlur = blur
        p.motionBlurEnabled = blur
        p.shutterAngle = 360
        p.layers = [l]
        return p
    }

    /// Count of partially-covered columns along the motion direction: blur smears the edges.
    private func softColumns(_ px: [UInt8], width: Int) -> Int {
        (0..<width).filter { x in let v = px[(50 * width + x) * 4]; return v > 20 && v < 235 }.count
    }

    func testMotionBlurSmearsAMovingLayer() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let sharp = try XCTUnwrap(r.renderPixels(project: movingBox(blur: false), time: 0.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let blurred = try XCTUnwrap(r.renderPixels(project: movingBox(blur: true), time: 0.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertLessThan(softColumns(sharp, width: 200), 4)
        XCTAssertGreaterThan(softColumns(blurred, width: 200), 6, "motion blur should soften the leading/trailing edges")
        // Energy is roughly preserved (average, not add).
        let sum = { (a: [UInt8]) in stride(from: 0, to: a.count, by: 4).reduce(0) { $0 + Int(a[$1]) } }
        XCTAssertEqual(Double(sum(blurred)), Double(sum(sharp)), accuracy: Double(sum(sharp)) * 0.08)
    }

    func testStillLayerIsUnchangedByMotionBlur() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var p = movingBox(blur: true)
        p.layers[0].transform.position = Animated(Vec2(100, 50))
        var q = p; q.layers[0].motionBlur = false
        let a = try XCTUnwrap(r.renderPixels(project: p, time: 0.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let b = try XCTUnwrap(r.renderPixels(project: q, time: 0.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertEqual(a, b)
    }

    func testSceneResizeKeepsLayersCentered() {
        var p = Project.new(name: "s", width: 100, height: 100, fps: 30)
        var l = p.makeLayer(name: "a", content: .solid, size: Vec2(10, 10))
        l.transform.position = Animated(Vec2(50, 50))
        p.layers = [l]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.resizeComp(width: 200, height: 100)
        XCTAssertEqual(s.project.layers[0].transform.position.value(at: 0), Vec2(100, 50))
    }

    func testOldProjectsDecodeWithoutMotionBlurFields() throws {
        let p = Project.new(name: "o", width: 10, height: 10, fps: 30)
        let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertFalse(back.motionBlurEnabled)
        XCTAssertEqual(back.shutterAngle, 180)
    }
}
