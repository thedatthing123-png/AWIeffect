import SwiftUI

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
        endEdit()
    }

    /// Live text while typing (one undo step for the whole typing session).
    func setTextLive(_ s: String) {
        guard let i = selectedIndex, project.layers[i].text != nil else { return }
        mutate("Type Text") { p in
            p.layers[i].text?.string = s
            let n = s.count
            if var t = p.layers[i].text {
                t.colorSpans = t.colorSpans.filter { $0.start < n }.map { var c = $0; c.end = min(c.end, n); return c }
                p.layers[i].text = t
            }
        }
    }

    /// Prefix of animators the Letters section owns (per-word / per-letter style, split parts).
    static let styleAnimatorPrefix = "✦ "
    static let partAnimatorPrefix = "◆ "

    /// Style just these characters (size, raise, turn, opacity, blur) with a fixed range animator.
    func styleRange(_ start: Int, _ end: Int, _ change: (inout TextAnimatorProperties) -> Void) {
        guard let t = selectedLayer?.text else { return }
        let n = max(1, Array(t.string).count)
        let name = Self.styleAnimatorPrefix + "\(start)-\(end)"
        editTextContinuous { td in
            if let i = td.animators.firstIndex(where: { $0.name == name }) {
                change(&td.animators[i].properties)
            } else {
                var a = TextAnimator(name: name)
                a.selector.basedOn = .characters
                a.selector.shape = .square
                a.selector.start = Animated(Double(start) / Double(n) * 100)
                a.selector.end = Animated(Double(end) / Double(n) * 100)
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
            let parts = TextParts.ranges(t.string, unit: unit)
            let n = max(1, Array(t.string).count)
            for (k, r) in parts.enumerated() {
                var a = TextAnimator(name: Self.partAnimatorPrefix + "\(unit == .words ? "Word" : "Letter") \(k + 1) · \(r.text)")
                a.selector.basedOn = .characters
                a.selector.shape = .square
                a.selector.start = Animated(Double(r.start) / Double(n) * 100)
                a.selector.end = Animated(Double(r.end) / Double(n) * 100)
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

/// Text Studio: one organized panel. A quick bar (type, font, size, color, align) is always on top; below it the
/// sections sit in one scroll with a jump bar, so nothing hides behind tabs. Every change is live.
struct TextPanel: View {
    @ObservedObject var state: EditorState
    @State private var showFonts = false
    @State private var section = "Style"
    @State private var presetCategory = "In"
    @State private var letterUnit: TextUnit = .words
    @State private var picked: TextParts.Part?

    private let sections = ["Style", "Letters", "Animate", "Animators", "Counter", "3D"]

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Text Studio")
            if let text = state.selectedLayer?.text {
                quickBar(text)
                ScrollViewReader { proxy in
                    jumpBar(proxy)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            group("Style") { styleSection(text) }
                            group("Letters") { lettersSection(text) }
                            group("Animate") { animateSection }
                            group("Animators") { animatorsSection(text) }
                            group("Counter") { counterSection(text) }
                            group("3D") { threeDSection }
                        }
                        .padding(.horizontal, 12).padding(.bottom, 18)
                    }
                }
            }
        }
        .awiSheet(isPresented: $showFonts) {
            FontPicker(current: state.selectedLayer?.text?.fontName ?? "") { name in
                state.editText("Font") { $0.fontName = name }
            }
        }
    }

    // MARK: Quick bar

    private func quickBar(_ text: TextData) -> some View {
        let t = state.currentTime
        return HStack(spacing: 6) {
            Button { state.beginTyping() } label: {
                Label("Type", systemImage: "character.cursor.ibeam").font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 10).frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.accent))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Type Text")
            Button { showFonts = true } label: {
                HStack(spacing: 4) {
                    Text(FontLibrary.displayName(text.fontName)).font(.custom(text.fontName, size: 14)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
                .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Font")
            ValueScrubber(value: text.fontSize, range: 8...600, step: 1, unit: "pt", onBegin: { state.beginEdit("Size") },
                          onChange: { v in state.editTextContinuous { $0.fontSize = v } }, onEnd: { state.endEdit() })
                .frame(width: 84)
            AWIColorWell("", selection: Binding(get: { Color(text.fill.value(at: t)) }, set: { c in
                state.coalescedEdit("Text Color") { $0.text?.fill.set(c.rgba, at: t) }
            })).labelsHidden().frame(width: 34)
            Button {
                let next: TextAlignment = text.alignment == .left ? .center : (text.alignment == .center ? .right : .left)
                state.editText("Align") { $0.alignment = next }
            } label: {
                Image(systemName: text.alignment == .left ? "text.alignleft" : (text.alignment == .center ? "text.aligncenter" : "text.alignright"))
                    .font(.system(size: 15, weight: .semibold)).frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface)).foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Alignment")
        }
        .padding(.horizontal, 12).padding(.bottom, 6)
    }

    private func jumpBar(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sections, id: \.self) { s in
                    Button {
                        section = s
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(s, anchor: .top) }
                    } label: {
                        Text(s).font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(Capsule().fill(section == s ? Theme.accent.opacity(0.85) : Theme.raised))
                            .foregroundStyle(section == s ? .white : Theme.text)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 34)
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accentGlow)
            content()
        }
        .id(title)
    }

    // MARK: Style

    private func styleSection(_ text: TextData) -> some View {
        let t = state.currentTime
        let tracked = text.tracking.isAnimated
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                KeyframeDiamond(filled: text.tracking.hasKeyframe(at: t), animated: tracked) {
                    state.editText("Keyframe Spacing") { $0.tracking.toggleKeyframe(at: t) }
                }
                row("Spacing", value: text.tracking.value(at: t), range: -50...300) { v in state.editTextContinuous { $0.tracking.set(v, at: t) } }
            }
            row("Line Height", value: text.lineSpacing.value(at: t), range: 0.6...3) { v in state.editTextContinuous { $0.lineSpacing.set(v, at: t) } }
            HStack(spacing: 6) {
                quickFX("Stroke", "character.textbox", "awi.border")
                quickFX("Glow", "sun.max", "awi.outerGlow")
                quickFX("Shadow", "shadow", "ae.dropShadow")
                quickFX("Deep Glow", "rays", "awi.deepGlow")
            }
            Toggle("Text on Path (follows this layer's first mask)", isOn: Binding(get: { text.onPath ?? false }, set: { b in
                state.editText("Text on Path") { $0.onPath = b ? true : nil; if b && $0.pathOffset == nil { $0.pathOffset = Animated(0) } }
            }))
            .tint(Theme.accent).foregroundStyle(Theme.text).font(.system(size: 13))
            if text.onPath == true {
                row("Path Offset %", value: text.pathOffset?.value(at: t) ?? 0, range: -100...100) { v in
                    state.editTextContinuous { $0.pathOffset = ($0.pathOffset ?? Animated(0)); $0.pathOffset?.set(v, at: t) }
                }
            }
        }
    }

    /// Adds a styling effect in one tap (it shows up in Effects, fully editable).
    private func quickFX(_ title: String, _ icon: String, _ id: String) -> some View {
        let has = state.selectedLayer?.effects.contains { $0.typeID == id } ?? false
        return Button {
            if let d = EffectRegistry.definition(id), !has { state.addEffect(d) }
            else { state.panel = .effects }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(has ? Theme.accent.opacity(0.3) : Theme.raised))
            .foregroundStyle(has ? Theme.accentGlow : Theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func row(_ title: String, value: Double, range: ClosedRange<Double>, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
            ValueScrubber(value: value, range: range, onBegin: { state.beginEdit(title) }, onChange: set, onEnd: { state.endEdit() })
        }
    }

    // MARK: Letters (per word / letter style + split)

    private func lettersSection(_ text: TextData) -> some View {
        let parts = TextParts.ranges(text.string, unit: letterUnit)
        let split = text.animators.contains { $0.name.hasPrefix(EditorState.partAnimatorPrefix) }
        return VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $letterUnit) {
                Text("Words").tag(TextUnit.words); Text("Letters").tag(TextUnit.characters)
            }
            .pickerStyle(.segmented)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, w in
                        let span = text.colorSpans.first { $0.start == w.start && $0.end == w.end }
                        Button { picked = (picked?.start == w.start && picked?.end == w.end) ? nil : w } label: {
                            Text(w.text).font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 11).padding(.vertical, 7)
                                .background(Capsule().fill(picked?.start == w.start && picked?.end == w.end ? Theme.accent.opacity(0.4) : Theme.raised))
                                .foregroundStyle(span.map { Color($0.color) } ?? Theme.text)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let p = picked, p.end <= Array(text.string).count {
                let name = EditorState.styleAnimatorPrefix + "\(p.start)-\(p.end)"
                let props = text.animators.first { $0.name == name }?.properties
                let span = text.colorSpans.first { $0.start == p.start && $0.end == p.end }
                VStack(spacing: 6) {
                    HStack {
                        Text("Color").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
                        AWIColorWell("", selection: Binding(get: { span.map { Color($0.color) } ?? Color(text.fill.value(at: state.currentTime)) }, set: { c in
                            let col = c.rgba
                            state.editText("Letter Color") { t in
                                t.colorSpans.removeAll { $0.start == p.start && $0.end == p.end }
                                t.colorSpans.append(TextColorSpan(start: p.start, end: p.end, color: col))
                            }
                        })).labelsHidden()
                        Spacer()
                        Button("Reset") {
                            state.editText("Reset Letters") { t in
                                t.colorSpans.removeAll { $0.start == p.start && $0.end == p.end }
                                t.animators.removeAll { $0.name == name }
                            }
                        }
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.danger)
                    }
                    row("Size %", value: props?.scale?.staticValue.x ?? 100, range: 10...400) { v in state.styleRange(p.start, p.end) { $0.scale = Animated(Vec2(v, v)) } }
                    row("Raise", value: -(props?.position?.staticValue.y ?? 0), range: -300...300) { v in
                        state.styleRange(p.start, p.end) { $0.position = Animated(Vec2($0.position?.staticValue.x ?? 0, -v)) }
                    }
                    row("Turn", value: props?.rotation?.staticValue ?? 0, range: -180...180) { v in state.styleRange(p.start, p.end) { $0.rotation = Animated(v) } }
                    row("Opacity", value: props?.opacity?.staticValue ?? 100, range: 0...100) { v in state.styleRange(p.start, p.end) { $0.opacity = Animated(v) } }
                    row("Blur", value: props?.blur?.staticValue ?? 0, range: 0...60) { v in state.styleRange(p.start, p.end) { $0.blur = Animated(v) } }
                }
                .padding(8).glass(radius: 10)
            } else {
                Text("Tap a word or letter to give it its own color, size, raise, turn, opacity or blur.")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
            Toggle(isOn: Binding(get: { split }, set: { on in state.setSplit(on ? letterUnit : nil) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Animate each \(letterUnit == .words ? "word" : "letter") separately").font(.system(size: 13, weight: .semibold))
                    Text("Every part gets its own move, size, turn and fade (keyframe them in Animators). Still one text layer.")
                        .font(.system(size: 11)).foregroundStyle(Theme.textDim)
                }
            }
            .tint(Theme.accent).foregroundStyle(Theme.text)
        }
    }

    // MARK: Animate (presets)

    private var animateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Designs").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(TitleStyles.all) { style in
                        Button { state.applyTitleStyle(style) } label: { TitleStyleTile(style: style).frame(width: 112) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 90)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TextPresetPack.categories, id: \.self) { c in
                        Button { presetCategory = c } label: {
                            Text(c).font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 11).padding(.vertical, 6)
                                .background(Capsule().fill(presetCategory == c ? Theme.accent : Theme.raised))
                                .foregroundStyle(presetCategory == c ? .white : Theme.text)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(TextPreset.library.filter { $0.shownCategory == presetCategory }) { preset in
                    Button { state.applyTextPreset(preset) } label: { TextPresetTile(preset: preset) }
                        .buttonStyle(.plain)
                }
            }
            Text("Presets start at the playhead and are made of normal animators: open Animators to tweak them.")
                .font(.caption).foregroundStyle(Theme.textDim)
        }
    }

    // MARK: Animators

    private func animatorsSection(_ text: TextData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(text.animators) { a in AnimatorCard(state: state, animator: a) }
            Text("Add animator").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textDim)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                addTile("Move", "arrow.up.and.down.and.arrow.left.and.right") { $0.position = Animated(Vec2(0, -60)) }
                addTile("Scale", "arrow.up.left.and.arrow.down.right") { $0.scale = Animated(Vec2(0, 0)) }
                addTile("Turn", "arrow.clockwise") { $0.rotation = Animated(90) }
                addTile("Fade", "circle.lefthalf.filled") { $0.opacity = Animated(0) }
                addTile("Color", "paintpalette") { $0.fill = Animated(RGBA(hex: 0x9B5CFF)) }
                addTile("Spacing", "arrow.left.and.right") { $0.tracking = Animated(40) }
                addTile("Skew", "skew") { $0.skew = Animated(20) }
                addTile("Blur", "drop.halffull") { $0.blur = Animated(12) }
                addTile("Scramble", "textformat.abc") { $0.characterOffset = Animated(10) }
                addTile("Flip X", "rotate.3d") { $0.rotationX = Animated(90) }
                addTile("Turn Y", "arrow.triangle.2.circlepath") { $0.rotationY = Animated(90) }
                addTile("Depth Z", "square.3.layers.3d.down.right") { $0.positionZ = Animated(800) }
            }
        }
    }

    private func addTile(_ title: String, _ icon: String, _ props: @escaping (inout TextAnimatorProperties) -> Void) -> some View {
        Button {
            state.editText("Add Animator") { t in
                var a = TextAnimator(name: "\(title) \(t.animators.count + 1)")
                props(&a.properties)
                t.animators.append(a)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(title) animator")
    }

    // MARK: Counter

    private func counterSection(_ text: TextData) -> some View {
        let t = state.currentTime
        return VStack(alignment: .leading, spacing: 8) {
            Toggle("Counter / Timer", isOn: Binding(get: { text.counter != nil }, set: { on in
                let start = state.selectedLayer?.inPoint ?? 0
                state.editText(on ? "Counter On" : "Counter Off") { td in
                    if on {
                        var c = TextCounter()
                        c.value = Animated(0)
                        c.value.insertKeyframe(Keyframe(time: start, value: 0, interpolation: .bezier))
                        c.value.insertKeyframe(Keyframe(time: start + 2, value: 100, interpolation: .bezier))
                        td.counter = c
                    } else { td.counter = nil }
                }
            }))
            .tint(Theme.accent).foregroundStyle(Theme.text).font(.system(size: 13, weight: .semibold))
            if let c = text.counter {
                Picker("", selection: Binding(get: { c.mode }, set: { m in state.editText("Counter Mode") { $0.counter?.mode = m } })) {
                    Text("Number").tag(TextCounter.Mode.number); Text("Timer").tag(TextCounter.Mode.timer)
                }
                .pickerStyle(.segmented)
                HStack(spacing: 6) {
                    KeyframeDiamond(filled: c.value.hasKeyframe(at: t), animated: c.value.isAnimated) {
                        state.editText("Keyframe Counter") { $0.counter?.value.toggleKeyframe(at: t) }
                    }
                    Text(c.mode == .timer ? "Seconds" : "Value").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text).frame(width: 60, alignment: .leading)
                    ValueScrubber(value: c.value.value(at: t), range: 0...1000, onBegin: { state.beginEdit("Counter") },
                                  onChange: { v in state.editTextContinuous { $0.counter?.value.set(v, at: t) } }, onEnd: { state.endEdit() }, allowBeyond: true)
                }
                if c.mode == .number {
                    Stepper("Decimals: \(c.decimals)", value: Binding(get: { c.decimals }, set: { d in state.editText("Decimals") { $0.counter?.decimals = min(4, max(0, d)) } }), in: 0...4)
                        .foregroundStyle(Theme.text).font(.system(size: 13))
                    Toggle("Thousands separator (1,000)", isOn: Binding(get: { c.separator }, set: { b in state.editText("Separator") { $0.counter?.separator = b } }))
                        .tint(Theme.accent).foregroundStyle(Theme.text).font(.system(size: 13))
                } else {
                    Picker("", selection: Binding(get: { c.timerStyle }, set: { s in state.editText("Timer Style") { $0.counter?.timerStyle = s } })) {
                        Text("00:00").tag(0); Text("00:00:00").tag(1); Text("00:00.00").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                HStack(spacing: 6) {
                    fixField("Before", c.prefix) { s in state.editText("Prefix") { $0.counter?.prefix = s } }
                    fixField("After", c.suffix) { s in state.editText("Suffix") { $0.counter?.suffix = s } }
                }
                Text("Keyframe the value, then open Graph to change how fast it counts (ease, bounce…).")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
        }
    }

    private func fixField(_ label: String, _ value: String, _ set: @escaping (String) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textDim)
            TextField("", text: Binding(get: { value }, set: set))
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 10).frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
    }

    // MARK: 3D

    private var threeDSection: some View {
        let l = state.selectedLayer
        let t = state.currentTime
        return VStack(alignment: .leading, spacing: 8) {
            Toggle("3D Text (turns in space, catches lights)", isOn: Binding(get: { l?.is3D ?? false }, set: { on in
                state.beginEdit("3D Text"); state.mutateLayer { $0.is3D = on; if on && $0.extrude.value(at: t) < 1 { $0.extrude = Animated(24) } }; state.endEdit()
            }))
            .tint(Theme.accent).foregroundStyle(Theme.text).font(.system(size: 13, weight: .semibold))
            if l?.is3D == true {
                row("Depth", value: l?.extrude.value(at: t) ?? 0, range: 0...300) { v in state.mutateLayer { $0.extrude.set(v, at: t) } }
                Text("Effects, animators and presets all still work on 3D text. Try the 3D presets in Animate, and Rotate (trackball) in Move & Transform.")
                    .font(.caption).foregroundStyle(Theme.textDim)
                Button { state.makeSelected3DObject() } label: {
                    Label("Make Solid 3D Model (bevel + materials)", systemImage: "cube.fill").font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 38).background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
                        .foregroundStyle(Theme.text)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Typing bar shown above the keyboard while you type on the canvas (the rest of the editor steps aside).
struct TypeBar: View {
    @ObservedObject var state: EditorState
    @State private var draft = ""
    @State private var showFonts = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { showFonts = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "textformat").font(.system(size: 13, weight: .bold))
                        Text(FontLibrary.displayName(state.selectedLayer?.text?.fontName ?? "")).lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10).frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
                    .foregroundStyle(Theme.text)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { focused = false; state.endTyping() } label: {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 34).background(RoundedRectangle(cornerRadius: 9).fill(Theme.accent))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done Typing")
            }
            TextField("Type your text", text: $draft, axis: .vertical)
                .lineLimit(1...3)
                .focused($focused)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 1.5))
                .onChange(of: draft) { _, s in state.setTextLive(s) }
                .accessibilityLabel("Text Input")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.background)
        .onAppear {
            draft = state.selectedLayer?.text?.string ?? ""
            DispatchQueue.main.async { focused = true }
        }
        .awiSheet(isPresented: $showFonts) {
            FontPicker(current: state.selectedLayer?.text?.fontName ?? "") { name in state.editText("Font") { $0.fontName = name } }
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
