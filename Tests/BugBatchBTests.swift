import XCTest
import simd
import SwiftUI
@testable import AWIeffect

/// Regressions for the R2 (canvas / transform / rig / masks / physics) and R4 (CC Studio / effects UI / color /
/// presets) bug batch.
@MainActor
final class BugBatchBTests: XCTestCase {
    private func project() -> Project { Project.new(name: "bugs-b", width: 1000, height: 1000, fps: 30, duration: 4, background: .black) }
    private func state(_ p: Project) -> EditorState {
        EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }
    private let fit = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    private func drawn(_ s: EditorState, _ id: UUID, _ local: Vec2) -> Vec2 {
        let view = s.canvasViewProject(s.project)
        let l = Renderer.resolveParenting(view, time: s.currentTime).layers.first { $0.id == id }!
        let M = Renderer.placementMatrix(l, camera: Renderer.activeCamera(view, time: s.currentTime), time: s.currentTime, renderScale: 1)
        return LayerPlacement.projected(local, by: M)!
    }

    /// Parent rotated + scaled, child linked to it.
    private func parentedProject() -> (Project, parent: UUID, child: UUID) {
        var p = project()
        var parent = p.makeLayer(name: "parent", content: .solid, size: Vec2(100, 100))
        parent.transform.position = Animated(Vec2(300, 300))
        parent.transform.rotation = Animated(30)
        parent.transform.scale = Animated(Vec2(150, 150))
        var child = p.makeLayer(name: "child", content: .solid, size: Vec2(200, 200))
        child.parentID = parent.id
        child.transform.position = Animated(Vec2(100, 0))
        child.transform.rotation = Animated(10)
        p.layers = [child, parent]
        return (p, parent.id, child.id)
    }

    // MARK: R2 — pivot / scale / rotate centre

    func testPivotDragOnParentedLayerKeepsItInPlaceAndPutsAnchorUnderFinger() throws {
        let (p, _, child) = parentedProject()
        let s = state(p)
        s.select(child)
        s.transformTool = .pivot
        let corner0 = drawn(s, child, Vec2(-100, -100)), corner1 = drawn(s, child, Vec2(100, 80))
        let start = drawn(s, child, .zero)
        let undo0 = s.undoStack.count
        let d = try XCTUnwrap(s.beginCanvasDrag(at: CGPoint(x: start.x, y: start.y), comp: start, fit: fit))
        let target = start + Vec2(40, -25)
        s.updateCanvasDrag(d, comp: target)
        s.endCanvasDrag()
        let l = try XCTUnwrap(s.project.layers.first { $0.id == child })
        let a = l.transform.anchor.value(at: 0)
        XCTAssertNotEqual(a, .zero)
        let anchorNow = drawn(s, child, a)
        XCTAssertEqual(anchorNow.x, target.x, accuracy: 0.5); XCTAssertEqual(anchorNow.y, target.y, accuracy: 0.5)
        // The layer didn't jump.
        let c0 = drawn(s, child, Vec2(-100, -100)), c1 = drawn(s, child, Vec2(100, 80))
        XCTAssertEqual(c0.x, corner0.x, accuracy: 0.5); XCTAssertEqual(c0.y, corner0.y, accuracy: 0.5)
        XCTAssertEqual(c1.x, corner1.x, accuracy: 0.5); XCTAssertEqual(c1.y, corner1.y, accuracy: 0.5)
        XCTAssertEqual(s.undoStack.count, undo0 + 1)
    }

