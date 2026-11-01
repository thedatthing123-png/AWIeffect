import SwiftUI
import UIKit

/// Overlays generated on the device at the project's resolution (no licensing worries, any size, crisp).
enum OverlayKind: String, CaseIterable, Identifiable {
    case warmLeak, coolLeak, rainbowLeak, bokeh, dust, scratches, sparkles, lensDirt, frameVignette
    case speedLines, comicBurst, screentone, filmGrain, vhsLines, paper, lightRays, glitchBlocks, stars
    var id: String { rawValue }
    var title: String {
        switch self {
        case .warmLeak: return "Warm Light Leak"
        case .coolLeak: return "Cool Light Leak"
        case .rainbowLeak: return "Prism Leak"
        case .bokeh: return "Bokeh"
        case .dust: return "Film Dust"
        case .scratches: return "Scratches"
        case .sparkles: return "Sparkles"
        case .lensDirt: return "Lens Dirt"
        case .frameVignette: return "Dark Frame"
        case .speedLines: return "Speed Lines"
        case .comicBurst: return "Comic Burst"
        case .screentone: return "Screentone"
        case .filmGrain: return "Film Grain"
        case .vhsLines: return "VHS Lines"
        case .paper: return "Paper Texture"
        case .lightRays: return "Light Rays"
        case .glitchBlocks: return "Glitch Blocks"
        case .stars: return "Starfield"
        }
    }
    var section: String {
        switch self {
        case .warmLeak, .coolLeak, .rainbowLeak, .lightRays, .bokeh, .sparkles, .lensDirt, .stars: return "Light"
        case .speedLines, .comicBurst, .screentone, .paper: return "Manga"
        case .dust, .scratches, .filmGrain, .vhsLines, .glitchBlocks, .frameVignette: return "Texture & Retro"
        }
    }
    var symbol: String {
        switch self {
        case .warmLeak, .coolLeak, .rainbowLeak: return "sun.haze"
        case .bokeh: return "circle.grid.cross"
        case .dust: return "aqi.low"
        case .scratches: return "line.diagonal"
        case .sparkles: return "sparkles"
        case .lensDirt: return "camera.aperture"
        case .frameVignette: return "rectangle.inset.filled"
        case .speedLines, .comicBurst, .lightRays: return "rays"
        case .screentone: return "circle.grid.3x3"
        case .filmGrain, .paper: return "square.grid.4x3.fill"
        case .vhsLines: return "tv"
        case .glitchBlocks: return "square.split.diagonal"
        case .stars: return "star"
        }
    }
    /// How the overlay should composite.
    var blend: BlendMode {
        switch self {
        case .frameVignette, .dust, .scratches, .screentone, .filmGrain, .vhsLines, .paper, .speedLines: return .multiply
        default: return .screen
        }
    }
}

