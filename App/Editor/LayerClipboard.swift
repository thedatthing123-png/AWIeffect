import Foundation
import SwiftUI

enum LayerStylePart: String, CaseIterable, Identifiable {
    case fill = "Color & Fill", border = "Border & Shadow", blending = "Blending & Opacity"
    case transform = "Move & Transform", text = "Text Style", effects = "Effects"
    var id: String { rawValue }
}

/// The clipboard owns copies of its media. Closing or deleting the source project cannot break it.
final class LayerClipboardPayload: @unchecked Sendable {
    let layers: [Layer]
    let precomps: [Project]
    let folder: URL
    init(layers: [Layer], precomps: [Project], folder: URL) {
        self.layers = layers; self.precomps = precomps; self.folder = folder
    }
    deinit { try? FileManager.default.removeItem(at: folder) }
}

enum LayerClipboardFiles {
    static func files(_ layers: [Layer], folder: URL) throws -> Set<String> {
        var names = Set<String>()
        for layer in layers {
            if let file = layer.mediaFile { names.insert(file) }
            if let file = layer.model3D?.fileName { names.insert(file) }
            if let file = layer.model3D?.imageFile { names.insert(file) }
            for effect in layer.effects { if let file = effect.text?["file"], !file.isEmpty { names.insert(file) } }
            if let id = layer.drawingID {
                let name = "draw-\(id).json"
                let doc = try JSONDecoder().decode(DrawingDoc.self, from: Data(contentsOf: folder.appendingPathComponent(name)))
                names.insert(name); names.formUnion(doc.layers.map(\.file))
            }
        }
        return names
    }
    static func snapshot(layers: [Layer], precomps: [Project], source: URL) throws -> LayerClipboardPayload {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AWI-clipboard-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            let names = try files(layers + precomps.flatMap(\.layers), folder: source)
            for name in names {
                guard URL(fileURLWithPath: name).lastPathComponent == name else { throw CocoaError(.fileReadInvalidFileName) }
                try FileManager.default.copyItem(at: source.appendingPathComponent(name), to: folder.appendingPathComponent(name))
            }
            return LayerClipboardPayload(layers: layers, precomps: precomps, folder: folder)
        } catch { try? FileManager.default.removeItem(at: folder); throw error }
    }

    /// Imports assets transactionally and refreshes references, including editable drawings and nested comps.
    static func imported(_ payload: LayerClipboardPayload, destination: URL, existingLayerIDs: Set<UUID> = []) throws -> (layers: [Layer], comps: [Project]) {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let names = try files(payload.layers + payload.precomps.flatMap(\.layers), folder: payload.folder)
        var mapping: [String: String] = [:], created: [URL] = []
        let compIDs = Dictionary(uniqueKeysWithValues: payload.precomps.map { ($0.id, UUID()) })
        let layers = payload.layers + payload.precomps.flatMap(\.layers)
        let layerIDs = Dictionary(layers.map { ($0.id, UUID()) }, uniquingKeysWith: { a, _ in a })
        let drawingIDs = Dictionary(layers.compactMap(\.drawingID).map { ($0, UUID()) }, uniquingKeysWith: { a, _ in a })
        for name in names {
            mapping[name] = UUID().uuidString + "." + URL(fileURLWithPath: name).pathExtension
        }
        for (old, new) in drawingIDs { mapping["draw-\(old).json"] = "draw-\(new).json" }
        do {
            for name in names {
                let url = destination.appendingPathComponent(mapping[name]!)
                created.append(url)
                if let old = drawingIDs.keys.first(where: { name == "draw-\($0).json" }) {
                    var doc = try JSONDecoder().decode(DrawingDoc.self, from: Data(contentsOf: payload.folder.appendingPathComponent(name)))
                    doc.id = drawingIDs[old]!
                    for i in doc.layers.indices { doc.layers[i].file = mapping[doc.layers[i].file] ?? doc.layers[i].file }
                    try JSONEncoder().encode(doc).write(to: url, options: .atomic)
                } else { try fm.copyItem(at: payload.folder.appendingPathComponent(name), to: url) }
            }
            func remap(_ original: Layer) -> Layer {
                var l = original; l.id = layerIDs[l.id]!
                l.parentID = l.parentID.flatMap { layerIDs[$0] }; l.groupID = l.groupID.flatMap { layerIDs[$0] }
                l.drawingID = l.drawingID.flatMap { drawingIDs[$0] }
                switch l.content {
                case .image(let f, let w, let h): l.content = .image(fileName: mapping[f]!, pixelWidth: w, pixelHeight: h)
                case .video(let f, let w, let h, let a): l.content = .video(fileName: mapping[f]!, pixelWidth: w, pixelHeight: h, hasAudio: a)
                case .audio(let f, let d): l.content = .audio(fileName: mapping[f]!, duration: d)
                case .precomp(let id): if let new = compIDs[id] { l.content = .precomp(id: new) }
                default: break
                }
                if let f = l.model3D?.fileName { l.model3D?.fileName = mapping[f] }
                if let f = l.model3D?.imageFile { l.model3D?.imageFile = mapping[f] }
                for i in l.effects.indices {
                    l.effects[i].id = UUID()
                    if let f = l.effects[i].text?["file"] { l.effects[i].text?["file"] = mapping[f] }
                    if let id = (l.effects[i].text?["layer"]).flatMap(UUID.init(uuidString:)) {
                        l.effects[i].text?["layer"] = (layerIDs[id] ?? (existingLayerIDs.contains(id) ? id : nil))?.uuidString
                    }
                }
                for i in l.masks.indices { l.masks[i].id = UUID() }
                l.remapRigReferences(layerIDs, keepExternal: false)
                return l
            }
            let comps = payload.precomps.map { original -> Project in
                var p = original; p.id = compIDs[p.id]!; p.layers = p.layers.map(remap)
                p.precomps = []; p.parentContext = nil; return p
            }
            return (payload.layers.map(remap), comps)
        } catch { for url in created { try? fm.removeItem(at: url) }; throw error }
    }
}

