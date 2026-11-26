import SwiftUI
import PhotosUI
import AVFoundation

enum EffectsPresentation {
    static let studioIDs: Set<String> = ["awi18.grade", "awi18.puppet"]
    static let retiredIDs: Set<String> = [
        "awi.manga", "awi.impactFrame", "awi.looks", "awi.saber",
        "awi.shine", "awi.glitch", "awi.vhs", "awi.pixelSort", "awi.particles",
        "awi8.crossProcess", "awi8.bleachBypass", "awi8.infrared", "awi13.cyberpunk", "awi13.lomo", "awi13.dayForNight"
    ]
    static let browseable = EffectRegistry.all.filter { canBrowse($0) }

    static func canBrowse(_ definition: EffectDefinition) -> Bool {
        !studioIDs.contains(definition.id) && !retiredIDs.contains(definition.id)
    }
}

// MARK: - Effect sections (Alight Motion-style browsing)

/// Primary effect families. Descriptions and tags are used for search, not filing.
enum EffectSection: String, CaseIterable, Identifiable {
    case text = "Text", shake = "Shake & Motion", glow = "Glow & Light", blur = "Blur", glitch = "Glitch", distort = "Distort & Warp",
         transition = "Transitions", particles = "Particles", backgrounds = "Backgrounds", threeD = "3D",
         repeaters = "Repeat & Tile", stylize = "Stylize & Draw", retro = "Retro & Film", color = "Color & Grade", keying = "Key & Matte", other = "More"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .text: return "textformat"
        case .shake: return "waveform.path"
        case .glow: return "sun.max.fill"
        case .blur: return "drop.halffull"
        case .glitch: return "bolt.horizontal.fill"
        case .distort: return "tornado"
        case .transition: return "square.split.diagonal.2x2"
        case .particles: return "sparkles"
        case .backgrounds: return "square.grid.3x3.fill"
        case .threeD: return "cube.fill"
        case .repeaters: return "square.grid.2x2"
        case .stylize: return "pencil.and.scribble"
        case .retro: return "film"
        case .color: return "paintpalette.fill"
        case .keying: return "person.crop.rectangle"
        case .other: return "ellipsis.circle"
        }
    }

    private static let primary: [String: EffectSection] = {
        var result: [String: EffectSection] = [:]
        let families: [(EffectSection, [String])] = [
            (.threeD, EffectRegistry.batch17.map(\.id) + [
                "awi20.flip", "awi10.cardTilt", "awi.amref.e3dc893f46bd6", "awi.amref.e52053df16be1",
                "awi.amref.ef1f2a785b8af", "awi.amref.efc60eccebd05", "awi.amref.e77bf324369ab",
                "awi.amref.e54bb2887bbf3", "awi.amref.e81d6711ee96b", "awi.amref.e228c81dec835",
                "awi.amref.e0fb0e4c76b45", "awi.amref.ec2da1b62e988", "awi.amref.e4cc43ae57f09"
            ]),
            (.glow, [
                "ae.glow", "ae.lensFlare", "awi.deepGlow", "awi.godRays", "awi.shapedLightSweep",
                "awi10.lightSweep", "awi10.organicLightSweep", "awi10.volumetricBeam", "awi10.pointLight",
                "awi.edgeCurrent", "awi10.filmBloom", "awi15.prismGlow", "awi15.softGlow", "awi15.darkGlow", "awi15.hueGlow",
                "awi15.lightWrap", "awi.outlineGlow", "awi.outerGlow", "awi.innerGlow", "awi16.glowScan", "awi7.energyBeam"
            ]),
            (.glitch, [
                "awi.syncRoll", "awi.lineHold", "awi.sortBands", "awi.rgbSplit", "awi18.twitch", "awi18.scanTear", "awi18.waveGlitch", "awi18.blockShuffle",
                "awi18.channelSmear", "awi18.warpChroma", "awi6.glitchBlocks", "awi6.glitchLines", "awi6.digitalNoise",
                "awi16.glitchColorBands", "awi6.datamosh"
            ]),
            (.repeaters, [
                "ae.motionTile", "awi6.hexTiles", "awi8.mosaicTiles", "awi11.repeatGrid",
                "awi11.repeatLine", "awi11.repeatRadial", "awi11.mirrorTile"
            ]),
            (.particles, ["awi18.particles", "awi7.bokehParticles"]),
            (.retro, EffectRegistry.batch13.map(\.id)),
            (.stylize, ["awi23.drawProgress", "awi.ghost"])
        ]
        for (family, ids) in families {
            for id in ids { result[id] = family }
        }
        return result
    }()

    /// Give authored assignments priority over the renderer's broad category.
    static func of(_ d: EffectDefinition) -> EffectSection {
        if let section = primary[d.id] { return section }
        switch d.category {
        case .text: return .text
        case .blur: return .blur
        case .color: return .color
        case .distort: return .distort
        case .generate: return .backgrounds
        case .keying: return .keying
        case .motion: return .shake
        case .stylize: return .stylize
        case .transition: return .transition
        case .glitch: return .glitch
        }
    }

    static let counts: [EffectSection: Int] = Dictionary(grouping: EffectsPresentation.browseable, by: { of($0) }).mapValues(\.count)
}

