import XCTest
import UIKit
@testable import AWIeffect

final class EffectsLargeBatchTests: XCTestCase {
    private func scene(_ effect: EffectInstance? = nil) -> Project {
        var p = Project.new(name: "batch", width: 128, height: 128, fps: 30, duration: 2, background: RGBA(0,0,0,0))
        var l = p.makeLayer(name: "disc", content: .shape(.ellipse), size: Vec2(48,48))
        l.fill = Animated(RGBA(0.3,0.6,0.9)); l.effects = effect.map { [$0] } ?? []; p.layers = [l]; return p
    }
    private func pixels(_ p: Project, time: Double = 0.4) throws -> [UInt8] {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device") }
        return try XCTUnwrap(r.renderPixels(project: p, time: time, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }
    private func diff(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a,b).reduce(0.0) { $0 + Double(abs(Int($1.0)-Int($1.1))) } / Double(a.count)
    }
    func testBatchZeroSettingsPreserveImageAndTransparentPixels() throws {
        let neutral: [(String,[String:Double])] = [
            ("awi24.distanceWarp",["amount":0]), ("awi24.spectralPrism",["amount":0]),
            ("awi24.lensCalibration",["k1":0,"k2":0,"p1":0,"p2":0]),
            ("awi24.matteFrequency",["base":100,"detail":100]), ("awi24.localContrastMatte",["mix":0])
        ]
        let baseline = try pixels(scene())
        for (id, values) in neutral {
            var e = try XCTUnwrap(EffectRegistry.definition(id)).makeInstance()
            for (k,v) in values { e.params[k] = .number(Animated(v)) }
            let output = try pixels(scene(e))
            XCTAssertLessThan(diff(baseline, output), 0.6, id)
            for i in stride(from: 0, to: output.count, by: 4) where output[i+3] == 0 {
                XCTAssertEqual(Array(output[i..<i+3]), [0,0,0], id)
            }
        }
    }
    func testDistanceFieldPreservesHoleSignAndHasMeasuredFalloff() throws {
        let e = try XCTUnwrap(EffectRegistry.definition("awi24.alphaDistance")).makeInstance()
        var p = scene(e)
        p.layers[0].masks = [LayerMask(name: "hole", path: Animated(.ellipse(size: Vec2(12,12))), mode: .subtract)]
        let output = try pixels(p)
        func red(_ x: Int, _ y: Int) -> Int { Int(output[(y*128+x)*4]) }
        XCTAssertLessThan(red(64,64), 128, "hole must be outside")
        XCTAssertGreaterThan(red(80,64), 128, "disc must be inside")
        XCTAssertLessThan(red(100,64), 128, "outside must be negative")
        XCTAssertLessThan(abs(red(80,64)-red(47,64)), 5, "symmetric geometry should have symmetric distances")
        XCTAssertGreaterThan(red(94,64), red(102,64), "outside falloff must encode distance, not a binary mask")
    }
    func testNormalOutputOnFlatSurfaceAndPrismAlpha() throws {
        var p = scene(try XCTUnwrap(EffectRegistry.definition("awi24.heightNormal")).makeInstance())
        p.layers[0].content = .solid; p.layers[0].size = Animated(Vec2(128,128))
        let normal = try pixels(p), offset = (64*128+64)*4
        XCTAssertEqual(Int(normal[offset]),128,accuracy:1); XCTAssertEqual(Int(normal[offset+1]),128,accuracy:1)
        XCTAssertEqual(normal[offset+2],255)
        p = scene(try XCTUnwrap(EffectRegistry.definition("awi24.spectralPrism")).makeInstance())
        let prism = try pixels(p)
        XCTAssertTrue(prism.contains { $0 > 0 })
        for i in stride(from: 0, to: prism.count, by: 4) where prism[i+3] == 0 { XCTAssertEqual(Array(prism[i..<i+3]),[0,0,0]) }
    }
    func testTextEffectsComposeWithSavedAnimatorsWithoutMutatingThem() throws {
        var p = scene(); p.layers[0].content = .text; p.layers[0].text = TextData(string: "AB\nCD")
        var animator = TextAnimator(name: "existing"); animator.properties.rotation = Animated(5)
        p.layers[0].text!.animators = [animator]
        let saved = p.layers[0].text!
        var transform = try XCTUnwrap(EffectRegistry.definition("awi24.textTransform")).makeInstance()
        transform.params["y"] = .number(Animated(10))
        p.layers[0].effects = [transform]
        let text = try XCTUnwrap(Renderer.renderTextData(p.layers[0],time:0.4)), layout = TextEngine.shared.layout(text,time:0.4)
        let states = Renderer.glyphStates(text,layout:layout,time:0.4,effects:p.layers[0].effects)
        XCTAssertTrue(states.allSatisfy { abs($0.rotation-5)<0.001 && abs($0.offset.y-10)<0.001 })
        XCTAssertEqual(p.layers[0].text!,saved)
        let copy = try JSONDecoder().decode(Project.self,from:JSONEncoder().encode(p))
        XCTAssertEqual(copy.layers[0].effects,p.layers[0].effects)
    }
    func testTextProgressRetainsLayoutAndJitterIsSeekDeterministic() throws {
        let text = TextData(string: "AB\nCD"), layout = TextEngine.shared.layout(TextData(string:"AB\nCD"),time:0)
        var progress = try XCTUnwrap(EffectRegistry.definition("awi24.textProgress")).makeInstance()
        progress.params["end"] = .number(Animated(40))
        let states = Renderer.glyphStates(text,layout:layout,time:0,effects:[progress])
        for (i,glyph) in layout.glyphs.enumerated() where !glyph.isSpace {
            XCTAssertEqual(states[i].offset,.zero)
            XCTAssertEqual(states[i].opacity,glyph.charIndex<2 ? 1 : 0,accuracy:0.001)
        }
        let jitter = try XCTUnwrap(EffectRegistry.definition("awi24.textJitter")).makeInstance()
        let a = Renderer.glyphStates(text,layout:layout,time:0.4,effects:[jitter])
        _ = Renderer.glyphStates(text,layout:layout,time:1.7,effects:[jitter])
        let b = Renderer.glyphStates(text,layout:layout,time:0.4,effects:[jitter])
        XCTAssertEqual(a.map(\.offset),b.map(\.offset)); XCTAssertEqual(a.map(\.rotation),b.map(\.rotation))
    }
    func testPrintRemakesKeepLegacyAndInitializeMissingDefaults() throws {
        for definition in [EffectRegistry.cmykHalftone,EffectRegistry.halftoneLines16] {
            var old = definition.makeInstance(); old.params["version"] = nil
            var legacy = old; legacy.params["version"] = .choice(0)
            XCTAssertEqual(try pixels(scene(old)),try pixels(scene(legacy)))
            var changed = old
            for key in ["amount","strength","blackWeight","phase"] { changed.params[key] = nil }
            changed.params["version"] = .choice(1)
            XCTAssertEqual(try pixels(scene(changed)),try pixels(scene(definition.makeInstance())))
        }
    }
    func testPrintBatchMatchesSuppliedScreenEquations() throws {
        for definition in [EffectRegistry.cmykHalftone, EffectRegistry.halftoneLines16] {
            var effect = definition.makeInstance()
            effect.params["amount"] = .number(Animated(16)); effect.params["angle"] = .number(Animated(0))
            effect.params["blackWeight"] = .number(Animated(100))
            var p = scene(effect); p.layers[0].content = .solid; p.layers[0].size = Animated(Vec2(128,128))
            p.layers[0].fill = Animated(RGBA(0.25,0.25,0.25))
            let output = try pixels(p)
            func smooth(_ value: Double) -> Double { let u = min(1,max(0,(value-0.4)/0.2)); return u*u*(3-2*u) }
            for y in stride(from: 25, through: 100, by: 7) {
                let expected: [Double]
                if definition.id == "awi8.cmykHalftone" {
                    let dx = 64.5-64, dy = Double(y)+0.5-64, c = sqrt(0.5)
                    let gx = (dx*c-dy*c)/8, gy = (dx*c+dy*c)/8
                    let row = floor(gy+0.5), shift = Int(row) & 1 != 0 ? 0.5 : 0
                    let column = floor(gx+shift+0.5)-shift
                    let black = smooth(max(0,1-hypot(gx-column,gy-row))*0.75)
                    expected = Array(repeating:(1-black)*255,count:3)
                } else {
                    let gridY = (Double(y)+0.5-64)/8
                    let weight = smooth(0.25+abs(gridY-floor(gridY+0.5)))
                    expected = zip([17.0,51,85],[255.0,238,221]).map { pair in pair.0*(1-weight)+pair.1*weight }
                }
                for channel in 0..<3 { XCTAssertEqual(Double(output[(y*128+64)*4+channel]),expected[channel],accuracy:3,definition.name) }
            }
        }
    }
    func testTextUtilityDefaultsDoNotMoveOrHideExistingText() throws {
        for id in ["textTransform","textProgress","characterOffset","textLineSpacing"] {
            var p = scene(); p.layers[0].content = .text; p.layers[0].text = TextData(string:"AWI\nEDIT")
            p.layers[0].effects = [try XCTUnwrap(EffectRegistry.definition("awi24."+id)).makeInstance()]
            let text = try XCTUnwrap(Renderer.renderTextData(p.layers[0],time:0)), layout = TextEngine.shared.layout(text,time:0)
            let states = Renderer.glyphStates(text,layout:layout,time:0,effects:p.layers[0].effects)
            XCTAssertTrue(states.allSatisfy { $0.offset == .zero && $0.rotation == 0 && $0.charOffset == 0 && $0.opacity == 1 },id)
            XCTAssertEqual(text.lineSpacing.value(at:0),1.15,accuracy:1e-9)
        }
    }
    func testBatchManifestAndRenderedPreviews() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        let folder = URL(fileURLWithPath:"/tmp/awi-ui",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let manifest = EffectRegistry.all.map { ["id":$0.id,"name":$0.name,"category":$0.category.rawValue] }
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("effect-manifest.json"))
        for definition in EffectRegistry.textBatch24 + EffectRegistry.imageBatch24 + [EffectRegistry.cmykHalftone,EffectRegistry.halftoneLines16] {
            var p = scene(EffectThumbnails.showcase(definition))
            if definition.category == .text {
                p.layers[0].content = .text; p.layers[0].text = TextData(string:"AWI\nEDIT"); p.layers[0].text!.fontSize = 24
            }
            let image = try XCTUnwrap(renderer.renderImage(project:p,time:0.4,maxDimension:256,mediaURL:{URL(fileURLWithPath:$0)}))
            try XCTUnwrap(image.pngData()).write(to:folder.appendingPathComponent("batch24-"+definition.id+".png"))
        }
    }
}