    func testPivotCompensationIn3DKeepsPlanePoint() {
        var tr = LayerTransform(position: Animated(Vec2(400, 300)))
        tr.rotationY = Animated(40); tr.rotationX = Animated(-20); tr.rotation = Animated(15); tr.scale = Animated(Vec2(120, 80))
        tr.positionZ = Animated(50)
        let newAnchor = Vec2(30, -20)
        var l = Layer(name: "3d", content: .solid, tag: .amber, outPoint: 4, transform: tr, size: Animated(Vec2(100, 100)))
        l.is3D = true
        let before = Renderer.layerWorld(l, time: 0) * SIMD4(newAnchor.x, newAnchor.y, 0, 1)
        let moved = CanvasHandles.pivotCompensated(tr, is3D: true, newAnchor: newAnchor, time: 0)
        l.transform.anchor = Animated(newAnchor); l.transform.position = Animated(moved.position); l.transform.positionZ = Animated(moved.z)
        let after = Renderer.layerWorld(l, time: 0) * SIMD4(newAnchor.x, newAnchor.y, 0, 1)
        XCTAssertEqual(before.x, after.x, accuracy: 1e-6); XCTAssertEqual(before.y, after.y, accuracy: 1e-6); XCTAssertEqual(before.z, after.z, accuracy: 1e-6)
    }

    func testScaleAndRotateTurnAroundTheDrawnAnchorOfAParentedLayer() throws {
        let (p, _, child) = parentedProject()
        let s = state(p)
        s.select(child)
        s.transformTool = .rotate
        let anchor = drawn(s, child, .zero)
        let start = anchor + Vec2(60, 0)
        let d = try XCTUnwrap(s.beginCanvasDrag(at: CGPoint(x: start.x, y: start.y), comp: start, fit: fit))
        XCTAssertEqual(d.pivot.x, anchor.x, accuracy: 1e-6); XCTAssertEqual(d.pivot.y, anchor.y, accuracy: 1e-6)
        // A quarter turn around the anchor adds 90° to the layer's OWN rotation (not parent + own).
        s.updateCanvasDrag(d, comp: anchor + Vec2(0, 60))
        s.endCanvasDrag()
        XCTAssertEqual(s.project.layers.first { $0.id == child }!.transform.rotation.value(at: 0), 100, accuracy: 0.11)
    }

    // MARK: R2 — Motion Sketch

    private func sketch(_ s: EditorState, _ id: UUID, moves: Int = 4) throws {
        let start = drawn(s, id, .zero)
        let d = try XCTUnwrap(s.beginCanvasDrag(at: CGPoint(x: start.x, y: start.y), comp: start, fit: fit))
        for k in 1...moves {
            s.updateCanvasDrag(d, comp: start + Vec2(Double(k) * 10, 0))
            RunLoop.current.run(until: Date().addingTimeInterval(0.04))
        }
        s.endCanvasDrag()
    }

    func testMotionSketchRecordsWithSnapOffAnd3DInOneUndoStep() throws {
        var p = project()
        var a = p.makeLayer(name: "a", content: .solid, size: Vec2(200, 200))
        a.transform.position = Animated(Vec2(200, 200))
        var b = p.makeLayer(name: "b", content: .solid, size: Vec2(200, 200))
        b.transform.position = Animated(Vec2(600, 600)); b.is3D = true
        p.layers = [a, b]
        let s = state(p)
        s.motionSketch = true; s.snappingEnabled = false; s.transformTool = .move
        s.select(a.id)
        let undo0 = s.undoStack.count
        try sketch(s, a.id)
        XCTAssertTrue(s.project.layers[0].transform.position.isAnimated, "Snap off must still record")
        XCTAssertEqual(s.undoStack.count, undo0 + 1, "drag + sketch = one undo step")
        s.snappingEnabled = true
        s.seek(0)
        s.select(b.id)
        try sketch(s, b.id)
        XCTAssertTrue(s.project.layers[1].transform.position.isAnimated, "3D layers must record")
    }

    func testMotionSketchRecordsEveryLayerOfAMultiSelection() throws {
        var p = project()
        var a = p.makeLayer(name: "a", content: .solid, size: Vec2(200, 200)); a.transform.position = Animated(Vec2(200, 200))
        var b = p.makeLayer(name: "b", content: .solid, size: Vec2(200, 200)); b.transform.position = Animated(Vec2(600, 600))
        p.layers = [a, b]
        let s = state(p)
        s.motionSketch = true; s.transformTool = .move
        s.select(a.id)
        s.multiSelection = [a.id, b.id]
        try sketch(s, a.id)
        XCTAssertTrue(s.project.layers[0].transform.position.isAnimated)
        XCTAssertTrue(s.project.layers[1].transform.position.isAnimated)
    }

