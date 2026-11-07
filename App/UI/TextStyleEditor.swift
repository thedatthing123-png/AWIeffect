import SwiftUI

/// Row builders for keyframable text values. `write` hands the caller's Animated value to the edit.
@MainActor struct TextRows {
    let state: EditorState

    typealias Writer<V: Interpolatable> = (inout TextData, (inout Animated<V>) -> Void) -> Void

    func number(_ title: String, _ a: Animated<Double>, _ range: ClosedRange<Double>, unit: String = "", step: Double = 0,
                beyond: Bool = false, _ write: @escaping Writer<Double>) -> some View {
        let t = state.currentTime
        let st = state
        return TSNumberRow(title: title, value: a.value(at: t), range: range, step: step, unit: unit, allowBeyond: beyond,
                           key: (a.hasKeyframe(at: t), a.isAnimated, { st.editText("Keyframe \(title)") { td in write(&td) { $0.toggleKeyframe(at: t) } } }),
                           onBegin: { st.beginEdit(title) },
                           onChange: { v in st.editTextContinuous { td in write(&td) { $0.set(v, at: t) } } },
                           onEnd: { st.endEdit() })
    }

    func color(_ title: String, _ a: Animated<RGBA>, _ write: @escaping Writer<RGBA>) -> some View {
        let t = state.currentTime
        let st = state
        return TSColorRow(title: title, color: a.value(at: t),
                          key: (a.hasKeyframe(at: t), a.isAnimated, { st.editText("Keyframe \(title)") { td in write(&td) { $0.toggleKeyframe(at: t) } } })) { c in
            st.beginEdit(title)
            st.editTextContinuous { td in write(&td) { $0.set(c, at: t) } }
            st.endEdit()
        }
    }

    /// Plain number (not keyframable).
    func plain(_ title: String, _ value: Double, _ range: ClosedRange<Double>, unit: String = "", step: Double = 0,
               beyond: Bool = false, _ set: @escaping (inout TextData, Double) -> Void) -> some View {
        let st = state
        return TSNumberRow(title: title, value: value, range: range, step: step, unit: unit, allowBeyond: beyond, key: nil,
                           onBegin: { st.beginEdit(title) }, onChange: { v in st.editTextContinuous { set(&$0, v) } }, onEnd: { st.endEdit() })
    }
}

/// Style stack edits addressed by layer id (robust to reordering while a card is on screen).
@MainActor enum TextStyleOps {
    static func withStyle(_ td: inout TextData, _ change: (inout TextStyleStack) -> Void) {
        var s = td.style ?? TextStyleStack()
        change(&s)
        td.style = s.isEmpty ? nil : s
    }
    static func fill(_ td: inout TextData, _ id: UUID, _ change: (inout TextFillLayer) -> Void) {
        withStyle(&td) { s in if let i = s.fills.firstIndex(where: { $0.id == id }) { change(&s.fills[i]) } }
    }
    static func stroke(_ td: inout TextData, _ id: UUID, _ change: (inout TextStrokeLayer) -> Void) {
        withStyle(&td) { s in if let i = s.strokes.firstIndex(where: { $0.id == id }) { change(&s.strokes[i]) } }
    }
    static func shadow(_ td: inout TextData, _ id: UUID, _ change: (inout TextShadowLayer) -> Void) {
        withStyle(&td) { s in if let i = s.shadows.firstIndex(where: { $0.id == id }) { change(&s.shadows[i]) } }
    }
    static func glow(_ td: inout TextData, _ change: (inout TextGlowLayer) -> Void) {
        withStyle(&td) { s in if var g = s.glow { change(&g); s.glow = g } }
    }

    /// Moves an element of an id-keyed array up/down.
    static func move<T: Identifiable>(_ a: inout [T], _ id: T.ID, by d: Int) where T.ID == UUID {
        guard let i = a.firstIndex(where: { $0.id == id }) else { return }
        let j = max(0, min(a.count - 1, i + d))
        guard i != j else { return }
        let x = a.remove(at: i); a.insert(x, at: j)
    }
}

