import XCTest
import simd
@testable import AWIeffect

/// Text Studio Part 1: ids, migration, selectors, animated bounds, style stack, real per-letter 3D.
final class TextStudioEngineTests: XCTestCase {
    private let green = RGBA(0, 1, 0)

    // MARK: Stable ids

    func testSpanStaysOnItsLettersAfterEdits() {
        var t = TextData(string: "Hello World", fontSize: 40)
        t.colorSpans = [TextColorSpan(start: 6, end: 11, color: green)]
        t.edit(replacing: 6..<6, with: "Big ")                    // "Hello Big World"
        XCTAssertEqual(t.string, "Hello Big World")
        XCTAssertEqual(t.baseColor(forCharacter: 6, time: 0), t.fill.value(at: 0), "inserted letter took the span color")
        XCTAssertEqual(t.baseColor(forCharacter: 10, time: 0), green, "W lost its color")
        XCTAssertEqual(t.colorSpans.first?.start, 10)
        t.edit(replacing: 0..<6, with: "")                        // "Big World"
        XCTAssertEqual(t.baseColor(forCharacter: 4, time: 0), green)
        t.setString("Big Worlds")
        XCTAssertEqual(t.baseColor(forCharacter: 8, time: 0), green)
        XCTAssertNotEqual(t.baseColor(forCharacter: 9, time: 0), green)
        XCTAssertEqual(t.charIDs?.count, t.string.count)
        XCTAssertEqual(Set(t.charIDs ?? []).count, t.string.count, "ids must be unique")
    }

    func testDeletingAllSpanLettersRemovesSpan() {
        var t = TextData(string: "AB CD")
        t.colorSpans = [TextColorSpan(start: 3, end: 5, color: green)]
        t.edit(replacing: 3..<5, with: "")
        XCTAssertTrue(t.colorSpans.isEmpty)
    }

