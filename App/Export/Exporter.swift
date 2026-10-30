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
    var bitrateMbps: Double = 20
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
        if settings.format == .gif { return try await exportGIF(project: project, settings: settings, mediaURL: mediaURL, progress: progress) }
        let alpha = settings.format == .transparent
        var project = project
        if alpha { project.background.a = 0 }
        let fps = settings.fps ?? project.fps
        let (w, h) = Self.outputSize(project, scale: settings.scale)
        let renderScale = Double(w) / Double(project.width)

        let safeName = project.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).\(alpha ? "mov" : "mp4")")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: alpha ? .mov : .mp4)
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: Int(settings.bitrateMbps * 1_000_000),
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
        // Audio: mix every audible layer through the same composition the preview plays.
        var audioReader: AVAssetReader?
        var audioOut: AVAssetReaderAudioMixOutput?
        var audioIn: AVAssetWriterInput?
        if let (comp, mix) = AudioPreview.composition(project, mediaURL: mediaURL) {
            let reader = try AVAssetReader(asset: comp)
            let start = CMTime(seconds: max(0, settings.start), preferredTimescale: 48000)
            let end = CMTime(seconds: min(project.duration, settings.end ?? project.duration), preferredTimescale: 48000)
            reader.timeRange = CMTimeRange(start: start, end: end)
            let out = AVAssetReaderAudioMixOutput(audioTracks: comp.tracks(withMediaType: .audio), audioSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2,
            ])
            out.audioMix = mix
            if reader.canAdd(out) {
                reader.add(out)
                let ain = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 256_000,
                ])
                ain.expectsMediaDataInRealTime = false
                if writer.canAdd(ain) { writer.add(ain); audioReader = reader; audioOut = out; audioIn = ain }
            }
        }
        guard writer.startWriting() else { throw ExportError.writer(writer.error?.localizedDescription ?? "start") }
        writer.startSession(atSourceTime: .zero)

        // Audio is interleaved with the video as frames go out; feeding it only at the end stalls the writer
        // (video input stops being ready while it waits for audio) — the old "stuck at 14%" bug.
        let audioOffset = CMTime(seconds: max(0, settings.start), preferredTimescale: 48000)
        var pendingAudio: CMSampleBuffer?
        var audioDone = audioReader == nil
        if let reader = audioReader, !reader.startReading() { audioDone = true; audioIn?.markAsFinished() }
        func pumpAudio(until limit: CMTime) {
            guard !audioDone, let out = audioOut, let ain = audioIn else { return }
            while ain.isReadyForMoreMediaData {
                if pendingAudio == nil {
                    guard let sb = out.copyNextSampleBuffer() else { ain.markAsFinished(); audioDone = true; return }
                    var timing = CMSampleTimingInfo()
                    CMSampleBufferGetSampleTimingInfo(sb, at: 0, timingInfoOut: &timing)
                    timing.presentationTimeStamp = CMTimeSubtract(timing.presentationTimeStamp, audioOffset)
                    var shifted: CMSampleBuffer?
                    CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sb, sampleTimingEntryCount: 1,
                                                          sampleTimingArray: &timing, sampleBufferOut: &shifted)
                    pendingAudio = shifted
                    if shifted == nil { continue }
                }
                guard let sb = pendingAudio else { return }
                if CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(sb), limit) > 0 { return }
                ain.append(sb)
                pendingAudio = nil
            }
        }

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
            let ahead = CMTime(seconds: Double(i) / fps + 0.5, preferredTimescale: 48000)
            pumpAudio(until: ahead)
            while !input.isReadyForMoreMediaData {
                pumpAudio(until: ahead)
                if writer.status == .failed { throw ExportError.writer(writer.error?.localizedDescription ?? "writer failed") }
                try await Task.sleep(nanoseconds: 2_000_000)
                if cancelled { writer.cancelWriting(); throw ExportError.cancelled }
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
            cb.commit()
            cb.waitUntilCompleted()
            let pts = CMTime(value: CMTimeValue((Double(i) / fps * Double(timescale)).rounded()), timescale: timescale)
            if !adaptor.append(pb, withPresentationTime: pts) {
                throw ExportError.writer(writer.error?.localizedDescription ?? "append failed")
            }
            progress(Double(i + 1) / Double(frames))
        }
        input.markAsFinished()
        // Drain the rest of the audio.
        var spins = 0
        while !audioDone && spins < 20000 {
            pumpAudio(until: .positiveInfinity)
            if !audioDone { try await Task.sleep(nanoseconds: 1_000_000); spins += 1 }
        }
        if !audioDone { audioIn?.markAsFinished() }
        await writer.finishWriting()
        if writer.status != .completed { throw ExportError.writer(writer.error?.localizedDescription ?? "finish") }
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
            progress(Double(i + 1) / Double(frames))
            await Task.yield()
        }
        guard CGImageDestinationFinalize(dest) else { throw ExportError.writer("gif finalize") }
        return url
    }
}
