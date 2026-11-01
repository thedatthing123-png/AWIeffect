import SwiftUI

/// Swipe a row left to delete it (like iOS lists): drag past the threshold and let go, or tap the revealed button.
struct SwipeToDelete<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var isEnabled = true
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var horizontal: Bool?
    private let reveal: CGFloat = 84

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < -4 {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { offset = 0 }
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: max(reveal, -offset), alignment: .center).frame(maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.danger))
                }
                .buttonStyle(.plain)
            }
            content()
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .local)
                        .onChanged { v in
                            guard isEnabled else { return }
                            // Decide once per drag: sideways swipes delete, vertical ones scroll.
                            if horizontal == nil { horizontal = abs(v.translation.width) > abs(v.translation.height) * 1.4 }
                            guard horizontal == true else { return }
                            offset = min(0, v.translation.width)
                        }
                        .onEnded { v in
                            defer { horizontal = nil }
                            guard isEnabled, horizontal == true else { return }
                            if v.translation.width < -180 || v.predictedEndTranslation.width < -320 {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.easeOut(duration: 0.18)) { offset = -600 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { if isEnabled { onDelete() }; offset = 0 }
                            } else {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { offset = v.translation.width < -reveal / 2 ? -reveal : 0 }
                            }
                        }, including: isEnabled ? .all : .subviews)
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { offset = 0; horizontal = nil }
        }
        .clipped()
    }
}
