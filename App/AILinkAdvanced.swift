import Foundation
import UIKit

/// Native operations for the AI Link editor. Never exposes relay settings, pairing keys,
/// Settings UI or storage. All mutations run through EditorState's existing undo machinery.
extension AILink {
    func handleAdvanced(_ r: HTTPRequest) -> HTTPResponse? {
        if r.method == "GET" && (r.path == "/editor/capabilities" || r.path == "/capabilities") {
            return .json([
                "version": 1,
                "rigCommands": ["inspect", "add_bone", "select_bone", "reparent_bone",
                                "delete_bone", "move_rest_joint", "pose_bone",
                                "bind_mesh", "unbind_mesh", "paint_weights",
                                "make_chain_ik", "remove_ik", "set_deform_amount"],
                "groupCommands": ["create","ungroup","duplicate"],
                "textAnimatorCommands": ["list", "add", "remove"],
                "artStudioCommands": ["draw_strokes", "edit_drawing_layer", "draw_operations"],
                "layerPatchFields": Self.aiPatchFields.sorted(),
                "restrictions": ["App settings and relay keys are unavailable",
                                 "Existing project and media IDs must be preserved",
                                 "Use app-native rig commands instead of modifying bone JSON by hand"]
            ])
        }
        let a = ((try? JSONSerialization.jsonObject(with: r.body)) as? [String: Any]) ?? [:]
        switch (r.method, r.path) {
        case ("GET", "/timeline"):
            guard let e = editor else { return .noProject }
            let p = e.project
            return .json(["ok": true, "project": p.name, "width": p.width,
                          "height": p.height, "fps": p.fps, "duration": p.duration,
                          "time": e.currentTime,
                          "layers": p.layers.enumerated().map { i, l in
                              ["id": l.id.uuidString, "name": l.name, "index": i,
                               "inPoint": l.inPoint, "outPoint": l.outPoint,
                               "visible": l.isVisible, "locked": l.isLocked,
                               "effectCount": l.effects.count, "is3D": l.is3D] as [String: Any]
                          }])
        case ("POST", "/groups/create"):
            guard let e = editor else { return .noProject }
            var input = a
            input["command"] = "create"
            return aiGroupCommand(input, e)
        case ("POST", "/groups/ungroup"):
            guard let e = editor else { return .noProject }
            var input = a
            input["command"] = "ungroup"
            input["group"] = a["group"] ?? a["layer"]
            return aiGroupCommand(input, e)
        case ("POST", "/layers/patch"):
            guard let e = editor else { return .noProject }
            var input = a
            input["id"] = a["id"] ?? a["layer"]
            return aiPatchLayer(input, e)
        case ("POST", "/precomp/open"):
            guard let e = editor, let id = Self.uuid(a["layer"]),
                  let layer = e.project.layers.first(where: { $0.id == id }),
                  case .precomp = layer.content else {
                return .json(["error": "existing precomp layer required"], status: 400)
            }
            e.select(id)
            e.openPrecomp()
            return .json(["ok": e.isInPrecomp, "opened": id.uuidString])
        case ("POST", "/precomp/close"):
            guard let e = editor else { return .noProject }
            guard e.isInPrecomp else { return .json(["error": "no open precomp"], status: 409) }
            e.closePrecomp()
            return .json(["ok": true])
        case ("POST", "/layers/graph"):
            guard let e = editor else { return .noProject }
            return aiGraphHandles(a, e)
        case ("POST", "/keyframes/velocity"):
            guard let e = editor else { return .noProject }
            return aiVelocity(a, e)
        case ("POST", "/layers/expression"):
            guard let e = editor else { return .noProject }
            return aiExpression(a, e)
        case ("POST", "/layers/remap"):
            guard let e = editor else { return .noProject }
            return aiTimeRemap(a, e)
        case ("POST", "/masks/path"):
            guard let e = editor else { return .noProject }
            return aiAddMaskPath(a, e)
        case ("POST", "/layers/batch-patch"):
            guard let e = editor else { return .noProject }
            return aiBatchPatchLayers(a, e)
        case ("POST", "/project/patch"):
            guard let e = editor else { return .noProject }
            return aiPatchProject(a, e)
        case ("POST", "/physics/bake"):
            guard let e = editor else { return .noProject }
            return aiBakePhysics(a, e)
        case ("POST", "/physics/soft-body"):
            guard let e = editor else { return .noProject }
            return aiBakeSoftBody(a, e)
        case ("POST", "/rig/ik"):
            guard let e = editor else { return .noProject }
            return aiLegacyIK(a, e, remove: false)
        case ("POST", "/rig/remove"):
            guard let e = editor else { return .noProject }
            return aiLegacyIK(a, e, remove: true)
        case ("POST", "/text/animators"):
            guard let e = editor else { return .noProject }
            return aiTextAnimators(a, e)
        case ("POST", "/editor/rig"):
            guard let e = editor else { return .noProject }
            return aiRigCommand(a, e)
        case ("POST", "/editor/layer/patch"):
            guard let e = editor else { return .noProject }
            return aiPatchLayer(a, e)
        case ("POST", "/editor/group"):
            guard let e = editor else { return .noProject }
            return aiGroupCommand(a, e)
        default:
            return handleArtStudio(r)
        }
    }





