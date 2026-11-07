import SwiftUI
import UniformTypeIdentifiers

/// CC Studio: color grading workspace for the selected layer (or an adjustment layer over everything).
/// Every control is a value (drag or type) on the layer's CC Studio Grade effect, so it can be keyframed.
struct CCStudioPanel: View {
    @ObservedObject var state: EditorState
    @State private var section = 0
    @State private var curveChannel = 0
    @State private var curvePoint: String?
    @State private var knot: Int?
    @State private var importLUT = false
    @State private var luts = LUTLibrary.shared.names()
    @State private var looks = LookLibrary.names()
    @State private var lookName = ""
    @State private var scopes: GradeScopes?
    @State private var scopeKind = GradeScopes.Kind.histogram
    @State private var scopeToken = ""
    @State private var scopeQueue = ScopeRenderQueueOf<GradeScopes>()
    @State private var confirmLook: String?
    @State private var picking = false
    @State private var showWheelNumbers = false

    private var gradeIndex: Int? { state.selectedLayer?.effects.firstIndex { $0.typeID == EffectRegistry.grade.id } }
    private var grade: EffectInstance? { gradeIndex.flatMap { state.selectedLayer?.effects[$0] } }

    private static let sections = ["Basic", "Wheels", "Curves", "HSL", "LUT", "Looks"]
    private static let channels = ["Master", "Red", "Green", "Blue", "Hue vs Hue", "Hue vs Sat", "Hue vs Lum", "Luma vs Sat"]

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "CC Studio")
            if state.selectedLayer == nil {
                VStack(spacing: 10) {
                    Text("Grade one layer, or the whole edit with an adjustment layer.").font(.caption).foregroundStyle(Theme.textDim)
                    Button { state.addGradeAdjustment() } label: { Label("Grade Everything (Adjustment Layer)", systemImage: "camera.filters") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(14)
            } else if grade == nil {
                VStack(spacing: 10) {
                    Button { state.addEffect(EffectRegistry.grade); state.panel = .ccStudio } label: { Label("Add Grade to This Layer", systemImage: "camera.filters") }
                        .buttonStyle(PrimaryButtonStyle())
                    Button { state.addGradeAdjustment() } label: { Label("Grade Everything Below (Adjustment Layer)", systemImage: "square.3.layers.3d") }
                }
                .padding(14)
            } else if let g = grade {
                chips(Self.sections, selection: $section)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        toolsRow(g)
                        if picking { pickerFrame(g) }
                        CCScopeView(scopes: scopes, kind: $scopeKind)
                        switch section {
                        case 0:
                            group(g, ["exposure", "contrast", "highlights", "shadows", "temp", "tint", "vibrance", "saturation"])
                            row(g, "split")
                        case 1:
                            wheelsSection(g)
                        case 2:
                            curvesSection(g)
                        case 3:
                            qualifierSection(g)
                        case 4:
                            lutSection(g)
                        default:
                            looksSection(g)
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
        }
        .fileImporter(isPresented: $importLUT, allowedContentTypes: [UTType(filenameExtension: "cube") ?? .data, .data], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r { for u in urls { _ = try? LUTLibrary.shared.importFile(u) } }
            luts = LUTLibrary.shared.names()
        }
        .onAppear(perform: refreshScopes)
        .onChange(of: state.project.modifiedAt) { _, _ in refreshScopes() }
        // Scrubbing the playhead refreshes the scopes too.
        .onChange(of: state.currentTime) { _, _ in refreshScopes() }
        .onChange(of: curveChannel) { _, _ in curvePoint = nil; knot = nil }
    }

    // MARK: Layout pieces

    /// A row of 44 pt chips that scrolls sideways (labels never squeeze).
    private func chips(_ titles: [String], selection: Binding<Int>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(titles.indices, id: \.self) { i in
                    Button { selection.wrappedValue = i } label: {
                        Text(titles[i]).font(.system(size: 13, weight: .semibold)).lineLimit(1).fixedSize()
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .background(Capsule().fill(selection.wrappedValue == i ? Theme.accent.opacity(0.85) : Theme.surface))
                            .foregroundStyle(selection.wrappedValue == i ? Color.white : Theme.text)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
        }
        .padding(.bottom, 6)
    }

    /// Bypass, A / B versions and the white-balance eyedropper.
    private func toolsRow(_ g: EffectInstance) -> some View {
        HStack(spacing: 8) {
            toolButton(g.isEnabled ? "Bypass" : "Bypassed", g.isEnabled ? "eye" : "eye.slash", on: !g.isEnabled) { state.toggleEffect(g.id) }
                .accessibilityLabel(g.isEnabled ? "Bypass grade" : "Turn grade back on")
            toolButton("Version \(GradeR4.slot(g))", "square.on.square", on: g.text?["gradeAlt"] != nil) {
                state.mutate("Switch Grade A/B") { p in
                    guard let i = state.selectedIndex, let j = p.layers[i].effects.firstIndex(where: { $0.id == g.id }) else { return }
                    p.layers[i].effects[j] = GradeR4.swapAB(p.layers[i].effects[j])
                }
            }
            .accessibilityLabel("Switch between grade versions A and B, now \(GradeR4.slot(g))")
            toolButton("White Bal.", "eyedropper", on: picking) { picking.toggle() }
                .accessibilityLabel("White balance eyedropper")
        }
    }

    private func toolButton(_ title: String, _ icon: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(on ? Theme.accent.opacity(0.35) : Theme.surface))
                .foregroundStyle(on ? Theme.accentGlow : Theme.text)
        }
        .buttonStyle(.plain)
    }

    /// The frame at the playhead: tap something that should be neutral grey or white.
    private func pickerFrame(_ g: EffectInstance) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tap something that should be white or grey.").font(.caption).foregroundStyle(Theme.textDim)
            if let s = scopes, let img = s.frame {
                GeometryReader { geo in
                    Image(decorative: img, scale: 1).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture { loc in
                            let aspect = Double(s.width) / Double(max(1, s.height))
                            let fw = min(Double(geo.size.width), Double(geo.size.height) * aspect), fh = fw / aspect
                            let ox = (Double(geo.size.width) - fw) / 2, oy = (Double(geo.size.height) - fh) / 2
                            let u = (Double(loc.x) - ox) / fw, v = (Double(loc.y) - oy) / fh
                            guard (0...1).contains(u), (0...1).contains(v), let c = s.sample(atX: u, y: v) else { return }
                            neutralize(g, c)
                        }
                }
                .frame(height: 150)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
            }
        }
    }

    private func neutralize(_ g: EffectInstance, _ c: (Double, Double, Double)) {
        let d = GradeR4.whiteBalanceDelta(r: c.0, g: c.1, b: c.2)
        let t = state.currentTime
        state.beginEdit("White Balance")
        CCLive.set(state, g, "temp", min(100, max(-100, GradeR4.num(g, "temp", t) + d.temp)))
        CCLive.set(state, g, "tint", min(100, max(-100, GradeR4.num(g, "tint", t) + d.tint)))
        state.endEdit()
        picking = false
    }

    // MARK: Controls

    private func def(_ k: String) -> ParamDef? { EffectRegistry.gradeParams.first { $0.id == k } }

    private func row(_ g: EffectInstance, _ k: String, label: String? = nil) -> some View {
        let d = def(k)
        var lo = -100.0, hi = 100.0, step = 0.0, unit = ""
        if case .number(let a, let b, let s, let u)? = d?.kind { lo = a; hi = b; step = s; unit = u }
        let kf = state.effectParamHasKeyframe(g.id, k)
        return HStack {
            KeyframeDiamond(filled: kf.filled, animated: kf.animated) { state.toggleEffectKeyframe(g.id, k) }
            Text(label ?? d?.name ?? k).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 96, alignment: .leading).lineLimit(2).minimumScaleFactor(0.85)
            ValueScrubber(value: GradeR4.num(g, k, state.currentTime), range: lo...hi, step: step, unit: unit,
                          onBegin: { state.beginEdit("Grade") },
                          onChange: { v in CCLive.set(state, g, k, v) },
                          onEnd: { state.endEdit() })
        }
    }

    private func group(_ g: EffectInstance, _ keys: [String]) -> some View {
        VStack(spacing: 6) { ForEach(keys, id: \.self) { row(g, $0) } }
    }

    private func toggleRow(_ g: EffectInstance, _ k: String, _ title: String) -> some View {
        Toggle(isOn: Binding(get: { GradeR4.flag(g, k) }, set: { b in
            state.beginEdit(title); CCLive.setFlag(state, g, k, b); state.endEdit()
        })) { Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text) }
        .tint(Theme.accent).frame(minHeight: 44)
    }

    private func wheelsSection(_ g: EffectInstance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                CCColorWheel(state: state, effect: g, title: "Lift", prefix: "lift")
                CCColorWheel(state: state, effect: g, title: "Gamma", prefix: "gamma")
                CCColorWheel(state: state, effect: g, title: "Gain", prefix: "gain")
                CCColorWheel(state: state, effect: g, title: "Offset", prefix: "off")
            }
            Text("Drag the puck to tint, drag around the ring for brightness.").font(.caption).foregroundStyle(Theme.textDim)
            DisclosureGroup(isExpanded: $showWheelNumbers) {
                VStack(spacing: 6) {
                    ForEach(["lift", "gamma", "gain", "off"], id: \.self) { p in group(g, [p + "R", p + "G", p + "B"]) }
                }
                .padding(.top, 6)
            } label: {
                Text("Wheel numbers").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).frame(minHeight: 44)
            }
            .tint(Theme.textDim)
        }
    }

    private func curvesSection(_ g: EffectInstance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            chips(Self.channels, selection: $curveChannel).padding(.horizontal, -10)
            if curveChannel < 4 {
                let c = ["m", "r", "g", "b"][curveChannel]
                CCCurveGraph(state: state, effect: g, channel: c, selected: $curvePoint).frame(height: 200)
                Text("Tap the curve to add a point, drag to move it.").font(.caption).foregroundStyle(Theme.textDim)
                curvePointEditor(g, c)
            } else {
                let prefix = ["hueHue", "hueSat", "hueLum", "lumSat"][curveChannel - 4]
                CCKnotGraph(state: state, effect: g, prefix: prefix, selected: $knot).frame(height: 190)
                if let k = knot, k < GradeR4.knotXs(prefix).count {
                    row(g, "\(prefix)\(k)", label: prefix == "lumSat" ? GradeR4.lumaKnotNames[k] : GradeR4.vectorNames[k])
                } else {
                    Text(prefix == "lumSat" ? "Drag a point to change saturation by brightness." : "Each point is one color vector. Drag it up or down.")
                        .font(.caption).foregroundStyle(Theme.textDim)
                }
            }
        }
    }

    @ViewBuilder private func curvePointEditor(_ g: EffectInstance, _ c: String) -> some View {
        if let id = curvePoint, id == "mBlack" || id == "mWhite" {
            row(g, id)
        } else if let id = curvePoint, let slot = GradeR4.slots(c).first(where: { $0.on == id }), GradeR4.flag(g, slot.on) {
            row(g, slot.x, label: "Input")
            row(g, slot.y, label: "Output")
            Button(role: .destructive) {
                state.beginEdit("Remove Curve Point")
                CCLive.setFlag(state, g, slot.on, false)
                state.endEdit()
                curvePoint = nil
            } label: {
                Label("Remove Point", systemImage: "minus.circle").font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44).background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.danger)
        }
    }

    private func qualifierSection(_ g: EffectInstance) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("QUALIFY").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
            Rectangle().fill(LinearGradient(colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 1, brightness: 1) }, startPoint: .leading, endPoint: .trailing))
                .frame(height: 10).clipShape(Capsule())
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule().strokeBorder(.white, lineWidth: 2)
                            .frame(width: max(8, geo.size.width * CGFloat(GradeR4.num(g, "hslRange", state.currentTime) / 360) * 2), height: 14)
                            .position(x: geo.size.width * CGFloat(GradeR4.num(g, "hslHue", state.currentTime) / 360), y: 5)
                    }
                }
            group(g, ["hslHue", "hslRange", "qSoft", "qSatLo", "qSatHi", "qLumLo", "qLumHi"])
            toggleRow(g, "qShow", "Show Mask")
            Text("ADJUST").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim).padding(.top, 4)
            group(g, ["hslShift", "hslSat", "hslLight"])
            Text("Per-color Hue / Sat / Lum vectors are under Curves.").font(.caption).foregroundStyle(Theme.textDim)
        }
    }

    private func lutSection(_ g: EffectInstance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { importLUT = true } label: { Label("Import .cube LUT", systemImage: "square.and.arrow.down") }.buttonStyle(PrimaryButtonStyle())
            row(g, "lutStrength")
            let current = g.text?["lut"]
            if let current, !luts.contains(current), !LUTLibrary.builtInFiles.contains(current) {
                // The grade names a LUT that isn't on this device (moved project / deleted file): it renders without it.
                Label("Missing LUT \"\((current as NSString).deletingPathExtension)\" — import it to restore the look.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(Theme.warning)
            }
            lutButton(g, nil, selected: current == nil)
            Text("BUILT-IN LOOKS").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim).padding(.top, 4)
            ForEach(LUTLibrary.builtInFiles, id: \.self) { name in lutButton(g, name, selected: current == name) }
            let own = luts.filter { !LUTLibrary.builtInFiles.contains($0) }
            Text("YOUR LUTS").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim).padding(.top, 4)
            ForEach(own, id: \.self) { name in lutButton(g, name, selected: current == name) }
            if own.isEmpty { Text("LUTs you import stay here for every project.").font(.caption).foregroundStyle(Theme.textDim) }
        }
    }

    private func lutButton(_ g: EffectInstance, _ name: String?, selected: Bool) -> some View {
        Button {
            state.mutate("LUT") { p in
                guard let i = state.selectedIndex, let j = p.layers[i].effects.firstIndex(where: { $0.id == g.id }) else { return }
                var t = p.layers[i].effects[j].text ?? [:]
                t["lut"] = name
                p.layers[i].effects[j].text = t.isEmpty ? nil : t
            }
        } label: {
            HStack {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Theme.accentGlow : Theme.textDim)
                Text(name.map { ($0 as NSString).deletingPathExtension } ?? "No LUT").foregroundStyle(Theme.text)
                Spacer()
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { if let name { Button(role: .destructive) { LUTLibrary.shared.remove(name); luts = LUTLibrary.shared.names() } label: { Label("Remove LUT", systemImage: "trash") } } }
    }

    private func looksSection(_ g: EffectInstance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Look name", text: $lookName).padding(9).glass(radius: 10).foregroundStyle(Theme.text)
                Button("Save Look") {
                    let n = lookName.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    // Saved in the app library and inside the project, so it travels with the project.
                    LookLibrary.save(n, g)
                    state.mutate("Save Look") { p in var all = p.savedLooks ?? [:]; all[n] = g; p.savedLooks = all }
                    looks = LookLibrary.names(); lookName = ""
                }
                .font(.system(size: 13, weight: .semibold))
            }
            let names = LookLibrary.allNames(project: state.project)
            ForEach(names, id: \.self) { n in
                Button {
                    // Keyframed grade: ask whether to keep the keyframes (merge) or replace everything.
                    if g.params.values.contains(where: { !$0.keyframeTimes.isEmpty }) { confirmLook = n } else { applyLook(n, to: g, merge: false) }
                } label: {
                    HStack {
                        Image(systemName: "camera.filters"); Text(n); Spacer()
                        if state.project.savedLooks?[n] != nil { Image(systemName: "doc.fill").font(.caption2).foregroundStyle(Theme.textDim) }
                    }
                    .foregroundStyle(Theme.text).frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        LookLibrary.remove(n); looks = LookLibrary.names()
                        if state.project.savedLooks?[n] != nil {
                            state.mutate("Delete Look") { p in p.savedLooks?[n] = nil; if p.savedLooks?.isEmpty == true { p.savedLooks = nil } }
                        }
                    } label: { Label("Delete Look", systemImage: "trash") }
                }
            }
            if names.isEmpty { Text("Save a grade as a Look to reuse it on any layer or project.").font(.caption).foregroundStyle(Theme.textDim) }
        }
        .confirmationDialog("This grade has keyframes", isPresented: Binding(get: { confirmLook != nil }, set: { if !$0 { confirmLook = nil } }),
                            titleVisibility: .visible) {
            if let n = confirmLook {
                Button("Apply at Playhead (keep keyframes)") { applyLook(n, to: g, merge: true); confirmLook = nil }
                Button("Replace Grade (remove keyframes)", role: .destructive) { applyLook(n, to: g, merge: false); confirmLook = nil }
                Button("Cancel", role: .cancel) { confirmLook = nil }
            }
        }
    }

    private func applyLook(_ n: String, to g: EffectInstance, merge: Bool) {
        guard let saved = LookLibrary.look(n, project: state.project) else { return }
        let t = state.currentTime
        state.mutate("Apply Look \(n)") { p in
            guard let i = state.selectedIndex, let j = p.layers[i].effects.firstIndex(where: { $0.id == g.id }) else { return }
            let current = p.layers[i].effects[j]
            p.layers[i].effects[j] = merge ? LookLibrary.merged(saved, into: current, at: t) : LookLibrary.replaced(saved, into: current)
        }
        // A Look that points at a LUT this device doesn't have: say so instead of silently grading without it.
        if let lut = saved.text?["lut"], !LUTLibrary.shared.names().contains(lut) {
            state.recoveryNotice = "The Look \"\(n)\" uses the LUT \"\(lut)\", which isn't on this device. Import it in CC Studio > LUT."
        }
    }

    // MARK: Scopes

    /// Scopes of the frame at the playhead (rendered small, analysed off the main thread). Follows scrubbing and
    /// edits; one render at a time (latest request wins) and waits while a live gesture drives the preview.
    private func refreshScopes() {
        guard !state.isLiveGesture else { return }   // the gesture's end changes modifiedAt and refreshes
        let p = state.project, t = state.currentTime, pid = p.id, store = state.store
        let token = "\(p.modifiedAt.timeIntervalSince1970)|\(t)"
        guard token != scopeToken else { return }
        scopeToken = token
        scopeQueue.submit(token: token) {
            guard let r = Renderer.shared,
                  let px = r.renderPixels(project: p, time: t, renderScale: min(1, 200 / Double(max(p.width, p.height))),
                                          mediaURL: { store.mediaURL($0, projectID: pid) }) else { return nil }
            return GradeScopes.analyze(width: px.width, height: px.height, rgba: px.rgba)
        } apply: { s in scopes = s }
    }
}

