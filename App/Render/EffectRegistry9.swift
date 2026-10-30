import Foundation
import Metal
import simd

/// Batch 9: transitions & wipes (layer reveal/hide). Every effect has a "Completion" control:
/// 0% = layer fully visible, 100% = layer fully hidden. Defaults sit at 50% so the effect is visibly mid-transition;
/// keyframe Completion 0→100 to wipe a layer out (or 100→0 to wipe it in).
extension EffectRegistry {
    static let batch9: [EffectDefinition] = [
        clockWipe9, barnDoors9, diagonalWipe9, diamondWipe9, heartWipe9, starWipe9, shapeIris9, pixelDissolve9,
        noiseDissolve9, burnAway9, inkBleed9, slidePush9, zoomThrough9, spinTwist9, glitchReveal9, stripesWipe9,
        checkerWipe9, radialBlinds9, blocksFlip9, rippleDissolve9, directionalBlurWipe9, lumaFade9, gradientSweep9,
        splitReveal9, liquidWipe9,
    ]

    private static func tr9(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        p.a.x = Float(ctx.num("completion") / 100)
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        ctx.gpu.run("fxTrans9", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }
    private static func n9(_ ctx: EffectContext, _ key: String) -> Float { Float(ctx.num(key)) }
    private static func px9(_ ctx: EffectContext, _ key: String) -> Float { Float(ctx.num(key) * ctx.unit) }
    private static func rad9(_ ctx: EffectContext, _ key: String) -> Float { Float(ctx.num(key) * .pi / 180) }
    private static func center9(_ ctx: EffectContext, _ key: String = "center") -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    private static let completion9 = ParamDef.number("completion", "Completion", 50, 0, 100, unit: "%")
    private static func feather9(_ def: Double = 12) -> ParamDef { .number("feather", "Feather", def, 0, 200, unit: "px") }
    private static let center9Def = ParamDef.point("center", "Center", Vec2(0.5, 0.5))

    private static func trans9(_ id: String, _ name: String, _ summary: String, _ params: [ParamDef],
                               _ mode: UInt32, _ fill: @escaping (EffectContext, inout EffectParams) -> Void) -> EffectDefinition {
        EffectDefinition(id: "awi9." + id, name: name, category: .keying, aeMatchNames: [],
                         summary: summary + " Completion 0% = fully visible, 100% = fully hidden.",
                         params: [completion9] + params,
                         stage: .pixels { ctx in tr9(ctx, mode) { p in fill(ctx, &p) } })
    }

    static let clockWipe9 = trans9("clockWipe", "Clock Wipe", "A clock hand sweeps around the center, hiding the layer behind it.",
        [feather9(), .angle("start", "Start Angle", 0), .choice("direction", "Direction", ["Clockwise", "Counter-clockwise"], 0), center9Def], 0) { ctx, p in
        let c = center9(ctx)
        p.a.y = px9(ctx, "feather"); p.a.z = rad9(ctx, "start"); p.a.w = ctx.effect.choice("direction") == 1 ? -1 : 1
        p.c.z = c.x; p.c.w = c.y }

    static let barnDoors9 = trans9("barnDoors", "Barn Doors", "Two doors open from the middle outward, hiding the layer from the center line.",
        [feather9(), .choice("orientation", "Orientation", ["Horizontal", "Vertical"], 0)], 1) { ctx, p in
        p.a.y = px9(ctx, "feather"); p.a.z = Float(ctx.effect.choice("orientation")) }

    static let diagonalWipe9 = trans9("diagonalWipe", "Diagonal Wipe", "A soft straight edge sweeps across at an angle.",
        [feather9(30), .angle("angle", "Angle", 45)], 2) { ctx, p in
        p.a.y = px9(ctx, "feather"); p.a.z = rad9(ctx, "angle") }

    static let diamondWipe9 = trans9("diamondWipe", "Diamond Wipe", "A diamond-shaped hole grows from the center.",
        [feather9(), center9Def], 3) { ctx, p in
        let c = center9(ctx); p.a.y = px9(ctx, "feather"); p.c.z = c.x; p.c.w = c.y }

    static let heartWipe9 = trans9("heartWipe", "Heart Wipe", "A heart-shaped iris closes in on the center.",
        [feather9(), .angle("rotation", "Rotation", 0), center9Def], 4) { ctx, p in
        let c = center9(ctx); p.a.y = px9(ctx, "feather"); p.a.z = rad9(ctx, "rotation"); p.c.z = c.x; p.c.w = c.y }

    static let starWipe9 = trans9("starWipe", "Star Wipe", "A star-shaped iris closes in on the center.",
        [feather9(), .number("points", "Points", 5, 3, 12, step: 1), .number("sharpness", "Sharpness", 3, 2, 8, step: 0.1),
         .angle("rotation", "Rotation", 0), center9Def], 5) { ctx, p in
        let c = center9(ctx)
        p.a.y = px9(ctx, "feather"); p.a.z = rad9(ctx, "rotation"); p.a.w = n9(ctx, "points"); p.b.x = n9(ctx, "sharpness")
        p.c.z = c.x; p.c.w = c.y }

    static let shapeIris9 = trans9("shapeIris", "Shape Iris", "An iris (circle, square, hexagon or diamond) closes in on the center.",
        [feather9(), .choice("shape", "Shape", ["Circle", "Square", "Hexagon", "Diamond"], 0), .angle("rotation", "Rotation", 0), center9Def], 6) { ctx, p in
        let c = center9(ctx)
        p.a.y = px9(ctx, "feather"); p.a.z = rad9(ctx, "rotation"); p.a.w = Float(ctx.effect.choice("shape")); p.c.z = c.x; p.c.w = c.y }

    static let pixelDissolve9 = trans9("pixelDissolve", "Pixel Dissolve", "Random square blocks blink out one by one.",
        [.number("block", "Block Size", 8, 1, 64, unit: "px"), .number("seed", "Random Seed", 1, 0, 100, step: 1)], 7) { ctx, p in
        p.a.y = max(1, px9(ctx, "block")); p.a.z = n9(ctx, "seed") }

    static let noiseDissolve9 = trans9("noiseDissolve", "Noise Dissolve", "Fractal-noise holes eat the layer with a glowing burn edge.",
        [.number("scale", "Noise Scale", 40, 5, 400, unit: "px"), .number("edge", "Edge Width", 0.1, 0, 0.5, step: 0.01),
         .number("glow", "Edge Glow", 1.5, 0, 4, step: 0.01), .color("color", "Edge Color", RGBA(1, 0.55, 0.15))], 8) { ctx, p in
        p.a.y = px9(ctx, "scale"); p.a.z = n9(ctx, "edge"); p.a.w = n9(ctx, "glow"); p.b = ctx.effect.color("color", ctx.time).simd }

    static let burnAway9 = trans9("burnAway", "Burn Away", "Paper burn: a charred band and flickering ember edge consume the layer.",
        [.number("scale", "Noise Scale", 50, 5, 400, unit: "px"), .number("width", "Burn Width", 0.08, 0.005, 0.3, step: 0.005),
         .number("ember", "Ember Intensity", 2, 0, 6, step: 0.01), .number("spread", "Bottom-up Spread", 40, 0, 100, unit: "%"),
         .color("color", "Ember Color", RGBA(1, 0.45, 0.08))], 9) { ctx, p in
        p.a.y = px9(ctx, "scale"); p.a.z = n9(ctx, "width"); p.a.w = n9(ctx, "ember"); p.b = ctx.effect.color("color", ctx.time).simd
        p.c.x = Float(ctx.num("spread") / 100) }

    static let inkBleed9 = trans9("inkBleed", "Ink Bleed", "An inky blot with ragged edges spreads out from the center, tinting its rim.",
        [.number("roughness", "Roughness", 0.5, 0, 1.5, step: 0.01), .number("scale", "Noise Scale", 30, 5, 300, unit: "px"),
         feather9(8), .color("ink", "Ink Color", RGBA(0.05, 0.05, 0.12)), center9Def], 10) { ctx, p in
        let c = center9(ctx)
        p.a.y = n9(ctx, "roughness"); p.a.z = px9(ctx, "scale"); p.a.w = px9(ctx, "feather"); p.b = ctx.effect.color("ink", ctx.time).simd
        p.c.z = c.x; p.c.w = c.y }

    static let slidePush9 = trans9("slidePush", "Slide Push", "The layer slides out of frame with motion blur.",
        [.angle("angle", "Direction", 0), .number("blur", "Motion Blur", 30, 0, 200, unit: "px")], 11) { ctx, p in
        p.a.y = rad9(ctx, "angle"); p.a.z = px9(ctx, "blur") }

    static let zoomThrough9 = trans9("zoomThrough", "Zoom Through", "Rushes into the layer with a zoom blur, fading away at the end.",
        [.number("zoom", "Zoom Amount", 6, 0, 20, step: 0.1), .number("fade", "Fade Start", 50, 0, 95, unit: "%"),
         .number("blur", "Zoom Blur", 30, 0, 100, unit: "%"), center9Def], 12) { ctx, p in
        let c = center9(ctx)
        p.a.y = n9(ctx, "zoom"); p.a.z = Float(ctx.num("fade") / 100); p.a.w = Float(ctx.num("blur") / 100); p.c.z = c.x; p.c.w = c.y }

    static let spinTwist9 = trans9("spinTwist", "Spin Twist", "Twirls the layer around the center while a hole opens in the middle.",
        [.number("twist", "Twist", 360, 0, 1080, unit: "°"), feather9(20), center9Def], 13) { ctx, p in
        let c = center9(ctx)
        p.a.y = rad9(ctx, "twist"); p.a.z = px9(ctx, "feather"); p.c.z = c.x; p.c.w = c.y }

    static let glitchReveal9 = trans9("glitchReveal", "Glitch Reveal", "Horizontal bands jitter with RGB split and drop out at random.",
        [.number("band", "Band Height", 8, 2, 60, unit: "px"), .number("shift", "Displacement", 20, 0, 100, unit: "px"),
         .number("split", "RGB Split", 6, 0, 30, unit: "px"), .number("seed", "Random Seed", 1, 0, 100, step: 1)], 14) { ctx, p in
        p.a.y = px9(ctx, "band"); p.a.z = px9(ctx, "shift"); p.a.w = px9(ctx, "split"); p.c.x = n9(ctx, "seed") }

    static let stripesWipe9 = trans9("stripesWipe", "Stripes Wipe", "Angled stripes each wipe shut, staggered across the frame.",
        [.number("count", "Stripes", 8, 2, 40, step: 1), .number("feather", "Softness", 0.08, 0, 0.5, step: 0.01),
         .number("stagger", "Stagger", 0.5, 0, 2, step: 0.01), .angle("angle", "Angle", 0)], 15) { ctx, p in
        p.a.y = n9(ctx, "count"); p.a.z = n9(ctx, "feather"); p.a.w = n9(ctx, "stagger"); p.b.x = rad9(ctx, "angle") }

    static let checkerWipe9 = trans9("checkerWipe", "Checker Wipe", "Alternating checkerboard squares wipe shut in two waves.",
        [.number("cell", "Square Size", 24, 4, 200, unit: "px"), .number("feather", "Softness", 0.1, 0, 0.5, step: 0.01)], 16) { ctx, p in
        p.a.y = px9(ctx, "cell"); p.a.z = n9(ctx, "feather") }

    static let radialBlinds9 = trans9("radialBlinds", "Radial Blinds", "Pie-slice blinds around the center each close like a fan.",
        [.number("count", "Blades", 8, 2, 48, step: 1), .number("feather", "Softness", 0.08, 0, 0.5, step: 0.01),
         .angle("rotation", "Rotation", 0), center9Def], 17) { ctx, p in
        let c = center9(ctx)
        p.a.y = n9(ctx, "count"); p.a.z = n9(ctx, "feather"); p.a.w = rad9(ctx, "rotation"); p.c.z = c.x; p.c.w = c.y }

    static let blocksFlip9 = trans9("blocksFlip", "Blocks Flip", "The layer splits into tiles that flip edge-on and vanish.",
        [.number("block", "Block Size", 20, 4, 200, unit: "px"), .number("stagger", "Stagger", 60, 0, 90, unit: "%"),
         .choice("order", "Order", ["Random", "Diagonal", "From Center"], 0)], 18) { ctx, p in
        p.a.y = px9(ctx, "block"); p.a.z = Float(ctx.num("stagger") / 100); p.a.w = Float(ctx.effect.choice("order")) }

    static let rippleDissolve9 = trans9("rippleDissolve", "Ripple Dissolve", "A rippling ring spreads outward, warping and dissolving the layer.",
        [.number("wavelength", "Wavelength", 16, 4, 80, unit: "px"), .number("amplitude", "Amplitude", 10, 0, 60, unit: "px"),
         feather9(8), center9Def], 19) { ctx, p in
        let c = center9(ctx)
        p.a.y = px9(ctx, "wavelength"); p.a.z = px9(ctx, "amplitude"); p.a.w = px9(ctx, "feather"); p.c.z = c.x; p.c.w = c.y }

    static let directionalBlurWipe9 = trans9("directionalBlurWipe", "Directional Blur Wipe", "A linear wipe whose edge smears with motion blur.",
        [.angle("angle", "Angle", 0), .number("blur", "Blur Length", 40, 0, 200, unit: "px"),
         .number("edge", "Edge Width", 40, 1, 300, unit: "px")], 20) { ctx, p in
        p.a.y = rad9(ctx, "angle"); p.a.z = px9(ctx, "blur"); p.a.w = px9(ctx, "edge") }

    static let lumaFade9 = trans9("lumaFade", "Luma Fade", "Hides the layer by its own brightness: brightest (or darkest) parts go first.",
        [.number("softness", "Softness", 0.15, 0, 0.5, step: 0.01), .toggle("brightFirst", "Bright Parts First", true)], 21) { ctx, p in
        p.a.y = n9(ctx, "softness"); p.a.z = ctx.effect.bool("brightFirst") ? 1 : 0 }

    static let gradientSweep9 = trans9("gradientSweep", "Gradient Sweep Wipe", "A linear wipe led by a glowing band of light.",
        [.angle("angle", "Angle", 0), .number("width", "Light Width", 12, 1, 100, unit: "px"),
         .number("intensity", "Light Intensity", 1.2, 0, 4, step: 0.01), .number("softness", "Softness", 6, 0, 100, unit: "px"),
         .color("color", "Light Color", RGBA(1, 0.95, 0.8))], 22) { ctx, p in
        p.a.y = rad9(ctx, "angle"); p.a.z = px9(ctx, "width"); p.a.w = n9(ctx, "intensity")
        p.b = ctx.effect.color("color", ctx.time).simd; p.c.x = px9(ctx, "softness") }

    static let splitReveal9 = trans9("splitReveal", "Split Reveal", "The layer splits down the middle and both halves slide apart, edges glowing.",
        [.angle("angle", "Split Direction", 0), .number("glow", "Edge Glow", 8, 0, 60, unit: "px"),
         .color("color", "Glow Color", RGBA(1, 1, 1))], 23) { ctx, p in
        p.a.y = rad9(ctx, "angle"); p.a.z = px9(ctx, "glow"); p.b = ctx.effect.color("color", ctx.time).simd }

    static let liquidWipe9 = trans9("liquidWipe", "Liquid Wipe", "A linear wipe with a flowing, wavy liquid edge (animated).",
        [.angle("angle", "Angle", 0), .number("amplitude", "Wave Height", 12, 0, 80, unit: "px"),
         .number("wavelength", "Wavelength", 40, 4, 300, unit: "px"), .number("speed", "Flow Speed", 3, 0, 10, step: 0.1),
         feather9(4)], 24) { ctx, p in
        p.a.y = rad9(ctx, "angle"); p.a.z = px9(ctx, "amplitude"); p.a.w = px9(ctx, "wavelength")
        p.b.x = n9(ctx, "speed"); p.b.y = px9(ctx, "feather") }
}
