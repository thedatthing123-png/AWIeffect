import SwiftUI
import CoreGraphics

/// Serial, coalescing scope renders: at most one in flight; while it runs only the newest request is kept, and a
/// result is applied only if it is still the newest (no stale scopes after scrubbing).
final class ScopeRenderQueueOf<Result> {
    private let queue = DispatchQueue(label: "awi.scopes", qos: .userInitiated)
    private let lock = NSLock()
    private var latest = ""
    private var running = false
    private var pending: (String, () -> Result?, (Result) -> Void)?

    init() {}

    func submit(token: String, work: @escaping () -> Result?, apply: @escaping (Result) -> Void) {
        lock.lock()
        latest = token
        if running { pending = (token, work, apply); lock.unlock(); return }
        running = true
        lock.unlock()
        run(token, work, apply)
    }

    var latestToken: String { lock.lock(); defer { lock.unlock() }; return latest }

    private func run(_ token: String, _ work: @escaping () -> Result?, _ apply: @escaping (Result) -> Void) {
        queue.async { [weak self] in
            let result = work()
            DispatchQueue.main.async {
                guard let self else { return }
                if let result, self.latestToken == token { apply(result) }
                self.lock.lock()
                let next = self.pending
                self.pending = nil
                self.running = next != nil
                self.lock.unlock()
                if let next { self.run(next.0, next.1, next.2) }
            }
        }
    }
}

typealias ScopeRenderQueue = ScopeRenderQueueOf<[[Float]]>

extension ScopeRenderQueueOf where Result == [[Float]] {
    /// 64-bin RGB histogram of RGBA8 pixels.
    static func histogram(_ rgba: [UInt8]) -> [[Float]] { GradeScopes.histogram(rgba) }
}

