import XCTest
import simd
@testable import AWIeffect

/// R2 renewals: mask point editing, pen helpers, shape operator stack.
@MainActor
final class RenewCanvasTests: XCTestCase {
    private func project() -> Project { Project.new(name: "renew-r2", width: 1000, height: 1000, fps: 30, duration: 4, background: .black) }
    private func state(_ p: Project) -> EditorState {
        EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }

    private func maskedState() -> (EditorState, UUID) {
        var p = project()
        var l = p.makeLayer(name: "solid", content: .shape(.rectangle), size: Vec2(400, 400))
        l.transform.position = Animated(Vec2(500, 500))
        l.masks = [LayerMask(name: "Mask 1", path: Animated(.rectangle(size: Vec2(200, 200))))]
        p.layers = [l]
        let s = state(p)
        s.select(l.id)
        return (s, l.masks[0].id)
    }

    // MARK: path math

    func testInsertVertexKeepsTheCurve() {
        var path = BezierPath.ellipse(size: Vec2(100, 100))
        let before = path.point(onSegment: 0, t: 0.25)!
        let mid = path.point(onSegment: 0, t: 0.5)!
        let j = path.insertVertex(onSegment: 0, t: 0.5)
        XCTAssertEqual(j, 1)
        XCTAssertEqual(path.vertices.count, 5)
        XCTAssertEqual(path.vertices[1].point.x, mid.x, accuracy: 1e-9)
        XCTAssertEqual(path.vertices[1].point.y, mid.y, accuracy: 1e-9)
        // The first half of the old segment is now segment 0 (t = 0.5 there = old t = 0.25).
        let after = path.point(onSegment: 0, t: 0.5)!
        XCTAssertEqual(after.x, before.x, accuracy: 1e-9)
        XCTAssertEqual(after.y, before.y, accuracy: 1e-9)
    }

    func testInsertOnClosingSegmentAppends() {
        var path = BezierPath.rectangle(size: Vec2(100, 100))
        let n = path.vertices.count
        XCTAssertEqual(path.insertVertex(onSegment: n - 1, t: 0.5), n)
        XCTAssertEqual(path.vertices.count, n + 1)
    }

    func testRemoveVertexKeepsAClosedShape() {
        var path = BezierPath(vertices: [PathVertex(point: .zero), PathVertex(point: Vec2(1, 0)), PathVertex(point: Vec2(0, 1))], closed: true)
        XCTAssertFalse(path.removeVertex(0))
        XCTAssertEqual(path.vertices.count, 3)
    }

    func testPointKindsAndHandles() {
        var path = BezierPath.rectangle(size: Vec2(100, 100))
        XCTAssertEqual(path.kind(of: 0), .corner)
        path.setKind(.smooth, at: 0)
        XCTAssertEqual(path.kind(of: 0), .smooth)
        // Linked: the other side follows in line, keeping its own length.
        let inLen = hypot(path.vertices[0].inTangent.x, path.vertices[0].inTangent.y)
        path.moveHandle(0, side: .outTangent, toLocal: path.vertices[0].point + Vec2(0, 40), broken: false)
        XCTAssertEqual(path.vertices[0].inTangent.x, 0, accuracy: 1e-9)
        XCTAssertEqual(path.vertices[0].inTangent.y, -inLen, accuracy: 1e-9)
        XCTAssertEqual(path.kind(of: 0), .smooth)
        // Broken: only one side moves.
        let keep = path.vertices[0].inTangent
        path.moveHandle(0, side: .outTangent, toLocal: path.vertices[0].point + Vec2(30, 0), broken: true)
        XCTAssertEqual(path.vertices[0].inTangent, keep)
        XCTAssertEqual(path.kind(of: 0), .broken)
        path.setKind(.corner, at: 0)
        XCTAssertEqual(path.vertices[0].outTangent, .zero)
    }

    func testWholeMaskTransform() {
        let path = BezierPath.rectangle(size: Vec2(100, 100))
        let c = path.vertexCentroid
        let big = path.transformed(scale: 200, about: c)
        XCTAssertEqual(hypot(big.vertices[0].point.x - c.x, big.vertices[0].point.y - c.y),
                       2 * hypot(path.vertices[0].point.x - c.x, path.vertices[0].point.y - c.y), accuracy: 1e-9)
        let moved = path.transformed(translate: Vec2(10, -5), about: c)
        XCTAssertEqual(moved.vertices[2].point, path.vertices[2].point + Vec2(10, -5))
        let turned = path.transformed(rotation: 90, about: .zero)
        XCTAssertEqual(turned.vertices[0].point.x, -path.vertices[0].point.y, accuracy: 1e-9)
    }

