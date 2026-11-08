import Foundation
import UIKit

/// Additive AI Link controls. These use existing editor operations or validated Codable edits.
/// No rendering, UI, media format, or project persistence implementation is changed here.
extension AILink {
    func handleAdvanced(_ r: HTTPRequest, editor e: EditorState) -> HTTPResponse? {
        let a = ((try? JSONSerialization.jsonObject(with: r.body)) as? [String: Any]) ?? [:]
        switch (r.method, r.path) {
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
