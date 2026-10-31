import SwiftUI
import PhotosUI

/// Image every effect / preset thumbnail renders on. Owner-chosen image (Settings) or a built-in test image.
enum PreviewImage {
    static var userURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("preview-image.jpg")
    }
    static var builtinURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("awi-test-image-v1.png")
    }

    /// The URL to use, generating the built-in test image on first use.
    static func url() -> URL {
        if FileManager.default.fileExists(atPath: userURL.path) { return userURL }
        // The owner's default preview picture ships inside the app.
        if let b = Bundle.main.url(forResource: "default-preview", withExtension: "jpg") { return b }
        if !FileManager.default.fileExists(atPath: builtinURL.path) { generateBuiltin() }
        return builtinURL
    }

    static func setUserImage(_ data: Data) {
        guard let img = UIImage(data: data) else { return }
        // Normalize to a square-ish 720px JPEG so thumbnails stay fast.
        let side: CGFloat = 720
        let s = side / min(img.size.width, img.size.height)
        let size = CGSize(width: img.size.width * s, height: img.size.height * s)
        let out = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            img.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }
        try? out.jpegData(compressionQuality: 0.9)?.write(to: userURL, options: .atomic)
        Renderer.shared?.clearImageCache()
        EffectThumbnails.shared.clear()
    }

    static func resetToBuiltin() {
        try? FileManager.default.removeItem(at: userURL)
        Renderer.shared?.clearImageCache()
        EffectThumbnails.shared.clear()
    }

    /// Procedural test card: sky gradient, sun, mountains, bright shapes and fine detail
    /// so blur, glow, color and distortion effects all read clearly.
    private static func generateBuiltin() {
        let side: CGFloat = 720
        let img = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            let cg = ctx.cgContext
            let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [UIColor(red: 0.16, green: 0.10, blue: 0.35, alpha: 1).cgColor,
                                          UIColor(red: 0.85, green: 0.42, blue: 0.62, alpha: 1).cgColor,
                                          UIColor(red: 1.0, green: 0.78, blue: 0.45, alpha: 1).cgColor] as CFArray,
                                 locations: [0, 0.6, 1])!
            cg.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: side * 0.7), options: [.drawsAfterEndLocation])
            UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: side * 0.58, y: side * 0.22, width: side * 0.22, height: side * 0.22))
            for (i, color) in [UIColor(red: 0.35, green: 0.18, blue: 0.55, alpha: 1), UIColor(red: 0.18, green: 0.09, blue: 0.32, alpha: 1)].enumerated() {
                let path = UIBezierPath()
                let base = side * (0.62 + CGFloat(i) * 0.1)
                path.move(to: CGPoint(x: 0, y: side))
                path.addLine(to: CGPoint(x: 0, y: base))
                for k in 0...8 {
                    let x = side * CGFloat(k) / 8
                    let y = base - (k % 2 == 0 ? 0 : side * (0.12 - CGFloat(i) * 0.04))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: side, y: side))
                path.close()
                color.setFill()
                path.fill()
            }
            // Bright neon stripes for glow, checker detail for blur/sharpness.
            UIColor(red: 0.6, green: 1, blue: 0.95, alpha: 1).setFill()
            cg.fill(CGRect(x: side * 0.08, y: side * 0.12, width: side * 0.3, height: 8))
            UIColor(red: 1, green: 0.4, blue: 0.85, alpha: 1).setFill()
            cg.fill(CGRect(x: side * 0.08, y: side * 0.17, width: side * 0.22, height: 8))
            for y in 0..<6 {
                for x in 0..<6 where (x + y) % 2 == 0 {
                    UIColor.white.setFill()
                    cg.fill(CGRect(x: side * 0.1 + CGFloat(x) * 14, y: side * 0.3 + CGFloat(y) * 14, width: 14, height: 14))
                }
            }
            UIColor(red: 0.1, green: 0.85, blue: 0.3, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: side * 0.4, y: side * 0.4, width: side * 0.12, height: side * 0.12))
        }
        try? img.pngData()?.write(to: builtinURL, options: .atomic)
    }
}

