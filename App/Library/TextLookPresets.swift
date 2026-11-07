import Foundation

/// Look presets: style stacks (fill / gradient, stroke-on-stroke, shadows, glow), layer effects, a font suggestion
/// and, for 3D looks, real 3D materials. Applying a look never touches animators.
enum TextLookPresets {
    // MARK: Helpers

    static func solid(_ hex: UInt32) -> TextFillLayer { TextFillLayer(kind: .solid, colors: [RGBA(hex: hex)]) }
    static func linear(_ hexes: [UInt32], angle: Double = 90, perLetter: Bool = false) -> TextFillLayer {
        TextFillLayer(kind: .linear, colors: hexes.map { RGBA(hex: $0) }, angle: angle, space: perLetter ? .glyph : .text)
    }
    static func radial(_ hexes: [UInt32]) -> TextFillLayer { TextFillLayer(kind: .radial, colors: hexes.map { RGBA(hex: $0) }) }
    static func stroke(_ hex: UInt32, _ width: Double, _ pos: TextStrokePosition = .outside) -> TextStrokeLayer {
        TextStrokeLayer(color: RGBA(hex: hex), width: width, position: pos)
    }
    static func drop(_ hex: UInt32 = 0x000000, _ distance: Double, blur: Double, angle: Double = 135, opacity: Double = 80) -> TextShadowLayer {
        var s = TextShadowLayer(kind: .drop, color: RGBA(hex: hex), distance: distance, blur: blur)
        s.angle = Animated(angle)
        s.opacity = Animated(opacity)
        return s
    }
    static func inner(_ hex: UInt32 = 0x000000, _ distance: Double, blur: Double, angle: Double = 135, opacity: Double = 60) -> TextShadowLayer {
        var s = TextShadowLayer(kind: .inner, color: RGBA(hex: hex), distance: distance, blur: blur)
        s.angle = Animated(angle)
        s.opacity = Animated(opacity)
        return s
    }
    static func glow(_ hex: UInt32, _ radius: Double, _ intensity: Double = 100, keepHue: Bool = false) -> TextGlowLayer {
        var g = TextGlowLayer()
        g.color = Animated(RGBA(hex: hex))
        g.radius = Animated(radius)
        g.intensity = Animated(intensity)
        g.useFillColor = keepHue ? true : nil
        return g
    }
    static func stack(_ fills: [TextFillLayer], _ strokes: [TextStrokeLayer] = [], _ shadows: [TextShadowLayer] = [],
                      glow: TextGlowLayer? = nil) -> TextStyleStack {
        TextStyleStack(fills: fills, strokes: strokes, shadows: shadows, glow: glow)
    }
    static func n(_ v: Double) -> ParamValue { .number(Animated(v)) }
    static func c(_ hex: UInt32) -> ParamValue { .color(Animated(RGBA(hex: hex))) }

    static func look(_ id: String, _ name: String, _ cat: String, font: String? = nil, tracking: Double? = nil, _ style: TextStyleStack,
                     effects: [(String, [String: ParamValue])] = [], text3D: Text3DOptions? = nil) -> TextLookPreset {
        TextLookPreset(id: "look.\(id)", name: name, category: cat, font: font, style: style, effects: effects, text3D: text3D, tracking: tracking)
    }

    /// 3D text options with separate front / bevel / side materials.
    static func three(_ front: Text3DMaterial, bevel: Text3DMaterial? = nil, side: Text3DMaterial? = nil, extrusion: Double = 40,
                      bevelSize: Double = 4, profile: Text3DBevelProfile = .round) -> Text3DOptions {
        var o = Text3DOptions(material: front, extrusion: extrusion, bevelSize: bevelSize, bevelProfile: profile)
        if let bevel { o.bevel = bevel }
        if let side { o.side = side }
        return o
    }

    // MARK: Looks

    static var all: [TextLookPreset] { manga + impact + sticker + neon + glitch + lyric + speed + cinematic + minimal + threeD }

