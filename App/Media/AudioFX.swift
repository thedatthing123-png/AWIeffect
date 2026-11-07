import Foundation
import AVFoundation
import AudioToolbox

/// Per-layer audio processing: 3-band EQ with low/high cut, compressor, pitch shift, speed pitch and ducking under
/// another layer. Applied by `AudioPreview.buildComposition`, so preview and export always hear the same thing.
struct LayerAudioFX: Codable, Equatable {
    /// High-pass / low-pass corner in Hz (0 = off).
    var lowCut: Double = 0
    var highCut: Double = 0
    /// Shelf at 120 Hz, bell at `midFrequency`, shelf at 8 kHz (dB).
    var lowGain: Double = 0
    var midGain: Double = 0
    var midFrequency: Double = 1000
    var highGain: Double = 0
    /// Compressor: threshold (dB) and make-up gain (dB) after it.
    var compressor = false
    var threshold: Double = -18
    var makeup: Double = 0
    /// Pitch shift in semitones (length unchanged).
    var pitch: Double = 0
    /// Constant speed changes keep the original pitch (tape-style when off: slower = deeper).
    var keepPitch = true
    /// Ducking: this layer gets quieter while `duckUnder` is sounding.
    var duckUnder: UUID? = nil
    var duckAmount: Double = -12
    var duckRelease: Double = 0.35
    /// Clip fades (seconds from each edge) and their curve; separate from the volume keys, like an NLE fade handle.
    var fadeIn: Double = 0
    var fadeOut: Double = 0
    var fadeShape: FadeShape = .smooth

    enum FadeShape: String, Codable, CaseIterable, Identifiable {
        case linear, smooth, equalPower
        var id: String { rawValue }
        var title: String {
            switch self {
            case .linear: return "Linear"
            case .smooth: return "S-Curve"
            case .equalPower: return "Equal Power"
            }
        }
        /// Gain for fade progress x (0 = silent edge, 1 = full).
        func gain(_ x: Double) -> Double {
            let t = min(1, max(0, x))
            switch self {
            case .linear: return t
            case .smooth: return t * t * (3 - 2 * t)
            case .equalPower: return sin(t * .pi / 2)
            }
        }
    }

    /// Fade multiplier at composition time `t` for a clip spanning `inPoint…outPoint`.
    func fadeGain(at t: Double, inPoint: Double, outPoint: Double) -> Double {
        var g = 1.0
        if fadeIn > 0 { g *= fadeShape.gain((t - inPoint) / fadeIn) }
        if fadeOut > 0 { g *= fadeShape.gain((outPoint - t) / fadeOut) }
        return g
    }

    static let lowShelfHz = 120.0
    static let highShelfHz = 8000.0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case lowCut, highCut, lowGain, midGain, midFrequency, highGain, compressor, threshold, makeup, pitch, keepPitch, duckUnder, duckAmount, duckRelease
        case fadeIn, fadeOut, fadeShape
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lowCut = try c.decodeIfPresent(Double.self, forKey: .lowCut) ?? 0
        highCut = try c.decodeIfPresent(Double.self, forKey: .highCut) ?? 0
        lowGain = try c.decodeIfPresent(Double.self, forKey: .lowGain) ?? 0
        midGain = try c.decodeIfPresent(Double.self, forKey: .midGain) ?? 0
        midFrequency = try c.decodeIfPresent(Double.self, forKey: .midFrequency) ?? 1000
        highGain = try c.decodeIfPresent(Double.self, forKey: .highGain) ?? 0
        compressor = try c.decodeIfPresent(Bool.self, forKey: .compressor) ?? false
        threshold = try c.decodeIfPresent(Double.self, forKey: .threshold) ?? -18
        makeup = try c.decodeIfPresent(Double.self, forKey: .makeup) ?? 0
        pitch = try c.decodeIfPresent(Double.self, forKey: .pitch) ?? 0
        keepPitch = try c.decodeIfPresent(Bool.self, forKey: .keepPitch) ?? true
        duckUnder = try c.decodeIfPresent(UUID.self, forKey: .duckUnder)
        duckAmount = try c.decodeIfPresent(Double.self, forKey: .duckAmount) ?? -12
        duckRelease = try c.decodeIfPresent(Double.self, forKey: .duckRelease) ?? 0.35
        fadeIn = try c.decodeIfPresent(Double.self, forKey: .fadeIn) ?? 0
        fadeOut = try c.decodeIfPresent(Double.self, forKey: .fadeOut) ?? 0
        fadeShape = (try? c.decodeIfPresent(FadeShape.self, forKey: .fadeShape)) ?? .smooth
    }

    var needsEQ: Bool { lowCut > 0 || highCut > 0 || abs(lowGain) > 0.01 || abs(midGain) > 0.01 || abs(highGain) > 0.01 }
    /// True when the sound has to be rendered through the effect chain.
    var needsProcessing: Bool { needsEQ || compressor || abs(pitch) > 0.001 }
    /// True when the volume has to be written as a sampled envelope (fades / ducking).
    var needsEnvelope: Bool { fadeIn > 0 || fadeOut > 0 || duckUnder != nil }
    var isNeutral: Bool { !needsProcessing && keepPitch && !needsEnvelope }
}

