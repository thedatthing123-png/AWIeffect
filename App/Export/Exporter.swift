import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox
import CoreVideo
import Metal
import UIKit

enum VideoCodec: String, CaseIterable, Identifiable {
    case h264 = "H.264", hevc = "HEVC"
    var id: String { rawValue }
    var avCodec: AVVideoCodecType { self == .h264 ? .h264 : .hevc }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4", transparent = "MOV (alpha)", prores422 = "ProRes 422", prores4444 = "ProRes 4444"
    case gif = "GIF", pngSequence = "PNG Sequence", audioM4A = "Audio M4A", audioWAV = "Audio WAV"
    var id: String { rawValue }
    var isProRes: Bool { self == .prores422 || self == .prores4444 }
    var isAudioOnly: Bool { self == .audioM4A || self == .audioWAV }
    /// Keeps empty background transparent.
    var keepsAlpha: Bool { self == .transparent || self == .prores4444 || self == .pngSequence }
    /// Has a user-chosen bitrate (the others are fixed-quality codecs).
    var usesBitrate: Bool { self == .mp4 || self == .transparent }
    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .transparent, .prores422, .prores4444: return "mov"
        case .gif: return "gif"
        case .pngSequence: return "zip"
        case .audioM4A: return "m4a"
        case .audioWAV: return "wav"
        }
    }
    /// What actually encodes the file (shown for every format).
    func codecName(_ codec: VideoCodec) -> String {
        switch self {
        case .mp4: return codec.rawValue + " video + AAC audio"
        case .transparent: return "HEVC with alpha + AAC audio"
        case .prores422: return "Apple ProRes 422 HQ + AAC audio (editing master, large files)"
        case .prores4444: return "Apple ProRes 4444 with alpha + AAC audio (editing master, very large files)"
        case .gif: return "GIF, 256 colours, no sound"
        case .pngSequence: return "PNG frames with alpha in one ZIP, no sound"
        case .audioM4A: return "AAC 256 kbps, 48 kHz stereo"
        case .audioWAV: return "PCM 16-bit, 48 kHz stereo (uncompressed)"
        }
    }
}

/// One-tap platform settings. Platforms re-encode uploads, so these aim for clean input at the right rate.
struct ExportPreset: Identifiable, Hashable {
    let name: String
    let shortSide: Double
    let codec: VideoCodec
    let bitrateMbps: Double
    let maxFPS: Double
    /// Vertical 9:16 platforms.
    let vertical: Bool
    var id: String { name }

    static let all: [ExportPreset] = [
        ExportPreset(name: "TikTok", shortSide: 1080, codec: .h264, bitrateMbps: 20, maxFPS: 60, vertical: true),
        ExportPreset(name: "Reels", shortSide: 1080, codec: .h264, bitrateMbps: 20, maxFPS: 30, vertical: true),
        ExportPreset(name: "Shorts", shortSide: 1080, codec: .h264, bitrateMbps: 24, maxFPS: 60, vertical: true),
        ExportPreset(name: "YouTube", shortSide: 2160, codec: .hevc, bitrateMbps: 40, maxFPS: 60, vertical: false),
    ]

    /// Settings for `project` (keeps the chosen range; YouTube never upscales past the project).
    func apply(to settings: ExportSettings, project: Project) -> ExportSettings {
        var s = settings
        s.format = .mp4
        s.codec = codec
        s.bitrateMbps = bitrateMbps
        let short = Double(max(1, min(project.width, project.height)))
        s.scale = (vertical ? shortSide : min(shortSide, max(1080, short))) / short
        s.fps = project.fps > maxFPS ? maxFPS : nil
        return s
    }

    /// The project's shape doesn't match the platform (the preset keeps the project's frame).
    func aspectMismatch(_ project: Project) -> Bool {
        let r = Double(project.width) / Double(max(1, project.height))
        return vertical ? abs(r - 9.0 / 16.0) > 0.02 : r < 1
    }
}

/// Still frame formats.
enum FrameFormat: String, CaseIterable, Identifiable {
    case pngAlpha = "PNG Transparent", png = "PNG", jpg = "JPG"
    var id: String { rawValue }
}