    static let manga: [TextLookPreset] = [
        look("mangaSfx", "Manga SFX Ink", "Manga/AMV", font: "HelveticaNeue-CondensedBlack",
             stack([solid(0x111111)], [stroke(0xFFFFFF, 14), stroke(0x111111, 6)], [drop(0x000000, 12, blur: 0, opacity: 90)])),
        look("shonen", "Shonen Fire", "Manga/AMV", font: "AvenirNext-HeavyItalic",
             stack([linear([0xFFF27A, 0xFF7A00, 0xFF2A00])], [stroke(0x1A0000, 8), stroke(0xFFD25C, 4)], glow: glow(0xFF5A00, 40, 160))),
        look("cursed", "Cursed Energy", "Manga/AMV", font: "Futura-CondensedExtraBold",
             stack([linear([0xDDEBFF, 0x6A8BFF], angle: 90)], [stroke(0x0A0F3A, 6)], glow: glow(0x3A7BFF, 36, 180)),
             effects: [("awi.rgbSplit", ["amount": n(4)])]),
        look("cuteBubble", "Cute Bubble", "Manga/AMV", font: "ChalkboardSE-Bold",
             stack([solid(0xFFFFFF)], [stroke(0xFF7EB6, 16)], [drop(0xB03070, 10, blur: 0)])),
        look("villain", "Villain Monologue", "Manga/AMV", font: "Didot-Bold",
             stack([linear([0xB00020, 0x2A0008])], [stroke(0x000000, 4)], [drop(0x000000, 0, blur: 24, opacity: 90)], glow: glow(0xFF0030, 18, 80))),
        look("magicalGirl", "Magical Girl", "Manga/AMV", font: "AvenirNext-HeavyItalic",
             stack([linear([0xFFB6E6, 0xC59BFF, 0x8FE3FF], angle: 0)], [stroke(0xFFFFFF, 10), stroke(0xFF5CA8, 5)], glow: glow(0xFFC6F0, 30, 130))),
        look("screentone", "Screentone Print", "Manga/AMV", font: "Futura-CondensedExtraBold",
             stack([solid(0x202020)], [stroke(0xFFFFFF, 8)]), effects: [("awi.halftone", ["size": n(6)])]),
    ]

    static let impact: [TextLookPreset] = [
        look("animeImpact", "Anime Impact", "Impact", font: "Futura-CondensedExtraBold",
             stack([solid(0xFFFFFF)], [stroke(0x000000, 14), stroke(0xFF2040, 8)], glow: glow(0xFF2040, 40, 160))),
        look("thumbBold", "Thumbnail Bold", "Impact", font: "Impact",
             stack([solid(0xFFE600)], [stroke(0x000000, 18)], [drop(0x000000, 18, blur: 6, opacity: 85)])),
        look("redAlert", "Red Alert", "Impact", font: "HelveticaNeue-CondensedBlack",
             stack([linear([0xFFFFFF, 0xFFB0B0])], [stroke(0xE00000, 12), stroke(0x000000, 6)], [drop(0x000000, 8, blur: 0)])),
        look("goldPunch", "Gold Punch", "Impact", font: "AvenirNext-Heavy",
             stack([linear([0xFFF1C1, 0xFFC94A, 0xA8741A])], [stroke(0x3A2200, 8)], [inner(0xFFFFFF, 3, blur: 2, angle: 315, opacity: 70), drop(0x000000, 10, blur: 4)])),
        look("knockout", "Knockout White", "Impact", font: "Impact",
             stack([solid(0xFFFFFF)], [stroke(0x000000, 10), stroke(0xFFFFFF, 6), stroke(0x000000, 6)])),
    ]

    static let sticker: [TextLookPreset] = [
        look("stickerWhite", "White Sticker", "Sticker", font: "AvenirNext-Heavy",
             stack([solid(0xFF3D7F)], [stroke(0xFFFFFF, 18)], [drop(0x000000, 8, blur: 10, opacity: 45)])),
        look("stickerDouble", "Double Sticker", "Sticker", font: "AvenirNext-Heavy",
             stack([solid(0x111111)], [stroke(0xFFE14D, 10), stroke(0xFFFFFF, 10), stroke(0x111111, 6)])),
        look("candy", "Candy Stack", "Sticker", font: "ChalkboardSE-Bold",
             stack([linear([0xFFFFFF, 0xFFD6EC])], [stroke(0xFF5CA8, 8), stroke(0x5CC8FF, 8), stroke(0xFFE14D, 8)])),
        look("popOutline", "Pop Outline", "Sticker", font: "Futura-CondensedExtraBold",
             stack([solid(0xFFFFFF)], [stroke(0x000000, 6, .center)], [drop(0x5CC8FF, 10, blur: 0, angle: 120, opacity: 100)])),
        look("clayBadge", "Clay Badge", "Sticker", font: "Cooper-Black",
             stack([solid(0xFFB238)], [stroke(0xD9480F, 10)], [inner(0xFFFFFF, 4, blur: 4, angle: 315, opacity: 50), drop(0x5C1F00, 12, blur: 0, opacity: 100)])),
    ]

