import XCTest
import CoreText
@testable import AWIeffect

/// Text Studio state logic (no UI, no GPU).
final class TextStudioTests: XCTestCase {
    private func text(_ s: String) -> TextData {
        var t = TextData(string: s)
        t.ensureCharIDs()
        return t
    }

    func testSelectionAnimatorTargetsSelectedCharIDs() {
        var t = text("HELLO")
        let ids = TextStudioLogic.ids(t, range: 1..<3)
        TextStudioLogic.offsetSelection(&t, ids: ids, by: Vec2(10, -5), at: 0)
        XCTAssertEqual(t.animators.count, 1)
        XCTAssertEqual(t.animators[0].selector.targetIDs, ids)
        XCTAssertEqual(t.animators[0].properties.position?.value(at: 0), Vec2(10, -5))
        // Second drag reuses the same animator and accumulates.
        TextStudioLogic.offsetSelection(&t, ids: ids, by: Vec2(5, 5), at: 0)
        XCTAssertEqual(t.animators.count, 1)
        XCTAssertEqual(t.animators[0].properties.position?.value(at: 0), Vec2(15, 0))
    }

    func testDirectLetterRotationReusesAnimatorAndPreservesPosition() throws {
        var t = text("PHANTOM")
        let ids = TextStudioLogic.ids(t, range: 0..<2)
        TextStudioLogic.offsetSelection(&t, ids: ids, by: Vec2(40, 20), at: 0)
        TextStudioLogic.setSelectionRotation(&t, ids: ids, to: 30, at: 0)
        XCTAssertEqual(t.animators.count, 1)
        XCTAssertEqual(t.animators[0].properties.position?.staticValue, Vec2(40, 20))
        t.animators[0].properties.rotation?.insertKeyframe(Keyframe(time: 0, value: 30, interpolation: .linear))
        TextStudioLogic.setSelectionRotation(&t, ids: ids, to: 120, at: 1)
        XCTAssertEqual(t.animators[0].properties.rotation?.keyframes.count, 2)
        XCTAssertEqual(TextStudioLogic.selectionRotation(t, ids: ids, at: 0.5), 75, accuracy: 1e-8)
        let encoded = try JSONEncoder().encode(t)
        let copy = try JSONDecoder().decode(TextData.self, from: encoded)
        XCTAssertEqual(copy.animators[0].selector.targetIDs, ids)
        XCTAssertEqual(TextStudioLogic.selectionRotation(copy, ids: ids, at: 1), 120)
    }

    func testSelectionSurvivesEditsBeforeIt() {
        var t = text("HELLO")
        let ids = TextStudioLogic.ids(t, range: 3..<5)
        TextStudioLogic.offsetSelection(&t, ids: ids, by: Vec2(1, 1), at: 0)
        t.edit(replacing: 0..<0, with: "OH ")
        XCTAssertEqual(TextStudioLogic.range(t, ids: ids), 6..<8)
        XCTAssertEqual(TextStudioLogic.letters(t, ids: ids), "LO")
        XCTAssertEqual(t.animators[0].selector.targetIDs, ids)
    }

    func testCombinedAmountHitsOnlySelectedLetters() {
        var t = text("ABCD")
        let ids = TextStudioLogic.ids(t, range: 2..<3)
        TextStudioLogic.animateSelection(&t, ids: ids, add: .opacity)
        let a = t.animators[0]
        let all = t.resolvedCharIDs
        let v = all.enumerated().map { i, id in
            SelectorMath.combinedAmount(a, units: { _ in (i, all.count) }, charID: id, time: 0)
        }
        XCTAssertEqual(v, [0, 0, 1, 0])
    }

    func testRemoveProperty() {
        var t = text("AB")
        TextStudioLogic.animateSelection(&t, ids: t.resolvedCharIDs, add: .rotation)
        let id = t.animators[0].id
        TextStudioLogic.addProperty(&t, animator: id, .blur)
        XCTAssertEqual(TextPropKey.present(in: t.animators[0].properties), [.rotation, .blur])
        TextStudioLogic.removeProperty(&t, animator: id, .rotation)
        XCTAssertNil(t.animators[0].properties.rotation)
        XCTAssertEqual(TextPropKey.present(in: t.animators[0].properties), [.blur])
    }

    func testReorderDuplicateDelete() {
        var t = text("AB")
        t.animators = [TextAnimator(name: "A"), TextAnimator(name: "B"), TextAnimator(name: "C")]
        let c = t.animators[2].id
        TextStudioLogic.moveAnimator(&t, c, by: -1)
        XCTAssertEqual(t.animators.map(\.name), ["A", "C", "B"])
        TextStudioLogic.moveAnimator(&t, t.animators[0].id, by: -1)
        XCTAssertEqual(t.animators.map(\.name), ["A", "C", "B"])
        let copy = TextStudioLogic.duplicateAnimator(&t, c)
        XCTAssertEqual(t.animators.map(\.name), ["A", "C", "C copy", "B"])
        XCTAssertNotEqual(copy, c)
        TextStudioLogic.deleteAnimator(&t, c)
        XCTAssertEqual(t.animators.map(\.name), ["A", "C copy", "B"])
    }

