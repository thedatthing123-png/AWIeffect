import Foundation
import Metal
import simd

/// Batch 13: film emulation (stock looks, burn, light damage, gate weave, Super 8, instant photo), retro digital
/// media (JPEG artifacts, bit crush, teletext, thermal printer, risograph, screen print) and screens (LED, LCD,
/// hologram, analog TV, neon sign) plus a few stylized grades (cyberpunk, lomo, day-for-night).
extension EffectRegistry {
    static let batch13: [EffectDefinition] = [
        warmPortraitStock13, coolGreenStock13, tungstenHalationStock13, punchySlideStock13, grainyMonoStock13,
        filmBurn13, lightDamage13, gateWeave13, superEight13, instantPhoto13,
        jpegArtifacts13, bitCrush13, ledScreen13, lcdSubpixels13, hologramScan13, analogTV13, teletextMosaic13,
        thermalPrinter13, risograph13, screenPrint13, neonSign13, cyberpunkGrade13, lomo13, dayForNight13,
    ]

    private static func f13(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void = { _ in }) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        ctx.gpu.run("fxRetro13", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }
    private static func n13(_ ctx: EffectContext, _ k: String, _ scale: Double = 1) -> Float { Float(ctx.num(k) * scale) }
    private static func px13(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * ctx.unit) }
    private static func col13(_ ctx: EffectContext, _ k: String) -> SIMD4<Float> { ctx.effect.color(k, ctx.time).simd }
    private static func pct13(_ id: String, _ name: String, _ def: Double, _ lo: Double = 0, _ hi: Double = 100) -> ParamDef {
        .number(id, name, def, lo, hi, unit: "%")
    }
    /// Film stock looks share Strength + Grain (+ optional extras in a.z / a.w).
    private static func stock13(_ id: String, _ name: String, _ mode: UInt32, _ summary: String,
                                grain: Double, extra: [ParamDef] = [],
                                _ more: @escaping (EffectContext, inout EffectParams) -> Void = { _, _ in }) -> EffectDefinition {
        EffectDefinition(
            id: id, name: name, category: .color, aeMatchNames: [], summary: summary,
            params: [pct13("strength", "Strength", 100), pct13("grain", "Grain", grain)] + extra,
            stage: .pixels { ctx in f13(ctx, mode) { p in
                p.a.x = n13(ctx, "strength", 0.01); p.a.y = n13(ctx, "grain", 0.01); more(ctx, &p) } })
    }

    // MARK: Film stocks

    static let warmPortraitStock13 = stock13("awi13.warmPortrait", "Film Stock: Warm Portrait", 0,
        "Warm, soft-contrast negative film look with gentle skin tones and lifted shadows.", grain: 30)
    static let coolGreenStock13 = stock13("awi13.coolGreen", "Film Stock: Cool Green", 1,
        "Cool negative film look with green-cyan shadows and crisp highlights.", grain: 30)
    static let tungstenHalationStock13 = stock13("awi13.tungstenHalation", "Film Stock: Tungsten Halation", 2,
        "Tungsten-balanced cinema stock: cool cast with a red halation glow around bright areas.", grain: 25,
        extra: [.number("halRadius", "Halation Radius", 8, 1, 40, unit: "px"), pct13("halation", "Halation", 80, 0, 200)]) { ctx, p in
        p.a.z = px13(ctx, "halRadius"); p.a.w = n13(ctx, "halation", 0.01)
    }
    static let punchySlideStock13 = stock13("awi13.punchySlide", "Film Stock: Punchy Slide", 3,
        "Saturated, contrasty slide-film (reversal) look with deep blues.", grain: 20)
    static let grainyMonoStock13 = stock13("awi13.grainyMono", "Film Stock: Grainy B&W", 4,
        "Classic high-speed black & white film with heavy grain and punchy contrast.", grain: 60,
        extra: [pct13("contrast", "Contrast", 60)]) { ctx, p in p.a.z = n13(ctx, "contrast", 0.01) }

    // MARK: Film damage / camera

    static let filmBurn13 = EffectDefinition(
        id: "awi13.filmBurn", name: "Film Burn", category: .stylize, aeMatchNames: [],
        summary: "Animated burning light creeping in from the frame edges, like film melting in the gate.",
        params: [pct13("intensity", "Intensity", 100, 0, 200), .number("speed", "Speed", 1, 0, 5, step: 0.01),
                 pct13("size", "Size", 45)],
        stage: .pixels { ctx in f13(ctx, 5) { p in
            p.a = SIMD4(n13(ctx, "intensity", 0.01), n13(ctx, "speed"), n13(ctx, "size", 0.01), 0) } })

    static let lightDamage13 = EffectDefinition(
        id: "awi13.lightDamage", name: "Light Damage Frames", category: .stylize, aeMatchNames: [],
        summary: "Random light-struck frames: flashing leaks and blotches that change every few frames.",
        params: [pct13("amount", "Amount", 80), .number("rate", "Frame Rate", 8, 1, 24, unit: "/s"),
                 .color("color", "Leak Color", RGBA(1, 0.45, 0.15))],
        stage: .pixels { ctx in f13(ctx, 6) { p in
            p.a = SIMD4(n13(ctx, "amount", 0.01), n13(ctx, "rate"), 0, 0); p.b = col13(ctx, "color") } })

    static let gateWeave13 = EffectDefinition(
        id: "awi13.gateWeave", name: "Gate Weave", category: .stylize, aeMatchNames: [],
        summary: "Subtle projector jitter of the whole frame with a dark frame line at the edges.",
        params: [.number("amount", "Weave Amount", 4, 0, 30, unit: "px"), .number("speed", "Speed", 1, 0, 5, step: 0.01),
                 pct13("frameLine", "Frame Line", 40)],
        stage: .pixels { ctx in f13(ctx, 7) { p in
            p.a = SIMD4(px13(ctx, "amount"), n13(ctx, "speed"), n13(ctx, "frameLine", 0.01), 0) } })

    static let superEight13 = EffectDefinition(
        id: "awi13.superEight", name: "Super 8", category: .stylize, aeMatchNames: [],
        summary: "Home-movie look: warm faded color, heavy vignette, frame jitter and grain.",
        params: [pct13("vignette", "Vignette", 70), .number("jitter", "Jitter", 3, 0, 20, unit: "px"),
                 pct13("warmth", "Warmth", 70), pct13("grain", "Grain", 40)],
        stage: .pixels { ctx in f13(ctx, 8) { p in
            p.a = SIMD4(n13(ctx, "vignette", 0.01), px13(ctx, "jitter"), n13(ctx, "warmth", 0.01), n13(ctx, "grain", 0.01)) } })

    static let instantPhoto13 = EffectDefinition(
        id: "awi13.instantPhoto", name: "Instant Photo", category: .stylize, aeMatchNames: [],
        summary: "Faded instant-camera print with a cream frame, thicker at the bottom.",
        params: [pct13("fade", "Fade", 60), pct13("border", "Border", 6, 0, 25), pct13("warmth", "Warmth", 50),
                 .color("frame", "Frame Color", RGBA(0.95, 0.93, 0.87))],
        stage: .pixels { ctx in f13(ctx, 9) { p in
            p.a = SIMD4(n13(ctx, "fade", 0.01), n13(ctx, "border", 0.01), n13(ctx, "warmth", 0.01), 0); p.b = col13(ctx, "frame") } })

    // MARK: Digital / print retro

    static let jpegArtifacts13 = EffectDefinition(
        id: "awi13.jpegArtifacts", name: "JPEG Artifacts", category: .stylize, aeMatchNames: [],
        summary: "Over-compressed look: blocky quantization, ringing and smeared chroma.",
        params: [pct13("quality", "Quality", 15), .number("block", "Block Size", 8, 4, 32, unit: "px")],
        stage: .pixels { ctx in f13(ctx, 10) { p in
            p.a = SIMD4(n13(ctx, "quality", 0.01), px13(ctx, "block"), 0, 0) } })

    static let bitCrush13 = EffectDefinition(
        id: "awi13.bitCrush", name: "Bit Crush", category: .stylize, aeMatchNames: [],
        summary: "Reduce color depth per channel with optional ordered dithering.",
        params: [.number("bits", "Bits per Channel", 3, 1, 8, step: 1), pct13("dither", "Dither", 50)],
        stage: .pixels { ctx in f13(ctx, 11) { p in
            p.a = SIMD4(n13(ctx, "bits"), n13(ctx, "dither", 0.01), 0, 0) } })

    static let teletextMosaic13 = EffectDefinition(
        id: "awi13.teletext", name: "Teletext Mosaic", category: .stylize, aeMatchNames: [],
        summary: "Broadcast teletext look: 2x3 block graphics in the 8-color palette.",
        params: [.number("cell", "Cell Width", 8, 2, 40, unit: "px"), pct13("threshold", "Threshold", 50)],
        stage: .pixels { ctx in f13(ctx, 16) { p in
            p.a = SIMD4(px13(ctx, "cell"), n13(ctx, "threshold", 0.01), 0, 0) } })

    static let thermalPrinter13 = EffectDefinition(
        id: "awi13.thermalPrinter", name: "Thermal Printer", category: .stylize, aeMatchNames: [],
        summary: "Receipt-printer look: dithered dots on paper with faded print rows.",
        params: [.number("dot", "Dot Size", 2, 1, 8, unit: "px"), pct13("darkness", "Darkness", 40),
                 pct13("fade", "Fade Streaks", 40), .color("paper", "Paper", RGBA(0.96, 0.95, 0.9)),
                 .color("ink", "Ink", RGBA(0.12, 0.12, 0.16))],
        stage: .pixels { ctx in f13(ctx, 17) { p in
            p.a = SIMD4(px13(ctx, "dot"), n13(ctx, "darkness", 0.01), n13(ctx, "fade", 0.01), 0)
            p.b = col13(ctx, "paper"); p.c = col13(ctx, "ink") } })

    static let risograph13 = EffectDefinition(
        id: "awi13.risograph", name: "Risograph", category: .stylize, aeMatchNames: [],
        summary: "Two-ink riso print: angled halftone dots, misregistered plates and paper grain.",
        params: [.number("dot", "Dot Size", 5, 2, 20, unit: "px"), .number("misreg", "Misregistration", 3, 0, 20, unit: "px"),
                 pct13("grain", "Grain", 40), .color("ink1", "Ink 1", RGBA(1, 0.28, 0.55)),
                 .color("ink2", "Ink 2", RGBA(0.1, 0.35, 0.85))],
        stage: .pixels { ctx in f13(ctx, 18) { p in
            p.a = SIMD4(px13(ctx, "dot"), px13(ctx, "misreg"), n13(ctx, "grain", 0.01), 0)
            p.b = col13(ctx, "ink1"); p.c = col13(ctx, "ink2") } })

    static let screenPrint13 = EffectDefinition(
        id: "awi13.screenPrint", name: "Screen Print", category: .stylize, aeMatchNames: [],
        summary: "Three flat inks by brightness with offset plates and worn ink texture.",
        params: [pct13("balance", "Balance", 0, -50, 50), pct13("texture", "Ink Wear", 40),
                 .number("offset", "Plate Offset", 3, 0, 20, unit: "px"),
                 .color("dark", "Dark Ink", RGBA(0.1, 0.1, 0.25)), .color("mid", "Mid Ink", RGBA(0.95, 0.3, 0.25)),
                 .color("light", "Paper", RGBA(0.97, 0.9, 0.75))],
        stage: .pixels { ctx in f13(ctx, 19) { p in
            p.a = SIMD4(n13(ctx, "balance", 0.01), n13(ctx, "texture", 0.01), px13(ctx, "offset"), 0)
            p.b = col13(ctx, "dark"); p.c = col13(ctx, "mid")
            let l = col13(ctx, "light"); p.d = SIMD4(0, l.x, l.y, l.z) } })

    // MARK: Screens

    static let ledScreen13 = EffectDefinition(
        id: "awi13.ledScreen", name: "LED Screen", category: .stylize, aeMatchNames: [],
        summary: "Dot-matrix LED wall: each cell becomes one round glowing diode.",
        params: [.number("cell", "Cell Size", 8, 3, 40, unit: "px"), pct13("dot", "Dot Size", 80),
                 pct13("brightness", "Brightness", 130, 50, 300)],
        stage: .pixels { ctx in f13(ctx, 12) { p in
            p.a = SIMD4(px13(ctx, "cell"), n13(ctx, "dot", 0.01), n13(ctx, "brightness", 0.01), 0) } })

    static let lcdSubpixels13 = EffectDefinition(
        id: "awi13.lcdSubpixels", name: "LCD Subpixels", category: .stylize, aeMatchNames: [],
        summary: "Macro view of an LCD panel: every pixel split into red, green and blue stripes.",
        params: [.number("size", "Pixel Size", 6, 3, 30, unit: "px"), pct13("gap", "Gap", 40),
                 pct13("brightness", "Brightness", 100, 50, 300)],
        stage: .pixels { ctx in f13(ctx, 13) { p in
            p.a = SIMD4(max(px13(ctx, "size"), 3), n13(ctx, "gap", 0.01), n13(ctx, "brightness", 0.01), 0) } })

    static let hologramScan13 = EffectDefinition(
        id: "awi13.hologramScan", name: "Hologram Scan", category: .stylize, aeMatchNames: [],
        summary: "Sci-fi projection: tinted image with moving scan lines, sweep band and flicker.",
        params: [pct13("intensity", "Intensity", 90), .number("lines", "Line Count", 60, 4, 200),
                 .number("speed", "Scan Speed", 1, 0, 5, step: 0.01), pct13("flicker", "Flicker", 30),
                 .color("tint", "Tint", RGBA(0.2, 0.75, 1))],
        stage: .pixels { ctx in f13(ctx, 14) { p in
            p.a = SIMD4(n13(ctx, "intensity", 0.01), n13(ctx, "lines"), n13(ctx, "speed"), n13(ctx, "flicker", 0.01))
            p.b = col13(ctx, "tint") } })

    static let analogTV13 = EffectDefinition(
        id: "awi13.analogTV", name: "Analog TV", category: .stylize, aeMatchNames: [],
        summary: "Broadcast-TV reception: snow noise, vertical roll with a hum bar and smeared chroma.",
        params: [pct13("noise", "Noise", 30), .number("roll", "Roll Speed", 0.3, 0, 2, step: 0.01),
                 .number("bleed", "Chroma Bleed", 6, 0, 30, unit: "px")],
        stage: .pixels { ctx in f13(ctx, 15) { p in
            p.a = SIMD4(n13(ctx, "noise", 0.01), n13(ctx, "roll"), px13(ctx, "bleed"), 0) } })

    static let neonSign13 = EffectDefinition(
        id: "awi13.neonSign", name: "Neon Sign", category: .stylize, aeMatchNames: [],
        summary: "Desaturated night scene where bright areas turn into flickering neon tubes with glow.",
        params: [pct13("threshold", "Threshold", 55), .number("radius", "Glow Radius", 8, 1, 40, unit: "px"),
                 pct13("flicker", "Flicker", 30), pct13("desat", "Desaturate", 70),
                 .color("color", "Neon Color", RGBA(1, 0.2, 0.6))],
        stage: .pixels { ctx in f13(ctx, 20) { p in
            p.a = SIMD4(n13(ctx, "threshold", 0.01), px13(ctx, "radius"), n13(ctx, "flicker", 0.01), n13(ctx, "desat", 0.01))
            p.b = col13(ctx, "color") } })

    // MARK: Grades

    static let cyberpunkGrade13 = EffectDefinition(
        id: "awi13.cyberpunk", name: "Cyberpunk Grade", category: .color, aeMatchNames: [],
        summary: "Teal shadows and hot magenta highlights with boosted saturation.",
        params: [pct13("strength", "Strength", 100), pct13("pivot", "Pivot", 45), pct13("saturation", "Saturation", 130, 0, 200)],
        stage: .pixels { ctx in f13(ctx, 21) { p in
            p.a = SIMD4(n13(ctx, "strength", 0.01), n13(ctx, "pivot", 0.01), n13(ctx, "saturation", 0.01), 0) } })

    static let lomo13 = EffectDefinition(
        id: "awi13.lomo", name: "Lomo", category: .color, aeMatchNames: [],
        summary: "Toy-camera look: cross-processed curves, saturated color and a heavy vignette.",
        params: [pct13("strength", "Strength", 100), pct13("vignette", "Vignette", 70), pct13("saturation", "Saturation", 140, 0, 200)],
        stage: .pixels { ctx in f13(ctx, 22) { p in
            p.a = SIMD4(n13(ctx, "strength", 0.01), n13(ctx, "vignette", 0.01), n13(ctx, "saturation", 0.01), 0) } })

    static let dayForNight13 = EffectDefinition(
        id: "awi13.dayForNight", name: "Day for Night", category: .color, aeMatchNames: [],
        summary: "Classic cinema trick: underexposed, blue, desaturated daylight that reads as moonlight.",
        params: [pct13("darkness", "Darkness", 60), pct13("blue", "Blue Tint", 70), pct13("desat", "Desaturate", 50),
                 .color("moon", "Moonlight", RGBA(0.6, 0.75, 1))],
        stage: .pixels { ctx in f13(ctx, 23) { p in
            p.a = SIMD4(n13(ctx, "darkness", 0.01), n13(ctx, "blue", 0.01), n13(ctx, "desat", 0.01), 0)
            p.b = col13(ctx, "moon") } })
}
