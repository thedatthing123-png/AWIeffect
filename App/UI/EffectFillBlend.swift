import SwiftUI

/// Fill style: Solid (the layer's own fill) or a Linear / Radial gradient (a Gradient Fill effect at the top of the
/// stack, every value keyframable). Switching back to Solid turns the gradient off (Undo restores it).
struct FillGradientSection: View {
    @ObservedObject var state: EditorState
    let layer: Layer

    private var gradient: EffectInstance? { layer.effects.first { $0.typeID == EffectRegistry.gradientR4.id } }
    private var style: Int { guard let g = gradient, g.isEnabled else { return 0 }; return 1 + g.choice("type") }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FILL STYLE").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
            HStack(spacing: 8) {
                chip("Solid", 0); chip("Linear", 1); chip("Radial", 2)
            }
            if style > 0, let g = gradient {
                ForEach(EffectRegistry.gradientR4.params.filter { $0.id != "type" }) { pd in ParamRow(state: state, effect: g, def: pd) }
                Text("Blend Normal = gradient fill; other blends = gradient overlay.").font(.caption).foregroundStyle(Theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ title: String, _ v: Int) -> some View {
        Button { pick(v) } label: {
            Text(title).font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(style == v ? Theme.accent.opacity(0.85) : Theme.surface))
                .foregroundStyle(style == v ? Color.white : Theme.text)
        }
        .buttonStyle(.plain)
    }

    private func pick(_ v: Int) {
        guard let i = state.selectedIndex else { return }
        let t = state.currentTime
        state.mutate(v == 0 ? "Solid Fill" : "Gradient Fill") { p in
            let id = EffectRegistry.gradientR4.id
            if let j = p.layers[i].effects.firstIndex(where: { $0.typeID == id }) {
                p.layers[i].effects[j].isEnabled = v != 0
                if v != 0 { p.layers[i].effects[j].params["type"] = .choice(v - 1) }
            } else if v != 0 {
                var e = EffectRegistry.gradientR4.makeInstance()
                e.params["type"] = .choice(v - 1)
                // Starts from the layer's own color so the switch doesn't jump.
                e.params["color1"] = .color(Animated(p.layers[i].fill.value(at: t)))
                p.layers[i].effects.insert(e, at: 0)
            }
        }
    }
}

/// Blend mode: the current mode large, then one row of chips grouped by family. Tapping a chip applies it at once
/// (the canvas is the live preview); one undo step per pick.
struct BlendModePicker: View {
    @ObservedObject var state: EditorState
    let layer: Layer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(layer.blendMode.title).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
                Text(layer.blendMode.group.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textDim)
                Spacer()
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(BlendMode.groups, id: \.self) { grp in
                            Text(grp.uppercased()).font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.textDim)
                                .rotationEffect(.degrees(-90)).fixedSize().frame(width: 16)
                            ForEach(BlendMode.allCases.filter { $0.group == grp }) { m in
                                Button {
                                    guard m != layer.blendMode else { return }
                                    state.mutate("Blend Mode") { p in if let i = state.selectedIndex { p.layers[i].blendMode = m } }
                                } label: {
                                    Text(m.title).font(.system(size: 12, weight: .semibold)).lineLimit(1).fixedSize()
                                        .padding(.horizontal, 12).frame(minHeight: 44)
                                        .background(Capsule().fill(layer.blendMode == m ? Theme.accent.opacity(0.85) : Theme.surface))
                                        .foregroundStyle(layer.blendMode == m ? Color.white : Theme.text)
                                }
                                .buttonStyle(.plain)
                                .id(m)
                            }
                        }
                    }
                }
                .onAppear { proxy.scrollTo(layer.blendMode, anchor: .center) }
            }
        }
    }
}

/// Track matte from any layer (not just the one above): pick it by tapping it on the canvas.
struct MatteFromLayerSection: View {
    @ObservedObject var state: EditorState
    let layer: Layer
    @State private var mode: TrackMatte = .alpha

    var body: some View {
        let current = state.matteSource(layer)
        VStack(alignment: .leading, spacing: 6) {
            Text("MATTE FROM ANY LAYER").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim).padding(.top, 6)
            if let cur = current {
                let id = cur.0, m = cur.1
                let name = state.project.layers.first { $0.id == id }?.name ?? "Missing layer"
                HStack(spacing: 8) {
                    Text("\(name) · \(m.title)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(2)
                    Spacer()
                    Button(role: .destructive) { state.setMatteSource(nil, mode: .none) } label: {
                        Label("Remove", systemImage: "minus.circle").font(.system(size: 12, weight: .semibold)).padding(.horizontal, 10).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.danger)
                }
            }
            HStack(spacing: 8) {
                Menu {
                    ForEach(TrackMatte.allCases.filter { $0 != .none }) { m in Button(m.title) { mode = m } }
                } label: {
                    HStack { Text(mode.title).lineLimit(1); Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)) }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentGlow)
                        .frame(maxWidth: .infinity, minHeight: 44).background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                }
                Button {
                    state.linkPickMatte = mode
                    state.beginLinkPick()
                } label: {
                    Label("Pick on Canvas", systemImage: "hand.tap").font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44).background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.35)))
                        .foregroundStyle(Theme.accentGlow)
                }
                .buttonStyle(.plain)
            }
            Text("Uses that layer's alpha or brightness wherever it is in the stack. The matte layer still draws on its own.").font(.caption).foregroundStyle(Theme.textDim)
        }
        .onAppear { if let m = current?.1 { mode = m } }
    }
}
