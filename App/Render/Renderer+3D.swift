import Foundation
import simd

/// AE-style 2.5D: 3D layers are planes in a world seen through the active camera.
/// Coordinates follow AE: x right, y down, z away from the viewer; the default camera sits at
/// (comp center, −zoom) looking down +z, so a layer at z = 0 shows at 100% size.
struct CameraState {
    var world: simd_double4x4       // camera -> world
    var zoom: Double
    var center: SIMD2<Double>       // comp center (principal point)
    var options: CameraOptions?
    /// 2D camera (comp px -> comp px) applied to 2D layers; identity when the camera is 3D-only.
    var view2D = matrix_identity_double3x3

    var view: simd_double4x4 { world.inverse }

    static func defaultCamera(for p: Project) -> CameraState {
        let zoom = defaultZoom(p)
        let c = SIMD2(Double(p.width) / 2, Double(p.height) / 2)
        return CameraState(world: translation(SIMD3(c.x, c.y, -zoom)), zoom: zoom, center: c, options: nil)
    }

    /// AE's default 50 mm-equivalent camera ≈ zoom of comp width × 1.37 (close enough for layout).
    static func defaultZoom(_ p: Project) -> Double { Double(p.width) * 1.3733 }

    static func translation(_ t: SIMD3<Double>) -> simd_double4x4 {
        simd_double4x4(columns: (SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(t.x, t.y, t.z, 1)))
    }

    static func rotation(x: Double, y: Double, z: Double) -> simd_double4x4 {
        let rx = x * .pi / 180, ry = y * .pi / 180, rz = z * .pi / 180
        let X = simd_double4x4(columns: (SIMD4(1, 0, 0, 0), SIMD4(0, cos(rx), sin(rx), 0), SIMD4(0, -sin(rx), cos(rx), 0), SIMD4(0, 0, 0, 1)))
        let Y = simd_double4x4(columns: (SIMD4(cos(ry), 0, -sin(ry), 0), SIMD4(0, 1, 0, 0), SIMD4(sin(ry), 0, cos(ry), 0), SIMD4(0, 0, 0, 1)))
        let Z = simd_double4x4(columns: (SIMD4(cos(rz), sin(rz), 0, 0), SIMD4(-sin(rz), cos(rz), 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, 0, 0, 1)))
        // AE applies X, then Y, then Z rotation.
        return Z * Y * X
    }
}

extension Renderer {
    /// Topmost active camera layer, else AE's default camera.
    static func activeCamera(_ p: Project, time: Double) -> CameraState {
        guard let cam = p.layers.first(where: { $0.content == .camera && $0.isActive(at: time) }) else {
            return .defaultCamera(for: p)
        }
        let t = cam.transform
        let pos = t.position.value(at: time)
        let opts = cam.camera ?? CameraOptions()
        let world = CameraState.translation(SIMD3(pos.x, pos.y, t.positionZ.value(at: time)))
            * CameraState.rotation(x: t.rotationX.value(at: time), y: t.rotationY.value(at: time), z: t.rotation.value(at: time))
        var state = CameraState(world: world, zoom: opts.zoom.value(at: time),
                                center: SIMD2(Double(p.width) / 2, Double(p.height) / 2), options: opts)
        if opts.affects2D { state.view2D = view2D(cam, project: p, time: time) }
        return state
    }