/// Saved grades ("Looks"), kept for every project.
enum LookLibrary {
    private static let key = "awi.looks"
    private static func all() -> [String: EffectInstance] {
        guard let d = UserDefaults.standard.data(forKey: key), let v = try? JSONDecoder().decode([String: EffectInstance].self, from: d) else { return [:] }
        return v
    }
    private static func write(_ v: [String: EffectInstance]) {
        if let d = try? JSONEncoder().encode(v) { UserDefaults.standard.set(d, forKey: key) }
    }
    static func names() -> [String] { all().keys.sorted() }
    static func save(_ name: String, _ e: EffectInstance) { var a = all(); a[name] = e; write(a) }
    static func load(_ name: String) -> EffectInstance? { all()[name] }
    static func remove(_ name: String) { var a = all(); a[name] = nil; write(a) }

    /// Looks saved in the app plus the ones carried inside the project.
    static func allNames(project: Project) -> [String] { Set(names()).union((project.savedLooks ?? [:]).keys).sorted() }
    /// The project's own copy wins (it is the one that travelled with the project).
    static func look(_ name: String, project: Project) -> EffectInstance? { project.savedLooks?[name] ?? load(name) }

    /// Replace: the grade becomes the Look (same effect id and switch; controls the Look lacks reset to default).
    static func replaced(_ look: EffectInstance, into current: EffectInstance) -> EffectInstance {
        var out = current
        out.params = look.params
        out.text = look.text
        return out
    }

