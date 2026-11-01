import XCTest
@testable import AWIeffect

/// Anti-stub tests: every registered effect must visibly change the image, and every control must do something.
final class EffectTests: XCTestCase {
    /// Effects that work from the layer's alpha shape (no visible change on an opaque adjustment layer, like in AE).
    static let alphaShaped: Set<String> = ["ae.dropShadow", "ae.simpleChoker", "ae.roughenEdges", "awi.outlineGlow", "awi.energyAura", "awi.rimLight", "awi.outerGlow", "awi.innerGlow", "awi.neonStroke", "awi.border", "awi8.longShadow", "awi11.featherEdges", "awi11.matteChoker", "awi11.alphaLevels", "awi11.edgeRefine", "awi10.bevelAlpha", "awi10.smoothBevel", "awi10.glass", "awi10.edgeAO", "awi10.innerShadow", "awi10.fresnel", "awi16.tornEdges", "awi17.extrudeFlat"]

    private func renderer() throws -> Renderer {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device available; effect tests not run") }
        return r
    }

    /// Colorful test scene with hard edges, brights, darks and a green "screen" area.
    private func scene(effect: EffectInstance?, onAdjustment: Bool = false) -> Project {
        var p = Project.new(name: "fx", width: 160, height: 160, fps: 30, duration: 2, background: RGBA(0.08, 0.06, 0.12))
        var bg = p.makeLayer(name: "green", content: .solid, size: Vec2(160, 60))
        bg.fill = Animated(RGBA(0.1, 0.9, 0.2))
        bg.transform.position = Animated(Vec2(80, 130))
        var star = p.makeLayer(name: "star", content: .shape(.star), size: Vec2(90, 90))
        star.fill = Animated(RGBA(1, 0.95, 0.8))
        star.sides = Animated(5)
        var rect = p.makeLayer(name: "rect", content: .shape(.rectangle), size: Vec2(50, 30))
        rect.fill = Animated(RGBA(0.6, 0.2, 0.9))
        rect.transform.position = Animated(Vec2(40, 40))
        if let effect {
            if onAdjustment {
                var adj = p.makeLayer(name: "adj", content: .adjustment, size: Vec2(160, 160))
                adj.effects = [effect]
                p.layers = [adj, rect, star, bg]
                return p
            }
            star.effects = [effect]
        }
        p.layers = [rect, star, bg]
        return p
    }

    /// Settings that make each effect clearly visible.
    private func visible(_ def: EffectDefinition) -> EffectInstance {
        var e = def.makeInstance()
        func n(_ k: String, _ v: Double) { e.params[k] = .number(Animated(v)) }
        switch def.id {
        case "ae.gaussianBlur": n("blurriness", 12)
        case "ae.directionalBlur": n("length", 20); n("direction", 90)
        case "ae.radialBlur": n("amount", 40)
        case "ae.exposure": n("exposure", 1.5)
        case "ae.brightnessContrast": n("brightness", 60)
        case "ae.hueSaturation": n("hue", 120)
        case "ae.tint": break
        case "ae.levels": n("inBlack", 80)
        case "ae.invert": break
        case "ae.fill": break
        case "awi.vignette": n("amount", 100); n("size", 10)
        case "ae.glow": n("threshold", 40); n("radius", 15); n("intensity", 2)
        case "awi.rgbSplit": n("amount", 6)
        case "ae.fractalNoise": n("scale", 20)
        case "awi.chromaKey": e.params["key"] = .color(Animated(RGBA(0.1, 0.9, 0.2)))
        case "awi.shake": n("amplitude", 30)
        case "ae.curves": n("mids", 75)
        case "awi.looks": n("contrast", 60); n("temp", 50)
        case "ae.offset": e.params["shift"] = .point(Animated(Vec2(0.7, 0.6)))
        case "ae.motionTile": n("tileW", 50); n("tileH", 50); n("outW", 160); n("outH", 160)
        case "awi20.flip": n("angle", 40)
        case "ae.waveWarp": e.params["pinning"] = .choice(2)
        case "awi20.fractalWarp": e.params["pinning"] = .choice(2); n("magnitude", 1.5)
        case "awi20.amWaveWarp": n("magnitude", 10); n("damping", -60)
        case "ae.polarCoordinates": n("interp", 100)
        case "ae.linearWipe", "ae.radialWipe", "ae.irisWipe", "ae.blockDissolve", "ae.venetianBlinds", "ae.gradientWipe": n("completion", 50)
        case "ae.cornerPin": e.params["ul"] = .point(Animated(Vec2(0.2, 0.1)))
        case "ae.colorBalance": n("mr", 60); n("sb", 50)
        case "ae.changeToColor": e.params["from"] = .color(Animated(RGBA(0.6, 0.2, 0.9))); n("tolerance", 20)
        case "ae.strobe": n("duration", 0.2)
        case "awi18.transform": n("x", 25); n("rotation", 20); n("scale", 120)
        case "awi19.colorSelect":
            // Keep the purple rect: the dark purple background is close in color but not brightness, so the
            // brightness and softness controls decide how much of it stays.
            e.params["color"] = .color(Animated(RGBA(0.6, 0.2, 0.9))); n("tolerance", 55)
        case "awi18.particles":
            // Box emitter (so its width / height matter) and short lives (so fade out shows by t = 0.4).
            e.params["emitter"] = .choice(1); n("life", 0.5); n("lifeRandom", 0)
        case "awi18.grade":
            // A visible base grade, with the HSL secondary active so its range / sat / light controls matter.
            n("exposure", 0.6); n("hslHue", 270); n("hslShift", 60); n("hslSat", 40); n("hslLight", 20); n("hslRange", 60)
        case "awi18.puppet":
            // A held pin at the center and a dragged pin near the top: the top bends sideways.
            e.params["pinR0"] = .point(Animated(Vec2(0, 20))); e.params["pinD0"] = .point(Animated(Vec2(0, 20)))
            e.params["pinR1"] = .point(Animated(Vec2(0, -35))); e.params["pinD1"] = .point(Animated(Vec2(28, -30)))
        default: break
        }
        return e
    }

