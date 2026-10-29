import Foundation

// MARK: - Generic AE property tree

/// One node of an AE property tree (match name + payload).
struct AEProp {
    enum Kind {
        case group([AEProp])
        case value(RIFXChunk)       // LIST tdbs
        case effect(RIFXChunk)      // LIST sspc (effect instance)
        case other(RIFXChunk)
    }
    let matchName: String
    let kind: Kind

    var children: [AEProp] { if case .group(let c) = kind { return c }; return [] }
    func find(_ name: String) -> AEProp? { children.first { $0.matchName == name } }
}

/// A decoded animatable value: static components, keyframes (seconds), expression.
struct AEValue {
    struct Key {
        var time: Double
        var value: [Double]
        var interpolationOut: Int   // 1 linear, 2 bezier, 3 hold
        var inSpeed: Double, inInfluence: Double, outSpeed: Double, outInfluence: Double
    }
    var staticValue: [Double]
    var keys: [Key]
    var expression: String?
    var isColor: Bool
}

// MARK: - Import report

struct ImportReport {
    enum Status: String { case native = "Native", approximate = "Approximate", missing = "Missing" }
    struct Entry: Identifiable {
        let id = UUID()
        let layer: String
        let item: String
        let status: Status
        let detail: String
    }
    var compName = ""
    var entries: [Entry] = []
    /// Effect match name -> number of uses across the whole file (effect scanner).
    var effectUsage: [String: Int] = [:]
    var comps: [String] = []

    var nativeCount: Int { entries.filter { $0.status == .native }.count }
    var approximateCount: Int { entries.filter { $0.status == .approximate }.count }
    var missingCount: Int { entries.filter { $0.status == .missing }.count }

    mutating func add(_ layer: String, _ item: String, _ s: Status, _ d: String = "") {
        entries.append(Entry(layer: layer, item: item, status: s, detail: d))
    }
}

struct AEPImportResult {
    var project: Project
    var report: ImportReport
}

// MARK: - Importer

/// Imports After Effects projects (.aep) into AWIeffect projects.
enum AEPImporter {
    struct Comp {
        let id: UInt32
        let name: String
        let chunk: RIFXChunk
        var width: Int, height: Int, fps: Double, duration: Double, timebase: Double
        var background: RGBA
    }

    struct Footage {
        let id: UInt32
        let name: String
        var kind: String          // "Soli", "png!", "MOoV", ...
        var width: Int, height: Int
        var solidColor: RGBA?
    }

    static func load(url: URL, compName: String? = nil) throws -> AEPImportResult {
        try importData(try Data(contentsOf: url), compName: compName, projectName: url.deletingPathExtension().lastPathComponent)
    }

    static func importData(_ data: Data, compName: String? = nil, projectName: String = "Imported") throws -> AEPImportResult {
        let root = try RIFXParser.parse(data)
        var comps: [Comp] = []
        var footage: [UInt32: Footage] = [:]
        var compByID: [UInt32: Comp] = [:]
        collectItems(root, comps: &comps, footage: &footage)
        for c in comps { compByID[c.id] = c }
        var report = ImportReport()
        report.comps = comps.map(\.name)
        guard !comps.isEmpty else { throw RIFXError.notAEP }

        // Pick the requested comp, else the one with the most layers (usually the main edit).
        let comp = comps.first { $0.name == compName } ?? comps.max { $0.chunk.children("Layr").count < $1.chunk.children("Layr").count }!
        report.compName = comp.name

        var project = Project.new(name: comp.name.isEmpty ? projectName : comp.name, width: comp.width, height: comp.height,
                                  fps: comp.fps, duration: max(comp.duration, 1 / comp.fps), background: comp.background)
        // Effect scanner over every comp.
        for c in comps {
            for lc in c.chunk.children("Layr") {
                guard let tdgp = lc.child("tdgp") else { continue }
                let tree = walkGroup(tdgp)
                if let parade = tree.first(where: { $0.matchName == "ADBE Effect Parade" }) {
                    for e in parade.children { report.effectUsage[e.matchName, default: 0] += 1 }
                }
            }
        }

        var layers: [Layer] = []
        for lc in comp.chunk.children("Layr") {
            if let l = importLayer(lc, comp: comp, footage: footage, comps: compByID, report: &report) { layers.append(l) }
        }
        // AE stores layers top to bottom, same as AWIeffect.
        project.layers = layers
        return AEPImportResult(project: project, report: report)
    }