@MainActor final class LayerClipboard: ObservableObject {
    static let shared = LayerClipboard()
    @Published var payload: LayerClipboardPayload?
    @Published var busy = false
}

extension EditorState {
    func copyLayer() {
        guard let selected = selectedLayer, !LayerClipboard.shared.busy else { return }
        let ids = Self.descendantIDs(of: selected.id, in: project).union([selected.id])
        var source = project
        Self.unparentKeepingWorld(&source) { ids.contains($0.id) && $0.parentID.map { !ids.contains($0) } == true }
        let layers = source.layers.filter { ids.contains($0.id) }
        var library: [UUID: Project] = [:]
        func collect(_ p: Project) { for c in p.precomps { library[c.id] = c; collect(c) } }
        collect(rootProject)
        var needed = Set<UUID>()
        func visit(_ layers: [Layer]) {
            for layer in layers { if case .precomp(let id) = layer.content, needed.insert(id).inserted, let p = library[id] { visit(p.layers) } }
        }
        visit(layers)
        let comps = needed.compactMap { library[$0] }, folder = store.mediaFolder(for: rootProject.id)
        LayerClipboard.shared.busy = true
        Task {
            defer { LayerClipboard.shared.busy = false }
            do {
                LayerClipboard.shared.payload = try await Task.detached(priority: .userInitiated) {
                    try LayerClipboardFiles.snapshot(layers: layers, precomps: comps, source: folder)
                }.value
            } catch { recoveryNotice = "Could not copy layer: " + error.localizedDescription }
        }
    }
    func pasteLayer(style: Set<LayerStylePart>? = nil, contentOnly: Bool = false) {
        guard let payload = LayerClipboard.shared.payload, !LayerClipboard.shared.busy else { return }
        let target = selectedLayerID, projectID = project.id, folder = store.mediaFolder(for: rootProject.id)
        let existingLayerIDs = Set(project.layers.map(\.id))
        if (style != nil || contentOnly) && selectedLayer == nil { return }
        LayerClipboard.shared.busy = true
        Task {
            defer { LayerClipboard.shared.busy = false }
            do {
                let imported = try await Task.detached(priority: .userInitiated) {
                    try LayerClipboardFiles.imported(payload, destination: folder, existingLayerIDs: existingLayerIDs)
                }.value
                guard project.id == projectID else { recoveryNotice = "Paste cancelled because the open composition changed."; return }
                var layers = imported.layers
                guard var source = layers.first else { return }
                let time = currentTime
                if let style {
                    source.shiftTiming(by: (project.layers.first { $0.id == target }?.inPoint ?? time) - source.inPoint, duration: project.duration)
                    mutate("Paste Style") { p in
                        guard let i = p.layers.firstIndex(where: { $0.id == target }), !p.layers[i].isLocked else { return }
                        Self.applyStyle(source, to: &p.layers[i], parts: style)
                    }
                } else if contentOnly {
                    mutate("Replace Content") { p in
                        guard let i = p.layers.firstIndex(where: { $0.id == target }), !p.layers[i].isLocked else { return }
                        // Content uses the preset's logical bounds. Position, scale keys, masks and effects stay intact.
                        p.layers[i].content = source.content; p.layers[i].drawingID = source.drawingID
                        p.layers[i].model3D = source.model3D; p.layers[i].path = source.path
                        p.layers[i].shapeContents = source.shapeContents
                        if source.content == .text { p.layers[i].text = source.text }
                        p.precomps += imported.comps
                    }
                } else {
                    let offset = time - (layers.map(\.inPoint).min() ?? 0)
                    for i in layers.indices { layers[i].shiftTiming(by: offset, duration: project.duration); layers[i].isLocked = false }
                    mutate("Paste Layer") { p in
                        var palette = p
                        for index in layers.indices where layers[index].isContainer {
                            layers[index].tag = palette.nextContainerTag()
                            palette.layers.append(layers[index])
                        }
                        p.layers.insert(contentsOf: layers, at: selectedIndex ?? 0)
                        p.precomps += imported.comps; p.fitAutoLength()
                    }
                    select(layers.first?.id)
                }
                AudioPreview.shared.invalidate()
            } catch { recoveryNotice = "Could not paste layer: " + error.localizedDescription }
        }
    }
    static func applyStyle(_ source: Layer, to target: inout Layer, parts: Set<LayerStylePart>) {
        if parts.contains(.fill) {
            target.fill = source.fill; target.cornerRadius = source.cornerRadius
            if target.shapeContents != nil {
                let styles = source.editableShapeContents.compactMap(\.component)
                var pathIndex = 0
                for i in target.shapeContents!.indices where target.shapeContents![i].component != nil {
                    if styles.indices.contains(pathIndex) {
                        target.shapeContents![i].component?.fill = styles[pathIndex].fill
                        target.shapeContents![i].component?.fillOn = styles[pathIndex].fillOn
                        target.shapeContents![i].component?.fillGradient = styles[pathIndex].fillGradient
                    } else {
                        target.shapeContents![i].component?.fill = source.fill
                        target.shapeContents![i].component?.fillOn = true
                        target.shapeContents![i].component?.fillGradient = nil
                    }
                    pathIndex += 1
                }
            }
            if target.text != nil {
                target.text?.fill = source.text?.fill ?? source.fill
                target.text?.colorSpans = source.text?.colorSpans ?? []
            }
        }
        let styleIDs: Set<String> = [EffectRegistry.border.id, EffectRegistry.dropShadow.id]
        if parts.contains(.border) {
            target.stroke = source.stroke
            if target.shapeContents != nil {
                let styles = source.editableShapeContents.compactMap(\.component)
                var pathIndex = 0
                for i in target.shapeContents!.indices where target.shapeContents![i].component != nil {
                    target.shapeContents![i].component?.stroke = styles.indices.contains(pathIndex) ? styles[pathIndex].stroke : source.stroke
                    target.shapeContents![i].component?.strokeGradient = styles.indices.contains(pathIndex) ? styles[pathIndex].strokeGradient : nil
                    pathIndex += 1
                }
            }
            if !parts.contains(.effects) {
                target.effects.removeAll { styleIDs.contains($0.typeID) }
                target.effects += source.effects.filter { styleIDs.contains($0.typeID) }
            }
        }
        if parts.contains(.blending) {
            target.blendMode = source.blendMode; target.transform.opacity = source.transform.opacity
            target.trackMatte = source.trackMatte; target.clipToBelow = source.clipToBelow
        }
        if parts.contains(.transform) {
            let opacity = target.transform.opacity; target.transform = source.transform
            if !parts.contains(.blending) { target.transform.opacity = opacity }
            target.is3D = source.is3D; target.extrude = source.extrude
        }
        if parts.contains(.text), let text = source.text, let string = target.text?.string {
            let previous = target.text!
            target.text = text; target.text?.string = string; target.text?.counter = previous.counter
            if !parts.contains(.fill) { target.text?.fill = previous.fill; target.text?.colorSpans = previous.colorSpans }
            if target.masks.isEmpty { target.text?.onPath = false }
        }
        if parts.contains(.effects) {
            if parts.contains(.border) { target.effects = source.effects }
            else { target.effects = target.effects.filter { styleIDs.contains($0.typeID) } + source.effects.filter { !styleIDs.contains($0.typeID) } }
        }
    }
}

struct PasteLayerStyleSheet: View {
    @ObservedObject var state: EditorState
    @Environment(\.dismiss) private var dismiss
    @State private var parts = Set(LayerStylePart.allCases)
    var body: some View {
        NavigationStack {
            Form {
                ForEach(LayerStylePart.allCases) { part in
                    Toggle(part.rawValue, isOn: Binding(get: { parts.contains(part) }, set: { if $0 { parts.insert(part) } else { parts.remove(part) } }))
                        .disabled(part == .text && (state.selectedLayer?.text == nil || LayerClipboard.shared.payload?.layers.first?.text == nil))
                }
                Text("Choose which properties to replace. Text Style keeps your target text.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("Paste Style")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Paste") { state.pasteLayer(style: parts); dismiss() }.disabled(parts.isEmpty) }
            }
        }
    }
}
