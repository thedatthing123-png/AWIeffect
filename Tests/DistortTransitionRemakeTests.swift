import XCTest
@testable import AWIeffect

/// Render checks for the batch 28 Distort & Transitions remakes.
final class DistortTransitionRemakeTests: XCTestCase {
    private func renderer() throws -> Renderer {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device available; effect tests not run") }
        return r
    }

    private func scene(_ effect: EffectInstance?) -> Project {
        var p = Project.new(name: "fx28", width: 160, height: 160, fps: 30, duration: 2, background: RGBA(0.08, 0.06, 0.12))
        var star = p.makeLayer(name: "star", content: .shape(.star), size: Vec2(110, 110))
        star.fill = Animated(RGBA(1, 0.95, 0.8))
        star.sides = Animated(5)
        var rect = p.makeLayer(name: "rect", content: .shape(.rectangle), size: Vec2(160, 160))
        rect.fill = Animated(RGBA(0.6, 0.2, 0.9))
        if let effect { star.effects = [effect] }
        p.layers = [star, rect]
        return p
    }

    private func instance(_ id: String, _ edit: (inout EffectInstance) -> Void = { _ in }) throws -> EffectInstance {
        var e = try XCTUnwrap(EffectRegistry.definition(id)).makeInstance()
        edit(&e)
        return e
    }

    private func num(_ e: inout EffectInstance, _ k: String, _ v: Double) { e.params[k] = .number(Animated(v)) }

    private func render(_ r: Renderer, _ p: Project, t: Double = 0.4) throws -> [UInt8] {
        try XCTUnwrap(r.renderPixels(project: p, time: t, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    private func diff(_ a: [UInt8], _ b: [UInt8]) -> Double {
        var s = 0.0
        for i in 0..<min(a.count, b.count) { s += Double(abs(Int(a[i]) - Int(b[i]))) }
        return s / Double(max(1, a.count))
    }

    func testNewControlsDefaultToPreviousBehavior() throws {
        let td = try instance("ae.turbulentDisplace")
        XCTAssertEqual(td.choice("edge"), 0, "Turbulent Displace keeps Repeat Edge Pixels")
        XCTAssertEqual(td.choice("aa"), 0)
        XCTAssertEqual(try instance("ae.waveWarp").choice("edge"), 0, "Wave Warp keeps transparent edges")
        XCTAssertEqual(try instance("awi9.clockWipe").choice("ease"), 0, "transitions stay linear unless eased")
        XCTAssertEqual(try instance("ae.magnify").number("opacity", 0), 100)
    }

    func testTurbulentDisplaceTypesAllWarpDifferently() throws {
        let r = try renderer()
        let base = try render(r, scene(nil))
        var outs: [[UInt8]] = []
        for type in 0..<5 {
            let e = try instance("ae.turbulentDisplace") { e in
                e.params["dispType"] = .choice(type); num(&e, "amount", 40); num(&e, "size", 40)
            }
            let o = try render(r, scene(e))
            XCTAssertGreaterThan(diff(base, o), 0.5, "type \(type) should visibly warp")
            outs.append(o)
        }
        XCTAssertGreaterThan(diff(outs[0], outs[2]), 0.2, "Bulge differs from Turbulent")
        XCTAssertGreaterThan(diff(outs[2], outs[3]), 0.2, "Twist differs from Bulge")
    }

    func testTurbulentCycleEvolutionLoops() throws {
        let r = try renderer()
        func at(_ evo: Double) throws -> [UInt8] {
            try render(r, scene(try instance("ae.turbulentDisplace") { e in
                num(&e, "amount", 40); num(&e, "size", 40); e.params["cycle"] = .toggle(true); num(&e, "cycleLen", 1); num(&e, "evolution", evo)
            }))
        }
        let a = try at(0), b = try at(360), mid = try at(180)
        XCTAssertLessThan(diff(a, b), 0.6, "one full cycle returns to the start")
        XCTAssertGreaterThan(diff(a, mid), 0.3, "half a cycle looks different")
    }

    func testTransitionEasingShiftsProgress() throws {
        let r = try renderer()
        func wipe(_ ease: Int) throws -> [UInt8] {
            try render(r, scene(try instance("awi9.diagonalWipe") { e in num(&e, "completion", 30); e.params["ease"] = .choice(ease) }))
        }
        XCTAssertGreaterThan(diff(try wipe(0), try wipe(1)), 0.5, "Ease In lags behind linear at 30%")
    }

    func testPixelDissolveSoftnessFadesBlocks() throws {
        let r = try renderer()
        let hard = try render(r, scene(try instance("awi9.pixelDissolve") { e in num(&e, "completion", 50) }))
        let soft = try render(r, scene(try instance("awi9.pixelDissolve") { e in num(&e, "completion", 50); num(&e, "softness", 60) }))
        XCTAssertGreaterThan(diff(hard, soft), 0.5)
    }

    func testStripesWipeRendersPartialCoverage() throws {
        let r = try renderer()
        let base = try render(r, scene(nil))
        let o = try render(r, scene(try instance("awi9.stripesWipe") { e in num(&e, "completion", 50); num(&e, "feather", 0) }))
        XCTAssertGreaterThan(diff(base, o), 1.0)
    }

    func testMagnifyOpacityAndFeather() throws {
        let r = try renderer()
        let none = try render(r, scene(nil))
        let off = try render(r, scene(try instance("ae.magnify") { e in num(&e, "opacity", 0) }))
        XCTAssertLessThan(diff(none, off), 0.2, "0% opacity leaves the layer untouched")
        let hard = try render(r, scene(try instance("ae.magnify") { e in num(&e, "mag", 300); num(&e, "size", 50) }))
        let soft = try render(r, scene(try instance("ae.magnify") { e in num(&e, "mag", 300); num(&e, "size", 50); num(&e, "feather", 30) }))
        XCTAssertGreaterThan(diff(hard, soft), 0.05)
    }

    func testPolarAndRippleStillRender() throws {
        let r = try renderer()
        let base = try render(r, scene(nil))
        let polar = try render(r, scene(try instance("ae.polarCoordinates")))
        XCTAssertGreaterThan(diff(base, polar), 0.5)
        let ripple = try render(r, scene(try instance("ae.ripple") { e in e.params["conversion"] = .choice(0); num(&e, "height", 20) }))
        XCTAssertGreaterThan(diff(base, ripple), 0.2)
    }

    /// Batch 6 / 14 warps: Low + Default edges matches the original kernel; High antialiasing smooths it;
    /// Mirror edges fill the empty corners a skew leaves.
    func testWarpAntialiasingAndEdgeBehavior() throws {
        let r = try renderer()
        func twist(_ aa: Int) throws -> [UInt8] {
            try render(r, scene(try instance("awi14.twistColumns") { e in e.params["aa"] = .choice(aa) }))
        }
        var legacy = try instance("awi14.twistColumns")
        legacy.params["aa"] = nil; legacy.params["edge"] = nil
        XCTAssertLessThan(diff(try render(r, scene(legacy)), try twist(0)), 0.3, "Low antialiasing keeps the original look")
        XCTAssertGreaterThan(diff(try twist(0), try twist(2)), 0.05, "High antialiasing changes jagged column edges")

        let skewDefault = try render(r, scene(try instance("awi14.skew") { e in num(&e, "skewX", 40) }))
        let skewMirror = try render(r, scene(try instance("awi14.skew") { e in num(&e, "skewX", 40); e.params["edge"] = .choice(4) }))
        XCTAssertGreaterThan(diff(skewDefault, skewMirror), 0.1)
    }
}
