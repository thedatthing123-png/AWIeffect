import SwiftUI

/// Animate tab: the selected letters (swipe pad), the animator list and each animator's selectors, properties and
/// letter effects.
struct TextAnimateTab: View {
    @ObservedObject var state: EditorState
    @ObservedObject var session = TextStudioSession.shared
    @State private var openID: UUID?
    @State private var splitUnit: TextUnit = .words

    var body: some View {
        if let text = state.selectedLayer?.text {
            VStack(alignment: .leading, spacing: 8) {
                if session.hasSelection, TextStudioLogic.range(text, ids: session.selectedIDs) != nil { selectionCard(text) }
                addRow(text)
                groups(text)
                if text.animators.isEmpty {
                    Text("No animators yet. Add one, pick a preset, or select letters on the canvas and drag them.")
                        .font(.caption).foregroundStyle(Theme.textDim)
                }
                ForEach(Array(text.animators.enumerated()), id: \.element.id) { k, a in
                    AnimatorRow(state: state, animator: a, index: k, count: text.animators.count, open: openID == a.id) {
                        openID = openID == a.id ? nil : a.id
                    }
                    if openID == a.id { AnimatorEditor(state: state, animatorID: a.id) }
                }
                split(text)
            }
        }
    }

    // MARK: Selection

    private func selectionCard(_ text: TextData) -> some View {
        let ids = session.selectedIDs
        let letters = TextStudioLogic.letters(text, ids: ids)
        let shown = letters.count > 20 ? String(letters.prefix(20)) + "…" : letters
        let t = state.currentTime
        let anchorMode = session.dragMovesAnchor
        let current = anchorMode ? TextStudioLogic.selectionAnchor(text, ids: ids, at: t) : TextStudioLogic.selectionOffset(text, ids: ids, at: t)
        return TSCard(title: "Selected: “\(shown)”", subtitle: String(format: "%@ %.0f, %.0f px", anchorMode ? "Anchor" : "Offset", current.x, current.y)) {
            TSIconButton(icon: "xmark", label: "Deselect Letters") { session.selectedIDs = [] }
        } content: {
            TSButton(title: "Animate Selected Letters", icon: "sparkles", filled: true) {
                var made: UUID?
                state.editText("Animate Letters") { td in made = TextStudioLogic.animateSelection(&td, ids: ids, add: .position) }
                openID = made
            }
            TSSegmented(options: [(false, "Move Letters"), (true, "Move Anchor")], selection: anchorMode, label: "Swipe") { session.dragMovesAnchor = $0 }
            SwipePad(hint: anchorMode ? "Swipe to move the letters' pivot" : "Swipe to move the selected letters (writes their animator)",
                     gain: 400, onDelta: { d in
                let tt = state.currentTime
                state.editTextContinuous { td in
                    let dv = Vec2(Double(d.width), Double(d.height))
                    if anchorMode { TextStudioLogic.setSelectionAnchor(&td, ids: ids, to: TextStudioLogic.selectionAnchor(td, ids: ids, at: tt) + dv, at: tt) }
                    else { TextStudioLogic.offsetSelection(&td, ids: ids, by: dv, at: tt) }
                }
            }, begin: { state.beginPanelGesture(anchorMode ? "Move Letter Anchor" : "Move Letters") }, end: { state.endPanelGesture() })
            .frame(height: 96)
            if let i = TextStudioLogic.selectionAnimatorIndex(text, ids: ids) {
                let a = text.animators[i]
                TSButton(title: "Edit “\(a.name)”", icon: "slider.horizontal.3") { openID = a.id }
            }
        }
    }

    // MARK: Add

    private func addRow(_ text: TextData) -> some View {
        HStack(spacing: 8) {
            TSSection(title: "Animators")
            Menu {
                ForEach(Array(templates.enumerated()), id: \.offset) { _, tpl in
                    Button { add(tpl.0, tpl.1) } label: { Label(tpl.0, systemImage: tpl.2) }
                }
                Divider()
                Button { add("Animator", nil) } label: { Label("Empty Animator", systemImage: "plus.square") }
            } label: {
                Label("Add Animator", systemImage: "plus.circle.fill").font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).frame(minHeight: TS.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                    .foregroundStyle(Theme.accentGlow)
            }
            .accessibilityLabel("Add Animator")
        }
    }

    private var templates: [(String, TextPropKey, String)] {
        [("Move", .position, "arrow.up.and.down.and.arrow.left.and.right"), ("Scale", .scale, "arrow.up.left.and.arrow.down.right"),
         ("Turn", .rotation, "arrow.clockwise"), ("Fade", .opacity, "circle.lefthalf.filled"), ("Color", .fill, "paintpalette"),
         ("Spacing", .tracking, "arrow.left.and.right"), ("Skew", .skew, "skew"), ("Blur", .blur, "drop.halffull"),
         ("Glow", .glow, "sun.max"), ("Scramble", .scramble, "textformat.abc"), ("Flip X", .rotationX, "rotate.3d"),
         ("Turn Y", .rotationY, "arrow.triangle.2.circlepath"), ("Depth Z", .positionZ, "square.3.layers.3d.down.right")]
    }

