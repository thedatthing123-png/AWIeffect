import XCTest
@testable import AWIeffect

final class GraphRemakeTests: XCTestCase {
    private func animation(_ kind: EaseCurve.Kind, cycles: Double = 3, smoothness: Double = 1) -> Animated<Double> {
        var c = EaseCurve(kind); c.a = cycles; c.b = smoothness
        var a = Animated(10.0)
        a.insertKeyframe(Keyframe(time: 0, value: 10, interpolation: .bezier))
        a.insertKeyframe(Keyframe(time: 3, value: 0))
        a.keyframes[0].curve = c
        return a
    }
    func testRepeatResetsAndBackForthReturnsWithoutJumping() {
        let repeatA = animation(.cycleRepeat)
        XCTAssertEqual(repeatA.value(at: 0), 10)
        XCTAssertEqual(repeatA.value(at: 1 - 1e-6), 0, accuracy: 0.00001)
        XCTAssertEqual(repeatA.value(at: 1), 10, accuracy: 0.00001)
        XCTAssertEqual(repeatA.value(at: 3), 0)
        let back = animation(.cyclePingPong, cycles: 2)
        XCTAssertEqual(back.value(at: 1), 0, accuracy: 0.00001)
        XCTAssertEqual(back.value(at: 2), 10, accuracy: 0.00001)
        XCTAssertEqual(back.value(at: 3), 0)
        XCTAssertEqual(back.value(at: 1 - 1e-5), back.value(at: 1 + 1e-5), accuracy: 1e-7)
    }
    func testSmoothnessChangesTurnVelocityAndFrequencyChangesPasses() {
        let smooth = animation(.cyclePingPong, cycles: 2)
        let sharp = animation(.cyclePingPong, cycles: 2, smoothness: 0)
        let dt = 0.0001
        XCTAssertLessThan(abs((smooth.value(at: 1) - smooth.value(at: 1-dt))/dt), 0.01)
        XCTAssertGreaterThan(abs((sharp.value(at: 1) - sharp.value(at: 1-dt))/dt), 9)
        let once = animation(.cycleRepeat, cycles: 1), triple = animation(.cycleRepeat, cycles: 3)
        XCTAssertGreaterThan(once.value(at: 1), 5)
        XCTAssertEqual(triple.value(at: 1), 10)
    }
    @MainActor func testTwoHandleEditsAreRelativeAndClamped() {
        let c = EaseCurve(.cyclePingPong)
        XCTAssertEqual(ParameterCurveEditor.translated(c, first: true, delta: 0, width: 348), c)
        let more = ParameterCurveEditor.translated(c, first: true, delta: 60, width: 348)
        XCTAssertEqual(more.a, 5); XCTAssertEqual(more.b, c.b)
        let less = ParameterCurveEditor.translated(c, first: false, delta: -150, width: 348)
        XCTAssertEqual(less.b, 0.5, accuracy: 1e-8); XCTAssertEqual(less.a, c.a)
        XCTAssertEqual(ParameterCurveEditor.translated(c, first: true, delta: 10000, width: 348).a, 12)
        let bounce = EaseCurve(.bounceOut)
        XCTAssertNotEqual(ParameterCurveEditor.translated(bounce, first: false, delta: 80, width: 348).b, bounce.b)
    }
    func testLoopsSerializeReverseAndPreviewLikeActualKeyframes() throws {
        for kind in [EaseCurve.Kind.cycleRepeat, .cyclePingPong] {
            let original = animation(kind)
            let decoded = try JSONDecoder().decode(Animated<Double>.self, from: JSONEncoder().encode(original))
            var reverse = original; reverse.reverseKeys(around: 3)
            let c = original.keyframes[0].curve!
            let preview = SavedEase(name: "loop", interpolation: .bezier, out: .easyOut, into: .easyIn, curve: c)
            for frame in 1..<180 {
                let time = Double(frame) / 60
                XCTAssertEqual(decoded.value(at: time), original.value(at: time), accuracy: 1e-8)
                // Skip exact repeat discontinuities: reversing uses the existing right-continuous key convention.
                if abs(time.rounded() - time) > 0.001 {
                    XCTAssertEqual(reverse.value(at: time), original.value(at: 3-time), accuracy: 1e-7)
                }
                XCTAssertEqual(10 - 10 * preview.progress(time/3), original.value(at: time), accuracy: 1e-7)
                XCTAssertTrue(preview.velocity(at: time/3, valueDelta: -10, duration: 3).isFinite)
            }
        }
        let legacy = try JSONDecoder().decode(EaseCurve.self, from: Data("{\"kind\":\"bounceOut\",\"a\":3,\"b\":0.45}".utf8))
        XCTAssertEqual(legacy, EaseCurve(.bounceOut))
    }
}
