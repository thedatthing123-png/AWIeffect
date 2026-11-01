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
                Menu {
                    Button { state.editText("Duplicate Animator") { t in
                        if let i = t.animators.firstIndex(where: { $0.id == animator.id }) { var c = t.animators[i]; c.id = UUID(); c.name += " copy"; t.animators.insert(c, at: i + 1) }
                    } } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Button { state.editText("Move Animator") { t in
                        if let i = t.animators.firstIndex(where: { $0.id == animator.id }), i > 0 { t.animators.swapAt(i, i - 1) }
                    } } label: { Label("Move Up", systemImage: "arrow.up") }
                    Button(role: .destructive) {
                        state.editText("Delete Animator") { t in t.animators.removeAll { $0.id == animator.id } }
                    } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis").frame(width: 30, height: 28) }
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
                    keyed("Start", animator.selector.start, -100...200, \.selector.start)
                    keyed("End", animator.selector.end, -100...200, \.selector.end)
                    keyed("Offset", animator.selector.offset, -200...200, \.selector.offset)
                    slider("Ease High", animator.selector.easeHigh, -100...100) { a, v, _ in a.selector.easeHigh = v }
                    slider("Ease Low", animator.selector.easeLow, -100...100) { a, v, _ in a.selector.easeLow = v }
                    Toggle("Randomize Order", isOn: Binding(get: { animator.selector.randomize }, set: { b in edit("Randomize") { $0.selector.randomize = b } }))
                        .tint(Theme.accent).foregroundStyle(Theme.text)
                    if animator.selector.randomize {
                        slider("Random Seed", Double(animator.selector.seed), 0...999) { a, v, _ in a.selector.seed = Int(v) }
                    }
                } else {
                    slider(animator.selector.kind == .wave ? "Waves/sec" : "Wiggles/sec", animator.selector.frequency.value(at: state.currentTime), 0...30) { a, v, t in
                        a.selector.frequency.set(v, at: t)
                    }
                    if animator.selector.kind == .wave {
                        slider("Letters/wave", animator.selector.spread.value(at: state.currentTime), 1...30) { a, v, t in a.selector.spread.set(v, at: t) }
                    }
                }
                keyed("Amount", animator.selector.amount, -100...100, \.selector.amount)
                if animator.selector.kind != .range {
                    slider("Min Amount", animator.selector.minAmount, -100...100) { a, v, _ in a.selector.minAmount = v }
                    slider("Max Amount", animator.selector.maxAmount, -100...100) { a, v, _ in a.selector.maxAmount = v }
                }
                Divider().overlay(Theme.stroke)
                HStack {
                    Text("PROPERTIES").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                    Spacer()
                    Menu {
                        prop("Position", animator.properties.position == nil) { $0.position = Animated(Vec2(0, -60)) }
                        prop("Scale", animator.properties.scale == nil) { $0.scale = Animated(Vec2(0, 0)) }
                        prop("Rotation", animator.properties.rotation == nil) { $0.rotation = Animated(90) }
                        prop("Opacity", animator.properties.opacity == nil) { $0.opacity = Animated(0) }
                        prop("Fill Color", animator.properties.fill == nil) { $0.fill = Animated(RGBA(hex: 0x9B5CFF)) }
                        prop("Tracking", animator.properties.tracking == nil) { $0.tracking = Animated(40) }
                        prop("Skew", animator.properties.skew == nil) { $0.skew = Animated(20) }
                        prop("Blur", animator.properties.blur == nil) { $0.blur = Animated(12) }
                        prop("Character Offset", animator.properties.characterOffset == nil) { $0.characterOffset = Animated(10) }
                        prop("Rotation X (3D)", animator.properties.rotationX == nil) { $0.rotationX = Animated(90) }
                        prop("Rotation Y (3D)", animator.properties.rotationY == nil) { $0.rotationY = Animated(90) }
                        prop("Position Z (3D)", animator.properties.positionZ == nil) { $0.positionZ = Animated(400) }
                        prop("Outline", animator.properties.outline == nil) { $0.outline = Animated(4) }
                    } label: {
                        Label("Add Property", systemImage: "plus.circle.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accentGlow)
                    }
                }
                if let pos = animator.properties.position?.value(at: state.currentTime) {
                    slider("Position X", pos.x, -1000...1000) { a, v, t in a.properties.position?.set(Vec2(v, pos.y), at: t) }
                    slider("Position Y", pos.y, -1000...1000) { a, v, t in a.properties.position?.set(Vec2(pos.x, v), at: t) }
                }
                if let sc = animator.properties.scale?.value(at: state.currentTime) {
                    slider("Scale X", sc.x, -400...400) { a, v, t in let y = a.properties.scale?.value(at: t).y ?? v; a.properties.scale?.set(Vec2(v, y), at: t) }
                    slider("Scale Y", sc.y, -400...400) { a, v, t in let x = a.properties.scale?.value(at: t).x ?? v; a.properties.scale?.set(Vec2(x, v), at: t) }
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
                if let v0 = animator.properties.outline?.value(at: state.currentTime) {
                    slider("Outline", v0, 0...40) { a, v, t in a.properties.outline?.set(v, at: t) }
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

    /// Slider with a keyframe diamond (AE stopwatch) for an animatable selector value.
    private func keyed(_ title: String, _ anim: Animated<Double>, _ range: ClosedRange<Double>, _ path: WritableKeyPath<TextAnimator, Animated<Double>>) -> some View {
        let t = state.currentTime
        return HStack(spacing: 4) {
            KeyframeDiamond(filled: anim.hasKeyframe(at: t), animated: anim.isAnimated) {
                edit("Keyframe \(title)") { $0[keyPath: path].toggleKeyframe(at: t) }
            }
            slider(title, anim.value(at: t), range) { a, v, tt in a[keyPath: path].set(v, at: tt) }
        }
    }

    private func prop(_ title: String, _ available: Bool, _ add: @escaping (inout TextAnimatorProperties) -> Void) -> some View {
        Button(title) { edit("Add \(title)") { add(&$0.properties) } }.disabled(!available)
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