    private func aiGraphHandles(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let id = Self.uuid(a["layer"]),
              let layer = e.project.layers.first(where: {$0.id == id}), !layer.isLocked,
              let name = a["property"] as? String, let key = PropertyKey(rawValue:name),
              let out = aiPoint(a["out"]), let inside = aiPoint(a["in"]),
              out.x.isFinite, out.y.isFinite, inside.x.isFinite, inside.y.isFinite,
              out.x > 0, out.x <= 1, inside.x >= 0, inside.x < 1,
              abs(out.y) <= 100, abs(inside.y) <= 100 else {
            return Self.need("unlocked layer, property, out/in [x,y] handles")
        }
        let rawInterp = a["interpolation"] as? String ?? "bezier"
        guard let interp = Interpolation(rawValue:rawInterp) else {
            return .json(["error":"interpolation must be linear, bezier or hold"],status:400)
        }
        e.select(id)
        let segments = e.easeSegments(key)
        guard !segments.isEmpty else { return .json(["error":"property requires at least 2 keyframes"],status:409) }
        let seg = a["segment"] as? Int
        guard seg == nil || (seg! >= 0 && seg! < segments.count) else {
            return .json(["error":"segment index out of range"],status:400)
        }
        e.setEase(key,segment:seg,interpolation:interp,
                  out:EaseHandle(x:out.x,y:out.y),into:EaseHandle(x:inside.x,y:inside.y))
        return .json(["ok":true,"layer":id.uuidString,"property":name,
                      "segments":seg == nil ? segments.count : 1])
    }

    private func aiVelocity(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let id = Self.uuid(a["layer"]),
              let layer = e.project.layers.first(where: {$0.id == id}), !layer.isLocked else {
            return Self.need("unlocked layer")
        }
        let inputs = ["inInfluence","inSpeed","outInfluence","outSpeed"]
        var values: [Double] = []
        for name in inputs {
            guard let n = (a[name] as? NSNumber)?.doubleValue, n.isFinite,
                  (name.hasSuffix("Influence") ? (n >= 0.1 && n <= 100) : (n >= -1000 && n <= 1000)) else {
                return .json(["error":"velocity influence must be 0.1..100%; speed -1000..100%","field":name],status:400)
            }
            values.append(n)
        }
        let time = (a["time"] as? NSNumber)?.doubleValue ?? e.currentTime
        guard time.isFinite && time >= 0 && time <= e.project.duration else { return Self.need("time") }
        e.select(id)
        e.seek(time)
        guard e.hasKeyframeAtPlayhead else {
            return .json(["error":"no transform keyframe at requested time"],status:409)
        }
        e.applyKeyframeVelocity(inInfluence:values[0] / 100, inSpeed:values[1] / 100,
                                outInfluence:values[2] / 100, outSpeed:values[3] / 100)
        return .json(["ok":true,"layer":id.uuidString,"time":time])
    }

