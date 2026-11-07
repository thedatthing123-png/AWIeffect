import SwiftUI

// Shared Text Studio rows. Layout rule: at most 3 controls per row, every tap target ≥ 44 pt, labels wrap instead of
// truncating, nothing overlaps.

enum TS {
    static let tap: CGFloat = 44
    static let labelWidth: CGFloat = 104
}

/// Keyframe stopwatch with a full 44 pt target.
struct TSDiamond: View {
    let filled: Bool
    let animated: Bool
    var label = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: filled ? "diamond.fill" : "diamond")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(filled || animated ? Theme.keyframe : Theme.textDim)
                .frame(width: TS.tap, height: TS.tap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel((filled ? "Remove keyframe " : "Add keyframe ") + label)
    }
}

/// Row label that wraps to two lines instead of truncating.
struct TSLabel: View {
    let text: String
    var width: CGFloat = TS.labelWidth
    var body: some View {
        Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            .frame(width: width, alignment: .leading)
    }
}

/// [diamond] label [scrubber] — the standard editable number. Pass `anim` for keyframable values.
struct TSNumberRow: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var unit: String = ""
    var allowBeyond = false
    /// (has key at playhead, is animated, toggle) — nil hides the diamond (value can't keyframe).
    var key: (filled: Bool, animated: Bool, toggle: () -> Void)? = nil
    let onBegin: () -> Void
    let onChange: (Double) -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if let key {
                TSDiamond(filled: key.filled, animated: key.animated, label: title, action: key.toggle)
            } else {
                Color.clear.frame(width: TS.tap, height: TS.tap)
            }
            TSLabel(text: title)
            ValueScrubber(value: value, range: range, step: step, unit: unit, onBegin: onBegin, onChange: onChange, onEnd: onEnd,
                          allowBeyond: allowBeyond)
                .frame(minHeight: TS.tap)
                .accessibilityLabel(title)
        }
    }
}

/// [diamond] label [color well].
struct TSColorRow: View {
    let title: String
    let color: RGBA
    var key: (filled: Bool, animated: Bool, toggle: () -> Void)? = nil
    let set: (RGBA) -> Void

    var body: some View {
        HStack(spacing: 4) {
            if let key { TSDiamond(filled: key.filled, animated: key.animated, label: title, action: key.toggle) }
            else { Color.clear.frame(width: TS.tap, height: TS.tap) }
            TSLabel(text: title)
            AWIColorWell("", selection: Binding(get: { Color(color) }, set: { set($0.rgba) })).labelsHidden()
                .frame(minWidth: TS.tap, minHeight: TS.tap)
                .accessibilityLabel(title)
            Spacer(minLength: 0)
        }
    }
}

/// Labelled switch, full-width 44 pt row.
struct TSToggleRow: View {
    let title: String
    var detail: String? = nil
    let isOn: Bool
    let set: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: set)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(Theme.textDim).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.accent)
        .frame(minHeight: TS.tap)
    }
}

/// Label + a menu picker showing the current choice (one control).
struct TSMenuRow<V: Hashable>: View {
    let title: String
    let options: [(V, String)]
    let selection: V
    let set: (V) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: TS.tap, height: 1)
            TSLabel(text: title)
            Menu {
                ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                    Button { set(o.0) } label: {
                        if o.0 == selection { Label(o.1, systemImage: "checkmark") } else { Text(o.1) }
                    }
                }
            } label: {
                HStack {
                    Text(options.first { $0.0 == selection }?.1 ?? "—").font(.system(size: 13, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: TS.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .foregroundStyle(Theme.text)
            }
            .accessibilityLabel(title)
        }
    }
}

/// Wide 44 pt button.
struct TSButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Theme.text
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: TS.tap)
            .background(RoundedRectangle(cornerRadius: 11).fill(filled ? Theme.accent : Theme.raised))
            .foregroundStyle(filled ? .white : tint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Square 44 pt icon button.
struct TSIconButton: View {
    let icon: String
    let label: String
    var tint: Color = Theme.text
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .frame(width: TS.tap, height: TS.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(active ? Theme.accent.opacity(0.35) : Theme.surface))
                .foregroundStyle(active ? Theme.accentGlow : tint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Section title.
struct TSSection: View {
    let title: String
    var body: some View {
        Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accentGlow)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
    }
}

/// Card with a title row (title + up to two trailing controls) and content.
struct TSCard<Trailing: View, Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.textDim).lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                trailing()
            }
            .frame(minHeight: TS.tap)
            content()
        }
        .padding(10)
        .glass(radius: 12)
    }
}

/// Segmented choice built from real 44 pt buttons (2–3 options per row; the system segmented control is 32 pt tall).
struct TSSegmented<V: Hashable>: View {
    let options: [(V, String)]
    let selection: V
    var label = ""
    let set: (V) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                Button { set(o.0) } label: {
                    Text(o.1).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: TS.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(o.0 == selection ? Theme.accent.opacity(0.85) : Theme.surface))
                        .foregroundStyle(o.0 == selection ? Color.white : Theme.text)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label.isEmpty ? o.1 : "\(label) \(o.1)")
                .accessibilityAddTraits(o.0 == selection ? .isSelected : [])
            }
        }
    }
}

extension EditorState {
    /// Scrubber wiring for a text value: one undo step per drag.
    func textScrub(_ title: String, _ change: @escaping (inout TextData, Double) -> Void)
        -> (begin: () -> Void, change: (Double) -> Void, end: () -> Void) {
        ({ [weak self] in self?.beginEdit(title) },
         { [weak self] v in self?.editTextContinuous { change(&$0, v) } },
         { [weak self] in self?.endEdit() })
    }
}