    private func add(_ title: String, _ key: TextPropKey?) {
        var made: UUID?
        state.editText("Add Animator") { t in
            var a = TextAnimator(name: "\(title) \(t.animators.count + 1)")
            if let key { key.add(to: &a.properties) }
            t.animators.append(a)
            made = a.id
        }
        openID = made
    }

    // MARK: Preset groups

    @ViewBuilder private func groups(_ text: TextData) -> some View {
        let gs = TextStudioLogic.presetGroups(text)
        ForEach(gs, id: \.self) { g in
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Theme.accentGlow).frame(width: TS.tap, height: TS.tap)
                VStack(alignment: .leading, spacing: 1) {
                    Text(TextStudioLogic.groupTitle(g)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(text.animators.filter { $0.group == g }.count) preset animators").font(.system(size: 11)).foregroundStyle(Theme.textDim)
                }
                Spacer(minLength: 4)
                Button { state.removeTextPresetGroup(g) } label: {
                    Text("Remove Preset").font(.system(size: 12, weight: .semibold)).padding(.horizontal, 10).frame(minHeight: TS.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface)).foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Preset \(TextStudioLogic.groupTitle(g))")
            }
        }
    }

    // MARK: Split

    @ViewBuilder private func split(_ text: TextData) -> some View {
        let on = text.animators.contains { $0.name.hasPrefix(EditorState.partAnimatorPrefix) }
        TSSection(title: "Split")
        TSSegmented(options: [(TextUnit.words, "Words"), (.characters, "Letters")], selection: splitUnit, label: "Split by") { splitUnit = $0 }
        TSToggleRow(title: "Animate each \(splitUnit == .words ? "word" : "letter") separately",
                    detail: "Every part gets its own animator (move, size, turn, fade). Still one text layer.", isOn: on) { b in
            state.setSplit(b ? splitUnit : nil)
        }
    }
}

/// Collapsed animator row: [enable] [name — tap to open] [options].
struct AnimatorRow: View {
    @ObservedObject var state: EditorState
    let animator: TextAnimator
    let index: Int
    let count: Int
    let open: Bool
    let toggle: () -> Void
    @State private var renaming = false
    @State private var newName = ""

    var body: some View {
        HStack(spacing: 6) {
            TSIconButton(icon: animator.isEnabled ? "eye" : "eye.slash", label: "Enable \(animator.name)", active: animator.isEnabled) {
                state.editText("Toggle Animator") { t in if let i = TextStudioLogic.index(t, animator.id) { t.animators[i].isEnabled.toggle() } }
            }
            Button(action: toggle) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(animator.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        Text(summary).font(.system(size: 11)).foregroundStyle(Theme.textDim).lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").rotationEffect(.degrees(open ? 90 : 0)).foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: TS.tap)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Animator \(animator.name)")
            Menu {
                Button { newName = animator.name; renaming = true } label: { Label("Rename", systemImage: "pencil") }
                Button { move(-1) } label: { Label("Move Up", systemImage: "arrow.up") }.disabled(index == 0)
                Button { move(1) } label: { Label("Move Down", systemImage: "arrow.down") }.disabled(index >= count - 1)
                Button { state.editText("Duplicate Animator") { TextStudioLogic.duplicateAnimator(&$0, animator.id) } } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Button(role: .destructive) { state.editText("Delete Animator") { TextStudioLogic.deleteAnimator(&$0, animator.id) } } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold)).frame(width: TS.tap, height: TS.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface)).foregroundStyle(Theme.text)
            }
            .accessibilityLabel("Animator Options \(animator.name)")
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(open ? Theme.accent.opacity(0.18) : Theme.raised.opacity(0.6)))
        .alert("Rename Animator", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Rename") { let n = newName; state.editText("Rename Animator") { TextStudioLogic.renameAnimator(&$0, animator.id, to: n) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var summary: String {
        let props = TextPropKey.present(in: animator.properties).map(\.title)
        var parts: [String] = []
        if let g = animator.group { parts.append("Preset: " + TextStudioLogic.groupTitle(g)) }
        parts.append(props.isEmpty ? "No properties" : props.prefix(3).joined(separator: ", ") + (props.count > 3 ? " +\(props.count - 3)" : ""))
        if !(animator.letterEffects ?? []).isEmpty { parts.append("\(animator.letterEffects!.count) letter effects") }
        return parts.joined(separator: " · ")
    }

    private func move(_ d: Int) { state.editText(d < 0 ? "Move Animator Up" : "Move Animator Down") { TextStudioLogic.moveAnimator(&$0, animator.id, by: d) } }
}

