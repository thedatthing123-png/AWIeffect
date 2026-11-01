import Foundation
import UIKit

/// The rest of the editor over AI Link: projects, layers, properties + keyframes, effects, presets, easing and
/// contact sheets — everything you can do in the editor except Settings (key / connection) and deleting projects.
/// Every change is one undo step in the app.
extension AILink {
    /// Set by the root view: opens a project in the editor.
    static var openProject: ((Project) -> Void)?

    func handleEditor(_ r: HTTPRequest) -> HTTPResponse? {
        let a = ((try? JSONSerialization.jsonObject(with: r.body)) as? [String: Any]) ?? [:]
        switch (r.method, r.path) {
        case ("GET", "/projects"):
            let list = ProjectStore.shared.list().map { ["id": $0.id.uuidString, "name": $0.name, "width": $0.width, "height": $0.height,
                                                         "fps": $0.fps, "duration": $0.duration, "open": $0.id == editor?.project.id] as [String: Any] }
            return .json(["projects": list])
        case ("POST", "/projects/create"):
            let w = (a["width"] as? Int) ?? 1080, h = (a["height"] as? Int) ?? 1920
            var p = Project.new(name: (a["name"] as? String) ?? "AI Project", width: min(8192, max(16, w / 2 * 2)), height: min(8192, max(16, h / 2 * 2)),
                                fps: (a["fps"] as? Double) ?? 30, duration: 5, background: Self.color(a["background"]) ?? .black)
            p.autoLength = true
            try? ProjectStore.shared.save(p)
            Self.openProject?(p)
            return .json(["ok": true, "id": p.id.uuidString, "note": "opened in the editor"])
        case ("POST", "/projects/open"):
            guard let id = Self.uuid(a["id"]), let p = try? ProjectStore.shared.load(id) else { return .json(["error": "project not found"], status: 404) }
            editor?.saveNow()
            Self.openProject?(p)
            return .json(["ok": true])
        case ("POST", "/projects/duplicate"):
            guard let id = Self.uuid(a["id"]), let p = try? ProjectStore.shared.duplicate(id) else { return .json(["error": "project not found"], status: 404) }
            return .json(["ok": true, "id": p.id.uuidString])
        case ("POST", "/projects/rename"):
            guard let e = editor, let name = a["name"] as? String else { return .noProject }
            e.mutate("Rename") { $0.name = name }
            return .json(["ok": true])
        default: break
        }
        guard let e = editor else { return r.path.hasPrefix("/layers") || r.path.hasPrefix("/effects") || r.path.hasPrefix("/presets") || r.path.hasPrefix("/ease") || r.path == "/render/sheet" ? .noProject : nil }
        switch (r.method, r.path) {
        case ("POST", "/layers/add"): return addLayer(a, e)
        case ("POST", "/layers/edit"): return editLayer(a, e)
        case ("POST", "/layers/delete"):
            guard let id = Self.uuid(a["id"]) else { return Self.need("id") }
            e.select(id); e.deleteSelected(); return .json(["ok": true])
        case ("POST", "/layers/duplicate"):
            guard let id = Self.uuid(a["id"]) else { return Self.need("id") }
            e.select(id); e.duplicateSelected(); return .json(["ok": true, "id": e.selectedLayerID?.uuidString ?? ""])
        case ("POST", "/layers/reorder"):
            guard let id = Self.uuid(a["id"]), let from = e.project.layers.firstIndex(where: { $0.id == id }), let to = a["index"] as? Int else { return Self.need("id, index") }
            e.reorderLayer(from: from, to: max(0, min(e.project.layers.count - 1, to))); return .json(["ok": true])
        case ("POST", "/layers/split"):
            guard let id = Self.uuid(a["id"]) else { return Self.need("id") }
            e.select(id); e.seek((a["time"] as? Double) ?? e.currentTime); e.splitSelected(); return .json(["ok": true])
        case ("POST", "/effects/add"):
            guard let id = Self.uuid(a["layer"]), let type = a["type"] as? String, let d = EffectRegistry.definition(type) else { return Self.need("layer, type (effect id from get_catalog)") }
            e.select(id); e.addEffect(d)
            guard let eid = e.selectedLayer?.effects.last?.id else { return .json(["error": "couldn't add"], status: 500) }
            if let params = a["params"] as? [String: Any] { setParams(e, layer: id, effect: eid, params, at: a["time"] as? Double, key: a["keyframe"] as? Bool ?? false) }
            return .json(["ok": true, "effect": eid.uuidString])
        case ("POST", "/effects/set"):
            guard let id = Self.uuid(a["layer"]), let eid = Self.uuid(a["effect"]), let params = a["params"] as? [String: Any] else { return Self.need("layer, effect, params") }
            setParams(e, layer: id, effect: eid, params, at: a["time"] as? Double, key: a["keyframe"] as? Bool ?? false)
            return .json(["ok": true])
        case ("POST", "/effects/remove"):
            guard let id = Self.uuid(a["layer"]), let eid = Self.uuid(a["effect"]) else { return Self.need("layer, effect") }
            e.mutate("AI Remove Effect") { p in if let i = p.layers.firstIndex(where: { $0.id == id }) { p.layers[i].effects.removeAll { $0.id == eid } } }
            return .json(["ok": true])
        case ("POST", "/presets/apply"):
            guard let id = Self.uuid(a["layer"]), let kind = a["kind"] as? String, let pid = a["id"] as? String else { return Self.need("layer, kind (text|title|layer), id") }
            e.select(id)
            if let t = a["time"] as? Double { e.seek(t) }
            switch kind {
            case "text": guard let p = TextPreset.library.first(where: { $0.id == pid }) else { return .json(["error": "unknown text animation"], status: 404) }; e.applyTextPreset(p)
            case "title": guard let s = TitleStyles.all.first(where: { $0.id == pid }) else { return .json(["error": "unknown title style"], status: 404) }; e.applyTitleStyle(s)
            default: guard let p = PresetLibrary.all.first(where: { $0.id == pid }) else { return .json(["error": "unknown layer preset"], status: 404) }; e.applyPreset(p)
            }
            return .json(["ok": true])
        case ("POST", "/ease"):
            // {layer, property (position/scale/rotation/opacity/anchor/positionZ/rotationX/rotationY), curve: EaseCurve kind or "easy"/"linear"/"hold", segment?}
            guard let id = Self.uuid(a["layer"]), let prop = (a["property"] as? String).flatMap(PropertyKey.init(rawValue:)), let c = a["curve"] as? String else {
                return Self.need("layer, property, curve")
            }
            e.select(id)
            let seg = a["segment"] as? Int
            if let kind = EaseCurve.Kind(rawValue: c) {
                e.setEase(prop, segment: seg, interpolation: .bezier, out: .easyOut, into: .easyIn, curve: EaseCurve(kind))
            } else if let p = EasePreset.all.first(where: { $0.id == c || $0.name.lowercased() == c.lowercased() }) {
                e.setEase(prop, segment: seg, interpolation: p.interpolation, out: p.out, into: p.into, curve: nil)
            } else { return .json(["error": "unknown curve", "curves": EaseCurve.Kind.allCases.map(\.rawValue) + EasePreset.all.map(\.id)], status: 404) }
            return .json(["ok": true])
        case ("POST", "/render/sheet") where UIApplication.shared.applicationState == .background:
            return .json(["error": "AWIeffect is in the background: come back to the app to preview frames (edits still work)."], status: 409)
        case ("POST", "/render/sheet"):
            return contactSheet(e, count: max(2, min(16, Int(r.query["count"] ?? "") ?? 6)), size: Double(r.query["size"] ?? "") ?? 360)
        default:
            return nil
        }
    }

