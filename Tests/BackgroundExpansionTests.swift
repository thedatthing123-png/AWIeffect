import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

final class BackgroundExpansionTests: XCTestCase {
    private func scene(_ effect: EffectInstance) -> Project {
        var p = Project.new(name: "Background expansion", width: 240, height: 180, fps: 30, duration: 3, background: RGBA(0,0,0,0))
        var layer = p.makeLayer(name: "Background", content: .solid, size: Vec2(240,180))
        layer.fill = Animated(RGBA(0.13,0.29,0.21)); layer.effects = [effect]; p.layers = [layer]
        return p
    }
    private func pixels(_ effect: EffectInstance, time: Double = 0.4) throws -> [UInt8] {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return try XCTUnwrap(renderer.renderPixels(project: scene(effect), time: time, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }
    private func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a,b).reduce(0.0) { $0 + Double(abs(Int($1.0)-Int($1.1))) } / Double(a.count)
    }
    func testSavedInstancesMissingParametersUseDefinitionDefaults() throws {
        for definition in EffectRegistry.batch30 {
            let current = definition.makeInstance()
            let old = EffectInstance(typeID: definition.id, params: [:])
            XCTAssertLessThan(difference(try pixels(current), try pixels(old)), 0.01, definition.name)
            XCTAssertEqual(EffectSection.of(definition), .backgrounds)
        }
    }
    func testEveryBackgroundAnimatesAndCanBeHeldWithZeroSpeed() throws {
        for definition in EffectRegistry.batch30 {
            var effect = definition.makeInstance()
            XCTAssertGreaterThan(difference(try pixels(effect, time: 0.1), try pixels(effect, time: 0.9)), 0.05, definition.name)
            effect.params["speed"] = .number(Animated(0))
            XCTAssertEqual(try pixels(effect, time: 0.1), try pixels(effect, time: 0.9), definition.name)
            let centered = try pixels(effect)
            effect.params["center"] = .point(Animated(Vec2(0.3,0.6)))
            XCTAssertGreaterThan(difference(try pixels(effect), centered), 0.05, definition.name)
        }
    }
    func testBlendBypassAndTransparentColorOutput() throws {
        for definition in EffectRegistry.batch30 {
            var effect = definition.makeInstance()
            effect.params["blend"] = .number(Animated(0))
            let bypass = try pixels(effect)
            var reference = scene(effect); reference.layers[0].effects = []
            guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
            XCTAssertEqual(bypass, try XCTUnwrap(renderer.renderPixels(project: reference, time: 0.4, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba)
            effect.params["only"] = .toggle(true)
            effect.params["color"] = .color(Animated(RGBA(1,0,0,0)))
            effect.params["color2"] = .color(Animated(RGBA(0,0,1,0)))
            XCTAssertTrue(try pixels(effect).allSatisfy { $0 == 0 }, definition.name)
        }
    }
    func testSolidSunburstHasFilledWedgesNotLightRays() throws {
        let definition = try XCTUnwrap(EffectRegistry.definition("awi30.solidSunburst"))
        var effect = definition.makeInstance()
        effect.params["fade"] = .number(Animated(0)); effect.params["softness"] = .number(Animated(0))
        effect.params["shape"] = .number(Animated(0)); effect.params["speed"] = .number(Animated(0))
        effect.params["color"] = .color(Animated(RGBA(1,0,0))); effect.params["color2"] = .color(Animated(RGBA(0,0,1)))
        let result = try pixels(effect)
        let filled = stride(from: 0, to: result.count, by: 4).filter { result[$0] > 250 || result[$0+2] > 250 }.count
        XCTAssertGreaterThan(Double(filled) / Double(240*180), 0.85)
        XCTAssertTrue(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == 255 })
    }
    func testExistingShapesAndKeysHavePurposefulSections() {
        XCTAssertEqual(EffectSection.of(EffectRegistry.rmCube17), .shapes)
        XCTAssertEqual(EffectSection.of(EffectRegistry.fractalNoise), .procedural)
        XCTAssertEqual(EffectSection.of(EffectRegistry.definition("ae.lumaKey")!), .keying)
    }
    func testWriteBackgroundContactSheetAndMotion() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let directory = URL(fileURLWithPath: "/tmp/awi-backgrounds", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sheetHeight = CGFloat((EffectRegistry.batch30.count+3)/4)*220
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: 960,height: sheetHeight)).image { context in
            UIColor(white: 0.06,alpha: 1).setFill(); context.fill(CGRect(x: 0,y: 0,width: 960,height: sheetHeight))
            for (index, definition) in EffectRegistry.batch30.enumerated() {
                let x = CGFloat(index%4)*240, y = CGFloat(index/4)*220
                let image = renderer.renderImage(project: scene(definition.makeInstance()), time: 0.4, maxDimension: 240, mediaURL: { URL(fileURLWithPath: $0) })
                image?.draw(in: CGRect(x: x,y: y,width: 240,height: 180))
                (definition.name as NSString).draw(at: CGPoint(x: x+10,y: y+188),withAttributes: [.font: UIFont.systemFont(ofSize: 15),.foregroundColor: UIColor.white])
            }
        }
        try XCTUnwrap(sheet.pngData()).write(to: directory.appendingPathComponent("background-contact-sheet.png"))
        // Moving previews for the five core designs, also saved as PNG frames for frame-by-frame inspection.
        let moving = Array(EffectRegistry.batch30.prefix(5)) + EffectRegistry.batch30.filter { ["awi30.herringbone", "awi30.hexMesh", "awi30.circuitBoard", "awi30.rippleInterference", "awi30.guilloche"].contains($0.id) }
        for definition in moving {
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(directory.appendingPathComponent("\(definition.id).gif") as CFURL,UTType.gif.identifier as CFString,30,nil))
            CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for frame in 0..<30 {
                let image = try XCTUnwrap(renderer.renderImage(project: scene(definition.makeInstance()),time: Double(frame)/15,maxDimension: 240,mediaURL: { URL(fileURLWithPath: $0) }))
                CGImageDestinationAddImage(destination,try XCTUnwrap(image.cgImage),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/15]] as CFDictionary)
                if frame%10 == 0 { try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("\(definition.id)-\(frame).png")) }
            }
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
}
