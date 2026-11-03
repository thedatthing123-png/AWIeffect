import Foundation
import simd

/// Projection shared by dragging and alignment: position values remain in their parent's space.
enum LayerPlacement {
    static func snap(features: [Double], targets: [Double], held: Double?, grab: Double) -> (delta: Double, guide: Double?) {
        if let held, let feature = features.min(by: { abs($0 - held) < abs($1 - held) }), abs(feature - held) < grab * 2.2 {
            return (held - feature, held)
        }
        var best = grab, result: (Double, Double?) = (0, nil)
        for feature in features { for target in targets {
            let d = target - feature
            if abs(d) < best { best = abs(d); result = (d, target) }
        } }
        return result
    }
    static func projected(_ point: Vec2, by matrix: simd_double3x3) -> Vec2? {
        let q = matrix * SIMD3(point.x, point.y, 1)
        guard q.x.isFinite, q.y.isFinite, q.z.isFinite, abs(q.z) > 1e-8 else { return nil }
        return Vec2(q.x / q.z, q.y / q.z)
    }
    static func positionMatrix(_ layer: Layer, project: Project, time: Double) -> simd_double3x3 {
        let resolved = Renderer.resolveParenting(project, time: time)
        let world = resolved.layers.first(where: { $0.id == layer.id }) ?? layer
        let camera = Renderer.activeCamera(resolved, time: time)
        let parent = layer.parentID.flatMap { Renderer.parentAffine($0, in: project, time: time)?.m } ?? matrix_identity_double3x3
        if !layer.is3D {
            let depth = world.transform.positionZ.value(at: time) - camera.world.columns.3.z
            let factor = camera.projects2DDepth ? max(1e-4, camera.zoom / max(max(1, abs(camera.zoom) * 0.01), depth)) : 1
            let c = camera.center
            let projection = simd_double3x3(columns: (SIMD3(factor, 0, 0), SIMD3(0, factor, 0), SIMD3(c.x * (1 - factor), c.y * (1 - factor), 1)))
            return projection * camera.view2D * parent
        }
        let plane = simd_double4x4(columns: (SIMD4(parent[0].x, parent[0].y, 0, 0), SIMD4(parent[1].x, parent[1].y, 0, 0),
                                          SIMD4(0, 0, 1, 0), SIMD4(parent[2].x, parent[2].y, world.transform.positionZ.value(at: time), 1)))
        let view = camera.view * plane
        func projectColumn(_ v: SIMD4<Double>) -> SIMD3<Double> { SIMD3(camera.zoom * v.x + camera.center.x * v.z, camera.zoom * v.y + camera.center.y * v.z, v.z) }
        return simd_double3x3(columns: (projectColumn(view[0]), projectColumn(view[1]), projectColumn(view[3])))
    }
    static func bounds(_ layer: Layer, project: Project, time: Double) -> CGRect? {
        let resolved = Renderer.resolveParenting(project, time: time)
        let world = resolved.layers.first(where: { $0.id == layer.id }) ?? layer
        let matrix = Renderer.placementMatrix(world, camera: Renderer.activeCamera(resolved, time: time), time: time, renderScale: 1)
        let hs = Renderer.layerHalfSize(world, time: time)
        let points = [Vec2(-hs.x, -hs.y), Vec2(hs.x, -hs.y), Vec2(hs.x, hs.y), Vec2(-hs.x, hs.y)].compactMap { projected($0, by: matrix) }
        guard points.count == 4 else { return nil }
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
    static func movedPosition(_ layer: Layer, project: Project, time: Double, screenDelta: Vec2) -> Vec2? {
        let matrix = positionMatrix(layer, project: project, time: time)
        guard abs(matrix.determinant) > 1e-10, let anchor = projected(layer.transform.position.value(at: time), by: matrix) else { return nil }
        return projected(anchor + screenDelta, by: matrix.inverse)
    }
}

extension EditorState {
    func snapPositionOnCanvas(_ position: Vec2, layer: Layer) -> Vec2 {
        guard snappingEnabled, !layer.is3D else { return position }
        var p = live.project ?? project
        guard let i = p.layers.firstIndex(where: { $0.id == layer.id }) else { return position }
        p.layers[i].transform.position.set(position, at: currentTime)
        let matrix = LayerPlacement.positionMatrix(p.layers[i], project: p, time: currentTime)
        guard abs(matrix.determinant) > 1e-10,
              let anchor = LayerPlacement.projected(position, by: matrix),
              let rect = LayerPlacement.bounds(p.layers[i], project: p, time: currentTime) else { return position }
        var xs = [0.0, Double(p.width) / 2, Double(p.width)], ys = [0.0, Double(p.height) / 2, Double(p.height)]
        for other in p.layers where other.id != layer.id && other.isActive(at: currentTime) && other.content != .camera && !other.isAudioOnly {
            if let bounds = LayerPlacement.bounds(other, project: p, time: currentTime) {
                xs += [bounds.minX, bounds.midX, bounds.maxX]; ys += [bounds.minY, bounds.midY, bounds.maxY]
            }
        }
        let grab = Double(p.width) * 0.005
        let sx = LayerPlacement.snap(features: [rect.minX, rect.midX, rect.maxX], targets: xs, held: snapGuides.x, grab: grab)
        let sy = LayerPlacement.snap(features: [rect.minY, rect.midY, rect.maxY], targets: ys, held: snapGuides.y, grab: grab)
        snapGuides = SnapGuides(x: sx.guide, y: sy.guide)
        return LayerPlacement.projected(anchor + Vec2(sx.delta, sy.delta), by: matrix.inverse) ?? position
    }

    func alignSelected(_ mode: Int) {
        let ids = multiSelection ?? selectedLayerID.map { Set([$0]) } ?? []
        let original = project, time = currentTime
        mutate("Align to Canvas") { project in
            for i in project.layers.indices where ids.contains(project.layers[i].id) && !project.layers[i].isLocked {
                let layer = project.layers[i]
                guard let rect = LayerPlacement.bounds(layer, project: original, time: time) else { continue }
                var delta = Vec2.zero
                switch mode {
                case 0: delta.x = -rect.minX
                case 1: delta.x = Double(project.width) / 2 - rect.midX
                case 2: delta.x = Double(project.width) - rect.maxX
                case 3: delta.y = -rect.minY
                case 4: delta.y = Double(project.height) / 2 - rect.midY
                default: delta.y = Double(project.height) - rect.maxY
                }
                if let value = LayerPlacement.movedPosition(layer, project: original, time: time, screenDelta: delta) {
                    project.layers[i].transform.position.set(value, at: time)
                }
            }
        }
    }
}