    // MARK: Layers

    private func addLayer(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        let type = (a["type"] as? String) ?? "shape"
        switch type {
        case "text":
            e.addText(); e.endTyping()
            if let s = a["text"] as? String { e.editText("AI Text") { $0.string = s } }
        case "shape": e.addShape(ShapeKind(rawValue: (a["shape"] as? String) ?? "rectangle") ?? .rectangle)
        case "solid": e.addSolid()
        case "adjustment": e.addAdjustmentLayer()
        case "null": e.addNull()
        case "camera": e.addCamera()
        case "light": e.addLight(LightType(rawValue: (a["light"] as? String) ?? "spot") ?? .spot)
        case "particles": e.addParticleLayer()
        case "image":
            guard let f = a["file"] as? String, let data = try? Data(contentsOf: e.mediaURL(f)) else { return Self.need("file (from upload_media)") }
            e.addImage(data: data, ext: (f as NSString).pathExtension)
        case "video":
            guard let f = a["file"] as? String else { return Self.need("file (from upload_media)") }
            e.addVideo(from: e.mediaURL(f))
        default:
            return .json(["error": "unknown type", "types": ["text", "shape", "solid", "adjustment", "null", "camera", "light", "particles", "image", "video"]], status: 400)
        }
        guard let id = e.selectedLayerID else { return .json(["error": "couldn't add"], status: 500) }
        if a.count > 1 { var b = a; b["id"] = id.uuidString; _ = editLayer(b, e) }
        return .json(["ok": true, "id": id.uuidString])
    }

