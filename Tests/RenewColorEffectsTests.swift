import XCTest
@testable import AWIeffect

final class RenewColorEffectsTests: XCTestCase {
    func testDefaultGradeUsesOriginalPathAndOlderGradesMatch() {
        let g = EffectRegistry.grade.makeInstance()
        XCTAssertFalse(GradeR4.isActive(g), "a fresh grade renders through the original kernel")
        var old = g
        for d in EffectRegistry.gradeR4Params { old.params[d.id] = nil }
        XCTAssertFalse(GradeR4.isActive(old))
        XCTAssertEqual(GradeR4.num(old, "qSatHi", 0), 100, "missing controls read their default")
        let a = GradeR4.activePoints(old, 0, channel: "m"), b = GradeCurves.points(old, 0, channel: "m")
        XCTAssertEqual(a.xs, b.xs); XCTAssertEqual(a.ys, b.ys)
        var changed = g
        changed.params["offR"] = .number(Animated(10))
        XCTAssertTrue(GradeR4.isActive(changed))
    }

    func testAddAndRemoveCurvePoints() {
        var g = EffectRegistry.grade.makeInstance()
        g.params["me1on"] = .toggle(true)
        g.params["me1x"] = .number(Animated(10))
        g.params["me1y"] = .number(Animated(30))
        let p = GradeR4.activePoints(g, 0, channel: "m")
        XCTAssertEqual(p.xs.count, 6)
        XCTAssertEqual(p.xs[1], 0.1, accuracy: 1e-9)
        XCTAssertEqual(GradeCurves.curve(xs: p.xs, ys: p.ys)[Int(0.1 * 255)], 0.3, accuracy: 0.02)
        g.params["m50on"] = .toggle(false)
        XCTAssertEqual(GradeR4.activePoints(g, 0, channel: "m").xs.count, 5)
        XCTAssertEqual(GradeR4.freeSlot(g, channel: "m")?.on, "m50on", "removed original points are reused first")
    }

    func testHueCurveWrapsAndPassesThroughKnots() {
        var g = EffectRegistry.grade.makeInstance()
        g.params["hueSat0"] = .number(Animated(-50))
        XCTAssertEqual(GradeR4.value(g, "hueSat", 0, at: 0), -50, accuracy: 1e-6)
        XCTAssertEqual(GradeR4.value(g, "hueSat", 0, at: 1), -50, accuracy: 1e-6)
        XCTAssertEqual(GradeR4.value(g, "hueSat", 0, at: 180.0 / 360), 0, accuracy: 1e-6)
    }

    func testWheelPuckRoundTripAndWhiteBalance() {
        let c = GradeR4.rgb(puckX: 20, y: -10, mean: 5)
        let p = GradeR4.puck(r: c.r, g: c.g, b: c.b)
        XCTAssertEqual(p.x, 20, accuracy: 1e-9); XCTAssertEqual(p.y, -10, accuracy: 1e-9)
        XCTAssertEqual((c.r + c.g + c.b) / 3, 5, accuracy: 1e-9)
        let d = GradeR4.whiteBalanceDelta(r: 0.6, g: 0.5, b: 0.4)
        XCTAssertLessThan(d.temp, 0, "a warm grey is cooled")
        XCTAssertEqual(GradeR4.whiteBalanceDelta(r: 0.5, g: 0.5, b: 0.5).temp, 0, accuracy: 1e-9)
    }

    func testABSwapKeepsBothVersions() {
        var g = EffectRegistry.grade.makeInstance()
        g.params["exposure"] = .number(Animated(1))
        var b = GradeR4.swapAB(g)
        XCTAssertEqual(GradeR4.slot(b), "B")
        XCTAssertEqual(b.number("exposure", 0), 1, "B starts as a copy")
        b.params["exposure"] = .number(Animated(-1))
        let a = GradeR4.swapAB(b)
        XCTAssertEqual(GradeR4.slot(a), "A")
        XCTAssertEqual(a.number("exposure", 0), 1)
        XCTAssertEqual(GradeR4.swapAB(a).number("exposure", 0), -1)
        XCTAssertEqual(a.id, g.id)
    }

    func testScopesAnalysis() {
        let px: [UInt8] = [255, 255, 255, 255, 0, 0, 0, 255, 255, 0, 0, 255, 0, 0, 255, 255]
        let s = GradeScopes.analyze(width: 2, height: 2, rgba: px)
        XCTAssertEqual(s.histogram.count, 3)
        XCTAssertNotNil(s.waveform); XCTAssertNotNil(s.parade); XCTAssertNotNil(s.vectorscope)
        let w = s.sample(atX: 0, y: 0)
        XCTAssertNotNil(w)
        XCTAssertEqual(GradeScopes.vectorDensity(px, size: 8).reduce(0, +), 4)
    }

    func testBuiltInLooksIncludeFormerColorEffects() {
        for n in ["Cross Process", "Bleach Bypass", "Infrared", "Day for Night", "Cyberpunk", "Lomo", "Faded Vintage", "Sepia", "Print Film"] {
            XCTAssertTrue(LUTLibrary.builtInFiles.contains(LUTLibrary.builtInFile(n)), n)
        }
    }

    func testGradeR4RendersOnGPU() throws {
        guard Renderer.shared != nil else { throw XCTSkip("SKIP-GPU") }
        var g = EffectRegistry.grade.makeInstance()
        g.params["hueSat3"] = .number(Animated(-100))
        XCTAssertTrue(GradeR4.isActive(g))
    }
}
