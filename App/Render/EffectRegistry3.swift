import Foundation
import Metal
import simd

/// Batch 3: generators, more stylize/distort, transitions, color tools and mattes (AE + Alight Motion staples).
extension EffectRegistry {
    static let batch3: [EffectDefinition] = [
        gradientRamp, fourColorGradient, checkerboard, grid, cellPattern, lightning, lensFlare,
        emboss, roughenEdges, scatter, strobe, kaleida, sharpen, unsharpMask, dropShadow,
        ripple, spherize, magnify, cornerPin, ccLens,
        linearWipe, radialWipe, irisWipe, blockDissolve, venetianBlinds, gradientWipe,
        colorBalance, vibrance, blackWhite, photoFilter, tritone, leaveColor, changeToColor,
        simpleChoker, lumaKey,
    ]

    private static func f(_ v: Double) -> Float { Float(v) }
    private static func px(_ ctx: EffectContext, _ p: Vec2) -> SIMD2<Float> { SIMD2(Float(p.x * Double(ctx.width)), Float(p.y * Double(ctx.height))) }

    private static func k(_ kernel: String, _ mode: UInt32, _ ctx: EffectContext, aux: MTLTexture? = nil,
                          _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        let tex = aux.map { [ctx.input, out, $0] } ?? (["fxStylize2", "fxMatte"].contains(kernel) ? [ctx.input, out, ctx.input] : [ctx.input, out])
        ctx.gpu.run(kernel, ctx.cb, textures: tex, params: p, grid: out)
        return out
    }

    // MARK: Generate

    static let gradientRamp = EffectDefinition(
        id: "ae.gradientRamp", name: "Gradient Ramp", category: .generate, aeMatchNames: ["ADBE Ramp"],
        summary: "Linear or radial gradient between two colors.",
        params: [.point("start", "Start of Ramp", Vec2(0.5, 0), ae: 1), .color("startColor", "Start Color", .black, ae: 2),
                 .point("end", "End of Ramp", Vec2(0.5, 1), ae: 3), .color("endColor", "End Color", .white, ae: 4),
                 .choice("shape", "Ramp Shape", ["Linear Ramp", "Radial Ramp"], 0, ae: 5),
                 .number("blend", "Blend With Original", 0, 0, 100, unit: "%", ae: 7)],
        stage: .pixels { ctx in k("fxGenerate", 0, ctx) { p in
            let s = px(ctx, ctx.effect.point("start", ctx.time)), e = px(ctx, ctx.effect.point("end", ctx.time))
            p.a = SIMD4(s.x, s.y, e.x, e.y); p.b = ctx.effect.color("startColor", ctx.time).simd; p.c = ctx.effect.color("endColor", ctx.time).simd
            p.d.w = f(ctx.num("blend") / 100); p.i.y = UInt32(ctx.effect.choice("shape")) } })

    static let fourColorGradient = EffectDefinition(
        id: "ae.fourColorGradient", name: "4-Color Gradient", category: .generate, aeMatchNames: ["ADBE 4ColorGradient"],
        summary: "Smooth blend of four colored points.",
        params: [.point("p1", "Point 1", Vec2(0.1, 0.1), ae: 1), .color("c1", "Color 1", RGBA(1, 0.9, 0.2), ae: 2),
                 .point("p2", "Point 2", Vec2(0.9, 0.1), ae: 3), .color("c2", "Color 2", RGBA(0.1, 0.8, 0.3), ae: 4),
                 .point("p3", "Point 3", Vec2(0.1, 0.9), ae: 5), .color("c3", "Color 3", RGBA(0.9, 0.2, 0.8), ae: 6),
                 .point("p4", "Point 4", Vec2(0.9, 0.9), ae: 7), .color("c4", "Color 4", RGBA(0.1, 0.3, 1), ae: 8),
                 .number("blend", "Blend With Original", 0, 0, 100, unit: "%")],
        stage: .pixels { ctx in k("fxGenerate", 1, ctx) { p in
            let t = ctx.time
            let p1 = px(ctx, ctx.effect.point("p1", t)), p2 = px(ctx, ctx.effect.point("p2", t))
            let p3 = px(ctx, ctx.effect.point("p3", t)), p4 = px(ctx, ctx.effect.point("p4", t))
            p.a = SIMD4(p1.x, p1.y, p2.x, p2.y); p.b = SIMD4(p3.x, p3.y, p4.x, p4.y)
            let c1 = ctx.effect.color("c1", t), c2 = ctx.effect.color("c2", t), c3 = ctx.effect.color("c3", t), c4 = ctx.effect.color("c4", t)
            func b(_ v: Double) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
            p.c = SIMD4(f(c1.r), f(c1.g), f(c1.b), f(c2.r))
            p.d = SIMD4(f(c2.g), f(c2.b), f(c3.r), f(ctx.num("blend") / 100))
            p.i = SIMD4(0, b(c3.g), b(c3.b), b(c4.r) | (b(c4.g) << 8) | (b(c4.b) << 16)) } })

