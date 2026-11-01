import Foundation
import Metal

/// Batch 2: distortions, stylize, glitch, color, and the AWI plugin set (our own versions of pro plugins).
extension EffectRegistry {
    static let batch2: [EffectDefinition] = [
        turbulentDisplace, waveWarp, bulge, twirl, opticsCompensation, mirror, polarCoordinates, motionTile, offset,
        posterize, threshold, findEdges, mosaic, halftone, crt, curves, looks, grain,
        deepGlow, saber, shine, glitch, vhs, pixelSort, mangaFX, impactFrame, particles,
    ]

    private static func run(_ kernel: String, _ ctx: EffectContext, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        ctx.gpu.run(kernel, ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }

    private static func f(_ v: Double) -> Float { Float(v) }

    // MARK: Distort

    static let turbulentDisplace = EffectDefinition(
        id: "ae.turbulentDisplace", name: "Turbulent Displace", category: .distort, aeMatchNames: ["ADBE Turbulent Displace"],
        summary: "Organic, smoky warping driven by fractal noise.",
        params: [.number("amount", "Amount", 50, 0, 1000, ae: 2), .number("size", "Size", 100, 2, 1000, ae: 3),
                 .number("complexity", "Complexity", 1, 1, 8, step: 1, ae: 5), .number("evolution", "Evolution", 0, -3600, 3600, unit: "°", ae: 6)],
        margin: { e, t in e.number("amount", t) },
        stage: .pixels { ctx in run("fxWarp", ctx) { p in
            p.a = SIMD4(f(ctx.num("amount") * ctx.unit), f(ctx.num("size") * ctx.unit), f(ctx.num("complexity")), f(ctx.num("evolution") / 360))
            p.i.x = 0 } })

    static let waveWarp = EffectDefinition(
        id: "ae.waveWarp", name: "Wave Warp", category: .distort, aeMatchNames: ["ADBE Wave Warp"],
        summary: "Rolling waves across the layer.",
        params: [.choice("type", "Wave Type", ["Sine", "Square", "Triangle", "Sawtooth"], 0, ae: 1),
                 .number("height", "Wave Height", 10, -500, 500, ae: 2), .number("width", "Wave Width", 40, 1, 1000, ae: 3),
                 .angle("direction", "Direction", 90, ae: 4), .number("speed", "Wave Speed", 1, -20, 20, step: 0.1, ae: 5)],
        margin: { e, t in abs(e.number("height", t)) },
        stage: .pixels { ctx in run("fxWarp", ctx) { p in
            p.a = SIMD4(f(ctx.num("height") * ctx.unit), f(ctx.num("width") * ctx.unit), f(ctx.num("direction")), f(ctx.time * ctx.num("speed") * 2 * .pi))
            p.i = SIMD4(1, UInt32(ctx.effect.choice("type")), 0, 0) } })

    static let bulge = EffectDefinition(
        id: "ae.bulge", name: "Bulge", category: .distort, aeMatchNames: ["ADBE Bulge"],
        summary: "Lens-like swelling (or pinching) around a point.",
        params: [.point("center", "Bulge Center", Vec2(0.5, 0.5), ae: 3), .number("radius", "Radius", 120, 1, 2000, ae: 1),
                 .number("height", "Bulge Height", 1, -4, 4, step: 0.01, ae: 4)],
        stage: .pixels { ctx in run("fxWarp", ctx) { p in
            let c = ctx.effect.point("center", ctx.time)
            p.a = SIMD4(f(c.x * Double(ctx.width)), f(c.y * Double(ctx.height)), f(ctx.num("radius") * ctx.unit), f(ctx.num("height")))
            p.i.x = 2 } })

    static let twirl = EffectDefinition(
        id: "ae.twirl", name: "Twirl", category: .distort, aeMatchNames: ["ADBE Twirl"],
        summary: "Spins pixels around a center, stronger inside.",
        params: [.angle("angle", "Angle", 180, ae: 1), .number("radius", "Twirl Radius", 30, 1, 100, unit: "%", ae: 2),
                 .point("center", "Twirl Center", Vec2(0.5, 0.5), ae: 3)],
        stage: .pixels { ctx in run("fxWarp", ctx) { p in
            let c = ctx.effect.point("center", ctx.time)
            p.a = SIMD4(f(c.x * Double(ctx.width)), f(c.y * Double(ctx.height)),
                        f(ctx.num("radius") / 100 * Double(max(ctx.width, ctx.height))), f(ctx.num("angle")))
            p.i.x = 3 } })

    static let opticsCompensation = EffectDefinition(
        id: "ae.opticsCompensation", name: "Optics Compensation", category: .distort, aeMatchNames: ["ADBE Optics Compensation"],
        summary: "Wide-angle lens bend (or remove it) — the classic edit zoom look.",
        params: [.number("fov", "Field of View", 60, 0, 179, ae: 1), .toggle("reverse", "Reverse Lens Distortion", false, ae: 2)],
        stage: .pixels { ctx in run("fxWarp", ctx) { p in
            p.a = SIMD4(f(ctx.num("fov")), 0, 0, 0); p.i = SIMD4(4, ctx.effect.bool("reverse") ? 1 : 0, 0, 0) } })

    static let mirror = EffectDefinition(
        id: "ae.mirror", name: "Mirror", category: .distort, aeMatchNames: ["ADBE Mirror"],
        summary: "Reflects one side across a line.",
        params: [.point("center", "Reflection Center", Vec2(0.5, 0.5), ae: 1), .angle("angle", "Reflection Angle", 0, ae: 2)],
        stage: .pixels { ctx in run("fxWarp", ctx) { p in
            let c = ctx.effect.point("center", ctx.time)
            p.a = SIMD4(f(c.x * Double(ctx.width)), f(c.y * Double(ctx.height)), f(ctx.num("angle")), 0); p.i.x = 5 } })

    static let polarCoordinates = EffectDefinition(
        id: "ae.polarCoordinates", name: "Polar Coordinates", category: .distort, aeMatchNames: ["ADBE Polar Coordinates"],
        summary: "Wraps the image into a circle (or unwraps it).",
        params: [.number("interp", "Interpolation", 100, 0, 100, unit: "%", ae: 1),
                 .choice("type", "Type of Conversion", ["Rect to Polar", "Polar to Rect"], 0, ae: 2)],
        stage: .pixels { ctx in run("fxWarp", ctx) { p in
            p.a = SIMD4(f(ctx.num("interp") / 100), 0, 0, 0); p.i.x = ctx.effect.choice("type") == 0 ? 6 : 7 } })

    static let motionTile = EffectDefinition(
        id: "ae.motionTile", name: "Motion Tile", category: .distort, aeMatchNames: ["ADBE Tile"],
        summary: "Repeats the layer in a grid — great with shakes so edges never show.",
        params: [.point("center", "Tile Center", Vec2(0.5, 0.5), ae: 1), .number("tileW", "Tile Width", 100, 1, 1000, unit: "%", ae: 2),
                 .number("tileH", "Tile Height", 100, 1, 1000, unit: "%", ae: 3), .toggle("mirror", "Mirror Edges", true, ae: 6)],
        stage: .pixels { ctx in run("fxWarp", ctx) { p in
            let c = ctx.effect.point("center", ctx.time)
            p.a = SIMD4(f(c.x * Double(ctx.width)), f(c.y * Double(ctx.height)), f(ctx.num("tileW") / 100), f(ctx.num("tileH") / 100))
            p.i = SIMD4(8, ctx.effect.bool("mirror") ? 1 : 0, 0, 0) } })

    static let offset = EffectDefinition(
        id: "ae.offset", name: "Offset", category: .distort, aeMatchNames: ["ADBE Offset"],
        summary: "Scrolls the image with wrap-around.",
        params: [.point("shift", "Shift Center To", Vec2(0.5, 0.5), ae: 1)],
        stage: .pixels { ctx in run("fxWarp", ctx) { p in
            let s = ctx.effect.point("shift", ctx.time)
            p.a = SIMD4(f((s.x - 0.5) * Double(ctx.width)), f((s.y - 0.5) * Double(ctx.height)), 0, 0); p.i.x = 9 } })

    // MARK: Stylize

    private static func stylize(_ mode: UInt32, _ ctx: EffectContext, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        run("fxStylize", ctx) { p in fill(&p); p.i.x = mode }
    }

    static let posterize = EffectDefinition(
        id: "ae.posterize", name: "Posterize", category: .stylize, aeMatchNames: ["ADBE Posterize"],
        summary: "Reduces colors to a few levels.", params: [.number("levels", "Level", 6, 2, 64, step: 1, ae: 1)],
        stage: .pixels { ctx in stylize(0, ctx) { $0.a.x = f(ctx.num("levels")) } })

    static let threshold = EffectDefinition(
        id: "ae.threshold", name: "Threshold", category: .stylize, aeMatchNames: ["ADBE Threshold2"],
        summary: "Pure black and white at a cutoff.", params: [.number("level", "Level", 128, 0, 255, step: 1, ae: 1)],
        stage: .pixels { ctx in stylize(1, ctx) { $0.a.x = f(ctx.num("level") / 255) } })

    static let findEdges = EffectDefinition(
        id: "ae.findEdges", name: "Find Edges", category: .stylize, aeMatchNames: ["ADBE Find Edges"],
        summary: "Line-art look from edges.",
        params: [.toggle("invert", "Invert", false, ae: 1), .number("blend", "Blend With Original", 0, 0, 100, unit: "%", ae: 2)],
        stage: .pixels { ctx in stylize(2, ctx) { p in p.a.y = f(ctx.num("blend") / 100); p.i.y = ctx.effect.bool("invert") ? 1 : 0 } })

    static let mosaic = EffectDefinition(
        id: "ae.mosaic", name: "Mosaic", category: .stylize, aeMatchNames: ["ADBE Mosaic"],
        summary: "Pixelates into blocks.",
        params: [.number("h", "Horizontal Blocks", 20, 1, 400, step: 1, ae: 1), .number("v", "Vertical Blocks", 20, 1, 400, step: 1, ae: 2)],
        stage: .pixels { ctx in stylize(3, ctx) { p in p.a = SIMD4(f(ctx.num("h")), f(ctx.num("v")), 0, 0) } })

    static let halftone = EffectDefinition(
        id: "awi.halftone", name: "Halftone", category: .stylize, aeMatchNames: ["CC Ball Action"],
        summary: "Print-style dots (mono or color) — manga & comic looks.",
        params: [.number("size", "Dot Size", 8, 2, 80, unit: "px"), .angle("angle", "Angle", 45), .toggle("color", "Color Dots", false)],
        stage: .pixels { ctx in stylize(4, ctx) { p in p.a = SIMD4(f(ctx.num("size") * ctx.unit), f(ctx.num("angle")), 0, 0); p.i.y = ctx.effect.bool("color") ? 1 : 0 } })

    static let crt = EffectDefinition(
        id: "awi.crt", name: "CRT / Scanlines", category: .stylize, aeMatchNames: [],
        summary: "Old monitor: scanlines, RGB grille and screen curve.",
        params: [.number("strength", "Strength", 60, 0, 100, unit: "%"), .number("line", "Line Size", 3, 1, 20, unit: "px"),
                 .number("curve", "Curvature", 30, 0, 100, unit: "%")],
        stage: .pixels { ctx in stylize(5, ctx) { p in p.a = SIMD4(f(ctx.num("strength") / 100), f(ctx.num("line") * ctx.unit), f(ctx.num("curve") / 100), 0) } })

    static let mangaFX = EffectDefinition(
        id: "awi.manga", name: "AWI Manga FX", category: .stylize, aeMatchNames: [],
        summary: "Turns footage into manga: ink, screentone and speed lines.",
        params: [.number("tone", "Screentone Size", 6, 2, 40, unit: "px"), .number("ink", "Ink Threshold", 25, 0, 100, unit: "%"),
                 .number("lines", "Speed Lines", 40, 0, 100, unit: "%"), .number("seed", "Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in stylize(7, ctx) { p in
            p.a = SIMD4(f(ctx.num("tone") * ctx.unit), f(ctx.num("ink") / 100), f(ctx.num("lines") / 100), f(ctx.num("seed"))) } })

    static let impactFrame = EffectDefinition(
        id: "awi.impactFrame", name: "AWI Impact Frame", category: .stylize, aeMatchNames: [],
        summary: "The anime hit frame: inverted ink + radial streaks. Keyframe it for 2-3 frames.",
        params: [.number("threshold", "Ink Threshold", 45, 0, 100, unit: "%"), .number("lines", "Streak Density", 20, 1, 100),
                 .point("center", "Impact Point", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in stylize(6, ctx) { p in
            let c = ctx.effect.point("center", ctx.time)
            p.a = SIMD4(f(ctx.num("threshold") / 100), f(ctx.num("lines")), f(c.x * Double(ctx.width)), f(c.y * Double(ctx.height))) } })

    // MARK: Color

    static let curves = EffectDefinition(
        id: "ae.curves", name: "Curves", category: .color, aeMatchNames: ["ADBE CurvesCustom"],
        summary: "Five-point tone curve (blacks, shadows, mids, highlights, whites) per channel.",
        params: [.choice("channel", "Channel", ["RGB", "Red", "Green", "Blue"], 0),
                 .number("black", "Blacks", 0, -50, 50, unit: "%"), .number("shadows", "Shadows", 25, 0, 100, unit: "%"),
                 .number("mids", "Midtones", 50, 0, 100, unit: "%"), .number("highs", "Highlights", 75, 0, 100, unit: "%"),
                 .number("white", "Whites", 100, 50, 150, unit: "%")],
        stage: .pixels { ctx in run("fxColor2", ctx) { p in
            p.a = SIMD4(f(ctx.num("black") / 100), f(ctx.num("shadows") / 100), f(ctx.num("mids") / 100), f(ctx.num("highs") / 100))
            p.b.x = f(ctx.num("white") / 100); p.i = SIMD4(0, UInt32(ctx.effect.choice("channel")), 0, 0) } })

    static let looks = EffectDefinition(
        id: "awi.looks", name: "AWI Looks", category: .color, aeMatchNames: ["ADBE Lumetri"],
        summary: "Lumetri-style grade: temperature, tint, contrast, saturation, vibrance, highlights, shadows, fade.",
        params: [.number("temp", "Temperature", 0, -100, 100), .number("tint", "Tint", 0, -100, 100), .number("contrast", "Contrast", 0, -100, 100),
                 .number("sat", "Saturation", 0, -100, 100), .number("vib", "Vibrance", 0, -100, 100), .number("high", "Highlights", 0, -100, 100),
                 .number("shad", "Shadows", 0, -100, 100), .number("fade", "Faded Film", 0, 0, 100)],
        stage: .pixels { ctx in run("fxColor2", ctx) { p in
            p.a = SIMD4(f(ctx.num("temp") / 100), f(ctx.num("tint") / 100), f(ctx.num("contrast") / 100), f(ctx.num("sat") / 100))
            p.b = SIMD4(f(ctx.num("vib") / 100), f(ctx.num("high") / 100), f(ctx.num("shad") / 100), f(ctx.num("fade") / 100))
            p.i.x = 1 } })

    static let grain = EffectDefinition(
        id: "ae.noise", name: "Noise / Grain", category: .color, aeMatchNames: ["ADBE Noise", "ADBE Add Grain"],
        summary: "Film grain or digital noise, animated per frame.",
        params: [.number("amount", "Amount of Noise", 15, 0, 100, unit: "%", ae: 1), .number("size", "Grain Size", 1, 0.5, 8, step: 0.1),
                 .toggle("color", "Use Color Noise", false, ae: 3)],
        stage: .pixels { ctx in run("fxColor2", ctx) { p in
            p.a = SIMD4(f(ctx.num("amount") / 100), f(ctx.num("size") * ctx.unit), ctx.effect.bool("color") ? 1 : 0, f((ctx.time * 30).rounded()))
            p.i.x = 2 } })

    // MARK: AWI plugins

    static let deepGlow = EffectDefinition(
        id: "awi.deepGlow", name: "AWI Deep Glow", category: .color, aeMatchNames: ["PEDeepGlow", "PEDG2"],
        summary: "Deep, wide glow from the whole subject that keeps its own colors: halos glow in the subject's hue and never wash out to white. Threshold limits it to the brighter parts if you want.",
        params: [.number("radius", "Radius", 120, 1, 2000, unit: "px"), .number("exposure", "Exposure", 0, -4, 4, step: 0.01),
                 .number("threshold", "Threshold", 0, 0, 100, unit: "%"), .color("tint", "Tint", RGBA(1, 1, 1)),
                 .number("aberration", "Chromatic Aberration", 0, 0, 40, unit: "px"),
                 .number("saturation", "Glow Saturation", 30, 0, 200, unit: "%")],
        margin: { e, t in min(e.number("radius", t) * 1.5, 900) },
        stage: .pixels { ctx in
            // Glow source: the whole subject (threshold 0), or only its brighter parts.
            var source = ctx.input
            let th = ctx.num("threshold") / 100
            if th > 0.001 {
                var tp = EffectParams(); tp.a = SIMD4(f(th), 0.08, 0, 0)
                let bright = ctx.temp()
                ctx.gpu.run("fxGlowThreshold", ctx.cb, textures: [ctx.input, bright], params: tp, grid: bright)
                source = bright
            }
            // The glow is soft, so it's built on a smaller copy (half or quarter size): same look, far less memory.
            let r0 = ctx.num("radius") * ctx.unit
            let down = r0 > 160 ? 4 : (r0 > 24 ? 2 : 1)
            if down > 1 {
                let small = ctx.pool.acquire(width: max(1, source.width / down), height: max(1, source.height / down))
                ctx.gpu.run("fxResample", ctx.cb, textures: [source, small], grid: small)
                source = small
            }
            let r = r0 / Double(down)
            // Six octaves of blur summed: tight core + very wide, deep halo.
            var acc: MTLTexture? = nil
            for k in 0..<6 {
                let g = ctx.gpu.gaussian(ctx, input: source, sigma: max(0.6, r / pow(2, Double(5 - k)) / 2))
                if let a = acc {
                    let o = ctx.pool.acquire(width: source.width, height: source.height); var add = EffectParams(); add.a = SIMD4(1, 0, 0, 0)
                    ctx.gpu.run("fxGlowCombine", ctx.cb, textures: [a, g, o], params: add, grid: o); acc = o
                } else { acc = g }
            }
            var glow = acc!
            let ca = ctx.num("aberration") * ctx.unit / Double(down)
            if ca > 0.1 {
                let o = ctx.pool.acquire(width: glow.width, height: glow.height); var p = EffectParams(); p.a = SIMD4(f(ca), 0, 0, 0)
                ctx.gpu.run("fxRGBSplit", ctx.cb, textures: [glow, o], params: p, grid: o); glow = o
            }
            // Color-keeping combine: adds light in the subject's hue; anything past full brightness is scaled as
            // a whole instead of clipping to white.
            let out = ctx.temp()
            var cp = EffectParams()
            cp.a = SIMD4(f(pow(2, ctx.num("exposure")) / 4), f(ctx.num("saturation") / 100), 0, 0)
            cp.b = ctx.effect.color("tint", ctx.time).simd
            ctx.gpu.run("fx19GlowKeep", ctx.cb, textures: [ctx.input, out, glow], params: cp, grid: out)
            return out
        })

    static let saber = EffectDefinition(
        id: "awi.saber", name: "AWI Saber", category: .color, aeMatchNames: ["VIDEOCOPILOT Saber"],
        summary: "Energy beam: hot core + colored glow on the layer's shape (text, shapes, paths).",
        params: [.color("color", "Glow Color", RGBA(0.2, 0.55, 1)), .number("intensity", "Glow Intensity", 60, 0, 300, unit: "%"),
                 .number("spread", "Glow Spread", 20, 1, 300, unit: "px"), .number("core", "Core Size", 50, 1, 100, unit: "%"),
                 .number("flicker", "Flicker", 0, 0, 100, unit: "%")],
        margin: { e, t in e.number("spread", t) * 3 },
        stage: .pixels { ctx in
            let col = ctx.effect.color("color", ctx.time)
            let core = run("fxSaberCore", ctx) { p in
                p.a = SIMD4(f(ctx.num("core") / 100), 0, f(ctx.num("flicker") / 100), f(ctx.time)); p.b = col.simd }
            let s = ctx.num("spread") * ctx.unit
            let g1 = ctx.gpu.gaussian(ctx, input: core, sigma: s / 4), g2 = ctx.gpu.gaussian(ctx, input: core, sigma: s)
            let sum = ctx.temp(); var add = EffectParams(); add.a = SIMD4(1, 0, 0, 0)
            ctx.gpu.run("fxGlowCombine", ctx.cb, textures: [g1, g2, sum], params: add, grid: sum)
            let out = ctx.temp()
            // Flicker pulses the whole beam (glow included), not just the core.
            let pulse = 0.5 + 0.5 * sin(ctx.time * 53) * cos(ctx.time * 17 + 1.3)
            let flick = 1 - ctx.num("flicker") / 100 * 0.8 * pulse
            var cp = EffectParams(); cp.a = SIMD4(f(ctx.num("intensity") / 100 * 2 * flick), 0, 0, 0); cp.i = SIMD4(0, 0, 1, 0)
            cp.b = col.simd; cp.c = col.simd
            ctx.gpu.run("fxGlowCombine", ctx.cb, textures: [core, sum, out], params: cp, grid: out)
            return out
        })

    static let shine = EffectDefinition(
        id: "awi.shine", name: "AWI Shine", category: .color, aeMatchNames: ["tc Shine", "TCShine"],
        summary: "Volumetric light rays bursting from a point.",
        params: [.point("source", "Source Point", Vec2(0.5, 0.35)), .number("length", "Ray Length", 50, 0, 100, unit: "%"),
                 .number("intensity", "Boost Light", 0.6, 0, 10, step: 0.1), .color("color", "Ray Color", RGBA(1, 0.9, 0.7))],
        stage: .pixels { ctx in run("fxShine", ctx) { p in
            let s = ctx.effect.point("source", ctx.time)
            p.a = SIMD4(f(s.x * Double(ctx.width)), f(s.y * Double(ctx.height)), f(ctx.num("length") / 100), f(ctx.num("intensity")))
            p.b = ctx.effect.color("color", ctx.time).simd; p.i.x = 48 } })

    static let glitch = EffectDefinition(
        id: "awi.glitch", name: "AWI Glitch", category: .stylize, aeMatchNames: ["S_DigitalDamage", "RG Universe Glitch"],
        summary: "Digital damage: slice offsets, RGB splits and inverted blocks that change every frame.",
        params: [.number("amount", "Amount", 50, 0, 100, unit: "%"), .number("block", "Block Height", 16, 2, 200, unit: "px"),
                 .number("rgb", "RGB Shift", 10, 0, 100, unit: "px"), .number("rate", "Changes / Second", 12, 1, 60)],
        stage: .pixels { ctx in run("fxGlitch", ctx) { p in
            p.a = SIMD4(f(ctx.num("amount") / 100), f(ctx.num("block") * ctx.unit), f(ctx.num("rgb") * ctx.unit), f((ctx.time * ctx.num("rate")).rounded(.down)))
            p.i.x = 0 } })

    static let vhs = EffectDefinition(
        id: "awi.vhs", name: "AWI VHS", category: .stylize, aeMatchNames: ["RG Universe VHS"],
        summary: "Tape look: chroma bleed, wobble, noise and tracking band.",
        params: [.number("amount", "Bleed", 60, 0, 100, unit: "%"), .number("noise", "Noise", 20, 0, 100, unit: "%"),
                 .number("wobble", "Wobble", 30, 0, 100, unit: "%")],
        stage: .pixels { ctx in run("fxGlitch", ctx) { p in
            p.a = SIMD4(f(ctx.num("amount") / 100), f(ctx.num("noise") / 100), f(ctx.num("wobble") / 100), f(ctx.time)); p.i.x = 1 } })

    static let pixelSort = EffectDefinition(
        id: "awi.pixelSort", name: "AWI Pixel Sort", category: .stylize, aeMatchNames: ["Pixel Sorter"],
        summary: "Bright runs of pixels stretch into sorted-looking streaks.",
        params: [.number("threshold", "Threshold", 55, 0, 100, unit: "%"), .number("length", "Length", 120, 1, 1000, unit: "px"),
                 .angle("direction", "Direction", 90)],
        stage: .pixels { ctx in run("fxPixelSort", ctx) { p in
            p.a = SIMD4(f(ctx.num("threshold") / 100), f(ctx.num("length") * ctx.unit), f(ctx.num("direction")), 0); p.i.x = 64 } })

    static let particles = EffectDefinition(
        id: "awi.particles", name: "AWI Particles", category: .generate, aeMatchNames: ["CC Particle World", "tc Particular"],
        summary: "Emitter of glowing particles with velocity, spread, gravity and life.",
        params: [.point("emitter", "Emitter", Vec2(0.5, 0.7)), .number("rate", "Birth Rate", 60, 0, 600, unit: "/s"),
                 .number("velocity", "Velocity", 300, 0, 3000, unit: "px/s"), .number("spread", "Spread", 90, 0, 360, unit: "°"),
                 .angle("direction", "Direction", 0), .number("gravity", "Gravity", 300, -3000, 3000),
                 .number("life", "Life", 1.5, 0.1, 10, step: 0.1, unit: "s"), .number("size", "Size", 6, 1, 100, unit: "px"),
                 .color("color", "Color", RGBA(1, 0.8, 0.4)), .number("seed", "Random Seed", 1, 0, 1000, step: 1)],
        margin: { _, _ in 0 },
        stage: .pixels { ctx in run("fxParticles", ctx) { p in
            let e = ctx.effect.point("emitter", ctx.time)
            p.a = SIMD4(f(e.x * Double(ctx.width)), f(e.y * Double(ctx.height)), f(ctx.num("rate")), f(ctx.num("velocity") * ctx.unit))
            p.b = SIMD4(f(ctx.num("spread")), f(ctx.num("direction")), f(ctx.num("gravity") * ctx.unit), f(ctx.num("life")))
            p.c = SIMD4(f(ctx.num("size") * ctx.unit), f(ctx.time), f(ctx.num("seed")), 400)
            p.d = ctx.effect.color("color", ctx.time).simd } })
}
