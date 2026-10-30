import Foundation
import Metal
import simd

/// Batch 11: Alight Motion-style repeaters (grid, line, radial, scatter, mirror tile, zoom tunnel, echo offset),
/// opacity tools (blink, pulse, dissolve, feather, vignette alpha, linear fade, flicker) and matte/key tools
/// (advanced chroma key, spill cleaner, matte choker, unmultiply, color range key, luma matte, alpha levels,
/// edge refine, remove color matting).
extension EffectRegistry {
    static let batch11: [EffectDefinition] = [
        repeatGrid11, repeatLine11, repeatRadial11, scatterField11, mirrorTile11, zoomTunnel11, echoOffset11,
        blink11, pulseOpacity11, randomDissolve11, featherEdges11, vignetteAlpha11, linearAlphaFade11, opacityFlicker11,
        advancedChromaKey11, spillCleaner11, matteChoker11, colorRangeKey11, lumaMatteSoft11,
        alphaLevels11, edgeRefine11, removeColorMatting11,
    ]

    private static func r11(_ ctx: EffectContext, _ mode: UInt32, src: MTLTexture? = nil, aux: MTLTexture? = nil,
                            _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        let s = src ?? ctx.input
        ctx.gpu.run("fxRepeat11", ctx.cb, textures: [s, out, aux ?? s], params: p, grid: out)
        return out
    }
    private static func pt11(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    /// Unit direction for an angle in degrees (0 = right, 90 = down).
    private static func dir11(_ deg: Double) -> SIMD2<Float> {
        let a = deg * .pi / 180
        return SIMD2(Float(cos(a)), Float(sin(a)))
    }

    // MARK: Repeaters

    static let repeatGrid11 = EffectDefinition(
        id: "awi11.repeatGrid", name: "Repeat Grid", category: .motion, aeMatchNames: [],
        summary: "Tiles copies of the layer in rows and columns with a gap and a brick-style row offset.",
        params: [.number("cols", "Columns", 2, 1, 8, step: 1), .number("rows", "Rows", 2, 1, 8, step: 1),
                 .number("spacing", "Spacing", 10, 0, 50, unit: "%"), .number("rowOffset", "Row Offset", 0, 0, 100, unit: "%")],
        stage: .pixels { ctx in r11(ctx, 0) { p in
            p.a = SIMD4(Float(ctx.num("cols")), Float(ctx.num("rows")), Float(ctx.num("spacing") / 100), Float(ctx.num("rowOffset") / 100)) } })

    static let repeatLine11 = EffectDefinition(
        id: "awi11.repeatLine", name: "Repeat Line", category: .motion, aeMatchNames: [],
        summary: "Copies in a row; each copy steps along a direction and shrinks, rotates and fades.",
        params: [.number("count", "Copies", 4, 1, 12, step: 1), .number("spacing", "Spacing", 30, 0, 200, unit: "px"),
                 .angle("direction", "Direction", 0), .number("scaleFall", "Scale Falloff", 15, 0, 50, unit: "%"),
                 .angle("rotation", "Rotation / Copy", 10), .number("opacityFall", "Opacity Falloff", 25, 0, 90, unit: "%")],
        margin: { e, t in min(600, max(0, e.number("spacing", t)) * max(0, e.number("count", t) - 1)) },
        stage: .pixels { ctx in r11(ctx, 1) { p in
            let d = dir11(ctx.num("direction"))
            p.a = SIMD4(Float(ctx.num("count")), Float(ctx.num("spacing") * ctx.unit), Float(ctx.num("scaleFall") / 100), Float(ctx.num("opacityFall") / 100))
            p.b = SIMD4(d.x, d.y, Float(ctx.num("rotation") * .pi / 180), 0) } })

    static let repeatRadial11 = EffectDefinition(
        id: "awi11.repeatRadial", name: "Repeat Radial", category: .motion, aeMatchNames: [],
        summary: "Scaled copies arranged in a ring around the layer, optionally turned to face outward.",
        params: [.number("count", "Copies", 6, 1, 24, step: 1), .number("radius", "Radius", 60, 0, 300, unit: "px"),
                 .number("scale", "Copy Scale", 40, 5, 100, unit: "%"), .angle("phase", "Rotate Ring", 0),
                 .toggle("orient", "Rotate Copies", true)],
        margin: { e, t in min(600, max(0, e.number("radius", t))) },
        stage: .pixels { ctx in r11(ctx, 2) { p in
            p.a = SIMD4(Float(ctx.num("count")), Float(ctx.num("radius") * ctx.unit), Float(ctx.num("scale") / 100), Float(ctx.num("phase") * .pi / 180))
            p.b.x = ctx.effect.bool("orient") ? 1 : 0 } })

    static let scatterField11 = EffectDefinition(
        id: "awi11.scatterField", name: "Scatter Field", category: .motion, aeMatchNames: [],
        summary: "Randomly placed, sized and rotated copies of the layer (change the seed for a new layout).",
        params: [.number("count", "Copies", 16, 1, 48, step: 1), .number("spread", "Spread", 80, 0, 400, unit: "px"),
                 .number("scale", "Copy Scale", 35, 5, 100, unit: "%"), .angle("rotation", "Random Rotation", 45),
                 .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        margin: { e, t in min(600, max(0, e.number("spread", t))) },
        stage: .pixels { ctx in r11(ctx, 3) { p in
            p.a = SIMD4(Float(ctx.num("count")), Float(ctx.num("spread") * ctx.unit), Float(ctx.num("scale") / 100), Float(ctx.num("seed")))
            p.b.x = Float(ctx.num("rotation") * .pi / 180) } })

    static let mirrorTile11 = EffectDefinition(
        id: "awi11.mirrorTile", name: "Mirror Tile", category: .motion, aeMatchNames: [],
        summary: "4-way mirrored tiling: every neighbouring tile is flipped so the seams match.",
        params: [.number("tiles", "Tiles", 2, 1, 8, step: 1), .number("offsetX", "Offset X", 0, -50, 50, unit: "%"),
                 .number("offsetY", "Offset Y", 0, -50, 50, unit: "%")],
        stage: .pixels { ctx in r11(ctx, 4) { p in
            p.a = SIMD4(Float(ctx.num("tiles")), Float(ctx.num("offsetX") / 100), Float(ctx.num("offsetY") / 100), 0) } })

    static let zoomTunnel11 = EffectDefinition(
        id: "awi11.zoomTunnel", name: "Infinite Zoom Tunnel", category: .motion, aeMatchNames: [],
        summary: "Nested shrinking copies that zoom endlessly toward the center (animated).",
        params: [.number("copies", "Copies", 6, 1, 16, step: 1), .number("step", "Scale Step", 60, 20, 95, unit: "%"),
                 .number("speed", "Speed", 0.5, 0, 4, step: 0.01)],
        stage: .pixels { ctx in r11(ctx, 5) { p in
            p.a = SIMD4(Float(ctx.num("copies")), Float(ctx.num("step") / 100), Float(ctx.num("speed")), 0) } })

    static let echoOffset11 = EffectDefinition(
        id: "awi11.echoOffset", name: "Echo Offset", category: .motion, aeMatchNames: [],
        summary: "Spatial echo: fading copies stepped along a direction.",
        params: [.number("copies", "Copies", 5, 1, 16, step: 1), .number("distance", "Distance", 12, 0, 100, unit: "px"),
                 .angle("direction", "Direction", 45), .number("fade", "Fade", 40, 0, 95, unit: "%")],
        margin: { e, t in min(600, max(0, e.number("distance", t)) * max(1, e.number("copies", t))) },
        stage: .pixels { ctx in r11(ctx, 6) { p in
            let d = dir11(ctx.num("direction"))
            p.a = SIMD4(Float(ctx.num("copies")), Float(ctx.num("distance") * ctx.unit), Float(ctx.num("fade") / 100), 0)
            p.b = SIMD4(d.x, d.y, 0, 0) } })

    // MARK: Opacity

    static let blink11 = EffectDefinition(
        id: "awi11.blink", name: "Blink", category: .stylize, aeMatchNames: [],
        summary: "Switches the layer on and off at a steady rate.",
        params: [.number("rate", "Rate", 1, 0, 10, step: 0.05, unit: "Hz"), .number("duty", "On Time", 30, 5, 95, unit: "%"),
                 .number("minOpacity", "Off Opacity", 0, 0, 100, unit: "%")],
        stage: .pixels { ctx in r11(ctx, 7) { p in
            p.a = SIMD4(Float(ctx.num("rate")), Float(ctx.num("duty") / 100), Float(ctx.num("minOpacity") / 100), 0) } })

    static let pulseOpacity11 = EffectDefinition(
        id: "awi11.pulseOpacity", name: "Pulse Opacity", category: .stylize, aeMatchNames: [],
        summary: "Smoothly breathes the opacity between a minimum and maximum.",
        params: [.number("speed", "Speed", 1, 0, 8, step: 0.05, unit: "Hz"), .number("min", "Minimum", 20, 0, 100, unit: "%"),
                 .number("max", "Maximum", 100, 0, 100, unit: "%"), .angle("phase", "Phase", 0)],
        stage: .pixels { ctx in r11(ctx, 8) { p in
            p.a = SIMD4(Float(ctx.num("speed")), Float(ctx.num("min") / 100), Float(ctx.num("max") / 100), Float(ctx.num("phase") * .pi / 180)) } })

    static let randomDissolve11 = EffectDefinition(
        id: "awi11.randomDissolve", name: "Random Dissolve", category: .stylize, aeMatchNames: [],
        summary: "Dissolves the layer away in random grains (animate the amount for a transition).",
        params: [.number("amount", "Amount", 50, 0, 100, unit: "%"), .number("grain", "Grain Size", 2, 1, 20, unit: "px"),
                 .number("seed", "Random Seed", 1, 0, 100, step: 1), .toggle("animate", "Animate Grain", false)],
        stage: .pixels { ctx in r11(ctx, 9) { p in
            p.a = SIMD4(Float(ctx.num("amount") / 100), Float(max(1, ctx.num("grain") * ctx.unit)), Float(ctx.num("seed")), ctx.effect.bool("animate") ? 1 : 0) } })

    static let featherEdges11 = EffectDefinition(
        id: "awi11.featherEdges", name: "Feather Edges", category: .keying, aeMatchNames: [],
        summary: "Softens the layer's alpha edge inward without growing the shape.",
        params: [.number("radius", "Feather", 10, 0, 60, unit: "px")],
        stage: .pixels { ctx in
            let blur = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: max(0.5, ctx.num("radius") * ctx.unit / 2))
            return r11(ctx, 10, aux: blur) { _ in }
        })

    static let vignetteAlpha11 = EffectDefinition(
        id: "awi11.vignetteAlpha", name: "Vignette Alpha", category: .stylize, aeMatchNames: [],
        summary: "Radial fade to transparent toward the edges.",
        params: [.point("center", "Center", Vec2(0.5, 0.5)), .number("radius", "Radius", 70, 10, 150, unit: "%"),
                 .number("softness", "Softness", 40, 1, 100, unit: "%")],
        stage: .pixels { ctx in r11(ctx, 11) { p in
            let c = pt11(ctx, "center")
            p.a = SIMD4(c.x, c.y, Float(ctx.num("radius") / 100), Float(ctx.num("softness") / 100)) } })

    static let linearAlphaFade11 = EffectDefinition(
        id: "awi11.linearAlphaFade", name: "Linear Alpha Fade", category: .stylize, aeMatchNames: [],
        summary: "Linear gradient fade to transparent along a direction.",
        params: [.angle("direction", "Direction", 90), .number("start", "Start", 20, 0, 100, unit: "%"),
                 .number("length", "Fade Length", 60, 1, 100, unit: "%")],
        stage: .pixels { ctx in r11(ctx, 21) { p in
            let d = dir11(ctx.num("direction"))
            p.a = SIMD4(d.x, d.y, Float(ctx.num("start") / 100), Float(ctx.num("length") / 100)) } })

    static let opacityFlicker11 = EffectDefinition(
        id: "awi11.opacityFlicker", name: "Opacity Flicker", category: .stylize, aeMatchNames: [],
        summary: "Random stepped opacity drops, like a failing light.",
        params: [.number("speed", "Speed", 12, 1, 30, step: 0.5, unit: "Hz"), .number("amount", "Amount", 60, 0, 100, unit: "%"),
                 .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in r11(ctx, 22) { p in
            p.a = SIMD4(Float(ctx.num("speed")), Float(ctx.num("amount") / 100), Float(ctx.num("seed")), 0) } })

    // MARK: Matte / Key

    static let advancedChromaKey11 = EffectDefinition(
        id: "awi11.advancedChromaKey", name: "Advanced Chroma Key", category: .keying, aeMatchNames: [],
        summary: "Chroma-distance key with tolerance, edge softness and built-in spill suppression.",
        params: [.color("key", "Key Color", RGBA(0.1, 0.9, 0.2)), .number("tolerance", "Tolerance", 25, 0, 100, unit: "%"),
                 .number("softness", "Softness", 10, 0, 100, unit: "%"), .number("spill", "Spill Suppression", 50, 0, 100, unit: "%")],
        stage: .pixels { ctx in r11(ctx, 12) { p in
            p.b = ctx.effect.color("key", ctx.time).simd
            p.a = SIMD4(Float(ctx.num("tolerance") / 100), Float(ctx.num("softness") / 100), Float(ctx.num("spill") / 100), 0) } })

    static let spillCleaner11 = EffectDefinition(
        id: "awi11.spillCleaner", name: "Key Spill Cleaner", category: .keying, aeMatchNames: [],
        summary: "Removes the key color's tint from edges and reflections, with optional luma compensation.",
        params: [.color("key", "Key Color", RGBA(0.1, 0.9, 0.2)), .number("amount", "Amount", 80, 0, 100, unit: "%"),
                 .number("luma", "Luma Compensation", 0, 0, 100, unit: "%")],
        stage: .pixels { ctx in r11(ctx, 13) { p in
            p.b = ctx.effect.color("key", ctx.time).simd
            p.a = SIMD4(Float(ctx.num("amount") / 100), Float(ctx.num("luma") / 100), 0, 0) } })

    static let matteChoker11 = EffectDefinition(
        id: "awi11.matteChoker", name: "Matte Choker", category: .keying, aeMatchNames: [],
        summary: "Shrinks (positive) or grows (negative) the alpha matte, then softens it.",
        params: [.number("choke", "Choke", 3, -20, 20, step: 0.1, unit: "px"), .number("softness", "Softness", 1, 0, 20, step: 0.1, unit: "px")],
        margin: { e, t in max(0, -e.number("choke", t)) + max(0, e.number("softness", t)) * 2 },
        stage: .pixels { ctx in
            let m = r11(ctx, 14) { p in p.a.x = Float(ctx.num("choke") * ctx.unit) }
            let s = ctx.num("softness") * ctx.unit / 2
            return s > 0.05 ? ctx.gpu.gaussian(ctx, input: m, sigma: s) : m
        })

    static let unmultiply11 = EffectDefinition(
        id: "awi11.unmultiply", name: "Unmultiply", category: .keying, aeMatchNames: [],
        summary: "Turns black into transparency (for flares, fire and light footage shot on black).",
        params: [.number("amount", "Amount", 100, 0, 100, unit: "%"), .number("gamma", "Alpha Gamma", 1, 0.2, 3, step: 0.01)],
        stage: .pixels { ctx in r11(ctx, 15) { p in
            p.a = SIMD4(Float(ctx.num("amount") / 100), Float(ctx.num("gamma")), 0, 0) } })

    static let colorRangeKey11 = EffectDefinition(
        id: "awi11.colorRangeKey", name: "Color Range Key", category: .keying, aeMatchNames: [],
        summary: "Keys out a hue range above minimum saturation and brightness.",
        params: [.angle("hue", "Hue", 120), .number("width", "Hue Width", 40, 0, 180, unit: "°"),
                 .number("satMin", "Min Saturation", 20, 0, 100, unit: "%"), .number("valMin", "Min Brightness", 10, 0, 100, unit: "%"),
                 .toggle("invert", "Invert", false)],
        stage: .pixels { ctx in r11(ctx, 16) { p in
            var h = ctx.num("hue").truncatingRemainder(dividingBy: 360); if h < 0 { h += 360 }
            p.a = SIMD4(Float(h), Float(ctx.num("width")), Float(ctx.num("satMin") / 100), Float(ctx.num("valMin") / 100))
            p.i.y = ctx.effect.bool("invert") ? 1 : 0 } })

    static let lumaMatteSoft11 = EffectDefinition(
        id: "awi11.lumaMatteSoft", name: "Luma Matte Soft", category: .keying, aeMatchNames: [],
        summary: "Brightness becomes alpha with a soft in/out ramp.",
        params: [.number("in", "Black Point", 10, 0, 100, unit: "%"), .number("out", "White Point", 60, 0, 100, unit: "%"),
                 .toggle("invert", "Invert", false)],
        stage: .pixels { ctx in r11(ctx, 17) { p in
            p.a = SIMD4(Float(ctx.num("in") / 100), Float(ctx.num("out") / 100), 0, 0)
            p.i.y = ctx.effect.bool("invert") ? 1 : 0 } })

    static let alphaLevels11 = EffectDefinition(
        id: "awi11.alphaLevels", name: "Alpha Levels", category: .keying, aeMatchNames: [],
        summary: "Levels on the alpha channel: input black/white, gamma and output range.",
        params: [.number("inBlack", "Input Black", 30, 0, 100, unit: "%"), .number("inWhite", "Input White", 70, 0, 100, unit: "%"),
                 .number("gamma", "Gamma", 1, 0.1, 4, step: 0.01), .number("outBlack", "Output Black", 0, 0, 100, unit: "%"),
                 .number("outWhite", "Output White", 80, 0, 100, unit: "%")],
        stage: .pixels { ctx in r11(ctx, 18) { p in
            p.a = SIMD4(Float(ctx.num("inBlack") / 100), Float(ctx.num("inWhite") / 100), Float(ctx.num("gamma")), Float(ctx.num("outBlack") / 100))
            p.b.x = Float(ctx.num("outWhite") / 100) } })

    static let edgeRefine11 = EffectDefinition(
        id: "awi11.edgeRefine", name: "Edge Refine", category: .keying, aeMatchNames: [],
        summary: "Smooths jagged matte edges, then re-sharpens and shifts them.",
        params: [.number("smooth", "Smooth", 5, 0, 20, step: 0.1, unit: "px"), .number("contrast", "Contrast", 50, 0, 100, unit: "%"),
                 .number("shift", "Shift Edge", 0, -100, 100, unit: "%")],
        margin: { e, t in max(0, e.number("smooth", t)) * 1.5 },
        stage: .pixels { ctx in
            let blur = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: max(0.5, ctx.num("smooth") * ctx.unit / 2))
            return r11(ctx, 19, aux: blur) { p in
                p.a = SIMD4(Float(ctx.num("contrast") / 100), Float(ctx.num("shift") / 100), 0, 0) }
        })

    static let removeColorMatting11 = EffectDefinition(
        id: "awi11.removeColorMatting", name: "Remove Color Matting", category: .keying, aeMatchNames: [],
        summary: "Removes a matte/background color, turning it into transparency and restoring the true colors.",
        params: [.color("matte", "Matte Color", RGBA(0.08, 0.06, 0.12)), .number("amount", "Amount", 100, 0, 100, unit: "%")],
        stage: .pixels { ctx in r11(ctx, 20) { p in
            p.b = ctx.effect.color("matte", ctx.time).simd
            p.a.x = Float(ctx.num("amount") / 100) } })
}