/// Everything CC Studio's scopes show for one frame, computed off the main thread from a small render of the frame.
struct GradeScopes {
    enum Kind: Int, CaseIterable, Identifiable {
        case histogram, waveform, parade, vectorscope
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .histogram: return "Histogram"
            case .waveform: return "Waveform"
            case .parade: return "RGB Parade"
            case .vectorscope: return "Vectorscope"
            }
        }
    }

    var histogram: [[Float]] = []
    var waveform: CGImage?
    var parade: CGImage?
    var vectorscope: CGImage?
    /// The analysed frame (for the white-balance eyedropper).
    var frame: CGImage?
    var width = 0
    var height = 0
    var rgba: [UInt8] = []

    static let rows = 64

    static func histogram(_ rgba: [UInt8]) -> [[Float]] {
        var h = Array(repeating: [Float](repeating: 0, count: 64), count: 3)
        var i = 0
        while i + 3 < rgba.count {
            for c in 0..<3 { h[c][Int(rgba[i + c]) >> 2] += 1 }
            i += 4
        }
        return h
    }

    /// Waveform density: `columns` x `rows` counts of a per-pixel value (0...255) by image column, bottom = 0.
    static func waveDensity(_ rgba: [UInt8], width: Int, height: Int, columns: Int, value: (Int) -> Int) -> [Float] {
        var d = [Float](repeating: 0, count: columns * rows)
        guard width > 0, height > 0, rgba.count >= width * height * 4 else { return d }
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let col = min(columns - 1, x * columns / width)
                let row = min(rows - 1, value(i) * rows / 256)
                d[(rows - 1 - row) * columns + col] += 1
            }
        }
        return d
    }

    /// Vectorscope density (size x size): Rec. 709 Cb across, Cr up; the center is neutral.
    static func vectorDensity(_ rgba: [UInt8], size: Int) -> [Float] {
        var d = [Float](repeating: 0, count: size * size)
        var i = 0
        while i + 3 < rgba.count {
            let r = Double(rgba[i]) / 255, g = Double(rgba[i + 1]) / 255, b = Double(rgba[i + 2]) / 255
            let cb = -0.1146 * r - 0.3854 * g + 0.5 * b, cr = 0.5 * r - 0.4542 * g - 0.0458 * b
            let x = min(size - 1, max(0, Int((cb + 0.5) * Double(size)))), y = min(size - 1, max(0, Int((0.5 - cr) * Double(size))))
            d[y * size + x] += 1
            i += 4
        }
        return d
    }

    /// RGBA8 image of densities, tinted; brightness grows with the square root of the count.
    static func image(_ layers: [([Float], (Float, Float, Float))], width: Int, height: Int) -> CGImage? {
        var px = [UInt8](repeating: 0, count: width * height * 4)
        for (d, tint) in layers {
            guard d.count == width * height, let mx = d.max(), mx > 0 else { continue }
            let norm = 1 / (mx * 0.35).squareRoot()
            for i in 0..<(width * height) where d[i] > 0 {
                let v = min(1, d[i].squareRoot() * norm)
                px[i * 4] = UInt8(min(255, Float(px[i * 4]) + v * tint.0 * 255))
                px[i * 4 + 1] = UInt8(min(255, Float(px[i * 4 + 1]) + v * tint.1 * 255))
                px[i * 4 + 2] = UInt8(min(255, Float(px[i * 4 + 2]) + v * tint.2 * 255))
                px[i * 4 + 3] = 255
            }
        }
        return cgImage(px, width: width, height: height)
    }

    static func cgImage(_ px: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, px.count >= width * height * 4,
              let provider = CGDataProvider(data: Data(px) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// All scopes of an RGBA8 frame (run on the scope queue, never the main thread).
    static func analyze(width: Int, height: Int, rgba: [UInt8]) -> GradeScopes {
        var s = GradeScopes()
        s.width = width; s.height = height; s.rgba = rgba
        s.histogram = histogram(rgba)
        let cols = min(160, max(1, width))
        let luma = waveDensity(rgba, width: width, height: height, columns: cols) { i in
            (Int(rgba[i]) * 54 + Int(rgba[i + 1]) * 183 + Int(rgba[i + 2]) * 19) >> 8
        }
        s.waveform = image([(luma, (0.75, 1, 0.8))], width: cols, height: rows)
        let pc = min(64, max(1, width))
        let parts = (0..<3).map { c in waveDensity(rgba, width: width, height: height, columns: pc) { Int(rgba[$0 + c]) } }
        // Three channels side by side.
        var joined: [[Float]] = Array(repeating: [Float](repeating: 0, count: pc * 3 * rows), count: 3)
        for c in 0..<3 { for y in 0..<rows { for x in 0..<pc { joined[c][y * pc * 3 + c * pc + x] = parts[c][y * pc + x] } } }
        s.parade = image([(joined[0], (1, 0.25, 0.25)), (joined[1], (0.25, 1, 0.3)), (joined[2], (0.3, 0.45, 1))], width: pc * 3, height: rows)
        let vs = 96
        s.vectorscope = image([(vectorDensity(rgba, size: vs), (0.8, 1, 0.85))], width: vs, height: vs)
        s.frame = cgImage(rgba, width: width, height: height)
        return s
    }

    /// Average color (0...1) of a 5x5 patch around a point given in 0...1 frame coordinates.
    func sample(atX u: Double, y v: Double) -> (Double, Double, Double)? {
        guard width > 0, height > 0, rgba.count >= width * height * 4 else { return nil }
        let cx = Int(u * Double(width)), cy = Int(v * Double(height))
        var sum = (0.0, 0.0, 0.0), n = 0.0
        for y in max(0, cy - 2)...min(height - 1, max(0, cy + 2)) {
            for x in max(0, cx - 2)...min(width - 1, max(0, cx + 2)) {
                let i = (y * width + x) * 4
                guard rgba[i + 3] > 0 else { continue }
                let a = Double(rgba[i + 3]) / 255
                sum.0 += Double(rgba[i]) / 255 / a; sum.1 += Double(rgba[i + 1]) / 255 / a; sum.2 += Double(rgba[i + 2]) / 255 / a
                n += 1
            }
        }
        guard n > 0 else { return nil }
        return (sum.0 / n, sum.1 / n, sum.2 / n)
    }
}

/// The scope box at the top of CC Studio. The title is the scope picker.
struct CCScopeView: View {
    let scopes: GradeScopes?
    @Binding var kind: GradeScopes.Kind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.55))
            content.padding(.horizontal, 6).padding(.top, 30).padding(.bottom, 6)
        }
        .frame(height: kind == .vectorscope ? 190 : 132)
        .overlay(alignment: .topLeading) {
            Menu {
                ForEach(GradeScopes.Kind.allCases) { k in
                    Button { kind = k } label: { if k == kind { Label(k.title, systemImage: "checkmark") } else { Text(k.title) } }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(kind.title.uppercased()).font(.system(size: 10, weight: .bold))
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 8).frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .padding(.top, -8)
            .accessibilityLabel("Scope: \(kind.title)")
        }
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .histogram:
            Canvas { ctx, size in
                guard let h = scopes?.histogram, h.count == 3 else { return }
                let colors: [Color] = [.red, .green, .blue]
                for ch in 0..<3 {
                    guard let mx = h[ch].max(), mx > 0 else { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height))
                    for (i, v) in h[ch].enumerated() {
                        path.addLine(to: CGPoint(x: CGFloat(i) / CGFloat(h[ch].count - 1) * size.width, y: size.height - CGFloat(v / mx) * size.height))
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    ctx.fill(path, with: .color(colors[ch].opacity(0.35)))
                }
            }
        case .waveform, .parade:
            ZStack {
                if let img = kind == .waveform ? scopes?.waveform : scopes?.parade {
                    Image(decorative: img, scale: 1).resizable().interpolation(.medium)
                }
                graticule(lines: 4, parade: kind == .parade)
            }
        case .vectorscope:
            ZStack {
                if let img = scopes?.vectorscope { Image(decorative: img, scale: 1).resizable().interpolation(.medium) }
                vectorGraticule
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }

    private func graticule(lines: Int, parade: Bool) -> some View {
        Canvas { ctx, size in
            var p = Path()
            for k in 0...lines {
                let y = size.height * CGFloat(k) / CGFloat(lines)
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
            }
            if parade { for k in 1...2 { let x = size.width * CGFloat(k) / 3; p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) } }
            ctx.stroke(p, with: .color(.white.opacity(0.12)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    /// Rings, the six color targets and the skin-tone line.
    private var vectorGraticule: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2), r = min(size.width, size.height) / 2
            var p = Path()
            for f in [0.25, 0.5, 0.75, 1.0] { p.addEllipse(in: CGRect(x: c.x - r * f, y: c.y - r * f, width: 2 * r * f, height: 2 * r * f)) }
            ctx.stroke(p, with: .color(.white.opacity(0.14)), lineWidth: 0.5)
            let targets: [(Double, Double, Double, Color)] = [(0.75, 0, 0, .red), (0.75, 0.75, 0, .yellow), (0, 0.75, 0, .green),
                                                             (0, 0.75, 0.75, .cyan), (0, 0, 0.75, .blue), (0.75, 0, 0.75, .pink)]
            for (rr, gg, bb, col) in targets {
                let cb = -0.1146 * rr - 0.3854 * gg + 0.5 * bb, cr = 0.5 * rr - 0.4542 * gg - 0.0458 * bb
                let q = CGPoint(x: c.x + CGFloat(cb * 2) * r, y: c.y - CGFloat(cr * 2) * r)
                ctx.stroke(Path(CGRect(x: q.x - 4, y: q.y - 4, width: 8, height: 8)), with: .color(col.opacity(0.8)), lineWidth: 1)
            }
            // Skin tones sit on this line (about 123° in the usual vectorscope orientation).
            let a = 123.0 * .pi / 180
            var skin = Path(); skin.move(to: c); skin.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y - CGFloat(sin(a)) * r))
            ctx.stroke(skin, with: .color(.orange.opacity(0.5)), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
    }
}
