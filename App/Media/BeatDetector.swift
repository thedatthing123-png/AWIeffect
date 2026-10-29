import Foundation
import Accelerate

/// On-device beat/onset detection: spectral flux with an adaptive threshold, then tempo-aware peak picking.
enum BeatDetector {
    /// Returns beat times in seconds for mono `samples` at `sampleRate`.
    static func beats(samples: [Float], sampleRate: Double, sensitivity: Double = 0.5) -> [Double] {
        let n = 1024, hop = 512
        guard samples.count > n * 2 else { return [] }
        let log2n = vDSP_Length(log2(Double(n)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
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
        // Adaptive threshold: local mean + k * local std over ~0.5s.
        let win = max(4, Int(0.5 / hopSec))
        let k = Float(1.6 - sensitivity)
        var onsets: [Double] = []
        let minGap = 0.18
        for j in 0..<flux.count {
            let lo = max(0, j - win), hi = min(flux.count, j + win)
            let slice = Array(flux[lo..<hi])
            var mean: Float = 0, std: Float = 0
            vDSP_normalize(slice, 1, nil, 1, &mean, &std, vDSP_Length(slice.count))
            let isPeak = (j == 0 || flux[j] > flux[j - 1]) && (j == flux.count - 1 || flux[j] >= flux[j + 1])
            if isPeak, flux[j] > mean + k * std, flux[j] > 0.01 {
                let t = Double(j) * hopSec + Double(n) / 2 / sampleRate
                if let last = onsets.last, t - last < minGap { continue }
                onsets.append(t)
            }
        }
        return onsets
    }

    static func beats(url: URL, sensitivity: Double = 0.5) -> [Double] {
        let sr = 22050.0
        return beats(samples: AudioAnalysis.samples(url: url, sampleRate: sr), sampleRate: sr, sensitivity: sensitivity)
    }
}
