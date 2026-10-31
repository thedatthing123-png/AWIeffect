import SwiftUI

/// The app's own pop-up: a dark drawer that rises from the bottom over a dimmed editor. Tap outside or swipe it
/// down to close (whatever you changed is already applied). Replaces the system sheets everywhere.
struct DrawerChrome<Content: View>: View {
    @Binding var isPresented: Bool
    var heightFraction: CGFloat = 0.82
    @ViewBuilder let content: () -> Content
    @State private var shown = false
    @State private var drag: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.opacity(shown ? 0.5 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                VStack(spacing: 0) {
                    Capsule().fill(Theme.textDim.opacity(0.6)).frame(width: 42, height: 5)
                        .frame(maxWidth: .infinity).frame(height: 22)
                        .contentShape(Rectangle())
                        .gesture(DragGesture()
                            .onChanged { drag = max(0, $0.translation.height) }
                            .onEnded { g in
                                if g.translation.height > 120 || g.predictedEndTranslation.height > 260 { close() }
                                else { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { drag = 0 } }
                            })
                        .accessibilityLabel("Close")
                        .accessibilityAddTraits(.isButton)
                        .onTapGesture { close() }
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: geo.size.height * heightFraction)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                        .fill(Theme.background)
                        .overlay(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 20, y: -4)
                        .ignoresSafeArea(edges: .bottom)
                )
                .offset(y: shown ? drag : geo.size.height)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) { shown = true } }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.18)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { isPresented = false }
        }
    }
}

extension View {
    /// Custom drawer instead of a system sheet.
    func awiSheet<C: View>(isPresented: Binding<Bool>, heightFraction: CGFloat = 0.82, @ViewBuilder content: @escaping () -> C) -> some View {
        fullScreenCover(isPresented: isPresented) {
            DrawerChrome(isPresented: isPresented, heightFraction: heightFraction, content: content)
                .presentationBackground(.clear)
        }
    }
}