/// Offline rendering of the EQ → pitch → compressor chain into a scratch file (cached, never on the main thread).
enum AudioFXRender {
    private static let lock = NSLock()
    private static let cache: NSCache<NSString, RetimedAudio.Source> = {
        let c = NSCache<NSString, RetimedAudio.Source>()
        c.countLimit = 6
        return c
    }()
    static let rate = 48_000.0

    static func cacheKey(fx: LayerAudioFX, source: URL) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let fxKey = (try? encoder.encode(fx)).map { String(decoding: $0, as: UTF8.self) } ?? UUID().uuidString
        let attributes = try? FileManager.default.attributesOfItem(atPath: source.path)
        return "\(fxKey)|\(source.path)|\(attributes?[.size] ?? 0)|\(attributes?[.modificationDate] ?? "")"
    }

    /// Returns a processed copy of `asset`'s sound with identical timing.
    static func process(_ asset: AVURLAsset, fx: LayerAudioFX, isCancelled: () -> Bool = { false }) throws -> RetimedAudio.Source {
        lock.lock(); defer { lock.unlock() }
        let key = cacheKey(fx: fx, source: asset.url) as NSString
        if let hit = cache.object(forKey: key), FileManager.default.fileExists(atPath: hit.asset.url.path) { return hit }
        let fm = FileManager.default
        let decoded = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-fxsrc.caf")
        defer { try? fm.removeItem(at: decoded) }
        try decode(asset, to: decoded, isCancelled: isCancelled)
        let output = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-fx.caf")
        var success = false
        defer { if !success { try? fm.removeItem(at: output) } }
        try render(decoded, to: output, fx: fx, isCancelled: isCancelled)
        success = true
        let source = RetimedAudio.Source(url: output)
        cache.setObject(source, forKey: key)
        return source
    }

    private static func decode(_ asset: AVURLAsset, to url: URL, isCancelled: () -> Bool) throws {
        guard let track = asset.tracks(withMediaType: .audio).first else { throw ExportError.writer("Audio source has no sound track.") }
        let reader = try AVAssetReader(asset: asset)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: true)!
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: format.settings)
        guard reader.canAdd(output) else { throw ExportError.writer("Cannot decode audio source.") }
        reader.add(output)
        guard reader.startReading() else { throw ExportError.writer(reader.error?.localizedDescription ?? "Cannot read audio.") }
        defer { if reader.status == .reading { reader.cancelReading() } }
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: true)
        while let sample = output.copyNextSampleBuffer() {
            if isCancelled() || Task.isCancelled { throw ExportError.cancelled }
            let frames = CMSampleBufferGetNumSamples(sample)
            guard frames > 0, let block = CMSampleBufferGetDataBuffer(sample),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
                  let bytes = buffer.mutableAudioBufferList.pointee.mBuffers.mData else { continue }
            buffer.frameLength = AVAudioFrameCount(frames)
            let size = frames * Int(format.streamDescription.pointee.mBytesPerFrame)
            guard CMBlockBufferGetDataLength(block) >= size,
                  CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: size, destination: bytes) == kCMBlockBufferNoErr else {
                throw ExportError.writer("Cannot copy decoded audio samples.")
            }
            try file.write(from: buffer)
        }
        guard reader.status == .completed else { throw ExportError.writer(reader.error?.localizedDescription ?? "Audio decoding failed.") }
    }

    /// Configures the EQ bands for `fx` (shared with tests).
    static func configure(_ eq: AVAudioUnitEQ, fx: LayerAudioFX) {
        let b = eq.bands
        guard b.count >= 5 else { return }
        b[0].filterType = .highPass; b[0].frequency = Float(max(20, fx.lowCut)); b[0].bypass = fx.lowCut <= 0
        b[1].filterType = .lowShelf; b[1].frequency = Float(LayerAudioFX.lowShelfHz); b[1].gain = Float(fx.lowGain); b[1].bypass = abs(fx.lowGain) < 0.01
        b[2].filterType = .parametric; b[2].frequency = Float(fx.midFrequency); b[2].bandwidth = 1.2; b[2].gain = Float(fx.midGain); b[2].bypass = abs(fx.midGain) < 0.01
        b[3].filterType = .highShelf; b[3].frequency = Float(LayerAudioFX.highShelfHz); b[3].gain = Float(fx.highGain); b[3].bypass = abs(fx.highGain) < 0.01
        b[4].filterType = .lowPass; b[4].frequency = Float(fx.highCut > 0 ? min(20_000, fx.highCut) : 20_000); b[4].bypass = fx.highCut <= 0
        eq.bypass = !fx.needsEQ
    }

    private static func render(_ input: URL, to output: URL, fx: LayerAudioFX, isCancelled: () -> Bool) throws {
        let file = try AVAudioFile(forReading: input)
        let format = file.processingFormat
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let eq = AVAudioUnitEQ(numberOfBands: 5)
        let pitch = AVAudioUnitTimePitch()
        let dynamics = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
        for node in [player, eq, pitch, dynamics] as [AVAudioNode] { engine.attach(node) }
        engine.connect(player, to: eq, format: format)
        engine.connect(eq, to: pitch, format: format)
        engine.connect(pitch, to: dynamics, format: format)
        engine.connect(dynamics, to: engine.mainMixerNode, format: format)
        configure(eq, fx: fx)
        pitch.pitch = Float(max(-24, min(24, fx.pitch)) * 100)
        pitch.bypass = abs(fx.pitch) < 0.001
        dynamics.bypass = !fx.compressor
        if fx.compressor {
            let unit = dynamics.audioUnit
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, Float(max(-60, min(0, fx.threshold))), 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, 4, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, 0.004, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, 0.12, 0)
        }
        // Make-up gain after the compressor (the mixer applies it, so no version-specific unit parameter is needed).
        engine.mainMixerNode.outputVolume = fx.compressor ? Float(pow(10, max(-24, min(24, fx.makeup)) / 20)) : 1
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try engine.start()
        defer { player.stop(); engine.stop() }
        player.scheduleFile(file, at: nil)
        player.play()
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            throw ExportError.writer("Cannot allocate audio buffer.")
        }
        do {
            let out = try AVAudioFile(forWriting: output, settings: engine.manualRenderingFormat.settings,
                                      commonFormat: .pcmFormatFloat32, interleaved: engine.manualRenderingFormat.isInterleaved)
            var stalls = 0
            while engine.manualRenderingSampleTime < file.length {
                if isCancelled() || Task.isCancelled { throw ExportError.cancelled }
                let remaining = file.length - engine.manualRenderingSampleTime
                let frames = AVAudioFrameCount(min(Int64(buffer.frameCapacity), remaining))
                switch try engine.renderOffline(frames, to: buffer) {
                case .success:
                    try out.write(from: buffer); stalls = 0
                case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
                    stalls += 1
                    if stalls > 1000 { throw ExportError.writer("Audio effects stopped responding.") }
                case .error:
                    throw ExportError.writer("Audio effects failed.")
                @unknown default:
                    throw ExportError.writer("Audio effects failed.")
                }
            }
        }
    }
}