    /// Scene transform of a 2D camera: what the camera sees fills the frame (move right = scene slides left,
    /// scale up = zoom in, rotate = scene turns the other way). Shakes on the camera layer shake the scene.
    static func view2D(_ cam: Layer, project p: Project, time: Double) -> simd_double3x3 {
        let fx = transformOffsets(cam, time: time)
        let pos = cam.transform.position.value(at: time) + Vec2(fx.dx, fx.dy)
        let sc = cam.transform.scale.value(at: time) * fx.ds / 100
        let r = -(cam.transform.rotation.value(at: time) + fx.dr) * .pi / 180
        let cx = Double(p.width) / 2, cy = Double(p.height) / 2
        guard pos.x.isFinite, pos.y.isFinite, sc.x.isFinite, sc.y.isFinite, r.isFinite, abs(sc.x) > 1e-4, abs(sc.y) > 1e-4 else { return matrix_identity_double3x3 }
        let toCenter = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(cx, cy, 1)))
        let scale = simd_double3x3(diagonal: SIMD3(sc.x, sc.y, 1))
        let rot = simd_double3x3(columns: (SIMD3(cos(r), sin(r), 0), SIMD3(-sin(r), cos(r), 0), SIMD3(0, 0, 1)))
        let fromCam = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-pos.x, -pos.y, 1)))
        return toCenter * scale * rot * fromCam
    }

    /// Layer-local -> world (4x4), including AE anchor, scale, 3D rotation and Z position.
    static func layerWorld(_ layer: Layer, time: Double) -> simd_double4x4 {
        let t = layer.transform
        let fx = transformOffsets(layer, time: time)
        let pos = t.position.value(at: time) + Vec2(fx.dx, fx.dy)
        let anc = t.anchor.value(at: time)
        let sc = t.scale.value(at: time) * fx.ds
        let T = CameraState.translation(SIMD3(pos.x, pos.y, t.positionZ.value(at: time)))
        let R = CameraState.rotation(x: t.rotationX.value(at: time), y: t.rotationY.value(at: time), z: t.rotation.value(at: time) + fx.dr)
        let S = simd_double4x4(diagonal: SIMD4(sc.x / 100, sc.y / 100, 1, 1))
        let A = CameraState.translation(SIMD3(-anc.x, -anc.y, 0))
        return T * R * S * A
    }

    /// Homography mapping the layer plane (local x, y) to comp pixels at `renderScale`.
    static func layerHomography(_ layer: Layer, camera: CameraState, time: Double, renderScale: Double, localZ: Double = 0) -> simd_double3x3 {
        var MV: simd_double4x4 = camera.view * layerWorld(layer, time: time)
        // A plane pushed `localZ` along the layer's own normal (extrusion slices).
        if localZ != 0 { MV.columns.3 += MV.columns.2 * localZ }
        // Pinhole projection: [zoom*x + cx*z, zoom*y + cy*z, z], applied to the columns for local x, y and origin
        // (local z = 0 drops the third column).
        let f: Double = camera.zoom * renderScale
        let cx: Double = camera.center.x * renderScale
        let cy: Double = camera.center.y * renderScale
        func project(_ c: SIMD4<Double>) -> SIMD3<Double> {
            let x: Double = f * c.x + cx * c.z
            let y: Double = f * c.y + cy * c.z
            return SIMD3(x, y, c.z)
        }
        return simd_double3x3(columns: (project(MV.columns.0), project(MV.columns.1), project(MV.columns.3)))
    }

    /// Camera-space depth of the layer's anchor (for back-to-front sorting and depth of field).
    static func layerDepth(_ layer: Layer, camera: CameraState, time: Double) -> Double {
        let p = camera.view * layerWorld(layer, time: time) * SIMD4(layer.transform.anchor.value(at: time).x,
                                                                     layer.transform.anchor.value(at: time).y, 0, 1)
        return p.z
    }

    /// Local -> target matrix for any layer (homography for 3D layers, affine otherwise).
    static func placementMatrix(_ layer: Layer, camera: CameraState, time: Double, renderScale: Double) -> simd_double3x3 {
        if layer.is3D { return layerHomography(layer, camera: camera, time: time, renderScale: renderScale) }
        let m = layerMatrix(layer, time: time, renderScale: renderScale)
        guard camera.view2D != matrix_identity_double3x3, layer.content != .camera else { return m }
        // view2D works in comp px; layerMatrix already includes the render scale.
        let s = simd_double3x3(diagonal: SIMD3(renderScale, renderScale, 1))
        let si = simd_double3x3(diagonal: SIMD3(1 / max(renderScale, 1e-9), 1 / max(renderScale, 1e-9), 1))
        return s * camera.view2D * si * m
    }

    /// Target pixels per local pixel near the layer's anchor (projective-aware).
    static func pixelsPerLocal(_ M: simd_double3x3, at p: Vec2) -> Double {
        func proj(_ x: Double, _ y: Double) -> SIMD2<Double> {
            let q = M * SIMD3(x, y, 1)
            return SIMD2(q.x, q.y) / max(q.z, 1e-6)
        }
        let o = proj(p.x, p.y), dx = proj(p.x + 1, p.y) - o, dy = proj(p.x, p.y + 1) - o
        return max(1e-4, min(simd_length(dx), simd_length(dy)))
    }

    /// AE draw order: 2D layers keep stacking order; each run of adjacent 3D layers is sorted back-to-front.
    static func drawOrder(_ layers: [Layer], camera: CameraState, time: Double) -> [Layer] {
        var out: [Layer] = []
        var run: [Layer] = []
        func flush() {
            out += run.sorted { layerDepth($0, camera: camera, time: time) > layerDepth($1, camera: camera, time: time) }
            run.removeAll()
        }
        for l in layers.reversed() {   // bottom-up
            if l.is3D { run.append(l) } else { flush(); out.append(l) }
        }
        flush()
        return out
    }

    /// Depth-of-field blur sigma (comp px) for a 3D layer.
    static func dofSigma(_ layer: Layer, camera: CameraState, time: Double) -> Double {
        guard layer.is3D, let o = camera.options, o.depthOfField else { return 0 }
        let z = layerDepth(layer, camera: camera, time: time)
        guard z > 1 else { return 0 }
        let f = o.focusDistance.value(at: time)
        return o.aperture.value(at: time) * abs(z - f) / z * o.blurLevel.value(at: time) / 100 * 0.5
    }
}