// MARK: - Preview quality

enum PreviewQuality: Double, CaseIterable, Identifiable {
    case full = 1, half = 0.5, quarter = 0.25, eighth = 0.125
    var id: Double { rawValue }
    var title: String { [1: "Full", 0.5: "1/2", 0.25: "1/4", 0.125: "1/8"][rawValue] ?? "Full" }
}

struct PreviewQualityMenu: View {
    @ObservedObject var state: EditorState
    var body: some View {
        Menu {
            Picker("Preview Quality", selection: $state.previewQuality) {
                ForEach(PreviewQuality.allCases) { q in Text(q.title).tag(q) }
            }
            Text("Lower = smoother playback while editing. Export is always full quality.")
        } label: {
            Text(state.previewQuality.title).font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(minWidth: 38, minHeight: 28)
                .background(Capsule().fill(Theme.raised))
                .foregroundStyle(state.previewQuality == .full ? Theme.text : Theme.warning)
        }
        .accessibilityLabel("Preview Quality")
    }
}

// MARK: - Nulls

extension EditorState {
    /// AE null object: an invisible handle for parenting / driving other layers.
    func addNull() {
        mutate("Add Null") { p in
            var l = p.makeLayer(name: "Null \(p.layers.filter(\.isNull).count + 1)", content: .solid, size: Vec2(100, 100))
            l.isNull = true
            l.fill = Animated(RGBA(1, 1, 1, 0))
            l.tag = .pink
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .transform
    }

    /// One-tap "plugin" looks applied to the selected layer.
    func applyPlugin(_ def: EffectDefinition, params: [String: ParamValue] = [:]) {
        guard selectedIndex != nil else { return }
        var e = def.makeInstance()
        for (k, v) in params { e.params[k] = v }
        mutate("Add \(def.name)") { p in if let i = self.selectedIndex { p.layers[i].effects.append(e) } }
        panel = .effects
    }
}

// MARK: - ⚡ Quick menu

/// Pop-up menu of fast adds and one-tap AE-plugin-style tools (Deep Glow, Saber, S_Shake, Twixtor-style slow-mo…),
/// built in so nothing needs a separate plugin.
struct QuickMenu: View {
    @ObservedObject var state: EditorState
    @EnvironmentObject private var drawLauncher: DrawLauncher

