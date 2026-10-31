import SwiftUI

/// Alight Motion-style value control: a bar showing where the value sits in its range.
/// Drag sideways to change it (the bar's width covers the whole range; drag slowly for fine steps),
/// tap to type an exact number. Typed numbers may go past the bar's ends, like After Effects.
struct ValueScrubber: View {
    let value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var unit: String = ""
    var onBegin: () -> Void = {}
    let onChange: (Double) -> Void
    var onEnd: () -> Void = {}
    /// Typed numbers may go past the bar's ends (positions, rotations). Effect settings stay inside their range,
    /// since some effects loop by their values and far-out numbers could stall the GPU.
    var allowBeyond = false

    @State private var dragBase: Double?
    @State private var lastX: CGFloat = 0
    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    private var span: Double { max(range.upperBound - range.lowerBound, 1e-9) }
    /// How far typed values may go past the bar (keeps renders sane).
    private var hardRange: ClosedRange<Double> { allowBeyond ? (range.lowerBound - span * 4)...(range.upperBound + span * 4) : range }

    static func format(_ v: Double, step: Double, span: Double) -> String {
        if step >= 1 || (step == 0 && span >= 100) { return String(format: "%.0f", v) }
        if span >= 10 { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }

    private func quantize(_ v: Double) -> Double {
        let q = step > 0 ? (v / step).rounded() * step : v
        return min(max(q, hardRange.lowerBound), hardRange.upperBound)
    }

    var body: some View {
        GeometryReader { geo in
            let frac = CGFloat(min(max((value - range.lowerBound) / span, 0), 1))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 9).fill(Theme.surface)
                RoundedRectangle(cornerRadius: 9).fill(Theme.accent.opacity(dragBase == nil ? 0.32 : 0.5))
                    .frame(width: max(0, geo.size.width * frac))
                if editing {
                    TextField("", text: $text)
                        .keyboardType(.numbersAndPunctuation)
                        .submitLabel(.done)
                        .focused($focused)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .onSubmit(commitText)
                        .onChange(of: focused) { _, f in if !f { commitText() } }
                        .padding(.horizontal, 8)
                } else {
                    Text(Self.format(value, step: step, span: span) + unit)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !editing else { return }
                text = Self.format(value, step: step, span: span)
                editing = true
                focused = true
            }
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { g in
                    if dragBase == nil {
                        dragBase = value; lastX = g.translation.width
                        onBegin()
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    // Fine control: slow drags move the value less than fast ones.
                    let dx = g.translation.width - lastX
                    lastX = g.translation.width
                    let speed = abs(dx)
                    let gain = speed < 2 ? 0.35 : 1.0
                    let next = (dragBase ?? value) + Double(dx) / Double(max(geo.size.width, 1)) * span * gain
                    dragBase = min(max(next, range.lowerBound), range.upperBound)
                    onChange(quantize(dragBase ?? value))
                }
                .onEnded { _ in dragBase = nil; onEnd() }, including: editing ? .none : .all)
        }
        .frame(height: 32)
        .accessibilityElement()
        .accessibilityValue(Self.format(value, step: step, span: span) + unit)
        .accessibilityAdjustableAction { dir in
            let d = (step > 0 ? step : span / 100) * (dir == .increment ? 1 : -1)
            onBegin(); onChange(quantize(value + d)); onEnd()
        }
    }

    private func commitText() {
        guard editing else { return }
        editing = false
        let cleaned = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let v = Double(cleaned), v.isFinite else { return }
        onBegin(); onChange(quantize(v)); onEnd()
    }
}
