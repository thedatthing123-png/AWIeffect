import SwiftUI
import UniformTypeIdentifiers

/// CC Studio: color grading workspace for the selected layer (or an adjustment layer over everything).
/// Every control is a value (drag or type) on the layer's CC Studio Grade effect, so it can be keyframed.
struct CCStudioPanel: View {
    @ObservedObject var state: EditorState
    @State private var section = 0
    @State private var curveChannel = 0
    @State private var importLUT = false
    @State private var luts = LUTLibrary.shared.names()
    @State private var looks = LookLibrary.names()
    @State private var lookName = ""
    @State private var histogram: [[Float]] = []
    @State private var scopeToken = ""
    @State private var scopeQueue = ScopeRenderQueue()
    @State private var confirmLook: String?

    private var gradeIndex: Int? { state.selectedLayer?.effects.firstIndex { $0.typeID == EffectRegistry.grade.id } }
    private var grade: EffectInstance? { gradeIndex.flatMap { state.selectedLayer?.effects[$0] } }

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
                Picker("", selection: $section) {
                    Text("Basic").tag(0); Text("Wheels").tag(1); Text("Curves").tag(2); Text("HSL").tag(3); Text("LUT").tag(4); Text("Looks").tag(5)
                }
                .pickerStyle(.segmented).padding(.horizontal, 10).padding(.bottom, 6)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        scopes
                        switch section {
                        case 0:
                            group(g, ["exposure", "contrast", "highlights", "shadows", "temp", "tint", "vibrance", "saturation"])
                            row(g, "split")
                        case 1:
                            wheel(g, "Lift (Shadows)", "lift")
                            wheel(g, "Gamma (Mids)", "gamma")
                            wheel(g, "Gain (Highlights)", "gain")
                        case 2:
                            Picker("", selection: $curveChannel) { Text("Master").tag(0); Text("Red").tag(1); Text("Green").tag(2); Text("Blue").tag(3) }
                                .pickerStyle(.segmented)
                            CurveGraph(state: state, effect: g, prefix: ["m", "r", "g", "b"][curveChannel])
                                .frame(height: 180)
                            if curveChannel == 0 { group(g, ["mBlack", "m25", "m50", "m75", "mWhite"]) }
                            else { let p = ["", "r", "g", "b"][curveChannel]; group(g, [p + "25", p + "50", p + "75"]) }
                        case 3:
                            HStack {
                                Text("Target").font(.system(size: 12)).foregroundStyle(Theme.textDim)
                                Rectangle().fill(LinearGradient(colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 1, brightness: 1) }, startPoint: .leading, endPoint: .trailing))
                                    .frame(height: 10).clipShape(Capsule())
                            }
                            group(g, ["hslHue", "hslRange", "hslShift", "hslSat", "hslLight"])
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
        // Scrubbing the playhead refreshes the histogram too.
        .onChange(of: state.currentTime) { _, _ in refreshScopes() }
    }

    // MARK: Controls

    private func def(_ k: String) -> ParamDef? { EffectRegistry.gradeParams.first { $0.id == k } }

    private func row(_ g: EffectInstance, _ k: String) -> some View {
        let d = def(k)
        var lo = -100.0, hi = 100.0, step = 0.0, unit = ""
        if case .number(let a, let b, let s, let u)? = d?.kind { lo = a; hi = b; step = s; unit = u }
        return HStack {
            KeyframeDiamond(filled: state.effectParamHasKeyframe(g.id, k).filled, animated: state.effectParamHasKeyframe(g.id, k).animated) {
                state.toggleEffectKeyframe(g.id, k)
            }
            Text(d?.name ?? k).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 92, alignment: .leading).lineLimit(1).minimumScaleFactor(0.8)
            ValueScrubber(value: g.number(k, state.currentTime), range: lo...hi, step: step, unit: unit,
                          onBegin: { state.beginEdit("Grade") },
                          onChange: { v in state.setEffectParam(g.id, k) { pv, t in if case .number(var a) = pv { a.set(v, at: t); pv = .number(a) } } },
                          onEnd: { state.endEdit() })
        }
    }

    private func group(_ g: EffectInstance, _ keys: [String]) -> some View {
        VStack(spacing: 6) { ForEach(keys, id: \.self) { row(g, $0) } }
    }

    private func wheel(_ g: EffectInstance, _ title: String, _ p: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
                Spacer()
                let t = state.currentTime
                Circle().fill(Color(red: 0.5 + g.number(p + "R", t) / 200, green: 0.5 + g.number(p + "G", t) / 200, blue: 0.5 + g.number(p + "B", t) / 200))
                    .frame(width: 18, height: 18)
            }
            group(g, [p + "R", p + "G", p + "B"])
        }
        .padding(10).glass(radius: 12)
    }

    private func lutSection(_ g: EffectInstance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { importLUT = true } label: { Label("Import .cube LUT", systemImage: "square.and.arrow.down") }.buttonStyle(PrimaryButtonStyle())
            row(g, "lutStrength")
            let current = g.text?["lut"]
            if let current, !luts.contains(current) {
                // The grade names a LUT that isn't on this device (moved project / deleted file): it renders without it.
                Label("Missing LUT \"\((current as NSString).deletingPathExtension)\" — import it to restore the look.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(Theme.warning)
            }
            lutButton(g, nil, selected: current == nil)
            ForEach(luts, id: \.self) { name in lutButton(g, name, selected: current == name) }
            if luts.isEmpty { Text("LUTs you import stay here for every project.").font(.caption).foregroundStyle(Theme.textDim) }
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
            .padding(.vertical, 6)
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

    private var scopes: some View {
        Canvas { ctx, size in
            guard histogram.count == 3 else { return }
            let colors: [Color] = [.red, .green, .blue]
            for ch in 0..<3 {
                let h = histogram[ch]
                guard let mx = h.max(), mx > 0 else { continue }
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                for (i, v) in h.enumerated() {
                    path.addLine(to: CGPoint(x: CGFloat(i) / CGFloat(h.count - 1) * size.width, y: size.height - CGFloat(v / mx) * size.height))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                ctx.fill(path, with: .color(colors[ch].opacity(0.35)))
            }
        }
        .frame(height: 70)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
        .overlay(alignment: .topLeading) { Text("HISTOGRAM").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.6)).padding(5) }
    }

    /// Histogram of the frame at the playhead (rendered small, off the main thread). Follows scrubbing and edits;
    /// renders one at a time (latest request wins) and waits while a live gesture drives the preview.
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
            return ScopeRenderQueue.histogram(px.rgba)
        } apply: { h in histogram = h }
    }
}

