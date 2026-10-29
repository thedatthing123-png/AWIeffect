import SwiftUI

/// Audio waveform drawn inside a timeline clip (peaks computed off the main thread).
struct WaveformStrip: View {
    let url: URL
    let speed: Double
    let sourceStart: Double
    let pointsPerSecond: CGFloat
    @State private var peaks: [Float] = []

    var body: some View {
        Canvas { ctx, size in
            guard !peaks.isEmpty else { return }
            let perSecond = 50.0
            var path = Path()
            var x: CGFloat = 0
            while x < size.width {
                let t = sourceStart + Double(x / pointsPerSecond) * speed
                let i = Int(t * perSecond)
                if i >= 0, i < peaks.count {
                    let h = CGFloat(peaks[i]) * size.height * 0.9
                    path.addRect(CGRect(x: x, y: (size.height - h) / 2, width: 1.5, height: max(1, h)))
                }
                x += 2
            }
            ctx.fill(path, with: .color(.white.opacity(0.55)))
        }
        .task(id: url) {
            let u = url
            let p = await Task.detached(priority: .utility) { AudioAnalysis.peaks(url: u) }.value
            peaks = p
        }
    }
}