    static let checkerboard = EffectDefinition(
        id: "ae.checkerboard", name: "Checkerboard", category: .generate, aeMatchNames: ["ADBE Checkerboard"],
        summary: "Checker pattern over the layer.",
        params: [.point("anchor", "Anchor", Vec2(0.5, 0.5), ae: 1), .number("size", "Width", 40, 2, 1000, unit: "px", ae: 3),
                 .color("color", "Color", .white, ae: 5), .number("opacity", "Opacity", 100, 0, 100, unit: "%", ae: 6)],
        stage: .pixels { ctx in k("fxGenerate", 2, ctx) { p in
            let a = px(ctx, ctx.effect.point("anchor", ctx.time))
            p.a = SIMD4(a.x, a.y, f(ctx.num("size") * ctx.unit), 0); p.b = ctx.effect.color("color", ctx.time).simd; p.c.x = f(ctx.num("opacity") / 100) } })

    static let grid = EffectDefinition(
        id: "ae.grid", name: "Grid", category: .generate, aeMatchNames: ["ADBE Grid"],
        summary: "Grid lines over the layer.",
        params: [.point("anchor", "Anchor", Vec2(0.5, 0.5), ae: 1), .number("size", "Cell Size", 60, 4, 1000, unit: "px"),
                 .number("width", "Border", 2, 0.5, 50, unit: "px"), .color("color", "Color", .white)],
        stage: .pixels { ctx in k("fxGenerate", 3, ctx) { p in
            let a = px(ctx, ctx.effect.point("anchor", ctx.time))
            p.a = SIMD4(a.x, a.y, f(ctx.num("size") * ctx.unit), f(ctx.num("width") * ctx.unit)); p.b = ctx.effect.color("color", ctx.time).simd } })

    static let cellPattern = EffectDefinition(
        id: "ae.cellPattern", name: "Cell Pattern", category: .generate, aeMatchNames: ["ADBE Cell Pattern"],
        summary: "Organic cells (Voronoi) — textures, scales, energy.",
        params: [.number("size", "Size", 60, 4, 1000, unit: "px", ae: 4), .number("evolution", "Evolution", 0, -3600, 3600, unit: "°"),
                 .number("contrast", "Contrast", 2, 0.1, 10, step: 0.1)],
        stage: .pixels { ctx in k("fxGenerate", 4, ctx) { p in
            p.a = SIMD4(f(ctx.num("size") * ctx.unit), f(ctx.num("evolution") / 360), f(ctx.num("contrast")), 0) } })

    static let lightning = EffectDefinition(
        id: "ae.lightning", name: "Advanced Lightning", category: .generate, aeMatchNames: ["ADBE Lightning 2", "ADBE Lightning"],
        summary: "Crackling bolt between two points, re-shaped every frame.",
        params: [.point("start", "Origin", Vec2(0.2, 0.2), ae: 2), .point("end", "Direction", Vec2(0.8, 0.8), ae: 3),
                 .number("width", "Core Width", 2, 0.5, 30, unit: "px"), .color("color", "Glow Color", RGBA(0.5, 0.6, 1)),
                 .number("rate", "Flicker Rate", 12, 0, 60, unit: "/s")],
        stage: .pixels { ctx in k("fxGenerate", 5, ctx) { p in
            let s = px(ctx, ctx.effect.point("start", ctx.time)), e = px(ctx, ctx.effect.point("end", ctx.time))
            p.a = SIMD4(s.x, s.y, e.x, e.y); p.b = SIMD4(f((ctx.time * ctx.num("rate")).rounded(.down)), 0, f(ctx.num("width") * ctx.unit), 0)
            p.c = ctx.effect.color("color", ctx.time).simd } })