enum OverlayLibrary {
    static func render(_ kind: OverlayKind, width: Int, height: Int, seed: Int = 1) -> UIImage {
        let size = CGSize(width: width, height: height)
        var rng = SeededRandom(seed: UInt64(seed * 7919 + 17))
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let cg = ctx.cgContext
            let w = size.width, h = size.height, m = max(w, h)
            // Screen overlays start black (invisible), multiply overlays start white (invisible).
            (kind.blend == .multiply ? UIColor.white : UIColor.black).setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            func radial(_ c: CGPoint, _ r: CGFloat, _ colors: [UIColor]) {
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
                cg.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
            }
            switch kind {
            case .warmLeak, .coolLeak, .rainbowLeak:
                let palette: [UIColor] = kind == .warmLeak ? [.systemOrange, .systemRed, .systemYellow]
                    : (kind == .coolLeak ? [.systemTeal, .systemBlue, .systemPurple] : [.systemPink, .systemYellow, .systemTeal, .systemPurple])
                cg.setBlendMode(.screen)
                for k in 0..<5 {
                    let c = palette[k % palette.count]
                    let p = CGPoint(x: w * CGFloat(rng.next(0.0, 1.0)), y: k % 2 == 0 ? h * CGFloat(rng.next(-0.1, 0.3)) : h * CGFloat(rng.next(0.7, 1.1)))
                    radial(p, m * CGFloat(rng.next(0.35, 0.7)), [c.withAlphaComponent(0.9), c.withAlphaComponent(0.25), .clear])
                }
            case .bokeh:
                cg.setBlendMode(.screen)
                for _ in 0..<40 {
                    let r = m * CGFloat(rng.next(0.01, 0.06))
                    let p = CGPoint(x: w * CGFloat(rng.next(0, 1)), y: h * CGFloat(rng.next(0, 1)))
                    let col = UIColor(hue: CGFloat(rng.next(0.05, 0.15)), saturation: 0.5, brightness: 1, alpha: CGFloat(rng.next(0.15, 0.5)))
                    col.setFill(); cg.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                    UIColor.white.withAlphaComponent(0.15).setStroke(); cg.setLineWidth(max(1, r * 0.06))
                    cg.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                }
            case .dust:
                for _ in 0..<Int(w * h / 3000) {
                    let p = CGPoint(x: w * CGFloat(rng.next(0, 1)), y: h * CGFloat(rng.next(0, 1)))
                    let r = CGFloat(rng.next(0.5, 2.8))
                    UIColor(white: CGFloat(rng.next(0.0, 0.5)), alpha: CGFloat(rng.next(0.3, 0.9))).setFill()
                    cg.fillEllipse(in: CGRect(x: p.x, y: p.y, width: r, height: r * CGFloat(rng.next(0.6, 1.6))))
                }
                for _ in 0..<12 {
                    let p = CGPoint(x: w * CGFloat(rng.next(0, 1)), y: h * CGFloat(rng.next(0, 1)))
                    UIColor(white: 0.2, alpha: 0.6).setStroke(); cg.setLineWidth(1.2)
                    cg.move(to: p); cg.addCurve(to: CGPoint(x: p.x + CGFloat(rng.next(-30, 30)), y: p.y + CGFloat(rng.next(-30, 30))),
                                                control1: CGPoint(x: p.x + 10, y: p.y - 12), control2: CGPoint(x: p.x - 8, y: p.y + 14))
                    cg.strokePath()
                }
            case .scratches:
                for _ in 0..<14 {
                    let x = w * CGFloat(rng.next(0, 1))
                    UIColor(white: CGFloat(rng.next(0.1, 0.6)), alpha: CGFloat(rng.next(0.3, 0.8))).setStroke()
                    cg.setLineWidth(CGFloat(rng.next(0.6, 2.2)))
                    cg.move(to: CGPoint(x: x, y: h * CGFloat(rng.next(0, 0.4))))
                    cg.addLine(to: CGPoint(x: x + CGFloat(rng.next(-12, 12)), y: h * CGFloat(rng.next(0.6, 1))))
                    cg.strokePath()
                }
            case .sparkles:
                cg.setBlendMode(.screen)
                for _ in 0..<60 {
                    let p = CGPoint(x: w * CGFloat(rng.next(0, 1)), y: h * CGFloat(rng.next(0, 1)))
                    let r = m * CGFloat(rng.next(0.004, 0.02))
                    radial(p, r * 2.5, [UIColor.white, UIColor.white.withAlphaComponent(0.25), .clear])
                    UIColor.white.withAlphaComponent(0.8).setStroke(); cg.setLineWidth(max(1, r * 0.15))
                    cg.move(to: CGPoint(x: p.x - r * 4, y: p.y)); cg.addLine(to: CGPoint(x: p.x + r * 4, y: p.y))
                    cg.move(to: CGPoint(x: p.x, y: p.y - r * 4)); cg.addLine(to: CGPoint(x: p.x, y: p.y + r * 4))
                    cg.strokePath()
                }
            case .lensDirt:
                cg.setBlendMode(.screen)
                for _ in 0..<70 {
                    let p = CGPoint(x: w * CGFloat(rng.next(0, 1)), y: h * CGFloat(rng.next(0, 1)))
                    let r = m * CGFloat(rng.next(0.005, 0.05))
                    radial(p, r, [UIColor(white: 1, alpha: CGFloat(rng.next(0.05, 0.22))), .clear])
                }
            case .speedLines, .comicBurst:
                // Manga focus lines: wedges converging on the center, leaving a clear middle.
                let c = CGPoint(x: w / 2, y: h / 2)
                let count = kind == .speedLines ? 140 : 70
                (kind == .speedLines ? UIColor.black : UIColor.white).setFill()
                if kind == .comicBurst { cg.setBlendMode(.screen) }
                for _ in 0..<count {
                    let a = CGFloat(rng.next(0, 2 * .pi)), da = CGFloat(rng.next(0.002, kind == .speedLines ? 0.012 : 0.03))
                    let inner = m * CGFloat(rng.next(kind == .speedLines ? 0.22 : 0.08, kind == .speedLines ? 0.42 : 0.3))
                    let outer = m * 1.2
                    cg.move(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
                    cg.addLine(to: CGPoint(x: c.x + cos(a - da) * outer, y: c.y + sin(a - da) * outer))
                    cg.addLine(to: CGPoint(x: c.x + cos(a + da) * outer, y: c.y + sin(a + da) * outer))
                    cg.closePath()
                }
                cg.fillPath()
            case .screentone:
                // Halftone dots, bigger toward the bottom-right like a printed gradient.
                let step = max(6, m / 90)
                UIColor(white: 0.1, alpha: 1).setFill()
                var y: CGFloat = 0, row = 0
                while y < h + step {
                    var x: CGFloat = row % 2 == 0 ? 0 : step / 2
                    while x < w + step {
                        let k = (x / w + y / h) / 2
                        let r = step * 0.48 * max(0.05, k)
                        cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                        x += step
                    }
                    y += step * 0.866; row += 1
                }
            case .filmGrain:
                for _ in 0..<Int(w * h / 40) {
                    let p = CGPoint(x: w * CGFloat(rng.next(0, 1)), y: h * CGFloat(rng.next(0, 1)))
                    UIColor(white: CGFloat(rng.next(0.35, 0.85)), alpha: CGFloat(rng.next(0.2, 0.6))).setFill()
                    cg.fill(CGRect(x: p.x, y: p.y, width: 1.5, height: 1.5))
                }
            case .vhsLines:
                var y: CGFloat = 0
                while y < h {
                    UIColor(white: 0.55, alpha: 0.5).setFill()
                    cg.fill(CGRect(x: 0, y: y, width: w, height: max(1, h / 540)))
                    y += max(3, h / 270)
                }
                for _ in 0..<4 {
                    let by = h * CGFloat(rng.next(0, 1))
                    UIColor(white: 0.3, alpha: 0.5).setFill()
                    cg.fill(CGRect(x: 0, y: by, width: w, height: h * CGFloat(rng.next(0.004, 0.02))))
                }
            case .paper:
                UIColor(red: 0.97, green: 0.94, blue: 0.86, alpha: 1).setFill()
                cg.fill(CGRect(origin: .zero, size: size))
                for _ in 0..<Int(w * h / 90) {
                    let p = CGPoint(x: w * CGFloat(rng.next(0, 1)), y: h * CGFloat(rng.next(0, 1)))
                    UIColor(white: CGFloat(rng.next(0.7, 0.92)), alpha: CGFloat(rng.next(0.15, 0.4))).setFill()
                    cg.fill(CGRect(x: p.x, y: p.y, width: CGFloat(rng.next(1, 4)), height: 1))
                }
            case .lightRays:
                cg.setBlendMode(.screen)
                let src = CGPoint(x: w * CGFloat(rng.next(0.1, 0.4)), y: -h * 0.1)
                for _ in 0..<9 {
                    let a = CGFloat(rng.next(0.5, 1.3)), da = CGFloat(rng.next(0.02, 0.07))
                    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [UIColor(red: 1, green: 0.92, blue: 0.75, alpha: CGFloat(rng.next(0.25, 0.55))).cgColor, UIColor.clear.cgColor] as CFArray, locations: nil)!
                    cg.saveGState()
                    cg.move(to: src)
                    cg.addLine(to: CGPoint(x: src.x + cos(a - da) * m * 1.5, y: src.y + sin(a - da) * m * 1.5))
                    cg.addLine(to: CGPoint(x: src.x + cos(a + da) * m * 1.5, y: src.y + sin(a + da) * m * 1.5))
                    cg.closePath(); cg.clip()
                    cg.drawRadialGradient(g, startCenter: src, startRadius: 0, endCenter: src, endRadius: m * 1.3, options: [])
                    cg.restoreGState()
                }
            case .glitchBlocks:
                cg.setBlendMode(.screen)
                let cols: [UIColor] = [.systemPink, .cyan, .systemGreen, .white]
                for _ in 0..<26 {
                    cols[Int(rng.next(0, 3.99))].withAlphaComponent(CGFloat(rng.next(0.25, 0.7))).setFill()
                    cg.fill(CGRect(x: w * CGFloat(rng.next(-0.1, 1)), y: h * CGFloat(rng.next(0, 1)),
                                   width: w * CGFloat(rng.next(0.05, 0.5)), height: h * CGFloat(rng.next(0.004, 0.04))))
                }
            case .stars:
                cg.setBlendMode(.screen)
                for _ in 0..<Int(w * h / 2500) {
                    let p = CGPoint(x: w * CGFloat(rng.next(0, 1)), y: h * CGFloat(rng.next(0, 1)))
                    let r = CGFloat(rng.next(0.4, 1.8)) * max(1, m / 1080)
                    UIColor(white: 1, alpha: CGFloat(rng.next(0.3, 1))).setFill()
                    cg.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                }
            case .frameVignette:
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [UIColor.white.cgColor, UIColor.white.cgColor, UIColor(white: 0.05, alpha: 1).cgColor] as CFArray,
                                   locations: [0, 0.55, 1])!
                cg.drawRadialGradient(g, startCenter: CGPoint(x: w / 2, y: h / 2), startRadius: 0,
                                      endCenter: CGPoint(x: w / 2, y: h / 2), endRadius: m * 0.75, options: [.drawsAfterEndLocation])
            }
        }
    }
}

