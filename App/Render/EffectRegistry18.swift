import Foundation
import Metal
import simd

/// Batch 18: edit essentials for AMV / manga edits — an AE-grade Shake Pro, Zoom Punch for beat hits,
/// Twitch-style glitch bursts and a manga negative / mono flash.
extension EffectRegistry {
    static let batch18: [EffectDefinition] = [shakePro18, zoomPunch18, twitch18, negativeFlash18,
                                              warpChroma18, scanTear18, waveGlitch18, blockShuffle18, channelSmear18, puppet18, grade, transformFX18, displacementMap18, setMatte18, particles18]

    /// Quantizes time to "hold" frames (choppy anime shake: the shake jumps every few frames).
    private static func held(_ t: Double, _ hold: Double) -> Double {
        guard hold >= 1 else { return t }
        let step = (hold + 1) / 30
        return (t / step).rounded(.down) * step
    }

    private static func hash18(_ x: Double) -> Double {
        let v = sin(x * 127.1 + 311.7) * 43758.5453
        return (v - floor(v)) * 2 - 1
    }

    static let shakePro18 = EffectDefinition(
        id: "awi18.shakePro", name: "Shake Pro", category: .motion,
        aeMatchNames: [],
        summary: "Every kind of edit shake in one: smooth wiggle, twitchy jumps, handheld camera, earthquake, impact hits and vibration. Choppy hold frames for anime shakes, direction lock and fade-out. Motion blur turns on by itself.",
        params: [
            .choice("mode", "Shake Type", ["Smooth (Wiggle)", "Twitch (Jumps)", "Handheld Camera", "Earthquake", "Impact Hits", "Vibrate"], 0),
            .number("amount", "Position Amount", 40, 0, 600, unit: "px"),
            .number("rotation", "Rotation Amount", 4, 0, 90, unit: "°"),
            .number("zoom", "Zoom Amount", 0, 0, 60, unit: "%"),
            .number("speed", "Speed", 10, 0.5, 40, step: 0.1, unit: "/s"),
            .number("hold", "Hold Frames (choppy)", 0, 0, 12, step: 1),
            .choice("direction", "Direction", ["Both", "Horizontal Only", "Vertical Only"], 0),
            .number("fade", "Fade Out", 0, 0, 10, step: 0.1, unit: "/s"),
            .number("seed", "Random Seed", 1, 0, 1000, step: 1),
        ],
        stage: .transform { e, raw in
            let t = held(raw, e.number("hold", raw))
            let f = e.number("speed", raw), seed = e.number("seed", raw)
            let env = exp(-max(0, e.number("fade", raw)) * max(0, raw))
            var x = 0.0, y = 0.0, r = 0.0, z = 0.0
            switch e.choice("mode") {
            case 1:
                // Twitch: random jumps (no easing), occasional bigger kicks.
                let slot = (t * f).rounded(.down)
                let kick = hash18(slot * 0.37 + seed) > 0.6 ? 1.8 : 1
                x = hash18(slot + seed * 7.1) * kick; y = hash18(slot * 1.3 + seed * 3.7) * kick
                r = hash18(slot * 2.1 + seed); z = hash18(slot * 0.7 + seed * 5.3)
            case 2:
                // Handheld: slow, layered drift with more rotation.
                x = Wiggle.value(t: t, freq: f * 0.12, octaves: 3, seed: seed * 13 + 1)
                y = Wiggle.value(t: t, freq: f * 0.1, octaves: 3, seed: seed * 13 + 2)
                r = Wiggle.value(t: t, freq: f * 0.08, octaves: 2, seed: seed * 13 + 3) * 1.5
                z = Wiggle.value(t: t, freq: f * 0.05, octaves: 2, seed: seed * 13 + 4)
            case 3:
                // Earthquake: fast, detailed, mostly vertical rumble.
                x = Wiggle.value(t: t, freq: f * 1.8, octaves: 4, seed: seed * 13 + 1) * 0.6
                y = Wiggle.value(t: t, freq: f * 2.2, octaves: 4, seed: seed * 13 + 2)
                r = Wiggle.value(t: t, freq: f * 1.4, octaves: 3, seed: seed * 13 + 3) * 0.5
                z = Wiggle.value(t: t, freq: f, octaves: 2, seed: seed * 13 + 4) * 0.5
            case 4:
                // Impact hits: a hit every (8 / speed) s that rings out fast.
                let period = 8 / max(f, 0.01)
                let ph = t.truncatingRemainder(dividingBy: period)
                let ring = exp(-ph * 9) * sin(ph * 70)
                let n = (t / period).rounded(.down)
                x = ring * hash18(n + seed); y = ring * hash18(n * 1.7 + seed)
                r = ring * hash18(n * 2.3 + seed); z = abs(ring)
            case 5:
                // Vibrate: tight, regular buzz.
                x = sin(t * f * 6 * .pi + seed) ; y = sin(t * f * 6.6 * .pi + seed * 2)
                r = sin(t * f * 5 * .pi + seed * 3) * 0.3; z = sin(t * f * 4 * .pi) * 0.3
            default:
                x = Wiggle.value(t: t, freq: f, octaves: 2, seed: seed * 13 + 1)
                y = Wiggle.value(t: t, freq: f, octaves: 2, seed: seed * 13 + 2)
                r = Wiggle.value(t: t, freq: f, octaves: 2, seed: seed * 13 + 3)
                z = Wiggle.value(t: t, freq: f, octaves: 2, seed: seed * 13 + 4)
            }
            switch e.choice("direction") {
            case 1: y = 0
            case 2: x = 0
            default: break
            }
            let a = e.number("amount", raw) * env
            return (x * a, y * a, r * e.number("rotation", raw) * env, 1 + z * e.number("zoom", raw) / 100 * env)
        })