/// Serial, coalescing scope renders: at most one in flight; while it runs only the newest request is kept, and a
/// result is applied only if it is still the newest (no stale histogram after scrubbing).
final class ScopeRenderQueue {
    private let queue = DispatchQueue(label: "awi.scopes", qos: .userInitiated)
    private let lock = NSLock()
    private var latest = ""
    private var running = false
    private var pending: (String, () -> [[Float]]?, ([[Float]]) -> Void)?

    func submit(token: String, work: @escaping () -> [[Float]]?, apply: @escaping ([[Float]]) -> Void) {
        lock.lock()
        latest = token
        if running { pending = (token, work, apply); lock.unlock(); return }
        running = true
        lock.unlock()
        run(token, work, apply)
    }

    var latestToken: String { lock.lock(); defer { lock.unlock() }; return latest }

    private func run(_ token: String, _ work: @escaping () -> [[Float]]?, _ apply: @escaping ([[Float]]) -> Void) {
        queue.async { [weak self] in
            let result = work()
            DispatchQueue.main.async {
                guard let self else { return }
                if let result, self.latestToken == token { apply(result) }
                self.lock.lock()
                let next = self.pending
                self.pending = nil
                self.running = next != nil
                self.lock.unlock()
                if let next { self.run(next.0, next.1, next.2) }
            }
        }
    }

