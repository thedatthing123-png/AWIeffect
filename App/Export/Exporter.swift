import Foundation
import AVFoundation
import CoreVideo
import Metal

enum VideoCodec: String, CaseIterable, Identifiable {
    case h264 = "H.264", hevc = "HEVC"
    var id: String { rawValue }
    var avCodec: AVVideoCodecType { self == .h264 ? .h264 : .hevc }
}

struct ExportSettings: Equatable {
    var scale: Double = 1
    var codec: VideoCodec = .h264
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
        let (w, h) = Self.outputSize(project, scale: settings.scale)
        let renderScale = Double(w) / Double(project.width)

        let safeName = project.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: Int(settings.bitrateMbps * 1_000_000),
            AVVideoExpectedSourceFrameRateKey: Int(project.fps.rounded()),
            AVVideoMaxKeyFrameIntervalKey: Int(project.fps.rounded()),
        ]
        if settings.codec == .h264 { compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: settings.codec.avCodec,
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
        let pool = r.makePool()

        let start = max(0, settings.start)
        let end = min(project.duration, settings.end ?? project.duration)
        let frames = max(1, Int(((end - start) * project.fps).rounded()))
        let timescale = CMTimeScale(max(600, Int32(project.fps.rounded()) * 100))

        for i in 0..<frames {
            if cancelled { writer.cancelWriting(); throw ExportError.cancelled }
            while !input.isReadyForMoreMediaData {
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
            let t = start + Double(i) / project.fps
            pool.recycle()
            r.encode(project: project, time: t, renderScale: renderScale, into: comp, commandBuffer: cb, pool: pool, mediaURL: mediaURL)
            r.encodeToBGRA(comp: comp, out: outTex, commandBuffer: cb)
            cb.commit()
            cb.waitUntilCompleted()
            let pts = CMTime(value: CMTimeValue((Double(i) / project.fps * Double(timescale)).rounded()), timescale: timescale)
            if !adaptor.append(pb, withPresentationTime: pts) {
                throw ExportError.writer(writer.error?.localizedDescription ?? "append failed")
            }
            progress(Double(i + 1) / Double(frames))
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed { throw ExportError.writer(writer.error?.localizedDescription ?? "finish") }
        return url
    }
}
