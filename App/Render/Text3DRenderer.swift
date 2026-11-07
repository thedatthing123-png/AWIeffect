import Foundation
import SceneKit
import Metal
import CoreText
import UIKit

/// One letter of real 3D text.
struct Text3DGlyph {
    var glyph: CGGlyph
    var fontName: String
    var fontSize: Double
    /// Glyph space (CoreText points, y up, baseline origin, z toward the viewer) -> placement model space.
    var transform: simd_float4x4
    /// Per-letter opacity (0-1) for letter animators.
    var opacity: Double = 1

    init(glyph: CGGlyph, fontName: String, fontSize: Double, transform: simd_float4x4 = matrix_identity_float4x4, opacity: Double = 1) {
        self.glyph = glyph; self.fontName = fontName; self.fontSize = fontSize; self.transform = transform; self.opacity = opacity
    }

    /// Lays a single line out with CoreText and returns its glyphs centered on the origin, scaled by `unitsPerPoint`
    /// into model space (ModelScenePlacement fits a layer's half-size to 1 unit, so pass 1 / (min(layer w, h) / 2)).
    static func line(_ string: String, fontName: String, fontSize: Double, unitsPerPoint: Double) -> [Text3DGlyph] {
        let font = CTFontCreateWithName(fontName as CFString, CGFloat(fontSize), nil)
        let attributed = NSAttributedString(string: string, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attributed)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
        let originX = -width / 2, originY = -Double(ascent - descent) / 2
        var out: [Text3DGlyph] = []
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return [] }
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var glyphs = [CGGlyph](repeating: 0, count: count), positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            let attrs = CTRunGetAttributes(run) as NSDictionary
            let runFontName: String
            if let value = attrs[kCTFontAttributeName as String] {
                runFontName = CTFontCopyPostScriptName(value as! CTFont) as String
            } else {
                runFontName = fontName
            }
            for i in 0..<count {
                let s = Float(unitsPerPoint)
                var m = matrix_identity_float4x4
                m.columns.0 = SIMD4(s, 0, 0, 0)
                m.columns.1 = SIMD4(0, s, 0, 0)
                m.columns.2 = SIMD4(0, 0, s, 0)
                m.columns.3 = SIMD4(Float((originX + Double(positions[i].x)) * unitsPerPoint),
                                    Float((originY + Double(positions[i].y)) * unitsPerPoint), 0, 1)
                out.append(Text3DGlyph(glyph: glyphs[i], fontName: runFontName, fontSize: fontSize, transform: m))
            }
        }
        return out
    }
}

/// Renders real extruded/bevelled per-letter 3D text with SceneKit PBR, a procedural studio environment,
/// the scene lights and the comp camera (same conventions as ModelRenderer's placement path).
final class Text3DRenderer {
    static let shared: Text3DRenderer? = Renderer.shared.map { Text3DRenderer(device: $0.device) }

    private let device: MTLDevice
    private let queue: MTLCommandQueue?
    private let lock = NSLock()
    private var renderers: [SCNRenderer] = []
    private struct Target { let color: MTLTexture; let view: MTLTexture; let depth: MTLTexture }
    private var targets: [String: Target] = [:]
    private var geometries: [Text3DMeshKey: SCNGeometry] = [:]
    private var outlines: [Text3DMeshKey: SCNGeometry] = [:]
    private let frontMaterial = SCNMaterial(), bevelMaterial = SCNMaterial(), sideMaterial = SCNMaterial()
    private let outlineMaterial = SCNMaterial()
    private lazy var environment: UIImage? = Self.studioEnvironment()

    init(device: MTLDevice) {
        self.device = device
        queue = device.makeCommandQueue()
        outlineMaterial.lightingModel = .constant
        outlineMaterial.diffuse.contents = UIColor.black
        outlineMaterial.cullMode = .front
        outlineMaterial.shaderModifiers = [.geometry: """
        #pragma arguments
        float outlineWidthTxt4;
        #pragma body
        _geometry.position.xyz += _geometry.normal * outlineWidthTxt4;
        """]
    }

