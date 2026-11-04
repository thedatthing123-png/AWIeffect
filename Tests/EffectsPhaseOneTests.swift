import XCTest
import simd
@testable import AWIeffect

final class EffectsPhaseOneTests: XCTestCase {
    private func scene(_ effect: EffectInstance?, color: RGBA = .black) -> Project {
        var p = Project.new(name: "effect reference", width: 128, height: 96, fps: 30, duration: 3, background: RGBA(0, 0, 0, 0))
        var l = p.makeLayer(name: "card", content: .solid, size: Vec2(128, 96))
        l.fill = Animated(color); l.effects = effect.map { [$0] } ?? []; p.layers = [l]; return p
    }
    private func pixels(_ project: Project, time: Double = 0.4) throws -> [UInt8] {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        return try XCTUnwrap(r.renderPixels(project: project, time: time, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }
    private func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(a.count)
    }
    func testLitRippleAddsWhiteBandsWithoutNeedingImageDetail() throws {
        let e = EffectRegistry.litRipple23.makeInstance()
        let plain = try pixels(scene(nil)), lit = try pixels(scene(e))
        XCTAssertGreaterThan(difference(plain, lit), 3)
        let reds = stride(from: 0, to: lit.count, by: 4).map { lit[$0] }
        XCTAssertGreaterThan(Int(reds.max()!) - Int(reds.min()!), 30, "white rings must vary in brightness on a black solid")
        XCTAssertGreaterThan(difference(lit, try pixels(scene(e), time: 1.3)), 1)
        var off = e; off.params["light"] = .number(Animated(0)); off.params["strength"] = .number(Animated(0))
        XCTAssertLessThan(difference(plain, try pixels(scene(off))), 0.01)
        var mixed = e; mixed.params["mix"] = .number(Animated(0))
        XCTAssertLessThan(difference(plain, try pixels(scene(mixed))), 0.01)
    }
    func testLitRipplePreservesTransparentPixelsAndTintWorks() throws {
        var e = EffectRegistry.litRipple23.makeInstance()
        e.params["strength"] = .number(Animated(0))
        let empty = try pixels(scene(e, color: RGBA(0, 0, 0, 0)))
        XCTAssertTrue(empty.allSatisfy { $0 == 0 })
        let white = try pixels(scene(e)); e.params["tint"] = .color(Animated(RGBA(1, 0, 0)))
        let red = try pixels(scene(e))
        XCTAssertGreaterThan(difference(white, red), 2)
        XCTAssertTrue(stride(from: 1, to: red.count, by: 4).allSatisfy { red[$0] == 0 })
    }
    func testTimeSliceMaskReverseComplementsCoverageAndChangesOverTime() throws {
        var e = EffectRegistry.timeSliceMask23.makeInstance()
        e.params["output"] = .choice(1)
        let a = try pixels(scene(e))
        e.params["reverse"] = .toggle(true)
        let b = try pixels(scene(e))
        for i in stride(from: 3, to: a.count, by: 4) { XCTAssertEqual(Int(a[i]) + Int(b[i]), 255, accuracy: 2) }
        XCTAssertGreaterThan(difference(a, try pixels(scene(e), time: 0.8)), 5)
        e.params["smoothness"] = .number(Animated(0)); e.params["feather"] = .number(Animated(0))
        let hard = try pixels(scene(e))
        XCTAssertTrue(stride(from: 3, to: hard.count, by: 4).allSatisfy { hard[$0] == 0 || hard[$0] == 255 })
    }
    func testDrawProgressUsesLengthAcrossUnequalSegmentsAndCrossedEndsAreEmpty() {
        let segments: [SIMD4<Float>] = [SIMD4(0, 0, 10, 0), SIMD4(10, 0, 100, 0)]
        var e = EffectRegistry.drawingProgress23.makeInstance(); e.params["end"] = .number(Animated(75))
        let quarter = EffectRegistry.drawingSegments(segments, effects: [e], time: 0)
        XCTAssertEqual(quarter.count, 2); XCTAssertEqual(quarter.last!.z, 25, accuracy: 0.001)
        e.params["start"] = .number(Animated(50))
        XCTAssertTrue(EffectRegistry.drawingSegments(segments, effects: [e], time: 0).isEmpty)
        e.isEnabled = false
        XCTAssertEqual(EffectRegistry.drawingSegments(segments, effects: [e], time: 0), segments)
    }
    func testDrawProgressKeyframesRenderStrokeRevealAndRoundTrip() throws {
        var p = scene(nil)
        p.layers[0].content = .shape(.path); p.layers[0].fill = Animated(RGBA(0, 0, 0, 0))
        p.layers[0].path = Animated(BezierPath(vertices: [PathVertex(point: Vec2(-50, 0)), PathVertex(point: Vec2(50, 0))], closed: false))
        p.layers[0].stroke.enabled = true; p.layers[0].stroke.width = Animated(6); p.layers[0].stroke.color = Animated(.white)
        var e = EffectRegistry.drawingProgress23.makeInstance()
        var end = Animated(100.0); end.insertKeyframe(Keyframe(time: 0, value: 100)); end.insertKeyframe(Keyframe(time: 1, value: 0))
        e.params["end"] = .number(end); p.layers[0].effects = [e]
        let empty = try pixels(p, time: 0), halfway = try pixels(p, time: 0.5), full = try pixels(p, time: 1)
        func coverage(_ px: [UInt8]) -> Int { stride(from: 3, to: px.count, by: 4).filter { px[$0] > 128 }.count }
        XCTAssertEqual(coverage(empty), 0); XCTAssertGreaterThan(coverage(halfway), 200)
        XCTAssertEqual(Double(coverage(halfway)) / Double(coverage(full)), 0.5, accuracy: 0.08)
        let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(try pixels(decoded, time: 0.5), halfway)
    }
    func testHalftonePrintHasSolidEndpointsAndMixIdentity() throws {
        var e = EffectRegistry.halftone.makeInstance()
        for color in [RGBA.black, .white] {
            XCTAssertLessThan(difference(try pixels(scene(e, color: color)), try pixels(scene(nil, color: color))), 0.1)
        }
        let gray = RGBA(0.45, 0.45, 0.45)
        let print = try pixels(scene(e, color: gray))
        XCTAssertGreaterThan(difference(print, try pixels(scene(nil, color: gray))), 10)
        e.params["mix"] = .number(Animated(0))
        XCTAssertLessThan(difference(try pixels(scene(e, color: gray)), try pixels(scene(nil, color: gray))), 0.01)
        e.params["mix"] = .number(Animated(100)); e.params["version"] = nil
        let missing = try pixels(scene(e, color: gray)); e.params["version"] = .choice(0)
        XCTAssertEqual(try pixels(scene(e, color: gray)), missing)
        XCTAssertNotEqual(missing, print)
        XCTAssertNil(EffectRegistry.definition(aeMatchName: "CC Ball Action"), "2D print dots are not 3D Ball Action")
    }
}
