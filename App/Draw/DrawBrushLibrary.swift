import SwiftUI

/// A ready-made brush. Picking one keeps your color.
struct BrushPreset: Identifiable {
    let name: String
    let group: String
    let brush: Brush
    var id: String { group + name }

    private static func make(_ kind: BrushKind, size: Double, hard: Double = 0.85, opacity: Double = 1, stabilizer: Double = 0.4,
                             pressure: Bool = true, start: Double = 0, end: Double = 0, thin: Double = 0, spacing: Double = 0,
                             jitter: Double = 0, scatter: Double = 0) -> Brush {
        var b = Brush(kind: kind, size: size, opacity: opacity, hardness: hard, stabilizer: stabilizer)
        b.pressureSize = pressure; b.taperStart = start; b.taperEnd = end; b.speedThin = thin
        b.spacing = spacing; b.sizeJitter = jitter; b.scatter = scatter
        return b
    }

    static let groups = ["Ink", "Sketch", "Paint", "Texture", "Light"]
    static let all: [BrushPreset] = [
        .init(name: "G-Pen", group: "Ink", brush: make(.ink, size: 10, stabilizer: 0.45, start: 40, end: 50, thin: 0.6)),
        .init(name: "Maru Pen", group: "Ink", brush: make(.ink, size: 5, stabilizer: 0.4, start: 24, end: 30, thin: 0.5)),
        .init(name: "Mapping Pen", group: "Ink", brush: make(.ink, size: 2.5, stabilizer: 0.35, start: 12, end: 16, thin: 0.3)),
        .init(name: "Heavy Inker", group: "Ink", brush: make(.ink, size: 26, stabilizer: 0.55, start: 90, end: 110, thin: 0.7)),
        .init(name: "Mono Line", group: "Ink", brush: make(.pen, size: 8, hard: 0.95, stabilizer: 0.4, pressure: false)),
        .init(name: "Pencil", group: "Sketch", brush: make(.pencil, size: 5, opacity: 0.85, stabilizer: 0.15)),
        .init(name: "Soft 2B", group: "Sketch", brush: make(.pencil, size: 12, opacity: 0.55, stabilizer: 0.15, jitter: 0.2)),
        .init(name: "Rough Sketch", group: "Sketch", brush: make(.charcoal, size: 9, opacity: 0.7, stabilizer: 0.1, scatter: 0.1)),
        .init(name: "Round Brush", group: "Paint", brush: make(.pen, size: 30, hard: 0.7, stabilizer: 0.25)),
        .init(name: "Marker", group: "Paint", brush: make(.marker, size: 28, hard: 0.8, opacity: 0.8, stabilizer: 0.3, pressure: false)),
        .init(name: "Flat Chisel", group: "Paint", brush: make(.flat, size: 30, hard: 0.9, stabilizer: 0.3, pressure: false)),
        .init(name: "Airbrush", group: "Paint", brush: make(.airbrush, size: 120, hard: 0.1, stabilizer: 0.2, pressure: false)),
        .init(name: "Watercolor", group: "Paint", brush: make(.watercolor, size: 60, hard: 0.5, opacity: 0.7, stabilizer: 0.25)),
        .init(name: "Charcoal", group: "Texture", brush: make(.charcoal, size: 34, stabilizer: 0.15)),
        .init(name: "Spray", group: "Texture", brush: make(.spray, size: 90, hard: 0.5, stabilizer: 0.1, pressure: false)),
        .init(name: "Dirty Ink", group: "Texture", brush: make(.ink, size: 18, stabilizer: 0.2, spacing: 0.35, jitter: 0.6, scatter: 0.3)),
        .init(name: "Screentone", group: "Texture", brush: make(.screentone, size: 90, hard: 0.95, stabilizer: 0.2, pressure: false)),
        .init(name: "Soft Glow", group: "Light", brush: make(.glow, size: 110, hard: 0.1, stabilizer: 0.25, pressure: false)),
        .init(name: "Hot Line", group: "Light", brush: make(.glow, size: 36, hard: 0.2, stabilizer: 0.4, start: 30, end: 40, thin: 0.4)),
    ]

    /// A real stroke from the real engine, so what you see is what the brush does.
    @MainActor private static var previews: [String: UIImage] = [:]
    @MainActor static func preview(_ preset: BrushPreset) -> UIImage? {
        if let cached = previews[preset.id] { return cached }
        guard let e = DrawEngine(width: 300, height: 72), let layer = e.activeLayer else { return nil }
        var b = preset.brush
        b.color = .white
        b.size = min(b.size, 44); b.taperStart = min(b.taperStart, 60); b.taperEnd = min(b.taperEnd, 50); b.stabilizer = 0
        e.brush = b
        let wave = (0...50).map { i -> SIMD2<Double> in
            let t = Double(i) / 50
            return SIMD2(24 + t * 240, 36 + sin(t * 6.28) * 16)
        }
        e.beginStroke(at: wave[0], pressure: 0.4)
        for (i, p) in wave.enumerated().dropFirst() { e.continueStroke(to: p, pressure: 0.3 + 0.7 * sin(Double(i) / 50 * .pi)) }
        e.endStroke()
        guard let cg = e.cgImage(e.bytes(of: layer)) else { return nil }
        let image = UIImage(cgImage: cg)
        previews[preset.id] = image
        return image
    }
}

struct BrushPicker: View {
    @ObservedObject var session: DrawSession
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(BrushPreset.groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textDim)
                            ForEach(BrushPreset.all.filter { $0.group == group }) { preset in row(preset) }
                        }
                    }
                }
                .padding(14)
            }
            .background(Theme.background)
            .navigationTitle("Brushes").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Settings") { showSettings = true } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .navigationDestination(isPresented: $showSettings) { BrushSettings(session: session) }
        }
    }

    private func row(_ preset: BrushPreset) -> some View {
        Button {
            var b = preset.brush
            b.color = session.brush.color
            session.brush = b
            session.brushName = preset.name
            session.tool = .brush
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(preset.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text).frame(width: 104, alignment: .leading)
                if let image = BrushPreset.preview(preset) { Image(uiImage: image).resizable().scaledToFit().frame(height: 40) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(session.brushName == preset.name ? Theme.accent.opacity(0.28) : Theme.surface))
        }
        .accessibilityLabel(preset.name)
    }
}

/// Every setting of the current brush.
struct BrushSettings: View {
    @ObservedObject var session: DrawSession

    private func row(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack { Text(title).frame(width: 110, alignment: .leading); Slider(value: value, in: range).tint(Theme.accent) }
    }

    var body: some View {
        Form {
            Section("Line") {
                row("Stabilizer", $session.brush.stabilizer, 0...1)
                row("Start Taper", $session.brush.taperStart, 0...300)
                row("End Taper", $session.brush.taperEnd, 0...300)
                row("Speed Thins", $session.brush.speedThin, 0...1)
            }
            Section("Tip") {
                row("Hardness", $session.brush.hardness, 0...0.99)
                row("Spacing", $session.brush.spacing, 0...1.5)
                row("Size Jitter", $session.brush.sizeJitter, 0...1)
                row("Scatter", $session.brush.scatter, 0...2)
            }
            Section("Apple Pencil") {
                Toggle("Pressure changes size", isOn: $session.brush.pressureSize)
                Toggle("Pressure changes opacity", isOn: $session.brush.pressureOpacity)
            }
        }
        .navigationTitle(session.brushName).navigationBarTitleDisplayMode(.inline)
    }
}
