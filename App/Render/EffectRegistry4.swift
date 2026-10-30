import Foundation
import Metal
import simd

/// Batch 4: light on the subject's outline — AE-style outline glow (Saber "Layer Masks/Alpha" look), anime energy aura,
/// rim light, Photoshop-style outer / inner glow and a glowing stroke. All read the layer's alpha, so they shine on
/// cut-out characters and text.
extension EffectRegistry {
    static let batch4: [EffectDefinition] = [outlineGlow, energyAura, rimLight, outerGlow, innerGlow, neonStroke]

    private static func g4(_ ctx: EffectContext, _ mode: UInt32, src: MTLTexture, aux: MTLTexture? = nil, side: UInt32 = 0,
                           _ fill: (inout EffectParams) -> Void = { _ in }) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode; p.i.y = side
        ctx.gpu.run("fxGlow4", ctx.cb, textures: [src, out, aux ?? src], params: p, grid: out)
        return out
    }

    /// Additive glow: the edge light blurred at a few radii (tight core + wide bloom), added onto `base`.
    private static func bloom(_ ctx: EffectContext, base: MTLTexture, light: MTLTexture, size: Double, gain: Double) -> MTLTexture {
        var out = g4(ctx, 1, src: base, aux: light) { $0.a.x = Float(gain) }
        guard size > 0.5 else { return out }
        for (k, frac) in [0.12, 0.4, 1.0].enumerated() {
            let g = ctx.gpu.gaussian(ctx, input: light, sigma: max(0.6, size * frac / 2))
            out = g4(ctx, 1, src: out, aux: g) { $0.a.x = Float(gain * [1.0, 0.8, 0.6][k]) }
        }
        return out
    }

    private static func cleared(_ ctx: EffectContext) -> MTLTexture {
        let t = ctx.temp(); ctx.gpu.run("fxClear", ctx.cb, textures: [t], grid: t); return t
    }

    private static func edgeLine(_ ctx: EffectContext, width: Double, color: RGBA, intensity: Double, sharpness: Double,
                                 noise: Double, noiseScale: Double, rise: Double, flicker: Double, speed: Double, side: UInt32) -> MTLTexture {
        let soft = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: max(0.5, width * ctx.unit / 2))
        return g4(ctx, 0, src: ctx.input, aux: soft, side: side) { p in
            p.a = SIMD4(Float(intensity), Float(sharpness), Float(noiseScale * ctx.unit), Float(rise * ctx.unit))
            p.b = color.simd
            p.c = SIMD4(Float(noise * ctx.unit), Float(ctx.time), Float(flicker), Float(speed))
        }
    }

    static let outlineGlow = EffectDefinition(
        id: "awi.outlineGlow", name: "Outline Glow", category: .stylize, aeMatchNames: [],
        summary: "Glowing light traced around the subject's outline (cut-out characters, text, shapes).",
        params: [.color("color", "Glow Color", RGBA(hex: 0x3FA9FF)), .color("core", "Core Color", .white),
                 .number("intensity", "Intensity", 1.6, 0, 6, step: 0.01), .number("glow", "Glow Size", 40, 0, 400, unit: "px"),
                 .number("coreWidth", "Core Width", 4, 0.5, 40, unit: "px"), .number("noise", "Distortion", 4, 0, 60, unit: "px"),
                 .number("flicker", "Flicker", 0.15, 0, 1, step: 0.01), .number("speed", "Speed", 1, 0, 10, step: 0.1),
                 .toggle("outside", "Outside Only", false), .toggle("only", "Glow Only", false)],
        margin: { e, t in e.number("glow", t) * 1.5 + e.number("noise", t) },
        stage: .pixels { ctx in
            let side: UInt32 = ctx.effect.bool("outside") ? 1 : 0
            let a = ctx.num("intensity")
            let glow = edgeLine(ctx, width: ctx.num("coreWidth"), color: ctx.effect.color("color", ctx.time), intensity: a, sharpness: 0.8,
                                noise: ctx.num("noise"), noiseScale: 40, rise: 0, flicker: ctx.num("flicker"), speed: ctx.num("speed") * 2, side: side)
            let core = edgeLine(ctx, width: ctx.num("coreWidth") * 0.5, color: ctx.effect.color("core", ctx.time), intensity: min(1, a), sharpness: 2.5,
                                noise: ctx.num("noise"), noiseScale: 40, rise: 0, flicker: ctx.num("flicker"), speed: ctx.num("speed") * 2, side: side)
            let base = ctx.effect.bool("only") ? cleared(ctx) : ctx.input
            let lit = bloom(ctx, base: base, light: glow, size: ctx.num("glow") * ctx.unit, gain: 1)
            return g4(ctx, 1, src: lit, aux: core) { $0.a.x = 1 }
        })

    static let energyAura = EffectDefinition(
        id: "awi.energyAura", name: "Energy Aura", category: .stylize, aeMatchNames: [],
        summary: "Anime power-up aura: flickering flame light rising off the outline.",
        params: [.color("color", "Aura Color", RGBA(hex: 0xA64BFF)), .color("core", "Core Color", RGBA(hex: 0xF1D9FF)),
                 .number("intensity", "Intensity", 2, 0, 6, step: 0.01), .number("size", "Aura Size", 60, 0, 400, unit: "px"),
                 .number("width", "Flame Width", 10, 1, 80, unit: "px"), .number("turbulence", "Turbulence", 18, 0, 80, unit: "px"),
                 .number("scale", "Flame Scale", 30, 4, 200, unit: "px"), .number("rise", "Rise Speed", 120, 0, 600, unit: "px/s"),
                 .number("flicker", "Flicker", 0.25, 0, 1, step: 0.01)],
        margin: { e, t in e.number("size", t) * 1.5 + e.number("turbulence", t) + e.number("width", t) },
        stage: .pixels { ctx in
            let col = ctx.effect.color("color", ctx.time)
            let flame = edgeLine(ctx, width: ctx.num("width"), color: col, intensity: ctx.num("intensity"), sharpness: 0.6,
                                 noise: ctx.num("turbulence"), noiseScale: ctx.num("scale"), rise: ctx.num("rise") / 30, flicker: ctx.num("flicker"),
                                 speed: 1.5, side: 1)
            let core = edgeLine(ctx, width: ctx.num("width") * 0.35, color: ctx.effect.color("core", ctx.time), intensity: 1, sharpness: 2,
                                noise: ctx.num("turbulence") * 0.4, noiseScale: ctx.num("scale"), rise: ctx.num("rise") / 30, flicker: ctx.num("flicker"),
                                speed: 1.5, side: 1)
            let lit = bloom(ctx, base: ctx.input, light: flame, size: ctx.num("size") * ctx.unit, gain: 1)
            return g4(ctx, 1, src: lit, aux: core) { $0.a.x = 1 }
        })

    static let rimLight = EffectDefinition(
        id: "awi.rimLight", name: "Rim Light", category: .color, aeMatchNames: [],
        summary: "Back light catching one side of the subject's edge.",
        params: [.color("color", "Light Color", RGBA(hex: 0xFFD9A0)), .angle("angle", "Light Direction", 45),
                 .number("distance", "Rim Width", 10, 0, 100, unit: "px"), .number("softness", "Softness", 4, 0, 60, unit: "px"),
                 .number("intensity", "Intensity", 1.5, 0, 6, step: 0.01), .number("bloom", "Bloom", 12, 0, 200, unit: "px")],
        margin: { e, t in e.number("bloom", t) * 1.5 },
        stage: .pixels { ctx in
            let a = (ctx.num("angle") - 90) * .pi / 180, d = ctx.num("distance") * ctx.unit
            let rim0 = g4(ctx, 3, src: ctx.input) { p in
                p.a = SIMD4(Float(cos(a) * d), Float(sin(a) * d), Float(ctx.num("intensity")), 0); p.b = ctx.effect.color("color", ctx.time).simd }
            let soft = ctx.num("softness") > 0.3 ? ctx.gpu.gaussian(ctx, input: rim0, sigma: ctx.num("softness") * ctx.unit / 2) : rim0
            let rim = g4(ctx, 4, src: soft, aux: ctx.input)       // keep the rim inside the subject
            return bloom(ctx, base: ctx.input, light: rim, size: ctx.num("bloom") * ctx.unit, gain: 1)
        })

    static let outerGlow = EffectDefinition(
        id: "awi.outerGlow", name: "Outer Glow", category: .stylize, aeMatchNames: [],
        summary: "Soft colored halo around the layer (Photoshop layer style).",
        params: [.color("color", "Color", RGBA(hex: 0xFF5CA8)), .number("size", "Size", 30, 0, 400, unit: "px"),
                 .number("intensity", "Intensity", 1.2, 0, 6, step: 0.01), .number("spread", "Spread", 0, 0, 100, unit: "%")],
        margin: { e, t in e.number("size", t) * 1.5 },
        stage: .pixels { ctx in
            let solid = g4(ctx, 2, src: ctx.input) { p in p.a.x = Float(1 + ctx.num("spread") / 25); p.b = ctx.effect.color("color", ctx.time).simd }
            let blur = ctx.gpu.gaussian(ctx, input: solid, sigma: max(0.5, ctx.num("size") * ctx.unit / 2))
            let halo = g4(ctx, 4, src: blur, aux: ctx.input, side: 1)
            return g4(ctx, 1, src: ctx.input, aux: halo) { $0.a.x = Float(ctx.num("intensity")) }
        })

    static let innerGlow = EffectDefinition(
        id: "awi.innerGlow", name: "Inner Glow", category: .stylize, aeMatchNames: [],
        summary: "Light glowing inward from the layer's edges.",
        params: [.color("color", "Color", RGBA(hex: 0xFFF2B0)), .number("size", "Size", 20, 0, 300, unit: "px"),
                 .number("intensity", "Intensity", 1, 0, 6, step: 0.01)],
        stage: .pixels { ctx in
            let outside = g4(ctx, 2, src: ctx.input, side: 1) { p in p.a.x = 1; p.b = ctx.effect.color("color", ctx.time).simd }
            let blur = ctx.gpu.gaussian(ctx, input: outside, sigma: max(0.5, ctx.num("size") * ctx.unit / 2))
            let inner = g4(ctx, 4, src: blur, aux: ctx.input)
            return g4(ctx, 1, src: ctx.input, aux: inner) { $0.a.x = Float(ctx.num("intensity")) }
        })

    static let neonStroke = EffectDefinition(
        id: "awi.neonStroke", name: "Neon Stroke", category: .stylize, aeMatchNames: [],
        summary: "Crisp glowing stroke traced on the outline, with optional stroke-only look.",
        params: [.color("color", "Color", RGBA(hex: 0x5CFFB0)), .number("width", "Stroke Width", 3, 0.5, 40, unit: "px"),
                 .number("glow", "Glow", 16, 0, 200, unit: "px"), .number("intensity", "Intensity", 1.4, 0, 6, step: 0.01),
                 .toggle("only", "Stroke Only", false)],
        margin: { e, t in e.number("glow", t) * 1.5 + e.number("width", t) },
        stage: .pixels { ctx in
            let line = edgeLine(ctx, width: ctx.num("width"), color: ctx.effect.color("color", ctx.time), intensity: ctx.num("intensity"),
                                sharpness: 0.35, noise: 0, noiseScale: 1, rise: 0, flicker: 0, speed: 0, side: 0)
            let base = ctx.effect.bool("only") ? cleared(ctx) : ctx.input
            return bloom(ctx, base: base, light: line, size: ctx.num("glow") * ctx.unit, gain: 1)
        })
}