/// The open animator: name, selectors (with the visual strip), properties and letter effects.
struct AnimatorEditor: View {
    @ObservedObject var state: EditorState
    @ObservedObject var session = TextStudioSession.shared
    let animatorID: UUID
    @State private var showEffects = false

    private var text: TextData? { state.selectedLayer?.text }
    private var animator: TextAnimator? { text.flatMap { t in TextStudioLogic.index(t, animatorID).map { t.animators[$0] } } }

    var body: some View {
        if let text, let a = animator {
            VStack(alignment: .leading, spacing: 8) {
                nameRow(a)
                TSSection(title: "Selectors")
                ForEach(Array(a.allSelectors.enumerated()), id: \.offset) { k, s in
                    SelectorEditor(state: state, animatorID: animatorID, index: k, count: a.allSelectors.count, selector: s, text: text)
                }
                Menu {
                    Button("Range") { addSelector(.range) }
                    Button("Wiggly") { addSelector(.wiggly) }
                    Button("Wave") { addSelector(.wave) }
                    Button("Random") { addSelector(.random) }
                    Button("Beat") { addSelector(.beat) }
                } label: { wideLabel("Add Selector", "plus") }
                .accessibilityLabel("Add Selector")
                propertiesSection(a)
                effectsSection(a)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
            .sheet(isPresented: $showEffects) {
                EffectBrowser(vectorPaths: false) { def in
                    showEffects = false
                    guard !def.isTransformEffect else { return }
                    state.editText("Add Letter Effect") { t in
                        if let i = TextStudioLogic.index(t, animatorID) { t.animators[i].letterEffects = (t.animators[i].letterEffects ?? []) + [def.makeInstance()] }
                    }
                }
            }
        }
    }

    private func wideLabel(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon).font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: TS.tap)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.raised)).foregroundStyle(Theme.accentGlow)
    }

    private func nameRow(_ a: TextAnimator) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: TS.tap, height: 1)
            TSLabel(text: "Name")
            TextField("Animator name", text: Binding(get: { a.name }, set: { n in
                state.coalescedEdit("Rename Animator") { l in if l.text != nil { TextStudioLogic.renameAnimator(&l.text!, animatorID, to: n) } }
            }))
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
            .padding(.horizontal, 10).frame(minHeight: TS.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            .accessibilityLabel("Animator Name")
        }
    }

    private func addSelector(_ k: SelectorKind) { state.editText("Add Selector") { TextStudioLogic.addSelector(&$0, animator: animatorID, kind: k) } }

    // MARK: Properties

    @ViewBuilder private func propertiesSection(_ a: TextAnimator) -> some View {
        HStack(spacing: 8) {
            TSSection(title: "Properties")
            Menu {
                ForEach(TextPropKey.sections, id: \.self) { sec in
                    Section(sec) {
                        ForEach(TextPropKey.allCases.filter { $0.section == sec }) { key in
                            Button(key.title) { state.editText("Add \(key.title)") { TextStudioLogic.addProperty(&$0, animator: animatorID, key) } }
                                .disabled(key.isPresent(a.properties))
                        }
                    }
                }
            } label: {
                Label("Add Property", systemImage: "plus.circle.fill").font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).frame(minHeight: TS.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface)).foregroundStyle(Theme.accentGlow)
            }
            .accessibilityLabel("Add Property")
        }
        let keys = TextPropKey.present(in: a.properties)
        if keys.isEmpty {
            Text("Add a property: it is what the selected letters change to.").font(.caption).foregroundStyle(Theme.textDim)
        }
        ForEach(keys) { key in PropertyEditor(state: state, animatorID: animatorID, key: key, props: a.properties) }
    }

    // MARK: Letter effects

    @ViewBuilder private func effectsSection(_ a: TextAnimator) -> some View {
        TSSection(title: "Letter Effects")
        let fx = a.letterEffects ?? []
        if fx.isEmpty {
            Text("Effects here only hit the letters this animator selects (the selection amount is the mix).")
                .font(.caption).foregroundStyle(Theme.textDim)
        }
        ForEach(fx) { e in LetterEffectCard(state: state, animatorID: animatorID, effect: e) }
        Button { showEffects = true } label: { wideLabel("Add Letter Effect", "wand.and.stars") }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Letter Effect")
    }
}

/// Animator-addressed edits shared by the editors below.
@MainActor struct AnimatorEdits {
    let state: EditorState
    let animatorID: UUID

    func edit(_ label: String, _ change: (inout TextAnimator) -> Void) {
        state.editText(label) { t in if let i = TextStudioLogic.index(t, animatorID) { change(&t.animators[i]) } }
    }

    func live(_ change: (inout TextAnimator) -> Void) {
        state.editTextContinuous { t in if let i = TextStudioLogic.index(t, animatorID) { change(&t.animators[i]) } }
    }
}

/// One selector: kind / based on / mode, the visual strip and every value with a keyframe diamond.
struct SelectorEditor: View {
    @ObservedObject var state: EditorState
    @ObservedObject var session = TextStudioSession.shared
    let animatorID: UUID
    let index: Int
    let count: Int
    let selector: TextSelector
    let text: TextData

