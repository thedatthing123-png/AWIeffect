import SwiftUI
import UniformTypeIdentifiers

extension EditorState {
    func addText() {
        mutate("Add Text") { p in
            var l = p.makeLayer(name: "Text \(p.layers.count + 1)", content: .text, size: Vec2(10, 10))
            let size = Double(min(p.width, p.height)) * 0.12
            l.text = TextData(string: "AWIeffect", fontSize: size)
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .text
    }

    func editText(_ label: String, _ change: (inout TextData) -> Void) {
        guard let i = selectedIndex, project.layers[i].text != nil else { return }
        mutate(label) { p in
            var t = p.layers[i].text!
            change(&t)
            p.layers[i].text = t
        }
    }

    /// Continuous text edit (sliders): wrap with beginEdit/endEdit.
    func editTextContinuous(_ change: (inout TextData) -> Void) {
        guard let i = selectedIndex, project.layers[i].text != nil else { return }
        var p = project
        change(&p.layers[i].text!)
        project = p
    }

    func applyTextPreset(_ preset: TextPreset) {
        guard let l = selectedLayer else { return }
        let start = max(l.inPoint, currentTime)
        editText("Text Preset \(preset.name)") { t in
            t.animators = preset.make(start, 1.0)
        }
    }
}

/// Text Studio panel: content, style, per-word colors, premade animations and animators.
struct TextPanel: View {
    @ObservedObject var state: EditorState
    @State private var tab = 0
    @State private var draft = ""
    @State private var showFonts = false

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Text Studio")
            Picker("", selection: $tab) {
                Text("Text").tag(0); Text("Style").tag(1); Text("Animate").tag(2); Text("Animators").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12).padding(.bottom, 6)
            if let text = state.selectedLayer?.text {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        switch tab {
                        case 0: contentTab(text)
                        case 1: styleTab(text)
                        case 2: presetsTab
                        default: animatorsTab(text)
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
        }
        .onAppear { draft = state.selectedLayer?.text?.string ?? "" }
        .onChange(of: state.selectedLayerID) { _, _ in draft = state.selectedLayer?.text?.string ?? "" }
        .sheet(isPresented: $showFonts) {
            FontPicker(current: state.selectedLayer?.text?.fontName ?? "") { name in
                state.editText("Font") { $0.fontName = name }
                showFonts = false
            }
        }
    }

    // MARK: Text

    private func contentTab(_ text: TextData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Type something", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(10).glass(radius: 10)
                .foregroundStyle(Theme.text)
                .onSubmit(commit)
            HStack {
                Button("Apply Text", action: commit).buttonStyle(PrimaryButtonStyle())
            }
            Text("Tap a word to color just that word:").font(.caption).foregroundStyle(Theme.textDim)
            WordColorChips(state: state, text: text)
        }
    }

    private func commit() {
        let s = draft
        state.editText("Edit Text") { t in
            t.string = s
            let n = s.count
            t.colorSpans = t.colorSpans.filter { $0.start < n }.map { var c = $0; c.end = min(c.end, n); return c }
        }
    }

    // MARK: Style

