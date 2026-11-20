import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

final class ReferenceEffectsTests: XCTestCase {
    private func render(_ effect: EffectInstance?, time: Double = 0.4) throws -> [UInt8] {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        var project = Project.new(name: "Reference effects", width: 256, height: 256, fps: 30, background: RGBA(0, 0, 0, 0))
        var layer = project.makeLayer(name: "Cutout", content: .shape(.ellipse), size: Vec2(210, 180))
        layer.fill = Animated(RGBA(0.5, 0.2, 0.8))
        layer.effects = effect.map { [$0] } ?? []
        project.layers = [layer]
        return try XCTUnwrap(renderer.renderPixels(project: project, time: time, preserveAlpha: true,
            mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }
    func testRidgesKeepCoverageAndBlendZeroIsIdentity() throws {
        let baseline = try render(nil)
        var effect = EffectRegistry.fractalRidgesAM35.makeInstance()
        let ridges = try render(effect)
        XCTAssertNotEqual(baseline, ridges)
        XCTAssertEqual(stride(from: 3, to: baseline.count, by: 4).map { baseline[$0] },
                       stride(from: 3, to: ridges.count, by: 4).map { ridges[$0] })
        effect.params["blend"] = .number(Animated(0))
        XCTAssertEqual(try render(effect), baseline)
    }
    func testMissingParametersUseRegisteredDefaults() throws {
        let fresh = EffectRegistry.fractalRidgesAM35.makeInstance()
        var old = fresh
        old.params.removeAll()
        XCTAssertEqual(try render(fresh), try render(old))
    }
    func testEvolutionAndColorsChangeRidges() throws {
        var effect = EffectRegistry.fractalRidgesAM35.makeInstance()
        let baseline = try render(effect)
        effect.params["evolution"] = .number(Animated(0.7))
        XCTAssertNotEqual(try render(effect), baseline)
        effect.params["color1"] = .color(Animated(RGBA(0.02, 0.08, 0.3)))
        effect.params["color2"] = .color(Animated(RGBA(1, 0.4, 0.03)))
        XCTAssertNotEqual(try render(effect), baseline)
    }
    func testWriteRidgesStillAndMotionReview() throws {
        let directory = URL(fileURLWithPath: "/tmp/awi-ui")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            directory.appendingPathComponent("fractal-ridges-motion.gif") as CFURL, UTType.gif.identifier as CFString, 24, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<24 {
            var effect = EffectRegistry.fractalRidgesAM35.makeInstance()
            effect.params["evolution"] = .number(Animated(Double(frame) / 24))
            effect.params["color1"] = .color(Animated(RGBA(0.015, 0.025, 0.12)))
            effect.params["color2"] = .color(Animated(RGBA(1, 0.4, 0.04)))
            let pixels = try render(effect)
            let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
            let image = try XCTUnwrap(CGImage(width: 256, height: 256, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: 1024, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: true, intent: .defaultIntent))
            if frame == 0 { try UIImage(cgImage: image).pngData()?.write(to: directory.appendingPathComponent("fractal-ridges-still.png")) }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
