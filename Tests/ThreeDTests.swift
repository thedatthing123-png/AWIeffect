import XCTest
import simd
@testable import AWIeffect

final class ThreeDTests: XCTestCase {
    private func project() -> Project {
        var p = Project.new(name: "3d", width: 200, height: 200, fps: 30, duration: 2, background: .black)
        var l = p.makeLayer(name: "plane", content: .solid, size: Vec2(60, 60))
        l.fill = Animated(.white)
        l.is3D = true
        p.layers = [l]
        return p
    }

    private func render(_ p: Project) throws -> [UInt8] {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device") }
        return try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    private func litWidth(_ px: [UInt8], row: Int = 100) -> Int {
        (0..<200).filter { px[(row * 200 + $0) * 4] > 128 }.count
    }

    func testDefaultCameraShowsZZeroAtFullSize() throws {
        // A 3D layer at z = 0 must look exactly like the 2D layer (AE default camera).
        let p = project()
        let w3 = litWidth(try render(p))
        var flat = p; flat.layers[0].is3D = false
        XCTAssertEqual(w3, litWidth(try render(flat)), accuracy: 2)
    }

    func testPushingBackMakesItSmaller() throws {
        var p = project()
        let near = litWidth(try render(p))
        p.layers[0].transform.positionZ = Animated(400)
        XCTAssertLessThan(litWidth(try render(p)), near - 5)
    }

    func testYRotationForeshortens() throws {
        var p = project()
        let flat = litWidth(try render(p))
        p.layers[0].transform.rotationY = Animated(60)
        let turned = litWidth(try render(p))
        XCTAssertEqual(Double(turned), Double(flat) * 0.5, accuracy: 6, "60° turn should roughly halve the width")
    }

    func testBehindCameraIsCulled() throws {
        var p = project()
        p.layers[0].transform.positionZ = Animated(-CameraState.defaultZoom(p) - 50)
        XCTAssertEqual(litWidth(try render(p)), 0)
    }

    func testDepthSortDrawsNearestOnTop() throws {
        var p = project()
        var far = p.layers[0]; far.id = UUID(); far.fill = Animated(RGBA(1, 0, 0)); far.transform.positionZ = Animated(200)
        var near = p.layers[0]; near.id = UUID(); near.fill = Animated(RGBA(0, 1, 0)); near.transform.positionZ = Animated(-100)
        // Stack order says red on top, but red is farther: green must win.
        p.layers = [far, near]
        let px = try render(p)
        let c = (100 * 200 + 100) * 4
        XCTAssertGreaterThan(px[c + 1], 200); XCTAssertLessThan(px[c], 60)
    }

    func testCameraLayerMoves() throws {
        var p = project()
        let base = try render(p)
        var cam = p.makeLayer(name: "cam", content: .camera, size: Vec2(1, 1))
        cam.camera = CameraOptions(zoom: Animated(CameraState.defaultZoom(p)))
        cam.transform.positionZ = Animated(-CameraState.defaultZoom(p))
        cam.transform.position = Animated(Vec2(140, 100))   // pan right -> layer appears left
        p.layers.insert(cam, at: 0)
        let moved = try render(p)
        func leftEdge(_ b: [UInt8]) -> Int {
            for x in 0..<200 where b[(100 * 200 + x) * 4] > 128 { return x }
            return 999
        }
        XCTAssertLessThan(leftEdge(moved), leftEdge(base) - 20)
    }

    func testDepthOfFieldBlursOutOfFocus() throws {
        var p = project()
        var cam = p.makeLayer(name: "cam", content: .camera, size: Vec2(1, 1))
        let zoom = CameraState.defaultZoom(p)
        cam.camera = CameraOptions(zoom: Animated(zoom), depthOfField: true, focusDistance: Animated(zoom), aperture: Animated(200))
        cam.transform.positionZ = Animated(-zoom)
        p.layers.insert(cam, at: 0)
        let sharp = try render(p)
        p.layers[1].transform.positionZ = Animated(600)   // out of focus
        let blurred = try render(p)
        // A blurred edge has more partially-lit pixels.
        let partial = { (b: [UInt8]) in (0..<200).filter { (20...230).contains(b[(100 * 200 + $0) * 4]) }.count }
        XCTAssertGreaterThan(partial(blurred), partial(sharp) + 4)
    }

    func testOldTransformDecodesWithout3DFields() throws {
        let t = LayerTransform(position: Animated(Vec2(1, 2)))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(t)) as! [String: Any]
        json.removeValue(forKey: "positionZ"); json.removeValue(forKey: "rotationX")
        let back = try JSONDecoder().decode(LayerTransform.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.positionZ.staticValue, 0)
    }
}