    private var ed: AnimatorEdits { AnimatorEdits(state: state, animatorID: animatorID) }

    var body: some View {
        let s = selector
        let k = index
        TSCard(title: "Selector \(k + 1) · \(kindTitle(s.kind))", subtitle: k == 0 ? nil : "Mode: \((s.mode ?? .add).title)") {
            if count > 1 {
                TSIconButton(icon: "trash", label: "Remove Selector \(k + 1)", tint: Theme.danger) {
                    state.editText("Remove Selector") { TextStudioLogic.removeSelector(&$0, animator: animatorID, at: k) }
                }
            }
        } content: {
            TSMenuRow(title: "Kind", options: SelectorKind.allCases.map { ($0, kindTitle($0)) }, selection: s.kind) { v in
                ed.edit("Selector Kind") { $0.setSelector(k) { $0.kind = v } }
            }
            if k > 0 {
                TSMenuRow(title: "Mode", options: SelectorMode.allCases.map { ($0, $0.title) }, selection: s.mode ?? .add) { v in
                    ed.edit("Selector Mode") { $0.setSelector(k) { $0.mode = v } }
                }
            }
            if let ids = s.targetIDs {
                exactLetters(ids)
            } else {
                TSMenuRow(title: "Based On", options: TextUnit.allCases.map { ($0, $0.title) }, selection: s.basedOn) { v in
                    ed.edit("Based On") { $0.setSelector(k) { $0.basedOn = v } }
                }
            }
            SelectorStrip(chars: Array(text.string), ids: text.resolvedCharIDs, selector: s, time: state.currentTime,
                          interactive: s.kind == .range && s.targetIDs == nil,
                          begin: { state.beginPanelGesture("Selector Range") },
                          change: { a, b, o in
                              let t = state.currentTime
                              ed.live { $0.setSelector(k) { sel in
                                  if let a { sel.start.set(a, at: t) }
                                  if let b { sel.end.set(b, at: t) }
                                  if let o { sel.offset.set(o, at: t) }
                              } }
                          },
                          end: { state.endPanelGesture() })
            if s.targetIDs == nil && session.hasSelection {
                TSButton(title: "Target the selected letters", icon: "character.cursor.ibeam") {
                    let ids = session.selectedIDs
                    ed.edit("Target Letters") { $0.setSelector(k) { $0.targetIDs = ids } }
                }
            }
            if s.kind == .range && s.targetIDs == nil {
                rangeValues(s, k)
            } else if s.kind != .range {
                otherValues(s, k)
            }
            number("Amount", s.amount, -100...100, unit: "%", k) { $0.amount }
        }
    }

    private func kindTitle(_ k: SelectorKind) -> String {
        switch k {
        case .range: return "Range"
        case .wiggly: return "Wiggly"
        case .wave: return "Wave"
        case .random: return "Random"
        case .beat: return "Beat"
        }
    }

