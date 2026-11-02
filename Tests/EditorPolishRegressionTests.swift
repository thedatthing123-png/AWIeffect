import XCTest
import simd
@testable import AWIeffect

final class EditorPolishRegressionTests: XCTestCase {
    private func scene() -> Project {
        var p = Project.new(name: "depth", width: 128, height: 128, fps: 30, duration: 2, background: RGBA(0, 0, 0, 0))
        var layer = p.makeLayer(name: "card", content: .solid, size: Vec2(40, 40))
        layer.fill = Animated(.white); layer.transform.position = Animated(Vec2(90, 64))
        var camera = p.makeLayer(name: "camera", content: .camera, size: Vec2(1, 1))
        let zoom = CameraState.defaultZoom(p)
        camera.transform.positionZ = Animated(-zoom)
        camera.camera = CameraOptions(zoom: Animated(zoom), focusDistance: Animated(zoom))
        camera.camera!.affects2D = true
        p.layers = [camera, layer]; return p
    }
    private func point(_ matrix: simd_double3x3, _ x: Double, _ y: Double) -> SIMD2<Double> {
        let q = matrix * SIMD3(x, y, 1); return SIMD2(q.x, q.y) / q.z
    }
    func test2DDepthChangesProjectedSizeAndCameraParallax() {
        var p = scene()
        let zoom = CameraState.defaultZoom(p)
        func matrix() -> simd_double3x3 { Renderer.placementMatrix(p.layers[1], camera: Renderer.activeCamera(p, time: 0), time: 0, renderScale: 1) }
        let near = matrix()
        p.layers[1].transform.positionZ = Animated(zoom)
        let far = matrix()
        XCTAssertEqual(simd_length(point(near, 20, 0) - point(near, -20, 0)), 40, accuracy: 0.001)
        XCTAssertEqual(simd_length(point(far, 20, 0) - point(far, -20, 0)), 20, accuracy: 0.001)
        p.layers[0].transform.position = Animated(Vec2(84, 64))
        XCTAssertEqual(point(matrix(), 0, 0).x - point(far, 0, 0).x, -10, accuracy: 0.001)
        p.layers[1].transform.positionZ = Animated(0)
        XCTAssertEqual(point(matrix(), 0, 0).x - point(near, 0, 0).x, -20, accuracy: 0.001)
    }
    func test2DCameraZActsAsDollyAnd3DOnlyCameraKeepsOverlaysFlat() {
        var p = scene(), zoom = CameraState.defaultZoom(scene())
        p.layers[0].transform.positionZ = Animated(-zoom / 2)
        let a = Renderer.placementMatrix(p.layers[1], camera: Renderer.activeCamera(p, time: 0), time: 0, renderScale: 1)
        XCTAssertEqual(simd_length(point(a, 20, 0) - point(a, -20, 0)), 80, accuracy: 0.001)
        p.layers[0].camera!.affects2D = false; p.layers[1].transform.positionZ = Animated(1000)
        let b = Renderer.placementMatrix(p.layers[1], camera: Renderer.activeCamera(p, time: 0), time: 0, renderScale: 1)
        XCTAssertEqual(simd_length(point(b, 20, 0) - point(b, -20, 0)), 40, accuracy: 0.001)
    }
    func testTrue3DProjectionKeepsExistingHomography() {
        var p = scene(); p.layers[1].is3D = true
        p.layers[1].transform.positionZ = Animated(250); p.layers[1].transform.rotationY = Animated(35)
        let camera = Renderer.activeCamera(p, time: 0)
        let actual = Renderer.placementMatrix(p.layers[1], camera: camera, time: 0, renderScale: 0.5)
        let expected = Renderer.layerHomography(p.layers[1], camera: camera, time: 0, renderScale: 0.5)
        for i in 0..<3 { XCTAssertLessThan(simd_length(actual[i] - expected[i]), 1e-9) }
    }
    func test2DPlaneBehindCameraDoesNotExplodeIntoFrame() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("Metal unavailable") }
        var p = scene(); p.layers[1].transform.positionZ = Animated(-2000)
        let pixels = try XCTUnwrap(renderer.renderPixels(project: p, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertTrue(pixels.enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 0 })
    }
    @MainActor
    func testPreviewInvalidatesWhenCameraModeChangesWithoutDateOrLayerCountChange() {
        let coordinator = MetalPreview.Coordinator()
        var p = scene(); coordinator.updateProject(p, redrawToken: 0)
        let initial = coordinator.renderRevision
        p.layers[0].camera!.affects2D = false
        coordinator.updateProject(p, redrawToken: 0)
        XCTAssertGreaterThan(coordinator.renderRevision, initial)
        let changed = coordinator.renderRevision
        coordinator.updateProject(p, redrawToken: 0); XCTAssertEqual(coordinator.renderRevision, changed)
        coordinator.updateProject(p, redrawToken: 1); XCTAssertGreaterThan(coordinator.renderRevision, changed)
    }
    func testDeepGlowDoesNotFlickerWithTimeOnStaticInput() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("Metal unavailable") }
        var p = scene(); p.layers.removeFirst()
        p.layers[0].effects = [EffectRegistry.deepGlow.makeInstance()]
        func pixels(_ t: Double) throws -> [UInt8] { try XCTUnwrap(renderer.renderPixels(project: p, time: t, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba }
        let first = try pixels(0)
        XCTAssertEqual(first, try pixels(1))
        XCTAssertEqual(first, try pixels(0))
    }
}
