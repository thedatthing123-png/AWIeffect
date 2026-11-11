import Foundation
import UIKit

/// Native operations for the AI Link editor. Never exposes relay settings, pairing keys,
/// Settings UI or storage. All mutations run through EditorState's existing undo machinery.
extension AILink {
    func handleAdvanced(_ r: HTTPRequest) -> HTTPResponse? {
        if r.method == "GET" && r.path == "/editor/capabilities" {
            return .json([
                "version": 1,
                "rigCommands": ["inspect", "add_bone", "select_bone", "reparent_bone",
                                "delete_bone", "move_rest_joint", "pose_bone",
                                "bind_mesh", "unbind_mesh", "paint_weights",
                                "make_chain_ik", "remove_ik", "set_deform_amount"],
                "groupCommands": ["create","ungroup","duplicate"],
                "artStudioCommands": ["draw_strokes", "edit_drawing_layer", "draw_operations"],
                "layerPatchFields": Self.aiPatchFields.sorted(),
                "restrictions": ["App settings and relay keys are unavailable",
                                 "Existing project and media IDs must be preserved",
                                 "Use app-native rig commands instead of modifying bone JSON by hand"]
            ])
        }
        let a = ((try? JSONSerialization.jsonObject(with: r.body)) as? [String: Any]) ?? [:]
        switch (r.method, r.path) {
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