/// Renders and caches effect thumbnails on the preview image.
final class EffectThumbnails {
    static let shared = EffectThumbnails()
    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "awi.thumbnails", qos: .userInitiated)
    private let lock = NSLock()

    func clear() { lock.lock(); cache.removeAll(); lock.unlock() }

    func cached(_ id: String) -> UIImage? { lock.lock(); defer { lock.unlock() }; return cache[id] }

    func thumbnail(for def: EffectDefinition, completion: @escaping (UIImage?) -> Void) {
        if let c = cached(def.id) { completion(c); return }
        queue.async {
            let img = Self.render(def)
            self.lock.lock(); self.cache[def.id] = img; self.lock.unlock()
            DispatchQueue.main.async { completion(img) }
        }
    }

    // Animated previews (looping GIF-like frames), kept for the most recently viewed effects.
    private var frameCache: [String: [UIImage]] = [:]
    private var frameOrder: [String] = []

    func frames(for def: EffectDefinition, completion: @escaping ([UIImage]) -> Void) {
        lock.lock()
        if let f = frameCache[def.id] { lock.unlock(); completion(f); return }
        lock.unlock()
        queue.async {
            guard let r = Renderer.shared else { return }
            let url = PreviewImage.url()
            var p = Self.previewProject(effect: Self.showcase(def))
            p.fps = 12
            let imgs = (0..<14).compactMap { i in r.renderImage(project: p, time: 0.1 + Double(i) / 12, maxDimension: 120, mediaURL: { _ in url }) }
            self.lock.lock()
            self.frameCache[def.id] = imgs; self.frameOrder.append(def.id)
            while self.frameOrder.count > 48 { self.frameCache[self.frameOrder.removeFirst()] = nil }
            self.lock.unlock()
            DispatchQueue.main.async { completion(imgs) }
        }
    }

    static func previewProject(effect: EffectInstance?) -> Project {
        var p = Project.new(name: "thumb", width: 360, height: 360, fps: 30, duration: 2, background: RGBA(0.05, 0.04, 0.08))
        var l = p.makeLayer(name: "img", content: .image(fileName: "preview", pixelWidth: 720, pixelHeight: 720), size: Vec2(720, 720))
        l.transform.scale = Animated(Vec2(50, 50))
        if let effect {
            // Shake shows nothing in a still; give the thumbnail a visible offset frame instead.
            l.effects = [effect]
        }
        p.layers = [l]
        return p
    }

    private static func render(_ def: EffectDefinition) -> UIImage? {
        guard let r = Renderer.shared else { return nil }
        let url = PreviewImage.url()
        let p = previewProject(effect: showcase(def))
        return r.renderImage(project: p, time: 0.37, maxDimension: 180, mediaURL: { _ in url })
    }

    /// Default instance with settings pushed far enough that a still thumbnail shows what the effect does.
    static func showcase(_ def: EffectDefinition) -> EffectInstance {
        var inst = def.makeInstance()
        // Make subtle defaults visible in a thumbnail.
        switch def.id {
        case "ae.gaussianBlur": inst.params["blurriness"] = .number(Animated(14))
        case "ae.exposure": inst.params["exposure"] = .number(Animated(1.2))
        case "ae.brightnessContrast": inst.params["contrast"] = .number(Animated(45))
        case "ae.hueSaturation": inst.params["hue"] = .number(Animated(120))
        case "ae.glow": inst.params["threshold"] = .number(Animated(45)); inst.params["radius"] = .number(Animated(30))
        case "ae.invert": break
        case "ae.levels": inst.params["inBlack"] = .number(Animated(50)); inst.params["inWhite"] = .number(Animated(200))
        case "awi.shake": inst.params["amplitude"] = .number(Animated(40))
        case "ae.curves": inst.params["mids"] = .number(Animated(78))
        case "awi.looks": inst.params["contrast"] = .number(Animated(50)); inst.params["temp"] = .number(Animated(60))
        case "ae.offset": inst.params["shift"] = .point(Animated(Vec2(0.75, 0.5)))
        case "ae.motionTile": inst.params["tileW"] = .number(Animated(40)); inst.params["tileH"] = .number(Animated(40))
        case "ae.turbulentDisplace": inst.params["amount"] = .number(Animated(40)); inst.params["size"] = .number(Animated(60))
        case "awi.saber": inst.params["spread"] = .number(Animated(30))
        case "ae.linearWipe", "ae.radialWipe", "ae.irisWipe", "ae.blockDissolve", "ae.venetianBlinds", "ae.gradientWipe":
            inst.params["completion"] = .number(Animated(45))
        case "ae.cornerPin": inst.params["ul"] = .point(Animated(Vec2(0.15, 0.12))); inst.params["lr"] = .point(Animated(Vec2(0.92, 0.85)))
        case "ae.colorBalance": inst.params["mr"] = .number(Animated(60)); inst.params["sb"] = .number(Animated(50))
        case "ae.strobe": inst.params["duration"] = .number(Animated(0.3))
        default: break
        }
        return inst
    }
}