    private func aiExpression(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let id = Self.uuid(a["layer"]),
              e.project.layers.contains(where: {$0.id == id && !$0.isLocked}),
              let raw = a["property"] as? String,
              let key = PropertyKey(rawValue:raw) else {
            return Self.need("unlocked layer and property")
        }
        let expression = a["expression"] as? String
        guard expression == nil || expression!.count <= 8000 else {
            return .json(["error":"expression too long"],status:400)
        }
        e.select(id)
        e.setExpression(key,expression)
        return .json(["ok":true,"layer":id.uuidString,"property":raw])
    }

    private func aiTimeRemap(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let id = Self.uuid(a["layer"]),
              e.project.layers.contains(where: {$0.id == id && !$0.isLocked}) else {
            return Self.need("unlocked layer")
        }
        if a["clear"] as? Bool == true {
            e.mutate("AI Clear Time Remap") { project in
                if let i = project.layers.firstIndex(where: {$0.id == id}) {
                    project.layers[i].timeRemap = nil
                }
            }
            return .json(["ok":true,"cleared":true])
        }
        guard let raw = a["points"] as? [[String: Any]],
              (2...256).contains(raw.count) else {
            return Self.need("points: [{time,source}, ...] (2..256)")
        }
        var points: [(Double,Double)] = []
        for point in raw {
            guard let t = (point["time"] as? NSNumber)?.doubleValue,
                  let source = (point["source"] as? NSNumber)?.doubleValue,
                  t.isFinite, source.isFinite, t >= 0, source >= 0,
                  (points.last.map({t > $0.0}) ?? true) else {
                return .json(["error":"time/source must be finite nonnegative and times strictly increasing"],status:400)
            }
            points.append((t,source))
        }
        var remap = Animated(points[0].1)
        for (t,source) in points {
            remap.insertKeyframe(Keyframe(time:t,value:source,interpolation:.linear))
        }
        e.mutate("AI Time Remap") { project in
            if let i = project.layers.firstIndex(where: {$0.id == id}) {
                project.layers[i].timeRemap = remap
            }
        }
        return .json(["ok":true,"layer":id.uuidString,"keyframes":points.count])
    }

    /// Legacy relay route: add a closed native bezier mask, not an AI-generated matte.
    private func aiAddMaskPath(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let id = Self.uuid(a["layer"]),
              let old = e.project.layers.first(where: { $0.id == id }), !old.isLocked else {
            return .json(["error":"existing unlocked layer required"],status:404)
        }
        guard let points = a["points"] as? [[NSNumber]],
              (3...1000).contains(points.count),
              points.allSatisfy({ $0.count == 2 && $0[0].doubleValue.isFinite && $0[1].doubleValue.isFinite &&
                                 abs($0[0].doubleValue) <= 100000 && abs($0[1].doubleValue) <= 100000 }) else {
            return .json(["error":"points require 3..1000 finite [x,y] vertices"],status:400)
        }
        var mask = LayerMask(path: Animated(BezierPath(vertices: points.map {
            PathVertex(point: Vec2($0[0].doubleValue, $0[1].doubleValue))
        }, closed: true)))
        if let name = a["name"] as? String { mask.name = String(name.prefix(120)) }
        if let raw = a["mode"] as? String {
            guard let mode = MaskMode(rawValue: raw) else { return .json(["error":"invalid mask mode"],status:400) }
            mask.mode = mode
        }
        mask.inverted = a["inverted"] as? Bool ?? false
        if let feather = (a["feather"] as? NSNumber)?.doubleValue, feather.isFinite {
            mask.feather = Animated(max(0,min(5000,feather)))
        }
        e.mutate("AI Add Mask") { p in
            guard let i = p.layers.firstIndex(where: {$0.id == id}) else { return }
            p.layers[i].masks.append(mask)
        }
        return .json(["ok":true,"layer":id.uuidString,"mask":mask.id.uuidString])
    }