    /// {id, time?, keyframe?: true, set: {position:[x,y], scale:[x,y], rotation, opacity, anchor:[x,y], positionZ, rotationX, rotationY,
    ///  fill:[r,g,b,a], name, inPoint, outPoint, speed, blend, is3D, parent (id or null), text, font, fontSize, tracking, visible, motionBlur}}
    private func editLayer(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let id = Self.uuid(a["id"]) else { return Self.need("id") }
        let set = (a["set"] as? [String: Any]) ?? a
        let t = (a["time"] as? Double) ?? e.currentTime
        let key = (a["keyframe"] as? Bool) ?? false
        var unknown: [String] = []
        if let p = set["parent"] { e.select(id); e.setParent(Self.uuid(p)) }
        e.mutate("AI Edit Layer") { proj in
            guard let i = proj.layers.firstIndex(where: { $0.id == id }) else { return }
            var l = proj.layers[i]
            func put<V: Interpolatable>(_ anim: inout Animated<V>, _ v: V) {
                if key { anim.insertKeyframe(Keyframe(time: t, value: v, interpolation: .bezier)) } else { anim.set(v, at: t) }
            }
            for (k, v) in set {
                switch k {
                case "position": if let p = Self.vec(v) { put(&l.transform.position, p) }
                case "scale": if let p = Self.vec(v) { put(&l.transform.scale, p) } else if let d = v as? Double { put(&l.transform.scale, Vec2(d, d)) }
                case "anchor": if let p = Self.vec(v) { put(&l.transform.anchor, p) }
                case "rotation": if let d = v as? Double { put(&l.transform.rotation, d) }
                case "opacity": if let d = v as? Double { put(&l.transform.opacity, d) }
                case "positionZ": if let d = v as? Double { put(&l.transform.positionZ, d) }
                case "rotationX": if let d = v as? Double { put(&l.transform.rotationX, d) }
                case "rotationY": if let d = v as? Double { put(&l.transform.rotationY, d) }
                case "fill": if let c = Self.color(v) { if l.text != nil { put(&l.text!.fill, c) } else { put(&l.fill, c) } }
                case "size": if let p = Self.vec(v) { put(&l.size, p) }
                case "name": if let s = v as? String { l.name = s }
                case "inPoint": if let d = v as? Double { l.inPoint = max(0, d) }
                case "outPoint": if let d = v as? Double { l.outPoint = max(l.inPoint + 0.01, d) }
                case "speed": if let d = v as? Double { l.speed = max(0.05, d) }
                case "blend": if let s = v as? String, let b = BlendMode(rawValue: s) { l.blendMode = b }
                case "is3D": if let b = v as? Bool { l.is3D = b }
                case "visible": if let b = v as? Bool { l.isVisible = b }
                case "motionBlur": if let b = v as? Bool { l.motionBlur = b }
                case "text": if let s = v as? String { l.text?.string = s }
                case "font": if let s = v as? String { l.text?.fontName = s }
                case "fontSize": if let d = v as? Double { l.text?.fontSize = d }
                case "tracking": if let d = v as? Double, l.text != nil { put(&l.text!.tracking, d) }
                case "parent", "id", "time", "keyframe", "set", "type", "shape", "light", "file": break
                default: unknown.append(k)
                }
            }
            proj.layers[i] = l
        }
        e.redrawToken += 1
        let out: [String: Any] = unknown.isEmpty ? ["ok": true] : ["ok": true, "ignored": unknown]
        return .json(out)
    }

