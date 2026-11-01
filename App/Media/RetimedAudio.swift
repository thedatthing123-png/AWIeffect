import AVFoundation

/// Disk-backed PCM resampling for reverse and arbitrary source-time curves. Preview and export use
/// the same result. Only a few source pages are resident, even for long clips.
enum RetimedAudio {
    private static let lock = NSLock()
    final class Source {
        let asset: AVURLAsset
        init(url: URL) { asset = AVURLAsset(url: url) }
        deinit { try? FileManager.default.removeItem(at: asset.url) }
    }
    private static let cache: NSCache<NSData, Source> = {
        let cache = NSCache<NSData, Source>()
        cache.countLimit = 4
        cache.totalCostLimit = 256 * 1024 * 1024
        return cache
    }()
    private static let rate = 48_000.0

    static func source(for layer: Layer, source: URL, isCancelled: () -> Bool = { false }) throws -> Source {
        lock.lock(); defer { lock.unlock() }
        if isCancelled() || Task.isCancelled { throw ExportError.cancelled }
        let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var key = try encoder.encode(layer)
        key.append(Data("\(source.path)|\(attributes[.size] ?? 0)|\(attributes[.modificationDate] ?? "")".utf8))
        if let source = cache.object(forKey: key as NSData), FileManager.default.fileExists(atPath: source.asset.url.path) { return source }
        let decoded = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: decoded) }
        try decode(source, to: decoded, isCancelled: isCancelled)
        let input = try AVAudioFile(forReading: decoded, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = input.processingFormat
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-retimed.caf")
        var success = false
        defer { if !success { try? FileManager.default.removeItem(at: outputURL) } }
        let duration = layer.outPoint - layer.inPoint
        guard duration.isFinite, duration > 0, duration * rate < Double(Int64.max) else {
            throw ExportError.writer("Invalid audio layer duration.")
        }
        do {
            let output = try AVAudioFile(forWriting: outputURL, settings: format.settings)
            let count = Int64((duration * rate).rounded())
            let pageSize: Int64 = 4096
            var pages: [Int64: AVAudioPCMBuffer] = [:]
            func sample(_ frame: Int64, _ channel: Int) throws -> Float {
                guard frame >= 0, frame < input.length else { return 0 }
                let page = frame / pageSize
                if pages[page] == nil {
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(pageSize)) else {
                        throw ExportError.writer("Cannot allocate audio samples.")
                    }
                    input.framePosition = page * pageSize
                    try input.read(into: buffer)
                    if pages.count >= 4 { pages.removeAll() }
                    pages[page] = buffer
                }
                guard let buffer = pages[page], let data = buffer.floatChannelData else { return 0 }
                let offset = Int(frame % pageSize)
                return offset < Int(buffer.frameLength) ? data[channel][offset] : 0
            }
            var offset: Int64 = 0
            while offset < count {
                if isCancelled() || Task.isCancelled { throw ExportError.cancelled }
                let n = AVAudioFrameCount(min(4096, count - offset))
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n), let channels = buffer.floatChannelData else {
                    throw ExportError.writer("Cannot allocate retimed audio.")
                }
                buffer.frameLength = n
                for i in 0..<Int(n) {
                    let t = layer.inPoint + Double(offset + Int64(i)) / rate
                    let seconds = layer.sourceTime(at: t)
                    let next = layer.sourceTime(at: t + 1 / rate)
                    let position = seconds * rate
                    // A frozen picture has no advancing audio; out-of-source ranges are silence.
                    let valid = position.isFinite && position >= 0 && position < Double(input.length) && abs(next - seconds) > 1e-12
                    for c in 0..<Int(format.channelCount) {
                        if valid {
                            let a = Int64(position.rounded(.down))
                            let fraction = Float(position - Double(a))
                            let first = try sample(a, c), second = try sample(a + 1, c)
                            channels[c][i] = first + (second - first) * fraction
                        } else { channels[c][i] = 0 }
                    }
                }
                try output.write(from: buffer)
                offset += Int64(n)
            }
        }
        success = true
        let source = Source(url: outputURL)
        let bytes = (try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.intValue ?? 0
        cache.setObject(source, forKey: key as NSData, cost: bytes)
        return source
    }

    private static func decode(_ url: URL, to output: URL, isCancelled: () -> Bool) throws {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else { throw ExportError.writer("Audio source has no sound track.") }
        let reader = try AVAssetReader(asset: asset)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: true)!
        let settings = format.settings
        let source = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        guard reader.canAdd(source) else { throw ExportError.writer("Cannot decode audio source.") }
        reader.add(source)
        let file = try AVAudioFile(forWriting: output, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: true)
        guard reader.startReading() else { throw ExportError.writer(reader.error?.localizedDescription ?? "Cannot read audio.") }
        defer { if reader.status == .reading { reader.cancelReading() } }
        while let sample = source.copyNextSampleBuffer() {
            if isCancelled() || Task.isCancelled { throw ExportError.cancelled }
            let frames = CMSampleBufferGetNumSamples(sample)
            guard frames > 0, let block = CMSampleBufferGetDataBuffer(sample),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
                  let bytes = buffer.mutableAudioBufferList.pointee.mBuffers.mData else {
                throw ExportError.writer("Invalid decoded audio samples.")
            }
            buffer.frameLength = AVAudioFrameCount(frames)
            let size = frames * Int(format.streamDescription.pointee.mBytesPerFrame)
            guard CMBlockBufferGetDataLength(block) >= size,
                  CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: size, destination: bytes) == kCMBlockBufferNoErr else {
                throw ExportError.writer("Cannot copy decoded audio samples.")
            }
            try file.write(from: buffer)
        }
        guard reader.status == .completed else { throw ExportError.writer(reader.error?.localizedDescription ?? "Audio source decoding failed.") }
    }
}