/// Sidechain ducking: an envelope follower on the key layer turns the ducked layer down while it sounds.
enum AudioDucking {
    static let window = 0.05

    /// Gain per window (0…1) from the key's level per window (dBFS). Fast attack, `release` seconds to recover.
    static func gains(levelsDB: [Float], amountDB: Double, release: Double, window: Double = window, thresholdDB: Float = -42) -> [Float] {
        let duck = Float(pow(10, min(0, max(-60, amountDB)) / 20))
        let attack = Float(min(1, window / 0.02))
        let recover = Float(1 - exp(-window / max(0.01, release)))
        var g: Float = 1
        return levelsDB.map { level in
            let target: Float = level > thresholdDB ? duck : 1
            g += (target - g) * (target < g ? attack : recover)
            return g
        }
    }

    /// RMS level (dBFS) of one composition track per `window`, indexed from composition time 0.
    static func levels(of track: AVAssetTrack, in asset: AVAsset, until end: Double, isCancelled: () -> Bool) throws -> [Float] {
        let count = max(1, Int((end / window).rounded(.up)))
        var sums = [Double](repeating: 0, count: count), counts = [Int](repeating: 0, count: count)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: end, preferredTimescale: 48000))
        let out = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1,
        ])
        guard reader.canAdd(out) else { return [] }
        reader.add(out)
        guard reader.startReading() else { return [] }
        defer { if reader.status == .reading { reader.cancelReading() } }
        let per = window * 48000
        while let sb = out.copyNextSampleBuffer() {
            if isCancelled() || Task.isCancelled { throw ExportError.cancelled }
            guard let block = CMSampleBufferGetDataBuffer(sb) else { continue }
            let pts = CMSampleBufferGetPresentationTimeStamp(sb).seconds
            let length = CMBlockBufferGetDataLength(block)
            var samples = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
            guard !samples.isEmpty else { continue }
            let status = samples.withUnsafeMutableBytes { raw -> OSStatus in
                guard let base = raw.baseAddress else { return -1 }
                return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: raw.count, destination: base)
            }
            guard status == kCMBlockBufferNoErr else { continue }
            let first = (pts.isFinite ? pts : 0) * 48000
            for (k, s) in samples.enumerated() {
                let w = Int((first + Double(k)) / per)
                guard w >= 0, w < count else { continue }
                sums[w] += Double(s * s); counts[w] += 1
            }
        }
        return (0..<count).map { w in
            guard counts[w] > 0 else { return -120 }
            let rms = sqrt(sums[w] / Double(counts[w]))
            return Float(20 * log10(max(rms, 1e-6)))
        }
    }

    /// Writes the layer's volume (its own keys × fades × duck gain) as short ramps.
    static func apply(gains: [Float], layer: Layer, to params: AVMutableAudioMixInputParameters, end: Double) {
        let a = max(0, layer.inPoint), b = min(end, layer.outPoint)
        guard b > a else { return }
        func volume(_ t: Double) -> Float {
            let w = min(max(0, Int(t / window)), max(0, gains.count - 1))
            let g = gains.isEmpty ? 1 : gains[w]
            let fade = layer.audioFX?.fadeGain(at: t, inPoint: layer.inPoint, outPoint: layer.outPoint) ?? 1
            return Float(max(0, layer.volume.value(at: t)) / 100 * fade) * g
        }
        params.setVolume(volume(a), at: .zero)
        var t = a
        while t < b {
            let next = min(b, t + window)
            let range = CMTimeRange(start: CMTime(seconds: t, preferredTimescale: 48000), end: CMTime(seconds: next, preferredTimescale: 48000))
            params.setVolumeRamp(fromStartVolume: volume(t), toEndVolume: volume(next), timeRange: range)
            t = next
        }
    }
}
