import Foundation
import Metal
import simd

/// Batch 14: distortion 2 & space warps — gravitational lensing, recursive/log-polar zooms (droste, fractal zoom, tunnel),
/// paper-like warps (page curl, accordion fold), geometric warps (skew, keystone, stretch segment), animated wave/vortex
/// warps, refraction surfaces (glass blocks, frosted window, water surface, mirage) and chunky shakes.
extension EffectRegistry {
    static let batch14: [EffectDefinition] = [
        blackHole14, droste14, fractalZoom14, pageCurl14, fold14, skew14, keystone14, stretchSegment14, waveLine14,
        twistColumns14, smearDrag14, meshJitter14, elasticBounce14, magnifier14, tunnelWarp14, puff14, pinchWaves14,
        polarRipple14, vortexSpin14, glassBlocks14, frostedWindow14, waterSurface14, mirage14, earthquake14, zoomRings14,
    ]

    private static func d14(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        ctx.gpu.run("fxWarp14", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }
    private static func pt14(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    private static func n14(_ ctx: EffectContext, _ key: String, _ scale: Double = 1) -> Float { Float(ctx.num(key) * scale) }
    private static func rad14(_ ctx: EffectContext, _ key: String) -> Float { Float(ctx.num(key) * .pi / 180) }
    private static func pc14(_ ctx: EffectContext, _ key: String) -> Float { Float(ctx.num(key) * 0.01) }

    static let blackHole14 = EffectDefinition(
        id: "awi14.blackHole", name: "Black Hole", category: .distort, aeMatchNames: [],
        summary: "Gravitational lensing around an event horizon with a glowing accretion ring.",
        params: [.number("radius", "Horizon Radius", 25, 5, 80, unit: "%"), .number("lensing", "Lensing", 1, 0, 2, step: 0.01),
                 .number("glow", "Accretion Glow", 70, 0, 100, unit: "%"), .number("spin", "Spin", 1, -5, 5, step: 0.05),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 0) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(pc14(ctx, "radius"), n14(ctx, "lensing"), pc14(ctx, "glow"), n14(ctx, "spin")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let droste14 = EffectDefinition(
        id: "awi14.droste", name: "Droste Spiral", category: .distort, aeMatchNames: [],
        summary: "Recursive picture-in-picture spiral that zooms forever.",
        params: [.number("scale", "Recursion Scale", 3, 1.5, 8, step: 0.05), .number("twist", "Spiral Twist", 1, 0, 3, step: 0.05),
                 .number("speed", "Zoom Speed", 0.3, 0, 2, step: 0.01), .number("rotation", "Rotation", 0, -180, 180, unit: "°"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 1) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(n14(ctx, "scale"), n14(ctx, "twist"), n14(ctx, "speed"), rad14(ctx, "rotation")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let fractalZoom14 = EffectDefinition(
        id: "awi14.fractalZoom", name: "Fractal Zoom", category: .distort, aeMatchNames: [],
        summary: "Endless self-similar zoom built from layered scaled copies.",
        params: [.number("scale", "Level Scale", 2, 1.2, 4, step: 0.05), .number("speed", "Zoom Speed", 0.25, 0, 2, step: 0.01),
                 .number("rotation", "Rotation per Level", 15, -90, 90, unit: "°"), .number("mix", "Mix", 100, 0, 100, unit: "%"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 2) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(n14(ctx, "scale"), n14(ctx, "speed"), rad14(ctx, "rotation"), pc14(ctx, "mix")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let pageCurl14 = EffectDefinition(
        id: "awi14.pageCurl", name: "Page Curl", category: .distort, aeMatchNames: [],
        summary: "Peels the layer back like a sheet of paper from a corner.",
        params: [.number("progress", "Progress", 40, 0, 100, unit: "%"), .number("angle", "Direction", 30, -180, 180, unit: "°"),
                 .number("radius", "Curl Radius", 15, 2, 60, unit: "%"), .number("shadow", "Shadow", 60, 0, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 3) { p in
            p.a = SIMD4(pc14(ctx, "progress"), rad14(ctx, "angle"), pc14(ctx, "radius"), pc14(ctx, "shadow")) } })

    static let fold14 = EffectDefinition(
        id: "awi14.fold", name: "Accordion Fold", category: .distort, aeMatchNames: [],
        summary: "Compresses the image into shaded accordion folds.",
        params: [.number("folds", "Folds", 5, 1, 20, step: 1), .number("depth", "Fold Depth", 50, 0, 100, unit: "%"),
                 .number("angle", "Fold Direction", 0, -180, 180, unit: "°"), .number("shading", "Shading", 60, 0, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 4) { p in
            p.a = SIMD4(n14(ctx, "folds"), pc14(ctx, "depth"), rad14(ctx, "angle"), pc14(ctx, "shading")) } })

    static let skew14 = EffectDefinition(
        id: "awi14.skew", name: "Skew / Shear", category: .distort, aeMatchNames: [],
        summary: "Slants the image horizontally and/or vertically around an anchor.",
        params: [.number("skewX", "Horizontal Skew", 20, -60, 60, unit: "°"), .number("skewY", "Vertical Skew", 0, -60, 60, unit: "°"),
                 .point("anchor", "Anchor", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 5) { p in
            let c = pt14(ctx, "anchor")
            p.a = SIMD4(Float(tan(ctx.num("skewX") * .pi / 180)), Float(tan(ctx.num("skewY") * .pi / 180)), 0, 0)
            p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let keystone14 = EffectDefinition(
        id: "awi14.keystone", name: "Perspective Tilt", category: .distort, aeMatchNames: [],
        summary: "Keystone tilt that narrows one side as if the image leaned away.",
        params: [.number("tiltX", "Horizontal Tilt", 0, -100, 100, unit: "%"), .number("tiltY", "Vertical Tilt", 50, -100, 100, unit: "%"),
                 .number("zoom", "Zoom", 100, 50, 200, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 6) { p in
            p.a = SIMD4(pc14(ctx, "tiltX"), pc14(ctx, "tiltY"), pc14(ctx, "zoom"), 0) } })

    static let stretchSegment14 = EffectDefinition(
        id: "awi14.stretchSegment", name: "Stretch Segment", category: .distort, aeMatchNames: [],
        summary: "Stretches a band of the image and pushes the rest aside.",
        params: [.number("position", "Position", 50, 0, 100, unit: "%"), .number("width", "Band Width", 10, 1, 40, unit: "%"),
                 .number("stretch", "Stretch", 2.5, 1, 5, step: 0.05), .number("angle", "Direction", 0, -180, 180, unit: "°")],
        stage: .pixels { ctx in d14(ctx, 7) { p in
            p.a = SIMD4(pc14(ctx, "position"), n14(ctx, "width", 0.005), n14(ctx, "stretch"), rad14(ctx, "angle")) } })

    static let waveLine14 = EffectDefinition(
        id: "awi14.waveLine", name: "Wave Ripple Line", category: .distort, aeMatchNames: [],
        summary: "A packet of waves traveling across the image in one direction.",
        params: [.number("amplitude", "Amplitude", 12, 0, 50, unit: "%"), .number("wavelength", "Wavelength", 15, 2, 100, unit: "%"),
                 .number("speed", "Speed", 1, 0, 3, step: 0.01), .number("angle", "Direction", 0, -180, 180, unit: "°"),
                 .number("packet", "Packet Width", 25, 2, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 8) { p in
            p.a = SIMD4(pc14(ctx, "amplitude"), pc14(ctx, "wavelength"), n14(ctx, "speed"), rad14(ctx, "angle"))
            p.b = SIMD4(pc14(ctx, "packet"), 0, 0, 0) } })

    static let twistColumns14 = EffectDefinition(
        id: "awi14.twistColumns", name: "Twist Columns", category: .distort, aeMatchNames: [],
        summary: "Slices the image into columns that twist like rotating cylinders.",
        params: [.number("columns", "Columns", 6, 1, 30, step: 1), .number("twist", "Twist", 180, -720, 720, unit: "°"),
                 .number("speed", "Spin Speed", 1, -10, 10, step: 0.05), .number("shading", "Shading", 60, 0, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 9) { p in
            p.a = SIMD4(n14(ctx, "columns"), rad14(ctx, "twist"), n14(ctx, "speed"), pc14(ctx, "shading")) } })

    static let smearDrag14 = EffectDefinition(
        id: "awi14.smearDrag", name: "Smear Drag", category: .distort, aeMatchNames: [],
        summary: "Drags bright content into a fading smear trail along a direction.",
        params: [.number("length", "Smear Length", 30, 0, 100, unit: "%"), .number("angle", "Direction", 0, -180, 180, unit: "°"),
                 .number("falloff", "Falloff", 1, 0.1, 5, step: 0.05), .number("bias", "Highlight Bias", 50, 0, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 10) { p in
            p.a = SIMD4(pc14(ctx, "length"), rad14(ctx, "angle"), n14(ctx, "falloff"), pc14(ctx, "bias")) } })

    static let meshJitter14 = EffectDefinition(
        id: "awi14.meshJitter", name: "Mesh Jitter", category: .distort, aeMatchNames: [],
        summary: "Randomly nudges the points of a warp mesh, re-rolled over time.",
        params: [.number("cell", "Mesh Size", 20, 3, 100, unit: "%"), .number("amount", "Amount", 35, 0, 100, unit: "%"),
                 .number("rate", "Rate", 8, 0, 30, step: 0.1, unit: "/s"), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d14(ctx, 11) { p in
            p.a = SIMD4(pc14(ctx, "cell"), pc14(ctx, "amount"), n14(ctx, "rate"), n14(ctx, "seed")) } })

    static let elasticBounce14 = EffectDefinition(
        id: "awi14.elasticBounce", name: "Elastic Bounce Warp", category: .distort, aeMatchNames: [],
        summary: "Jelly-like squash and stretch jiggle that settles over time.",
        params: [.number("amount", "Amount", 40, 0, 100, unit: "%"), .number("frequency", "Frequency", 2, 0.1, 10, step: 0.05, unit: "Hz"),
                 .number("damping", "Damping", 1.5, 0, 10, step: 0.05), .number("radius", "Radius", 100, 10, 200, unit: "%"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 12) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(pc14(ctx, "amount"), n14(ctx, "frequency"), n14(ctx, "damping"), pc14(ctx, "radius")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let magnifier14 = EffectDefinition(
        id: "awi14.magnifier", name: "Magnifier Lens", category: .distort, aeMatchNames: [],
        summary: "A rimmed magnifying glass that drifts around an orbit.",
        params: [.number("radius", "Lens Radius", 35, 5, 100, unit: "%"), .number("magnification", "Magnification", 2, 1, 6, step: 0.05),
                 .number("rim", "Rim Width", 8, 0, 30, unit: "%"), .number("speed", "Orbit Speed", 0.3, -2, 2, step: 0.01),
                 .number("orbit", "Orbit Radius", 30, 0, 100, unit: "%"), .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 13) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(pc14(ctx, "radius"), n14(ctx, "magnification"), pc14(ctx, "rim"), n14(ctx, "speed"))
            p.b = SIMD4(c.x, c.y, pc14(ctx, "orbit"), 0) } })

    static let tunnelWarp14 = EffectDefinition(
        id: "awi14.tunnelWarp", name: "Tunnel Warp", category: .distort, aeMatchNames: [],
        summary: "Wraps the image onto a log-polar tunnel that flies toward you.",
        params: [.number("speed", "Fly Speed", 0.5, -3, 3, step: 0.01), .number("twist", "Twist", 0.5, -3, 3, step: 0.01),
                 .number("repeats", "Repeats", 2, 0.5, 8, step: 0.05), .number("fade", "Depth Fade", 1, 0, 3, step: 0.01),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 14) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(n14(ctx, "speed"), n14(ctx, "twist"), n14(ctx, "repeats"), n14(ctx, "fade")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let puff14 = EffectDefinition(
        id: "awi14.puff", name: "Puff / Inflate", category: .distort, aeMatchNames: [],
        summary: "Swells bright shapes outward like they were inflated.",
        params: [.number("amount", "Amount", 1.5, 0, 3, step: 0.01), .number("radius", "Radius", 15, 2, 60, unit: "%"),
                 .number("highlight", "Highlight", 40, 0, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 15) { p in
            p.a = SIMD4(n14(ctx, "amount"), pc14(ctx, "radius"), pc14(ctx, "highlight"), 0) } })

    static let pinchWaves14 = EffectDefinition(
        id: "awi14.pinchWaves", name: "Pinch Waves", category: .distort, aeMatchNames: [],
        summary: "Rotating lobes that alternately pinch and bulge around a center.",
        params: [.number("amount", "Amount", 50, -100, 100, unit: "%"), .number("lobes", "Lobes", 5, 1, 16, step: 1),
                 .number("speed", "Speed", 0.5, -3, 3, step: 0.01), .number("radius", "Radius", 90, 10, 200, unit: "%"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 16) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(pc14(ctx, "amount"), n14(ctx, "lobes"), n14(ctx, "speed"), pc14(ctx, "radius")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let polarRipple14 = EffectDefinition(
        id: "awi14.polarRipple", name: "Polar Ripple", category: .distort, aeMatchNames: [],
        summary: "Rings that twist back and forth around a center (rotational ripples).",
        params: [.number("angle", "Twist Amount", 20, 0, 90, unit: "°"), .number("wavelength", "Wavelength", 20, 2, 100, unit: "%"),
                 .number("speed", "Speed", 1, -5, 5, step: 0.01), .number("decay", "Decay", 30, 0, 100, unit: "%"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 17) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(rad14(ctx, "angle"), pc14(ctx, "wavelength"), n14(ctx, "speed"), pc14(ctx, "decay")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let vortexSpin14 = EffectDefinition(
        id: "awi14.vortexSpin", name: "Vortex Spin", category: .distort, aeMatchNames: [],
        summary: "A whirlpool twist that keeps winding up over time.",
        params: [.number("strength", "Strength", 0.5, -3, 3, step: 0.01, unit: "turns"), .number("radius", "Radius", 80, 5, 200, unit: "%"),
                 .number("speed", "Spin Speed", 0.5, -3, 3, step: 0.01), .number("power", "Falloff", 2, 0.2, 5, step: 0.05),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 18) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(n14(ctx, "strength"), pc14(ctx, "radius"), n14(ctx, "speed"), n14(ctx, "power")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let glassBlocks14 = EffectDefinition(
        id: "awi14.glassBlocks", name: "Glass Blocks", category: .distort, aeMatchNames: [],
        summary: "Seen through a wall of square refracting glass bricks.",
        params: [.number("size", "Block Size", 18, 3, 80, unit: "%"), .number("refraction", "Refraction", 50, 0, 100, unit: "%"),
                 .number("bevel", "Bevel", 15, 0, 50, unit: "%"), .number("highlight", "Highlight", 50, 0, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 19) { p in
            p.a = SIMD4(pc14(ctx, "size"), pc14(ctx, "refraction"), pc14(ctx, "bevel"), pc14(ctx, "highlight")) } })

    static let frostedWindow14 = EffectDefinition(
        id: "awi14.frostedWindow", name: "Frosted Window", category: .distort, aeMatchNames: [],
        summary: "Icy frosted pane with a wiped-clear spot.",
        params: [.number("roughness", "Roughness", 6, 0, 30, unit: "%"), .number("grain", "Grain Size", 5, 1, 50, unit: "%"),
                 .number("frost", "Frost", 40, 0, 100, unit: "%"), .number("seed", "Random Seed", 1, 0, 100, step: 1),
                 .number("clear", "Clear Spot", 25, 0, 100, unit: "%"), .point("center", "Clear Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 20) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(pc14(ctx, "roughness"), pc14(ctx, "grain"), pc14(ctx, "frost"), n14(ctx, "seed"))
            p.b = SIMD4(c.x, c.y, pc14(ctx, "clear"), 0) } })

    static let waterSurface14 = EffectDefinition(
        id: "awi14.waterSurface", name: "Water Surface", category: .distort, aeMatchNames: [],
        summary: "Looking through rippling water with caustic light glints.",
        params: [.number("strength", "Refraction", 30, 0, 100, unit: "%"), .number("scale", "Wave Scale", 10, 2, 60, unit: "%"),
                 .number("speed", "Speed", 1, 0, 5, step: 0.01), .number("highlight", "Caustics", 50, 0, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 21) { p in
            p.a = SIMD4(pc14(ctx, "strength"), pc14(ctx, "scale"), n14(ctx, "speed"), pc14(ctx, "highlight")) } })

    static let mirage14 = EffectDefinition(
        id: "awi14.mirage", name: "Mirage", category: .distort, aeMatchNames: [],
        summary: "Desert heat shimmer in horizontal bands with a wobbling reflection below the horizon.",
        params: [.number("amount", "Shimmer", 4, 0, 20, unit: "%"), .number("band", "Band Height", 6, 1, 40, unit: "%"),
                 .number("speed", "Speed", 1, 0, 5, step: 0.01), .number("horizon", "Horizon", 60, 0, 100, unit: "%"),
                 .number("reflection", "Reflection", 60, 0, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 22) { p in
            p.a = SIMD4(pc14(ctx, "amount"), pc14(ctx, "band"), n14(ctx, "speed"), pc14(ctx, "horizon"))
            p.b = SIMD4(pc14(ctx, "reflection"), 0, 0, 0) } })

    static let earthquake14 = EffectDefinition(
        id: "awi14.earthquake", name: "Earthquake Displace", category: .distort, aeMatchNames: [],
        summary: "Breaks the image into cracked chunks that shake independently.",
        params: [.number("intensity", "Intensity", 8, 0, 50, unit: "%"), .number("block", "Chunk Size", 20, 3, 80, unit: "%"),
                 .number("frequency", "Frequency", 12, 0, 30, step: 0.1, unit: "/s"), .number("seed", "Random Seed", 1, 0, 100, step: 1),
                 .number("cracks", "Cracks", 50, 0, 100, unit: "%")],
        stage: .pixels { ctx in d14(ctx, 23) { p in
            p.a = SIMD4(pc14(ctx, "intensity"), pc14(ctx, "block"), n14(ctx, "frequency"), n14(ctx, "seed"))
            p.b = SIMD4(pc14(ctx, "cracks"), 0, 0, 0) } })

    static let zoomRings14 = EffectDefinition(
        id: "awi14.zoomRings", name: "Zoom Rings", category: .distort, aeMatchNames: [],
        summary: "Concentric bands alternately zoomed in, out and twisted, drifting outward.",
        params: [.number("width", "Ring Width", 15, 2, 60, unit: "%"), .number("zoom", "Zoom", 40, -100, 100, unit: "%"),
                 .number("speed", "Speed", 0.4, -3, 3, step: 0.01), .number("twist", "Twist", 10, -90, 90, unit: "°"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d14(ctx, 24) { p in
            let c = pt14(ctx, "center")
            p.a = SIMD4(pc14(ctx, "width"), pc14(ctx, "zoom"), n14(ctx, "speed"), rad14(ctx, "twist")); p.b = SIMD4(c.x, c.y, 0, 0) } })
}
