import XCTest
@testable import AWIeffect

@MainActor
final class RenewTimelineTests: XCTestCase {
    private func makeState(_ edit: (inout Project) -> Void = { _ in }) -> EditorState {
        var p = Project.new(name: "t", width: 100, height: 100, fps: 30, duration: 10, background: .black)
        var a = p.makeLayer(name: "a", content: .solid, size: Vec2(10, 10))
        a.inPoint = 0; a.outPoint = 4
        a.transform.opacity.insertKeyframe(Keyframe(time: 1, value: 0, interpolation: .linear))
        a.transform.opacity.insertKeyframe(Keyframe(time: 2, value: 100, interpolation: .linear))
        a.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(0, 0), interpolation: .linear))
        a.transform.position.insertKeyframe(Keyframe(time: 3, value: Vec2(90, 30), interpolation: .linear))
        var b = p.makeLayer(name: "b", content: .solid, size: Vec2(10, 10))
        b.inPoint = 5; b.outPoint = 7
        p.layers = [a, b]
        edit(&p)
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.select(p.layers[0].id)
        return s
    }

    // MARK: Lanes

    func testLanesListEachAnimatedProperty() {
        let s = makeState()
        let lanes = s.project.layers[0].propertyLanes()
        XCTAssertEqual(lanes.map(\.id), ["tr.position", "tr.opacity"])
        XCTAssertEqual(lanes[0].times, [1, 3])
        XCTAssertTrue(lanes.allSatisfy(\.graphable))
    }

    func testLanesCoverEveryKeyOfTheLayer() {
        let s = makeState { p in
            var fx = EffectInstance(typeID: "blur", params: ["radius": .number(Animated(4))])
            if case .number(var a)? = fx.params["radius"] {
                a.insertKeyframe(Keyframe(time: 2.5, value: 10)); fx.params["radius"] = .number(a)
            }
            p.layers[0].effects = [fx]
            p.layers[0].transform.rotationX.insertKeyframe(Keyframe(time: 0.5, value: 20))
        }
        let l = s.project.layers[0]
        let laneTimes = Set(l.propertyLanes().flatMap(\.times))
        XCTAssertEqual(laneTimes, Set(l.keyframeTimes))
        XCTAssertTrue(l.propertyLanes().contains { $0.id.hasPrefix("fx.") })
        XCTAssertTrue(l.propertyLanes().contains { $0.id == "3d.rotationX" })
    }

    // MARK: Selection moves

    func testMovingOneLaneKeyLeavesOtherLanes() {
        let s = makeState()
        let o = s.project.layers[0]
        let sel = KeySelection(layerID: o.id, keys: ["tr.opacity": [1]])
        let moved = s.moveKeySelection(of: o, sel, by: 0.5)
        XCTAssertEqual(moved?.keys["tr.opacity"], [1.5])
        XCTAssertEqual(s.project.layers[0].transform.opacity.keyframes.map(\.time), [1.5, 2])
        XCTAssertEqual(s.project.layers[0].transform.position.keyframes.map(\.time), [1, 3], "position shares t=1 but isn't selected")
    }

    func testMoveOntoOccupiedKeyIsRejected() {
        let s = makeState()
        let o = s.project.layers[0]
        let sel = KeySelection(layerID: o.id, keys: ["tr.opacity": [1]])
        XCTAssertNil(s.moveKeySelection(of: o, sel, by: 1))
        XCTAssertEqual(s.project.layers[0].transform.opacity.keyframes.count, 2)
    }

    func testMarqueeSelectsAcrossLanes() {
        let s = makeState()
        let l = s.project.layers[0]
        let sel = KeySelection.marquee(layerID: l.id, lanes: l.propertyLanes(), laneRange: 0...1, from: 0.5, to: 1.5)
        XCTAssertEqual(sel.count, 2)
        XCTAssertTrue(sel.contains("tr.position", 1) && sel.contains("tr.opacity", 1))
    }

    func testStretchScalesAroundFirstKey() {
        let s = makeState()
        let o = s.project.layers[0]
        let sel = KeySelection(layerID: o.id, keys: ["tr.opacity": [1, 2], "tr.position": [1, 3]])
        s.beginEdit("Stretch")
        s.stretchKeySelection(of: o, sel, factor: 2)
        s.endEdit()
        XCTAssertEqual(s.project.layers[0].transform.opacity.keyframes.map(\.time), [1, 3])
        XCTAssertEqual(s.project.layers[0].transform.position.keyframes.map(\.time), [1, 5])
        s.undo()
        XCTAssertEqual(s.project.layers[0].transform.position.keyframes.map(\.time), [1, 3], "one undo step")
    }

    func testReverseMirrorsValues() {
        let s = makeState()
        let o = s.project.layers[0]
        let sel = KeySelection(layerID: o.id, keys: ["tr.opacity": [1, 2]])
        s.reverseKeySelection(of: o, sel)
        let k = s.project.layers[0].transform.opacity.keyframes
        XCTAssertEqual(k.map(\.time), [1, 2])
        XCTAssertEqual(k.map(\.value), [100, 0])
    }

    // MARK: Graph

    func testGraphChannelRoundTripsVectorComponent() {
        var a = Animated(Vec2(0, 0))
        a.insertKeyframe(Keyframe(time: 0, value: Vec2(1, 2)))
        a.insertKeyframe(Keyframe(time: 1, value: Vec2(3, 4)))
        var y = ValueGraph.channel(a, dim: 1)
        XCTAssertEqual(y.keyframes.map(\.value), [2, 4])
        XCTAssertTrue(ValueGraph.moveKey(&y, id: y.keyframes[1].id, time: 1, value: 10))
        ValueGraph.merge(y, into: &a, dim: 1)
        XCTAssertEqual(a.keyframes[1].value, Vec2(3, 10))
    }

    func testGraphHandleDragMakesBezier() {
        var a = Animated(0.0)
        a.insertKeyframe(Keyframe(time: 0, value: 0, interpolation: .linear))
        a.insertKeyframe(Keyframe(time: 1, value: 100, interpolation: .linear))
        ValueGraph.setHandle(&a, key: 0, out: true, t: 0.5, v: 0)
        XCTAssertEqual(a.keyframes[0].interpolation, .bezier)
        XCTAssertEqual(a.keyframes[0].easeOut.x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(a.keyframes[0].easeOut.y, 0, accuracy: 1e-9)
        let p = ValueGraph.handlePoint(a, key: 0, out: true)
        XCTAssertEqual(p?.t ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertEqual(ValueGraph.speed(at: 0.5) { a.value(at: $0) } > 0, true)
    }

    // MARK: Clip edits

    func testRippleDeletePullsLaterClipsBack() {
        let s = makeState()
        s.rippleDeleteSelected()
        XCTAssertEqual(s.project.layers.count, 1)
        XCTAssertEqual(s.project.layers[0].inPoint, 1, accuracy: 1e-6)
        s.undo()
        XCTAssertEqual(s.project.layers.count, 2, "one undo step")
    }

    func testCloseGapAtPlayhead() {
        let s = makeState()
        s.currentTime = 4.5
        XCTAssertEqual(s.gapAtPlayhead(), 4...5)
        s.closeGapAtPlayhead()
        XCTAssertEqual(s.project.layers[1].inPoint, 4, accuracy: 1e-6)
    }

    func testSlipStaysInsideSource() {
        var l = Layer(name: "v", content: .audio(fileName: "a.m4a", duration: 10), outPoint: 4, transform: LayerTransform(position: Animated(Vec2(0, 0))), size: Animated(Vec2(1, 1)))
        l.sourceStart = 1
        XCTAssertEqual(EditorState.slipped(l, by: 2, sourceLength: 10), 3, accuracy: 1e-9)
        XCTAssertEqual(EditorState.slipped(l, by: 20, sourceLength: 10), 6, accuracy: 1e-9)
        XCTAssertEqual(EditorState.slipped(l, by: -5, sourceLength: 10), 0, accuracy: 1e-9)
    }

    func testMultiClipMoveStopsAtZero() {
        let s = makeState()
        s.moveClips(s.project.layers, by: -2)
        XCTAssertEqual(s.project.layers[0].inPoint, 0, accuracy: 1e-6)
        XCTAssertEqual(s.project.layers[1].inPoint, 5, accuracy: 1e-6)
    }

    // MARK: Markers, ruler, history

    func testMarkersSaveAndOldProjectsDecode() throws {
        let s = makeState()
        s.currentTime = 2
        s.addMarker(onLayer: false)
        s.addMarker(onLayer: true)
        let data = try JSONEncoder().encode(s.project)
        let back = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(back.compMarkers?.first?.time ?? -1, 2, accuracy: 1e-6)
        XCTAssertEqual(back.layers[0].layerMarkers?.count, 1)
        XCTAssertTrue(s.namedMarkerTimes.contains { abs($0 - 2) < 1e-6 })
        let old = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(makeState().project))
        XCTAssertNil(old.compMarkers)
    }

    func testRulerFrameLabels() {
        XCTAssertEqual(TimelineRuler.label(1, step: 10.0 / 30, fps: 30, frames: true), "30")
        let step = TimelineRuler.step(zoom: 90, fps: 30, frames: true)
        XCTAssertEqual((step * 30).rounded(), step * 30, accuracy: 1e-9, "frame steps are whole frames")
    }

    func testHistoryHasTimestamps() {
        let s = makeState()
        s.mutate("A") { $0.name = "x" }
        XCTAssertLessThanOrEqual(abs(s.historyDate(at: 0).timeIntervalSinceNow), 5)
    }

    // MARK: Expressions

    func testPickWhipReferenceEvaluates() {
        let s = makeState()
        s.currentTime = 3
        let ref = EditorState.expressionReference(layerName: "a", property: ExpressionResolver.referenceProperties[0])
        s.select(s.project.layers[1].id)
        XCTAssertNil(s.validateExpression(.position, code: ref))
        XCTAssertNotNil(s.validateExpression(.position, code: "thisComp.layer(\"missing\").transform.position"))
        s.setExpression(.position, ref)
        let resolved = ExpressionResolver.resolve(s.project, time: 3)
        XCTAssertEqual(resolved.layers[1].transform.position.staticValue, Vec2(90, 30))
        XCTAssertEqual(s.expressionInventory().count, 1)
    }
}
