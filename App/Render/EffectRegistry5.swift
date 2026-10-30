import Foundation
import Metal
import simd

/// Batch 5: looks editors build by hand in AE / Alight Motion and share as presets — lens chromatic aberration,
/// god rays, light leaks, old film, halation, gradient map, cinematic bars, bokeh, chromatic zoom blur, flicker,
/// hue cycle, ink sketch, retro dither — plus Alight Motion-style motion behaviours (swing, oscillate, pulse, spin,
/// bounce, jitter) that animate without keyframes.
extension EffectRegistry {
    static let batch5: [EffectDefinition] = [
        chromaticAberration, godRays, lightLeak, oldFilm, halation, gradientMap, cinematicBars, lensBlur, chromaticZoom,
        flicker, hueCycle, inkSketch, retroDither,
        swing, oscillate, pulse, spin, bounce, jitter,
    ]

    private static func l5(_ ctx: EffectContext, _ mode: UInt32, src: MTLTexture? = nil, aux: MTLTexture? = nil,
                           _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        let s = src ?? ctx.input
        ctx.gpu.run("fxLook5", ctx.cb, textures: [s, out, aux ?? s], params: p, grid: out)
        return out
    }
    private static func pt(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }

    static let chromaticAberration = EffectDefinition(
        id: "awi.chromaticAberration", name: "Chromatic Aberration", category: .stylize, aeMatchNames: [],
        summary: "Lens color fringing that grows toward the edges.",
        params: [.number("amount", "Amount", 8, 0, 80, unit: "px"), .point("center", "Center", Vec2(0.5, 0.5)),
                 .number("falloff", "Edge Falloff", 1.5, 0, 4, step: 0.05)],
        stage: .pixels { ctx in l5(ctx, 0) { p in
            let c = pt(ctx, "center"); p.a = SIMD4(Float(ctx.num("amount") * ctx.unit), c.x, c.y, Float(ctx.num("falloff"))) } })

    static let godRays = EffectDefinition(
        id: "awi.godRays", name: "God Rays", category: .color, aeMatchNames: ["CC Light Rays"],
        summary: "Volumetric light streaming out of the bright parts toward a source point.",
        params: [.point("center", "Source", Vec2(0.5, 0.3)), .number("length", "Ray Length", 50, 0, 100, unit: "%"),
                 .number("intensity", "Intensity", 1.5, 0, 6, step: 0.01), .number("threshold", "Threshold", 30, 0, 95, unit: "%"),
                 .color("color", "Color", RGBA(1, 0.92, 0.75))],
        stage: .pixels { ctx in l5(ctx, 1) { p in
            let c = pt(ctx, "center")
            p.a = SIMD4(c.x, c.y, Float(ctx.num("length") / 100), Float(ctx.num("intensity")))
            p.b = ctx.effect.color("color", ctx.time).simd; p.c.x = Float(ctx.num("threshold") / 100) } })

    static let lightLeak = EffectDefinition(
        id: "awi.lightLeak", name: "Light Leak", category: .generate, aeMatchNames: [],
        summary: "Drifting warm film light leaks (animated).",
        params: [.number("intensity", "Intensity", 0.9, 0, 2, step: 0.01), .number("speed", "Speed", 1, 0, 6, step: 0.05),
                 .number("scale", "Size", 260, 30, 1200, unit: "px"), .angle("hue", "Hue Shift", 0), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in l5(ctx, 2) { p in
            p.a = SIMD4(Float(ctx.num("intensity")), Float(ctx.num("speed")), Float(ctx.num("scale") * ctx.unit), Float(ctx.num("hue") * .pi / 180))
            p.c.x = Float(ctx.num("seed")) } })

