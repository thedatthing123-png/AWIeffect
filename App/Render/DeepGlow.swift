import Foundation
import Metal

enum DeepGlow {
    /// A normalized mixture of logarithmically spaced Gaussian scales approximates a
    /// long-tailed light kernel. Wide scales use smaller grids, never six full-size blurs.
    static func render(_ ctx: EffectContext) -> MTLTexture {
        func number(_ key: String, _ fallback: Double) -> Double { ctx.effect.params[key] == nil ? fallback : ctx.num(key) }
        let mix = number("mix", 100) / 100
        guard mix > 0 else { return ctx.input }
        let cap = [256.0, 512, 1024][min(2, max(0, ctx.effect.choice("quality")))]
        let down = max(1, Double(max(ctx.width, ctx.height)) / cap)
        let width = max(1, Int((Double(ctx.width) / down).rounded()))
        let height = max(1, Int((Double(ctx.height) / down).rounded()))
        let prepared = ctx.pool.acquire(width: width, height: height)
        var source = EffectParams()
        source.a = SIMD4(Float(ctx.num("threshold") / 100), Float(max(0.001, number("softness", 8) / 100)), ctx.effect.bool("gamma") ? 1 : 0, 0)
        ctx.gpu.run("fxDeepSource", ctx.cb, textures: [ctx.input, prepared], params: source, grid: prepared)
        let buffers = [ctx.pool.acquire(width: width, height: height), ctx.pool.acquire(width: width, height: height)]
        ctx.gpu.run("fxClear", ctx.cb, textures: [buffers[0]], grid: buffers[0])
        let falloff = number("falloff", 1)
        let weights = (0..<6).map { pow(0.75, Double($0) * falloff) }
        let total = weights.reduce(0, +)
        var index = 0
        let radius = ctx.num("radius") * ctx.unit / down
        for k in 0..<6 {
            let sigma = max(0.2, radius / pow(2, Double(5 - k)) / 2)
            let levelDown = max(1, sigma / 3)
            var input = prepared
            if levelDown > 1.01 {
                input = ctx.pool.acquire(width: max(1, Int(Double(width) / levelDown)), height: max(1, Int(Double(height) / levelDown)))
                ctx.gpu.run("fxResample", ctx.cb, textures: [prepared, input], grid: input)
            }
            let blurred = ctx.gpu.gaussian(ctx, input: input, sigma: sigma / levelDown)
            let output = buffers[1 - index]
            var params = EffectParams(); params.a.x = Float(weights[k] / total)
            ctx.gpu.run("fxDeepAccumulate", ctx.cb, textures: [buffers[index], output, blurred], params: params, grid: output)
            index = 1 - index
        }
        var glow = buffers[index]
        let aberration = ctx.num("aberration") * ctx.unit / down
        if aberration > 0.01 {
            let split = ctx.pool.acquire(width: width, height: height)
            var params = EffectParams(); params.a.x = Float(aberration)
            ctx.gpu.run("fxRGBSplit", ctx.cb, textures: [glow, split], params: params, grid: split)
            glow = split
        }
        let output = ctx.temp()
        var params = EffectParams()
        params.a = SIMD4(Float(pow(2, ctx.num("exposure")) * 1.5), Float(ctx.num("saturation") / 100), ctx.effect.bool("gamma") ? 1 : 0, Float(mix))
        params.b = ctx.effect.color("tint", ctx.time).simd
        params.i.x = ctx.effect.bool("glowOnly") ? 1 : 0
        ctx.gpu.run("fxDeepComposite", ctx.cb, textures: [ctx.input, output, glow], params: params, grid: output)
        return output
    }
}