    func testOldProjectMigratesSpansAndLetterAnimators() throws {
        var old = TextData(string: "ABCD", fontSize: 40)
        old.colorSpans = [TextColorSpan(start: 1, end: 2, color: green)]
        var a = TextAnimator(name: TextData.styleAnimatorPrefix + "2-4")
        a.selector.shape = .square
        a.selector.start = Animated(50)
        a.selector.end = Animated(100)
        a.properties.scale = Animated(Vec2(150, 150))
        old.animators = [a]
        let data = try JSONEncoder().encode(old)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("charIDs"), "old fixture must have no ids")
        var t = try JSONDecoder().decode(TextData.self, from: data)
        XCTAssertEqual(t.charIDs?.count, 4)
        XCTAssertEqual(t.colorSpans.first?.ids, [t.charIDs![1]])
        XCTAssertEqual(t.animators.first?.selector.targetIDs, [t.charIDs![2], t.charIDs![3]])
        // Same look as before migration: the same letters are picked.
        let lay = TextEngine.shared.layout(t, time: 0)
        let picked = lay.glyphs.map { TextEngine.selection(t.animators[0], glyph: $0, layout: lay, time: 0, beats: []) }
        XCTAssertEqual(picked, [0, 0, 1, 1])
        // And it stays on C/D after typing in front.
        t.setString("xxABCD")
        let lay2 = TextEngine.shared.layout(t, time: 0)
        let picked2 = lay2.glyphs.map { TextEngine.selection(t.animators[0], glyph: $0, layout: lay2, time: 0, beats: []) }
        XCTAssertEqual(picked2, [0, 0, 0, 0, 1, 1])
        // Round trip keeps everything.
        let again = try JSONDecoder().decode(TextData.self, from: JSONEncoder().encode(t))
        XCTAssertEqual(again, t)
    }

    // MARK: Selectors

    private func units(_ i: Int, _ n: Int) -> (TextSelector) -> (index: Int, count: Int) { { _ in (i, n) } }

    func testMultipleSelectorsCombine() {
        var a = TextAnimator(name: "x")
        a.selector.start = Animated(0); a.selector.end = Animated(50)
        var b = TextSelector()
        b.start = Animated(25); b.end = Animated(100)
        b.mode = .intersect
        a.selectors = [b]
        let v = (0..<4).map { SelectorMath.combinedAmount(a, units: units($0, 4), charID: 0, time: 0) }
        XCTAssertEqual(v, [0, 1, 0, 0])
        a.setSelector(1) { $0.mode = .subtract }
        let w = (0..<4).map { SelectorMath.combinedAmount(a, units: units($0, 4), charID: 0, time: 0) }
        XCTAssertEqual(w, [1, 0, -1, -1])
        XCTAssertEqual(a.allSelectors.count, 2)
    }

    func testRandomSelectorIsStableAndInRange() {
        var s = TextSelector()
        s.kind = .random
        s.minAmount = 20; s.maxAmount = 60
        let v = (0..<30).map { SelectorMath.amount(s, index: $0, count: 30, time: 0) }
        XCTAssertTrue(v.allSatisfy { $0 >= 0.2 - 1e-9 && $0 <= 0.6 + 1e-9 })
        XCTAssertGreaterThan(Set(v).count, 10)
        XCTAssertEqual(v, (0..<30).map { SelectorMath.amount(s, index: $0, count: 30, time: 3) })
    }

    func testBeatSelectorPulsesOnBeats() {
        var s = TextSelector()
        s.kind = .beat
        let beats = [1.0]
        XCTAssertEqual(SelectorMath.amount(s, index: 0, count: 1, time: 1.0, beats: beats), 1, accuracy: 1e-6)
        XCTAssertLessThan(SelectorMath.amount(s, index: 0, count: 1, time: 1.3, beats: beats), 0.5)
        XCTAssertEqual(SelectorMath.amount(s, index: 0, count: 1, time: 0.5, beats: beats), 0)
    }

    func testAnimatedSelectorValues() {
        var s = TextSelector()
        s.kind = .wiggly
        var maxA = Animated(0.0)
        maxA.insertKeyframe(Keyframe(time: 0, value: 0.0))
        maxA.insertKeyframe(Keyframe(time: 1, value: 100.0))
        s.maxAmountAnim = maxA
        s.minAmountAnim = Animated(0)
        XCTAssertEqual(SelectorMath.amount(s, index: 2, count: 5, time: 0), 0, accuracy: 1e-9)
    }

    // MARK: Bounds

    func testAnimatedBoundsContainMovedLetters() {
        var t = TextData(string: "AB", fontSize: 60)
        var a = TextAnimator(name: "Fly")
        a.properties.position = Animated(Vec2(0, -500))
        a.properties.scale = Animated(Vec2(300, 300))
        t.animators = [a]
        let lay = TextEngine.shared.layout(t, time: 0)
        let b = TextEngine.animatedBounds(t, layout: lay, time: 0)
        XCTAssertLessThan(b.minY, lay.bounds.minY - 400)
        XCTAssertTrue(b.contains(lay.bounds))
    }

    func testStyleStackWidensBounds() {
        var t = TextData(string: "A", fontSize: 60)
        let lay = TextEngine.shared.layout(t, time: 0)
        let plain = TextEngine.animatedBounds(t, layout: lay, time: 0)
        t.style = TextStyleStack(strokes: [TextStrokeLayer(width: 30)], shadows: [TextShadowLayer(distance: 40, blur: 4)])
        let styled = TextEngine.animatedBounds(t, layout: lay, time: 0)
        XCTAssertGreaterThan(styled.width, plain.width + 50)
    }

    // MARK: Real per-letter 3D

    func testLetterTurnedSixtyDegreesIsNarrowerAndTrapezoidal() throws {
        let t = TextData(string: "H", fontSize: 200)
        let lay = TextEngine.shared.layout(t, time: 0)
        let g = try XCTUnwrap(lay.glyphs.first)
        var st = Renderer.GlyphState()
        let flat = try XCTUnwrap(TextEngine.placement(g, st, layout: lay, track: nil))
        st.rotY = 60
        let turned = try XCTUnwrap(TextEngine.placement(g, st, layout: lay, track: nil))
        func project(_ H: simd_double3x3, _ x: Double, _ y: Double) -> SIMD2<Double> {
            let p = H * SIMD3(x, y, 1); return SIMD2(p.x, p.y) / p.z
        }
        let h = g.halfSize
        let w0 = project(flat, h.x, 0).x - project(flat, -h.x, 0).x
        let w1 = project(turned, h.x, 0).x - project(turned, -h.x, 0).x
        XCTAssertLessThan(abs(w1), abs(w0) * 0.7)
        let leftH = project(turned, -h.x, h.y).y - project(turned, -h.x, -h.y).y
        let rightH = project(turned, h.x, h.y).y - project(turned, h.x, -h.y).y
        XCTAssertGreaterThan(abs(leftH - rightH), 0.5, "no perspective: the turned letter is not a trapezoid")
        // No 3D -> plain affine (old projects look the same).
        XCTAssertEqual(flat[0][2], 0, accuracy: 1e-12)
        XCTAssertEqual(flat[2][2], 1, accuracy: 1e-12)
    }

    // MARK: Paragraph

    func testBoxWidthWrapsAndAutoFitShrinks() {
        var t = TextData(string: "one two three four five six", fontSize: 40)
        let single = TextEngine.shared.layout(t, time: 0)
        XCTAssertEqual(single.lineCount, 1)
        t.boxWidth = 200
        let wrapped = TextEngine.shared.layout(t, time: 0)
        XCTAssertGreaterThan(wrapped.lineCount, 1)
        XCTAssertLessThanOrEqual(wrapped.lineWidths.max() ?? 0, 201)
        t.autoFit = true
        let fit = TextEngine.shared.layout(t, time: 0)
        XCTAssertEqual(fit.lineCount, 1)
        XCTAssertLessThanOrEqual(fit.lineWidths.max() ?? 0, 205)
    }

    func testVerticalTextStacksDown() {
        var t = TextData(string: "AB漢", fontSize: 40)
        t.vertical = true
        let l = TextEngine.shared.layout(t, time: 0)
        XCTAssertEqual(l.glyphs.count, 3)
        XCTAssertLessThan(l.glyphs[0].center.y, l.glyphs[2].center.y)
        XCTAssertEqual(l.glyphs[0].baseRotation, .pi / 2, accuracy: 1e-9)
        XCTAssertEqual(l.glyphs[2].baseRotation, 0)
    }

    func testCharStyleSizeOverrideGrowsLetter() {
        var t = TextData(string: "AA", fontSize: 40)
        t.setCharStyle(1..<2) { $0.sizePercent = 200 }
        let l = TextEngine.shared.layout(t, time: 0)
        XCTAssertGreaterThan(l.glyphs[1].halfSize.y, l.glyphs[0].halfSize.y * 1.6)
    }

    // MARK: Keyframe tools see new fields

    func testTraversalVisitsNewAnimatedFields() {
        var p = Project.new(name: "t", width: 100, height: 100, fps: 30, duration: 2, background: .black)
        var l = p.makeLayer(name: "t", content: .text, size: Vec2(1, 1))
        var t = TextData(string: "Hi")
        var stroke = TextStrokeLayer()
        stroke.width.insertKeyframe(Keyframe(time: 0.7, value: 3.0))
        t.style = TextStyleStack(strokes: [stroke])
        var a = TextAnimator(name: "a")
        var sel = TextSelector()
        var ease = Animated(0.0)
        ease.insertKeyframe(Keyframe(time: 1.3, value: 50.0))
        sel.easeHighAnim = ease
        a.selectors = [sel]
        var glow = Animated(0.0)
        glow.insertKeyframe(Keyframe(time: 1.6, value: 80.0))
        a.properties.glow = glow
        t.animators = [a]
        l.text = t
        p.layers = [l]
        var visit = AnimationTraversal(operation: .inspect)
        p.layers[0].traverseAnimations(&visit)
        for time in [0.7, 1.3, 1.6] {
            XCTAssertTrue(visit.times.contains { abs($0 - time) < 1e-9 }, "keyframe at \(time) not visited")
        }
    }

    // MARK: Rendering (GPU)

    private func render(_ p: Project) throws -> [UInt8] {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device") }
        return try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    private func project(_ t: TextData, width: Int = 320, height: Int = 160) -> Project {
        var p = Project.new(name: "t", width: width, height: height, fps: 30, duration: 1, background: .black)
        var l = p.makeLayer(name: "t", content: .text, size: Vec2(1, 1))
        l.text = t
        p.layers = [l]
        return p
    }

    func testStrokeStackRenders() throws {
        var t = TextData(string: "O", fontSize: 90)
        t.fill = Animated(RGBA(1, 1, 1))
        t.style = TextStyleStack(strokes: [TextStrokeLayer(color: RGBA(1, 0, 0), width: 6),
                                           TextStrokeLayer(color: RGBA(0, 0, 1), width: 14)])
        let px = try render(project(t))
        var red = 0, blue = 0, white = 0
        for i in stride(from: 0, to: px.count, by: 4) {
            if px[i] > 150 && px[i + 1] < 80 && px[i + 2] < 80 { red += 1 }
            if px[i + 2] > 150 && px[i] < 80 && px[i + 1] < 80 { blue += 1 }
            if px[i] > 200 && px[i + 1] > 200 && px[i + 2] > 200 { white += 1 }
        }
        XCTAssertGreaterThan(red, 50, "inner stroke missing")
        XCTAssertGreaterThan(blue, 50, "outer stroke missing")
        XCTAssertGreaterThan(white, 50, "fill missing")
    }

    func testGradientFillChangesAcrossText() throws {
        var t = TextData(string: "IIIIIIII", fontSize: 90)
        t.style = TextStyleStack(fills: [TextFillLayer(kind: .linear, colors: [RGBA(1, 0, 0), RGBA(0, 0, 1)], angle: 0)])
        let px = try render(project(t))
        let w = 320
        var leftRed = 0, rightBlue = 0
        for y in 0..<160 { for x in 0..<w {
            let i = (y * w + x) * 4
            if x < w / 3, px[i] > px[i + 2] + 60 { leftRed += 1 }
            if x > w * 2 / 3, px[i + 2] > px[i] + 60 { rightBlue += 1 }
        } }
        XCTAssertGreaterThan(leftRed, 30)
        XCTAssertGreaterThan(rightBlue, 30)
    }

    func testMovedLettersWithEffectDoNotClip() throws {
        // A blurred text layer goes through the local buffer; a letter flown far up must still draw.
        var t = TextData(string: "AB", fontSize: 40)
        var a = TextAnimator(name: "Up")
        a.selector.start = Animated(50); a.selector.end = Animated(100)
        a.properties.position = Animated(Vec2(0, -75))
        t.animators = [a]
        var p = project(t, width: 200, height: 200)
        p.layers[0].effects = [EffectRegistry.glow.makeInstance()]
        let px = try render(p)
        // Rows well above the layout box (layout box is ~40 px tall around the center).
        let topRows = (0..<60).contains { y in (0..<200).contains { px[(y * 200 + $0) * 4] > 100 } }
        XCTAssertTrue(topRows, "the moved letter was clipped by the layer buffer")
    }
}
