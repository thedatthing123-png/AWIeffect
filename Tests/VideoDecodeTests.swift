import XCTest
import AVFoundation
import Metal
@testable import AWIeffect

/// The streaming video decoder must hand back the right frame, the right way up (also for rotated phone clips),
/// in order and after jumps, and stay safe when several threads ask at once.
final class VideoDecodeTests: XCTestCase {
    /// 40 frames at 30 fps: top half red, bottom half blue, left stripe brightness = frame * 6.
    private func makeVideo(rotated: Bool) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        let w = 320, h = 240
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        if rotated { input.transform = CGAffineTransform(rotationAngle: .pi / 2) }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for i in 0..<40 {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
            let buf = pb!
            CVPixelBufferLockBaseAddress(buf, [])
            let base = CVPixelBufferGetBaseAddress(buf)!.assumingMemoryBound(to: UInt8.self)
            let row = CVPixelBufferGetBytesPerRow(buf)
            for y in 0..<h {
                for x in 0..<w {
                    let o = y * row + x * 4
                    if x < 48 { let g = UInt8(i * 6); base[o] = g; base[o + 1] = g; base[o + 2] = g }
                    else if y < h / 2 { base[o] = 0; base[o + 1] = 0; base[o + 2] = 255 }
                    else { base[o] = 255; base[o + 1] = 0; base[o + 2] = 0 }
                    base[o + 3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(buf, [])
            adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30))
        }
        input.markAsFinished()
        let done = expectation(description: "write")
        writer.finishWriting { done.fulfill() }
        wait(for: [done], timeout: 30)
        XCTAssertEqual(writer.status, .completed)
        return url
    }

    /// BGRA pixels of a (private) texture.
    private func pixels(_ tex: MTLTexture) -> [UInt8] {
        let r = Renderer.shared!
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: tex.pixelFormat, width: tex.width, height: tex.height, mipmapped: false)
        d.storageMode = .shared
        let out = r.device.makeTexture(descriptor: d)!
        let cb = r.queue.makeCommandBuffer()!
        let bl = cb.makeBlitCommandEncoder()!
        bl.copy(from: tex, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: tex.width, height: tex.height, depth: 1),
                to: out, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        bl.endEncoding()
        cb.commit(); cb.waitUntilCompleted()
        var px = [UInt8](repeating: 0, count: tex.width * tex.height * 4)
        out.getBytes(&px, bytesPerRow: tex.width * 4, from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
        return px
    }

    /// (r, g, b) at a relative position.
    private func color(_ px: [UInt8], _ tex: MTLTexture, _ fx: Double, _ fy: Double) -> (Int, Int, Int) {
        let x = Int(fx * Double(tex.width - 1)), y = Int(fy * Double(tex.height - 1))
        let o = (y * tex.width + x) * 4
        return (Int(px[o + 2]), Int(px[o + 1]), Int(px[o]))
    }

    private func stripe(_ tex: MTLTexture, rotated: Bool) -> Int {
        let px = pixels(tex)
        // Upright: stripe on the left edge. Rotated 90° clockwise: it ends up along the top edge.
        return rotated ? color(px, tex, 0.5, 0.05).1 : color(px, tex, 0.05, 0.5).1
    }