    /// Apply multiple existing-layer edits in one undo step; fail the entire batch on invalid JSON.
    private func aiBatchPatchLayers(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let patches = a["patches"] as? [[String: Any]], (1...256).contains(patches.count) else {
            return .json(["error":"patches requires 1..256 entries"],status:400)
        }
        let enc = JSONEncoder(), dec = JSONDecoder()
        var replacements: [UUID: Layer] = [:]
        do {
            for patch in patches {
                guard let id = Self.uuid(patch["layer"]),
                      replacements[id] == nil,
                      let set = patch["set"] as? [String: Any], !set.isEmpty,
                      Set(set.keys).isSubset(of: Self.aiPatchFields),
                      let original = e.project.layers.first(where: {$0.id == id}), !original.isLocked,
                      var obj = try JSONSerialization.jsonObject(with: enc.encode(original)) as? [String: Any] else {
                    return .json(["error":"invalid, locked, duplicate, or protected layer patch"],status:400)
                }
                for (key, value) in set { obj[key] = value }
                let updated = try dec.decode(Layer.self, from: JSONSerialization.data(withJSONObject: obj))
                guard updated.id == id, updated.content == original.content else {
                    return .json(["error":"layer identity/content cannot change"],status:400)
                }
                replacements[id] = updated
            }
        } catch {
            return .json(["error":"invalid patch JSON: \(error)"],status:400)
        }
        e.mutate("AI Batch Patch Layers") { p in
            for i in p.layers.indices {
                if let replacement = replacements[p.layers[i].id] { p.layers[i] = replacement }
            }
        }
        return .json(["ok":true,"updated":replacements.keys.map(\.uuidString).sorted()])
    }

    /// Only project composition metadata. Never app Settings or relay credentials.
    private func aiPatchProject(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let set = a["set"] as? [String: Any], !set.isEmpty else { return Self.need("set") }
        let allowed: Set<String> = ["name","duration","fps","width","height"]
        guard Set(set.keys).isSubset(of: allowed) else {
            return .json(["error":"unsupported or protected project field","allowed":allowed.sorted()],status:400)
        }
        let newName = set["name"] as? String
        let duration = (set["duration"] as? NSNumber)?.doubleValue
        let fps = (set["fps"] as? NSNumber)?.doubleValue
        let width = (set["width"] as? NSNumber)?.intValue
        let height = (set["height"] as? NSNumber)?.intValue
        if (set["name"] != nil && (newName == nil || newName!.isEmpty || newName!.count > 120)) ||
           (set["duration"] != nil && (duration == nil || !duration!.isFinite || duration! < 1 || duration! > 36000)) ||
           (set["fps"] != nil && (fps == nil || !fps!.isFinite || fps! < 1 || fps! > 240)) ||
           (set["width"] != nil && (width == nil || width! < 16 || width! > 8192)) ||
           (set["height"] != nil && (height == nil || height! < 16 || height! > 8192)) {
            return .json(["error":"invalid composition dimensions or timing"],status:400)
        }
        e.mutate("AI Project Properties") { p in
            if let newName { p.name = newName }
            if let duration { p.duration = duration }
            if let fps { p.fps = fps }
            if let width { p.width = width }
            if let height { p.height = height }
        }
        return .json(["ok":true,"fields":set.keys.sorted()])
    }

    private func aiBakePhysics(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let raw = a["dynamic"] as? [String], !raw.isEmpty, raw.count <= 128,
              let ids = Optional(raw.compactMap(UUID.init(uuidString:))), ids.count == raw.count,
              ids.allSatisfy({ id in e.project.layers.contains(where: {$0.id == id && !$0.isLocked}) }) else {
            return Self.need("dynamic unlocked layer IDs")
        }
        let rawStatic = (a["static"] as? [String]) ?? []
        let statics = rawStatic.compactMap(UUID.init(uuidString:))
        guard statics.count == rawStatic.count else { return Self.need("valid static layer IDs") }
        var settings = PhysicsSettings()
        if let n = (a["gravity"] as? NSNumber)?.doubleValue, n.isFinite { settings.gravity = max(-20000,min(20000,n)) }
        if let n = (a["bounciness"] as? NSNumber)?.doubleValue, n.isFinite { settings.bounciness = max(0,min(1,n)) }
        if let n = (a["friction"] as? NSNumber)?.doubleValue, n.isFinite { settings.friction = max(0,min(1,n)) }
        if let n = (a["duration"] as? NSNumber)?.doubleValue, n.isFinite { settings.duration = max(0.1,min(30,n)) }
        if let n = a["substeps"] as? Int { settings.substeps = max(1,min(32,n)) }
        if let p = aiPoint(a["wind"]) { settings.wind = p }
        if let p = aiPoint(a["launch"]) { settings.launch = p }
        e.bakePhysics(dynamicIDs:ids,staticIDs:statics,settings:settings)
        return .json(["ok":true,"dynamicCount":ids.count])
    }

