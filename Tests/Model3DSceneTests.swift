import XCTest
import simd
@testable import AWIeffect

final class Model3DSceneTests: XCTestCase {
    private func scene(rotationY: Double = 0, cameraX: Double? = nil) -> Project {
        var p = Project.new(name: "m", width: 240, height: 240, fps: 30, duration: 1, background: .black)
        var l = p.makeLayer(name: "bar", content: .model, size: Vec2(160, 160))
        var o = Model3DOptions()
        o.text = "I"; o.extrusion = 120; o.chamfer = 0; o.yaw = Animated(0); o.pitch = Animated(0); o.color = Animated(RGBA(1, 1, 1))
        l.model3D = o; l.is3D = true
        l.transform.position = Animated(Vec2(120, 120))
        l.transform.rotationY = Animated(rotationY)
        p.layers = [l]
        if let cameraX {
            var cam = p.makeLayer(name: "cam", content: .camera, size: Vec2(240, 240))
            cam.camera = CameraOptions(); cam.camera?.zoom = Animated(330)
            cam.transform.position = Animated(Vec2(cameraX, 120))
            cam.transform.positionZ = Animated(-330)
            p.layers.insert(cam, at: 0)
        }
        return p
    }

    private func litColumns(_ p: Project) throws -> (count: Int, pixels: [UInt8]) {
        guard let r = Renderer.shared, ModelRenderer.shared != nil else { throw XCTSkip("SKIP-GPU") }
        let px = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        var columns = 0
        for x in 0..<240 where (0..<240).contains(where: { px[($0 * 240 + x) * 4] > 30 }) { columns += 1 }
        return (columns, px)
    }

    /// A flat picture turned 90° is a line. A real object shows its side, which is deep here.
    func testTurningAModelShowsItsSideInsteadOfALine() throws {
        let front = try litColumns(scene()).count
        XCTAssertGreaterThan(front, 0, "the model must render")
        let side = try litColumns(scene(rotationY: 90)).count
        XCTAssertGreaterThan(side, 20, "edge-on, a flat plane would be only a few pixels wide")
    }

    func testCameraMoveSeesTheModelFromAnotherAngle() throws {
        let center = try litColumns(scene(cameraX: 120))
        XCTAssertGreaterThan(center.count, 0, "the model must render")
        let moved = try litColumns(scene(cameraX: 220))
        XCTAssertNotEqual(center.pixels, moved.pixels)
        XCTAssertGreaterThan(moved.count, 0, "the model stays in view")
    }

    /// The model must land where a flat 3D layer's plane would, so the two line up in a scene.
    func testPlacementMatchesTheFlatLayerProjection() {
        var p = scene(rotationY: 25)
        p.layers[0].transform.positionZ = Animated(80)
        p.layers[0].transform.rotationX = Animated(-15)
        let l = p.layers[0], camera = CameraState.defaultCamera(for: p)
        let placement = Renderer.modelPlacement(l, project: p, camera: camera, time: 0)
        // Model point (0.5, 0.25, 0) is layer-local (40, -20) at fit 80: model y is up, layer y is down.
        let q = placement.modelToCamera * SIMD4<Float>(0.5, 0.25, 0, 1)
        let scale = Float(camera.zoom)
        let x = q.x / -q.z * scale + 120, y = -q.y / -q.z * scale + 120
        let h = Renderer.layerHomography(l, camera: camera, time: 0, renderScale: 1) * SIMD3(40.0, -20.0, 1)
        XCTAssertEqual(Double(x), h.x / h.z, accuracy: 0.5)
        XCTAssertEqual(Double(y), h.y / h.z, accuracy: 0.5)
    }

    func testFlatLayersAndTwoDModelsKeepTheirOldPath() throws {
        var p = scene()
        p.layers[0].is3D = false
        let flat = try litColumns(p)
        XCTAssertGreaterThan(flat.count, 0, "the model must render")
        XCTAssertGreaterThan(flat.count, 3)
    }

    func testLensPresetsMatchRealFocalLengths() {
        XCTAssertEqual(EditorState.zoom(forFocalLength: 50, compWidth: 1920), 2666.67, accuracy: 0.01)
        XCTAssertEqual(EditorState.focalLength(zoom: EditorState.zoom(forFocalLength: 85, compWidth: 1080), compWidth: 1080), 85, accuracy: 1e-9)
    }

    @MainActor func testFocusOnALayerSetsItsDistance() throws {
        var p = scene()
        var cam = p.makeLayer(name: "cam", content: .camera, size: Vec2(240, 240))
        cam.camera = CameraOptions(); cam.camera?.zoom = Animated(330)
        cam.transform.position = Animated(Vec2(120, 120)); cam.transform.positionZ = Animated(-330)
        p.layers.insert(cam, at: 0)
        p.layers[1].transform.positionZ = Animated(170)
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.selectedLayerID = cam.id
        s.focusCamera(on: p.layers[1].id)
        XCTAssertEqual(try XCTUnwrap(s.project.layers[0].camera).focusDistance.value(at: 0), 500, accuracy: 1)
        XCTAssertTrue(s.project.layers[0].camera?.depthOfField == true)
    }

    func testImportedMaterialsStayUnlessOverridden() {
        var o = Model3DOptions()
        XCTAssertNil(o.overrideMaterial)
        o.overrideMaterial = true; o.emission = 0.5
        let data = try? JSONEncoder().encode(o)
        let back = data.flatMap { try? JSONDecoder().decode(Model3DOptions.self, from: $0) }
        XCTAssertEqual(back?.overrideMaterial, true); XCTAssertEqual(back?.emission, 0.5)
        let plain = (try? JSONEncoder().encode(Model3DOptions())).flatMap { try? JSONDecoder().decode(Model3DOptions.self, from: $0) }
        XCTAssertNil(plain?.emission); XCTAssertNil(plain?.overrideMaterial)
    }
}
