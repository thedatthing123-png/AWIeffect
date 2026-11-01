import SwiftUI
import UniformTypeIdentifiers

extension EditorState {
    func addText() {
        mutate("Add Text") { p in
            var l = p.makeLayer(name: "Text \(p.layers.count + 1)", content: .text, size: Vec2(10, 10))
            let size = Double(min(p.width, p.height)) * 0.12
            l.text = TextData(string: "Text", fontSize: size)
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .text
        // Like Alight Motion: a new text starts in typing mode.
        beginTyping()
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
        mutateLayer { l in if l.text != nil { change(&l.text!) } }
    }

    func applyTextPreset(_ preset: TextPreset, duration: Double = 1.0) {
        guard let l = selectedLayer else { return }
        let start = max(l.inPoint, currentTime)
        editText("Text Preset \(preset.name)") { t in
            t.animators = preset.make(start, max(0.05, duration))
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
        .onReceive(timer) { _ in if !frames.isEmpty && !isUITesting { frameIndex += 1 } }
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
                if let bl = animator.properties.blur?.value(at: state.currentTime) {
                    slider("Blur", bl, 0...100) { a, v, t in a.properties.blur?.set(v, at: t) }
                }
                if let co = animator.properties.characterOffset?.value(at: state.currentTime) {
                    slider("Char Offset", co, -40...40) { a, v, t in a.properties.characterOffset?.set(v, at: t) }
                }
                if let v0 = animator.properties.rotationX?.value(at: state.currentTime) {
                    slider("Rotation X", v0, -360...360) { a, v, t in a.properties.rotationX?.set(v, at: t) }
                }
                if let v0 = animator.properties.rotationY?.value(at: state.currentTime) {
                    slider("Rotation Y", v0, -360...360) { a, v, t in a.properties.rotationY?.set(v, at: t) }
                }
                if let v0 = animator.properties.positionZ?.value(at: state.currentTime) {
                    slider("Position Z", v0, -900...5000) { a, v, t in a.properties.positionZ?.set(v, at: t) }
                }
                if let c = animator.properties.fill?.value(at: state.currentTime) {
                    AWIColorWell("Fill Color", selection: Binding(get: { Color(c) }, set: { col in
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
            ValueScrubber(value: value, range: range, onBegin: { state.beginEdit(title) }, onChange: { v in
                let t = state.currentTime
                state.editTextContinuous { td in
                    if let i = td.animators.firstIndex(where: { $0.id == animator.id }) { set(&td.animators[i], v, t) }
                }
            }, onEnd: { state.endEdit() })
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
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
