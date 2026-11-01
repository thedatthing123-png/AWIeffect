import XCTest
import AVFoundation
import Metal
import Photos
import UIKit
@testable import AWIeffect

final class EssentialRegressionTests: XCTestCase {
    func testPhotosRoutesImagesAndMoviesSeparately() {
        for ext in ["png", "PNG", "gif", "jpg"] {
            XCTAssertEqual(PhotoLibrarySaver.resourceType(for: URL(fileURLWithPath: "/frame.\(ext)")), .photo)
        }
        for ext in ["mp4", "mov", "MOV"] {
            XCTAssertEqual(PhotoLibrarySaver.resourceType(for: URL(fileURLWithPath: "/video.\(ext)")), .video)
        }
        XCTAssertNil(PhotoLibrarySaver.resourceType(for: URL(fileURLWithPath: "/project.json")))
    }

    func testPhotosMissingFileFailsBeforeRequestingPermission() async {
        do {
            try await PhotoLibrarySaver.save(URL(fileURLWithPath: "/missing-\(UUID()).png"))
            XCTFail("Missing export must not report success")
        } catch { XCTAssertTrue(error is PhotoLibrarySaver.SaveError) }
    }

    func testGlyphRasterOwnsStorageAndRejectsInvalidAnimationValues() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal unavailable") }
        let layout = TextEngine.shared.layout(TextData(string: "AW 漢🙂", fontSize: 50), time: 0)
        let glyph = try XCTUnwrap(layout.glyphs.first)
        XCTAssertNil(TextEngine.shared.glyphTexture(glyph, scale: .infinity, device: device))
        XCTAssertNil(TextEngine.shared.glyphTexture(glyph, scale: 1, blur: .nan, device: device))
        XCTAssertNil(TextEngine.shared.glyphTexture(glyph, scale: 1e100, device: device))
        for blur in [0.0, 2, 12, 40] {
            for g in layout.glyphs where !g.isSpace {
                let entry = try XCTUnwrap(TextEngine.shared.glyphTexture(g, scale: 1, blur: blur, device: device))
                var bytes = [UInt8](repeating: 0, count: entry.tex.width * entry.tex.height)
                entry.tex.getBytes(&bytes, bytesPerRow: entry.tex.width, from: MTLRegionMake2D(0, 0, entry.tex.width, entry.tex.height), mipmapLevel: 0)
                XCTAssertTrue(bytes.contains { $0 > 0 }, "Empty raster at blur \(blur)")
            }
        }
    }

    func testConversionPreservesStraightAlphaAndOpaquePathStillFlattens() throws {
        guard let r = Renderer.shared else { throw XCTSkip("Metal unavailable") }
        let p = Project.new(name: "alpha", width: 32, height: 32, fps: 24, duration: 0.25, background: RGBA(0.8, 0.4, 0.2, 0.5))
        let alpha = try XCTUnwrap(r.renderPixels(project: p, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) }))
        let opaque = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertEqual(Double(alpha.rgba[3]), 128, accuracy: 2)
        XCTAssertEqual(Int(opaque.rgba[3]), 255)
        XCTAssertEqual(Double(alpha.rgba[0]), 204, accuracy: 3)
        XCTAssertEqual(Double(opaque.rgba[0]), 102, accuracy: 3)
        let image = try XCTUnwrap(r.renderImage(project: p, time: 0, maxDimension: 32, mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertEqual(image.cgImage?.alphaInfo, .last)
        let roundTrip = try XCTUnwrap(UIImage(data: try XCTUnwrap(image.pngData())))
        XCTAssertNotEqual(roundTrip.cgImage?.alphaInfo, .noneSkipLast)
    }

    private func ramp() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
        buffer.frameLength = 48000
        for c in 0..<2 { for i in 0..<48000 { buffer.floatChannelData![c][i] = 0.1 + Float(i) / 60000 } }
        do { let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer) }
        return url
    }

    func testReverseAndFreezeAudioUseTheVisualSourceTimeMap() throws {
        let source = try ramp()
        defer { try? FileManager.default.removeItem(at: source) }
        let p = Project.new(name: "audio", width: 32, height: 32, fps: 30, duration: 1, background: .black)
        var layer = p.makeLayer(name: "tone", content: .audio(fileName: "tone.wav", duration: 1), size: Vec2(1, 1))
        layer.outPoint = 1
        var map = Animated(0.99)
        map.insertKeyframe(Keyframe(time: 0, value: 0.99, interpolation: .linear))
        map.insertKeyframe(Keyframe(time: 1, value: 0, interpolation: .linear))
        layer.timeRemap = map
        let reversed = try RetimedAudio.file(for: layer, source: source)
        let file = try AVAudioFile(forReading: reversed)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 48000)!
        try file.read(into: buffer)
        XCTAssertEqual(buffer.frameLength, 48000)
        XCTAssertGreaterThan(buffer.floatChannelData![0][100], 0.8)
        XCTAssertLessThan(buffer.floatChannelData![0][47000], 0.2)
        layer.timeRemap = Animated(0.5)
        let frozen = try RetimedAudio.file(for: layer, source: source)
        let still = try AVAudioFile(forReading: frozen)
        let silence = AVAudioPCMBuffer(pcmFormat: still.processingFormat, frameCapacity: 1024)!
        try still.read(into: silence)
        XCTAssertEqual(silence.floatChannelData![0][500], 0)
    }

    func testBrokenAudioFailsExportInsteadOfReturningSilentSuccess() async throws {
        var p = Project.new(name: "bad-audio", width: 32, height: 32, fps: 24, duration: 1, background: .black)
        p.layers = [p.makeLayer(name: "missing", content: .audio(fileName: "missing.wav", duration: 1), size: Vec2(1, 1))]
        do {
            _ = try await Exporter.renderAudio(project: p, start: 0, end: 1, mediaURL: { _ in URL(fileURLWithPath: "/missing.wav") })
            XCTFail("Broken audio must be reported")
        } catch { XCTAssertFalse(error is CancellationError) }
    }
}