    static let neon: [TextLookPreset] = [
        look("neonPink", "Neon Pink Tube", "Neon", font: "AvenirNext-DemiBold",
             stack([solid(0xFFE3F2)], [stroke(0xFF2FA0, 4)], glow: glow(0xFF2FA0, 34, 200))),
        look("neonCyan", "Neon Cyan Tube", "Neon", font: "Futura-Medium",
             stack([solid(0xE6FFFF)], [stroke(0x00E5FF, 4)], glow: glow(0x00E5FF, 38, 200))),
        look("neonSign", "Neon Script Sign", "Neon", font: "SnellRoundhand-Black",
             stack([solid(0xFFF6C8)], [stroke(0xFFB020, 3)], glow: glow(0xFFB020, 44, 220))),
        look("neonHollow", "Hollow Neon", "Neon", font: "AvenirNext-Bold",
             stack([solid(0x000000)], [stroke(0x7CFF4D, 5, .inside)], glow: glow(0x7CFF4D, 30, 180))),
        look("neonDuo", "Neon Duo", "Neon", font: "AvenirNext-Heavy",
             stack([linear([0xFF2FA0, 0x00E5FF], angle: 0)], [stroke(0xFFFFFF, 2)], glow: glow(0xB98CFF, 36, 180, keepHue: true))),
    ]

    static let glitch: [TextLookPreset] = [
        look("rgbGlitch", "RGB Split Mono", "Glitch", font: "Menlo-Bold",
             stack([solid(0xFFFFFF)], [], [drop(0xFF2F6E, 6, blur: 0, angle: 270, opacity: 100), drop(0x2FF6FF, 6, blur: 0, angle: 90, opacity: 100)]),
             effects: [("awi.rgbSplit", ["amount": n(10)])]),
        look("hacker", "Hacker Terminal", "Glitch", font: "Courier-Bold",
             stack([solid(0x4DFF7A)], [], glow: glow(0x00FF55, 20, 140))),
        look("corrupt", "Corrupted File", "Glitch", font: "Menlo-Bold",
             stack([linear([0xFFFFFF, 0x9B5CFF], angle: 90)], [stroke(0x000000, 4)]),
             effects: [("awi.glitch", ["amount": n(35)])]),
        look("vhsTape", "VHS Tape", "Glitch", font: "AvenirNext-Heavy",
             stack([solid(0xF2F2F2)], [], [drop(0xFF2F6E, 4, blur: 2, angle: 270, opacity: 90)]),
             effects: [("awi.vhs", ["amount": n(50)])]),
    ]

    static let lyric: [TextLookPreset] = [
        look("lyricSoft", "Soft Lyric", "Lyric", font: "AvenirNext-DemiBold",
             stack([solid(0xFFFFFF)], [], [drop(0x000000, 4, blur: 16, opacity: 70)])),
        look("lyricGlowWhite", "Glow Lyric", "Lyric", font: "AvenirNext-Medium",
             stack([solid(0xFFFFFF)], [], glow: glow(0xFFFFFF, 20, 90, keepHue: true))),
        look("lyricDream", "Dream Lyric", "Lyric", font: "Baskerville-BoldItalic",
             stack([linear([0xFFE7F3, 0xC6D8FF], angle: 0)], [], [drop(0x3A2A6A, 2, blur: 20, opacity: 70)], glow: glow(0xC6B8FF, 26, 70))),
        look("lyricCaption", "Caption Outline", "Lyric", font: "AvenirNext-Bold",
             stack([solid(0xFFFFFF)], [stroke(0x000000, 8)])),
    ]

    static let speed: [TextLookPreset] = [
        look("speedStreak", "Speed Streak", "Speed", font: "AvenirNext-HeavyItalic",
             stack([linear([0xFFFFFF, 0x9FD8FF], angle: 0)], [stroke(0x0A2A5A, 6)], [drop(0x5CC8FF, 26, blur: 0, angle: 270, opacity: 70)])),
        look("speedLines", "Speed Line Stroke", "Speed", font: "Futura-CondensedExtraBold",
             stack([solid(0x111111)], [stroke(0xFFFFFF, 6), stroke(0x111111, 4), stroke(0xFFFFFF, 3)], [drop(0x000000, 30, blur: 0, angle: 250, opacity: 60)])),
        look("velocityChrome", "Velocity Chrome", "Speed", font: "AvenirNext-HeavyItalic",
             stack([linear([0xFFFFFF, 0x8A96A8, 0xFFFFFF, 0x4A5260])], [stroke(0x0A0A0A, 4)], glow: glow(0x9FD8FF, 14, 60))),
    ]

