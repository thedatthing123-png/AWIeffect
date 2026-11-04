import Foundation
import Metal

extension EffectRegistry {
    static func printScreen(_ ctx: EffectContext, lines: Bool) -> MTLTexture {
        let out = ctx.temp(), rect = layerRect(ctx)
        let definition = EffectRegistry.definition(ctx.effect.typeID)
        func number(_ key: String) -> Double {
            if ctx.effect.params[key] != nil { return ctx.num(key) }
            return definition?.params.first(where: { $0.id == key })?.defaultValue.number(at: ctx.time) ?? 0
        }
        func color(_ key: String) -> RGBA {
            ctx.effect.params[key]?.color(at: ctx.time) ?? definition?.params.first(where: { $0.id == key })?.defaultValue.color(at: ctx.time) ?? .white
        }
        var p = EffectParams()
        p.i.x = lines ? 1 : 0
        p.a = SIMD4(Float(max(0.001, number("amount")) / (ctx.compositionPixels?.x ?? Double(ctx.width))),
                    Float(number("strength") / 100), Float(number("phase")), Float(number("angle") * .pi / 180))
        if lines {
            let ink = color("ink"), paper = color("paper")
            p.b = SIMD4(Float(ink.r), Float(ink.g), Float(ink.b), Float(ink.a))
            p.c = SIMD4(Float(paper.r), Float(paper.g), Float(paper.b), Float(paper.a))
        }
        p.d = SIMD4(Float(number("blackWeight") / 100), lines ? 1 : Float(number("mix") / 100), rect.x + rect.z / 2, rect.y + rect.w / 2)
        ctx.gpu.run("fxPrintScreens", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
        return out
    }
}