/// Style tab: font, size, spacing, paragraph, the selected letters and the style stack.
struct TextStyleTab: View {
    @ObservedObject var state: EditorState
    @ObservedObject var session = TextStudioSession.shared
    @State private var fontsFor: FontTarget?

    enum FontTarget: Identifiable { case text, selection; var id: Int { self == .text ? 0 : 1 } }

    private var rows: TextRows { TextRows(state: state) }

    var body: some View {
        if let text = state.selectedLayer?.text {
            VStack(alignment: .leading, spacing: 8) {
                fontButton(text)
                basics(text)
                if session.hasSelection, let r = TextStudioLogic.range(text, ids: session.selectedIDs) { selectionCard(text, r) }
                styleStack(text)
                paragraph(text)
                CounterEditor(state: state, text: text)
            }
            .sheet(item: $fontsFor) { target in
                FontPicker(current: target == .text ? text.fontName : (selectionFont(text) ?? text.fontName), sample: text.string) { name in
                    if target == .text { state.editText("Font") { $0.fontName = name } }
                    else {
                        let ids = session.selectedIDs
                        state.editText("Letter Font") { td in
                            if let r = TextStudioLogic.range(td, ids: ids) { td.setCharStyle(r) { $0.fontName = name == td.fontName ? nil : name } }
                        }
                    }
                }
            }
        }
    }

    private func selectionFont(_ text: TextData) -> String? {
        session.selectedIDs.first.flatMap { text.charStyles?[$0]?.fontName }
    }

    // MARK: Font + basics

