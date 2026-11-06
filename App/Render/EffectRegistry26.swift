import Foundation
import Metal
import simd

/// Batch 26: shake & blur remake. Shared helpers for the remade blurs (fxBlur26 in Effects26.metal) and the
/// Shake Pro motion engine. Each effect keeps its own id and settings, so saved projects open with the new look.
extension EffectRegistry {
    /// One pass of fxBlur26. Textures: src, out, aux, mask, extra (unused slots fall back to the source).
    static func blur26(_ ctx: EffectContext, _ mode: UInt32, src: MTLTexture? = nil, aux: MTLTexture? = nil,
                       mask: MTLTexture? = nil, extra: MTLTexture? = nil, _ fill: (inout EffectParams) -> Void = { _ in }) -> MTLTexture {
        let out = ctx.temp()
        var p = EffectParams()
        fill(&p)
        p.i.x = mode
        p.d.x = Float(ctx.time)
        let s = src ?? ctx.input
        ctx.gpu.run("fxBlur26", ctx.cb, textures: [s, out, aux ?? s, mask ?? s, extra ?? s], params: p, grid: out)
        return out
    }

    /// Point param in layer pixels.
    static func pt26(_ ctx: EffectContext, _ key: String) -> SIMD2<Float> {
        let v = ctx.effect.point(key, ctx.time)
        return SIMD2(Float(v.x * Double(ctx.width)), Float(v.y * Double(ctx.height)))
    }

    // MARK: Shake engine

    private static func hash26(_ x: Double) -> Double {
        let v = sin(x * 127.1 + 311.7) * 43758.5453
        return (v - floor(v)) * 2 - 1
    }

    /// Normalized shake offsets (x, y, rotation, zoom), each roughly in [-1, 1], for Shake Pro's types.
    /// - t: time already quantized for hold frames; f: speed (/s); seed: random seed.
    static func shake26(mode: Int, t: Double, f: Double, seed: Double) -> (Double, Double, Double, Double) {
        switch mode {
        case 1:
            // Twitch: snaps to a new random pose every 1/f s with a one-frame ease-out (no linear slide),
            // then holds; about one pose in four is a bigger kick.
            let rate = max(f, 0.01)
            let slot = (t * rate).rounded(.down)
            let ph = t * rate - slot
            let snap = min(1, ph / 0.18)
            let e = 1 - (1 - snap) * (1 - snap) * (1 - snap)
            func pose(_ s: Double, _ k: Double) -> Double {
                let kick = hash26(s * 0.37 + seed * 1.9) > 0.5 ? 1.7 : 0.8
                return hash26(s * (1.3 + k) + seed * (3.7 + k)) * kick
            }
            func axis(_ k: Double) -> Double { pose(slot - 1, k) + (pose(slot, k) - pose(slot - 1, k)) * e }
            return (axis(0), axis(1), axis(2), axis(3))
        case 2:
            // Handheld: slow layered drift; roll follows the sideways sway like a real operator.
            let x = Wiggle.value(t: t, freq: f * 0.12, octaves: 3, seed: seed * 13 + 1)
            let y = Wiggle.value(t: t, freq: f * 0.1, octaves: 3, seed: seed * 13 + 2)
            let r = Wiggle.value(t: t, freq: f * 0.08, octaves: 2, seed: seed * 13 + 3) * 1.1 + x * 0.4
            let z = Wiggle.value(t: t, freq: f * 0.05, octaves: 2, seed: seed * 13 + 4)
            return (x, y, r, z)
        case 3:
            // Earthquake: a heavy low heave plus fast detailed rumble, mostly vertical, with surges.
            let surge = 0.65 + 0.35 * Wiggle.value(t: t, freq: max(f * 0.08, 0.05), octaves: 1, seed: seed * 13 + 9)
            let heaveY = Wiggle.value(t: t, freq: f * 0.35, octaves: 2, seed: seed * 13 + 5)
            let heaveX = Wiggle.value(t: t, freq: f * 0.3, octaves: 2, seed: seed * 13 + 6)
            let rumY = Wiggle.value(t: t, freq: f * 2.4, octaves: 4, ampMult: 0.6, seed: seed * 13 + 2)
            let rumX = Wiggle.value(t: t, freq: f * 2.0, octaves: 4, ampMult: 0.6, seed: seed * 13 + 1)
            let x = (heaveX * 0.35 + rumX * 0.4) * surge
            let y = (heaveY * 0.55 + rumY * 0.6) * surge
            let r = Wiggle.value(t: t, freq: f * 1.4, octaves: 3, seed: seed * 13 + 3) * 0.45 * surge
            let z = abs(rumY) * 0.5 * surge
            return (x, y, r, z)
        case 4:
            // Impact: each hit kicks the layer in a random direction and rings out as an underdamped spring
            // (decays to rest before the next hit). Rotation rings slightly later; zoom punches and settles.
            let period = 8 / max(f, 0.01)
            let n = (t / period).rounded(.down)
            let ph = t - n * period
            let omega = 2 * Double.pi * min(18, max(5, 3.2 / period))
            let zeta = 0.22
            let wd = omega * sqrt(1 - zeta * zeta)
            let env = exp(-zeta * omega * ph)
            let ring = env * cos(wd * ph)
            let ringLag = env * cos(wd * ph - 0.9)
            let ang = hash26(n * 1.7 + seed) * .pi
            return (ring * cos(ang), ring * sin(ang), ringLag * hash26(n * 2.3 + seed), exp(-ph * omega * 0.35))
        case 5:
            let x = sin(t * f * 6 * .pi + seed), y = sin(t * f * 6.6 * .pi + seed * 2)
            return (x, y, sin(t * f * 5 * .pi + seed * 3) * 0.3, sin(t * f * 4 * .pi) * 0.3)
        default:
            // Smooth wiggle (tension): independent fractal noise per axis.
            return (Wiggle.value(t: t, freq: f, octaves: 2, seed: seed * 13 + 1),
                    Wiggle.value(t: t, freq: f, octaves: 2, seed: seed * 13 + 2),
                    Wiggle.value(t: t, freq: f, octaves: 2, seed: seed * 13 + 3),
                    Wiggle.value(t: t, freq: f, octaves: 2, seed: seed * 13 + 4))
        }
    }