    static let oldFilm = EffectDefinition(
        id: "awi.oldFilm", name: "Old Film", category: .stylize, aeMatchNames: [],
        summary: "Grain, scratches, dust, gate flicker and sepia, changing every frame.",
        params: [.number("grain", "Grain", 0.15, 0, 0.6, step: 0.01), .number("scratches", "Scratches", 0.5, 0, 1, step: 0.01),
                 .number("dust", "Dust", 0.6, 0, 1, step: 0.01), .number("flicker", "Flicker", 0.3, 0, 1, step: 0.01),
                 .number("sepia", "Sepia", 0.7, 0, 1, step: 0.01), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in l5(ctx, 3) { p in
            p.a = SIMD4(Float(ctx.num("grain")), Float(ctx.num("scratches")), Float(ctx.num("dust")), Float(ctx.num("flicker")))
            p.b.x = Float(ctx.num("sepia")); p.c.x = Float(ctx.num("seed")) } })

    static let halation = EffectDefinition(
        id: "awi.halation", name: "Halation", category: .color, aeMatchNames: [],
        summary: "Film halation: a warm red glow bleeding around highlights.",
        params: [.number("threshold", "Threshold", 30, 0, 99, unit: "%"), .number("size", "Size", 20, 0, 200, unit: "px"),
                 .number("intensity", "Intensity", 1, 0, 4, step: 0.01), .color("tint", "Tint", RGBA(1, 0.25, 0.1))],
        margin: { e, t in e.number("size", t) },
        stage: .pixels { ctx in
            let hi = l5(ctx, 4) { p in p.a.x = Float(ctx.num("threshold") / 100); p.b = ctx.effect.color("tint", ctx.time).simd }
            let blur = ctx.gpu.gaussian(ctx, input: hi, sigma: max(0.5, ctx.num("size") * ctx.unit / 2))
            return l5(ctx, 5, aux: blur) { p in p.a.x = Float(ctx.num("intensity")) }
        })

    static let gradientMap = EffectDefinition(
        id: "awi.gradientMap", name: "Gradient Map", category: .color, aeMatchNames: [],
        summary: "Maps brightness to a two-color gradient (duotone posters, anime color looks).",
        params: [.color("dark", "Shadows", RGBA(hex: 0x1B0A3C)), .color("light", "Highlights", RGBA(hex: 0xFF8AD8)),
                 .number("mix", "Mix", 100, 0, 100, unit: "%"), .number("contrast", "Contrast", 1, 0.2, 3, step: 0.01)],
        stage: .pixels { ctx in l5(ctx, 6) { p in
            p.b = ctx.effect.color("dark", ctx.time).simd; p.c = ctx.effect.color("light", ctx.time).simd
            p.a = SIMD4(Float(ctx.num("mix") / 100), Float(ctx.num("contrast")), 0, 0) } })

    static let cinematicBars = EffectDefinition(
        id: "awi.cinematicBars", name: "Cinematic Bars", category: .generate, aeMatchNames: [],
        summary: "Letterbox bars for a widescreen movie look (animate the aspect to slide them in).",
        params: [.number("aspect", "Aspect Ratio", 2.39, 0.5, 4, step: 0.01), .number("softness", "Softness", 0, 0, 60, unit: "px"),
                 .number("offset", "Vertical Offset", 0, -500, 500, unit: "px"), .number("opacity", "Opacity", 100, 0, 100, unit: "%"),
                 .color("color", "Color", .black)],
        stage: .pixels { ctx in l5(ctx, 7) { p in
            p.a = SIMD4(Float(ctx.num("aspect")), Float(ctx.num("softness") * ctx.unit), Float(ctx.num("offset") * ctx.unit), Float(ctx.num("opacity") / 100))
            p.b = ctx.effect.color("color", ctx.time).simd } })

    static let lensBlur = EffectDefinition(
        id: "awi.lensBlur", name: "Lens Blur (Bokeh)", category: .blur, aeMatchNames: ["ADBE Camera Lens Blur"],
        summary: "Camera-style defocus with bright bokeh discs.",
        params: [.number("radius", "Blur Radius", 12, 0, 80, unit: "px"), .number("boost", "Highlight Boost", 1, 0, 4, step: 0.01),
                 .angle("rotation", "Iris Rotation", 0)],
        margin: { e, t in e.number("radius", t) },
        stage: .pixels { ctx in l5(ctx, 8) { p in
            p.a = SIMD4(Float(ctx.num("radius") * ctx.unit), Float(ctx.num("boost")), Float(ctx.num("rotation") * .pi / 180), 0) } })