    func clear() {
        lock.lock()
        geometries.removeAll(); outlines.removeAll(); targets.removeAll(); renderers.removeAll()
        lock.unlock()
        Text3DMesh.clearCache()
    }

    // MARK: Geometry

    /// SceneKit geometry for a mesh. `materials` are front, back, bevel and side; empty parts are left out.
    static func geometry(_ mesh: Text3DMesh, materials: [SCNMaterial]) -> SCNGeometry {
        let pos = SCNGeometrySource(vertices: mesh.positions.map { SCNVector3($0.x, $0.y, $0.z) })
        let nrm = SCNGeometrySource(normals: mesh.normals.map { SCNVector3($0.x, $0.y, $0.z) })
        var elements: [SCNGeometryElement] = [], used: [SCNMaterial] = []
        for (i, part) in [mesh.front, mesh.back, mesh.bevel, mesh.side].enumerated() where !part.isEmpty {
            elements.append(SCNGeometryElement(indices: part, primitiveType: .triangles))
            used.append(materials[min(i, materials.count - 1)])
        }
        let g = SCNGeometry(sources: [pos, nrm], elements: elements)
        g.materials = used
        return g
    }

    private func cachedGeometry(_ key: Text3DMeshKey) -> (SCNGeometry, SCNGeometry)? {
        if let g = geometries[key], let o = outlines[key] { return (g, o) }
        guard let mesh = Text3DMesh.mesh(for: key), !mesh.isEmpty else { return nil }
        let g = Self.geometry(mesh, materials: [frontMaterial, frontMaterial, bevelMaterial, sideMaterial])
        let o = Self.geometry(mesh, materials: [outlineMaterial])
        if geometries.count >= 512 { geometries.removeAll(); outlines.removeAll() }
        geometries[key] = g; outlines[key] = o
        return (g, o)
    }

    // MARK: Materials

    private static let toonFragment = """
    #pragma body
    float3 lumaTxt4 = float3(0.299, 0.587, 0.114);
    float baseTxt4 = max(dot(_surface.diffuse.rgb, lumaTxt4), 0.001);
    float litTxt4 = dot(_output.color.rgb, lumaTxt4) / baseTxt4;
    float bandTxt4 = litTxt4 > 0.75 ? 1.0 : (litTxt4 > 0.35 ? 0.72 : 0.42);
    _output.color.rgb = _surface.diffuse.rgb * bandTxt4 + _surface.emission.rgb;
    """

