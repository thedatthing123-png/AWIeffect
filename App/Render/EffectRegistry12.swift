import Foundation
import Metal
import simd

/// Batch 12: abstract backgrounds & particles 2 (anime edit / AMV favourites) — plexus, constellation, fireworks,
/// bubbles, rain ripples, vortex dust, neural network, metaballs, voronoi shapes, isolines, cosmic nebula, glow
/// tunnel, wave lines, hex grid glow, light trails, sunburst, kaleido mandala, grid warp, liquid gradient, ink smoke,
/// crystal shards, spiral galaxy, orbit rings, heartbeat line, sparkle dust. All composite over the layer (Blend / Only).
extension EffectRegistry {
    static let batch12: [EffectDefinition] = [
        plexus12, constellation12, fireworks12, bubbles12, rainRipples12, vortexDust12, neuralNetwork12, metaballs12,
        voronoiShapes12, isolines12, cosmicNebula12, glowTunnel12, waveLines12, hexGridGlow12, lightTrails12, sunburst12,
        kaleidoMandala12, gridWarp12, liquidGradient12, inkSmoke12, crystalShards12, spiralGalaxy12, orbitRings12,
        heartbeatLine12, sparkleDust12,
    ]

    private static func g12(_ ctx: EffectContext, _ mode: UInt32, over: Bool, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.i.y = over ? 1 : 0
        p.d.x = Float(ctx.time)
        p.d.y = Float(ctx.num("blend") / 100)
        p.d.z = ctx.effect.bool("only") ? 1 : 0
        ctx.gpu.run("fxAbstract12", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }
    private static func pt12(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }
    private static func n12(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k)) }
    private static func px12(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * ctx.unit) }
    private static func pc12(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) / 100) }
    private static func col12(_ ctx: EffectContext, _ k: String) -> SIMD4<Float> { ctx.effect.color(k, ctx.time).simd }
    private static func pack12(_ ctx: EffectContext, _ k: String) -> UInt32 {
        let c = ctx.effect.color(k, ctx.time)
        func b(_ v: Double) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
        return (b(c.r) << 16) | (b(c.g) << 8) | b(c.b)
    }
    private static func p12(_ list: [ParamDef], _ blend: Double = 100) -> [ParamDef] {
        list + [.number("blend", "Blend", blend, 0, 100, unit: "%"), .toggle("only", "Effect Only", false)]
    }
    private static let seed12: ParamDef = .number("seed", "Random Seed", 1, 0, 100, step: 1)

    static let plexus12 = EffectDefinition(
        id: "awi12.plexus", name: "Plexus", category: .generate, aeMatchNames: [],
        summary: "Drifting points joined by fading lines when they come close (plexus network).",
        params: p12([.number("spacing", "Spacing", 40, 10, 200, unit: "px"), .number("speed", "Speed", 1, 0, 5, step: 0.01),
                  .number("link", "Link Distance", 60, 5, 300, unit: "px"), .number("size", "Point Size", 2.5, 0.5, 10, step: 0.1, unit: "px"),
                  .number("width", "Line Width", 1, 0.2, 5, step: 0.1, unit: "px"), .color("color", "Color", RGBA(0.55, 0.85, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 0, over: false) { p in
            p.a = SIMD4(px12(ctx, "spacing"), n12(ctx, "speed"), px12(ctx, "link"), px12(ctx, "size"))
            p.b = col12(ctx, "color"); p.c = SIMD4(n12(ctx, "seed"), px12(ctx, "width"), 0, 0) } })

    static let constellation12 = EffectDefinition(
        id: "awi12.constellation", name: "Constellation", category: .generate, aeMatchNames: [],
        summary: "Twinkling stars linked into constellation figures.",
        params: p12([.number("spacing", "Spacing", 36, 10, 200, unit: "px"), .number("speed", "Twinkle Speed", 2, 0, 8, step: 0.05),
                  .number("size", "Star Size", 2.5, 0.5, 10, step: 0.1, unit: "px"), .number("lineOpacity", "Line Opacity", 60, 0, 100, unit: "%"),
                  .number("connections", "Connections", 60, 0, 100, unit: "%"), .number("width", "Line Width", 1, 0.2, 5, step: 0.1, unit: "px"),
                  .color("color", "Color", RGBA(0.85, 0.9, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 1, over: false) { p in
            p.a = SIMD4(px12(ctx, "spacing"), n12(ctx, "speed"), px12(ctx, "size"), pc12(ctx, "lineOpacity"))
            p.b = col12(ctx, "color"); p.c = SIMD4(n12(ctx, "seed"), px12(ctx, "width"), pc12(ctx, "connections"), 0) } })

    static let fireworks12 = EffectDefinition(
        id: "awi12.fireworks", name: "Fireworks", category: .generate, aeMatchNames: [],
        summary: "Big staggered firework bursts: glowing spark trails drooping with gravity, bright heads and bloom.",
        params: p12([.number("radius", "Burst Size", 32, 5, 80, unit: "%"), .number("period", "Burst Interval", 1.8, 0.3, 6, step: 0.05, unit: "s"),
                  .number("gravity", "Gravity", 22, 0, 200, unit: "%/s²"), .number("size", "Spark Size", 2.2, 0.5, 8, step: 0.1, unit: "px"),
                  .number("trail", "Trail", 1.2, 0, 3, step: 0.01), .number("saturation", "Saturation", 85, 0, 100, unit: "%"),
                  .number("bursts", "Bursts", 5, 1, 8, step: 1), seed12]),
        stage: .pixels { ctx in g12(ctx, 2, over: false) { p in
            p.a = SIMD4(pc12(ctx, "radius"), n12(ctx, "period"), pc12(ctx, "gravity"), px12(ctx, "size"))
            p.b.x = n12(ctx, "bursts")
            p.c = SIMD4(n12(ctx, "seed"), pc12(ctx, "saturation"), n12(ctx, "trail"), 0) } })

    static let bubbles12 = EffectDefinition(
        id: "awi12.bubbles", name: "Bubbles", category: .generate, aeMatchNames: [],
        summary: "Glossy soap bubbles rising and swaying.",
        params: p12([.number("spacing", "Spacing", 36, 10, 200, unit: "px"), .number("size", "Bubble Size", 9, 2, 60, step: 0.1, unit: "px"),
                  .number("speed", "Rise Speed", 50, 0, 400, unit: "px/s"), .number("wobble", "Sway", 0.6, 0, 2, step: 0.01),
                  .color("color", "Color", RGBA(0.7, 0.9, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 3, over: false) { p in
            p.a = SIMD4(px12(ctx, "spacing"), px12(ctx, "size"), px12(ctx, "speed"), n12(ctx, "wobble"))
            p.b = col12(ctx, "color"); p.c.x = n12(ctx, "seed") } })

    static let rainRipples12 = EffectDefinition(
        id: "awi12.rainRipples", name: "Rain Ripples", category: .generate, aeMatchNames: [],
        summary: "Raindrops landing on a wet floor, spreading concentric ripples.",
        params: p12([.number("spacing", "Spacing", 45, 10, 200, unit: "px"), .number("speed", "Drop Rate", 0.8, 0, 4, step: 0.01),
                  .number("rings", "Rings", 2, 1, 5, step: 0.1), .number("width", "Ring Width", 1.2, 0.3, 6, step: 0.1, unit: "px"),
                  .number("flatten", "Perspective", 50, 10, 100, unit: "%"), .color("color", "Color", RGBA(0.75, 0.88, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 4, over: false) { p in
            p.a = SIMD4(px12(ctx, "spacing"), n12(ctx, "speed"), n12(ctx, "rings"), px12(ctx, "width"))
            p.b = col12(ctx, "color"); p.c = SIMD4(n12(ctx, "seed"), pc12(ctx, "flatten"), 0, 0) } })

    static let vortexDust12 = EffectDefinition(
        id: "awi12.vortexDust", name: "Vortex Dust", category: .generate, aeMatchNames: [],
        summary: "Glowing dust swirling in a spiral vortex.",
        params: p12([.point("center", "Center", Vec2(0.5, 0.5)), .number("speed", "Spin Speed", 1, -4, 4, step: 0.01),
                  .number("twist", "Twist", 2, 0, 8, step: 0.01), .number("density", "Density", 8, 2, 20, step: 0.1),
                  .number("size", "Particle Size", 2.2, 0.5, 6, step: 0.1, unit: "px"), .number("inflow", "Inflow", 0.3, 0, 2, step: 0.01),
                  .number("streak", "Streak Length", 3, 1, 6, step: 0.01), .color("color", "Color", RGBA(1, 0.75, 0.45)), seed12]),
        stage: .pixels { ctx in g12(ctx, 5, over: false) { p in
            let c = pt12(ctx, "center")
            p.a = SIMD4(c.x, c.y, n12(ctx, "speed"), n12(ctx, "twist")); p.b = col12(ctx, "color")
            p.c = SIMD4(n12(ctx, "density"), px12(ctx, "size"), n12(ctx, "seed"), n12(ctx, "inflow")); p.d.w = n12(ctx, "streak") } })

    static let neuralNetwork12 = EffectDefinition(
        id: "awi12.neuralNetwork", name: "Neural Network", category: .generate, aeMatchNames: [],
        summary: "Nodes and synapses with energy pulses running along the links.",
        params: p12([.number("spacing", "Spacing", 44, 10, 200, unit: "px"), .number("speed", "Pulse Speed", 0.8, 0, 4, step: 0.01),
                  .number("size", "Node Size", 3, 0.5, 10, step: 0.1, unit: "px"), .number("width", "Line Width", 1, 0.2, 5, step: 0.1, unit: "px"),
                  .color("color", "Line Color", RGBA(0.3, 0.5, 1)), .color("pulse", "Pulse Color", RGBA(0.6, 1, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 6, over: false) { p in
            p.a = SIMD4(px12(ctx, "spacing"), n12(ctx, "speed"), px12(ctx, "size"), px12(ctx, "width"))
            p.b = col12(ctx, "color"); p.c = col12(ctx, "pulse"); p.d.w = n12(ctx, "seed") } })

    static let metaballs12 = EffectDefinition(
        id: "awi12.metaballs", name: "Metaballs", category: .generate, aeMatchNames: [],
        summary: "Glossy liquid blobs drifting and melting into each other, with rim light and soft glow.",
        params: p12([.number("size", "Blob Size", 14, 3, 40, unit: "%"), .number("speed", "Speed", 0.8, 0, 5, step: 0.01),
                  .number("threshold", "Gooeyness", 1, 0.2, 3, step: 0.01), .number("count", "Count", 7, 2, 12, step: 1),
                  .color("color", "Color 1", RGBA(1, 0.3, 0.6)), .color("color2", "Color 2", RGBA(0.4, 0.6, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 7, over: true) { p in
            p.a = SIMD4(pc12(ctx, "size"), n12(ctx, "speed"), n12(ctx, "threshold"), n12(ctx, "count"))
            p.b = col12(ctx, "color"); p.c = col12(ctx, "color2"); p.d.w = n12(ctx, "seed") } })

    static let voronoiShapes12 = EffectDefinition(
        id: "awi12.voronoiShapes", name: "Voronoi Shapes", category: .generate, aeMatchNames: [],
        summary: "Soft beveled cells in a curated palette, with depth shading and thin glowing seams.",
        params: p12([.number("size", "Cell Size", 46, 8, 250, unit: "px"), .number("speed", "Speed", 0.8, 0, 5, step: 0.01),
                  .number("border", "Border", 1.5, 0, 10, step: 0.1, unit: "px"), .number("saturation", "Saturation", 85, 0, 100, unit: "%"),
                  .number("palette", "Palette", 0, 0, 4, step: 1), seed12]),
        stage: .pixels { ctx in g12(ctx, 8, over: true) { p in
            p.a = SIMD4(px12(ctx, "size"), n12(ctx, "speed"), px12(ctx, "border"), pc12(ctx, "saturation"))
            p.c.x = n12(ctx, "seed"); p.c.y = n12(ctx, "palette") } })

    static let isolines12 = EffectDefinition(
        id: "awi12.isolines", name: "Isolines", category: .generate, aeMatchNames: [],
        summary: "Glowing contour lines of a slowly morphing noise landscape.",
        params: p12([.number("scale", "Scale", 60, 10, 400, unit: "px"), .number("speed", "Speed", 1, 0, 5, step: 0.01),
                  .number("lines", "Line Count", 8, 1, 30, step: 0.1), .number("width", "Line Width", 1.2, 0.3, 6, step: 0.1, unit: "px"),
                  .color("color", "Color 1", RGBA(0.3, 0.9, 1)), .color("color2", "Color 2", RGBA(1, 0.4, 0.9)), seed12]),
        stage: .pixels { ctx in g12(ctx, 9, over: false) { p in
            p.a = SIMD4(px12(ctx, "scale"), n12(ctx, "speed"), n12(ctx, "lines"), px12(ctx, "width"))
            p.b = col12(ctx, "color"); p.c = col12(ctx, "color2"); p.d.w = n12(ctx, "seed") } })

    static let cosmicNebula12 = EffectDefinition(
        id: "awi12.cosmicNebula", name: "Cosmic Nebula", category: .generate, aeMatchNames: [],
        summary: "Swirling space clouds with scattered twinkling stars.",
        params: p12([.number("scale", "Scale", 80, 10, 400, unit: "px"), .number("speed", "Speed", 0.5, 0, 3, step: 0.01),
                  .number("intensity", "Intensity", 1.2, 0, 4, step: 0.01), .number("stars", "Stars", 0.5, 0, 3, step: 0.01),
                  .color("color", "Color 1", RGBA(0.6, 0.2, 1)), .color("color2", "Color 2", RGBA(0.1, 0.7, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 10, over: false) { p in
            p.a = SIMD4(px12(ctx, "scale"), n12(ctx, "speed"), n12(ctx, "intensity"), n12(ctx, "stars"))
            p.b = col12(ctx, "color"); p.c = col12(ctx, "color2"); p.d.w = n12(ctx, "seed") } })

    static let glowTunnel12 = EffectDefinition(
        id: "awi12.glowTunnel", name: "Glow Tunnel", category: .generate, aeMatchNames: [],
        summary: "Neon polygon rings rushing toward the viewer with cycling colors.",
        params: p12([.point("center", "Center", Vec2(0.5, 0.5)), .number("speed", "Speed", 1.5, 0, 6, step: 0.01),
                  .number("density", "Ring Density", 1, 0.2, 5, step: 0.01), .number("sides", "Sides", 4, 3, 12, step: 1),
                  .number("glow", "Glow", 1, 0.1, 4, step: 0.01), .number("hueSpeed", "Color Cycle", 1, 0, 5, step: 0.01), seed12]),
        stage: .pixels { ctx in g12(ctx, 11, over: false) { p in
            let c = pt12(ctx, "center")
            p.a = SIMD4(c.x, c.y, n12(ctx, "speed"), n12(ctx, "density"))
            p.c = SIMD4(n12(ctx, "sides"), n12(ctx, "glow"), n12(ctx, "hueSpeed"), n12(ctx, "seed")) } })

    static let waveLines12 = EffectDefinition(
        id: "awi12.waveLines", name: "Wave Lines", category: .generate, aeMatchNames: [],
        summary: "Stacked flowing sine lines with a color gradient.",
        params: p12([.number("count", "Line Count", 12, 2, 60, step: 0.1), .number("amplitude", "Amplitude", 14, 0, 100, unit: "px"),
                  .number("frequency", "Frequency", 1.5, 0.1, 8, step: 0.01), .number("speed", "Speed", 2, 0, 10, step: 0.01),
                  .number("width", "Line Width", 1.2, 0.3, 6, step: 0.1, unit: "px"),
                  .color("color", "Color 1", RGBA(0.2, 0.8, 1)), .color("color2", "Color 2", RGBA(1, 0.3, 0.8))]),
        stage: .pixels { ctx in g12(ctx, 12, over: false) { p in
            p.a = SIMD4(n12(ctx, "count"), px12(ctx, "amplitude"), n12(ctx, "frequency"), n12(ctx, "speed"))
            p.b = col12(ctx, "color"); p.c = col12(ctx, "color2"); p.d.w = px12(ctx, "width") } })

    static let hexGridGlow12 = EffectDefinition(
        id: "awi12.hexGridGlow", name: "Hex Grid Glow", category: .generate, aeMatchNames: [],
        summary: "A glowing honeycomb grid with pulse waves and flashing cells.",
        params: p12([.number("size", "Hex Size", 22, 6, 150, unit: "px"), .number("speed", "Pulse Speed", 1, 0, 5, step: 0.01),
                  .number("width", "Line Width", 1.2, 0.3, 6, step: 0.1, unit: "px"), .number("glow", "Glow", 1.2, 0, 3, step: 0.01),
                  .color("color", "Color", RGBA(0.2, 0.9, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 13, over: false) { p in
            p.a = SIMD4(px12(ctx, "size"), n12(ctx, "speed"), px12(ctx, "width"), n12(ctx, "glow"))
            p.b = col12(ctx, "color"); p.c.x = n12(ctx, "seed") } })

    static let lightTrails12 = EffectDefinition(
        id: "awi12.lightTrails", name: "Light Trails", category: .generate, aeMatchNames: [],
        summary: "Long-exposure light streaks: curved glowing trails with bright heads and depth layers.",
        params: p12([.angle("angle", "Angle", 0), .number("spacing", "Spacing", 18, 3, 100, unit: "px"),
                  .number("speed", "Speed", 400, 0, 2000, unit: "px/s"), .number("length", "Trail Length", 60, 5, 200, unit: "%"),
                  .number("thickness", "Thickness", 2, 0.3, 8, step: 0.1, unit: "px"), .number("spread", "Color Spread", 40, 0, 100, unit: "%"),
                  .number("curve", "Curvature", 35, 0, 100, unit: "%"), .color("color", "Color", RGBA(1, 0.55, 0.3)), seed12]),
        stage: .pixels { ctx in g12(ctx, 14, over: false) { p in
            p.a = SIMD4(px12(ctx, "spacing"), px12(ctx, "speed"), pc12(ctx, "length"), px12(ctx, "thickness"))
            p.d.w = pc12(ctx, "curve")
            p.b = col12(ctx, "color")
            p.c = SIMD4(Float(ctx.num("angle") * .pi / 180), n12(ctx, "seed"), pc12(ctx, "spread"), 0) } })

    static let sunburst12 = EffectDefinition(
        id: "awi12.sunburst", name: "Sunburst", category: .generate, aeMatchNames: [],
        summary: "Soft rotating light rays fading from a glowing center, blended over the image.",
        params: p12([.point("center", "Center", Vec2(0.5, 0.5)), .number("rays", "Rays", 16, 2, 48, step: 1),
                  .number("speed", "Rotation Speed", 0.25, -3, 3, step: 0.01), .number("softness", "Softness", 45, 0, 100, unit: "%"),
                  .number("opacity", "Ray Opacity", 65, 0, 100, unit: "%"), .number("length", "Ray Length", 70, 5, 200, unit: "%"),
                  .color("color", "Color 1", RGBA(1, 0.88, 0.55)), .color("color2", "Color 2", RGBA(1, 0.5, 0.3))]),
        stage: .pixels { ctx in g12(ctx, 15, over: true) { p in
            let c = pt12(ctx, "center")
            p.a = SIMD4(c.x, c.y, n12(ctx, "rays"), n12(ctx, "speed"))
            p.b = col12(ctx, "color"); p.c = col12(ctx, "color2"); p.d.w = pc12(ctx, "softness")
            p.b.w = pc12(ctx, "length"); p.c.w = pc12(ctx, "opacity") } })

    static let kaleidoMandala12 = EffectDefinition(
        id: "awi12.kaleidoMandala", name: "Kaleido Mandala", category: .generate, aeMatchNames: [],
        summary: "A rotating, symmetric neon mandala pattern.",
        params: p12([.number("segments", "Segments", 8, 3, 24, step: 1), .number("speed", "Speed", 1, 0, 5, step: 0.01),
                  .number("scale", "Scale", 40, 10, 300, unit: "px"), .number("complexity", "Complexity", 1.5, 0.2, 5, step: 0.01),
                  .number("saturation", "Saturation", 80, 0, 100, unit: "%"), seed12]),
        stage: .pixels { ctx in g12(ctx, 16, over: false) { p in
            p.a = SIMD4(n12(ctx, "segments"), n12(ctx, "speed"), px12(ctx, "scale"), n12(ctx, "complexity"))
            p.c = SIMD4(n12(ctx, "seed"), pc12(ctx, "saturation"), 0, 0) } })

    static let gridWarp12 = EffectDefinition(
        id: "awi12.gridWarp", name: "Grid Warp", category: .generate, aeMatchNames: [],
        summary: "A glowing grid that bends and flows like fabric.",
        params: p12([.number("size", "Cell Size", 24, 6, 150, unit: "px"), .number("warp", "Warp", 10, 0, 80, unit: "px"),
                  .number("speed", "Speed", 1, 0, 5, step: 0.01), .number("width", "Line Width", 1, 0.3, 6, step: 0.1, unit: "px"),
                  .color("color", "Color", RGBA(0.7, 0.4, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 17, over: false) { p in
            p.a = SIMD4(px12(ctx, "size"), px12(ctx, "warp"), n12(ctx, "speed"), px12(ctx, "width"))
            p.b = col12(ctx, "color"); p.c.x = n12(ctx, "seed") } })

    static let liquidGradient12 = EffectDefinition(
        id: "awi12.liquidGradient", name: "Liquid Gradient", category: .generate, aeMatchNames: [],
        summary: "A flowing mesh gradient of four colors.",
        params: p12([.number("speed", "Speed", 0.5, 0, 3, step: 0.01), .number("warp", "Warp", 30, 0, 100, unit: "%"),
                  .number("softness", "Sharpness", 1.5, 0.3, 4, step: 0.01),
                  .color("color", "Color 1", RGBA(1, 0.35, 0.55)), .color("color2", "Color 2", RGBA(0.35, 0.4, 1)),
                  .color("color3", "Color 3", RGBA(0.2, 0.9, 0.85)), .color("color4", "Color 4", RGBA(1, 0.8, 0.3)), seed12]),
        stage: .pixels { ctx in g12(ctx, 18, over: true) { p in
            let c1 = col12(ctx, "color"), c2 = col12(ctx, "color2"), c3 = col12(ctx, "color3")
            p.a = SIMD4(c1.x, c1.y, c1.z, n12(ctx, "speed"))
            p.b = SIMD4(c2.x, c2.y, c2.z, pc12(ctx, "warp"))
            p.c = SIMD4(c3.x, c3.y, c3.z, n12(ctx, "softness"))
            p.d.w = n12(ctx, "seed"); p.i.z = pack12(ctx, "color4") } })

    static let inkSmoke12 = EffectDefinition(
        id: "awi12.inkSmoke", name: "Ink Smoke", category: .generate, aeMatchNames: [],
        summary: "Curling ink-in-water smoke wisps drifting upward.",
        params: p12([.number("scale", "Scale", 70, 10, 400, unit: "px"), .number("speed", "Speed", 0.6, 0, 3, step: 0.01),
                  .number("density", "Density", 60, 0, 100, unit: "%"), .number("softness", "Softness", 25, 2, 100, unit: "%"),
                  .color("color", "Color", RGBA(0.75, 0.7, 0.95)), seed12]),
        stage: .pixels { ctx in g12(ctx, 19, over: true) { p in
            p.a = SIMD4(px12(ctx, "scale"), n12(ctx, "speed"), pc12(ctx, "density"), pc12(ctx, "softness"))
            p.b = col12(ctx, "color"); p.c.x = n12(ctx, "seed") } })

    static let crystalShards12 = EffectDefinition(
        id: "awi12.crystalShards", name: "Crystal Shards", category: .generate, aeMatchNames: [],
        summary: "Faceted crystal shards catching a moving light, with glowing edges.",
        params: p12([.number("size", "Shard Size", 34, 8, 250, unit: "px"), .number("speed", "Light Speed", 1, 0, 5, step: 0.01),
                  .number("edge", "Edge Glow", 1, 0, 3, step: 0.01), .number("contrast", "Facet Contrast", 70, 0, 100, unit: "%"),
                  .number("refraction", "Refraction", 50, 0, 100, unit: "%"), .color("color", "Tint", RGBA(0.55, 0.75, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 20, over: true) { p in
            p.a = SIMD4(px12(ctx, "size"), n12(ctx, "speed"), n12(ctx, "edge"), pc12(ctx, "contrast"))
            p.b = col12(ctx, "color"); p.c.x = n12(ctx, "seed"); p.c.y = pc12(ctx, "refraction") } })

    static let spiralGalaxy12 = EffectDefinition(
        id: "awi12.spiralGalaxy", name: "Spiral Galaxy", category: .generate, aeMatchNames: [],
        summary: "A rotating spiral galaxy with dusty arms and a bright core.",
        params: p12([.point("center", "Center", Vec2(0.5, 0.5)), .number("size", "Size", 45, 5, 150, unit: "%"),
                  .number("speed", "Rotation Speed", 0.3, -3, 3, step: 0.01), .number("arms", "Arms", 2, 1, 8, step: 1),
                  .number("twist", "Twist", 3, 0, 8, step: 0.01), .color("color", "Arm Color", RGBA(0.45, 0.45, 1)),
                  .color("color2", "Core Color", RGBA(1, 0.8, 0.55)), seed12]),
        stage: .pixels { ctx in g12(ctx, 21, over: false) { p in
            let c = pt12(ctx, "center")
            p.a = SIMD4(c.x, c.y, pc12(ctx, "size"), n12(ctx, "speed")); p.b = col12(ctx, "color"); p.i.z = pack12(ctx, "color2")
            p.c = SIMD4(n12(ctx, "arms"), n12(ctx, "twist"), n12(ctx, "seed"), 0) } })

    static let orbitRings12 = EffectDefinition(
        id: "awi12.orbitRings", name: "Orbit Rings", category: .generate, aeMatchNames: [],
        summary: "Tilted orbital rings with glowing satellites circling a center.",
        params: p12([.point("center", "Center", Vec2(0.5, 0.5)), .number("radius", "Radius", 42, 5, 150, unit: "%"),
                  .number("speed", "Speed", 1, -4, 4, step: 0.01), .number("rings", "Rings", 4, 1, 8, step: 1),
                  .number("tilt", "Tilt", 32, 5, 100, unit: "%"), .number("width", "Line Width", 1.5, 0.2, 5, step: 0.1, unit: "px"),
                  .number("dot", "Satellite Size", 4, 0.5, 12, step: 0.1, unit: "px"), .color("color", "Color", RGBA(0.5, 0.9, 1)), seed12]),
        stage: .pixels { ctx in g12(ctx, 22, over: false) { p in
            let c = pt12(ctx, "center")
            p.a = SIMD4(c.x, c.y, pc12(ctx, "radius"), n12(ctx, "speed")); p.b = col12(ctx, "color")
            p.c = SIMD4(n12(ctx, "rings"), pc12(ctx, "tilt"), px12(ctx, "width"), px12(ctx, "dot")); p.d.w = n12(ctx, "seed") } })

    static let heartbeatLine12 = EffectDefinition(
        id: "awi12.heartbeatLine", name: "Heartbeat Line", category: .generate, aeMatchNames: [],
        summary: "An ECG heartbeat trace sweeping across with a glowing head.",
        params: p12([.number("y", "Height", 50, 0, 100, unit: "%"), .number("amplitude", "Amplitude", 40, 0, 200, unit: "px"),
                  .number("beat", "Beat Width", 70, 10, 400, unit: "px"), .number("speed", "Sweep Speed", 0.5, 0, 3, step: 0.01),
                  .number("width", "Line Width", 2.5, 0.3, 6, step: 0.1, unit: "px"), .number("trail", "Trail", 60, 5, 100, unit: "%"),
                  .number("grid", "Grid", 30, 0, 100, unit: "%"), .color("color", "Color", RGBA(0.3, 1, 0.55))]),
        stage: .pixels { ctx in g12(ctx, 23, over: false) { p in
            p.a = SIMD4(pc12(ctx, "y"), px12(ctx, "amplitude"), px12(ctx, "beat"), n12(ctx, "speed"))
            p.b = col12(ctx, "color"); p.c = SIMD4(px12(ctx, "width"), pc12(ctx, "trail"), pc12(ctx, "grid"), 0) } })

    static let sparkleDust12 = EffectDefinition(
        id: "awi12.sparkleDust", name: "Sparkle Dust", category: .generate, aeMatchNames: [],
        summary: "Drifting glitter that flashes with little star glints.",
        params: p12([.number("spacing", "Spacing", 20, 5, 100, unit: "px"), .number("size", "Size", 4, 1, 20, step: 0.1, unit: "px"),
                  .number("flash", "Flash Speed", 1.5, 0, 6, step: 0.01), .number("drift", "Drift", 20, 0, 200, unit: "px/s"),
                  .number("variance", "Color Variance", 50, 0, 100, unit: "%"), .color("color", "Color", RGBA(1, 0.9, 0.7)), seed12]),
        stage: .pixels { ctx in g12(ctx, 24, over: false) { p in
            p.a = SIMD4(px12(ctx, "spacing"), px12(ctx, "size"), n12(ctx, "flash"), px12(ctx, "drift"))
            p.b = col12(ctx, "color"); p.c = SIMD4(n12(ctx, "seed"), pc12(ctx, "variance"), 0, 0) } })
}
