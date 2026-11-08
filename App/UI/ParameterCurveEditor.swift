import SwiftUI

/// Two semantic controls, never a draggable point at every bounce or oscillation.
struct ParameterCurveEditor: View {
    let ease: SavedEase
    let onChange: (EaseCurve, Bool) -> Void
    @State private var original: EaseCurve?
    @GestureState private var dragging = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CurvePlot(ease: ease, speed: false)
                if let c = ease.curve {
                    if let a = c.kind.paramA { handle(c, first: true, spec: a, width: geo.size.width, y: geo.size.height - 22) }
                    if let b = c.kind.paramB { handle(c, first: false, spec: b, width: geo.size.width, y: 22) }
                }
            }.coordinateSpace(name: "parameterCurve")
        }
        .onChange(of: dragging) { _, active in
            if !active, original != nil {
                original = nil
                if let curve = ease.curve { onChange(curve, true) }
            }
        }
        .onChange(of: ease.curve?.kind) { _, _ in original = nil }
    }

    private func handle(_ curve: EaseCurve, first: Bool, spec: (String, ClosedRange<Double>, Double), width: CGFloat, y: CGFloat) -> some View {
        let value = first ? curve.a : curve.b
        let f = min(1, max(0, (value - spec.1.lowerBound) / (spec.1.upperBound - spec.1.lowerBound)))
        return Circle().fill(first ? Theme.keyframe : Color.white)
            .frame(width: 18, height: 18).overlay(Circle().stroke(Theme.accent, lineWidth: 2))
            .frame(width: 44, height: 44).contentShape(Rectangle())
            .accessibilityElement(children: .ignore).accessibilityLabel(spec.0 + " handle")
            .accessibilityValue(String(format: "%.2f", value))
            .accessibilityAdjustableAction { direction in
                var next = curve
                let step = first && [.cycleRepeat, .cyclePingPong, .bounceIn, .bounceOut].contains(curve.kind) ? 1 : (spec.1.upperBound - spec.1.lowerBound) / 20
                let v = min(spec.1.upperBound, max(spec.1.lowerBound, value + (direction == .increment ? step : -step)))
                if first { next.a = v } else { next.b = v }; onChange(next, true)
            }
            .position(x: 24 + CGFloat(f) * max(1, width - 48), y: y)
            .highPriorityGesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("parameterCurve"))
                .updating($dragging) { _, active, _ in active = true }
                .onChanged { drag in
                    if original == nil { original = curve }
                    onChange(Self.translated(original ?? curve, first: first, delta: drag.translation.width, width: width), false)
                }.onEnded { drag in
                    onChange(Self.translated(original ?? curve, first: first, delta: drag.translation.width, width: width), true)
                    original = nil
                })
    }

    static func translated(_ source: EaseCurve, first: Bool, delta: CGFloat, width: CGFloat) -> EaseCurve {
        guard let spec = first ? source.kind.paramA : source.kind.paramB else { return source }
        var c = source
        let base = first ? source.a : source.b
        var v = base + Double(delta / max(1, width - 48)) * (spec.1.upperBound - spec.1.lowerBound)
        if first && [.cycleRepeat, .cyclePingPong, .bounceIn, .bounceOut].contains(source.kind) { v = v.rounded() }
        v = min(spec.1.upperBound, max(spec.1.lowerBound, v))
        if first { c.a = v } else { c.b = v }
        return c
    }
}
