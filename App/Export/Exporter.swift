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
    private var cancelled = false
    func cancel() { cancelled = true }

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
        defer { VideoSources.shared.setFullQuality(false) }
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).\(alpha ? "mov" : "mp4")")
        try? FileManager.default.removeItem(at: url)

        // Video is written on its own first; audio is mixed separately and attached at the end, so the two
        // can never stall each other (the old "export stuck at 11-14%" bug).
        let videoURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-video.\(alpha ? "mov" : "mp4")")
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: alpha ? .mov : .mp4)
        var compression: [String: Any] = [
            // Bitrate scales with resolution and frame rate (the setting is for 1080p30), so fast edits never
            // turn blocky: 4K or 60 fps get proportionally more data.
            AVVideoAverageBitRateKey: Int(min(200, max(8, settings.bitrateMbps * (Double(w * h) / 2_073_600) * (fps / 30))) * 1_000_000),
            AVVideoExpectedSourceFrameRateKey: Int(fps.rounded()),
            AVVideoMaxKeyFrameIntervalKey: Int(fps.rounded()),
        ]
        if settings.codec == .h264 && !alpha { compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel }
        if alpha { compression[kVTCompressionPropertyKey_TargetQualityForAlpha as String] = 0.9 }
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
            var cvTex: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(nil, cache, pb, nil, .bgra8Unorm, w, h, 0, &cvTex)
            guard let cvTex, let outTex = CVMetalTextureGetTexture(cvTex), let cb = r.queue.makeCommandBuffer() else {
                throw ExportError.writer("metal texture")
            }
            let t = start + Double(i) / fps
            texPool.recycle()
            r.encode(project: project, time: t, renderScale: renderScale, into: comp, commandBuffer: cb, pool: texPool, mediaURL: mediaURL)
            r.encodeToBGRA(comp: comp, out: outTex, commandBuffer: cb)
            let gpuDone = DispatchSemaphore(value: 0)
            cb.addCompletedHandler { _ in gpuDone.signal() }
            cb.commit()
            if gpuDone.wait(timeout: .now() + 20) == .timedOut {
                writer.cancelWriting()
                throw ExportError.writer("frame \(i) took too long to render (try a lower resolution)")
            }
            if let e = cb.error { NSLog("AWIeffect export frame \(i) GPU error: \(e)") }
            let pts = CMTime(value: CMTimeValue((Double(i) / fps * Double(timescale)).rounded()), timescale: timescale)
            if !adaptor.append(pb, withPresentationTime: pts) {
                throw ExportError.writer(writer.error?.localizedDescription ?? "append failed")
            }
            progress(Double(i + 1) / Double(frames))
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed { throw ExportError.writer(writer.error?.localizedDescription ?? "finish") }
        progress(0.99)

        // Audio pass: mix every audible layer to AAC, then mux with the video (no re-encode).
        guard let audioURL = try await Self.renderAudio(project: project, start: start, end: end, mediaURL: mediaURL) else {
            try? FileManager.default.moveItem(at: videoURL, to: url)
            progress(1)
            return url
        }
        defer { try? FileManager.default.removeItem(at: audioURL); try? FileManager.default.removeItem(at: videoURL) }
        let mux = AVMutableComposition()
        let vAsset = AVURLAsset(url: videoURL), aAsset = AVURLAsset(url: audioURL)
        let vDur = try await vAsset.load(.duration)
        if let vt = try await vAsset.loadTracks(withMediaType: .video).first,
           let ct = mux.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try ct.insertTimeRange(CMTimeRange(start: .zero, duration: vDur), of: vt, at: .zero)
        }
        if let at = try await aAsset.loadTracks(withMediaType: .audio).first,
           let ct = mux.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let aDur = try await aAsset.load(.duration)
            try ct.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(aDur, vDur)), of: at, at: .zero)
        }
        guard let session = AVAssetExportSession(asset: mux, presetName: AVAssetExportPresetPassthrough) else {
            try? FileManager.default.copyItem(at: videoURL, to: url)
            progress(1)
            return url
        }
        session.outputURL = url
        session.outputFileType = alpha ? .mov : .mp4
        await session.export()
        if session.status != .completed {
            // Muxing failed: still hand back the (silent) video rather than nothing.
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.copyItem(at: videoURL, to: url)
        }
        progress(1)
        return url
    }

    /// Mixes the project's audio (all audible layers, volume keys, speed) into an AAC file, or nil when silent.
    static func renderAudio(project: Project, start: Double, end: Double, mediaURL: @escaping (String) -> URL) async throws -> URL? {
        guard let (comp, mix) = AudioPreview.composition(project, mediaURL: mediaURL) else { return nil }
        let tracks = comp.tracks(withMediaType: .audio)
        guard !tracks.isEmpty else { return nil }
        let reader = try AVAssetReader(asset: comp)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 48000), end: CMTime(seconds: end, preferredTimescale: 48000))
        let out = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2,
        ])
        out.audioMix = mix
        guard reader.canAdd(out) else { return nil }
        reader.add(out)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-audio.m4a")
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let ain = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 256_000,
        ])
        ain.expectsMediaDataInRealTime = false
        guard writer.canAdd(ain) else { return nil }
        writer.add(ain)
        guard reader.startReading(), writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: CMTime(seconds: start, preferredTimescale: 48000))
        var spins = 0
        while true {
            if ain.isReadyForMoreMediaData {
                guard let sb = out.copyNextSampleBuffer() else { break }
                ain.append(sb)
            } else {
                try await Task.sleep(nanoseconds: 1_000_000)
                spins += 1
                if spins > 60_000 { break }   // safety: never hang the export
            }
        }
        ain.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
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
            progress(Double(i + 1) / Double(frames))
            await Task.yield()
        }
        guard CGImageDestinationFinalize(dest) else { throw ExportError.writer("gif finalize") }
        return url
    }
}
