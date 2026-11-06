import XCTest
import Combine
import simd
@testable import AWIeffect

final class AuditRegressionTests: XCTestCase {
    private func animated(_ value: Double, at time: Double = 2) -> Animated<Double> {
        var a = Animated(value)
        a.insertKeyframe(Keyframe(time: time, value: value, interpolation: .linear))
        return a
    }

    private func project() -> Project {
        Project.new(name: "audit", width: 128, height: 128, fps: 30, duration: 8, background: .black)
    }

    func testNestedAnimationFieldsShareTimelineRetimeAndShift() throws {
        var p = project()
        var l = p.makeLayer(name: "text", content: .text, size: Vec2(40, 40))
        l.text = TextData(string: "A")
        l.text!.lineSpacing = animated(1.5)
        l.text!.pathOffset = animated(20)
        l.text!.counter = TextCounter()
        l.text!.counter!.value = animated(12)
        var animator = TextAnimator(name: "blur")
        animator.selector.frequency = animated(2)
        animator.selector.spread = animated(3)
        animator.properties.blur = animated(8)
        animator.properties.rotationX = animated(90)
        animator.properties.outline = animated(4)
        l.text!.animators = [animator]
        var mask = LayerMask(path: Animated(BezierPath.rectangle(size: Vec2(30, 30))))
        mask.opacity = animated(50); mask.expansion = animated(5); mask.feather = animated(8)
        l.masks = [mask]
        l.shapeOps = ShapeOps(); l.shapeOps!.offset = animated(4)
        l.model3D = Model3DOptions(); l.model3D!.lightAngle = animated(45)
        XCTAssertEqual(l.keyframeTimes, [2])
        l.retimeKeys(at: 2, to: 3)
        XCTAssertEqual(l.keyframeTimes, [3])
        l.shiftTiming(by: 1, duration: p.duration)
        XCTAssertEqual(l.keyframeTimes, [4])
        XCTAssertTrue(l.text!.animators[0].properties.blur!.hasKeyframe(at: 4))
        XCTAssertTrue(l.masks[0].expansion.hasKeyframe(at: 4))
        let roundTrip = try JSONDecoder().decode(Layer.self, from: JSONEncoder().encode(l))
        XCTAssertEqual(roundTrip, l)
    }

    func testClipShiftUsesActualClampedDeltaAndPreservesPreroll() {
        var p = project()
        var l = p.makeLayer(name: "clip", content: .solid, size: Vec2(10, 10))
        l.inPoint = 2; l.outPoint = 6
        l.transform.rotation = animated(45, at: 1)
        l.shiftTiming(by: -10, duration: p.duration)
        XCTAssertEqual(l.inPoint, 0); XCTAssertEqual(l.outPoint, 4)
        XCTAssertEqual(l.transform.rotation.keyframeTimes, [-1])
    }

    func testLegacyAndModernFrameBlendingCanBothBeDisabled() {
        var p = project()
        var l = p.makeLayer(name: "clip", content: .solid, size: Vec2(10, 10))
        l.frameBlending = true
        XCTAssertTrue(l.usesFrameBlending)
        l.usesFrameBlending = false
        XCTAssertFalse(l.usesFrameBlending)
        l.usesFrameBlending = true
        XCTAssertTrue(l.timeFX?.frameBlend == true)
    }

    func testDepthExpressionsAndCompositionLayerCountAreEvaluated() {
        var p = project()
        var l = p.makeLayer(name: "3d", content: .solid, size: Vec2(10, 10))
        l.transform.positionZ.expression = "thisComp.numLayers * 100"
        l.transform.rotationX.expression = "time * 90"
        l.transform.rotationY.expression = "45"
        p.layers = [l, p.makeLayer(name: "other", content: .solid, size: Vec2(10, 10))]
        let resolved = ExpressionResolver.resolve(p, time: 2)
        XCTAssertEqual(resolved.layers[0].transform.positionZ.staticValue, 200)
        XCTAssertEqual(resolved.layers[0].transform.rotationX.staticValue, 180)
        XCTAssertEqual(resolved.layers[0].transform.rotationY.staticValue, 45)
    }