    static let lensFlare = EffectDefinition(
        id: "ae.lensFlare", name: "Lens Flare", category: .generate, aeMatchNames: ["ADBE Lens Flare"],
        summary: "Bright flare with ring, ghosts and streak.",
        params: [.point("center", "Flare Center", Vec2(0.3, 0.3), ae: 1), .number("brightness", "Flare Brightness", 100, 0, 300, unit: "%", ae: 2)],
        stage: .pixels { ctx in k("fxGenerate", 6, ctx) { p in
            let c = px(ctx, ctx.effect.point("center", ctx.time)); p.a = SIMD4(c.x, c.y, f(ctx.num("brightness")), 0) } })

    // MARK: Stylize

    static let emboss = EffectDefinition(
        id: "ae.emboss", name: "Emboss", category: .stylize, aeMatchNames: ["ADBE Emboss"],
        summary: "Raised relief from edges.",
        params: [.angle("direction", "Direction", 45, ae: 1), .number("relief", "Relief", 2, 0.5, 20, ae: 2),
                 .number("blend", "Blend With Original", 0, 0, 100, unit: "%", ae: 4)],
        stage: .pixels { ctx in k("fxStylize2", 0, ctx) { p in p.a = SIMD4(f(ctx.num("direction")), f(ctx.num("relief") * ctx.unit), f(ctx.num("blend") / 100), 0) } })

    static let roughenEdges = EffectDefinition(
        id: "ae.roughenEdges", name: "Roughen Edges", category: .stylize, aeMatchNames: ["ADBE Roughen Edges"],
        summary: "Eroded, painterly or burnt edges.",
        params: [.number("border", "Border", 8, 0, 200, unit: "px", ae: 3), .number("scale", "Scale", 20, 1, 400, unit: "px", ae: 6),
                 .number("evolution", "Evolution", 0, -3600, 3600, unit: "°", ae: 10)],
        margin: { e, t in e.number("border", t) },
        stage: .pixels { ctx in k("fxStylize2", 1, ctx) { p in p.a = SIMD4(f(ctx.num("border") * ctx.unit), f(ctx.num("scale") * ctx.unit), f(ctx.num("evolution") / 360), 0) } })

    static let scatter = EffectDefinition(
        id: "ae.scatter", name: "Scatter", category: .stylize, aeMatchNames: ["ADBE Scatter"],
        summary: "Grainy pixel scatter.", params: [.number("amount", "Scatter Amount", 10, 0, 200, unit: "px", ae: 1)],
        margin: { e, t in e.number("amount", t) },
        stage: .pixels { ctx in k("fxStylize2", 2, ctx) { p in p.a.x = f(ctx.num("amount") * ctx.unit) } })

    static let strobe = EffectDefinition(
        id: "ae.strobe", name: "Strobe Light", category: .stylize, aeMatchNames: ["ADBE Strobe"],
        summary: "Flashes a color on a rhythm.",
        params: [.color("color", "Strobe Color", .white, ae: 1), .number("blend", "Blend", 100, 0, 100, unit: "%", ae: 2),
                 .number("duration", "Strobe Duration", 0.05, 0.01, 2, step: 0.01, unit: "s", ae: 3),
                 .number("period", "Strobe Period", 0.25, 0.02, 5, step: 0.01, unit: "s", ae: 4)],
        stage: .pixels { ctx in k("fxStylize2", 3, ctx) { p in
            let on = ctx.time.truncatingRemainder(dividingBy: max(ctx.num("period"), 0.01)) < ctx.num("duration")
            p.a = SIMD4(on ? 1 : 0, f(ctx.num("blend") / 100), 0, 0); p.b = ctx.effect.color("color", ctx.time).simd } })

