import XCTest
import simd
@testable import AWIeffect

/// Batch 29 remakes: Fractal Noise, generators (clouds/smoke/fire/crystal shards/snow/rain/confetti/bubbles),
/// Luma Key, Color Range Key, Exposure, Brightness & Contrast, Vibrance.
final class BackgroundColorRemakeTests: XCTestCase {
    private func scene(_ effect: EffectInstance?, color: RGBA = .black, size: Int = 96) -> Project {
        var p = Project.new(name: "remake29", width: size, height: size, fps: 30, duration: 3, background: RGBA(0, 0, 0, 0))
        var l = p.makeLayer(name: "card", content: .solid, size: Vec2(Double(size), Double(size)))
        l.fill = Animated(color); l.effects = effect.map { [$0] } ?? []; p.layers = [l]; return p
    }
    private func pixels(_ project: Project, time: Double = 0.4) throws -> [UInt8] {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        return try XCTUnwrap(r.renderPixels(project: project, time: time, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }
    private func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(max(a.count, 1))
    }
    private func center(_ px: [UInt8], size: Int = 96) -> [Int] {
        let i = ((size / 2) * size + size / 2) * 4
        return (0..<4).map { Int(px[i + $0]) }
    }
    private func instance(_ id: String, _ set: (inout EffectInstance) -> Void = { _ in }) throws -> EffectInstance {
        var e = try XCTUnwrap(EffectRegistry.definition(id)).makeInstance()
        set(&e); return e
    }
    private func num(_ e: inout EffectInstance, _ k: String, _ v: Double) { e.params[k] = .number(Animated(v)) }

    // MARK: Keys

    func testLumaKeyDarkerRemovesDarkAndKeepsBright() throws {
        let e = try instance("ae.lumaKey")
        XCTAssertGreaterThan(center(try pixels(scene(e, color: RGBA(0.9, 0.9, 0.9))))[3], 245, "bright pixels must stay opaque (was keying out almost everything)")
        XCTAssertLessThan(center(try pixels(scene(e, color: RGBA(0.03, 0.03, 0.03))))[3], 10, "dark pixels must be removed")
        let brighter = try instance("ae.lumaKey") { $0.params["type"] = .choice(1) }
        XCTAssertLessThan(center(try pixels(scene(brighter, color: RGBA(0.9, 0.9, 0.9))))[3], 10)
        XCTAssertGreaterThan(center(try pixels(scene(brighter, color: RGBA(0.03, 0.03, 0.03))))[3], 245)
        let matte = try instance("ae.lumaKey") { $0.params["viewMatte"] = .toggle(true) }
        let m = center(try pixels(scene(matte, color: RGBA(0.03, 0.03, 0.03))))
        XCTAssertGreaterThan(m[3], 245, "view matte is opaque"); XCTAssertLessThan(m[0], 10, "keyed area shows black in the matte")
    }

    func testLumaKeyEdgeCleanBrightensSoftEdges() throws {
        // A pixel inside the feather band: with edge cleaning its black contamination is removed (brighter straight color).
        var soft = try instance("ae.lumaKey") { e in e.params["threshold"] = .number(Animated(30)); e.params["feather"] = .number(Animated(40)) }
        num(&soft, "edgeClean", 0)
        var clean = soft; num(&clean, "edgeClean", 100)
        let gray = RGBA(0.3, 0.3, 0.3)
        let a = center(try pixels(scene(soft, color: gray))), b = center(try pixels(scene(clean, color: gray)))
        XCTAssertEqual(Double(a[3]), Double(b[3]), accuracy: 2, "edge cleaning changes color, not the matte")
        XCTAssertGreaterThan(b[0], a[0], "decontaminated edge is brighter than the black-fringed one")
    }

    func testColorRangeKeyRemovesGreenAndKeepsOtherHues() throws {
        let e = try instance("awi11.colorRangeKey")
        XCTAssertLessThan(center(try pixels(scene(e, color: RGBA(0.1, 0.85, 0.2))))[3], 15)
        XCTAssertGreaterThan(center(try pixels(scene(e, color: RGBA(0.85, 0.2, 0.6))))[3], 245)
    }

    // MARK: Color

    func testBrightnessDoesNotClipNearWhites() throws {
        let e = try instance("ae.brightnessContrast") { $0.params["brightness"] = .number(Animated(100)) }
        let a = center(try pixels(scene(e, color: RGBA(0.85, 0.85, 0.85))))[0]
        let b = center(try pixels(scene(e, color: RGBA(0.92, 0.92, 0.92))))[0]
        XCTAssertLessThan(a, b, "two different near-white tones must stay different")
        var legacy = e; legacy.params["legacy"] = .toggle(true)
        XCTAssertEqual(center(try pixels(scene(legacy, color: RGBA(0.85, 0.85, 0.85))))[0], 255, "legacy mode keeps the old clipping formula")
    }

    func testExposureWorksInLinearLight() throws {
        let e = try instance("ae.exposure") { $0.params["exposure"] = .number(Animated(1)) }
        let r = center(try pixels(scene(e, color: RGBA(0.5, 0.5, 0.5))))[0]
        XCTAssertGreaterThan(r, 150); XCTAssertLessThan(r, 245, "+1 stop on mid gray must not blow out to white")
        let zero = try instance("ae.exposure")
        XCTAssertLessThan(difference(try pixels(scene(nil, color: RGBA(0.4, 0.6, 0.2))), try pixels(scene(zero, color: RGBA(0.4, 0.6, 0.2)))), 0.6,
                          "0 stops is identity")
    }

    func testVibranceKeepsAlphaAndChangesColor() throws {
        let e = try instance("ae.vibrance") { e in e.params["vibrance"] = .number(Animated(100)); e.params["saturation"] = .number(Animated(60)) }
        let base = RGBA(0.6, 0.45, 0.4, 0.5)
        let plain = center(try pixels(scene(nil, color: base))), out = center(try pixels(scene(e, color: base)))
        XCTAssertEqual(Double(out[3]), Double(plain[3]), accuracy: 2, "premultiplied alpha is preserved")
        XCTAssertGreaterThan(abs(out[0] - out[2]), abs(plain[0] - plain[2]), "muted color gets more saturated")
    }

    // MARK: Fractal Noise

    func testFractalNoiseHasContrastEvolvesAndCyclesSeamlessly() throws {
        let e = try instance("ae.fractalNoise") { $0.params["scale"] = .number(Animated(30)) }
        let px = try pixels(scene(e))
        let reds = stride(from: 0, to: px.count, by: 4).map { Int(px[$0]) }
        XCTAssertGreaterThan(reds.max()! - reds.min()!, 80, "noise must span a real tonal range")
        var evolved = e; evolved.params["evolution"] = .number(Animated(90))
        XCTAssertGreaterThan(difference(px, try pixels(scene(evolved))), 2)
        var c0 = e; c0.params["cycle"] = .toggle(true); c0.params["evolution"] = .number(Animated(0))
        var c1 = c0; c1.params["evolution"] = .number(Animated(360))
        XCTAssertLessThan(difference(try pixels(scene(c0)), try pixels(scene(c1))), 0.5, "one full cycle loops back")
        var rocky = e; rocky.params["type"] = .choice(7)
        XCTAssertGreaterThan(difference(px, try pixels(scene(rocky))), 2, "fractal types differ")
    }

    // MARK: Generators

    func testParticleGeneratorsMoveOverTime() throws {
        for id in ["awi7.snow", "awi7.rain", "awi7.confetti", "awi12.bubbles", "awi7.smoke", "awi7.fire", "awi7.clouds"] {
            let e = try instance(id)
            let a = try pixels(scene(e), time: 0.4), b = try pixels(scene(e), time: 1.2)
            XCTAssertGreaterThan(difference(a, b), 0.3, "\(id) must animate")
            XCTAssertTrue(stride(from: 0, to: a.count, by: 4).contains { a[$0] > 20 || a[$0 + 2] > 20 }, "\(id) rendered nothing")
        }
    }

    func testSnowDepthLayersAndOldProjectsWithoutNewControls() throws {
        let e = try instance("awi7.snow")
        var one = e; one.params["layers"] = .number(Animated(1))
        XCTAssertGreaterThan(difference(try pixels(scene(e)), try pixels(scene(one))), 0.3)
        var old = e; old.params["depth"] = nil; old.params["layers"] = nil
        XCTAssertLessThan(difference(try pixels(scene(e)), try pixels(scene(old))), 0.01, "missing new controls use their defaults")
        var oldClouds = try instance("awi7.clouds")
        let cloudsNew = try pixels(scene(oldClouds))
        for k in ["warp", "detail", "shading", "shadow"] { oldClouds.params[k] = nil }
        XCTAssertLessThan(difference(cloudsNew, try pixels(scene(oldClouds))), 0.01)
    }

    func testCrystalShardsAreFacetsNotNoise() throws {
        let px = try pixels(scene(try instance("awi12.crystalShards"), color: RGBA(0.3, 0.4, 0.6), size: 128), time: 0.5)
        var sum = 0.0, n = 0.0
        for y in 0..<128 { for x in 0..<127 {
            let i = (y * 128 + x) * 4
            sum += Double(abs(Int(px[i]) - Int(px[i + 4]))); n += 1
        } }
        XCTAssertLessThan(sum / n, 30, "neighbouring pixels inside a facet must be coherent, not white noise")
        let reds = stride(from: 0, to: px.count, by: 4).map { Int(px[$0]) }
        XCTAssertGreaterThan(reds.max()! - reds.min()!, 40, "facets are shaded differently")
    }
}
