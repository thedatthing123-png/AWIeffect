import Foundation
import SwiftUI
import UIKit
import simd

/// The remote Art Studio bridge uses the SAME Metal DrawEngine as the phone UI.
/// Rebuilds the linked drawing document per command, then persists once per operation.
/// App/account Settings and relay keys are deliberately inaccessible.
extension AILink {
    func handleArtStudio(_ r: HTTPRequest) -> HTTPResponse? {
        guard r.method == "POST",
              ["/draw/strokes", "/draw/layer", "/draw/operations"].contains(r.path) else { return nil }
        guard UIApplication.shared.applicationState == .active else {
            return .json(["error": "Keep AWIeffect in the foreground while using Art Studio"], status: 409)
        }
        guard let e = editor else { return .noProject }
        guard let a = (try? JSONSerialization.jsonObject(with: r.body)) as? [String: Any] else {
            return .json(["error": "Expected a JSON object"], status: 400)
        }
        let existing = Self.uuid(a["layer"])
        let layer = existing.flatMap { id in e.project.layers.first { $0.id == id } }
        if existing != nil && layer == nil {
            return .json(["error": "Drawing layer not found"], status: 404)
        }
        if let layer, (layer.isLocked || layer.isGroup || layer.isAudioOnly) {
            return .json(["error": "This layer cannot be edited in Art Studio"], status: 409)
        }
        guard let draw = e.makeDrawEngine(editing: layer) else {
            return .json(["error": "Metal DrawEngine could not initialize"], status: 503)
        }
        switch r.path {
        case "/draw/strokes":
            guard let strokes = a["strokes"] as? [[String: Any]], !strokes.isEmpty, strokes.count <= 100 else {
                return Self.need("strokes (1..100)")
            }
            let total = strokes.reduce(0) { $0 + (($1["points"] as? [Any])?.count ?? 0) }
            guard total > 0 && total <= 8000 else {
                return .json(["error": "Use 1..8000 points per call"], status: 400)
            }
            if let brush = a["brush"] as? String {
                guard let kind = BrushKind(rawValue: brush) else {
                    return .json(["error": "Unknown brush; use pen, pencil, marker, airbrush, ink, flat, spray, glow, watercolor, charcoal, screentone or eraser"], status: 400)
                }
                draw.brush.kind = kind
            }
            if let size = (a["size"] as? NSNumber)?.doubleValue, size.isFinite {
                draw.brush.size = max(0.5, min(1000, size))
            }
            if let opacity = (a["opacity"] as? NSNumber)?.doubleValue, opacity.isFinite {
                draw.brush.opacity = max(0, min(1, opacity))
            }
            if let color = Self.color(a["color"]) { draw.brush.color = color }
            var authored = 0
            for stroke in strokes {
                guard let points = stroke["points"] as? [[NSNumber]], !points.isEmpty else {
                    return .json(["error": "Every stroke requires points [[x,y,pressure?],...]"], status: 400)
                }
                var coords: [(SIMD2<Double>,Double)] = []
                for p in points {
                    guard (2...3).contains(p.count) else { return Self.need("points with 2 or 3 values") }
                    let x=p[0].doubleValue, y=p[1].doubleValue
                    let pressure = p.count == 3 ? p[2].doubleValue : 1
                    guard x.isFinite, y.isFinite, pressure.isFinite,
                          abs(x) < 100000, abs(y) < 100000 else { return Self.need("finite stroke coordinates") }
                    coords.append((SIMD2(x,y),max(0.01,min(1,pressure))))
                }
                guard let first = coords.first else { continue }
                draw.beginStroke(at: first.0, pressure: first.1)
                for point in coords.dropFirst() { draw.continueStroke(to: point.0, pressure: point.1) }
                draw.endStroke()
                authored += 1
            }
            e.finishDrawing(draw, editing: existing)
            return .json(["ok": true, "strokes": authored,
                          "layer": e.selectedLayerID?.uuidString ?? existing?.uuidString ?? ""])
        case "/draw/layer":
            guard let operation = a["operation"] as? String else { return Self.need("operation") }
            if let i = a["index"] as? Int {
                guard draw.layers.indices.contains(i) else {
                    return .json(["error": "Drawing-layer index is out of range"], status: 400)
                }
                draw.activeIndex = i
            }
            switch operation {
            case "add":
                guard draw.addLayer(name: a["name"] as? String) != nil else {
                    return .json(["error": "Cannot create drawing layer"], status: 500)
                }
            case "duplicate": draw.duplicateActiveLayer()
            case "delete": draw.deleteActiveLayer()
            case "up": draw.moveActiveLayer(up: true)
            case "down": draw.moveActiveLayer(up: false)
            case "set":
                guard let active=draw.activeLayer else { return .json(["error": "No active drawing layer"], status: 409) }
                if let name=a["name"] as? String { active.name=String(name.prefix(120)) }
                if let value=(a["opacity"] as? NSNumber)?.doubleValue, value.isFinite { active.opacity=max(0,min(1,value)) }
                if let raw=a["blend"] as? String {
                    guard let blend=BlendMode(rawValue:raw) else { return .json(["error":"Invalid blend mode"],status:400) }
                    active.blend=blend
                }
                if let value=a["visible"] as? Bool { active.visible=value }
                if let value=a["clipping"] as? Bool { active.clipping=value }
                if let value=a["alphaLock"] as? Bool { active.alphaLock=value }
                draw.touch()
            default:
                return .json(["error": "Unknown drawing-layer operation"], status: 400)
            }
            e.finishDrawing(draw, editing: existing)
            return .json(["ok":true,"layers":draw.layers.map { ["id":$0.id.uuidString,"name":$0.name] },
                          "activeIndex": draw.activeIndex,
                          "layer":e.selectedLayerID?.uuidString ?? existing?.uuidString ?? ""])
        default:
            guard let operations=a["operations"] as? [[String: Any]],
                  !operations.isEmpty, operations.count <= 50 else {
                return Self.need("operations (1..50)")
            }
            func point(_ value: Any?) -> SIMD2<Double>? {
                guard let p=value as? [NSNumber], p.count == 2 else { return nil }
                let x=p[0].doubleValue,y=p[1].doubleValue
                guard x.isFinite,y.isFinite else { return nil }
                return SIMD2(x,y)
            }
            for operation in operations {
                guard let name=operation["name"] as? String else { return Self.need("operation.name") }
                let tolerance=max(0,min(1,(operation["tolerance"] as? NSNumber)?.doubleValue ?? 0.12))
                switch name {
                case "select_wand":
                    guard let p=point(operation["point"]) else { return Self.need("point [x,y]") }
                    draw.selectWand(at:p,tolerance:tolerance)
                case "select_lasso":
                    guard let raw=operation["points"] as? [[NSNumber]], raw.count>=3,raw.count<=500,
                          raw.allSatisfy({ $0.count == 2 && $0[0].doubleValue.isFinite && $0[1].doubleValue.isFinite }) else {
                        return Self.need("lasso points >= 3")
                    }
                    draw.selectLasso(raw.map { SIMD2($0[0].doubleValue,$0[1].doubleValue) })
                case "select_opaque": draw.selectOpaque()
                case "invert_selection": draw.invertSelection()
                case "clear_selection": draw.clearSelection()
                case "delete_selection": draw.deleteSelection()
                case "delete_outside_selection": draw.deleteOutsideSelection()
                case "fill":
                    guard let p=point(operation["point"]) else { return Self.need("point [x,y]") }
                    if let color=Self.color(operation["color"]) { draw.brush.color=color }
                    draw.fill(at:p,tolerance:tolerance)
                case "erase_fill":
                    guard let p=point(operation["point"]) else { return Self.need("point [x,y]") }
                    draw.eraseFill(at:p,tolerance:tolerance,gapClose:0)
                case "clear_active_layer": draw.clearActiveLayer()
                case "flip_horizontal": draw.flipActive(horizontal:true)
                case "flip_vertical": draw.flipActive(horizontal:false)
                case "undo": draw.undo()
                case "redo": draw.redo()
                default: return .json(["error":"Unsupported Art Studio operation","name":name],status:400)
                }
            }
            e.finishDrawing(draw, editing: existing)
            return .json(["ok":true,"operationCount":operations.count,"layer":e.selectedLayerID?.uuidString ?? existing?.uuidString ?? ""])
        }
    }
}