    static let zoomPunch18 = EffectDefinition(
        id: "awi18.zoomPunch", name: "Zoom Punch", category: .motion,
        aeMatchNames: [],
        summary: "A punchy zoom hit that repeats on a beat, with a fast attack and an eased settle. Great on beat drops.",
        params: [
            .number("amount", "Punch Amount", 18, 0, 150, unit: "%"),
            .number("bpm", "Beats Per Minute", 150, 20, 300, step: 1),
            .number("decay", "Settle Speed", 5, 1, 30, step: 0.1),
            .number("spin", "Spin Kick", 0, 0, 45, unit: "°"),
            .number("offset", "Beat Offset", 0.05, 0, 2, step: 0.01, unit: "s"),
        ],
        stage: .transform { e, t in
            let period = 60 / max(e.number("bpm", t), 1)
            let ph = (t - e.number("offset", t)).truncatingRemainder(dividingBy: period)
            let p = ph < 0 ? ph + period : ph
            let env = exp(-p * e.number("decay", t))
            let beat = ((t - e.number("offset", t)) / period).rounded(.down)
            let dir = beat.truncatingRemainder(dividingBy: 2) == 0 ? 1.0 : -1.0
            return (0, 0, e.number("spin", t) * env * dir, 1 + e.number("amount", t) / 100 * env)
        })

