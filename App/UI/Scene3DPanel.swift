import SwiftUI

/// 3D Scene: turn flat panels, cut-out characters and backgrounds into a real 3D scene in one step —
/// each layer gets its own depth (no more faking it with Z + a 2D camera) — then optionally add a camera
/// move through it. Everything stays normal Z positions and camera keyframes you can keep tweaking.
struct Scene3DPanel: View {
    @ObservedObject var state: EditorState
    @State private var depth = 600.0
    @State private var push = 30.0
    @State private var duration = 2.5
    @State private var drift = 3.0
    @State private var turn = 2.0

    private var targets: [Layer] {
        let ids = state.multiSelection
        return state.project.layers.filter { l in
            (ids?.contains(l.id) ?? true) && !l.isAudioOnly && l.content != .camera && l.content != .adjustment && l.content != .light
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "3D Scene", showKeyNav: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ADD TO THE SCENE").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accentGlow)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        tile("Camera", "video.fill") { state.addCamera() }
                        tile("Spot Light", "light.cylindrical.ceiling") { state.addLight(.spot) }
                        tile("Point Light", "lightbulb.fill") { state.addLight(.point) }
                        tile("Sun Light", "sun.max.fill") { state.addLight(.parallel) }
                        tile("Ambient", "circle.hexagongrid.fill") { state.addLight(.ambient) }
                        tile("All Layers 3D", "cube.fill") {
                            state.mutate("All 3D") { p in
                                for i in p.layers.indices where !p.layers[i].isAudioOnly && p.layers[i].content != .camera
                                    && p.layers[i].content != .light && p.layers[i].content != .adjustment { p.layers[i].is3D = true }
                            }
                        }
                    }
                    Text("LAYOUT").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accentGlow).padding(.top, 4)
                    Text(state.isMultiSelecting ? "Uses the \(targets.count) selected layers (top layer = closest)." : "Uses every visual layer (top layer = closest). Select layers first to pick only some.")
                        .font(.caption).foregroundStyle(Theme.textDim)
                    row("Depth Between Layers", depth, 0...3000, "px") { depth = $0 }
                    Button { state.mangaPanelPush(depth: depth, push: 0, duration: 0, drift: 0, turn: 0, addCamera: false) } label: {
                        Label("Make 3D Scene", systemImage: "square.3.layers.3d").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Divider().overlay(Theme.stroke)
                    Text("CAMERA MOVE").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                    row("Push In", push, -80...80, "%") { push = $0 }
                    row("Length", duration, 0.3...10, "s") { duration = $0 }
                    row("Drift", drift, -20...20, "%") { drift = $0 }
                    row("Turn", turn, -30...30, "°") { turn = $0 }
                    Button { state.mangaPanelPush(depth: depth, push: push / 100, duration: duration, drift: drift / 100, turn: turn, addCamera: true) } label: {
                        Label("Make 3D Scene + Camera Move", systemImage: "camera.viewfinder").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text("Starts at the playhead. Positions and sizes are adjusted so the first frame looks exactly like your flat layout; then the camera moves through real depth (parallax). Fine-tune any layer's Depth (Z) in Transform.")
                        .font(.caption).foregroundStyle(Theme.textDim)
                    if !targets.isEmpty {
                        Divider().overlay(Theme.stroke)
                        Text("LAYER DEPTHS").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                        ForEach(targets) { l in
                            HStack {
                                Text(l.name).font(.system(size: 12)).foregroundStyle(Theme.text).lineLimit(1).frame(width: 110, alignment: .leading)
                                ValueScrubber(value: l.transform.positionZ.value(at: state.currentTime), range: -2000...6000, step: 1, unit: " z",
                                              onBegin: { state.beginEdit("Layer Depth") },
                                              onChange: { v in setZ(l.id, v) }, onEnd: { state.endEdit() }, allowBeyond: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
    }

    private func setZ(_ id: UUID, _ v: Double) {
        let t = state.currentTime
        state.mutate("Layer Depth") { p in
            guard let i = p.layers.firstIndex(where: { $0.id == id }) else { return }
            p.layers[i].is3D = true
            p.layers[i].transform.positionZ.set(v, at: t)
        }
    }

    private func row(_ title: String, _ v: Double, _ r: ClosedRange<Double>, _ unit: String, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 110, alignment: .leading)
            ValueScrubber(value: v, range: r, unit: unit, onChange: set)
        }
    }

    private func tile(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.system(size: 10.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.raised))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