    func testViewportRenderingAndInputAgreeAfterRotationAndZoom() {
        let viewport = DrawViewport(size: CGSize(width: 160, height: 90), zoom: 2.3, rotation: .pi / 3, offset: CGPoint(x: 21, y: -8))
        for point in [SIMD2(0.0, 0), SIMD2(160.0, 90), SIMD2(67.0, 22)] {
            let restored = viewport.canvas(viewport.view(point))
            XCTAssertEqual(restored.x, point.x, accuracy: 1e-8)
            XCTAssertEqual(restored.y, point.y, accuracy: 1e-8)
        }
        XCTAssertNotEqual(viewport.view(SIMD2(0, 0)).y, viewport.view(SIMD2(160, 0)).y)
    }

    func testSelectionBrushShowsLiveMaskAndCanCancel() throws {
        let e = try XCTUnwrap(DrawEngine(width: 64, height: 64))
        e.beginSelectStroke(at: SIMD2(20, 20), radius: 8, subtract: false)
        XCTAssertTrue(e.hasSelection, "Live brush mask was hidden")
        e.continueSelectStroke(to: SIMD2(40, 20))
        e.cancelSelectStroke()
        XCTAssertFalse(e.hasSelection)
    }

    func testLassoFillsPixelsWithoutChangingSelectionAndSupportsUndo() throws {
        let e = try XCTUnwrap(DrawEngine(width: 64, height: 64))
        e.fillLasso([SIMD2(5, 5), SIMD2(30, 5), SIMD2(30, 30), SIMD2(5, 30)], color: RGBA(1, 0, 0), opacity: 1)
        XCTAssertFalse(e.hasSelection)
        let px = e.bytes(of: try XCTUnwrap(e.activeLayer))
        XCTAssertGreaterThan(px[(15 * 64 + 15) * 4 + 3], 240)
        XCTAssertEqual(px[(45 * 64 + 45) * 4 + 3], 0)
        e.undo()
        XCTAssertEqual(e.bytes(of: e.activeLayer!)[(15 * 64 + 15) * 4 + 3], 0)
    }

    func testTempoTrackingRejectsSubdivisionAsIndependentBeats() {
        var flux = [Double](repeating: 0, count: 1200)
        for i in stride(from: 25, to: 1200, by: 25) { flux[i] = i % 50 == 25 ? 1 : 0.2 }
        let result = BeatDetector.track(flux: flux, hopSeconds: 0.01, bpm: 120)
        XCTAssertEqual(result.bpm ?? 0, 120, accuracy: 0.1)
        XCTAssertGreaterThan(result.times.count, 15)
        for gap in zip(result.times, result.times.dropFirst()).map({ $1 - $0 }) {
            XCTAssertEqual(gap, 0.5, accuracy: 0.03)
        }
        XCTAssertTrue(BeatDetector.track(flux: [Double](repeating: 0, count: 100), hopSeconds: 0.01).times.isEmpty)
    }

    @MainActor
    func testGroupScopeSavesMembersAndUsesRootMediaFolder() throws {
        var p = project()
        let l = p.makeLayer(name: "art", content: .image(fileName: "image.png", pixelWidth: 40, pixelHeight: 40), size: Vec2(40, 40))
        p.layers = [l]
        let store = ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let state = EditorState(project: p, store: store)
        state.select(l.id); state.groupSelected()
        let group = try XCTUnwrap(state.selectedLayerID)
        state.openGroup()
        XCTAssertEqual(state.project.background.a, 0)
        XCTAssertEqual(state.project.layers.count, 1)
        XCTAssertEqual(state.mediaURL("image.png"), store.mediaURL("image.png", projectID: p.id))
        state.mutate("inside group") { $0.layers[0].name = "edited" }
        XCTAssertEqual(state.rootProject.layers.first(where: { $0.id == l.id })?.name, "edited")
        state.closePrecomp()
        XCTAssertEqual(state.project.layers.first(where: { $0.id == l.id })?.groupID, group)
        XCTAssertEqual(state.project.id, p.id)
    }

