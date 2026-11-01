import Foundation
import Metal
import simd

/// Batch 19: the glitch pack. Every glitch shares designed timing — an always-on base, burst hits that attack
/// instantly and ring out, fast small jitter, rare big spikes, and pieces that hold a frame or two then snap.
extension EffectRegistry {
    static let batch19: [EffectDefinition] = [sliceGlitch19, datamosh19, pixelSort19, jpeg19, vhsTracking19, signalLoss19,
                                              interlace19, blockCorrupt19, stutter19, mirrorTile19, slitScan19, chromaShatter19,
                                              glitchFlash19, displaceGlitch19, colorSelect19]

    /// Keeps only one color (like a reversed chroma key): duplicate a layer, keep just the hair / eyes / energy,
    /// then glow or grade that part on its own.
    static let colorSelect19 = EffectDefinition(
        id: "awi19.colorSelect", name: "Color Select", category: .keying, aeMatchNames: [],
        summary: "Keeps only the picked color and hides everything else (or the opposite). Great for glowing just the hair, eyes or energy on a copy of the layer.",
        params: [
            .color("color", "Color to Keep", RGBA(0.1, 0.9, 0.2)),
            .number("tolerance", "Tolerance", 25, 0, 100, unit: "%"),
            .number("softness", "Edge Softness", 10, 0, 100, unit: "%"),
            .number("luma", "Brightness Matters", 20, 0, 100, unit: "%"),
            .toggle("invert", "Invert (hide that color instead)", false),
        ],
        stage: .pixels { ctx in
            let out = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(Float(ctx.num("tolerance") / 100 * 0.8), Float(ctx.num("softness") / 100 * 0.5), ctx.effect.bool("invert") ? 1 : 0, Float(ctx.num("luma") / 100))
            p.b = ctx.effect.color("color", ctx.time).simd
            ctx.gpu.run("fx19ColorSelect", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            return out
        })

    /// Shared timing controls (b vector in the kernel).
    private static let timing: [ParamDef] = [
        .number("base", "Always On", 25, 0, 100, unit: "%"),
        .number("rate", "Bursts Per Second", 3, 0.2, 20, step: 0.05),
        .number("length", "Burst Length", 50, 2, 100, unit: "%"),
        .number("seed", "Random Seed", 1, 0, 1000, step: 1),
    ]

    private static func glitch(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.b = SIMD4(Float(ctx.num("base") / 100), Float(ctx.num("rate")), Float(ctx.num("length") / 100), Float(ctx.num("seed")))
        p.i.x = mode
        p.d.x = Float(ctx.time)
        ctx.gpu.run("fx19", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }

    private static func g(_ id: String, _ name: String, _ summary: String, _ params: [ParamDef], margin: @escaping (EffectInstance, Double) -> Double = { _, _ in 0 },
                          _ mode: UInt32, _ fill: @escaping (EffectContext, inout EffectParams) -> Void) -> EffectDefinition {
        EffectDefinition(id: "awi19." + id, name: name, category: .glitch, aeMatchNames: [], summary: summary, params: params + timing,
                         margin: margin, stage: .pixels { ctx in glitch(ctx, mode) { fill(ctx, &$0) } })
    }

    static let sliceGlitch19 = g("slice", "Slice Glitch", "Horizontal slices jump sideways with a color split, in bursts.",
        [.number("offset", "Slice Offset", 60, 0, 400, unit: "px"), .number("slices", "Slices", 16, 2, 80, step: 1), .number("rgb", "RGB Split", 10, 0, 80, unit: "px")],
        margin: { e, t in e.number("offset", t) }, 0) { ctx, p in
        p.a = SIMD4(Float(ctx.num("offset") * ctx.unit), Float(ctx.num("slices")), Float(ctx.num("rgb") * ctx.unit), 0)
    }

    static let datamosh19 = g("datamosh", "Datamosh", "Blocks smear their pixels along a motion field and freeze like broken video compression.",
        [.number("smear", "Smear", 40, 0, 300, unit: "px"), .number("block", "Block Size", 16, 4, 80, step: 1, unit: "px"), .number("stuck", "Frozen Blocks", 40, 0, 100, unit: "%")],
        margin: { e, t in e.number("smear", t) }, 1) { ctx, p in
        p.a = SIMD4(Float(ctx.num("smear") * ctx.unit), Float(ctx.num("block") * ctx.unit), Float(ctx.num("stuck") / 100), 0)
    }

    static let pixelSort19 = g("pixelSort", "Pixel Sort", "Bright runs of pixels stretch into streaks along a direction.",
        [.number("streak", "Streak Length", 60, 0, 400, unit: "px"), .number("threshold", "Brightness Threshold", 45, 0, 100, unit: "%"), .angle("angle", "Direction", 90)],
        margin: { e, t in e.number("streak", t) }, 2) { ctx, p in
        p.a = SIMD4(Float(ctx.num("streak") * ctx.unit), Float(ctx.num("threshold") / 100), Float(ctx.num("angle") * .pi / 180), 0)
    }

    static let jpeg19 = g("jpeg", "JPEG Corruption", "Blocky compression damage, ringing, color bleed and hue-shifted blocks.",
        [.number("damage", "Damage", 70, 0, 100, unit: "%"), .number("block", "Block Size", 8, 2, 48, step: 1, unit: "px"), .number("bleed", "Color Bleed", 8, 0, 60, unit: "px")],
        margin: { e, t in e.number("bleed", t) }, 3) { ctx, p in
        p.a = SIMD4(Float(ctx.num("damage") / 100), Float(ctx.num("block") * ctx.unit), Float(ctx.num("bleed") * ctx.unit), 0)
    }

    static let vhsTracking19 = g("vhs", "VHS Tracking", "A rolling tracking band warps the picture, with chroma bleed, tape noise and bright tape lines.",
        [.number("tracking", "Tracking Warp", 40, 0, 300, unit: "px"), .number("band", "Band Height", 30, 2, 100, unit: "%"),
         .number("roll", "Roll Speed", 1, 0, 10, step: 0.05), .number("noise", "Tape Noise", 35, 0, 100, unit: "%"), .number("bleed", "Color Bleed", 6, 0, 40, unit: "px")],
        margin: { e, t in e.number("tracking", t) }, 4) { ctx, p in
        p.a = SIMD4(Float(ctx.num("tracking") * ctx.unit), Float(ctx.num("band") / 100), Float(ctx.num("roll")), Float(ctx.num("noise") / 100))
        p.c.x = Float(ctx.num("bleed") * ctx.unit)
    }

    static let signalLoss19 = g("signalLoss", "Signal Loss", "The picture drops into static and color bars, then snaps back.",
        [.number("static", "Static", 70, 0, 100, unit: "%"), .number("bars", "Color Bars", 30, 0, 100, unit: "%"), .number("drop", "Drop Strength", 80, 0, 100, unit: "%")],
        5) { ctx, p in
        p.a = SIMD4(Float(ctx.num("static") / 100), Float(ctx.num("bars") / 100), Float(ctx.num("drop") / 100), 0)
    }

    static let interlace19 = g("interlace", "Interlace / Bad TV", "Odd and even lines tear apart with a CRT wobble and scanlines.",
        [.number("split", "Line Split", 12, 0, 120, unit: "px"), .number("wobble", "Wobble", 10, 0, 120, unit: "px"), .number("scan", "Scanlines", 50, 0, 100, unit: "%")],
        margin: { e, t in e.number("split", t) + e.number("wobble", t) }, 6) { ctx, p in
        p.a = SIMD4(Float(ctx.num("split") * ctx.unit), Float(ctx.num("wobble") * ctx.unit), Float(ctx.num("scan") / 100), 0)
    }

    static let blockCorrupt19 = g("blockCorrupt", "Block Corruption", "Blocks fill with frozen pixels and wrong colors.",
        [.number("amount", "Amount", 60, 0, 100, unit: "%"), .number("block", "Block Size", 18, 4, 100, step: 1, unit: "px"), .number("shift", "Color Shift", 60, 0, 100, unit: "%")],
        7) { ctx, p in
        p.a = SIMD4(Float(ctx.num("amount") / 100), Float(ctx.num("block") * ctx.unit), Float(ctx.num("shift") / 100), 0)
    }

    static let stutter19 = g("stutter", "Stutter Jump", "The picture jumps between held spots with a ghost of the last one, like skipped frames.",
        [.number("jump", "Jump Distance", 30, 0, 300, unit: "px"), .number("ghost", "Ghost", 50, 0, 100, unit: "%"), .number("zoom", "Zoom Kick", 40, 0, 100, unit: "%")],
        margin: { e, t in e.number("jump", t) }, 8) { ctx, p in
        p.a = SIMD4(Float(ctx.num("jump") * ctx.unit), Float(ctx.num("ghost") / 100), Float(ctx.num("zoom") / 100), 0)
    }

    static let mirrorTile19 = g("mirrorTile", "Mirror Tile Glitch", "The frame splits into tiles that randomly flip and shift.",
        [.number("tiles", "Tiles", 4, 1, 16, step: 1), .number("flip", "Flip Amount", 70, 0, 100, unit: "%"), .number("offset", "Tile Shift", 20, 0, 200, unit: "px")],
        9) { ctx, p in
        p.a = SIMD4(Float(ctx.num("tiles")), Float(ctx.num("flip") / 100), Float(ctx.num("offset") * ctx.unit), 0)
    }

    static let slitScan19 = g("slitScan", "Slit Scan", "Rows slide on a traveling wave for a stretched, melting time-smear look.",
        [.number("stretch", "Stretch", 40, 0, 300, unit: "px"), .number("frequency", "Frequency", 40, 1, 200), .number("speed", "Speed", 4, 0, 30, step: 0.1), .angle("angle", "Direction", 0)],
        margin: { e, t in e.number("stretch", t) }, 10) { ctx, p in
        p.a = SIMD4(Float(ctx.num("stretch") * ctx.unit), Float(ctx.num("frequency") / max(ctx.unit, 1e-3)), Float(ctx.num("speed")), Float(ctx.num("angle") * .pi / 180))
    }

    static let chromaShatter19 = g("chromaShatter", "Chroma Shatter", "The picture breaks into shards, each pushed out with its own color split.",
        [.number("shards", "Shards", 8, 2, 40, step: 1), .number("push", "Push", 30, 0, 200, unit: "px"), .number("rgb", "RGB Split", 12, 0, 80, unit: "px")],
        margin: { e, t in e.number("push", t) + e.number("rgb", t) }, 11) { ctx, p in
        p.a = SIMD4(Float(ctx.num("shards")), Float(ctx.num("push") * ctx.unit), Float(ctx.num("rgb") * ctx.unit), 0)
    }

    static let glitchFlash19 = g("flash", "Glitch Flash", "Single-frame hits: invert, a shifted channel and a flash.",
        [.number("invert", "Invert", 80, 0, 100, unit: "%"), .number("shift", "Channel Shift", 14, 0, 100, unit: "px"), .number("flash", "Flash", 40, 0, 100, unit: "%")],
        margin: { e, t in e.number("shift", t) }, 12) { ctx, p in
        p.a = SIMD4(Float(ctx.num("invert") / 100), Float(ctx.num("shift") * ctx.unit), Float(ctx.num("flash") / 100), 0)
    }

    static let displaceGlitch19 = g("displace", "Displacement Glitch", "Blocky noise pushes the layer around in steps.",
        [.number("amount", "Amount", 30, 0, 300, unit: "px"), .number("block", "Block Size", 12, 2, 80, step: 1, unit: "px"),
         .number("steps", "Steps Per Second", 12, 1, 30, step: 1), .number("vertical", "Vertical", 30, 0, 100, unit: "%")],
        margin: { e, t in e.number("amount", t) }, 13) { ctx, p in
        p.a = SIMD4(Float(ctx.num("amount") * ctx.unit), Float(ctx.num("block") * ctx.unit), Float(ctx.num("steps")), Float(ctx.num("vertical") / 100))
    }
}
