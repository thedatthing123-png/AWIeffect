import SwiftUI

/// Complete premade titles: font, colors, stroke / glow / shadow (real effects, editable after) and an animation.
/// One tap turns the selected text layer into a finished design, like the premade text in Alight Motion.
struct TitleStyle: Identifiable {
    let id: String
    let name: String
    let category: String
    let font: String
    let fill: RGBA
    var size: Double = 120
    var tracking: Double = 0
    /// Effects as (effect id, settings).
    var effects: [(String, [String: ParamValue])] = []
    /// Text animation preset id (TextPresets.all).
    var animation: String?

    static func n(_ v: Double) -> ParamValue { .number(Animated(v)) }
    static func c(_ hex: UInt32) -> ParamValue { .color(Animated(RGBA(hex: hex))) }
    static func ch(_ i: Int) -> ParamValue { .choice(i) }
    static func p(_ x: Double, _ y: Double) -> ParamValue { .point(Animated(Vec2(x, y))) }

    func makeEffects() -> [EffectInstance] {
        effects.compactMap { id, values in
            guard var e = EffectRegistry.definition(id)?.makeInstance() else { return nil }
            for (k, v) in values { e.params[k] = v }
            return e
        }
    }
}

enum TitleStyles {
    typealias S = TitleStyle
    static let categories = ["Anime & Manga", "YouTube", "Neon", "Cinematic", "Retro", "Glitch", "Minimal"]