    func testSelectorsAddRemoveKeepOne() {
        var t = text("AB")
        t.animators = [TextAnimator(name: "A")]
        let id = t.animators[0].id
        TextStudioLogic.addSelector(&t, animator: id, kind: .random)
        XCTAssertEqual(t.animators[0].allSelectors.count, 2)
        XCTAssertEqual(t.animators[0].allSelectors[1].mode, .intersect)
        TextStudioLogic.removeSelector(&t, animator: id, at: 0)
        XCTAssertEqual(t.animators[0].allSelectors.count, 1)
        XCTAssertEqual(t.animators[0].selector.kind, .random)
        XCTAssertNil(t.animators[0].selector.mode)
        TextStudioLogic.removeSelector(&t, animator: id, at: 0)
        XCTAssertEqual(t.animators[0].allSelectors.count, 1)
    }

    func testPresetGroupRemovalKeepsUserAnimators() {
        var t = text("HELLO")
        t.animators = [TextAnimator(name: "Mine")]
        let g = TextStudioLogic.presetGroup("Fade Up")
        TextStudioLogic.applyPresetGroup(&t, group: g, animators: [TextAnimator(name: "P1"), TextAnimator(name: "P2")])
        XCTAssertEqual(t.animators.count, 3)
        // Re-applying replaces only the group.
        TextStudioLogic.applyPresetGroup(&t, group: g, animators: [TextAnimator(name: "P1")])
        XCTAssertEqual(t.animators.map(\.name), ["Mine", "P1"])
        XCTAssertEqual(TextStudioLogic.presetGroups(t), [g])
        TextStudioLogic.removePresetGroup(&t, group: g)
        XCTAssertEqual(t.animators.map(\.name), ["Mine"])
    }

    func testUnitIndicesAndCaretConversion() {
        let u = TextStudioLogic.unitIndices(Array("ab cd"), basedOn: .words)
        XCTAssertEqual(u.count, 2)
        XCTAssertEqual(u.indices, [0, 0, 0, 1, 1])
        let s = "a😀b"
        XCTAssertEqual(TextStudioLogic.utf16Offset(ofCharacter: 2, in: s), 3)
        XCTAssertEqual(TextStudioLogic.characterIndex(ofUTF16: 3, in: s), 2)
    }

    func testOldProjectTextDecodesWithout3D() throws {
        var p = Project.new(name: "t", width: 100, height: 100, fps: 30, duration: 1, background: .black)
        var l = p.makeLayer(name: "t", content: .text, size: Vec2(10, 10))
        l.text = TextData(string: "Old")
        p.layers = [l]
        let data = try JSONEncoder().encode(p)
        // Strip any 3D key to mimic a save made before 3D text existed.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var layers = try XCTUnwrap(json["layers"] as? [[String: Any]])
        var td = try XCTUnwrap(layers[0]["text"] as? [String: Any])
        td.removeValue(forKey: "text3D")
        layers[0]["text"] = td
        json["layers"] = layers
        let old = try JSONSerialization.data(withJSONObject: json)
        let back = try JSONDecoder().decode(Project.self, from: old)
        XCTAssertNil(back.layers[0].text?.text3D)
        XCTAssertEqual(back.layers[0].text?.string, "Old")
        // And a 3D text round-trips.
        var l3 = back.layers[0]
        l3.text?.text3D = Text3DOptions(material: .gold, extrusion: 60)
        let again = try JSONDecoder().decode(Layer.self, from: JSONEncoder().encode(l3))
        XCTAssertEqual(again.text?.text3D?.extrusion.value(at: 0), 60)
    }

    func testLetterMatrixPlacesOriginWithOffset() {
        let font = CTFontCreateWithName("Helvetica" as CFString, 100, nil)
        let g = LaidGlyph(glyph: 1, font: font, center: Vec2(10, -30), halfSize: Vec2(20, 30), origin: Vec2(-10, 0),
                          charIndex: 0, charExSpaceIndex: 0, wordIndex: 0, lineIndex: 0, isSpace: false)
        var st = Renderer.GlyphState()
        st.offset = Vec2(5, 7)
        let m = Renderer.letterMatrix(g, st)
        let p = m * SIMD4(0.0, 0, 0, 1)
        XCTAssertEqual(p.x, -5, accuracy: 1e-9)
        XCTAssertEqual(p.y, 7, accuracy: 1e-9)
    }
}