    @MainActor
    func testTimelineParentPickKeepsOriginalChildSelected() throws {
        var p = project()
        let child = p.makeLayer(name: "child", content: .solid, size: Vec2(10, 10))
        let parent = p.makeLayer(name: "parent", content: .solid, size: Vec2(10, 10))
        p.layers = [child, parent]
        let state = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        state.select(child.id); state.beginLinkPick(); state.openLayer(parent.id)
        XCTAssertEqual(state.selectedLayerID, child.id)
        XCTAssertEqual(state.selectedLayer?.parentID, parent.id)
        XCTAssertFalse(state.linkPicking)
        state.select(parent.id)
        XCTAssertFalse(state.canParent(to: child.id))
    }
    func testArtTransformMovesOnlySelectionAndUndoRestoresItsMask() throws {
        let engine = try XCTUnwrap(DrawEngine(width: 64, height: 64))
        let layer = try XCTUnwrap(engine.activeLayer)
        var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
        for y in 10..<20 { for x in 10..<20 { pixels[(y * 64 + x) * 4] = 255; pixels[(y * 64 + x) * 4 + 3] = 255 } }
        for y in 40..<50 { for x in 40..<50 { pixels[(y * 64 + x) * 4 + 1] = 255; pixels[(y * 64 + x) * 4 + 3] = 255 } }
        engine.setBytes(pixels, of: layer)
        engine.selectShape(SIMD2(8, 8), SIMD2(22, 22), ellipse: false)
        engine.transformActive(translate: SIMD2(20, 0), scale: 1, rotation: 0, pivot: SIMD2(15, 15))
        let moved = engine.bytes(of: layer)
        XCTAssertEqual(moved[(15 * 64 + 15) * 4 + 3], 0)
        XCTAssertGreaterThan(moved[(15 * 64 + 35) * 4], 250)
        XCTAssertGreaterThan(moved[(45 * 64 + 45) * 4 + 1], 250, "Unselected pixels moved")
        engine.undo(); XCTAssertEqual(engine.bytes(of: layer), pixels)
        engine.deleteOutsideSelection()
        let cropped = engine.bytes(of: layer)
        XCTAssertGreaterThan(cropped[(15 * 64 + 15) * 4 + 3], 250)
        XCTAssertEqual(cropped[(45 * 64 + 45) * 4 + 3], 0)
    }
    func testArtSelectionUndoRedoAndClearAreIndependentOfPaint() throws {
        let engine = try XCTUnwrap(DrawEngine(width: 32, height: 32))
        engine.selectShape(SIMD2(2, 2), SIMD2(20, 20), ellipse: false)
        XCTAssertTrue(engine.hasSelection)
        engine.undo(); XCTAssertFalse(engine.hasSelection)
        engine.redo(); XCTAssertTrue(engine.hasSelection)
        engine.clearSelection(recordUndo: true); XCTAssertFalse(engine.hasSelection)
        engine.undo(); XCTAssertTrue(engine.hasSelection)
    }
    func testVersionRecoveryPreservesCorruptFileAndRapidSnapshots() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProjectStore(root: root)
        var p = project()
        try store.save(p, snapshotVersion: true)
        p.name = "latest"; try store.save(p, snapshotVersion: true)
        XCTAssertEqual(store.versions(for: p.id).count, 2)
        let json = store.folder(for: p.id).appendingPathComponent("project.json")
        try Data("broken".utf8).write(to: json)
        let recovered = try store.load(p.id)
        XCTAssertEqual(recovered.name, "latest")
        XCTAssertEqual(store.list().count, 1, "Recoverable project vanished from Home")
        let files = try FileManager.default.contentsOfDirectory(at: store.folder(for: p.id), includingPropertiesForKeys: nil)
        let backup = try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("project-corrupt-") })
        XCTAssertEqual(try Data(contentsOf: backup), Data("broken".utf8))
        try store.save(recovered)
        XCTAssertEqual(try store.load(p.id).name, "latest")
    }
    @MainActor
    func testSaveFailureIsVisibleAndRetryClearsError() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ProjectStore(root: root)
        try FileManager.default.removeItem(at: root)
        try Data("occupied".utf8).write(to: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let state = EditorState(project: project(), store: store)
        state.saveNow(); XCTAssertNotNil(state.saveError)
        try FileManager.default.removeItem(at: root)
        state.saveNow(); XCTAssertNil(state.saveError)
        XCTAssertEqual(try store.load(state.project.id).id, state.project.id)
    }

    func testCancelledArtStrokeDoesNotLeaveNavigationDot() throws {
        let engine = try XCTUnwrap(DrawEngine(width: 32, height: 32))
        let layer = try XCTUnwrap(engine.activeLayer), before = engine.bytes(of: try XCTUnwrap(engine.activeLayer))
        engine.brush.size = 8; engine.beginStroke(at: SIMD2(16, 16), pressure: 1)
        engine.cancelStroke()
        XCTAssertEqual(engine.bytes(of: layer), before)
        XCTAssertFalse(engine.canUndo)
    }

    @MainActor
    func testNestedGroupsRenderAndKeepMembersWhenEditingAndDuplicating() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("Metal unavailable") }
        var p = project()
        var layer = p.makeLayer(name: "red", content: .solid, size: Vec2(40, 40)); layer.fill = Animated(RGBA(1, 0, 0))
        p.layers = [layer]
        let state = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        state.select(layer.id); state.groupSelected()
        let inner = try XCTUnwrap(state.selectedLayerID)
        state.groupSelected()
        let outer = try XCTUnwrap(state.selectedLayerID)
        XCTAssertNotEqual(inner, outer)
        XCTAssertEqual(state.project.layers.first(where: { $0.id == inner })?.groupID, outer)
        XCTAssertEqual(state.project.layers.first(where: { $0.id == layer.id })?.groupID, inner)
        let pixels = try XCTUnwrap(renderer.renderPixels(project: state.project, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertGreaterThan(pixels[(64 * 128 + 64) * 4], 240, "Nested group content vanished")
        state.openGroup(); state.select(inner); state.openGroup()
        state.mutate("inner edit") { $0.layers[0].name = "updated" }
        XCTAssertEqual(state.rootProject.layers.first(where: { $0.id == layer.id })?.name, "updated")
        state.closePrecomp(); state.closePrecomp(); state.duplicateGroup(outer)
        XCTAssertEqual(state.project.layers.filter(\.isGroup).count, 4)
        XCTAssertEqual(state.project.layers.filter { !$0.isGroup }.count, 2)
    }

    @MainActor
    func testAutomaticSaveFailureIsVisibleWithoutExplicitSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ProjectStore(root: root)
        try FileManager.default.removeItem(at: root); try Data("occupied".utf8).write(to: root)
        defer { try? FileManager.default.removeItem(at: root) }
        // Earlier tests leave their own autosaves queued on the shared save queue; let those finish first.
        EditorState.saveQueue.sync {}
        let state = EditorState(project: project(), store: store)
        XCTAssertThrowsError(try store.save(project(), snapshotVersion: false), "the store must refuse to write here")
        let reported = expectation(description: "Automatic save reports its write failure")
        let subscription = state.$saveError.compactMap { $0 }.first().sink { _ in reported.fulfill() }
        state.mutate("edit") { $0.name = "unsaved" }
        await fulfillment(of: [reported], timeout: 30)
        XCTAssertEqual(state.project.name, "unsaved")
        withExtendedLifetime(subscription) {}
        XCTAssertNotNil(state.saveError)
    }

    func testBeatAnalysisFindsPulsesInActualAudioWaveform() {
        let rate = 22050.0
        var audio = [Float](repeating: 0, count: Int(rate * 8))
        for beat in 1..<16 {
            let start = Int(Double(beat) * rate / 2)
            for i in 0..<900 where start + i < audio.count {
                audio[start + i] = Float(sin(Double(i) * 2 * .pi * 100 / rate) * exp(-Double(i) / 180))
            }
        }
        let result = BeatDetector.analyze(samples: audio, sampleRate: rate, bpm: 120)
        XCTAssertGreaterThanOrEqual(result.times.count, 12)
        for time in result.times { XCTAssertEqual(time, (time * 2).rounded() / 2, accuracy: 0.07) }
        let automatic = BeatDetector.analyze(samples: audio, sampleRate: rate)
        XCTAssertEqual(automatic.bpm ?? 0, 120, accuracy: 6)
    }

}
