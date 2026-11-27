import XCTest
@testable import AWIeffect

final class SmoothSceneTests: XCTestCase {
    private func fixture() -> Project {
        var project = Project.new(name: "Smooth Scene", width: 200, height: 120, fps: 30, duration: 2, background: .black)
        func movingLayer(name: String, y: Double, color: RGBA) -> Layer {
            var layer = project.makeLayer(name: name, content: .solid, size: Vec2(16, 16))
            layer.fill = Animated(color)
            layer.transform.position.keyframes = [
                Keyframe(time: 0, value: Vec2(30, y)),
                Keyframe(time: 1, value: Vec2(150, y)),
                Keyframe(time: 1.7, value: Vec2(170, y), interpolation: .hold)
            ]
            return layer
        }
        var adjustment = project.makeLayer(name: "Smooth Scene", content: .adjustment, size: Vec2(200, 120))
        adjustment.outPoint = 1.5
        adjustment.smoothSceneStrength = 100
        let above = movingLayer(name: "Above", y: 30, color: .white)
        let below = movingLayer(name: "Below", y: 84, color: RGBA(0.28, 0.85, 1))
        project.layers = [above, adjustment, below]
        return project
    }

    func testAdjustmentScopeAndKeyframePositions() throws {
        let raw = fixture()
        let quarter = SmoothScene.applying(to: raw, at: 0.25)
        XCTAssertEqual(quarter.layers[0], raw.layers[0])
        XCTAssertLessThan(quarter.layers[2].transform.position.value(at: 0.25).x, 60)
        XCTAssertEqual(quarter.layers[2].transform.position.value(at: 1), Vec2(150, 84))
        XCTAssertEqual(quarter.layers[2].transform.position.keyframes, raw.layers[2].transform.position.keyframes)
        XCTAssertEqual(SmoothScene.applying(to: raw, at: 1.5), raw)
        let restored = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(quarter))
        XCTAssertEqual(restored.layers[1].smoothSceneStrength, 100)
        XCTAssertEqual(restored.layers[2].transform.position.sceneSmoothing, 0)
    }

    func testHoldAndAuthoredBezierSurvive() {
        var track = Animated(0.0)
        track.keyframes = [Keyframe(time: 0, value: 0, interpolation: .hold),
                           Keyframe(time: 1, value: 60, interpolation: .bezier),
                           Keyframe(time: 2, value: 100)]
        var smoothed = track
        smoothed.sceneSmoothing = 1
        for time in [0.25, 0.99, 1, 1.25, 1.9, 2] {
            XCTAssertEqual(smoothed.value(at: time), track.value(at: time))
        }
    }

    func testCameraFollowsShotAndProjectionMode() {
        var raw = fixture()
        raw.layers.remove(at: 1)
        raw.layers[1].is3D = true
        var first = raw.makeLayer(name: "Camera A", content: .camera, size: Vec2(200, 120))
        first.camera = CameraOptions()
        first.smoothSceneStrength = 65
        first.transform.position = raw.layers[0].transform.position
        var next = first
        next.id = UUID()
        next.inPoint = 1
        next.smoothSceneStrength = nil
        // The topmost camera cuts in over the first camera, which stays on the timeline.
        raw.layers.insert(contentsOf: [next, first], at: 0)
        var evaluated = SmoothScene.applying(to: raw, at: 0.25)
        XCTAssertEqual(evaluated.layers[1].transform.position.sceneSmoothing, 0.65, accuracy: 1e-8)
        XCTAssertEqual(evaluated.layers[2].transform.position.sceneSmoothing, 0)
        XCTAssertEqual(evaluated.layers[3].transform.position.sceneSmoothing, 0.65, accuracy: 1e-8)
        XCTAssertEqual(SmoothScene.applying(to: raw, at: 1.1), raw)

        raw.layers[1].camera?.affects2D = true
        evaluated = SmoothScene.applying(to: raw, at: 0.25)
        XCTAssertEqual(evaluated.layers[2].transform.position.sceneSmoothing, 0.65, accuracy: 1e-8)
    }

    func testOverlappingScopesUseStrongestAndDoNotMoveSharedParentForUpperLayer() {
        var raw = fixture()
        raw.layers[0].parentID = raw.layers[2].id
        let isolated = SmoothScene.applying(to: raw, at: 0.25)
        XCTAssertEqual(isolated.layers[2].transform.position.sceneSmoothing, 0)

        raw.layers[0].parentID = nil
        var camera = raw.makeLayer(name: "Camera", content: .camera, size: Vec2(200, 120))
        camera.camera = CameraOptions()
        camera.camera?.affects2D = true
        camera.smoothSceneStrength = 35
        raw.layers.insert(camera, at: 0)
        let both = SmoothScene.applying(to: raw, at: 0.25)
        XCTAssertEqual(both.layers[1].transform.position.sceneSmoothing, 0.35, accuracy: 1e-8)
        XCTAssertEqual(both.layers[3].transform.position.sceneSmoothing, 1, accuracy: 1e-8)
    }

    func testOnlyContinuousShakeGetsProceduralSmoothing() {
        var raw = fixture()
        var stepped = EffectRegistry.shakePro18.makeInstance()
        stepped.params["hold"] = .number(Animated(3))
        raw.layers[2].effects = [EffectRegistry.shake.makeInstance(), stepped]
        let evaluated = SmoothScene.applying(to: raw, at: 0.25)
        XCTAssertGreaterThan(evaluated.layers[2].effects[0].sceneSmoothing, 0)
        XCTAssertEqual(evaluated.layers[2].effects[1], stepped)
        XCTAssertEqual(evaluated.layers[2].effects[0].params, raw.layers[2].effects[0].params)
    }

    @MainActor
    func testRendersASinglePoseAndExportsComparison() async throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("Metal unavailable") }
        let project = fixture()
        let media: (String) -> URL = { URL(fileURLWithPath: $0) }
        let frame = try XCTUnwrap(renderer.renderPixels(project: project, time: 0.25, mediaURL: media))
        func channel(x: Int, y: Int, component: Int) -> UInt8 {
            frame.rgba[(y * frame.width + x) * 4 + component]
        }
        XCTAssertGreaterThan(channel(x: 60, y: 30, component: 0), 230)
        XCTAssertGreaterThan(channel(x: 46, y: 84, component: 2), 230)
        XCTAssertLessThan(channel(x: 60, y: 84, component: 2), 20)

        let output = URL(fileURLWithPath: "/tmp/awi-authoring/smooth-scene", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let video = try await Exporter().export(project: project, settings: ExportSettings(format: .mp4), mediaURL: media) { _ in }
        defer { try? FileManager.default.removeItem(at: video) }
        try Data(contentsOf: video).write(to: output.appendingPathComponent("adjustment-comparison.mp4"), options: .atomic)
    }
}