// MARK: - Effects panel (stack on the selected layer)

struct EffectsPanel: View {
    @ObservedObject var state: EditorState
    @State private var showBrowser = false
    @State private var showFFX = false
    @State private var ffxMessage: String?
    @State private var expanded: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Effects")
            ScrollView {
                VStack(spacing: 8) {
                    Button { showBrowser = true } label: {
                        Label("Add Effect", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.accent.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
                            .foregroundStyle(Theme.accentGlow)
                    }
                    Button { showFFX = true } label: {
                        Label("Apply AE Preset (.ffx)", systemImage: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .glass(radius: 12)
                            .foregroundStyle(Theme.text)
                    }
                    if let m = ffxMessage { Text(m).font(.caption).foregroundStyle(Theme.textDim) }
                    if let layer = state.selectedLayer {
                        if layer.effects.isEmpty {
                            Text(layer.content == .adjustment ? "Effects on an adjustment layer apply to every layer below it."
                                                               : "No effects yet.")
                                .font(.caption).foregroundStyle(Theme.textDim).padding(.top, 6)
                        }
                        ForEach(layer.effects) { e in effectCard(e) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .fileImporter(isPresented: $showFFX, allowedContentTypes: [.ffx, .data]) { result in
            guard case .success(let url) = result else { return }
            if let r = state.applyFFX(url: url) {
                ffxMessage = "Preset: \(r.nativeCount + r.approximateCount) effects applied, \(r.missingCount) not built yet."
            } else {
                ffxMessage = "That file isn't an After Effects preset."
            }
        }
        .sheet(isPresented: $showBrowser) {
            EffectBrowser { def in
                state.addEffect(def)
                showBrowser = false
            }
            .presentationDetents([.large])
        }
    }

    private func effectCard(_ e: EffectInstance) -> some View {
        let def = EffectRegistry.definition(e.typeID)
        let isOpen = expanded.contains(e.id)
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    if isOpen { expanded.remove(e.id) } else { expanded.insert(e.id) }
                } label: {
                    Image(systemName: "chevron.right").rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: 24, height: 30)
                }
                Text(def?.name ?? "Missing effect: \(e.typeID)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(def == nil ? Theme.danger : (e.isEnabled ? Theme.text : Theme.textDim))
                Spacer()
                Button { state.toggleEffect(e.id) } label: {
                    Image(systemName: e.isEnabled ? "eye" : "eye.slash").frame(width: 30, height: 30)
                }
                Menu {
                    Button { state.moveEffect(e.id, up: true) } label: { Label("Move Up", systemImage: "arrow.up") }
                    Button { state.moveEffect(e.id, up: false) } label: { Label("Move Down", systemImage: "arrow.down") }
                    Button { state.duplicateEffect(e.id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Button(role: .destructive) { state.removeEffect(e.id) } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis").frame(width: 30, height: 30) }
            }
            .foregroundStyle(Theme.text)
            if isOpen, let def {
                ForEach(def.params) { pd in ParamRow(state: state, effect: e, def: pd) }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .glass(radius: 12)
        .onAppear { if state.selectedLayer?.effects.last?.id == e.id { expanded.insert(e.id) } }
    }
}

/// One editable effect parameter with keyframe diamond.
struct ParamRow: View {
    @ObservedObject var state: EditorState
    let effect: EffectInstance
    let def: ParamDef

    var body: some View {
        let kf = state.effectParamHasKeyframe(effect.id, def.id)
        let t = state.currentTime
        HStack(spacing: 6) {
            switch def.kind {
            case .toggle, .choice:
                Color.clear.frame(width: 34, height: 30)
            default:
                KeyframeDiamond(filled: kf.filled, animated: kf.animated) { state.toggleEffectKeyframe(effect.id, def.id) }
            }
            Text(def.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                .frame(width: 96, alignment: .leading).lineLimit(2).minimumScaleFactor(0.8)
            control(t: t)
        }
    }

    @ViewBuilder private func control(t: Double) -> some View {
        switch def.kind {
        case .number(let lo, let hi, let step, let unit):
            ValueScrubber(value: effect.number(def.id, t), range: lo...hi, step: step, unit: unit,
                          onBegin: { state.beginEdit("Edit \(def.name)") },
                          onChange: { setNumber($0) }, onEnd: { state.endEdit() })
        case .angle:
            ValueScrubber(value: effect.number(def.id, t), range: -360...360, step: 1, unit: "°",
                          onBegin: { state.beginEdit("Edit \(def.name)") },
                          onChange: { setNumber($0) }, onEnd: { state.endEdit() })
        case .point:
            let v = effect.point(def.id, t)
            NumberField(value: v.x * 100, label: "X%") { nv in setPoint(Vec2(nv / 100, v.y)) }
            NumberField(value: v.y * 100, label: "Y%") { nv in setPoint(Vec2(v.x, nv / 100)) }
        case .color:
            let c = effect.color(def.id, t)
            ColorPicker("", selection: Binding(get: { Color(c) }, set: { col in
                state.beginEdit("Edit \(def.name)")
                state.setEffectParam(effect.id, def.id) { pv, time in
                    if case .color(var a) = pv { a.set(col.rgba, at: time); pv = .color(a) }
                }
                state.endEdit()
            }), supportsOpacity: false).labelsHidden()
            Spacer()
        case .toggle:
            Toggle("", isOn: Binding(get: { effect.bool(def.id) }, set: { b in
                state.beginEdit("Edit \(def.name)")
                state.setEffectParam(effect.id, def.id) { pv, _ in pv = .toggle(b) }
                state.endEdit()
            })).labelsHidden().tint(Theme.accent)
            Spacer()
        case .choice(let options):
            Menu {
                ForEach(options.indices, id: \.self) { i in
                    Button(options[i]) {
                        state.beginEdit("Edit \(def.name)")
                        state.setEffectParam(effect.id, def.id) { pv, _ in pv = .choice(i) }
                        state.endEdit()
                    }
                }
            } label: {
                HStack {
                    Text(options[safe: effect.choice(def.id)] ?? "—").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                }
                .foregroundStyle(Theme.accentGlow)
                .padding(.horizontal, 10).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
            }
            Spacer()
        }
    }

    private func setNumber(_ v: Double) {
        state.setEffectParam(effect.id, def.id) { pv, time in
            if case .number(var a) = pv { a.set(v, at: time); pv = .number(a) }
        }
    }

    private func setPoint(_ v: Vec2) {
        state.beginEdit("Edit \(def.name)")
        state.setEffectParam(effect.id, def.id) { pv, time in
            if case .point(var a) = pv { a.set(v, at: time); pv = .point(a) }
        }
        state.endEdit()
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - Effect browser

struct EffectBrowser: View {
    let pick: (EffectDefinition) -> Void
    @State private var query = ""
    @State private var tab: Tab = .all
    @AppStorage("awi.favEffects") private var favRaw = ""
    @AppStorage("awi.recentEffects") private var recentRaw = ""
    @Environment(\.dismiss) private var dismiss

    enum Tab: Hashable { case all, favorites, recent, section(EffectSection) }

    private var favorites: [String] { favRaw.split(separator: ",").map(String.init) }
    private var recents: [String] { recentRaw.split(separator: ",").map(String.init) }

    private var filtered: [EffectDefinition] {
        let base: [EffectDefinition]
        switch tab {
        case .all: base = EffectRegistry.all
        case .favorites: base = favorites.compactMap { EffectRegistry.definition($0) }
        case .recent: base = recents.compactMap { EffectRegistry.definition($0) }
        case .section(let sec): base = EffectRegistry.all.filter { EffectSection.of($0) == sec }
        }
        guard !query.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.summary.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("All", .all)
                            chip("★ Favorites", .favorites)
                            chip("Recent", .recent)
                            ForEach(EffectSection.allCases) { sec in
                                if let n = EffectSection.counts[sec], n > 0 { chip("\(sec.rawValue) \(n)", .section(sec)) }
                            }
                        }
                    }
                    if tab == .all && query.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(EffectSection.allCases) { sec in
                                if let n = EffectSection.counts[sec], n > 0 {
                                    Button { tab = .section(sec) } label: {
                                        VStack(spacing: 5) {
                                            Image(systemName: sec.symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.accentGlow)
                                            Text(sec.rawValue).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.7)
                                            Text("\(n)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.textDim)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 74)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.raised))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(sec.rawValue)
                                }
                            }
                        }
                    }
                    Text("\(filtered.count) effects · hold one to favorite it").font(.caption).foregroundStyle(Theme.textDim)
                    if filtered.isEmpty {
                        Text(tab == .favorites ? "No favorites yet — hold any effect and tap Favorite." : "Nothing here yet.")
                            .font(.footnote).foregroundStyle(Theme.textDim).padding(.top, 20)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(filtered) { d in
                            Button { remember(d.id); pick(d) } label: {
                                EffectTile(def: d)
                                    .overlay(alignment: .topTrailing) {
                                        if favorites.contains(d.id) {
                                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Theme.warning).padding(5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { toggleFavorite(d.id) } label: {
                                    Label(favorites.contains(d.id) ? "Unfavorite" : "Favorite", systemImage: favorites.contains(d.id) ? "star.slash" : "star")
                                }
                                Text(d.summary)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .searchable(text: $query, prompt: "Search \(EffectRegistry.all.count) effects")
            .navigationTitle("Add Effect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func toggleFavorite(_ id: String) {
        var f = favorites
        if let i = f.firstIndex(of: id) { f.remove(at: i) } else { f.insert(id, at: 0) }
        favRaw = f.joined(separator: ",")
    }

    private func remember(_ id: String) {
        var r = recents.filter { $0 != id }
        r.insert(id, at: 0)
        recentRaw = r.prefix(24).joined(separator: ",")
    }

    private func chip(_ title: String, _ t: Tab) -> some View {
        Button { tab = t } label: {
            Text(title).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(tab == t ? Theme.accent : Theme.raised))
                .foregroundStyle(tab == t ? .white : Theme.text)
        }
        .buttonStyle(.plain)
    }
}

struct EffectTile: View {
    let def: EffectDefinition
    @State private var image: UIImage?
    /// Looping preview frames: the tile plays the effect (shakes shake, glitches glitch).
    @State private var frames: [UIImage] = []
    @State private var frameIndex = 0
    @State private var visible = false
    private let timer = Timer.publish(every: 1.0 / 12, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.raised)
                if !frames.isEmpty {
                    Image(uiImage: frames[frameIndex % frames.count]).resizable().scaledToFill()
                } else if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if def.isTransformEffect {
                    Image(systemName: def.category.symbol).font(.system(size: 28)).foregroundStyle(Theme.accentGlow)
                } else {
                    ProgressView().tint(Theme.accent)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(def.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text)
                .lineLimit(2).multilineTextAlignment(.center).frame(height: 28)
        }
        .onReceive(timer) { _ in if visible && !frames.isEmpty { frameIndex += 1 } }
        .onAppear {
            visible = true
            if image == nil, !def.isTransformEffect { EffectThumbnails.shared.thumbnail(for: def) { image = $0 } }
            // Animate once the tile has been on screen for a moment (scrolling past stays cheap).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard visible, frames.isEmpty, !isUITesting else { return }
                EffectThumbnails.shared.frames(for: def) { f in if visible { frames = f } }
            }
        }
        .onDisappear { visible = false; frames = [] }
    }
}

/// Settings sheet for app-wide options (preview image).
struct SettingsSheet: View {
    @State private var item: PhotosPickerItem?
    @State private var preview: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(uiImage: preview ?? UIImage()).resizable().scaledToFill()
                            .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker("Choose Image", selection: $item, matching: .images)
                            Button("Use Built-in Test Image", role: .destructive) {
                                PreviewImage.resetToBuiltin(); load()
                            }
                        }
                    }
                } header: { Text("Effect preview image") } footer: {
                    Text("Every effect, preset and transition thumbnail renders on this image.")
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                    LabeledContent("Effects", value: "\(EffectRegistry.all.count)")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear(perform: load)
        .onChange(of: item) { _, it in
            guard let it else { return }
            Task {
                if let data = try? await it.loadTransferable(type: Data.self) { PreviewImage.setUserImage(data) }
                await MainActor.run { load() }
            }
        }
    }

    private func load() { preview = UIImage(contentsOfFile: PreviewImage.url().path) }
}
