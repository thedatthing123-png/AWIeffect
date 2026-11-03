import Foundation
import SceneKit
import Metal
import MetalKit
import UIKit

/// Settings for 3D model / extruded 3D text layers.
struct Model3DOptions: Codable, Equatable {
    /// Imported model file (usdz/obj/scn/dae) in the project media folder; nil = 3D text.
    var fileName: String? = nil
    /// Extruded 2D shape outline (layer-local px, y down) — "Make 3D Object" on shape layers.
    var shapePath: BezierPath? = nil
    /// Image / drawing whose alpha silhouette is extruded, with the picture on the front face.
    var imageFile: String? = nil
    var text: String = "AWI"
    var fontName: String = "Helvetica-Bold"
    var extrusion = 30.0
    var chamfer = 4.0
    var color = Animated(RGBA(hex: 0x9B5CFF))
    var metalness = 0.6
    var roughness = 0.3
    var yaw = Animated(-20.0)
    var pitch = Animated(10.0)
    var roll = Animated(0.0)
    /// Degrees per second of automatic Y spin.
    var spin = 0.0
    /// Light angle (degrees) and strength.
    var lightAngle = Animated(35.0)
    var lightIntensity = Animated(1200.0)
}

/// Renders model/3D-text layers offscreen with SceneKit into a texture the compositor places like an image.
final class ModelRenderer {
    static let shared: ModelRenderer? = Renderer.shared.map { ModelRenderer(device: $0.device) }

    private let device: MTLDevice
    private let renderQueue: MTLCommandQueue?
    private var availableRenderers: [SCNRenderer] = []
    private var rendererGeneration = 0
    private struct CachedContent { let node: SCNNode; let front: SCNMaterial?; let radius: Double }
    private var scenes: [String: CachedContent] = [:]
    private let lock = NSLock()

    init(device: MTLDevice) {
        self.device = device
        renderQueue = device.makeCommandQueue()
    }

    func clear() { lock.lock(); scenes.removeAll(); availableRenderers.removeAll(); rendererGeneration += 1; lock.unlock() }