struct ExportSettings: Equatable {
    var scale: Double = 1
    var codec: VideoCodec = .h264
    var format: ExportFormat = .transparent
    /// Output frame rate (nil = the project's).
    var fps: Double? = nil
    /// Megabits per second.
    var bitrateMbps: Double = 40
    var start: Double = 0
    var end: Double? = nil
}

enum ExportError: LocalizedError {
    case noRenderer, writer(String), cancelled
    var errorDescription: String? {
        switch self {
        case .noRenderer: return "Metal renderer unavailable."
        case .writer(let s): return "Export failed: \(s)"
        case .cancelled: return "Export cancelled."
        }
    }
}

/// Renders every frame through the same Metal compositor as the preview and encodes it to video.
final class Exporter {
    private let cancellationLock = NSLock()
    private var cancellationRequested = false
    private var cancelled: Bool {
        cancellationLock.lock(); defer { cancellationLock.unlock() }
        return cancellationRequested
    }
    func cancel() {
        cancellationLock.lock(); cancellationRequested = true; cancellationLock.unlock()
    }

    static func outputSize(_ project: Project, scale: Double) -> (Int, Int) {
        // Encoders want even dimensions.
        let w = max(2, Int((Double(project.width) * scale / 2).rounded()) * 2)
        let h = max(2, Int((Double(project.height) * scale / 2).rounded()) * 2)
        return (w, h)
    }

    /// GIF output limits (applied in `exportGIF`, shown in the export sheet).
    static let gifMaxDimension = 480.0
    static let gifMaxFPS = 25.0
    static let audioBitrate = 256_000

    /// Average video bits per second actually given to the encoder: the setting is for 1080p30 and scales with
    /// resolution and frame rate, capped so Photos and other players always accept the file.
    static func videoBitrate(_ settings: ExportSettings, width w: Int, height h: Int, fps: Double) -> Int {
        let alpha = settings.format.keepsAlpha
        let mbps = min(settings.codec == .h264 && !alpha ? 60 : 120, max(8, settings.bitrateMbps * (Double(w * h) / 2_073_600) * (fps / 30)))
        return Int(mbps * 1_000_000)
    }

    /// GIF frame size and rate after the caps.
    static func gifOutput(_ project: Project, settings: ExportSettings) -> (width: Int, height: Int, fps: Double) {
        let fps = min(gifMaxFPS, settings.fps ?? project.fps)
        let longSide = Double(max(project.width, project.height))
        let maxDim = min(gifMaxDimension, longSide * settings.scale)
        let k = maxDim / max(longSide, 1)
        return (max(1, Int((Double(project.width) * k).rounded())), max(1, Int((Double(project.height) * k).rounded())), fps)
    }

    /// Expected file size in bytes, from the same numbers the encoder uses (video + AAC audio when anything is
    /// audible; HEVC alpha carries an extra alpha plane, roughly +60 %).
    static func estimatedBytes(_ project: Project, settings: ExportSettings) -> Double {
        let start = max(0, settings.start), end = min(project.duration, settings.end ?? project.duration)
        let dur = max(0, end - start)
        if settings.format == .gif {
            let g = gifOutput(project, settings: settings)
            // Palette-indexed LZW frames: about 0.4 byte per pixel for typical motion-graphics content.
            return Double(g.width * g.height) * 0.4 * (dur * g.fps).rounded()
        }
        let fps = settings.fps ?? project.fps
        let (w, h) = outputSize(project, scale: settings.scale)
        let hasAudio = project.layers.contains(where: { $0.hasAudio && $0.isVisible })
        // Pixels per second relative to 1080p30, for the fixed-quality codecs.
        let load = Double(w * h) / 2_073_600 * fps / 30
        let audio = hasAudio ? Double(audioBitrate) : 0
        switch settings.format {
        case .audioM4A: return Double(audioBitrate) * dur / 8 * 1.01
        case .audioWAV: return 48_000 * 4 * dur + 44
        case .pngSequence: return Double(w * h) * 1.6 * (dur * fps).rounded()
        case .prores422: return (220_000_000 * load + audio) * dur / 8 * 1.01
        case .prores4444: return (330_000_000 * load + audio) * dur / 8 * 1.01
        case .mp4, .transparent, .gif: break
        }
        var bps = Double(videoBitrate(settings, width: w, height: h, fps: fps))
        if settings.format == .transparent { bps *= 1.6 }
        bps += audio
        return bps * dur / 8 * 1.01   // container overhead
    }

