import XCTest
@testable import AWIeffect

/// The graph editor for text: easing on animator properties and on selector timing (Start / End / Offset / Amount).
@MainActor final class TextGraphEditorTests: XCTestCase {
    private func editor() -> (EditorState, UUID) {
        var p = Project.new(name: "g", width: 400, height: 200, fps: 30, duration: 4)
        var l = p.makeLayer(name: "t", content: .text, size: Vec2(1, 1))
        var td = TextData(string: "Hello", fontSize: 60)
        var a = TextAnimator(name: "Move")
        var pos = Animated(Vec2(0, 80)); pos.insertKeyframe(Keyframe(time: 0, value: Vec2(0, 80))); pos.insertKeyframe(Keyframe(time: 1, value: Vec2(0, 0)))
        a.properties.position = pos
        var start = Animated(0.0); start.insertKeyframe(Keyframe(time: 0, value: 0)); start.insertKeyframe(Keyframe(time: 2, value: 100))
        a.selector.start = start
        td.animators = [a]
        l.text = td
        p.layers = [l]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.selectedLayerID = l.id
        return (s, a.id)
    }

    func testPropertyEasingIsEditable() throws {
        let (s, id) = editor()
        XCTAssertEqual(s.textEaseSegments(id, .property(.position)).count, 1)
        let back = try XCTUnwrap(EasePreset.all.first { $0.id == "back" })
        s.setTextEase(id, .property(.position), segment: 0, interpolation: back.interpolation, out: back.out, into: back.into)
        let seg = try XCTUnwrap(s.textEaseSegments(id, .property(.position)).first)
        XCTAssertEqual(seg.interpolation, .bezier)
        XCTAssertEqual(seg.into.y, back.into.y, accuracy: 1e-9, "overshoot handle applied")
        s.undo()
        XCTAssertNotEqual(s.textEaseSegments(id, .property(.position)).first?.into.y ?? 0, back.into.y, "one undo step")
    }

    func testSelectorTimingEasingIsEditable() throws {
        let (s, id) = editor()
        let target = TextEaseTarget.selector(0, .start)
        XCTAssertEqual(s.textEaseSegments(id, target).count, 1)
        s.setTextEase(id, target, segment: nil, interpolation: .hold, out: .linearOut, into: .linearIn)
        XCTAssertEqual(s.textEaseSegments(id, target).first?.interpolation, .hold)
        // The selector's value now holds until the next key.
        let a = try XCTUnwrap(s.selectedLayer?.text?.animators.first)
        XCTAssertEqual(a.selector.start.value(at: 1.5), 0, accuracy: 1e-9)
        XCTAssertTrue(s.textEaseSegments(id, .selector(0, .end)).isEmpty, "End has no keyframes")
    }
}
