import Foundation
import UIKit

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

        var cache: [UInt32: Project] = [:]
        project.layers = buildLayers(comp, footage: footage, comps: compByID, report: &report, cache: &cache, depth: 0)
        project.precomps = Array(cache.values)
        return AEPImportResult(project: project, report: report)
    }

    /// Imports a comp's layers (AE order = top to bottom, same as AWIeffect), importing nested comps into `cache`.
    private static func buildLayers(_ comp: Comp, footage: [UInt32: Footage], comps: [UInt32: Comp], report: inout ImportReport,
                                    cache: inout [UInt32: Project], depth: Int) -> [Layer] {
        var layers: [Layer] = []
        for lc in comp.chunk.children("Layr") {
            if let l = importLayer(lc, comp: comp, footage: footage, comps: comps, report: &report, cache: &cache, depth: depth) {
                layers.append(l)
            }
        }
        return layers
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
                    // "Soli" + 6 bytes, then float32 A, R, G, B (verified against AE sample solids).
                    let a = Double(opti.f32(10)), r = Double(opti.f32(14)), g = Double(opti.f32(18)), b = Double(opti.f32(22))
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
            // Masks put an `mkif` info chunk between the match name and the mask's property group: step over it.
            if c.id == "mkif" { continue }
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

    /// ldta stores AE's internal transfer-mode index (AE SDK PF_Xfer order: 2 = normal, 4 = add...).
    private static func blendMode(_ raw: UInt8) -> (BlendMode, Bool) {
        switch raw {
        case 0, 2: return (.normal, true)
        case 4: return (.add, true)
        case 5: return (.multiply, true)
        case 6: return (.screen, true)
        case 7: return (.overlay, true)
        case 8: return (.softLight, true)
        case 9: return (.hardLight, true)
        case 13: return (.hue, true)
        case 14: return (.saturation, true)
        case 15: return (.color, true)
        case 16: return (.luminosity, true)
        case 10: return (.darken, true)
        case 11: return (.lighten, true)
        case 12: return (.difference, true)
        default: return (.normal, false)
        }
    }

    private static func importLayer(_ lc: RIFXChunk, comp: Comp, footage: [UInt32: Footage], comps: [UInt32: Comp],
                                    report: inout ImportReport, cache: inout [UInt32: Project], depth: Int) -> Layer? {
        guard let ldta = lc.child("ldta") else { return nil }
        let rawName = lc.children.first { $0.id == "Utf8" }?.string ?? ""
        let sourceName = footage[ldta.u32(40)]?.name ?? comps[ldta.u32(40)]?.name ?? ""
        let name = !rawName.isEmpty ? rawName : (!sourceName.isEmpty ? sourceName : "Layer")
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
        var textFont: String?
        var importedPath: BezierPath?
        var importedStroke: (RGBA, Double)?
        var precompStart: Double?

        switch layerType {
        case 3:
            content = .text
            let extracted = extractText(tree)
            textString = extracted.text ?? name
            textFont = extracted.font
            report.add(name, "Text layer", .approximate, "Text, font size and fill imported; per-character styling and text animators are approximated.")
        case 4:
            if let shape = importShape(tree) {
                content = .shape(shape.kind)
                size = shape.size
                fill = shape.fill
                importedPath = shape.path.map { p in
                    // AE shape coordinates are relative to the layer origin; AWIeffect paths are relative to the layer center.
                    var q = p
                    for i in q.vertices.indices { q.vertices[i].point = q.vertices[i].point - Vec2(Double(comp.width) / 2, Double(comp.height) / 2) }
                    return q
                }
                importedStroke = shape.stroke
                if shape.path != nil { content = .shape(.path) }
                report.add(name, "Shape layer", shape.path != nil ? .native : .approximate,
                           shape.path != nil ? "Bezier path, fill and stroke imported." : "First \(shape.kind.title.lowercased()) with its fill imported.")
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
                if depth < 5 {
                    let nested: Project
                    if let cached = cache[sourceID] {
                        nested = cached
                    } else {
                        var np = Project.new(name: c.name, width: c.width, height: c.height, fps: c.fps,
                                             duration: max(c.duration, 1 / c.fps), background: RGBA(0, 0, 0, 0))
                        cache[sourceID] = np   // placeholder first, guards against cycles
                        np.layers = buildLayers(c, footage: footage, comps: comps, report: &report, cache: &cache, depth: depth + 1)
                        cache[sourceID] = np
                        nested = np
                    }
                    content = .precomp(id: nested.id)
                    precompStart = start
                    report.add(name, "Pre-comp “\(c.name)”", .native, "\(nested.layers.count) layers imported as a nested comp.")
                } else {
                    fill = RGBA(0.2, 0.15, 0.3)
                    report.add(name, "Pre-comp “\(c.name)”", .missing, "Nested too deep (more than 5 levels).")
                }
            }
        }

        var layer = Layer(name: name, content: content, outPoint: max(outPoint, inPoint + 1 / comp.fps),
                          transform: LayerTransform(position: Animated(Vec2(Double(comp.width) / 2, Double(comp.height) / 2))),
                          size: Animated(size))
        layer.inPoint = max(0, inPoint)
        if let ps = precompStart { layer.sourceStart = layer.inPoint - ps }   // nested time = comp time - layer start
        if let p = importedPath { layer.path = Animated(p) }
        if let st = importedStroke {
            layer.stroke.enabled = true
            layer.stroke.color = Animated(st.0)
            layer.stroke.width = Animated(st.1)
        }
        if importedPath != nil, importedStroke != nil, fill.a == 0 { layer.fill = Animated(RGBA(0, 0, 0, 0)) }
        layer.isVisible = visible && !isNull
        layer.fill = Animated(fill)
        let bm = blendMode(ldta.u8(99))
        layer.blendMode = bm.0
        if !bm.1 { report.add(name, "Blend mode", .approximate, "Blend mode #\(ldta.u8(99)) mapped to Normal.") }
        if content == .text {
            var t = TextData(string: textString ?? name, fontSize: 100)
            // Use the project's font when iOS has it (Arial, Helvetica, Futura...), else keep the default.
            if let f = textFont, UIFont(name: f, size: 12) != nil { t.fontName = f }
            t.fill = Animated(.white)
            t.animators = TextAnimatorImport.animators(in: tree, timebase: comp.timebase, layerStart: start)
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
            // Scale and opacity are stored as 0-1 fractions (py-aep `_PERCENT_MATCH_NAMES`).
            if let v = val("ADBE Scale") { layer.transform.scale = animated(v, fallback: Vec2(100, 100)) { $0.map { $0 * 100 } } }
            if let v = val("ADBE Rotate Z") { layer.transform.rotation = animated(v, fallback: 0) }
            if let v = val("ADBE Opacity") { layer.transform.opacity = animated(v, fallback: 100) { $0.map { $0 * 100 } } }
            for p in [layer.transform.position.expression, layer.transform.scale.expression, layer.transform.rotation.expression,
                      layer.transform.opacity.expression].compactMap({ $0 }) {
                report.add(name, "Expression", .native, String(p.prefix(60)))
            }
        }

        // Effects.
        if let parade = tree.first(where: { $0.matchName == "ADBE Effect Parade" }) {
            for e in parade.children {
                if let def = EffectRegistry.definition(aeMatchName: e.matchName) {
                    let inst = effectInstance(def, from: e, timebase: comp.timebase, layerStart: start)
                    layer.effects.append(inst)
                    let approx = def.id.hasPrefix("awi.") || e.matchName.hasPrefix("CC ")
                    report.add(name, def.name, approx ? .approximate : .native, e.matchName)
                } else if let sub = PluginSwap.lookup(e.matchName), let def = EffectRegistry.definition(sub.id) {
                    // Third-party plugin (Twitch, Optical Flares, Sapphire, BCC, Universe…) → this app's built-in version.
                    var inst = def.makeInstance()
                    for (k, v) in sub.params { inst.params[k] = v }
                    layer.effects.append(inst)
                    report.add(name, def.name, .approximate, "\(sub.plugin) replaced by the built-in \(def.name).")
                } else {
                    report.add(name, e.matchName, .missing, "No built-in equivalent yet.")
                }
            }
        }
        // Masks (AE "ADBE Mask Parade"): path, mode, inverted, feather, opacity, expansion.
        if let parade = tree.first(where: { $0.matchName == "ADBE Mask Parade" }) {
            let half = Vec2(size.x / 2, size.y / 2)
            let infos = lc.allMkif   // one per mask, in order
            for (mi, atom) in parade.children.filter({ $0.matchName == "ADBE Mask Atom" }).enumerated() {
                guard case .other(let shapeChunk)? = atom.find("ADBE Mask Shape")?.kind,
                      var path = parseShapePath(shapeChunk, scale: size) else { continue }
                for i in path.vertices.indices { path.vertices[i].point = path.vertices[i].point - half }
                path.closed = true
                var m = LayerMask(name: "Mask \(layer.masks.count + 1)", path: Animated(path))
                func num(_ mn: String) -> AEValue? {
                    if case .value(let c)? = atom.find(mn)?.kind { return readValue(c, timebase: comp.timebase, layerStart: start) }
                    return nil
                }
                if let f = num("ADBE Mask Feather") { m.feather = animated(f, fallback: 0) { [$0.first ?? 0] } }
                if let o = num("ADBE Mask Opacity") { m.opacity = animated(o, fallback: 100) { $0.map { $0 * 100 } } }
                if let e = num("ADBE Mask Offset") { m.expansion = animated(e, fallback: 0) }
                if mi < infos.count {
                    let info = infos[mi]
                    m.inverted = info.u8(0) != 0
                    let modes: [MaskMode] = [.none, .add, .subtract, .intersect, .lighten, .darken, .difference]
                    let raw = Int(info.u16(6))
                    if raw < modes.count { m.mode = modes[raw] }
                }
                layer.masks.append(m)
                report.add(name, m.name, .native, "\(path.vertices.count)-point mask, \(m.mode.title)")
            }
        }
        return layer
    }

    /// Builds an AWIeffect effect from an AE effect group, mapping params by their `-000N` index.
    static func effectInstance(_ def: EffectDefinition, from e: AEProp, timebase: Double, layerStart: Double) -> EffectInstance {
        var inst = def.makeInstance()
        for pd in def.params {
            guard let idx = pd.aeIndex else { continue }
            let pname = "\(e.matchName)-\(String(format: "%04d", idx))"
            guard case .value(let c)? = e.find(pname)?.kind else { continue }
            let v = readValue(c, timebase: timebase, layerStart: layerStart)
            switch pd.kind {
            case .number, .angle:
                inst.params[pd.id] = .number(animated(v, fallback: inst.number(pd.id, 0)))
            case .color:
                inst.params[pd.id] = .color(animated(v, fallback: .white))
            case .point:
                // Effect points are stored as 0-1 fractions of the layer, same as AWIeffect.
                inst.params[pd.id] = .point(animated(v, fallback: Vec2(0.5, 0.5)))
            case .toggle:
                inst.params[pd.id] = .toggle((v.staticValue.first ?? 0) != 0)
            case .choice(let opts):
                // AE popups are 1-based.
                let i = Int((v.staticValue.first ?? 1).rounded()) - 1
                inst.params[pd.id] = .choice(min(max(i, 0), opts.count - 1))
            }
        }
        return inst
    }

    // MARK: Text & shapes (best effort)

    /// Text + font from the text document (`btdk`, COS data). AE terminates the text itself with a CR,
    /// which tells it apart from font names stored in the same blob.
    private static func extractText(_ tree: [AEProp]) -> (text: String?, font: String?) {
        guard let textProps = tree.first(where: { $0.matchName == "ADBE Text Properties" }) else { return (nil, nil) }
        var blobs: [Data] = []
        func collect(_ props: [AEProp]) {
            for p in props {
                switch p.kind {
                case .other(let c):
                    if let b = c.child("btdk") { blobs.append(b.data) }
                    if c.key == "btdk" { blobs.append(c.data) }
                case .group(let kids): collect(kids)
                default: break
                }
            }
        }
        collect(textProps.children)
        var text: String?, font: String?
        for b in blobs {
            for raw in utf16Strings(b) {
                let cleaned = raw.replacingOccurrences(of: "\r", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if text == nil, raw.hasSuffix("\r") {
                    // Skip empty paragraph markers; the real text is non-empty.
                    if !cleaned.isEmpty { text = cleaned }
                } else if font == nil, !raw.contains(" "), !raw.contains("\r"), raw.count > 2 {
                    font = raw
                }
            }
        }
        return (text, font)
    }

    /// Every COS UTF-16BE string `(<FE FF> ...)` in a blob; a ')' that starts a UTF-16 unit closes it.
    static func utf16Strings(_ data: Data) -> [String] {
        let b = [UInt8](data)
        var out: [String] = []
        var i = 0
        while i + 3 < b.count {
            guard b[i] == 0x28, b[i + 1] == 0xFE, b[i + 2] == 0xFF else { i += 1; continue }
            var j = i + 3
            var units: [UInt16] = []
            while j + 1 < b.count {
                var hi = b[j]
                if hi == 0x29 { break }
                if hi == 0x5C, j + 1 < b.count { j += 1; hi = b[j] }
                guard j + 1 < b.count else { break }
                var lo = b[j + 1]
                if lo == 0x5C, j + 2 < b.count { j += 1; lo = b[j + 1] }
                units.append(UInt16(hi) << 8 | UInt16(lo))
                j += 2
            }
            let str = String(decoding: units, as: UTF16.self)
            if !str.isEmpty { out.append(str) }
            i = j + 1
        }
        return out
    }

    static func firstUTF16String(_ data: Data) -> String? { utf16Strings(data).first }

    private static func importShape(_ tree: [AEProp]) -> (kind: ShapeKind, size: Vec2, fill: RGBA, path: BezierPath?, stroke: (RGBA, Double)?)? {
        guard let root = tree.first(where: { $0.matchName == "ADBE Root Vectors Group" }) else { return nil }
        var kind: ShapeKind?
        var size = Vec2(200, 200)
        var fill = RGBA(0, 0, 0, 0)
        var hasFill = false
        var path: BezierPath?
        var stroke: (RGBA, Double)?
        func color(_ p: AEProp, _ m: String) -> RGBA? {
            if case .value(let c)? = p.find(m)?.kind {
                let v = readValue(c, timebase: 24576, layerStart: 0)
                if v.staticValue.count >= 3 { return RGBA(v.staticValue[0], v.staticValue[1], v.staticValue[2], 1) }
            }
            return nil
        }
        func visit(_ props: [AEProp]) {
            for p in props {
                switch p.matchName {
                case "ADBE Vector Shape - Rect": kind = kind ?? .rectangle; sizeFrom(p, "ADBE Vector Rect Size")
                case "ADBE Vector Shape - Ellipse": kind = kind ?? .ellipse; sizeFrom(p, "ADBE Vector Ellipse Size")
                case "ADBE Vector Shape - Star": kind = kind ?? .star
                case "ADBE Vector Shape - Group":
                    if path == nil, case .other(let c)? = p.find("ADBE Vector Shape")?.kind { path = parseShapePath(c) }
                case "ADBE Vector Graphic - Fill":
                    if let c = color(p, "ADBE Vector Fill Color") { fill = c; hasFill = true }
                case "ADBE Vector Graphic - Stroke":
                    if stroke == nil, let c = color(p, "ADBE Vector Stroke Color") {
                        var w = 4.0
                        if case .value(let ch)? = p.find("ADBE Vector Stroke Width")?.kind {
                            w = readValue(ch, timebase: 24576, layerStart: 0).staticValue.first ?? 4
                        }
                        stroke = (c, w)
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
        if !hasFill && path == nil { fill = RGBA(1, 1, 1) }
        guard kind != nil || path != nil else { return nil }
        return (kind ?? .path, size, fill, path, stroke)
    }

    /// Decodes a static AE bezier path (`om-s` > `omks` > `shap`): `shph` holds the closed flag and a float32 bounding box;
    /// the point list stores float32 (x, y) triplets of vertex, out-tangent, in-tangent, normalized to that box and absolute.
    /// `scale`: masks store their box normalized to the layer size, so pass the layer size for masks.
    static func parseShapePath(_ chunk: RIFXChunk, scale: Vec2? = nil) -> BezierPath? {
        func findShap(_ c: RIFXChunk) -> RIFXChunk? {
            if c.key == "shap" { return c }
            for k in c.children { if let f = findShap(k) { return f } }
            return nil
        }
        guard let shap = findShap(chunk), let shph = shap.child("shph"),
              let list = shap.child("list"), let ldat = list.child("ldat") else { return nil }
        let open = (shph.u8(3) & 0x08) != 0
        let x0 = Double(shph.f32(4)), y0 = Double(shph.f32(8)), x1 = Double(shph.f32(12)), y1 = Double(shph.f32(16))
        let w = x1 - x0, h = y1 - y0
        guard w.isFinite, h.isFinite else { return nil }
        let floats = ldat.data.count / 4
        let n = floats / 6
        guard n >= 2 else { return nil }
        let sx = scale?.x ?? 1, sy = scale?.y ?? 1
        func pt(_ i: Int) -> Vec2 {
            let j = (i + n * 3) % (n * 3)
            return Vec2((x0 + Double(ldat.f32(j * 8)) * w) * sx, (y0 + Double(ldat.f32(j * 8 + 4)) * h) * sy)
        }
        // Per vertex k: [3k] = vertex, [3k+1] = its out-handle, and its in-handle sits just before it at [3k-1]
        // (handles are absolute points; AWIeffect stores them relative to the vertex).
        var verts: [PathVertex] = []
        for k in 0..<n {
            let v = pt(k * 3), outT = pt(k * 3 + 1), inT = pt(k * 3 - 1)
            verts.append(PathVertex(point: v, inTangent: inT - v, outTangent: outT - v))
        }
        return BezierPath(vertices: verts, closed: !open)
    }
}