    static let kaleida = EffectDefinition(
        id: "cc.kaleida", name: "Kaleida", category: .stylize, aeMatchNames: ["CC Kaleida"],
        summary: "Kaleidoscope mirrors.",
        params: [.point("center", "Center", Vec2(0.5, 0.5), ae: 1), .number("size", "Size", 120, 4, 2000, unit: "px", ae: 2),
                 .number("mirrors", "Mirroring", 6, 2, 24, step: 1, ae: 3), .angle("rotation", "Rotation", 0, ae: 4)],
        stage: .pixels { ctx in k("fxStylize2", 4, ctx) { p in
            let c = px(ctx, ctx.effect.point("center", ctx.time))
            p.a = SIMD4(c.x, c.y, f(ctx.num("size") * ctx.unit), f(ctx.num("rotation"))); p.i.y = UInt32(max(2, ctx.num("mirrors"))) } })

    static let sharpen = EffectDefinition(
        id: "ae.sharpen", name: "Sharpen", category: .blur, aeMatchNames: ["ADBE Sharpen"],
        summary: "Crisper detail.", params: [.number("amount", "Sharpen Amount", 30, 0, 100, ae: 1)],
        stage: .pixels { ctx in k("fxStylize2", 5, ctx) { p in p.a.x = f(ctx.num("amount") / 50) } })