    static let cinematic: [TextLookPreset] = [
        look("trailerGold", "Trailer Gold", "Cinematic", font: "Didot-Bold", tracking: 24,
             stack([linear([0xFFF1C1, 0xA8741A])], [], [drop(0x000000, 6, blur: 18, opacity: 70)], glow: glow(0xFFD27A, 22, 60))),
        look("epicChrome", "Epic Chrome", "Cinematic", font: "Copperplate-Bold", tracking: 12,
             stack([linear([0xFFFFFF, 0x55606E, 0xE8EEF5])], [stroke(0x1A1E24, 2)], [inner(0xFFFFFF, 2, blur: 1, angle: 315, opacity: 80)])),
        look("elegantSerif", "Elegant Serif", "Cinematic", font: "Baskerville-BoldItalic",
             stack([solid(0xFFFFFF)], [], [drop(0x000000, 4, blur: 30, opacity: 70)])),
        look("noirSteel", "Noir Steel", "Cinematic", font: "HelveticaNeue-Bold", tracking: 30,
             stack([linear([0xC8CED6, 0x50565E], angle: 90)], [], [inner(0x000000, 3, blur: 4)])),
    ]

    static let minimal: [TextLookPreset] = [
        look("clean", "Clean White", "Minimal", font: "HelveticaNeue-Bold", stack([solid(0xFFFFFF)])),
        look("wide", "Wide Spaced", "Minimal", font: "AvenirNext-UltraLight", tracking: 40, stack([solid(0xFFFFFF)])),
        look("softShadow", "Soft Shadow", "Minimal", font: "AvenirNext-Bold", stack([solid(0xFFFFFF)], [], [drop(0x000000, 8, blur: 24, opacity: 60)])),
        look("ink", "Ink Black", "Minimal", font: "AvenirNext-Heavy", stack([solid(0x111111)])),
    ]

    static let threeD: [TextLookPreset] = [
        look("3dChrome", "Chrome 3D", "3D", font: "AvenirNext-Heavy",
             stack([linear([0xFFFFFF, 0x8A96A8])]), text3D: three(.chrome)),
        look("3dGold", "Gold 3D", "3D", font: "Didot-Bold",
             stack([linear([0xFFF1C1, 0xC08A2A])]), text3D: three(.gold, extrusion: 50, bevelSize: 6)),
        look("3dGlass", "Glass 3D", "3D", font: "AvenirNext-Bold",
             stack([solid(0xDDF3FF)]), text3D: three(.glass, extrusion: 30, bevelSize: 6)),
        look("3dToon", "Toon 3D", "3D", font: "ChalkboardSE-Bold",
             stack([solid(0xFF5C73)], [stroke(0x000000, 6)]), text3D: three(.toonLook, extrusion: 36, profile: .flat)),
        look("3dNeon", "Neon 3D", "3D", font: "Futura-Medium",
             stack([solid(0x33F2FF)], [], glow: glow(0x33F2FF, 30, 160)), text3D: three(.neon, extrusion: 20, bevelSize: 2)),
        look("3dStone", "Stone 3D", "3D", font: "Copperplate-Bold",
             stack([solid(0x86807A)]), text3D: three(.stone, extrusion: 60, bevelSize: 3, profile: .angle)),
        look("3dPlastic", "Plastic 3D", "3D", font: "AvenirNext-Heavy",
             stack([solid(0x2A6BFF)]), text3D: three(.plastic, extrusion: 44, bevelSize: 8)),
        look("3dChromeGold", "Chrome Face Gold Sides", "3D", font: "AvenirNext-Heavy",
             stack([linear([0xFFFFFF, 0x9AA4B2])]), text3D: three(.chrome, bevel: .gold, side: .gold, extrusion: 55)),
        look("3dGoldStone", "Gold Bevel Stone", "3D", font: "Copperplate-Bold",
             stack([solid(0x86807A)]), text3D: three(.stone, bevel: .gold, side: .stone, extrusion: 50, bevelSize: 6, profile: .angle)),
        look("3dNeonGlass", "Neon Glass", "3D", font: "AvenirNext-Bold",
             stack([solid(0xC8FFFF)], [], glow: glow(0x00E5FF, 26, 140)), text3D: three(.glass, bevel: .neon, side: .glass, extrusion: 28)),
        look("3dToonGold", "Toon Gold Badge", "3D", font: "Cooper-Black",
             stack([solid(0xFFC94A)], [stroke(0x3A2200, 6)]), text3D: three(.toonLook, bevel: .gold, side: .gold, extrusion: 40, profile: .angle)),
        look("3dPlasticChrome", "Plastic Chrome Trim", "3D", font: "Futura-CondensedExtraBold",
             stack([solid(0xFF3D7F)]), text3D: three(.plastic, bevel: .chrome, side: .plastic, extrusion: 46, bevelSize: 6)),
        look("3dBlackChrome", "Black Chrome", "3D", font: "HelveticaNeue-CondensedBlack",
             stack([linear([0x5A5E66, 0x0A0A0C])]),
             text3D: three(Text3DMaterial(color: RGBA(0.08, 0.08, 0.1), metalness: 1, roughness: 0.12, clearcoat: 0.6), side: .chrome, extrusion: 48)),
    ]
}