    func testSketchedPositionClearsOldKeysFromTheSketchOn() {
        var base = Animated(Vec2(0, 0))
        for (t, x) in [(0.0, 0.0), (1.0, 10.0), (2.0, 20.0), (3.5, 99.0)] { base.insertKeyframe(Keyframe(time: t, value: Vec2(x, 0), interpolation: .linear)) }
        let samples: [(Double, Vec2)] = stride(from: 1.0, through: 2.0, by: 0.01).map { ($0, Vec2($0 * 100, 5)) }
        let out = EditorState.sketchedPosition(base: base, samples: samples, fps: 30)
        XCTAssertTrue(out.keyframes.contains { $0.time == 0 }, "keys before the sketch stay")
        XCTAssertFalse(out.keyframes.contains { abs($0.time - 3.5) < 1e-6 }, "old keys after the sketch don't carry on")
        XCTAssertEqual(out.keyframes.filter { $0.time >= 1 - 1e-6 }.count, 31)
        XCTAssertEqual(out.value(at: 2).x, 200, accuracy: 1.5)
    }

    // MARK: R2 — motion path

    func testMotionPathIsDrawnThroughParentingAndDotDragInverts() {
        let (p, _, child) = parentedProject()
        let l = p.layers.first { $0.id == child }!
        let world = Renderer.resolveParenting(p, time: 0).layers.first { $0.id == child }!.transform.position.value(at: 0)
        let sp = MotionPathMath.screenPoint(l, value: l.transform.position.value(at: 0), project: p, time: 0)!
        XCTAssertEqual(sp.x, world.x, accuracy: 1e-6); XCTAssertEqual(sp.y, world.y, accuracy: 1e-6)
        let target = Vec2(512, 433)
        let v = MotionPathMath.value(l, at: target, project: p, time: 0)!
        let back = MotionPathMath.screenPoint(l, value: v, project: p, time: 0)!
        XCTAssertEqual(back.x, target.x, accuracy: 1e-6); XCTAssertEqual(back.y, target.y, accuracy: 1e-6)
    }

    // MARK: R2 — IK

