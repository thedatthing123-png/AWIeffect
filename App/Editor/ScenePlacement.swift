import Foundation
import simd

extension EditorState {
    /// Change depth while optionally keeping the projected anchor and plane size at the playhead.
    func setSceneDepth(_ depth: Double, for id: UUID, keepFraming: Bool) {
        guard depth.isFinite else { return }
        let time = currentTime
        mutate("Layer Depth") { project in
            guard let i = project.layers.firstIndex(where: { $0.id == id }), !project.layers[i].isLocked else { return }
            let original = project.layers[i]
            if keepFraming {
                let posed = Renderer.resolveParenting(project, time: time)
                let camera = Renderer.activeCamera(posed, time: time)
                guard let world = posed.layers.first(where: { $0.id == id }) else { return }
                let anchor = world.transform.anchor.value(at: time)
                let M = Renderer.placementMatrix(world, camera: camera, time: time, renderScale: 1)
                guard let screen = LayerPlacement.projected(anchor, by: M) else { return }
                let origin = camera.world.columns.3
                let ray = camera.world * SIMD4((screen.x - camera.center.x) / camera.zoom,
                                               (screen.y - camera.center.y) / camera.zoom, 1, 0)
                guard abs(ray.z) > 1e-9 else { return }
                let parent = original.parentID
                let targetZ = depth + Renderer.chainZ(parent, in: project, time: time)
                let distance = (targetZ - origin.z) / ray.z
                guard distance.isFinite, distance >= max(1, abs(camera.zoom) * 0.01) else { return }
                let target = origin + ray * distance
                let offsets = Renderer.transformOffsets(world, time: time)
                var position = Vec2(target.x - offsets.dx, target.y - offsets.dy)
                if let parent, let frame = Renderer.parentAffine(parent, in: project, time: time) {
                    guard abs(frame.m.determinant) > 1e-9 else { return }
                    let local = frame.m.inverse * SIMD3(position.x, position.y, 1)
                    position = Vec2(local.x, local.y)
                }
                var candidate = world
                candidate.is3D = true
                candidate.transform.position = Animated(Vec2(target.x - offsets.dx, target.y - offsets.dy))
                candidate.transform.positionZ = Animated(targetZ)
                let ratio: Double
                if world.is3D {
                    ratio = distance / Renderer.layerDepth(world, camera: camera, time: time)
                } else {
                    let oldSize = Renderer.pixelsPerLocal(M, at: anchor)
                    let newSize = Renderer.pixelsPerLocal(Renderer.placementMatrix(candidate, camera: camera, time: time, renderScale: 1), at: anchor)
                    ratio = oldSize / newSize
                }
                guard ratio.isFinite, (0.0001...10000).contains(ratio), position.x.isFinite, position.y.isFinite else { return }
                project.layers[i].transform.position.set(position, at: time)
                project.layers[i].transform.scale.set(original.transform.scale.value(at: time) * ratio, at: time)
            }
            project.layers[i].is3D = true
            project.layers[i].transform.positionZ.set(depth, at: time)
            project.layers[i].transform.pairPositionKeys(previous: original.transform, at: time)
        }
    }

    /// Add an eased move to the current shot camera with its existing lens and world orientation.
    func keySceneCameraMove(push: Double, duration: Double, drift: Double, roll: Double) {
        guard let camera = activeCameraLayer, Self.cameraIs3D(camera), !camera.isLocked,
              push.isFinite, duration.isFinite, drift.isFinite, roll.isFinite else { return }
        let start = currentTime
        let end = project.snapToFrame(start + max(project.frameDuration, duration))
        guard end > start, end <= camera.outPoint - project.frameDuration + 1e-6 else { return }
        let t = camera.transform
        let turn = CameraState.rotation(x: t.rotationX.value(at: start), y: t.rotationY.value(at: start), z: t.rotation.value(at: start))
        let zoom = camera.camera?.zoom.value(at: start) ?? CameraState.defaultZoom(project)
        let delta = turn * SIMD4(Double(project.width) * drift, -Double(project.height) * drift * 0.66, zoom * push, 0)
        let from = t.position.value(at: start)
        let fromZ = t.positionZ.value(at: start)
        let fromRoll = t.rotation.value(at: start)
        mutate("Key Camera Move") { p in
            guard let index = p.layers.firstIndex(where: { $0.id == camera.id }) else { return }
            func key<V: Interpolatable>(_ track: inout Animated<V>, from a: V, to b: V) {
                if !track.hasKeyframe(at: start) {
                    track.insertKeyframe(Keyframe(time: start, value: a, interpolation: .bezier))
                }
                track.insertKeyframe(Keyframe(time: end, value: b, interpolation: .bezier))
            }
            var xy = Vec2(delta.x, delta.y)
            if let parent = camera.parentID, let frame = Renderer.parentAffine(parent, in: p, time: start),
               abs(frame.m.determinant) > 1e-9 {
                let local = frame.m.inverse * SIMD3(delta.x, delta.y, 0)
                xy = Vec2(local.x, local.y)
            }
            var transform = p.layers[index].transform
            key(&transform.position, from: from, to: from + xy)
            key(&transform.positionZ, from: fromZ, to: fromZ + delta.z)
            key(&transform.rotation, from: fromRoll, to: fromRoll + roll)
            p.layers[index].transform = transform
        }
        cameraView = true
    }

    /// Aim a selected spotlight or sun at the selected artwork's actual depth plane.
    func pickLightAim() {
        guard let lightID = selectedLayerID else { return }
        beginLayerPick(returnTo: .threeD, prompt: "Tap the layer to light") { [weak self] id in
            guard let self, let id, id != lightID else { return }
            let time = self.currentTime
            let posed = Renderer.resolveParenting(self.project, time: time)
            guard let light = posed.layers.first(where: { $0.id == lightID }),
                  let target = posed.layers.first(where: { $0.id == id }), EditorState.isLightingArtwork(target) else { return }
            let from = light.transform.position.value(at: time), to = target.transform.position.value(at: time)
            let fromZ = light.transform.positionZ.value(at: time), toZ = target.transform.positionZ.value(at: time)
            guard let angle = Aim.angles(from: SIMD3(from.x, from.y, fromZ), to: SIMD3(to.x, to.y, toZ),
                                         rotationZ: light.transform.rotation.value(at: time)) else { return }
            self.mutate("Aim Light at \(target.name)") { project in
                guard let i = project.layers.firstIndex(where: { $0.id == lightID }), !project.layers[i].isLocked else { return }
                project.layers[i].transform.rotationX.set(angle.x, at: time)
                project.layers[i].transform.rotationY.set(angle.y, at: time)
            }
        }
    }
}
