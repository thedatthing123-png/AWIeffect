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

    func testProjectedDragTracksFingerAtDepthAndUnderRotatedParent() throws {
        var p = scene()
        p.layers[1].transform.positionZ = Animated(CameraState.defaultZoom(p))
        var parent = p.makeLayer(name: "parent", content: .solid, size: Vec2(10, 10))
        parent.transform.rotation = Animated(35); parent.transform.scale = Animated(Vec2(150, 75))
        p.layers.append(parent); p.layers[1].parentID = parent.id
        let layer = p.layers[1], matrix = LayerPlacement.positionMatrix(layer, project: p, time: 0)
        let before = try XCTUnwrap(LayerPlacement.projected(layer.transform.position.value(at: 0), by: matrix))
        let moved = try XCTUnwrap(LayerPlacement.movedPosition(layer, project: p, time: 0, screenDelta: Vec2(21, -17)))
        let after = try XCTUnwrap(LayerPlacement.projected(moved, by: matrix))
        XCTAssertEqual(after.x - before.x, 21, accuracy: 1e-6)
        XCTAssertEqual(after.y - before.y, -17, accuracy: 1e-6)
    }

    func testOrbitViewIsStableAndDoesNotMutateComposition() {
        let p = scene()
        let a = OrbitView.scene(p, orbit: .home, time: 0)
        let b = OrbitView.scene(p, orbit: .home, time: 1)
        XCTAssertEqual(a, b)
        XCTAssertFalse(p.layers[1].is3D)
        XCTAssertEqual(p.layers.first?.content, .camera)
    }
    func testSpeedTimingScalesEveryAnimationAroundClipStart() {
        var p = scene()
        var layer = p.layers[1]; layer.inPoint = 2; layer.outPoint = 6
        layer.transform.position.insertKeyframe(Keyframe(time: 3, value: Vec2(1, 2), interpolation: .linear))
        layer.transform.position.insertKeyframe(Keyframe(time: 5, value: Vec2(3, 4), interpolation: .linear))
        layer.text = TextData(string: "speed")
        layer.text!.tracking.insertKeyframe(Keyframe(time: 4, value: 12, interpolation: .linear))
        var traversal = AnimationTraversal(operation: .scaleTime(layer.inPoint, 0.5))
        layer.traverseAnimations(&traversal)
        XCTAssertEqual(layer.transform.position.keyframeTimes, [2.5, 3.5])
        XCTAssertEqual(layer.text!.tracking.keyframeTimes, [3])
        var restore = AnimationTraversal(operation: .scaleTime(layer.inPoint, 2))
        layer.traverseAnimations(&restore)
        XCTAssertEqual(layer.transform.position.keyframeTimes, [3, 5])
        XCTAssertEqual(layer.text!.tracking.keyframeTimes, [4])
    }

    func testReverseAnimationMatchesOriginalAndCanBeRestored() {
        var original = Animated(0.0)
        original.insertKeyframe(Keyframe(time: 2, value: 10, interpolation: .bezier, easeOut: EaseHandle(x: 0.2, y: 0.1)))
        original.insertKeyframe(Keyframe(time: 4, value: 80, interpolation: .hold, easeIn: EaseHandle(x: 0.7, y: 0.9)))
        original.insertKeyframe(Keyframe(time: 6, value: 30, interpolation: .linear))
        var reversed = original; reversed.reverseKeys(around: 8)
        for time in stride(from: 2.05, through: 5.95, by: 0.1) {
            XCTAssertEqual(reversed.value(at: time), original.value(at: 8 - time), accuracy: 0.001)
        }
        reversed.reverseKeys(around: 8)
        XCTAssertEqual(reversed, original)
    }

    func testSnappingUsesVisibleEdgesAndReleasesAwayFromGuide() {
        let edge = LayerPlacement.snap(features: [42, 62, 82], targets: [0, 64, 128], held: nil, grab: 3)
        XCTAssertEqual(edge.delta, 2); XCTAssertEqual(edge.guide, 64)
        let held = LayerPlacement.snap(features: [48, 68, 88], targets: [], held: 64, grab: 3)
        XCTAssertEqual(held.delta, -4); XCTAssertEqual(held.guide, 64)
        XCTAssertNil(LayerPlacement.snap(features: [55, 75, 95], targets: [], held: 64, grab: 3).guide)
    }
    @MainActor func testAlignmentUsesRotatedVisibleBoundsAndCanUndo() throws {
        var p = scene()
        p.layers[1].transform.rotation = Animated(37)
        p.layers[1].transform.anchor = Animated(Vec2(7, -4))
        p.layers[1].transform.positionZ = Animated(CameraState.defaultZoom(p))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let state = EditorState(project: p, store: ProjectStore(root: root))
        state.select(p.layers[1].id); state.alignSelected(0)
        let bounds = try XCTUnwrap(LayerPlacement.bounds(state.project.layers[1], project: state.project, time: 0))
        XCTAssertEqual(bounds.minX, 0, accuracy: 0.001)
        state.undo()
        XCTAssertEqual(state.project.layers[1].transform, p.layers[1].transform)
    }

    @MainActor func testSelectiveStyleKeepsContentAndUnselectedProperties() {
        var p = scene(), source = p.layers[1]
        source.fill = Animated(RGBA(1, 0, 0, 1)); source.transform.position = Animated(Vec2(10, 20))
        source.transform.opacity = Animated(25); source.effects = [EffectRegistry.deepGlow.makeInstance()]
        var target = p.makeLayer(name: "target", content: .text, size: Vec2(50, 60))
        target.text = TextData(string: "Keep me"); let original = target
        EditorState.applyStyle(source, to: &target, parts: [.effects, .fill])
        XCTAssertEqual(target.transform, original.transform); XCTAssertEqual(target.text?.string, original.text?.string)
        XCTAssertEqual(target.text?.fill, source.fill)
        XCTAssertEqual(target.content, original.content); XCTAssertEqual(target.size, original.size)
        XCTAssertEqual(target.fill, source.fill); XCTAssertEqual(target.effects, source.effects)
        EditorState.applyStyle(source, to: &target, parts: [.transform])
        XCTAssertEqual(target.transform.position, source.transform.position)
        XCTAssertEqual(target.transform.opacity, original.transform.opacity)
    }

    func testClipboardOwnsMediaAndRemapsDrawingAndNestedReferences() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let input = root.appendingPathComponent("source"), output = root.appendingPathComponent("target")
        try fm.createDirectory(at: input, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data([1, 2, 3]).write(to: input.appendingPathComponent("image.png"))
        try Data([4, 5, 6]).write(to: input.appendingPathComponent("paint.png"))
        let drawing = UUID()
        let doc = DrawingDoc(id: drawing, width: 2, height: 2, layers: [DrawingDoc.LayerInfo(id: UUID(), name: "paint", opacity: 1, blend: .normal, visible: true, clipping: false, alphaLock: false, file: "paint.png")])
        try JSONEncoder().encode(doc).write(to: input.appendingPathComponent("draw-\(drawing).json"))
        var p = scene(), nested = scene()
        var image = p.makeLayer(name: "image", content: .image(fileName: "image.png", pixelWidth: 2, pixelHeight: 2), size: Vec2(2, 2))
        image.drawingID = drawing
        var group = p.makeLayer(name: "group", content: .solid, size: Vec2(128, 128)); group.isGroup = true
        image.groupID = group.id; image.parentID = group.id
        nested.layers = [image]
        let compLayer = p.makeLayer(name: "nested", content: .precomp(id: nested.id), size: Vec2(128, 128))
        let payload = try LayerClipboardFiles.snapshot(layers: [group, image, compLayer], precomps: [nested], source: input)
        try fm.removeItem(at: input)
        let result = try LayerClipboardFiles.imported(payload, destination: output)
        XCTAssertNotEqual(result.layers[0].id, group.id)
        XCTAssertEqual(result.layers[1].parentID, result.layers[0].id)
        XCTAssertEqual(result.layers[1].groupID, result.layers[0].id)
        XCTAssertEqual(result.layers[2].content, .precomp(id: result.comps[0].id))
        let file = try XCTUnwrap(result.layers[1].mediaFile)
        XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent(file)), Data([1, 2, 3]))
        let newID = try XCTUnwrap(result.layers[1].drawingID); XCTAssertNotEqual(newID, drawing)
        let copiedDoc = try JSONDecoder().decode(DrawingDoc.self, from: Data(contentsOf: output.appendingPathComponent("draw-\(newID).json")))
        XCTAssertEqual(copiedDoc.id, newID)
        XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent(copiedDoc.layers[0].file)), Data([4, 5, 6]))
        let second = try LayerClipboardFiles.imported(payload, destination: output)
        XCTAssertNotEqual(result.layers[1].mediaFile, second.layers[1].mediaFile)
    }
}
