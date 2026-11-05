import Foundation
import Vision
import CoreImage
import UIKit

/// A frame-accurate matte: one small file per video frame in the project's media folder.
/// Frames made here are final: editing one never touches another, and the live AI is not run for them.
struct MatteFrame: Equatable {
    var width: Int
    var height: Int
    var bytes: [UInt8]

    static func filled(_ w: Int, _ h: Int, _ v: UInt8) -> MatteFrame { MatteFrame(width: w, height: h, bytes: [UInt8](repeating: v, count: w * h)) }

    /// Keep = the selection joins the cutout, cut = it leaves.
    mutating func apply(selection: [UInt8], keep: Bool) {
        guard selection.count == bytes.count else { return }
        for i in bytes.indices {
            bytes[i] = keep ? max(bytes[i], selection[i]) : min(bytes[i], 255 - selection[i])
        }
    }

    /// Alpha image for showing a matte or selection over the frame.
    func image(color: (UInt8, UInt8, UInt8) = (255, 255, 255)) -> UIImage? {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for i in bytes.indices {
            let a = Int(bytes[i])
            rgba[i * 4] = UInt8(Int(color.0) * a / 255); rgba[i * 4 + 1] = UInt8(Int(color.1) * a / 255)
            rgba[i * 4 + 2] = UInt8(Int(color.2) * a / 255); rgba[i * 4 + 3] = UInt8(a)
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum CutoutBake {
    static func fileName(_ id: String, frame: Int) -> String { "matte-\(id)-\(frame).awimatte" }

    /// Header (width, height as UInt32) + zlib-compressed bytes. Mattes compress to a few KB.
    static func save(_ m: MatteFrame, to url: URL) throws {
        var header = [UInt32(m.width), UInt32(m.height)]
        var data = Data(bytes: &header, count: 8)
        data.append(try (Data(m.bytes) as NSData).compressed(using: .zlib) as Data)
        try data.write(to: url, options: .atomic)
    }

    static func load(_ url: URL) -> MatteFrame? {
        guard let data = try? Data(contentsOf: url), data.count > 8 else { return nil }
        let w = data.withUnsafeBytes { Int($0.loadUnaligned(fromByteOffset: 0, as: UInt32.self)) }
        let h = data.withUnsafeBytes { Int($0.loadUnaligned(fromByteOffset: 4, as: UInt32.self)) }
        guard let raw = try? (data.dropFirst(8) as NSData).decompressed(using: .zlib) as Data, raw.count == w * h else { return nil }
        return MatteFrame(width: w, height: h, bytes: [UInt8](raw))
    }

    /// RGBA pixels of a frame at the matte's size (for edge snapping).
    static func pixels(of cg: CGImage, width w: Int, height h: Int) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.interpolationQuality = .medium
            ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return px
    }

    /// Anime holds frames for 2 or 3 video frames. A held frame reuses its matte, which removes most edge flicker.
    static func isHeldFrame(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count, !a.isEmpty else { return false }
        var sum = 0
        for i in a.indices { sum += abs(Int(a[i]) - Int(b[i])) }
        return Double(sum) / Double(a.count) < 1.2
    }

    /// A tiny grayscale copy of a frame, for comparing frames.
    static func thumbnail(_ cg: CGImage) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: 64 * 64)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 64,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
            ctx?.interpolationQuality = .low
            ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        return px
    }

    /// Removes everything outside `box` (UV, top-left) and every island that doesn't touch the tracked subject.
    /// This is what clears the leftover bits of background.
    static func isolate(_ m: inout MatteFrame, box: CGRect) {
        let w = m.width, h = m.height
        let x0 = max(0, Int(box.minX * CGFloat(w))), x1 = min(w - 1, Int(box.maxX * CGFloat(w)))
        let y0 = max(0, Int(box.minY * CGFloat(h))), y1 = min(h - 1, Int(box.maxY * CGFloat(h)))
        guard x1 >= x0, y1 >= y0 else { return }
        for y in 0..<h { for x in 0..<w where x < x0 || x > x1 || y < y0 || y > y1 { m.bytes[y * w + x] = 0 } }
        // The island with the most area inside the box's middle is the subject.
        var label = [Int32](repeating: 0, count: w * h)
        var next: Int32 = 0, best: Int32 = 0, bestScore = -1
        let cx0 = x0 + (x1 - x0) / 4, cx1 = x1 - (x1 - x0) / 4, cy0 = y0 + (y1 - y0) / 4, cy1 = y1 - (y1 - y0) / 4
        for start in m.bytes.indices where m.bytes[start] > 40 && label[start] == 0 {
            next += 1
            var stack = [start], score = 0
            label[start] = next
            while let i = stack.popLast() {
                let x = i % w, y = i / w
                score += x >= cx0 && x <= cx1 && y >= cy0 && y <= cy1 ? 8 : 1
                for n in [x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1, y > 0 ? i - w : -1, y < h - 1 ? i + w : -1]
                where n >= 0 && m.bytes[n] > 40 && label[n] == 0 { label[n] = next; stack.append(n) }
            }
            if score > bestScore { bestScore = score; best = next }
        }
        guard best > 0 else { return }
        for i in m.bytes.indices where label[i] != best { m.bytes[i] = 0 }
    }

