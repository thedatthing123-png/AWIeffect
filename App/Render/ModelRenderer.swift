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
    /// Imported models: replace their own materials with the color / metal / roughness above.
    var overrideMaterial: Bool? = nil
    /// The surface glows in its own color (0-1), on top of lighting.
    var emission: Double? = nil
    /// Imported models: play the animation that came with the file, at this speed, starting this many seconds in.
    var playAnimation: Bool? = nil
    var animationSpeed: Double? = nil
    var animationOffset: Double? = nil
}

/// Where a 3D layer's model sits as seen by the scene camera. With this the model is a real object in the scene:
/// orbiting the camera or turning the layer shows its other sides, instead of tilting a flat picture of it.
struct ModelScenePlacement {
    /// Model space (y up, z toward the viewer, fitted to about 2 units) -> SceneKit camera space.
    var modelToCamera: simd_float4x4
    /// Vertical field of view of the scene camera.
    var fieldOfView: Double
    var lights: [Renderer.LightGPU]
    /// World -> SceneKit camera space, for the lights.
    var worldToCamera: simd_float4x4
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
            guard let scene = try? ModelImport.load(url: mediaURL(f)) else { return nil }
            node = SCNNode()
            for c in scene.rootNode.childNodes { node.addChildNode(c) }
            // Animations in the file follow the timeline, not the wall clock, so scrubbing and export match.
            node.enumerateHierarchy { n, _ in
                for key in n.animationKeys {
                    guard let player = n.animationPlayer(forKey: key) else { continue }
                    player.animation.usesSceneTimeBase = true
                    player.animation.repeatCount = .greatestFiniteMagnitude
                    player.play()
                }
            }
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

    private static func node(for l: Renderer.LightGPU, worldToCamera: simd_float4x4) -> SCNNode {
        let node = SCNNode(), light = SCNLight()
        let strength = max(l.color.x, max(l.color.y, l.color.z))
        light.color = UIColor(red: CGFloat(l.color.x / max(strength, 1e-3)), green: CGFloat(l.color.y / max(strength, 1e-3)), blue: CGFloat(l.color.z / max(strength, 1e-3)), alpha: 1)
        light.intensity = CGFloat(strength * 1000)
        switch Int(l.posType.w) {
        case 0: light.type = .omni
        case 1:
            light.type = .spot
            light.spotOuterAngle = CGFloat(acos(min(1, max(-1, Double(l.dirCone.w)))) * 360 / .pi)
            light.spotInnerAngle = light.spotOuterAngle * CGFloat(1 - l.color.w)
        case 2: light.type = .directional
        default: light.type = .ambient
        }
        if l.falloff.x > 0 { light.attenuationEndDistance = CGFloat(l.falloff.x) }
        node.light = light
        let p = worldToCamera * SIMD4(l.posType.x, l.posType.y, l.posType.z, 1)
        let d = worldToCamera * SIMD4(l.dirCone.x, l.dirCone.y, l.dirCone.z, 0)
        node.simdPosition = SIMD3(p.x, p.y, p.z)
        node.simdLook(at: SIMD3(p.x + d.x, p.y + d.y, p.z + d.z))
        return node
    }

    static func cameraDistance(radius: Double, aspect: Double, fov: Double = 35) -> Double {
        let vertical = fov * .pi / 360
        let horizontal = atan(tan(vertical) * max(0.01, aspect))
        return max(0.01, radius) / max(0.001, sin(min(vertical, horizontal))) * 1.08
    }