    private func diff(_ a: [UInt8], _ b: [UInt8]) -> Double {
        var s = 0.0
        for i in 0..<min(a.count, b.count) { s += Double(abs(Int(a[i]) - Int(b[i]))) }
        return s / Double(a.count)
    }

    private func render(_ r: Renderer, _ p: Project, t: Double = 0.4) throws -> [UInt8] {
        try XCTUnwrap(r.renderPixels(project: p, time: t, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    func testRegistryIsConsistent() {
        var ids = Set<String>()
        for d in EffectRegistry.all where !EffectRegistry.layerRefIDs.contains(d.id) && d.id != "awi20.softBody" {
            XCTAssertTrue(ids.insert(d.id).inserted, "duplicate id \(d.id)")
            XCTAssertFalse(d.params.isEmpty, "\(d.name) has no controls")
            let inst = d.makeInstance()
            XCTAssertEqual(inst.params.count, d.params.count, "\(d.name) instance missing params")
            XCTAssertNotNil(EffectRegistry.definition(d.id))
            for m in d.aeMatchNames { XCTAssertEqual(EffectRegistry.definition(aeMatchName: m)?.id, d.id) }
        }
    }

    func testEveryEffectChangesTheImage() throws {
        let r = try renderer()
        let base = try render(r, scene(effect: nil))
        for d in EffectRegistry.all where !EffectRegistry.layerRefIDs.contains(d.id) && d.id != "awi20.softBody" {
            let out = try render(r, scene(effect: visible(d), onAdjustment: !d.isTransformEffect && !Self.alphaShaped.contains(d.id)))
            XCTAssertGreaterThan(diff(base, out), 0.5, "\(d.name) did not visibly change the image")
            XCTAssertTrue(out.contains { $0 > 10 }, "\(d.name) rendered black")
        }
    }

    func testEveryEffectWorksOnAdjustmentLayer() throws {
        let r = try renderer()
        let base = try render(r, scene(effect: nil))
        for d in EffectRegistry.all where !d.isTransformEffect && !Self.alphaShaped.contains(d.id) && !EffectRegistry.layerRefIDs.contains(d.id) && d.id != "awi20.softBody" {
            let out = try render(r, scene(effect: visible(d), onAdjustment: true))
            XCTAssertGreaterThan(diff(base, out), 0.5, "\(d.name) did nothing on an adjustment layer")
        }
    }

    func testDisabledEffectIsIdentity() throws {
        let r = try renderer()
        let base = try render(r, scene(effect: nil))
        for d in EffectRegistry.all where !EffectRegistry.layerRefIDs.contains(d.id) && d.id != "awi20.softBody" {
            var e = visible(d)
            e.isEnabled = false
            XCTAssertLessThan(diff(base, try render(r, scene(effect: e))), 0.01, "disabled \(d.name) still changes output")
        }
    }

    /// Every slider must change the result somewhere in its range (catches unwired params).
    func testEveryNumericControlIsWired() throws {
        let r = try renderer()
        // Params that only matter in a mode not active in this test (documented, not silent).
        let modal: Set<String> = ["ae.hueSaturation/colorizeSat", "awi18.negativeFlash/threshold", "awi18.grade/lutStrength", "awi18.transform/x", "awi18.transform/y"]
        for d in EffectRegistry.all where !EffectRegistry.layerRefIDs.contains(d.id) && d.id != "awi20.softBody" {
            for pd in d.params {
                guard case .number(let lo, let hi, _, _) = pd.kind, !modal.contains("\(d.id)/\(pd.id)") else { continue }
                var a = visible(d), b = visible(d)
                a.params[pd.id] = .number(Animated(lo + (hi - lo) * 0.02))
                b.params[pd.id] = .number(Animated(lo + (hi - lo) * 0.6))
                // Adjustment layer = effect sees the whole varied scene, not just one flat shape.
                let adj = !d.isTransformEffect && !Self.alphaShaped.contains(d.id)
                let ra = try render(r, scene(effect: a, onAdjustment: adj)), rb = try render(r, scene(effect: b, onAdjustment: adj))
                XCTAssertGreaterThan(diff(ra, rb), 0.05, "\(d.name) › \(pd.name) does nothing")
            }
        }
    }

    func testGaussianBlurIsSymmetricAndConservesBrightness() throws {
        let r = try renderer()
        var p = Project.new(name: "b", width: 101, height: 101, fps: 30, background: .black)
        var dot = p.makeLayer(name: "d", content: .solid, size: Vec2(21, 21))
        dot.fill = Animated(.white)
        var e = EffectRegistry.gaussianBlur.makeInstance()
        e.params["blurriness"] = .number(Animated(10))
        dot.effects = [e]
        p.layers = [dot]
        let px = try render(r, p, t: 0)
        func at(_ x: Int, _ y: Int) -> Int { Int(px[(y * 101 + x) * 4]) }
        XCTAssertEqual(at(40, 50), at(60, 50), accuracy: 2)
        XCTAssertEqual(at(50, 40), at(50, 60), accuracy: 2)
        XCTAssertLessThan(at(50, 50), 255)
        XCTAssertGreaterThan(at(35, 50), 5, "blur did not spread past the layer bounds")
    }

    func testShakeMovesOverTime() throws {
        let r = try renderer()
        var e = EffectRegistry.shake.makeInstance()
        e.params["amplitude"] = .number(Animated(25))
        let p = scene(effect: e)
        XCTAssertGreaterThan(diff(try render(r, p, t: 0.1), try render(r, p, t: 0.6)), 0.5)
    }

    func testChromaKeyRemovesGreen() throws {
        let r = try renderer()
        var p = Project.new(name: "k", width: 64, height: 64, fps: 30, background: .black)
        var g = p.makeLayer(name: "g", content: .solid, size: Vec2(64, 64))
        g.fill = Animated(RGBA(0.05, 0.85, 0.1))
        g.effects = [EffectRegistry.chromaKey.makeInstance()]
        p.layers = [g]
        let px = try render(r, p, t: 0)
        XCTAssertLessThan(Int(px[(32 * 64 + 32) * 4 + 1]), 20, "green screen not keyed out")
    }

    func testOldProjectWithoutEffectsStillDecodes() throws {
        var p = Project.new(name: "old", width: 10, height: 10, fps: 30)
        p.layers.append(p.makeLayer(name: "l", content: .solid, size: Vec2(10, 10)))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String: Any]
        var layers = json["layers"] as! [[String: Any]]
        layers[0].removeValue(forKey: "effects")
        layers[0].removeValue(forKey: "blendMode")
        json["layers"] = layers
        let data = try JSONSerialization.data(withJSONObject: json)
        let back = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(back.layers[0].effects.count, 0)
        XCTAssertEqual(back.layers[0].blendMode, .normal)
    }

    /// Layer-referencing effects: a displacement map from another layer moves pixels; Set Matte cuts by it.
    func testLayerReferenceEffects() throws {
        let r = try renderer()
        var p = scene(effect: nil)
        var map = p.makeLayer(name: "map", content: .solid, size: Vec2(160, 160))
        map.fill = Animated(RGBA(1, 1, 1))
        map.isVisible = true
        p.layers.append(map)
        let base = try render(r, p)
        var d = EffectRegistry.displacementMap18.makeInstance()
        d.params["h"] = .number(Animated(40))
        d.text = ["layer": map.id.uuidString]
        var withMap = p
        if let i = withMap.layers.firstIndex(where: { $0.name == "star" }) { withMap.layers[i].effects = [d] }
        XCTAssertGreaterThan(diff(base, try render(r, withMap)), 0.3, "displacement map from another layer moves pixels")
        var m = EffectRegistry.setMatte18.makeInstance()
        m.params["invert"] = .toggle(true)
        m.text = ["layer": map.id.uuidString]
        var matted = p
        if let i = matted.layers.firstIndex(where: { $0.name == "star" }) { matted.layers[i].effects = [m] }
        XCTAssertGreaterThan(diff(base, try render(r, matted)), 0.3, "inverted set matte from a full white layer hides the star")
    }
}
