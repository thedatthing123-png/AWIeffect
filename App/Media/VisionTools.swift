import Foundation
import Vision
import CoreImage
import Metal
import MetalKit
import AVFoundation

/// AI background cutout modes (all on-device, Apple Vision).
enum CutoutMode: String, Codable, CaseIterable, Identifiable {
    case realistic   // people (VNGeneratePersonSegmentationRequest)
    case object      // any salient subject (VNGenerateForegroundInstanceMaskRequest)
    case drawn       // anime / manga / illustrations: subject lift tuned for flat art
    var id: String { rawValue }
    var title: String {
        switch self {
        case .realistic: return "Realistic (People)"
        case .object: return "Object / Figure"
        case .drawn: return "Anime / Drawn"
        }
    }
}

struct CutoutSettings: Codable, Equatable {
    var mode: CutoutMode = .realistic
    /// Grows (+) or shrinks (−) the matte edge, px.
    var choke = 0.0
    /// Softens the matte edge, px.
    var feather = 1.0
    var invert = false
    /// Video: blends each matte with its neighbouring frames so edges don't flicker (0-100).
    var stabilityStore: Double? = nil
    var stability: Double { get { stabilityStore ?? 50 } set { stabilityStore = newValue } }
    /// Sharpens (+) a soft matte edge into a clean cut; 0 keeps the AI's natural softness (hair).
    var edgeContrastStore: Double? = nil
    var edgeContrast: Double { get { edgeContrastStore ?? 0 } set { edgeContrastStore = newValue } }
}

extension VideoSources {
    /// CPU frame for analysis (Vision), at `time` seconds of the source.
    func cgImage(url: URL, time: Double, maxSize: CGFloat = 768) -> CGImage? {
        let asset = AVURLAsset(url: url)
        let g = AVAssetImageGenerator(asset: asset)
        g.appliesPreferredTrackTransform = true
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        g.maximumSize = CGSize(width: maxSize, height: maxSize)
        return try? g.copyCGImage(at: CMTime(seconds: max(0, time), preferredTimescale: 60000), actualTime: nil)
    }
}

/// Generates and caches cutout mattes as r8 textures (keyed by source file + frame + mode).
final class CutoutEngine {
    static let shared = CutoutEngine()
    private var cache: [String: MTLTexture] = [:]
    private var order: [String] = []
    private let lock = NSLock()

    private var raw: [String: (w: Int, h: Int, bytes: [UInt8])] = [:]
    private var rawOrder: [String] = []

    /// One frame's matte as bytes (computed once, cached).
    private func rawMatte(_ layer: Layer, file: String, frame: Int, mode: CutoutMode, mediaURL: (String) -> URL) -> (w: Int, h: Int, bytes: [UInt8])? {
        let key = "\(file)|\(frame)|\(mode.rawValue)"
        lock.lock()
        if let r = raw[key] { lock.unlock(); return r }
        lock.unlock()
        let url = mediaURL(file)
        let cg: CGImage?
        switch layer.content {
        case .video: cg = VideoSources.shared.cgImage(url: url, time: (Double(frame) + 0.5) / 30)
        case .image: cg = CIImage(contentsOf: url).flatMap { ci in
            let scale = min(1, 1024 / max(ci.extent.width, ci.extent.height))
            return CIContext().createCGImage(ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
                                             from: ci.extent.applying(CGAffineTransform(scaleX: scale, y: scale)))
        }
        default: cg = nil
        }
        guard let cg, let pb = Self.mask(cg, mode: mode) else { return nil }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
        var bytes = [UInt8](repeating: 0, count: w * h)
        CIContext().render(CIImage(cvPixelBuffer: pb), toBitmap: &bytes, rowBytes: w, bounds: CGRect(x: 0, y: 0, width: w, height: h),
                           format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
        let r = (w: w, h: h, bytes: bytes)
        lock.lock()
        raw[key] = r; rawOrder.append(key)
        if rawOrder.count > 96 { raw[rawOrder.removeFirst()] = nil }
        lock.unlock()
        return r
    }

    func matte(for layer: Layer, sourceTime: Double, mediaURL: (String) -> URL, device: MTLDevice) -> MTLTexture? {
        guard let s = layer.cutout, let file = layer.mediaFile else { return nil }
        var frameKey = 0
        var isVideo = false
        if case .video = layer.content { frameKey = Int((sourceTime * 30).rounded(.down)); isVideo = true }
        let stab = isVideo ? min(100, max(0, s.stability)) / 100 : 0
        let key = "\(file)|\(frameKey)|\(s.mode.rawValue)|\(Int(stab * 100))"
        lock.lock()
        if let t = cache[key] { lock.unlock(); return t }
        lock.unlock()
        guard var cur = rawMatte(layer, file: file, frame: frameKey, mode: s.mode, mediaURL: mediaURL) else { return nil }
        if stab > 0.001 {
            // Temporal smoothing: weighted average with the previous / next frame's matte (same size).
            let prev = rawMatte(layer, file: file, frame: max(0, frameKey - 1), mode: s.mode, mediaURL: mediaURL)
            let next = rawMatte(layer, file: file, frame: frameKey + 1, mode: s.mode, mediaURL: mediaURL)
            let side = stab / 3
            var out = cur.bytes
            for i in out.indices {
                var v = Double(cur.bytes[i]) * (1 - side * 2), wsum = 1 - side * 2
                if let p = prev, p.w == cur.w, p.h == cur.h { v += Double(p.bytes[i]) * side; wsum += side }
                if let n = next, n.w == cur.w, n.h == cur.h { v += Double(n.bytes[i]) * side; wsum += side }
                out[i] = UInt8(min(255, max(0, v / max(wsum, 1e-6))))
            }
            cur.bytes = out
        }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: cur.w, height: cur.h, mipmapped: false)
        d.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        tex.replace(region: MTLRegionMake2D(0, 0, cur.w, cur.h), mipmapLevel: 0, withBytes: cur.bytes, bytesPerRow: cur.w)
        lock.lock()
        cache[key] = tex
        order.append(key)
        if order.count > 48 { cache[order.removeFirst()] = nil }
        lock.unlock()
        return tex
    }

