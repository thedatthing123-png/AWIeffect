import SwiftUI
import UIKit

extension EditorState {
    /// Starts typing on the canvas: the editor makes room above the keyboard and dims everything else.
    func beginTyping() {
        guard selectedLayer?.text != nil else { return }
        pause()
        beginEdit("Type Text")
        textTyping = true
    }

    func endTyping() {
        textTyping = false
        TextStudioSession.shared.caret = nil
        endEdit()
    }

    /// Live text while typing (one undo step for the whole typing session).
    func setTextLive(_ s: String) {
        guard let i = selectedIndex, project.layers[i].text != nil else { return }
        mutate("Type Text") { p in
            // Keeps the ids of untouched letters, so colors / letter styles / split parts stay on their letters.
            p.layers[i].text?.setString(s)
        }
    }

    /// Prefix of animators the Letters section owns (per-word / per-letter style, split parts).
    static let styleAnimatorPrefix = "✦ "
    static let partAnimatorPrefix = "◆ "

    /// Style just these characters (size, raise, turn, opacity, blur) with an animator on exactly those letters.
    func styleRange(_ start: Int, _ end: Int, _ change: (inout TextAnimatorProperties) -> Void) {
        guard selectedLayer?.text != nil else { return }
        let name = Self.styleAnimatorPrefix + "\(start)-\(end)"
        editTextContinuous { td in
            if let i = td.animators.firstIndex(where: { $0.name == name }) {
                change(&td.animators[i].properties)
            } else {
                td.migrateToCharIDs()
                var a = TextAnimator(name: name)
                a.selector.targetIDs = TextStudioLogic.ids(td, range: start..<end)
                change(&a.properties)
                td.animators.append(a)
            }
        }
    }

    /// Split mode: one animator per word (or letter) so each part animates on its own inside one layer.
    func setSplit(_ unit: TextUnit?) {
        guard let t = selectedLayer?.text else { return }
        editText(unit == nil ? "Join Text" : "Split Text") { td in
            td.animators.removeAll { $0.name.hasPrefix(Self.partAnimatorPrefix) }
            guard let unit else { return }
            td.migrateToCharIDs()
            let parts = TextParts.ranges(t.string, unit: unit)
            for (k, r) in parts.enumerated() {
                var a = TextAnimator(name: Self.partAnimatorPrefix + "\(unit == .words ? "Word" : "Letter") \(k + 1) · \(r.text)")
                a.selector.targetIDs = TextStudioLogic.ids(td, range: r.start..<r.end)
                a.properties.position = Animated(Vec2(0, 0))
                a.properties.scale = Animated(Vec2(100, 100))
                a.properties.rotation = Animated(0)
                a.properties.opacity = Animated(100)
                td.animators.append(a)
            }
        }
    }
}

enum TextParts {
    struct Part { let text: String; let start: Int; let end: Int }

    static func ranges(_ s: String, unit: TextUnit) -> [Part] {
        let chars = Array(s)
        if unit != .words {
            return chars.enumerated().compactMap { i, c in c.isWhitespace ? nil : Part(text: String(c), start: i, end: i + 1) }
        }
        var out: [Part] = []
        var i = 0
        while i < chars.count {
            if chars[i].isWhitespace { i += 1; continue }
            var j = i
            while j < chars.count, !chars[j].isWhitespace { j += 1 }
            out.append(Part(text: String(chars[i..<j]), start: i, end: j))
            i = j
        }
        return out
    }
}

enum TextStudioTab: String, CaseIterable { case style = "Style", animate = "Animate", presets = "Presets", threeD = "3D" }

