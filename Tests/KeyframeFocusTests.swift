import XCTest
@testable import AWIeffect

@MainActor final class KeyframeFocusTests: XCTestCase {
    private func setup() -> (EditorState, UUID) {
        var p = Project.new(name: "focus", width: 100, height: 100, fps: 30, duration: 6, background: .black)
        var l = p.makeLayer(name: "l", content: .solid, size: Vec2(50, 50)); l.inPoint = 0; l.outPoint = 6
        for t in [1.0, 3] { l.transform.opacity.insertKeyframe(Keyframe(time: t, value: t * 20)) }
        var glow = EffectRegistry.gaussianBlur.makeInstance()
        var a = Animated(0.0)
        for t in [1.0, 2] { a.insertKeyframe(Keyframe(time: t, value: t * 5)) }
        glow.params["blurriness"] = .number(a)
        l.effects = [glow]
        p.layers = [l]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.selectedLayerID = l.id
        return (s, glow.id)
    }

    private func blurTimes(_ s: EditorState) -> [Double] {
        guard case .number(let a)? = s.project.layers[0].effects[0].params["blurriness"] else { return [] }
        return a.keyframeTimes
    }

    func testOpenEffectMovesOnlyItsOwnKeys() {
        let (s, effect) = setup()
        XCTAssertEqual(s.project.layers[0].keyframeMarkers(effect: effect).map(\.time), [1, 2])
        s.moveKeyframes(of: s.project.layers[0], from: 1, to: 1.5, effect: effect)
        XCTAssertEqual(blurTimes(s), [1.5, 2])
        XCTAssertEqual(s.project.layers[0].transform.opacity.keyframeTimes, [1, 3], "opacity shares the time but stays put")
    }

    func testKeysCanLandOnTheSameTimeAsOthers() {
        let (s, effect) = setup()
        // The blur key at 2 goes onto 3, where opacity has a key: both now sit at 3.
        s.moveKeyframes(of: s.project.layers[0], from: 2, to: 3, effect: effect)
        XCTAssertEqual(blurTimes(s), [1, 3])
        XCTAssertEqual(s.project.layers[0].transform.opacity.keyframeTimes, [1, 3])
        // Without focus, every property at 1 moves together; landing on another key of the same property is
        // rejected so nothing is deleted.
        s.moveKeyframes(of: s.project.layers[0], from: 1, to: 3)
        XCTAssertEqual(s.project.layers[0].transform.opacity.keyframeTimes, [1, 3], "no key was replaced")
        XCTAssertEqual(blurTimes(s), [1, 3])
    }

    func testFocusClearsWhenLeavingEffectsOrChangingLayer() {
        let (s, effect) = setup()
        s.panel = .effects
        s.keyframeFocusEffects = [effect]
        s.panel = .graph
        XCTAssertEqual(s.keyframeFocusEffects, [effect], "the graph editor keeps the focus")
        s.panel = .transform
        XCTAssertTrue(s.keyframeFocusEffects.isEmpty)
        s.keyframeFocusEffects = [effect]
        s.selectedLayerID = nil
        XCTAssertTrue(s.keyframeFocusEffects.isEmpty)
    }
}
