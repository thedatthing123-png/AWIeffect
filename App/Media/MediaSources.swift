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
        /// One sequential reader per playback position: two copies of the same clip at different times each keep
        /// their own reader instead of fighting over one (which made both stutter and show wrong frames).
        let channels: [Channel] = (0..<VideoSources.channelCount).map { _ in Channel() }
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

    private final class Channel {
        /// Serializes this reader.
        let decodeLock = NSLock()
        var reader: AVAssetReader?
        var output: AVAssetReaderTrackOutput?
        /// Index of the last frame the reader handed out (-1 = none).
        var readerFrame = -1
        // Guarded by VideoSources.lock.
        var lastRequest = -10
        var prefetching = false
        var lastUse: UInt64 = 0
        var owner: Int?
    }

    static let channelCount = 4
    private var useCounter: UInt64 = 0
    private var sources: [String: Source] = [:]
    private let lock = NSLock()
    private let prefetchQueue = DispatchQueue(label: "awi.video.prefetch", qos: .userInitiated)
    private let ciLock = NSLock()
    private var ciContext: CIContext?
    static let cacheFrames = 48
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
    /// `channel` identifies who is asking (a layer): each caller keeps its own reader position.
    func texture(url: URL, time: Double, device: MTLDevice, channel: Int = 0) -> MTLTexture? {
        let s = source(url)
        guard s.duration > 0 else { return nil }
        let t = min(max(0, time), max(0, s.duration - 1 / s.fps))
        let frame = Int((t * s.fps + 1e-3).rounded(.down))
        lock.lock()
        let c = pickChannel(s, owner: channel, frame: frame)
        let hit = s.cache[frame]
        let sequential = frame > c.lastRequest && frame - c.lastRequest <= 3
        c.lastRequest = frame
        lock.unlock()
        let tex = hit ?? decode(s, c, frame: frame, device: device)
        if sequential { prefetch(s, c, after: frame, device: device) }
        return tex
    }

    /// A channel already reading right here (copies of a clip at the same moment share one decoder — phones only
    /// allow a few), else the caller's own, else a free one, else the least recently used. Call with `lock` held.
    private func pickChannel(_ s: Source, owner: Int, frame: Int) -> Channel {
        useCounter &+= 1
        if let near = s.channels.filter({ $0.owner != nil && $0.lastRequest >= 0 && frame >= $0.lastRequest && frame - $0.lastRequest <= 2 })
            .min(by: { frame - $0.lastRequest < frame - $1.lastRequest }) {
            near.lastUse = useCounter
            return near
        }
        let c = s.channels.first { $0.owner == owner }
            ?? s.channels.first { $0.owner == nil }
            ?? s.channels.min { $0.lastUse < $1.lastUse }!
        if c.owner != owner { c.owner = owner; c.lastRequest = -10 }
        c.lastUse = useCounter
        return c
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
    private func prefetch(_ s: Source, _ c: Channel, after frame: Int, device: MTLDevice) {
        lock.lock()
        if c.prefetching { lock.unlock(); return }
        c.prefetching = true
        lock.unlock()
        let last = max(0, Int(s.duration * s.fps) - 1)
        prefetchQueue.async { [weak self] in
            guard let self else { return }
            var f = frame + 1
            while f <= min(last, frame + Self.prefetchAhead) {
                // Playback jumped elsewhere: stop guessing.
                self.lock.lock(); let req = c.lastRequest; self.lock.unlock()
                if req > f || f - req > Self.prefetchAhead + 2 { break }
                if self.cachedTexture(s, f) == nil { _ = self.decode(s, c, frame: f, device: device) }
                f += 1
            }
            self.lock.lock(); c.prefetching = false; self.lock.unlock()
        }
    }

    private func decode(_ s: Source, _ c: Channel, frame: Int, device: MTLDevice, retried: Bool = false) -> MTLTexture? {
        c.decodeLock.lock(); defer { c.decodeLock.unlock() }
        if let t = cachedTexture(s, frame) { return t }
        guard let track = s.track else { return nil }
        // Restart the reader for backwards jumps and long forward skips (cheaper than decoding through).
        if c.reader == nil || c.reader?.status != .reading || frame <= c.readerFrame || frame - c.readerFrame > Int(s.fps * 1.5) {
            c.reader?.cancelReading()
            c.reader = nil; c.output = nil; c.readerFrame = -1
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
            c.reader = r; c.output = o
        }
        guard let o = c.output else { return nil }
        while let sample = o.copyNextSampleBuffer() {
            guard let pb = CMSampleBufferGetImageBuffer(sample) else { continue }
            let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
            let idx = Int((pts * s.fps + 0.25).rounded(.down))
            c.readerFrame = idx
            if idx < frame { continue }
            // The reader skipped past the frame we want (it was sitting somewhere else): reopen exactly at this frame
            // once instead of showing a later frame (that was a twitch on duplicated clips).
            if idx > frame + 1 && !retried {
                c.reader?.cancelReading(); c.reader = nil; c.output = nil; c.readerFrame = -1
                c.decodeLock.unlock()
                defer { c.decodeLock.lock() }
                return decode(s, c, frame: frame, device: device, retried: true)
            }
            guard let tex = makeTexture(pb, orientation: s.orientation, device: device) else { return nil }
            store(s, idx, tex)
            // A frame missing in the file (variable frame rate): show the next one for the requested index.
            if idx != frame { store(s, frame, tex) }
            return tex
        }
        // The decoder was refused / failed mid-way: start a fresh reader once and try again before giving up.
        if c.reader?.status == .failed, !retried {
            c.reader = nil; c.output = nil; c.readerFrame = -1
            c.decodeLock.unlock()
            defer { c.decodeLock.lock() }
            return decode(s, c, frame: frame, device: device, retried: true)
        }
        // Reader ran off the end (or failed): show the nearest cached frame of this file, never an unrelated one.
        lock.lock(); defer { lock.unlock() }
        guard let near = s.cache.keys.min(by: { abs($0 - frame) < abs($1 - frame) }), abs(near - frame) <= 2 else { return nil }
        return s.cache[near]
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
        // CI encodes GPU work lazily. Keep the decoder's surface alive until that work completes;
        // releasing it here let AVFoundation reuse it for a later frame during prefetch.
        cb.addCompletedHandler { [pb, img] _ in withExtendedLifetime((pb, img)) {} }
        cb.commit()
        return tex
    }

    func clear() {
        lock.lock(); let all = Array(sources.values); sources.removeAll(); lock.unlock()
        for s in all { for c in s.channels { c.decodeLock.lock(); c.reader?.cancelReading(); c.decodeLock.unlock() } }
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