/// Text Studio: header (back · expand · type), four tabs (Style / Animate / Presets / 3D) and the live canvas above.
/// On the canvas: tap a letter to type at that spot, drag across letters to select them, drag selected letters to move
/// them (writes an animator), pinch to size the selection or the whole text.
struct TextPanel: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var session = TextStudioSession.shared
    @AppStorage("awi.textStudioTab") private var tabRaw = TextStudioTab.style.rawValue

    private var tab: TextStudioTab { TextStudioTab(rawValue: tabRaw) ?? .style }

    var body: some View {
        VStack(spacing: 0) {
            header
            if state.selectedLayer?.text != nil {
                tabBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        switch tab {
                        case .style: TextStyleTab(state: state)
                        case .animate: TextAnimateTab(state: state)
                        case .presets: TextPresetBrowser(state: state, scrolls: false)
                        case .threeD: Text3DTab(state: state)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 24)
                }
                .id(tabRaw)                       // each tab starts at its top
                .transaction { $0.animation = nil }
            }
        }
        .onAppear { session.follow(state.selectedLayerID) }
        .onChange(of: state.selectedLayerID) { _, id in session.follow(id) }
    }

    /// [back] title [expand] [type] — three controls.
    private var header: some View {
        HStack(spacing: 6) {
            Button { session.expanded = false; state.panel = .none } label: {
                Image(systemName: "chevron.down").font(.system(size: 15, weight: .semibold)).frame(width: TS.tap, height: TS.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(Theme.text)
            .accessibilityLabel("Panel Back")
            VStack(alignment: .leading, spacing: 0) {
                Text("Text Studio").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                Text(session.hasSelection ? "\(session.selectedIDs.count) letters selected" : "Drag across letters on the canvas to select")
                    .font(.system(size: 11)).foregroundStyle(Theme.textDim).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            TSIconButton(icon: session.expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                         label: session.expanded ? "Shrink Text Studio" : "Expand Text Studio", active: session.expanded) {
                session.expanded.toggle()
            }
            Button { state.beginTyping() } label: {
                Label("Type", systemImage: "character.cursor.ibeam").font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 12).frame(minHeight: TS.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Type Text")
        }
        .padding(.horizontal, 8)
    }

    /// The four tabs: one navigation control, each segment ≥ 44 pt tall and a quarter of the width.
    private var tabBar: some View {
        TSSegmented(options: TextStudioTab.allCases.map { ($0, $0.rawValue) }, selection: tab, label: "Text Studio Tab") { tabRaw = $0.rawValue }
            .padding(.horizontal, 12).padding(.vertical, 4)
    }
}

/// Typing bar shown above the keyboard while you type (the rest of the editor steps aside). The field's caret and the
/// caret drawn on the canvas are the same: tap a letter on the canvas to move it there.
struct TypeBar: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var session = TextStudioSession.shared
    @State private var draft = ""
    @State private var showFonts = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { showFonts = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "textformat").font(.system(size: 13, weight: .bold))
                        Text(FontLibrary.displayName(state.selectedLayer?.text?.fontName ?? "")).lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10).frame(minHeight: TS.tap)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
                    .foregroundStyle(Theme.text)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Font")
                Spacer()
                Button { state.endTyping() } label: {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                        .frame(width: 52, height: TS.tap).background(RoundedRectangle(cornerRadius: 9).fill(Theme.accent))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done Typing")
            }
            ZStack(alignment: .topLeading) {
                CaretTextView(text: $draft, selection: $session.caret, focus: true)
                    .frame(minHeight: TS.tap, maxHeight: 96)
                if draft.isEmpty {
                    Text("Type your text").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.textDim)
                        .padding(.horizontal, 11).padding(.vertical, 10).allowsHitTesting(false)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 1.5))
            .onChange(of: draft) { _, s in if s != state.selectedLayer?.text?.string { state.setTextLive(s) } }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.background)
        .onAppear {
            draft = state.selectedLayer?.text?.string ?? ""
            if session.caret == nil { let n = draft.count; session.caret = n..<n }
        }
        .awiSheet(isPresented: $showFonts) {
            FontPicker(current: state.selectedLayer?.text?.fontName ?? "", sample: draft) { name in state.editText("Font") { $0.fontName = name } }
        }
    }
}

/// UITextView-backed field whose caret / selection is shared (in Character indices) with the canvas.
struct CaretTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: Range<Int>?
    var focus: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let v = UITextView()
        v.backgroundColor = .clear
        v.font = .systemFont(ofSize: 16, weight: .semibold)
        v.textColor = UIColor(Theme.text)
        v.tintColor = UIColor(Theme.accentGlow)
        v.autocorrectionType = .no
        v.spellCheckingType = .no
        v.smartQuotesType = .no
        v.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        v.delegate = context.coordinator
        v.accessibilityLabel = "Text Input"
        v.text = text
        return v
    }

    func updateUIView(_ v: UITextView, context: Context) {
        context.coordinator.parent = self
        guard v.markedTextRange == nil else { return }       // never interrupt IME composition
        if v.text != text {
            context.coordinator.applying = true
            v.text = text
            context.coordinator.applying = false
        }
        if let sel = selection {
            let s = v.text ?? ""
            let a = TextStudioLogic.utf16Offset(ofCharacter: sel.lowerBound, in: s)
            let b = TextStudioLogic.utf16Offset(ofCharacter: sel.upperBound, in: s)
            let ns = NSRange(location: a, length: max(0, b - a))
            if v.selectedRange != ns {
                context.coordinator.applying = true
                v.selectedRange = ns
                context.coordinator.applying = false
            }
        }
        if focus, !v.isFirstResponder, v.window != nil { DispatchQueue.main.async { v.becomeFirstResponder() } }
        else if focus, !v.isFirstResponder { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { v.becomeFirstResponder() } }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CaretTextView
        var applying = false
        init(_ p: CaretTextView) { parent = p }

        func textViewDidChange(_ v: UITextView) {
            guard !applying else { return }
            parent.text = v.text ?? ""
            report(v)
        }

        func textViewDidChangeSelection(_ v: UITextView) {
            guard !applying, v.markedTextRange == nil else { return }
            report(v)
        }

        private func report(_ v: UITextView) {
            let s = v.text ?? ""
            let r = v.selectedRange
            let a = TextStudioLogic.characterIndex(ofUTF16: r.location, in: s)
            let b = TextStudioLogic.characterIndex(ofUTF16: r.location + r.length, in: s)
            let new = a..<max(a, b)
            let binding = parent.$selection
            if binding.wrappedValue != new { DispatchQueue.main.async { binding.wrappedValue = new } }
        }
    }
}

extension FontLibrary {
    /// Readable font name for buttons ("AvenirNext-HeavyItalic" -> "Avenir Next Heavy Italic").
    static func displayName(_ postScript: String) -> String {
        guard !postScript.isEmpty else { return "Font" }
        var out = ""
        for (i, ch) in postScript.replacingOccurrences(of: "-", with: " ").enumerated() {
            if i > 0, ch.isUppercase, let last = out.last, last.isLowercase { out.append(" ") }
            out.append(ch)
        }
        return out
    }
}
