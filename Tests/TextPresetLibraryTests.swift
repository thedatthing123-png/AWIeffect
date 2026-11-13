import XCTest
@testable import AWIeffect

/// Part 3: the preset library (animations + looks), apply / remove groups, AI Link ids.
final class TextPresetLibraryTests: XCTestCase {
    private static let beats: [Double] = [0.25, 0.75, 1.25]
    private static let times: [Double] = [0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.2, 1.5, 1.9, 2.6]

    private func text(for p: TextPreset) -> TextData {
        var t = TextData(string: "Text Preset\nAMV", fontSize: 60)
        t.animators = p.make(0.1, 1.0)
        return t
    }

    private func frame(_ t: TextData, at time: Double) -> [Double] {
        let layout = TextEngine.shared.layout(t, time: time)
        let states = TextEngine.glyphStates(t, layout: layout, time: time, beats: Self.beats)
        var out: [Double] = []
        out.reserveCapacity(states.count * 32)
        for s in states {
            out.append(s.offset.x); out.append(s.offset.y); out.append(s.scale.x); out.append(s.scale.y)
            out.append(s.rotation); out.append(s.skew); out.append(s.opacity)
            out.append(s.color.r); out.append(s.color.g); out.append(s.color.b); out.append(s.color.a)
            out.append(s.tracking); out.append(s.blur); out.append(s.charOffset)
            out.append(s.rotX); out.append(s.rotY); out.append(s.z); out.append(s.outline)
            out.append(s.anchor.x); out.append(s.anchor.y); out.append(s.tintMix); out.append(s.fillOpacity)
            out.append(s.strokeWidth); out.append(s.strokeMix); out.append(s.glow); out.append(s.hueShift)
            out.append(s.dirBlur); out.append(s.dirBlurAngle); out.append(s.scramble)
            if let c = s.strokeColor { out.append(c.r); out.append(c.g); out.append(c.b) } else { out.append(-1) }
        }
        return out
    }

    private func differs(_ a: [Double], _ b: [Double]) -> Bool {
        guard a.count == b.count else { return true }
        for i in a.indices where abs(a[i] - b[i]) > 1e-6 && !(a[i].isNaN && b[i].isNaN) { return true }
        return false
    }

    /// A preset's preview: frames over the preview time range.
    private func preview(_ p: TextPreset) -> [[Double]] {
        let t = text(for: p)
        return Self.times.map { frame(t, at: $0) }
    }

    // MARK: Catalog

    /// The current set (the full designed library comes with the post-expansion preset pass).
    func testLibraryKeepsTheCurrentPresetsInRealCategories() {
        let all = TextPresetLibrary.animations
        XCTAssertGreaterThanOrEqual(all.count, 150)
        for p in all { XCTAssertTrue(TextPresetLibrary.categories.contains(p.category), "\(p.id) in \(p.category)") }
        for c in TextPresetLibrary.categories { XCTAssertFalse(TextPresetLibrary.presets(in: c).isEmpty, c) }
        XCTAssertEqual(TextPreset.library.count, all.count)
    }

    func testIDsAndNamesAreUnique() {
        let ids = TextPresetLibrary.animations.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        let names = TextPresetLibrary.animations.map { $0.name.lowercased() }
        XCTAssertEqual(Set(names).count, names.count, "duplicate names")
        let lookIDs = TextPresetLibrary.looks.map(\.id)
        XCTAssertEqual(Set(lookIDs).count, lookIDs.count)
        let lookNames = TextPresetLibrary.looks.map { $0.name.lowercased() }
        XCTAssertEqual(Set(lookNames).count, lookNames.count)
    }

    func testEveryOlderPresetIDStillResolves() {
        let older = TextPresets.all.map(\.id) + TextPresetStudio.all.map(\.id) + TextPresetPack.all.map(\.id)
        for id in older { XCTAssertNotNil(TextPresetLibrary.animation(id), id) }
        for id in ["typewriter", "scalePop", "karaoke", "impactSlam", "studio.lineRise", "pack.in.fade.random", "pack.3d.flipX", "pack.kin.sfx"] {
            XCTAssertNotNil(TextPresetLibrary.animation(id), id)
            XCTAssertNotNil(TextPreset.library.first { $0.id == id }, id)
        }
        for s in TitleStyles.all { if let a = s.animation { XCTAssertNotNil(TextPresetLibrary.animation(a), a) } }
    }

    func testWordsLabelMatchesWordSelectors() {
        for p in TextPresetLibrary.animations where p.name.contains("Words") {
            let units = p.make(0, 1).flatMap { $0.allSelectors.map(\.basedOn) }
            XCTAssertTrue(units.contains(.words), "\(p.name) says Words but selects \(units)")
        }
    }

    // MARK: Motion

