import Foundation
import Metal
import simd

/// Batch 6: distortion & glitch — lens warps (fisheye, barrel/pincushion, bulge, squeeze, bend, swirl), liquid/glass/water
/// refraction (glass, liquid, ripples, rain on glass, heat haze), tilings & breaks (hex tiles, shatter, slice) and
/// glitch looks (blocks, lines, digital noise, datamosh smear, pixel stretch, signal interference, CRT roll).
extension EffectRegistry {
    static let batch6: [EffectDefinition] = [
        fisheye6, lensDistortion6, glass6, liquid6, ripples6, rainGlass6, heatHaze6, bulge6, squeeze6, bend6, swirl6,
        hexTiles6, shatter6, slice6, glitchBlocks6, glitchLines6, digitalNoise6, datamosh6, pixelStretch6, lumaDisplace6,
        kaleido6, wobble6, interference6, scanDistort6,
    ]

    private static func d6(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        ctx.gpu.run("fxDistort6", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }
    private static func pt6(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    private static func n6(_ ctx: EffectContext, _ key: String, _ scale: Double = 1) -> Float { Float(ctx.num(key) * scale) }
    private static func px6(_ ctx: EffectContext, _ key: String) -> Float { Float(ctx.num(key) * ctx.unit) }
    private static func rad6(_ ctx: EffectContext, _ key: String) -> Float { Float(ctx.num(key) * .pi / 180) }

    static let fisheye6 = EffectDefinition(
        id: "awi6.fisheye", name: "Fisheye", category: .distort, aeMatchNames: [],
        summary: "Wide-angle fisheye magnification (negative = anti-fisheye pinch).",
        params: [.number("amount", "Amount", 60, -100, 100, unit: "%"), .number("radius", "Radius", 110, 5, 150, unit: "%"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d6(ctx, 0) { p in
            let c = pt6(ctx, "center"); p.a = SIMD4(n6(ctx, "amount", 0.01), n6(ctx, "radius", 0.01), c.x, c.y) } })

    static let lensDistortion6 = EffectDefinition(
        id: "awi6.lensDistortion", name: "Lens Distortion", category: .distort, aeMatchNames: [],
        summary: "Barrel / pincushion lens distortion with edge color fringing.",
        params: [.number("k1", "Distortion", 0.4, -1, 1, step: 0.01), .number("k2", "Edge Distortion", 0.2, -1, 1, step: 0.01),
                 .number("chroma", "Chromatic Fringe", 30, 0, 100, unit: "%"), .number("zoom", "Zoom", 100, 50, 200, unit: "%"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d6(ctx, 1) { p in
            let c = pt6(ctx, "center")
            p.a = SIMD4(n6(ctx, "k1"), n6(ctx, "k2"), n6(ctx, "chroma", 0.01), n6(ctx, "zoom", 0.01)); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let glass6 = EffectDefinition(
        id: "awi6.glass", name: "Glass Refraction", category: .distort, aeMatchNames: [],
        summary: "Looking through bumpy frosted glass (animated).",
        params: [.number("strength", "Refraction", 10, 0, 60, unit: "px"), .number("scale", "Bump Size", 30, 4, 300, unit: "px"),
                 .number("speed", "Speed", 0.5, 0, 5, step: 0.05), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 2) { p in
            p.a = SIMD4(px6(ctx, "strength"), px6(ctx, "scale"), n6(ctx, "speed"), n6(ctx, "seed")) } })

    static let liquid6 = EffectDefinition(
        id: "awi6.liquid", name: "Liquid Warp", category: .distort, aeMatchNames: [],
        summary: "Flowing, melting fluid distortion (animated domain warp).",
        params: [.number("amount", "Amount", 20, 0, 120, unit: "px"), .number("scale", "Scale", 70, 5, 500, unit: "px"),
                 .number("speed", "Speed", 1, 0, 6, step: 0.05), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 3) { p in
            p.a = SIMD4(px6(ctx, "amount"), px6(ctx, "scale"), n6(ctx, "speed"), n6(ctx, "seed")) } })

    static let ripples6 = EffectDefinition(
        id: "awi6.ripples", name: "Water Ripples", category: .distort, aeMatchNames: [],
        summary: "Concentric water rings spreading from a point (animated).",
        params: [.number("amplitude", "Amplitude", 6, 0, 40, unit: "px"), .number("wavelength", "Wavelength", 18, 3, 200, unit: "px"),
                 .number("speed", "Speed", 1.5, 0, 8, step: 0.05), .number("decay", "Decay", 30, 0, 100, unit: "%"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d6(ctx, 4) { p in
            let c = pt6(ctx, "center")
            p.a = SIMD4(px6(ctx, "amplitude"), px6(ctx, "wavelength"), n6(ctx, "speed"), n6(ctx, "decay", 0.01)); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let rainGlass6 = EffectDefinition(
        id: "awi6.rainOnGlass", name: "Rain on Glass", category: .distort, aeMatchNames: [],
        summary: "Water droplets on a window, refracting the scene and sliding down.",
        params: [.number("cell", "Droplet Spacing", 22, 6, 120, unit: "px"), .number("size", "Droplet Size", 70, 0, 100, unit: "%"),
                 .number("refraction", "Refraction", 1.2, 0, 3, step: 0.01), .number("speed", "Slide Speed", 1, 0, 5, step: 0.05),
                 .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 5) { p in
            p.a = SIMD4(px6(ctx, "cell"), n6(ctx, "size", 0.01), n6(ctx, "refraction"), n6(ctx, "speed")); p.c.x = n6(ctx, "seed") } })

    static let heatHaze6 = EffectDefinition(
        id: "awi6.heatHaze", name: "Heat Haze", category: .distort, aeMatchNames: [],
        summary: "Shimmering rising hot-air distortion (animated).",
        params: [.number("amount", "Amount", 6, 0, 40, unit: "px"), .number("scale", "Scale", 20, 3, 200, unit: "px"),
                 .number("speed", "Rise Speed", 2, 0, 10, step: 0.05), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 6) { p in
            p.a = SIMD4(px6(ctx, "amount"), px6(ctx, "scale"), n6(ctx, "speed"), n6(ctx, "seed")) } })

    static let bulge6 = EffectDefinition(
        id: "awi6.bulge", name: "Bulge / Pinch", category: .distort, aeMatchNames: [],
        summary: "Inflate (positive) or pinch (negative) a round area.",
        params: [.number("amount", "Amount", 70, -100, 100, unit: "%"), .number("radius", "Radius", 80, 5, 150, unit: "%"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d6(ctx, 7) { p in
            let c = pt6(ctx, "center"); p.a = SIMD4(n6(ctx, "amount", 0.01), n6(ctx, "radius", 0.01), c.x, c.y) } })

    static let squeeze6 = EffectDefinition(
        id: "awi6.squeeze", name: "Squeeze", category: .distort, aeMatchNames: [],
        summary: "Squash or stretch the middle of the frame with a curved profile.",
        params: [.number("amount", "Amount", 50, -100, 100, unit: "%"), .number("curve", "Curve", 1.5, 0.2, 5, step: 0.05),
                 .choice("direction", "Direction", ["Horizontal", "Vertical"], 0)],
        stage: .pixels { ctx in d6(ctx, 8) { p in
            p.a = SIMD4(n6(ctx, "amount", 0.01), n6(ctx, "curve"), 0, 0); p.i.y = UInt32(max(0, ctx.effect.choice("direction"))) } })

    static let bend6 = EffectDefinition(
        id: "awi6.bend", name: "Bend", category: .distort, aeMatchNames: [],
        summary: "Bend the image into an arc along an axis.",
        params: [.number("amount", "Bend", 40, -200, 200, unit: "px"), .angle("axis", "Axis Angle", 0)],
        stage: .pixels { ctx in d6(ctx, 9) { p in p.a = SIMD4(px6(ctx, "amount"), rad6(ctx, "axis"), 0, 0) } })

    static let swirl6 = EffectDefinition(
        id: "awi6.swirl", name: "Swirl+", category: .distort, aeMatchNames: [],
        summary: "Twirl with adjustable falloff and optional continuous spin.",
        params: [.number("twist", "Twist", 180, -1080, 1080, unit: "°"), .number("radius", "Radius", 90, 5, 150, unit: "%"),
                 .number("falloff", "Falloff", 1.5, 0.2, 5, step: 0.05), .number("spin", "Spin Speed", 0, -360, 360, unit: "°/s"),
                 .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d6(ctx, 10) { p in
            let c = pt6(ctx, "center")
            p.a = SIMD4(rad6(ctx, "twist"), n6(ctx, "radius", 0.01), n6(ctx, "falloff"), rad6(ctx, "spin")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let hexTiles6 = EffectDefinition(
        id: "awi6.hexTiles", name: "Hexagon Tiles", category: .distort, aeMatchNames: [],
        summary: "Break the image into hex tiles, each randomly rotated and shifted.",
        params: [.number("size", "Tile Size", 24, 4, 200, unit: "px"), .number("rotation", "Rotation", 25, 0, 180, unit: "°"),
                 .number("offset", "Offset", 4, 0, 50, unit: "px"), .number("gap", "Grout", 1.5, 0, 10, step: 0.1, unit: "px"),
                 .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 11) { p in
            p.a = SIMD4(px6(ctx, "size"), rad6(ctx, "rotation"), px6(ctx, "offset"), n6(ctx, "seed")); p.b.x = px6(ctx, "gap") } })

    static let shatter6 = EffectDefinition(
        id: "awi6.shatter", name: "Shatter", category: .distort, aeMatchNames: [],
        summary: "Crack into Voronoi shards that fly outward as Progress rises.",
        params: [.number("progress", "Progress", 35, 0, 100, unit: "%"), .number("cell", "Shard Size", 30, 8, 200, unit: "px"),
                 .number("spread", "Spread", 100, 0, 200, unit: "%"), .number("seed", "Random Seed", 1, 0, 100, step: 1),
                 .point("center", "Origin", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d6(ctx, 12) { p in
            let c = pt6(ctx, "center")
            p.a = SIMD4(n6(ctx, "progress", 0.01), px6(ctx, "cell"), n6(ctx, "spread", 0.01), n6(ctx, "seed")); p.b = SIMD4(c.x, c.y, 0, 0) } })

    static let slice6 = EffectDefinition(
        id: "awi6.slice", name: "Perfect Slice", category: .distort, aeMatchNames: [],
        summary: "Cut the image along a line and slide the halves apart.",
        params: [.number("offset", "Slide", 24, -200, 200, unit: "px"), .angle("angle", "Angle", 30), .point("center", "Cut Point", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d6(ctx, 13) { p in
            let c = pt6(ctx, "center"); p.a = SIMD4(px6(ctx, "offset"), rad6(ctx, "angle"), c.x, c.y) } })

    static let glitchBlocks6 = EffectDefinition(
        id: "awi6.glitchBlocks", name: "Glitch Blocks", category: .stylize, aeMatchNames: [],
        summary: "Random rectangular blocks jump sideways with RGB separation.",
        params: [.number("amount", "Displacement", 20, 0, 100, unit: "px"), .number("block", "Block Size", 14, 3, 120, unit: "px"),
                 .number("probability", "Amount of Blocks", 40, 0, 100, unit: "%"), .number("rate", "Rate", 8, 0, 30, step: 0.5, unit: "fps"),
                 .number("split", "RGB Split", 4, 0, 30, unit: "px"), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 14) { p in
            p.a = SIMD4(px6(ctx, "amount"), px6(ctx, "block"), n6(ctx, "probability", 0.01), n6(ctx, "rate"))
            p.c = SIMD4(n6(ctx, "seed"), px6(ctx, "split"), 0, 0) } })

    static let glitchLines6 = EffectDefinition(
        id: "awi6.glitchLines", name: "Glitch Lines", category: .stylize, aeMatchNames: [],
        summary: "Horizontal line tearing that flickers every frame.",
        params: [.number("amount", "Tear", 25, 0, 120, unit: "px"), .number("height", "Line Height", 3, 1, 40, unit: "px"),
                 .number("density", "Density", 50, 0, 100, unit: "%"), .number("rate", "Rate", 10, 0, 30, step: 0.5, unit: "fps"),
                 .number("chroma", "Color Shift", 3, 0, 20, unit: "px"), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 15) { p in
            p.a = SIMD4(px6(ctx, "amount"), px6(ctx, "height"), n6(ctx, "density", 0.01), n6(ctx, "rate"))
            p.c = SIMD4(n6(ctx, "seed"), px6(ctx, "chroma"), 0, 0) } })

    static let digitalNoise6 = EffectDefinition(
        id: "awi6.digitalNoise", name: "Digital Noise Glitch", category: .stylize, aeMatchNames: [],
        summary: "Corrupted-signal zones of posterized pixel noise and sparks.",
        params: [.number("intensity", "Intensity", 50, 0, 100, unit: "%"), .number("block", "Pixel Size", 5, 1, 40, unit: "px"),
                 .number("rate", "Rate", 12, 0, 30, step: 0.5, unit: "fps"), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 16) { p in
            p.a = SIMD4(n6(ctx, "intensity", 0.01), px6(ctx, "block"), n6(ctx, "rate"), n6(ctx, "seed")) } })

    static let datamosh6 = EffectDefinition(
        id: "awi6.datamosh", name: "Datamosh Smear", category: .stylize, aeMatchNames: [],
        summary: "Brights bleed in blocky directional smears like broken video compression.",
        params: [.number("length", "Smear Length", 30, 0, 200, unit: "px"), .angle("angle", "Direction", 0),
                 .number("block", "Block Size", 16, 2, 100, unit: "px"), .number("chaos", "Chaos", 50, 0, 100, unit: "%"),
                 .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 17) { p in
            p.a = SIMD4(px6(ctx, "length"), rad6(ctx, "angle"), px6(ctx, "block"), n6(ctx, "chaos", 0.01)); p.c.x = n6(ctx, "seed") } })

    static let pixelStretch6 = EffectDefinition(
        id: "awi6.pixelStretch", name: "Pixel Stretch", category: .stylize, aeMatchNames: [],
        summary: "Smear the pixels on a line out to the edge of the frame.",
        params: [.number("position", "Position", 50, 0, 100, unit: "%"), .number("jitter", "Jitter", 4, 0, 40, unit: "px"),
                 .choice("direction", "Direction", ["Right", "Left", "Down", "Up"], 0), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 18) { p in
            p.a = SIMD4(n6(ctx, "position", 0.01), px6(ctx, "jitter"), 0, 0)
            p.i.y = UInt32(max(0, ctx.effect.choice("direction"))); p.c.x = n6(ctx, "seed") } })

    static let lumaDisplace6 = EffectDefinition(
        id: "awi6.lumaDisplace", name: "Luma Displace", category: .distort, aeMatchNames: [],
        summary: "Push pixels by their own brightness (brights move, darks stay).",
        params: [.number("amount", "Amount", 25, -100, 100, unit: "px"), .angle("angle", "Direction", 45),
                 .choice("mode", "Mode", ["Along Direction", "Radial"], 0)],
        stage: .pixels { ctx in d6(ctx, 19) { p in
            p.a = SIMD4(px6(ctx, "amount"), rad6(ctx, "angle"), 0, 0); p.i.y = UInt32(max(0, ctx.effect.choice("mode"))) } })

    static let kaleido6 = EffectDefinition(
        id: "awi6.kaleidoscope", name: "Kaleidoscope+", category: .distort, aeMatchNames: [],
        summary: "Mirrored polar segments with rotation, spin and zoom.",
        params: [.number("segments", "Segments", 6, 2, 32, step: 1), .angle("rotation", "Rotation", 0),
                 .number("spin", "Spin Speed", 0, -180, 180, unit: "°/s"), .number("zoom", "Zoom", 100, 25, 400, unit: "%"),
                 .toggle("mirror", "Mirror Segments", true), .point("center", "Center", Vec2(0.5, 0.5))],
        stage: .pixels { ctx in d6(ctx, 20) { p in
            let c = pt6(ctx, "center")
            p.a = SIMD4(n6(ctx, "segments"), rad6(ctx, "rotation"), rad6(ctx, "spin"), n6(ctx, "zoom", 0.01))
            p.b = SIMD4(c.x, c.y, 0, 0); p.i.y = ctx.effect.bool("mirror") ? 1 : 0 } })

    static let wobble6 = EffectDefinition(
        id: "awi6.wobble", name: "Wobble", category: .distort, aeMatchNames: [],
        summary: "Jelly-like sine wobble that keeps moving.",
        params: [.number("amplitude", "Amplitude", 6, 0, 60, unit: "px"), .number("wavelength", "Wavelength", 50, 8, 400, unit: "px"),
                 .number("speed", "Speed", 1.5, 0, 10, step: 0.05)],
        stage: .pixels { ctx in d6(ctx, 21) { p in
            p.a = SIMD4(px6(ctx, "amplitude"), px6(ctx, "wavelength"), n6(ctx, "speed"), 0) } })

    static let interference6 = EffectDefinition(
        id: "awi6.interference", name: "Signal Interference", category: .stylize, aeMatchNames: [],
        summary: "Rolling sine bands of horizontal shift, brightness and color fringing.",
        params: [.number("strength", "Strength", 10, 0, 60, unit: "px"), .number("bands", "Bands", 4, 0.5, 30, step: 0.1),
                 .number("speed", "Speed", 1, 0, 10, step: 0.05), .number("chroma", "Color Shift", 3, 0, 20, unit: "px"),
                 .number("noise", "Line Noise", 20, 0, 100, unit: "%"), .number("seed", "Random Seed", 1, 0, 100, step: 1)],
        stage: .pixels { ctx in d6(ctx, 22) { p in
            p.a = SIMD4(px6(ctx, "strength"), n6(ctx, "bands"), n6(ctx, "speed"), px6(ctx, "chroma"))
            p.b.x = n6(ctx, "noise", 0.01); p.c.x = n6(ctx, "seed") } })

    static let scanDistort6 = EffectDefinition(
        id: "awi6.scanDistort", name: "Scan Distort", category: .stylize, aeMatchNames: [],
        summary: "Old CRT: rolling picture, wavy sync bar, scanlines and curved glass.",
        params: [.number("roll", "Roll Speed", 0.5, 0, 3, step: 0.01), .number("bar", "Sync Wobble", 10, 0, 60, unit: "px"),
                 .number("scanlines", "Scanlines", 40, 0, 100, unit: "%"), .number("curvature", "Curvature", 25, 0, 100, unit: "%")],
        stage: .pixels { ctx in d6(ctx, 23) { p in
            p.a = SIMD4(n6(ctx, "roll"), px6(ctx, "bar"), n6(ctx, "scanlines", 0.01), n6(ctx, "curvature", 0.01)) } })
}