    @ViewBuilder private func exactLetters(_ ids: [UInt32]) -> some View {
        let l = TextStudioLogic.letters(text, ids: ids)
        Text("Exact letters: “\(l.count > 24 ? String(l.prefix(24)) + "…" : l)”").font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.accentGlow).fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 6) {
            if session.hasSelection {
                TSButton(title: "Use Selected Letters", icon: "character.cursor.ibeam") {
                    let sel = session.selectedIDs
                    ed.edit("Target Letters") { $0.setSelector(index) { $0.targetIDs = sel } }
                }
            }
            TSButton(title: "Use a Range", icon: "slider.horizontal.below.rectangle") {
                let k = index
                ed.edit("Range Selector") { $0.setSelector(k) { $0.targetIDs = nil } }
            }
        }
    }

    @ViewBuilder private func rangeValues(_ s: TextSelector, _ k: Int) -> some View {
        number("Start", s.start, -100...200, unit: "%", k) { $0.start }
        number("End", s.end, -100...200, unit: "%", k) { $0.end }
        number("Offset", s.offset, -200...200, unit: "%", k) { $0.offset }
        TSMenuRow(title: "Shape", options: SelectorShape.allCases.map { ($0, $0.title) }, selection: s.shape) { v in
            ed.edit("Selector Shape") { $0.setSelector(k) { $0.shape = v } }
        }
        optional("Ease High", s.easeHighValue(at: state.currentTime), s.easeHighAnim, -100...100, k, anim: \.easeHighAnim) { $0.easeHigh = $1 }
        optional("Ease Low", s.easeLowValue(at: state.currentTime), s.easeLowAnim, -100...100, k, anim: \.easeLowAnim) { $0.easeLow = $1 }
        TSToggleRow(title: "Randomize Order", isOn: s.randomize) { b in ed.edit("Randomize") { $0.setSelector(k) { $0.randomize = b } } }
        if s.randomize { seedRow(s, k) }
    }

    @ViewBuilder private func otherValues(_ s: TextSelector, _ k: Int) -> some View {
        switch s.kind {
        case .wiggly, .wave:
            number(s.kind == .wave ? "Waves / sec" : "Wiggles / sec", s.frequency, 0...30, unit: "", k) { $0.frequency }
            if s.kind == .wave { number("Letters / wave", s.spread, 1...30, unit: "", k) { $0.spread } }
            if s.kind == .wiggly { seedRow(s, k) }
        case .random:
            seedRow(s, k)
        case .beat:
            optional("Rise (s)", s.beatAttack?.value(at: state.currentTime) ?? 0.03, s.beatAttack, 0...1, k, anim: \.beatAttack) { _, _ in }
            optional("Fall (s)", s.beatDecay?.value(at: state.currentTime) ?? 0.25, s.beatDecay, 0...3, k, anim: \.beatDecay) { _, _ in }
        case .range:
            EmptyView()
        }
        if s.kind != .beat {
            optional("Min Amount", s.minAmountValue(at: state.currentTime), s.minAmountAnim, -100...100, k, anim: \.minAmountAnim) { $0.minAmount = $1 }
            optional("Max Amount", s.maxAmountValue(at: state.currentTime), s.maxAmountAnim, -100...100, k, anim: \.maxAmountAnim) { $0.maxAmount = $1 }
        }
    }

    private func seedRow(_ s: TextSelector, _ k: Int) -> some View {
        optional("Random Seed", Double(s.seedValue(at: state.currentTime)), s.seedAnim, 0...999, k, anim: \.seedAnim) { sel, v in sel.seed = Int(v.rounded()) }
    }

    /// Always-animatable selector value.
    private func number(_ title: String, _ a: Animated<Double>, _ range: ClosedRange<Double>, unit: String, _ k: Int,
                        _ kp: @escaping (TextSelector) -> Animated<Double>) -> some View {
        let t = state.currentTime
        let path = Self.path(title)
        return TSNumberRow(title: title, value: a.value(at: t), range: range, unit: unit, allowBeyond: true,
                           key: (a.hasKeyframe(at: t), a.isAnimated, { ed.edit("Keyframe \(title)") { $0.setSelector(k) { sel in Self.apply(path, &sel) { $0.toggleKeyframe(at: t) } } } }),
                           onBegin: { state.beginEdit(title) },
                           onChange: { v in ed.live { $0.setSelector(k) { sel in Self.apply(path, &sel) { $0.set(v, at: t) } } } },
                           onEnd: { state.endEdit() })
    }

    private static func path(_ title: String) -> WritableKeyPath<TextSelector, Animated<Double>> {
        switch title {
        case "Start": return \.start
        case "End": return \.end
        case "Offset": return \.offset
        case "Amount": return \.amount
        case "Letters / wave": return \.spread
        default: return \.frequency
        }
    }

    private static func apply(_ kp: WritableKeyPath<TextSelector, Animated<Double>>, _ s: inout TextSelector, _ f: (inout Animated<Double>) -> Void) {
        f(&s[keyPath: kp])
    }

    /// Value with a fixed fallback that becomes Animated when keyframed (ease, min / max, seed, beat timing).
    private func optional(_ title: String, _ value: Double, _ anim: Animated<Double>?, _ range: ClosedRange<Double>, _ k: Int,
                          anim kp: WritableKeyPath<TextSelector, Animated<Double>?>,
                          fixed: @escaping (inout TextSelector, Double) -> Void) -> some View {
        let t = state.currentTime
        return TSNumberRow(title: title, value: value, range: range, allowBeyond: false,
                           key: (anim?.hasKeyframe(at: t) ?? false, anim?.isAnimated ?? false, {
                               ed.edit("Keyframe \(title)") { $0.setSelector(k) { sel in
                                   var a = sel[keyPath: kp] ?? Animated(value)
                                   a.toggleKeyframe(at: t)
                                   sel[keyPath: kp] = a
                               } }
                           }),
                           onBegin: { state.beginEdit(title) },
                           onChange: { v in ed.live { $0.setSelector(k) { sel in
                               if sel[keyPath: kp] != nil { sel[keyPath: kp]?.set(v, at: t) }
                               else if Self.hasFixed(kp) { fixed(&sel, v) }
                               else { sel[keyPath: kp] = Animated(v) }
                           } } },
                           onEnd: { state.endEdit() })
    }

    /// Beat timing has no fixed field: it is stored as Animated from the first edit.
    private static func hasFixed(_ kp: WritableKeyPath<TextSelector, Animated<Double>?>) -> Bool {
        kp != \TextSelector.beatAttack && kp != \TextSelector.beatDecay
    }
}

/// The selector drawn over the letters: start / end handles below, offset handle above, falloff curve in between.
struct SelectorStrip: View {
    let chars: [Character]
    let ids: [UInt32]
    let selector: TextSelector
    let time: Double
    let interactive: Bool
    let begin: () -> Void
    /// New start / end / offset (nil = unchanged), percent.
    let change: (Double?, Double?, Double?) -> Void
    let end: () -> Void

