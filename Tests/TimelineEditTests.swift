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
}
