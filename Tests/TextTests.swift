import XCTest
@testable import AWIeffect

final class TextTests: XCTestCase {
    // MARK: Selector math (no GPU)

    func testSquareRangeSelectsExactUnits() {
        var s = TextSelector()
        s.start = Animated(0); s.end = Animated(50)
        let v = (0..<4).map { SelectorMath.amount(s, index: $0, count: 4, time: 0) }
        XCTAssertEqual(v, [1, 1, 0, 0])
    }

    func testOffsetShiftsRange() {
        var s = TextSelector()
        s.start = Animated(0); s.end = Animated(25); s.offset = Animated(50)
        XCTAssertEqual(SelectorMath.amount(s, index: 2, count: 4, time: 0), 1)
        XCTAssertEqual(SelectorMath.amount(s, index: 0, count: 4, time: 0), 0)
    }

    func testRampShapesAreMonotonic() {
        var s = TextSelector()
        s.shape = .rampUp
        let up = (0..<10).map { SelectorMath.amount(s, index: $0, count: 10, time: 0) }
        XCTAssertEqual(up, up.sorted())
        s.shape = .rampDown
        let down = (0..<10).map { SelectorMath.amount(s, index: $0, count: 10, time: 0) }
        XCTAssertEqual(down, down.sorted(by: >))
    }

    func testTrianglePeaksInMiddle() {
        var s = TextSelector()
        s.shape = .triangle
        let v = (0..<9).map { SelectorMath.amount(s, index: $0, count: 9, time: 0) }
        XCTAssertEqual(v.firstIndex(of: v.max()!), 4)
    }

    func testRandomOrderIsAPermutation() {
        let o = SelectorMath.randomOrder(count: 20, seed: 3)
        XCTAssertEqual(Set(o), Set(0..<20))
        XCTAssertNotEqual(o, Array(0..<20))
    }

    func testWaveTravelsAcrossUnits() {
        var s = TextSelector()
        s.kind = .wave
        s.spread = Animated(4)
        let a = SelectorMath.amount(s, index: 0, count: 8, time: 0.1)
        let b = SelectorMath.amount(s, index: 1, count: 8, time: 0.1)
        XCTAssertNotEqual(a, b, accuracy: 1e-6)
    }

    // MARK: Layout

    func testLayoutHasGlyphPerCharacterAndUnitCounts() {
        let t = TextData(string: "Hi you\nAW", fontSize: 50)
        let l = TextEngine.shared.layout(t, time: 0)
        XCTAssertEqual(l.glyphs.count, 8)   // H i space y o u A W (no glyph for the line break)
        XCTAssertEqual(l.wordCount, 3)
        XCTAssertEqual(l.lineCount, 2)
        XCTAssertGreaterThan(l.bounds.width, 50)
    }

    // MARK: Rendering (GPU)

    private func render(_ p: Project, t: Double) throws -> [UInt8] {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device") }
        return try XCTUnwrap(r.renderPixels(project: p, time: t, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    private func diff(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(a.count)
    }

    private func textProject(_ string: String = "AWIeffect", animators: [TextAnimator] = []) -> Project {
        var p = Project.new(name: "t", width: 320, height: 120, fps: 30, duration: 2, background: .black)
        var l = p.makeLayer(name: "t", content: .text, size: Vec2(1, 1))
        l.text = TextData(string: string, fontSize: 48)
        l.text?.animators = animators
        p.layers = [l]
        return p
    }

    func testTextRendersVisiblePixels() throws {
        let px = try render(textProject(), t: 0)
        let lit = stride(from: 0, to: px.count, by: 4).filter { px[$0] > 128 }.count
        XCTAssertGreaterThan(lit, 300, "text drew almost nothing")
        XCTAssertEqual(px[0], 0, "text leaked into the corner")
    }

    func testPerWordColor() throws {
        var p = textProject("RED GREEN")
        p.layers[0].text?.fill = Animated(RGBA(1, 0, 0))
        p.layers[0].text?.colorSpans = [TextColorSpan(start: 4, end: 9, color: RGBA(0, 1, 0))]
        let px = try render(p, t: 0)
        var red = 0, green = 0
        for i in stride(from: 0, to: px.count, by: 4) {
            if px[i] > 150 && px[i + 1] < 60 { red += 1 }
            if px[i + 1] > 150 && px[i] < 60 { green += 1 }
        }
        XCTAssertGreaterThan(red, 100)
        XCTAssertGreaterThan(green, 100)
    }

    /// Every preset must animate (frames differ over time) and look different from every other preset.
    func testEveryPresetAnimatesAndIsDistinct() throws {
        var mids: [String: [UInt8]] = [:]
        for preset in TextPresets.all {
            let p = textProject(animators: preset.make(0, 1))
            let a = try render(p, t: 0.05), b = try render(p, t: 0.5), c = try render(p, t: 1.4)
            XCTAssertGreaterThan(diff(a, b) + diff(b, c), 0.3, "\(preset.name) does not animate")
            mids[preset.id] = b
        }
        let ids = TextPresets.all.map(\.id)
        for i in ids.indices { for j in ids.indices where j > i {
            XCTAssertGreaterThan(diff(mids[ids[i]]!, mids[ids[j]]!), 0.2, "\(ids[i]) and \(ids[j]) look the same")
        } }
    }

    func testRevealPresetsEndFullyVisible() throws {
        let plain = try render(textProject(), t: 1.5)
        for id in ["typewriter", "fadeUp", "bounceIn", "slideStagger", "spinIn", "dropIn", "trackingIn", "flicker", "glitch"] {
            let preset = TextPresets.all.first { $0.id == id }!
            let end = try render(textProject(animators: preset.make(0, 1)), t: 1.5)
            XCTAssertLessThan(diff(plain, end), 0.5, "\(preset.name) does not settle on the plain text")
        }
    }

    func testEffectsWorkOnText() throws {
        var p = textProject()
        let base = try render(p, t: 0)
        var e = EffectRegistry.glow.makeInstance()
        e.params["threshold"] = .number(Animated(30))
        e.params["radius"] = .number(Animated(12))
        p.layers[0].effects = [e]
        XCTAssertGreaterThan(diff(base, try render(p, t: 0)), 0.5)
    }
}
