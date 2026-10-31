import Foundation
import Metal
import simd

/// Batch 17: 3D-look procedurals — tiny raymarched solids, input-textured projections (tunnel, skybox, sphere /
/// cylinder wrap, page flip, cube flip, rotating plane), 3D scenes (floor grid, starfield planes, skyline, seascape,
/// clouds, point cloud, orbiting particles) and an alpha extrusion. All composite over the layer (Blend / Only).
extension EffectRegistry {
    static let batch17: [EffectDefinition] = [
        rmCube17, rmSphere17, rmTorus17, rmCylinder17, rmPyramid17, rmOctahedron17, rmStarPrism17, rmHeart17,
        rmHollowBox17, rmRing17, tunnel3D17, cubeSkybox17, sphereMap17, cylinderWrap17, pageFlip17, cubeFlip17,
        floorGrid17, starPlanes17, citySkyline17, seascape17, volClouds17, pointCloud17, orbitParticles17,
        extrudeFlat17, logoPlane17,
    ]

    /// comp: 0 additive light, 1 over (straight color + coverage), 2 replace (premultiplied, mixed by Blend).
    private static func g17(_ ctx: EffectContext, _ mode: UInt32, comp: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.i.y = comp
        p.d.x = Float(ctx.time)
        p.d.y = Float(ctx.num("blend") / 100)
        p.d.z = ctx.effect.bool("only") ? 1 : 0
        ctx.gpu.run("fx3D17", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }
    private static func n17(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k)) }
    private static func px17(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * ctx.unit) }
    private static func pc17(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) / 100) }
    private static func rad17(_ ctx: EffectContext, _ k: String) -> Float { Float(ctx.num(k) * .pi / 180) }
    private static func col17(_ ctx: EffectContext, _ k: String) -> SIMD4<Float> { ctx.effect.color(k, ctx.time).simd }
    private static func mn17(_ ctx: EffectContext) -> Float { Float(max(min(ctx.width, ctx.height), 1)) }
    private static func p17(_ list: [ParamDef], _ blend: Double = 100) -> [ParamDef] {
        list + [.number("blend", "Blend", blend, 0, 100, unit: "%"), .toggle("only", "Effect Only", false)]
    }

    // MARK: Raymarched solids

    private static func solid17(_ id: String, _ name: String, _ mode: UInt32, _ summary: String, _ color: RGBA,
                                rx: Double = 30, ry: Double = 45) -> EffectDefinition {
        EffectDefinition(
            id: "awi17." + id, name: name, category: .generate, aeMatchNames: [], summary: summary,
            params: p17([.number("rotX", "Spin X Speed", rx, -360, 360, unit: "°/s"),
                         .number("rotY", "Spin Y Speed", ry, -360, 360, unit: "°/s"),
                         .number("size", "Size", 45, 5, 100, unit: "%"),
                         .angle("light", "Light Angle", 45), .color("color", "Color", color)]),
            stage: .pixels { ctx in g17(ctx, mode, comp: 1) { p in
                p.a = SIMD4(rad17(ctx, "rotX"), rad17(ctx, "rotY"), pc17(ctx, "size"), rad17(ctx, "light"))
                p.b = col17(ctx, "color") } })
    }

    static let rmCube17 = solid17("cube", "Raymarched Cube", 0, "A lit, rounded 3D cube spinning in place.", RGBA(0.3, 0.6, 1))
    static let rmSphere17 = solid17("sphere", "Raymarched Sphere", 1, "A shaded 3D ball with a spinning surface pattern.", RGBA(1, 0.45, 0.3))
    static let rmTorus17 = solid17("torus", "Raymarched Torus", 2, "A spinning 3D donut with soft lighting.", RGBA(1, 0.75, 0.2))
    static let rmCylinder17 = solid17("cylinder", "Raymarched Cylinder", 3, "A tumbling 3D cylinder.", RGBA(0.4, 0.9, 0.6))
    static let rmPyramid17 = solid17("pyramid", "Raymarched Pyramid", 4, "A spinning square-based 3D pyramid.", RGBA(0.95, 0.8, 0.45))
    static let rmOctahedron17 = solid17("octahedron", "Raymarched Octahedron", 5, "A spinning 3D diamond (octahedron).", RGBA(0.6, 0.5, 1))
    static let rmStarPrism17 = solid17("starPrism", "Star Prism 3D", 6, "A thick extruded five-point star spinning in 3D.", RGBA(1, 0.85, 0.2))
    static let rmHeart17 = solid17("heart", "Heart 3D", 7, "A puffy extruded 3D heart.", RGBA(1, 0.25, 0.4), rx: 20, ry: 60)
    static let rmHollowBox17 = solid17("hollowBox", "Hollow Box 3D", 8, "A wireframe-style 3D box frame spinning in place.", RGBA(0.3, 0.95, 1))
    static let rmRing17 = solid17("ring", "Ring 3D", 9, "A flat 3D ring tumbling through space.", RGBA(1, 0.6, 0.9))

    // MARK: Input-textured projections

    static let tunnel3D17 = EffectDefinition(
        id: "awi17.tunnel3D", name: "Infinite Tunnel 3D", category: .generate, aeMatchNames: [],
        summary: "Flies down an endless tunnel whose walls are tiled with the layer image.",
        params: p17([.number("speed", "Speed", 0.6, -5, 5, step: 0.01), .number("repeat", "Wall Tiles", 3, 1, 8, step: 1),
                     .number("twist", "Twist", 0.5, -3, 3, step: 0.01), .number("fog", "Depth Fog", 70, 0, 100, unit: "%")]),
        stage: .pixels { ctx in g17(ctx, 10, comp: 2) { p in
            p.a = SIMD4(n17(ctx, "speed"), n17(ctx, "repeat"), n17(ctx, "twist"), pc17(ctx, "fog")) } })

    static let cubeSkybox17 = EffectDefinition(
        id: "awi17.cubeSkybox", name: "Cube Skybox", category: .distort, aeMatchNames: [],
        summary: "Puts the layer on all six walls of a cube and looks around from inside it.",
        params: p17([.number("yawSpeed", "Turn Speed", 25, -180, 180, unit: "°/s"), .number("yaw", "Yaw", 30, -180, 180, unit: "°"),
                     .number("pitch", "Pitch", 15, -89, 89, unit: "°"), .number("fov", "Field of View", 90, 30, 150, unit: "°")]),
        stage: .pixels { ctx in g17(ctx, 11, comp: 2) { p in
            p.a = SIMD4(rad17(ctx, "yaw") + rad17(ctx, "yawSpeed") * Float(ctx.time), rad17(ctx, "pitch"), rad17(ctx, "fov"), 0) } })

    static let sphereMap17 = EffectDefinition(
        id: "awi17.sphereMap", name: "Sphere Map", category: .distort, aeMatchNames: [],
        summary: "Wraps the layer around a rotating, shaded 3D globe.",
        params: p17([.number("radius", "Radius", 95, 5, 150, unit: "%"), .number("spin", "Spin Speed", 40, -360, 360, unit: "°/s"),
                     .number("tilt", "Tilt", 20, -90, 90, unit: "°"), .number("shading", "Shading", 70, 0, 100, unit: "%"),
                     .number("shadow", "Drop Shadow", 50, 0, 100, unit: "%")]),
        stage: .pixels { ctx in g17(ctx, 12, comp: 2) { p in
            p.a = SIMD4(pc17(ctx, "radius") * mn17(ctx) * 0.5, rad17(ctx, "spin") * Float(ctx.time), rad17(ctx, "tilt"), pc17(ctx, "shading"))
            p.b.x = pc17(ctx, "shadow") } })

    static let cylinderWrap17 = EffectDefinition(
        id: "awi17.cylinderWrap", name: "Cylinder Wrap", category: .distort, aeMatchNames: [],
        summary: "Wraps the layer around a spinning vertical 3D cylinder.",
        params: p17([.number("radius", "Radius", 60, 5, 100, unit: "%"), .number("spin", "Spin Speed", 40, -360, 360, unit: "°/s"),
                     .number("height", "Height", 80, 10, 100, unit: "%"), .number("shading", "Shading", 70, 0, 100, unit: "%"),
                     .number("shadow", "Drop Shadow", 50, 0, 100, unit: "%")]),
        stage: .pixels { ctx in g17(ctx, 13, comp: 2) { p in
            p.a = SIMD4(pc17(ctx, "radius") * Float(ctx.width) * 0.5, rad17(ctx, "spin") * Float(ctx.time),
                        pc17(ctx, "height") * Float(ctx.height), pc17(ctx, "shading"))
            p.b.x = pc17(ctx, "shadow") } })

    private static func eye17(_ ctx: EffectContext) -> Float { mn17(ctx) * (4.0 - 3.0 * pc17(ctx, "perspective")) }

    static let pageFlip17 = EffectDefinition(
        id: "awi17.pageFlip", name: "Page Flip 3D", category: .distort, aeMatchNames: [],
        summary: "Turns the layer over like a book page hinged on its left edge (animate Progress).",
        params: p17([.number("progress", "Progress", 35, 0, 100, unit: "%"), .number("perspective", "Perspective", 50, 0, 100, unit: "%"),
                     .number("shading", "Shading", 70, 0, 100, unit: "%"), .number("pageSize", "Page Size", 90, 30, 100, unit: "%"),
                     .number("shadow", "Drop Shadow", 50, 0, 100, unit: "%")]),
        stage: .pixels { ctx in g17(ctx, 14, comp: 2) { p in
            p.a = SIMD4(pc17(ctx, "progress") * .pi, eye17(ctx), pc17(ctx, "shading"), pc17(ctx, "pageSize"))
            p.b.x = pc17(ctx, "shadow") } })

    static let cubeFlip17 = EffectDefinition(
        id: "awi17.cubeFlip", name: "Cube Flip", category: .distort, aeMatchNames: [],
        summary: "Puts the layer on a 3D cube that rotates a quarter turn to the next face (animate Progress).",
        params: p17([.number("progress", "Progress", 30, 0, 100, unit: "%"), .number("perspective", "Perspective", 50, 0, 100, unit: "%"),
                     .number("shading", "Shading", 60, 0, 100, unit: "%")]),
        stage: .pixels { ctx in g17(ctx, 15, comp: 2) { p in
            p.a = SIMD4(pc17(ctx, "progress") * .pi * 0.5, eye17(ctx), pc17(ctx, "shading"), 0) } })

    static let logoPlane17 = EffectDefinition(
        id: "awi17.logoPlane", name: "Rotating Logo Plane", category: .distort, aeMatchNames: [],
        summary: "Shows the layer as a flat card turning in 3D with real perspective.",
        params: p17([.number("rotX", "Rotation X", 20, -180, 180, unit: "°"), .number("rotY", "Rotation Y", 35, -180, 180, unit: "°"),
                     .number("spin", "Spin Speed", 0, -360, 360, unit: "°/s"), .number("fov", "Field of View", 50, 10, 120, unit: "°"),
                     .number("shading", "Shading", 50, 0, 100, unit: "%")]),
        stage: .pixels { ctx in g17(ctx, 16, comp: 2) { p in
            let eye = Float(ctx.height) * 0.5 / tan(rad17(ctx, "fov") * 0.5)
            p.a = SIMD4(rad17(ctx, "rotX"), rad17(ctx, "rotY") + rad17(ctx, "spin") * Float(ctx.time), eye, pc17(ctx, "shading")) } })

    // MARK: 3D scenes

    static let floorGrid17 = EffectDefinition(
        id: "awi17.floorGrid", name: "Floor Grid 360", category: .generate, aeMatchNames: [],
        summary: "An endless glowing floor grid seen from a camera that turns around 360°.",
        params: p17([.number("yawSpeed", "Turn Speed", 25, -90, 90, unit: "°/s"), .number("cell", "Cell Size", 1, 0.2, 4, step: 0.01),
                     .number("height", "Camera Height", 1, 0.2, 4, step: 0.01), .number("width", "Line Width", 4, 1, 20, unit: "%"),
                     .number("glow", "Horizon Glow", 50, 0, 100, unit: "%"), .color("color", "Color", RGBA(0.2, 0.9, 1))]),
        stage: .pixels { ctx in g17(ctx, 17, comp: 0) { p in
            p.a = SIMD4(0.3 + rad17(ctx, "yawSpeed") * Float(ctx.time), n17(ctx, "cell"), n17(ctx, "height"), pc17(ctx, "width"))
            p.b = col17(ctx, "color"); p.c.x = pc17(ctx, "glow") } })

    static let starPlanes17 = EffectDefinition(
        id: "awi17.starPlanes", name: "3D Starfield Planes", category: .generate, aeMatchNames: [],
        summary: "Layers of star planes flying toward the camera with a slow roll.",
        params: p17([.number("speed", "Speed", 1, 0, 5, step: 0.01), .number("density", "Density", 5, 1, 12, step: 0.1),
                     .number("size", "Star Size", 1.6, 0.5, 6, step: 0.1, unit: "px"), .number("roll", "Roll Speed", 10, -90, 90, unit: "°/s"),
                     .color("color", "Color", RGBA(0.9, 0.95, 1))]),
        stage: .pixels { ctx in g17(ctx, 18, comp: 0) { p in
            p.a = SIMD4(n17(ctx, "speed"), n17(ctx, "density"), px17(ctx, "size"), rad17(ctx, "roll") * Float(ctx.time))
            p.b = col17(ctx, "color") } })

    static let citySkyline17 = EffectDefinition(
        id: "awi17.citySkyline", name: "City Skyline", category: .generate, aeMatchNames: [],
        summary: "Scrolling layers of 3D-looking buildings with lit windows.",
        params: p17([.number("speed", "Scroll Speed", 40, 0, 400, unit: "px/s"), .number("width", "Building Width", 28, 10, 120, unit: "px"),
                     .number("height", "Max Height", 55, 10, 100, unit: "%"), .number("windows", "Lit Windows", 60, 0, 100, unit: "%"),
                     .color("color", "Building Color", RGBA(0.25, 0.28, 0.4)), .color("window", "Window Color", RGBA(1, 0.85, 0.45))]),
        stage: .pixels { ctx in g17(ctx, 19, comp: 1) { p in
            p.a = SIMD4(px17(ctx, "speed") * Float(ctx.time), px17(ctx, "width"), pc17(ctx, "height"), pc17(ctx, "windows"))
            p.b = col17(ctx, "color"); p.c = col17(ctx, "window") } })

    static let seascape17 = EffectDefinition(
        id: "awi17.seascape", name: "Seascape", category: .generate, aeMatchNames: [],
        summary: "Rolling ocean waves under a sky with a low sun and reflections.",
        params: p17([.number("waves", "Wave Height", 0.6, 0, 2, step: 0.01), .number("speed", "Wave Speed", 1, 0, 5, step: 0.01),
                     .number("height", "Camera Height", 1.2, 0.3, 5, step: 0.01), .angle("sun", "Sun Angle", 60),
                     .color("water", "Water Color", RGBA(0.05, 0.25, 0.4)), .color("sky", "Sky Color", RGBA(0.35, 0.55, 0.9))]),
        stage: .pixels { ctx in g17(ctx, 20, comp: 1) { p in
            p.a = SIMD4(n17(ctx, "waves"), n17(ctx, "speed"), n17(ctx, "height"), rad17(ctx, "sun"))
            p.b = col17(ctx, "water"); p.c = col17(ctx, "sky") } })

    static let volClouds17 = EffectDefinition(
        id: "awi17.volClouds", name: "Volumetric Clouds", category: .generate, aeMatchNames: [],
        summary: "Fluffy raymarched clouds with sun scattering (bright tops, shaded bases, silver lining) drifting overhead.",
        params: p17([.number("coverage", "Coverage", 50, 0, 100, unit: "%"), .number("speed", "Drift Speed", 0.6, 0, 5, step: 0.01),
                     .number("density", "Density", 1.5, 0.1, 5, step: 0.01), .angle("sun", "Sun Direction", 60),
                     .color("color", "Color", RGBA(1, 1, 1))]),
        stage: .pixels { ctx in g17(ctx, 21, comp: 1) { p in
            p.a = SIMD4(pc17(ctx, "coverage"), n17(ctx, "speed"), n17(ctx, "density"), rad17(ctx, "sun"))
            p.b = col17(ctx, "color") } })

    static let pointCloud17 = EffectDefinition(
        id: "awi17.pointCloud", name: "Point Cloud Sphere", category: .generate, aeMatchNames: [],
        summary: "A big rotating sphere of glowing points with depth: near points larger and brighter, far ones dimmer and tinted.",
        params: p17([.number("rotX", "Spin X Speed", 20, -360, 360, unit: "°/s"), .number("rotY", "Spin Y Speed", 50, -360, 360, unit: "°/s"),
                     .number("size", "Size", 80, 10, 100, unit: "%"), .number("count", "Points", 600, 50, 2000, step: 1),
                     .number("dot", "Dot Size", 3, 0.5, 10, step: 0.1, unit: "px"), .color("color", "Near Color", RGBA(0.4, 0.95, 1)),
                     .color("farColor", "Far Color", RGBA(0.55, 0.25, 1))]),
        stage: .pixels { ctx in g17(ctx, 22, comp: 0) { p in
            p.a = SIMD4(rad17(ctx, "rotX"), rad17(ctx, "rotY"), pc17(ctx, "size") * mn17(ctx) * 0.42, px17(ctx, "dot"))
            p.b = col17(ctx, "color"); p.c = col17(ctx, "farColor"); p.d.w = n17(ctx, "count") } })

    static let orbitParticles17 = EffectDefinition(
        id: "awi17.orbitParticles", name: "3D Particles Orbit", category: .generate, aeMatchNames: [],
        summary: "A big swirling 3D swarm of glowing particles with motion streaks and depth-of-field, orbiting the center.",
        params: p17([.number("speed", "Orbit Speed", 1, -5, 5, step: 0.01), .number("radius", "Radius", 85, 10, 100, unit: "%"),
                     .number("tilt", "Tilt", 25, -90, 90, unit: "°"), .number("count", "Particles", 48, 8, 64, step: 1),
                     .number("dot", "Particle Size", 4, 0.5, 12, step: 0.1, unit: "px"),
                     .number("trail", "Trail Length", 45, 0, 100, unit: "%"), .color("color", "Color", RGBA(1, 0.75, 0.35))]),
        stage: .pixels { ctx in g17(ctx, 23, comp: 0) { p in
            p.a = SIMD4(n17(ctx, "speed"), pc17(ctx, "radius") * mn17(ctx) * 0.55, rad17(ctx, "tilt"), px17(ctx, "dot"))
            p.b = col17(ctx, "color"); p.c.x = n17(ctx, "count"); p.c.y = pc17(ctx, "trail") } })

    static let extrudeFlat17 = EffectDefinition(
        id: "awi17.extrudeFlat", name: "Extrude Flat", category: .generate, aeMatchNames: [],
        summary: "Fakes a solid 3D extrusion of the layer's shape by stacking shaded offset copies of its alpha.",
        params: p17([.number("depth", "Depth", 40, 0, 150, unit: "px"), .angle("angle", "Direction", 135),
                     .number("shade", "Side Shading", 60, 0, 100, unit: "%"), .number("layerColor", "Use Layer Color", 0, 0, 100, unit: "%"),
                     .color("color", "Side Color", RGBA(0.35, 0.3, 0.5))]),
        margin: { e, t in e.number("depth", t) },
        stage: .pixels { ctx in g17(ctx, 24, comp: 2) { p in
            p.a = SIMD4(px17(ctx, "depth"), rad17(ctx, "angle"), pc17(ctx, "shade"), pc17(ctx, "layerColor"))
            p.b = col17(ctx, "color") } })
}
