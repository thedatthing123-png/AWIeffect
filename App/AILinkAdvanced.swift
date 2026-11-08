import Foundation
import UIKit

/// Additive AI Link controls. These use existing editor operations or validated Codable edits.
/// No rendering, UI, media format, or project persistence implementation is changed here.
extension AILink {
    func handleAdvanced(_ r: HTTPRequest, editor e: EditorState) -> HTTPResponse? {
        if let exported = AILinkExportJobs.shared.handle(r, editor: e) { return exported }
        let a = ((try? JSONSerialization.jsonObject(with: r.body)) as? [String: Any]) ?? [:]
        switch (r.method, r.path) {
        case ("POST", "/text/animators"):
            guard let id = Self.uuid(a["layer"]), let idx = e.project.layers.firstIndex(where: { $0.id == id }),
                  e.project.layers[idx].text != nil else {
                return .json(["error": "requires text layer"], status: 400)
            }
            let operation = a["operation"] as? String ?? "add"
            switch operation {
            case "add":
                let name = (a["name"] as? String) ?? "AI Animator"
                guard !name.isEmpty, name.count <= 100 else { return .json(["error": "invalid animator name"], status: 400) }
                let animator = TextAnimator(name: name)
                e.mutate("AI Add Text Animator") { $0.layers[idx].text?.animators.append(animator) }
                return .json(["ok": true, "id": animator.id.uuidString])
            case "remove":
                guard let aid = Self.uuid(a["animator"]),
                      e.project.layers[idx].text?.animators.contains(where: { $0.id == aid }) == true else {
                    return .json(["error": "animator not found"], status: 400)
                }
                e.mutate("AI Remove Text Animator") { $0.layers[idx].text?.animators.removeAll { $0.id == aid } }
                return .json(["ok": true])
            case "list":
                return .json(["animators": e.project.layers[idx].text?.animators.map {
                    ["id": $0.id.uuidString, "name": $0.name, "enabled": $0.isEnabled] as [String: Any]
                } ?? []])
            default: return .json(["error": "operation must be add|remove|list"], status: 400)
            }
        case ("POST", "/masks/path"):
            guard let id = Self.uuid(a["layer"]),
                  let idx = e.project.layers.firstIndex(where: { $0.id == id }),
                  let points = a["points"] as? [[NSNumber]],
                  points.count >= 3, points.count <= 300 else {
                return .json(["error": "requires layer and 3...300 path points"], status: 400)
            }
            var vertices: [PathVertex] = []
            for point in points {
                guard point.count == 2, point.allSatisfy({ $0.doubleValue.isFinite }) else {
                    return .json(["error": "each point must be [x,y]"], status: 400)
                }
                vertices.append(PathVertex(point: Vec2(point[0].doubleValue, point[1].doubleValue)))
            }
            var mask = LayerMask(path: Animated(BezierPath(vertices: vertices, closed: true)))
            if let name = a["name"] as? String { mask.name = name }
            if let mode = a["mode"] as? String, let m = MaskMode(rawValue: mode) { mask.mode = m }
            if let inverse = a["inverted"] as? Bool { mask.inverted = inverse }
            if let feather = (a["feather"] as? NSNumber)?.doubleValue, feather.isFinite {
                mask.feather = Animated(min(5000, max(0, feather)))
            }
            e.mutate("AI Add Mask") { $0.layers[idx].masks.append(mask) }
            return .json(["ok": true, "mask": mask.id.uuidString])
        case ("POST", "/physics/soft-body"):
            guard let id = Self.uuid(a["layer"]), e.project.layers.contains(where: { $0.id == id }),
                  let type = a["material"] as? String, let material = SoftMaterial(rawValue: type) else {
                return .json(["error": "requires layer and valid SoftMaterial"], status: 400)
            }
            let drop = (a["drop"] as? NSNumber)?.doubleValue ?? 150
            let gravity = (a["gravity"] as? NSNumber)?.doubleValue ?? 1800
            let duration = (a["duration"] as? NSNumber)?.doubleValue ?? 2
            guard [drop, gravity, duration].allSatisfy({ $0.isFinite }),
                  duration >= 0.1, duration <= 10 else {
                return .json(["error": "invalid soft-body settings"], status: 400)
            }
            e.select(id)
            e.bakeSoftBody(material, drop: drop, gravity: gravity, duration: duration,
                           floorAtBottom: a["floorAtBottom"] as? Bool ?? true)
            return .json(["ok": true])
        case ("POST", "/draw/layer"):
            guard UIApplication.shared.applicationState != .background else {
                return .json(["error": "Art Studio needs foreground app"], status: 409)
            }
            guard let id = Self.uuid(a["layer"]),
                  let layer = e.project.layers.first(where: { $0.id == id }),
                  layer.drawingID != nil,
                  let engine = e.makeDrawEngine(editing: layer) else {
                return .json(["error": "requires existing linked Art Studio drawing"], status: 400)
            }
            let index = a["index"] as? Int ?? engine.activeIndex
            guard engine.layers.indices.contains(index) else { return .json(["error": "invalid drawing layer index"], status: 400) }
            engine.activeIndex = index
            let op = a["operation"] as? String ?? "set"
            switch op {
            case "add": _ = engine.addLayer(name: a["name"] as? String)
            case "duplicate": engine.duplicateActiveLayer()
            case "delete":
                guard engine.layers.count > 1 else { return .json(["error": "cannot delete last drawing layer"], status: 400) }
                engine.deleteActiveLayer()
            case "up": engine.moveActiveLayer(up: true)
            case "down": engine.moveActiveLayer(up: false)
            case "set":
                guard let active = engine.activeLayer else { return .json(["error": "drawing layer not found"], status: 400) }
                if let name = a["name"] as? String { active.name = name }
                if let opacity = (a["opacity"] as? NSNumber)?.doubleValue, opacity.isFinite {
                    active.opacity = min(1, max(0, opacity))
                }
                if let blend = a["blend"] as? String, let mode = BlendMode(rawValue: blend) { active.blend = mode }
                if let visible = a["visible"] as? Bool { active.visible = visible }
                if let clipping = a["clipping"] as? Bool { active.clipping = clipping }
                if let locked = a["alphaLock"] as? Bool { active.alphaLock = locked }
            default: return .json(["error": "operation must be add|duplicate|delete|up|down|set"], status: 400)
            }
            e.finishDrawing(engine, editing: id)
            return .json(["ok": true, "drawingLayers": engine.layers.count])
        case ("GET", "/capabilities"):
            return .json([
                "mcp": "AI Link Advanced",
                "native": ["timeline", "effects", "presets", "easing", "graph", "expressions",
                           "3dModel", "3dText", "timeRemap", "precomps", "groups", "puppet",
                           "ikRig", "physicsBake", "drawStrokes", "textAnimators", "layerPatches",
                           "projectPatches", "keyframeVelocity"],
                "patchableLayerFields": ["text", "masks", "path", "stroke", "shapeOps", "model3D",
                                         "light", "camera", "ik", "timeFX", "cutout", "extrude",
                                         "trackMatte", "transform", "effects", "volume", "timeRemap"],
                "notes": "Native feature commands plus validated Codable patching. Open app to render or draw. Does not support export or standalone cache control yet."
            ])
        case ("POST", "/groups/create"):
            guard let ids = a["layers"] as? [String], !ids.isEmpty, ids.count <= 256 else {
                return .json(["error": "requires layers array"], status: 400)
            }
            let valid = ids.compactMap(UUID.init(uuidString:))
            guard valid.count == ids.count,
                  valid.allSatisfy({ id in e.project.layers.contains(where: { $0.id == id }) }) else {
                return .json(["error": "all layers must exist"], status: 400)
            }
            e.multiSelection = Set(valid)
            e.groupSelected()
            return .json(["ok": true, "group": e.selectedLayerID?.uuidString ?? ""])
        case ("POST", "/groups/ungroup"):
            guard let id = Self.uuid(a["layer"]),
                  let layer = e.project.layers.first(where: { $0.id == id }), layer.isGroup else {
                return .json(["error": "requires group layer"], status: 400)
            }
            e.select(id); e.ungroupSelected()
            return .json(["ok": true])
        case ("POST", "/rig/ik"):
            guard let lower = Self.uuid(a["lower"]), let upper = Self.uuid(a["upper"]),
                  lower != upper,
                  e.project.layers.contains(where: { $0.id == lower }),
                  e.project.layers.contains(where: { $0.id == upper }) else {
                return .json(["error": "requires existing upper and lower layer IDs"], status: 400)
            }
            let controller = Self.uuid(a["controller"])
            guard controller == nil || e.project.layers.contains(where: { $0.id == controller }) else {
                return .json(["error": "controller does not exist"], status: 400)
            }
            e.select(lower); e.makeIK(upper: upper, controller: controller)
            return .json(["ok": true, "controller": e.selectedLayerID?.uuidString ?? ""])
        case ("POST", "/rig/remove"):
            guard let id = Self.uuid(a["layer"]), let layer = e.project.layers.first(where: { $0.id == id }),
                  layer.ik != nil else { return .json(["error": "layer has no IK rig"], status: 400) }
            e.select(id); e.removeIK()
            return .json(["ok": true])
        case ("POST", "/puppet/pin"):
            guard let id = Self.uuid(a["layer"]),
                  e.project.layers.contains(where: { $0.id == id }),
                  let position = Self.vec(a["point"]),
                  position.x.isFinite, position.y.isFinite else {
                return .json(["error": "requires layer and comp-space point [x,y]"], status: 400)
            }
            e.select(id)
            let operation = a["operation"] as? String ?? "add"
            let index = a["index"] as? Int ?? -1
            switch operation {
            case "add": e.addPuppetPin(atComp: position)
            case "move":
                guard index >= 0 && index < e.puppetPins.count else {
                    return .json(["error": "invalid pin index"], status: 400)
                }
                e.movePuppetPin(index, toComp: position)
            case "remove":
                guard index >= 0 && index < e.puppetPins.count else {
                    return .json(["error": "invalid pin index"], status: 400)
                }
                e.removePuppetPin(index)
            case "starch":
                guard index >= 0 && index < e.puppetPins.count else {
                    return .json(["error": "invalid pin index"], status: 400)
                }
                e.togglePuppetStarch(index)
            case "reset": e.resetPuppetPose()
            default: return .json(["error": "operation must be add|move|remove|starch|reset"], status: 400)
            }
            return .json(["ok": true, "pins": e.puppetPins.count])
        case ("POST", "/physics/bake"):
            guard let strings = a["dynamic"] as? [String],
                  !strings.isEmpty, strings.count <= 100,
                  strings.allSatisfy({ UUID(uuidString: $0) != nil }),
                  let dynamics = Optional(strings.compactMap(UUID.init(uuidString:))),
                  dynamics.count == strings.count,
                  dynamics.allSatisfy({ id in e.project.layers.contains(where: { $0.id == id }) }) else {
                return .json(["error": "requires existing dynamic layer IDs"], status: 400)
            }
            let staticNames = (a["static"] as? [String]) ?? []
            let statics = staticNames.compactMap(UUID.init(uuidString:))
            guard statics.count == staticNames.count,
                  statics.allSatisfy({ id in e.project.layers.contains(where: { $0.id == id }) }) else {
                return .json(["error": "invalid static layers"], status: 400)
            }
            var settings = PhysicsSettings()
            if let gravity = (a["gravity"] as? NSNumber)?.doubleValue, gravity.isFinite { settings.gravity = gravity }
            if let bounce = (a["bounciness"] as? NSNumber)?.doubleValue, bounce.isFinite { settings.bounciness = min(1, max(0, bounce)) }
            if let friction = (a["friction"] as? NSNumber)?.doubleValue, friction.isFinite { settings.friction = min(1, max(0, friction)) }
            if let duration = (a["duration"] as? NSNumber)?.doubleValue, duration.isFinite { settings.duration = min(20, max(0.1, duration)) }
            if let substeps = a["substeps"] as? Int { settings.substeps = min(24, max(1, substeps)) }
            if let wind = Self.vec(a["wind"]), wind.x.isFinite, wind.y.isFinite { settings.wind = wind }
            if let launch = Self.vec(a["launch"]), launch.x.isFinite, launch.y.isFinite { settings.launch = launch }
            e.bakePhysics(dynamicIDs: dynamics, staticIDs: statics, settings: settings)
            return .json(["ok": true, "baked": dynamics.count])
        case ("POST", "/keyframes/velocity"):
            guard let id = Self.uuid(a["layer"]), e.project.layers.contains(where: { $0.id == id }),
                  let i = (a["inInfluence"] as? NSNumber)?.doubleValue,
                  let ispeed = (a["inSpeed"] as? NSNumber)?.doubleValue,
                  let o = (a["outInfluence"] as? NSNumber)?.doubleValue,
                  let ospeed = (a["outSpeed"] as? NSNumber)?.doubleValue,
                  [i, ispeed, o, ospeed].allSatisfy({ $0.isFinite }) else {
                return .json(["error": "requires layer, inInfluence, inSpeed, outInfluence, outSpeed"], status: 400)
            }
            e.select(id)
            if let t = (a["time"] as? NSNumber)?.doubleValue, t.isFinite { e.seek(t) }
            e.applyKeyframeVelocity(inInfluence: i, inSpeed: ispeed, outInfluence: o, outSpeed: ospeed)
            return .json(["ok": true])
        case ("POST", "/project/patch"):
            guard let changes = a["set"] as? [String: Any], !changes.isEmpty else {
                return .json(["error": "requires set object"], status: 400)
            }
            let protected: Set<String> = ["id", "layers", "precompList", "parentContext", "precompDepth"]
            guard protected.isDisjoint(with: changes.keys),
                  let data = try? JSONEncoder().encode(e.project),
                  var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return .json(["error": "cannot patch protected project fields"], status: 400)
            }
            Self.deepMerge(&json, changes)
            guard let updatedData = try? JSONSerialization.data(withJSONObject: json),
                  let newProject = try? JSONDecoder().decode(Project.self, from: updatedData),
                  newProject.id == e.project.id, newProject.width >= 16, newProject.height >= 16,
                  newProject.width <= 8192, newProject.height <= 8192, newProject.fps.isFinite,
                  newProject.fps > 0, newProject.fps <= 240, newProject.layers == e.project.layers else {
                return .json(["error": "project patch did not decode/validate"], status: 400)
            }
            e.mutate("AI Project Settings") { $0 = newProject }
            return .json(["ok": true])
        case ("POST", "/draw/strokes"):
            // Paint with the existing Metal Draw Studio brush engine; save through its existing linked-document path.
            guard UIApplication.shared.applicationState != .background else {
                return .json(["error": "drawing requires AWIeffect in the foreground"], status: 409)
            }
            guard let strokes = a["strokes"] as? [[String: Any]],
                  !strokes.isEmpty, strokes.count <= 128 else {
                return .json(["error": "requires 1...128 brush strokes"], status: 400)
            }
            let existingID = Self.uuid(a["layer"])
            let existingLayer = existingID.flatMap { id in e.project.layers.first(where: { $0.id == id }) }
            if existingID != nil && existingLayer?.drawingID == nil {
                return .json(["error": "layer is not an Art Studio drawing"], status: 400)
            }
            var paths: [[(SIMD2<Double>, Double)]] = []
            var pointsTotal = 0
            for stroke in strokes {
                guard let points = stroke["points"] as? [[NSNumber]], !points.isEmpty else {
                    return .json(["error": "each stroke needs points [[x,y,pressure?], ...]"], status: 400)
                }
                pointsTotal += points.count
                guard pointsTotal <= 16000 else { return .json(["error": "too many brush points"], status: 400) }
                var path: [(SIMD2<Double>, Double)] = []
                for point in points {
                    guard point.count >= 2, point.count <= 3,
                          point.allSatisfy({ $0.doubleValue.isFinite }) else {
                        return .json(["error": "invalid point"], status: 400)
                    }
                    path.append((SIMD2(point[0].doubleValue, point[1].doubleValue),
                                 point.count == 3 ? min(1, max(0, point[2].doubleValue)) : 1))
                }
                paths.append(path)
            }
            guard let engine = e.makeDrawEngine(editing: existingLayer) else {
                return .json(["error": "Draw Studio Metal engine unavailable"], status: 503)
            }
            if let kind = a["brush"] as? String, let b = BrushKind(rawValue: kind) { engine.brush.kind = b }
            if let size = (a["size"] as? NSNumber)?.doubleValue, size.isFinite {
                engine.brush.size = min(400, max(0.5, size))
            }
            if let opacity = (a["opacity"] as? NSNumber)?.doubleValue, opacity.isFinite {
                engine.brush.opacity = min(1, max(0, opacity))
            }
            if let c = Self.color(a["color"]) { engine.brush.color = c }
            for path in paths {
                guard let first = path.first else { continue }
                engine.beginStroke(at: first.0, pressure: first.1)
                for point in path.dropFirst() { engine.continueStroke(to: point.0, pressure: point.1) }
                engine.endStroke()
            }
            e.finishDrawing(engine, editing: existingID)
            return .json(["ok": true, "layer": e.selectedLayerID?.uuidString ?? existingID?.uuidString ?? "",
                          "strokes": paths.count, "points": pointsTotal])
        case ("POST", "/layers/model"):
            guard let f = a["file"] as? String,
                  !f.isEmpty, (f as NSString).lastPathComponent == f,
                  ["usdz", "obj"].contains((f as NSString).pathExtension.lowercased()),
                  FileManager.default.fileExists(atPath: e.mediaURL(f).path) else {
                return .json(["error": "requires uploaded .usdz or .obj file name"], status: 400)
            }
            e.addModelLayer(text: nil, fileURL: e.mediaURL(f))
            return .json(["ok": true, "id": e.selectedLayerID?.uuidString ?? ""])
        case ("POST", "/layers/text3d"):
            guard let content = a["text"] as? String, !content.isEmpty else {
                return .json(["error": "requires text"], status: 400)
            }
            e.addModelLayer(text: content, fileURL: nil)
            return .json(["ok": true, "id": e.selectedLayerID?.uuidString ?? ""])
        case ("POST", "/layers/expression"):
            guard let id = Self.uuid(a["layer"]),
                  e.project.layers.contains(where: { $0.id == id }),
                  let name = a["property"] as? String,
                  let property = PropertyKey(rawValue: name) else {
                return .json(["error": "requires valid layer and property"], status: 400)
            }
            e.select(id)
            e.setExpression(property, a["expression"] as? String)
            return .json(["ok": true])
        case ("POST", "/layers/graph"):
            guard let id = Self.uuid(a["layer"]),
                  e.project.layers.contains(where: { $0.id == id }),
                  let name = a["property"] as? String,
                  let property = PropertyKey(rawValue: name),
                  let values = a["out"] as? [NSNumber], values.count == 2,
                  let incoming = a["in"] as? [NSNumber], incoming.count == 2,
                  values.allSatisfy({ $0.doubleValue.isFinite }),
                  incoming.allSatisfy({ $0.doubleValue.isFinite }) else {
                return .json(["error": "requires layer, property, out:[x,y], in:[x,y]"], status: 400)
            }
            let interpolation = Interpolation(rawValue: a["interpolation"] as? String ?? "bezier") ?? .bezier
            e.select(id)
            let segment = a["segment"] as? Int
            let segments = e.easeSegments(property)
            guard !segments.isEmpty, segment == nil || (segment! >= 0 && segment! < segments.count) else {
                return .json(["error": "property needs at least 2 keyframes; segment must exist"], status: 400)
            }
            e.setEase(property, segment: segment, interpolation: interpolation,
                      out: EaseHandle(x: values[0].doubleValue, y: values[1].doubleValue),
                      into: EaseHandle(x: incoming[0].doubleValue, y: incoming[1].doubleValue))
            return .json(["ok": true])
        case ("POST", "/layers/remap"):
            guard let id = Self.uuid(a["layer"]),
                  let index = e.project.layers.firstIndex(where: { $0.id == id }) else {
                return .json(["error": "requires valid layer"], status: 400)
            }
            if a["clear"] as? Bool == true {
                e.mutate("AI Clear Time Remap") { $0.layers[index].timeRemap = nil }
                return .json(["ok": true])
            }
            guard let points = a["points"] as? [[String: Any]], points.count >= 2, points.count <= 2048 else {
                return .json(["error": "points must contain 2...2048 {time, source} entries"], status: 400)
            }
            var pairs: [(Double, Double)] = []
            for point in points {
                guard let t = (point["time"] as? NSNumber)?.doubleValue,
                      let source = (point["source"] as? NSNumber)?.doubleValue,
                      t.isFinite, source.isFinite, t >= 0, source >= 0 else {
                    return .json(["error": "invalid remap time or source"], status: 400)
                }
                pairs.append((t, source))
            }
            pairs.sort { $0.0 < $1.0 }
            guard zip(pairs, pairs.dropFirst()).allSatisfy({ $0.0.0 < $0.1.0 }) else {
                return .json(["error": "remap times must be unique"], status: 400)
            }
            var animation = Animated(pairs[0].1)
            for (time, source) in pairs {
                animation.insertKeyframe(Keyframe(time: time, value: source, interpolation: .linear))
            }
            e.mutate("AI Time Remap") { $0.layers[index].timeRemap = animation }
            return .json(["ok": true, "keyframes": pairs.count])
        case ("POST", "/precomp/open"):
            guard let id = Self.uuid(a["layer"]), let layer = e.project.layers.first(where: { $0.id == id }) else {
                return .json(["error": "requires precomp layer"], status: 400)
            }
            guard case .precomp = layer.content else { return .json(["error": "layer is not a precomp"], status: 400) }
            e.select(id)
            e.openPrecomp()
            return .json(["ok": true, "name": e.project.name])
        case ("POST", "/precomp/close"):
            guard e.isInPrecomp else { return .json(["error": "not in a precomp"], status: 409) }
            e.closePrecomp()
            return .json(["ok": true, "name": e.project.name])
        case ("POST", "/layers/patch"):
            guard let id = Self.uuid(a["layer"]), let changes = a["set"] as? [String: Any] else {
                return .json(["error": "requires layer and set object"], status: 400)
            }
            return patchLayers([["layer": id.uuidString, "set": changes]], e)
        case ("POST", "/layers/batch-patch"):
            guard let patches = a["patches"] as? [[String: Any]], !patches.isEmpty, patches.count <= 256 else {
                return .json(["error": "requires 1...256 patches"], status: 400)
            }
            return patchLayers(patches, e)
        default: return nil
        }
    }

    /// Validate all changes and decode all layers before changing the project.
    /// Protected identity and layer-content fields cannot be changed by arbitrary JSON.
    private func patchLayers(_ patches: [[String: Any]], _ e: EditorState) -> HTTPResponse {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var prepared: [(Int, Layer)] = []
        var occupied = Set<UUID>()
        let forbidden: Set<String> = ["id", "content", "parentID", "groupID", "drawingID", "isGroup"]
        for patch in patches {
            guard let id = Self.uuid(patch["layer"]),
                  let index = e.project.layers.firstIndex(where: { $0.id == id }),
                  let updates = patch["set"] as? [String: Any],
                  !updates.isEmpty, forbidden.isDisjoint(with: updates.keys),
                  !occupied.contains(id) else {
                return .json(["error": "invalid/duplicate layer or protected field (id, content, parentID, groupID, drawingID, isGroup)"], status: 400)
            }
            occupied.insert(id)
            guard let data = try? encoder.encode(e.project.layers[index]),
                  var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return .json(["error": "could not serialize layer"], status: 500)
            }
            Self.deepMerge(&json, updates)
            guard let merged = try? JSONSerialization.data(withJSONObject: json),
                  let result = try? decoder.decode(Layer.self, from: merged),
                  result.id == id, result.inPoint.isFinite, result.outPoint.isFinite,
                  result.outPoint > result.inPoint else {
                return .json(["error": "patch failed layer validation/decoding"], status: 400)
            }
            prepared.append((index, result))
        }
        e.mutate("AI Batch Layer Edit") { project in
            for (index, layer) in prepared { project.layers[index] = layer }
        }
        e.redrawToken += 1
        return .json(["ok": true, "updated": prepared.count])
    }

    private static func deepMerge(_ target: inout [String: Any], _ source: [String: Any]) {
        for (key, value) in source {
            if var original = target[key] as? [String: Any], let nested = value as? [String: Any] {
                deepMerge(&original, nested)
                target[key] = original
            } else {
                target[key] = value
            }
        }
    }
}
