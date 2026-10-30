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

    func testAlphaTrackMatteCutsLayerAndHidesMatte() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var p = Project.new(name: "tm", width: 100, height: 100, fps: 30, duration: 2, background: .black)
        var matte = p.makeLayer(name: "matte", content: .solid, size: Vec2(40, 100))
        matte.fill = Animated(RGBA(0, 0, 1)); matte.transform.position = Animated(Vec2(30, 50))
        var fill = p.makeLayer(name: "fill", content: .solid, size: Vec2(100, 100))
        fill.fill = Animated(RGBA(1, 0, 0)); fill.trackMatte = .alpha
        p.layers = [matte, fill]
        let px = try XCTUnwrap(r.renderPixels(project: p, time: 0.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        func at(_ x: Int) -> (Int, Int) { let i = (50 * 100 + x) * 4; return (Int(px[i]), Int(px[i + 2])) }
        XCTAssertGreaterThan(at(30).0, 200, "red should show inside the matte")
        XCTAssertLessThan(at(80).0, 20, "red must be cut outside the matte")
        XCTAssertLessThan(at(30).1, 20, "the matte layer itself must be hidden")
        // Inverted
        p.layers[1].trackMatte = .alphaInverted
        let inv = try XCTUnwrap(r.renderPixels(project: p, time: 0.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertLessThan(Int(inv[(50 * 100 + 30) * 4]), 20)
        XCTAssertGreaterThan(Int(inv[(50 * 100 + 80) * 4]), 200)
    }

    func testPosterizeTimeHoldsFrames() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var p = movingBox(blur: false)
        p.layers[0].timeFX = LayerTimeFX(posterizeFPS: 4)
        let a = try XCTUnwrap(r.renderPixels(project: p, time: 0.51, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let b = try XCTUnwrap(r.renderPixels(project: p, time: 0.70, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertEqual(a, b, "posterized layer must not move between steps")
    }

    func testEchoAddsTrailingCopies() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var p = movingBox(blur: false)
        let plain = try XCTUnwrap(r.renderPixels(project: p, time: 0.6, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        p.layers[0].timeFX = LayerTimeFX(echoCount: 4, echoDelay: 0.08, echoDecay: 0.7)
        let echo = try XCTUnwrap(r.renderPixels(project: p, time: 0.6, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let lit = { (a: [UInt8]) in stride(from: 0, to: a.count, by: 4).filter { a[$0] > 30 }.count }
        XCTAssertGreaterThan(lit(echo), lit(plain) * 2, "echo copies should trail behind the moving box")
    }

    func testFreezeFrame() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var p = movingBox(blur: false)
        p.layers[0].timeFX = LayerTimeFX(freezeAt: 0.2)
        let a = try XCTUnwrap(r.renderPixels(project: p, time: 0.3, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let b = try XCTUnwrap(r.renderPixels(project: p, time: 0.9, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertEqual(a, b)
    }

    func testLightsShade3DLayers() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var p = Project.new(name: "l", width: 200, height: 200, fps: 30, duration: 2, background: .black)
        var card = p.makeLayer(name: "card", content: .solid, size: Vec2(200, 200))
        card.fill = Animated(.white); card.is3D = true
        p.layers = [card]
        let unlit = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        // Ambient at 50%: everything uniformly darker.
        var amb = p.makeLayer(name: "amb", content: .light, size: Vec2(1, 1))
        amb.light = LightOptions(type: .ambient, intensity: Animated(50))
        var q = p; q.layers.insert(amb, at: 0)
        let ambPx = try XCTUnwrap(r.renderPixels(project: q, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        func px(_ a: [UInt8], _ x: Int, _ y: Int) -> Int { Int(a[(y * 200 + x) * 4]) }
        XCTAssertGreaterThan(px(unlit, 100, 100), 240)
        XCTAssertLessThan(px(ambPx, 100, 100), 200, "ambient 50% should darken")
        // A spot pointed straight at the middle: bright pool in the center, dark corners.
        var spot = p.makeLayer(name: "spot", content: .light, size: Vec2(1, 1))
        spot.transform.position = Animated(Vec2(100, 100)); spot.transform.positionZ = Animated(-300)
        spot.light = LightOptions(type: .spot, coneAngle: Animated(40), coneFeather: Animated(20))
        var s2 = p; s2.layers.insert(spot, at: 0)
        let spotPx = try XCTUnwrap(r.renderPixels(project: s2, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertGreaterThan(px(spotPx, 100, 100), px(spotPx, 5, 5) + 80, "spot light should pool in the center")
    }
}
