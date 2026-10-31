import Foundation
import AVFoundation
import Metal
import MetalKit
import CoreImage

/// Decodes video frames for layers (preview, thumbnails and export all go through here).
///
/// Playback reads frames sequentially with an `AVAssetReader` (like a real player) instead of an exact seek per
/// frame, and decodes a few frames ahead on a background queue so the preview usually finds the next frame ready.
/// Every decode for a file is serialized, so preview, export and thumbnails can ask at the same time safely.
final class VideoSources {
    static let shared = VideoSources()

    private final class Source {
        let asset: AVURLAsset
        let track: AVAssetTrack?
        let duration: Double
        let fps: Double
        let orientation: CGImagePropertyOrientation
        /// Serializes reader use for this file.
        let decodeLock = NSLock()
        var reader: AVAssetReader?
        var output: AVAssetReaderTrackOutput?
        /// Index of the last frame the reader handed out (-1 = none).
        var readerFrame = -1
        // Guarded by VideoSources.lock.
        var lastRequest = -10
        var prefetching = false
        var cache: [Int: MTLTexture] = [:]
        var order: [Int] = []

        init(url: URL) {
            asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            track = asset.tracks(withMediaType: .video).first
            duration = CMTimeGetSeconds(asset.duration)
            fps = Double(max(1, track?.nominalFrameRate ?? 30))
            orientation = Self.orientation(track?.preferredTransform ?? .identity)
        }

        static func orientation(_ t: CGAffineTransform) -> CGImagePropertyOrientation {
            let deg = (atan2(Double(t.b), Double(t.a)) * 180 / .pi).rounded()
            switch deg {
            case 90: return .right
            case -90: return .left
            case 180, -180: return .down
            default: return .up
            }
        }
    }

    private var sources: [String: Source] = [:]
    private let lock = NSLock()
    private let prefetchQueue = DispatchQueue(label: "awi.video.prefetch", qos: .userInitiated)
    private let ciLock = NSLock()
    private var ciContext: CIContext?
    static let cacheFrames = 24
    static let prefetchAhead = 4
    /// Decode size cap: a lighter "proxy" size while editing, full size while exporting.
    static let previewMaxSide: CGFloat = 1440
    static let fullMaxSide: CGFloat = 2160
    private(set) var maxSide: CGFloat = VideoSources.previewMaxSide

    /// Export switches to full-size frames (and back afterwards); cached frames of the other size are dropped.
    func setFullQuality(_ full: Bool) {
        let want = full ? Self.fullMaxSide : Self.previewMaxSide
        guard want != maxSide else { return }
        lock.lock()
        maxSide = want
        for s in sources.values { s.cache.removeAll(); s.order.removeAll() }
        lock.unlock()
    }

    private func source(_ url: URL) -> Source {
        lock.lock(); defer { lock.unlock() }
        if let s = sources[url.path] { return s }
        let s = Source(url: url)
        sources[url.path] = s
        return s
    }

    func duration(_ url: URL) -> Double { source(url).duration }
    func fps(_ url: URL) -> Double { source(url).fps }

    /// Frame texture at `time` seconds of the source (clamped), cached per source frame.
    func texture(url: URL, time: Double, device: MTLDevice) -> MTLTexture? {
        let s = source(url)
        guard s.duration > 0 else { return nil }
        let t = min(max(0, time), max(0, s.duration - 1 / s.fps))
        let frame = Int((t * s.fps + 1e-3).rounded(.down))
        lock.lock()
        let hit = s.cache[frame]
        let sequential = frame > s.lastRequest && frame - s.lastRequest <= 3
        s.lastRequest = frame
        lock.unlock()
        let tex = hit ?? decode(s, frame: frame, device: device)
        if sequential { prefetch(s, after: frame, device: device) }
        return tex
    }

    private func cachedTexture(_ s: Source, _ frame: Int) -> MTLTexture? {
        lock.lock(); defer { lock.unlock() }
        return s.cache[frame]
    }