    private func limbProject() -> (Project, upper: UUID, lower: UUID) {
        var p = project()
        var up = p.makeLayer(name: "upper", content: .solid, size: Vec2(20, 100))
        up.transform.position = Animated(Vec2(100, 100))
        var lo = p.makeLayer(name: "lower", content: .solid, size: Vec2(20, 100))
        lo.transform.position = Animated(Vec2(200, 100))
        lo.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(200, 100), interpolation: .linear))
        lo.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(220, 100), interpolation: .linear))
        p.layers = [lo, up]
        return (p, up.id, lo.id)
    }

    func testMakeIKKeepsKeyframesAndIsOneUndoStep() throws {
        let (p, upper, lower) = limbProject()
        let s = state(p)
        s.select(lower)
        let undo0 = s.undoStack.count
        s.makeIK(upper: upper, controller: nil)
        let lo = try XCTUnwrap(s.project.layers.first { $0.id == lower })
        XCTAssertEqual(lo.parentID, upper)
        XCTAssertNotNil(lo.ik)
        XCTAssertEqual(lo.transform.position.keyframes.count, 2, "linking must convert keys, not erase them")
        XCTAssertEqual(s.undoStack.count, undo0 + 1)
        s.undo()
        XCTAssertNil(s.project.layers.first { $0.id == lower }?.ik)
        XCTAssertNil(s.project.layers.first { $0.id == lower }?.parentID)
    }

    func testIKBindsAuthoredEndpointWithoutChangingArtworkOrAddingDraftUndo() throws {
        let (p, upper, lower) = limbProject()
        let s = state(p)
        s.select(lower)
        let undoCount = s.undoStack.count
        let endpoint = Vec2(70, -15) // A sideways forearm, not the image's bottom edge.
        s.ikDraftTip = (lower, endpoint)
        XCTAssertEqual(s.undoStack.count, undoCount)
        let before = Renderer.resolveParenting(s.project, time: 0)
        let drawnBefore = try XCTUnwrap(before.layers.first { $0.id == lower })
        let m = Renderer.layerMatrix(drawnBefore, time: 0, renderScale: 1)
        let expected = m * SIMD3(endpoint.x, endpoint.y, 1)
        s.makeIK(upper: upper, controller: nil)
        let bound = try XCTUnwrap(s.project.layers.first { $0.id == lower }?.ik)
        let controller = try XCTUnwrap(s.project.layers.first { $0.id == bound.controllerID })
        XCTAssertEqual(controller.transform.position.staticValue.x, expected.x, accuracy: 1e-8)
        XCTAssertEqual(controller.transform.position.staticValue.y, expected.y, accuracy: 1e-8)
        let after = Renderer.resolveParenting(s.project, time: 0)
        let posed = try XCTUnwrap(after.layers.first { $0.id == lower })
        XCTAssertEqual(posed.transform.rotation.value(at: 0), drawnBefore.transform.rotation.value(at: 0), accuracy: 1e-7)
        XCTAssertEqual(s.undoStack.count, undoCount + 1)
        XCTAssertNil(s.ikDraftTip)
        s.undo()
        XCTAssertEqual(s.project.layers.count, p.layers.count)
        XCTAssertNil(s.project.layers.first { $0.id == lower }?.ik)
    }

    func testDirectIKPosePreservesKeysAndCoalescesUndo() throws {
        let (p, upper, lower) = limbProject()
        let s = state(p)
        s.select(lower)
        s.makeIK(upper: upper, controller: nil)
        let rig = try XCTUnwrap(s.project.layers.first { $0.id == lower }?.ik)
        let ci = try XCTUnwrap(s.project.layers.firstIndex { $0.id == rig.controllerID })
        let original = s.project.layers[ci].transform.position.staticValue
        s.project.layers[ci].transform.position.insertKeyframe(Keyframe(time: 0, value: original, interpolation: .linear))
        let before = s.project
        let undoCount = s.undoStack.count
        s.beginEdit("Pose IK")
        s.beginLiveGesture()
        s.poseIKController(rig.controllerID, atCanvas: Vec2(220, 140))
        s.poseIKController(rig.controllerID, atCanvas: Vec2(230, 150))
        s.endLiveGesture()
        s.endEdit()
        XCTAssertEqual(s.undoStack.count, undoCount + 1)
        XCTAssertEqual(s.project.layers[ci].transform.position.value(at: 0), Vec2(230, 150))
        XCTAssertEqual(s.project.layers.first { $0.id == lower }?.transform.position.keyframes.count, 2)
        s.undo()
        XCTAssertEqual(s.project.layers[ci].transform.position, before.layers[ci].transform.position)
    }

    func testIKDraftEndpointBelongsToItsLayer() {
        let (p, upper, lower) = limbProject()
        let s = state(p)
        s.ikDraftTip = (lower, Vec2(75, 10))
        let other = p.layers.first { $0.id == upper }!
        XCTAssertEqual(s.ikRestTip(for: other), Vec2(0, 50))
    }

    func testIKExistingControllerDefinesBindEndpoint() throws {
        var (p, upper, lower) = limbProject()
        var controller = p.makeLayer(name: "hand", content: .solid, size: Vec2(10, 10))
        controller.isNull = true
        controller.transform.position = Animated(Vec2(260, 130))
        p.layers.insert(controller, at: 0)
        let s = state(p)
        s.select(lower)
        s.makeIK(upper: upper, controller: controller.id)
        let rig = try XCTUnwrap(s.project.layers.first { $0.id == lower }?.ik)
        XCTAssertEqual(rig.l2, hypot(60, 30), accuracy: 1e-8)
        let posed = try XCTUnwrap(Renderer.resolveParenting(s.project, time: 0).layers.first { $0.id == lower })
        XCTAssertEqual(posed.transform.rotation.value(at: 0), 0, accuracy: 1e-7,
                       "Binding to a controller at the intended wrist must not rotate the artwork")
        XCTAssertEqual(s.project.layers.count, p.layers.count)
    }

    func testIKRejectsLinkLoopsAndPickerExcludesDescendants() {
        var (p, _, lower) = limbProject()
        var hand = p.makeLayer(name: "hand", content: .solid, size: Vec2(20, 20))
        hand.parentID = lower
        hand.transform.position = Animated(Vec2(0, 50))
        var finger = p.makeLayer(name: "finger", content: .solid, size: Vec2(5, 5))
        finger.parentID = hand.id
        p.layers.insert(contentsOf: [finger, hand], at: 0)
        XCTAssertEqual(IKSolver.descendants(of: lower, in: p), [hand.id, finger.id])
        let s = state(p)
        s.select(lower)
        let undo0 = s.undoStack.count
        s.makeIK(upper: finger.id, controller: nil)
        XCTAssertNil(s.project.layers.first { $0.id == lower }?.ik)
        XCTAssertNil(s.project.layers.first { $0.id == lower }?.parentID)
        XCTAssertEqual(s.undoStack.count, undo0)
    }

    func testIKBlendLetsRotationKeysThrough() throws {
        let (p, upper, lower) = limbProject()
        let s = state(p)
        s.select(lower)
        s.makeIK(upper: upper, controller: nil)
        var q = s.project
        let li = try XCTUnwrap(q.layers.firstIndex { $0.id == lower })
        q.layers[li].transform.rotation = Animated(25)
        q.layers[li].ik?.blend = 0
        XCTAssertEqual(IKSolver.apply(q, time: 0).layers[li].transform.rotation.value(at: 0), 25, accuracy: 1e-9)
        q.layers[li].ik?.blend = nil   // default = full IK
        let full = IKSolver.apply(q, time: 0).layers[li].transform.rotation.value(at: 0)
        q.layers[li].ik?.blend = 0.5
        let half = IKSolver.apply(q, time: 0).layers[li].transform.rotation.value(at: 0)
        XCTAssertEqual(half, IKSolver.blendAngle(fk: 25, ik: full, w: 0.5), accuracy: 1e-9)
        XCTAssertEqual(IKSolver.blendAngle(fk: 170, ik: -170, w: 0.5), 180, accuracy: 1e-9, "shortest way round")
    }

    // MARK: R2 — masks

    func testNewMaskOnParentedLayerLandsWhereItWasDrawn() throws {
        let (p, _, child) = parentedProject()
        let s = state(p)
        s.select(child)
        let comp = BezierPath(vertices: [PathVertex(point: Vec2(350, 380)), PathVertex(point: Vec2(420, 380), inTangent: Vec2(-10, 5), outTangent: Vec2(10, -5)),
                                         PathVertex(point: Vec2(400, 450))], closed: true)
        s.addMask(comp, to: child)
        let mask = try XCTUnwrap(s.project.layers.first { $0.id == child }?.masks.first)
        let M = try XCTUnwrap(s.displayPlacement(of: child))
        for (local, drawnV) in zip(mask.path.value(at: 0).vertices, comp.vertices) {
            let q = LayerPlacement.projected(local.point, by: M)!
            XCTAssertEqual(q.x, drawnV.point.x, accuracy: 1e-6); XCTAssertEqual(q.y, drawnV.point.y, accuracy: 1e-6)
            let tip = LayerPlacement.projected(local.point + local.outTangent, by: M)!
            XCTAssertEqual(tip.x, drawnV.point.x + drawnV.outTangent.x, accuracy: 1e-6)
        }
    }

    func testMaskOutlineFollowsCurves() {
        let path = BezierPath.ellipse(size: Vec2(100, 100))
        let pts = MaskPointsOverlay.outline(path, project: { $0 }, steps: 16)
        XCTAssertEqual(pts.count, path.vertices.count * 16)
        // Half-way along the first segment sits on the circle (r = 50), not on the straight chord (~35).
        XCTAssertEqual(hypot(pts[8].x, pts[8].y), 50, accuracy: 1.0)
    }

    // MARK: R2 — free view

    func testFreeViewHitTestsUseTheViewWithoutCamera() {
        var p = project()
        var cam = p.makeLayer(name: "cam", content: .camera, size: Vec2(10, 10))
        cam.transform.position = Animated(Vec2(200, 900))
        p.layers = [cam]
        let s = state(p)
        s.cameraView = false
        let view = s.canvasViewProject(s.project)
        XCTAssertFalse(view.layers[0].isActive(at: 0))
        let c = Renderer.activeCamera(view, time: 0), def = CameraState.defaultCamera(for: p)
        XCTAssertEqual(c.zoom, def.zoom)
        XCTAssertEqual(c.world, def.world)
        s.cameraView = true
        XCTAssertTrue(s.canvasViewProject(s.project).layers[0].isActive(at: 0))
    }

    // MARK: R2 — transform panel

    func testZDiamondKeysZWhenTheZFieldIsActive() {
        XCTAssertEqual(TransformPanel.diamondKey(tool: .position, axisZ: true), .positionZ)
        XCTAssertEqual(TransformPanel.diamondKey(tool: .position, axisZ: false), .position)
        XCTAssertEqual(TransformPanel.diamondKey(tool: .scale, axisZ: true), .scale)
    }

    func testLinkedScaleStripKeepsAspectRatio() {
        let s = TransformToolBody.scaled(Vec2(100, 50), dx: 10, dy: 0, linked: true)
        XCTAssertEqual(s.x, 110, accuracy: 1e-9); XCTAssertEqual(s.y, 55, accuracy: 1e-9)
        let h = TransformToolBody.scaled(Vec2(100, 50), dx: 0, dy: 10, linked: true)
        XCTAssertEqual(h.x / h.y, 2, accuracy: 1e-9)
        let free = TransformToolBody.scaled(Vec2(100, 50), dx: 10, dy: 0, linked: false)
        XCTAssertEqual(free, Vec2(110, 50))
    }

    // MARK: R2 — physics

    func testPhysicsBakeOnParentedLayerWritesParentSpaceAndKeepsFramesPastTheEnd() throws {
        var p = project()
        p.duration = 2
        var parent = p.makeLayer(name: "parent", content: .solid, size: Vec2(200, 200))
        parent.transform.position = Animated(Vec2(500, 300)); parent.transform.rotation = Animated(20)
        var child = p.makeLayer(name: "child", content: .solid, size: Vec2(40, 40))
        child.parentID = parent.id
        child.transform.position = Animated(Vec2(60, 0))
        p.layers = [child, parent]
        let s = state(p)
        s.seek(1)
        var settings = PhysicsSettings()
        settings.gravity = 0; settings.floor = false; settings.walls = false; settings.ceiling = false; settings.airDrag = 0
        settings.duration = 2.5
        s.bakePhysics(dynamicIDs: [child.id], settings: settings)
        let keys = try XCTUnwrap(s.project.layers.first { $0.id == child.id }).transform.position.keyframes
        XCTAssertFalse(keys.isEmpty)
        // Nothing pushes it: it stays where it was, in its parent's space.
        for k in keys { XCTAssertEqual(k.value.x, 60, accuracy: 0.5); XCTAssertEqual(k.value.y, 0, accuracy: 0.5) }
        XCTAssertGreaterThan(keys.last!.time, p.duration, "results past the comp end are kept")
    }

    // MARK: R4 — CC Studio

    func testScopeQueueAppliesOnlyTheNewestResult() {
        let q = ScopeRenderQueue()
        var applied: [Float] = []
        let done = expectation(description: "newest applied")
        q.submit(token: "a", work: { Thread.sleep(forTimeInterval: 0.15); return [[1]] }, apply: { applied.append($0[0][0]) })
        q.submit(token: "b", work: { [[2]] }, apply: { applied.append($0[0][0]) })
        q.submit(token: "c", work: { [[3]] }, apply: { applied.append($0[0][0]); done.fulfill() })
        wait(for: [done], timeout: 3)
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(applied, [3], "stale renders (a) and replaced requests (b) never land")
    }

    func testHistogramBins() {
        let h = ScopeRenderQueue.histogram([255, 0, 4, 255, 255, 0, 4, 255])
        XCTAssertEqual(h[0][63], 2); XCTAssertEqual(h[1][0], 2); XCTAssertEqual(h[2][1], 2)
    }

    func testCurvePointsMoveSidewaysAndStayOrdered() {
        // Evenly spaced points render exactly like the original fixed-x curve (saved grades look the same).
        func original(_ pts: [Double]) -> [Double] {
            let xs = [0, 0.25, 0.5, 0.75, 1.0]
            return (0..<256).map { i in
                let x = Double(i) / 255, k = min(3, Int(x * 4)), t = (x - xs[k]) / 0.25
                let p0 = pts[max(0, k - 1)], p1 = pts[k], p2 = pts[k + 1], p3 = pts[min(4, k + 2)]
                let v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
                return min(1, max(0, v))
            }
        }
        for pts in [[0, 0.25, 0.5, 0.75, 1], [0.1, 0.3, 0.5, 0.8, 0.9], [0, 0.1, 0.7, 0.6, 1]] {
            let now = GradeCurves.curve(xs: [0, 0.25, 0.5, 0.75, 1], ys: pts), old = original(pts)
            for i in 0..<256 { XCTAssertEqual(now[i], old[i], accuracy: 1e-9) }
        }
        let x1 = 100.0 / 255
        let moved = GradeCurves.curve(xs: [0, x1, 0.5, 0.75, 1], ys: [0, 0.7, 0.75, 0.85, 1])
        XCTAssertEqual(moved[100], 0.7, accuracy: 1e-9, "the curve passes through the moved point")
        let o = GradeCurves.orderedXs([0, 0.6, 0.5, 0.4, 1])
        XCTAssertTrue(o[1] < o[2] && o[2] < o[3] && o[3] < o[4])
        // Older grades without x controls read as the even 25/50/75 positions.
        let g = EffectRegistry.grade.makeInstance()
        var old = g; for k in ["m25x", "m50x", "m75x"] { old.params[k] = nil }
        XCTAssertEqual(GradeCurves.points(old, 0, channel: "m").xs, [0, 0.25, 0.5, 0.75, 1])
    }

    func testLooksTravelWithTheProjectAndMergeKeepsKeyframes() throws {
        var current = EffectRegistry.grade.makeInstance()
        var ex = Animated(0.0)
        ex.insertKeyframe(Keyframe(time: 0, value: 0, interpolation: .linear))
        ex.insertKeyframe(Keyframe(time: 2, value: 1, interpolation: .linear))
        current.params["exposure"] = .number(ex)
        var look = EffectRegistry.grade.makeInstance()
        look.params["exposure"] = .number(Animated(0.5))
        look.params["contrast"] = .number(Animated(30))
        let merged = LookLibrary.merged(look, into: current, at: 1)
        guard case .number(let m)? = merged.params["exposure"] else { return XCTFail() }
        XCTAssertEqual(m.keyframes.count, 3, "grade keyframes survive; the Look is keyed at the playhead")
        XCTAssertEqual(m.value(at: 1), 0.5, accuracy: 1e-9)
        XCTAssertEqual(merged.number("contrast", 0), 30)
        XCTAssertEqual(merged.id, current.id)
        let replaced = LookLibrary.replaced(look, into: current)
        XCTAssertTrue(replaced.params["exposure"]!.keyframeTimes.isEmpty)

        var p = project()
        p.savedLooks = ["Teal": look]
        let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.savedLooks?["Teal"], look)
        XCTAssertTrue(LookLibrary.allNames(project: p).contains("Teal"))
        XCTAssertEqual(LookLibrary.look("Teal", project: p), look)
        let older = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project()))
        XCTAssertNil(older.savedLooks)
    }

    // MARK: R4 — effects panel / color

    func testColorDragIsOneUndoStep() {
        var p = project()
        let only = p.makeLayer(name: "l", content: .solid, size: Vec2(10, 10))
        p.layers = [only]
        let s = state(p)
        s.select(p.layers[0].id)
        let undo0 = s.undoStack.count
        for v in [0.1, 0.2, 0.3, 0.4] { s.coalescedProjectEdit("Background") { $0.background = RGBA(v, v, v) } }
        XCTAssertEqual(s.undoStack.count, undo0 + 1)
        XCTAssertEqual(s.project.background, RGBA(0.4, 0.4, 0.4))
        s.endEdit()
        for v in [0.1, 0.5] { s.coalescedEdit("Edit Color") { $0.fill.set(RGBA(v, 0, 0), at: 0) } }
        XCTAssertEqual(s.undoStack.count, undo0 + 2)
    }

    func testEffectCardAutoOpensOnlyOnce() {
        let id = UUID()
        XCTAssertTrue(EffectsPanel.shouldAutoOpen(id, last: id, opened: []))
        XCTAssertFalse(EffectsPanel.shouldAutoOpen(id, last: id, opened: [id]), "scrolling back must not re-open a collapsed card")
        XCTAssertFalse(EffectsPanel.shouldAutoOpen(id, last: UUID(), opened: []))
    }

    func testBorderShadowSwitchReflectsEveryInstance() {
        var a = EffectRegistry.border.makeInstance(); a.isEnabled = false
        let b = EffectRegistry.border.makeInstance()
        XCTAssertTrue(StylePanel.isOn([a, b]))
        XCTAssertEqual(StylePanel.shown([a, b])?.id, b.id)
        XCTAssertEqual(StylePanel.toggleTargets([a, b], on: false), [b.id])
        XCTAssertEqual(StylePanel.toggleTargets([a, b], on: true), [])
        var c = b; c.isEnabled = false
        XCTAssertEqual(StylePanel.toggleTargets([a, c], on: true), [a.id])
    }

    // MARK: R4 — presets

    func testPresetReappliesWithoutStackingAndKeepsUserOpacity() throws {
        var p = project()
        var l = p.makeLayer(name: "l", content: .solid, size: Vec2(100, 100))
        l.transform.opacity = Animated(60)
        let zoom = try XCTUnwrap(PresetLibrary.all.first { $0.id == "zoomBlurIn" })
        let s0 = l.transform.scale.value(at: 0)
        var once = PresetLibrary.applying(zoom, to: l, project: p, at: 0)
        once = PresetLibrary.applying(zoom, to: once, project: p, at: 0)
        XCTAssertEqual(once.effects.count, 1, "applying again replaces its own effects")
        XCTAssertEqual(once.transform.scale.value(at: 0.35), s0, "values don't compound")
        XCTAssertEqual(once.transform.scale.value(at: 0).x, s0.x * 1.6, accuracy: 1e-9)

        let fade = try XCTUnwrap(PresetLibrary.all.first { $0.id == "fadeUpIn" })
        var faded = PresetLibrary.applying(fade, to: l, project: p, at: 0)
        XCTAssertEqual(faded.transform.opacity.value(at: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(faded.transform.opacity.value(at: 0.5), 60, accuracy: 1e-9, "fades up to the layer's own opacity")
        faded = PresetLibrary.applying(fade, to: faded, project: p, at: 0)
        XCTAssertEqual(faded.transform.opacity.value(at: 0.5), 60, accuracy: 1e-9)
        XCTAssertEqual(faded.transform.position.value(at: 0.5), l.transform.position.value(at: 0))
        XCTAssertEqual(faded.transform.position.value(at: 0).y, l.transform.position.value(at: 0).y + 120, accuracy: 1e-9)
    }
}
