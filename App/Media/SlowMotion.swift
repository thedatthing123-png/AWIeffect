import Foundation
import AVFoundation
import VideoToolbox

/// Twixtor-style smooth slow motion: renders a clip once with in-between frames made by Apple's on-device
/// optical-flow frame interpolation (VideoToolbox, iOS 26), so a 4x slowed clip plays at full smoothness.
/// The result is a new video file; the layer switches to it at normal speed.
enum SlowMotion {
    enum Failure: LocalizedError {
        case unsupported, reader, writer(String), cancelled
        var errorDescription: String? {
            switch self {
            case .unsupported: return "Smooth Slow-Mo isn't available for this clip on this device."
            case .reader: return "Couldn't read the video."
            case .writer(let s): return "Couldn't write the slow-mo video: \(s)"
            case .cancelled: return "Cancelled."
            }
        }
    }

    /// Renders `url` slowed down `factor` times (2, 4, 8). Returns the new file.
    static func render(url: URL, factor: Int, progress: @escaping (Double) -> Void) async throws -> URL {
        #if targetEnvironment(simulator)
        throw Failure.unsupported
        #else
        guard #available(iOS 26.0, *) else { throw Failure.unsupported }
        return try await Interpolator.render(url: url, factor: max(2, factor), progress: progress)
        #endif
    }
}

#if !targetEnvironment(simulator)
@available(iOS 26.0, *)
private enum Interpolator {
    static func render(url: URL, factor: Int, progress: @escaping (Double) -> Void) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw SlowMotion.Failure.reader }
        let natural = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let fps = Double(try await track.load(.nominalFrameRate))
        let duration = try await asset.load(.duration).seconds
        let w = Int(natural.width), h = Int(natural.height)

        guard VTFrameRateConversionConfiguration.isSupported,
              let config = VTFrameRateConversionConfiguration(frameWidth: w, frameHeight: h, usePrecomputedFlow: false,
                                                              qualityPrioritization: .quality, revision: .revision1)
        else { throw SlowMotion.Failure.unsupported }
        let processor = VTFrameProcessor()
        try processor.startSession(configuration: config)
        defer { processor.endSession() }

        // Read frames in the format the interpolator wants, so no conversion is needed.
        let reader = try AVAssetReader(asset: asset)
        var srcAttrs = (config.sourcePixelBufferAttributes as? [String: Any]) ?? [:]
        if srcAttrs[kCVPixelBufferPixelFormatTypeKey as String] == nil { srcAttrs[kCVPixelBufferPixelFormatTypeKey as String] = kCVPixelFormatType_32BGRA }
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: srcAttrs)
        out.alwaysCopiesSampleData = false
        guard reader.canAdd(out) else { throw SlowMotion.Failure.reader }
        reader.add(out)
        guard reader.startReading() else { throw SlowMotion.Failure.reader }

        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, config.destinationPixelBufferAttributes as CFDictionary, &pool)
        guard let pool else { throw SlowMotion.Failure.writer("buffer pool") }

        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("slowmo-\(factor)x-\(UUID().uuidString.prefix(6)).mov")
        let writer = try AVAssetWriter(outputURL: dest, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: w, AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: max(8_000_000, w * h * 12)],
        ])
        input.transform = transform
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        guard writer.canAdd(input) else { throw SlowMotion.Failure.writer("input") }
        writer.add(input)
        guard writer.startWriting() else { throw SlowMotion.Failure.writer(writer.error?.localizedDescription ?? "start") }
        writer.startSession(atSourceTime: .zero)

        // Output: every source frame plus (factor - 1) in-betweens, all one source frame-time apart -> factor x slower.
        let step = CMTime(value: 1000, timescale: CMTimeScale(max(1, fps * 1000)))
        var outIndex: Int64 = 0
        func append(_ pb: CVPixelBuffer) async throws {
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw SlowMotion.Failure.writer(writer.error?.localizedDescription ?? "failed") }
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            if !adaptor.append(pb, withPresentationTime: CMTimeMultiply(step, multiplier: Int32(outIndex))) {
                throw SlowMotion.Failure.writer(writer.error?.localizedDescription ?? "append")
            }
            outIndex += 1
        }

        let phases = (1..<factor).map { Float($0) / Float(factor) }
        var previous: (pb: CVPixelBuffer, pts: CMTime)?
        while let sample = out.copyNextSampleBuffer() {
            if Task.isCancelled { writer.cancelWriting(); throw SlowMotion.Failure.cancelled }
            guard let pb = CMSampleBufferGetImageBuffer(sample) else { continue }
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            if let prev = previous, CMTimeCompare(pts, prev.pts) > 0 {
                var dests: [VTFrameProcessorFrame] = []
                let span = CMTimeSubtract(pts, prev.pts)
                for ph in phases {
                    var b: CVPixelBuffer?
                    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &b)
                    let t = CMTimeAdd(prev.pts, CMTimeMultiplyByFloat64(CMTimeConvertScale(span, timescale: 90_000, method: .roundHalfAwayFromZero), multiplier: Float64(ph)))
                    if let b, let f = VTFrameProcessorFrame(buffer: b, presentationTimeStamp: t) { dests.append(f) }
                }
                if dests.count == phases.count,
                   let a = VTFrameProcessorFrame(buffer: prev.pb, presentationTimeStamp: prev.pts),
                   let n = VTFrameProcessorFrame(buffer: pb, presentationTimeStamp: pts),
                   let params = VTFrameRateConversionParameters(sourceFrame: a, nextFrame: n, opticalFlow: nil, interpolationPhase: phases,
                                                                submissionMode: .sequential, destinationFrames: dests) {
                    try await processor.process(parameters: params)
                    for d in dests { try await append(d.buffer) }
                } else {
                    // Couldn't interpolate this pair: repeat the frame so timing stays right.
                    for _ in phases { try await append(prev.pb) }
                }
            }
            try await append(pb)
            previous = (pb, pts)
            if duration > 0 { progress(min(0.99, pts.seconds / duration)) }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw SlowMotion.Failure.writer(writer.error?.localizedDescription ?? "finish") }
        progress(1)
        return dest
    }
}
#endif

extension EditorState {
    /// Replaces the selected video layer's clip with a smooth slow-motion render (same in point, `factor` x longer).
    func applySmoothSlowMo(factor: Int, progress: @escaping (Double) -> Void) async throws {
        guard let l = selectedLayer, case .video(let file, let pw, let ph, _) = l.content else { return }
        let src = mediaURL(file)
        let out = try await SlowMotion.render(url: src, factor: factor, progress: progress)
        let data = try Data(contentsOf: out)
        let name = try store.importMedia(data: data, ext: "mov", into: project.id)
        try? FileManager.default.removeItem(at: out)
        guard let i = project.layers.firstIndex(where: { $0.id == l.id }) else { return }
        mutate("Smooth Slow-Mo \(factor)x") { p in
            let old = p.layers[i]
            p.layers[i].content = .video(fileName: name, pixelWidth: pw, pixelHeight: ph, hasAudio: false)
            p.layers[i].sourceStart = old.sourceStart * Double(factor)
            p.layers[i].speed = old.speed
            p.layers[i].outPoint = old.inPoint + (old.outPoint - old.inPoint) * Double(factor)
        }
    }
}
