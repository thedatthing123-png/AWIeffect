import XCTest
@testable import AWIeffect

@MainActor
final class TimelineEditTests: XCTestCase {
    private func state() -> EditorState {
        var p = Project.new(name: "t", width: 100, height: 100, fps: 30, duration: 10, background: .black)
        var a = p.makeLayer(name: "a", content: .solid, size: Vec2(10, 10))
        a.inPoint = 1; a.outPoint = 3
        a.transform.opacity.insertKeyframe(Keyframe(time: 1.5, value: 0, interpolation: .linear))
        a.transform.opacity.insertKeyframe(Keyframe(time: 2.5, value: 100, interpolation: .linear))
        let b = p.makeLayer(name: "b", content: .solid, size: Vec2(10, 10))
        p.layers = [a, b]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.select(a.id)
        return s
    }

    func testMoveClipCarriesKeyframes() {
        let s = state()
        let o = s.project.layers[0]
        s.moveClip(o, by: 2)
        let l = s.project.layers[0]
        XCTAssertEqual(l.inPoint, 3, accuracy: 1e-6); XCTAssertEqual(l.outPoint, 5, accuracy: 1e-6)
        XCTAssertEqual(l.transform.opacity.keyframes.map(\.time), [3.5, 4.5])
    }

    func testMoveClipStopsAtZero() {
        let s = state()
        s.moveClip(s.project.layers[0], by: -5)
        XCTAssertEqual(s.project.layers[0].inPoint, 0, accuracy: 1e-6)
    }

    func testTrimStartAdvancesSource() {
        let s = state()
        s.mutate("speed") { $0.layers[0].speed = 2 }
        s.trimClip(s.project.layers[0], start: true, by: 0.5)
        let l = s.project.layers[0]
        XCTAssertEqual(l.inPoint, 1.5, accuracy: 1e-6)
        XCTAssertEqual(l.sourceStart, 1.0, accuracy: 1e-6, "media must keep showing the same frames")
        s.trimClip(s.project.layers[0], start: false, by: -0.5)
        XCTAssertEqual(s.project.layers[0].outPoint, 2.5, accuracy: 1e-6)
    }

    func testTrimNeverInverts() {
        let s = state()
        s.trimClip(s.project.layers[0], start: false, by: -10)
        XCTAssertGreaterThan(s.project.layers[0].outPoint, s.project.layers[0].inPoint)
    }

    func testReorder() {
        let s = state()
        s.reorderLayer(from: 0, to: 1)
        XCTAssertEqual(s.project.layers.map(\.name), ["b", "a"])
        s.undo()
        XCTAssertEqual(s.project.layers.map(\.name), ["a", "b"])
    }

    func testMoveKeyframes() {
        let s = state()
        s.moveKeyframes(of: s.project.layers[0], from: 1.5, to: 2)
        XCTAssertEqual(s.project.layers[0].transform.opacity.keyframes.map(\.time), [2, 2.5])
    }

    func testCopyPasteKeys() {
        let s = state()
        s.mutateLayer { $0.transform.position = Animated(Vec2(10, 20)) }
        s.copyKeyframes()
        s.select(s.project.layers[1].id)
        s.seek(4)
        s.pasteKeyframes()
        XCTAssertTrue(s.project.layers[1].transform.position.hasKeyframe(at: 4))
        XCTAssertEqual(s.project.layers[1].transform.position.value(at: 4), Vec2(10, 20))
    }

    // MARK: Parenting

    func testParentingKeepsPlaceAndFollows() {
        let s = state()
        s.mutate("place") { p in
            p.layers[0].transform.position = Animated(Vec2(30, 30))
            p.layers[1].transform.position = Animated(Vec2(60, 50))
        }
        let child = s.project.layers[0].id, parent = s.project.layers[1].id
        s.select(child)
        s.setParent(parent)
        let world = { Renderer.resolveParenting(s.project, time: s.currentTime).layers.first { $0.id == child }!.transform.position.value(at: s.currentTime) }
        XCTAssertEqual(world().x, 30, accuracy: 0.01); XCTAssertEqual(world().y, 30, accuracy: 0.01)
        // Move + rotate the parent: the child follows.
        s.mutate("move parent") { p in p.layers[1].transform.position = Animated(Vec2(70, 50)); p.layers[1].transform.rotation = Animated(90) }
        // Child was at (-30, -20) from the parent; rotated 90° clockwise (y down) -> (20, -30).
        XCTAssertEqual(world().x, 90, accuracy: 0.01); XCTAssertEqual(world().y, 20, accuracy: 0.01)
        // Unparent keeps the current world position.
        s.setParent(nil)
        XCTAssertEqual(s.project.layers[0].transform.position.value(at: s.currentTime).x, 90, accuracy: 0.01)
    }

    func testParentCycleRejected() {
        let s = state()
        let a = s.project.layers[0].id, b = s.project.layers[1].id
        s.select(a); s.setParent(b)
        s.select(b); s.setParent(a)
        XCTAssertNil(s.project.layers[1].parentID)
    }

    func testAutoLengthFollowsLayers() {
        var p = Project.new(name: "a", width: 100, height: 100, fps: 30, duration: 10)
        p.autoLength = true
        var l = p.makeLayer(name: "clip", content: .solid, size: Vec2(10, 10))
        l.outPoint = 4
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.mutate("add") { $0.layers = [l] }
        XCTAssertEqual(s.project.duration, 4, accuracy: 1e-6)
        s.select(s.project.layers[0].id)
        s.trimClip(s.project.layers[0], start: false, by: 3)
        XCTAssertEqual(s.project.duration, 7, accuracy: 0.05, "project grows with the clip")
        s.trimClip(s.project.layers[0], start: false, by: -5)
        XCTAssertEqual(s.project.duration, 2, accuracy: 0.05, "and shrinks with it")
    }

    func testLiveCanvasDragCommitsOnceOnRelease() {
        let s = state()
        let before = s.project.layers[0].transform.position.value(at: s.currentTime)
        s.beginEdit("Move Layer"); s.beginLiveGesture()
        for k in 1...20 { s.mutateLayer { $0.transform.position.set(Vec2(Double(k), 5), at: 0) } }
        XCTAssertEqual(s.project.layers[0].transform.position.value(at: s.currentTime), before, "project untouched mid-drag")
        XCTAssertEqual(s.canvasProject.layers[0].transform.position.value(at: s.currentTime), Vec2(20, 5))
        s.endCanvasDrag()
        XCTAssertNil(s.live.project)
        XCTAssertEqual(s.project.layers[0].transform.position.value(at: s.currentTime), Vec2(20, 5))
        s.undo()
        XCTAssertEqual(s.project.layers[0].transform.position.value(at: s.currentTime), before, "one undo step for the whole drag")
    }
}