    // MARK: Items

    private static func collectItems(_ chunk: RIFXChunk, comps: inout [Comp], footage: inout [UInt32: Footage]) {
        for c in chunk.children {
            if c.key == "Item" {
                guard let idta = c.child("idta") else { continue }
                let type = idta.u16(0)
                let id = idta.u32(16)
                let name = c.child("Utf8")?.string ?? ""
                if type == 4, let cdta = c.child("cdta") {
                    comps.append(parseComp(id: id, name: name, chunk: c, cdta: cdta))
                } else if type == 7 {
                    footage[id] = parseFootage(id: id, name: name, item: c)
                }
            }
            if !c.children.isEmpty { collectItems(c, comps: &comps, footage: &footage) }
        }
    }

    private static func parseComp(id: UInt32, name: String, chunk: RIFXChunk, cdta: RIFXChunk) -> Comp {
        let timebase = Double(cdta.u32(8))
        let fpsRaw = Double(cdta.u16(156)) + Double(cdta.u16(158)) / 65536
        let fps = fpsRaw > 0 && fpsRaw < 1000 ? fpsRaw : 30
        let duration = cdta.ratio(44, signed: false)
        let w = Int(cdta.u16(140)), h = Int(cdta.u16(142))
        let bg = RGBA(Double(cdta.u8(52)) / 255, Double(cdta.u8(53)) / 255, Double(cdta.u8(54)) / 255)
        return Comp(id: id, name: name, chunk: chunk, width: max(16, w), height: max(16, h), fps: fps,
                    duration: duration.isFinite && duration > 0 ? duration : 10,
                    timebase: timebase > 0 ? timebase : fps * 1024, background: bg)
    }

