import XCTest
import AVFoundation
@testable import AWIeffect

final class MediaTests: XCTestCase {
    // MARK: Timing

    func testSourceTimeSpeedAndTrim() {
        var p = Project.new(name: "m", width: 10, height: 10, fps: 30, duration: 10)
        var l = p.makeLayer(name: "v", content: .video(fileName: "x.mov", pixelWidth: 10, pixelHeight: 10, hasAudio: false), size: Vec2(10, 10))
        l.inPoint = 2; l.speed = 0.5; l.sourceStart = 1
        XCTAssertEqual(l.sourceTime(at: 4), 2, accuracy: 1e-9)
        l.timeRemap = Animated(0)
        l.timeRemap?.insertKeyframe(Keyframe(time: 0, value: 5))
        l.timeRemap?.insertKeyframe(Keyframe(time: 10, value: 0))
        XCTAssertEqual(l.sourceTime(at: 5), 2.5, accuracy: 1e-9, "time remap overrides speed")
        _ = p
    }

    @MainActor
    func testSpeedRampSlowsAroundPlayhead() {
        var p = Project.new(name: "r", width: 10, height: 10, fps: 30, duration: 6)
        var l = p.makeLayer(name: "v", content: .video(fileName: "x.mov", pixelWidth: 10, pixelHeight: 10, hasAudio: false), size: Vec2(10, 10))
        l.outPoint = 6
        p.layers = [l]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.select(l.id)
        s.currentTime = 3
        s.applySpeedRamp(slow: 0.25, fast: 1.6, window: 0.4)
        let r = s.project.layers[0]
        let slow = r.sourceTime(at: 3.1) - r.sourceTime(at: 2.9)
        let fast = r.sourceTime(at: 1.1) - r.sourceTime(at: 0.9)
        XCTAssertLessThan(slow, fast * 0.5)
        // Monotonic: source time never runs backwards.
        var prev = -1.0
        for t in stride(from: 0.0, through: 6, by: 0.05) { let v = r.sourceTime(at: t); XCTAssertGreaterThanOrEqual(v, prev - 1e-6); prev = v }
    }

    func testMarkersOptionalForOldProjects() throws {
        let p = Project.new(name: "o", width: 10, height: 10, fps: 30)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String: Any]
        json.removeValue(forKey: "markerTimes")
        let back = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.markers, [])
    }

    // MARK: Beats

    func testBeatDetectorFindsClicks() {
        let sr = 22050.0
        var s = [Float](repeating: 0, count: Int(sr * 4))
        let beatTimes = stride(from: 0.5, to: 3.6, by: 0.5).map { $0 }
        for b in beatTimes {
            let i = Int(b * sr)
            for k in 0..<800 where i + k < s.count { s[i + k] = Float(sin(Double(k) * 0.3)) * Float(exp(-Double(k) / 200)) }
        }
        let found = BeatDetector.beats(samples: s, sampleRate: sr, sensitivity: 0.5)
        XCTAssertGreaterThanOrEqual(found.count, beatTimes.count - 1)
        for b in beatTimes.dropLast() {
            XCTAssertTrue(found.contains { abs($0 - b) < 0.08 }, "missed beat at \(b): \(found)")
        }
    }

    // MARK: Video decode through the renderer

    /// Writes a tiny 2-second video: red for 1s, then blue.
    private func makeVideo() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        let w = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
        let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64])
        w.add(input)
        w.startWriting(); w.startSession(atSourceTime: .zero)
        for f in 0..<20 {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
            var pb: CVPixelBuffer?
            CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &pb)
            CVPixelBufferLockBaseAddress(pb!, [])
            let base = CVPixelBufferGetBaseAddress(pb!)!.assumingMemoryBound(to: UInt8.self)
            let bpr = CVPixelBufferGetBytesPerRow(pb!)
            for y in 0..<64 { for x in 0..<64 {
                let o = y * bpr + x * 4
                if f < 10 { base[o] = 0; base[o + 1] = 0; base[o + 2] = 255 } else { base[o] = 255; base[o + 1] = 0; base[o + 2] = 0 }
                base[o + 3] = 255
            } }
            CVPixelBufferUnlockBaseAddress(pb!, [])
            ad.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: 10))
        }
        input.markAsFinished()
        let done = expectation(description: "write")
        w.finishWriting { done.fulfill() }
        wait(for: [done], timeout: 10)
        return url
    }

    func testVideoFramesRenderAtTheRightTime() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device") }
        let url = try makeVideo()
        var p = Project.new(name: "v", width: 64, height: 64, fps: 10, duration: 2, background: .black)
        var l = p.makeLayer(name: "clip", content: .video(fileName: url.lastPathComponent, pixelWidth: 64, pixelHeight: 64, hasAudio: false),
                            size: Vec2(64, 64))
        l.fill = Animated(.white)
        p.layers = [l]
        let dir = url.deletingLastPathComponent()
        let early = try XCTUnwrap(r.renderPixels(project: p, time: 0.3, mediaURL: { dir.appendingPathComponent($0) })).rgba
        let late = try XCTUnwrap(r.renderPixels(project: p, time: 1.5, mediaURL: { dir.appendingPathComponent($0) })).rgba
        let c = (32 * 64 + 32) * 4
        XCTAssertGreaterThan(early[c], 180, "expected red at 0.3s"); XCTAssertLessThan(early[c + 2], 80)
        XCTAssertGreaterThan(late[c + 2], 180, "expected blue at 1.5s"); XCTAssertLessThan(late[c], 80)
        // Slow-mo: at half speed, comp 1.5s shows source 0.75s (still red).
        p.layers[0].speed = 0.5
        let slow = try XCTUnwrap(r.renderPixels(project: p, time: 1.5, mediaURL: { dir.appendingPathComponent($0) })).rgba
        XCTAssertGreaterThan(slow[c], 180, "speed 0.5 should still show red at comp 1.5s")
    }
}
