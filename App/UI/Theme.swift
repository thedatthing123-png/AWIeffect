import SwiftUI

enum Theme {
    static let background = Color(hex: 0x0E0B14)
    static let surface = Color(hex: 0x17121F)
    static let raised = Color(hex: 0x211A2D)
    static let stroke = Color.white.opacity(0.07)
    static let accent = Color(hex: 0x9B5CFF)
    static let accentGlow = Color(hex: 0xB98CFF)
    static let keyframe = Color(hex: 0xC9A2FF)
    static let text = Color(hex: 0xF2EEF8)
    static let textDim = Color(hex: 0xA69DB5)
    static let danger = Color(hex: 0xFF5C7A)
    static let warning = Color(hex: 0xFFC75C)
    static let ok = Color(hex: 0x5CFFB0)

    static let corner: CGFloat = 14

    static func tagColor(_ t: LayerTag) -> Color {
        switch t {
        case .purple: return Color(hex: 0x9B5CFF)
        case .blue: return Color(hex: 0x5C8CFF)
        case .teal: return Color(hex: 0x3FD6C6)
        case .pink: return Color(hex: 0xFF5CA8)
        case .amber: return Color(hex: 0xFFB84D)
        case .green: return Color(hex: 0x5CD67A)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    init(_ c: RGBA) { self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a) }

    var rgba: RGBA {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBA(Double(r), Double(g), Double(b), Double(a))
    }
}

/// Glassy raised panel.
struct GlassPanel: ViewModifier {
    var radius: CGFloat = Theme.corner
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.raised.opacity(0.85))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.stroke))
    }
}

extension View {
    func glass(radius: CGFloat = Theme.corner) -> some View { modifier(GlassPanel(radius: radius)) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.accentGlow, Theme.accent], startPoint: .top, endPoint: .bottom))
            )
            .shadow(color: Theme.accent.opacity(configuration.isPressed ? 0.2 : 0.5), radius: 14, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Square tool tile used in bottom panels.
struct ToolTile: View {
    let icon: String
    let title: String
    var active = false
    let action: () -> Void
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 19, weight: .medium))
                Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(active ? Theme.accentGlow : Theme.text)
            .frame(minWidth: 66, maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(active ? Theme.accent.opacity(0.18) : Theme.surface))
        }
        .buttonStyle(.plain)
    }
}

/// Keyframe diamond toggle.
struct KeyframeDiamond: View {
    let filled: Bool
    let animated: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: filled ? "diamond.fill" : "diamond")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(filled || animated ? Theme.keyframe : Theme.textDim)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filled ? "Remove keyframe" : "Add keyframe")
    }
}

func formatTimecode(_ t: Double, fps: Double) -> String {
    let total = max(0, t)
    let s = Int(total)
    let f = Int(((total - Double(s)) * fps).rounded(.down))
    return String(format: "%02d:%02d:%02d", s / 60, s % 60, f)
}
