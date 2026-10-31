import Foundation
import Metal
import simd

/// Batch 7: procedural generators & particles (anime / AMV staples) — starfield, stars, snow, rain, embers, bokeh,
/// dust, fireflies, speed lines, manga focus lines, shockwave, beam, plasma, aurora, clouds, smoke, fire, electric
/// arcs, code rain, retro grid, tunnel, equalizer, halftone, confetti. All composite over the layer (Blend / Only).
extension EffectRegistry {
    static let batch7: [EffectDefinition] = [
        starfield, twinklingStars, snow, rain, embers, bokehParticles, dustMotes, fireflies,
        speedLines, mangaFocusLines, shockwave, energyBeam, plasma, aurora, clouds, smoke, fire,
        electricArcs, codeRain, retroGrid, tunnel, equalizer, halftoneBackground, confetti,
    ]

    private static func g7(_ ctx: EffectContext, _ mode: UInt32, over: Bool, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.i.y = over ? 1 : 0
        p.d.x = Float(ctx.time)
        p.d.y = Float(ctx.num("blend") / 100)
        p.d.z = ctx.effect.bool("only") ? 1 : 0
        ctx.gpu.run("fxGen7", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }
    private static func pt7(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    private static func n7(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k)) }
    private static func px7(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * ctx.unit) }
    private static func pc7(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) / 100) }
    private static func col7(_ ctx: EffectContext, _ k: String) -> SIMD4<Float> { ctx.effect.color(k, ctx.time).simd }
    private static func p7(_ list: [ParamDef], _ blend: Double = 100) -> [ParamDef] {
        list + [.number("blend", "Blend", blend, 0, 100, unit: "%"), .toggle("only", "Effect Only", false)]
    }
    private static let seed7: ParamDef = .number("seed", "Random Seed", 1, 0, 100, step: 1)

    static let starfield = EffectDefinition(
        id: "awi7.starfield", name: "Starfield Warp", category: .generate, aeMatchNames: [],
        summary: "Stars rushing toward the viewer from a center point (warp speed).",
        params: p7([.point("center", "Center", Vec2(0.5, 0.5)), .number("speed", "Speed", 1, 0, 10, step: 0.05),
                 .number("density", "Density", 5, 1, 12, step: 0.1), .number("size", "Star Size", 1.5, 0.5, 8, step: 0.1, unit: "px"),
                 .number("streak", "Streak", 4, 0, 20, step: 0.1), .color("color", "Color", RGBA(0.85, 0.92, 1)), seed7]),
        stage: .pixels { ctx in g7(ctx, 0, over: false) { p in
            let c = pt7(ctx, "center")
            p.a = SIMD4(c.x, c.y, n7(ctx, "speed"), n7(ctx, "density")); p.b = col7(ctx, "color")
            p.c = SIMD4(px7(ctx, "size"), n7(ctx, "seed"), n7(ctx, "streak"), 0) } })

    static let twinklingStars = EffectDefinition(
        id: "awi7.twinklingStars", name: "Twinkling Stars", category: .generate, aeMatchNames: [],
        summary: "A night sky of twinkling stars with little cross flares.",
        params: p7([.number("spacing", "Spacing", 24, 6, 120, unit: "px"), .number("size", "Star Size", 2, 0.5, 10, step: 0.1, unit: "px"),
                 .number("speed", "Twinkle Speed", 1.5, 0, 6, step: 0.05), .number("brightness", "Brightness", 1.2, 0, 3, step: 0.01),
                 .color("color", "Color", RGBA(1, 0.97, 0.88)), seed7]),
        stage: .pixels { ctx in g7(ctx, 1, over: false) { p in
            p.a = SIMD4(px7(ctx, "spacing"), px7(ctx, "size"), n7(ctx, "speed"), n7(ctx, "brightness"))
            p.b = col7(ctx, "color"); p.c.x = n7(ctx, "seed") } })

    static let snow = EffectDefinition(
        id: "awi7.snow", name: "Snow", category: .generate, aeMatchNames: [],
        summary: "Falling snowflakes in three depth layers with wind and sway.",
        params: p7([.number("spacing", "Spacing", 28, 8, 120, unit: "px"), .number("size", "Flake Size", 3, 0.5, 12, step: 0.1, unit: "px"),
                 .number("speed", "Fall Speed", 90, 0, 600, unit: "px/s"), .number("wind", "Wind", 20, -300, 300, unit: "px/s"),
                 .number("wobble", "Sway", 0.8, 0, 2, step: 0.01), .color("color", "Color", RGBA(1, 1, 1)), seed7]),
        stage: .pixels { ctx in g7(ctx, 2, over: true) { p in
            p.a = SIMD4(px7(ctx, "spacing"), px7(ctx, "size"), px7(ctx, "speed"), px7(ctx, "wind"))
            p.b = col7(ctx, "color"); p.c = SIMD4(n7(ctx, "seed"), n7(ctx, "wobble"), 0, 0) } })

    static let rain = EffectDefinition(
        id: "awi7.rain", name: "Rain", category: .generate, aeMatchNames: [],
        summary: "Slanted rain streaks in parallax layers.",
        params: p7([.angle("angle", "Angle", 15), .number("speed", "Speed", 900, 0, 3000, unit: "px/s"),
                 .number("length", "Drop Length", 18, 2, 100, unit: "px"), .number("spacing", "Spacing", 10, 3, 60, unit: "px"),
                 .number("width", "Width", 1.2, 0.3, 6, step: 0.1, unit: "px"), .number("amount", "Amount", 60, 0, 100, unit: "%"),
                 .color("color", "Color", RGBA(0.75, 0.82, 0.95)), seed7], 80),
        stage: .pixels { ctx in g7(ctx, 3, over: true) { p in
            p.a = SIMD4(Float(ctx.num("angle") * .pi / 180), px7(ctx, "speed"), px7(ctx, "length"), px7(ctx, "spacing"))
            p.b = col7(ctx, "color"); p.c = SIMD4(px7(ctx, "width"), n7(ctx, "seed"), pc7(ctx, "amount"), 0) } })

    static let embers = EffectDefinition(
        id: "awi7.embers", name: "Embers & Sparks", category: .generate, aeMatchNames: [],
        summary: "Hot glowing embers with bloom halos and streaking sparks, rising on turbulent air and cooling from white to red.",
        params: p7([.number("spacing", "Spacing", 28, 8, 150, unit: "px"), .number("size", "Size", 3.5, 0.5, 10, step: 0.1, unit: "px"),
                 .number("speed", "Rise Speed", 120, 0, 500, unit: "px/s"), .number("turbulence", "Turbulence", 1, 0, 3, step: 0.01),
                 .number("flicker", "Flicker", 6, 0, 20, step: 0.1), .color("color", "Color", RGBA(1, 0.45, 0.1)), seed7]),
        stage: .pixels { ctx in g7(ctx, 4, over: false) { p in
            p.a = SIMD4(px7(ctx, "spacing"), px7(ctx, "size"), px7(ctx, "speed"), n7(ctx, "turbulence"))
            p.b = col7(ctx, "color"); p.c = SIMD4(n7(ctx, "seed"), n7(ctx, "flicker"), 0, 0) } })

    static let bokehParticles = EffectDefinition(
        id: "awi7.bokehParticles", name: "Bokeh Particles", category: .generate, aeMatchNames: [],
        summary: "Soft out-of-focus light circles floating upward.",
        params: p7([.number("spacing", "Spacing", 60, 20, 200, unit: "px"), .number("size", "Size", 16, 2, 60, unit: "px"),
                 .number("speed", "Speed", 25, 0, 200, unit: "px/s"), .number("softness", "Softness", 0.6, 0.05, 1, step: 0.01),
                 .number("hueVar", "Color Variation", 50, 0, 100, unit: "%"), .color("color", "Color", RGBA(1, 0.75, 0.45)), seed7]),
        stage: .pixels { ctx in g7(ctx, 5, over: false) { p in
            p.a = SIMD4(px7(ctx, "spacing"), px7(ctx, "size"), px7(ctx, "speed"), n7(ctx, "softness"))
            p.b = col7(ctx, "color"); p.c = SIMD4(pc7(ctx, "hueVar"), n7(ctx, "seed"), 0, 0) } })

    static let dustMotes = EffectDefinition(
        id: "awi7.dustMotes", name: "Dust Motes", category: .generate, aeMatchNames: [],
        summary: "Floating dust in depth: large defocused specks up front, small sharp glinting ones behind, caught in soft light.",
        params: p7([.number("spacing", "Spacing", 26, 8, 120, unit: "px"), .number("size", "Size", 2.2, 0.3, 6, step: 0.1, unit: "px"),
                 .number("speed", "Drift", 12, 0, 100, unit: "px/s"), .number("brightness", "Brightness", 1.3, 0, 3, step: 0.01),
                 .color("color", "Color", RGBA(1, 0.95, 0.85)), seed7]),
        stage: .pixels { ctx in g7(ctx, 6, over: false) { p in
            p.a = SIMD4(px7(ctx, "spacing"), px7(ctx, "size"), px7(ctx, "speed"), n7(ctx, "brightness"))
            p.b = col7(ctx, "color"); p.c.x = n7(ctx, "seed") } })

    static let fireflies = EffectDefinition(
        id: "awi7.fireflies", name: "Fireflies", category: .generate, aeMatchNames: [],
        summary: "Wandering glowing fireflies that pulse on and off.",
        params: p7([.number("spacing", "Spacing", 45, 15, 200, unit: "px"), .number("size", "Size", 2.5, 0.5, 8, step: 0.1, unit: "px"),
                 .number("speed", "Wander", 20, 0, 100, unit: "px/s"), .number("glow", "Glow", 3, 0, 8, step: 0.05),
                 .number("pulse", "Pulse Speed", 2.5, 0, 10, step: 0.05), .color("color", "Color", RGBA(0.75, 1, 0.3)), seed7]),
        stage: .pixels { ctx in g7(ctx, 7, over: false) { p in
            p.a = SIMD4(px7(ctx, "spacing"), px7(ctx, "size"), px7(ctx, "speed"), n7(ctx, "glow"))
            p.b = col7(ctx, "color"); p.c = SIMD4(n7(ctx, "seed"), n7(ctx, "pulse"), 0, 0) } })

    static let speedLines = EffectDefinition(
        id: "awi7.speedLines", name: "Speed Lines", category: .generate, aeMatchNames: [],
        summary: "Animated anime radial speed lines around a clear center.",
        params: p7([.point("center", "Center", Vec2(0.5, 0.5)), .number("count", "Density", 90, 10, 300, step: 1),
                 .number("thickness", "Width", 45, 0, 100, unit: "%"), .number("inner", "Inner Radius", 30, 0, 100, unit: "%"),
                 .number("fps", "Flicker Rate", 12, 0, 30, step: 0.5, unit: "fps"), .number("jitter", "Length Variation", 40, 0, 100, unit: "%"),
                 .color("color", "Color", RGBA(1, 1, 1)), seed7]),
        stage: .pixels { ctx in g7(ctx, 8, over: true) { p in
            let c = pt7(ctx, "center")
            p.a = SIMD4(c.x, c.y, n7(ctx, "count"), pc7(ctx, "thickness")); p.b = col7(ctx, "color")
            p.c = SIMD4(pc7(ctx, "inner"), n7(ctx, "fps"), n7(ctx, "seed"), pc7(ctx, "jitter")) } })

    static let mangaFocusLines = EffectDefinition(
        id: "awi7.mangaFocusLines", name: "Manga Focus Lines", category: .generate, aeMatchNames: [],
        summary: "Tapered concentration lines pointing at the subject, static or jittering.",
        params: p7([.point("center", "Center", Vec2(0.5, 0.5)), .number("count", "Line Count", 160, 20, 400, step: 1),
                 .number("thickness", "Thickness", 60, 0, 100, unit: "%"), .number("inner", "Inner Radius", 40, 0, 100, unit: "%"),
                 .number("fps", "Jitter Rate", 0, 0, 24, step: 0.5, unit: "fps"), .number("aspect", "Aspect", 1, 0.3, 3, step: 0.01),
                 .color("color", "Ink", RGBA(1, 1, 1)), seed7]),
        stage: .pixels { ctx in g7(ctx, 9, over: true) { p in
            let c = pt7(ctx, "center")
            p.a = SIMD4(c.x, c.y, n7(ctx, "count"), pc7(ctx, "thickness")); p.b = col7(ctx, "color")
            p.c = SIMD4(pc7(ctx, "inner"), n7(ctx, "fps"), n7(ctx, "seed"), n7(ctx, "aspect")) } })

    static let shockwave = EffectDefinition(
        id: "awi7.shockwave", name: "Shockwave Ring", category: .generate, aeMatchNames: [],
        summary: "An expanding ring that warps the image and glows (animate Progress, or set Auto Speed).",
        params: p7([.point("center", "Center", Vec2(0.5, 0.5)), .number("progress", "Progress", 40, 0, 100, unit: "%"),
                 .number("radius", "Max Radius", 220, 10, 2000, unit: "px"), .number("thickness", "Thickness", 12, 1, 100, unit: "px"),
                 .number("distortion", "Distortion", 25, -100, 100, unit: "px"), .number("glow", "Glow", 1, 0, 3, step: 0.01),
                 .number("auto", "Auto Speed", 0, 0, 3, step: 0.01), .color("color", "Color", RGBA(0.6, 0.85, 1)),
                 .number("secondary", "Secondary Ring", 50, 0, 100, unit: "%")]),
        stage: .pixels { ctx in g7(ctx, 10, over: false) { p in
            let c = pt7(ctx, "center")
            p.a = SIMD4(c.x, c.y, pc7(ctx, "progress"), px7(ctx, "radius")); p.b = col7(ctx, "color")
            p.c = SIMD4(px7(ctx, "thickness"), px7(ctx, "distortion"), n7(ctx, "glow"), n7(ctx, "auto"))
            p.d.w = pc7(ctx, "secondary") } })

    static let energyBeam = EffectDefinition(
        id: "awi7.energyBeam", name: "Energy Beam", category: .generate, aeMatchNames: [],
        summary: "Energy beam between two points: white-hot core, saturated glow, crackling filaments, sparks and flared ends.",
        params: p7([.point("start", "Start", Vec2(0.1, 0.55)), .point("end", "End", Vec2(0.9, 0.45)),
                 .number("width", "Width", 8, 1, 80, unit: "px"), .number("glow", "Glow", 3, 0.5, 10, step: 0.05),
                 .number("wiggle", "Wiggle", 6, 0, 100, unit: "px"), .number("speed", "Speed", 4, 0, 20, step: 0.05),
                 .color("color", "Color", RGBA(0.3, 0.6, 1))]),
        stage: .pixels { ctx in g7(ctx, 11, over: false) { p in
            let a = pt7(ctx, "start"), b = pt7(ctx, "end")
            p.a = SIMD4(a.x, a.y, b.x, b.y); p.b = col7(ctx, "color")
            p.c = SIMD4(px7(ctx, "width"), n7(ctx, "glow"), px7(ctx, "wiggle"), n7(ctx, "speed")) } })

    static let plasma = EffectDefinition(
        id: "awi7.plasma", name: "Plasma", category: .generate, aeMatchNames: [],
        summary: "Silky domain-warped plasma with a violet / magenta / cyan gradient map (Hue Shift recolors it).",
        params: p7([.number("scale", "Scale", 110, 4, 400, unit: "px"), .number("speed", "Speed", 1, 0, 6, step: 0.05),
                 .angle("hue", "Hue Shift", 0), .number("saturation", "Saturation", 100, 0, 100, unit: "%")], 75),
        stage: .pixels { ctx in g7(ctx, 12, over: true) { p in
            p.a = SIMD4(px7(ctx, "scale"), n7(ctx, "speed"), Float(ctx.num("hue") / 360), pc7(ctx, "saturation")) } })

    static let aurora = EffectDefinition(
        id: "awi7.aurora", name: "Aurora", category: .generate, aeMatchNames: [],
        summary: "Waving northern-light curtains with vertical rays.",
        params: p7([.number("position", "Position", 55, 0, 100, unit: "%"), .number("scale", "Scale", 90, 10, 600, unit: "px"),
                 .number("speed", "Speed", 1, 0, 5, step: 0.05), .number("intensity", "Intensity", 1.4, 0, 4, step: 0.01),
                 .color("low", "Bottom Color", RGBA(0.2, 1, 0.6)), .color("high", "Top Color", RGBA(0.6, 0.3, 1)), seed7]),
        stage: .pixels { ctx in g7(ctx, 13, over: false) { p in
            p.a = SIMD4(pc7(ctx, "position"), px7(ctx, "scale"), n7(ctx, "speed"), n7(ctx, "intensity"))
            p.b = col7(ctx, "low"); p.c = col7(ctx, "high"); p.d.w = n7(ctx, "seed") } })

    static let clouds = EffectDefinition(
        id: "awi7.clouds", name: "Clouds & Fog", category: .generate, aeMatchNames: [],
        summary: "Drifting, slowly evolving fractal clouds or fog.",
        params: p7([.number("scale", "Scale", 80, 10, 800, unit: "px"), .number("coverage", "Coverage", 55, 0, 100, unit: "%"),
                 .number("softness", "Softness", 35, 0, 100, unit: "%"), .number("drift", "Drift", 30, -300, 300, unit: "px/s"),
                 .number("evolve", "Evolve", 0.3, 0, 3, step: 0.01), .color("color", "Color", RGBA(0.92, 0.94, 1)), seed7], 85),
        stage: .pixels { ctx in g7(ctx, 14, over: true) { p in
            p.a = SIMD4(px7(ctx, "scale"), pc7(ctx, "coverage"), pc7(ctx, "softness"), px7(ctx, "drift"))
            p.b = col7(ctx, "color"); p.c = SIMD4(n7(ctx, "evolve"), n7(ctx, "seed"), 0, 0) } })

    static let smoke = EffectDefinition(
        id: "awi7.smoke", name: "Smoke", category: .generate, aeMatchNames: [],
        summary: "Turbulent smoke rising from the bottom and thinning out.",
        params: p7([.number("scale", "Scale", 70, 10, 600, unit: "px"), .number("speed", "Rise Speed", 60, 0, 400, unit: "px/s"),
                 .number("turbulence", "Turbulence", 1, 0, 3, step: 0.01), .number("height", "Height", 70, 0, 100, unit: "%"),
                 .number("density", "Density", 100, 0, 200, unit: "%"), .color("color", "Color", RGBA(0.7, 0.7, 0.75)), seed7]),
        stage: .pixels { ctx in g7(ctx, 15, over: true) { p in
            p.a = SIMD4(px7(ctx, "scale"), px7(ctx, "speed"), n7(ctx, "turbulence"), pc7(ctx, "height"))
            p.b = col7(ctx, "color"); p.c = SIMD4(n7(ctx, "seed"), pc7(ctx, "density"), 0, 0) } })

    static let fire = EffectDefinition(
        id: "awi7.fire", name: "Fire", category: .generate, aeMatchNames: [],
        summary: "Stylized flames licking up from the bottom of the frame.",
        params: p7([.number("height", "Height", 45, 0, 100, unit: "%"), .number("scale", "Scale", 40, 5, 400, unit: "px"),
                 .number("speed", "Speed", 2, 0, 10, step: 0.05), .number("turbulence", "Turbulence", 0.6, 0, 2, step: 0.01),
                 .number("intensity", "Intensity", 1.2, 0, 3, step: 0.01), .color("tint", "Tint", RGBA(1, 0.45, 0.1)), seed7]),
        stage: .pixels { ctx in g7(ctx, 16, over: false) { p in
            p.a = SIMD4(pc7(ctx, "height"), px7(ctx, "scale"), n7(ctx, "speed"), n7(ctx, "turbulence"))
            p.b = col7(ctx, "tint"); p.c = SIMD4(n7(ctx, "seed"), n7(ctx, "intensity"), 0, 0) } })

    static let electricArcs = EffectDefinition(
        id: "awi7.electricArcs", name: "Electric Arcs", category: .generate, aeMatchNames: [],
        summary: "Jagged branching lightning between two points with forks, flicker and layered glow.",
        params: p7([.point("start", "Start", Vec2(0.15, 0.5)), .point("end", "End", Vec2(0.85, 0.5)),
                 .number("bolts", "Bolts", 2, 1, 4, step: 1), .number("amplitude", "Amplitude", 25, 0, 200, unit: "px"),
                 .number("width", "Width", 2.5, 0.5, 20, step: 0.1, unit: "px"), .number("fps", "Flicker Rate", 12, 0, 30, step: 0.5, unit: "fps"),
                 .number("glow", "Glow", 3, 0.5, 10, step: 0.05), .color("color", "Color", RGBA(0.5, 0.75, 1)), seed7]),
        stage: .pixels { ctx in g7(ctx, 17, over: false) { p in
            let a = pt7(ctx, "start"), b = pt7(ctx, "end")
            p.a = SIMD4(a.x, a.y, b.x, b.y); p.b = col7(ctx, "color")
            p.c = SIMD4(px7(ctx, "amplitude"), px7(ctx, "width"), n7(ctx, "fps"), n7(ctx, "glow"))
            p.d.w = n7(ctx, "seed"); p.i.z = UInt32(max(1, min(4, Int(ctx.num("bolts"))))) } })

    static let codeRain = EffectDefinition(
        id: "awi7.codeRain", name: "Code Rain", category: .generate, aeMatchNames: [],
        summary: "Falling columns of glowing glyphs (digital rain).",
        params: p7([.number("cell", "Glyph Size", 12, 4, 60, unit: "px"), .number("speed", "Fall Speed", 12, 0, 60, step: 0.1),
                 .number("trail", "Trail Length", 14, 1, 60, step: 0.5), .number("change", "Glyph Change Rate", 8, 0, 30, step: 0.1),
                 .number("density", "Density", 85, 0, 100, unit: "%"), .color("color", "Color", RGBA(0.2, 1, 0.4)), seed7]),
        stage: .pixels { ctx in g7(ctx, 18, over: false) { p in
            p.a = SIMD4(px7(ctx, "cell"), n7(ctx, "speed"), n7(ctx, "trail"), n7(ctx, "change"))
            p.b = col7(ctx, "color"); p.c = SIMD4(n7(ctx, "seed"), pc7(ctx, "density"), 0, 0) } })

    static let retroGrid = EffectDefinition(
        id: "awi7.retroGrid", name: "Retro Grid & Sun", category: .generate, aeMatchNames: [],
        summary: "Synthwave scene: gradient sun with sliding slits and bloom, neon mountains, horizon haze and a glowing grid rushing into the fog.",
        params: p7([.number("horizon", "Horizon", 55, 0, 100, unit: "%"), .number("spacing", "Grid Spacing", 36, 4, 300, unit: "px"),
                 .number("speed", "Speed", 1.5, 0, 10, step: 0.05), .number("lineWidth", "Line Width", 1.6, 0.3, 10, step: 0.1, unit: "px"),
                 .number("sun", "Sun Size", 22, 0, 100, unit: "%"), .color("grid", "Grid Color", RGBA(1, 0.2, 0.85)),
                 .color("sunColor", "Sun Color", RGBA(1, 0.85, 0.2))]),
        stage: .pixels { ctx in g7(ctx, 19, over: true) { p in
            p.a = SIMD4(pc7(ctx, "horizon"), px7(ctx, "spacing"), n7(ctx, "speed"), px7(ctx, "lineWidth"))
            p.b = col7(ctx, "grid"); p.c = col7(ctx, "sunColor"); p.d.w = pc7(ctx, "sun") } })

    static let tunnel = EffectDefinition(
        id: "awi7.tunnel", name: "Tunnel", category: .generate, aeMatchNames: [],
        summary: "Glowing neon tunnel: bloomed rings shifting color with depth, twisting spokes, speed streaks and a dark vanishing point.",
        params: p7([.point("center", "Center", Vec2(0.5, 0.5)), .number("density", "Ring Density", 4, 0.5, 20, step: 0.05),
                 .number("speed", "Speed", 1, 0, 10, step: 0.05), .number("width", "Line Width", 15, 0, 100, unit: "%"),
                 .number("segments", "Spokes", 12, 0, 48, step: 1), .number("twist", "Twist", 0.5, -5, 5, step: 0.01),
                 .number("fade", "Depth Fade", 30, 0, 100, unit: "%"), .color("color", "Color", RGBA(0.3, 0.8, 1))]),
        stage: .pixels { ctx in g7(ctx, 20, over: false) { p in
            let c = pt7(ctx, "center")
            p.a = SIMD4(c.x, c.y, n7(ctx, "density"), n7(ctx, "speed")); p.b = col7(ctx, "color")
            p.c = SIMD4(pc7(ctx, "width"), n7(ctx, "segments"), n7(ctx, "twist"), pc7(ctx, "fade")) } })

    static let equalizer = EffectDefinition(
        id: "awi7.equalizer", name: "Equalizer Bars", category: .generate, aeMatchNames: [],
        summary: "Glowing rounded spectrum bars with gradient, falling peak caps and a floor reflection (time driven).",
        params: p7([.number("bars", "Bars", 24, 2, 128, step: 1), .number("height", "Max Height", 45, 0, 100, unit: "%"),
                 .number("speed", "Speed", 2, 0, 10, step: 0.05), .number("gap", "Gap", 25, 0, 90, unit: "%"),
                 .choice("style", "Style", ["Solid", "Blocks"], 1), .color("bottom", "Bottom Color", RGBA(0.2, 0.9, 1)),
                 .color("top", "Top Color", RGBA(1, 0.3, 0.8)), seed7]),
        stage: .pixels { ctx in g7(ctx, 21, over: true) { p in
            p.a = SIMD4(n7(ctx, "bars"), pc7(ctx, "height"), n7(ctx, "speed"), pc7(ctx, "gap"))
            p.b = col7(ctx, "bottom"); p.c = col7(ctx, "top"); p.d.w = n7(ctx, "seed")
            p.i.z = UInt32(ctx.effect.choice("style")) } })

    static let halftoneBackground = EffectDefinition(
        id: "awi7.halftoneBackground", name: "Halftone Pattern", category: .generate, aeMatchNames: [],
        summary: "Animated halftone with soft glowing gradient dots sized by a flowing noise field and waves.",
        params: p7([.number("cell", "Dot Spacing", 14, 3, 120, unit: "px"), .angle("angle", "Angle", 45),
                 .number("speed", "Speed", 0.5, 0, 5, step: 0.01), .number("wave", "Wave Scale", 120, 5, 1000, unit: "px"),
                 .number("dot", "Dot Size", 100, 0, 150, unit: "%"), .choice("pattern", "Pattern", ["Radial Wave", "Diagonal Sweep"], 0),
                 .color("color", "Color", RGBA(1, 0.3, 0.6))], 50),
        stage: .pixels { ctx in g7(ctx, 22, over: true) { p in
            p.a = SIMD4(px7(ctx, "cell"), Float(ctx.num("angle") * .pi / 180), n7(ctx, "speed"), px7(ctx, "wave"))
            p.b = col7(ctx, "color"); p.c.x = pc7(ctx, "dot"); p.i.z = UInt32(ctx.effect.choice("pattern")) } })

    static let confetti = EffectDefinition(
        id: "awi7.confetti", name: "Confetti", category: .generate, aeMatchNames: [],
        summary: "Colorful paper confetti tumbling down.",
        params: p7([.number("spacing", "Spacing", 34, 10, 150, unit: "px"), .number("size", "Size", 5, 1, 30, step: 0.1, unit: "px"),
                 .number("speed", "Fall Speed", 110, 0, 600, unit: "px/s"), .number("spin", "Spin", 3, 0, 15, step: 0.05),
                 .number("sway", "Sway", 0.8, 0, 2, step: 0.01), .number("saturation", "Saturation", 80, 0, 100, unit: "%"), seed7]),
        stage: .pixels { ctx in g7(ctx, 23, over: true) { p in
            p.a = SIMD4(px7(ctx, "spacing"), px7(ctx, "size"), px7(ctx, "speed"), n7(ctx, "spin"))
            p.c = SIMD4(n7(ctx, "seed"), pc7(ctx, "saturation"), n7(ctx, "sway"), 0) } })
}
