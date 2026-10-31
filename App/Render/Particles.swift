import Foundation
import Metal
import simd

/// Must match ParticleUniforms in Particles.metal.
struct ParticleUniforms {
    var emit: SIMD4<Float>, life: SIMD4<Float>, motion: SIMD4<Float>, forces: SIMD4<Float>
    var look: SIMD4<Float>, fade: SIMD4<Float>, colorA: SIMD4<Float>, colorB: SIMD4<Float>
    var view: SIMD4<Float>, mode: SIMD4<UInt32>
}

/// Render pipelines for the particle system (additive glow / normal blending).
final class ParticleGPU {
    static let shared = ParticleGPU()
    private(set) var additive: MTLRenderPipelineState?
    private(set) var normal: MTLRenderPipelineState?

    private init() {
        guard let device = Renderer.shared?.device, let lib = device.makeDefaultLibrary() else { return }
        func make(add: Bool) -> MTLRenderPipelineState? {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = lib.makeFunction(name: "particleVertex")
            d.fragmentFunction = lib.makeFunction(name: "particleFragment")
            let c = d.colorAttachments[0]!
            c.pixelFormat = .rgba16Float
            c.isBlendingEnabled = true
            c.rgbBlendOperation = .add; c.alphaBlendOperation = .add
            c.sourceRGBBlendFactor = .one; c.sourceAlphaBlendFactor = .one
            c.destinationRGBBlendFactor = add ? .one : .oneMinusSourceAlpha
            c.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: d)
        }
        additive = make(add: true)
        normal = make(add: false)
    }
}

extension EffectRegistry {
    static let particleSprites = ["Soft Glow", "Dot", "Spark (streaks)", "Star", "Shard", "Ring", "Custom Layer"]

