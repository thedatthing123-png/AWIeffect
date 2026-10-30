import Foundation
import SceneKit
import Metal
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
    private let renderer: SCNRenderer
    private var scenes: [String: SCNNode] = [:]
    private var targets: [String: MTLTexture] = [:]
    private let lock = NSLock()

    init(device: MTLDevice) {
        self.device = device
        renderer = SCNRenderer(device: device, options: nil)
    }

    /// Model content node (cached per file / per text settings).
    private func content(_ o: Model3DOptions, mediaURL: (String) -> URL) -> SCNNode? {
        let key: String
        if let f = o.fileName { key = f }
        else if let p = o.shapePath { key = "shape|\(p.vertices.map { "\($0.point.x),\($0.point.y),\($0.inTangent.x),\($0.inTangent.y),\($0.outTangent.x),\($0.outTangent.y)" }.joined(separator: ";"))|\(o.extrusion)|\(o.chamfer)" }
        else if let f = o.imageFile { key = "image|\(f)|\(o.extrusion)|\(o.chamfer)|\(o.roughness)" }
        else { key = "text|\(o.text)|\(o.fontName)|\(o.extrusion)|\(o.chamfer)" }
        if let n = scenes[key] { return n }
        let node: SCNNode
        if o.shapePath != nil || o.imageFile != nil {
            guard let g = Extrude3D.geometry(o, mediaURL: mediaURL) else { return nil }
            node = SCNNode(geometry: g.geometry)
            if let front = g.front { node.setValue(front, forKey: "awiFront") }
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
        scenes[key] = holder
        return holder
    }

    /// Renders the layer at `time` into a premultiplied BGRA texture of `width`×`height`.
    func render(_ o: Model3DOptions, time: Double, width: Int, height: Int, cb: MTLCommandBuffer, mediaURL: (String) -> URL) -> MTLTexture? {
        lock.lock(); defer { lock.unlock() }
        guard let model = content(o, mediaURL: mediaURL)?.clone() else { return nil }
        let key = "\(width)x\(height)"
        let target: MTLTexture
        if let t = targets[key] { target = t } else {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            d.usage = [.renderTarget, .shaderRead]
            d.storageMode = .private
            guard let t = device.makeTexture(descriptor: d) else { return nil }
            targets[key] = t
            target = t
        }

        let scene = SCNScene()
        // Materials: PBR so lights/reflections read as real 3D.
        let col = o.color.value(at: time)
        model.enumerateHierarchy { n, _ in
            guard let g = n.geometry, o.fileName == nil else { return }
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(red: col.r, green: col.g, blue: col.b, alpha: 1)
            m.metalness.contents = o.metalness
            m.roughness.contents = o.roughness
            if o.imageFile != nil, let front = n.value(forKey: "awiFront") as? SCNMaterial {
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
        cam.position = SCNVector3(0, 0, 4.2)
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
        let rp = MTLRenderPassDescriptor()
        rp.colorAttachments[0].texture = target
        rp.colorAttachments[0].loadAction = .clear
        rp.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        rp.colorAttachments[0].storeAction = .store
        renderer.render(atTime: time, viewport: CGRect(x: 0, y: 0, width: width, height: height), commandBuffer: cb, passDescriptor: rp)
        return target
    }
}