    private func aiBakeSoftBody(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let id = Self.uuid(a["layer"]),
              let layer = e.project.layers.first(where: {$0.id == id}), !layer.isLocked,
              let raw = a["material"] as? String, let material = SoftMaterial(rawValue:raw) else {
            return Self.need("unlocked layer and material (jelly|rubber|slime|pudding|stiff)")
        }
        e.select(id)
        let drop = max(0,min(5000,(a["drop"] as? NSNumber)?.doubleValue ?? 200))
        let gravity = max(0,min(20000,(a["gravity"] as? NSNumber)?.doubleValue ?? 1800))
        let duration = max(0.1,min(30,(a["duration"] as? NSNumber)?.doubleValue ?? 2))
        e.bakeSoftBody(material,drop:drop,gravity:gravity,duration:duration,
                       floorAtBottom:a["floorAtBottom"] as? Bool ?? true)
        return .json(["ok":true,"layer":id.uuidString])
    }

    private func aiLegacyIK(_ a: [String: Any], _ e: EditorState, remove: Bool) -> HTTPResponse {
        if remove {
            guard let id = Self.uuid(a["layer"]), e.project.layers.contains(where: {$0.id == id}) else {
                return Self.need("layer")
            }
            e.select(id)
            e.removeIK()
            return .json(["ok":true,"layer":id.uuidString])
        }
        guard let upper = Self.uuid(a["upper"]), let lower = Self.uuid(a["lower"]),
              upper != lower, e.project.layers.contains(where: {$0.id == upper && !$0.isLocked}),
              e.project.layers.contains(where: {$0.id == lower && !$0.isLocked}) else {
            return Self.need("upper and lower unlocked layer IDs")
        }
        let controller = Self.uuid(a["controller"])
        e.select(lower)
        e.makeIK(upper:upper,controller:controller)
        guard e.project.layers.contains(where: {$0.id == lower && $0.ik != nil}) else {
            return .json(["error":"native IK authoring rejected the joint relationship"],status:409)
        }
        return .json(["ok":true,"lower":lower.uuidString])
    }