    static let unsharpMask = EffectDefinition(
        id: "ae.unsharpMask", name: "Unsharp Mask", category: .blur, aeMatchNames: ["ADBE Unsharp Mask2", "ADBE Unsharp Mask"],
        summary: "Classic radius-based sharpening.",
        params: [.number("amount", "Amount", 50, 0, 500, unit: "%", ae: 1), .number("radius", "Radius", 2, 0.1, 50, step: 0.1, unit: "px", ae: 2),
                 .number("threshold", "Threshold", 0, 0, 255, ae: 3)],
        stage: .pixels { ctx in
            let blurred = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: ctx.num("radius") * ctx.unit)
            return k("fxStylize2", 6, ctx, aux: blurred) { p in p.a = SIMD4(f(ctx.num("amount") / 100), f(ctx.num("threshold") / 255), 0, 0) }
        })

    static let dropShadow = EffectDefinition(
        id: "ae.dropShadow", name: "Drop Shadow", category: .stylize, aeMatchNames: ["ADBE Drop Shadow"],
        summary: "Soft shadow behind the layer.",
        params: [.color("color", "Shadow Color", .black, ae: 1), .number("opacity", "Opacity", 50, 0, 100, unit: "%", ae: 2),
                 .angle("direction", "Direction", 135, ae: 3), .number("distance", "Distance", 20, 0, 1000, unit: "px", ae: 4),
                 .number("softness", "Softness", 20, 0, 300, unit: "px", ae: 5), .toggle("only", "Shadow Only", false, ae: 6)],
        margin: { e, t in e.number("distance", t) + e.number("softness", t) * 2 },
        stage: .pixels { ctx in
            let a = (ctx.num("direction") - 90) * .pi / 180, d = ctx.num("distance") * ctx.unit
            let prep = k("fxMatte", 2, ctx) { p in
                p.a = SIMD4(f(cos(a) * d), f(sin(a) * d), f(ctx.num("opacity") / 100), 0); p.b = ctx.effect.color("color", ctx.time).simd }
            let soft = ctx.gpu.gaussian(ctx, input: prep, sigma: ctx.num("softness") / 2 * ctx.unit)
            if ctx.effect.bool("only") { return soft }
            let out = ctx.temp(); var p = EffectParams(); p.i.x = 3
            ctx.gpu.run("fxMatte", ctx.cb, textures: [soft, out, ctx.input], params: p, grid: out)
            return out
        })

    // MARK: Distort

    static let ripple = EffectDefinition(
        id: "ae.ripple", name: "Ripple", category: .distort, aeMatchNames: ["ADBE Ripple"],
        summary: "Water ripples from a center.",
        params: [.number("radius", "Radius", 60, 1, 100, unit: "%", ae: 1), .point("center", "Center of Ripple", Vec2(0.5, 0.5), ae: 2),
                 .number("width", "Wave Width", 40, 2, 500, unit: "px", ae: 5), .number("height", "Wave Height", 12, 0, 200, unit: "px", ae: 6),
                 .number("speed", "Wave Speed", 1, -10, 10, step: 0.1, ae: 4)],
        stage: .pixels { ctx in k("fxDistort2", 0, ctx) { p in
            let c = px(ctx, ctx.effect.point("center", ctx.time))
            p.a = SIMD4(c.x, c.y, f(ctx.num("radius") / 100 * Double(max(ctx.width, ctx.height))), f(ctx.num("width") * ctx.unit))
            p.b = SIMD4(f(ctx.num("height") * ctx.unit), f(ctx.time * ctx.num("speed") * 2 * .pi), 0, 0) } })

    static let spherize = EffectDefinition(
        id: "ae.spherize", name: "Spherize", category: .distort, aeMatchNames: ["ADBE Spherize"],
        summary: "Wraps the image around a sphere.",
        params: [.number("radius", "Radius", 150, 1, 2000, unit: "px", ae: 1), .point("center", "Center of Sphere", Vec2(0.5, 0.5), ae: 2),
                 .number("amount", "Amount", 100, 0, 100, unit: "%")],
        stage: .pixels { ctx in k("fxDistort2", 1, ctx) { p in
            let c = px(ctx, ctx.effect.point("center", ctx.time)); p.a = SIMD4(c.x, c.y, f(ctx.num("radius") * ctx.unit), f(ctx.num("amount") / 100)) } })

    static let magnify = EffectDefinition(
        id: "ae.magnify", name: "Magnify", category: .distort, aeMatchNames: ["ADBE Magnify"],
        summary: "Zoomed loupe circle.",
        params: [.point("center", "Center", Vec2(0.5, 0.5), ae: 2), .number("mag", "Magnification", 200, 100, 1000, unit: "%", ae: 3),
                 .number("size", "Size", 120, 4, 2000, unit: "px", ae: 5)],
        stage: .pixels { ctx in k("fxDistort2", 2, ctx) { p in
            let c = px(ctx, ctx.effect.point("center", ctx.time)); p.a = SIMD4(c.x, c.y, f(ctx.num("mag") / 100), f(ctx.num("size") * ctx.unit)) } })

    static let cornerPin = EffectDefinition(
        id: "ae.cornerPin", name: "Corner Pin", category: .distort, aeMatchNames: ["ADBE Corner Pin"],
        summary: "Moves the four corners — screens, posters, perspective.",
        params: [.point("ul", "Upper Left", Vec2(0, 0), ae: 1), .point("ur", "Upper Right", Vec2(1, 0), ae: 2),
                 .point("ll", "Lower Left", Vec2(0, 1), ae: 3), .point("lr", "Lower Right", Vec2(1, 1), ae: 4)],
        stage: .pixels { ctx in k("fxDistort2", 3, ctx) { p in
            let t = ctx.time, w = Double(ctx.width), h = Double(ctx.height)
            let dst = [ctx.effect.point("ul", t), ctx.effect.point("ur", t), ctx.effect.point("ll", t), ctx.effect.point("lr", t)].map { Vec2($0.x * w, $0.y * h) }
            let src = [Vec2(0, 0), Vec2(w, 0), Vec2(0, h), Vec2(w, h)]
            // Homography target -> source (inverse warp).
            let H = Homography.solve(from: dst, to: src)
            p.a = SIMD4(f(H[0][0]), f(H[1][0]), f(H[2][0]), 0)
            p.b = SIMD4(f(H[0][1]), f(H[1][1]), f(H[2][1]), 0)
            p.c = SIMD4(f(H[0][2]), f(H[1][2]), f(H[2][2]), 0) } })

    static let ccLens = EffectDefinition(
        id: "cc.lens", name: "CC Lens", category: .distort, aeMatchNames: ["CC Lens"],
        summary: "Round fisheye lens.",
        params: [.point("center", "Center", Vec2(0.5, 0.5), ae: 1), .number("size", "Size", 45, 1, 100, unit: "%", ae: 2),
                 .number("convergence", "Convergence", 0, -1, 2, step: 0.01, ae: 3)],
        stage: .pixels { ctx in k("fxDistort2", 4, ctx) { p in
            let c = px(ctx, ctx.effect.point("center", ctx.time))
            p.a = SIMD4(c.x, c.y, f(ctx.num("size") / 100 * Double(min(ctx.width, ctx.height))), f(ctx.num("convergence"))) } })

    // MARK: Transitions

    private static func wipe(_ id: String, _ name: String, _ ae: [String], _ summary: String, _ mode: UInt32, extra: [ParamDef],
                             _ fill: @escaping (EffectContext, inout EffectParams) -> Void) -> EffectDefinition {
        EffectDefinition(id: id, name: name, category: .keying, aeMatchNames: ae, summary: summary,
                         params: [.number("completion", "Transition Completion", 0, 0, 100, unit: "%", ae: 1),
                                  .number("feather", "Feather", 10, 0, 500, unit: "px")] + extra,
                         stage: .pixels { ctx in k("fxTransition", mode, ctx) { p in
                             p.a.x = f(ctx.num("completion") / 100); p.a.y = f(ctx.num("feather") * ctx.unit); fill(ctx, &p) } })
    }

    static let linearWipe = wipe("ae.linearWipe", "Linear Wipe", ["ADBE Linear Wipe"], "Wipes the layer away along an angle.", 0,
                                 extra: [.angle("angle", "Wipe Angle", 90, ae: 2)]) { ctx, p in p.a.z = f(ctx.num("angle")) }
    static let radialWipe = wipe("ae.radialWipe", "Radial Wipe", ["ADBE Radial Wipe"], "Clock-hand reveal.", 1,
                                 extra: [.angle("start", "Start Angle", 0, ae: 2), .point("center", "Wipe Center", Vec2(0.5, 0.5), ae: 3),
                                         .choice("direction", "Wipe", ["Clockwise", "Counterclockwise"], 0, ae: 4)]) { ctx, p in
        let c = px(ctx, ctx.effect.point("center", ctx.time)); p.a.z = f(ctx.num("start")); p.b = SIMD4(c.x, c.y, 0, 0); p.i.y = UInt32(ctx.effect.choice("direction")) }
    static let irisWipe = wipe("ae.irisWipe", "Iris Wipe", ["ADBE Iris Wipe"], "Circle closes in on a point.", 2,
                               extra: [.point("center", "Iris Center", Vec2(0.5, 0.5), ae: 1)]) { ctx, p in
        let c = px(ctx, ctx.effect.point("center", ctx.time)); p.b = SIMD4(c.x, c.y, 0, 0); p.a.z = f(hypot(Double(ctx.width), Double(ctx.height)) / 2) }
    static let blockDissolve = wipe("ae.blockDissolve", "Block Dissolve", ["ADBE Block Dissolve"], "Random blocks vanish.", 3,
                                    extra: [.number("block", "Block Size", 16, 1, 400, unit: "px", ae: 2)]) { ctx, p in p.a.z = f(ctx.num("block") * ctx.unit) }
    static let venetianBlinds = wipe("ae.venetianBlinds", "Venetian Blinds", ["ADBE Venetian Blinds"], "Stripes close like blinds.", 4,
                                     extra: [.angle("direction", "Direction", 0, ae: 2), .number("width", "Width", 40, 2, 1000, unit: "px", ae: 3)]) { ctx, p in
        p.a.z = f(ctx.num("direction")); p.a.w = f(ctx.num("width") * ctx.unit) }
    static let gradientWipe = wipe("ae.gradientWipe", "Gradient Wipe", ["ADBE Gradient Wipe"], "Dark areas vanish first (luma wipe).", 5,
                                   extra: [.number("softness", "Transition Softness", 20, 0, 100, unit: "%", ae: 2)]) { ctx, p in p.a.z = f(ctx.num("softness") / 100) }

    // MARK: Color

    private static func col(_ mode: UInt32, _ ctx: EffectContext, _ fill: (inout EffectParams) -> Void) -> MTLTexture { k("fxColor3", mode, ctx, fill) }

    static let colorBalance = EffectDefinition(
        id: "ae.colorBalance", name: "Color Balance", category: .color, aeMatchNames: ["ADBE Color Balance 2"],
        summary: "Push shadows, midtones and highlights toward colors.",
        params: [.number("sr", "Shadow Red", 0, -100, 100), .number("sg", "Shadow Green", 0, -100, 100), .number("sb", "Shadow Blue", 0, -100, 100),
                 .number("mr", "Midtone Red", 0, -100, 100), .number("mg", "Midtone Green", 0, -100, 100), .number("mb", "Midtone Blue", 0, -100, 100),
                 .number("hr", "Highlight Red", 0, -100, 100), .number("hg", "Highlight Green", 0, -100, 100), .number("hb", "Highlight Blue", 0, -100, 100)],
        stage: .pixels { ctx in col(0, ctx) { p in
            func v(_ k: String) -> Float { f(ctx.num(k) / 100) }
            p.a = SIMD4(v("sr"), v("sg"), v("sb"), 0); p.b = SIMD4(v("mr"), v("mg"), v("mb"), 0); p.c = SIMD4(v("hr"), v("hg"), v("hb"), 0) } })

    static let vibrance = EffectDefinition(
        id: "ae.vibrance", name: "Vibrance", category: .color, aeMatchNames: ["ADBE Vibrance"],
        summary: "Boosts muted colors more than saturated ones.",
        params: [.number("vibrance", "Vibrance", 30, -100, 100, ae: 1), .number("saturation", "Saturation", 0, -100, 100, ae: 2)],
        stage: .pixels { ctx in col(1, ctx) { p in p.a = SIMD4(f(ctx.num("vibrance") / 100), f(ctx.num("saturation") / 100), 0, 0) } })

    static let blackWhite = EffectDefinition(
        id: "ae.blackWhite", name: "Black & White", category: .color, aeMatchNames: ["ADBE Black&White"],
        summary: "Monochrome with per-hue brightness and optional tint.",
        params: [.number("reds", "Reds", 40, -200, 300), .number("yellows", "Yellows", 60, -200, 300), .number("greens", "Greens", 40, -200, 300),
                 .number("cyans", "Cyans", 60, -200, 300), .number("blues", "Blues", 20, -200, 300), .number("magentas", "Magentas", 80, -200, 300),
                 .number("tint", "Tint Amount", 0, 0, 100, unit: "%"), .color("tintColor", "Tint Color", RGBA(1, 0.85, 0.6))],
        stage: .pixels { ctx in col(2, ctx) { p in
            func v(_ k: String) -> Float { f(ctx.num(k) / 100) }
            p.a = SIMD4(v("reds"), v("yellows"), v("greens"), v("cyans")); p.b = SIMD4(v("blues"), v("magentas"), v("tint"), 0)
            p.c = ctx.effect.color("tintColor", ctx.time).simd } })

    static let photoFilter = EffectDefinition(
        id: "ae.photoFilter", name: "Photo Filter", category: .color, aeMatchNames: ["ADBE Photo Filter"],
        summary: "Lens filter tint (warm, cool, any color).",
        params: [.color("color", "Color", RGBA(1, 0.6, 0.2), ae: 2), .number("density", "Density", 25, 0, 100, unit: "%", ae: 3),
                 .toggle("preserve", "Preserve Luminosity", true, ae: 4)],
        stage: .pixels { ctx in col(3, ctx) { p in
            p.b = ctx.effect.color("color", ctx.time).simd; p.a.x = f(ctx.num("density") / 100); p.i.y = ctx.effect.bool("preserve") ? 1 : 0 } })

    static let tritone = EffectDefinition(
        id: "ae.tritone", name: "Tritone", category: .color, aeMatchNames: ["ADBE Tritone"],
        summary: "Maps shadows, mids and highlights to three colors.",
        params: [.color("high", "Highlights", .white, ae: 1), .color("mid", "Midtones", RGBA(0.6, 0.35, 0.9), ae: 2),
                 .color("shadow", "Shadows", RGBA(0.05, 0.02, 0.12), ae: 3), .number("blend", "Blend With Original", 0, 0, 100, unit: "%", ae: 4)],
        stage: .pixels { ctx in col(4, ctx) { p in
            p.b = ctx.effect.color("high", ctx.time).simd; p.c = ctx.effect.color("mid", ctx.time).simd
            p.d = ctx.effect.color("shadow", ctx.time).simd; p.a.w = f(ctx.num("blend") / 100) } })

    static let leaveColor = EffectDefinition(
        id: "ae.leaveColor", name: "Leave Color", category: .color, aeMatchNames: ["ADBE Leave Color"],
        summary: "Everything gray except one color.",
        params: [.number("amount", "Amount to Decolor", 100, 0, 100, unit: "%", ae: 1), .color("color", "Color To Leave", RGBA(1, 0, 0), ae: 2),
                 .number("tolerance", "Tolerance", 10, 0, 50, unit: "%", ae: 3)],
        stage: .pixels { ctx in col(5, ctx) { p in
            p.a = SIMD4(f(ctx.num("amount") / 100), f(ctx.num("tolerance") / 100), 0, 0); p.b = ctx.effect.color("color", ctx.time).simd } })

    static let changeToColor = EffectDefinition(
        id: "ae.changeToColor", name: "Change to Color", category: .color, aeMatchNames: ["ADBE Change To Color"],
        summary: "Swaps one hue for another.",
        params: [.color("from", "From", RGBA(1, 0, 0), ae: 1), .color("to", "To", RGBA(0, 0.4, 1), ae: 2),
                 .number("tolerance", "Hue Tolerance", 8, 0, 50, unit: "%", ae: 5), .number("softness", "Softness", 5, 0, 50, unit: "%", ae: 7)],
        stage: .pixels { ctx in col(6, ctx) { p in
            p.b = ctx.effect.color("from", ctx.time).simd; p.c = ctx.effect.color("to", ctx.time).simd
            p.a = SIMD4(f(ctx.num("tolerance") / 100), f(ctx.num("softness") / 100), 0, 0) } })

    // MARK: Matte

    static let simpleChoker = EffectDefinition(
        id: "ae.simpleChoker", name: "Simple Choker", category: .keying, aeMatchNames: ["ADBE Simple Choker", "ADBE Matte Choker"],
        summary: "Shrinks (or grows) the layer's alpha edge.",
        params: [.number("choke", "Choke Matte", 2, -20, 20, step: 0.1, unit: "px", ae: 2)],
        stage: .pixels { ctx in
            let blurred = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: max(0.6, abs(ctx.num("choke")) * ctx.unit))
            return k("fxMatte", 1, ctx, aux: blurred) { p in p.a.x = f(-ctx.num("choke") / 20) }
        })

    static let lumaKey = EffectDefinition(
        id: "ae.lumaKey", name: "Luma Key", category: .keying, aeMatchNames: ["ADBE Luma Key"],
        summary: "Removes dark (or bright) areas — black backgrounds, fire, smoke.",
        params: [.choice("type", "Key Type", ["Key Out Darker", "Key Out Brighter"], 0, ae: 1),
                 .number("threshold", "Threshold", 20, 0, 100, unit: "%", ae: 2), .number("tolerance", "Tolerance", 5, 0, 100, unit: "%", ae: 3),
                 .number("feather", "Edge Feather", 8, 0, 100, unit: "%", ae: 5)],
        stage: .pixels { ctx in k("fxMatte", 0, ctx) { p in
            p.a = SIMD4(f(ctx.num("threshold") / 100), f(ctx.num("tolerance") / 100), f(max(0.005, ctx.num("feather") / 100)), 0)
            p.i.y = UInt32(ctx.effect.choice("type")) } })
}