    @State private var handle: Handle?
    @State private var base: (start: Double, end: Double, offset: Double)?
    enum Handle { case start, end, offset, pending }

    private var lane: CGFloat { 44 }
    private var mid: CGFloat { 64 }

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let s0 = selector.start.value(at: time), e0 = selector.end.value(at: time), o0 = selector.offset.value(at: time)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in draw(ctx, width: size.width) }
                    .frame(width: w, height: mid)
                    .offset(y: interactive ? lane : 0)
                    .allowsHitTesting(false)
                if interactive {
                    // Offset lane (top).
                    knob("O", x: xFor((s0 + e0) / 2 + o0, w), y: lane / 2, color: Theme.warning)
                    Color.clear.contentShape(Rectangle()).frame(width: w, height: lane)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                            if base == nil { base = (s0, e0, o0); handle = .offset; begin() }
                            guard let b = base else { return }
                            change(nil, nil, b.offset + Double(g.translation.width / w) * 100)
                        }.onEnded { _ in base = nil; handle = nil; end() })
                        .accessibilityLabel("Selector Offset Handle")
                    // Start / end lane (bottom).
                    knob("S", x: xFor(s0 + o0, w), y: lane + mid + lane / 2, color: Theme.ok)
                    knob("E", x: xFor(e0 + o0, w), y: lane + mid + lane / 2, color: Theme.danger)
                    Color.clear.contentShape(Rectangle()).frame(width: w, height: lane).offset(y: lane + mid)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                            if base == nil {
                                base = (s0, e0, o0)
                                let x = Double(g.startLocation.x)
                                let ds = abs(x - Double(xFor(s0 + o0, w))), de = abs(x - Double(xFor(e0 + o0, w)))
                                handle = abs(ds - de) < 6 ? .pending : (ds < de ? .start : .end)
                                begin()
                            }
                            guard let b = base else { return }
                            let dx = Double(g.translation.width)
                            // Handles on top of each other: the drag direction picks (right = End, left = Start).
                            if handle == .pending, abs(dx) > 3 { handle = dx > 0 ? .end : .start }
                            let dp = dx / Double(w) * 100
                            if handle == .start { change(b.start + dp, nil, nil) }
                            else if handle == .end { change(nil, b.end + dp, nil) }
                        }.onEnded { _ in base = nil; handle = nil; end() })
                        .accessibilityLabel("Selector Start and End Handles")
                }
            }
        }
        .frame(height: interactive ? lane * 2 + mid : mid)
    }

    private func xFor(_ percent: Double, _ w: CGFloat) -> CGFloat {
        let p = percent.isFinite ? percent : 0
        return min(w - 10, max(10, CGFloat(p / 100) * w))
    }

    private func knob(_ label: String, x: CGFloat, y: CGFloat, color: Color) -> some View {
        ZStack {
            Circle().fill(color).frame(width: 26, height: 26)
            Text(label).font(.system(size: 11, weight: .heavy)).foregroundStyle(.black)
        }
        .position(x: x, y: y)
        .allowsHitTesting(false)
    }

    /// Amount of letter `i` for this selector alone (−1...1).
    private func amount(_ i: Int, _ units: (indices: [Int], count: Int)) -> Double {
        if let t = selector.targetIDs {
            return i < ids.count && t.contains(ids[i]) ? selector.amount.value(at: time) / 100 : 0
        }
        let u = i < units.indices.count ? units.indices[i] : 0
        let v = SelectorMath.amount(selector, index: u, count: max(1, units.count), time: time)
        return v.isFinite ? v : 0
    }

    private func draw(_ ctx: GraphicsContext, width w: CGFloat) {
        let h = mid
        let n = max(1, chars.count)
        let cell = w / CGFloat(n)
        let base = h - 8, top: CGFloat = 8
        func y(_ v: Double) -> CGFloat { base - CGFloat(max(-0.4, min(1, v))) * (base - top) }
        // Range band.
        if selector.kind == .range && selector.targetIDs == nil {
            let o = selector.offset.value(at: time)
            var a = selector.start.value(at: time) + o, b = selector.end.value(at: time) + o
            if a > b { swap(&a, &b) }
            let r = CGRect(x: CGFloat(a / 100) * w, y: 0, width: CGFloat(max(0, b - a) / 100) * w, height: h)
            ctx.fill(Path(r), with: .color(Theme.accent.opacity(0.16)))
        }
        // Zero line.
        var zero = Path(); zero.move(to: CGPoint(x: 0, y: base)); zero.addLine(to: CGPoint(x: w, y: base))
        ctx.stroke(zero, with: .color(Theme.stroke), lineWidth: 1)
        // Letters, brighter the more they are selected.
        let units = TextStudioLogic.unitIndices(chars, basedOn: selector.basedOn)
        let amounts = chars.indices.map { amount($0, units) }
        let fontSize = min(18, max(8, cell * 0.8))
        for (i, c) in chars.enumerated() {
            let v = amounts[i]
            let shown = c.isWhitespace ? "·" : String(c)
            let col = v > 0.02 ? Theme.accentGlow : Theme.textDim
            ctx.draw(Text(shown).font(.system(size: fontSize, weight: .bold)).foregroundColor(col.opacity(0.35 + 0.65 * min(1, abs(v)))),
                     at: CGPoint(x: cell * (CGFloat(i) + 0.5), y: h / 2))
        }
        // Falloff curve.
        var curve = Path()
        if selector.kind == .range && selector.targetIDs == nil {
            let steps = 120
            let amt = selector.amount.value(at: time) / 100
            for k in 0..<steps {
                let v = SelectorMath.rangeCoverage(selector, unit: k, count: steps, time: time) * amt
                let p = CGPoint(x: (CGFloat(k) + 0.5) / CGFloat(steps) * w, y: y(v))
                if k == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
            }
        } else {
            for (i, v) in amounts.enumerated() {
                let p = CGPoint(x: cell * (CGFloat(i) + 0.5), y: y(v))
                if i == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
            }
        }
        ctx.stroke(curve, with: .color(Theme.keyframe), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
}

/// One animator property: header [title · ease · remove], then its values with keyframe diamonds.
struct PropertyEditor: View {
    @ObservedObject var state: EditorState
    let animatorID: UUID
    let key: TextPropKey
    let props: TextAnimatorProperties

    private var ed: AnimatorEdits { AnimatorEdits(state: state, animatorID: animatorID) }

    var body: some View {
        let t = state.currentTime
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(key.title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Menu {
                    Button("Linear") { setInterp(.linear) }
                    Button("Ease (smooth)") { setInterp(.bezier) }
                    Button("Hold (jump)") { setInterp(.hold) }
                } label: {
                    Label("Ease", systemImage: "point.topleft.down.curvedto.point.bottomright.up").font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10).frame(minHeight: TS.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface)).foregroundStyle(Theme.text)
                }
                .disabled(!key.isAnimated(props))
                .accessibilityLabel("Ease \(key.title)")
                TSIconButton(icon: "minus.circle", label: "Remove \(key.title)", tint: Theme.danger) {
                    ed.edit("Remove \(key.title)") { key.remove(from: &$0.properties) }
                }
            }
            switch key.access {
            case .scalar(let kp):
                if let a = props[keyPath: kp] {
                    TSNumberRow(title: "Value", value: a.value(at: t), range: key.range, unit: key.unit, allowBeyond: key.allowsBeyond,
                                key: (a.hasKeyframe(at: t), a.isAnimated, { ed.edit("Keyframe \(key.title)") { $0.properties[keyPath: kp]?.toggleKeyframe(at: t) } }),
                                onBegin: { state.beginEdit(key.title) },
                                onChange: { v in ed.live { $0.properties[keyPath: kp]?.set(v, at: t) } },
                                onEnd: { state.endEdit() })
                }
            case .vector(let kp):
                if let a = props[keyPath: kp] {
                    let v = a.value(at: t)
                    TSNumberRow(title: "X", value: v.x, range: key.range, unit: key.unit, allowBeyond: true,
                                key: (a.hasKeyframe(at: t), a.isAnimated, { ed.edit("Keyframe \(key.title)") { $0.properties[keyPath: kp]?.toggleKeyframe(at: t) } }),
                                onBegin: { state.beginEdit(key.title) },
                                onChange: { x in ed.live { p in
                                    let y = p.properties[keyPath: kp]?.value(at: t).y ?? v.y
                                    p.properties[keyPath: kp]?.set(Vec2(x, y), at: t)
                                } },
                                onEnd: { state.endEdit() })
                    TSNumberRow(title: "Y", value: v.y, range: key.range, unit: key.unit, allowBeyond: true, key: nil,
                                onBegin: { state.beginEdit(key.title) },
                                onChange: { y in ed.live { p in
                                    let x = p.properties[keyPath: kp]?.value(at: t).x ?? v.x
                                    p.properties[keyPath: kp]?.set(Vec2(x, y), at: t)
                                } },
                                onEnd: { state.endEdit() })
                }
            case .color(let kp):
                if let a = props[keyPath: kp] {
                    TSColorRow(title: "Color", color: a.value(at: t),
                               key: (a.hasKeyframe(at: t), a.isAnimated, { ed.edit("Keyframe \(key.title)") { $0.properties[keyPath: kp]?.toggleKeyframe(at: t) } })) { c in
                        ed.edit(key.title) { $0.properties[keyPath: kp]?.set(c, at: t) }
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.6)))
    }

    private func setInterp(_ i: Interpolation) { ed.edit("Ease \(key.title)") { key.setInterpolation(i, in: &$0.properties) } }
}

