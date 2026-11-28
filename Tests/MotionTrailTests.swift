import XCTest
import SwiftUI
@testable import AWIeffect

final class MotionTrailTests: XCTestCase {
    func testTrailFollowsMotionAndTapersBehindLayer() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var project = Project.new(name: "Ribbon", width: 200, height: 100, fps: 30, duration: 2, background: .black)
        var layer = project.makeLayer(name: "Head", content: .shape(.ellipse), size: Vec2(10, 10))
        layer.fill = Animated(.white)
        layer.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(20, 50), interpolation: .linear))
        layer.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(180, 50), interpolation: .linear))
        var effect = EffectRegistry.motionTrail.makeInstance()
        effect.params["lifetime"] = .number(Animated(1))
        effect.params["headWidth"] = .number(Animated(32))
        effect.params["headColor"] = .color(Animated(RGBA(1, 0, 0)))
        effect.params["tailColor"] = effect.params["headColor"]
        layer.effects = [effect]
        project.layers = [layer]
        let render = { (p: Project) in renderer.renderPixels(project: p, time: 1, mediaURL: { URL(fileURLWithPath: $0) }) }
        let moving = try XCTUnwrap(render(project)).rgba
        func red(_ x: Int, _ y: Int) -> UInt8 { moving[(y * 200 + x) * 4] }
        XCTAssertGreaterThan(red(100, 50), 60)
        XCTAssertGreaterThan(red(150, 58), 100)
        XCTAssertLessThan(red(40, 58), 10)
        XCTAssertLessThan(red(192, 50), 10)

        project.layers[0].effects[0].params["middleEnabled"] = .toggle(true)
        project.layers[0].effects[0].params["middleColor"] = .color(Animated(RGBA(0, 1, 0)))
        project.layers[0].effects[0].params["middlePosition"] = .number(Animated(25))
        let gradient = try XCTUnwrap(render(project)).rgba
        let stop = (50 * 200 + 139) * 4
        XCTAssertGreaterThan(gradient[stop + 1], 130)
        XCTAssertLessThan(gradient[stop], 20)

        project.layers[0].effects[0].params["fadeCurve"] = .number(Animated(5))
        let slowFade = try XCTUnwrap(render(project)).rgba
        XCTAssertGreaterThan(slowFade[stop + 1], gradient[stop + 1])
        project.layers[0].effects[0].params["edgeSoftness"] = .number(Animated(100))
        let softened = try XCTUnwrap(render(project)).rgba
        let edge = (58 * 200 + 139) * 4 + 1
        XCTAssertLessThan(softened[edge], slowFade[edge])

        project.layers[0].transform.position = Animated(Vec2(180, 50))
        let still = try XCTUnwrap(render(project)).rgba
        project.layers[0].effects[0].isEnabled = false
        XCTAssertEqual(still, try XCTUnwrap(render(project)).rgba)
    }

    func testProjectedOverlayClipsOversizedDashedPathsAndKeepsBreaks() {
        let size = CGSize(width: 100, height: 80)
        let a = CGPoint(x: -1e12, y: 30), b = CGPoint(x: 1e12, y: 30)
        let clipped = ViewportStroke.path([a, b], in: size).boundingRect
        XCTAssertEqual(clipped.minX, -4, accuracy: 0.01)
        XCTAssertEqual(clipped.maxX, 104, accuracy: 0.01)
        XCTAssertTrue(ViewportStroke.path([a, nil, b], in: size).isEmpty)
    }
}