    /// Merge at the playhead: animated controls keep their keyframes (the Look's value is keyed at `t`); everything
    /// else takes the Look's value. Controls the Look lacks go back to default unless they are animated.
    static func merged(_ look: EffectInstance, into current: EffectInstance, at t: Double) -> EffectInstance {
        var out = current
        for (k, v) in look.params {
            switch (current.params[k], v) {
            case (.number(var a)?, .number(let b)) where a.isAnimated && !b.isAnimated:
                a.set(b.value(at: t), at: t); out.params[k] = .number(a)
            case (.point(var a)?, .point(let b)) where a.isAnimated && !b.isAnimated:
                a.set(b.value(at: t), at: t); out.params[k] = .point(a)
            case (.color(var a)?, .color(let b)) where a.isAnimated && !b.isAnimated:
                a.set(b.value(at: t), at: t); out.params[k] = .color(a)
            default:
                out.params[k] = v
            }
        }
        let defaults = EffectRegistry.definition(current.typeID)?.params ?? []
        for (k, v) in current.params where look.params[k] == nil && v.keyframeTimes.isEmpty {
            if let d = defaults.first(where: { $0.id == k }) { out.params[k] = d.defaultValue } else { out.params[k] = nil }
        }
        out.text = look.text
        return out
    }
}

extension EditorState {
    /// An adjustment layer on top carrying a grade: grades everything below it.
    func addGradeAdjustment() {
        mutate("Add Grade Layer") { p in
            var l = p.makeLayer(name: "Grade", content: .adjustment, size: Vec2(Double(p.width), Double(p.height)))
            l.effects = [EffectRegistry.grade.makeInstance()]
            l.tag = .amber
            l.outPoint = p.duration
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .ccStudio
    }
}
