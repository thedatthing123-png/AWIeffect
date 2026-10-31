import XCTest
import AVFoundation
@testable import AWIeffect

/// Full export pipeline (render → H.264 → audio mix → mux) must finish, with both tracks present.
final class ExportTests: XCTestCase {
    private func sineWav(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        let n = AVAudioFrameCount(seconds * 48000)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n)!
        buf.frameLength = n
        for c in 0..<2 { for i in 0..<Int(n) { buf.floatChannelData![c][i] = sinf(Float(i) * 2 * .pi * 440 / 48000) * 0.3 } }
        try file.write(from: buf)
        return url
    }

    private func project(withAudio: Bool) throws -> (Project, (String) -> URL) {
        var p = Project.new(name: "exp", width: 320, height: 240, fps: 30, duration: 2, background: RGBA(0.1, 0.1, 0.2))
        var box = p.makeLayer(name: "box", content: .shape(.star), size: Vec2(120, 120))
        box.transform.rotation.insertKeyframe(Keyframe(time: 0, value: 0, interpolation: .linear))
        box.transform.rotation.insertKeyframe(Keyframe(time: 2, value: 180, interpolation: .linear))
        box.effects = [EffectRegistry.glow.makeInstance(), EffectRegistry.shake.makeInstance()]
        p.layers = [box]
        var media: [String: URL] = [:]
        if withAudio {
            let wav = try sineWav(seconds: 3)
            media["tone.wav"] = wav
            var a = p.makeLayer(name: "music", content: .audio(fileName: "tone.wav", duration: 3), size: Vec2(1, 1))
            a.outPoint = 2
            p.layers.append(a)
        }
        return (p, { media[$0] ?? URL(fileURLWithPath: $0) })
    }

    private func export(_ p: Project, _ media: @escaping (String) -> URL, _ settings: ExportSettings) async throws -> URL {
        guard Renderer.shared != nil else { throw XCTSkip("SKIP-GPU") }
        var last = 0.0
        let url = try await Exporter().export(project: p, settings: settings, mediaURL: media) { last = $0 }
        XCTAssertEqual(last, 1, accuracy: 0.02, "progress never reached 100%")
        return url
    }

    func testExportWithMusicFinishesWithBothTracks() async throws {
        let (p, media) = try project(withAudio: true)
        let url = try await export(p, media, ExportSettings())
        let asset = AVURLAsset(url: url)
        let v = try await asset.loadTracks(withMediaType: .video), a = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(v.count, 1); XCTAssertEqual(a.count, 1, "music missing from export")
        let d = try await asset.load(.duration)
        XCTAssertEqual(CMTimeGetSeconds(d), 2, accuracy: 0.15)
    }

    func testSilentExportAndCustomFPS() async throws {
        let (p, media) = try project(withAudio: false)
        var s = ExportSettings(); s.fps = 24; s.scale = 0.5
        let url = try await export(p, media, s)
        let asset = AVURLAsset(url: url)
        XCTAssertEqual(try await asset.loadTracks(withMediaType: .video).count, 1)
    }

    func testGIFExport() async throws {
        let (p, media) = try project(withAudio: false)
        var s = ExportSettings(); s.format = .gif
        let url = try await export(p, media, s)
        XCTAssertEqual(url.pathExtension, "gif")
        XCTAssertGreaterThan((try? Data(contentsOf: url).count) ?? 0, 1000)
    }
}
