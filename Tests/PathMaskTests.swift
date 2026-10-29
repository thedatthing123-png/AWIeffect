import XCTest
import simd
@testable import AWIeffect

final class PathMaskTests: XCTestCase {
    private func render(_ p: Project, t: Double = 0) throws -> [UInt8] {
        guard let r = Renderer.shared, PathGPU.shared != nil else { throw XCTSkip("SKIP-GPU: no Metal device") }
        return try XCTUnwrap(r.renderPixels(project: p, time: t, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }
    private func px(_ b: [UInt8], _ w: Int, _ x: Int, _ y: Int) -> UInt8 { b[(y * w + x) * 4] }

    private func solidProject(masks: [LayerMask]) -> Project {
        var p = Project.new(name: "m", width: 100, height: 100, fps: 30, background: .black)
        var l = p.makeLayer(name: "s", content: .solid, size: Vec2(100, 100))
        l.fill = Animated(.white)
        l.masks = masks
        p.layers = [l]
        return p
    }

    func testPathSegmentsAndBounds() {
        let e = BezierPath.ellipse(size: Vec2(100, 50))
        XCTAssertEqual(e.segments(stepsPerCurve: 8).count, 32)
        let b = e.bounds
        XCTAssertEqual(b.min.x, -50, accuracy: 0.5); XCTAssertEqual(b.max.y, 25, accuracy: 0.5)
    }

    func testPathInterpolation() {
        let a = BezierPath.rectangle(size: Vec2(10, 10)), b = BezierPath.rectangle(size: Vec2(30, 30))
        XCTAssertEqual(BezierPath.lerp(a, b, 0.5).vertices[2].point, Vec2(10, 10))
    }

    func testTrimPathsHalf() {
        let segs = BezierPath.rectangle(size: Vec2(100, 100)).segments()
        let half = PathGPU.trimmed(segs, start: 0, end: 50, offset: 0, closed: true)
        let len = half.reduce(0.0) { $0 + Double(simd_length(SIMD2($1.z - $1.x, $1.w - $1.y))) }
        XCTAssertEqual(len, 200, accuracy: 0.5)
    }

    func testAddMaskKeepsInsideOnly() throws {
        let m = LayerMask(path: Animated(.rectangle(size: Vec2(40, 40))))
        let b = try render(solidProject(masks: [m]))
        XCTAssertGreaterThan(px(b, 100, 50, 50), 240)
        XCTAssertEqual(px(b, 100, 5, 5), 0)
    }

    func testSubtractAndInvert() throws {
        var m = LayerMask(path: Animated(.rectangle(size: Vec2(40, 40))))
        m.mode = .subtract
        let sub = try render(solidProject(masks: [m]))
        XCTAssertEqual(px(sub, 100, 50, 50), 0)
        XCTAssertGreaterThan(px(sub, 100, 5, 5), 240)
        m.mode = .add; m.inverted = true
        let inv = try render(solidProject(masks: [m]))
        XCTAssertEqual(px(inv, 100, 50, 50), 0)
    }

    func testFeatherSoftensEdge() throws {
        var m = LayerMask(path: Animated(.rectangle(size: Vec2(60, 60))))
        let hard = try render(solidProject(masks: [m]))
        m.feather = Animated(30)
        let soft = try render(solidProject(masks: [m]))
        // At the old edge the feathered mask is partially transparent.
        XCTAssertGreaterThan(px(hard, 100, 50, 22), 240)
        XCTAssertLessThan(px(soft, 100, 50, 22), 200)
    }

    func testPathShapeFillAndStroke() throws {
        var p = Project.new(name: "s", width: 100, height: 100, fps: 30, background: .black)
        var l = p.makeLayer(name: "p", content: .shape(.path), size: Vec2(60, 60))
        l.path = Animated(.ellipse(size: Vec2(60, 60)))
        l.fill = Animated(RGBA(1, 0, 0))
        l.stroke.enabled = true
        l.stroke.color = Animated(RGBA(0, 1, 0))
        l.stroke.width = Animated(6)
        p.layers = [l]
        let b = try render(p)
        XCTAssertGreaterThan(b[(50 * 100 + 50) * 4], 240, "fill missing")          // red center
        XCTAssertGreaterThan(b[(50 * 100 + 80) * 4 + 1], 200, "stroke missing")    // green ring at r=30
        XCTAssertEqual(b[(5 * 100 + 5) * 4], 0)
    }

    func testMaskPathAnimates() throws {
        var path = Animated(BezierPath.rectangle(size: Vec2(10, 10)))
        path.insertKeyframe(Keyframe(time: 0, value: .rectangle(size: Vec2(10, 10))))
        path.insertKeyframe(Keyframe(time: 1, value: .rectangle(size: Vec2(90, 90))))
        let p = solidProject(masks: [LayerMask(path: path)])
        XCTAssertEqual(px(try render(p, t: 0), 100, 20, 50), 0)
        XCTAssertGreaterThan(px(try render(p, t: 1), 100, 20, 50), 240)
    }
}
