import XCTest
@testable import AWIeffect

final class PhysicsModelTests: XCTestCase {
    private func body(_ x: Double, _ y: Double, r: Double = 20, isStatic: Bool = false) -> PhysicsLab.Body {
        .init(id: UUID(), p: Vec2(x, y), v: .zero, angle: 0, w: 0, r: r, invMass: isStatic ? 0 : 1 / (r * r), isStatic: isStatic)
    }

    func testFallsAndRestsOnFloor() {
        let b = body(100, 50)
        var s = PhysicsSettings(); s.duration = 4
        let out = PhysicsLab.simulate([b], width: 400, height: 400, settings: s, fps: 30)[b.id]!
        XCTAssertGreaterThan(out[10].position.y, 50, "did not fall")
        XCTAssertEqual(out.last!.position.y, 380, accuracy: 2, "should rest on the floor")
    }

    func testBounceLosesEnergy() {
        let b = body(100, 50)
        var s = PhysicsSettings(); s.bounciness = 0.6; s.duration = 3
        let ys = PhysicsLab.simulate([b], width: 400, height: 400, settings: s, fps: 60)[b.id]!.map(\.position.y)
        // Find apexes after the first floor hit: each lower than the previous (heights shrink).
        var apexes: [Double] = []
        for i in 1..<(ys.count - 1) where ys[i] < ys[i - 1] && ys[i] <= ys[i + 1] { apexes.append(ys[i]) }
        XCTAssertGreaterThanOrEqual(apexes.count, 2)
        if apexes.count >= 2 { XCTAssertGreaterThan(apexes[1], apexes[0]) }
    }

    func testBodiesCollideAndDontOverlap() {
        let a = body(100, 300), b = body(100, 100)
        var s = PhysicsSettings(); s.duration = 3
        let out = PhysicsLab.simulate([a, b], width: 400, height: 400, settings: s, fps: 30)
        let pa = out[a.id]!.last!.position, pb = out[b.id]!.last!.position
        let d = ((pa.x - pb.x) * (pa.x - pb.x) + (pa.y - pb.y) * (pa.y - pb.y)).squareRoot()
        XCTAssertGreaterThan(d, 36, "bodies overlap")
    }

    func testStaticObstacleStaysPut() {
        let ground = body(100, 300, r: 40, isStatic: true), ball = body(100, 50)
        let out = PhysicsLab.simulate([ground, ball], width: 400, height: 400, settings: PhysicsSettings(), fps: 30)
        XCTAssertEqual(out[ground.id]!.last!.position, Vec2(100, 300))
        XCTAssertLessThan(out[ball.id]!.map(\.position.y).max()!, 300, "ball passed through the obstacle")
    }

    @MainActor
    func testBakeWritesKeyframes() {
        var p = Project.new(name: "p", width: 400, height: 400, fps: 30, duration: 4)
        var l = p.makeLayer(name: "ball", content: .shape(.ellipse), size: Vec2(40, 40))
        l.transform.position = Animated(Vec2(200, 40))
        p.layers = [l]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.bakePhysics(dynamicIDs: [l.id], settings: PhysicsSettings())
        let pos = s.project.layers[0].transform.position
        XCTAssertGreaterThan(pos.keyframes.count, 30)
        XCTAssertGreaterThan(pos.value(at: 1).y, 40)
        s.undo()
        XCTAssertFalse(s.project.layers[0].transform.position.isAnimated)
    }

    func testThreeDTextRenders() throws {
        guard let r = Renderer.shared, ModelRenderer.shared != nil else { throw XCTSkip("SKIP-GPU: no Metal device") }
        var p = Project.new(name: "m", width: 200, height: 200, fps: 30, duration: 1, background: .black)
        var l = p.makeLayer(name: "t", content: .model, size: Vec2(180, 180))
        l.model3D = Model3DOptions()
        l.model3D?.color = Animated(RGBA(1, 1, 1))
        p.layers = [l]
        let px = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let lit = stride(from: 0, to: px.count, by: 4).filter { px[$0] > 40 || px[$0 + 1] > 40 || px[$0 + 2] > 40 }.count
        guard lit > 0 else { throw XCTSkip("SceneKit offscreen rendering unavailable in this simulator") }
        XCTAssertGreaterThan(lit, 500, "3D text barely visible")
    }
}