    static let chromaticZoom = EffectDefinition(
        id: "awi.chromaticZoom", name: "Chromatic Zoom Blur", category: .blur, aeMatchNames: [],
        summary: "Zoom blur with split RGB streaks (velocity-edit favourite).",
        params: [.point("center", "Center", Vec2(0.5, 0.5)), .number("amount", "Amount", 25, 0, 100, unit: "%"),
                 .number("spread", "Color Spread", 0.4, 0, 1, step: 0.01)],
        stage: .pixels { ctx in l5(ctx, 9) { p in
            let c = pt(ctx, "center"); p.a = SIMD4(c.x, c.y, Float(ctx.num("amount") / 100 * 0.5), Float(ctx.num("spread"))) } })

    static let flicker = EffectDefinition(
        id: "awi.flicker", name: "Flicker", category: .color, aeMatchNames: [],
        summary: "Random brightness flicker (lights, glitches, horror).",
        params: [.number("amount", "Amount", 0.6, 0, 1, step: 0.01), .number("frequency", "Frequency", 12, 0.5, 60, unit: "/s"),
                 .number("smooth", "Smoothness", 0.3, 0, 1, step: 0.01), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in l5(ctx, 10) { p in
            p.a = SIMD4(Float(ctx.num("amount")), Float(ctx.num("frequency")), Float(ctx.num("smooth")), Float(ctx.num("seed"))) } })

    static let hueCycle = EffectDefinition(
        id: "awi.hueCycle", name: "Hue Cycle", category: .color, aeMatchNames: [],
        summary: "Rainbow color cycling over time (and optionally across the frame).",
        params: [.number("speed", "Speed", 90, -720, 720, unit: "°/s"), .angle("offset", "Offset", 0),
                 .number("spread", "Spatial Spread", 0, 0, 500)],
        stage: .pixels { ctx in l5(ctx, 11) { p in
            p.a = SIMD4(Float(ctx.num("speed")), Float(ctx.num("offset")), Float(ctx.num("spread") / max(ctx.unit, 1e-3)), 0) } })

    static let inkSketch = EffectDefinition(
        id: "awi.inkSketch", name: "Ink Sketch", category: .stylize, aeMatchNames: [],
        summary: "Anime line-art: dark ink outlines traced from the image, optional paper look.",
        params: [.number("strength", "Line Strength", 1, 0, 1, step: 0.01), .number("threshold", "Detail", 0.2, 0.02, 1, step: 0.01),
                 .number("paper", "Paper", 0, 0, 1, step: 0.01), .number("width", "Line Width", 1.5, 0.5, 6, step: 0.1, unit: "px")],
        stage: .pixels { ctx in l5(ctx, 12) { p in
            p.a = SIMD4(Float(ctx.num("strength")), Float(ctx.num("threshold")), Float(ctx.num("paper")), Float(ctx.num("width") * ctx.unit)) } })

    static let retroDither = EffectDefinition(
        id: "awi.retroDither", name: "Retro Dither", category: .stylize, aeMatchNames: [],
        summary: "Pixelated ordered dithering with an optional handheld-console palette.",
        params: [.number("pixel", "Pixel Size", 4, 1, 32, step: 1, unit: "px"), .number("levels", "Color Levels", 4, 2, 16, step: 1),
                 .number("palette", "Console Palette", 0, 0, 1, step: 0.01)],
        stage: .pixels { ctx in l5(ctx, 13) { p in
            p.a = SIMD4(Float(max(1, ctx.num("pixel") * ctx.unit)), Float(ctx.num("levels")), Float(ctx.num("palette")), 0) } })

    // MARK: Motion behaviours (Alight Motion "Swing / Oscillate / Pulse / Spin / Bounce / Random Jitter")

