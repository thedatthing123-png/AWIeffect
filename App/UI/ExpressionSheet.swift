import SwiftUI

/// Ready-made expressions (written for AWIeffect; same API as After Effects).
struct ExpressionSnippet: Identifiable {
    let id = UUID()
    let title: String
    let code: String
    let note: String

    static let library: [ExpressionSnippet] = [
        .init(title: "Shake", code: "wiggle(8, 25)", note: "8 wiggles/sec, 25 px (or units)"),
        .init(title: "Smooth Shake", code: "wiggle(3, 40, 3, 0.6)", note: "Slower, more organic"),
        .init(title: "Choppy Shake", code: "posterizeTime(12);\nwiggle(12, 30)", note: "Stepped 12 fps jitter"),
        .init(title: "Shake → Calm", code: "var a = linear(time, inPoint, inPoint + 1, 60, 0);\nwiggle(10, a)", note: "Strong hit that settles in 1s"),
        .init(title: "Loop (Cycle)", code: "loopOut(\"cycle\")", note: "Repeat the keyframes forever"),
        .init(title: "Loop (Ping-Pong)", code: "loopOut(\"pingpong\")", note: "Back and forth"),
        .init(title: "Loop (Offset)", code: "loopOut(\"offset\")", note: "Keep stacking the change"),
        .init(title: "Keep Going", code: "loopOut(\"continue\")", note: "Continue at the last speed"),
        .init(title: "Bounce Settle", code: "inertia(0.06, 3, 6)", note: "Springy overshoot after the last keyframe"),
        .init(title: "Spin", code: "time * 180", note: "Rotation: 180° per second"),
        .init(title: "Pulse", code: "var s = 100 + 8 * Math.sin(time * Math.PI * 4);\n[s, s]", note: "Scale: breathing pulse"),
        .init(title: "Flicker", code: "posterizeTime(15);\nrandom(30, 100)", note: "Opacity: random flicker"),
        .init(title: "Fade In", code: "ease(time, inPoint, inPoint + 0.5, 0, 100)", note: "Opacity: 0 → 100 over 0.5s"),
        .init(title: "Orbit", code: "var r = 200, a = time * 2;\n[thisComp.width / 2 + Math.cos(a) * r, thisComp.height / 2 + Math.sin(a) * r]", note: "Position: circle around the center"),
        .init(title: "Lag", code: "valueAtTime(time - 0.1)", note: "Follow own animation 0.1s late"),
    ]
}

struct ExpressionSheet: View {
    @ObservedObject var state: EditorState
    let key: PropertyKey
    @State private var code = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Expression · \(key.title)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textDim)
                TextEditor(text: $code)
                    .font(.system(size: 15, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 120)
                    .glass(radius: 12)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if let err = state.expressionError(key), state.expression(key) != nil {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Theme.danger)
                }
                Text("Library").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textDim)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(ExpressionSnippet.library) { s in
                            Button { code = s.code } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                                    Text(s.note).font(.system(size: 10)).foregroundStyle(Theme.textDim).lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                                .padding(8).glass(radius: 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Remove", role: .destructive) { state.setExpression(key, nil); dismiss() }
                        .disabled(state.expression(key) == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        state.setExpression(key, code)
                        state.redrawToken += 1
                    }
                    .bold()
                }
            }
        }
        .onAppear { code = state.expression(key) ?? "" }
    }
}
