import AVFoundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct RelightStudio: View {
    @ObservedObject var state: EditorState
    let layer: Layer

    private enum Tab: String, CaseIterable { case passes = "Passes", surface = "Surface" }
    @State private var tab: Tab = .passes
    @State private var requestedPass: RelightPass?
    @State private var importing = false
    @State private var busy = false
    @State private var error: String?
    private var material: RelightSurface { layer.relight ?? RelightSurface() }

    var body: some View {
        VStack(spacing: 5) {
            PanelHeader(state: state, title: "Relight Studio", showKeyNav: false)
            Picker("Relight controls", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if tab == .passes { passes } else { surface }
                    if let error { Text(error).font(.caption).foregroundStyle(Theme.textDim) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(Theme.text)
            }
            .accessibilityIdentifier("relight-studio-scroll")
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: layer.isImage ? [.image] : [.image, .movie]) { result in
            guard let pass = requestedPass else { return }
            switch result {
            case .failure(let failure): error = failure.localizedDescription
            case .success(let url):
                busy = true
                Task { @MainActor in
                    defer { busy = false }
                    do { try await state.importRelightPass(pass, from: url, layer: layer); error = nil }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
    }

    private var passes: some View {
        VStack(alignment: .leading, spacing: 7) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                ForEach(RelightPass.allCases) { pass in passTile(pass) }
            }
            if busy { ProgressView("Importing pass…").font(.caption) }
            if material.maps.isEmpty {
                Text("Import maps that match the source framing and timing. Start with Depth or Normals.")
                    .font(.caption).foregroundStyle(Theme.textDim)
            }
        }
    }

    private func passTile(_ pass: RelightPass) -> some View {
        let media = material.maps[pass]
        return HStack(spacing: 0) {
            Button {
                requestedPass = pass
                importing = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: pass.icon).frame(width: 17).foregroundStyle(Theme.accentGlow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pass.title).font(.system(size: 12, weight: .semibold))
                        Text(media?.name ?? "Import").font(.caption2).foregroundStyle(Theme.textDim)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(media == nil ? "Import \(pass.title)" : "Replace \(pass.title)")
            .disabled(busy || layer.isLocked)
            if media != nil {
                Button {
                    set("Remove \(pass.title)") { $0.maps[pass] = nil }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(pass.title)")
                .disabled(busy || layer.isLocked)
            }
        }
        .glass(radius: 9)
    }

    private var surface: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Relight Surface", isOn: Binding(get: { !material.maps.isEmpty && material.enabled }, set: { value in
                set("Relight Surface") { $0.enabled = value }
            })).frame(minHeight: 44)
                .disabled(material.maps.isEmpty)
            if material.maps[.depth] != nil {
                control("Depth", \.depth, 0...500, " px")
                Toggle("Invert Depth", isOn: toggle("Invert Depth", \.invertDepth)).frame(minHeight: 44)
                Toggle("Relief Shadows", isOn: toggle("Relief Shadows", \.reliefShadows)).frame(minHeight: 44)
            }
            if material.maps[.normal] != nil || material.maps[.depth] != nil {
                control("Normal Strength", \.normalStrength, 0...200, "%")
            }
            if material.maps[.normal] != nil {
                Toggle("Flip Normal Y", isOn: toggle("Flip Normal Y", \.flipNormalY)).frame(minHeight: 44)
            }
            if !material.maps.isEmpty {
                control("Roughness", \.roughness, 4...100, "%")
                control("Specular", \.specular, 0...100, "%")
            }
            if let light = state.project.layers.first(where: { $0.content == .light && $0.isActive(at: state.currentTime) }) {
                Button {
                    state.select(light.id)
                    state.panel = .threeD
                } label: {
                    Label("Open Lighting Studio", systemImage: "lightbulb.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain).glass(radius: 9)
            } else {
                Button {
                    state.addLight(.point)
                } label: {
                    Label("Add Point Light", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain).glass(radius: 9)
            }
        }
        .font(.system(size: 13))
        .tint(Theme.accent)
        .disabled(layer.isLocked)
    }

    private func toggle(_ label: String, _ key: WritableKeyPath<RelightSurface, Bool>) -> Binding<Bool> {
        Binding(get: { material[keyPath: key] }, set: { value in set(label) { $0[keyPath: key] = value } })
    }

    private func control(_ label: String, _ key: WritableKeyPath<RelightSurface, Double>,
                         _ range: ClosedRange<Double>, _ unit: String) -> some View {
        HStack(spacing: 9) {
            Text(label).font(.caption).frame(width: 92, alignment: .leading)
            ValueScrubber(value: material[keyPath: key], range: range, step: 1, unit: unit,
                          onBegin: { state.beginEdit(label) },
                          onChange: { value in set(label) { $0[keyPath: key] = value } },
                          onEnd: { state.endEdit() })
                .frame(height: 44)
                .accessibilityLabel(label)
        }
    }

    private func set(_ label: String, _ change: (inout RelightSurface) -> Void) {
        state.mutate(label) { p in
            guard let index = p.layers.firstIndex(where: { $0.id == layer.id && !$0.isLocked }) else { return }
            var updated = p.layers[index].relight ?? RelightSurface()
            change(&updated)
            p.layers[index].relight = updated
        }
    }
}

extension EditorState {
    func importRelightPass(_ pass: RelightPass, from url: URL, layer: Layer) async throws {
        let projectID = rootProject.id, compositionID = project.id
        guard let sourceName = layer.mediaFile, !layer.isLocked else { throw RelightImportError.layerChanged }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { throw RelightImportError.incompatible }
        let movie = UTType(filenameExtension: ext)?.conforms(to: .movie) == true
        let width: Int, height: Int, passWidth: Double, passHeight: Double
        switch layer.content {
        case .image(_, let w, let h), .video(_, let w, let h, _): width = w; height = h
        default: throw RelightImportError.layerChanged
        }
        if movie {
            guard !layer.isImage else { throw RelightImportError.incompatible }
            let asset = AVURLAsset(url: url)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw RelightImportError.incompatible }
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let bounds = CGRect(origin: .zero, size: size).applying(transform)
            passWidth = Double(abs(bounds.width)); passHeight = Double(abs(bounds.height))
            let length = try await asset.load(.duration).seconds
            let originalLength = try await AVURLAsset(url: mediaURL(sourceName)).load(.duration).seconds
            let fps = try await track.load(.nominalFrameRate)
            guard length.isFinite, originalLength.isFinite,
                  abs(length - originalLength) <= 1.5 / max(1, Double(fps)) else {
                throw RelightImportError.duration
            }
        } else {
            guard let image = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
                  let w = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let h = properties[kCGImagePropertyPixelHeight] as? NSNumber else { throw RelightImportError.incompatible }
            let rotation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
            passWidth = (rotation >= 5 ? h : w).doubleValue
            passHeight = (rotation >= 5 ? w : h).doubleValue
        }
        guard width > 0, height > 0, passWidth > 0, passHeight > 0,
              abs(passHeight * Double(width) / Double(height) - passWidth) <= 1.5 else {
            throw RelightImportError.framing
        }
        guard rootProject.id == projectID, project.id == compositionID,
              project.layers.contains(where: { $0.id == layer.id && !$0.isLocked && $0.mediaFile == sourceName }) else {
            throw RelightImportError.layerChanged
        }
        let file = try store.importMedia(fileAt: url, ext: ext, into: projectID)
        mutate("Import \(pass.title)") { project in
            guard let index = project.layers.firstIndex(where: { $0.id == layer.id }) else { return }
            var surface = project.layers[index].relight ?? RelightSurface()
            surface.maps[pass] = RelightMedia(file: file, name: url.lastPathComponent, isVideo: movie)
            surface.enabled = true
            project.layers[index].relight = surface
        }
    }
}

private enum RelightImportError: LocalizedError {
    case incompatible, duration, framing, layerChanged
    var errorDescription: String? {
        switch self {
        case .incompatible: return "Choose a compatible image or a video pass for footage."
        case .duration: return "Video passes need to match the source video’s duration."
        case .framing: return "This pass needs the same aspect ratio as the source."
        case .layerChanged: return "The source layer changed or is locked. Select the layer again."
        }
    }
}
