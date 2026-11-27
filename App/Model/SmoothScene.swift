import Foundation

enum SmoothScene {
    private static let effectTracks: [String: [String]] = [
        "awi.shake": ["amplitude", "rotation", "zoom"],
        "awi18.shakePro": ["amount", "rotation", "zoom"],
        "awi18.transform": ["x", "y", "scale", "rotation"],
        "ae.waveWarp": ["height", "width", "phase", "direction"],
        "ae.turbulentDisplace": ["amount", "evolution", "offsetX", "offsetY"],
        "awi20.fractalWarp": ["magnitude", "position", "parallax"],
        "awi.shapedLightSweep": ["center", "width", "angle", "intensity"]
    ]

    static func applying(to source: Project, at time: Double) -> Project {
        guard source.layers.contains(where: {
            ($0.content == .adjustment || $0.content == .camera) && ($0.smoothSceneStrength ?? 0) > 0
        }) else { return source }

        let layers = source.layers
        let edge = 2 / max(1, source.fps)
        let anySolo = layers.contains(where: \.isSolo)
        func strength(_ layer: Layer, start: Double, end: Double) -> Double {
            let amount = (layer.smoothSceneStrength ?? 0) / 100
            guard amount.isFinite, amount > 0 else { return 0 }
            let x = min(1, max(0, min(time - start, end - time) / edge))
            return min(amount, 1) * x * x * (3 - 2 * x)
        }

        let cameraIndex = layers.firstIndex { $0.content == .camera && $0.isActive(at: time) }
        var cameraStrength = 0.0
        if let index = cameraIndex {
            let camera = layers[index]
            var start = camera.inPoint, end = camera.outPoint
            for higher in layers[..<index] where higher.content == .camera && higher.isVisible {
                if higher.outPoint <= time { start = max(start, higher.outPoint) }
                if higher.inPoint > time { end = min(end, higher.inPoint) }
            }
            cameraStrength = strength(camera, start: start, end: end)
        }

        // Walk the timeline in stack order. Each group has its own adjustment stack.
        var adjustmentByGroup: [UUID?: Double] = [:]
        var localAdjustment: [UUID: Double] = [:]
        for layer in layers {
            localAdjustment[layer.id] = adjustmentByGroup[layer.groupID, default: 0]
            if layer.content == .adjustment && layer.isActive(at: time) && (!anySolo || layer.isSolo) {
                let value = strength(layer, start: layer.inPoint, end: layer.outPoint)
                adjustmentByGroup[layer.groupID, default: 0] = max(value, adjustmentByGroup[layer.groupID, default: 0])
            }
        }

        let camera = cameraIndex.map { layers[$0] }
        let groupParents = Dictionary(layers.compactMap { layer in layer.groupID.map { (layer.id, $0) } },
                                      uniquingKeysWith: { first, _ in first })
        var amountByID: [UUID: Double] = [:]
        for layer in layers {
            if layer.content == .camera {
                amountByID[layer.id] = camera?.id == layer.id ? cameraStrength : 0
                continue
            }
            guard !layer.isAudioOnly, layer.content != .light, layer.content != .adjustment else { continue }
            var amount = localAdjustment[layer.id, default: 0]
            var parent = layer.groupID
            var seen = Set<UUID>()
            while let id = parent, seen.insert(id).inserted {
                amount = max(amount, localAdjustment[id, default: 0])
                parent = groupParents[id]
            }
            if camera?.camera?.affects2D == true || (layer.is3D || layer.content == .model || layer.text?.text3D != nil) {
                amount = max(amount, cameraStrength)
            }
            amountByID[layer.id] = amount
        }

        // A linked child outside the scope must not inherit smoothed motion from a shared parent.
        // Cap the common parent's strength at the smallest strength among its linked dependents.
        let parentByID = Dictionary(layers.compactMap { layer in layer.parentID.map { (layer.id, $0) } },
                                    uniquingKeysWith: { first, _ in first })
        for layer in layers {
            let limit = amountByID[layer.id, default: 0]
            var parent = layer.parentID
            while let id = parent, amountByID[id, default: 0] > limit {
                amountByID[id] = limit
                parent = parentByID[id]
            }
        }

        var project = source
        for index in layers.indices {
            let amount = amountByID[layers[index].id, default: 0]
            guard amount > 0 else { continue }
            apply(amount, time: time, to: &project.layers[index])
        }
        return project
    }

    private static func apply(_ amount: Double, time: Double, to layer: inout Layer) {
        func smooth<T>(_ track: inout Animated<T>) {
            guard track.keyframes.count > 1, !track.hasActiveExpression else { return }
            track.sceneSmoothing = amount
        }
        smooth(&layer.transform.position)
        smooth(&layer.transform.anchor)
        smooth(&layer.transform.positionZ)
        smooth(&layer.transform.scale)
        smooth(&layer.transform.rotation)
        smooth(&layer.transform.rotationX)
        smooth(&layer.transform.rotationY)
        if var options = layer.camera {
            smooth(&options.zoom)
            layer.camera = options
        }
        for index in layer.effects.indices where layer.effects[index].isEnabled {
            let effect = layer.effects[index]
            guard let keys = effectTracks[effect.typeID] else { continue }
            if effect.typeID == "awi.shake" ||
                (effect.typeID == "awi18.shakePro" && effect.choice("mode") == 0 && effect.number("hold", time) < 1) {
                layer.effects[index].sceneSmoothing = amount
            }
            for key in keys {
                switch effect.params[key] {
                case .number(var track):
                    smooth(&track)
                    layer.effects[index].params[key] = .number(track)
                case .point(var track):
                    smooth(&track)
                    layer.effects[index].params[key] = .point(track)
                default:
                    break
                }
            }
        }
    }
}