    private func styleTab(_ text: TextData) -> some View {
        let t = state.currentTime
        return VStack(alignment: .leading, spacing: 10) {
            Button { showFonts = true } label: {
                HStack {
                    Text("Font").foregroundStyle(Theme.textDim)
                    Spacer()
                    Text(text.fontName).font(.custom(text.fontName, size: 16)).foregroundStyle(Theme.text).lineLimit(1)
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textDim)
                }
                .padding(10).glass(radius: 10)
            }
            labeledSlider("Size", value: text.fontSize, range: 8...600) { v in state.editTextContinuous { $0.fontSize = v } }
            labeledSlider("Tracking", value: text.tracking.value(at: t), range: -50...200) { v in
                state.editTextContinuous { $0.tracking.set(v, at: t) }
            }
            labeledSlider("Line Spacing", value: text.lineSpacing.value(at: t), range: 0.6...3) { v in
                state.editTextContinuous { $0.lineSpacing.set(v, at: t) }
            }
            HStack {
                Text("Color").foregroundStyle(Theme.textDim)
                ColorPicker("", selection: Binding(get: { Color(text.fill.value(at: t)) }, set: { c in
                    state.editText("Text Color") { $0.fill.set(c.rgba, at: t) }
                })).labelsHidden()
                Spacer()
                Picker("", selection: Binding(get: { text.alignment }, set: { a in state.editText("Align") { $0.alignment = a } })) {
                    Image(systemName: "text.alignleft").tag(TextAlignment.left)
                    Image(systemName: "text.aligncenter").tag(TextAlignment.center)
                    Image(systemName: "text.alignright").tag(TextAlignment.right)
                }
                .pickerStyle(.segmented).frame(width: 150)
            }
        }
    }

    private func labeledSlider(_ title: String, value: Double, range: ClosedRange<Double>, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 90, alignment: .leading)
            Slider(value: Binding(get: { min(max(value, range.lowerBound), range.upperBound) }, set: { v in
                state.beginEdit(title)
                set(v)
            }), in: range) { e in if !e { state.endEdit() } }
            Text(String(format: "%.1f", value)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accentGlow)
                .frame(width: 48, alignment: .trailing)
        }
    }

    // MARK: Presets

    private var presetsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Premade animations start at the playhead. Every one is built from editable animators.")
                .font(.caption).foregroundStyle(Theme.textDim)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(TextPresets.all) { preset in
                    Button { state.applyTextPreset(preset) } label: { TextPresetTile(preset: preset) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Animators

    private func animatorsTab(_ text: TextData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if text.animators.isEmpty {
                Text("No animators. Pick a premade animation or add one.").font(.caption).foregroundStyle(Theme.textDim)
            }
            ForEach(text.animators) { a in AnimatorCard(state: state, animator: a) }
            Menu {
                Button("Position") { addAnimator { $0.position = Animated(Vec2(0, -60)) } }
                Button("Scale") { addAnimator { $0.scale = Animated(Vec2(0, 0)) } }
                Button("Rotation") { addAnimator { $0.rotation = Animated(90) } }
                Button("Opacity") { addAnimator { $0.opacity = Animated(0) } }
                Button("Fill Color") { addAnimator { $0.fill = Animated(RGBA(hex: 0x9B5CFF)) } }
                Button("Tracking") { addAnimator { $0.tracking = Animated(40) } }
                Button("Skew") { addAnimator { $0.skew = Animated(20) } }
            } label: {
                Label("Add Animator", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accent.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
                    .foregroundStyle(Theme.accentGlow)
            }
        }
    }

    private func addAnimator(_ props: (inout TextAnimatorProperties) -> Void) {
        state.editText("Add Animator") { t in
            var a = TextAnimator(name: "Animator \(t.animators.count + 1)")
            props(&a.properties)
            t.animators.append(a)
        }
    }
}

/// Word chips; tapping one opens a color picker that colors just that word.
struct WordColorChips: View {
    @ObservedObject var state: EditorState
    let text: TextData
    @State private var picked: (start: Int, end: Int)?
    @State private var color = Color(hex: 0x9B5CFF)

    private var words: [(word: String, start: Int, end: Int)] {
        var out: [(String, Int, Int)] = []
        let chars = Array(text.string)
        var i = 0
        while i < chars.count {
            if chars[i].isWhitespace { i += 1; continue }
            var j = i
            while j < chars.count, !chars[j].isWhitespace { j += 1 }
            out.append((String(chars[i..<j]), i, j))
            i = j
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(words.enumerated()), id: \.offset) { _, w in
                        let span = text.colorSpans.first { $0.start == w.start && $0.end == w.end }
                        Button { picked = (w.start, w.end); color = span.map { Color($0.color) } ?? Color(text.fill.staticValue) } label: {
                            Text(w.word).font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(picked?.start == w.start ? Theme.accent.opacity(0.35) : Theme.raised))
                                .foregroundStyle(span.map { Color($0.color) } ?? Theme.text)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let p = picked {
                HStack {
                    ColorPicker("Word color", selection: $color).foregroundStyle(Theme.text)
                    Button("Apply") {
                        let c = color.rgba
                        state.editText("Word Color") { t in
                            t.colorSpans.removeAll { $0.start == p.start && $0.end == p.end }
                            t.colorSpans.append(TextColorSpan(start: p.start, end: p.end, color: c))
                        }
                    }
                    Button("Reset", role: .destructive) {
                        state.editText("Word Color") { t in t.colorSpans.removeAll { $0.start == p.start && $0.end == p.end } }
                    }
                }
                .font(.system(size: 13, weight: .semibold))
            }
        }
    }
}

struct TextPresetTile: View {
    let preset: TextPreset
    @State private var frames: [UIImage] = []
    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 1.0 / 12, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.black)
                if !frames.isEmpty { Image(uiImage: frames[frameIndex % frames.count]).resizable().scaledToFit() }
                else { ProgressView().tint(Theme.accent) }
            }
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(preset.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
        }
        .onReceive(timer) { _ in if !frames.isEmpty { frameIndex += 1 } }
        .onAppear { if frames.isEmpty { TextPresetPreviews.frames(for: preset) { frames = $0 } } }
    }
}