    func testUprightFramesInOrderAndAfterJumps() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let url = try makeVideo(rotated: false)
        VideoSources.shared.clear()
        for f in [0, 1, 2, 3, 10, 25, 5, 39] {
            let tex = try XCTUnwrap(VideoSources.shared.texture(url: url, time: (Double(f) + 0.1) / 30, device: r.device), "frame \(f)")
            XCTAssertEqual(tex.width, 320); XCTAssertEqual(tex.height, 240)
            let px = pixels(tex)
            let top = color(px, tex, 0.7, 0.2), bottom = color(px, tex, 0.7, 0.8)
            XCTAssertGreaterThan(top.0, 180, "frame \(f): top should be red, got \(top)"); XCTAssertLessThan(top.2, 80)
            XCTAssertGreaterThan(bottom.2, 180, "frame \(f): bottom should be blue, got \(bottom)"); XCTAssertLessThan(bottom.0, 80)
            XCTAssertEqual(Double(stripe(tex, rotated: false)), Double(f * 6), accuracy: 10, "frame \(f) decoded the wrong frame")
        }
    }

    func testRotatedPhoneClipIsUpright() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let url = try makeVideo(rotated: true)
        VideoSources.shared.clear()
        let tex = try XCTUnwrap(VideoSources.shared.texture(url: url, time: 12.1 / 30, device: r.device))
        XCTAssertEqual(tex.width, 240); XCTAssertEqual(tex.height, 320)
        // Ground truth: AVFoundation's own oriented frame.
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.appliesPreferredTrackTransform = true
        let cg = try g.copyCGImage(at: CMTime(value: 12, timescale: 30), actualTime: nil)
        XCTAssertEqual(cg.width, 240)
        let px = pixels(tex)
        // Rotated clockwise: the red top half is now the right half, blue on the left.
        let right = color(px, tex, 0.8, 0.7), left = color(px, tex, 0.2, 0.7)
        XCTAssertGreaterThan(right.0, 180, "right should be red, got \(right)")
        XCTAssertGreaterThan(left.2, 180, "left should be blue, got \(left)")
        XCTAssertEqual(Double(stripe(tex, rotated: true)), 72, accuracy: 10)
    }

    func testConcurrentDecodeIsSafe() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let url = try makeVideo(rotated: false)
        VideoSources.shared.clear()
        DispatchQueue.concurrentPerform(iterations: 64) { i in
            _ = VideoSources.shared.texture(url: url, time: Double((i * 7) % 40) / 30, device: r.device)
        }
        let tex = try XCTUnwrap(VideoSources.shared.texture(url: url, time: 20.1 / 30, device: r.device))
        XCTAssertEqual(Double(stripe(tex, rotated: false)), 120, accuracy: 10)
    }

    func testSequentialPlaybackIsFast() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let url = try makeVideo(rotated: false)
        VideoSources.shared.clear()
        let t0 = CFAbsoluteTimeGetCurrent()
        for f in 0..<40 { _ = VideoSources.shared.texture(url: url, time: (Double(f) + 0.1) / 30, device: r.device) }
        let per = (CFAbsoluteTimeGetCurrent() - t0) / 40 * 1000
        print("SKIP-INFO video decode \(String(format: "%.2f", per)) ms/frame")
        XCTAssertLessThan(per, 30)
    }

    /// Two copies of the same clip playing at different source times (a duplicated clip offset in time) must each
    /// get their own correct frame every time: no stealing each other's reader, no wrong / twitching frames.
    func testDuplicatedClipsAtDifferentTimesGetTheirOwnFrames() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let url = try makeVideo(rotated: false)
        VideoSources.shared.clear()
        for f in 0..<18 {
            let a = try XCTUnwrap(VideoSources.shared.texture(url: url, time: (Double(f) + 0.1) / 30, device: r.device, channel: 1))
            let b = try XCTUnwrap(VideoSources.shared.texture(url: url, time: (Double(f + 20) + 0.1) / 30, device: r.device, channel: 2))
            XCTAssertEqual(Double(stripe(a, rotated: false)), Double(f * 6), accuracy: 10, "copy A frame \(f) wrong")
            XCTAssertEqual(Double(stripe(b, rotated: false)), Double((f + 20) * 6), accuracy: 10, "copy B frame \(f + 20) wrong")
        }
    }

    /// Two identical clips at the same time render pixel-identical frames (duplicate = same picture).
    func testIdenticalDuplicatesRenderTheSame() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let url = try makeVideo(rotated: false)
        VideoSources.shared.clear()
        for f in [3, 4, 5, 6] {
            let a = pixels(try XCTUnwrap(VideoSources.shared.texture(url: url, time: (Double(f) + 0.1) / 30, device: r.device, channel: 11)))
            let b = pixels(try XCTUnwrap(VideoSources.shared.texture(url: url, time: (Double(f) + 0.1) / 30, device: r.device, channel: 12)))
            XCTAssertEqual(a, b, "duplicates differ at frame \(f)")
        }
    }
}