    func testEveryPresetAnimates() {
        for p in TextPresetLibrary.animations {
            let frames = preview(p)
            let moving = frames.dropFirst().contains { differs($0, frames[0]) }
            XCTAssertTrue(moving, "\(p.id) (\(p.name)) does not change over time")
        }
    }

    func testPreviewsAreDistinctWithinEachCategory() {
        for c in TextPresetLibrary.categories {
            let list = TextPresetLibrary.presets(in: c)
            let previews = list.map { preview($0).flatMap { $0 } }
            for i in list.indices {
                for j in list.indices where j > i {
                    XCTAssertTrue(differs(previews[i], previews[j]), "\(c): \(list[i].id) looks the same as \(list[j].id)")
                }
            }
        }
    }

    // MARK: Apply / remove

    private func textLayer(_ string: String = "Hello there", outPoint: Double = 10) -> Layer {
        var p = Project.new(name: "t", width: 400, height: 200, fps: 30, duration: outPoint)
        var l = p.makeLayer(name: "t", content: .text, size: Vec2(1, 1))
        l.text = TextData(string: string, fontSize: 60)
        return l
    }

    func testApplyKeepsUserAnimatorsAndRemoveTakesOnlyTheGroup() throws {
        var l = textLayer()
        var mine = TextAnimator(name: "Mine")
        mine.properties.position = Animated(Vec2(0, 10))
        l.text!.animators = [mine]
        let a = try XCTUnwrap(TextPresetLibrary.animation("impactSlam"))
        let b = try XCTUnwrap(TextPresetLibrary.animation("typewriter"))
        XCTAssertTrue(TextPresetLibrary.applyPreset(a, to: &l, start: 1, duration: 1))
        TextPresetLibrary.applyPreset(b, to: &l, start: 2)
        let anims = l.text!.animators
        XCTAssertEqual(anims.first?.id, mine.id)
        XCTAssertEqual(anims.filter { $0.group == a.id }.count, a.make(1, 1).count)
        XCTAssertEqual(anims.filter { $0.group == b.id }.count, b.make(2, 1).count)
        // Re-applying creates another removable instance instead of silently deleting the first one.
        TextPresetLibrary.applyPreset(a, to: &l, start: 3, duration: 0.5)
        XCTAssertEqual(l.text!.animators.filter { $0.group == a.id }.count, a.make(3, 0.5).count)
        XCTAssertEqual(l.text!.animators.filter { $0.group == a.id + "#2" }.count, a.make(3, 0.5).count)
        XCTAssertEqual(l.text!.animators.count, anims.count + a.make(3, 0.5).count)
        TextPresetLibrary.removePresetGroup(a.id, from: &l)
        XCTAssertEqual(l.text!.animators.map(\.id).first, mine.id)
        XCTAssertTrue(l.text!.animators.allSatisfy { $0.group == nil || $0.group == b.id || $0.group == a.id + "#2" })
        XCTAssertFalse(l.text!.animators.contains { $0.group == a.id })
        XCTAssertEqual(TextPresetLibrary.groups(in: l), [b.id, a.id + "#2"])
    }

    func testDefaultDurationIsOneSecondOrWhatIsLeft() {
        let l = textLayer(outPoint: 10)
        XCTAssertEqual(TextPresetLibrary.defaultDuration(for: l, start: 2), 1, accuracy: 1e-9)
        XCTAssertEqual(TextPresetLibrary.defaultDuration(for: l, start: 9.6), 0.4, accuracy: 1e-9)
    }

    func testSnapToBeatsMovesStartAndEnd() throws {
        var l = textLayer()
        let p = try XCTUnwrap(TextPresetLibrary.animation("studio.lineRise"))
        TextPresetLibrary.applyPreset(p, to: &l, start: 1.05, duration: 1, snapToBeats: [1.0, 1.8, 3])
        let sel = try XCTUnwrap(l.text!.animators.first?.selector)
        XCTAssertEqual(sel.start.keyframes.first?.time ?? -1, 1.0, accuracy: 1e-9)
        XCTAssertEqual(sel.start.keyframes.last?.time ?? -1, 1.8, accuracy: 1e-9)
    }

