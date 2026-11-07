import SwiftUI

/// Preset browser for the Text Studio's Presets tab: Animation / Look kinds, category chips, a two-column grid of
/// live previews rendered with the selected layer's own text and font, duration + snap-to-beats, Apply / Remove.
/// Applying adds a removable preset group; the user's own animators and styles are never deleted.
struct TextPresetBrowser: View {
    @ObservedObject var state: EditorState
    /// false when the host already scrolls (the grid then lays out at full height).
    var scrolls: Bool = true

    @State private var kind: TextPresetKind = .animation
    @State private var category = TextPresetLibrary.categories[0]
    @State private var lookCategory = TextPresetLibrary.lookCategories[0]
    @State private var selectedID: String?
    @State private var duration: Double?
    @State private var snapToBeats = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var layer: Layer? { state.selectedLayer.flatMap { $0.text != nil ? $0 : nil } }
    private var previewSource: TextPresetPreviewSource { TextPresetPreviewSource(layer: layer) }
    private var start: Double { max(layer?.inPoint ?? 0, state.currentTime) }
    private var shownDuration: Double {
        if let duration { return duration }
        guard let layer else { return 1 }
        return TextPresetLibrary.defaultDuration(for: layer, start: start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Kind", selection: $kind) {
                ForEach(TextPresetKind.allCases) { k in Text(k.title).tag(k) }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)

            chips
            if kind == .animation { timingControls }
            if scrolls {
                ScrollView(.vertical, showsIndicators: true) { grid.padding(.bottom, 8) }
            } else {
                grid
            }
            actionBar
        }
        .padding(.horizontal, 16)
        .onChange(of: kind) { _, _ in selectedID = nil }
    }

    // MARK: Parts

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let list = kind == .animation ? TextPresetLibrary.categories : TextPresetLibrary.lookCategories
                ForEach(list, id: \.self) { c in
                    let on = kind == .animation ? c == category : c == lookCategory
                    Button {
                        if kind == .animation { category = c } else { lookCategory = c }
                    } label: {
                        Text(c)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(on ? Color.white : Theme.text)
                            .fixedSize()
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(on ? Theme.accent : Theme.raised))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var timingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Duration")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .fixedSize()
                ValueScrubber(value: shownDuration, range: 0.1...6, step: 0.05, unit: "s", onChange: { duration = $0 })
                    .frame(minHeight: 44)
            }
            Toggle(isOn: $snapToBeats) {
                Text("Snap to beats")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .tint(Theme.accent)
            .frame(minHeight: 44)
            .disabled(state.textPresetBeats.isEmpty)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            if kind == .animation {
                ForEach(TextPresetLibrary.presets(in: category)) { p in
                    tile(id: p.id, name: p.name, preview: .animation(p))
                }
            } else {
                ForEach(TextPresetLibrary.looks(in: lookCategory)) { l in
                    tile(id: l.id, name: l.name, preview: .look(l))
                }
            }
        }
    }

    private func tile(id: String, name: String, preview: TextPresetPreviewItem) -> some View {
        let applied = layer.map { TextPresetLibrary.hasGroup(id, in: $0) } ?? false
        return Button { selectedID = selectedID == id ? nil : id } label: {
            TextPresetBrowserTile(item: preview, name: name, source: previewSource,
                                  selected: selectedID == id, applied: applied)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selectedID == id ? .isSelected : [])
    }

    private var actionBar: some View {
        let id = selectedID
        let applied = id.flatMap { g in layer.map { TextPresetLibrary.hasGroup(g, in: $0) } } ?? false
        return HStack(spacing: 10) {
            Button { apply() } label: {
                Label(applied ? "Reapply" : "Apply", systemImage: "wand.and.stars")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(id == nil || layer == nil ? Theme.raised : Theme.accent))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            .disabled(id == nil || layer == nil)

            Button { if let id { state.removeTextPresetGroup(id) } } label: {
                Label("Remove", systemImage: "minus.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.raised))
                    .foregroundStyle(applied ? Theme.danger : Theme.textDim)
            }
            .buttonStyle(.plain)
            .disabled(!applied)
        }
    }

    private func apply() {
        guard let id = selectedID else { return }
        if kind == .animation, let p = TextPresetLibrary.animation(id) {
            state.applyLibraryPreset(p, duration: duration, snapToBeats: snapToBeats)
        } else if let l = TextPresetLibrary.look(id) {
            state.applyTextLook(l)
        }
    }
}

// MARK: - Tile

enum TextPresetPreviewItem {
    case animation(TextPreset)
    case look(TextLookPreset)

    var id: String {
        switch self {
        case .animation(let p): return p.id
        case .look(let l): return l.id
        }
    }
}

/// What the previews draw: the selected layer's own text (first line, trimmed), font and style.
struct TextPresetPreviewSource: Equatable {
    var string: String
    var fontName: String
    var style: TextStyleStack?

    init(layer: Layer?) {
        let raw = layer?.text?.string ?? ""
        let firstLine = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        string = trimmed.isEmpty ? "Text" : String(trimmed.prefix(14))
        fontName = layer?.text?.fontName ?? "Helvetica-Bold"
        style = layer?.text?.style
    }

