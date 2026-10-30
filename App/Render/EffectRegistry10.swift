import Foundation
import Metal
import simd

/// Batch 10: lighting, material & 3D looks editors reach for in AE plugins — bevels, bump / normal-map lighting,
/// chrome & gold, glass, light sweeps, star glints, spot / point lights, two-tone and specular lighting, edge AO,
/// inner shadow, fresnel and holographic foil, neon tubes, volumetric beams, film bloom, lens dirt and a pseudo-3D
/// card tilt. Written from scratch on the GPU (kernel `fxLight10`).
extension EffectRegistry {
    static let batch10: [EffectDefinition] = [
        bevelAlpha10, smoothBevel10, bumpMap10, normalLight10, chrome10, gold10, glass10, lightSweep10,
        starGlint10, rainbowGlint10, spotlight10, pointLight10, twoTone10, edgeAO10, innerShadow10, embossColor10,
        fresnel10, holoFoil10, neonTubes10, specular10, beam10, filmBloom10, lensDirt10, cardTilt10,
    ]

    private static func r10(_ ctx: EffectContext, _ mode: UInt32, src: MTLTexture? = nil, aux: MTLTexture? = nil, sub: UInt32 = 0,
                            _ fill: (inout EffectParams) -> Void = { _ in }) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode; p.i.y = sub
        p.d.x = Float(ctx.time)
        let s = src ?? ctx.input
        ctx.gpu.run("fxLight10", ctx.cb, textures: [s, out, aux ?? s], params: p, grid: out)
        return out
    }
    private static func pt10(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    private static func rad10(_ deg: Double) -> Float { Float(deg * .pi / 180) }
    private static func col10(_ ctx: EffectContext, _ key: String) -> SIMD4<Float> { ctx.effect.color(key, ctx.time).simd }
    /// Soft height field: alpha (luma 0) or luminance × alpha (luma 1), blurred by `soft` layer pixels.
    private static func height10(_ ctx: EffectContext, luma: Float, soft: Double) -> MTLTexture {
        let h = r10(ctx, 0) { $0.a.x = luma }
        return ctx.gpu.gaussian(ctx, input: h, sigma: max(0.5, soft * ctx.unit / 2))
    }
    private static func depth10(_ ctx: EffectContext, _ key: String) -> Float { Float(ctx.num(key) * ctx.unit) }

    // MARK: Bevels & bumps

    static let bevelAlpha10 = EffectDefinition(
        id: "awi10.bevelAlpha", name: "Bevel Alpha", category: .stylize, aeMatchNames: ["ADBE Bevel Alpha"],
        summary: "Lit bevel along the layer's alpha edge (text, logos, cut-outs).",
        params: [.number("width", "Edge Thickness", 8, 1, 40, unit: "px"), .number("intensity", "Light Intensity", 1, 0, 2, step: 0.01),
                 .angle("angle", "Light Angle", 135), .color("highlight", "Highlight", .white), .color("shadow", "Shadow", .black)],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 0, soft: ctx.num("width"))
            return r10(ctx, 1, aux: h) { p in
                p.a = SIMD4(12, Float(ctx.num("intensity")), rad10(ctx.num("angle")), 0)
                p.b = col10(ctx, "highlight"); p.c = col10(ctx, "shadow") }
        })

    static let smoothBevel10 = EffectDefinition(
        id: "awi10.smoothBevel", name: "Smooth Bevel+", category: .stylize, aeMatchNames: [],
        summary: "Rounded, glossy bevel with soft shadow and a specular hot spot.",
        params: [.number("size", "Size", 12, 2, 60, unit: "px"), .number("depth", "Depth", 10, 0, 30, step: 0.1),
                 .number("highlight", "Highlight", 1, 0, 2, step: 0.01), .number("shadow", "Shadow", 1, 0, 2, step: 0.01),
                 .number("shininess", "Shininess", 16, 1, 64, step: 0.5), .number("elevation", "Light Elevation", 40, 5, 85, unit: "°"),
                 .angle("angle", "Light Angle", 135), .color("color", "Highlight Color", .white)],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 0, soft: ctx.num("size"))
            return r10(ctx, 2, aux: h) { p in
                p.a = SIMD4(depth10(ctx, "depth"), Float(ctx.num("highlight")), Float(ctx.num("shadow")), rad10(ctx.num("angle")))
                p.b = SIMD4(rad10(ctx.num("elevation")), Float(ctx.num("shininess")), 0, 0); p.c = col10(ctx, "color") }
        })

    static let bumpMap10 = EffectDefinition(
        id: "awi10.bumpMap", name: "Bump Map", category: .stylize, aeMatchNames: [],
        summary: "Relief lighting from the image's own brightness.",
        params: [.number("depth", "Depth", 10, 0, 40, step: 0.1), .number("softness", "Softness", 2, 0, 20, unit: "px"),
                 .number("intensity", "Intensity", 1, 0, 3, step: 0.01), .number("elevation", "Light Elevation", 45, 5, 85, unit: "°"),
                 .angle("angle", "Light Angle", 135)],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 1, soft: ctx.num("softness"))
            return r10(ctx, 3, aux: h) { p in
                p.a = SIMD4(depth10(ctx, "depth"), Float(ctx.num("intensity")), rad10(ctx.num("angle")), rad10(ctx.num("elevation"))) }
        })

    static let normalLight10 = EffectDefinition(
        id: "awi10.normalLight", name: "Normal Map Lighting", category: .color, aeMatchNames: [],
        summary: "A movable point light shading the image's relief with ambient and specular.",
        params: [.point("light", "Light Position", Vec2(0.3, 0.3)), .number("height", "Light Height", 120, 10, 600, unit: "px"),
                 .number("ambient", "Ambient", 0.25, 0, 1, step: 0.01), .number("specular", "Specular", 0.6, 0, 2, step: 0.01),
                 .number("shininess", "Shininess", 24, 1, 128, step: 0.5), .number("depth", "Bump Depth", 8, 0, 40, step: 0.1),
                 .number("softness", "Softness", 1.5, 0, 20, unit: "px"), .color("color", "Light Color", RGBA(1, 0.95, 0.85))],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 1, soft: ctx.num("softness"))
            return r10(ctx, 4, aux: h) { p in
                let l = pt10(ctx, "light")
                p.a = SIMD4(l.x, l.y, Float(ctx.num("height") * ctx.unit), depth10(ctx, "depth"))
                p.b = col10(ctx, "color")
                p.c = SIMD4(Float(ctx.num("ambient")), Float(ctx.num("specular")), Float(ctx.num("shininess")), 0) }
        })

    // MARK: Materials

    private static func metal10(_ ctx: EffectContext, mode: UInt32, contrastKey: String, tint: SIMD4<Float>) -> MTLTexture {
        let h = height10(ctx, luma: 1, soft: ctx.num("softness"))
        return r10(ctx, mode, aux: h) { p in
            p.a = SIMD4(depth10(ctx, "depth"), Float(ctx.num("bands")), Float(ctx.num("mix") / 100), Float(ctx.num(contrastKey)))
            p.b = tint }
    }

    static let chrome10 = EffectDefinition(
        id: "awi10.chrome", name: "Chrome Metal", category: .stylize, aeMatchNames: [],
        summary: "Polished chrome: environment bands reflected off the image's relief.",
        params: [.number("depth", "Depth", 10, 0, 40, step: 0.1), .number("softness", "Softness", 2, 0, 20, unit: "px"),
                 .number("bands", "Reflections", 1.5, 0.2, 6, step: 0.01), .number("contrast", "Contrast", 1.2, 0.3, 4, step: 0.01),
                 .number("mix", "Mix", 100, 0, 100, unit: "%"), .color("tint", "Tint", RGBA(0.85, 0.9, 1))],
        stage: .pixels { ctx in metal10(ctx, mode: 5, contrastKey: "contrast", tint: col10(ctx, "tint")) })

    static let gold10 = EffectDefinition(
        id: "awi10.gold", name: "Gold Text", category: .stylize, aeMatchNames: [],
        summary: "Shiny gold lettering look with warm reflections and glints.",
        params: [.number("depth", "Depth", 10, 0, 40, step: 0.1), .number("softness", "Softness", 2, 0, 20, unit: "px"),
                 .number("bands", "Reflections", 1.2, 0.2, 6, step: 0.01), .number("shine", "Shine", 1, 0.3, 4, step: 0.01),
                 .number("mix", "Mix", 100, 0, 100, unit: "%")],
        stage: .pixels { ctx in metal10(ctx, mode: 6, contrastKey: "shine", tint: SIMD4(1, 1, 1, 1)) })

    static let glass10 = EffectDefinition(
        id: "awi10.glass", name: "Glass Material", category: .stylize, aeMatchNames: [],
        summary: "Turns the layer's shape into glass: see-through body, refracted edges, highlight.",
        params: [.number("thickness", "Edge Thickness", 8, 1, 40, unit: "px"), .number("depth", "Depth", 12, 0, 40, step: 0.1),
                 .number("refraction", "Refraction", 8, 0, 40, unit: "px"), .number("transparency", "Transparency", 55, 0, 100, unit: "%"),
                 .number("highlight", "Highlight", 1, 0, 2, step: 0.01), .angle("angle", "Light Angle", 135)],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 0, soft: ctx.num("thickness"))
            return r10(ctx, 7, aux: h) { p in
                p.a = SIMD4(depth10(ctx, "depth"), Float(ctx.num("refraction") * ctx.unit), Float(1 - ctx.num("transparency") / 100),
                            Float(ctx.num("highlight")))
                p.b.x = rad10(ctx.num("angle")) }
        })

    static let lightSweep10 = EffectDefinition(
        id: "awi10.lightSweep", name: "Light Sweep", category: .color, aeMatchNames: ["CC Light Sweep"],
        summary: "Animated shine band gliding across the layer.",
        params: [.angle("angle", "Direction", 30), .number("width", "Width", 40, 2, 300, unit: "px"),
                 .number("intensity", "Intensity", 1, 0, 3, step: 0.01), .number("speed", "Sweeps / sec", 0.6, 0, 4, step: 0.01),
                 .number("offset", "Offset", 30, 0, 100, unit: "%"), .number("softness", "Softness", 60, 0, 100, unit: "%"),
                 .color("color", "Color", .white)],
        stage: .pixels { ctx in r10(ctx, 8) { p in
            let a = ctx.num("angle") * .pi / 180
            p.a = SIMD4(Float(cos(a)), Float(-sin(a)), Float(ctx.num("width") * ctx.unit), Float(ctx.num("intensity")))
            p.b = col10(ctx, "color")
            p.c = SIMD4(Float(ctx.num("speed")), Float(ctx.num("offset") / 100), Float(ctx.num("softness") / 100), 0) } })

    // MARK: Glints & lights

    private static func glint10(_ ctx: EffectContext, mode: UInt32) -> MTLTexture {
        let lines = UInt32([2, 3, 4][min(max(ctx.effect.choice("points"), 0), 2)])
        return r10(ctx, mode, sub: lines) { p in
            let rot = ctx.num("rotation") + ctx.num("spin") * ctx.time
            p.a = SIMD4(Float(ctx.num("threshold") / 100), Float(ctx.num("length") * ctx.unit), Float(ctx.num("intensity")), rad10(rot))
            p.b = col10(ctx, "color") }
    }
    private static func glintParams10(_ color: RGBA) -> [ParamDef] {
        [.number("threshold", "Threshold", 60, 0, 95, unit: "%"), .number("length", "Ray Length", 30, 2, 200, unit: "px"),
         .number("intensity", "Intensity", 1.5, 0, 4, step: 0.01), .number("spin", "Spin", 45, 0, 360, unit: "°/s"),
         .angle("rotation", "Rotation", 0), .choice("points", "Points", ["4", "6", "8"], 1), .color("color", "Color", color)]
    }

    static let starGlint10 = EffectDefinition(
        id: "awi10.starGlint", name: "Star Glint", category: .color, aeMatchNames: ["CC Star Burst"],
        summary: "Rotating 4/6/8-point star sparkles on the highlights.",
        params: glintParams10(RGBA(1, 0.97, 0.9)),
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in glint10(ctx, mode: 9) })

    static let rainbowGlint10 = EffectDefinition(
        id: "awi10.rainbowGlint", name: "Rainbow Glint", category: .color, aeMatchNames: [],
        summary: "Prismatic star sparkles whose rays shimmer through the spectrum.",
        params: glintParams10(.white),
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in glint10(ctx, mode: 10) })

    static let spotlight10 = EffectDefinition(
        id: "awi10.spotlight", name: "Spotlight", category: .color, aeMatchNames: ["ADBE Lighting Effect"],
        summary: "A cone of light with soft falloff; everything outside the beam darkens.",
        params: [.point("source", "Source", Vec2(0.5, 0.05)), .angle("direction", "Direction", 90),
                 .number("cone", "Cone Angle", 50, 5, 120, unit: "°"), .number("softness", "Edge Softness", 40, 0, 100, unit: "%"),
                 .number("ambient", "Ambient", 20, 0, 100, unit: "%"), .number("intensity", "Intensity", 1.5, 0, 4, step: 0.01),
                 .number("reach", "Reach", 200, 10, 1000, unit: "px"), .color("color", "Color", RGBA(1, 0.95, 0.85))],
        stage: .pixels { ctx in r10(ctx, 11) { p in
            let s = pt10(ctx, "source")
            p.a = SIMD4(s.x, s.y, rad10(ctx.num("direction")), rad10(ctx.num("cone") / 2))
            p.b = col10(ctx, "color")
            p.c = SIMD4(Float(ctx.num("softness") / 100), Float(ctx.num("ambient") / 100), Float(ctx.num("intensity")),
                        Float(ctx.num("reach") * ctx.unit)) } })

    static let pointLight10 = EffectDefinition(
        id: "awi10.pointLight", name: "Point Light Glow", category: .color, aeMatchNames: [],
        summary: "A colored light that shades the layer by distance and glows around itself.",
        params: [.point("position", "Position", Vec2(0.3, 0.3)), .number("radius", "Radius", 80, 10, 600, unit: "px"),
                 .number("intensity", "Intensity", 1.5, 0, 4, step: 0.01), .number("glow", "Glow", 0.6, 0, 2, step: 0.01),
                 .color("color", "Color", RGBA(1, 0.6, 0.3))],
        stage: .pixels { ctx in r10(ctx, 12) { p in
            let s = pt10(ctx, "position")
            p.a = SIMD4(s.x, s.y, Float(ctx.num("radius") * ctx.unit), Float(ctx.num("intensity")))
            p.b = col10(ctx, "color"); p.c.x = Float(ctx.num("glow")) } })

    static let twoTone10 = EffectDefinition(
        id: "awi10.twoTone", name: "Two-Tone Lighting", category: .color, aeMatchNames: [],
        summary: "Warm key light on one side, cool rim light on the other.",
        params: [.number("size", "Softness", 4, 0, 30, unit: "px"), .number("depth", "Depth", 12, 0, 40, step: 0.1),
                 .number("key", "Key Strength", 1.2, 0, 3, step: 0.01), .number("rim", "Rim Strength", 1.2, 0, 3, step: 0.01),
                 .angle("angle", "Key Angle", 135), .color("keyColor", "Key Color", RGBA(1, 0.8, 0.5)),
                 .color("rimColor", "Rim Color", RGBA(0.3, 0.6, 1))],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 0.5, soft: ctx.num("size"))
            return r10(ctx, 13, aux: h) { p in
                p.a = SIMD4(depth10(ctx, "depth"), Float(ctx.num("key")), Float(ctx.num("rim")), rad10(ctx.num("angle")))
                p.b = col10(ctx, "keyColor"); p.c = col10(ctx, "rimColor") }
        })

    // MARK: Edges

    static let edgeAO10 = EffectDefinition(
        id: "awi10.edgeAO", name: "Edge Occlusion", category: .stylize, aeMatchNames: [],
        summary: "Ambient-occlusion style darkening creeping in from the alpha edges.",
        params: [.number("radius", "Radius", 10, 1, 60, unit: "px"), .number("strength", "Strength", 1, 0, 2, step: 0.01),
                 .color("color", "Color", .black)],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 0, soft: ctx.num("radius"))
            return r10(ctx, 14, aux: h) { p in p.a.x = Float(ctx.num("strength")); p.b = col10(ctx, "color") }
        })

    static let innerShadow10 = EffectDefinition(
        id: "awi10.innerShadow", name: "Inner Shadow", category: .stylize, aeMatchNames: [],
        summary: "Photoshop-style inner shadow cast inside the shape.",
        params: [.number("distance", "Distance", 6, 0, 60, unit: "px"), .angle("angle", "Light Angle", 135),
                 .number("size", "Size", 6, 0, 40, unit: "px"), .number("opacity", "Opacity", 75, 0, 100, unit: "%"),
                 .color("color", "Color", .black)],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 0, soft: ctx.num("size"))
            return r10(ctx, 15, aux: h) { p in
                let a = ctx.num("angle") * .pi / 180, d = ctx.num("distance") * ctx.unit
                // Shadow falls away from the light: offset = -lightDir * distance.
                p.a = SIMD4(Float(-cos(a) * d), Float(sin(a) * d), Float(ctx.num("opacity") / 100), 0)
                p.b = col10(ctx, "color") }
        })

    static let embossColor10 = EffectDefinition(
        id: "awi10.embossColor", name: "Emboss Color", category: .stylize, aeMatchNames: ["ADBE Color Emboss"],
        summary: "Embossed relief that keeps the original colors.",
        params: [.number("depth", "Height", 10, 0, 40, step: 0.1), .number("amount", "Amount", 100, 0, 200, unit: "%"),
                 .number("softness", "Softness", 1, 0, 10, unit: "px"), .angle("angle", "Direction", 135)],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 1, soft: ctx.num("softness"))
            return r10(ctx, 16, aux: h) { p in
                p.a = SIMD4(depth10(ctx, "depth"), Float(ctx.num("amount") / 100), rad10(ctx.num("angle")), 0) }
        })

    static let fresnel10 = EffectDefinition(
        id: "awi10.fresnel", name: "Fresnel Edge Glow", category: .color, aeMatchNames: [],
        summary: "Glancing-angle glow on the shape's edges, like light wrapping a 3D surface.",
        params: [.number("width", "Width", 10, 1, 40, unit: "px"), .number("depth", "Depth", 20, 0, 60, step: 0.1),
                 .number("power", "Falloff", 2, 0.5, 8, step: 0.01), .number("intensity", "Intensity", 1, 0, 3, step: 0.01),
                 .color("color", "Color", RGBA(0.3, 0.8, 1))],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 0, soft: ctx.num("width"))
            return r10(ctx, 17, aux: h) { p in
                p.a = SIMD4(depth10(ctx, "depth"), Float(ctx.num("power")), Float(ctx.num("intensity")), 0)
                p.b = col10(ctx, "color") }
        })

    static let holoFoil10 = EffectDefinition(
        id: "awi10.holoFoil", name: "Holographic Foil", category: .color, aeMatchNames: [],
        summary: "Iridescent foil whose colors shift with the surface angle and time.",
        params: [.number("scale", "Band Scale", 2, 0.2, 10, step: 0.01), .number("speed", "Shimmer Speed", 0.5, 0, 3, step: 0.01),
                 .number("mix", "Mix", 70, 0, 100, unit: "%"), .number("depth", "Relief", 8, 0, 40, step: 0.1)],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 1, soft: 2)
            return r10(ctx, 18, aux: h) { p in
                p.a = SIMD4(Float(ctx.num("scale")), Float(ctx.num("speed")), Float(ctx.num("mix") / 100), depth10(ctx, "depth")) }
        })

    static let neonTubes10 = EffectDefinition(
        id: "awi10.neonTubes", name: "Neon Tubes", category: .stylize, aeMatchNames: [],
        summary: "Shades strokes and shapes like glowing glass neon tubes.",
        params: [.number("thickness", "Tube Softness", 6, 1, 30, unit: "px"), .number("glow", "Glow Size", 20, 0, 100, unit: "px"),
                 .number("intensity", "Glow Intensity", 1.2, 0, 4, step: 0.01), .number("colorize", "Colorize", 80, 0, 100, unit: "%"),
                 .color("color", "Color", RGBA(1, 0.2, 0.7))],
        margin: { e, t in e.number("glow", t) },
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 0.5, soft: ctx.num("thickness"))
            let tube = r10(ctx, 19, aux: h) { p in p.a.x = Float(ctx.num("colorize") / 100); p.b = col10(ctx, "color") }
            guard ctx.num("glow") > 0.3 else { return tube }
            let g = ctx.gpu.gaussian(ctx, input: tube, sigma: max(0.5, ctx.num("glow") * ctx.unit / 2))
            return r10(ctx, 25, src: tube, aux: g) { p in p.a.x = Float(ctx.num("intensity")) }
        })

    static let specular10 = EffectDefinition(
        id: "awi10.specular", name: "Specular Highlight", category: .color, aeMatchNames: [],
        summary: "Glossy specular hot spots from a directional light on the image's relief.",
        params: [.number("depth", "Depth", 10, 0, 40, step: 0.1), .number("shininess", "Shininess", 32, 1, 128, step: 0.5),
                 .number("intensity", "Intensity", 1, 0, 3, step: 0.01), .number("elevation", "Light Elevation", 45, 5, 85, unit: "°"),
                 .number("softness", "Softness", 2, 0, 20, unit: "px"), .angle("angle", "Light Angle", 135),
                 .color("color", "Color", .white)],
        stage: .pixels { ctx in
            let h = height10(ctx, luma: 1, soft: ctx.num("softness"))
            return r10(ctx, 20, aux: h) { p in
                p.a = SIMD4(depth10(ctx, "depth"), Float(ctx.num("shininess")), Float(ctx.num("intensity")), rad10(ctx.num("angle")))
                p.b = col10(ctx, "color"); p.c.x = rad10(ctx.num("elevation")) }
        })

    // MARK: Atmosphere & bloom

    static let beam10 = EffectDefinition(
        id: "awi10.volumetricBeam", name: "Volumetric Light Beam", category: .generate, aeMatchNames: [],
        summary: "A shaft of light from a point, with drifting dust in the beam.",
        params: [.point("source", "Source", Vec2(0.5, 0.0)), .angle("direction", "Direction", 90),
                 .number("spread", "Spread", 25, 2, 90, unit: "°"), .number("length", "Length", 220, 20, 1000, unit: "px"),
                 .number("intensity", "Intensity", 0.8, 0, 3, step: 0.01), .number("dust", "Dust", 0.5, 0, 1, step: 0.01),
                 .number("dustScale", "Dust Scale", 14, 2, 100, unit: "px"), .color("color", "Color", RGBA(1, 0.92, 0.75))],
        stage: .pixels { ctx in r10(ctx, 21) { p in
            let s = pt10(ctx, "source")
            p.a = SIMD4(s.x, s.y, rad10(ctx.num("direction")), rad10(ctx.num("spread")))
            p.b = col10(ctx, "color")
            p.c = SIMD4(Float(ctx.num("length") * ctx.unit), Float(ctx.num("intensity")), Float(ctx.num("dust")),
                        Float(ctx.num("dustScale") * ctx.unit)) } })

    static let filmBloom10 = EffectDefinition(
        id: "awi10.filmBloom", name: "Film Glow Bloom", category: .color, aeMatchNames: [],
        summary: "Multi-radius filmic bloom with a warm tint on the highlights.",
        params: [.number("threshold", "Threshold", 50, 0, 95, unit: "%"), .number("radius", "Radius", 30, 2, 200, unit: "px"),
                 .number("intensity", "Intensity", 1, 0, 4, step: 0.01), .number("tintAmount", "Tint Amount", 40, 0, 100, unit: "%"),
                 .color("tint", "Tint", RGBA(1, 0.75, 0.5))],
        margin: { e, t in e.number("radius", t) },
        stage: .pixels { ctx in
            let hi = r10(ctx, 26) { p in
                p.a = SIMD4(Float(ctx.num("threshold") / 100), Float(ctx.num("tintAmount") / 100), 0, 0); p.b = col10(ctx, "tint") }
            var out = ctx.input
            for (frac, gain) in [(0.15, 0.9), (0.4, 0.7), (1.0, 0.55)] {
                let g = ctx.gpu.gaussian(ctx, input: hi, sigma: max(0.6, ctx.num("radius") * ctx.unit * frac / 2))
                out = r10(ctx, 25, src: out, aux: g) { p in p.a.x = Float(ctx.num("intensity") * gain) }
            }
            return out
        })

    static let lensDirt10 = EffectDefinition(
        id: "awi10.lensDirt", name: "Lens Dirt", category: .color, aeMatchNames: [],
        summary: "Bloom that lights up smudges and specks on a dirty lens.",
        params: [.number("threshold", "Threshold", 50, 0, 95, unit: "%"), .number("size", "Bloom Size", 60, 4, 300, unit: "px"),
                 .number("intensity", "Intensity", 1.5, 0, 4, step: 0.01), .number("scale", "Dirt Scale", 50, 10, 400, unit: "px"),
                 .number("density", "Dirt Density", 0.6, 0, 1, step: 0.01)],
        margin: { e, t in e.number("size", t) * 0.5 },
        stage: .pixels { ctx in
            let hi = r10(ctx, 26) { p in p.a = SIMD4(Float(ctx.num("threshold") / 100), 0, 0, 0) }
            let g = ctx.gpu.gaussian(ctx, input: hi, sigma: max(0.6, ctx.num("size") * ctx.unit / 2))
            return r10(ctx, 23, aux: g) { p in
                p.a = SIMD4(Float(ctx.num("intensity")), Float(ctx.num("scale") * ctx.unit), Float(ctx.num("density")), 0) }
        })

    // MARK: 3D

    static let cardTilt10 = EffectDefinition(
        id: "awi10.cardTilt", name: "Pseudo 3D Card Tilt", category: .distort, aeMatchNames: [],
        summary: "Tilts the layer in perspective like a card, with light shading on the turned face.",
        params: [.number("rotX", "Tilt X", 15, -80, 80, unit: "°"), .number("rotY", "Tilt Y", 30, -80, 80, unit: "°"),
                 .number("distance", "Perspective Distance", 600, 100, 3000, unit: "px"), .number("shading", "Shading", 60, 0, 100, unit: "%")],
        stage: .pixels { ctx in r10(ctx, 24) { p in
            p.a = SIMD4(rad10(ctx.num("rotX")), rad10(ctx.num("rotY")), Float(ctx.num("distance") * ctx.unit), Float(ctx.num("shading") / 100)) } })
}
