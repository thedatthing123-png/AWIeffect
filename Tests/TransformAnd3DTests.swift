import XCTest
import simd
@testable import AWIeffect

@MainActor
final class TransformAnd3DTests: XCTestCase {
    private func state(_ content: LayerContent = .shape(.rectangle)) -> EditorState {
        var p = Project.new(name: "t", width: 200, height: 200, fps: 30, duration: 2, background: .black)
        var l = p.makeLayer(name: "box", content: content, size: Vec2(80, 40))
        l.fill = Animated(.white)
        p.layers = [l]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.select(l.id)
        return s
    }
    private let fit = CGRect(x: 0, y: 0, width: 200, height: 200)

    func testEdgeHandleStretchesOneAxis() throws {
        let s = state()
        let h = CanvasHandles.handles(s.selectedLayer!, project: s.project, time: 0, fit: fit)
        let right = h.edges[1]
        let d = try XCTUnwrap(s.beginCanvasDrag(at: right, comp: Vec2(right.x, right.y), fit: fit))
        s.updateCanvasDrag(d, comp: Vec2(right.x + 40, right.y))
        s.endCanvasDrag()
        let sc = s.selectedLayer!.transform.scale.value(at: 0)
        XCTAssertEqual(sc.x, 200, accuracy: 1)
        XCTAssertEqual(sc.y, 100, accuracy: 0.01, "edge stretch must not touch height")
    }

    func testLinkedVsStretchScaleTool() throws {
        let s = state()
        s.transformTool = .scale
        s.scaleLinked = true
        var d = try XCTUnwrap(s.beginCanvasDrag(at: CGPoint(x: 175, y: 100), comp: Vec2(175, 100), fit: fit))
        s.updateCanvasDrag(d, comp: Vec2(190, 100)); s.endCanvasDrag()
        var sc = s.selectedLayer!.transform.scale.value(at: 0)
        XCTAssertEqual(sc.x, sc.y, accuracy: 0.01, "linked scale stays uniform")
        XCTAssertGreaterThan(sc.x, 110)
        s.scaleLinked = false
        d = try XCTUnwrap(s.beginCanvasDrag(at: CGPoint(x: 170, y: 100), comp: Vec2(170, 100), fit: fit))
        s.updateCanvasDrag(d, comp: Vec2(170, 100)); s.updateCanvasDrag(d, comp: Vec2(185, 100)); s.endCanvasDrag()
        let before = sc
        sc = s.selectedLayer!.transform.scale.value(at: 0)
        XCTAssertGreaterThan(sc.x, before.x)
        XCTAssertEqual(sc.y, before.y, accuracy: 0.01, "stretch along x keeps y")
    }

    func testPivotMoveKeepsLayerInPlace() throws {
        let s = state()
        s.mutateLayer { $0.transform.rotation.set(30, at: 0) }
        let l0 = s.selectedLayer!
        let corner0 = Renderer.layerMatrix(l0, time: 0, renderScale: 1, includeEffects: false) * SIMD3(40, 20, 1)
        s.transformTool = .pivot
        let d = try XCTUnwrap(s.beginCanvasDrag(at: CGPoint(x: 100, y: 100), comp: Vec2(100, 100), fit: fit))
        s.updateCanvasDrag(d, comp: Vec2(120, 95)); s.endCanvasDrag()
        let l1 = s.selectedLayer!
        XCTAssertNotEqual(l1.transform.anchor.value(at: 0), l0.transform.anchor.value(at: 0), "anchor should move")
        let corner1 = Renderer.layerMatrix(l1, time: 0, renderScale: 1, includeEffects: false) * SIMD3(40, 20, 1)
        XCTAssertEqual(corner1.x, corner0.x, accuracy: 1.5)
        XCTAssertEqual(corner1.y, corner0.y, accuracy: 1.5)
    }

    func testRotateToolTurnsLayer() throws {
        let s = state()
        s.transformTool = .rotate
        let d = try XCTUnwrap(s.beginCanvasDrag(at: CGPoint(x: 150, y: 100), comp: Vec2(150, 100), fit: fit))
        s.updateCanvasDrag(d, comp: Vec2(100, 150)); s.endCanvasDrag()
        XCTAssertEqual(s.selectedLayer!.transform.rotation.value(at: 0), 90, accuracy: 0.5)
    }

    func testStarOutlineHasAllPoints() {
        var p = Project.new(name: "t", width: 100, height: 100, fps: 30)
        var l = p.makeLayer(name: "s", content: .shape(.star), size: Vec2(80, 80))
        l.sides = Animated(5)
        let o = Extrude3D.outline(l, time: 0)
        XCTAssertEqual(o?.vertices.count, 10)
        _ = p
    }

    func testAlphaOutlineTracesCircle() throws {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = false; return f }())
        let img = r.image { c in UIColor.white.setFill(); c.cgContext.fillEllipse(in: CGRect(x: 20, y: 30, width: 60, height: 40)) }
        let out = try XCTUnwrap(Extrude3D.alphaOutline(img.cgImage!))
        XCTAssertEqual(out.crop.width, 60, accuracy: 3)
        XCTAssertEqual(out.crop.height, 40, accuracy: 3)
        XCTAssertEqual(out.path.bounds.width, 60, accuracy: 4)
        XCTAssertFalse(out.path.contains(CGPoint(x: 29, y: 19)), "corner outside the ellipse")
        XCTAssertTrue(out.path.contains(.zero))
    }

    private func coverage(_ px: [UInt8]) -> Int { stride(from: 0, to: px.count, by: 4).filter { px[$0] > 20 || px[$0 + 1] > 20 || px[$0 + 2] > 20 }.count }

    func testShapeBecomesReal3DObject() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let s = state(.shape(.star))
        s.mutateLayer { $0.size = Animated(Vec2(120, 120)) }
        s.makeSelected3DObject()
        let l = try XCTUnwrap(s.selectedLayer)
        XCTAssertEqual(l.content, .model)
        XCTAssertNotNil(l.model3D?.shapePath)
        let px = try XCTUnwrap(r.renderPixels(project: s.project, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertGreaterThan(coverage(px), 1500, "extruded star didn't render")
    }

    func testExtrudeThickensTurned3DLayer() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let s = state(.solid)
        s.mutate("3d") { p in
            p.layers[0].is3D = true
            p.layers[0].transform.rotationY = Animated(70)
        }
        let flat = coverage(try XCTUnwrap(r.renderPixels(project: s.project, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba)
        s.mutate("ex") { $0.layers[0].extrude = Animated(80) }
        let thick = coverage(try XCTUnwrap(r.renderPixels(project: s.project, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba)
        XCTAssertGreaterThan(thick, flat + 500, "extrusion should add visible side walls (\(flat) -> \(thick))")
    }

    func testExtrudeDecodesFromOldProjects() throws {
        var p = Project.new(name: "o", width: 10, height: 10, fps: 30)
        p.layers = [p.makeLayer(name: "a", content: .solid, size: Vec2(5, 5))]
        let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.layers[0].extrude.staticValue, 0)
    }
}
