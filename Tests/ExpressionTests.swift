import XCTest
@testable import AWIeffect

final class ExpressionTests: XCTestCase {
    private func scope(_ t: Double) -> ExpressionScope {
        ExpressionScope(time: t, fps: 30, compWidth: 1080, compHeight: 1920, compDuration: 10,
                        layerIndex: 1, layerName: "L", inPoint: 0, outPoint: 10, seed: 42)
    }

    private func eval<V: ExpressionValue>(_ a: Animated<V>, _ expr: String, _ t: Double) -> V? {
        var p = a
        p.expression = expr
        return ExpressionEngine.shared.evaluate(p, scope: scope(t), key: "test")
    }

    func testBasicMathAndTime() {
        XCTAssertEqual(eval(Animated(0.0), "time * 180", 0.5), 90)
        XCTAssertEqual(eval(Animated(5.0), "value + 1", 0), 6)
        XCTAssertEqual(eval(Animated(Vec2(10, 20)), "[value[0] * 2, value[1]]", 0), Vec2(20, 20))
    }

    func testMultiStatementReturnsLastValue() {
        XCTAssertEqual(eval(Animated(0.0), "var a = 3;\nvar b = 4;\nMath.sqrt(a*a + b*b)", 0), 5)
    }

    func testWiggleIsDeterministicBoundedAndMoves() throws {
        let base = Animated(Vec2(100, 100))
        let a = try XCTUnwrap(eval(base, "wiggle(5, 30)", 1.0))
        let b = try XCTUnwrap(eval(base, "wiggle(5, 30)", 1.0))
        let c = try XCTUnwrap(eval(base, "wiggle(5, 30)", 1.37))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertLessThanOrEqual(abs(a.x - 100), 30.0001)
        XCTAssertNotEqual(a.x - 100, a.y - 100, "x and y must wiggle independently")
    }

    func testLinearAndEase() {
        XCTAssertEqual(eval(Animated(0.0), "linear(time, 0, 2, 0, 100)", 1), 50)
        XCTAssertEqual(eval(Animated(0.0), "ease(time, 0, 2, 0, 100)", 1), 50)
        XCTAssertEqual(eval(Animated(0.0), "linear(time, 0, 2, 0, 100)", 5), 100)
        XCTAssertLessThan(eval(Animated(0.0), "ease(time, 0, 1, 0, 100)", 0.1)!, 10)
    }

    func testLoopOutCycleAndPingPong() {
        var a = Animated(0.0)
        a.insertKeyframe(Keyframe(time: 0, value: 0))
        a.insertKeyframe(Keyframe(time: 1, value: 100))
        XCTAssertEqual(eval(a, "loopOut(\"cycle\")", 1.25)!, 25, accuracy: 0.01)
        XCTAssertEqual(eval(a, "loopOut(\"pingpong\")", 1.25)!, 75, accuracy: 0.01)
        XCTAssertEqual(eval(a, "loopOut(\"offset\")", 1.5)!, 150, accuracy: 0.01)
        XCTAssertEqual(eval(a, "loopOut(\"continue\")", 2)!, 200, accuracy: 0.5)
        XCTAssertEqual(eval(a, "loopOut(\"cycle\")", 0.5)!, 50, accuracy: 0.01, "inside keyframes = unchanged")
    }

    func testValueAtTimeAndPosterize() {
        var a = Animated(0.0)
        a.insertKeyframe(Keyframe(time: 0, value: 0))
        a.insertKeyframe(Keyframe(time: 1, value: 10))
        XCTAssertEqual(eval(a, "valueAtTime(time - 0.5)", 1)!, 5, accuracy: 1e-6)
        XCTAssertEqual(eval(Animated(0.0), "posterizeTime(2); time", 0.74)!, 0.5, accuracy: 1e-9)
    }

    func testRandomIsSeededPerFrameAndInRange() {
        let a = eval(Animated(0.0), "random(30, 100)", 0.5)!
        let b = eval(Animated(0.0), "random(30, 100)", 0.5)!
        XCTAssertEqual(a, b)
        XCTAssertTrue((30...100).contains(a))
    }

    func testErrorsAreReportedNotCrashing() {
        XCTAssertNil(eval(Animated(0.0), "thisIsNotDefined + 1", 0))
        XCTAssertNotNil(ExpressionEngine.shared.error(for: "test"))
        XCTAssertNil(eval(Animated(Vec2(0, 0)), "\"hello\"", 0))
    }

    func testEverySnippetEvaluates() {
        var pos = Animated(Vec2(500, 500))
        pos.insertKeyframe(Keyframe(time: 0, value: Vec2(0, 0)))
        pos.insertKeyframe(Keyframe(time: 1, value: Vec2(100, 50)))
        var num = Animated(50.0)
        num.insertKeyframe(Keyframe(time: 0, value: 0))
        num.insertKeyframe(Keyframe(time: 1, value: 100))
        for s in ExpressionSnippet.library {
            // Snippets return either a single number or an array; at least one property type must accept it.
            let ok = eval(num, s.code, 1.4) != nil || eval(pos, s.code, 1.4) != nil
            XCTAssertTrue(ok, "Snippet \(s.title) failed: \(ExpressionEngine.shared.error(for: "test") ?? "?")")
        }
    }

    func testExpressionsDriveRendering() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device") }
        var p = Project.new(name: "e", width: 100, height: 100, fps: 30, duration: 2, background: .black)
        var l = p.makeLayer(name: "box", content: .solid, size: Vec2(20, 20))
        l.fill = Animated(.white)
        l.transform.position.expression = "[20 + time * 60, 50]"
        p.layers = [l]
        let a = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let b = try XCTUnwrap(r.renderPixels(project: p, time: 1, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertGreaterThan(a[(50 * 100 + 20) * 4], 200)
        XCTAssertGreaterThan(b[(50 * 100 + 80) * 4], 200)
        XCTAssertLessThan(b[(50 * 100 + 20) * 4], 30)
    }
}
