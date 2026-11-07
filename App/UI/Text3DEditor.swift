import SwiftUI

/// 3D tab: real extruded 3D text (Text3DOptions on the layer), plus the older flat-slab and solid-model options.
struct Text3DTab: View {
    @ObservedObject var state: EditorState
    @State private var part: Part = .front

    enum Part: Hashable { case front, bevel, side }

    var body: some View {
        if let l = state.selectedLayer, l.text != nil {
            VStack(alignment: .leading, spacing: 8) {
                TSToggleRow(title: "Real 3D text", detail: "Each letter is a solid with depth, bevel and materials. Letter animators turn and push them in real 3D.",
                            isOn: l.text?.text3D != nil) { on in
                    state.beginEdit(on ? "Real 3D Text On" : "Real 3D Text Off")
                    state.mutateLayer { layer in
                        if on {
                            let existing = layer.text?.text3D
                            layer.text?.text3D = existing ?? Text3DOptions()
                            layer.is3D = true
                        } else { layer.text?.text3D = nil }
                    }
                    state.endEdit()
                }
                if let o = l.text?.text3D { realControls(o) } else { legacy(l) }
            }
        }
    }

    // MARK: Real 3D

    private func edit(_ label: String, _ change: (inout Text3DOptions) -> Void) {
        state.beginEdit(label)
        state.mutateLayer { l in if var o = l.text?.text3D { change(&o); l.text?.text3D = o } }
        state.endEdit()
    }

    private func live(_ change: (inout Text3DOptions) -> Void) {
        state.mutateLayer { l in if var o = l.text?.text3D { change(&o); l.text?.text3D = o } }
    }

    private typealias Writer = (inout Text3DOptions, (inout Animated<Double>) -> Void) -> Void

    private func number(_ title: String, _ a: Animated<Double>, _ range: ClosedRange<Double>, unit: String = "", beyond: Bool = false,
                        _ write: @escaping Writer) -> some View {
        let t = state.currentTime
        return TSNumberRow(title: title, value: a.value(at: t), range: range, unit: unit, allowBeyond: beyond,
                           key: (a.hasKeyframe(at: t), a.isAnimated, { edit("Keyframe \(title)") { o in write(&o) { $0.toggleKeyframe(at: t) } } }),
                           onBegin: { state.beginEdit(title) },
                           onChange: { v in live { o in write(&o) { $0.set(v, at: t) } } },
                           onEnd: { state.endEdit() })
    }

