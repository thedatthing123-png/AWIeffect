import SwiftUI

/// Shared CC Studio helpers.
@MainActor
enum CCLive {
    /// The grade as it is right now (the live copy mid-drag), so handles follow the finger.
    static func grade(_ state: EditorState, _ e: EffectInstance) -> EffectInstance {
        guard let id = state.selectedLayerID,
              let l = (state.live.project ?? state.project).layers.first(where: { $0.id == id }) else { return e }
        return l.effects.first { $0.id == e.id } ?? e
    }

    static func set(_ state: EditorState, _ e: EffectInstance, _ key: String, _ v: Double) {
        state.setEffectParam(e.id, key) { pv, time in if case .number(var a) = pv { a.set(v, at: time); pv = .number(a) } }
    }

    static func setFlag(_ state: EditorState, _ e: EffectInstance, _ key: String, _ b: Bool) {
        state.setEffectParam(e.id, key) { pv, _ in pv = .toggle(b) }
    }

    /// Keyframe several controls as one (a wheel = its R, G, B and luminance): one undo step.
    static func toggleKeyframes(_ state: EditorState, _ e: EffectInstance, _ keys: [String]) {
        let t = state.currentTime
        let target = !keys.contains { state.effectParamHasKeyframe(e.id, $0).filled }
        state.beginEdit("Keyframe")
        for k in keys {
            state.setEffectParam(e.id, k) { v, time in
                if case .number(var a) = v, a.hasKeyframe(at: t) != target { a.toggleKeyframe(at: time); v = .number(a) }
            }
        }
        state.endEdit()
    }

    static func keyState(_ state: EditorState, _ e: EffectInstance, _ keys: [String]) -> (filled: Bool, animated: Bool) {
        let s = keys.map { state.effectParamHasKeyframe(e.id, $0) }
        return (s.contains { $0.filled }, s.contains { $0.animated })
    }
}

/// A color wheel: drag the puck to push the color balance (R / G / B of the wheel, keeping its brightness), drag
/// around the outer ring to change the wheel's luminance. Movement is scaled down for precision.
struct CCColorWheel: View {
    @ObservedObject var state: EditorState
    let effect: EffectInstance
    let title: String
    /// "lift", "gamma", "gain" or "off".
    let prefix: String

    @State private var base: (x: Double, y: Double, mean: Double, lum: Double)?
    @State private var ringMode = false
    @State private var lastAngle: Double = 0

    private var lumKey: String { prefix + "Y" }
    private var keys: [String] { [prefix + "R", prefix + "G", prefix + "B", lumKey] }

    var body: some View {
        let g = CCLive.grade(state, effect), t = state.currentTime
        let r = GradeR4.num(g, prefix + "R", t), gg = GradeR4.num(g, prefix + "G", t), b = GradeR4.num(g, prefix + "B", t)
        let puck = GradeR4.puck(r: r, g: gg, b: b), lum = GradeR4.num(g, lumKey, t)
        let ks = CCLive.keyState(state, effect, keys)
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                KeyframeDiamond(filled: ks.filled, animated: ks.animated) { CCLive.toggleKeyframes(state, effect, keys) }
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    state.beginEdit("Reset \(title)")
                    let mean = (r + gg + b) / 3
                    for k in ["R", "G", "B"] { CCLive.set(state, effect, prefix + k, mean) }
                    state.endEdit()
                } label: {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 12, weight: .semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Theme.textDim)
                .accessibilityLabel("Reset \(title) balance")
            }
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let R = size / 2, inner = R * 0.82
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    // Luminance ring: its marker turns with the value (one turn = 100).
                    Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: R - inner)
                        .frame(width: size, height: size)
                    Circle().trim(from: 0, to: 0.06)
                        .stroke(Theme.accentGlow, style: StrokeStyle(lineWidth: R - inner - 4, lineCap: .round))
                        .frame(width: size - (R - inner), height: size - (R - inner))
                        .rotationEffect(.degrees(-90 - 10.8 + lum / 100 * 360))
                    Circle()
                        .fill(AngularGradient(colors: (0...12).map { Color(hue: 1 - Double($0) / 12, saturation: 0.75, brightness: 0.85) }, center: .center))
                        .overlay(Circle().fill(RadialGradient(colors: [Color(white: 0.5), Color(white: 0.5).opacity(0)], center: .center, startRadius: 0, endRadius: inner)))
                        .frame(width: inner * 2, height: inner * 2)
                    Path { p in
                        p.move(to: CGPoint(x: center.x - 6, y: center.y)); p.addLine(to: CGPoint(x: center.x + 6, y: center.y))
                        p.move(to: CGPoint(x: center.x, y: center.y - 6)); p.addLine(to: CGPoint(x: center.x, y: center.y + 6))
                    }
                    .stroke(Color.black.opacity(0.45), lineWidth: 1)
                    Circle().strokeBorder(.white, lineWidth: 2).background(Circle().fill(Color.black.opacity(0.25)))
                        .frame(width: 18, height: 18)
                        .position(x: center.x + CGFloat(puck.x / 100) * inner, y: center.y - CGFloat(puck.y / 100) * inner)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Circle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let live = CCLive.grade(state, effect), now = state.currentTime
                        let cr = GradeR4.num(live, prefix + "R", now), cg = GradeR4.num(live, prefix + "G", now), cb = GradeR4.num(live, prefix + "B", now)
                        if base == nil {
                            let d = hypot(v.startLocation.x - center.x, v.startLocation.y - center.y)
                            ringMode = d > inner
                            lastAngle = atan2(Double(v.startLocation.y - center.y), Double(v.startLocation.x - center.x))
                            let pk = GradeR4.puck(r: cr, g: cg, b: cb)
                            base = (pk.x, pk.y, (cr + cg + cb) / 3, GradeR4.num(live, lumKey, now))
                            state.beginEdit(title)
                        }
                        guard let b0 = base else { return }
                        if ringMode {
                            let a = atan2(Double(v.location.y - center.y), Double(v.location.x - center.x))
                            var da = a - lastAngle
                            if da > .pi { da -= 2 * .pi } else if da < -.pi { da += 2 * .pi }
                            lastAngle = a
                            let cur = GradeR4.num(live, lumKey, now)
                            CCLive.set(state, effect, lumKey, min(100, max(-100, cur + da / (2 * .pi) * 100)))
                        } else {
                            // Half speed: a full finger sweep across the wheel moves the puck half way.
                            var x = b0.x + Double(v.translation.width / max(inner, 1)) * 50
                            var y = b0.y - Double(v.translation.height / max(inner, 1)) * 50
                            let m = hypot(x, y)
                            if m > 100 { x *= 100 / m; y *= 100 / m }
                            let c = GradeR4.rgb(puckX: x, y: y, mean: b0.mean)
                            CCLive.set(state, effect, prefix + "R", min(100, max(-100, c.r)))
                            CCLive.set(state, effect, prefix + "G", min(100, max(-100, c.g)))
                            CCLive.set(state, effect, prefix + "B", min(100, max(-100, c.b)))
                        }
                    }
                    .onEnded { _ in base = nil; state.endEdit() })
                .accessibilityLabel("\(title) wheel")
            }
            .frame(height: 140)
            HStack(spacing: 4) {
                Text("Lum").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textDim).frame(width: 30, alignment: .leading)
                ValueScrubber(value: lum, range: -100...100, step: 0,
                              onBegin: { state.beginEdit("\(title) Luminance") },
                              onChange: { CCLive.set(state, effect, lumKey, $0) },
                              onEnd: { state.endEdit() })
            }
        }
        .padding(8).glass(radius: 12)
    }
}