    /// Renders the layer at `time` into a premultiplied BGRA texture of `width`×`height`.
    func render(_ o: Model3DOptions, time: Double, width: Int, height: Int, cb: MTLCommandBuffer, pool: TexturePool? = nil,
                placement: ModelScenePlacement? = nil, mediaURL: (String) -> URL) -> MTLTexture? {
        lock.lock(); defer { lock.unlock() }
        guard width > 0, height > 0, width <= TexturePool.maxSide, height <= TexturePool.maxSide,
              let cached = content(o, mediaURL: mediaURL) else { return nil }
        // SCNText builds its mesh lazily. Prepare the source before copying its geometry.
        let preparationRenderer = availableRenderers.last ?? SCNRenderer(device: device, options: nil)
        guard preparationRenderer.prepare(cached.node, shouldAbortBlock: nil) else { return nil }
        let model = cached.node.clone()
        let animated = o.fileName != nil && o.playAnimation != false
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
            // Imported models keep their own materials unless the layer overrides them.
            guard let original = n.geometry, o.fileName == nil || o.overrideMaterial == true, let g = original.copy() as? SCNGeometry else { return }
            n.geometry = g
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(red: col.r, green: col.g, blue: col.b, alpha: col.a)
            m.metalness.contents = min(1, max(0, o.metalness))
            m.roughness.contents = min(1, max(0, o.roughness))
            if let glow = o.emission, glow > 0 {
                m.emission.contents = UIColor(red: col.r, green: col.g, blue: col.b, alpha: 1)
                m.emission.intensity = CGFloat(glow)
            }
            if o.imageFile != nil, let front = cached.front {
                // SCNShape elements: front, back, sides, front chamfer, back chamfer.
                g.materials = [front, front, m, m, m]
            } else {
                g.materials = [m]
            }
        }
        let yaw = o.yaw.value(at: time) + o.spin * time
        model.eulerAngles = SCNVector3(Float(o.pitch.value(at: time) * .pi / 180), Float(yaw * .pi / 180), Float(o.roll.value(at: time) * .pi / 180))
        if let placement {
            let holder = SCNNode()
            holder.simdTransform = placement.modelToCamera
            holder.addChildNode(model)
            scene.rootNode.addChildNode(holder)
        } else {
            scene.rootNode.addChildNode(model)
        }

        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 35
        let distance = Self.cameraDistance(radius: cached.radius, aspect: Double(width) / Double(height))
        cam.camera?.zNear = max(0.001, distance - cached.radius * 1.5)
        cam.camera?.zFar = distance + cached.radius * 3
        cam.position = SCNVector3(0, 0, Float(distance))
        if let placement {
            cam.camera?.fieldOfView = CGFloat(placement.fieldOfView)
            cam.camera?.projectionDirection = .vertical
            cam.camera?.zNear = 1
            cam.camera?.zFar = 200_000
            cam.position = SCNVector3(0, 0, 0)
            for light in placement.lights { scene.rootNode.addChildNode(Self.node(for: light, worldToCamera: placement.worldToCamera)) }
        }
        scene.rootNode.addChildNode(cam)
        let key2 = SCNNode()
        key2.light = SCNLight()
        key2.light?.type = .directional
        key2.light?.intensity = CGFloat(o.lightIntensity.value(at: time))
        key2.light?.castsShadow = true
        let a = o.lightAngle.value(at: time) * .pi / 180
        key2.eulerAngles = SCNVector3(Float(-0.6), Float(a), 0)
        // Scene lights replace the built-in key light.
        if placement?.lights.isEmpty != false { scene.rootNode.addChildNode(key2) }
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
        renderer.sceneTime = animated ? max(0, time * (o.animationSpeed ?? 1) + (o.animationOffset ?? 0)) : 0
        renderer.update(atTime: time)
        guard renderer.prepare(scene, shouldAbortBlock: nil) else { return nil }
        // Render straight into a GPU texture. The old path took a snapshot image, copied it to the CPU and uploaded
        // it again every frame, which made the 3D camera heavy. SceneKit writes linear light into an sRGB target;
        // a plain view of the same memory gives the compositor the display values it expects.
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        colorDesc.usage = [.renderTarget, .shaderRead, .pixelFormatView]
        colorDesc.storageMode = .private
        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        depthDesc.usage = [.renderTarget]
        depthDesc.storageMode = .private
        guard let color = device.makeTexture(descriptor: colorDesc), let depth = device.makeTexture(descriptor: depthDesc),
              let texture = color.makeTextureView(pixelFormat: .bgra8Unorm) else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.storeAction = .dontCare
        renderer.render(atTime: time, viewport: CGRect(x: 0, y: 0, width: width, height: height), commandBuffer: modelBuffer, passDescriptor: pass)
        modelBuffer.commit()
        _ = completed.wait(timeout: .now() + 2)
        _ = target
        renderer.scene = nil; renderer.pointOfView = nil
        if availableRenderers.count < 8 { availableRenderers.append(renderer) }
        return texture
    }
}