    static let swing = EffectDefinition(
        id: "awi.swing", name: "Swing", category: .motion, aeMatchNames: [],
        summary: "Pendulum rotation back and forth around the anchor point.",
        params: [.number("angle", "Angle", 15, 0, 180, unit: "°"), .number("frequency", "Frequency", 1, 0.05, 10, step: 0.05, unit: "/s"),
                 .angle("phase", "Phase", 0)],
        stage: .transform { e, t in
            (0, 0, e.number("angle", t) * sin(2 * .pi * e.number("frequency", t) * t + e.number("phase", t) * .pi / 180), 1) })

    static let oscillate = EffectDefinition(
        id: "awi.oscillate", name: "Oscillate", category: .motion, aeMatchNames: [],
        summary: "Smooth back-and-forth movement along a direction.",
        params: [.number("distance", "Distance", 40, 0, 1000, unit: "px"), .angle("direction", "Direction", 0),
                 .number("frequency", "Frequency", 1, 0.05, 10, step: 0.05, unit: "/s"), .angle("phase", "Phase", 0)],
        stage: .transform { e, t in
            let s = e.number("distance", t) * sin(2 * .pi * e.number("frequency", t) * t + e.number("phase", t) * .pi / 180)
            let a = e.number("direction", t) * .pi / 180
            return (s * cos(a), s * sin(a), 0, 1) })

    static let pulse = EffectDefinition(
        id: "awi.pulse", name: "Pulse", category: .motion, aeMatchNames: [],
        summary: "Rhythmic scale throb (set the BPM to match the music).",
        params: [.number("amount", "Amount", 10, 0, 100, unit: "%"), .number("bpm", "BPM", 100, 20, 300, step: 1),
                 .number("sharpness", "Sharpness", 3, 1, 12, step: 0.1)],
        stage: .transform { e, t in
            let beat = (t * e.number("bpm", t) / 60).truncatingRemainder(dividingBy: 1)
            let k = pow(1 - beat, e.number("sharpness", t))
            return (0, 0, 0, 1 + e.number("amount", t) / 100 * k) })

    static let spin = EffectDefinition(
        id: "awi.spin", name: "Spin", category: .motion, aeMatchNames: [],
        summary: "Continuous rotation.",
        params: [.number("speed", "Speed", 90, -1440, 1440, unit: "°/s"), .angle("offset", "Start Angle", 0)],
        stage: .transform { e, t in (0, 0, e.number("speed", t) * t + e.number("offset", t), 1) })

    static let bounce = EffectDefinition(
        id: "awi.bounce", name: "Bounce", category: .motion, aeMatchNames: [],
        summary: "Hopping up and down like a ball (squash on landing).",
        params: [.number("height", "Height", 60, 0, 1000, unit: "px"), .number("frequency", "Bounces per Second", 1.5, 0.1, 10, step: 0.05),
                 .number("squash", "Squash", 8, 0, 40, unit: "%")],
        stage: .transform { e, t in
            let ph = (t * e.number("frequency", t)).truncatingRemainder(dividingBy: 1)
            let h = 4 * ph * (1 - ph)
            let land = max(0, 1 - h * 6)
            // Squashed on landing, slightly stretched in the air.
            return (0, -h * e.number("height", t), 0, 1 - land * e.number("squash", t) / 100 + (1 - land) * e.number("squash", t) / 300) })

    static let jitter = EffectDefinition(
        id: "awi.jitter", name: "Random Jitter", category: .motion, aeMatchNames: [],
        summary: "Stepped random jumps (stop-motion / hand-made feel).",
        params: [.number("amount", "Position", 6, 0, 200, unit: "px"), .number("rotation", "Rotation", 2, 0, 45, unit: "°"),
                 .number("rate", "Steps per Second", 8, 1, 60, step: 1), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .transform { e, t in
            let step = (t * e.number("rate", t)).rounded(.down), s = e.number("seed", t)
            func r(_ k: Double) -> Double { let x = sin(step * 12.9898 + s * 78.233 + k * 37.719) * 43758.5453; return (x - x.rounded(.down)) * 2 - 1 }
            return (r(1) * e.number("amount", t), r(2) * e.number("amount", t), r(3) * e.number("rotation", t), 1) })
}