    private func store(_ s: Source, _ frame: Int, _ tex: MTLTexture) {
        lock.lock()
        if s.cache[frame] == nil { s.order.append(frame) }
        s.cache[frame] = tex
        while s.order.count > Self.cacheFrames { s.cache[s.order.removeFirst()] = nil }
        lock.unlock()
    }

    /// Decodes the next few frames in the background while playback continues.
    private func prefetch(_ s: Source, after frame: Int, device: MTLDevice) {
        lock.lock()
        if s.prefetching { lock.unlock(); return }
        s.prefetching = true
        lock.unlock()
        let last = max(0, Int(s.duration * s.fps) - 1)
        prefetchQueue.async { [weak self] in
            guard let self else { return }
            var f = frame + 1
            while f <= min(last, frame + Self.prefetchAhead) {
                // Playback jumped elsewhere: stop guessing.
                self.lock.lock(); let req = s.lastRequest; self.lock.unlock()
                if req > f || f - req > Self.prefetchAhead + 2 { break }
                if self.cachedTexture(s, f) == nil { _ = self.decode(s, frame: f, device: device) }
                f += 1
            }
            self.lock.lock(); s.prefetching = false; self.lock.unlock()
        }
    }

    private func decode(_ s: Source, frame: Int, device: MTLDevice) -> MTLTexture? {
        s.decodeLock.lock(); defer { s.decodeLock.unlock() }
        if let t = cachedTexture(s, frame) { return t }
        guard let track = s.track else { return nil }
        // Restart the reader for backwards jumps and long forward skips (cheaper than decoding through).
        if s.reader == nil || s.reader?.status != .reading || frame <= s.readerFrame || frame - s.readerFrame > Int(s.fps * 1.5) {
            s.reader?.cancelReading()
            s.reader = nil; s.output = nil; s.readerFrame = -1
            guard let r = try? AVAssetReader(asset: s.asset) else { return nil }
            let o = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            ])
            o.alwaysCopiesSampleData = false
            guard r.canAdd(o) else { return nil }
            r.add(o)
            let start = max(0, (Double(frame) - 0.5) / s.fps)
            r.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 60000), end: .positiveInfinity)
            guard r.startReading() else { return nil }
            s.reader = r; s.output = o
        }
        guard let o = s.output else { return nil }
        while let sample = o.copyNextSampleBuffer() {
            guard let pb = CMSampleBufferGetImageBuffer(sample) else { continue }
            let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
            let idx = Int((pts * s.fps + 0.25).rounded(.down))
            s.readerFrame = idx
            if idx < frame { continue }
            guard let tex = makeTexture(pb, orientation: s.orientation, device: device) else { return nil }
            store(s, idx, tex)
            // A frame missing in the file (variable frame rate): show the next one for the requested index.
            if idx != frame { store(s, frame, tex) }
            return tex
        }
        // Reader ran off the end: show the last decoded frame, if any.
        lock.lock(); defer { lock.unlock() }
        return s.order.last.flatMap { s.cache[$0] }
    }

    /// Pixel buffer → oriented, size-capped GPU texture (values passed through untouched: still sRGB-encoded).
    private func makeTexture(_ pb: CVPixelBuffer, orientation: CGImagePropertyOrientation, device: MTLDevice) -> MTLTexture? {
        ciLock.lock(); defer { ciLock.unlock() }
        if ciContext == nil {
            ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull(), .cacheIntermediates: false])
        }
        guard let ctx = ciContext else { return nil }
        var img = CIImage(cvPixelBuffer: pb).oriented(orientation)
        img = img.transformed(by: CGAffineTransform(translationX: -img.extent.minX, y: -img.extent.minY))
        let fit = min(1, maxSide / max(img.extent.width, img.extent.height))
        if fit < 1 { img = img.transformed(by: CGAffineTransform(scaleX: fit, y: fit)) }
        let w = max(1, Int(img.extent.width.rounded())), h = max(1, Int(img.extent.height.rounded()))
        // Core Image is y-up; Metal textures are y-down.
        img = img.transformed(by: CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -CGFloat(h)))
        // Mipmapped: footage scaled down in the comp samples smoothly (no shimmer while it moves).
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: true)
        d.usage = [.shaderRead, .shaderWrite, .renderTarget]
        d.storageMode = .private
        guard let tex = device.makeTexture(descriptor: d), let cb = Renderer.shared?.queue.makeCommandBuffer() else { return nil }
        ctx.render(img, to: tex, commandBuffer: cb, bounds: CGRect(x: 0, y: 0, width: w, height: h), colorSpace: CGColorSpaceCreateDeviceRGB())
        if tex.mipmapLevelCount > 1, let bl = cb.makeBlitCommandEncoder() { bl.generateMipmaps(for: tex); bl.endEncoding() }
        cb.commit()
        return tex
    }

    func clear() {
        lock.lock(); let all = Array(sources.values); sources.removeAll(); lock.unlock()
        for s in all { s.decodeLock.lock(); s.reader?.cancelReading(); s.decodeLock.unlock() }
    }
}

