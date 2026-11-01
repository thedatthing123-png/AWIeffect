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

/// One refine-brush stroke on a cutout (AE Roto Brush style): points in source UV (0-1, top-left), radius in UV
/// units of the longer side. A stroke with `time` fixes that moment of a video (plus/minus `span` s); nil = every frame.
struct CutoutStroke: Codable, Equatable, Hashable {
    var points: [Vec2]
    var radius: Double
    var subtract: Bool
    var time: Double?
    var span: Double = 0.5
    /// Smart: the stroke grows to the edges of what it was painted on (eye, arm, sword) instead of a plain brush.
    var smart: Bool? = nil
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
    /// Refine-brush strokes (add / remove), applied on top of the AI matte.
    var strokesStore: [CutoutStroke]? = nil
    var strokes: [CutoutStroke] { get { strokesStore ?? [] } set { strokesStore = newValue.isEmpty ? nil : newValue } }
    /// Tap-picked subject (source UV): only the subject under this point is kept (Object / Drawn modes).
    var pick: Vec2? = nil
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
    private func rawMatte(_ layer: Layer, file: String, frame: Int, mode: CutoutMode, pick: Vec2? = nil, mediaURL: (String) -> URL) -> (w: Int, h: Int, bytes: [UInt8])? {
        let key = "\(file)|\(frame)|\(mode.rawValue)|\(pick.map { "\(Int($0.x * 1000)),\(Int($0.y * 1000))" } ?? "-")"
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
        guard let cg, let pb = Self.mask(cg, mode: mode, pick: pick.map { CGPoint(x: $0.x, y: $0.y) }) else { return nil }
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
        let frameTime = Double(frameKey) / 30
        let active = s.strokes.filter { st in st.time.map { abs($0 - frameTime) <= st.span } ?? true }
        let key = "\(file)|\(frameKey)|\(s.mode.rawValue)|\(Int(stab * 100))|\(s.pick.map { "\($0.x),\($0.y)" } ?? "-")|\(active.hashValue)"
        lock.lock()
        if let t = cache[key] { lock.unlock(); return t }
        lock.unlock()
        guard var cur = rawMatte(layer, file: file, frame: frameKey, mode: s.mode, pick: s.pick, mediaURL: mediaURL) else { return nil }
        if stab > 0.001 {
            // Temporal smoothing: a weighted window of neighbouring frames (wider with more Stability) so the edge
            // stops boiling; the current frame always weighs most so fast motion does not ghost.
            let reach = stab > 0.66 ? 3 : (stab > 0.33 ? 2 : 1)
            var acc = cur.bytes.map { Double($0) }
            var wsum = 1.0
            for d in 1...reach {
                let w = stab * (1 - Double(d - 1) / Double(reach + 1)) * 0.7
                for f in [frameKey - d, frameKey + d] where f >= 0 {
                    guard let n = rawMatte(layer, file: file, frame: f, mode: s.mode, pick: s.pick, mediaURL: mediaURL), n.w == cur.w, n.h == cur.h else { continue }
                    for i in acc.indices { acc[i] += Double(n.bytes[i]) * w }
                    wsum += w
                }
            }
            cur.bytes = acc.map { UInt8(min(255, max(0, $0 / wsum))) }
        }
        if !active.isEmpty {
            let smartOnes = active.filter { $0.smart == true }
            if !smartOnes.isEmpty, let src = sourcePixels(layer, file: file, frame: frameKey, w: cur.w, h: cur.h, mediaURL: mediaURL) {
                Self.smartPaint(smartOnes, source: src, into: &cur.bytes, w: cur.w, h: cur.h)
            }
            Self.paint(active.filter { $0.smart != true }, into: &cur.bytes, w: cur.w, h: cur.h)
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

    private var srcCache: [String: [UInt8]] = [:]

    /// The frame's pixels at the matte's size (for edge-aware refine strokes).
    private func sourcePixels(_ layer: Layer, file: String, frame: Int, w: Int, h: Int, mediaURL: (String) -> URL) -> [UInt8]? {
        let key = "\(file)|\(frame)|\(w)x\(h)"
        lock.lock(); if let c = srcCache[key] { lock.unlock(); return c }; lock.unlock()
        let url = mediaURL(file)
        let cg: CGImage?
        switch layer.content {
        case .video: cg = VideoSources.shared.cgImage(url: url, time: (Double(frame) + 0.5) / 30)
        case .image: cg = CIImage(contentsOf: url).flatMap { CIContext().createCGImage($0, from: $0.extent) }
        default: cg = nil
        }
        guard let cg else { return nil }
        var px = [UInt8](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.interpolationQuality = .medium
            ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        lock.lock()
        if srcCache.count > 24 { srcCache.removeAll() }
        srcCache[key] = px
        lock.unlock()
        return px
    }

    /// Smart refine (Photoshop Quick Select style): from every point of the stroke the selection floods outward
    /// through similar colors and stops at lines / color edges, within reach of the stroke. Remove strokes cut it.
    static func smartPaint(_ strokes: [CutoutStroke], source px: [UInt8], into bytes: inout [UInt8], w: Int, h: Int) {
        let side = Double(max(w, h))
        for st in strokes {
            let r = max(1.5, st.radius * side)
            let pts = st.points.map { (Int($0.x * Double(w)), Int($0.y * Double(h))) }.filter { $0.0 >= 0 && $0.1 >= 0 && $0.0 < w && $0.1 < h }
            guard !pts.isEmpty else { continue }
            // Reach: the stroke's box grown by a few brush sizes (so one stroke on an eye fills the eye, not the face).
            let reach = Int(r * 4)
            let x0 = max(0, (pts.map(\.0).min() ?? 0) - reach), x1 = min(w - 1, (pts.map(\.0).max() ?? 0) + reach)
            let y0 = max(0, (pts.map(\.1).min() ?? 0) - reach), y1 = min(h - 1, (pts.map(\.1).max() ?? 0) + reach)
            // Average color under the stroke = what we're selecting; tolerance relative to it.
            var sr = 0, sg = 0, sb = 0
            for (x, y) in pts { let o = (y * w + x) * 4; sr += Int(px[o]); sg += Int(px[o + 1]); sb += Int(px[o + 2]) }
            let n = pts.count
            let tr = sr / n, tg = sg / n, tb = sb / n
            // Spread of colors under the stroke widens the tolerance (striped / shaded parts).
            var spread = 0
            for (x, y) in pts { let o = (y * w + x) * 4; spread = max(spread, abs(Int(px[o]) - tr) + abs(Int(px[o + 1]) - tg) + abs(Int(px[o + 2]) - tb)) }
            let tol = 60 + min(120, spread)
            var seen = [Bool](repeating: false, count: w * h)
            var stack = pts
            var region: [Int] = []
            while let (x, y) = stack.popLast() {
                guard x >= x0, x <= x1, y >= y0, y <= y1 else { continue }
                let i = y * w + x
                if seen[i] { continue }
                seen[i] = true
                let o = i * 4
                let d = abs(Int(px[o]) - tr) + abs(Int(px[o + 1]) - tg) + abs(Int(px[o + 2]) - tb)
                if d > tol { continue }
                region.append(i)
                stack.append((x + 1, y)); stack.append((x - 1, y)); stack.append((x, y + 1)); stack.append((x, y - 1))
            }
            // The painted stroke itself always counts, then the grown region with a soft 1px edge.
            var m = [UInt8](repeating: 0, count: w * h)
            for i in region { m[i] = 255 }
            paint([CutoutStroke(points: st.points, radius: st.radius, subtract: false)], into: &m, w: w, h: h)
            let soft = m
            for y in max(1, y0)..<min(h - 1, y1 + 1) { for x in max(1, x0)..<min(w - 1, x1 + 1) {
                let i = y * w + x
                let center: Int = Int(soft[i]) * 4
                let sides: Int = Int(soft[i - 1]) + Int(soft[i + 1]) + Int(soft[i - w]) + Int(soft[i + w])
                m[i] = UInt8((center + sides) / 8)
            } }
            for i in 0..<(w * h) where m[i] > 0 {
                bytes[i] = st.subtract ? min(bytes[i], 255 - m[i]) : max(bytes[i], m[i])
            }
        }
    }

    /// Refine-brush strokes rasterized onto a matte (soft round brush; add = max, remove = min).
    static func paint(_ strokes: [CutoutStroke], into bytes: inout [UInt8], w: Int, h: Int) {
        let side = Double(max(w, h))
        for st in strokes {
            let r = max(1.5, st.radius * side), r2 = r * r
            var pts: [Vec2] = []
            // Fill in between samples so fast strokes stay continuous.
            for (k, p) in st.points.enumerated() {
                let q = Vec2(p.x * Double(w), p.y * Double(h))
                if k > 0, let last = pts.last {
                    let d = hypot(q.x - last.x, q.y - last.y), n = Int(d / max(1, r * 0.3))
                    if n > 0 { for j in 1...n { let t = Double(j) / Double(n + 1); pts.append(Vec2(last.x + (q.x - last.x) * t, last.y + (q.y - last.y) * t)) } }
                }
                pts.append(q)
            }
            for c in pts {
                let x0 = max(0, Int(c.x - r)), x1 = min(w - 1, Int(c.x + r)), y0 = max(0, Int(c.y - r)), y1 = min(h - 1, Int(c.y + r))
                guard x1 >= x0, y1 >= y0 else { continue }
                for y in y0...y1 { for x in x0...x1 {
                    let dx = Double(x) + 0.5 - c.x, dy = Double(y) + 0.5 - c.y, dd = dx * dx + dy * dy
                    guard dd <= r2 else { continue }
                    let a = UInt8(255 * min(1, (r - dd.squareRoot()) / max(1.5, r * 0.25)))
                    let i = y * w + x
                    bytes[i] = st.subtract ? min(bytes[i], 255 - a) : max(bytes[i], a)
                } }
            }
        }
    }

    /// One-channel matte (0-1) for the image, at the image's resolution or the model's.
    /// `pick` (UV, top-left) keeps only the subject under that point (Object / Drawn modes).
    static func mask(_ image: CGImage, mode: CutoutMode, pick: CGPoint? = nil) -> CVPixelBuffer? {
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
            var instances = obs.allInstances
            if let pick {
                // The instance label under the tap; everything if the tap missed a subject.
                let labels = obs.instanceMask
                CVPixelBufferLockBaseAddress(labels, .readOnly)
                let lw = CVPixelBufferGetWidth(labels), lh = CVPixelBufferGetHeight(labels), row = CVPixelBufferGetBytesPerRow(labels)
                if let base = CVPixelBufferGetBaseAddress(labels)?.assumingMemoryBound(to: UInt8.self) {
                    let x = min(lw - 1, max(0, Int(pick.x * Double(lw)))), y = min(lh - 1, max(0, Int(pick.y * Double(lh))))
                    let v = Int(base[y * row + x])
                    if v > 0 { instances = IndexSet(integer: v) }
                }
                CVPixelBufferUnlockBaseAddress(labels, .readOnly)
            }
            return try? obs.generateScaledMaskForImage(forInstances: instances, from: handler)
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
