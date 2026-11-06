import XCTest
@testable import AWIeffect

/// Batch 27 remakes: print screens, manga ink, film / TV looks and glitches render, react to their controls, open
/// older saved instances unchanged, and film/TV noise stays monochrome.
final class StylizeRetroRemakeTests: XCTestCase {
    private func renderer() throws -> Renderer {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device available; effect tests not run") }
        return r
    }

    /// A full-frame gray solid with a bright star and a purple rectangle; the effect sits on the solid.
    private func scene(_ effect: EffectInstance?, gray: Double = 0.5, shapes: Bool = true) -> Project {
        var p = Project.new(name: "fx27", width: 160, height: 160, fps: 30, duration: 2, background: .black)
        var bg = p.makeLayer(name: "gray", content: .solid, size: Vec2(160, 160))
        bg.fill = Animated(RGBA(gray, gray, gray))
        bg.transform.position = Animated(Vec2(80, 80))
        var star = p.makeLayer(name: "star", content: .shape(.star), size: Vec2(90, 90))
        star.fill = Animated(RGBA(1, 0.95, 0.8))
        star.sides = Animated(5)
        var rect = p.makeLayer(name: "rect", content: .shape(.rectangle), size: Vec2(50, 30))
        rect.fill = Animated(RGBA(0.25, 0.1, 0.4))
        rect.transform.position = Animated(Vec2(40, 40))
        if let effect {
            var adj = p.makeLayer(name: "adj", content: .adjustment, size: Vec2(160, 160))
            adj.effects = [effect]
            p.layers = shapes ? [adj, rect, star, bg] : [adj, bg]
        } else {
            p.layers = shapes ? [rect, star, bg] : [bg]
        }
        return p
    }