    private func setParams(_ e: EditorState, layer: UUID, effect: UUID, _ params: [String: Any], at time: Double?, key: Bool) {
        let t = time ?? e.currentTime
        e.mutate("AI Effect Settings") { p in
            guard let i = p.layers.firstIndex(where: { $0.id == layer }), let j = p.layers[i].effects.firstIndex(where: { $0.id == effect }) else { return }
            var fx = p.layers[i].effects[j]
            for (k, v) in params {
                func put<V: Interpolatable>(_ a: Animated<V>, _ val: V) -> Animated<V> {
                    var a = a
                    if key { a.insertKeyframe(Keyframe(time: t, value: val, interpolation: .bezier)) } else { a.set(val, at: t) }
                    return a
                }
                switch (fx.params[k], v) {
                case (.number(let a)?, let d as Double): fx.params[k] = .number(put(a, d))
                case (.number(let a)?, let d as Int): fx.params[k] = .number(put(a, Double(d)))
                case (.point(let a)?, _): if let p2 = Self.vec(v) { fx.params[k] = .point(put(a, p2)) }
                case (.color(let a)?, _): if let c = Self.color(v) { fx.params[k] = .color(put(a, c)) }
                case (.toggle?, let b as Bool): fx.params[k] = .toggle(b)
                case (.choice?, let n as Int): fx.params[k] = .choice(n)
                default: break
                }
            }
            p.layers[i].effects[j] = fx
        }
    }

    // MARK: Contact sheet

    private func contactSheet(_ e: EditorState, count: Int, size: Double) -> HTTPResponse {
        guard let r = Renderer.shared else { return .json(["error": "no renderer"], status: 500) }
        let pid = e.project.id, store = e.store
        let dur = max(e.project.duration, 0.1)
        let imgs: [UIImage] = (0..<count).compactMap { k in
            r.renderImage(project: e.project, time: dur * Double(k) / Double(count), maxDimension: size, mediaURL: { store.mediaURL($0, projectID: pid) })
        }
        guard let first = imgs.first else { return .json(["error": "render failed"], status: 500) }
        let cols = min(count, 4), rows = (imgs.count + cols - 1) / cols
        let cw = first.size.width, ch = first.size.height
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: cw * CGFloat(cols), height: ch * CGFloat(rows))).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: cw * CGFloat(cols), height: ch * CGFloat(rows)))
            for (k, im) in imgs.enumerated() {
                im.draw(in: CGRect(x: CGFloat(k % cols) * cw, y: CGFloat(k / cols) * ch, width: cw, height: ch))
                let label = String(format: "%.2fs", dur * Double(k) / Double(count)) as NSString
                label.draw(at: CGPoint(x: CGFloat(k % cols) * cw + 6, y: CGFloat(k / cols) * ch + 4),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.white])
            }
        }
        guard let png = sheet.pngData() else { return .json(["error": "encode failed"], status: 500) }
        return HTTPResponse(status: 200, type: "image/png", body: png)
    }

    // MARK: Helpers

    static func uuid(_ v: Any?) -> UUID? { (v as? String).flatMap(UUID.init(uuidString:)) }
    static func vec(_ v: Any?) -> Vec2? {
        if let a = v as? [Double], a.count >= 2 { return Vec2(a[0], a[1]) }
        if let a = v as? [Int], a.count >= 2 { return Vec2(Double(a[0]), Double(a[1])) }
        if let a = v as? [NSNumber], a.count >= 2 { return Vec2(a[0].doubleValue, a[1].doubleValue) }
        return nil
    }
    static func color(_ v: Any?) -> RGBA? {
        if let s = v as? String, s.hasPrefix("#"), let n = UInt32(s.dropFirst(), radix: 16) { return RGBA(hex: n) }
        if let a = v as? [NSNumber], a.count >= 3 { return RGBA(a[0].doubleValue, a[1].doubleValue, a[2].doubleValue, a.count > 3 ? a[3].doubleValue : 1) }
        return nil
    }
    static func need(_ what: String) -> HTTPResponse { .json(["error": "needs \(what)"], status: 400) }
}