    private func fontButton(_ text: TextData) -> some View {
        Button { fontsFor = .text } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FONT").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textDim)
                    Text(FontLibrary.displayName(text.fontName)).font(.custom(text.fontName, size: 20)).foregroundStyle(Theme.text)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textDim)
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Font")
    }

    @ViewBuilder private func basics(_ text: TextData) -> some View {
        rows.plain("Size", text.fontSize, 8...600, unit: "px", step: 1, beyond: true) { $0.fontSize = min(4000, max(1, $1)) }
        if text.style?.fills.isEmpty ?? true {
            rows.color("Fill", text.fill) { td, f in f(&td.fill) }
        } else {
            Text("Letters are filled by the Fill layers below.").font(.caption).foregroundStyle(Theme.textDim)
        }
        rows.number("Tracking", text.tracking, -50...300, unit: "px", beyond: true) { td, f in f(&td.tracking) }
        rows.number("Line Height", text.lineSpacing, 0.6...3) { td, f in f(&td.lineSpacing) }
        rows.number("Baseline Shift", text.baselineShift ?? Animated(0), -300...300, unit: "px", beyond: true) { td, f in
            var a = td.baselineShift ?? Animated(0); f(&a); td.baselineShift = a
        }
        TSSegmented(options: [(TextAlignment.left, "Left"), (.center, "Center"), (.right, "Right")], selection: text.alignment, label: "Align") { a in
            state.editText("Align") { $0.alignment = a }
        }
        TSMenuRow(title: "Spacing grows from", options: [(-1, "Alignment"), (0, "Left"), (1, "Center"), (2, "Right")],
                  selection: text.spacingAnchor ?? -1) { v in state.editText("Spacing Anchor") { $0.spacingAnchor = v < 0 ? nil : v } }
    }

    // MARK: Selected letters

    private func selectionCard(_ text: TextData, _ r: Range<Int>) -> some View {
        let ids = session.selectedIDs
        let cs = text.charStyle(at: r.lowerBound) ?? TextCharStyle()
        let letters = TextStudioLogic.letters(text, ids: ids)
        let shown = letters.count > 20 ? String(letters.prefix(20)) + "…" : letters
        return TSCard(title: "Selected: “\(shown)”",
                      subtitle: "Only these letters change. Drag them on the canvas to move them.") {
            TSIconButton(icon: "arrow.uturn.backward", label: "Reset Selected Letters", tint: Theme.danger) {
                setLetters(ids, "Reset Letters") { $0 = TextCharStyle() }
            }
            TSIconButton(icon: "xmark", label: "Deselect Letters") { session.selectedIDs = [] }
        } content: {
            TSColorRow(title: "Color", color: cs.fill ?? text.fill.value(at: state.currentTime)) { c in setLetters(ids, "Letter Color") { $0.fill = c } }
            letterScrub(ids, "Size", cs.sizePercent ?? 100, 10...400, unit: "%") { s, v in s.sizePercent = abs(v - 100) < 0.5 ? nil : v }
            letterScrub(ids, "Raise", cs.baselineShift ?? 0, -300...300, unit: "px") { s, v in s.baselineShift = abs(v) < 0.01 ? nil : v }
            TSColorRow(title: "Stroke Color", color: cs.strokeColor ?? .black) { c in setLetters(ids, "Letter Stroke") { $0.strokeColor = c } }
            letterScrub(ids, "Stroke Width", cs.strokeWidth ?? 0, 0...60, unit: "px") { s, v in s.strokeWidth = v < 0.01 ? nil : v }
            TSButton(title: "Font: " + FontLibrary.displayName(cs.fontName ?? text.fontName), icon: "textformat") { fontsFor = .selection }
        }
    }

    private func setLetters(_ ids: [UInt32], _ label: String, _ change: @escaping (inout TextCharStyle) -> Void) {
        state.editText(label) { td in if let rr = TextStudioLogic.range(td, ids: ids) { td.setCharStyle(rr, change) } }
    }

    private func letterScrub(_ ids: [UInt32], _ title: String, _ v: Double, _ range: ClosedRange<Double>, unit: String,
                             _ change: @escaping (inout TextCharStyle, Double) -> Void) -> some View {
        rows.plain(title, v, range, unit: unit, beyond: true) { td, x in
            if let rr = TextStudioLogic.range(td, ids: ids) { td.setCharStyle(rr) { change(&$0, x) } }
        }
    }

    // MARK: Style stack

    @ViewBuilder private func styleStack(_ text: TextData) -> some View {
        let style = text.style ?? TextStyleStack()
        HStack(spacing: 8) {
            TSSection(title: "Style Layers")
            Menu {
                Button("Solid Fill") { addFill(text, .solid) }
                Button("Linear Gradient Fill") { addFill(text, .linear) }
                Button("Radial Gradient Fill") { addFill(text, .radial) }
                Button("Stroke") { addStroke(text) }
                Button("Drop Shadow") { addShadow(.drop) }
                Button("Inner Shadow") { addShadow(.inner) }
                Button("Glow") { state.editText("Add Glow") { td in TextStyleOps.withStyle(&td) { s in if s.glow == nil { s.glow = TextGlowLayer() } } } }
                    .disabled(style.glow != nil)
            } label: {
                Label("Add Layer", systemImage: "plus.circle.fill").font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).frame(minHeight: TS.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                    .foregroundStyle(Theme.accentGlow)
            }
            .accessibilityLabel("Add Style Layer")
        }
        if style.isEmpty {
            Text("Stack fills, gradients, strokes (stroke on stroke), shadows and a glow. Every value keyframes.")
                .font(.caption).foregroundStyle(Theme.textDim)
        }
        ForEach(Array(style.fills.enumerated()), id: \.element.id) { k, f in fillCard(f, k, count: style.fills.count) }
        ForEach(Array(style.strokes.enumerated()), id: \.element.id) { k, s in strokeCard(s, k, count: style.strokes.count) }
        ForEach(Array(style.shadows.enumerated()), id: \.element.id) { k, s in shadowCard(s, k) }
        if let g = style.glow { glowCard(g) }
    }

    private func addFill(_ text: TextData, _ kind: TextFillKind) {
        let base = text.fill.value(at: state.currentTime)
        state.editText("Add Fill") { td in
            TextStyleOps.withStyle(&td) { s in
                let colors: [RGBA] = kind == .solid ? [base] : [base, RGBA(hex: 0x9B5CFF)]
                s.fills.append(TextFillLayer(kind: kind, colors: colors))
            }
        }
    }

    private func addStroke(_ text: TextData) {
        let last = text.style?.strokes.last?.width.value(at: state.currentTime)
        let palette: [RGBA] = [.black, .white, RGBA(hex: 0xFF2D6F), RGBA(hex: 0x5CC8FF)]
        state.editText("Add Stroke") { td in
            TextStyleOps.withStyle(&td) { s in
                // Stroke on stroke: each new one sits behind and reaches further.
                s.strokes.append(TextStrokeLayer(color: palette[s.strokes.count % palette.count], width: (last ?? 0) + 6))
            }
        }
    }

    private func addShadow(_ kind: TextShadowKind) {
        state.editText(kind == .drop ? "Add Drop Shadow" : "Add Inner Shadow") { td in
            TextStyleOps.withStyle(&td) { s in s.shadows.append(TextShadowLayer(kind: kind)) }
        }
    }

    private func layerMenu(_ label: String, up: @escaping () -> Void, down: @escaping () -> Void, remove: @escaping () -> Void) -> some View {
        Menu {
            Button { up() } label: { Label("Move Up", systemImage: "arrow.up") }
            Button { down() } label: { Label("Move Down", systemImage: "arrow.down") }
            Button(role: .destructive) { remove() } label: { Label("Remove", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold))
                .frame(width: TS.tap, height: TS.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .foregroundStyle(Theme.text)
        }
        .accessibilityLabel("\(label) Options")
    }

    private func fillCard(_ f: TextFillLayer, _ k: Int, count: Int) -> some View {
        let id = f.id
        let t = state.currentTime
        return TSCard(title: f.name ?? "Fill \(k + 1)", subtitle: f.kind.title + (f.group != nil ? " · from preset" : "")) {
            TSIconButton(icon: f.isEnabled ? "eye" : "eye.slash", label: "Show Fill \(k + 1)", active: f.isEnabled) {
                state.editText("Toggle Fill") { TextStyleOps.fill(&$0, id) { $0.isEnabled.toggle() } }
            }
            layerMenu("Fill \(k + 1)", up: { state.editText("Move Fill") { td in TextStyleOps.withStyle(&td) { TextStyleOps.move(&$0.fills, id, by: -1) } } },
                      down: { state.editText("Move Fill") { td in TextStyleOps.withStyle(&td) { TextStyleOps.move(&$0.fills, id, by: 1) } } },
                      remove: { state.editText("Remove Fill") { td in TextStyleOps.withStyle(&td) { $0.fills.removeAll { $0.id == id } } } })
        } content: {
            TSMenuRow(title: "Type", options: TextFillKind.allCases.map { ($0, $0.title) }, selection: f.kind) { kind in
                state.editText("Fill Type") { TextStyleOps.fill(&$0, id) { l in
                    l.kind = kind
                    if kind != .solid && l.colors.count < 2 { l.colors.append(Animated(RGBA(hex: 0x9B5CFF))) }
                } }
            }
            if f.kind != .solid {
                TSMenuRow(title: "Measured", options: TextGradientSpace.allCases.map { ($0, $0.title) }, selection: f.space) { sp in
                    state.editText("Gradient Space") { TextStyleOps.fill(&$0, id) { $0.space = sp } }
                }
            }
            ForEach(Array(f.colors.enumerated()).prefix(f.kind == .solid ? 1 : 4), id: \.offset) { ci, c in
                HStack(spacing: 4) {
                    TSDiamond(filled: c.hasKeyframe(at: t), animated: c.isAnimated, label: "Color \(ci + 1)") {
                        state.editText("Keyframe Color") { TextStyleOps.fill(&$0, id) { l in if ci < l.colors.count { l.colors[ci].toggleKeyframe(at: t) } } }
                    }
                    TSLabel(text: f.kind == .solid ? "Color" : "Color \(ci + 1)")
                    AWIColorWell("", selection: Binding(get: { Color(c.value(at: t)) }, set: { col in
                        let v = col.rgba
                        state.coalescedEdit("Fill Color") { l in
                            if l.text != nil { TextStyleOps.fill(&l.text!, id) { fl in if ci < fl.colors.count { fl.colors[ci].set(v, at: t) } } }
                        }
                    })).labelsHidden().accessibilityLabel("Fill Color \(ci + 1)")
                    Spacer(minLength: 0)
                    if f.kind != .solid && f.colors.count > 2 {
                        TSIconButton(icon: "minus.circle", label: "Remove Color \(ci + 1)", tint: Theme.danger) {
                            state.editText("Remove Color Stop") { TextStyleOps.fill(&$0, id) { l in
                                guard ci < l.colors.count, l.colors.count > 2 else { return }
                                l.colors.remove(at: ci)
                                if var st = l.stops, ci < st.count { st.remove(at: ci); l.stops = st.count == l.colors.count ? st : nil }
                            } }
                        }
                    }
                }
                if f.kind != .solid {
                    let n = max(2, f.colors.count)
                    let pos = (f.stops.flatMap { ci < $0.count ? $0[ci] : nil } ?? Double(ci) / Double(n - 1)) * 100
                    rows.plain("Stop \(ci + 1) at", pos, 0...100, unit: "%") { td, v in
                        TextStyleOps.fill(&td, id) { l in
                            let m = max(2, l.colors.count)
                            var st = l.stops ?? (0..<m).map { Double($0) / Double(m - 1) }
                            while st.count < l.colors.count { st.append(1) }
                            if ci < st.count { st[ci] = min(1, max(0, v / 100)) }
                            l.stops = st
                        }
                    }
                }
            }
            if f.kind != .solid && f.colors.count < 4 {
                TSButton(title: "Add Color Stop", icon: "plus") {
                    state.editText("Add Color Stop") { TextStyleOps.fill(&$0, id) { l in
                        l.colors.append(Animated(RGBA.white)); if l.stops != nil { l.stops?.append(1) }
                    } }
                }
            }
            if f.kind == .linear {
                rows.number("Angle", f.angle, -180...360, unit: "°", beyond: true) { td, w in TextStyleOps.fill(&td, id) { w(&$0.angle) } }
            }
            if f.kind == .radial {
                rows.number("Radial Size", f.radialScale ?? Animated(100), 10...300, unit: "%") { td, w in
                    TextStyleOps.fill(&td, id) { l in var a = l.radialScale ?? Animated(100); w(&a); l.radialScale = a }
                }
            }
            rows.number("Opacity", f.opacity, 0...100, unit: "%") { td, w in TextStyleOps.fill(&td, id) { w(&$0.opacity) } }
        }
    }

    private func strokeCard(_ s: TextStrokeLayer, _ k: Int, count: Int) -> some View {
        let id = s.id
        return TSCard(title: s.name ?? "Stroke \(k + 1)", subtitle: (k == 0 ? "Right under the fill" : "Behind stroke \(k)") + (s.group != nil ? " · from preset" : "")) {
            TSIconButton(icon: s.isEnabled ? "eye" : "eye.slash", label: "Show Stroke \(k + 1)", active: s.isEnabled) {
                state.editText("Toggle Stroke") { TextStyleOps.stroke(&$0, id) { $0.isEnabled.toggle() } }
            }
            layerMenu("Stroke \(k + 1)", up: { state.editText("Move Stroke") { td in TextStyleOps.withStyle(&td) { TextStyleOps.move(&$0.strokes, id, by: -1) } } },
                      down: { state.editText("Move Stroke") { td in TextStyleOps.withStyle(&td) { TextStyleOps.move(&$0.strokes, id, by: 1) } } },
                      remove: { state.editText("Remove Stroke") { td in TextStyleOps.withStyle(&td) { $0.strokes.removeAll { $0.id == id } } } })
        } content: {
            rows.color("Color", s.color) { td, w in TextStyleOps.stroke(&td, id) { w(&$0.color) } }
            rows.number("Width", s.width, 0...80, unit: "px", beyond: true) { td, w in TextStyleOps.stroke(&td, id) { w(&$0.width) } }
            rows.number("Opacity", s.opacity, 0...100, unit: "%") { td, w in TextStyleOps.stroke(&td, id) { w(&$0.opacity) } }
            TSMenuRow(title: "Position", options: TextStrokePosition.allCases.map { ($0, $0.title) }, selection: s.position) { p in
                state.editText("Stroke Position") { TextStyleOps.stroke(&$0, id) { $0.position = p } }
            }
            TSMenuRow(title: "Corners", options: TextStrokeJoin.allCases.map { ($0, $0.title) }, selection: s.join) { j in
                state.editText("Stroke Corners") { TextStyleOps.stroke(&$0, id) { $0.join = j } }
            }
        }
    }

    private func shadowCard(_ s: TextShadowLayer, _ k: Int) -> some View {
        let id = s.id
        return TSCard(title: s.kind.title, subtitle: "Shadow \(k + 1)" + (s.group != nil ? " · from preset" : "")) {
            TSIconButton(icon: s.isEnabled ? "eye" : "eye.slash", label: "Show Shadow \(k + 1)", active: s.isEnabled) {
                state.editText("Toggle Shadow") { TextStyleOps.shadow(&$0, id) { $0.isEnabled.toggle() } }
            }
            layerMenu("Shadow \(k + 1)", up: { state.editText("Move Shadow") { td in TextStyleOps.withStyle(&td) { TextStyleOps.move(&$0.shadows, id, by: -1) } } },
                      down: { state.editText("Move Shadow") { td in TextStyleOps.withStyle(&td) { TextStyleOps.move(&$0.shadows, id, by: 1) } } },
                      remove: { state.editText("Remove Shadow") { td in TextStyleOps.withStyle(&td) { $0.shadows.removeAll { $0.id == id } } } })
        } content: {
            TSSegmented(options: TextShadowKind.allCases.map { ($0, $0 == .drop ? "Drop" : "Inner") }, selection: s.kind, label: "Shadow Type") { kind in
                state.editText("Shadow Type") { TextStyleOps.shadow(&$0, id) { $0.kind = kind } }
            }
            rows.color("Color", s.color) { td, w in TextStyleOps.shadow(&td, id) { w(&$0.color) } }
            rows.number("Opacity", s.opacity, 0...100, unit: "%") { td, w in TextStyleOps.shadow(&td, id) { w(&$0.opacity) } }
            rows.number("Angle", s.angle, -180...360, unit: "°", beyond: true) { td, w in TextStyleOps.shadow(&td, id) { w(&$0.angle) } }
            rows.number("Distance", s.distance, 0...200, unit: "px", beyond: true) { td, w in TextStyleOps.shadow(&td, id) { w(&$0.distance) } }
            rows.number("Blur", s.blur, 0...100, unit: "px") { td, w in TextStyleOps.shadow(&td, id) { w(&$0.blur) } }
        }
    }

    private func glowCard(_ g: TextGlowLayer) -> some View {
        TSCard(title: "Glow", subtitle: g.group != nil ? "From preset" : "Keeps the letters' hue like the light engine") {
            TSIconButton(icon: g.isEnabled ? "eye" : "eye.slash", label: "Show Glow", active: g.isEnabled) {
                state.editText("Toggle Glow") { TextStyleOps.glow(&$0) { $0.isEnabled.toggle() } }
            }
            TSIconButton(icon: "trash", label: "Remove Glow", tint: Theme.danger) {
                state.editText("Remove Glow") { td in TextStyleOps.withStyle(&td) { $0.glow = nil } }
            }
        } content: {
            TSToggleRow(title: "Use each letter's color", isOn: g.useFillColor ?? false) { b in
                state.editText("Glow Color Source") { TextStyleOps.glow(&$0) { $0.useFillColor = b ? true : nil } }
            }
            if !(g.useFillColor ?? false) {
                rows.color("Color", g.color) { td, w in TextStyleOps.glow(&td) { w(&$0.color) } }
            }
            rows.number("Radius", g.radius, 0...200, unit: "px", beyond: true) { td, w in TextStyleOps.glow(&td) { w(&$0.radius) } }
            rows.number("Intensity", g.intensity, 0...400, unit: "%") { td, w in TextStyleOps.glow(&td) { w(&$0.intensity) } }
        }
    }

    // MARK: Paragraph

    @ViewBuilder private func paragraph(_ text: TextData) -> some View {
        let t = state.currentTime
        TSSection(title: "Paragraph")
        TSToggleRow(title: "Text box (wrap lines)", detail: "Lines wrap at the box width.", isOn: text.boxWidth != nil) { on in
            let w = Double(TextEngine.shared.layout(text, time: t).bounds.width)
            state.editText(on ? "Text Box On" : "Text Box Off") { td in
                td.boxWidth = on ? max(200, w.isFinite ? w : 600) : nil
                if !on { td.autoFit = nil }
            }
        }
        if let bw = text.boxWidth {
            rows.plain("Box Width", bw, 40...4000, unit: "px", step: 1, beyond: true) { $0.boxWidth = max(20, $1) }
            TSToggleRow(title: "Auto-fit (shrink instead of wrap)", isOn: text.autoFit ?? false) { b in
                state.editText("Auto-fit") { $0.autoFit = b ? true : nil }
            }
        }
        TSToggleRow(title: "Vertical text", detail: "Columns top to bottom, right to left.", isOn: text.vertical ?? false) { b in
            state.editText("Vertical Text") { $0.vertical = b ? true : nil }
        }
        rows.plain("Outline Only", text.outline ?? 0, 0...40, unit: "px") { $0.outline = $1 > 0.05 ? $1 : nil }
        TSToggleRow(title: "Text on path", detail: "Letters follow this layer's first mask.", isOn: text.onPath ?? false) { b in
            state.editText("Text on Path") { $0.onPath = b ? true : nil; if b && $0.pathOffset == nil { $0.pathOffset = Animated(0) } }
        }
        if text.onPath == true {
            rows.number("Path Offset", text.pathOffset ?? Animated(0), -100...100, unit: "%", beyond: true) { td, w in
                var a = td.pathOffset ?? Animated(0); w(&a); td.pathOffset = a
            }
        }
    }
}