    /// Previous single-frame path (kept for callers that want the raw AI matte only).
    func rawMatteTexture(for layer: Layer, sourceTime: Double, mediaURL: (String) -> URL, device: MTLDevice) -> MTLTexture? {
        guard let s = layer.cutout, let file = layer.mediaFile else { return nil }
        var frameKey = 0
        if case .video = layer.content { frameKey = Int((sourceTime * 30).rounded(.down)) }
        let key = "\(file)|\(frameKey)|\(s.mode.rawValue)"
        lock.lock()
        if let t = cache[key] { lock.unlock(); return t }
        lock.unlock()
        let url = mediaURL(file)
        let cg: CGImage?
        switch layer.content {
        case .video: cg = VideoSources.shared.cgImage(url: url, time: sourceTime)
        case .image: cg = CIImage(contentsOf: url).flatMap { ci in
            let scale = min(1, 1024 / max(ci.extent.width, ci.extent.height))
            return CIContext().createCGImage(ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
                                             from: ci.extent.applying(CGAffineTransform(scaleX: scale, y: scale)))
        }
        default: cg = nil
        }
        guard let cg, let buffer = Self.mask(cg, mode: s.mode) else { return nil }
        guard let tex = Self.texture(from: buffer, device: device) else { return nil }
        lock.lock()
        cache[key] = tex
        order.append(key)
        if order.count > 48 { cache[order.removeFirst()] = nil }
        lock.unlock()
        return tex
    }

    /// One-channel matte (0-1) for the image, at the image's resolution or the model's.
    static func mask(_ image: CGImage, mode: CutoutMode) -> CVPixelBuffer? {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        switch mode {
        case .realistic:
            let r = VNGeneratePersonSegmentationRequest()
            r.qualityLevel = .accurate
            r.outputPixelFormat = kCVPixelFormatType_OneComponent8
            try? handler.perform([r])
            return r.results?.first?.pixelBuffer
        case .object, .drawn:
            let r = VNGenerateForegroundInstanceMaskRequest()
            try? handler.perform([r])
            guard let obs = r.results?.first else { return nil }
            return try? obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
        }
    }

    static func texture(from pb: CVPixelBuffer, device: MTLDevice) -> MTLTexture? {
        let ci = CIImage(cvPixelBuffer: pb)
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.shaderRead, .shaderWrite]
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        let ctx = CIContext(mtlDevice: device)
        // Masks may come as OneComponent32Float (instance masks) or 8-bit; render to gray8 either way.
        var bytes = [UInt8](repeating: 0, count: w * h)
        ctx.render(ci, toBitmap: &bytes, rowBytes: w, bounds: CGRect(x: 0, y: 0, width: w, height: h), format: .L8,
                   colorSpace: CGColorSpaceCreateDeviceGray())
        tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: bytes, bytesPerRow: w)
        return tex
    }

    func clear() { lock.lock(); cache.removeAll(); order.removeAll(); raw.removeAll(); rawOrder.removeAll(); lock.unlock() }
}

// MARK: - Motion tracking

enum MotionTracker {
    /// Tracks the object inside `box` (normalized source-image rect, origin top-left) from `start` to `end` source seconds.
    /// Returns (source time, normalized center) samples at `fps`.
    static func track(url: URL, box: CGRect, start: Double, end: Double, fps: Double,
                      progress: (Double) -> Void) -> [(Double, CGPoint)] {
        let seq = VNSequenceRequestHandler()
        // Vision uses a bottom-left origin.
        var observation = VNDetectedObjectObservation(boundingBox: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
        var out: [(Double, CGPoint)] = [(start, CGPoint(x: box.midX, y: box.midY))]
        let step = 1 / max(fps, 1)
        var t = start + step
        while t <= end {
            guard let cg = VideoSources.shared.cgImage(url: url, time: t, maxSize: 640) else { break }
            let req = VNTrackObjectRequest(detectedObjectObservation: observation)
            req.trackingLevel = .accurate
            do { try seq.perform([req], on: cg) } catch { break }
            guard let res = req.results?.first as? VNDetectedObjectObservation, res.confidence > 0.2 else { break }
            observation = res
            let b = res.boundingBox
            out.append((t, CGPoint(x: b.midX, y: 1 - b.midY)))
            progress((t - start) / max(end - start, 1e-6))
            t += step
        }
        return out
    }
}
