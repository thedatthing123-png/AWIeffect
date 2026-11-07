import Foundation
import Metal
import simd

/// Per-effect Mix %, Solo and hold keys for switches / menus, applied around every effect's own stage, so every
/// render path (layers, adjustment layers, text, export) gets them. Defaults change nothing:
/// - Mix lives in `params["fxMix"]` (0...100, keyframable); missing = 100.
/// - Solo marks the other effects of the layer with `text["soloMute"] = "1"`; the soloed one has `text["solo"] = "1"`.
/// - Hold keys of a toggle / choice live in `text["hold.<key>"]` as "time:value;time:value" (value 0/1 or the index).
enum EffectStackR4 {
    static let mixKey = "fxMix"
    static let holdPrefix = "hold."

    static func mix(_ e: EffectInstance, _ t: Double) -> Double {
        min(100, max(0, e.params[mixKey]?.number(at: t) ?? 100))
    }
    static func isMuted(_ e: EffectInstance) -> Bool { e.text?["soloMute"] == "1" }
    static func isSolo(_ e: EffectInstance) -> Bool { e.text?["solo"] == "1" }

    // MARK: Hold keys

    struct HoldKey: Equatable { var time: Double; var value: Int }

    static func holdKeys(_ e: EffectInstance, _ key: String) -> [HoldKey] {
        guard let s = e.text?[holdPrefix + key] else { return [] }
        return s.split(separator: ";").compactMap { part in
            let f = part.split(separator: ":")
            guard f.count == 2, let t = Double(f[0]), let v = Int(f[1]), t.isFinite else { return nil }
            return HoldKey(time: t, value: v)
        }
        .sorted { $0.time < $1.time }
    }

    static func encode(_ keys: [HoldKey]) -> String? {
        keys.isEmpty ? nil : keys.sorted { $0.time < $1.time }.map { "\($0.time):\($0.value)" }.joined(separator: ";")
    }

    /// The held value at `t`: the last key at or before `t` (the first key before it).
    static func heldValue(_ keys: [HoldKey], at t: Double) -> Int? {
        guard let first = keys.first else { return nil }
        return keys.last { $0.time <= t + 1e-9 }?.value ?? first.value
    }

    /// The effect with each held switch / menu set to its value at `t`; nil when it has no hold keys (fast path).
    static func resolved(_ e: EffectInstance, at t: Double) -> EffectInstance? {
        guard let text = e.text, text.keys.contains(where: { $0.hasPrefix(holdPrefix) }) else { return nil }
        var out = e
        for k in text.keys where k.hasPrefix(holdPrefix) {
            let key = String(k.dropFirst(holdPrefix.count))
            guard let v = heldValue(holdKeys(e, key), at: t) else { continue }
            let current = e.params[key] ?? EffectRegistry.rawDefinition(e.typeID)?.params.first { $0.id == key }?.defaultValue
            switch current {
            case .toggle?: out.params[key] = .toggle(v != 0)
            case .choice?: out.params[key] = .choice(v)
            default: break
            }
        }
        return out
    }

    /// Sets a hold key at `t` (replacing one at the same frame).
    static func settingHold(_ e: EffectInstance, _ key: String, value: Int, at t: Double) -> EffectInstance {
        var out = e
        var keys = holdKeys(e, key).filter { abs($0.time - t) > 1e-4 }
        keys.append(HoldKey(time: t, value: value))
        var text = e.text ?? [:]
        text[holdPrefix + key] = encode(keys)
        out.text = text
        return out
    }

    static func removingHold(_ e: EffectInstance, _ key: String, at t: Double) -> EffectInstance {
        var out = e
        var text = e.text ?? [:]
        text[holdPrefix + key] = encode(holdKeys(e, key).filter { abs($0.time - t) > 1e-4 })
        out.text = text.isEmpty ? nil : text
        return out
    }

    // MARK: Solo

    /// Solo `id` among `effects` (or clear solo when it is already soloed).
    static func toggledSolo(_ effects: [EffectInstance], _ id: UUID) -> [EffectInstance] {
        let clearing = effects.first { $0.id == id }.map(isSolo) ?? false
        return effects.map { e in
            var o = e
            var text = e.text ?? [:]
            text["solo"] = nil; text["soloMute"] = nil
            if !clearing { if e.id == id { text["solo"] = "1" } else { text["soloMute"] = "1" } }
            o.text = text.isEmpty ? nil : text
            return o
        }
    }

