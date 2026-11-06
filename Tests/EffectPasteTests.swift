import XCTest
@testable import AWIeffect

@MainActor final class EffectPasteTests: XCTestCase {
    func testPastedEffectKeyframesFollowTheNewLayer() throws {
        var p = Project.new(name: "paste", width: 100, height: 100, fps: 30, duration: 10, background: .black)
        var a = p.makeLayer(name: "a", content: .solid, size: Vec2(50, 50)); a.inPoint = 1; a.outPoint = 4
        var b = p.makeLayer(name: "b", content: .solid, size: Vec2(50, 50)); b.inPoint = 6; b.outPoint = 9
        var blur = EffectRegistry.gaussianBlur.makeInstance()
        var amount = Animated(0.0)
        amount.insertKeyframe(Keyframe(time: 1.5, value: 0)); amount.insertKeyframe(Keyframe(time: 2.5, value: 20))
        blur.params["blurriness"] = .number(amount)
        a.effects = [blur]
        p.layers = [a, b]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.selectedLayerID = a.id; s.copyEffects()
        s.selectedLayerID = b.id; s.pasteEffects()
        let pasted = try XCTUnwrap(s.project.layers[1].effects.first)
        guard case .number(let keys)? = pasted.params["blurriness"] else { return XCTFail() }
        XCTAssertEqual(keys.keyframeTimes, [6.5, 7.5], "0.5 s and 1.5 s into the new layer, like the original")
        XCTAssertNotEqual(pasted.id, blur.id)
        XCTAssertEqual(s.project.layers[0].effects.first?.params, blur.params, "the source is untouched")
        XCTAssertEqual(s.project.layers[1].transform, b.transform, "only the pasted effects move in time")
    }

    func testTransformEffectOffsetIsCappedForControl() throws {
        let def = try XCTUnwrap(EffectRegistry.all.first { $0.params.contains { $0.id == "x" && $0.name == "Position X Offset" } })
        for key in ["x", "y"] {
            guard case .number(let lo, let hi, _, _)? = def.params.first(where: { $0.id == key })?.kind else { return XCTFail() }
            XCTAssertEqual(lo, -5000); XCTAssertEqual(hi, 5000)
        }
    }}