    /// Model content node (cached per file / per text settings).
    private func content(_ o: Model3DOptions, mediaURL: (String) -> URL) -> CachedContent? {
        let key: String
        if let f = o.fileName { key = "file|\(mediaURL(f).path)" }
        else if let p = o.shapePath { key = "shape|\(p.vertices.map { "\($0.point.x),\($0.point.y),\($0.inTangent.x),\($0.inTangent.y),\($0.outTangent.x),\($0.outTangent.y)" }.joined(separator: ";"))|\(o.extrusion)|\(o.chamfer)" }
        else if let f = o.imageFile { key = "image|\(mediaURL(f).path)|\(o.extrusion)|\(o.chamfer)|\(o.roughness)" }
        else { key = "text|\(o.text)|\(o.fontName)|\(o.extrusion)|\(o.chamfer)" }
        if let n = scenes[key] { return n }
        let node: SCNNode
        var front: SCNMaterial?
        if o.shapePath != nil || o.imageFile != nil {
            guard let g = Extrude3D.geometry(o, mediaURL: mediaURL) else { return nil }
            node = SCNNode(geometry: g.geometry)
            front = g.front
            node.name = g.front == nil ? "awiShape" : "awiImage"
        } else if let f = o.fileName {
            guard let scene = try? SCNScene(url: mediaURL(f), options: [.checkConsistency: true]) else { return nil }
            node = SCNNode()
            for c in scene.rootNode.childNodes { node.addChildNode(c) }
        } else {
            let t = SCNText(string: o.text, extrusionDepth: CGFloat(o.extrusion))
            t.font = UIFont(name: o.fontName, size: 100) ?? .boldSystemFont(ofSize: 100)
            t.flatness = 0.2
            t.chamferRadius = CGFloat(o.chamfer)
            node = SCNNode(geometry: t)
        }
        // Center on the pivot and normalize size so every model fits the layer.
        let (lo, hi) = node.boundingBox
        let c = SCNVector3((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2)
        let size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
        let holder = SCNNode()
        node.position = SCNVector3(-c.x, -c.y, -c.z)
        holder.addChildNode(node)
        holder.scale = SCNVector3(2 / max(size, 1e-3), 2 / max(size, 1e-3), 2 / max(size, 1e-3))
        let half = SIMD3(Double(hi.x - lo.x), Double(hi.y - lo.y), Double(hi.z - lo.z)) / Double(max(size, 1e-3))
        let cached = CachedContent(node: holder, front: front, radius: max(0.01, simd_length(half)))
        if scenes.count >= 32 { scenes.removeAll() }
        scenes[key] = cached
        return cached
    }

    static func cameraDistance(radius: Double, aspect: Double, fov: Double = 35) -> Double {
        let vertical = fov * .pi / 360
        let horizontal = atan(tan(vertical) * max(0.01, aspect))
        return max(0.01, radius) / max(0.001, sin(min(vertical, horizontal))) * 1.08
    }

    /// Renders the layer at `time` into a premultiplied BGRA texture of `width`×`height`.
    func render(_ o: Model3DOptions, time: Double, width: Int, height: Int, cb: MTLCommandBuffer, pool: TexturePool? = nil, mediaURL: (String) -> URL) -> MTLTexture? {
        lock.lock(); defer { lock.unlock() }
        guard width > 0, height > 0, width <= TexturePool.maxSide, height <= TexturePool.maxSide,
              let cached = content(o, mediaURL: mediaURL) else { return nil }
        let model = cached.node.clone()
        // Never reuse a render target within a command buffer: motion samples and different layers
        // must retain independent pictures. A per-frame pool reuses storage only after GPU completion.
        let target: MTLTexture
        if let pool { target = pool.acquire(width: width, height: height, format: .bgra8Unorm) }
        else {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]
            guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
            target = texture
        }

        // SceneKit finalizes frame resources per submitted command buffer. Finish the isolated
        // model pass before the caller encodes sampling it; a bounded wait prevents a hung GPU
        // from holding the editor forever, and completion callbacks never acquire this lock.
        guard let modelBuffer = renderQueue?.makeCommandBuffer() else { return nil }
        let reusedRenderer = availableRenderers.popLast()
        let renderer = reusedRenderer ?? SCNRenderer(device: device, options: nil)
        let completed = DispatchSemaphore(value: 0)
        modelBuffer.addCompletedHandler { [renderer] _ in
            withExtendedLifetime(renderer) {}
            completed.signal()
        }
        let scene = SCNScene()
        // Materials: PBR so lights/reflections read as real 3D.
        let col = o.color.value(at: time)
        model.enumerateHierarchy { n, _ in
            guard let original = n.geometry, o.fileName == nil, let g = original.copy() as? SCNGeometry else { return }
            n.geometry = g
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(red: col.r, green: col.g, blue: col.b, alpha: col.a)
            m.metalness.contents = min(1, max(0, o.metalness))
            m.roughness.contents = min(1, max(0, o.roughness))
            if o.imageFile != nil, let front = cached.front {
                // SCNShape elements: front, back, sides, front chamfer, back chamfer.
                g.materials = [front, front, m, m, m]
            } else {
                g.materials = [m]
            }
        }
        let yaw = o.yaw.value(at: time) + o.spin * time
        model.eulerAngles = SCNVector3(Float(o.pitch.value(at: time) * .pi / 180), Float(yaw * .pi / 180), Float(o.roll.value(at: time) * .pi / 180))
        scene.rootNode.addChildNode(model)

        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 35
        let distance = Self.cameraDistance(radius: cached.radius, aspect: Double(width) / Double(height))
        cam.camera?.zNear = max(0.001, distance - cached.radius * 1.5)
        cam.camera?.zFar = distance + cached.radius * 3
        cam.position = SCNVector3(0, 0, Float(distance))
        scene.rootNode.addChildNode(cam)
        let key2 = SCNNode()
        key2.light = SCNLight()
        key2.light?.type = .directional
        key2.light?.intensity = CGFloat(o.lightIntensity.value(at: time))
        key2.light?.castsShadow = true
        let a = o.lightAngle.value(at: time) * .pi / 180
        key2.eulerAngles = SCNVector3(Float(-0.6), Float(a), 0)
        scene.rootNode.addChildNode(key2)
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 300
        scene.rootNode.addChildNode(amb)
        scene.lightingEnvironment.contents = UIColor(white: 0.6, alpha: 1)
        scene.background.contents = UIColor.clear

        renderer.scene = scene
        renderer.pointOfView = cam
        SCNTransaction.flush()
        renderer.update(atTime: time)
        guard renderer.prepare(scene, shouldAbortBlock: nil) else { return nil }
        // Snapshot owns SceneKit's full frame lifecycle, including first-frame presentation setup.
        if reusedRenderer == nil {
            _ = renderer.snapshot(atTime: time, with: CGSize(width: width, height: height), antialiasingMode: .none)
            SCNTransaction.flush()
            renderer.update(atTime: time)
        }
        let image = renderer.snapshot(atTime: time, with: CGSize(width: width, height: height), antialiasingMode: .none)
        guard let cg = image.cgImage,
              let texture = try? MTKTextureLoader(device: device).newTexture(cgImage: cg, options: [.SRGB: false, .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue)]) else { return nil }
        renderer.scene = nil; renderer.pointOfView = nil
        if availableRenderers.count < 8 { availableRenderers.append(renderer) }
        return texture
    }
}
