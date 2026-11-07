import SwiftUI
import UniformTypeIdentifiers

extension EditorState {
    func addText() {
        mutate("Add Text") { p in
            var l = p.makeLayer(name: "Text \(p.layers.count + 1)", content: .text, size: Vec2(10, 10))
            let size = Double(min(p.width, p.height)) * 0.12
            l.text = TextData(string: "Text", fontSize: size)
            l.text?.ensureCharIDs()
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

    /// Older entry point (AI Link): forwards to the preset library, which adds a removable tagged group and never
    /// deletes the user's own animators.
    func applyTextPreset(_ preset: TextPreset, duration: Double = 1.0) {
        applyLibraryPreset(preset, duration: duration)
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
            Text(preset.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text)
                .lineLimit(2).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .onReceive(timer) { _ in if !frames.isEmpty && !isUITesting { frameIndex += 1 } }
        .onAppear { if frames.isEmpty { TextPresetPreviews.frames(for: preset) { frames = $0 } } }
    }
}

/// Live-rendered looping previews of text presets on a black background.
enum TextPresetPreviews {
    private static var cache: [String: [UIImage]] = [:]
    private static var order: [String] = []
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
            DispatchQueue.main.async {
                // Bounded: the oldest previews are dropped first.
                cache[preset.id] = imgs
                order.removeAll { $0 == preset.id }
                order.append(preset.id)
                while order.count > 60 { cache[order.removeFirst()] = nil }
                completion(imgs)
            }
        }
    }
}

/// Font browser: search, favorites, and every row previews your own text in that font.
struct FontPicker: View {
    let current: String
    var sample: String = ""
    let pick: (String) -> Void
    @State private var query = ""
    @State private var tab = 1
    @State private var showImport = false
    @ObservedObject private var library = FontLibrary.shared
    @AppStorage("awi.favFonts") private var favRaw = ""
    @Environment(\.dismiss) private var dismiss

    private var favorites: [String] { favRaw.split(separator: "|").map(String.init) }
    private var preview: String {
        let s = sample.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return "The quick brown fox" }
        return s.count > 28 ? String(s.prefix(28)) + "…" : s
    }

    private func toggleFavorite(_ ps: String) {
        var f = favorites
        if let i = f.firstIndex(of: ps) { f.remove(at: i) } else { f.insert(ps, at: 0) }
        favRaw = f.joined(separator: "|")
    }

    private func matches(_ name: String) -> Bool { query.isEmpty || name.localizedCaseInsensitiveContains(query) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TSSegmented(options: [(0, "★ Favorites"), (1, "On Device"), (2, "Download")], selection: tab, label: "Fonts") { tab = $0 }
                    .padding(12)
                List {
                    switch tab {
                    case 0:
                        if favorites.isEmpty {
                            Text("Tap ☆ on any font to keep it here.").font(.caption).foregroundStyle(Theme.textDim)
                        }
                        ForEach(favorites.filter(matches), id: \.self) { f in row(f) }
                    case 1:
                        ForEach(TextEngine.availableFonts().filter(matches), id: \.self) { f in row(f) }
                    default:
                        ForEach(FontLibrary.catalog.filter { matches($0.name) || matches($0.style) }) { fam in catalogRow(fam) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Theme.background)
            .searchable(text: $query, prompt: "Search fonts")
            .navigationTitle("Fonts")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showImport = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
                }
            }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.font]) { r in
                if case .success(let u) = r, library.importFont(from: u) { tab = 1 }
            }
        }
    }

    /// [☆] [your text in the font + its name] [✓ when current] — the preview itself is the "use" button.
    private func row(_ f: String) -> some View {
        HStack(spacing: 6) {
            Button { toggleFavorite(f) } label: {
                Image(systemName: favorites.contains(f) ? "star.fill" : "star").foregroundStyle(favorites.contains(f) ? Theme.warning : Theme.textDim)
                    .frame(width: TS.tap, height: TS.tap).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favorites.contains(f) ? "Unfavorite \(f)" : "Favorite \(f)")
            Button { pick(f); dismiss() } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preview).font(.custom(f, size: 22)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.5)
                        Text(FontLibrary.displayName(f)).font(.caption).foregroundStyle(Theme.textDim).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if f == current { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                }
                .frame(minHeight: TS.tap).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Use font \(FontLibrary.displayName(f))")
        }
        .listRowBackground(Theme.surface)
    }

    private func catalogRow(_ fam: FontLibrary.Family) -> some View {
        let ps = library.installed[fam.name]?.first
        return HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ps == nil ? fam.name : preview).font(ps.map { .custom($0, size: 22) } ?? .system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.5)
                Text("\(fam.name) · \(fam.style)").font(.caption).foregroundStyle(Theme.textDim)
            }
            Spacer(minLength: 4)
            if let ps {
                Button("Use") { pick(ps); dismiss() }.buttonStyle(.borderedProminent).tint(Theme.accent).frame(minHeight: TS.tap)
            } else if library.downloading.contains(fam.name) {
                ProgressView().frame(width: TS.tap, height: TS.tap)
            } else {
                Button { library.download(fam.name) } label: {
                    Image(systemName: "arrow.down.circle.fill").font(.title3).frame(width: TS.tap, height: TS.tap)
                }
                .foregroundStyle(Theme.accentGlow)
                .accessibilityLabel("Download \(fam.name)")
            }
        }
        .listRowBackground(Theme.surface)
    }
}
