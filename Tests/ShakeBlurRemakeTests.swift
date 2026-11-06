import XCTest
@testable import AWIeffect

/// Batch 26: remade shakes (Shake Pro engine) and blurs (fxBlur26).
final class ShakeBlurRemakeTests: XCTestCase {
    private func renderer() throws -> Renderer {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device available; effect tests not run") }
        return r
    }

    private func transform(_ e: EffectInstance, _ t: Double) -> (Double, Double, Double, Double) {
        guard case .transform(let f) = EffectRegistry.shakePro18.stage else { XCTFail("Shake Pro is not a transform effect"); return (0, 0, 0, 1) }
        return f(e, t)
    }

    private func shakePro(mode: Int, speed: Double) -> EffectInstance {
        var e = EffectRegistry.shakePro18.makeInstance()
        e.params["mode"] = .choice(mode)
        e.params["speed"] = .number(Animated(speed))
        e.params["amount"] = .number(Animated(50))
        return e
    }

    func testImpactKicksThenRingsOutAndSettles() {
        let e = shakePro(mode: 4, speed: 10) // a hit every 0.8 s
        let kick = transform(e, 0.005), late = transform(e, 0.75)
        let kickLen = hypot(kick.0, kick.1), lateLen = hypot(late.0, late.1)
        XCTAssertGreaterThan(kickLen, 30, "impact should start at a strong kick")
        XCTAssertLessThan(lateLen, 2, "impact should settle before the next hit")
        // It rings: the offset crosses back past rest at least once in the first part of the hit.
        var signs = Set<Bool>()
        for k in 0..<40 { let v = transform(e, Double(k) * 0.01); if abs(v.0) + abs(v.1) > 1 { signs.insert(v.0 * kick.0 + v.1 * kick.1 > 0) } }
        XCTAssertEqual(signs.count, 2, "impact should overshoot (ring) rather than just decay")
    }

    func testTwitchSnapsThenHoldsAPose() {
        let e = shakePro(mode: 1, speed: 4) // a new pose every 0.25 s
        let a = transform(e, 0.30), b = transform(e, 0.45), next = transform(e, 0.70)
        XCTAssertEqual(a.0, b.0, accuracy: 1e-9); XCTAssertEqual(a.1, b.1, accuracy: 1e-9)
        XCTAssertGreaterThan(abs(a.0 - next.0) + abs(a.1 - next.1), 0.5, "twitch should jump to a new pose")
    }

    func testEaseInStartsFromRest() {
        var e = shakePro(mode: 0, speed: 10)
        e.params["fadeIn"] = .number(Animated(1))
        let start = transform(e, 0)
        XCTAssertEqual(start.0, 0, accuracy: 1e-9); XCTAssertEqual(start.3, 1, accuracy: 1e-9)
        e.params["fadeIn"] = .number(Animated(0))
        XCTAssertGreaterThan(abs(transform(e, 0.37).0) + abs(transform(e, 0.37).1), 0.01)
    }

    func testEarthquakeIsMostlyVertical() {
        let e = shakePro(mode: 3, speed: 10)
        var sx = 0.0, sy = 0.0
        for k in 0..<300 { let v = transform(e, Double(k) / 60); sx += abs(v.0); sy += abs(v.1) }
        XCTAssertGreaterThan(sy, sx, "earthquake rumble should favour vertical motion")
    }

    // MARK: GPU

    private func dotScene(_ effect: EffectInstance?, size: Double = 9, color: RGBA = .white) -> Project {
        var p = Project.new(name: "fx26", width: 121, height: 121, fps: 30, duration: 2, background: .black)
        var bg = p.makeLayer(name: "bg", content: .solid, size: Vec2(121, 121))
        bg.fill = Animated(RGBA(0.08, 0.08, 0.1))
        var dot = p.makeLayer(name: "dot", content: .solid, size: Vec2(size, size))
        dot.fill = Animated(color)
        if let effect {
            var adj = p.makeLayer(name: "adj", content: .adjustment, size: Vec2(121, 121))
            adj.effects = [effect]
            p.layers = [adj, dot, bg]
        } else {
            p.layers = [dot, bg]
        }
        return p
    }

