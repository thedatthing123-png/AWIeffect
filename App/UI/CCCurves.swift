import SwiftUI

/// RGB / master curve: tap the curve to add a point (up to 6), drag points anywhere (they stay in order), select a
/// point to type its values or remove it. Master's black and white ends move up and down.
struct CCCurveGraph: View {
    @ObservedObject var state: EditorState
    let effect: EffectInstance
    /// "m", "r", "g" or "b".
    let channel: String
    /// Selected point: a slot's on-key, or "mBlack" / "mWhite".
    @Binding var selected: String?

    @State private var dragging: String?
    @State private var tapCandidate = false

    private struct Handle { let id: String; let x: Double; let y: Double; let slot: GradeR4.Slot? }

    private func handles(_ g: EffectInstance, _ t: Double) -> [Handle] {
        var h = GradeR4.slots(channel).filter { GradeR4.flag(g, $0.on) }.map {
            Handle(id: $0.on, x: GradeR4.num(g, $0.x, t) / 100, y: GradeR4.num(g, $0.y, t) / 100, slot: $0)
        }
        // Original points read with the same ordering the renderer uses.
        if h.count == 3 && h.allSatisfy({ $0.slot?.legacy == true }) {
            let p = GradeCurves.points(g, t, channel: channel)
            h = h.enumerated().map { Handle(id: $0.element.id, x: p.xs[$0.offset + 1], y: p.ys[$0.offset + 1], slot: $0.element.slot) }
        }
        if channel == "m" {
            h.append(Handle(id: "mBlack", x: 0, y: GradeR4.num(g, "mBlack", t) / 100, slot: nil))
            h.append(Handle(id: "mWhite", x: 1, y: GradeR4.num(g, "mWhite", t) / 100, slot: nil))
        }
        return h
    }

    private var tint: Color { ["m": Color.white, "r": .red, "g": .green, "b": .blue][channel] ?? .white }

    var body: some View {
        GeometryReader { geo in
            let g = CCLive.grade(state, effect), t = state.currentTime
            let ap = GradeR4.activePoints(g, t, channel: channel)
            let curve = GradeCurves.curve(xs: ap.xs, ys: ap.ys)
            let hs = handles(g, t)
            let W = geo.size.width, H = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45))
                Path { p in
                    for k in 1..<4 {
                        let x = W * CGFloat(k) / 4, y = H * CGFloat(k) / 4
                        p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: H))
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: W, y: y))
                    }
                    p.move(to: CGPoint(x: 0, y: H)); p.addLine(to: CGPoint(x: W, y: 0))
                }
                .stroke(Color.white.opacity(0.1))
                Path { p in
                    for (i, v) in curve.enumerated() {
                        let pt = CGPoint(x: W * CGFloat(i) / 255, y: H * CGFloat(1 - v))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(tint, lineWidth: 2)
                ForEach(hs, id: \.id) { h in
                    Circle().fill(selected == h.id || dragging == h.id ? Theme.accentGlow : .white)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
                        .position(x: W * CGFloat(h.x), y: H * CGFloat(1 - h.y))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in drag(v, W: W, H: H) }
                .onEnded { v in end(v, W: W, H: H) })
        }
    }

    private func drag(_ v: DragGesture.Value, W: CGFloat, H: CGFloat) {
        let g = CCLive.grade(state, effect), t = state.currentTime
        if dragging == nil && !tapCandidate {
            // Nearest point within reach of the finger; otherwise this may be a tap that adds a point.
            let near = handles(g, t).map { h in (h, hypot(CGFloat(h.x) * W - v.startLocation.x, CGFloat(1 - h.y) * H - v.startLocation.y)) }
                .min { $0.1 < $1.1 }
            if let near, near.1 < 30 {
                dragging = near.0.id; selected = near.0.id
                state.beginEdit("Curve")
            } else {
                tapCandidate = true
            }
        }
        guard let id = dragging else { return }
        let y = min(1, max(0, 1 - Double(v.location.y / max(H, 1))))
        if id == "mBlack" { CCLive.set(state, effect, "mBlack", min(50, y * 100)); return }
        if id == "mWhite" { CCLive.set(state, effect, "mWhite", max(50, y * 100)); return }
        guard let slot = GradeR4.slots(channel).first(where: { $0.on == id }) else { return }
        // Sideways too, kept between its neighbours so points never cross.
        let others = handles(g, t).filter { $0.id != id && $0.slot != nil }.map(\.x)
        let cur = GradeR4.num(g, slot.x, t) / 100
        let lo = (others.filter { $0 < cur }.max() ?? 0) + 0.02, hi = (others.filter { $0 > cur }.min() ?? 1) - 0.02
        let nx = max(lo, min(hi, Double(v.location.x / max(W, 1))))
        CCLive.set(state, effect, slot.y, y * 100)
        CCLive.set(state, effect, slot.x, min(98, max(2, nx * 100)))
    }

    private func end(_ v: DragGesture.Value, W: CGFloat, H: CGFloat) {
        defer { tapCandidate = false }
        if dragging != nil { dragging = nil; state.endEdit(); return }
        guard tapCandidate, hypot(v.translation.width, v.translation.height) < 10 else { return }
        let g = CCLive.grade(state, effect), t = state.currentTime
        guard let slot = GradeR4.freeSlot(g, channel: channel) else {
            state.recoveryNotice = "A curve holds up to 6 points. Remove one to add another."
            return
        }
        // The new point sits on the curve where you tapped, so adding it changes nothing until you drag it.
        let ap = GradeR4.activePoints(g, t, channel: channel)
        let x = min(0.98, max(0.02, Double(v.location.x / max(W, 1))))
        if ap.xs.contains(where: { abs($0 - x) < 0.025 }) { return }
        let y = min(1, max(0, GradeCurves.spline(xs: ap.xs, ys: ap.ys, at: x)))
        state.beginEdit("Add Curve Point")
        CCLive.set(state, effect, slot.x, x * 100)
        CCLive.set(state, effect, slot.y, y * 100)
        CCLive.setFlag(state, effect, slot.on, true)
        state.endEdit()
        selected = slot.on
    }
}