    private static func run18(_ ctx: EffectContext, _ mode: UInt32, _ fill: (inout EffectParams) -> Void) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        ctx.gpu.run("fx18", ctx.cb, textures: [ctx.input, out, ctx.input], params: p, grid: out)
        return out
    }

    static let twitch18 = EffectDefinition(
        id: "awi18.twitch", name: "Twitch Glitch", category: .stylize,
        aeMatchNames: [],
        summary: "Random glitch bursts like the Twitch plugin: RGB split, sliced offsets, flashes and jitter blur that hit and vanish. Pair with Shake Pro (Twitch) for the full look.",
        params: [
            .number("intensity", "Intensity", 80, 0, 100, unit: "%"),
            .number("rate", "Bursts Per Second", 3.25, 0.2, 20, step: 0.05),
            .number("length", "Burst Length", 45, 2, 100, unit: "%"),
            .number("rgb", "RGB Split", 18, 0, 120, unit: "px"),
            .number("slice", "Slice Offset", 40, 0, 300, unit: "px"),
            .number("flash", "Flash", 25, 0, 100, unit: "%"),
            .number("blur", "Jitter Blur", 10, 0, 80, unit: "px"),
            .number("seed", "Random Seed", 3, 0, 1000, step: 1),
        ],
        margin: { e, t in e.number("slice", t) + e.number("rgb", t) },
        stage: .pixels { ctx in run18(ctx, 0) { p in
            p.a = SIMD4(Float(ctx.num("intensity") / 100), Float(ctx.num("rate")), Float(ctx.num("length") / 100), Float(ctx.num("seed")))
            p.b = SIMD4(Float(ctx.num("rgb") * ctx.unit), Float(ctx.num("slice") * ctx.unit), Float(ctx.num("flash") / 100), Float(ctx.num("blur") * ctx.unit))
        } })

    static let negativeFlash18 = EffectDefinition(
        id: "awi18.negativeFlash", name: "Negative Flash", category: .stylize,
        aeMatchNames: [],
        summary: "Manga-edit flicker: frames flash to negative, black & white ink, or alternate both.",
        params: [
            .choice("style", "Flash Style", ["Negative", "Mono Ink", "Alternate"], 0),
            .number("rate", "Flashes Per Second", 8, 0.5, 30, step: 0.1),
            .number("mix", "Strength", 100, 0, 100, unit: "%"),
            .number("threshold", "Ink Threshold", 50, 0, 100, unit: "%"),
        ],
        stage: .pixels { ctx in run18(ctx, 1) { p in
            p.a = SIMD4(Float(ctx.num("rate")), Float(ctx.num("mix") / 100), Float(ctx.effect.choice("style")), Float(ctx.num("threshold") / 100))
        } })

    static let warpChroma18 = EffectDefinition(
        id: "awi18.warpChroma", name: "Warp Chroma", category: .distort,
        aeMatchNames: [],
        summary: "Sapphire-style rainbow warp: edges push outward with the color channels split apart.",
        params: [
            .number("amount", "Warp Amount", 25, 0, 200, unit: "px"),
            .number("spread", "Chroma Spread", 60, 0, 100, unit: "%"),
            .angle("angle", "Warp Angle", 0),
        ],
        margin: { e, t in e.number("amount", t) * 2 },
        stage: .pixels { ctx in run18(ctx, 2) { p in
            p.a = SIMD4(Float(ctx.num("amount") * ctx.unit), Float(ctx.num("spread") / 100), Float(ctx.num("angle") * .pi / 180), 0)
        } })

    static let scanTear18 = EffectDefinition(
        id: "awi18.scanTear", name: "Scanline Tear", category: .stylize,
        aeMatchNames: [],
        summary: "A band of torn, jittering scanlines that rolls through the frame.",
        params: [
            .number("amount", "Tear Amount", 60, 0, 400, unit: "px"),
            .number("band", "Band Height", 30, 1, 100, unit: "%"),
            .number("speed", "Roll Speed", 1, 0, 10, step: 0.05),
            .number("jagged", "Line Size", 4, 1, 40, step: 1, unit: "px"),
        ],
        margin: { e, t in e.number("amount", t) },
        stage: .pixels { ctx in run18(ctx, 3) { p in
            p.a = SIMD4(Float(ctx.num("amount") * ctx.unit), Float(ctx.num("band") / 100), Float(ctx.num("speed")), Float(ctx.num("jagged") * ctx.unit))
        } })

    static let waveGlitch18 = EffectDefinition(
        id: "awi18.waveGlitch", name: "Wave Glitch", category: .stylize,
        aeMatchNames: [],
        summary: "Choppy sideways wave distortion that steps instead of flowing (digital wobble).",
        params: [
            .number("amount", "Wave Amount", 24, 0, 300, unit: "px"),
            .number("waves", "Waves", 4, 0.2, 40, step: 0.1),
            .number("speed", "Speed", 1.5, 0, 10, step: 0.05),
            .number("steps", "Steps Per Second", 12, 1, 30, step: 1),
        ],
        margin: { e, t in e.number("amount", t) },
        stage: .pixels { ctx in run18(ctx, 4) { p in
            p.a = SIMD4(Float(ctx.num("amount") * ctx.unit), Float(ctx.num("waves")), Float(ctx.num("speed")), Float(ctx.num("steps")))
        } })

    static let blockShuffle18 = EffectDefinition(
        id: "awi18.blockShuffle", name: "Block Shuffle", category: .stylize,
        aeMatchNames: [],
        summary: "Datamosh-style glitch: random blocks of the image swap places every few frames.",
        params: [
            .number("block", "Block Size", 24, 4, 200, unit: "px"),
            .number("chance", "Amount", 25, 0, 100, unit: "%"),
            .number("rate", "Changes Per Second", 12, 1, 30, step: 1),
            .number("seed", "Random Seed", 1, 0, 1000, step: 1),
        ],
        stage: .pixels { ctx in run18(ctx, 5) { p in
            p.a = SIMD4(Float(ctx.num("block") * ctx.unit), Float(ctx.num("chance") / 100), Float(ctx.num("rate")), Float(ctx.num("seed")))
        } })

    static let channelSmear18 = EffectDefinition(
        id: "awi18.channelSmear", name: "Channel Smear", category: .stylize,
        aeMatchNames: [],
        summary: "Red, green and blue streak behind the image at different lengths (speed smear with color split).",
        params: [
            .number("length", "Smear Length", 40, 0, 300, unit: "px"),
            .angle("angle", "Direction", 0),
            .number("spread", "Color Split", 60, 0, 100, unit: "%"),
        ],
        margin: { e, t in e.number("length", t) },
        stage: .pixels { ctx in run18(ctx, 6) { p in
            p.a = SIMD4(Float(ctx.num("length") * ctx.unit), Float(ctx.num("angle") * .pi / 180), Float(ctx.num("spread") / 100), 0)
        } })

    /// Pins stored in the instance: "pinR<i>" rest point and "pinD<i>" (animatable) dragged point, layer px.
    static func puppetPins(_ e: EffectInstance, _ t: Double) -> [SIMD4<Float>] {
        var out: [SIMD4<Float>] = []
        var i = 0
        while let r = e.params["pinR\(i)"], out.count < 32 {
            let rest = r.point(at: t), def = e.params["pinD\(i)"]?.point(at: t) ?? rest
            out.append(SIMD4(Float(rest.x), Float(rest.y), Float(def.x), Float(def.y)))
            i += 1
        }
        return out
    }

    static let puppet18 = EffectDefinition(
        id: "awi18.puppet", name: "Puppet Pins", category: .distort,
        aeMatchNames: [],
        summary: "AE Puppet tool: tap the layer to drop pins, drag a pin to bend the image around it (hair, capes, arms). Turn Animate on to keyframe each pose.",
        params: [
            .number("stiffness", "Stiffness", 1.2, 0.5, 3, step: 0.05),
        ],
        margin: { e, t in
            let pins = puppetPins(e, t)
            return Double(pins.map { max(abs($0.z - $0.x), abs($0.w - $0.y)) }.max() ?? 0)
        },
        stage: .pixels { ctx in
            let pins = puppetPins(ctx.effect, ctx.time)
            guard !pins.isEmpty else { return ctx.input }
            let out = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(Float(ctx.num("stiffness")), Float(ctx.unit), 0, 0)
            p.i.y = UInt32(pins.count)
            ctx.gpu.run("fxPuppet", ctx.cb, textures: [ctx.input, out], params: p, extra: pins, grid: out)
            return out
        })

    static let transformFX18 = EffectDefinition(
        id: "awi18.transform", name: "Transform (Effect)", category: .motion,
        aeMatchNames: [],
        summary: "AE's Transform effect: offset, scale and rotate inside the effect stack, on top of the layer's own keyframes (stack velocity hits and shakes without touching them). Gets motion blur from Smooth Motion.",
        params: [
            .number("x", "Position X Offset", 0, -2000, 2000, unit: "px"),
            .number("y", "Position Y Offset", 0, -2000, 2000, unit: "px"),
            .number("scale", "Scale", 100, 0, 1000, unit: "%"),
            .number("rotation", "Rotation", 0, -360, 360, unit: "°"),
        ],
        stage: .transform { e, t in (e.number("x", t), e.number("y", t), e.number("rotation", t), max(0, e.number("scale", t)) / 100) })

    /// Effects that read another layer (chosen in the effect card; stored as text["layer"]).
    static let layerRefIDs: Set<String> = ["awi18.displacementMap", "awi18.setMatte"]
    /// Effects that can use another layer's picture as their sprite (the layer itself, uncropped by position).
    static let spriteRefIDs: Set<String> = ["awi18.particles"]

    static let displacementMap18 = EffectDefinition(
        id: "awi18.displacementMap", name: "Displacement Map", category: .distort,
        aeMatchNames: [],
        summary: "Pushes this layer's pixels using another layer: mid grey stays, dark and bright push in opposite directions (glitch, heat, liquid, shattered looks from your own layers).",
        params: [
            .number("h", "Max Horizontal", 30, -500, 500, unit: "px"),
            .number("v", "Max Vertical", 0, -500, 500, unit: "px"),
            .choice("source", "Use", ["Brightness", "Red (H) / Green (V)"], 0),
        ],
        margin: { e, t in max(abs(e.number("h", t)), abs(e.number("v", t))) },
        stage: .pixels { ctx in
            guard let ref = ctx.reference else { return ctx.input }
            let out = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(Float(ctx.num("h") * ctx.unit), Float(ctx.num("v") * ctx.unit), Float(ctx.effect.choice("source")), 0)
            p.i.x = 0
            ctx.gpu.run("fxLayerRef", ctx.cb, textures: [ctx.input, out, ref], params: p, grid: out)
            return out
        })

    static let setMatte18 = EffectDefinition(
        id: "awi18.setMatte", name: "Set Matte", category: .keying,
        aeMatchNames: [],
        summary: "Uses another layer's alpha or brightness as this layer's transparency (any layer, anywhere in the stack — not just the one above).",
        params: [
            .choice("mode", "Use", ["Alpha", "Brightness"], 0),
            .toggle("invert", "Invert", false),
        ],
        stage: .pixels { ctx in
            guard let ref = ctx.reference else { return ctx.input }
            let out = ctx.temp()
            var p = EffectParams()
            p.a = SIMD4(Float(ctx.effect.choice("mode")), ctx.effect.bool("invert") ? 1 : 0, 0, 0)
            p.i.x = 1
            ctx.gpu.run("fxLayerRef", ctx.cb, textures: [ctx.input, out, ref], params: p, grid: out)
            return out
        })
}
