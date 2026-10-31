import Foundation
import SwiftUI

/// Multi-layer selection (hold a layer in the timeline, then drag up/down) and the actions that work on many layers.
extension EditorState {
    var isMultiSelecting: Bool { multiSelection != nil }

    /// Selected layers in stacking order (top first).
    var multiLayers: [Layer] {
        guard let ids = multiSelection else { return [] }
        return project.layers.filter { ids.contains($0.id) }
    }

    func beginMultiSelect(_ id: UUID) {
        pause()
        multiSelection = [id]
        multiAnchor = id
        selectedLayerID = id
        panel = .multi
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Selects the contiguous range from the anchor to the row under the finger.
    func extendMultiSelect(toRow row: Int) {
        guard let anchor = multiAnchor, let a = project.layers.firstIndex(where: { $0.id == anchor }), !project.layers.isEmpty else { return }
        let b = max(0, min(project.layers.count - 1, row))
        let ids = Set(project.layers[min(a, b)...max(a, b)].map(\.id))
        if ids != multiSelection { multiSelection = ids; UISelectionFeedbackGenerator().selectionChanged() }
    }

    func toggleInMulti(_ id: UUID) {
        guard var s = multiSelection else { return }
        if s.contains(id) { s.remove(id) } else { s.insert(id) }
        multiSelection = s
        if s.isEmpty { endMultiSelect() }
    }

    func selectAllLayers() { if multiSelection == nil { panel = .multi }; multiSelection = Set(project.layers.map(\.id)) }

    func endMultiSelect() {
        multiSelection = nil
        multiAnchor = nil
        panel = selectedLayerID == nil ? .none : .transform
    }

    func deleteMulti() {
        guard let ids = multiSelection, !ids.isEmpty else { return }
        mutate("Delete \(ids.count) Layers") { p in
            Self.unparentKeepingWorld(&p) { l in l.parentID.map { ids.contains($0) } ?? false }
            p.layers.removeAll { ids.contains($0.id) }
        }
        selectedLayerID = nil
        endMultiSelect()
    }

    func duplicateMulti() {
        guard let ids = multiSelection, !ids.isEmpty else { return }
        var newIDs = Set<UUID>()
        mutate("Duplicate \(ids.count) Layers") { p in
            var out: [Layer] = []
            var remap: [UUID: UUID] = [:]
            for l in p.layers where ids.contains(l.id) { remap[l.id] = UUID() }
            for l in p.layers {
                if ids.contains(l.id) {
                    var c = l; c.id = remap[l.id]!; c.name += " copy"
                    // Copies of a parent+child pair stay linked to each other, not to the originals.
                    if let pid = c.parentID, let np = remap[pid] { c.parentID = np }
                    out.append(c); newIDs.insert(c.id)
                }
                out.append(l)
            }
            p.layers = out
        }
        multiSelection = newIDs
    }

    /// Groups the selection into one pre-comp, keeping order and timing.
    func precomposeMulti(name: String? = nil) {
        guard let ids = multiSelection, !ids.isEmpty else { return }
        var clean = project
        Self.unparentKeepingWorld(&clean) { l in
            guard let pid = l.parentID else { return false }
            return ids.contains(l.id) != ids.contains(pid)
        }
        if clean != project { mutate("Unlink Parents") { $0 = clean } }
        let picked = project.layers.filter { ids.contains($0.id) }
        guard let firstIndex = project.layers.firstIndex(where: { ids.contains($0.id) }) else { return }
        var comp = Project.new(name: name ?? "Group \(project.precomps.count + 1)", width: project.width, height: project.height,
                               fps: project.fps, duration: project.duration, background: RGBA(0, 0, 0, 0))
        comp.layers = picked
        var newID = UUID()
        mutate("Pre-compose \(picked.count) Layers") { p in
            var all = p.precomps; all.append(comp); p.precomps = all
            var pl = p.makeLayer(name: comp.name, content: .precomp(id: comp.id), size: Vec2(Double(p.width), Double(p.height)))
            pl.inPoint = picked.map(\.inPoint).min() ?? 0
            pl.outPoint = picked.map(\.outPoint).max() ?? p.duration
            pl.sourceStart = pl.inPoint
            pl.tag = .teal
            newID = pl.id
            p.layers.removeAll { ids.contains($0.id) }
            p.layers.insert(pl, at: min(firstIndex, p.layers.count))
        }
        selectedLayerID = newID
        multiSelection = nil; multiAnchor = nil
        panel = .transform
    }

    func setVisibilityMulti(_ visible: Bool) {
        guard let ids = multiSelection else { return }
        mutate(visible ? "Show Layers" : "Hide Layers") { p in for i in p.layers.indices where ids.contains(p.layers[i].id) { p.layers[i].isVisible = visible } }
    }

    func make3DMulti(_ on: Bool) {
        guard let ids = multiSelection else { return }
        mutate(on ? "Make 3D" : "Make 2D") { p in
            for i in p.layers.indices where ids.contains(p.layers[i].id) && p.layers[i].content != .camera && p.layers[i].content != .adjustment {
                p.layers[i].is3D = on
            }
        }
    }

    /// Offsets each selected layer's timing so they start one after another (cascade / stagger).
    func staggerMulti(step: Double) {
        guard let ids = multiSelection else { return }
        mutate("Stagger Layers") { p in
            let start = p.layers.filter { ids.contains($0.id) }.map(\.inPoint).min() ?? 0
            var k = 0.0
            for i in p.layers.indices where ids.contains(p.layers[i].id) {
                let shift = p.snapToFrame(start + k * step) - p.layers[i].inPoint
                p.layers[i].shiftTiming(by: shift, duration: p.duration)
                k += 1
            }
        }
    }

    /// Aligns the selection in the comp: 0 left, 1 center, 2 right (x) / 3 top, 4 middle, 5 bottom (y).
    func alignMulti(_ mode: Int) {
        guard let ids = multiSelection else { return }
        let t = currentTime
        mutate("Align Layers") { p in
            for i in p.layers.indices where ids.contains(p.layers[i].id) {
                let hs = Renderer.layerHalfSize(p.layers[i], time: t)
                let sc = p.layers[i].transform.scale.value(at: t) * 0.01
                var pos = p.layers[i].transform.position.value(at: t)
                let w = Double(p.width), h = Double(p.height)
                switch mode {
                case 0: pos.x = hs.x * abs(sc.x)
                case 1: pos.x = w / 2
                case 2: pos.x = w - hs.x * abs(sc.x)
                case 3: pos.y = hs.y * abs(sc.y)
                case 4: pos.y = h / 2
                default: pos.y = h - hs.y * abs(sc.y)
                }
                p.layers[i].transform.position.set(pos, at: t)
            }
        }
    }

    func trimMultiToPlayhead(keepAfter: Bool) {
        guard let ids = multiSelection else { return }
        let t = currentTime
        mutate(keepAfter ? "Trim Start" : "Trim End") { p in
            for i in p.layers.indices where ids.contains(p.layers[i].id) {
                if keepAfter, t > p.layers[i].inPoint, t < p.layers[i].outPoint {
                    p.layers[i].sourceStart += (t - p.layers[i].inPoint) * p.layers[i].speed
                    p.layers[i].inPoint = t
                }
                if !keepAfter, t > p.layers[i].inPoint, t < p.layers[i].outPoint { p.layers[i].outPoint = t }
            }
        }
    }
}

extension Layer {
    /// Moves the layer and all its keyframes in time.
    mutating func shiftTiming(by dt: Double, duration: Double) {
        guard dt != 0 else { return }
        let len = outPoint - inPoint
        inPoint = max(0, inPoint + dt)
        outPoint = inPoint + len
        transform.position.shift(by: dt); transform.scale.shift(by: dt); transform.rotation.shift(by: dt)
        transform.opacity.shift(by: dt); transform.anchor.shift(by: dt)
        transform.rotationX.shift(by: dt); transform.rotationY.shift(by: dt); transform.positionZ.shift(by: dt)
        size.shift(by: dt); fill.shift(by: dt); cornerRadius.shift(by: dt); sides.shift(by: dt); innerRatio.shift(by: dt)
        volume.shift(by: dt); extrude.shift(by: dt); timeRemap?.shift(by: dt); path?.shift(by: dt)
        for i in effects.indices {
            for (k, v) in effects[i].params {
                switch v {
                case .number(var a): a.shift(by: dt); effects[i].params[k] = .number(a)
                case .point(var a): a.shift(by: dt); effects[i].params[k] = .point(a)
                case .color(var a): a.shift(by: dt); effects[i].params[k] = .color(a)
                default: break
                }
            }
        }
        for i in masks.indices { masks[i].path.shift(by: dt) }
        if camera != nil { camera!.zoom.shift(by: dt); camera!.focusDistance.shift(by: dt); camera!.aperture.shift(by: dt); camera!.blurLevel.shift(by: dt) }
        if model3D != nil { model3D!.yaw.shift(by: dt); model3D!.pitch.shift(by: dt); model3D!.roll.shift(by: dt); model3D!.color.shift(by: dt) }
        if light != nil { light!.color.shift(by: dt); light!.intensity.shift(by: dt); light!.coneAngle.shift(by: dt); light!.coneFeather.shift(by: dt); light!.falloffRadius.shift(by: dt) }
        if text != nil { text!.fill.shift(by: dt); text!.tracking.shift(by: dt) }
    }
}

extension Animated {
    mutating func shift(by dt: Double) {
        keyframes = keyframes.map { var k = $0; k.time = max(0, k.time + dt); return k }
    }
}

/// Bottom panel while several layers are selected.
struct MultiSelectPanel: View {
    @ObservedObject var state: EditorState
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(state.multiSelection?.count ?? 0) selected").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                Button("All") { state.selectAllLayers() }.font(.system(size: 13, weight: .semibold))
                Button("Done") { state.endMultiSelect() }.font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accentGlow)
                    .padding(.leading, 10)
            }
            .padding(.horizontal, 14).padding(.top, 10)
            Text("Hold the left side of a layer and drag up/down to select a range · tap layers to add / remove")
                .font(.caption2).foregroundStyle(Theme.textDim).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    section("Layers") {
                        ToolTile(icon: "folder.badge.plus", title: "Group") { state.groupSelected() }
                        ToolTile(icon: "square.stack.3d.up", title: "Pre-compose") { state.precomposeMulti() }
                        ToolTile(icon: "plus.square.on.square", title: "Duplicate") { state.duplicateMulti() }
                        ToolTile(icon: "trash", title: "Delete") { state.deleteMulti() }
                    }
                    section("Timing") {
                        ToolTile(icon: "arrow.right.to.line", title: "Trim Start") { state.trimMultiToPlayhead(keepAfter: true) }
                        ToolTile(icon: "arrow.left.to.line", title: "Trim End") { state.trimMultiToPlayhead(keepAfter: false) }
                        ToolTile(icon: "stairs", title: "Stagger") { state.staggerMulti(step: 0.1) }
                    }
                    section("View") {
                        ToolTile(icon: "eye", title: "Show") { state.setVisibilityMulti(true) }
                        ToolTile(icon: "eye.slash", title: "Hide") { state.setVisibilityMulti(false) }
                        ToolTile(icon: "cube", title: "Make 3D") { state.make3DMulti(true) }
                        ToolTile(icon: "square", title: "Make 2D") { state.make3DMulti(false) }
                    }
                    Text("ALIGN").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                    HStack(spacing: 8) {
                        ForEach(Array(["align.horizontal.left", "align.horizontal.center", "align.horizontal.right",
                                       "align.vertical.top", "align.vertical.center", "align.vertical.bottom"].enumerated()), id: \.offset) { i, icon in
                            Button { state.alignMulti(i) } label: {
                                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 36)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface)).foregroundStyle(Theme.text)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
            Spacer(minLength: 0)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
            HStack(spacing: 8) { content() }
        }
    }
}
