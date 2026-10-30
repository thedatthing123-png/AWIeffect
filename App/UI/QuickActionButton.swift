import SwiftUI

extension EditorState {
    /// Adds a keyframe on position, scale, rotation and opacity at the playhead (AE "key all transform").
    func keyAllTransform() {
        guard let i = selectedIndex else { return }
        let t = currentTime
        mutate("Keyframe Transform") { p in
            var tr = p.layers[i].transform
            if !tr.position.hasKeyframe(at: t) { tr.position.toggleKeyframe(at: t) }
            if !tr.scale.hasKeyframe(at: t) { tr.scale.toggleKeyframe(at: t) }
            if !tr.rotation.hasKeyframe(at: t) { tr.rotation.toggleKeyframe(at: t) }
            if !tr.opacity.hasKeyframe(at: t) { tr.opacity.toggleKeyframe(at: t) }
            p.layers[i].transform = tr
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

/// Floating radial shortcut menu (no keybinds needed): tap to open, tap an action.
struct QuickActionButton: View {
    @ObservedObject var state: EditorState
    @State private var open = false

    private var actions: [(String, String, () -> Void)] {
        [("diamond.fill", "Key All", { state.keyAllTransform() }),
         ("scissors", "Split", { state.splitSelected() }),
         ("plus.square.on.square", "Duplicate", { state.duplicateSelected() }),
         ("sparkles", "Effects", { state.panel = .effects }),
         ("wand.and.rays", "Presets", { state.panel = .presets }),
         ("arrow.uturn.backward", "Undo", { state.undo() })]
    }

    var body: some View {
        ZStack {
            if open {
                ForEach(Array(actions.enumerated()), id: \.offset) { i, a in
                    let angle = Double.pi * (0.5 + 0.5 * Double(i) / Double(actions.count - 1))   // fan up-left
                    Button {
                        a.2(); withAnimation(.spring(response: 0.3)) { open = false }
                    } label: {
                        Image(systemName: a.0).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(Theme.raised)).overlay(Circle().stroke(Theme.accent.opacity(0.6)))
                    }
                    .accessibilityLabel(a.1)
                    .offset(x: CGFloat(cos(angle) * 78), y: CGFloat(-sin(angle) * 78))
                    .transition(.scale.combined(with: .opacity))
                    .disabled(state.selectedLayer == nil && a.1 != "Undo")
                }
            }
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { open.toggle() } } label: {
                Image(systemName: open ? "xmark" : "bolt.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(LinearGradient(colors: [Theme.accentGlow, Theme.accent], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: Theme.accent.opacity(0.6), radius: 10)
            }
            .accessibilityLabel("Quick actions")
        }
        .frame(width: 46, height: 46)
    }
}
