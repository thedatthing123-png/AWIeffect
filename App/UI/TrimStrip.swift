import SwiftUI

/// Alight Motion-style clip strip for the selected layer: speed, then three trim buttons that change with the
/// playhead — inside the clip: Trim Start / Split / Trim End; before or after it: Extend (fill the clip out to
/// the playhead).
struct TrimStrip: View {
    @ObservedObject var state: EditorState
    @ObservedObject var clock: PlayClock

    var body: some View {
        if let l = state.selectedLayer, !state.isMultiSelecting, !state.linkPicking {
            let t = clock.time
            let inside = t > l.inPoint + 1e-4 && t < l.outPoint - 1e-4
            HStack(spacing: 6) {
                if l.isMedia {
                    button("speedometer", "Speed") { state.panel = .clip }
                }
                if inside {
                    button("arrow.right.to.line", "Trim Start") { trim(start: true) }
                    button("scissors", "Split") { state.splitSelected() }
                    button("arrow.left.to.line", "Trim End") { trim(start: false) }
                } else if t <= l.inPoint {
                    button("arrow.left.and.line.vertical.and.arrow.right", "Extend Start Here") { trim(start: true) }
                } else {
                    button("arrow.left.and.line.vertical.and.arrow.right", "Extend End Here") { trim(start: false) }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Theme.surface)
        }
    }

    private func trim(start: Bool) {
        guard let l = state.selectedLayer else { return }
        let t = state.project.snapToFrame(clock.time)
        state.beginEdit(start ? "Trim Start" : "Trim End")
        state.trimClip(l, start: start, by: t - (start ? l.inPoint : l.outPoint))
        state.endEdit()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func button(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