    /// Bridges the native TextStudio animator model to the unified connector.
    /// Only acts on an existing unlocked text layer. One undo step per mutation.
    private func aiTextAnimators(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let id = Self.uuid(a["layer"]) else { return Self.need("layer") }
        guard let layer = e.project.layers.first(where: { $0.id == id }),
              let text = layer.text else {
            return .json(["error": "text layer not found", "layer": id.uuidString], status: 404)
        }
        let op = (a["operation"] as? String) ?? "list"
        if op == "list" {
            return .json(["ok": true, "layer": id.uuidString,
                          "animators": text.animators.map { ["id": $0.id.uuidString, "name": $0.name, "enabled": $0.isEnabled] as [String: Any] }])
        }
        guard !layer.isLocked else {
            return .json(["error": "text layer is locked"], status: 409)
        }
        switch op {
        case "add":
            let name = (a["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let animatorName = (name?.isEmpty == false ? name! : "Text Animator")
            guard animatorName.count <= 128, text.animators.count < 128 else {
                return .json(["error": "animator limit or name length exceeded"], status: 400)
            }
            let newAnimator = TextAnimator(name: animatorName)
            e.mutate("AI Add Text Animator") { project in
                guard let i = project.layers.firstIndex(where: { $0.id == id }) else { return }
                project.layers[i].text?.animators.append(newAnimator)
            }
            return .json(["ok": true, "layer": id.uuidString, "animator": newAnimator.id.uuidString, "name": newAnimator.name])
        case "remove":
            guard let animatorID = Self.uuid(a["animator"]),
                  text.animators.contains(where: { $0.id == animatorID }) else {
                return .json(["error": "valid animator UUID required"], status: 404)
            }
            e.mutate("AI Remove Text Animator") { project in
                guard let i = project.layers.firstIndex(where: { $0.id == id }) else { return }
                project.layers[i].text?.animators.removeAll { $0.id == animatorID }
            }
            return .json(["ok": true, "layer": id.uuidString, "removed": animatorID.uuidString])
        default:
            return .json(["error": "unsupported animator operation", "operations": ["list", "add", "remove"]], status: 400)
        }
    }

    private func aiGroupCommand(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let command = a["command"] as? String else { return Self.need("command") }
        switch command {
        case "create":
            guard let raw = a["layers"] as? [String], !raw.isEmpty,
                  raw.count <= 256 else { return Self.need("layers (1..256)") }
            let ids = raw.compactMap(UUID.init(uuidString:))
            guard ids.count == raw.count, ids.allSatisfy({ id in e.project.layers.contains { $0.id == id && !$0.isLocked } }) else {
                return .json(["error":"all selected layers must exist and be unlocked"],status:400)
            }
            e.multiSelection = Set(ids)
            e.groupSelected()
            guard let id = e.selectedLayerID, e.project.layers.first(where: {$0.id == id})?.isGroup == true else {
                return .json(["error":"group creation failed"],status:409)
            }
            return .json(["ok":true,"group":id.uuidString])
        case "ungroup":
            guard let id = Self.uuid(a["group"]), e.project.layers.first(where:{$0.id == id})?.isGroup == true else {
                return Self.need("valid group")
            }
            e.select(id)
            e.ungroupSelected()
            return .json(["ok":!e.project.layers.contains(where: {$0.id == id}),"group":id.uuidString])
        case "duplicate":
            guard let id = Self.uuid(a["group"]), e.project.layers.first(where: {$0.id == id})?.isGroup == true else {
                return Self.need("valid group")
            }
            e.duplicateGroup(id)
            return .json(["ok":true])
        default:
            return .json(["error":"unsupported group command","commands":["create","ungroup","duplicate"]],status:404)
        }
    }

    /// Codable merge against an existing layer: never replace an incomplete layer
    /// or construct unknown model types by guessing their encoded representation.
    private static var aiPatchFields: Set<String> { [
        "name", "masks", "cutout", "path", "shapeContents", "shapeOps", "stroke",
        "effects", "text", "camera", "light", "model3D", "timeFX", "timeRemap",
        "trackMatte", "clipToBelow", "blendMode", "isVisible", "isLocked",
        "isSolo", "groupCollapsed", "inPoint", "outPoint", "motionBlur",
        "volume", "audioFX", "layerMarkers", "frameBlending", "speed",
        "sourceStart", "drawingID", "isCollider", "castsShadows",
        "acceptsShadows"
    ] }

    private func aiPatchLayer(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let id = Self.uuid(a["id"]), let changes = a["set"] as? [String: Any],
              !changes.isEmpty else { return Self.need("id, set") }
        let blocked = Set(changes.keys).subtracting(Self.aiPatchFields)
        guard blocked.isEmpty else {
            return .json(["error": "unsupported or protected layer fields",
                          "fields": blocked.sorted()], status: 400)
        }
        guard let old = e.project.layers.first(where: { $0.id == id }), !old.isLocked else {
            return .json(["error": "layer not found or locked"], status: 404)
        }
        do {
            let encoder = JSONEncoder()
            let original = try encoder.encode(old)
            guard var json = try JSONSerialization.jsonObject(with: original) as? [String: Any] else {
                return .json(["error": "layer encoding failed"], status: 500)
            }
            for (k, v) in changes { json[k] = v }
            let bytes = try JSONSerialization.data(withJSONObject: json)
            let replacement = try JSONDecoder().decode(Layer.self, from: bytes)
            guard replacement.id == id, replacement.content == old.content else {
                return .json(["error": "unsafe identity or content change"], status: 400)
            }
            e.mutate("AI Edit Layer") { p in
                if let i = p.layers.firstIndex(where: { $0.id == id }) { p.layers[i] = replacement }
            }
            return .json(["ok": true, "id": id.uuidString, "fields": changes.keys.sorted()])
        } catch {
            return .json(["error": "invalid layer patch: \(error)"], status: 400)
        }
    }

    private func aiPoint(_ value: Any?) -> Vec2? {
        guard let numbers = value as? [NSNumber], numbers.count == 2 else { return nil }
        let x = numbers[0].doubleValue, y = numbers[1].doubleValue
        guard x.isFinite, y.isFinite, abs(x) < 1e7, abs(y) < 1e7 else { return nil }
        return Vec2(x, y)
    }

    private func aiRigCommand(_ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        guard let command = a["command"] as? String else { return Self.need("command") }
        switch command {
        case "inspect":
            let owner = Self.uuid(a["artwork"]) ?? e.rigArtworkID
            let bones = e.project.layers.filter { $0.bone?.artworkID == owner }
                .map { b -> [String: Any] in
                    let tip = b.bone?.tip ?? .zero
                    return ["id": b.id.uuidString, "name": b.name,
                            "parent": b.parentID?.uuidString ?? "",
                            "tip": [tip.x, tip.y]]
                }
            let mesh = owner.flatMap { id in e.project.layers.first { $0.id == id } }?.boneMesh
            return .json(["ok": true, "artwork": owner?.uuidString ?? "",
                          "bones": bones, "meshBound": mesh != nil,
                          "vertexCount": mesh?.vertices.count ?? 0,
                          "boneInfluences": mesh?.boneIDs.map(\.uuidString) ?? []])
        case "add_bone":
            guard let artwork = Self.uuid(a["artwork"]), let start = aiPoint(a["start"]),
                  let end = aiPoint(a["end"]) else { return Self.need("artwork, start [x,y], end [x,y]") }
            let parent = Self.uuid(a["parent"])
            guard let id = e.addBone(artworkID: artwork, parentID: parent, start: start, end: end) else {
                return .json(["error": "cannot add bone; check artwork, parent and coordinates"], status: 409)
            }
            return .json(["ok": true, "bone": id.uuidString])
        case "select_bone":
            guard let id = Self.uuid(a["bone"]), e.project.layers.contains(where: { $0.id == id && $0.bone != nil }) else {
                return Self.need("valid bone")
            }
            e.selectAuthoringBone(id)
            return .json(["ok": true])
        case "reparent_bone":
            guard let id = Self.uuid(a["bone"]), let parent = Self.uuid(a["parent"]),
                  let b = e.project.layers.first(where: { $0.id == id }), b.bone != nil else {
                return Self.need("valid bone, parent")
            }
            guard id != parent, !IKSolver.descendants(of: id, in: e.project).contains(parent) else {
                return .json(["error": "reparent would create cycle"], status: 409)
            }
            e.reparentAuthoringBone(id, to: parent)
            return .json(["ok": true])
        case "delete_bone":
            guard let id = Self.uuid(a["bone"]), e.project.layers.contains(where: { $0.id == id && $0.bone != nil }) else {
                return Self.need("valid bone")
            }
            e.deleteAuthoringBone(id)
            return .json(["ok": true])
        case "move_rest_joint":
            guard let id = Self.uuid(a["bone"]), let p = aiPoint(a["point"]),
                  e.project.layers.contains(where: { $0.id == id && $0.bone != nil }) else {
                return Self.need("valid bone, point [x,y] (bone parent space)")
            }
            e.select(id)
            let wasRest = e.boneRestEditing
            e.boneRestEditing = true
            e.moveBoneRestJoint(id, to: p)
            e.finishBoneRestEditing()
            e.boneRestEditing = wasRest
            return .json(["ok": true])
        case "pose_bone":
            guard let id = Self.uuid(a["bone"]), let p = aiPoint(a["point"]),
                  e.project.layers.contains(where: { $0.id == id && $0.bone != nil }) else {
                return Self.need("valid bone, point [x,y] (canvas space)")
            }
            e.poseBone(id, atCanvas: p)
            return .json(["ok": true])
        case "bind_mesh":
            guard let artwork = Self.uuid(a["artwork"]),
                  let art = e.project.layers.first(where: { $0.id == artwork }), !art.isLocked else {
                return Self.need("valid unlocked artwork")
            }
            e.select(artwork)
            if let detail = (a["detail"] as? NSNumber)?.doubleValue { e.boneMeshDetail = max(4, min(128, detail)) }
            if let radius = (a["radius"] as? NSNumber)?.doubleValue { e.meshInfluenceRadius = max(2, min(3000, radius)) }
            if let coverage = a["coverage"] as? String {
                e.boneMeshCoverage = coverage == "whole" ? .wholeArtwork : .localized
            }
            e.bindBoneMesh()
            let bound = e.project.layers.first(where: { $0.id == artwork })?.boneMesh
            guard let mesh = bound else { return .json(["error": "bind failed; create bones or attach artwork first"], status: 409) }
            return .json(["ok": true, "vertices": mesh.vertices.count, "influences": mesh.boneIDs.count])
        case "unbind_mesh":
            guard let artwork = Self.uuid(a["artwork"]) else { return Self.need("artwork") }
            e.select(artwork)
            e.unbindBoneMesh()
            return .json(["ok": true])
        case "paint_weights":
            guard let artwork = Self.uuid(a["artwork"]), let influence = Self.uuid(a["bone"]),
                  let rawDabs = a["dabs"] as? [[String: Any]], !rawDabs.isEmpty, rawDabs.count <= 512,
                  e.project.layers.first(where: { $0.id == artwork })?.boneMesh?.boneIDs.contains(influence) == true else {
                return Self.need("artwork, bone in bound mesh, dabs <= 512")
            }
            let dabs = rawDabs.compactMap { item -> BoneWeightDab? in
                guard let center = aiPoint(item["center"]),
                      let n = item["amount"] as? NSNumber, n.doubleValue.isFinite else { return nil }
                return BoneWeightDab(center: center, amount: max(0, min(1, n.doubleValue)))
            }
            guard dabs.count == rawDabs.count else { return Self.need("dabs [{center:[x,y], amount:0..1}]") }
            e.select(artwork); e.beginBoneWeights()
            e.boneWeightBoneID = influence
            let brush = (a["brush"] as? String ?? "paint").lowercased()
            e.boneWeightBrush = brush == "erase" ? .erase : brush == "smooth" ? .smooth : .paint
            if let radius = (a["radius"] as? NSNumber)?.doubleValue { e.boneWeightRadius = max(2, min(1000, radius)) }
            if let hardness = (a["hardness"] as? NSNumber)?.doubleValue { e.boneWeightHardness = max(0, min(95, hardness)) }
            let changed = e.paintBoneWeights(dabs, beginStroke: true)
            e.finishBoneWeightStroke(commit: changed); e.finishBoneWeights()
            return .json(["ok": changed, "dabs": dabs.count])
        case "set_deform_amount":
            guard let artwork = Self.uuid(a["artwork"]),
                  let n = a["amount"] as? NSNumber, n.doubleValue.isFinite,
                  e.project.layers.first(where: { $0.id == artwork })?.boneMesh != nil else {
                return Self.need("bound artwork, amount 0..1")
            }
            let amount = max(0, min(1, n.doubleValue))
            e.mutate("AI Set Deformation") { p in
                if let index = p.layers.firstIndex(where: { $0.id == artwork }) {
                    p.layers[index].boneMesh?.amount = amount
                }
            }
            return .json(["ok": true, "amount": amount])
        case "make_chain_ik":
            guard let names = a["joints"] as? [String], names.count >= 2,
                  names.count <= 128 else { return Self.need("joints (2..128 bone ids)") }
            let ids = names.compactMap(UUID.init(uuidString:))
            guard ids.count == names.count else { return Self.need("valid joint UUIDs") }
            e.makeChainIK(ids, controller: Self.uuid(a["controller"]), endArtwork: Self.uuid(a["endArtwork"]))
            return .json(["ok": true])
        case "remove_ik":
            guard let id = Self.uuid(a["layer"]) else { return Self.need("layer") }
            e.select(id); e.removeIK()
            return .json(["ok": true])
        default:
            return .json(["error": "unknown rig command", "command": command], status: 404)
        }
    }
}
