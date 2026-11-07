import SwiftUI

struct OpaqueMenuActionStyle: PrimitiveButtonStyle {
    let dismiss: () -> Void
    func makeBody(configuration: Configuration) -> some View {
        Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { configuration.trigger() } } label: {
            configuration.label.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
