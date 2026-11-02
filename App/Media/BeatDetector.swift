import Foundation
import Accelerate

/// On-device spectral onsets, tempo estimation, and a tempo-consistent dynamic-programming beat path.
enum BeatDetector {
    /// Returns beat times in seconds for mono `samples` at `sampleRate`.
    static func beats(samples: [Float], sampleRate: Double, sensitivity: Double = 0.5) -> [Double] {
        analyze(samples: samples, sampleRate: sampleRate, sensitivity: sensitivity).times
    }

    struct Analysis { var times: [Double]; var bpm: Double? }

    static func analyze(samples: [Float], sampleRate: Double, sensitivity: Double = 0.5, bpm: Double? = nil) -> Analysis {
        guard sampleRate.isFinite, sampleRate >= 1000, samples.allSatisfy(\.isFinite) else { return Analysis(times: [], bpm: nil) }
        let n = 1024, hop = 512
        guard samples.count > n * 2 else { return Analysis(times: [], bpm: nil) }
        let log2n = vDSP_Length(log2(Double(n)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return Analysis(times: [], bpm: nil) }
        defer { vDSP_destroy_fftsetup(setup) }
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        var prev = [Float](repeating: 0, count: n / 2)
        var flux: [Float] = []
        var real = [Float](repeating: 0, count: n / 2), imag = [Float](repeating: 0, count: n / 2)
        var frame = [Float](repeating: 0, count: n)
        var mags = [Float](repeating: 0, count: n / 2)
        var i = 0
        while i + n <= samples.count {
            if Task.isCancelled { return Analysis(times: [], bpm: nil) }
            vDSP_vmul(Array(samples[i..<(i + n)]), 1, window, 1, &frame, 1, vDSP_Length(n))
            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    frame.withUnsafeBufferPointer { fp in
                        fp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { vDSP_ctoz($0, 2, &split, 1, vDSP_Length(n / 2)) }
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(n / 2))
                }
            }
            // Log-compressed half-wave-rectified spectral difference, weighted toward lows (kicks/snares).
            var f: Float = 0
            for k in 1..<(n / 2) {
                let m = log1p(mags[k] * 10)
                let d = m - prev[k]
                if d > 0 { f += d * (k < 64 ? 1.6 : 1) }
                prev[k] = m
            }
            flux.append(f)
            i += hop
        }
        let hopSec = Double(hop) / sampleRate
        return track(flux: flux.map(Double.init), hopSeconds: hopSec, offset: Double(n) / 2 / sampleRate,
                     sensitivity: sensitivity, bpm: bpm)
    }

    /// Independently implemented from the onset/tempo/sequence method described by Ellis (2007).
    /// A transient is evidence for a beat, not automatically a beat itself.
    static func track(flux: [Double], hopSeconds: Double, offset: Double = 0, sensitivity: Double = 0.5, bpm manualBPM: Double? = nil) -> Analysis {
        guard flux.count >= 4, hopSeconds.isFinite, hopSeconds > 0 else { return Analysis(times: [], bpm: nil) }
        let sensitivity = sensitivity.isFinite ? min(1, max(0, sensitivity)) : 0.5
        let maximum = flux.max() ?? 0
        guard maximum.isFinite, maximum > 1e-8 else { return Analysis(times: [], bpm: nil) }
        let normalized = flux.map { max(0, $0 / maximum) }
        let minimumLag = max(2, Int((60 / 240 / hopSeconds).rounded(.up)))
        let maximumLag = min(flux.count / 2, Int((60 / 45 / hopSeconds).rounded(.down)))
        guard maximumLag >= minimumLag else { return Analysis(times: [], bpm: nil) }
        var period: Double
        if let bpm = manualBPM, bpm.isFinite, (30...300).contains(bpm) {
            period = 60 / bpm / hopSeconds
        } else {
            var best = -Double.infinity, lag = minimumLag
            for candidate in minimumLag...maximumLag {
                var cross = 0.0, left = 0.0, right = 0.0
                for i in candidate..<normalized.count {
                    let a = normalized[i], b = normalized[i - candidate]
                    cross += a * b; left += a * a; right += b * b
                }
                let correlation = cross / max(1e-12, sqrt(left * right))
                let tempo = 60 / Double(candidate) / hopSeconds
                let prior = exp(-0.5 * pow(log2(tempo / 120) / 1.1, 2))
                let score = correlation * prior
                if score > best { best = score; lag = candidate }
            }
            guard best > 0.015 else { return Analysis(times: [], bpm: nil) }
            period = Double(lag)
        }
        let minStep = max(1, Int((period * 0.5).rounded(.down)))
        let maxStep = max(minStep, Int((period * 2).rounded(.up)))
        var scores = [Double](repeating: 0, count: normalized.count)
        var previous = [Int](repeating: -1, count: normalized.count)
        let threshold = 0.025 + (1 - sensitivity) * 0.12
        for i in normalized.indices {
            var best = 0.0, predecessor = -1
            if i >= minStep {
                for step in minStep...min(maxStep, i) {
                    let candidate = scores[i - step] - 2.5 * pow(log(Double(step) / period), 2)
                    if candidate > best { best = candidate; predecessor = i - step }
                }
            }
            scores[i] = best + max(0, normalized[i] - threshold)
            previous[i] = predecessor
        }
        guard var end = scores.indices.max(by: { scores[$0] < scores[$1] }), scores[end] > 0 else { return Analysis(times: [], bpm: nil) }
        var path: [Int] = []
        while end >= 0 {
            if normalized[end] > threshold { path.append(end) }
            end = previous[end]
        }
        let times = path.reversed().map { Double($0) * hopSeconds + offset }
        return Analysis(times: times, bpm: 60 / period / hopSeconds)
    }

    static func beats(url: URL, sensitivity: Double = 0.5) -> [Double] {
        let sr = 22050.0
        return beats(samples: AudioAnalysis.samples(url: url, sampleRate: sr), sampleRate: sr, sensitivity: sensitivity)
    }
}
