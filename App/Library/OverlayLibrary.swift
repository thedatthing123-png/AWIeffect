import SwiftUI
import UIKit

/// Overlays generated on the device at the project's resolution (no licensing worries, any size, crisp).
enum OverlayKind: String, CaseIterable, Identifiable {
    case warmLeak, coolLeak, rainbowLeak, bokeh, dust, scratches, sparkles, lensDirt, frameVignette
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
        }
    }
    /// How the overlay should composite.
    var blend: BlendMode { self == .frameVignette || self == .dust || self == .scratches ? .multiply : .screen }
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
            PanelHeader(state: state, title: "Overlays", showKeyNav: false)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(OverlayKind.allCases) { k in ToolTile(icon: k.symbol, title: k.title) { state.addOverlay(k) } }
                }
                .padding(.horizontal, 12)
                Text("Generated at your project size. Each tap makes a new random variation.").font(.caption).foregroundStyle(Theme.textDim).padding(10)
            }
        }
    }
}
