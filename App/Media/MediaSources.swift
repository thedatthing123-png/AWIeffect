import Foundation
import AVFoundation
import Metal
import MetalKit
import CoreImage

/// Decodes video frames for layers (preview, thumbnails and export all go through here).
final class VideoSources {
    static let shared = VideoSources()

    private final class Source {
        let asset: AVURLAsset
        let generator: AVAssetImageGenerator
        let duration: Double
        let fps: Double
        var cache: [Int: MTLTexture] = [:]
        var order: [Int] = []
        init(url: URL) {
            asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            generator.maximumSize = CGSize(width: 2160, height: 2160)
            duration = CMTimeGetSeconds(asset.duration)
            fps = Double(asset.tracks(withMediaType: .video).first?.nominalFrameRate ?? 30)
        }
    }

    private var sources: [String: Source] = [:]
    private let lock = NSLock()
    private var loader: MTKTextureLoader?
    static let cacheFrames = 12

    private func source(_ url: URL) -> Source {
        lock.lock(); defer { lock.unlock() }
        if let s = sources[url.path] { return s }
        let s = Source(url: url)
        sources[url.path] = s
        return s
    }

    func duration(_ url: URL) -> Double { source(url).duration }

    /// Frame texture at `time` seconds of the source (clamped), cached per source frame.
    func texture(url: URL, time: Double, device: MTLDevice) -> MTLTexture? {
        let s = source(url)
        let t = min(max(0, time), max(0, s.duration - 1 / max(s.fps, 1)))
        let frame = Int((t * s.fps).rounded(.down))
        lock.lock()
        if let tex = s.cache[frame] { lock.unlock(); return tex }
        if loader == nil { loader = MTKTextureLoader(device: device) }
        let loader = self.loader!
        lock.unlock()
        let cm = CMTime(seconds: (Double(frame) + 0.5) / s.fps, preferredTimescale: 60000)
        guard let cg = try? s.generator.copyCGImage(at: cm, actualTime: nil),
              let tex = try? loader.newTexture(cgImage: cg, options: [.SRGB: false, .textureStorageMode: MTLStorageMode.private.rawValue])
        else { return nil }
        lock.lock()
        s.cache[frame] = tex
        s.order.append(frame)
        if s.order.count > Self.cacheFrames { s.cache[s.order.removeFirst()] = nil }
        lock.unlock()
        return tex
    }

    func clear() { lock.lock(); sources.removeAll(); lock.unlock() }
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
