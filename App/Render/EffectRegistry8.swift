import Foundation
import Metal
import simd

/// Batch 8: color grading (grade wheels, HSL secondary, selective color, split toning, channel mixer, film stocks),
/// blurs (box, spin, frosted glass, tilt-shift, star / anamorphic streaks, sharpen pro) and painterly / drawing
/// styles (cel shading, oil paint, watercolor, pencil, CMYK halftone, tiles, crystallize, pointillism, long shadow).
extension EffectRegistry {
    static let batch8: [EffectDefinition] = [
        gradeWheels, hslSecondary, selectiveColor, splitToning, channelMixer, temperatureTint, bleachBypass, crossProcess,
        infrared, thermal, nightVision, sepiaPlus, vintageFade,
        celShading, oilPaint, watercolor, pencilSketch, cmykHalftone, mosaicTiles, crystallize, pointillism,
        boxBlur, spinBlur, starStreaks, lightStreaks, frostedGlass, tiltShift, sharpenPro, longShadow,
    ]

    private static func f8(_ ctx: EffectContext, _ mode: UInt32, src: MTLTexture? = nil, aux: MTLTexture? = nil,
                           _ fill: (inout EffectParams) -> Void = { _ in }) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        let s = src ?? ctx.input
        ctx.gpu.run("fxStyle8", ctx.cb, textures: [s, out, aux ?? s], params: p, grid: out)
        return out
    }
    private static func pt8(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    private static func n8(_ ctx: EffectContext, _ k: String, _ scale: Double = 1) -> Float { Float(ctx.num(k) * scale) }
    private static func px8(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * ctx.unit) }
    private static func col8(_ ctx: EffectContext, _ k: String) -> SIMD4<Float> { ctx.effect.color(k, ctx.time).simd }
    private static func pct(_ id: String, _ name: String, _ def: Double, _ lo: Double = 0, _ hi: Double = 100) -> ParamDef {
        .number(id, name, def, lo, hi, unit: "%")
    }

    // MARK: Color

    static let gradeWheels = EffectDefinition(
        id: "awi8.gradeWheels", name: "Color Grade Wheels", category: .color, aeMatchNames: [],
        summary: "Lift / gamma / gain color wheels for shadows, midtones and highlights (gray = neutral).",
        params: [.color("lift", "Lift (Shadows)", RGBA(0.35, 0.45, 0.7)), .color("gamma", "Gamma (Midtones)", RGBA(0.55, 0.5, 0.42)),
                 .color("gain", "Gain (Highlights)", RGBA(0.7, 0.55, 0.35)), pct("strength", "Strength", 100)],
        stage: .pixels { ctx in f8(ctx, 0) { p in
            p.a = col8(ctx, "lift"); p.b = col8(ctx, "gamma"); p.c = col8(ctx, "gain"); p.d.y = n8(ctx, "strength", 0.01) } })

    static let hslSecondary = EffectDefinition(
        id: "awi8.hslSecondary", name: "HSL Secondary", category: .color, aeMatchNames: [],
        summary: "Pick a hue range and shift its hue, saturation and lightness without touching the rest.",
        params: [.angle("hue", "Target Hue", 120), .number("range", "Range", 30, 0, 180, unit: "°"),
                 .number("softness", "Softness", 20, 0, 90, unit: "°"), .number("shift", "Hue Shift", 120, -180, 180, unit: "°"),
                 pct("sat", "Saturation", 0, -100, 100), pct("light", "Lightness", 0, -100, 100)],
        stage: .pixels { ctx in f8(ctx, 1) { p in
            let h = ctx.num("hue") / 360
            p.a = SIMD4(Float(h - floor(h)), n8(ctx, "range", 1.0 / 360), n8(ctx, "softness", 1.0 / 360), n8(ctx, "shift", 1.0 / 360))
            p.b = SIMD4(n8(ctx, "sat", 0.01), n8(ctx, "light", 0.01), 0, 0) } })

    static let selectiveColor = EffectDefinition(
        id: "awi8.selectiveColor", name: "Selective Color", category: .color, aeMatchNames: [],
        summary: "Photoshop-style CMYK adjustments applied to one color family.",
        params: [.choice("target", "Colors", ["Reds", "Yellows", "Greens", "Cyans", "Blues", "Magentas"], 2),
                 pct("cyan", "Cyan", 0, -100, 100), pct("magenta", "Magenta", 60, -100, 100),
                 pct("yellow", "Yellow", -40, -100, 100), pct("black", "Black", 0, -100, 100)],
        stage: .pixels { ctx in f8(ctx, 2) { p in
            p.a = SIMD4(n8(ctx, "cyan", 0.01), n8(ctx, "magenta", 0.01), n8(ctx, "yellow", 0.01), n8(ctx, "black", 0.01))
            p.b.x = Float(ctx.effect.choice("target")) / 6 } })

    static let splitToning = EffectDefinition(
        id: "awi8.splitToning", name: "Split Toning", category: .color, aeMatchNames: [],
        summary: "Tint the shadows and highlights with two different colors.",
        params: [.color("shadows", "Shadow Color", RGBA(0.1, 0.45, 0.6)), .color("highlights", "Highlight Color", RGBA(1, 0.6, 0.25)),
                 pct("balance", "Balance", 0, -100, 100), pct("amount", "Amount", 70)],
        stage: .pixels { ctx in f8(ctx, 3) { p in
            p.a = col8(ctx, "shadows"); p.b = col8(ctx, "highlights")
            p.c = SIMD4(n8(ctx, "balance", 0.01), n8(ctx, "amount", 0.01), 0, 0) } })

    static let channelMixer = EffectDefinition(
        id: "awi8.channelMixer", name: "Channel Mixer", category: .color, aeMatchNames: [],
        summary: "Rebuild each output channel from a mix of the red, green and blue inputs.",
        params: [pct("rr", "Red ← Red", 70, -200, 200), pct("rg", "Red ← Green", 30, -200, 200), pct("rb", "Red ← Blue", 0, -200, 200),
                 pct("gr", "Green ← Red", 0, -200, 200), pct("gg", "Green ← Green", 80, -200, 200), pct("gb", "Green ← Blue", 20, -200, 200),
                 pct("br", "Blue ← Red", 30, -200, 200), pct("bg", "Blue ← Green", 0, -200, 200), pct("bb", "Blue ← Blue", 90, -200, 200),
                 .toggle("mono", "Monochrome", false)],
        stage: .pixels { ctx in f8(ctx, 4) { p in
            func row(_ a: String, _ b: String, _ c: String) -> SIMD4<Float> { SIMD4(n8(ctx, a, 0.01), n8(ctx, b, 0.01), n8(ctx, c, 0.01), 0) }
            p.a = row("rr", "rg", "rb"); p.b = row("gr", "gg", "gb"); p.c = row("br", "bg", "bb")
            p.i.y = ctx.effect.bool("mono") ? 1 : 0 } })

    static let temperatureTint = EffectDefinition(
        id: "awi8.temperatureTint", name: "Temperature & Tint", category: .color, aeMatchNames: [],
        summary: "Simple white balance: warm/cool and green/magenta.",
        params: [pct("temp", "Temperature", 35, -100, 100), pct("tint", "Tint", 10, -100, 100)],
        stage: .pixels { ctx in f8(ctx, 5) { p in p.a = SIMD4(n8(ctx, "temp", 0.01), n8(ctx, "tint", 0.01), 0, 0) } })

    static let bleachBypass = EffectDefinition(
        id: "awi8.bleachBypass", name: "Bleach Bypass", category: .color, aeMatchNames: [],
        summary: "Desaturated, high-contrast silver-retention film look.",
        params: [pct("amount", "Amount", 80), pct("contrast", "Contrast", 50)],
        stage: .pixels { ctx in f8(ctx, 6) { p in p.a = SIMD4(n8(ctx, "amount", 0.01), n8(ctx, "contrast", 0.01), 0, 0) } })

    static let crossProcess = EffectDefinition(
        id: "awi8.crossProcess", name: "Cross Process", category: .color, aeMatchNames: [],
        summary: "Slide film developed in negative chemistry: punchy reds, green-yellow mids, lifted blue shadows.",
        params: [pct("amount", "Amount", 100), pct("yellow", "Yellow Highlights", 40)],
        stage: .pixels { ctx in f8(ctx, 7) { p in p.a = SIMD4(n8(ctx, "amount", 0.01), n8(ctx, "yellow", 0.01), 0, 0) } })

    static let infrared = EffectDefinition(
        id: "awi8.infrared", name: "Infrared", category: .color, aeMatchNames: [],
        summary: "Infrared film: foliage glows white, skies go dark.",
        params: [pct("amount", "Amount", 100), pct("foliage", "Foliage Glow", 80)],
        stage: .pixels { ctx in f8(ctx, 8) { p in p.a = SIMD4(n8(ctx, "amount", 0.01), n8(ctx, "foliage", 0.01), 0, 0) } })

    static let thermal = EffectDefinition(
        id: "awi8.thermal", name: "Thermal Vision", category: .color, aeMatchNames: [],
        summary: "Heat-map false color from brightness.",
        params: [pct("amount", "Amount", 100), pct("offset", "Palette Offset", 0)],
        stage: .pixels { ctx in f8(ctx, 9) { p in p.a = SIMD4(n8(ctx, "amount", 0.01), n8(ctx, "offset", 0.01), 0, 0) } })

    static let nightVision = EffectDefinition(
        id: "awi8.nightVision", name: "Night Vision", category: .color, aeMatchNames: [],
        summary: "Green intensifier-tube look with sensor noise, scanlines and vignette (animated).",
        params: [.number("gain", "Gain", 1.6, 0, 4, step: 0.01), .number("noise", "Noise", 0.2, 0, 1, step: 0.01),
                 .number("scan", "Scanlines", 0.3, 0, 1, step: 0.01), .number("vignette", "Vignette", 0.5, 0, 1, step: 0.01)],
        stage: .pixels { ctx in f8(ctx, 10) { p in p.a = SIMD4(n8(ctx, "gain"), n8(ctx, "noise"), n8(ctx, "scan"), n8(ctx, "vignette")) } })

    static let sepiaPlus = EffectDefinition(
        id: "awi8.sepiaPlus", name: "Sepia+", category: .color, aeMatchNames: [],
        summary: "Sepia toning with adjustable warmth and faded blacks.",
        params: [pct("amount", "Amount", 100), pct("warmth", "Warmth", 50), pct("fade", "Fade", 20)],
        stage: .pixels { ctx in f8(ctx, 11) { p in
            p.a = SIMD4(n8(ctx, "amount", 0.01), n8(ctx, "warmth", 0.01), n8(ctx, "fade", 0.01), 0) } })

    static let vintageFade = EffectDefinition(
        id: "awi8.vintageFade", name: "Vintage Fade", category: .color, aeMatchNames: [],
        summary: "Matte lifted blacks, muted colors and a warm cast.",
        params: [pct("fade", "Fade", 40), pct("warmth", "Warmth", 30, -100, 100), pct("desat", "Desaturate", 30)],
        stage: .pixels { ctx in f8(ctx, 28) { p in
            p.a = SIMD4(n8(ctx, "fade", 0.01), n8(ctx, "warmth", 0.01), n8(ctx, "desat", 0.01), 0) } })

    // MARK: Stylize & drawing

    static let celShading = EffectDefinition(
        id: "awi8.celShading", name: "Cel Shading", category: .stylize, aeMatchNames: [],
        summary: "Cartoon look: flat posterized color with dark ink outlines.",
        params: [.number("levels", "Color Levels", 4, 2, 12, step: 1), .number("threshold", "Edge Threshold", 0.3, 0, 2, step: 0.01),
                 .number("width", "Line Width", 1.5, 0.5, 6, step: 0.1, unit: "px"), .color("lineColor", "Line Color", RGBA(0.05, 0.04, 0.06))],
        stage: .pixels { ctx in f8(ctx, 12) { p in
            p.a = SIMD4(n8(ctx, "levels"), n8(ctx, "threshold"), px8(ctx, "width"), 0); p.b = col8(ctx, "lineColor") } })

    static let oilPaint = EffectDefinition(
        id: "awi8.oilPaint", name: "Oil Paint", category: .stylize, aeMatchNames: [],
        summary: "Kuwahara brush smoothing that keeps edges crisp, like thick paint.",
        params: [.number("radius", "Brush Size", 5, 1, 12, step: 0.1, unit: "px"), pct("strength", "Strength", 100)],
        stage: .pixels { ctx in f8(ctx, 13) { p in p.a = SIMD4(px8(ctx, "radius"), n8(ctx, "strength", 0.01), 0, 0) } })

    static let watercolor = EffectDefinition(
        id: "awi8.watercolor", name: "Watercolor", category: .stylize, aeMatchNames: [],
        summary: "Soft bleeding washes with darkened pigment edges and paper texture.",
        params: [.number("size", "Bleed", 6, 0, 40, unit: "px"), .number("edges", "Edge Darkening", 1, 0, 3, step: 0.01),
                 .number("paper", "Paper Texture", 0.4, 0, 1, step: 0.01), .number("wobble", "Wobble", 3, 0, 20, unit: "px")],
        margin: { e, t in e.number("size", t) * 1.5 + e.number("wobble", t) },
        stage: .pixels { ctx in
            let blur = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: ctx.num("size") * ctx.unit / 2)
            return f8(ctx, 14, aux: blur) { p in p.a = SIMD4(n8(ctx, "edges"), n8(ctx, "paper"), px8(ctx, "wobble"), 0) }
        })

    static let pencilSketch = EffectDefinition(
        id: "awi8.pencilSketch", name: "Pencil Sketch", category: .stylize, aeMatchNames: [],
        summary: "Cross-hatched pencil shading on paper with traced outlines.",
        params: [.number("strength", "Strength", 1, 0, 2, step: 0.01), .number("spacing", "Hatch Spacing", 5, 2, 20, step: 0.1, unit: "px"),
                 .number("edges", "Outlines", 1, 0, 3, step: 0.01),
                 .color("paper", "Paper", RGBA(0.96, 0.94, 0.89)), .color("pencil", "Pencil", RGBA(0.18, 0.18, 0.22))],
        stage: .pixels { ctx in f8(ctx, 15) { p in
            p.a = SIMD4(n8(ctx, "strength"), px8(ctx, "spacing"), n8(ctx, "edges"), 0)
            p.b = col8(ctx, "paper"); p.c = col8(ctx, "pencil") } })

    static let cmykHalftone = EffectDefinition(
        id: "awi8.cmykHalftone", name: "Comic Halftone CMYK", category: .stylize, aeMatchNames: [],
        summary: "Four rotated ink dot screens (cyan, magenta, yellow, black) like printed comics.",
        params: [.number("size", "Dot Size", 8, 3, 40, step: 0.1, unit: "px"), .angle("angle", "Screen Angle", 15), pct("mix", "Mix", 100)],
        stage: .pixels { ctx in f8(ctx, 16) { p in
            p.a = SIMD4(px8(ctx, "size"), n8(ctx, "angle", .pi / 180), n8(ctx, "mix", 0.01), 0) } })

    static let mosaicTiles = EffectDefinition(
        id: "awi8.mosaicTiles", name: "Mosaic Tiles", category: .stylize, aeMatchNames: [],
        summary: "Beveled square tiles separated by grout lines.",
        params: [.number("size", "Tile Size", 12, 4, 60, step: 0.5, unit: "px"), pct("grout", "Grout Width", 12),
                 pct("bevel", "Bevel", 40), .color("groutColor", "Grout Color", RGBA(0.85, 0.83, 0.78))],
        stage: .pixels { ctx in f8(ctx, 17) { p in
            p.a = SIMD4(px8(ctx, "size"), n8(ctx, "grout", 0.01), n8(ctx, "bevel", 0.01), 0); p.b = col8(ctx, "groutColor") } })

    static let crystallize = EffectDefinition(
        id: "awi8.crystallize", name: "Crystallize", category: .stylize, aeMatchNames: [],
        summary: "Breaks the image into flat-colored voronoi crystals.",
        params: [.number("size", "Cell Size", 14, 4, 80, step: 0.5, unit: "px"), pct("jitter", "Irregularity", 100),
                 pct("edge", "Cell Borders", 15)],
        stage: .pixels { ctx in f8(ctx, 18) { p in
            p.a = SIMD4(px8(ctx, "size"), n8(ctx, "jitter", 0.01), n8(ctx, "edge", 0.01), 0) } })

    static let pointillism = EffectDefinition(
        id: "awi8.pointillism", name: "Pointillism", category: .stylize, aeMatchNames: [],
        summary: "Painted with saturated dots of color on paper.",
        params: [.number("size", "Dot Spacing", 6, 2, 30, step: 0.1, unit: "px"), pct("jitter", "Jitter", 80),
                 pct("dot", "Dot Size", 90, 20, 150), .color("paper", "Paper", RGBA(0.95, 0.93, 0.88))],
        stage: .pixels { ctx in f8(ctx, 19) { p in
            p.a = SIMD4(px8(ctx, "size"), n8(ctx, "jitter", 0.01), n8(ctx, "dot", 0.01), 0); p.b = col8(ctx, "paper") } })

    static let longShadow = EffectDefinition(
        id: "awi8.longShadow", name: "Long Shadow", category: .stylize, aeMatchNames: [],
        summary: "Flat-design long shadow cast from the layer's shape.",
        params: [.angle("angle", "Direction", 45), .number("length", "Length", 60, 0, 300, unit: "px"),
                 pct("opacity", "Opacity", 70), pct("fade", "Fade", 50), .color("color", "Color", RGBA(0, 0, 0))],
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in f8(ctx, 29) { p in
            let a = ctx.num("angle") * .pi / 180
            p.a = SIMD4(Float(cos(a)), Float(sin(a)), px8(ctx, "length"), n8(ctx, "opacity", 0.01))
            p.b = col8(ctx, "color"); p.c.x = n8(ctx, "fade", 0.01) } })

    // MARK: Blur & light

    static let boxBlur = EffectDefinition(
        id: "awi8.boxBlur", name: "Box Blur", category: .blur, aeMatchNames: [],
        summary: "Even, flat-kernel blur.",
        params: [.number("radius", "Radius", 8, 0, 100, unit: "px"), .choice("dimensions", "Dimensions", ["Both", "Horizontal", "Vertical"], 0)],
        margin: { e, t in e.number("radius", t) },
        stage: .pixels { ctx in
            let r = px8(ctx, "radius"), dim = ctx.effect.choice("dimensions")
            var out = ctx.input
            if dim != 2 { out = f8(ctx, 20, src: out) { p in p.a = SIMD4(1, 0, r, 0) } }
            if dim != 1 { out = f8(ctx, 20, src: out) { p in p.a = SIMD4(0, 1, r, 0) } }
            return out
        })

    static let spinBlur = EffectDefinition(
        id: "awi8.spinBlur", name: "Spin Blur", category: .blur, aeMatchNames: [],
        summary: "Rotational blur around a center point.",
        params: [.point("center", "Center", Vec2(0.5, 0.5)), .number("angle", "Spin Angle", 15, 0, 90, step: 0.1, unit: "°")],
        stage: .pixels { ctx in f8(ctx, 21) { p in
            let c = pt8(ctx, "center"); p.a = SIMD4(c.x, c.y, n8(ctx, "angle", .pi / 180), 0) } })

    static let starStreaks = EffectDefinition(
        id: "awi8.starStreaks", name: "Star Streaks", category: .blur, aeMatchNames: [],
        summary: "Star-filter streaks radiating from the highlights.",
        params: [.choice("points", "Points", ["4 Points", "6 Points", "8 Points"], 0), .number("length", "Length", 40, 0, 200, unit: "px"),
                 pct("threshold", "Threshold", 60, 0, 95), .number("intensity", "Intensity", 2, 0, 6, step: 0.01),
                 .angle("rotation", "Rotation", 45), .color("tint", "Tint", RGBA(1, 0.95, 0.85))],
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in f8(ctx, 22) { p in
            p.a = SIMD4(px8(ctx, "length"), n8(ctx, "threshold", 0.01), n8(ctx, "intensity"), n8(ctx, "rotation", .pi / 180))
            p.b = col8(ctx, "tint"); p.i.y = UInt32(4 + 2 * ctx.effect.choice("points")) } })

    static let lightStreaks = EffectDefinition(
        id: "awi8.lightStreaks", name: "Light Streaks", category: .blur, aeMatchNames: [],
        summary: "Anamorphic horizontal flare streaks stretched out of the highlights.",
        params: [pct("threshold", "Threshold", 50, 0, 95), .number("length", "Length", 80, 0, 400, unit: "px"),
                 .number("intensity", "Intensity", 1.5, 0, 6, step: 0.01), .color("tint", "Tint", RGBA(0.35, 0.6, 1))],
        margin: { e, t in e.number("length", t) * 1.5 },
        stage: .pixels { ctx in
            let hi = f8(ctx, 23) { p in p.a.x = n8(ctx, "threshold", 0.01); p.b = col8(ctx, "tint") }
            let s = ctx.gpu.gaussian(ctx, input: hi, sigma: max(0.5, ctx.num("length") * ctx.unit / 2), vertical: false)
            return f8(ctx, 24, aux: s) { p in p.a.x = n8(ctx, "intensity") }
        })

    static let frostedGlass = EffectDefinition(
        id: "awi8.frostedGlass", name: "Frosted Glass", category: .blur, aeMatchNames: [],
        summary: "Diffused, grainy blur like looking through frosted glass.",
        params: [.number("amount", "Amount", 6, 0, 40, step: 0.1, unit: "px"), .number("grain", "Grain Size", 2, 1, 20, step: 0.1, unit: "px")],
        margin: { e, t in e.number("amount", t) },
        stage: .pixels { ctx in f8(ctx, 25) { p in p.a = SIMD4(px8(ctx, "amount"), px8(ctx, "grain"), 0, 0) } })

    static let tiltShift = EffectDefinition(
        id: "awi8.tiltShift", name: "Tilt-Shift", category: .blur, aeMatchNames: [],
        summary: "Miniature look: sharp band in focus, blur growing outside it, boosted color.",
        params: [.point("center", "Focus Center", Vec2(0.5, 0.5)), .angle("angle", "Band Angle", 0),
                 pct("width", "Focus Width", 15), pct("falloff", "Falloff", 20),
                 .number("blur", "Blur", 10, 0, 60, unit: "px"), pct("saturation", "Saturation Boost", 25)],
        margin: { e, t in e.number("blur", t) * 1.5 },
        stage: .pixels { ctx in
            let blur = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: ctx.num("blur") * ctx.unit / 2)
            let h = Double(ctx.height)
            return f8(ctx, 26, aux: blur) { p in
                let c = pt8(ctx, "center")
                p.a = SIMD4(c.x, c.y, Float(ctx.num("width") / 100 * h * 0.5), Float(ctx.num("falloff") / 100 * h * 0.5))
                p.b = SIMD4(n8(ctx, "angle", .pi / 180), n8(ctx, "saturation", 0.01), 0, 0)
            }
        })

    static let sharpenPro = EffectDefinition(
        id: "awi8.sharpenPro", name: "Sharpen Pro", category: .blur, aeMatchNames: [],
        summary: "Unsharp-mask sharpening with a radius and a noise threshold.",
        params: [.number("amount", "Amount", 2, 0, 5, step: 0.01), .number("radius", "Radius", 2, 0.5, 20, step: 0.1, unit: "px"),
                 pct("threshold", "Threshold", 2, 0, 50)],
        stage: .pixels { ctx in
            let blur = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: max(0.3, ctx.num("radius") * ctx.unit))
            return f8(ctx, 27, aux: blur) { p in p.a = SIMD4(n8(ctx, "amount"), n8(ctx, "threshold", 0.01), 0, 0) }
        })
}
