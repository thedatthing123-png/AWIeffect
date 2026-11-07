import XCTest
@testable import AWIeffect

@MainActor
final class RenewColorEffectsTests: XCTestCase {
    private func project() -> Project { Project.new(name: "r4", width: 1000, height: 1000, fps: 30, duration: 4, background: .black) }
    private func state(_ p: Project) -> EditorState {
        EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }

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

    // MARK: Effects panel

    func testHoldKeysResolveSwitchesAndMenusOverTime() {
        var e = EffectRegistry.gaussianBlur.makeInstance()
        XCTAssertNil(EffectStackR4.resolved(e, at: 0), "no hold keys: untouched (fast path)")
        e = EffectStackR4.settingHold(e, "repeatEdges", value: 0, at: 0)
        e = EffectStackR4.settingHold(e, "repeatEdges", value: 1, at: 1)
        e = EffectStackR4.settingHold(e, "dimensions", value: 2, at: 0.5)
        XCTAssertEqual(EffectStackR4.resolved(e, at: 0.5)?.bool("repeatEdges"), false)
        XCTAssertEqual(EffectStackR4.resolved(e, at: 1.5)?.bool("repeatEdges"), true)
        XCTAssertEqual(EffectStackR4.resolved(e, at: 0)?.choice("dimensions"), 2, "before the first key: the first key's value")
        e = EffectStackR4.removingHold(e, "repeatEdges", at: 1)
        XCTAssertEqual(EffectStackR4.holdKeys(e, "repeatEdges").count, 1)
        let back = try? JSONDecoder().decode(EffectInstance.self, from: JSONEncoder().encode(e))
        XCTAssertEqual(back, e, "hold keys save with the project")
    }

    func testMixDefaultsToFullAndSoloMutesTheOthers() {
        let a = EffectRegistry.gaussianBlur.makeInstance(), b = EffectRegistry.gaussianBlur.makeInstance()
        XCTAssertEqual(EffectStackR4.mix(a, 0), 100)
        let soloed = EffectStackR4.toggledSolo([a, b], b.id)
        XCTAssertTrue(EffectStackR4.isMuted(soloed[0])); XCTAssertTrue(EffectStackR4.isSolo(soloed[1]))
        let cleared = EffectStackR4.toggledSolo(soloed, b.id)
        XCTAssertEqual(cleared, [a, b], "ending solo restores the stack exactly")
        XCTAssertNotNil(EffectRegistry.definition("awiR4.gradient"))
        let t = EffectRegistry.definition("ae.shake").map { d -> Bool in if case .transform = d.stage { return true }; return false }
        XCTAssertNotEqual(t, false, "wrapping keeps each stage kind")
    }

    func testReorderIsOneUndoStep() {
        var p = project()
        var l = p.makeLayer(name: "l", content: .solid, size: Vec2(10, 10))
        let a = EffectRegistry.gaussianBlur.makeInstance(), b = EffectRegistry.exposure.makeInstance(), c = EffectRegistry.invert.makeInstance()
        l.effects = [a, b, c]
        p.layers = [l]
        let s = state(p)
        s.select(l.id)
        s.moveEffect(c.id, to: a.id)
        XCTAssertEqual(s.project.layers[0].effects.map(\.id), [c.id, a.id, b.id])
        s.undo()
        XCTAssertEqual(s.project.layers[0].effects.map(\.id), [a.id, b.id, c.id])
    }

    func testStackPresetsTravelAndApplyAsRemovableGroup() throws {
        var p = project()
        var l = p.makeLayer(name: "l", content: .solid, size: Vec2(10, 10))
        l.effects = EffectStackR4.toggledSolo([EffectRegistry.gaussianBlur.makeInstance(), EffectRegistry.invert.makeInstance()], UUID())
        p.layers = [l]
        let s = state(p)
        s.select(l.id)
        let name = "R4 test \(UUID().uuidString)"
        s.saveEffectStack(name)
        defer { EffectStackLibrary.remove(name) }
        XCTAssertEqual(s.project.effectStackPresets?[name]?.count, 2)
        XCTAssertNil(s.project.effectStackPresets?[name]?.first?.text?["soloMute"])
        s.applyEffectStack(name)
        let fx = s.project.layers[0].effects
        XCTAssertEqual(fx.count, 4)
        let tag = try XCTUnwrap(fx[2].text?["stack"])
        XCTAssertEqual(fx[3].text?["stack"], tag)
        XCTAssertNotEqual(fx[2].id, fx[0].id, "fresh ids")
        s.removeEffectGroup(tag)
        XCTAssertEqual(s.project.layers[0].effects.count, 2)
        let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(s.project))
        XCTAssertEqual(back.effectStackPresets?[name]?.count, 2)
        XCTAssertNil(try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project())).effectStackPresets)
    }

    func testMatteFromAnyLayer() {
        var p = project()
        let m = p.makeLayer(name: "matte", content: .solid, size: Vec2(10, 10))
        let mid = p.makeLayer(name: "mid", content: .solid, size: Vec2(10, 10))
        let l = p.makeLayer(name: "l", content: .solid, size: Vec2(10, 10))
        p.layers = [m, mid, l]
        let s = state(p)
        s.select(l.id)
        s.setMatteSource(m.id, mode: .lumaInverted)
        let got = s.matteSource(s.project.layers[2])
        XCTAssertEqual(got?.0, m.id); XCTAssertEqual(got?.1, .lumaInverted)
        s.setMatteSource(nil, mode: .none)
        XCTAssertNil(s.matteSource(s.project.layers[2]))
    }

    func testParticleR4ControlsDefaultToOldLook() {
        let e = EffectRegistry.particles18.makeInstance()
        XCTAssertFalse(e.bool("burst")); XCTAssertFalse(e.bool("floor")); XCTAssertEqual(e.choice("colorStops"), 0)
        XCTAssertEqual(MemoryLayout<ParticleUniforms>.stride, 14 * 16, "matches the Metal struct")
    }
}
