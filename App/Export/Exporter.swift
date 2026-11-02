import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox
import CoreVideo
import Metal

enum VideoCodec: String, CaseIterable, Identifiable {
    case h264 = "H.264", hevc = "HEVC"
    var id: String { rawValue }
    var avCodec: AVVideoCodecType { self == .h264 ? .h264 : .hevc }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4", transparent = "MOV (alpha)", gif = "GIF"
    var id: String { rawValue }
}

struct ExportSettings: Equatable {
    var scale: Double = 1
    var codec: VideoCodec = .h264
    var format: ExportFormat = .mp4
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

    func export(project: Project, settings: ExportSettings, mediaURL: @escaping (String) -> URL,
                progress: @escaping (Double) -> Void) async throws -> URL {
        guard let r = Renderer.shared else { throw ExportError.noRenderer }
        // Full-resolution footage for the final render (editing uses lighter proxies); restored when done.
        VideoSources.shared.setFullQuality(true)
        let savedCap = Renderer.blurSampleCap
        Renderer.blurSampleCap = nil
        defer { VideoSources.shared.setFullQuality(false); Renderer.blurSampleCap = savedCap }
        if settings.format == .gif { return try await exportGIF(project: project, settings: settings, mediaURL: mediaURL, progress: progress) }
        let alpha = settings.format == .transparent
        var project = project
        if alpha { project.background.a = 0 }
        // Final render quality: denser motion blur than the live preview (silky blur on shakes and fast moves).
        project.blurSamples = max(project.blurSamples, 32)
        let fps = settings.fps ?? project.fps
        let (w, h) = Self.outputSize(project, scale: settings.scale)
        let renderScale = Double(w) / Double(project.width)

        let safeName = project.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)-\(UUID().uuidString).\(alpha ? "mov" : "mp4")")
        try? FileManager.default.removeItem(at: url)

        // Video is written on its own first; audio is mixed separately and attached at the end, so the two
        // can never stall each other (the old "export stuck at 11-14%" bug).
        let videoURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-video.\(alpha ? "mov" : "mp4")")
        defer { try? FileManager.default.removeItem(at: videoURL) }
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: alpha ? .mov : .mp4)
        defer { if writer.status == .writing { writer.cancelWriting() } }
        var compression: [String: Any] = [
            // Bitrate scales with resolution and frame rate (the setting is for 1080p30), so fast edits never
            // turn blocky: 4K or 60 fps get proportionally more data.
            // Capped so Photos and other players always accept the file (very high H.264 rates get refused).
            AVVideoAverageBitRateKey: Int(min(settings.codec == .h264 && !alpha ? 60 : 120, max(8, settings.bitrateMbps * (Double(w * h) / 2_073_600) * (fps / 30))) * 1_000_000),
            AVVideoExpectedSourceFrameRateKey: Int(fps.rounded()),
            AVVideoMaxKeyFrameIntervalKey: Int(fps.rounded()),
        ]
        if settings.codec == .h264 && !alpha { compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel }
        if alpha {
            compression[kVTCompressionPropertyKey_TargetQualityForAlpha as String] = 0.9
            compression[kVTCompressionPropertyKey_AlphaChannelMode as String] = kVTAlphaChannelMode_StraightAlpha
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: alpha ? AVVideoCodecType.hevcWithAlpha : settings.codec.avCodec,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: compression,
        ])
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
        session.outputFileType = alpha ? .mov : .mp4
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
                            isCancelled: () -> Bool = { false }) async throws -> URL? {
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-audio.m4a")
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: url) } }
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        defer {
            if reader.status == .reading { reader.cancelReading() }
            if writer.status == .writing { writer.cancelWriting() }
        }
        let ain = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 256_000,
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

    /// Animated GIF (looping), capped at 480 px and 25 fps so files stay shareable.
    private func exportGIF(project: Project, settings: ExportSettings, mediaURL: @escaping (String) -> URL,
                           progress: @escaping (Double) -> Void) async throws -> URL {
        guard let r = Renderer.shared else { throw ExportError.noRenderer }
        let fps = min(25, settings.fps ?? project.fps)
        let start = max(0, settings.start), end = min(project.duration, settings.end ?? project.duration)
        let frames = max(1, Int(((end - start) * fps).rounded()))
        let safeName = project.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).gif")
        try? FileManager.default.removeItem(at: url)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames, nil) else {
            throw ExportError.writer("gif")
        }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
        let maxDim = min(480, Double(max(project.width, project.height)) * settings.scale)
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