    private static func apply(_ m: Text3DMaterial, to s: SCNMaterial, time: Double) {
        let c = m.color.value(at: time)
        let color = UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: 1)
        if m.toon {
            if s.lightingModel != .lambert { s.lightingModel = .lambert }
            if s.shaderModifiers?[.fragment] == nil { s.shaderModifiers = [.fragment: toonFragment] }
        } else {
            if s.lightingModel != .physicallyBased { s.lightingModel = .physicallyBased }
            if s.shaderModifiers != nil { s.shaderModifiers = nil }
        }
        s.diffuse.contents = color
        s.metalness.contents = NSNumber(value: min(1, max(0, m.metalness.value(at: time))))
        s.roughness.contents = NSNumber(value: min(1, max(0.02, m.roughness.value(at: time))))
        let glow = max(0, m.emission.value(at: time))
        s.emission.contents = glow > 0 ? color : UIColor.black
        s.emission.intensity = CGFloat(glow)
        if #available(iOS 13.0, *) {
            s.clearCoat.contents = NSNumber(value: min(1, max(0, m.clearcoat.value(at: time))))
            s.clearCoatRoughness.contents = NSNumber(value: 0.05)
        }
        let opacity = min(1, max(0, m.opacity.value(at: time) * c.a))
        let transmission = min(1, max(0, m.transmission.value(at: time)))
        let alpha = opacity * (1 - 0.85 * transmission)
        s.transparency = CGFloat(alpha)
        s.transparencyMode = alpha < 0.999 ? .dualLayer : .default
        s.blendMode = .alpha
        s.fresnelExponent = transmission > 0 ? 3 : 0
    }

    // MARK: Lights / environment

    private static func lightNode(_ l: Renderer.LightGPU, worldToCamera: simd_float4x4) -> SCNNode {
        let node = SCNNode(), light = SCNLight()
        let strength = max(l.color.x, max(l.color.y, l.color.z))
        light.color = UIColor(red: CGFloat(l.color.x / max(strength, 1e-3)), green: CGFloat(l.color.y / max(strength, 1e-3)),
                              blue: CGFloat(l.color.z / max(strength, 1e-3)), alpha: 1)
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

    /// Procedural equirectangular studio: dark floor, soft grey cyclorama, bright softboxes, warm/cool kickers.
    static func studioEnvironment(width: Int = 512, height: Int = 256) -> UIImage? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let W = CGFloat(width), H = CGFloat(height)
        // CGContext y is up: y = H is the zenith.
        let colors = [UIColor(white: 0.22, alpha: 1).cgColor, UIColor(white: 0.5, alpha: 1).cgColor,
                      UIColor(white: 0.62, alpha: 1).cgColor, UIColor(white: 0.05, alpha: 1).cgColor,
                      UIColor(white: 0.02, alpha: 1).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.38, 0.5, 0.53, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: UIColor) {
            ctx.setFillColor(c.cgColor)
            ctx.fill(CGRect(x: x * W, y: y * H, width: w * W, height: h * H))
        }
        box(0.0, 0.9, 1.0, 0.06, UIColor(white: 1, alpha: 1))            // overhead strip
        box(0.20, 0.6, 0.07, 0.25, UIColor(white: 1, alpha: 1))          // key softbox
        box(0.70, 0.62, 0.05, 0.22, UIColor(white: 0.95, alpha: 1))      // fill softbox
        box(0.45, 0.55, 0.12, 0.05, UIColor(white: 1, alpha: 1))         // front strip
        box(0.92, 0.5, 0.04, 0.35, UIColor(red: 1, green: 0.78, blue: 0.55, alpha: 1))  // warm kicker
        box(0.04, 0.5, 0.03, 0.3, UIColor(red: 0.55, green: 0.75, blue: 1, alpha: 1))   // cool kicker
        guard let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Camera-space placement for standalone renders (previews, tests): model space 4 units in front of a 35° camera.
    static func defaultPlacement(distance: Float = 4) -> ModelScenePlacement {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4(0, 0, -distance, 1)
        return ModelScenePlacement(modelToCamera: m, fieldOfView: 35, lights: [], worldToCamera: matrix_identity_float4x4)
    }

    // MARK: Render

    private func target(width: Int, height: Int) -> Target? {
        let key = "\(width)x\(height)"
        if let t = targets[key] { return t }
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        colorDesc.usage = [.renderTarget, .shaderRead, .pixelFormatView]
        colorDesc.storageMode = .private
        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        depthDesc.usage = [.renderTarget]
        depthDesc.storageMode = .private
        guard let color = device.makeTexture(descriptor: colorDesc), let depth = device.makeTexture(descriptor: depthDesc),
              let view = color.makeTextureView(pixelFormat: .bgra8Unorm) else { return nil }
        if targets.count >= 4 { targets.removeAll() }
        let t = Target(color: color, view: view, depth: depth)
        targets[key] = t
        return t
    }

    /// Renders `glyphs` at `time` into a premultiplied BGRA (display-encoded) texture of `size`.
    /// With a `pool` the result is a pool texture valid for the pool's frame; without one a new texture is returned.
    func render(glyphs: [Text3DGlyph], options: Text3DOptions, time: Double, placement: ModelScenePlacement,
                size: CGSize, pool: TexturePool? = nil) -> MTLTexture? {
        lock.lock(); defer { lock.unlock() }
        let width = Int(size.width.rounded()), height = Int(size.height.rounded())
        guard width > 0, height > 0, width <= TexturePool.maxSide, height <= TexturePool.maxSide,
              let queue = queue, let rt = target(width: width, height: height) else { return nil }

        let extrusion = max(0.01, options.extrusion.value(at: time))
        let bevelSize = max(0, options.bevelSize.value(at: time))
        apply(options, time: time)
        let toon = options.front.toon || options.bevel.toon || options.side.toon

        let scene = SCNScene()
        let holder = SCNNode()
        holder.simdTransform = placement.modelToCamera
        scene.rootNode.addChildNode(holder)
        var outlineSet = false
        for g in glyphs where g.opacity > 0.001 {
            let key = Text3DMeshKey(fontName: g.fontName, fontSize: g.fontSize, glyph: g.glyph, extrusion: extrusion,
                                    bevelSize: bevelSize, bevelSegments: options.bevelSegments, profile: options.bevelProfile)
            guard let pair = cachedGeometry(key) else { continue }
            let node = SCNNode(geometry: pair.0)
            node.simdTransform = g.transform
            node.opacity = CGFloat(min(1, g.opacity))
            if toon {
                if !outlineSet { outlineMaterial.setValue(NSNumber(value: max(0.5, g.fontSize * 0.018)), forKey: "outlineWidthTxt4"); outlineSet = true }
                node.addChildNode(SCNNode(geometry: pair.1))
            }
            holder.addChildNode(node)
        }

        let cam = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = CGFloat(placement.fieldOfView)
        camera.projectionDirection = .vertical
        camera.zNear = 0.01
        camera.zFar = 200_000
        camera.wantsHDR = false
        cam.camera = camera
        scene.rootNode.addChildNode(cam)
        if placement.lights.isEmpty {
            let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 900
            key.eulerAngles = SCNVector3(-0.6, 0.5, 0)
            let rim = SCNNode(); rim.light = SCNLight(); rim.light?.type = .directional; rim.light?.intensity = 500
            rim.eulerAngles = SCNVector3(0.3, Float.pi * 0.8, 0)
            scene.rootNode.addChildNode(key); scene.rootNode.addChildNode(rim)
        } else {
            for l in placement.lights { scene.rootNode.addChildNode(Self.lightNode(l, worldToCamera: placement.worldToCamera)) }
        }
        let amb = SCNNode(); amb.light = SCNLight(); amb.light?.type = .ambient; amb.light?.intensity = 120
        scene.rootNode.addChildNode(amb)
        scene.lightingEnvironment.contents = environment
        scene.lightingEnvironment.intensity = CGFloat(max(0, options.environmentIntensity.value(at: time)) * 1.6)
        let rotation = Float(options.environmentRotation.value(at: time) * .pi / 180)
        scene.lightingEnvironment.contentsTransform = SCNMatrix4MakeRotation(rotation, 0, 1, 0)
        scene.background.contents = UIColor.clear

        let renderer = renderers.popLast() ?? SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cam
        SCNTransaction.flush()
        renderer.update(atTime: time)
        guard renderer.prepare(scene, shouldAbortBlock: nil), let buffer = queue.makeCommandBuffer() else {
            renderer.scene = nil; renderer.pointOfView = nil
            return nil
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = rt.color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = rt.depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.storeAction = .dontCare
        renderer.render(atTime: time, viewport: CGRect(x: 0, y: 0, width: width, height: height), commandBuffer: buffer, passDescriptor: pass)

        // Copy out of the reused render target so several letters/layers/motion samples keep separate pictures.
        let output: MTLTexture
        if let pool { output = pool.acquire(width: width, height: height, format: .bgra8Unorm) }
        else {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            d.usage = [.shaderRead, .renderTarget]
            d.storageMode = .private
            guard let t = device.makeTexture(descriptor: d) else { return nil }
            output = t
        }
        if let blit = buffer.makeBlitCommandEncoder() {
            blit.copy(from: rt.view, to: output)
            blit.endEncoding()
        }
        let done = DispatchSemaphore(value: 0)
        buffer.addCompletedHandler { [renderer] _ in withExtendedLifetime(renderer) {}; done.signal() }
        buffer.commit()
        _ = done.wait(timeout: .now() + 2)
        renderer.scene = nil; renderer.pointOfView = nil
        if renderers.count < 4 { renderers.append(renderer) }
        return output
    }

    private func apply(_ o: Text3DOptions, time: Double) {
        Self.apply(o.front, to: frontMaterial, time: time)
        Self.apply(o.bevel, to: bevelMaterial, time: time)
        Self.apply(o.side, to: sideMaterial, time: time)
    }
}