    private func render(_ r: Renderer, _ p: Project, t: Double = 0.4) throws -> [UInt8] {
        try XCTUnwrap(r.renderPixels(project: p, time: t, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    private func lum(_ px: [UInt8], _ x: Int, _ y: Int) -> Double { Double(px[(y * 121 + x) * 4]) }

    /// Brightness-weighted centroid of the red channel above the background.
    private func centroid(_ px: [UInt8]) -> (Double, Double) {
        var sx = 0.0, sy = 0.0, sw = 0.0
        for y in 0..<121 { for x in 0..<121 { let w = max(0, lum(px, x, y) - 30); sx += w * Double(x); sy += w * Double(y); sw += w } }
        return sw > 0 ? (sx / sw, sy / sw) : (60, 60)
    }

    func testLensBlurTurnsAHighlightIntoAFlatDisc() throws {
        let r = try renderer()
        var e = EffectRegistry.lensBlur.makeInstance()
        e.params["radius"] = .number(Animated(18)); e.params["boost"] = .number(Animated(2))
        let px = try render(r, dotScene(e, size: 5))
        let center = lum(px, 60, 60), mid = lum(px, 60 + 10, 60), outside = lum(px, 60 + 30, 60)
        XCTAssertLessThan(center, 255, "the highlight should be spread out")
        XCTAssertGreaterThan(mid, 40, "bokeh should stay bright well inside its radius (a disc, not a soft gaussian bump)")
        XCTAssertLessThan(outside, mid, "bokeh should end at its radius")
    }

    func testCameraShakeBlurSmearsWithoutMovingTheImage() throws {
        let r = try renderer()
        let base = try render(r, dotScene(nil, size: 15))
        var e = EffectRegistry.shakeBlur15.makeInstance()
        e.params["amplitude"] = .number(Animated(20)); e.params["shutter"] = .number(Animated(100))
        let out = try render(r, dotScene(e, size: 15))
        var d = 0.0
        for i in 0..<base.count { d += Double(abs(Int(base[i]) - Int(out[i]))) }
        XCTAssertGreaterThan(d / Double(base.count), 0.3, "camera shake blur should smear the image")
        let c0 = centroid(base), c1 = centroid(out)
        XCTAssertLessThan(hypot(c0.0 - c1.0, c0.1 - c1.1), 12, "the blur should be measured from the shutter middle, not drift the frame")
    }

    func testEdgeBlurLeavesFlatAreasUntouched() throws {
        let r = try renderer()
        let base = try render(r, dotScene(nil, size: 70, color: RGBA(0.8, 0.3, 0.2)))
        var e = EffectRegistry.edgeBlur15.makeInstance()
        e.params["radius"] = .number(Animated(8))
        let out = try render(r, dotScene(e, size: 70, color: RGBA(0.8, 0.3, 0.2)))
        XCTAssertEqual(lum(out, 60, 60), lum(base, 60, 60), accuracy: 3, "flat interior should stay sharp")
        XCTAssertGreaterThan(abs(lum(out, 60 + 35, 60) - lum(base, 60 + 35, 60)) + abs(lum(out, 60 + 37, 60) - lum(base, 60 + 37, 60)), 4,
                             "the edge should be softened")
    }

    func testLumaMaskBlurKeepsDarksCrisp() throws {
        let r = try renderer()
        let base = try render(r, dotScene(nil, size: 40))
        var e = EffectRegistry.maskBlur15.makeInstance()
        e.params["radius"] = .number(Animated(10))
        let out = try render(r, dotScene(e, size: 40))
        // Far from the white square, the dark background has nothing bright to blur.
        XCTAssertEqual(lum(out, 5, 5), lum(base, 5, 5), accuracy: 2)
        XCTAssertNotEqual(lum(out, 60 + 20, 60), lum(base, 60 + 20, 60), "the bright square's edge should melt")
    }
}
