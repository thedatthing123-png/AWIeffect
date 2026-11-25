import XCTest
@testable import AWIeffect

/// Anti-stub tests: every registered effect must visibly change the image, and every control must do something.
final class EffectTests: XCTestCase {
    func testSmoothGlitchesMoveBetweenHeldPatternFrames() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        for def in [EffectRegistry.waveGlitch18, EffectRegistry.earthquake14,
                    EffectRegistry.sliceGlitch19, EffectRegistry.displaceGlitch19,
                    EffectRegistry.glitchBlocks6, EffectRegistry.glitchLines6] {
            var effect = def.makeInstance()
            if effect.params["base"] != nil { effect.params["base"] = .number(Animated(100)) }
            let p = scene(effect: effect, onAdjustment: true)
            let a = try XCTUnwrap(r.renderPixels(project: p, time: 0.31, mediaURL: { URL(fileURLWithPath: $0) })).rgba
            let b = try XCTUnwrap(r.renderPixels(project: p, time: 0.31 + 1.0 / 60, mediaURL: { URL(fileURLWithPath: $0) })).rgba
            let changed = zip(a, b).filter { abs(Int($0.0) - Int($0.1)) > 1 }.count
            XCTAssertGreaterThan(changed, 8, "\(def.name) must animate between held pattern updates")
        }
    }

    /// Effects that work from the layer's alpha shape (no visible change on an opaque adjustment layer, like in AE).
    static let alphaShaped: Set<String> = ["awi.amref.e616b758142ef", "awi.amref.e7b0d60717ad7", "awi.amref.e656bf85e2a2e", "ae.dropShadow", "ae.simpleChoker", "ae.roughenEdges", "awi.outlineGlow", "awi.energyAura", "awi.rimLight", "awi.outerGlow", "awi.innerGlow", "awi.neonStroke", "awi.border", "awi8.longShadow", "awi11.featherEdges", "awi11.matteChoker", "awi11.alphaLevels", "awi11.edgeRefine", "awi10.bevelAlpha", "awi10.smoothBevel", "awi10.glass", "awi10.edgeAO", "awi10.innerShadow", "awi10.fresnel", "awi16.tornEdges", "awi17.extrudeFlat"]

    private func renderer() throws -> Renderer {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device available; effect tests not run") }
        return r
    }

    private func textScene(effect: EffectInstance?) -> Project {
        var p = Project.new(name: "text fx", width: 160, height: 160, fps: 30, duration: 2, background: .black)
        var layer = p.makeLayer(name: "text", content: .text, size: Vec2(120, 40))
        layer.text = TextData(string: "AWI"); layer.text!.fontSize = 28
        layer.effects = effect.map { [$0] } ?? []; p.layers = [layer]
        return p
    }

    private func drawingScene(effect: EffectInstance?) -> Project {
        var p = Project.new(name: "path fx", width: 160, height: 160, fps: 30, duration: 2, background: .black)
        var layer = p.makeLayer(name: "freehand", content: .shape(.path), size: Vec2(120, 80))
        layer.path = Animated(BezierPath(vertices: [PathVertex(point: Vec2(-60, -35)), PathVertex(point: Vec2(0, 35)), PathVertex(point: Vec2(60, -35))], closed: false))
        layer.fill = Animated(RGBA(0, 0, 0, 0)); layer.stroke.enabled = true; layer.stroke.width = Animated(8); layer.stroke.color = Animated(.white)
        layer.effects = effect.map { [$0] } ?? []; p.layers = [layer]; return p
    }

    /// Colorful test scene with hard edges, brights, darks and a green "screen" area.
    private func scene(effect: EffectInstance?, onAdjustment: Bool = false) -> Project {
        if effect?.typeID == "awi23.drawProgress" { return drawingScene(effect: effect) }
        if let effect, EffectRegistry.definition(effect.typeID)?.category == .text { return textScene(effect: effect) }
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
        // A transition needs a progressed fixture to show its breakup clearly.
        case "awi.amref.eeab7e403ece5": n("progress", 65)
        // Custom palette mode activates Shades; fixed retro palettes do not use it.
        case "awi.amref.ea4ee3a4adc94": e.params["palette"] = .choice(7)
        // A channel router starts neutral; exercise an explicit HSV swap.
        case "awi.amref.ec2cdadc6c8df": e.params["hue"] = .choice(2); e.params["sat"] = .choice(0)
        case "awi.amref.e6b65a73fb112": n("orient_y",35)
        case "awi.amref.e8e0a6f88c6f1": n("wipePercent",55)
        case "awi.amref.ee440d77aa644": n("progress",0.5)
        case "awi.amref.e5ad5e1e9a0fb": n("flickerThreshold",0)
        case "awi.ref.liquidLensWipe", "awi.ref.voronoiPeel": n("progress", 55)
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
        case "awi.textSpacing": n("spacing", 25)
        case "awi23.drawProgress": n("end", 45)
        case "awi18.transform": n("x", 25); n("rotation", 20); n("scale", 120)
        // Lines alone are thin on the small test shapes; on paper the whole look shows.
        case "awi.inkSketch": n("paper", 1)
        // Key the purple rect (the test image has no green), so saturation and brightness limits matter.
        case "awi11.colorRangeKey": n("hue", 268); n("width", 30)
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

    /// Unmult keeps premultiplied color, so it only shows over a background that isn't black.
    func testUnmultTurnsBlackIntoTransparency() throws {
        let r = try renderer()
        func pixel(_ gray: Double, amount: Double, gamma: Double = 1) throws -> [UInt8] {
            var p = Project.new(name: "unmult", width: 32, height: 32, fps: 30, duration: 1, background: .white)
            var l = p.makeLayer(name: "light", content: .solid, size: Vec2(32, 32))
            l.fill = Animated(RGBA(gray, gray, gray))
            var e = try XCTUnwrap(EffectRegistry.definition("awi11.unmultiply")).makeInstance()
            e.params["amount"] = .number(Animated(amount)); e.params["gamma"] = .number(Animated(gamma))
            l.effects = [e]; p.layers = [l]
            let out = try render(r, p)
            return Array(out[(16 * 32 + 16) * 4..<(16 * 32 + 16) * 4 + 4])
        }
        XCTAssertGreaterThan(try pixel(0, amount: 100)[0], 245, "black is gone: the white background shows")
        XCTAssertLessThan(try pixel(0, amount: 0)[0], 10, "amount 0 changes nothing")
        XCTAssertGreaterThan(try pixel(1, amount: 100)[3], 250, "full brightness stays solid")
        XCTAssertNotEqual(try pixel(0.25, amount: 100, gamma: 0.4)[0], try pixel(0.25, amount: 100, gamma: 2)[0], "gamma shapes the alpha")
    }

    func testEveryEffectChangesTheImage() throws {
        let r = try renderer()
        let base = try render(r, scene(effect: nil))
        for d in EffectRegistry.all where !EffectRegistry.layerRefIDs.contains(d.id) && d.id != "awi20.softBody" && d.id != "awi11.unmultiply" {
            let out = try render(r, scene(effect: visible(d), onAdjustment: !d.isTransformEffect && !Self.alphaShaped.contains(d.id)))
            let comparison = d.id == "awi23.drawProgress" ? try render(r, drawingScene(effect: nil)) : (d.category == .text ? try render(r, textScene(effect: nil)) : base)
            XCTAssertGreaterThan(diff(comparison, out), 0.5, "\(d.name) did not visibly change the image")
            XCTAssertTrue(out.contains { $0 > 10 }, "\(d.name) rendered black")
        }
    }

    func testEveryEffectWorksOnAdjustmentLayer() throws {
        let r = try renderer()
        let base = try render(r, scene(effect: nil))
        for d in EffectRegistry.all where !d.isTransformEffect && !Self.alphaShaped.contains(d.id) && !EffectRegistry.layerRefIDs.contains(d.id) && d.id != "awi20.softBody" && d.id != "awi11.unmultiply" {
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
            let comparison = d.id == "awi23.drawProgress" ? try render(r, drawingScene(effect: nil)) : (d.category == .text ? try render(r, textScene(effect: nil)) : base)
            XCTAssertLessThan(diff(comparison, try render(r, scene(effect: e))), 0.01, "disabled \(d.name) still changes output")
        }
    }

    /// Every slider must change the result somewhere in its range (catches unwired params).
    func testEveryNumericControlIsWired() throws {
        try verifyNumericControls(shard:0)
    }
    func testNumericControlsPart1()throws { try verifyNumericControls(shard:1) }
    func testNumericControlsPart2()throws { try verifyNumericControls(shard:2) }
    func testNumericControlsPart3()throws { try verifyNumericControls(shard:3) }
    func testNumericControlsPart4()throws { try verifyNumericControls(shard:4) }
    func testNumericControlsPart5()throws { try verifyNumericControls(shard:5) }
    func testNumericControlsPart6()throws { try verifyNumericControls(shard:6) }
    func testNumericControlsPart7()throws { try verifyNumericControls(shard:7) }
    private func verifyNumericControls(shard:Int)throws {
        let r = try renderer()
        // Params that only matter in a mode not active in this test (documented, not silent).
        let modal: Set<String> = ["ae.hueSaturation/colorizeSat", "awi18.negativeFlash/threshold", "awi18.grade/lutStrength", "awi18.transform/x", "awi18.transform/y",
                                   // Whole-number phases line up (loops), and the tile output only shows past the layer bounds.
                                   "awi20.amWaveWarp/phase", "ae.motionTile/outW", "ae.motionTile/outH",
                                   // Cycle length only applies with Cycle Evolution on; tolerance only in Similar/Dissimilar;
                                   // edge cleaning only touches the few soft key-edge pixels (covered in BackgroundColorRemakeTests).
                                   "ae.fractalNoise/cycles", "ae.lumaKey/tolerance", "ae.lumaKey/edgeClean",
                                   // Same: cycle length only applies with Cycle Evolution on.
                                   "ae.turbulentDisplace/cycleLen", "ae.turbulentDisplace/pinSoft",
                                   // Curve point positions only matter once the curve is bent (flat by default).
                                   // Added curve points only act once switched on.
                                   "awi18.grade/me1x", "awi18.grade/me1y", "awi18.grade/me2x", "awi18.grade/me2y", "awi18.grade/me3x", "awi18.grade/me3y", "awi18.grade/re1x", "awi18.grade/re1y", "awi18.grade/re2x", "awi18.grade/re2y", "awi18.grade/re3x", "awi18.grade/re3y", "awi18.grade/ge1x", "awi18.grade/ge1y", "awi18.grade/ge2x", "awi18.grade/ge2y", "awi18.grade/ge3x", "awi18.grade/ge3y", "awi18.grade/be1x", "awi18.grade/be1y", "awi18.grade/be2x", "awi18.grade/be2y", "awi18.grade/be3x", "awi18.grade/be3y",
                                   "awi18.grade/m25x", "awi18.grade/m50x", "awi18.grade/m75x", "awi18.grade/r25x", "awi18.grade/r50x", "awi18.grade/r75x", "awi18.grade/g25x", "awi18.grade/g50x", "awi18.grade/g75x", "awi18.grade/b25x", "awi18.grade/b50x", "awi18.grade/b75x",
                                   // Hue softness and spill only act on colors at the edge of the keyed hue range (the test shapes are flat colors).
                                   "awi11.colorRangeKey/softness", "awi11.colorRangeKey/spill",
                                   // Burst and floor controls only act with Burst / Floor switched on.
                                   "awi18.particles/burstTime", "awi18.particles/burstCount", "awi18.particles/floorY", "awi18.particles/bounce"]
        for (index,d) in EffectRegistry.all.enumerated() where index%8==shard && !EffectRegistry.layerRefIDs.contains(d.id) && d.id != "awi20.softBody" && d.id != "awi11.unmultiply" {
            for pd in d.params {
                guard case .number(let lo, let hi, _, _) = pd.kind, !modal.contains("\(d.id)/\(pd.id)"),
                      // Hue-vs curves and their qualifiers (softness, sat/luma range) only move pixels of their own hue (checked on a color wheel in the R4 grade tests).
                      !(d.id == "awi18.grade" && (pd.id.hasPrefix("hue") || pd.id.hasPrefix("q"))) else { continue }
                var a = visible(d), b = visible(d)
                // Seed selects a random rotation field; a zero random strength
                // intentionally leaves all tiles at their fixed Rotation.
                if d.id == "awi.amref.e8404b5764d4f", pd.id == "seed" {
                    a.params["strength"] = .number(Animated(0.35)); b.params["strength"] = .number(Animated(0.35))
                }
                if d.id == "awi.amref.ec88108d754e8" {
                    // Density is the glitch-block grid; RGB fields are the
                    // single-color dot mode, not the source-color mode.
                    if pd.id == "density" { a.params["preset"] = .choice(5); b.params["preset"] = .choice(5) }
                    if ["range", "decay", "fade"].contains(pd.id) {
                        a.params["cutoff"] = .number(Animated(0.15)); b.params["cutoff"] = .number(Animated(0.15))
                        a.params["range"] = .number(Animated(1)); b.params["range"] = .number(Animated(1))
                    }
                    if pd.id == "generators" {
                        a.params["distortion"] = .number(Animated(4)); b.params["distortion"] = .number(Animated(4))
                        a.params["compress"] = .number(Animated(3)); b.params["compress"] = .number(Animated(3))
                    }
                    if ["colorR", "colorG", "colorB"].contains(pd.id) { a.params["colorMode"] = .choice(1); b.params["colorMode"] = .choice(1) }
                }
                if d.id == "awi.amref.e3418485b643b", pd.id == "flicker" {
                    // A large, dense dust field exercises flicker rather than
                    // depending on one tiny mark in the 128px test scene.
                    a.params["density"] = .number(Animated(800)); b.params["density"] = .number(Animated(800))
                    a.params["dotSize"] = .number(Animated(10)); b.params["dotSize"] = .number(Animated(10))
                }
                if d.id == "awi.amref.e7b0d60717ad7", pd.id == "quality" {
                    // Accuracy affects accumulated soft shadow coverage. A
                    // fully solid maximum-alpha shadow can converge earlier.
                    a.params["solidity"] = .number(Animated(0.35)); b.params["solidity"] = .number(Animated(0.35))
                }
                if d.id == "awi18.waveGlitch", pd.id == "steps" {
                    a.params["holdFrames"] = .toggle(true); b.params["holdFrames"] = .toggle(true)
                }
                a.params[pd.id] = .number(Animated(lo + (hi - lo) * 0.02))
                b.params[pd.id] = .number(Animated(lo + (hi - lo) * 0.6))
                if d.id == "awi.textSpacing" && pd.id == "spacing" {
                    // Use visible spacing within this finite text fixture; extreme spacing is covered by stress tests.
                    a.params[pd.id] = .number(Animated(-5)); b.params[pd.id] = .number(Animated(18))
                }
                if d.id == "awi.halftone" {
                    if pd.id == "size" { a.params["version"] = .choice(1); b.params["version"] = .choice(1) }
                    if pd.id == "phase" { a.params["phase"] = .number(Animated(-0.2)); b.params["phase"] = .number(Animated(0.35)) }
                }
                if d.id == "awi.deepGlow" && pd.id == "softness" {
                    a.params["threshold"] = .number(Animated(50)); b.params["threshold"] = .number(Animated(50))
                }
                if d.id == "awi6.bend" && ["head", "tail"].contains(pd.id) {
                    // End tuning limits curvature when Start leaves a short, wide segment.
                    // Tail has no bend at all in Freeze, so explicitly exercise Same Side.
                    a.params["angle"] = .number(Animated(150)); b.params["angle"] = .number(Animated(150))
                    let start = pd.id == "head" ? 85.0 : 15.0
                    a.params["start"] = .number(Animated(start)); b.params["start"] = .number(Animated(start))
                    a.params["before"] = .choice(1); b.params["before"] = .choice(1)
                }
                // Reference controls must be sampled inside their active domain:
                // periodic endpoints can be identical, and frequency controls
                // intentionally do nothing while their amplitude is zero.
                func both(_ key: String, _ value: Double) {
                    a.params[key] = .number(Animated(value)); b.params[key] = .number(Animated(value))
                }
                func compare(_ low: Double, _ high: Double) {
                    a.params[pd.id] = .number(Animated(low)); b.params[pd.id] = .number(Animated(high))
                }
                if d.id == "awi.amref.efc580f636abc", pd.id == "EVO2" { both("SPREAD",3) }
                if ["awi.amref.e150bc7e80a57","awi.amref.e255ba2d47539"].contains(d.id), pd.id == "phase" {
                    compare(0.13,0.67)
                }
                if d.id == "awi.amref.ecef0c8a880bd" {
                    // Travel=1 is the identity point of the two-second cycle.
                    if pd.id == "time" { compare(0.7,1.35) }
                    else if ["fbmScale","dispClamp"].contains(pd.id) { both("time",0.7) }
                }
                if ["Cross 3D","Hexagonal Prism","Raster Extrude","Star Polyhedron"].contains(d.name),
                   ["position_x","position_y"].contains(pd.id) {
                    // Source position units are hundredths of world space;
                    // +/-10000 sends both samples out of the camera frustum.
                    let center: Double = pd.id == "position_y" ? 55 : 0
                    compare(center-35,center+35)
                }
                if d.name == "Hexagon Tile Rotate", pd.id == "seed" { both("twirl",135) }
                if d.id == "awi.amref.e821e62f4d00a" {
                    if ["dissolveSpeed","dissolveCurve"].contains(pd.id) { both("dissolveAmt",0.42) }
                    for axis in ["x","y","z","tilt"] {
                        if pd.id.hasPrefix(axis), pd.id.contains("Freq") || pd.id.hasSuffix("Phase") {
                            both(axis+"RandAmp",axis == "tilt" ? 4 : 0.3)
                            both(axis+"WaveAmp",axis == "tilt" ? 6 : 0.3)
                        }
                    }
                    if pd.id == "xPhase" {
                        // Isolate a sine wave and compare opposite peaks at
                        // t=0.4, f=0.5. Broad range fractions nearly coincide.
                        both("amplitude",12); both("xRandAmp",0)
                        both("xWaveAmp",0.8); both("xWaveFreq",0.5)
                        compare(0.1,1.1)
                    }
                    if ["rgbRandomness","rgbFrequency"].contains(pd.id) {
                        both("rgbRandomness",0.8); both("zRandAmp",0.3); both("tiltRandAmp",4)
                        if pd.id == "rgbRandomness" { compare(0.02,0.6) }
                    }
                }
                if d.id == "awi.amref.e5ad5e1e9a0fb",
                   ["tearHeightMin","tearScanFreq","tearScanAmp","bandMix"].contains(pd.id) {
                    both("tearHeightMin",0.6); both("tearHeightRand",0.3)
                    both("tearScanAmp",0.35)
                    if ["tearScanFreq","tearScanAmp","bandMix"].contains(pd.id) {
                        // Band blending and scanlines share the colored-band branch;
                        // force that branch instead of relying on its seed.
                        both("bandProbThr",0); both("blockAffectThr",1)
                        a.params["enableColorBands"] = .toggle(true)
                        b.params["enableColorBands"] = .toggle(true)
                    }
                    if pd.id == "tearHeightMin" { compare(0.02,0.6) }
                    if pd.id == "tearScanAmp" { compare(0.02,0.6) }
                }
                if d.id == "awi.amref.ee440d77aa644", pd.id == "bgSpeed" { both("time",13.7) }
                if d.id == "awi.amref.e616b758142ef" {
                    // Isolate the edited texture/displacement so another
                    // opaque Grunge stage cannot cover its result.
                    let prefix=String(pd.id.prefix(2))
                    if prefix.first == "t", let index=Int(prefix.suffix(1)) {
                        for other in 1...8 { a.params["t\(other)active"] = .toggle(other == index); b.params["t\(other)active"] = .toggle(other == index) }
                        a.params[prefix+"region"] = .choice(0); b.params[prefix+"region"] = .choice(0)
                        if pd.id != prefix+"alpha" { both(prefix+"alpha",100) }
                        if pd.id != prefix+"grain" { both(prefix+"grain",15) }
                        if pd.id.hasSuffix("scale") { compare(0.6,1.6) }
                    } else if prefix == "d1" || prefix == "d2" {
                        a.params[prefix+"offset"] = .point(Animated(Vec2(250,160))); b.params[prefix+"offset"] = .point(Animated(Vec2(250,160)))
                        a.params[prefix+"region"] = .choice(2); b.params[prefix+"region"] = .choice(2)
                        if !pd.id.hasSuffix("grain") { both(prefix+"grain",15) }
                        if pd.id.hasSuffix("scale") { compare(0.6,1.6) }
                    }
                }
                // Adjustment layer = effect sees the whole varied scene, not just one flat shape.
                let adj = !d.isTransformEffect && !Self.alphaShaped.contains(d.id)
                let ra = try render(r, scene(effect: a, onAdjustment: adj)), rb = try render(r, scene(effect: b, onAdjustment: adj))
                var response=diff(ra,rb)
                // Reference shaders expose mode-specific controls (lighting,
                // noise families, blend modes). Exercise those modes rather
                // than treating a neutral/inactive default as a dead control.
                if response <= 0.05, d.id.hasPrefix("awi.amref.") {
                    var modes: [(String,ParamValue)] = []
                    for controller in d.params where controller.id != pd.id {
                        switch controller.kind {
                        case .choice(let labels):
                            modes += labels.indices.map { (controller.id,.choice($0)) }
                        case .toggle:
                            modes.append((controller.id,.toggle(true)))
                            modes.append((controller.id,.toggle(false)))
                        default: break
                        }
                    }
                    for (key,value) in modes {
                        var aa=a,bb=b;aa.params[key]=value;bb.params[key]=value
                        let x=try render(r,scene(effect:aa,onAdjustment:adj))
                        let y=try render(r,scene(effect:bb,onAdjustment:adj))
                        response=max(response,diff(x,y))
                        if response>0.05 { break }
                    }
                }
                XCTAssertGreaterThan(response, 0.05, "\(d.name) › \(pd.name) does nothing in the tested modes")
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