    var key: String { "\(string)|\(fontName)|\(style.map { "\($0.fills.count).\($0.strokes.count).\($0.shadows.count)" } ?? "-")" }
}

struct TextPresetBrowserTile: View {
    let item: TextPresetPreviewItem
    let name: String
    let source: TextPresetPreviewSource
    var selected = false
    var applied = false
    @State private var frames: [UIImage] = []
    @State private var loadedKey = ""

    private var key: String { item.id + "#" + source.key }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12).fill(Color.black)
                if frames.isEmpty {
                    ProgressView().tint(Theme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if frames.count == 1 || isUITesting {
                    Image(uiImage: frames[0]).resizable().scaledToFit()
                } else {
                    SwiftUI.TimelineView(.periodic(from: .now, by: 1.0 / 12)) { ctx in
                        let i = Int(ctx.date.timeIntervalSinceReferenceDate * 12) % frames.count
                        Image(uiImage: frames[max(0, i)]).resizable().scaledToFit()
                    }
                }
                if applied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.ok)
                        .padding(6)
                }
            }
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.accent : Theme.stroke, lineWidth: selected ? 3 : 1))
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Theme.accentGlow : Theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onAppear(perform: load)
        .onChange(of: key) { _, _ in load() }
    }

    private func load() {
        let k = key
        guard loadedKey != k else { return }
        loadedKey = k
        if let cached = TextPresetBrowserPreviews.cache.get(k) { frames = cached; return }
        frames = []
        TextPresetBrowserPreviews.frames(for: item, source: source, key: k) { imgs in
            if loadedKey == k { frames = imgs }
        }
    }
}

// MARK: - Previews (bounded LRU)

/// Small thread-safe LRU cache.
final class TextPresetLRU<Value> {
    private var store: [String: Value] = [:]
    private var order: [String] = []
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int) { self.capacity = max(1, capacity) }

    func get(_ key: String) -> Value? {
        lock.lock(); defer { lock.unlock() }
        guard let v = store[key] else { return nil }
        if let i = order.firstIndex(of: key) { order.remove(at: i) }
        order.append(key)
        return v
    }

    func set(_ key: String, _ value: Value) {
        lock.lock(); defer { lock.unlock() }
        if store[key] != nil, let i = order.firstIndex(of: key) { order.remove(at: i) }
        store[key] = value
        order.append(key)
        while order.count > capacity { store[order.removeFirst()] = nil }
    }

    var count: Int { lock.lock(); defer { lock.unlock() }; return store.count }
}

enum TextPresetBrowserPreviews {
    static let cache = TextPresetLRU<[UIImage]>(capacity: 48)
    static let frameCount = 20
    static let fps = 12.0
    private static let queue = DispatchQueue(label: "awi.textpresetbrowser", qos: .userInitiated)
    private static var waiting: [String: [([UIImage]) -> Void]] = [:]
    private static let waitLock = NSLock()

    /// Beat markers in preview projects so beat presets pulse.
    static let previewBeats: [Double] = [0.25, 0.75, 1.25]

    /// The preview text layer for a preset (also used by tests).
    static func project(for item: TextPresetPreviewItem, source: TextPresetPreviewSource) -> Project {
        var p = Project.new(name: "tpb", width: 320, height: 160, fps: fps, duration: Double(frameCount) / fps, background: .black)
        p.markers = previewBeats
        var l = p.makeLayer(name: "t", content: .text, size: Vec2(1, 1))
        let size = min(64, 440 / Double(max(3, source.string.count)))
        var t = TextData(string: source.string, fontName: source.fontName, fontSize: size)
        t.style = source.style
        l.text = t
        switch item {
        case .animation(let preset):
            TextPresetLibrary.applyPreset(preset, to: &l, start: 0.15, duration: 1.0)
        case .look(let look):
            TextPresetLibrary.applyLook(look, to: &l)
            l.text?.fontSize = size
            // A gentle intro so look tiles are live too.
            if let intro = TextPresetLibrary.animation("studio.softStagger") {
                TextPresetLibrary.applyPreset(intro, to: &l, start: 0.05, duration: 0.8)
            }
        }
        p.layers = [l]
        return p
    }

    static func frames(for item: TextPresetPreviewItem, source: TextPresetPreviewSource, key: String,
                       completion: @escaping ([UIImage]) -> Void) {
        waitLock.lock()
        if waiting[key] != nil { waiting[key]?.append(completion); waitLock.unlock(); return }
        waiting[key] = [completion]
        waitLock.unlock()
        queue.async {
            var imgs: [UIImage] = cache.get(key) ?? []
            if imgs.isEmpty, let r = Renderer.shared {
                let p = project(for: item, source: source)
                imgs = (0..<frameCount).compactMap { i in
                    r.renderImage(project: p, time: Double(i) / fps, maxDimension: 320, mediaURL: { URL(fileURLWithPath: $0) })
                }
                if !imgs.isEmpty { cache.set(key, imgs) }
            }
            waitLock.lock()
            let done = waiting[key] ?? []
            waiting[key] = nil
            waitLock.unlock()
            DispatchQueue.main.async { done.forEach { $0(imgs) } }
        }
    }
}
