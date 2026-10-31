import Foundation
import Metal
import simd

/// Batch 16: stylize & drawing 2 — anime / manga / editing looks (anime shading, screentone, speed hatch, cartoon
/// outline, contours, edge colorize, electric edges, glow scan, line screen, cross hatch, stipple, charcoal,
/// chalkboard, blueprint, neon outline, stained glass, pixel art, low poly, ASCII art, paper, torn edges, woodcut,
/// graffiti spray, glitch color bands). All run through the single `fxDraw16` kernel.
extension EffectRegistry {
    static let batch16: [EffectDefinition] = [
        animeShading16, mangaScreentone16, mangaSpeedHatch16, cartoonOutline16, contourLines16, contourGradient16,
        edgeColorize16, electricEdges16, glowScan16, halftoneLines16, crossHatch16, stipple16, charcoal16, chalkboard16,
        blueprint16, neonOutlineArt16, stainedGlass16, pixelArt16, lowPoly16, asciiArt16, paperTexture16, tornEdges16,
        woodcut16, graffitiSpray16, glitchColorBands16,
    ]

    private static func f16(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void = { _ in }) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        ctx.gpu.run("fxDraw16", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }
    private static func n16(_ ctx: EffectContext, _ k: String, _ scale: Double = 1) -> Float { Float(ctx.num(k) * scale) }
    private static func px16(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * ctx.unit) }
    private static func col16(_ ctx: EffectContext, _ k: String) -> SIMD4<Float> { ctx.effect.color(k, ctx.time).simd }
    private static func rad16(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * .pi / 180) }
    private static func dir16(_ ctx: EffectContext, _ k: String) -> SIMD4<Float> {
        let a = ctx.num(k) * .pi / 180
        return SIMD4(Float(cos(a)), Float(sin(a)), 0, 0)
    }
    private static func pct16(_ id: String, _ name: String, _ def: Double, _ lo: Double = 0, _ hi: Double = 100) -> ParamDef {
        .number(id, name, def, lo, hi, unit: "%")
    }
    private static func px16(_ id: String, _ name: String, _ def: Double, _ lo: Double, _ hi: Double) -> ParamDef {
        .number(id, name, def, lo, hi, step: 0.1, unit: "px")
    }
    private static let ink16 = RGBA(0.05, 0.04, 0.06)
    private static let paper16 = RGBA(0.97, 0.95, 0.9)

    static let animeShading16 = EffectDefinition(
        id: "awi16.animeShading", name: "Anime Shading", category: .stylize, aeMatchNames: [],
        summary: "Flat anime cel color with a 2-3 tone light ramp, a tinted shadow color and a specular pop.",
        params: [.number("tones", "Tones", 3, 2, 4, step: 1), pct16("bias", "Light Bias", 0, -100, 100),
                 .angle("light", "Light Direction", 225), .color("shadow", "Shadow Color", RGBA(0.45, 0.35, 0.7)),
                 pct16("strength", "Strength", 100)],
        stage: .pixels { ctx in f16(ctx, 0) { p in
            p.a = SIMD4(n16(ctx, "tones"), n16(ctx, "bias", 0.005), n16(ctx, "strength", 0.01), 0)
            p.b = col16(ctx, "shadow"); p.c = dir16(ctx, "light") } })

    static let mangaScreentone16 = EffectDefinition(
        id: "awi16.mangaScreentone", name: "Manga Screentone", category: .stylize, aeMatchNames: [],
        summary: "Black-and-white manga dot tone: dot size follows darkness on a rotated screen.",
        params: [px16("size", "Dot Size", 6, 2, 30), .angle("angle", "Screen Angle", 45), pct16("tone", "Tone", 0, -100, 100),
                 .color("ink", "Ink", ink16), .color("paper", "Paper", paper16), pct16("strength", "Strength", 100)],
        stage: .pixels { ctx in f16(ctx, 1) { p in
            p.a = SIMD4(px16(ctx, "size"), rad16(ctx, "angle"), n16(ctx, "tone", 0.005), n16(ctx, "strength", 0.01))
            p.b = col16(ctx, "ink"); p.c = col16(ctx, "paper") } })

    static let mangaSpeedHatch16 = EffectDefinition(
        id: "awi16.mangaSpeedHatch", name: "Manga Speed Hatch", category: .stylize, aeMatchNames: [],
        summary: "Animated manga speed lines on paper, denser in the dark areas.",
        params: [.number("count", "Line Count", 80, 10, 300, step: 1), .angle("angle", "Direction", 0),
                 .number("speed", "Speed", 2, 0, 10, step: 0.1), .color("ink", "Ink", ink16), pct16("strength", "Strength", 100)],
        stage: .pixels { ctx in f16(ctx, 2) { p in
            p.a = SIMD4(n16(ctx, "count"), rad16(ctx, "angle"), n16(ctx, "strength", 0.01), n16(ctx, "speed"))
            p.b = col16(ctx, "ink") } })

    static let cartoonOutline16 = EffectDefinition(
        id: "awi16.cartoonOutline", name: "Cartoon Outline", category: .stylize, aeMatchNames: [],
        summary: "Thick ink lines traced from luminance edges, with a color boost on the fills.",
        params: [px16("width", "Line Width", 3, 0.5, 12), .number("threshold", "Edge Threshold", 0.15, 0, 1, step: 0.01),
                 pct16("boost", "Color Boost", 30, 0, 100), .color("ink", "Ink Color", ink16)],
        stage: .pixels { ctx in f16(ctx, 3) { p in
            p.a = SIMD4(px16(ctx, "width"), n16(ctx, "threshold"), n16(ctx, "boost", 0.01), 0); p.b = col16(ctx, "ink") } })

    static let contourLines16 = EffectDefinition(
        id: "awi16.contourLines", name: "Contour Lines", category: .stylize, aeMatchNames: [],
        summary: "Topographic iso-luminance lines drawn over a dimmed image.",
        params: [.number("levels", "Levels", 10, 2, 40, step: 1), px16("smooth", "Smoothness", 6, 1, 30),
                 px16("width", "Line Width", 1, 0.5, 5), pct16("image", "Image", 40),
                 .color("color", "Line Color", RGBA(1, 0.85, 0.4))],
        stage: .pixels { ctx in f16(ctx, 4) { p in
            p.a = SIMD4(n16(ctx, "levels"), px16(ctx, "smooth"), px16(ctx, "width"), n16(ctx, "image", 0.01))
            p.b = col16(ctx, "color") } })

    static let contourGradient16 = EffectDefinition(
        id: "awi16.contourGradient", name: "Contour Gradient", category: .stylize, aeMatchNames: [],
        summary: "Banded false-color map of smoothed luminance, like a height map.",
        params: [.number("levels", "Bands", 8, 2, 24, step: 1), px16("smooth", "Smoothness", 6, 0, 30),
                 .color("low", "Low Color", RGBA(0.1, 0.15, 0.5)), .color("high", "High Color", RGBA(1, 0.85, 0.3)),
                 pct16("strength", "Strength", 100)],
        stage: .pixels { ctx in f16(ctx, 5) { p in
            p.a = SIMD4(n16(ctx, "levels"), px16(ctx, "smooth"), n16(ctx, "strength", 0.01), 0)
            p.b = col16(ctx, "low"); p.c = col16(ctx, "high") } })

    static let edgeColorize16 = EffectDefinition(
        id: "awi16.edgeColorize", name: "Edge Colorize", category: .stylize, aeMatchNames: [],
        summary: "Edges tinted with a hue that follows their direction and cycles over time.",
        params: [px16("width", "Edge Width", 1.2, 0.5, 5), pct16("intensity", "Intensity", 150, 0, 300),
                 .number("speed", "Hue Cycle Speed", 0.5, 0, 5, step: 0.01), pct16("background", "Background", 30)],
        stage: .pixels { ctx in f16(ctx, 6) { p in
            p.a = SIMD4(px16(ctx, "width"), n16(ctx, "intensity", 0.01), n16(ctx, "speed"), n16(ctx, "background", 0.01)) } })

    static let electricEdges16 = EffectDefinition(
        id: "awi16.electricEdges", name: "Electric Edges", category: .stylize, aeMatchNames: [],
        summary: "Crackling, flickering electric lines that jitter along the edges.",
        params: [px16("jitter", "Jitter", 4, 0, 20), pct16("intensity", "Intensity", 150, 0, 300),
                 .number("speed", "Speed", 3, 0, 10, step: 0.1), pct16("background", "Background", 40),
                 .color("color", "Color", RGBA(0.4, 0.75, 1))],
        stage: .pixels { ctx in f16(ctx, 7) { p in
            p.a = SIMD4(px16(ctx, "jitter"), n16(ctx, "intensity", 0.01), n16(ctx, "speed"), n16(ctx, "background", 0.01))
            p.b = col16(ctx, "color") } })

    static let glowScan16 = EffectDefinition(
        id: "awi16.glowScan", name: "Glow Scan", category: .stylize, aeMatchNames: [],
        summary: "A bright band sweeps across the frame, lighting up the edges it passes.",
        params: [.number("speed", "Speed", 0.6, 0, 2, step: 0.01), pct16("width", "Band Width", 15, 1, 50),
                 pct16("intensity", "Intensity", 150, 0, 300), .angle("angle", "Direction", 0),
                 .color("color", "Color", RGBA(0.3, 1, 0.8))],
        stage: .pixels { ctx in f16(ctx, 8) { p in
            p.a = SIMD4(n16(ctx, "speed"), n16(ctx, "width", 0.01), n16(ctx, "intensity", 0.01), 0)
            p.b = col16(ctx, "color"); p.c = dir16(ctx, "angle") } })

    static let halftoneLines16 = EffectDefinition(
        id: "awi16.halftoneLines", name: "Halftone Lines", category: .stylize, aeMatchNames: [],
        summary: "Line-screen halftone: line thickness follows darkness.",
        params: [px16("period", "Line Spacing", 6, 2, 30), .angle("angle", "Angle", 30), pct16("contrast", "Contrast", 100, 0, 300),
                 .toggle("keep", "Keep Color", false), .color("ink", "Ink", ink16), .color("paper", "Paper", paper16)],
        stage: .pixels { ctx in f16(ctx, 9) { p in
            p.a = SIMD4(px16(ctx, "period"), rad16(ctx, "angle"), n16(ctx, "contrast", 0.01), ctx.effect.bool("keep") ? 1 : 0)
            p.b = col16(ctx, "ink"); p.c = col16(ctx, "paper") } })

    static let crossHatch16 = EffectDefinition(
        id: "awi16.crossHatch", name: "Cross Hatch", category: .stylize, aeMatchNames: [],
        summary: "Pen-and-ink hatching: up to four layers of strokes build up in darker areas.",
        params: [px16("spacing", "Spacing", 6, 2, 30), px16("width", "Line Width", 1, 0.3, 4), pct16("color", "Keep Color", 0),
                 .color("ink", "Ink", ink16), .color("paper", "Paper", paper16)],
        stage: .pixels { ctx in f16(ctx, 10) { p in
            p.a = SIMD4(px16(ctx, "spacing"), px16(ctx, "width"), n16(ctx, "color", 0.01), 0)
            p.b = col16(ctx, "ink"); p.c = col16(ctx, "paper") } })

    static let stipple16 = EffectDefinition(
        id: "awi16.stipple", name: "Stipple", category: .stylize, aeMatchNames: [],
        summary: "Stippled ink dots scattered more densely in the darks.",
        params: [px16("cell", "Dot Spacing", 4, 2, 16), pct16("density", "Density", 100, 0, 200), pct16("color", "Keep Color", 0),
                 .color("ink", "Ink", ink16), .color("paper", "Paper", paper16)],
        stage: .pixels { ctx in f16(ctx, 11) { p in
            p.a = SIMD4(px16(ctx, "cell"), n16(ctx, "density", 0.01), n16(ctx, "color", 0.01), 0)
            p.b = col16(ctx, "ink"); p.c = col16(ctx, "paper") } })

    static let charcoal16 = EffectDefinition(
        id: "awi16.charcoal", name: "Charcoal", category: .stylize, aeMatchNames: [],
        summary: "Smudgy charcoal drawing with dark edges and streaky grain on paper.",
        params: [pct16("edges", "Edge Strength", 120, 0, 300), pct16("grain", "Grain", 50), px16("smudge", "Smudge", 2, 0.5, 10),
                 .color("paper", "Paper", RGBA(0.93, 0.91, 0.86))],
        stage: .pixels { ctx in f16(ctx, 12) { p in
            p.a = SIMD4(n16(ctx, "edges", 0.01), n16(ctx, "grain", 0.01), px16(ctx, "smudge"), 0); p.b = col16(ctx, "paper") } })

    static let chalkboard16 = EffectDefinition(
        id: "awi16.chalkboard", name: "Chalkboard", category: .stylize, aeMatchNames: [],
        summary: "Chalk drawing on a board: edges and highlights in grainy chalk strokes.",
        params: [px16("width", "Edge Width", 1.2, 0.5, 5), pct16("fill", "Fill", 50), pct16("grain", "Grain", 60),
                 .color("board", "Board", RGBA(0.1, 0.2, 0.15)), .color("chalk", "Chalk", RGBA(0.95, 0.95, 0.92))],
        stage: .pixels { ctx in f16(ctx, 13) { p in
            p.a = SIMD4(px16(ctx, "width"), n16(ctx, "fill", 0.01), n16(ctx, "grain", 0.01), 0)
            p.b = col16(ctx, "board"); p.c = col16(ctx, "chalk") } })

    static let blueprint16 = EffectDefinition(
        id: "awi16.blueprint", name: "Blueprint", category: .stylize, aeMatchNames: [],
        summary: "Technical blueprint: white edge lines over a blue grid sheet.",
        params: [px16("grid", "Grid Size", 16, 5, 80), px16("width", "Line Width", 1.2, 0.5, 4), pct16("gridOpacity", "Grid Opacity", 30),
                 pct16("fill", "Ghost Fill", 15), .color("paper", "Sheet Color", RGBA(0.05, 0.22, 0.55))],
        stage: .pixels { ctx in f16(ctx, 14) { p in
            p.a = SIMD4(px16(ctx, "grid"), px16(ctx, "width"), n16(ctx, "gridOpacity", 0.01), n16(ctx, "fill", 0.01))
            p.b = col16(ctx, "paper") } })

    static let neonOutlineArt16 = EffectDefinition(
        id: "awi16.neonOutlineArt", name: "Neon Outline Art", category: .stylize, aeMatchNames: [],
        summary: "Only the edges remain, as glowing neon lines (optionally on black).",
        params: [px16("core", "Line Width", 1.5, 0.5, 4), px16("glow", "Glow Radius", 10, 2, 40), pct16("intensity", "Intensity", 150, 0, 300),
                 .color("color", "Color", RGBA(1, 0.2, 0.8)), .toggle("source", "Use Source Hue", false), .toggle("black", "Black Background", true)],
        stage: .pixels { ctx in f16(ctx, 15) { p in
            p.a = SIMD4(px16(ctx, "core"), px16(ctx, "glow"), n16(ctx, "intensity", 0.01), 0); p.b = col16(ctx, "color")
            p.i.y = ctx.effect.bool("source") ? 1 : 0; p.i.z = ctx.effect.bool("black") ? 1 : 0 } })

    static let stainedGlass16 = EffectDefinition(
        id: "awi16.stainedGlass", name: "Stained Glass", category: .stylize, aeMatchNames: [],
        summary: "Voronoi glass panes of saturated color joined by dark lead lines.",
        params: [px16("cell", "Pane Size", 16, 4, 60), px16("lead", "Lead Width", 1.5, 0.3, 6), pct16("saturation", "Saturation", 130, 0, 200),
                 pct16("light", "Light Variation", 30), .color("leadColor", "Lead Color", RGBA(0.06, 0.05, 0.05))],
        stage: .pixels { ctx in f16(ctx, 16) { p in
            p.a = SIMD4(px16(ctx, "cell"), px16(ctx, "lead"), n16(ctx, "saturation", 0.01), n16(ctx, "light", 0.01))
            p.b = col16(ctx, "leadColor") } })

    static let pixelArt16 = EffectDefinition(
        id: "awi16.pixelArt", name: "Pixel Art", category: .stylize, aeMatchNames: [],
        summary: "Chunky pixels with a reduced palette and dark sprite outlines.",
        params: [px16("size", "Pixel Size", 6, 2, 32), .number("levels", "Palette Levels", 4, 2, 8, step: 1),
                 .number("threshold", "Outline Threshold", 0.15, 0, 1, step: 0.01), .color("outline", "Outline Color", ink16)],
        stage: .pixels { ctx in f16(ctx, 17) { p in
            p.a = SIMD4(px16(ctx, "size"), n16(ctx, "levels"), n16(ctx, "threshold"), 0); p.b = col16(ctx, "outline") } })

    static let lowPoly16 = EffectDefinition(
        id: "awi16.lowPoly", name: "Low Poly", category: .stylize, aeMatchNames: [],
        summary: "Triangle facets of flat color with per-facet shading and an optional wireframe.",
        params: [px16("size", "Facet Size", 18, 4, 80), pct16("shading", "Facet Shading", 30), pct16("wire", "Wireframe", 10),
                 .color("wireColor", "Wire Color", RGBA(1, 1, 1))],
        stage: .pixels { ctx in f16(ctx, 18) { p in
            p.a = SIMD4(px16(ctx, "size"), n16(ctx, "shading", 0.01), n16(ctx, "wire", 0.01), 0); p.b = col16(ctx, "wireColor") } })

    static let asciiArt16 = EffectDefinition(
        id: "awi16.asciiArt", name: "ASCII Art", category: .stylize, aeMatchNames: [],
        summary: "Image rebuilt from procedural text-like glyphs chosen by brightness.",
        params: [px16("cell", "Cell Size", 8, 4, 24), pct16("gain", "Brightness", 100, 0, 200),
                 .color("color", "Text Color", RGBA(0.3, 1, 0.4)), .toggle("source", "Use Source Color", false)],
        stage: .pixels { ctx in f16(ctx, 19) { p in
            p.a = SIMD4(px16(ctx, "cell"), n16(ctx, "gain", 0.01), 0, 0); p.b = col16(ctx, "color")
            p.i.y = ctx.effect.bool("source") ? 1 : 0 } })

    static let paperTexture16 = EffectDefinition(
        id: "awi16.paperTexture", name: "Paper Texture", category: .stylize, aeMatchNames: [],
        summary: "Prints the image onto fibrous, grainy paper.",
        params: [pct16("amount", "Amount", 70), px16("grain", "Grain Size", 3, 1, 20), pct16("fibers", "Fibers", 40),
                 .color("tint", "Paper Tint", RGBA(0.97, 0.93, 0.84))],
        stage: .pixels { ctx in f16(ctx, 20) { p in
            p.a = SIMD4(n16(ctx, "amount", 0.01), px16(ctx, "grain"), n16(ctx, "fibers", 0.01), 0); p.b = col16(ctx, "tint") } })

    static let tornEdges16 = EffectDefinition(
        id: "awi16.tornEdges", name: "Torn Edges", category: .stylize, aeMatchNames: [],
        summary: "Rips the layer's edges like torn paper, with a pale paper fringe.",
        params: [px16("amount", "Tear Amount", 8, 0, 40), px16("roughness", "Roughness Scale", 12, 2, 60),
                 px16("fringe", "Fringe Width", 3, 0, 10), .color("fringeColor", "Fringe Color", RGBA(0.96, 0.94, 0.88))],
        margin: { e, t in e.number("amount", t) },
        stage: .pixels { ctx in f16(ctx, 21) { p in
            p.a = SIMD4(px16(ctx, "amount"), px16(ctx, "roughness"), px16(ctx, "fringe"), 0); p.b = col16(ctx, "fringeColor") } })

    static let woodcut16 = EffectDefinition(
        id: "awi16.woodcut", name: "Woodcut", category: .stylize, aeMatchNames: [],
        summary: "Carved woodblock print: warped gouge lines whose thickness follows darkness.",
        params: [px16("period", "Line Spacing", 7, 2, 30), px16("warp", "Warp", 6, 0, 30), pct16("bias", "Darkness", 0, -100, 100),
                 pct16("edges", "Edge Ink", 100), .color("ink", "Ink", RGBA(0.08, 0.05, 0.03)), .color("paper", "Paper", RGBA(0.95, 0.9, 0.78))],
        stage: .pixels { ctx in f16(ctx, 22) { p in
            p.a = SIMD4(px16(ctx, "period"), px16(ctx, "warp"), n16(ctx, "bias", 0.005), n16(ctx, "edges", 0.01))
            p.b = col16(ctx, "ink"); p.c = col16(ctx, "paper") } })

    static let graffitiSpray16 = EffectDefinition(
        id: "awi16.graffitiSpray", name: "Graffiti Spray", category: .stylize, aeMatchNames: [],
        summary: "Spray-paint look: punchy saturated posterize broken up by speckled overspray.",
        params: [.number("levels", "Levels", 4, 2, 8, step: 1), pct16("noise", "Spray Noise", 35), px16("grain", "Speckle Size", 2, 1, 8),
                 pct16("saturation", "Saturation", 150, 0, 200)],
        stage: .pixels { ctx in f16(ctx, 23) { p in
            p.a = SIMD4(n16(ctx, "levels"), n16(ctx, "noise", 0.01), px16(ctx, "grain"), n16(ctx, "saturation", 0.01)) } })

    static let glitchColorBands16 = EffectDefinition(
        id: "awi16.glitchColorBands", name: "Glitch Art Color Bands", category: .stylize, aeMatchNames: [],
        summary: "Random horizontal bands get shifted, hue-rotated and channel-swapped, re-rolling over time.",
        params: [px16("band", "Band Height", 12, 2, 60), pct16("amount", "Amount", 50), px16("shift", "Shift", 20, 0, 80),
                 .number("speed", "Speed", 6, 0, 20, step: 0.1)],
        stage: .pixels { ctx in f16(ctx, 24) { p in
            p.a = SIMD4(px16(ctx, "band"), n16(ctx, "amount", 0.01), px16(ctx, "shift"), n16(ctx, "speed")) } })
}