/// Mapping from comp time to source time for media layers (speed, trim, time remap).
extension Layer {
    func sourceTime(at t: Double) -> Double {
        if let remap = timeRemap { return remap.value(at: t) }
        return (t - inPoint) * speed + sourceStart
    }

    var isMedia: Bool {
        switch content {
        case .video, .audio: return true
        default: return false
        }
    }

    var mediaFile: String? {
        switch content {
        case .video(let f, _, _, _), .audio(let f, _): return f
        case .image(let f, _, _): return f
        default: return nil
        }
    }

    var hasAudio: Bool {
        switch content {
        case .audio: return true
        case .video(_, _, _, let audio): return audio
        default: return false
        }
    }
}

/// Audio waveform peaks (for the timeline) and decoding helpers.
enum AudioAnalysis {
    private static var peakCache: [String: [Float]] = [:]
    private static let lock = NSLock()

    /// Mono float samples at `sampleRate`.
    static func samples(url: URL, sampleRate: Double = 22050, maxSeconds: Double = 600) -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first, let reader = try? AVAssetReader(asset: asset) else { return [] }
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1,
        ])
        reader.add(out)
        guard reader.startReading() else { return [] }
        var result: [Float] = []
        result.reserveCapacity(Int(sampleRate * min(maxSeconds, CMTimeGetSeconds(asset.duration) + 1)))
        while let sb = out.copyNextSampleBuffer(), let bb = CMSampleBufferGetDataBuffer(sb) {
            var len = 0
            var ptr: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(bb, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &len, dataPointerOut: &ptr)
            if let ptr {
                let n = len / 4
                ptr.withMemoryRebound(to: Float.self, capacity: n) { result.append(contentsOf: UnsafeBufferPointer(start: $0, count: n)) }
            }
            if Double(result.count) > sampleRate * maxSeconds { break }
        }
        return result
    }

    /// Normalized peak per bucket (`perSecond` buckets/second) for drawing waveforms.
    static func peaks(url: URL, perSecond: Int = 50) -> [Float] {
        lock.lock()
        if let p = peakCache[url.path] { lock.unlock(); return p }
        lock.unlock()
        let sr = 22050.0
        let s = samples(url: url, sampleRate: sr)
        let bucket = max(1, Int(sr) / perSecond)
        var peaks: [Float] = []
        var i = 0
        while i < s.count {
            var m: Float = 0
            for j in i..<min(s.count, i + bucket) { m = max(m, abs(s[j])) }
            peaks.append(m)
            i += bucket
        }
        let top = max(peaks.max() ?? 1, 1e-4)
        let norm = peaks.map { $0 / top }
        lock.lock(); peakCache[url.path] = norm; lock.unlock()
        return norm
    }
}