    func testNearestSegmentFindsTheOutline() {
        let path = BezierPath.rectangle(size: Vec2(100, 100))
        let probe = Vec2(0, path.vertices.map(\.point.y).min()! - 2)   // just above the top edge
        let hit = path.nearestSegment(to: probe, map: { $0 })
        XCTAssertNotNil(hit)
        XCTAssertLessThan(hit!.2, 3)
    }

    // MARK: editor flows

    func testDeleteAndInsertMaskPointAreOneUndoStepEach() {
        let (s, mid) = maskedState()
        s.maskSelection = MaskSelection(maskID: mid, vertex: 0)
        let n = s.selectedLayer!.masks[0].path.value(at: 0).vertices.count
        s.insertMaskPointAfterSelection()
        XCTAssertEqual(s.selectedLayer!.masks[0].path.value(at: 0).vertices.count, n + 1)
        XCTAssertEqual(s.maskSelection?.vertex, 1)
        s.deleteSelectedMaskPoint()
        XCTAssertEqual(s.selectedLayer!.masks[0].path.value(at: 0).vertices.count, n)
        s.undo()
        XCTAssertEqual(s.selectedLayer!.masks[0].path.value(at: 0).vertices.count, n + 1)
        s.undo()
        XCTAssertEqual(s.selectedLayer!.masks[0].path.value(at: 0).vertices.count, n)
    }