    /// Per-pixel median of three frames: a pixel that flickers for one frame goes away, real motion stays.
    static func median(_ a: MatteFrame, _ b: MatteFrame, _ c: MatteFrame) -> MatteFrame {
        guard a.bytes.count == b.bytes.count, b.bytes.count == c.bytes.count else { return b }
        var out = b
        for i in out.bytes.indices {
            let x = a.bytes[i], y = b.bytes[i], z = c.bytes[i]
            out.bytes[i] = max(min(x, y), min(max(x, y), z))
        }
        return out
    }

    struct AutoJob {
        var url: URL
        var bakeID: String
        var folder: (String) -> URL
        var box: CGRect
        var startFrame: Int
        var lastFrame: Int
        var rate: Double
        var mode: CutoutMode
        /// Frames edited by hand are never overwritten.
        var locked: Set<Int>
    }

    /// Follows the box through the clip from the current frame in both directions and writes a matte per frame.
    static func runAuto(_ job: AutoJob, progress: @escaping (Double) -> Void) -> Set<Int> {
        var written = Set<Int>()
        let forward = Array(job.startFrame...max(job.startFrame, job.lastFrame))
        let backward = job.startFrame > 0 ? Array((0..<job.startFrame).reversed()) : []
        let total = Double(max(1, forward.count + backward.count))
        var done = 0.0
        for frames in [forward, backward] where !frames.isEmpty {
            if Task.isCancelled { break }
            written.formUnion(pass(job, frames: frames) { done += 1; progress(done / total) })
        }
        return written
    }

    private static func pass(_ job: AutoJob, frames: [Int], step: () -> Void) -> Set<Int> {
        let seq = VNSequenceRequestHandler()
        var box = job.box
        var observation = VNDetectedObjectObservation(boundingBox: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
        var lastThumb: [UInt8] = [], lastMatte: MatteFrame?
        var window: [(Int, MatteFrame)] = []
        var written = Set<Int>()

        func emit(_ index: Int, _ m: MatteFrame) {
            guard !job.locked.contains(index) else { return }
            if (try? save(m, to: job.folder(fileName(job.bakeID, frame: index)))) != nil { written.insert(index) }
        }

        for f in frames {
            if Task.isCancelled { break }
            defer { step() }
            guard let cg = VideoSources.shared.cgImage(url: job.url, time: (Double(f) + 0.5) / job.rate, maxSize: 768) else { continue }
            let thumb = thumbnail(cg)
            var matte: MatteFrame?
            if let lastMatte, isHeldFrame(thumb, lastThumb) {
                matte = lastMatte
            } else {
                let request = VNTrackObjectRequest(detectedObjectObservation: observation)
                request.trackingLevel = .accurate
                if (try? seq.perform([request], on: cg)) != nil, let res = request.results?.first as? VNDetectedObjectObservation, res.confidence > 0.2 {
                    observation = res
                    let b = res.boundingBox
                    box = CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
                }
                let center = CGPoint(x: box.midX, y: box.midY)
                if let pb = CutoutEngine.mask(cg, mode: job.mode, pick: center) ?? CutoutEngine.mask(cg, mode: job.mode) {
                    let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
                    var bytes = [UInt8](repeating: 0, count: w * h)
                    CIContext().render(CIImage(cvPixelBuffer: pb), toBitmap: &bytes, rowBytes: w, bounds: CGRect(x: 0, y: 0, width: w, height: h),
                                       format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
                    var m = MatteFrame(width: w, height: h, bytes: bytes)
                    isolate(&m, box: box.insetBy(dx: -box.width * 0.2, dy: -box.height * 0.2))
                    matte = m
                }
            }
            lastThumb = thumb
            guard let matte else { continue }
            lastMatte = matte
            window.append((f, matte))
            if window.count == 3 {
                emit(window[1].0, median(window[0].1, window[1].1, window[2].1))
                if written.isEmpty { emit(window[0].0, window[0].1) }
                window.removeFirst()
            }
        }
        for (f, m) in window where !written.contains(f) { emit(f, m) }
        return written
    }
}
