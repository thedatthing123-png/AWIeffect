import SwiftUI

/// "+ Add" for lighting: every scene light and every light-type effect (glows, rays, flares, sweeps, leaks, rim light…),
/// searchable, in one place.
struct LightBrowser: View {
    @ObservedObject var state: EditorState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private struct SceneLight: Identifiable { let id: String; let title: String; let icon: String; let note: String; let type: LightType }
    private let sceneLights: [SceneLight] = [
        .init(id: "spot", title: "Spot Light", icon: "light.cylindrical.ceiling.fill", note: "Cone of light with soft edge and shadows (3D layers)", type: .spot),
        .init(id: "point", title: "Point Light", icon: "lightbulb.fill", note: "Bulb shining in every direction", type: .point),
        .init(id: "sun", title: "Sun / Parallel Light", icon: "sun.max.fill", note: "Sunlight from one direction, even across the scene", type: .parallel),
        .init(id: "ambient", title: "Ambient Light", icon: "circle.hexagongrid.fill", note: "Fills shadows evenly", type: .ambient),
    ]

    /// Effects that make or shape light.
    private var lightEffects: [EffectDefinition] {
        let words = ["light", "glow", "flare", "ray", "sweep", "shine", "leak", "bloom", "sun", "neon", "rim", "spot", "lamp", "beam", "god",
                     "exposure", "highlight", "sparkle", "glint", "star", "laser", "saber", "fire", "lightning", "aura"]
        return EffectRegistry.all.filter { d in
            let n = d.name.lowercased()
            return words.contains { n.contains($0) }
        }
        .sorted { $0.name < $1.name }
    }

    private func matches(_ s: String) -> Bool { query.isEmpty || s.localizedCaseInsensitiveContains(query) }

    var body: some View {
        NavigationStack {
            List {
                let lights = sceneLights.filter { matches($0.title) || matches($0.note) }
                if !lights.isEmpty {
                    Section("Scene lights (light 3D layers)") {
                        ForEach(lights) { l in
                            Button { state.addLight(l.type); dismiss() } label: { row(l.title, l.note, l.icon) }
                        }
                    }
                }
                let fx = lightEffects.filter { matches($0.name) || matches($0.summary) }
                if !fx.isEmpty {
                    Section(state.selectedLayer == nil ? "Light effects (added on a new adjustment layer)" : "Light effects (on the selected layer)") {
                        ForEach(fx, id: \.id) { d in
                            Button {
                                if state.selectedLayer == nil { state.addAdjustmentLayer() }
                                state.addEffect(d)
                                dismiss()
                            } label: { row(d.name, d.summary, "sparkles") }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search lights, glows, flares, rays…")
            .navigationTitle("Add Light")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func row(_ t: String, _ note: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.accentGlow).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                Text(note).font(.caption).foregroundStyle(Theme.textDim).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Lets any menu open the light browser.
final class LightLauncher: ObservableObject { @Published var open = false }