    // MARK: Wrapping

    static func wrap(_ d: EffectDefinition) -> EffectDefinition {
        let stage: EffectStage
        switch d.stage {
        case .pixels(let run):
            stage = .pixels { ctx in
                if isMuted(ctx.effect) { return ctx.input }
                var c = ctx
                if let r = resolved(ctx.effect, at: ctx.time) {
                    c = EffectContext(gpu: ctx.gpu, cb: ctx.cb, input: ctx.input, effect: r, time: ctx.time, unit: ctx.unit, pool: ctx.pool,
                                      reference: ctx.reference, layerPixels: ctx.layerPixels, compositionPixels: ctx.compositionPixels)
                }
                let out = run(c)
                let m = mix(ctx.effect, ctx.time)
                guard m < 99.999, out !== ctx.input, out.width == ctx.input.width, out.height == ctx.input.height else { return out }
                let dst = ctx.temp()
                var p = EffectParams()
                p.a = SIMD4(Float(m / 100), 0, 0, 0)
                ctx.gpu.run("fxMixR4", ctx.cb, textures: [ctx.input, out, dst], params: p, grid: dst)
                return dst
            }
        case .transform(let f):
            stage = .transform { e, t in
                if isMuted(e) { return (0, 0, 0, 1) }
                let r = f(resolved(e, at: t) ?? e, t)
                let m = mix(e, t) / 100
                guard m < 0.99999 else { return r }
                return (r.0 * m, r.1 * m, r.2 * m, 1 + (r.3 - 1) * m)
            }
        }
        return EffectDefinition(id: d.id, name: d.name, category: d.category, aeMatchNames: d.aeMatchNames, summary: d.summary,
                                params: d.params, margin: d.margin, expandedMargin: d.expandedMargin, stage: stage)
    }
}

extension EffectRegistry {
    /// The definition without the R4 wrapping (for its parameter list).
    static func rawDefinition(_ id: String) -> EffectDefinition? { all.first { $0.id == id } }

    static let batchR4: [EffectDefinition] = [gradientR4]

    /// Linear / radial gradient: the Fill panel's gradient fill and gradient overlay (colors, angle, center,
    /// all keyframable). Painted inside the layer's own shape (its alpha).
    static let gradientR4 = EffectDefinition(
        id: "awiR4.gradient", name: "Gradient Fill", category: .generate, aeMatchNames: [],
        summary: "Linear or radial gradient painted inside the layer's shape, as a fill or an overlay with a blend mode.",
        params: [
            .choice("type", "Type", ["Linear", "Radial"], 0),
            .color("color1", "Start Color", RGBA(hex: 0x9B5CFF)),
            .color("color2", "End Color", RGBA(hex: 0x3FD6C6)),
            .angle("angle", "Angle", 90),
            .point("center", "Center", Vec2(0.5, 0.5)),
            .number("scale", "Scale", 100, 5, 400, unit: "%"),
            .number("opacity", "Opacity", 100, 0, 100, unit: "%"),
            .choice("blend", "Blend", ["Normal", "Multiply", "Screen", "Overlay", "Soft Light", "Color"], 0),
        ],
        stage: .pixels { ctx in
            let out = ctx.temp()
            var p = EffectParams()
            let c = ctx.effect.point("center", ctx.time)
            let a = ctx.effect.number("angle", ctx.time) * .pi / 180
            p.a = SIMD4(Float(c.x), Float(c.y), Float(cos(a)), Float(sin(a)))
            p.b = ctx.effect.color("color1", ctx.time).simd
            p.c = ctx.effect.color("color2", ctx.time).simd
            p.d = SIMD4(Float(ctx.num("scale") / 100), Float(ctx.num("opacity") / 100), 0, 0)
            // Painted over the layer's own pixels (not the grown effect margin).
            let lp = ctx.layerPixels ?? SIMD2(Double(ctx.width), Double(ctx.height))
            p.d.z = Float(lp.x); p.d.w = Float(lp.y)
            p.i = SIMD4(UInt32(max(0, ctx.effect.choice("type"))), UInt32(max(0, ctx.effect.choice("blend"))), 0, 0)
            ctx.gpu.run("fxGradientR4", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
            return out
        })
}