/// Live-rendered looping previews of text presets on a black background.
enum TextPresetPreviews {
    private static var cache: [String: [UIImage]] = [:]
    private static let queue = DispatchQueue(label: "awi.textpreviews", qos: .userInitiated)

    static func project(for preset: TextPreset) -> Project {
        var p = Project.new(name: "tp", width: 320, height: 120, fps: 12, duration: 1.6, background: .black)
        var l = p.makeLayer(name: "t", content: .text, size: Vec2(1, 1))
        l.text = TextData(string: "Text Effect", fontSize: 44)
        l.text?.animators = preset.make(0.1, 1.0)
        p.layers = [l]
        return p
    }

    static func frames(for preset: TextPreset, completion: @escaping ([UIImage]) -> Void) {
        if let c = cache[preset.id] { completion(c); return }
        queue.async {
            guard let r = Renderer.shared else { return }
            let p = project(for: preset)
            let imgs = (0..<19).compactMap { i in
                r.renderImage(project: p, time: Double(i) / 12, maxDimension: 320, mediaURL: { URL(fileURLWithPath: $0) })
            }
            DispatchQueue.main.async { cache[preset.id] = imgs; completion(imgs) }
        }
    }
}

struct AnimatorCard: View {
    @ObservedObject var state: EditorState
    let animator: TextAnimator
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { open.toggle() } label: {
                    Image(systemName: "chevron.right").rotationEffect(.degrees(open ? 90 : 0)).frame(width: 24, height: 28)
                }
                Text(animator.name).font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { edit("Toggle Animator") { $0.isEnabled.toggle() } } label: {
                    Image(systemName: animator.isEnabled ? "eye" : "eye.slash").frame(width: 30, height: 28)
                }
                Button(role: .destructive) {
                    state.editText("Delete Animator") { t in t.animators.removeAll { $0.id == animator.id } }
                } label: { Image(systemName: "trash").frame(width: 30, height: 28) }
            }
            .foregroundStyle(Theme.text)
            if open {
                Picker("Selector", selection: Binding(get: { animator.selector.kind }, set: { k in edit("Selector") { $0.selector.kind = k } })) {
                    Text("Range").tag(SelectorKind.range); Text("Wiggly").tag(SelectorKind.wiggly); Text("Wave").tag(SelectorKind.wave)
                }
                .pickerStyle(.segmented)
                Picker("Based On", selection: Binding(get: { animator.selector.basedOn }, set: { b in edit("Based On") { $0.selector.basedOn = b } })) {
                    ForEach(TextUnit.allCases) { Text($0.title).tag($0) }
                }
                .foregroundStyle(Theme.text)
                if animator.selector.kind == .range {
                    Picker("Shape", selection: Binding(get: { animator.selector.shape }, set: { s in edit("Shape") { $0.selector.shape = s } })) {
                        ForEach(SelectorShape.allCases) { Text($0.title).tag($0) }
                    }
                    slider("Start", animator.selector.start.value(at: state.currentTime), 0...100) { a, v, t in a.selector.start.set(v, at: t) }
                    slider("End", animator.selector.end.value(at: state.currentTime), 0...100) { a, v, t in a.selector.end.set(v, at: t) }
                    slider("Offset", animator.selector.offset.value(at: state.currentTime), -100...100) { a, v, t in a.selector.offset.set(v, at: t) }
                    Toggle("Randomize Order", isOn: Binding(get: { animator.selector.randomize }, set: { b in edit("Randomize") { $0.selector.randomize = b } }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                } else {
                    slider(animator.selector.kind == .wave ? "Waves/sec" : "Wiggles/sec", animator.selector.frequency.value(at: state.currentTime), 0...30) { a, v, t in
                        a.selector.frequency.set(v, at: t)
                    }
                    if animator.selector.kind == .wave {
                        slider("Letters/wave", animator.selector.spread.value(at: state.currentTime), 1...30) { a, v, t in a.selector.spread.set(v, at: t) }
                    }
                }
                slider("Amount", animator.selector.amount.value(at: state.currentTime), -100...100) { a, v, t in a.selector.amount.set(v, at: t) }
                if let pos = animator.properties.position?.value(at: state.currentTime) {
                    slider("Position X", pos.x, -1000...1000) { a, v, t in a.properties.position?.set(Vec2(v, pos.y), at: t) }
                    slider("Position Y", pos.y, -1000...1000) { a, v, t in a.properties.position?.set(Vec2(pos.x, v), at: t) }
                }
                if let sc = animator.properties.scale?.value(at: state.currentTime) {
                    slider("Scale", sc.x, 0...400) { a, v, t in a.properties.scale?.set(Vec2(v, v), at: t) }
                }
                if let r = animator.properties.rotation?.value(at: state.currentTime) {
                    slider("Rotation", r, -720...720) { a, v, t in a.properties.rotation?.set(v, at: t) }
                }
                if let o = animator.properties.opacity?.value(at: state.currentTime) {
                    slider("Opacity", o, 0...100) { a, v, t in a.properties.opacity?.set(v, at: t) }
                }
                if let tr = animator.properties.tracking?.value(at: state.currentTime) {
                    slider("Tracking", tr, -100...400) { a, v, t in a.properties.tracking?.set(v, at: t) }
                }
                if let sk = animator.properties.skew?.value(at: state.currentTime) {
                    slider("Skew", sk, -70...70) { a, v, t in a.properties.skew?.set(v, at: t) }
                }
                if let c = animator.properties.fill?.value(at: state.currentTime) {
                    ColorPicker("Fill Color", selection: Binding(get: { Color(c) }, set: { col in
                        let t = state.currentTime
                        edit("Animator Color") { $0.properties.fill?.set(col.rgba, at: t) }
                    })).foregroundStyle(Theme.text)
                }
            }
        }
        .padding(10).glass(radius: 12)
    }

    private func edit(_ label: String, _ change: (inout TextAnimator) -> Void) {
        state.editText(label) { t in
            if let i = t.animators.firstIndex(where: { $0.id == animator.id }) { change(&t.animators[i]) }
        }
    }

    private func slider(_ title: String, _ value: Double, _ range: ClosedRange<Double>,
                        _ set: @escaping (inout TextAnimator, Double, Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 84, alignment: .leading)
            Slider(value: Binding(get: { min(max(value, range.lowerBound), range.upperBound) }, set: { v in
                state.beginEdit(title)
                let t = state.currentTime
                state.editTextContinuous { td in
                    if let i = td.animators.firstIndex(where: { $0.id == animator.id }) { set(&td.animators[i], v, t) }
                }
            }), in: range) { e in if !e { state.endEdit() } }
            Text(String(format: "%.0f", value)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accentGlow)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

struct FontPicker: View {
    let current: String
    let pick: (String) -> Void
    @State private var query = ""
    @State private var tab = 0
    @State private var showImport = false
    @ObservedObject private var library = FontLibrary.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Library").tag(0); Text("On Device").tag(1)
                }
                .pickerStyle(.segmented).padding(12)
                List {
                    if tab == 0 {
                        ForEach(FontLibrary.catalog.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { fam in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    let ps = library.installed[fam.name]?.first
                                    Text(fam.name).font(ps.map { .custom($0, size: 20) } ?? .system(size: 17, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                    Text(fam.style).font(.caption).foregroundStyle(Theme.textDim)
                                }
                                Spacer()
                                if let ps = library.installed[fam.name]?.first {
                                    Button("Use") { pick(ps) }.buttonStyle(.borderedProminent).tint(Theme.accent)
                                } else if library.downloading.contains(fam.name) {
                                    ProgressView()
                                } else {
                                    Button { library.download(fam.name) } label: { Image(systemName: "arrow.down.circle.fill").font(.title3) }
                                        .foregroundStyle(Theme.accentGlow)
                                }
                            }
                        }
                    } else {
                        ForEach(TextEngine.availableFonts().filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { f in
                            Button { pick(f) } label: {
                                HStack {
                                    Text(f).font(.custom(f, size: 18)).foregroundStyle(Theme.text)
                                    Spacer()
                                    if f == current { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Theme.background)
            .searchable(text: $query)
            .navigationTitle("Fonts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showImport = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
                }
            }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.font]) { r in
                if case .success(let u) = r, library.importFont(from: u) { tab = 1 }
            }
        }
    }
}