    func testLookReplacesOnlyLookPartsAndRemoves() throws {
        var l = textLayer()
        var userStack = TextStyleStack()
        userStack.strokes = [TextStrokeLayer(color: .black, width: 3)]
        l.text!.style = userStack
        var mine = TextAnimator(name: "Mine")
        mine.properties.opacity = Animated(50)
        l.text!.animators = [mine]
        let userEffectCount = l.effects.count
        var aStack = TextStyleStack(); aStack.strokes = [TextStrokeLayer(color: .white, width: 8)]
        let a = TextLookPreset(id: "look.testStroke", name: "Test Stroke", category: "Test", font: nil, style: aStack,
                               effects: [], text3D: nil, tracking: nil)
        let b = TextLookPreset(id: "look.testGold", name: "Test Gold", category: "Test", font: nil, style: TextStyleStack(),
                               effects: [], text3D: Text3DOptions(material: .gold), tracking: nil)
        TextPresetLibrary.applyLook(a, to: &l)
        XCTAssertEqual(l.text!.style!.strokes.count, 1 + a.style.strokes.count)
        XCTAssertEqual(l.text!.animators.map(\.id), [mine.id])
        TextPresetLibrary.applyLook(b, to: &l)
        XCTAssertFalse(l.text!.style!.strokes.contains { $0.group == a.id }, "earlier look parts replaced")
        XCTAssertTrue(l.text!.style!.strokes.contains { $0.group == nil }, "user stroke kept")
        XCTAssertNotNil(l.text!.text3D)
        XCTAssertEqual(l.text!.text3D?.front, Text3DMaterial.gold)
        TextPresetLibrary.removePresetGroup(b.id, from: &l)
        XCTAssertNil(l.text!.text3D)
        XCTAssertEqual(l.text!.style?.strokes.count, 1)
        XCTAssertEqual(l.effects.count, userEffectCount)
        XCTAssertEqual(l.text!.animators.map(\.id), [mine.id])
    }

    func testPresetGroupsSurviveSaveAndOldTextStillDecodes() throws {
        var l = textLayer()
        TextPresetLibrary.applyLook(TextLookPreset(id: "look.testChrome", name: "Test Chrome", category: "Test", font: nil,
                                                   style: TextStyleStack(fills: [TextFillLayer(kind: .solid, colors: [RGBA(1, 1, 1)])]), effects: [], text3D: Text3DOptions(material: .chrome),
                                                   tracking: nil), to: &l)
        TextPresetLibrary.applyPreset(try XCTUnwrap(TextPresetLibrary.animation("pack.3d.flipX")), to: &l, start: 0)
        let back = try JSONDecoder().decode(TextData.self, from: JSONEncoder().encode(l.text!))
        XCTAssertEqual(back.text3DGroup, "look.testChrome")
        XCTAssertEqual(back.style?.fills.first?.group, "look.testChrome")
        XCTAssertEqual(back.animators.first?.group, "pack.3d.flipX")
        let old = try JSONDecoder().decode(TextData.self, from: Data(#"{"string":"Hi"}"#.utf8))
        XCTAssertNil(old.text3D)
        XCTAssertNil(old.text3DGroup)
    }

    func testTitleStyleKeepsUserAnimators() throws {
        var l = textLayer()
        let mine = TextAnimator(name: "Mine")
        l.text!.animators = [mine]
        let style = try XCTUnwrap(TitleStyles.all.first { $0.animation != nil })
        style.apply(to: &l, start: 0)
        XCTAssertEqual(l.text!.animators.first?.id, mine.id)
        XCTAssertGreaterThan(l.text!.animators.count, 1)
    }

    // MARK: Previews

    func testPreviewCacheIsBoundedLRU() {
        let c = TextPresetLRU<Int>(capacity: 3)
        c.set("a", 1); c.set("b", 2); c.set("c", 3)
        XCTAssertEqual(c.get("a"), 1)
        c.set("d", 4)
        XCTAssertNil(c.get("b"), "least recently used evicted")
        XCTAssertEqual(c.get("a"), 1)
        XCTAssertEqual(c.count, 3)
    }

    func testPreviewUsesTheLayersOwnTextAndFont() throws {
        var l = textLayer("Sakura Drop")
        l.text!.fontName = "AvenirNext-Heavy"
        let src = TextPresetPreviewSource(layer: l)
        XCTAssertEqual(src.string, "Sakura Drop")
        XCTAssertEqual(src.fontName, "AvenirNext-Heavy")
        XCTAssertEqual(TextPresetPreviewSource(layer: nil).string, "Text")
        let p = TextPresetBrowserPreviews.project(for: .animation(try XCTUnwrap(TextPresetLibrary.animation("studio.lineRise"))), source: src)
        XCTAssertEqual(p.layers.first?.text?.string, "Sakura Drop")
        XCTAssertEqual(p.layers.first?.text?.fontName, "AvenirNext-Heavy")
        XCTAssertFalse(p.layers.first?.text?.animators.isEmpty ?? true)
    }

    func testPreviewRendersAnimatedFrames() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let p = TextPresetBrowserPreviews.project(for: .animation(try XCTUnwrap(TextPresetLibrary.animation("impactSlam"))),
                                            source: TextPresetPreviewSource(layer: nil))
        let a = r.renderImage(project: p, time: 0.2, maxDimension: 160, mediaURL: { URL(fileURLWithPath: $0) })
        let b = r.renderImage(project: p, time: 1.4, maxDimension: 160, mediaURL: { URL(fileURLWithPath: $0) })
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertNotEqual(a?.pngData(), b?.pngData())
    }
}