/// Hue vs Hue / Sat / Lum (8 vector knots, wrapping) and Luma vs Sat (5 knots). Drag a knot up or down; the
/// selected knot's value can also be typed below the graph.
struct CCKnotGraph: View {
    @ObservedObject var state: EditorState
    let effect: EffectInstance
    /// "hueHue", "hueSat", "hueLum" or "lumSat".
    let prefix: String
    @Binding var selected: Int?
    @State private var dragging: Int?

    private var limit: Double { prefix == "hueHue" ? 180 : 100 }
    private var isHue: Bool { prefix != "lumSat" }

    private func knotColor(_ i: Int) -> Color {
        isHue ? Color(hue: GradeR4.vectorHues[i] / 360, saturation: 0.85, brightness: 1) : Color(white: GradeR4.lumaKnots[i])
    }

    var body: some View {
        GeometryReader { geo in
            let g = CCLive.grade(state, effect), t = state.currentTime
            let W = geo.size.width, H = geo.size.height - 14
            let xs = GradeR4.knotXs(prefix), ks = GradeR4.knots(g, prefix, t)
            let lim = limit
            let py: (Double) -> CGFloat = { v in H * CGFloat(0.5 - v / lim / 2) }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: H / 2)); p.addLine(to: CGPoint(x: W, y: H / 2))
                    for x in xs { p.move(to: CGPoint(x: W * CGFloat(x), y: 0)); p.addLine(to: CGPoint(x: W * CGFloat(x), y: H)) }
                }
                .stroke(Color.white.opacity(0.1))
                Path { p in
                    for i in 0...128 {
                        let x = Double(i) / 128
                        let pt = CGPoint(x: W * CGFloat(x), y: py(min(limit, max(-limit, GradeR4.value(g, prefix, t, at: x)))))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(Color.white, lineWidth: 2)
                // Input band: the hues (or lumas) along the bottom.
                Rectangle()
                    .fill(LinearGradient(colors: isHue ? (0...12).map { Color(hue: Double($0) / 12, saturation: 0.85, brightness: 1) } : [.black, .white],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: W, height: 10).clipShape(Capsule())
                    .offset(y: H + 4)
                ForEach(xs.indices, id: \.self) { i in
                    Circle().fill(knotColor(i))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(selected == i || dragging == i ? Theme.accentGlow : .white, lineWidth: 2))
                        .position(x: W * CGFloat(xs[i]), y: py(ks[i]))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if dragging == nil {
                        let k = xs.indices.min { abs(CGFloat(xs[$0]) * W - v.startLocation.x) < abs(CGFloat(xs[$1]) * W - v.startLocation.x) } ?? 0
                        dragging = k; selected = k
                        state.beginEdit("Curve")
                    }
                    guard let k = dragging else { return }
                    let val = (0.5 - Double(v.location.y / max(H, 1))) * 2 * limit
                    // Snap to zero near the middle line so a knot can be put back exactly.
                    CCLive.set(state, effect, "\(prefix)\(k)", abs(val) < limit * 0.03 ? 0 : min(limit, max(-limit, val)))
                }
                .onEnded { _ in dragging = nil; state.endEdit() })
        }
    }
}