/// 4-point homography solver (for Corner Pin).
enum Homography {
    /// Returns H (column-major simd) with H * (x, y, 1) ~ mapping `from[i]` -> `to[i]`.
    static func solve(from a: [Vec2], to b: [Vec2]) -> simd_double3x3 {
        // Direct linear transform with h33 = 1: 8x8 system.
        var m = [[Double]](repeating: [Double](repeating: 0, count: 9), count: 8)
        for i in 0..<4 {
            let x = a[i].x, y = a[i].y, u = b[i].x, v = b[i].y
            m[2 * i] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u]
            m[2 * i + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v]
        }
        // Gaussian elimination with partial pivoting.
        for c in 0..<8 {
            var piv = c
            for r in c..<8 where abs(m[r][c]) > abs(m[piv][c]) { piv = r }
            m.swapAt(c, piv)
            let d = m[c][c]
            guard abs(d) > 1e-12 else { return matrix_identity_double3x3 }
            for k in c..<9 { m[c][k] /= d }
            for r in 0..<8 where r != c {
                let fct = m[r][c]
                if fct != 0 { for k in c..<9 { m[r][k] -= fct * m[c][k] } }
            }
        }
        let h = (0..<8).map { m[$0][8] }
        // Rows: [h0 h1 h2; h3 h4 h5; h6 h7 1] -> column-major.
        return simd_double3x3(columns: (SIMD3(h[0], h[3], h[6]), SIMD3(h[1], h[4], h[7]), SIMD3(h[2], h[5], 1)))
    }
}
