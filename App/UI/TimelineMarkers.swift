import SwiftUI

/// A named, colored marker. Comp markers store comp time; layer markers store time from the layer's in point.
struct TimelineMarker: Codable, Equatable, Identifiable {
    var id = UUID()
    var time: Double
    var name: String = ""
    var tag: LayerTag = .amber
}

/// Where a marker lives.
enum MarkerOwner: Equatable {
    case comp
    case layer(UUID)
}

extension EditorState {
    /// Adds a marker at the playhead (comp, or on the selected layer). Returns its id.
    @discardableResult
    func addMarker(onLayer: Bool) -> UUID? {
        let t = project.snapToFrame(currentTime)
        var marker = TimelineMarker(time: t)
        if onLayer {
            guard let i = selectedIndex else { return nil }
            let l = project.layers[i]
            marker.time = max(0, t - l.inPoint)
            marker.name = "Marker \((l.layerMarkers?.count ?? 0) + 1)"
            marker.tag = l.tag
            mutate("Add Layer Marker") { p in p.layers[i].layerMarkers = (p.layers[i].layerMarkers ?? []) + [marker] }
        } else {
            marker.name = "Marker \((project.compMarkers?.count ?? 0) + 1)"
            mutate("Add Marker") { p in p.compMarkers = ((p.compMarkers ?? []) + [marker]).sorted { $0.time < $1.time } }
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        return marker.id
    }

    func updateMarker(_ id: UUID, owner: MarkerOwner, label: String, _ change: (inout TimelineMarker) -> Void) {
        mutate(label) { p in
            switch owner {
            case .comp:
                guard var list = p.compMarkers, let k = list.firstIndex(where: { $0.id == id }) else { return }
                change(&list[k]); list.sort { $0.time < $1.time }
                p.compMarkers = list
            case .layer(let lid):
                guard let i = p.layers.firstIndex(where: { $0.id == lid }), var list = p.layers[i].layerMarkers,
                      let k = list.firstIndex(where: { $0.id == id }) else { return }
                change(&list[k]); list.sort { $0.time < $1.time }
                p.layers[i].layerMarkers = list
            }
        }
    }

    func deleteMarker(_ id: UUID, owner: MarkerOwner) {
        mutate("Delete Marker") { p in
            switch owner {
            case .comp:
                p.compMarkers?.removeAll { $0.id == id }
                if p.compMarkers?.isEmpty == true { p.compMarkers = nil }
            case .layer(let lid):
                guard let i = p.layers.firstIndex(where: { $0.id == lid }) else { return }
                p.layers[i].layerMarkers?.removeAll { $0.id == id }
                if p.layers[i].layerMarkers?.isEmpty == true { p.layers[i].layerMarkers = nil }
            }
        }
    }

    /// Comp time of a marker.
    func markerTime(_ m: TimelineMarker, owner: MarkerOwner) -> Double {
        switch owner {
        case .comp: return m.time
        case .layer(let lid): return m.time + (project.layers.first { $0.id == lid }?.inPoint ?? 0)
        }
    }

    /// Named markers (comp + layer) as snap targets, in comp time.
    var namedMarkerTimes: [Double] {
        var times = (project.compMarkers ?? []).map(\.time)
        for l in project.timelineLayers { times += (l.layerMarkers ?? []).map { $0.time + l.inPoint } }
        return times
    }
}

/// Every named marker of the comp and its layers: rename, recolor, jump to, move to the playhead, delete.
struct TimelineMarkersSheet: View {
    @ObservedObject var state: EditorState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(state.project.compMarkers ?? []) { m in
                        MarkerRow(state: state, marker: m, owner: .comp)
                    }
                    Button { state.addMarker(onLayer: false) } label: {
                        Label("Add Comp Marker at Playhead", systemImage: "flag.fill").frame(minHeight: 44)
                    }
                } header: { Text("Comp markers") }
                ForEach(state.project.timelineLayers.filter { !($0.layerMarkers ?? []).isEmpty }) { l in
                    Section {
                        ForEach(l.layerMarkers ?? []) { m in MarkerRow(state: state, marker: m, owner: .layer(l.id)) }
                    } header: { Text(l.name) }
                }
                if let l = state.selectedLayer {
                    Section {
                        Button { state.addMarker(onLayer: true) } label: {
                            Label("Add Marker to \(l.name)", systemImage: "flag").frame(minHeight: 44)
                        }
                    } footer: { Text("Layer markers move with the clip. Clips, keys and the playhead snap to every marker.") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Markers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// Color · name · actions (three controls).
private struct MarkerRow: View {
    @ObservedObject var state: EditorState
    let marker: TimelineMarker
    let owner: MarkerOwner
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(LayerTag.allCases, id: \.self) { tag in
                    Button(tag.rawValue.capitalized) {
                        state.updateMarker(marker.id, owner: owner, label: "Marker Color") { $0.tag = tag }
                    }
                }
            } label: {
                Image(systemName: "flag.fill").font(.system(size: 16)).foregroundStyle(Theme.tagColor(marker.tag))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Marker color")
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $name)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .onChange(of: focused) { _, f in if !f { commit() } }
                    .font(.system(size: 15, weight: .semibold))
                Text(formatTimecode(state.markerTime(marker, owner: owner), fps: state.project.fps))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textDim)
            }
            Menu {
                Button { state.seek(state.markerTime(marker, owner: owner)) } label: { Label("Go to Marker", systemImage: "arrow.right.to.line") }
                Button {
                    let t = state.project.snapToFrame(state.currentTime)
                    let local: Double
                    if case .layer(let lid) = owner { local = max(0, t - (state.project.layers.first { $0.id == lid }?.inPoint ?? 0)) } else { local = t }
                    state.updateMarker(marker.id, owner: owner, label: "Move Marker") { $0.time = local }
                } label: { Label("Move to Playhead", systemImage: "arrow.down.to.line") }
                Button(role: .destructive) { state.deleteMarker(marker.id, owner: owner) } label: { Label("Delete Marker", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 18)).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Marker actions")
        }
        .buttonStyle(.plain)
        .onAppear { name = marker.name }
    }

    private func commit() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard n != marker.name else { return }
        state.updateMarker(marker.id, owner: owner, label: "Rename Marker") { $0.name = n }
    }
}