    var body: some View {
        Menu {
            Section("Add") {
                Button { state.addNull() } label: { Label("Null Object", systemImage: "circle.dashed") }
                Button { state.addAdjustmentLayer() } label: { Label("Adjustment Layer", systemImage: "slider.horizontal.below.rectangle") }
                Button { state.addCamera() } label: { Label("Camera", systemImage: "video") }
                Button { state.showLightBrowser = true } label: { Label("Light… (search all lights & glows)", systemImage: "lightbulb.fill") }
                Button { state.addText() } label: { Label("Text", systemImage: "textformat") }
                Button { state.addSolid() } label: { Label("Solid", systemImage: "rectangle.fill") }
                Button { drawLauncher.open(nil) } label: { Label("Draw", systemImage: "paintbrush.pointed.fill") }
            }
            if state.selectedLayer != nil {
                Section("Plugins (one tap on the selected layer)") {
                    if state.selectedLayer?.isImage == true || state.selectedLayer?.isMedia == true {
                        Button { state.panel = .cutout } label: { Label("Remove Background (AI)", systemImage: "person.crop.rectangle.badge.plus") }
                    }
                    Button { state.applyPlugin(EffectRegistry.deepGlow) } label: { Label("Deep Glow", systemImage: "sun.max.fill") }
                    Button { state.applyPlugin(EffectRegistry.edgeCurrent) } label: { Label("Edge Current", systemImage: "wand.and.rays") }
                    Button { state.applyPlugin(EffectRegistry.outlineGlow) } label: { Label("Outline Glow", systemImage: "person.fill.viewfinder") }
                    Button { state.applyPlugin(EffectRegistry.shake) } label: { Label("S_Shake", systemImage: "waveform.path") }
                    Button { state.applyPlugin(EffectRegistry.jitter, params: ["rate": .number(Animated(24))]) } label: { Label("Twitch", systemImage: "bolt") }
                    Button { state.applyPlugin(EffectRegistry.lensFlare) } label: { Label("Optical Flare", systemImage: "camera.aperture") }
                    Button { state.applyPlugin(EffectRegistry.godRays) } label: { Label("God Rays", systemImage: "sun.haze.fill") }
                    Button { state.applyPlugin(EffectRegistry.lineHold) } label: { Label("Line Hold", systemImage: "bolt.horizontal.fill") }
                    Button { state.applyPlugin(EffectRegistry.chromaticAberration) } label: { Label("Chromatic Aberration", systemImage: "circle.hexagongrid") }
                    Button {
                        state.panel = .motionBlur
                    } label: { Label("Pixel Motion Blur", systemImage: "wind") }
                    Button {
                        state.mutate("Twixtor Slow-mo") { p in
                            guard let i = state.selectedIndex else { return }
                            p.layers[i].speed = 0.4; p.layers[i].usesFrameBlending = true
                        }
                    } label: { Label("Twixtor-style Slow-mo", systemImage: "tortoise.fill") }
                    Button { state.applySpeedRamp() } label: { Label("Velocity Ramp", systemImage: "speedometer") }
                    Button { state.makeSelected3DObject() } label: { Label("Element 3D (Extrude)", systemImage: "cube.transparent.fill") }
                    Button {
                        state.mutate("Echo Trails") { p in
                            guard let i = state.selectedIndex else { return }
                            p.layers[i].timeFX = LayerTimeFX(echoCount: 6, echoDelay: 0.04, echoDecay: 0.65)
                        }
                    } label: { Label("Echo Trails", systemImage: "square.3.layers.3d.down.right") }
                    Button { state.panel = .physics } label: { Label("Physics (Newton)", systemImage: "atom") }
                }
                Section("Motion Tools (Flow / Motion 2 / Sure Target style)") {
                    Menu {
                        ForEach(EditorState.EasePreset.allCases) { e in Button(e.rawValue) { state.applyEase(e) } }
                    } label: { Label("Ease Keyframes…", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
                    Button { state.applyExcite() } label: { Label("Excite (bounce after keys)", systemImage: "waveform.path.ecg") }
                    Button { state.applyLoop(pingPong: false) } label: { Label("Loop Animation", systemImage: "repeat") }
                    Button { state.applyLoop(pingPong: true) } label: { Label("Ping-Pong Loop", systemImage: "arrow.left.arrow.right") }
                    Menu {
                        Button("Center") { state.anchorGrid(0, 0) }
                        Button("Top Left") { state.anchorGrid(-1, -1) }; Button("Top") { state.anchorGrid(0, -1) }; Button("Top Right") { state.anchorGrid(1, -1) }
                        Button("Left") { state.anchorGrid(-1, 0) }; Button("Right") { state.anchorGrid(1, 0) }
                        Button("Bottom Left") { state.anchorGrid(-1, 1) }; Button("Bottom") { state.anchorGrid(0, 1) }; Button("Bottom Right") { state.anchorGrid(1, 1) }
                    } label: { Label("Anchor Point…", systemImage: "scope") }
                    if state.project.layers.contains(where: { $0.content == .camera }) {
                        Button { state.aimCameraAtSelected() } label: { Label("Aim Camera Here", systemImage: "camera.viewfinder") }
                    }
                    Button(role: .destructive) { state.clearMotionExpressions() } label: { Label("Remove Excite / Loop", systemImage: "xmark.circle") }
                }
                Section("Animate") {
                    Button { state.keyAllTransform() } label: { Label("Key All Transform", systemImage: "diamond.fill") }
                    Button { state.copyKeyframes() } label: { Label("Copy Keys", systemImage: "doc.on.doc") }
                    Button { state.pasteKeyframes() } label: { Label("Paste Keys", systemImage: "doc.on.clipboard") }
                    Button { state.splitSelected() } label: { Label("Split at Playhead", systemImage: "scissors") }
                    Button { state.duplicateSelected() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                }
            }
        } label: {
            Image(systemName: "bolt.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(LinearGradient(colors: [Theme.accentGlow, Theme.accent], startPoint: .top, endPoint: .bottom)))
        }
        .accessibilityLabel("Quick actions")
    }
}

// MARK: - My Library (user's own overlays / clips)

/// Files the user imports once and reuses in any project (stored in Documents/MyLibrary).
enum UserLibrary {
    static var folder: URL {
        let u = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("MyLibrary", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    static func items() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
    static func isVideo(_ u: URL) -> Bool { ["mov", "mp4", "m4v"].contains(u.pathExtension.lowercased()) }
    @discardableResult
    static func save(data: Data, ext: String) -> Bool {
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString).\(ext)"
        do { try data.write(to: folder.appendingPathComponent(name), options: .atomic); return true }
        catch { return false }
    }
    @discardableResult
    static func save(file: URL) -> Bool {
        let ext = file.pathExtension.isEmpty ? "mov" : file.pathExtension
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString).\(ext)"
        do { try FileManager.default.copyItem(at: file, to: folder.appendingPathComponent(name)); return true }
        catch { return false }
    }
    static func thumbnail(_ u: URL) -> UIImage? {
        if isVideo(u) {
            let g = AVAssetImageGenerator(asset: AVURLAsset(url: u))
            g.appliesPreferredTrackTransform = true
            g.maximumSize = CGSize(width: 240, height: 240)
            return (try? g.copyCGImage(at: .zero, actualTime: nil)).map { UIImage(cgImage: $0) }
        }
        return UIImage(contentsOfFile: u.path).flatMap { $0.preparingThumbnail(of: CGSize(width: 240, height: 240)) }
    }
}

extension EditorState {
    /// Adds a library item; overlays default to Screen so dark backgrounds disappear (light leaks, dust, flares).
    func addFromLibrary(_ u: URL, asOverlay: Bool) {
        if UserLibrary.isVideo(u) {
            addVideo(from: u)
        } else if let data = try? Data(contentsOf: u) {
            addImage(data: data, ext: u.pathExtension.isEmpty ? "png" : u.pathExtension)
        }
        guard asOverlay, let i = selectedIndex else { return }
        mutate("Overlay Blend") { p in
            p.layers[i].blendMode = .screen
            let l = p.layers[i]
            // Overlays cover the whole frame.
            let s = max(Double(p.width) / max(l.size.staticValue.x, 1), Double(p.height) / max(l.size.staticValue.y, 1)) * 100
            p.layers[i].transform.scale = Animated(Vec2(s, s))
            p.layers[i].transform.position = Animated(p.center)
        }
    }
}

struct MyLibrarySection: View {
    @ObservedObject var state: EditorState
    @State private var items: [URL] = UserLibrary.items()
    @State private var showImport = false
    @State private var thumbs: [URL: UIImage] = [:]
    @State private var importing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MY LIBRARY").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                Spacer()
                Button { showImport = true } label: {
                    Label("Import", systemImage: "plus.circle.fill").font(.system(size: 13, weight: .semibold))
                }
                .accessibilityLabel("Import to My Library")
                .buttonStyle(.borderless)
                .disabled(importing)
            }
            if items.isEmpty {
                Text("Import your own overlays, transitions or clips once — they stay here for every project. Tap adds it exactly as it is (normal blend); hold for a Screen-blend overlay option.")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(items, id: \.self) { u in
                    Button { state.addFromLibrary(u, asOverlay: false) } label: {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 10).fill(Theme.raised)
                            if let t = thumbs[u] { Image(uiImage: t).resizable().scaledToFill().allowsHitTesting(false) }
                            if UserLibrary.isVideo(u) {
                                Image(systemName: "play.fill").font(.system(size: 10)).padding(5).foregroundStyle(.white)
                            }
                        }
                        .frame(height: 80).clipped().clipShape(RoundedRectangle(cornerRadius: 10)).contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { state.addFromLibrary(u, asOverlay: false) } label: { Label("Add (as is)", systemImage: "square.on.square") }
                        Button { state.addFromLibrary(u, asOverlay: true) } label: { Label("Add as Full-Frame Screen Overlay", systemImage: "sun.haze") }
                        Button(role: .destructive) { try? FileManager.default.removeItem(at: u); reload() } label: { Label("Remove from Library", systemImage: "trash") }
                    }
                    .task { if thumbs[u] == nil { thumbs[u] = UserLibrary.thumbnail(u) } }
                }
            }
        }
        .awiSheet(isPresented: $showImport) {
            MediaPickerView(state: state, isPresented: $showImport, libraryOnly: true).onDisappear { reload() }
        }
    }

    private func reload() { items = UserLibrary.items() }
}