    func export(project: Project, settings: ExportSettings, mediaURL: @escaping (String) -> URL,
                progress: @escaping (Double) -> Void) async throws -> URL {
        guard let r = Renderer.shared else { throw ExportError.noRenderer }
        // Full-resolution footage for the final render (editing uses lighter proxies); restored when done.
        VideoSources.shared.setFullQuality(true)
        let savedProxy = Renderer.allowPrecompProxy
        Renderer.allowPrecompProxy = false
        defer { Renderer.allowPrecompProxy = savedProxy }
        let savedCap = Renderer.blurSampleCap
        Renderer.blurSampleCap = nil
        defer { VideoSources.shared.setFullQuality(false); Renderer.blurSampleCap = savedCap }
        switch settings.format {
        case .gif: return try await exportGIF(project: project, settings: settings, mediaURL: mediaURL, progress: progress)
        case .pngSequence: return try await exportSequence(project: project, settings: settings, mediaURL: mediaURL, progress: progress)
        case .audioM4A, .audioWAV: return try await exportAudioOnly(project: project, settings: settings, mediaURL: mediaURL, progress: progress)
        case .mp4, .transparent, .prores422, .prores4444: break
        }
        let alpha = settings.format.keepsAlpha
        let mov = settings.format != .mp4
        var project = project
        if alpha { project.background.a = 0 }
        // Preview may cap samples adaptively; export respects the chosen maximum.
        let fps = settings.fps ?? project.fps
        let (w, h) = Self.outputSize(project, scale: settings.scale)
        let renderScale = Double(w) / Double(project.width)

        let safeName = project.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)-\(UUID().uuidString).\(settings.format.fileExtension)")
        try? FileManager.default.removeItem(at: url)