/// Counter / timer text (moved from the old Counter section; same model).
struct CounterEditor: View {
    @ObservedObject var state: EditorState
    let text: TextData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TSSection(title: "Counter / Timer")
            TSToggleRow(title: "Counter / Timer", detail: "The text shows a number that counts.", isOn: text.counter != nil) { on in
                let start = state.selectedLayer?.inPoint ?? 0
                state.editText(on ? "Counter On" : "Counter Off") { td in
                    if on {
                        var c = TextCounter()
                        c.value.insertKeyframe(Keyframe(time: start, value: 0, interpolation: .bezier))
                        c.value.insertKeyframe(Keyframe(time: start + 2, value: 100, interpolation: .bezier))
                        td.counter = c
                    } else { td.counter = nil }
                }
            }
            if let c = text.counter {
                TSSegmented(options: [(TextCounter.Mode.number, "Number"), (.timer, "Timer")], selection: c.mode, label: "Counter Mode") { m in
                    state.editText("Counter Mode") { $0.counter?.mode = m }
                }
                TextRows(state: state).number(c.mode == .timer ? "Seconds" : "Value", c.value, 0...1000, beyond: true) { td, w in
                    if td.counter != nil { w(&td.counter!.value) }
                }
                if c.mode == .number {
                    TextRows(state: state).plain("Decimals", Double(c.decimals), 0...4, step: 1) { $0.counter?.decimals = min(4, max(0, Int($1.rounded()))) }
                    TSToggleRow(title: "Thousands separator (1,000)", isOn: c.separator) { b in state.editText("Separator") { $0.counter?.separator = b } }
                } else {
                    TSSegmented(options: [(0, "00:00"), (1, "00:00:00"), (2, "00:00.00")], selection: c.timerStyle, label: "Timer Style") { s in
                        state.editText("Timer Style") { $0.counter?.timerStyle = s }
                    }
                }
                field("Before", c.prefix) { s in state.editText("Prefix") { $0.counter?.prefix = s } }
                field("After", c.suffix) { s in state.editText("Suffix") { $0.counter?.suffix = s } }
            }
        }
    }

    private func field(_ label: String, _ value: String, _ set: @escaping (String) -> Void) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: TS.tap, height: 1)
            TSLabel(text: label)
            TextField("", text: Binding(get: { value }, set: set))
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                .padding(.horizontal, 10).frame(minHeight: TS.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .accessibilityLabel("Counter \(label)")
        }
    }
}