    /// 64-bin RGB histogram of RGBA8 pixels.
    static func histogram(_ rgba: [UInt8]) -> [[Float]] {
        var h = Array(repeating: [Float](repeating: 0, count: 64), count: 3)
        var i = 0
        while i + 3 < rgba.count {
            for c in 0..<3 { h[c][Int(rgba[i + c]) >> 2] += 1 }
            i += 4
        }
        return h
    }
}

/// Draggable curve: the 25 / 50 / 75 % points of the chosen channel.
struct CurveGraph: View {
    @ObservedObject var state: EditorState
    let effect: EffectInstance
    let prefix: String
    @State private var dragging: String?

    /// The effect as it is right now (the live copy mid-drag), so points follow the finger.
    private func live(_ e: EffectInstance) -> EffectInstance {
        guard let id = state.selectedLayerID,
              let l = (state.live.project ?? state.project).layers.first(where: { $0.id == id }) else { return e }
        return l.effects.first { $0.id == e.id } ?? e
    }

    var body: some View {
        GeometryReader { geo in
            let t = state.currentTime
            let keys = [prefix + "25", prefix + "50", prefix + "75"]
            let cp = GradeCurves.points(live(effect), t, channel: prefix)
            let pts = cp.ys, xs = cp.xs
            let curve = GradeCurves.curve(xs: xs, ys: pts)
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45))
                Path { p in
                    for k in 1..<4 {
                        let x = geo.size.width * CGFloat(k) / 4
                        p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height))
                        let y = geo.size.height * CGFloat(k) / 4
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.1))
                Path { p in
                    for (i, v) in curve.enumerated() {
                        let pt = CGPoint(x: geo.size.width * CGFloat(i) / 255, y: geo.size.height * CGFloat(1 - v))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(["m": Color.white, "r": .red, "g": .green, "b": .blue][prefix] ?? .white, lineWidth: 2)
                ForEach(Array(keys.enumerated()), id: \.offset) { k, key in
                    Circle().fill(dragging == key ? Theme.accentGlow : .white).frame(width: 14, height: 14)
                        .position(x: geo.size.width * CGFloat(xs[k + 1]), y: geo.size.height * CGFloat(1 - pts[k + 1]))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if dragging == nil {
                        // Nearest point to the finger (points can sit anywhere along x now).
                        let fx = Double(v.startLocation.x / max(geo.size.width, 1)), fy = 1 - Double(v.startLocation.y / max(geo.size.height, 1))
                        let k = (0..<3).min { a, b in
                            hypot(xs[a + 1] - fx, pts[a + 1] - fy) < hypot(xs[b + 1] - fx, pts[b + 1] - fy)
                        } ?? 1
                        dragging = keys[k]
                        state.beginEdit("Curve")
                    }
                    guard let key = dragging, let k = keys.firstIndex(of: key) else { return }
                    let val = min(100, max(0, (1 - Double(v.location.y / max(geo.size.height, 1))) * 100))
                    // Sideways too, kept between its neighbours so the points never cross.
                    let now = GradeCurves.points(live(effect), state.currentTime, channel: prefix).xs
                    let x = min(now[k + 2] - 0.02, max(now[k] + 0.02, Double(v.location.x / max(geo.size.width, 1)))) * 100
                    state.setEffectParam(effect.id, key) { pv, time in if case .number(var a) = pv { a.set(val, at: time); pv = .number(a) } }
                    state.setEffectParam(effect.id, key + "x") { pv, time in if case .number(var a) = pv { a.set(x, at: time); pv = .number(a) } }
                }
                .onEnded { _ in dragging = nil; state.endEdit() })
        }
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