        // Video is written on its own first; audio is mixed separately and attached at the end, so the two
        // can never stall each other (the old "export stuck at 11-14%" bug).
        let videoURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-video.\(mov ? "mov" : "mp4")")
        defer { try? FileManager.default.removeItem(at: videoURL) }
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: mov ? .mov : .mp4)
        defer { if writer.status == .writing { writer.cancelWriting() } }
        var compression: [String: Any] = [
            // Bitrate scales with resolution and frame rate (the setting is for 1080p30), so fast edits never
            // turn blocky: 4K or 60 fps get proportionally more data.
            // Capped so Photos and other players always accept the file (very high H.264 rates get refused).
            AVVideoAverageBitRateKey: Self.videoBitrate(settings, width: w, height: h, fps: fps),
            AVVideoExpectedSourceFrameRateKey: Int(fps.rounded()),
            AVVideoMaxKeyFrameIntervalKey: Int(fps.rounded()),
        ]
        if settings.codec == .h264 && !alpha { compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel }
        if settings.format == .transparent {
            compression[kVTCompressionPropertyKey_TargetQualityForAlpha as String] = 0.9
            compression[kVTCompressionPropertyKey_AlphaChannelMode as String] = kVTAlphaChannelMode_StraightAlpha
        }
        let codec: AVVideoCodecType
        switch settings.format {
        case .transparent: codec = .hevcWithAlpha
        case .prores422: codec = .proRes422HQ
        case .prores4444: codec = .proRes4444
        default: codec = settings.codec.avCodec
        }
        var outputSettings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        // ProRes is fixed-quality: its encoder rejects bitrate / keyframe keys.
        if !settings.format.isProRes { outputSettings[AVVideoCompressionPropertiesKey] = compression }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ])
        guard writer.canAdd(input) else { throw ExportError.writer("cannot add video input") }
        writer.add(input)
        guard writer.startWriting() else { throw ExportError.writer(writer.error?.localizedDescription ?? "start") }
        writer.startSession(atSourceTime: .zero)

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, r.device, nil, &cache)
        guard let cache, let comp = r.makeCompTexture(width: w, height: h) else { throw ExportError.writer("texture") }
        let texPool = r.makePool()

        let start = max(0, settings.start)
        let end = min(project.duration, settings.end ?? project.duration)
        let frames = max(1, Int(((end - start) * fps).rounded()))
        let timescale = CMTimeScale(max(600, Int32(fps.rounded()) * 100))

        for i in 0..<frames {
            if cancelled { writer.cancelWriting(); throw ExportError.cancelled }
            let waitStart = CFAbsoluteTimeGetCurrent()
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw ExportError.writer(writer.error?.localizedDescription ?? "writer failed") }
                try await Task.sleep(nanoseconds: 2_000_000)
                if cancelled { writer.cancelWriting(); throw ExportError.cancelled }
                // Never sit at a percentage forever: report what stalled instead.
                if CFAbsoluteTimeGetCurrent() - waitStart > 30 { writer.cancelWriting(); throw ExportError.writer("video encoder stopped responding at frame \(i)") }
            }
            guard let pool = adaptor.pixelBufferPool else { throw ExportError.writer("no pixel buffer pool") }
            var pbOut: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
            guard let pb = pbOut else { throw ExportError.writer("pixel buffer") }
            if alpha {
                CVBufferSetAttachment(pb, kCVImageBufferAlphaChannelModeKey, kCVImageBufferAlphaChannelMode_StraightAlpha, .shouldPropagate)
            }
            var cvTex: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(nil, cache, pb, nil, .bgra8Unorm, w, h, 0, &cvTex)
            guard let cvTex, let outTex = CVMetalTextureGetTexture(cvTex), let cb = r.queue.makeCommandBuffer() else {
                throw ExportError.writer("metal texture")
            }
            let t = start + Double(i) / fps
            texPool.recycle()
            r.encode(project: project, time: t, renderScale: renderScale, into: comp, commandBuffer: cb, pool: texPool, mediaURL: mediaURL)
            r.encodeToBGRA(comp: comp, out: outTex, commandBuffer: cb, dither: true, preserveAlpha: alpha)
            let gpuDone = DispatchSemaphore(value: 0)
            cb.addCompletedHandler { _ in gpuDone.signal() }
            cb.commit()
            if gpuDone.wait(timeout: .now() + 20) == .timedOut {
                writer.cancelWriting()
                throw ExportError.writer("frame \(i) took too long to render (try a lower resolution)")
            }
            if let e = cb.error { throw ExportError.writer("GPU frame \(i): \(e.localizedDescription)") }
            let pts = CMTime(value: CMTimeValue((Double(i) / fps * Double(timescale)).rounded()), timescale: timescale)
            if !adaptor.append(pb, withPresentationTime: pts) {
                throw ExportError.writer(writer.error?.localizedDescription ?? "append failed")
            }
            progress(0.9 * Double(i + 1) / Double(frames))
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed { throw ExportError.writer(writer.error?.localizedDescription ?? "finish") }
        progress(0.9)

        // Audio pass: mix every audible layer to AAC, then mux with the video (no re-encode).
        guard let audioURL = try await Self.renderAudio(project: project, start: start, end: end, mediaURL: mediaURL, isCancelled: { self.cancelled }) else {
            try FileManager.default.moveItem(at: videoURL, to: url)
            progress(1)
            return url
        }
        defer { try? FileManager.default.removeItem(at: audioURL); try? FileManager.default.removeItem(at: videoURL) }
        let mux = AVMutableComposition()
        let vAsset = AVURLAsset(url: videoURL), aAsset = AVURLAsset(url: audioURL)
        let vDur = try await vAsset.load(.duration)
        guard let vt = try await vAsset.loadTracks(withMediaType: .video).first,
              let videoTrack = mux.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let at = try await aAsset.loadTracks(withMediaType: .audio).first,
              let audioTrack = mux.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.writer("The video or mixed audio track is missing.")
        }
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: vDur), of: vt, at: .zero)
        let aDur = try await aAsset.load(.duration)
        try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(aDur, vDur)), of: at, at: .zero)
        guard let session = AVAssetExportSession(asset: mux, presetName: AVAssetExportPresetPassthrough) else {
            throw ExportError.writer("Cannot combine the video and audio tracks.")
        }
        session.outputURL = url
        session.outputFileType = mov ? .mov : .mp4
        await session.export()
        if session.status != .completed {
            try? FileManager.default.removeItem(at: url)
            throw ExportError.writer(session.error?.localizedDescription ?? "Cannot combine video and audio.")
        }
        if cancelled { try? FileManager.default.removeItem(at: url); throw ExportError.cancelled }
        progress(1)
        return url
    }

    /// Mixes the project's audio (all audible layers, volume keys, speed) into an AAC file, or nil when silent.
    static func renderAudio(project: Project, start: Double, end: Double, mediaURL: @escaping (String) -> URL,
                            isCancelled: () -> Bool = { false }, wav: Bool = false) async throws -> URL? {
        guard let timeline = try AudioPreview.buildComposition(project, mediaURL: mediaURL, isCancelled: isCancelled) else { return nil }
        defer { withExtendedLifetime(timeline) {} }
        let comp = timeline.composition, mix = timeline.mix
        let tracks = comp.tracks(withMediaType: .audio)
        guard !tracks.isEmpty else { return nil }
        let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 48000),
                                end: CMTime(seconds: min(end, comp.duration.seconds), preferredTimescale: 48000))
        // Selecting a silent part of a project is valid, and differs from failing to decode a source.
        guard range.duration.seconds > 0, tracks.contains(where: { track in
            track.segments.contains { !$0.isEmpty && CMTimeRangeGetIntersection($0.timeMapping.target, otherRange: range).duration.seconds > 0 }
        }) else { return nil }
        let reader = try AVAssetReader(asset: comp)
        reader.timeRange = range
        let out = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2,
        ])
        out.audioMix = mix
        guard reader.canAdd(out) else { throw ExportError.writer("Cannot read the audio mix.") }
        reader.add(out)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-audio.\(wav ? "wav" : "m4a")")
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: url) } }
        let writer = try AVAssetWriter(outputURL: url, fileType: wav ? .wav : .m4a)
        defer {
            if reader.status == .reading { reader.cancelReading() }
            if writer.status == .writing { writer.cancelWriting() }
        }
        let ain = AVAssetWriterInput(mediaType: .audio, outputSettings: wav ? [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2,
        ] : [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: Self.audioBitrate,
        ])
        ain.expectsMediaDataInRealTime = false
        guard writer.canAdd(ain) else { throw ExportError.writer("Cannot encode the audio mix.") }
        writer.add(ain)
        guard reader.startReading() else { throw ExportError.writer(reader.error?.localizedDescription ?? "Cannot start audio reading.") }
        guard writer.startWriting() else { throw ExportError.writer(writer.error?.localizedDescription ?? "Cannot start audio encoding.") }
        writer.startSession(atSourceTime: CMTime(seconds: start, preferredTimescale: 48000))
        var lastProgress = CFAbsoluteTimeGetCurrent()
        while true {
            if isCancelled() || Task.isCancelled { throw ExportError.cancelled }
            guard writer.status == .writing else { throw ExportError.writer(writer.error?.localizedDescription ?? "Audio encoder stopped.") }
            if ain.isReadyForMoreMediaData {
                guard let sb = out.copyNextSampleBuffer() else { break }
                guard ain.append(sb) else { throw ExportError.writer(writer.error?.localizedDescription ?? "Audio append failed.") }
                lastProgress = CFAbsoluteTimeGetCurrent()
            } else {
                if CFAbsoluteTimeGetCurrent() - lastProgress > 30 { throw ExportError.writer("Audio encoder stopped responding.") }
                try await Task.sleep(nanoseconds: 2_000_000)
            }
        }
        guard reader.status == .completed else { throw ExportError.writer(reader.error?.localizedDescription ?? "Audio decoding did not finish.") }
        ain.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ExportError.writer(writer.error?.localizedDescription ?? "Audio encoding did not finish.") }
        completed = true
        return url
    }

    /// Sound only (M4A or WAV) for the chosen range.
    private func exportAudioOnly(project: Project, settings: ExportSettings, mediaURL: @escaping (String) -> URL,
                                 progress: @escaping (Double) -> Void) async throws -> URL {
        let start = max(0, settings.start), end = min(project.duration, settings.end ?? project.duration)
        progress(0.05)
        guard let mixed = try await Self.renderAudio(project: project, start: start, end: end, mediaURL: mediaURL,
                                                     isCancelled: { self.cancelled }, wav: settings.format == .audioWAV) else {
            throw ExportError.writer("There is no sound in the chosen range.")
        }
        let safeName = project.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName.isEmpty ? "Audio" : safeName).\(settings.format.fileExtension)")
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: mixed, to: url)
        progress(1)
        return url
    }

    /// Numbered PNG frames (with alpha) streamed into one ZIP, ready for Files or a desktop editor.
    private func exportSequence(project: Project, settings: ExportSettings, mediaURL: @escaping (String) -> URL,
                                progress: @escaping (Double) -> Void) async throws -> URL {
        guard let r = Renderer.shared else { throw ExportError.noRenderer }
        var project = project
        project.background.a = 0
        let fps = settings.fps ?? project.fps
        let start = max(0, settings.start), end = min(project.duration, settings.end ?? project.duration)
        let frames = max(1, Int(((end - start) * fps).rounded()))
        let safeName = project.name.replacingOccurrences(of: "/", with: "-")
        let base = safeName.isEmpty ? "frame" : safeName
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(base)-PNG.zip")
        let zip = try ZipArchive.Writer(url: url)
        var finished = false
        defer { if !finished { try? FileManager.default.removeItem(at: url) } }
        let (w, h) = Self.outputSize(project, scale: settings.scale)
        let digits = max(4, String(frames).count)
        for i in 0..<frames {
            if cancelled { throw ExportError.cancelled }
            let png: Data? = autoreleasepool {
                r.renderImage(project: project, time: start + Double(i) / fps, maxDimension: Double(max(w, h)), mediaURL: mediaURL)?.pngData()
            }
            guard let png else { throw ExportError.writer("frame \(i)") }
            let number = String(repeating: "0", count: max(0, digits - String(i).count)) + String(i)
            try zip.add("\(base)_\(number).png", data: png)
            progress(0.98 * Double(i + 1) / Double(frames))
            await Task.yield()
        }
        try zip.finish()
        finished = true
        progress(1)
        return url
    }

    /// One still frame of the root comp: PNG with transparency, or opaque PNG / JPG on the project background.
    static func renderFrame(project: Project, time: Double, scale: Double, format: FrameFormat, mediaURL: @escaping (String) -> URL) throws -> URL {
        guard let r = Renderer.shared else { throw ExportError.noRenderer }
        var p = project
        p.background.a = format == .pngAlpha ? 0 : 1
        let (w, h) = outputSize(p, scale: scale)
        guard let img = r.renderImage(project: p, time: time, maxDimension: Double(max(w, h)), mediaURL: mediaURL) else {
            throw ExportError.writer("Couldn't render the frame.")
        }
        let data: Data?
        switch format {
        case .pngAlpha, .png: data = img.pngData()
        case .jpg: data = img.jpegData(compressionQuality: 0.95)
        }
        guard let data else { throw ExportError.writer("Couldn't encode the frame.") }
        let safeName = p.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(6)).\(format == .jpg ? "jpg" : "png")")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Animated GIF (looping), capped at 480 px and 25 fps so files stay shareable.
    private func exportGIF(project: Project, settings: ExportSettings, mediaURL: @escaping (String) -> URL,
                           progress: @escaping (Double) -> Void) async throws -> URL {
        guard let r = Renderer.shared else { throw ExportError.noRenderer }
        let fps = min(Self.gifMaxFPS, settings.fps ?? project.fps)
        let start = max(0, settings.start), end = min(project.duration, settings.end ?? project.duration)
        let frames = max(1, Int(((end - start) * fps).rounded()))
        let safeName = project.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).gif")
        try? FileManager.default.removeItem(at: url)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames, nil) else {
            throw ExportError.writer("gif")
        }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
        let maxDim = min(Self.gifMaxDimension, Double(max(project.width, project.height)) * settings.scale)
        let props = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: 1 / fps]] as CFDictionary
        for i in 0..<frames {
            if cancelled { throw ExportError.cancelled }
            guard let img = r.renderImage(project: project, time: start + Double(i) / fps, maxDimension: maxDim, mediaURL: mediaURL)?.cgImage else {
                throw ExportError.writer("frame \(i)")
            }
            CGImageDestinationAddImage(dest, img, props)
            progress(0.9 * Double(i + 1) / Double(frames))
            await Task.yield()
        }
        guard CGImageDestinationFinalize(dest) else { throw ExportError.writer("gif finalize") }
        progress(1)
        return url
    }
}
