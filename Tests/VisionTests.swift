import XCTest
import AVFoundation
@testable import AWIeffect

final class VisionTests: XCTestCase {
    /// Black video with a white square moving left -> right over 2 s.
    private func movingSquareVideo() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        let w = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240])
        let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
        w.add(input); w.startWriting(); w.startSession(atSourceTime: .zero)
        for f in 0..<30 {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
            var pb: CVPixelBuffer?
            CVPixelBufferCreate(nil, 320, 240, kCVPixelFormatType_32BGRA, nil, &pb)
            CVPixelBufferLockBaseAddress(pb!, [])
            let base = CVPixelBufferGetBaseAddress(pb!)!.assumingMemoryBound(to: UInt8.self)
            let bpr = CVPixelBufferGetBytesPerRow(pb!)
            let sx = 40 + f * 6
            for y in 0..<240 { for x in 0..<320 {
                let o = y * bpr + x * 4
                // Textured square (checker) so the tracker has features.
                let inside = x >= sx && x < sx + 50 && y >= 95 && y < 145
                let v: UInt8 = inside ? (((x / 5 + y / 5) % 2 == 0) ? 255 : 120) : 10
                base[o] = v; base[o + 1] = v; base[o + 2] = v; base[o + 3] = 255
            } }
            CVPixelBufferUnlockBaseAddress(pb!, [])
            ad.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: 15))
        }
        input.markAsFinished()
        let e = expectation(description: "w"); w.finishWriting { e.fulfill() }; wait(for: [e], timeout: 10)
        return url
    }

    func testTrackerFollowsMovingSquare() throws {
        let url = try movingSquareVideo()
        let box = CGRect(x: 40.0 / 320, y: 95.0 / 240, width: 50.0 / 320, height: 50.0 / 240)
        let samples = MotionTracker.track(url: url, box: box, start: 0, end: 1.8, fps: 15) { _ in }
        guard samples.count > 5 else { throw XCTSkip("Vision tracking unavailable in this simulator (\(samples.count) samples)") }
        let firstX = samples.first!.1.x, lastX = samples.last!.1.x
        XCTAssertGreaterThan(lastX - firstX, 0.3, "tracker did not follow the square: \(samples.map { $0.1.x })")
        XCTAssertEqual(Double(samples.last!.1.y), 0.5, accuracy: 0.08)
    }

    func testCutoutProducesMatteOrSkips() throws {
        // A bright subject on a flat background (subject lift); people segmentation needs a real person.
        let size = CGSize(width: 256, height: 256)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.9, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.systemPurple.setFill(); ctx.cgContext.fillEllipse(in: CGRect(x: 70, y: 50, width: 120, height: 160))
        }
        guard let cg = img.cgImage, let pb = CutoutEngine.mask(cg, mode: .object) else {
            throw XCTSkip("Vision subject lift unavailable in this simulator")
        }
        XCTAssertGreaterThan(CVPixelBufferGetWidth(pb), 0)
    }

    func testCutoutSettingsDecodeOptional() throws {
        var p = Project.new(name: "c", width: 10, height: 10, fps: 30)
        p.layers = [p.makeLayer(name: "i", content: .image(fileName: "a.png", pixelWidth: 10, pixelHeight: 10), size: Vec2(10, 10))]
        p.layers[0].cutout = CutoutSettings(mode: .drawn, choke: 2, feather: 3, invert: true)
        let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.layers[0].cutout, p.layers[0].cutout)
    }
}