/// A letter effect: [enable · name · remove], then its settings.
struct LetterEffectCard: View {
    @ObservedObject var state: EditorState
    let animatorID: UUID
    let effect: EffectInstance

    private var ed: AnimatorEdits { AnimatorEdits(state: state, animatorID: animatorID) }

    var body: some View {
        let def = EffectRegistry.definition(effect.typeID)
        let eid = effect.id
        let t = state.currentTime
        TSCard(title: def?.name ?? effect.typeID, subtitle: "On the selected letters") {
            TSIconButton(icon: effect.isEnabled ? "eye" : "eye.slash", label: "Enable \(def?.name ?? "Effect")", active: effect.isEnabled) {
                ed.edit("Toggle Letter Effect") { a in if let j = a.letterEffects?.firstIndex(where: { $0.id == eid }) { a.letterEffects![j].isEnabled.toggle() } }
            }
            TSIconButton(icon: "trash", label: "Remove \(def?.name ?? "Effect")", tint: Theme.danger) {
                ed.edit("Remove Letter Effect") { a in
                    a.letterEffects?.removeAll { $0.id == eid }
                    if a.letterEffects?.isEmpty ?? false { a.letterEffects = nil }
                }
            }
        } content: {
            ForEach(def?.params ?? []) { pd in param(pd, eid, t) }
        }
    }