    static let all: [TitleStyle] = [
        // Anime & Manga
        S(id: "animeImpact", name: "Anime Impact", category: "Anime & Manga", font: "Futura-CondensedExtraBold", fill: RGBA(hex: 0xFFFFFF),
          effects: [("awi.border", ["color": S.c(0x000000), "width": S.n(14)]), ("awi.outerGlow", ["color": S.c(0xFF2040), "size": S.n(40), "intensity": S.n(1.6)])],
          animation: "scalePop"),
        S(id: "mangaSfx", name: "Manga SFX", category: "Anime & Manga", font: "HelveticaNeue-CondensedBlack", fill: RGBA(hex: 0x111111), tracking: -4,
          effects: [("awi.border", ["color": S.c(0xFFFFFF), "width": S.n(16)]), ("ae.dropShadow", ["distance": S.n(14), "softness": S.n(0), "opacity": S.n(90)])],
          animation: "elasticPop"),
        S(id: "shonenFire", name: "Shonen Fire", category: "Anime & Manga", font: "AvenirNext-HeavyItalic", fill: RGBA(hex: 0xFFE14D),
          effects: [("ae.gradientRamp", ["startColor": S.c(0xFFF27A), "endColor": S.c(0xFF3A00), "blend": S.n(0)]),
                    ("awi.border", ["color": S.c(0x1A0000), "width": S.n(10)]), ("awi.outerGlow", ["color": S.c(0xFF5A00), "size": S.n(55), "intensity": S.n(2)])],
          animation: "bounceIn"),
        S(id: "cursedBlue", name: "Cursed Energy", category: "Anime & Manga", font: "Futura-CondensedExtraBold", fill: RGBA(hex: 0xDDEBFF),
          effects: [("awi.neonStroke", ["color": S.c(0x3A7BFF), "width": S.n(5), "glow": S.n(40), "intensity": S.n(2)]), ("awi.rgbSplit", ["amount": S.n(6)])],
          animation: "glitch"),
        S(id: "cuteBubble", name: "Cute Bubble", category: "Anime & Manga", font: "ChalkboardSE-Bold", fill: RGBA(hex: 0xFFFFFF),
          effects: [("awi.border", ["color": S.c(0xFF7EB6), "width": S.n(18)]), ("ae.dropShadow", ["color": S.c(0xB03070), "distance": S.n(10), "softness": S.n(0), "opacity": S.n(80)])],
          animation: "jelly"),
        // YouTube
        S(id: "ytBold", name: "Thumbnail Bold", category: "YouTube", font: "Impact", fill: RGBA(hex: 0xFFE600), size: 140,
          effects: [("awi.border", ["color": S.c(0x000000), "width": S.n(18)]), ("ae.dropShadow", ["distance": S.n(18), "softness": S.n(6), "opacity": S.n(85)])],
          animation: "scalePop"),
        S(id: "subscribe", name: "Subscribe Red", category: "YouTube", font: "AvenirNext-Heavy", fill: RGBA(hex: 0xFFFFFF),
          effects: [("awi.border", ["color": S.c(0xE00000), "width": S.n(22)]), ("ae.dropShadow", ["distance": S.n(10), "softness": S.n(16), "opacity": S.n(60)])],
          animation: "bounceIn"),
        S(id: "captionPop", name: "Caption Pop", category: "YouTube", font: "AvenirNext-Bold", fill: RGBA(hex: 0xFFFFFF), size: 90,
          effects: [("awi.border", ["color": S.c(0x000000), "width": S.n(9)])], animation: "wordPop"),
        S(id: "karaoke", name: "Highlight Words", category: "YouTube", font: "AvenirNext-Heavy", fill: RGBA(hex: 0xFFFFFF), size: 90,
          effects: [("awi.border", ["color": S.c(0x000000), "width": S.n(8)])], animation: "karaoke"),
        // Neon
        S(id: "neonPink", name: "Neon Pink", category: "Neon", font: "AvenirNext-DemiBold", fill: RGBA(hex: 0xFFE3F2),
          effects: [("awi.neonStroke", ["color": S.c(0xFF2FA0), "width": S.n(4), "glow": S.n(36), "intensity": S.n(2.2)])], animation: "flicker"),
        S(id: "neonCyan", name: "Neon Cyan", category: "Neon", font: "Futura-Medium", fill: RGBA(hex: 0xE6FFFF),
          effects: [("awi.neonStroke", ["color": S.c(0x00E5FF), "width": S.n(4), "glow": S.n(40), "intensity": S.n(2.2)])], animation: "flicker"),
        S(id: "neonSign", name: "Neon Sign", category: "Neon", font: "SnellRoundhand-Black", fill: RGBA(hex: 0xFFF6C8),
          effects: [("awi.outerGlow", ["color": S.c(0xFFB020), "size": S.n(45), "intensity": S.n(2.4)])], animation: "typewriter"),
        // Cinematic
        S(id: "trailer", name: "Trailer Gold", category: "Cinematic", font: "Didot-Bold", fill: RGBA(hex: 0xF4D58D), tracking: 24,
          effects: [("ae.gradientRamp", ["startColor": S.c(0xFFF1C1), "endColor": S.c(0xA8741A), "blend": S.n(0)]),
                    ("ae.glow", ["threshold": S.n(50), "radius": S.n(30), "intensity": S.n(1.2)])],
          animation: "trackingIn"),
        S(id: "epicSilver", name: "Epic Chrome", category: "Cinematic", font: "Copperplate-Bold", fill: RGBA(hex: 0xE8EEF5), tracking: 12,
          effects: [("ae.gradientRamp", ["startColor": S.c(0xFFFFFF), "endColor": S.c(0x55606E), "blend": S.n(0)]), ("awi10.bevelAlpha", ["width": S.n(6)])],
          animation: "smoothFade"),
        S(id: "elegant", name: "Elegant Serif", category: "Cinematic", font: "Baskerville-BoldItalic", fill: RGBA(hex: 0xFFFFFF),
          effects: [("ae.dropShadow", ["distance": S.n(4), "softness": S.n(30), "opacity": S.n(70)])], animation: "fadeUp"),
        // Retro
        S(id: "synthwave", name: "Synthwave", category: "Retro", font: "AvenirNext-HeavyItalic", fill: RGBA(hex: 0xFF4FD8),
          effects: [("ae.gradientRamp", ["startColor": S.c(0x4FE9FF), "endColor": S.c(0xFF3FD0), "blend": S.n(0)]),
                    ("awi8.longShadow", ["length": S.n(40), "color": S.c(0x2A0A4A)]), ("awi.outerGlow", ["color": S.c(0xFF3FD0), "size": S.n(30)])],
          animation: "slideStagger"),
        S(id: "retro70s", name: "70s Groovy", category: "Retro", font: "Cooper-Black", fill: RGBA(hex: 0xFFB238),
          effects: [("awi.border", ["color": S.c(0xD9480F), "width": S.n(12)]), ("awi8.longShadow", ["length": S.n(30), "color": S.c(0x5C1F00)])],
          animation: "wave"),
        S(id: "typewriter", name: "Typed Note", category: "Retro", font: "AmericanTypewriter-Bold", fill: RGBA(hex: 0xF2EAD3), size: 90,
          animation: "typewriter"),
        // Glitch
        S(id: "rgbGlitch", name: "RGB Glitch", category: "Glitch", font: "Menlo-Bold", fill: RGBA(hex: 0xFFFFFF),
          effects: [("awi.rgbSplit", ["amount": S.n(14)])], animation: "glitch"),
        S(id: "hacker", name: "Hacker Green", category: "Glitch", font: "Courier-Bold", fill: RGBA(hex: 0x4DFF7A), size: 90,
          effects: [("awi.outerGlow", ["color": S.c(0x00FF55), "size": S.n(22), "intensity": S.n(1.4)])], animation: "randomPop"),
        // Minimal
        S(id: "clean", name: "Clean White", category: "Minimal", font: "HelveticaNeue-Bold", fill: RGBA(hex: 0xFFFFFF), animation: "fadeUp"),
        S(id: "wideSpaced", name: "Wide Spaced", category: "Minimal", font: "AvenirNext-UltraLight", fill: RGBA(hex: 0xFFFFFF), tracking: 40, animation: "trackingIn"),
        S(id: "softShadow", name: "Soft Shadow", category: "Minimal", font: "AvenirNext-Bold", fill: RGBA(hex: 0xFFFFFF),
          effects: [("ae.dropShadow", ["distance": S.n(8), "softness": S.n(24), "opacity": S.n(60)])], animation: "riseLines"),
    ]