    private static func parseFootage(id: UInt32, name: String, item: RIFXChunk) -> Footage {
        var f = Footage(id: id, name: name, kind: "", width: 0, height: 0, solidColor: nil)
        if let pin = item.child("Pin ") {
            if let sspc = pin.child("sspc") {
                f.kind = String(decoding: sspc.data.dropFirst(22).prefix(4), as: UTF8.self)
                f.width = Int(sspc.u16(32))
                f.height = Int(sspc.u16(36))
            }
            if let opti = pin.child("opti") {
                let t = String(decoding: opti.data.prefix(4), as: UTF8.self)
                if t == "Soli" {
                    f.kind = "Soli"
                    let a = Double(opti.f32(6)), r = Double(opti.f32(10)), g = Double(opti.f32(14)), b = Double(opti.f32(18))
                    if [a, r, g, b].allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1.0001 }) {
                        f.solidColor = RGBA(r, g, b, a)
                    }
                }
            }
        }
        return f
    }

    // MARK: Property tree

    static func walkGroup(_ tdgp: RIFXChunk) -> [AEProp] {
        var out: [AEProp] = []
        var pendingName: String?
        for c in tdgp.children {
            if c.id == "tdmn" {
                let n = c.string
                if n == "ADBE Group End" { break }
                pendingName = n
                continue
            }
            guard let name = pendingName else { continue }
            switch c.key {
            case "tdgp": out.append(AEProp(matchName: name, kind: .group(walkGroup(c))))
            case "tdbs": out.append(AEProp(matchName: name, kind: .value(c)))
            case "sspc":
                // Effect instance: params live in the nested tdgp.
                if let g = c.child("tdgp") {
                    out.append(AEProp(matchName: name, kind: .group(walkGroup(g))))
                } else {
                    out.append(AEProp(matchName: name, kind: .effect(c)))
                }
            default: out.append(AEProp(matchName: name, kind: .other(c)))
            }
            pendingName = nil
        }
        return out
    }

    /// Decodes a `tdbs` property: static value, keyframes and expression.
    static func readValue(_ tdbs: RIFXChunk, timebase: Double, layerStart: Double) -> AEValue {
        let tdb4 = tdbs.child("tdb4")
        let dims = max(1, Int(tdb4?.u16(2) ?? 1))
        let isColor = ((tdb4?.u8(0x3F) ?? 0) & 1) == 1
        var stat: [Double] = []
        if let cdat = tdbs.child("cdat") {
            let n = min(cdat.data.count / 8, isColor ? 4 : dims)
            stat = (0..<n).map { cdat.f64($0 * 8) }
        }
        let expr = tdbs.children.first { $0.id == "Utf8" }?.string
        var keys: [AEValue.Key] = []
        if let list = tdbs.child("list"), let lhd3 = list.child("lhd3"), let ldat = list.child("ldat") {
            let count = Int(lhd3.u32(8)), size = Int(lhd3.u32(16))
            if size > 8, count > 0, ldat.data.count >= count * size {
                for k in 0..<count {
                    let o = k * size
                    let units = Double(ldat.s32(o))
                    let interp = Int(ldat.u8(o + 5))
                    let p = o + 8
                    var value: [Double] = [], speeds = (0.0, 0.0, 0.0, 0.0)
                    switch size {
                    case 152: // color: ease block (after 16 bytes) + ARGB 0-255
                        speeds = (ldat.f64(p + 16), ldat.f64(p + 24), ldat.f64(p + 32), ldat.f64(p + 40))
                        let a = ldat.f64(p + 48), r = ldat.f64(p + 56), g = ldat.f64(p + 64), b = ldat.f64(p + 72)
                        value = [r / 255, g / 255, b / 255, a / 255]
                    case 104, 128 where size == 104 || isSpatial(tdb4):
                        let n = size == 104 ? 2 : 3
                        speeds = (ldat.f64(p + 16), ldat.f64(p + 24), ldat.f64(p + 32), ldat.f64(p + 40))
                        value = (0..<n).map { ldat.f64(p + 48 + $0 * 8) }
                    case 48, 88, 128:
                        let n = size == 48 ? 1 : (size == 88 ? 2 : 3)
                        value = (0..<n).map { ldat.f64(p + $0 * 8) }
                        // Temporal ease from the first dimension.
                        speeds = (ldat.f64(p + n * 8), ldat.f64(p + 2 * n * 8), ldat.f64(p + 3 * n * 8), ldat.f64(p + 4 * n * 8))
                    default:
                        continue
                    }
                    keys.append(AEValue.Key(time: units / timebase + layerStart, value: value, interpolationOut: interp,
                                            inSpeed: speeds.0, inInfluence: speeds.1, outSpeed: speeds.2, outInfluence: speeds.3))
                }
            }
        }
        if isColor, stat.count == 4 { stat = [stat[1] / 255, stat[2] / 255, stat[3] / 255, stat[0] / 255] }
        return AEValue(staticValue: stat, keys: keys, expression: expr, isColor: isColor)
    }

    private static func isSpatial(_ tdb4: RIFXChunk?) -> Bool { ((tdb4?.u8(5) ?? 0) >> 3) & 1 == 1 }

    /// Converts an AEValue to an AWIeffect Animated with AE speed/influence easing mapped to bezier handles.
    static func animated<V: ExpressionValue>(_ v: AEValue, fallback: V, map: ([Double]) -> [Double] = { $0 }) -> Animated<V> {
        var a = Animated(V(exprComponents: map(v.staticValue)) ?? fallback)
        for k in v.keys {
            guard let val = V(exprComponents: map(k.value)) else { continue }
            let interp: Interpolation = k.interpolationOut == 3 ? .hold : (k.interpolationOut == 2 ? .bezier : .linear)
            a.insertKeyframe(Keyframe(time: k.time, value: val, interpolation: interp))
        }
        // Speed/influence -> normalized handles, per segment.
        for i in 0..<max(0, a.keyframes.count - 1) where a.keyframes[i].interpolation == .bezier {
            guard i < v.keys.count - 1 else { break }
            let k0 = v.keys[i], k1 = v.keys[i + 1]
            let dt = max(1e-6, k1.time - k0.time)
            let dv0 = zip(map(k1.value), map(k0.value)).map { $0 - $1 }
            let dv = sqrt(dv0.reduce(0) { $0 + $1 * $1 })
            let outX = min(max(k0.outInfluence / 100, 0.01), 1)
            let inX = min(max(k1.inInfluence / 100, 0.01), 1)
            let outY = dv > 1e-9 ? k0.outSpeed * outX * dt / dv : 0
            let inY = dv > 1e-9 ? k1.inSpeed * inX * dt / dv : 0
            a.keyframes[i].easeOut = EaseHandle(x: outX, y: outY.isFinite ? outY : 0)
            a.keyframes[i + 1].easeIn = EaseHandle(x: 1 - inX, y: 1 - (inY.isFinite ? inY : 0))
        }
        if let e = v.expression, !e.isEmpty { a.expression = e }
        return a
    }

    // MARK: Layers

    private static func blendMode(_ raw: UInt8) -> (BlendMode, Bool) {
        switch Int(raw) + 5210 {
        case 5212: return (.normal, true)
        case 5220, 5223: return (.add, true)
        case 5222: return (.screen, true)
        case 5216: return (.multiply, true)
        case 5226: return (.overlay, true)
        case 5221: return (.lighten, true)
        case 5215: return (.darken, true)
        case 5233, 5234: return (.difference, true)
        default: return (.normal, false)
        }
    }

    private static func importLayer(_ lc: RIFXChunk, comp: Comp, footage: [UInt32: Footage], comps: [UInt32: Comp],
                                    report: inout ImportReport) -> Layer? {
        guard let ldta = lc.child("ldta") else { return nil }
        let name = lc.children.first { $0.id == "Utf8" }?.string ?? "Layer"
        let start = ldta.ratio(12)
        let inPoint = ldta.ratio(20) + start
        let outPoint = ldta.ratio(28) + start
        let flags1 = ldta.u8(38), flags2 = ldta.u8(39)
        let isAdjustment = (flags1 >> 1) & 1 == 1
        let isNull = (flags1 >> 7) & 1 == 1
        let visible = flags2 & 1 == 1
        let layerType = ldta.u8(131)
        let sourceID = ldta.u32(40)
        let tree = lc.child("tdgp").map(walkGroup) ?? []

        var size = Vec2(Double(comp.width), Double(comp.height))
        var content: LayerContent = .solid
        var fill = RGBA(0.5, 0.5, 0.5)
        var textString: String?

        switch layerType {
        case 3:
            content = .text
            textString = extractText(tree) ?? name
            report.add(name, "Text layer", .approximate, "Text, font size and fill imported; per-character styling and text animators are approximated.")
        case 4:
            if let shape = importShape(tree) {
                content = .shape(shape.kind)
                size = shape.size
                fill = shape.fill
                report.add(name, "Shape layer", .approximate, "First \(shape.kind.title.lowercased()) with its fill imported.")
            } else {
                content = .shape(.rectangle)
                report.add(name, "Shape layer", .missing, "Custom paths are not supported yet; placeholder shape created.")
            }
        case 1, 2:
            report.add(name, layerType == 2 ? "Camera" : "Light", .missing, "3D camera/lights arrive in stage 7.")
            return nil
        default:
            if isAdjustment {
                content = .adjustment
                report.add(name, "Adjustment layer", .native)
            } else if isNull {
                report.add(name, "Null", .approximate, "Imported as a hidden solid; parenting arrives later.")
                fill = RGBA(0, 0, 0, 0)
            } else if let f = footage[sourceID] {
                size = Vec2(Double(max(1, f.width)), Double(max(1, f.height)))
                if f.kind == "Soli" {
                    fill = f.solidColor ?? fill
                    report.add(name, "Solid", .native)
                } else {
                    fill = RGBA(0.25, 0.2, 0.35)
                    report.add(name, "Footage “\(f.name)”", .missing, "Media files aren't inside .aep files. Replace this placeholder with your clip.")
                }
            } else if let c = comps[sourceID] {
                size = Vec2(Double(c.width), Double(c.height))
                fill = RGBA(0.2, 0.15, 0.3)
                report.add(name, "Pre-comp “\(c.name)”", .missing, "Pre-comps are imported as placeholders until nested comps land.")
            }
        }

        var layer = Layer(name: name, content: content, outPoint: max(outPoint, inPoint + 1 / comp.fps),
                          transform: LayerTransform(position: Animated(Vec2(Double(comp.width) / 2, Double(comp.height) / 2))),
                          size: Animated(size))
        layer.inPoint = max(0, inPoint)
        layer.isVisible = visible && !isNull
        layer.fill = Animated(fill)
        let bm = blendMode(ldta.u8(99))
        layer.blendMode = bm.0
        if !bm.1 { report.add(name, "Blend mode", .approximate, "Blend mode #\(ldta.u8(99)) mapped to Normal.") }
        if content == .text {
            var t = TextData(string: textString ?? name, fontSize: 100)
            t.fill = Animated(.white)
            layer.text = t
        }

        // Transform.
        if let tr = tree.first(where: { $0.matchName == "ADBE Transform Group" }) {
            let tb = comp.timebase
            func val(_ m: String) -> AEValue? {
                if case .value(let c)? = tr.find(m)?.kind { return readValue(c, timebase: tb, layerStart: start) }
                return nil
            }
            let half = Vec2(size.x / 2, size.y / 2)
            if let v = val("ADBE Anchor Point") {
                layer.transform.anchor = animated(v, fallback: .zero) { c in [c[safe: 0].map { $0 - half.x } ?? 0, c[safe: 1].map { $0 - half.y } ?? 0] }
            }
            if let v = val("ADBE Position") {
                layer.transform.position = animated(v, fallback: Vec2(Double(comp.width) / 2, Double(comp.height) / 2))
            } else if let x = val("ADBE Position_0"), let y = val("ADBE Position_1") {
                // Separated dimensions: combine static values (keyframes from X/Y merged by time).
                var a = Animated(Vec2(x.staticValue.first ?? 0, y.staticValue.first ?? 0))
                let ax: Animated<Double> = animated(x, fallback: 0), ay: Animated<Double> = animated(y, fallback: 0)
                for t in Set(ax.keyframeTimes + ay.keyframeTimes).sorted() {
                    a.insertKeyframe(Keyframe(time: t, value: Vec2(ax.value(at: t), ay.value(at: t)), interpolation: .bezier))
                }
                layer.transform.position = a
            }
            if let v = val("ADBE Scale") { layer.transform.scale = animated(v, fallback: Vec2(100, 100)) }
            if let v = val("ADBE Rotate Z") { layer.transform.rotation = animated(v, fallback: 0) }
            if let v = val("ADBE Opacity") { layer.transform.opacity = animated(v, fallback: 100) }
            for p in [layer.transform.position.expression, layer.transform.scale.expression, layer.transform.rotation.expression,
                      layer.transform.opacity.expression].compactMap({ $0 }) {
                report.add(name, "Expression", .native, String(p.prefix(60)))
            }
        }

        // Effects.
        if let parade = tree.first(where: { $0.matchName == "ADBE Effect Parade" }) {
            for e in parade.children {
                if let def = EffectRegistry.definition(aeMatchName: e.matchName) {
                    var inst = def.makeInstance()
                    for pd in def.params {
                        guard let idx = pd.aeIndex else { continue }
                        let pname = "\(e.matchName)-\(String(format: "%04d", idx))"
                        guard case .value(let c)? = e.find(pname)?.kind else { continue }
                        let v = readValue(c, timebase: comp.timebase, layerStart: start)
                        switch pd.kind {
                        case .number, .angle:
                            inst.params[pd.id] = .number(animated(v, fallback: inst.number(pd.id, 0)))
                        case .color:
                            inst.params[pd.id] = .color(animated(v, fallback: .white))
                        case .point:
                            inst.params[pd.id] = .point(animated(v, fallback: Vec2(0.5, 0.5)) { c in
                                [(c[safe: 0] ?? 0) / max(1, size.x), (c[safe: 1] ?? 0) / max(1, size.y)]
                            })
                        case .toggle:
                            inst.params[pd.id] = .toggle((v.staticValue.first ?? 0) != 0)
                        case .choice(let opts):
                            // AE popups are 1-based.
                            let i = Int((v.staticValue.first ?? 1).rounded()) - 1
                            inst.params[pd.id] = .choice(min(max(i, 0), opts.count - 1))
                        }
                    }
                    layer.effects.append(inst)
                    let approx = def.id.hasPrefix("awi.") || e.matchName.hasPrefix("CC ")
                    report.add(name, def.name, approx ? .approximate : .native, e.matchName)
                } else {
                    report.add(name, e.matchName, .missing, "Not built yet; settings are kept and it will light up once added.")
                }
            }
        }
        return layer
    }

    // MARK: Text & shapes (best effort)

    /// Finds the text string inside the text document (`btdk` COS data): first UTF-16BE string with a BOM.
    private static func extractText(_ tree: [AEProp]) -> String? {
        guard let textProps = tree.first(where: { $0.matchName == "ADBE Text Properties" }) else { return nil }
        func search(_ props: [AEProp]) -> String? {
            for p in props {
                switch p.kind {
                case .other(let c):
                    if let btdk = c.child("btdk") ?? (c.key == "btdk" ? c : nil), let s = firstUTF16String(btdk.data) { return s }
                    if let s = firstUTF16String(c.data) { return s }
                case .group(let kids): if let s = search(kids) { return s }
                default: break
                }
            }
            return nil
        }
        return search(textProps.children)
    }

    /// COS strings look like `(<FE FF> utf16be... )`; a ')' that starts a UTF-16 unit closes the string.
    static func firstUTF16String(_ data: Data) -> String? {
        let b = [UInt8](data)
        guard b.count > 4 else { return nil }
        for i in 0..<(b.count - 3) where b[i] == 0x28 && b[i + 1] == 0xFE && b[i + 2] == 0xFF {
            var j = i + 3
            var units: [UInt16] = []
            while j + 1 < b.count {
                var hi = b[j]
                if hi == 0x29 { break }
                if hi == 0x5C, j + 1 < b.count { j += 1; hi = b[j] }   // backslash-escaped byte
                guard j + 1 < b.count else { break }
                var lo = b[j + 1]
                if lo == 0x5C, j + 2 < b.count { j += 1; lo = b[j + 1] }
                units.append(UInt16(hi) << 8 | UInt16(lo))
                j += 2
            }
            let s = String(decoding: units, as: UTF16.self).replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .controlCharacters)
            if !s.isEmpty { return s }
        }
        return nil
    }

    private static func importShape(_ tree: [AEProp]) -> (kind: ShapeKind, size: Vec2, fill: RGBA)? {
        guard let root = tree.first(where: { $0.matchName == "ADBE Root Vectors Group" }) else { return nil }
        var kind: ShapeKind?
        var size = Vec2(200, 200)
        var fill = RGBA(1, 1, 1)
        func visit(_ props: [AEProp]) {
            for p in props {
                switch p.matchName {
                case "ADBE Vector Shape - Rect": kind = kind ?? .rectangle; sizeFrom(p, "ADBE Vector Rect Size")
                case "ADBE Vector Shape - Ellipse": kind = kind ?? .ellipse; sizeFrom(p, "ADBE Vector Ellipse Size")
                case "ADBE Vector Shape - Star": kind = kind ?? .star
                case "ADBE Vector Graphic - Fill":
                    if case .value(let c)? = p.find("ADBE Vector Fill Color")?.kind {
                        let v = readValue(c, timebase: 24576, layerStart: 0)
                        if v.staticValue.count >= 3 { fill = RGBA(v.staticValue[0], v.staticValue[1], v.staticValue[2], 1) }
                    }
                default: break
                }
                visit(p.children)
            }
        }
        func sizeFrom(_ p: AEProp, _ m: String) {
            if case .value(let c)? = p.find(m)?.kind {
                let v = readValue(c, timebase: 24576, layerStart: 0)
                if v.staticValue.count >= 2 { size = Vec2(v.staticValue[0], v.staticValue[1]) }
            }
        }
        visit(root.children)
        return kind.map { ($0, size, fill) }
    }
}