    private func set(_ eid: UUID, _ pid: String, live: Bool, _ v: ParamValue) {
        let change: (inout TextAnimator) -> Void = { a in
            if let j = a.letterEffects?.firstIndex(where: { $0.id == eid }) { a.letterEffects![j].params[pid] = v }
        }
        if live { ed.live(change) } else { ed.edit("Letter Effect", change) }
    }

    @ViewBuilder private func param(_ pd: ParamDef, _ eid: UUID, _ t: Double) -> some View {
        let current = effect.params[pd.id] ?? pd.defaultValue
        switch (pd.kind, current) {
        case (.number(let lo, let hi, let step, let unit), .number(let a)):
            TSNumberRow(title: pd.name, value: a.value(at: t), range: lo...max(hi, lo + 1e-6), step: step, unit: unit,
                        key: (a.hasKeyframe(at: t), a.isAnimated, { var b = a; b.toggleKeyframe(at: t); set(eid, pd.id, live: false, .number(b)) }),
                        onBegin: { state.beginEdit(pd.name) },
                        onChange: { v in var b = a; b.set(v, at: t); set(eid, pd.id, live: true, .number(b)) },
                        onEnd: { state.endEdit() })
        case (.angle, .number(let a)):
            TSNumberRow(title: pd.name, value: a.value(at: t), range: -360...360, unit: "°", allowBeyond: true,
                        key: (a.hasKeyframe(at: t), a.isAnimated, { var b = a; b.toggleKeyframe(at: t); set(eid, pd.id, live: false, .number(b)) }),
                        onBegin: { state.beginEdit(pd.name) },
                        onChange: { v in var b = a; b.set(v, at: t); set(eid, pd.id, live: true, .number(b)) },
                        onEnd: { state.endEdit() })
        case (.color, .color(let a)):
            TSColorRow(title: pd.name, color: a.value(at: t),
                       key: (a.hasKeyframe(at: t), a.isAnimated, { var b = a; b.toggleKeyframe(at: t); set(eid, pd.id, live: false, .color(b)) })) { c in
                var b = a; b.set(c, at: t); set(eid, pd.id, live: false, .color(b))
            }
        case (.toggle, .toggle(let on)):
            TSToggleRow(title: pd.name, isOn: on) { b in set(eid, pd.id, live: false, .toggle(b)) }
        case (.choice(let options), .choice(let i)):
            TSMenuRow(title: pd.name, options: options.enumerated().map { ($0.offset, $0.element) }, selection: i) { v in
                set(eid, pd.id, live: false, .choice(v))
            }
        case (.point, .point(let a)):
            let p = a.value(at: t)
            TSNumberRow(title: pd.name + " X", value: p.x, range: -2000...2000, allowBeyond: true,
                        key: (a.hasKeyframe(at: t), a.isAnimated, { var b = a; b.toggleKeyframe(at: t); set(eid, pd.id, live: false, .point(b)) }),
                        onBegin: { state.beginEdit(pd.name) },
                        onChange: { x in var b = a; b.set(Vec2(x, p.y), at: t); set(eid, pd.id, live: true, .point(b)) },
                        onEnd: { state.endEdit() })
            TSNumberRow(title: pd.name + " Y", value: p.y, range: -2000...2000, allowBeyond: true, key: nil,
                        onBegin: { state.beginEdit(pd.name) },
                        onChange: { y in var b = a; b.set(Vec2(p.x, y), at: t); set(eid, pd.id, live: true, .point(b)) },
                        onEnd: { state.endEdit() })
        default:
            EmptyView()
        }
    }
}