extension OverlayLibrary {
    private static var previews: [OverlayKind: UIImage] = [:]

    /// The overlay as it looks on footage: rendered small and blended over a sample frame.
    static func preview(_ kind: OverlayKind) -> UIImage {
        if let p = previews[kind] { return p }
        let size = CGSize(width: 192, height: 108)
        let over = render(kind, width: 192, height: 108, seed: 3)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2; fmt.opaque = true
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let cg = ctx.cgContext
            let colors = kind.blend == .multiply
                ? [UIColor(red: 0.95, green: 0.78, blue: 0.62, alpha: 1), UIColor(red: 0.55, green: 0.7, blue: 0.95, alpha: 1)]
                : [UIColor(red: 0.08, green: 0.07, blue: 0.16, alpha: 1), UIColor(red: 0.2, green: 0.12, blue: 0.3, alpha: 1)]
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
            cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            // A simple subject so the overlay reads as "on top of something".
            UIColor(white: kind.blend == .multiply ? 1 : 0.35, alpha: 0.9).setFill()
            cg.fillEllipse(in: CGRect(x: 76, y: 22, width: 40, height: 40))
            cg.fill(CGRect(x: 66, y: 64, width: 60, height: 44))
            over.draw(in: CGRect(origin: .zero, size: size), blendMode: kind.blend == .multiply ? .multiply : .screen, alpha: 1)
        }
        previews[kind] = img
        return img
    }
}

struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next(_ lo: Double, _ hi: Double) -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return lo + Double(state >> 11) / Double(1 << 53) * (hi - lo)
    }
}

extension EditorState {
    /// Generates an overlay at comp size and adds it on top with the right blend mode and a slow drift.
    func addOverlay(_ kind: OverlayKind) {
        let img = OverlayLibrary.render(kind, width: project.width, height: project.height, seed: Int.random(in: 1...9999))
        guard let data = img.pngData(), let name = try? store.importMedia(data: data, ext: "png", into: project.id) else { return }
        mutate("Add \(kind.title)") { p in
            var l = p.makeLayer(name: kind.title, content: .image(fileName: name, pixelWidth: p.width, pixelHeight: p.height),
                                size: Vec2(Double(p.width), Double(p.height)))
            l.blendMode = kind.blend
            l.fill = Animated(.white)
            l.tag = .amber
            // Gentle drift so the overlay feels alive.
            let c = p.center
            l.transform.scale = Animated(Vec2(110, 110))
            l.transform.position.insertKeyframe(Keyframe(time: 0, value: c + Vec2(-Double(p.width) * 0.03, 0)))
            l.transform.position.insertKeyframe(Keyframe(time: p.duration, value: c + Vec2(Double(p.width) * 0.03, 0)))
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
    }
}

struct OverlaysPanel: View {
    @ObservedObject var state: EditorState
    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "My Overlays", showKeyNav: false)
            ScrollView {
                MyLibrarySection(state: state).padding(.horizontal, 12).padding(.bottom, 8)
            }
        }
    }
}


/// A built-in overlay shown as what it actually looks like.
struct OverlayTile: View {
    let kind: OverlayKind
    let action: () -> Void
    @State private var image: UIImage?

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.raised)
                    if let image { Image(uiImage: image).resizable().scaledToFill() }
                }
                .frame(height: 62).clipShape(RoundedRectangle(cornerRadius: 9))
                Text(kind.title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .task { if image == nil { image = OverlayLibrary.preview(kind) } }
        .accessibilityLabel("Add \(kind.title)")
    }
}
