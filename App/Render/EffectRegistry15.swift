import Foundation
import Metal
import simd

/// Batch 15: blur, sharpen & glow 2 — hexagon bokeh, vortex, smear, inner / edge / luma-mask blur, minimax,
/// bilateral smoothing, channel blur, camera-shake blur, radial / spin / linear streaks, prism glow, dream bloom,
/// soft glow, dark glow, hue-keyed glow, neon bloom, starglow, light wrap, diffusion, clarity, high pass and structure.
extension EffectRegistry {
    static let batch15: [EffectDefinition] = [
        hexagonBlur15, vortexBlur15, smear15, innerBlur15, edgeBlur15, maskBlur15, minimax15, bilateral15, channelBlur15,
        shakeBlur15, radialStreaks15, spinStreaks15, linearStreaks15,
        prismGlow15, dreamBloom15, softGlow15, darkGlow15, hueGlow15, neonBloom15, starglow15, lightWrap15, diffusion15,
        clarity15, highPass15, structure15,
    ]

    private static func r15(_ ctx: EffectContext, _ mode: UInt32, src: MTLTexture? = nil, aux: MTLTexture? = nil,
                            mask: MTLTexture? = nil, _ fill: (inout EffectParams) -> Void = { _ in }) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        let s = src ?? ctx.input
        ctx.gpu.run("fxBlur15", ctx.cb, textures: [s, out, aux ?? s, mask ?? s], params: p, grid: out)
        return out
    }
    private static func pt15(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    private static func n15(_ ctx: EffectContext, _ k: String, _ scale: Double = 1) -> Float { Float(ctx.num(k) * scale) }
    private static func px15(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * ctx.unit) }
    private static func rad15(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * .pi / 180) }
    private static func col15(_ ctx: EffectContext, _ k: String) -> SIMD4<Float> { ctx.effect.color(k, ctx.time).simd }
    private static func dir15(_ ctx: EffectContext, _ angleKey: String, _ lenKey: String) -> SIMD2<Float> {
        let a = ctx.num(angleKey) * .pi / 180, l = ctx.num(lenKey) * ctx.unit
        return SIMD2(Float(cos(a) * l), Float(sin(a) * l))
    }
    /// Gaussian blur with a radius in layer pixels (sigma = radius / 2).
    private static func blur15(_ ctx: EffectContext, _ tex: MTLTexture, _ radius: Double) -> MTLTexture {
        ctx.gpu.gaussian(ctx, input: tex, sigma: max(0.3, radius * ctx.unit / 2))
    }
    private static func pct15(_ id: String, _ name: String, _ def: Double, _ lo: Double = 0, _ hi: Double = 100) -> ParamDef {
        .number(id, name, def, lo, hi, unit: "%")
    }

    // MARK: Blurs

    static let hexagonBlur15 = EffectDefinition(
        id: "awi15.hexagonBlur", name: "Hexagon Blur", category: .blur, aeMatchNames: [],
        summary: "Lens blur with hexagonal aperture bokeh; highlights bloom into bright hexagons.",
        params: [.number("radius", "Radius", 10, 0, 100, step: 0.1, unit: "px"), .number("boost", "Highlight Boost", 3, 0, 10, step: 0.01),
                 .angle("rotation", "Aperture Rotation", 0)],
        margin: { e, t in e.number("radius", t) },
        stage: .pixels { ctx in r15(ctx, 0) { p in p.a = SIMD4(px15(ctx, "radius"), n15(ctx, "boost"), rad15(ctx, "rotation"), 0) } })

    static let vortexBlur15 = EffectDefinition(
        id: "awi15.vortexBlur", name: "Vortex Blur", category: .blur, aeMatchNames: [],
        summary: "Rotational blur that is strongest at the center and fades out like a whirlpool.",
        params: [.point("center", "Center", Vec2(0.5, 0.5)), .number("angle", "Angle", 60, 0, 360, step: 0.1, unit: "°"),
                 .number("radius", "Falloff Radius", 80, 5, 400, unit: "px")],
        stage: .pixels { ctx in r15(ctx, 1) { p in
            let ce = pt15(ctx, "center")
            p.a = SIMD4(ce.x, ce.y, rad15(ctx, "angle"), px15(ctx, "radius")) } })

    static let smear15 = EffectDefinition(
        id: "awi15.smear", name: "Smear", category: .blur, aeMatchNames: [],
        summary: "Drags bright pixels along a direction like wet paint (luminance-driven smear).",
        params: [.number("length", "Length", 30, 0, 200, unit: "px"), .angle("angle", "Direction", 0),
                 pct15("decay", "Decay", 40), pct15("threshold", "Threshold", 30, 0, 95)],
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in r15(ctx, 2) { p in
            let d = dir15(ctx, "angle", "length")
            p.a = SIMD4(d.x, d.y, n15(ctx, "decay", 0.01), n15(ctx, "threshold", 0.01)) } })

    static let innerBlur15 = EffectDefinition(
        id: "awi15.innerBlur", name: "Inner Blur", category: .blur, aeMatchNames: [],
        summary: "Blurs the contents but keeps the layer's alpha edge crisp.",
        params: [.number("radius", "Radius", 8, 0, 100, step: 0.1, unit: "px"), pct15("amount", "Amount", 100)],
        stage: .pixels { ctx in
            let b = blur15(ctx, ctx.input, ctx.num("radius"))
            return r15(ctx, 3, aux: b) { p in p.a.x = n15(ctx, "amount", 0.01) }
        })

    static let edgeBlur15 = EffectDefinition(
        id: "awi15.edgeBlur", name: "Edge Blur", category: .blur, aeMatchNames: [],
        summary: "Softens only the edges (detected contrast) and leaves flat areas sharp.",
        params: [.number("radius", "Radius", 6, 0, 50, step: 0.1, unit: "px"), pct15("threshold", "Edge Threshold", 20, 0, 200),
                 .number("width", "Detect Width", 2, 0.5, 8, step: 0.1, unit: "px"), pct15("amount", "Amount", 100)],
        margin: { e, t in e.number("radius", t) },
        stage: .pixels { ctx in
            let edges = r15(ctx, 4) { p in p.a = SIMD4(px15(ctx, "width"), n15(ctx, "threshold", 0.01), 0, 0) }
            let soft = blur15(ctx, edges, ctx.num("radius"))
            let b = blur15(ctx, ctx.input, ctx.num("radius"))
            return r15(ctx, 5, aux: b, mask: soft) { p in p.a.x = n15(ctx, "amount", 0.02) }
        })

    static let maskBlur15 = EffectDefinition(
        id: "awi15.maskBlur", name: "Luma Mask Blur", category: .blur, aeMatchNames: [],
        summary: "Blurs only the bright (or, inverted, the dark) parts of the image.",
        params: [.number("radius", "Radius", 8, 0, 50, step: 0.1, unit: "px"), pct15("threshold", "Threshold", 50),
                 pct15("softness", "Softness", 15), .toggle("invert", "Blur Darks", false)],
        margin: { e, t in e.number("radius", t) },
        stage: .pixels { ctx in
            let m = r15(ctx, 6) { p in
                p.a = SIMD4(n15(ctx, "threshold", 0.01), n15(ctx, "softness", 0.01), 0, 0)
                p.i.y = ctx.effect.bool("invert") ? 1 : 0 }
            let b = blur15(ctx, ctx.input, ctx.num("radius"))
            return r15(ctx, 5, aux: b, mask: m) { p in p.a.x = 1 }
        })

    static let minimax15 = EffectDefinition(
        id: "awi15.minimax", name: "Minimax", category: .blur, aeMatchNames: [],
        summary: "Spreads the brightest (maximum) or darkest (minimum) color over a radius.",
        params: [.number("radius", "Radius", 3, 0, 30, step: 0.1, unit: "px"), .choice("operation", "Operation", ["Maximum", "Minimum"], 0)],
        margin: { e, t in e.number("radius", t) },
        stage: .pixels { ctx in
            let op: UInt32 = ctx.effect.choice("operation") == 1 ? 1 : 0
            let h = r15(ctx, 7) { p in p.a.x = px15(ctx, "radius"); p.b = SIMD4(1, 0, 0, 0); p.i.y = op }
            return r15(ctx, 7, src: h) { p in p.a.x = px15(ctx, "radius"); p.b = SIMD4(0, 1, 0, 0); p.i.y = op }
        })

    static let bilateral15 = EffectDefinition(
        id: "awi15.bilateral", name: "Bilateral Smooth", category: .blur, aeMatchNames: [],
        summary: "Edge-preserving smoothing (skin retouch): flattens texture without blurring edges.",
        params: [.number("radius", "Radius", 6, 1, 30, step: 0.1, unit: "px"), pct15("tolerance", "Tolerance", 40), pct15("amount", "Amount", 100)],
        stage: .pixels { ctx in r15(ctx, 8) { p in
            p.a = SIMD4(px15(ctx, "radius") / 3, n15(ctx, "tolerance", 0.015), n15(ctx, "amount", 0.01), 0) } })

    static let channelBlur15 = EffectDefinition(
        id: "awi15.channelBlur", name: "Channel Blur", category: .blur, aeMatchNames: [],
        summary: "Separate blur amounts for the red, green and blue channels.",
        params: [.number("red", "Red Blurriness", 6, 0, 60, step: 0.1, unit: "px"), .number("green", "Green Blurriness", 0, 0, 60, step: 0.1, unit: "px"),
                 .number("blue", "Blue Blurriness", 12, 0, 60, step: 0.1, unit: "px")],
        margin: { e, t in max(e.number("red", t), e.number("green", t), e.number("blue", t)) },
        stage: .pixels { ctx in
            func ch(_ k: String) -> MTLTexture { ctx.num(k) > 0.05 ? blur15(ctx, ctx.input, ctx.num(k)) : ctx.input }
            let rg = r15(ctx, 9, src: ch("red"), aux: ch("green"))
            return r15(ctx, 10, src: rg, aux: ch("blue"))
        })

    static let shakeBlur15 = EffectDefinition(
        id: "awi15.shakeBlur", name: "Camera Shake Blur", category: .blur, aeMatchNames: [],
        summary: "Motion blur along a wandering hand-held camera path (animated).",
        params: [.number("amplitude", "Amplitude", 12, 0, 60, step: 0.1, unit: "px"), pct15("shutter", "Shutter", 50),
                 .number("speed", "Speed", 4, 0, 20, step: 0.01, unit: "Hz")],
        margin: { e, t in e.number("amplitude", t) * 1.2 },
        stage: .pixels { ctx in r15(ctx, 11) { p in
            p.a = SIMD4(px15(ctx, "amplitude"), n15(ctx, "shutter", 0.01), n15(ctx, "speed"), 0) } })

    // MARK: Streaks

    static let radialStreaks15 = EffectDefinition(
        id: "awi15.radialStreaks", name: "Radial Streaks", category: .blur, aeMatchNames: [],
        summary: "Zoom-burst light streaks shooting outward from the highlights.",
        params: [.point("center", "Center", Vec2(0.5, 0.5)), pct15("length", "Length", 30),
                 pct15("threshold", "Threshold", 50, 0, 95), .number("intensity", "Intensity", 1.5, 0, 5, step: 0.01),
                 .color("tint", "Tint", RGBA(1, 0.95, 0.85))],
        margin: { e, t in e.number("length", t) * 2 },
        stage: .pixels { ctx in r15(ctx, 12) { p in
            let ce = pt15(ctx, "center")
            p.a = SIMD4(ce.x, ce.y, n15(ctx, "length", 0.01), n15(ctx, "threshold", 0.01))
            p.b.x = n15(ctx, "intensity"); p.c = col15(ctx, "tint") } })

    static let spinStreaks15 = EffectDefinition(
        id: "awi15.spinStreaks", name: "Spin Streaks", category: .blur, aeMatchNames: [],
        summary: "Highlights trail around a center in circular light arcs.",
        params: [.point("center", "Center", Vec2(0.5, 0.5)), .number("angle", "Arc Angle", 20, 0, 180, step: 0.1, unit: "°"),
                 pct15("threshold", "Threshold", 50, 0, 95), .number("intensity", "Intensity", 1.5, 0, 5, step: 0.01),
                 .color("tint", "Tint", RGBA(0.85, 0.92, 1))],
        stage: .pixels { ctx in r15(ctx, 13) { p in
            let ce = pt15(ctx, "center")
            p.a = SIMD4(ce.x, ce.y, rad15(ctx, "angle"), n15(ctx, "threshold", 0.01))
            p.b.x = n15(ctx, "intensity"); p.c = col15(ctx, "tint") } })

    static let linearStreaks15 = EffectDefinition(
        id: "awi15.linearStreaks", name: "Linear Streaks", category: .blur, aeMatchNames: [],
        summary: "Straight two-sided light streaks through the highlights at any angle.",
        params: [.number("length", "Length", 60, 0, 300, unit: "px"), .angle("angle", "Angle", 0),
                 pct15("threshold", "Threshold", 50, 0, 95), .number("intensity", "Intensity", 1.5, 0, 5, step: 0.01),
                 .color("tint", "Tint", RGBA(1, 0.9, 0.8))],
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in r15(ctx, 14) { p in
            let d = dir15(ctx, "angle", "length")
            p.a = SIMD4(d.x, d.y, n15(ctx, "threshold", 0.01), n15(ctx, "intensity")); p.c = col15(ctx, "tint") } })

    // MARK: Glows

    private static func extract15(_ ctx: EffectContext, threshold: Double, saturation: Double = 1) -> MTLTexture {
        r15(ctx, 15) { p in p.a = SIMD4(Float(threshold), Float(saturation), 0, 0) }
    }
    private static func addGlow15(_ ctx: EffectContext, _ base: MTLTexture, _ glow: MTLTexture, _ gain: Double,
                                  tint: SIMD4<Float> = SIMD4(1, 1, 1, 1), prism: Double = 0) -> MTLTexture {
        r15(ctx, 16, src: base, aux: glow) { p in
            p.a = SIMD4(Float(gain), Float(prism * ctx.unit), 0, 0); p.b = tint; p.i.z = prism > 0 ? 1 : 0 }
    }

    static let prismGlow15 = EffectDefinition(
        id: "awi15.prismGlow", name: "Prism Glow", category: .stylize, aeMatchNames: [],
        summary: "Glow whose red and blue parts split apart like light through a prism.",
        params: [.number("size", "Size", 15, 0, 100, step: 0.1, unit: "px"), pct15("threshold", "Threshold", 40, 0, 95),
                 .number("intensity", "Intensity", 1.5, 0, 5, step: 0.01), .number("spread", "Prism Spread", 6, 0, 40, step: 0.1, unit: "px")],
        margin: { e, t in e.number("size", t) * 1.5 + e.number("spread", t) },
        stage: .pixels { ctx in
            let hi = blur15(ctx, extract15(ctx, threshold: ctx.num("threshold") / 100), ctx.num("size"))
            return addGlow15(ctx, ctx.input, hi, ctx.num("intensity"), prism: max(0.01, ctx.num("spread")))
        })

    static let dreamBloom15 = EffectDefinition(
        id: "awi15.dreamBloom", name: "Dream Bloom", category: .stylize, aeMatchNames: [],
        summary: "Hazy, tinted dream-sequence glow that softens the whole picture.",
        params: [.number("size", "Size", 25, 0, 100, step: 0.1, unit: "px"), pct15("amount", "Amount", 60), pct15("haze", "Haze", 20),
                 .color("tint", "Tint", RGBA(1, 0.9, 0.95))],
        margin: { e, t in e.number("size", t) * 1.5 },
        stage: .pixels { ctx in
            let b = blur15(ctx, ctx.input, ctx.num("size"))
            return r15(ctx, 17, aux: b) { p in p.a = SIMD4(n15(ctx, "amount", 0.01), n15(ctx, "haze", 0.01), 0, 0); p.b = col15(ctx, "tint") }
        })

    static let softGlow15 = EffectDefinition(
        id: "awi15.softGlow", name: "Soft Glow", category: .stylize, aeMatchNames: [],
        summary: "A blurred copy of the brighter areas screened back over the image.",
        params: [.number("radius", "Radius", 20, 0, 100, step: 0.1, unit: "px"), pct15("intensity", "Intensity", 70, 0, 200),
                 pct15("threshold", "Threshold", 20, 0, 95)],
        margin: { e, t in e.number("radius", t) * 1.5 },
        stage: .pixels { ctx in
            let g = blur15(ctx, extract15(ctx, threshold: ctx.num("threshold") / 100), ctx.num("radius"))
            return r15(ctx, 18, aux: g) { p in p.a.x = n15(ctx, "intensity", 0.01) }
        })

    static let darkGlow15 = EffectDefinition(
        id: "awi15.darkGlow", name: "Dark Glow", category: .stylize, aeMatchNames: [],
        summary: "Shadows bloom outward and multiply over the image for a moody, inky look.",
        params: [.number("radius", "Radius", 15, 0, 100, step: 0.1, unit: "px"), pct15("amount", "Amount", 70),
                 .number("depth", "Depth", 2, 1, 4, step: 0.01)],
        stage: .pixels { ctx in
            let b = blur15(ctx, ctx.input, ctx.num("radius"))
            return r15(ctx, 19, aux: b) { p in p.a = SIMD4(n15(ctx, "amount", 0.01), n15(ctx, "depth"), 0, 0) }
        })

    static let hueGlow15 = EffectDefinition(
        id: "awi15.hueGlow", name: "Glow Threshold Color", category: .stylize, aeMatchNames: [],
        summary: "Only areas of the chosen hue glow; everything else stays untouched.",
        params: [.angle("hue", "Glow Hue", 270), .number("range", "Hue Range", 30, 0, 180, step: 0.1, unit: "°"),
                 .number("size", "Size", 15, 0, 100, step: 0.1, unit: "px"), .number("intensity", "Intensity", 2, 0, 5, step: 0.01)],
        margin: { e, t in e.number("size", t) * 1.5 },
        stage: .pixels { ctx in
            let h = ctx.num("hue") / 360
            let key = r15(ctx, 15) { p in
                p.a = SIMD4(0, 1.2, 0, 0)
                p.b = SIMD4(Float(h - floor(h)), n15(ctx, "range", 1.0 / 360), 0.04, 0); p.i.y = 1 }
            return addGlow15(ctx, ctx.input, blur15(ctx, key, ctx.num("size")), ctx.num("intensity"))
        })

    static let neonBloom15 = EffectDefinition(
        id: "awi15.neonBloom", name: "Neon Bloom", category: .stylize, aeMatchNames: [],
        summary: "Saturated multi-radius bloom for vivid neon light.",
        params: [.number("size", "Size", 12, 0, 100, step: 0.1, unit: "px"), pct15("threshold", "Threshold", 30, 0, 95),
                 pct15("saturation", "Saturation", 150, 0, 300), .number("intensity", "Intensity", 1.5, 0, 5, step: 0.01)],
        margin: { e, t in e.number("size", t) * 4 },
        stage: .pixels { ctx in
            let hi = extract15(ctx, threshold: ctx.num("threshold") / 100, saturation: ctx.num("saturation") / 100)
            var out = ctx.input
            for (k, f) in [1.0, 2.0, 4.0].enumerated() {
                let g = blur15(ctx, hi, ctx.num("size") * f)
                out = addGlow15(ctx, out, g, ctx.num("intensity") * [0.6, 0.45, 0.35][k])
            }
            return out
        })

    static let starglow15 = EffectDefinition(
        id: "awi15.starglow", name: "Starglow", category: .stylize, aeMatchNames: [],
        summary: "Eight-direction streak glow from the highlights with alternating colors.",
        params: [.number("length", "Streak Length", 40, 0, 200, unit: "px"), pct15("threshold", "Threshold", 60, 0, 95),
                 .number("intensity", "Intensity", 1.5, 0, 5, step: 0.01), .angle("rotation", "Rotation", 0),
                 .color("colorA", "Color A", RGBA(1, 0.85, 0.6)), .color("colorB", "Color B", RGBA(0.6, 0.8, 1))],
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in r15(ctx, 20) { p in
            p.a = SIMD4(px15(ctx, "length"), n15(ctx, "threshold", 0.01), n15(ctx, "intensity"), rad15(ctx, "rotation"))
            p.b = col15(ctx, "colorA"); p.c = col15(ctx, "colorB") } })

    static let lightWrap15 = EffectDefinition(
        id: "awi15.lightWrap", name: "Light Wrap", category: .stylize, aeMatchNames: [],
        summary: "Brighter surroundings bleed softly onto the edges of darker areas, blending elements together.",
        params: [.number("width", "Wrap Width", 15, 0, 100, step: 0.1, unit: "px"), pct15("intensity", "Intensity", 100, 0, 200)],
        stage: .pixels { ctx in
            let b = blur15(ctx, ctx.input, ctx.num("width"))
            return r15(ctx, 21, aux: b) { p in p.a.x = n15(ctx, "intensity", 0.01) }
        })

    static let diffusion15 = EffectDefinition(
        id: "awi15.diffusion", name: "Diffusion Filter", category: .stylize, aeMatchNames: [],
        summary: "Pro-Mist style diffusion: glowing highlights, softened detail and lifted blacks.",
        params: [.number("size", "Size", 20, 0, 100, step: 0.1, unit: "px"), pct15("strength", "Strength", 50),
                 pct15("lift", "Black Lift", 10, 0, 50), pct15("bloom", "Highlight Bloom", 50)],
        margin: { e, t in e.number("size", t) * 1.5 },
        stage: .pixels { ctx in
            let b = blur15(ctx, ctx.input, ctx.num("size"))
            return r15(ctx, 22, aux: b) { p in
                p.a = SIMD4(n15(ctx, "strength", 0.01), n15(ctx, "lift", 0.01), n15(ctx, "bloom", 0.01), 0) }
        })

    // MARK: Sharpen & detail

    static let clarity15 = EffectDefinition(
        id: "awi15.clarity", name: "Clarity", category: .blur, aeMatchNames: [],
        summary: "Midtone local contrast: punchier (or, negative, softer) without crushing shadows or highlights.",
        params: [pct15("amount", "Amount", 60, -100, 100), .number("radius", "Radius", 20, 1, 100, step: 0.1, unit: "px")],
        stage: .pixels { ctx in
            let b = blur15(ctx, ctx.input, ctx.num("radius"))
            return r15(ctx, 23, aux: b) { p in p.a.x = n15(ctx, "amount", 0.01) }
        })

    static let highPass15 = EffectDefinition(
        id: "awi15.highPass", name: "High Pass Sharpen", category: .blur, aeMatchNames: [],
        summary: "Adds the high-pass detail layer back onto the image (or shows it on gray).",
        params: [.number("radius", "Radius", 3, 0.5, 30, step: 0.1, unit: "px"), pct15("amount", "Amount", 150, 0, 500),
                 .toggle("show", "Show High Pass", false)],
        stage: .pixels { ctx in
            let b = blur15(ctx, ctx.input, ctx.num("radius"))
            return r15(ctx, 24, aux: b) { p in p.a.x = n15(ctx, "amount", 0.01); p.i.y = ctx.effect.bool("show") ? 1 : 0 }
        })

    static let structure15 = EffectDefinition(
        id: "awi15.structure", name: "Structure", category: .blur, aeMatchNames: [],
        summary: "Soft-limited micro-contrast that brings out fine texture and detail.",
        params: [pct15("amount", "Amount", 100, 0, 200), .number("size", "Detail Size", 2, 0.5, 10, step: 0.1, unit: "px")],
        stage: .pixels { ctx in
            let b = blur15(ctx, ctx.input, ctx.num("size"))
            return r15(ctx, 25, aux: b) { p in p.a.x = n15(ctx, "amount", 0.01) }
        })
}