    private func render(_ r: Renderer, _ p: Project, t: Double = 0.4) throws -> [UInt8] {
        try XCTUnwrap(r.renderPixels(project: p, time: t, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    private func diff(_ a: [UInt8], _ b: [UInt8]) -> Double {
        var s = 0.0
        for i in 0..<min(a.count, b.count) { s += Double(abs(Int(a[i]) - Int(b[i]))) }
        return s / Double(max(1, a.count))
    }

    private func instance(_ id: String) throws -> EffectInstance {
        try XCTUnwrap(EffectRegistry.definition(id), "missing \(id)").makeInstance()
    }

    func testPrintScreensRenderAndShapeMatters() throws {
        let r = try renderer()
        let plain = try render(r, scene(nil))
        for id in ["awi.halftone", "awi16.halftoneLines", "awi8.cmykHalftone", "awi16.mangaScreentone",
                   "awi16.crossHatch", "awi16.stipple", "awi16.woodcut"] {
            let out = try render(r, scene(try instance(id)))
            XCTAssertGreaterThan(diff(plain, out), 2, "\(id) does not visibly change the picture")
        }
        for id in ["awi.halftone", "awi8.cmykHalftone", "awi16.mangaScreentone"] {
            var round = try instance(id)
            var square = round
            round.params["shape"] = .choice(0)
            square.params["shape"] = .choice(1)
            let a = try render(r, scene(round)), b = try render(r, scene(square))
            XCTAssertGreaterThan(diff(a, b), 0.3, "\(id): dot shape has no effect")
        }
    }

    /// Instances saved before the new controls existed must open with the same look as the new defaults.
    func testOlderSavedInstancesMatchDefaults() throws {
        let r = try renderer()
        let cases: [(String, [String])] = [
            ("awi16.mangaScreentone", ["levels", "shape", "contrast"]),
            ("awi16.crossHatch", ["angle", "contrast"]),
            ("awi16.woodcut", ["angle"]),
            ("awi8.cmykHalftone", ["shape", "paper", "contrast"]),
            ("awi.inkSketch", ["blacks", "ink", "paperColor"]),
        ]
        for (id, newKeys) in cases {
            let full = try instance(id)
            var old = full
            for k in newKeys { old.params.removeValue(forKey: k) }
            let a = try render(r, scene(full)), b = try render(r, scene(old))
            XCTAssertLessThan(diff(a, b), 0.01, "\(id): an older saved instance renders differently")
        }
        // Halftone keeps its saved Rendering version behavior: no shape key = the established round-dot renderer.
        var legacy = try instance("awi.halftone")
        legacy.params["version"] = .choice(0)
        var legacyOld = legacy
        legacyOld.params.removeValue(forKey: "shape")
        XCTAssertLessThan(diff(try render(r, scene(legacy)), try render(r, scene(legacyOld))), 0.01)
    }

    func testInkLooksDrawLinesOnEdges() throws {
        let r = try renderer()
        let plain = try render(r, scene(nil))
        for id in ["awi.inkSketch", "awi8.pencilSketch", "awi8.celShading", "awi16.cartoonOutline"] {
            let out = try render(r, scene(try instance(id)))
            XCTAssertGreaterThan(diff(plain, out), 1, "\(id) does not visibly change the picture")
        }
        // Lines live on edges: on a flat solid, Ink Sketch (no paper, no solid blacks) leaves it nearly untouched.
        let flatPlain = try render(r, scene(nil, shapes: false))
        let flatInk = try render(r, scene(try instance("awi.inkSketch"), shapes: false))
        XCTAssertLessThan(diff(flatPlain, flatInk), 3, "Ink Sketch draws ink on a flat area")
    }

    func testFilmBurnKeepsThePictureInTheMiddle() throws {
        let r = try renderer()
        let plain = try render(r, scene(nil, shapes: false))
        let burn = try render(r, scene(try instance("awi13.filmBurn"), shapes: false), t: 1.3)
        let w = 160, mid = (80 * w + 80) * 4
        for ch in 0..<3 { XCTAssertLessThan(abs(Int(burn[mid + ch]) - Int(plain[mid + ch])), 30, "Film Burn washes out the center") }
        var mean = 0.0
        for i in stride(from: 0, to: burn.count, by: 4) { mean += Double(burn[i]) + Double(burn[i + 1]) + Double(burn[i + 2]) }
        mean /= Double(burn.count / 4 * 3)
        XCTAssertLessThan(mean, 235, "Film Burn renders nearly blank white")
        XCTAssertGreaterThan(diff(plain, burn), 1, "Film Burn adds no burn")
    }

    /// Film and TV noise on a gray picture stays gray: no random rainbow pixels.
    func testFilmAndTVNoiseIsMonochrome() throws {
        let r = try renderer()
        var grain = try instance("ae.noise")
        grain.params["amount"] = .number(Animated(60))
        var tv = try instance("awi13.analogTV")
        tv.params["noise"] = .number(Animated(80))
        let crt = try instance("awi.crt"), scan = try instance("awi6.scanDistort")
        for e in [grain, tv, crt, scan] {
            let px = try render(r, scene(e, shapes: false))
            var worst = 0
            for i in stride(from: 0, to: px.count, by: 4) {
                let a = Int(px[i]), b = Int(px[i + 1]), c = Int(px[i + 2])
                worst = max(worst, max(abs(a - b), max(abs(b - c), abs(a - c))))
            }
            // The CRT grille tints columns on purpose; everything else must stay neutral.
            XCTAssertLessThan(worst, e.typeID == "awi.crt" ? 140 : 6, "\(e.typeID) adds colored noise to a gray picture")
        }
        var colorGrain = grain
        colorGrain.params["color"] = .toggle(true)
        let px = try render(r, scene(colorGrain, shapes: false))
        var chroma = 0.0
        for i in stride(from: 0, to: px.count, by: 4) { chroma += Double(abs(Int(px[i]) - Int(px[i + 1])) + abs(Int(px[i + 1]) - Int(px[i + 2]))) }
        chroma /= Double(px.count / 4)
        XCTAssertLessThan(chroma, 40, "color grain reads as rainbow noise")
    }

    func testGlitchesHitDuringBursts() throws {
        let r = try renderer()
        let plain = try render(r, scene(nil))
        for id in ["awi19.slice", "awi19.interlace", "awi19.displace"] {
            var e = try instance(id)
            e.params["base"] = .number(Animated(100))
            let out = try render(r, scene(e))
            XCTAssertGreaterThan(diff(plain, out), 0.5, "\(id) shows no damage with Always On at 100%")
        }
    }
}