    @ViewBuilder private func realControls(_ o: Text3DOptions) -> some View {
        TSSection(title: "Looks")
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(Array(Text3DMaterial.presets.enumerated()), id: \.offset) { _, p in
                TSButton(title: p.name) { edit("3D Look \(p.name)") { $0.front = p.material; $0.bevel = p.material; $0.side = p.material } }
            }
        }
        Group {
        TSSection(title: "Shape")
        number("Extrusion", o.extrusion, 0...400, unit: "px", beyond: true) { o, w in w(&o.extrusion) }
        number("Bevel Size", o.bevelSize, 0...40, unit: "px", beyond: true) { o, w in w(&o.bevelSize) }
        TSNumberRow(title: "Bevel Segments", value: Double(o.bevelSegments), range: 1...12, step: 1, key: nil,
                    onBegin: { state.beginEdit("Bevel Segments") },
                    onChange: { v in live { $0.bevelSegments = max(1, min(12, Int(v.rounded()))) } },
                    onEnd: { state.endEdit() })
        TSSegmented(options: [(Text3DBevelProfile.flat, "Flat"), (.round, "Round"), (.angle, "Angle")], selection: o.bevelProfile, label: "Bevel Profile") { p in
            edit("Bevel Profile") { $0.bevelProfile = p }
        }
        }
        Group {
        TSSection(title: "Material")
        TSSegmented(options: [(Part.front, "Front"), (.bevel, "Bevel"), (.side, "Sides")], selection: part, label: "Material Part") { part = $0 }
        materialEditor(material(o, part))
        TSButton(title: "Use this material on all parts", icon: "square.stack.3d.up") {
            let m = material(o, part)
            edit("Same Material") { $0.front = m; $0.bevel = m; $0.side = m }
        }
        }
        Group {
        TSSection(title: "Environment")
        number("Reflections", o.environmentIntensity, 0...4) { o, w in w(&o.environmentIntensity) }
        number("Environment Turn", o.environmentRotation, -180...180, unit: "°", beyond: true) { o, w in w(&o.environmentRotation) }
        Text("Scene lights and the camera light and frame the 3D letters. Effects, masks and depth of field still apply to the layer.")
            .font(.caption).foregroundStyle(Theme.textDim)
        }
    }

    private func material(_ o: Text3DOptions, _ p: Part) -> Text3DMaterial {
        switch p { case .front: return o.front; case .bevel: return o.bevel; case .side: return o.side }
    }

    private func withPart(_ o: inout Text3DOptions, _ change: (inout Text3DMaterial) -> Void) {
        switch part {
        case .front: change(&o.front)
        case .bevel: change(&o.bevel)
        case .side: change(&o.side)
        }
    }

    @ViewBuilder private func materialEditor(_ m: Text3DMaterial) -> some View {
        let t = state.currentTime
        let partName = part == .front ? "Front" : (part == .bevel ? "Bevel" : "Sides")
        TSMenuRow(title: "\(partName) Look", options: [("", "Custom")] + Text3DMaterial.presets.map { ($0.name, $0.name) },
                  selection: Text3DMaterial.presets.first { $0.material == m }?.name ?? "") { name in
            guard let p = Text3DMaterial.preset(named: name) else { return }
            edit("\(partName) Look") { o in withPart(&o) { $0 = p } }
        }
        TSColorRow(title: "Color", color: m.color.value(at: t),
                   key: (m.color.hasKeyframe(at: t), m.color.isAnimated, { edit("Keyframe Color") { o in withPart(&o) { $0.color.toggleKeyframe(at: t) } } })) { c in
            edit("\(partName) Color") { o in withPart(&o) { $0.color.set(c, at: t) } }
        }
        number("Metal", m.metalness, 0...1) { o, w in withPart(&o) { w(&$0.metalness) } }
        number("Roughness", m.roughness, 0...1) { o, w in withPart(&o) { w(&$0.roughness) } }
        number("Glow", m.emission, 0...4) { o, w in withPart(&o) { w(&$0.emission) } }
        number("Clear Coat", m.clearcoat, 0...1) { o, w in withPart(&o) { w(&$0.clearcoat) } }
        number("Opacity", m.opacity, 0...1) { o, w in withPart(&o) { w(&$0.opacity) } }
        number("Glass", m.transmission, 0...1) { o, w in withPart(&o) { w(&$0.transmission) } }
        TSToggleRow(title: "Toon (cel shading + outline)", isOn: m.toon) { b in edit("Toon") { o in withPart(&o) { $0.toon = b } } }
    }

    // MARK: Older 3D options (kept for existing projects)

    @ViewBuilder private func legacy(_ l: Layer) -> some View {
        let t = state.currentTime
        TSSection(title: "Flat 3D layer")
        TSToggleRow(title: "3D layer (turns in space, catches lights)", isOn: l.is3D) { on in
            state.beginEdit("3D Text"); state.mutateLayer { $0.is3D = on; if on && $0.extrude.value(at: t) < 1 { $0.extrude = Animated(24) } }; state.endEdit()
        }
        if l.is3D {
            TSNumberRow(title: "Slab Depth", value: l.extrude.value(at: t), range: 0...300, unit: "px", allowBeyond: true,
                        key: (l.extrude.hasKeyframe(at: t), l.extrude.isAnimated, { state.beginEdit("Keyframe Depth"); state.mutateLayer { $0.extrude.toggleKeyframe(at: t) }; state.endEdit() }),
                        onBegin: { state.beginEdit("Depth") }, onChange: { v in state.mutateLayer { $0.extrude.set(v, at: t) } }, onEnd: { state.endEdit() })
            TSButton(title: "Make Solid 3D Model (separate model layer)", icon: "cube.fill") { state.makeSelected3DObject() }
        }
    }
}
