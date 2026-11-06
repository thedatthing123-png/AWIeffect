import XCTest
import simd
@testable import AWIeffect

@MainActor final class OrbitViewportTests: XCTestCase {
    private let fit = CGRect(x: 0, y: 0, width: 300, height: 300)

    private func editor() -> EditorState {
        var p = Project.new(name: "orbit", width: 300, height: 300, fps: 30, duration: 2, background: RGBA(0, 0, 0, 1))
        var near = p.makeLayer(name: "near", content: .solid, size: Vec2(120, 120))
        near.transform.position = Animated(Vec2(150, 150)); near.transform.positionZ = Animated(-200)
        var far = p.makeLayer(name: "far", content: .solid, size: Vec2(200, 200))
        far.transform.position = Animated(Vec2(150, 150)); far.transform.positionZ = Animated(300)
        var side = p.makeLayer(name: "side", content: .solid, size: Vec2(40, 40))
        side.transform.position = Animated(Vec2(40, 40))
        p.layers = [far, near, side]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.orbit = OrbitCamera(yaw: 0, pitch: 0, distance: 1.6, pan: .zero)
        return s
    }

    func testTapPicksTheFrontMostLayerAndEmptySpaceClears() throws {
        let s = editor()
        let projector = OrbitProjector(project: s.project, orbit: s.orbit, time: 0, fit: fit)
        let center = try XCTUnwrap(projector.point(SIMD3(150, 150, 0)))
        s.orbitSelect(at: center, fit: fit)
        XCTAssertEqual(s.selectedLayer?.name, "near", "both cover the middle; the nearer one wins")
        let corner = try XCTUnwrap(projector.point(SIMD3(40, 40, 0)))
        s.orbitSelect(at: corner, fit: fit)
        XCTAssertEqual(s.selectedLayer?.name, "side")
        s.orbitSelect(at: CGPoint(x: 299, y: 1), fit: fit)
        XCTAssertNil(s.selectedLayerID)
    }

    func testMoveHandleChangesOnlyItsAxisAndDepthMakesTheLayer3D() throws {
        let s = editor()
        s.selectedLayerID = s.project.layers[2].id
        let start = try XCTUnwrap(s.selectedLayer)
        XCTAssertFalse(start.is3D)
        s.applyGizmo(.move, axis: 0, amount: 25, from: start)
        XCTAssertEqual(s.selectedLayer?.transform.position.value(at: 0), Vec2(65, 40))
        s.applyGizmo(.move, axis: 2, amount: 120, from: try XCTUnwrap(s.selectedLayer))
        XCTAssertEqual(s.selectedLayer?.transform.positionZ.value(at: 0), 120)
        XCTAssertEqual(s.selectedLayer?.transform.position.value(at: 0), Vec2(65, 40))
        XCTAssertTrue(s.selectedLayer?.is3D == true)
    }

    func testRotateAndScaleHandles() throws {
        let s = editor()
        s.selectedLayerID = s.project.layers[1].id
        let start = try XCTUnwrap(s.selectedLayer)
        s.applyGizmo(.rotate, axis: 1, amount: 30, from: start)
        XCTAssertEqual(s.selectedLayer?.transform.rotationY.value(at: 0), 30)
        s.applyGizmo(.scale, axis: 0, amount: 0.5, from: start)
        XCTAssertEqual(s.selectedLayer?.transform.scale.value(at: 0), Vec2(150, 150))
    }

    func testAnimatedPropertyGetsAKeyAtThePlayhead() throws {
        let s = editor()
        s.selectedLayerID = s.project.layers[2].id
        s.mutateLayer { l in
            l.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(40, 40)))
            l.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(100, 40)))
        }
        s.seek(0.5)
        let start = try XCTUnwrap(s.selectedLayer)
        s.applyGizmo(.move, axis: 1, amount: 10, from: start)
        let keys = try XCTUnwrap(s.selectedLayer).transform.position.keyframeTimes
        XCTAssertEqual(keys, [0, 0.5, 1])
    }

    func testFrameSelectedCentersTheViewOnTheLayer() {
        let s = editor()
        s.selectedLayerID = s.project.layers[2].id
        s.frameSelectedInOrbit()
        XCTAssertEqual(s.orbit.pan, Vec2(40 - 150, 40 - 150))
        s.selectedLayerID = nil
        s.frameSelectedInOrbit()
        XCTAssertEqual(s.orbit, .home)
    }
}