    func testAddingAPointKeepsAnAnimatedMaskAnimating() {
        let (s, mid) = maskedState()
        s.mutate("keys") { p in
            let path = p.layers[0].masks[0].path.value(at: 0)
            p.layers[0].masks[0].path.insertKeyframe(Keyframe(time: 0, value: path, interpolation: .linear))
            p.layers[0].masks[0].path.insertKeyframe(Keyframe(time: 2, value: path.transformed(scale: 150, about: .zero), interpolation: .linear))
        }
        s.maskSelection = MaskSelection(maskID: mid, vertex: 1)
        s.insertMaskPointAfterSelection()
        let keys = s.selectedLayer!.masks[0].path.keyframes
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys[0].value.vertices.count, keys[1].value.vertices.count)
    }

    func testPointKindChangeAndSelectionClearsWithLayer() {
        let (s, mid) = maskedState()
        s.maskSelection = MaskSelection(maskID: mid, vertex: 2)
        s.setSelectedMaskPointKind(.smooth)
        XCTAssertEqual(s.selectedLayer!.masks[0].path.value(at: 0).kind(of: 2), .smooth)
        s.stepMaskSelection(5)
        XCTAssertEqual(s.maskSelection?.vertex, (2 + 5) % s.selectedLayer!.masks[0].path.value(at: 0).vertices.count)
        s.select(nil)
        XCTAssertNil(s.maskSelection)
    }

    func testMaskTapOnOutlineInsertsAndMissClears() {
        let (s, mid) = maskedState()
        guard let top = s.compPoint(fromLocal: Vec2(0, -100)) else { return XCTFail("no placement") }
        XCTAssertTrue(s.maskTap(atComp: top, reach: 20))
        XCTAssertEqual(s.selectedLayer!.masks[0].path.value(at: 0).vertices.count, 5)
        XCTAssertEqual(s.maskSelection?.maskID, mid)
        XCTAssertFalse(s.maskTap(atComp: Vec2(10, 10), reach: 20))
        XCTAssertNil(s.maskSelection)
    }

    // MARK: shape operators

    func testClassicOrderMatchesTheOldPipeline() {
        var ops = ShapeOps()
        ops.pucker = Animated(20); ops.offset = Animated(5); ops.zigzag = ZigZagOp()
        XCTAssertEqual(ops.activeOrder, [.pucker, .offset, .zigzag])
        let base = BezierPath.rectangle(size: Vec2(100, 100))
        var manual = ShapeOpsMath.pucker(base, amount: 20).flattened()
        manual = ShapeOpsMath.offset(manual, by: 5)
        manual = ShapeOpsMath.zigzag(manual, ZigZagOp(), time: 0)
        XCTAssertEqual(ShapeOpsMath.apply(ops, to: base, time: 0), manual)
    }

    func testReorderAndToggle() {
        var ops = ShapeOps()
        ops.setEnabled(.offset, true); ops.setEnabled(.twist, true); ops.setEnabled(.roundCorners, true)
        XCTAssertEqual(ops.activeOrder, [.roundCorners, .offset, .twist])
        ops.move(.twist, by: -2)   // out of range: nothing
        XCTAssertEqual(ops.activeOrder, [.roundCorners, .offset, .twist])
        ops.move(.twist, by: -1)
        XCTAssertEqual(ops.activeOrder, [.roundCorners, .twist, .offset])
        ops.setEnabled(.roundCorners, false)
        XCTAssertEqual(ops.activeOrder, [.twist, .offset])
        ops.setEnabled(.wiggle, true)
        XCTAssertEqual(ops.activeOrder.last, .wiggle)
        XCTAssertEqual(Set(ops.activeOrder).count, ops.activeOrder.count)
    }

    func testRoundCornersAndTwist() {
        let rect = BezierPath.rectangle(size: Vec2(100, 100))
        let round = ShapeOpsMath.roundCorners(rect, radius: 10)
        XCTAssertEqual(round.vertices.count, rect.vertices.count * 2)
        XCTAssertTrue(round.vertices.contains { $0.outTangent != .zero })
        // Radius clamps to half an edge.
        let huge = ShapeOpsMath.roundCorners(rect, radius: 1000)
        XCTAssertEqual(huge.vertices[0].point.x, huge.vertices[huge.vertices.count - 1].point.x, accuracy: 1e-6)
        let twisted = ShapeOpsMath.twist(rect.flattened(), angle: 90, center: .zero)
        XCTAssertEqual(twisted.vertices.count, rect.flattened().vertices.count)
        XCTAssertEqual(ShapeOpsMath.twist(rect, angle: 0, center: .zero), rect)
    }

    func testOldShapeOpsStillDecode() throws {
        let old = try JSONEncoder().encode(ShapeOps(repeater: nil, offset: Animated(4)))
        var json = try JSONSerialization.jsonObject(with: old) as! [String: Any]
        json.removeValue(forKey: "roundCorners"); json.removeValue(forKey: "twist"); json.removeValue(forKey: "order")
        let data = try JSONSerialization.data(withJSONObject: json)
        let back = try JSONDecoder().decode(ShapeOps.self, from: data)
        XCTAssertEqual(back.offset, Animated(4))
        XCTAssertNil(back.twist)
        XCTAssertEqual(back.activeOrder, [.offset])
    }

    // MARK: R2 part 2 — motion path, orient, snapping, arrange, picking, aiming

    func testSpatialHandlesCurveThePath() {
        var a = Animated(Vec2(0, 0))
        a.insertKeyframe(Keyframe(time: 0, value: Vec2(0, 0), interpolation: .linear))
        a.insertKeyframe(Keyframe(time: 1, value: Vec2(100, 0), interpolation: .linear))
        XCTAssertEqual(a.value(at: 0.5).y, 0, accuracy: 1e-9)
        MotionPathHandles.setHandle(&a, key: 0, out: true, tangent: Vec2(0, 60))
        XCTAssertNotNil(a.keyframes[0].spatialIn)
        XCTAssertGreaterThan(a.value(at: 0.5).y, 10)
        XCTAssertEqual(a.value(at: 1).x, 100, accuracy: 1e-9)
        // Dragged back onto the key: straight again.
        MotionPathHandles.setHandle(&a, key: 0, out: true, tangent: Vec2(0.5, 0))
        XCTAssertNil(a.keyframes[0].spatialOut)
        XCTAssertEqual(a.value(at: 0.5).y, 0, accuracy: 1e-9)
    }

    func testOrientAlongPath() throws {
        var p = project()
        var l = p.makeLayer(name: "car", content: .shape(.rectangle), size: Vec2(50, 20))
        l.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(100, 100), interpolation: .linear))
        l.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(100, 300), interpolation: .linear))
        l.transform.rotation = Animated(10)
        p.layers = [l]
        XCTAssertEqual(Renderer.resolveParenting(p, time: 0.5).layers[0].transform.rotation.value(at: 0.5), 10, accuracy: 1e-9)
        p.layers[0].transform.autoOrient = true
        // Moving straight down = 90 degrees, plus its own 10.
        XCTAssertEqual(Renderer.resolveParenting(p, time: 0.5).layers[0].transform.rotation.value(at: 0.5), 100, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(AutoOrient.angle(p.layers[0].transform.position, at: 5)), 90, accuracy: 1e-6)
        let data = try JSONEncoder().encode(p)
        XCTAssertTrue(try JSONDecoder().decode(Project.self, from: data).layers[0].transform.autoOrient)
    }

    func testOldTransformAndKeyframesDecode() throws {
        // A transform saved before Orient Along Path, with a key saved before spatial handles.
        var old = LayerTransform(position: Animated(Vec2(1, 2)))
        old.position.insertKeyframe(Keyframe(time: 0, value: Vec2(1, 2)))
        let data = try JSONEncoder().encode(old)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj.removeValue(forKey: "autoOrientStore")
        let json = String(decoding: try JSONSerialization.data(withJSONObject: obj), as: UTF8.self)
        XCTAssertFalse(json.contains("spatial"))
        let tr = try JSONDecoder().decode(LayerTransform.self, from: Data(json.utf8))
        XCTAssertFalse(tr.autoOrient)
        XCTAssertNil(tr.position.keyframes.first?.spatialOut)
    }

    func testSnapMath() {
        XCTAssertEqual(CanvasSnap.snapScale(149.4), 150)
        XCTAssertEqual(CanvasSnap.snapScale(147.5), 147.5)
        XCTAssertEqual(CanvasSnap.snapRotation(52), 45)
        XCTAssertEqual(CanvasSnap.gridLines(divisions: 4, length: 1000), [0, 250, 500, 750, 1000])
    }

    func testRotationIsFreeUnlessSnapIsOn() {
        var p = project()
        let l = p.makeLayer(name: "a", content: .shape(.rectangle), size: Vec2(200, 200))
        p.layers = [l]
        let s = state(p)
        s.select(l.id)
        s.beginLayerPinch(); s.updateLayerPinch(scale: 1, rotation: 44); s.endLayerPinch(ownsEdit: true)
        XCTAssertEqual(s.selectedLayer!.transform.rotation.value(at: 0), 44, accuracy: 1e-9)
        s.rotationSnap = true
        s.beginLayerPinch(); s.updateLayerPinch(scale: 1, rotation: 4); s.endLayerPinch(ownsEdit: true)
        XCTAssertEqual(s.selectedLayer!.transform.rotation.value(at: 0), 45, accuracy: 1e-9)
    }

    func testTapCycleAndMarquee() {
        let a = UUID(), b = UUID(), c = UUID()
        XCTAssertEqual(CanvasPick.next(hits: [a, b, c], current: nil, sameSpot: true), a)
        XCTAssertEqual(CanvasPick.next(hits: [a, b, c], current: a, sameSpot: true), b)
        XCTAssertEqual(CanvasPick.next(hits: [a, b, c], current: c, sameSpot: true), a)
        XCTAssertEqual(CanvasPick.next(hits: [a, b, c], current: b, sameSpot: false), a)
        XCTAssertNil(CanvasPick.next(hits: [], current: a, sameSpot: true))
        let picked = CanvasPick.marquee(CGRect(x: 0, y: 0, width: 100, height: 100),
                                        bounds: [(a, CGRect(x: 50, y: 50, width: 10, height: 10)), (b, CGRect(x: 300, y: 0, width: 10, height: 10))])
        XCTAssertEqual(picked, [a])
    }

    func testDistributeAndFit() {
        let a = UUID(), b = UUID(), c = UUID()
        let moves = Arrange.distribute([(a, CGRect(x: 0, y: 0, width: 10, height: 10)), (b, CGRect(x: 20, y: 0, width: 10, height: 10)),
                                        (c, CGRect(x: 100, y: 0, width: 10, height: 10))], horizontal: true)
        XCTAssertEqual(moves[b]!.x, 30, accuracy: 1e-9)
        XCTAssertEqual(moves[a]!.x, 0, accuracy: 1e-9)
        XCTAssertEqual(Arrange.fitScale(halfSize: Vec2(500, 250), comp: Vec2(1000, 1000), fill: false), 100, accuracy: 1e-9)
        XCTAssertEqual(Arrange.fitScale(halfSize: Vec2(500, 250), comp: Vec2(1000, 1000), fill: true), 200, accuracy: 1e-9)
    }

    func testAlignToSelectionCenterAnchorResetAndGuides() {
        var p = project()
        var a = p.makeLayer(name: "a", content: .shape(.rectangle), size: Vec2(100, 100))
        var b = p.makeLayer(name: "b", content: .shape(.rectangle), size: Vec2(100, 100))
        a.transform.position = Animated(Vec2(200, 200)); b.transform.position = Animated(Vec2(600, 400))
        p.layers = [a, b]
        let s = state(p)
        s.beginMultiSelect(a.id); s.multiSelection = [a.id, b.id]
        s.align(.left)
        XCTAssertEqual(s.project.layers[1].transform.position.value(at: 0).x, 200, accuracy: 0.01, "left edges meet the selection's left")
        s.undo()
        XCTAssertEqual(s.project.layers[1].transform.position.value(at: 0).x, 600, accuracy: 0.01)
        s.endMultiSelect(); s.select(a.id)
        s.mutate("anchor") { $0.layers[0].transform.anchor = Animated(Vec2(30, 0)) }
        let before = LayerPlacement.bounds(s.selectedLayer!, project: s.project, time: 0)!
        s.centerAnchor()
        XCTAssertEqual(s.selectedLayer!.transform.anchor.value(at: 0), .zero)
        let after = LayerPlacement.bounds(s.selectedLayer!, project: s.project, time: 0)!
        XCTAssertEqual(after.midX, before.midX, accuracy: 0.5, "centering the anchor keeps the layer in place")
        s.resetTransform()
        XCTAssertEqual(s.selectedLayer!.transform.position.value(at: 0), Vec2(500, 500))
        s.addGuide(vertical: true)
        XCTAssertEqual(s.guides.count, 1)
        XCTAssertTrue(s.extraSnapTargets(view: s.project, time: 0).xs.contains(500))
        let gid = s.guides[0].id
        s.beginEdit("Move Guide"); s.moveGuide(gid, to: -20); s.finishGuideDrag(gid)
        XCTAssertTrue(s.guides.isEmpty, "dragged off the comp = removed")
    }

    func testAimPointsAtTarget() {
        let c = SIMD3(500.0, 500.0, -1000.0), target = SIMD3(800.0, 200.0, 0.0)
        for rz in [0.0, 30.0] {
            let a = Aim.angles(from: c, to: target, rotationZ: rz)!
            let dir = CameraState.rotation(x: a.x, y: a.y, z: rz) * SIMD4(0, 0, 1, 0)
            let want = simd_normalize(target - c)
            XCTAssertEqual(dir.x, want.x, accuracy: 1e-9); XCTAssertEqual(dir.y, want.y, accuracy: 1e-9); XCTAssertEqual(dir.z, want.z, accuracy: 1e-9)
        }
        var p = project()
        var light = p.makeLayer(name: "light", content: .light, size: Vec2(10, 10))
        light.transform.position = Animated(Vec2(500, 500)); light.transform.positionZ = Animated(-800)
        p.layers = [light]
        let s = state(p)
        s.select(light.id)
        s.beginEdit("Aim"); s.aimSelected(atComp: Vec2(700, 300)); s.endEdit()
        let hit = Aim.planeHit(s.selectedLayer!, time: 0)!
        XCTAssertEqual(hit.x, 700, accuracy: 1); XCTAssertEqual(hit.y, 300, accuracy: 1)
    }

    func testLayerPickHandsTheTappedLayerToTheTool() {
        var p = project()
        let a = p.makeLayer(name: "lower", content: .shape(.rectangle), size: Vec2(10, 10))
        let b = p.makeLayer(name: "upper", content: .shape(.rectangle), size: Vec2(10, 10))
        p.layers = [a, b]
        let s = state(p)
        s.select(a.id)
        s.pickIKUpper()
        XCTAssertTrue(s.linkPicking)
        XCTAssertFalse(s.layerPickAllows(a.id))
        s.endLinkPick(parent: b.id)
        XCTAssertEqual(s.ikDraftUpper, b.id)
        XCTAssertEqual(s.panel, .rig)
        XCTAssertNil(s.project.layers[0].parentID, "a tool pick never parents")
    }
}
