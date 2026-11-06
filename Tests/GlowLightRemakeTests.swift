import XCTest
@testable import AWIeffect

/// Render checks for the Glow & Light remakes (Effects25 light engine): light adds with falloff,
/// keeps its hue instead of clipping to white, and only bright parts emit.
final class GlowLightRemakeTests: XCTestCase {
    private let size = 128

    private func renderer() throws -> Renderer {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return r
    }

    /// A colored square in the middle of a black frame with one effect on it.
    private func scene(_ id: String, color: RGBA, square: Double = 36, _ set: (inout EffectInstance) -> Void = { _ in }) throws -> Project {
        var p = Project.new(name: "light", width: size, height: size, fps: 30, duration: 2, background: .black)
        var l = p.makeLayer(name: "sq", content: .shape(.rectangle), size: Vec2(square, square))
        l.fill = Animated(color)
        l.transform.position = Animated(Vec2(Double(size) / 2, Double(size) / 2))
        var e = try XCTUnwrap(EffectRegistry.definition(id)).makeInstance()
        set(&e)
        l.effects = [e]
        p.layers = [l]
        return p
    }

    private func pixels(_ r: Renderer, _ p: Project, t: Double = 0.4) throws -> [UInt8] {
        try XCTUnwrap(r.renderPixels(project: p, time: t, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    private func px(_ buf: [UInt8], _ x: Int, _ y: Int) -> (r: Double, g: Double, b: Double) {
        let i = (y * size + x) * 4
        return (Double(buf[i]), Double(buf[i + 1]), Double(buf[i + 2]))
    }

    private func num(_ e: inout EffectInstance, _ k: String, _ v: Double) { e.params[k] = .number(Animated(v)) }

    func testGlowKeepsHueAndFallsOff() throws {
        let r = try renderer()
        let p = try scene("ae.glow", color: RGBA(1, 0.1, 0.05)) { e in
            num(&e, "threshold", 10); num(&e, "radius", 30); num(&e, "intensity", 4)
        }
        let out = try pixels(r, p)
        let mid = size / 2
        // Inside the square: even at high intensity the red stays red (no white sheet).
        let inside = px(out, mid, mid)
        XCTAssertGreaterThan(inside.r, 200)
        XCTAssertLessThan(inside.g, inside.r * 0.6, "glow clipped toward white instead of keeping its hue")
        // Outside: a red halo that falls off with distance.
        let near = px(out, mid + 22, mid), far = px(out, mid + 44, mid)
        XCTAssertGreaterThan(near.r, 20, "no halo next to the shape")
        XCTAssertGreaterThan(near.r, far.r, "halo has no falloff")
        XCTAssertGreaterThan(near.r, near.b * 1.5, "halo lost the source hue")
    }

    func testGlowThresholdOnlyEmitsFromBrightParts() throws {
        let r = try renderer()
        let dark = try pixels(r, try scene("ae.glow", color: RGBA(0.2, 0.2, 0.2)) { e in
            num(&e, "threshold", 60); num(&e, "radius", 30); num(&e, "intensity", 3)
        })
        let bright = try pixels(r, try scene("ae.glow", color: RGBA(1, 1, 1)) { e in
            num(&e, "threshold", 60); num(&e, "radius", 30); num(&e, "intensity", 3)
        })
        let mid = size / 2
        XCTAssertLessThan(px(dark, mid + 26, mid).r, 6, "a dark layer below the threshold must not glow")
        XCTAssertGreaterThan(px(bright, mid + 26, mid).r, 15, "a bright layer above the threshold must glow")
    }

    func testOuterGlowIsBrightestAtTheEdge() throws {
        let r = try renderer()
        let p = try scene("awi.outerGlow", color: RGBA(0.1, 0.1, 0.8)) { e in num(&e, "size", 40); num(&e, "intensity", 2) }
        let out = try pixels(r, p)
        let mid = size / 2
        let edge = px(out, mid + 21, mid), outer = px(out, mid + 40, mid)
        XCTAssertGreaterThan(edge.r + edge.g + edge.b, outer.r + outer.g + outer.b, "outer glow has no falloff")
        XCTAssertLessThan(edge.g, 250, "outer glow blew out to white")
    }

    func testStarStreaksRunAlongTheirRays() throws {
        let r = try renderer()
        // 4 points at 0° rotation: rays along the horizontal and vertical axes, not the diagonals.
        let p = try scene("awi8.starStreaks", color: RGBA(1, 1, 1), square: 8) { e in
            num(&e, "rotation", 0); num(&e, "length", 50); num(&e, "intensity", 4); num(&e, "threshold", 40)
        }
        let out = try pixels(r, p)
        let mid = size / 2
        let onRay = px(out, mid + 18, mid), offRay = px(out, mid + 13, mid + 13)
        XCTAssertGreaterThan(onRay.r, offRay.r + 5, "streak light is not concentrated along the rays")
    }

    func testLensFlareAddsLightWithoutWhiteSheet() throws {
        let r = try renderer()
        let base = try pixels(r, try scene("ae.lensFlare", color: RGBA(0.3, 0.3, 0.35)) { e in num(&e, "brightness", 0) })
        let out = try pixels(r, try scene("ae.lensFlare", color: RGBA(0.3, 0.3, 0.35)) { e in num(&e, "brightness", 200) })
        var diff = 0.0, sum = 0.0
        for i in stride(from: 0, to: out.count, by: 4) {
            diff += abs(Double(out[i]) - Double(base[i])); sum += Double(out[i])
        }
        let n = Double(out.count / 4)
        XCTAssertGreaterThan(diff / n, 1, "lens flare added no light")
        XCTAssertLessThan(sum / n, 200, "lens flare washed the frame out to white")
    }

    func testLightSweepMovesOverTime() throws {
        let r = try renderer()
        let p = try scene("awi10.lightSweep", color: RGBA(0.4, 0.3, 0.6), square: 100)
        let a = try pixels(r, p, t: 0.2), b = try pixels(r, p, t: 0.9)
        var d = 0.0
        for i in 0..<min(a.count, b.count) { d += abs(Double(a[i]) - Double(b[i])) }
        XCTAssertGreaterThan(d / Double(a.count), 0.3, "the sweep band does not travel")
        let mid = size / 2
        XCTAssertLessThan(px(a, mid, mid).g, 252, "sweep clipped to white")
    }

    func testSavedGlowWithoutNewControlsStillRenders() throws {
        let r = try renderer()
        // A project saved before the remake has no "falloff" / "burn" values: it must still glow, not go flat.
        let p = try scene("ae.glow", color: RGBA(1, 0.6, 0.1)) { e in
            e.params["falloff"] = nil; e.params["burn"] = nil
            num(&e, "threshold", 20); num(&e, "radius", 30); num(&e, "intensity", 2)
        }
        let out = try pixels(r, p)
        XCTAssertGreaterThan(px(out, size / 2 + 24, size / 2).r, 15)
    }
}
