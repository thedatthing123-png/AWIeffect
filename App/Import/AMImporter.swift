import Foundation

/// Imports Alight Motion project exports (.xml): scene settings, layers with timing, transforms, keyframes with
/// AM bezier easing, and AM effects mapped onto this app's equivalents (shake, oscillate, swing, pulsate, spin,
/// jitter, tile, ripple, pinch/bulge, blurs, exposure, hue, motion blur…). AM-internal media isn't inside the XML,
/// so media layers come in as placeholders to relink with Replace Media.
enum AMImporter {
    // MARK: Tiny XML tree

    final class Node {
        let name: String
        let attrs: [String: String]
        var children: [Node] = []
        var text = ""
        init(_ name: String, _ attrs: [String: String]) { self.name = name; self.attrs = attrs }
        func child(_ n: String) -> Node? { children.first { $0.name == n } }
        func all(_ n: String) -> [Node] { children.filter { $0.name == n } }
        subscript(_ k: String) -> String? { attrs[k] }
    }

    private final class TreeBuilder: NSObject, XMLParserDelegate {
        var stack: [Node] = [Node("#root", [:])]
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            let n = Node(name, attributes)
            stack.last?.children.append(n)
            stack.append(n)
        }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { _ = stack.popLast() }
        func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text += string }
    }

    static func parse(_ data: Data) -> Node? {
        let p = XMLParser(data: data)
        let b = TreeBuilder()
        p.delegate = b
        guard p.parse() else { return nil }
        return b.stack.first?.children.first
    }

    static func isAMProject(_ data: Data) -> Bool {
        let head = String(decoding: data.prefix(600), as: UTF8.self)
        return head.contains("<scene") || head.contains("Alight Motion")
    }

    // MARK: Values

    static func nums(_ s: String?) -> [Double] { (s ?? "").split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } }
    static func color(_ s: String?) -> RGBA? {
        guard var h = s?.trimmingCharacters(in: .whitespaces), h.hasPrefix("#") else { return nil }
        h.removeFirst()
        guard let v = UInt64(h, radix: 16) else { return nil }
        if h.count == 8 {   // AM writes #AARRGGBB
            return RGBA(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255, Double((v >> 24) & 0xFF) / 255)
        }
        return RGBA(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    /// Keyframes / static value of an AM property node. AM key times are 0…1 across the layer's duration.
    static func animated<V: Interpolatable>(_ node: Node?, inPoint: Double, length: Double, _ convert: ([Double]) -> V?) -> Animated<V>? {
        guard let node else { return nil }
        let kfs = node.all("kf")
        if kfs.isEmpty {
            guard let v = convert(nums(node["value"])) else { return nil }
            return Animated(v)
        }
        let parsed: [(t: Double, v: V, e: String?)] = kfs.compactMap { k in
            guard let tt = Double(k["t"] ?? ""), let v = convert(nums(k["v"])) else { return nil }
            return (inPoint + tt * length, v, k["e"])
        }.sorted { $0.t < $1.t }
        guard let first = parsed.first else { return nil }
        var a = Animated(first.v)
        var keys: [Keyframe<V>] = parsed.map { Keyframe(time: $0.t, value: $0.v, interpolation: .linear) }
        // AM puts the easing of a segment on the key it arrives at: "cubicBezier x1 y1 x2 y2".
        for i in parsed.indices where i > 0 {
            guard let e = parsed[i].e else { continue }
            let parts = e.split(separator: " ").map(String.init)
            if parts.first == "cubicBezier", parts.count >= 5, let x1 = Double(parts[1]), let y1 = Double(parts[2]),
               let x2 = Double(parts[3]), let y2 = Double(parts[4]) {
                keys[i - 1].interpolation = .bezier
                keys[i - 1].easeOut = EaseHandle(x: x1, y: y1)
                keys[i].easeIn = EaseHandle(x: x2, y: y2)
            } else if parts.first == "hold" {
                keys[i - 1].interpolation = .hold
            } else if parts.count >= 6, parts[0] == "local", let x1 = Double(parts[2]), let y1 = Double(parts[3]),
                      let x2 = Double(parts[4]), let y2 = Double(parts[5]) {
                // AM "local elastic/cyclic a b c d": keep the curve's handles (springy overshoot is approximated).
                keys[i - 1].interpolation = .bezier
                keys[i - 1].easeOut = EaseHandle(x: min(max(x1, 0), 1), y: y1)
                keys[i].easeIn = EaseHandle(x: min(max(x2, 0), 1), y: y2)
            }
        }
        for k in keys { a.insertKeyframe(k) }
        return a
    }

    static func double(_ node: Node?, _ inPoint: Double, _ length: Double, scale: Double = 1, offset: Double = 0) -> Animated<Double>? {
        animated(node, inPoint: inPoint, length: length) { $0.first.map { $0 * scale + offset } }
    }

    // MARK: Effects

    /// Maps one AM effect onto this app's effect (or layer settings). Returns false when there's no equivalent.
    static func applyEffect(_ fx: Node, to layer: inout Layer, project: inout Project, inPoint: Double, length: Double,
                            report: inout ImportReport) {
        let full = fx["id"] ?? ""
        let id = full.replacingOccurrences(of: "com.alightcreative.effects.", with: "").replacingOccurrences(of: "com.alightcreative.internal.", with: "")
            .replacingOccurrences(of: "com.alightcreative.", with: "").replacingOccurrences(of: "com.customfx.effects.", with: "")
        let base = id.trimmingCharacters(in: CharacterSet.decimalDigits)
        var props: [String: Node] = [:]
        for p in fx.all("property") { if let n = p["name"] { props[n] = p } }
        func num(_ k: String, scale: Double = 1, offset: Double = 0) -> ParamValue? {
            double(props[k], inPoint, length, scale: scale, offset: offset).map { .number($0) }
        }
        func bool(_ k: String) -> Bool? { props[k]?["value"].map { $0 == "true" } }
        func make(_ def: EffectDefinition, _ params: [String: ParamValue?]) {
            var e = def.makeInstance()
            for (k, v) in params { if let v { e.params[k] = v } }
            layer.effects.append(e)
        }
        let name = layer.name
        switch base {
        case "shake":
            make(EffectRegistry.shake, ["amplitude": num("mag"), "frequency": num("freq"), "rotation": .number(Animated(0))])
            report.add(name, "Shake", .native)
        case "oscillate":
            make(EffectRegistry.oscillate, ["distance": num("mag"), "frequency": num("freq"), "direction": num("angle"), "phase": num("phase", scale: 360)])
            report.add(name, "Oscillate", .native)
        case "swing":
            let a1 = Double(props["a1"]?["value"] ?? "") ?? -30, a2 = Double(props["a2"]?["value"] ?? "") ?? 30
            make(EffectRegistry.swing, ["angle": .number(Animated(abs(a2 - a1) / 2)), "frequency": num("freq"), "phase": num("phase", scale: 180)])
            if abs(a1 + a2) > 0.01 { layer.transform.rotation = Animated(layer.transform.rotation.staticValue + (a1 + a2) / 2) }
            report.add(name, "Swing", .native)
        case "pulsate":
            let mx = Double(props["maxsize"]?["value"] ?? "") ?? 1.1
            make(EffectRegistry.pulse, ["amount": .number(Animated((mx - 1) * 100)), "bpm": num("freq", scale: 60)])
            report.add(name, "Pulsate", .approximate, "Mapped to Pulse (beat-shaped).")
        case "spin":
            make(EffectRegistry.spin, ["speed": num("rpm", scale: 6)])
            report.add(name, "Spin", .native)
        case "jitter", "randomdisplace":
            make(EffectRegistry.jitter, ["amount": num("mag"), "rate": num("freq")])
            report.add(name, base == "jitter" ? "Jitter" : "Random Displace", .approximate, "Mapped to Random Jitter.")
        case "tile":
            let s = Double(props["scale"]?["value"] ?? "") ?? 1
            make(EffectRegistry.motionTile, ["tileW": .number(Animated(100 / max(s, 0.01))), "tileH": .number(Animated(100 / max(s, 0.01))),
                                             "mirror": .toggle(bool("mirror") ?? false)])
            if let ang = props["angle"], let rot = double(ang, inPoint, length) {
                // AM rotates the tiled content inside the frame; the closest match is spinning the mirrored layer.
                make(EffectRegistry.spin, ["speed": .number(Animated(0)), "offset": .number(rot)])
            }
            report.add(name, "Tile", .approximate, "Mapped to Motion Tile (mirror edges); content rotation via Spin.")
        case "circularripple":
            make(EffectRegistry.ripple, ["height": num("strength", scale: 400), "width": num("frequency", scale: 2), "speed": num("phase", scale: 0.2)])
            report.add(name, "Circular Ripple", .approximate)
        case "pinchbulge":
            make(EffectRegistry.bulge, ["height": num("strength", scale: -2), "radius": num("radius", scale: Double(min(project.width, project.height)))])
            report.add(name, "Pinch/Bulge", .native)
        case "zoomblur":
            make(EffectRegistry.radialBlur, ["amount": num("strength", scale: 100), "type": .choice(1)])
            report.add(name, "Zoom Blur", .native)
        case "gaussianblur", "blur":
            make(EffectRegistry.gaussianBlur, ["blurriness": num("strength", scale: 100)])
            report.add(name, "Blur", .native)
        case "exposure":
            make(EffectRegistry.exposure, ["exposure": num("exposure", scale: 2), "gamma": num("gamma"), "offset": num("offset")])
            report.add(name, "Exposure", .native)
        case "hueshift":
            make(EffectRegistry.hueSaturation, ["hue": num("hue")])
            report.add(name, "Hue Shift", .native)
        case "motionblur":
            layer.motionBlur = true
            project.motionBlurEnabled = true
            if let t = Double(props["tune"]?["value"] ?? "") { project.shutterAngle = max(project.shutterAngle, 180 * max(t, 0.2)) }
            report.add(name, "Motion Blur", .native, "Layer + scene motion blur switched on.")
        case "softglow", "glow", "edgeglow":
            make(EffectRegistry.glow, ["intensity": num("strength", scale: 8), "radius": .number(Animated(30))])
            report.add(name, "Soft Glow", .approximate, "Mapped to Glow.")
        case "lift":
            make(EffectRegistry.exposure, ["offset": num("fill", scale: 0.5)])
            report.add(name, "Lift", .approximate, "Mapped to Exposure offset.")
        case "findedges":
            make(EffectRegistry.findEdges, ["invert": bool("invert").map { .toggle($0) }])
            report.add(name, "Find Edges", .native)
        case "invert":
            make(EffectRegistry.invert, [:]); report.add(name, "Invert", .native)
        case "blink":
            make(EffectRegistry.flicker, ["frequency": num("freq"), "amount": .number(Animated(1)), "smooth": .number(Animated(0))])
            report.add(name, "Blink", .approximate, "Mapped to Flicker.")
        case "innerblur":
            if let d = EffectRegistry.definition("awi15.innerBlur") { make(d, [:]) } else { make(EffectRegistry.gaussianBlur, ["blurriness": num("strength", scale: 60)]) }
            report.add(name, "Inner Blur", .approximate)
        case "chromakey":
            make(EffectRegistry.chromaKey, ["key": props["keyColor"]?["value"].flatMap(color).map { .color(Animated($0)) },
                                            "tolerance": num("threshold", scale: 100)])
            report.add(name, "Chroma Key", .native)
        case "dblur":
            make(EffectRegistry.directionalBlur, ["length": num("strength", scale: 120), "direction": num("angle")])
            report.add(name, "Directional Blur", .native)
        case "rgbsep":
            make(EffectRegistry.rgbSplit, ["amount": num("strength", scale: 20)]); report.add(name, "RGB Split", .native)
        case "vhs":
            make(EffectRegistry.vhs, [:]); report.add(name, "VHS", .approximate)
        case "threshold":
            make(EffectRegistry.threshold, [:]); report.add(name, "Threshold", .approximate)
        case "sharpen":
            make(EffectRegistry.sharpen, [:]); report.add(name, "Sharpen", .approximate)
        case "pixelate":
            make(EffectRegistry.mosaic, [:]); report.add(name, "Pixelate", .approximate)
        case "fractalwarp":
            make(EffectRegistry.turbulentDisplace, ["amount": num("mag", scale: 150)]); report.add(name, "Fractal Warp", .approximate)
        case "brightcont":
            make(EffectRegistry.brightnessContrast, ["brightness": num("brightness", scale: 100), "contrast": num("contrast", scale: 50)])
            report.add(name, "Brightness & Contrast", .native)
        case "colorize", "colorhot":
            make(EffectRegistry.tint, [:]); report.add(name, base, .approximate, "Mapped to Tint.")
        case "unmult":
            make(EffectRegistry.lumaKey, [:]); report.add(name, "Unmult", .approximate)
        case "fade":
            let fi = Double(props["inTime"]?["value"] ?? "") ?? 0.5, fo = Double(props["outTime"]?["value"] ?? "") ?? 0.5
            var o = layer.transform.opacity
            o.insertKeyframe(Keyframe(time: inPoint, value: 0, interpolation: .linear))
            o.insertKeyframe(Keyframe(time: inPoint + min(fi, length / 2), value: 100, interpolation: .linear))
            o.insertKeyframe(Keyframe(time: inPoint + length - min(fo, length / 2), value: 100, interpolation: .linear))
            o.insertKeyframe(Keyframe(time: inPoint + length, value: 0, interpolation: .linear))
            layer.transform.opacity = o
            report.add(name, "Fade In/Out", .native)
        case "textprogress":
            // Typewriter: reveal characters by the "end" amount.
            if layer.text != nil, let end = double(props["end"], inPoint, length, scale: 100) {
                var a = TextAnimator(name: "Typewriter")
                a.selector.start = end
                a.selector.end = Animated(100)
                a.properties.opacity = Animated(0)
                layer.text?.animators.append(a)
                report.add(name, "Text Progress", .native, "Became a typewriter animator.")
            }
        case "textspacing":
            if let ls = double(props["letterspacing"], inPoint, length, scale: 20) { layer.text?.tracking = ls }
            report.add(name, "Text Spacing", .native)
        case "solidcolor":
            make(EffectRegistry.fill, ["color": props["color"]?["value"].flatMap(color).map { .color(Animated($0)) },
                                       "opacity": num("alpha", scale: 100)])
            report.add(name, "Solid Color", .native)
        case "replacecolor":
            if let d = EffectRegistry.definition("ae.changeToColor") { make(d, [:]) }
            report.add(name, "Replace Color", .approximate)
        case "blackbars":
            make(EffectRegistry.cinematicBars, [:]); report.add(name, "Black Bars", .native)
        case "boxblur":
            make(EffectRegistry.gaussianBlur, ["blurriness": num("strength", scale: 60)]); report.add(name, "Box Blur", .native)
        case "stretch", "scaleassist":
            let s = Double(props["scale"]?["value"] ?? "") ?? 1
            let sc = layer.transform.scale.staticValue
            layer.transform.scale = Animated(Vec2(sc.x * s, sc.y))
            report.add(name, base == "stretch" ? "Stretch" : "Scale Assist", .approximate, "Applied as a static scale.")
        default:
            // Name match against this app's library (e.g. vhs, glitch, chromatic, glow, mirror, kaleidoscope…).
            if let def = fuzzy(base) {
                make(def, [:])
                report.add(name, id, .approximate, "Matched to “\(def.name)” with default settings.")
            } else {
                report.add(name, id, .missing, "No equivalent effect yet.")
            }
        }
    }

    static func fuzzy(_ amID: String) -> EffectDefinition? {
        func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter } }
        let k = norm(amID)
        guard k.count >= 3 else { return nil }
        return EffectRegistry.all.first { norm($0.name) == k }
            ?? EffectRegistry.all.first { norm($0.name).contains(k) || (k.count >= 5 && k.contains(norm($0.name)) && norm($0.name).count >= 4) }
    }

    // MARK: Scene

    static func blend(_ s: String?) -> BlendMode {
        switch s ?? "" {
        case "screen", "lighten-add": return .screen
        case "add", "linear-dodge": return .add
        case "multiply": return .multiply
        case "overlay", "soft-overlay": return .overlay
        case "soft-light": return .softLight
        case "hard-light": return .hardLight
        case "color-dodge": return .colorDodge
        case "color-burn": return .colorBurn
        case "linear-burn": return .linearBurn
        case "hue": return .hue
        case "saturation": return .saturation
        case "color": return .color
        case "luminosity": return .luminosity
        case "subtract": return .subtract
        case "divide": return .divide
        case "lighten": return .lighten
        case "darken": return .darken
        case "difference": return .difference
        case "exclude", "exclusion": return .exclusion
        default: return .normal
        }
    }

    /// Builds this app's layers from one AM scene element (recursing into groups as pre-comps).
    static func layers(of scene: Node, project: inout Project, media: [String: Node], report: inout ImportReport,
                       depth: Int = 0) -> [Layer] {
        let w = Double(project.width), h = Double(project.height), fps = project.fps
        var out: [Layer] = []
        var idMap: [String: UUID] = [:]
        var parentOf: [UUID: String] = [:]
        var n = 0
        for node in scene.children where ["shape", "text", "image", "video", "embedScene", "audio", "nullobj", "drawing", "camera"].contains(node.name) {
            n += 1
            if node["hidden"] == "true" { continue }
            let start = (Double(node["startTime"] ?? "") ?? 0) / 1000
            let end = (Double(node["endTime"] ?? "") ?? project.duration * 1000) / 1000
            let length = max(end - start, 1 / fps)
            let tr = node.child("transform")
            let label = node["label"] ?? "\(node.name.capitalized) \(n)"
            var l = project.makeLayer(name: label, content: .solid, size: Vec2(w, h))
            l.inPoint = start; l.outPoint = end
            if let loc = animated(tr?.child("location"), inPoint: start, length: length, { v in v.count >= 2 ? Vec2(v[0], v[1]) : nil }) { l.transform.position = loc }
            if let z = animated(tr?.child("location"), inPoint: start, length: length, { v in v.count >= 3 ? v[2] : nil }), (z.isAnimated || z.staticValue != 0) {
                l.transform.positionZ = z; l.is3D = true
            }
            if let sc = animated(tr?.child("scale"), inPoint: start, length: length, { v -> Vec2? in
                v.count >= 2 ? Vec2(v[0] * 100, v[1] * 100) : (v.first.map { Vec2($0 * 100, $0 * 100) })
            }) { l.transform.scale = sc }
            if let r = double(tr?.child("rotation"), start, length) { l.transform.rotation = r }
            if let o = double(tr?.child("opacity"), start, length, scale: 100) { l.transform.opacity = o }
            if let pv = animated(tr?.child("pivot"), inPoint: start, length: length, { v in v.count >= 2 ? Vec2(v[0], v[1]) : nil }) { l.transform.anchor = pv }
            if let fc = node.child("fillColor") {
                if let c = color(fc["value"]) { l.fill = Animated(c) }
                else if !fc.all("kf").isEmpty {
                    // Animated color: keys carry hex values.
                    var a = Animated(color(fc.all("kf").first?["v"]) ?? .white)
                    for k in fc.all("kf") { if let tt = Double(k["t"] ?? ""), let c = color(k["v"]) {
                        a.insertKeyframe(Keyframe(time: start + tt * length, value: c, interpolation: .linear)) } }
                    l.fill = a
                }
            }
            l.blendMode = blend(node["blending"])
            if let size = animated(node.all("property").first { $0["name"] == "size" }, inPoint: start, length: length, { v in
                v.count >= 2 ? Vec2(v[0] * 2, v[1] * 2) : nil }) { l.size = size }

            switch node.name {
            case "camera":
                l.content = .camera
                let fov = Double(node.child("fov")?["value"] ?? "") ?? 60
                let zoom = Double(project.height) / 2 / tan(fov / 2 * .pi / 180)
                l.camera = CameraOptions(zoom: Animated(zoom), focusDistance: Animated(zoom))
                report.add(label, "Camera", .native)
            case "nullobj":
                l.isNull = true
                l.size = Animated(Vec2(100, 100))
                l.fill = Animated(RGBA(1, 1, 1, 0))
                report.add(label, "Null", .native)
            case "text":
                l.content = .text
                let str = node.child("content")?.text.trimmingCharacters(in: .whitespacesAndNewlines)
                var t = TextData(string: (str?.isEmpty == false ? str : nil) ?? label)
                // AM text "size" is in points before the layer's scale; ×10 matches its on-screen size.
                t.fontSize = (Double(node["size"] ?? "") ?? 12) * 10
                t.fill = l.fill
                t.alignment = node["align"] == "left" ? .left : (node["align"] == "right" ? .right : .center)
                l.text = t
                if node.child("shadow") != nil { l.effects.append(EffectRegistry.dropShadow.makeInstance()) }
                report.add(label, "Text", .approximate, "Font “\(node["font"]?.replacingOccurrences(of: "imported?name=", with: "") ?? "default")” → this app's default; pick a font in Text Studio.")
            case "drawing":
                // Each pen stroke becomes an open path with a stroke.
                var strokes: [Layer] = []
                for (si, st) in node.all("stroke").enumerated() {
                    let pts = (st["points"] ?? "").split(separator: ";").compactMap { tri -> Vec2? in
                        let v = tri.split(separator: ",").compactMap { Double($0) }
                        return v.count >= 2 ? Vec2(v[0], v[1]) : nil
                    }
                    guard pts.count >= 2 else { continue }
                    var sl = l
                    sl.id = UUID()
                    sl.name = "\(label) stroke \(si + 1)"
                    sl.content = .shape(.path)
                    sl.path = Animated(BezierPath.smoothed(pts, closed: false))
                    sl.fill = Animated(RGBA(0, 0, 0, 0))
                    sl.stroke.enabled = true
                    sl.stroke.color = Animated(color(st["color"]) ?? .white)
                    sl.stroke.width = Animated(Double(st["width"] ?? "") ?? 8)
                    strokes.append(sl)
                }
                for fx in node.all("effect") {
                    if fx["id"]?.hasSuffix("drawing.progress") == true {
                        for i in strokes.indices {
                            var pr: [String: Node] = [:]; for p in fx.all("property") { if let k = p["name"] { pr[k] = p } }
                            if let e = double(pr["end"], start, length) { strokes[i].stroke.trimEnd = e }
                            if let b = double(pr["start"], start, length) { strokes[i].stroke.trimStart = b }
                        }
                        report.add(label, "Drawing Progress", .native, "Became Trim Paths.")
                    }
                }
                report.add(label, "Drawing (\(strokes.count) strokes)", .native)
                if let pid = node["parent"] { for s in strokes { parentOf[s.id] = pid } }
                if let first = strokes.first, let nid = node["id"] { idMap[nid] = first.id }
                out += strokes
                continue
            case "embedScene":
                if let inner = node.child("scene"), depth < 6 {
                    let iw = Int(inner["width"] ?? "") ?? project.width, ih = Int(inner["height"] ?? "") ?? project.height
                    var comp = Project.new(name: label, width: iw, height: ih, fps: fps,
                                           duration: max(length, (Double(inner["totalTime"] ?? "") ?? length * 1000) / 1000),
                                           background: RGBA(0, 0, 0, 0))
                    comp.layers = layers(of: inner, project: &comp, media: media, report: &report, depth: depth + 1)
                    var all = project.precomps; all.append(comp); all += comp.precomps; project.precomps = all
                    comp.precompList = nil
                    l.content = .precomp(id: comp.id)
                    l.size = Animated(Vec2(Double(iw), Double(ih)))
                    report.add(label, "Group", .native, "Became a pre-comp.")
                }
            case "audio":
                report.add(label, "Audio", .missing, "Re-add your music (AM media isn't inside the XML).")
                continue
            default:
                let sk = node["s"] ?? ""
                if node["fillType"] == "media", let uri = node["fillVideo"] ?? node["fillImage"] {
                    let m = media[uri]
                    let mw = Double(m?["width"] ?? "") ?? w, mh = Double(m?["height"] ?? "") ?? h
                    l.name = "\(label) · Replace Media"
                    l.fill = Animated(RGBA(0.25, 0.2, 0.35))
                    l.sourceStart = (Double(node["inTime"] ?? "") ?? 0) / 1000
                    if let sp = Double(node["speed"] ?? "") { l.speed = sp }
                    if node.all("property").first(where: { $0["name"] == "size" }) == nil { l.size = Animated(Vec2(mw, mh)) }
                    report.add(label, "Media", .missing, "Media isn't inside AM exports — Replace Media on this layer relinks your clip (timing kept).")
                } else if sk.contains("ellipse") || sk.contains("circle") { l.content = .shape(.ellipse); report.add(label, "Ellipse", .native) }
                else if sk.contains("star") || sk.contains("foil") { l.content = .shape(.star); report.add(label, "Star", .native) }
                else if sk.contains("poly") || sk.contains("triangle") || sk.contains("hex") { l.content = .shape(.polygon); report.add(label, "Polygon", .native) }
                else if sk.contains("rect") || sk.contains("square") { l.content = .shape(.rectangle); report.add(label, "Rectangle", .native) }
                else { report.add(label, node.name, .approximate, "Imported as a solid.") }
            }
            if let g = node.child("gain"), let v = Double(g["value"] ?? "") { l.volume = Animated(v * 100) }
            for fx in node.all("effect") where fx["id"]?.hasSuffix("drawing.progress") != true {
                applyEffect(fx, to: &l, project: &project, inPoint: start, length: length, report: &report)
            }
            if let nid = node["id"] { idMap[nid] = l.id }
            if let pid = node["parent"] { parentOf[l.id] = pid }
            out.append(l)
        }
        // Parenting (AM "parent" attribute → this app's parent links; positions are already parent-relative).
        for i in out.indices { if let pid = parentOf[out[i].id], let p = idMap[pid] { out[i].parentID = p } }
        // AM lists bottom layer first; this app lists top first.
        return out.reversed()
    }

    static func load(data: Data, fallbackName: String) throws -> AEPImportResult {
        guard let scene = parse(data), scene.name == "scene" else {
            throw NSError(domain: "AM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not an Alight Motion project export."])
        }
        let w = Int(scene["width"] ?? "") ?? 1080, h = Int(scene["height"] ?? "") ?? 1920
        let fps = Double(scene["fps"] ?? "") ?? 30
        let duration = max(0.1, (Double(scene["totalTime"] ?? "") ?? 10_000) / 1000)
        var project = Project.new(name: scene["title"] ?? fallbackName, width: w, height: h, fps: fps, duration: duration,
                                  background: color(scene["bgcolor"]) ?? .black)
        var report = ImportReport()
        report.compName = project.name
        var media: [String: Node] = [:]
        for m in scene.all("media") { if let u = m["uri"] { media[u] = m } }
        project.layers = layers(of: scene, project: &project, media: media, report: &report)
        project.markers = scene.all("bookmark").compactMap { Double($0["t"] ?? "").map { $0 / 1000 } }
        return AEPImportResult(project: project, report: report)
    }
}