    /// Ease-in envelope (smoothstep over `dur` seconds); 1 when dur is ~0.
    static func easeIn26(_ t: Double, _ dur: Double) -> Double {
        guard dur > 0.001 else { return 1 }
        let x = min(1, max(0, t / dur))
        return x * x * (3 - 2 * x)
    }

    // MARK: Blur pipelines

    static func cameraShakeBlur26(_ ctx: EffectContext) -> MTLTexture {
        blur26(ctx, 0) { p in
            p.a = SIMD4(Float(ctx.num("amplitude") * ctx.unit), Float(ctx.num("shutter") / 100), Float(ctx.num("speed")),
                        Float(ctx.num("roll") * .pi / 180))
            p.b.x = Float(ctx.num("seed"))
        }
    }

    static func edgeBlur26(_ ctx: EffectContext) -> MTLTexture {
        let field = blur26(ctx, 4) { p in p.a = SIMD4(Float(ctx.num("width") * ctx.unit), Float(ctx.num("threshold") / 100), 0, 0) }
        // Spread the edge zone (and smooth its direction) so the blur covers both sides of each edge.
        let soft = ctx.gpu.gaussian(ctx, input: field, sigma: max(0.5, ctx.num("radius") * ctx.unit / 2))
        return blur26(ctx, 5, aux: soft) { p in p.a = SIMD4(Float(ctx.num("radius") * ctx.unit), Float(ctx.num("amount") / 100), 0, 0) }
    }

    static func lumaMaskBlur26(_ ctx: EffectContext) -> MTLTexture {
        let inv: UInt32 = ctx.effect.bool("invert") ? 1 : 0
        let th = Float(ctx.num("threshold") / 100), soft = Float(ctx.num("softness") / 100)
        let masked = blur26(ctx, 6) { p in p.a = SIMD4(th, soft, 0, 0); p.i.y = inv }
        let b = ctx.gpu.gaussian(ctx, input: masked, sigma: max(0.3, ctx.num("radius") * ctx.unit / 2))
        return blur26(ctx, 7, aux: b) { p in p.a = SIMD4(th, soft, 1, 0); p.i.y = inv }
    }

    static func frostedGlass26(_ ctx: EffectContext) -> MTLTexture {
        let soft = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: max(0.3, ctx.num("amount") * ctx.unit * 0.3))
        return blur26(ctx, 8, aux: soft) { p in
            p.a = SIMD4(Float(ctx.num("amount") * ctx.unit), Float(ctx.num("grain") * ctx.unit), Float(ctx.num("haze") / 100), 0)
        }
    }

    static func tiltShift26(_ ctx: EffectContext) -> MTLTexture {
        let sigma = ctx.num("blur") * ctx.unit / 2
        let b1 = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: sigma * 0.25)
        let b2 = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: sigma * 0.55)
        let b3 = ctx.gpu.gaussian(ctx, input: ctx.input, sigma: sigma)
        let h = Double(ctx.height)
        return blur26(ctx, 9, aux: b1, mask: b2, extra: b3) { p in
            let c = pt26(ctx, "center")
            p.a = SIMD4(c.x, c.y, Float(ctx.num("width") / 100 * h * 0.5), Float(ctx.num("falloff") / 100 * h * 0.5))
            p.b = SIMD4(Float(ctx.num("angle") * .pi / 180), Float(ctx.num("saturation") / 100), 0, 0)
        }
    }

    static func lensBlur26(_ ctx: EffectContext) -> MTLTexture {
        let radius = ctx.num("radius") * ctx.unit
        // Projects saved before the threshold control existed keep a highlights-only boost.
        let threshold = ctx.effect.params["threshold"] == nil ? 70 : ctx.num("threshold")
        let lin = blur26(ctx, 10) { p in p.a = SIMD4(Float(ctx.num("boost")), Float(threshold / 100), 0, 0) }
        // Slight prefilter so small highlights fill the ring taps (solid discs, no dotted rings).
        let rings = min(9, max(2, (radius / 5).rounded(.up)))
        let pre = ctx.gpu.gaussian(ctx, input: lin, sigma: max(0.3, radius / rings * 0.45))
        let blades: [Float] = [0, 5, 6, 8]
        let bl = blades[min(max(ctx.effect.choice("blades"), 0), blades.count - 1)]
        return blur26(ctx, 11, src: pre) { p in
            p.a = SIMD4(Float(radius), Float(ctx.num("rotation") * .pi / 180), bl, Float(ctx.num("rim") / 100))
        }
    }
}
