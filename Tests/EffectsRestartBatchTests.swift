import XCTest
import UIKit
import CoreText
@testable import AWIeffect

final class EffectsRestartBatchTests: XCTestCase {
    func testRestartDoesNotRegisterTheAbandonedTextWrappers() {
        for name in ["textTransform","textProgress","textWave","textJitter","textArc","textColorRamp","characterOffset","textLineSpacing","textOutline"] {
            XCTAssertNil(EffectRegistry.definition("awi24."+name))
        }
        XCTAssertEqual(EffectRegistry.imageBatch24.count,5)
    }
    func testFontContoursAreRealPathsAndTrimAcrossHolesByLength() {
        let shape = CGMutablePath()
        shape.addRect(CGRect(x:0,y:0,width:100,height:50))
        shape.addEllipse(in:CGRect(x:30,y:15,width:20,height:20))
        let paths = FontContourGeometry.convert(shape)
        XCTAssertEqual(paths.count,2)
        var effect = EffectRegistry.fontContourReveal.makeInstance()
        effect.params["end"] = .number(Animated(50))
        let sequential = FontContourGeometry.trimmed(paths,effects:[effect],time:0)
        XCTAssertEqual(sequential.count,1,"first half should not start the inner contour yet")
        effect.params["together"] = .toggle(true)
        XCTAssertEqual(FontContourGeometry.trimmed(paths,effects:[effect],time:0).count,2)
        effect.params["end"] = .number(Animated(0))
        XCTAssertTrue(FontContourGeometry.trimmed(paths,effects:[effect],time:0).isEmpty)
        effect.isEnabled = false
        XCTAssertEqual(FontContourGeometry.trimmed(paths,effects:[effect],time:0),paths)
    }
    func testFontTracePreservesTextStudioAndDoesNotBecomeAnOpacityReveal() throws {
        var p = scene(); p.layers[0].content = .text
        p.layers[0].text = TextData(string:"AO",fontSize:40)
        let saved = p.layers[0].text!
        var effect = EffectRegistry.fontContourReveal.makeInstance()
        func render(_ end: Double) throws -> [UInt8] {
            effect.params["end"] = .number(Animated(end)); p.layers[0].effects = [effect]
            return try pixels(p)
        }
        func mass(_ px: [UInt8]) -> Int { stride(from:3,to:px.count,by:4).reduce(0) { $0+Int(px[$1]) } }
        let empty = try render(0), partial = try render(35), full = try render(100)
        XCTAssertEqual(mass(empty),0); XCTAssertGreaterThan(mass(partial),500); XCTAssertGreaterThan(mass(full),mass(partial))
        XCTAssertEqual(p.layers[0].text!,saved)
        var animator = TextAnimator(name:"existing")
        animator.properties.position = Animated(Vec2(12,0)); animator.properties.opacity = Animated(50)
        p.layers[0].text!.animators = [animator]
        let moved = try pixels(p)
        XCTAssertGreaterThan(mass(moved),0)
        XCTAssertEqual(Double(mass(moved))/Double(mass(full)),0.5,accuracy:0.08)
        func centerX(_ px: [UInt8]) -> Double {
            var weighted = 0.0, sum = 0.0
            for y in 0..<128 { for x in 0..<128 { let a = Double(px[(y*128+x)*4+3]); weighted += Double(x)*a; sum += a } }
            return weighted/max(1,sum)
        }
        XCTAssertEqual(centerX(moved)-centerX(full),12,accuracy:1)
        animator.properties.blur = Animated(2); p.layers[0].text!.animators = [animator]
        XCTAssertGreaterThan(mass(try pixels(p)),0,"existing per-letter blur must remain supported")
        let copy = try JSONDecoder().decode(Project.self,from:JSONEncoder().encode(p))
        XCTAssertEqual(try pixels(copy),try pixels(p))
    }
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
            ("awi24.distanceWarp",["amount":0]),
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
    func testBatchManifestAndRenderedPreviews() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        let folder = URL(fileURLWithPath:"/tmp/awi-ui",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let manifest = EffectRegistry.all.map { ["id":$0.id,"name":$0.name,"category":$0.category.rawValue] }
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("effect-manifest.json"))
        for definition in EffectRegistry.imageBatch24 + [EffectRegistry.fontContourReveal] + [EffectRegistry.cmykHalftone,EffectRegistry.halftoneLines16] {
            var p = scene(EffectThumbnails.showcase(definition))
            if definition.category == .text {
                p.layers[0].content = .text; p.layers[0].text = TextData(string:"AWI\nEDIT"); p.layers[0].text!.fontSize = 24
            }
            let image = try XCTUnwrap(renderer.renderImage(project:p,time:0.4,maxDimension:256,mediaURL:{URL(fileURLWithPath:$0)}))
            try XCTUnwrap(image.pngData()).write(to:folder.appendingPathComponent("batch24-"+definition.id+".png"))
        }
    }
}
