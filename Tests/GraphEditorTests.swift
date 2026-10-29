import XCTest
@testable import AWIeffect

@MainActor
final class GraphEditorTests: XCTestCase {
    private func state() -> EditorState {
        var p = Project.new(name: "g", width: 100, height: 100, fps: 30, duration: 4)
        var l = p.makeLayer(name: "l", content: .solid, size: Vec2(10, 10))
        l.transform.rotation.insertKeyframe(Keyframe(time: 0, value: 0))
        l.transform.rotation.insertKeyframe(Keyframe(time: 1, value: 90))
        l.transform.rotation.insertKeyframe(Keyframe(time: 2, value: 0))
        p.layers = [l]
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let s = EditorState(project: p, store: ProjectStore(root: dir))
        s.select(l.id)
        return s
    }

    func testSegmentsListed() {
        let s = state()
        XCTAssertEqual(s.easeSegments(.rotation).count, 2)
        XCTAssertEqual(s.animatedKeys, [.rotation])
    }

    func testPresetChangesOnlyChosenSegment() {
        let s = state()
        let snap = EasePreset.all.first { $0.id == "snap" }!
        s.setEase(.rotation, segment: 0, interpolation: .bezier, out: snap.out, into: snap.into)
        let segs = s.easeSegments(.rotation)
        XCTAssertEqual(segs[0].interpolation, .bezier)
        XCTAssertEqual(segs[0].out, snap.out)
        XCTAssertEqual(segs[1].interpolation, .linear)
        // Snap = extreme ease in-out: nearly still at 20%, nearly done at 80%, halfway at the midpoint.
        let rot = s.project.layers[0].transform.rotation
        XCTAssertLessThan(rot.value(at: 0.2), 10)
        XCTAssertGreaterThan(rot.value(at: 0.8), 80)
        XCTAssertEqual(rot.value(at: 0.5), 45, accuracy: 1)
    }

    func testOvershootPresetOvershoots() {
        let s = state()
        let back = EasePreset.all.first { $0.id == "back" }!
        s.setEase(.rotation, segment: nil, interpolation: .bezier, out: back.out, into: back.into)
        let peak = stride(from: 0.5, through: 1.0, by: 0.01).map { s.project.layers[0].transform.rotation.value(at: $0) }.max()!
        XCTAssertGreaterThan(peak, 90)
    }

    func testEasingIsUndoable() {
        let s = state()
        s.setEase(.rotation, segment: 0, interpolation: .hold, out: .linearOut, into: .linearIn)
        XCTAssertEqual(s.easeSegments(.rotation)[0].interpolation, .hold)
        s.undo()
        XCTAssertEqual(s.easeSegments(.rotation)[0].interpolation, .linear)
    }
}