    static let particles18 = EffectDefinition(
        id: "awi18.particles", name: "Particle System", category: .generate,
        aeMatchNames: [],
        summary: "Full particle system (Particular-style): emitters, speed / spread, gravity, wind, turbulence, size and color over life, 3D depth, spin, sprites (glow, spark streaks, stars, shards…) or your own layer as the particle.",
        params: [
            .choice("emitter", "Emitter", ["Point", "Box", "Line", "Ring"], 0),
            .number("emitX", "Emitter X", 0, -100, 100, unit: "%"),
            .number("emitY", "Emitter Y", 0, -100, 100, unit: "%"),
            .number("emitW", "Emitter Width", 200, 0, 4000, unit: "px"),
            .number("emitH", "Emitter Height", 200, 0, 4000, unit: "px"),
            .number("rate", "Particles / s", 80, 1, 2000, step: 1),
            .number("life", "Life", 2, 0.1, 10, step: 0.05, unit: "s"),
            .number("lifeRandom", "Life Random", 40, 0, 100, unit: "%"),
            .number("speed", "Speed", 300, 0, 3000, unit: "px/s"),
            .number("speedRandom", "Speed Random", 50, 0, 100, unit: "%"),
            .angle("direction", "Direction", -90),
            .number("spread", "Spread", 90, 0, 360, unit: "°"),
            .number("gravity", "Gravity", 200, -3000, 3000, unit: "px/s²"),
            .number("wind", "Wind", 0, -3000, 3000, unit: "px/s²"),
            .number("turbulence", "Turbulence", 80, 0, 1000, unit: "px"),
            .number("turbScale", "Turbulence Scale", 150, 10, 2000, unit: "px"),
            .number("size", "Size", 24, 1, 400, unit: "px"),
            .number("sizeRandom", "Size Random", 50, 0, 100, unit: "%"),
            .number("sizeEnd", "Size at Death", 30, 0, 300, unit: "%"),
            .number("opacity", "Opacity", 100, 0, 100, unit: "%"),
            .number("fadeIn", "Fade In", 10, 0, 100, unit: "%"),
            .number("fadeOut", "Fade Out", 40, 0, 100, unit: "%"),
            .number("spin", "Spin", 90, -1440, 1440, unit: "°/s"),
            .number("spinRandom", "Spin Random", 60, 0, 100, unit: "%"),
            .number("depth", "3D Depth", 600, 0, 4000, unit: "px"),
            .color("colorA", "Color at Birth", RGBA(hex: 0xFFE3A3)),
            .color("colorB", "Color at Death", RGBA(hex: 0xFF4D6D)),
            .choice("sprite", "Particle", particleSprites, 3),
            .choice("blend", "Blend", ["Add (glow)", "Normal"], 0),
            .number("seed", "Random Seed", 1, 0, 1000, step: 1),
        ],
        stage: .pixels { ctx in
            guard let pso = ctx.effect.choice("blend") == 0 ? ParticleGPU.shared.additive : ParticleGPU.shared.normal else { return ctx.input }
            let out = ctx.temp()
            // Start from the layer itself, then draw particles over it.
            if let bl = ctx.cb.makeBlitCommandEncoder() { bl.copy(from: ctx.input, to: out); bl.endEncoding() }
            let u = ctx.unit
            let rate = ctx.num("rate"), life = ctx.num("life")
            // Pixel budget: big particles draw fewer at once, so a frame can never flood the GPU.
            let sizePx = max(1, ctx.num("size") * u * (ctx.effect.choice("sprite") == 2 ? 3 : 1))
            let budget = max(2_000_000, 6 * Double(ctx.width * ctx.height))
            let byBudget = max(1, budget / (sizePx * sizePx))
            let count = UInt32(min(20000, byBudget, max(1, (rate * life).rounded(.up))))
            let ca = ctx.effect.color("colorA", ctx.time), cb = ctx.effect.color("colorB", ctx.time)
            let dir = ctx.effect.number("direction", ctx.time) * .pi / 180
            var uni = ParticleUniforms(
                emit: SIMD4(Float(Double(ctx.width) / 2 * (1 + ctx.num("emitX") / 100)), Float(Double(ctx.height) / 2 * (1 + ctx.num("emitY") / 100)),
                            Float(ctx.num("emitW") * u), Float(ctx.num("emitH") * u)),
                life: SIMD4(Float(rate), Float(life), Float(ctx.num("lifeRandom") / 100), Float(ctx.time)),
                motion: SIMD4(Float(ctx.num("speed") * u), Float(ctx.num("speedRandom") / 100), Float(dir), Float(ctx.num("spread") * .pi / 180)),
                forces: SIMD4(Float(ctx.num("gravity") * u), Float(ctx.num("wind") * u), Float(ctx.num("turbulence") * u), Float(ctx.num("turbScale") * u)),
                look: SIMD4(Float(ctx.num("size") * u), Float(ctx.num("sizeRandom") / 100), Float(ctx.num("sizeEnd") / 100), Float(ctx.num("opacity") / 100)),
                fade: SIMD4(Float(ctx.num("fadeIn") / 100), Float(ctx.num("fadeOut") / 100), Float(ctx.num("spin") * .pi / 180), Float(ctx.num("spinRandom") / 100)),
                colorA: SIMD4(Float(ca.r), Float(ca.g), Float(ca.b), Float(ca.a)),
                colorB: SIMD4(Float(cb.r), Float(cb.g), Float(cb.b), Float(cb.a)),
                view: SIMD4(Float(ctx.num("depth") * u), Float(1000 * u), Float(ctx.width), Float(ctx.height)),
                mode: SIMD4(UInt32(ctx.effect.choice("emitter")), UInt32(ctx.effect.choice("sprite")), count, UInt32(max(0, ctx.num("seed")))))
            let rp = MTLRenderPassDescriptor()
            rp.colorAttachments[0].texture = out
            rp.colorAttachments[0].loadAction = .load
            rp.colorAttachments[0].storeAction = .store
            guard let enc = ctx.cb.makeRenderCommandEncoder(descriptor: rp) else { return ctx.input }
            enc.setRenderPipelineState(pso)
            enc.setVertexBytes(&uni, length: MemoryLayout<ParticleUniforms>.stride, index: 0)
            enc.setFragmentTexture(ctx.reference ?? ctx.input, index: 0)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: Int(count))
            enc.endEncoding()
            return out
        })
}


extension EditorState {
    /// A transparent full-frame layer carrying a Particle System (emitter in the middle of the frame).
    func addParticleLayer() {
        mutate("Add Particles") { p in
            var l = p.makeLayer(name: "Particles", content: .solid, size: Vec2(Double(p.width), Double(p.height)))
            l.fill = Animated(RGBA(0, 0, 0, 0))
            l.effects = [EffectRegistry.particles18.makeInstance()]
            l.tag = .pink
            l.outPoint = p.duration
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .effects
    }
}