    /// Effect ids a title style owns (replaced when another style is applied; the user's other effects stay).
    static let styleEffectIDs: Set<String> = Set(all.flatMap { $0.effects.map(\.0) })
}

extension TitleStyle {
    /// Applies font, color, style effects and animation to a text layer.
    func apply(to l: inout Layer, start: Double) {
        guard l.text != nil else { return }
        l.text!.fontName = UIFont(name: font, size: 12) != nil ? font : "Helvetica-Bold"
        l.text!.fill = Animated(fill)
        l.text!.colorSpans = []
        l.text!.tracking = Animated(tracking)
        if l.text!.fontSize < 40 || abs(l.text!.fontSize - 120) < 1 { l.text!.fontSize = size }
        if let a = animation, let preset = TextPresets.all.first(where: { $0.id == a }) { l.text!.animators = preset.make(start, 1.0) }
        l.effects.removeAll { TitleStyles.styleEffectIDs.contains($0.typeID) }
        l.effects += makeEffects()
    }
}

extension EditorState {
    func applyTitleStyle(_ style: TitleStyle) {
        guard let i = selectedIndex, project.layers[i].text != nil else { return }
        let start = max(project.layers[i].inPoint, currentTime)
        mutate("Title Style \(style.name)") { p in style.apply(to: &p.layers[i], start: start) }
    }
}

/// Looping live preview of a title style.
struct TitleStyleTile: View {
    let style: TitleStyle
    @State private var frames: [UIImage] = []
    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 1.0 / 12, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.06)], startPoint: .top, endPoint: .bottom))
                if !frames.isEmpty { Image(uiImage: frames[frameIndex % frames.count]).resizable().scaledToFit() }
                else { ProgressView().tint(Theme.accent) }
            }
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(style.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
        }
        .onReceive(timer) { _ in if !frames.isEmpty { frameIndex += 1 } }
        .onAppear { if frames.isEmpty { TitleStylePreviews.frames(for: style) { frames = $0 } } }
    }
}

enum TitleStylePreviews {
    private static var cache: [String: [UIImage]] = [:]
    private static let queue = DispatchQueue(label: "awi.titlepreviews", qos: .userInitiated)

    static func project(for style: TitleStyle) -> Project {
        var p = Project.new(name: "ts", width: 360, height: 136, fps: 12, duration: 1.6, background: RGBA(0.08, 0.08, 0.1))
        var l = p.makeLayer(name: "t", content: .text, size: Vec2(1, 1))
        l.text = TextData(string: "TITLE", fontSize: 64)
        style.apply(to: &l, start: 0.1)
        l.text?.fontSize = 64
        // Effect sizes were designed for 120 pt text: scale them to the preview.
        p.layers = [l]
        return p
    }

    static func frames(for style: TitleStyle, completion: @escaping ([UIImage]) -> Void) {
        if let c = cache[style.id] { completion(c); return }
        queue.async {
            guard let r = Renderer.shared else { return }
            let p = project(for: style)
            let imgs = (0..<19).compactMap { i in
                r.renderImage(project: p, time: Double(i) / 12, maxDimension: 360, mediaURL: { URL(fileURLWithPath: $0) })
            }
            DispatchQueue.main.async { cache[style.id] = imgs; completion(imgs) }
        }
    }
}
