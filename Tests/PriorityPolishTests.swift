import XCTest
import UIKit
@testable import AWIeffect

final class PriorityPolishTests: XCTestCase {
    func testTrackSmoothingPreservesLinearMovementAndAnchors() {
        let samples = (0..<30).map { (Double($0), CGPoint(x: Double($0), y: Double($0) * 2)) }
        let smooth = MotionTracker.smoothed(samples, radius: 5)
        for i in samples.indices {
            XCTAssertEqual(smooth[i].0, samples[i].0)
            XCTAssertEqual(smooth[i].1.x, samples[i].1.x, accuracy: 0.000001)
            XCTAssertEqual(smooth[i].1.y, samples[i].1.y, accuracy: 0.000001)
        }
        let noisy = (0..<30).map { (Double($0), CGPoint(x: $0 % 2 == 0 ? 0 : 10, y: 0)) }
        XCTAssertLessThan(abs(MotionTracker.smoothed(noisy, radius: 5)[15].1.x - 5), 1)
        XCTAssertEqual(MotionTracker.smoothed(noisy, radius: 0)[15].1, noisy[15].1)
    }

    private func render(_ effect: EffectInstance?, color: RGBA = RGBA(0.25, 0.2, 0.1)) throws -> [UInt8] {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        var p = Project.new(name: "priority", width: 128, height: 128, fps: 30, background: RGBA(0, 0, 0, 0))
        var layer = p.makeLayer(name: "subject", content: .shape(.ellipse), size: Vec2(64, 64))
        layer.fill = Animated(color); layer.effects = effect.map { [$0] } ?? []
        p.layers = [layer]
        return try XCTUnwrap(renderer.renderPixels(project: p, time: 0.4, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    func testOrganicSweepPreservesAlphaAndZeroIntensityIsIdentity() throws {
        var e = EffectRegistry.organicLightSweep.makeInstance()
        let base = try render(nil), sweep = try render(e)
        XCTAssertEqual(stride(from: 3, to: base.count, by: 4).map { base[$0] }, stride(from: 3, to: sweep.count, by: 4).map { sweep[$0] })
        e.params["intensity"] = .number(Animated(0))
        XCTAssertEqual(try render(e), base)
    }

    func testBlackDeepGlowDoesNotCreateOpaqueHalo() throws {
        var e = EffectRegistry.deepGlow.makeInstance()
        e.params["radius"] = .number(Animated(200))
        e.params["exposure"] = .number(Animated(-3))
        XCTAssertEqual(try render(e, color: .black), try render(nil, color: .black))
    }

    func testMissingTurbulenceControlsRetainLegacyDefaults() throws {
        let fresh = EffectRegistry.turbulentDisplace.makeInstance()
        var old = fresh
        for key in ["axis", "stretchX", "stretchY", "offsetX", "offsetY"] { old.params.removeValue(forKey: key) }
        XCTAssertEqual(try render(old), try render(fresh))
    }

    func testTransparentVideoIsDefault() { XCTAssertEqual(ExportSettings().format, .transparent) }

    func testPriorityPreviewArtifacts() throws {
        let directory = URL(fileURLWithPath: "/tmp/awi-ui")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for definition in [EffectRegistry.organicLightSweep, EffectRegistry.lightSweep10, EffectRegistry.deepGlow] {
            let bytes = try render(definition.makeInstance())
            let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
            let cg = try XCTUnwrap(CGImage(width: 128, height: 128, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 512,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent))
            try UIImage(cgImage: cg).pngData()?.write(to: directory.appendingPathComponent("priority-\(definition.id).png"))
        }
    }
}
