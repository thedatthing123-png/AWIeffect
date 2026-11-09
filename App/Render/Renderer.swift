import Foundation
import Metal
import MetalKit
import simd
import UIKit

/// Must match `LayerParams` in Shaders.metal.
struct LayerParams {
    var invRow0: SIMD4<Float>
    var invRow1: SIMD4<Float>
    var invRow2: SIMD4<Float>
    var color: SIMD4<Float>
    var geom: SIMD4<Float>
    var geom2: SIMD4<Float>
    var modes: SIMD4<UInt32>
    var region: SIMD4<UInt32>
}

enum RenderError: Error {
    case noDevice, pipeline(String), texture
}

/// The single compositor used by preview, thumbnails and export, so they always match.
final class Renderer {
    static let shared: Renderer? = try? Renderer()

    let device: MTLDevice
    let queue: MTLCommandQueue
    let fx: EffectGPU
    private let clearPSO: MTLComputePipelineState
    let drawPSO: MTLComputePipelineState
    /// Text Studio glyph pass (fills / gradients / strokes / shadows / glow, color emoji).
    let glyphPSO: MTLComputePipelineState
    private let lightPSO: MTLComputePipelineState
    private let toBGRAPSO: MTLComputePipelineState
    let displayPSO: MTLRenderPipelineState
    private let loader: MTKTextureLoader
    let dummy: MTLTexture
    private var imageCache: [String: MTLTexture] = [:]
    private var imageOrder: [String] = []
    private var imageCacheBytes = 0
    private static let imageCacheBudget = 128 * 1024 * 1024
    private let cacheLock = NSLock()
    private let encodeLock = NSRecursiveLock()

    static let compFormat: MTLPixelFormat = .rgba16Float
    /// Nested comps available while encoding (root project's library), the pool and nesting depth in use.
    private var precompLibrary: [Project] = []
    private(set) var currentPool: TexturePool?
    /// Beat / marker times of the project being encoded (text beat selectors).
    var textBeats: [Double] = []
    private var currentDepth = 0
    /// 3D layers casting shadows this frame (only filled when a light casts shadows).
    private var shadowCasters: [(id: UUID, gpu: ShadowCasterGPU, tex: MTLTexture)] = []
    /// 1x1 opaque white: stands in for solid / shape casters and unused caster slots.
    private lazy var whiteTexture: MTLTexture = {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        let t = device.makeTexture(descriptor: d)!
        var px: [UInt8] = [255, 255, 255, 255]
        t.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &px, bytesPerRow: 4)
        return t
    }()
    /// Parts of each group in the comp being encoded (group id -> parts, in stacking order).
    private var groupParts: [UUID: [Layer]] = [:]
    private var groupCameras: [Layer] = []

    /// Renders a nested comp at `time` (layer time -> comp time via the layer's timing), transparent background.
    private func renderPrecomp(_ id: UUID, layer: Layer, time: Double, density: Double, cb: MTLCommandBuffer,
                               mediaURL: (String) -> URL) -> MTLTexture? {
        guard currentDepth < 6, let pool = currentPool, var comp = precompLibrary.first(where: { $0.id == id }) else { return nil }
        let library = precompLibrary, depth = currentDepth
        if Self.allowPrecompProxy, let proxy = comp.preRenderProxy,
           proxy.signature == PrecompRenderCache.signature(comp, library: library),
           let frame = VideoSources.shared.texture(url: mediaURL(proxy.file), time: layer.sourceTime(at: time), device: device, channel: layer.id.hashValue) {
            let output = pool.acquire(width: frame.width, height: frame.height)
            fx.run("fxProxyPremultiply", cb, textures: [frame, output], grid: output)
            return output
        }
        let scale = min(2, max(0.05, density))
        let maxSide = Double(max(comp.width, comp.height)) * scale
        let s = maxSide > 4096 ? scale * 4096 / maxSide : scale
        let w = max(1, Int((Double(comp.width) * s).rounded())), h = max(1, Int((Double(comp.height) * s).rounded()))
        let tex = pool.acquire(width: w, height: h)
        comp.background.a = 0
        comp.precompList = library
        comp.precompDepth = depth + 1
        encode(project: comp, time: layer.sourceTime(at: time), renderScale: s, into: tex, commandBuffer: cb, pool: pool, mediaURL: mediaURL)
        // Restore the parent's encode context.
        precompLibrary = library
        currentPool = pool
        currentDepth = depth
        return tex
    }
    /// Renders `ref` alone (comp space) and resamples it into another layer's effect buffer, so an effect can read
    /// it pixel-for-pixel where the two overlap on screen.
    private func layerInBuffer(_ ref: Layer, project: Project, time: Double, renderScale: Double, comp: MTLTexture,
                               placement M: simd_double3x3, toLocal: simd_double3x3, size: (Int, Int),
                               cb: MTLCommandBuffer, pool: TexturePool, mediaURL: (String) -> URL) -> MTLTexture? {
        guard currentDepth < 8 else { return nil }
        let library = precompLibrary, depth = currentDepth, savedParts = groupParts, savedCams = groupCameras
        var sub = project
        sub.precompDepth = currentDepth + 1
        var one = ref; one.trackMatte = .none; one.isSolo = false; one.isVisible = true; one.groupID = nil
        sub.layers = project.layers.filter { $0.content == .camera } + [one]
        sub.background = RGBA(0, 0, 0, 0)
        let full = pool.acquire(width: comp.width, height: comp.height)
        encode(project: sub, time: time, renderScale: renderScale, into: full, commandBuffer: cb, pool: pool, mediaURL: mediaURL)
        precompLibrary = library; currentPool = pool; currentDepth = depth; groupParts = savedParts; groupCameras = savedCams
        let out = pool.acquire(width: size.0, height: size.1)
        fx.run("fxClear", cb, textures: [out], grid: out)
        // comp-image local (centered) -> comp px -> layer local -> buffer px.
        let center = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(comp.width) / 2, Double(comp.height) / 2, 1)))
        let place = toLocal.inverse * M.inverse * center
        let carrier = Layer(name: "ref", content: .solid, outPoint: 1, transform: LayerTransform(position: Animated(.zero)), size: Animated(Vec2(1, 1)))
        drawQuad(cb: cb, target: out, matrix: place, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 0.5,
                 opacity: 1, layer: carrier, time: time, source: .image(full), premultipliedImage: true, blendOverride: .normal)
        return out
    }

    /// Isolated comp-space coverage/reference, retaining group descendants and external parent transforms.
    private func fullLayer(_ layer: Layer, project: Project, time: Double, renderScale: Double, comp: MTLTexture,
                           cb: MTLCommandBuffer, pool: TexturePool, mediaURL: (String) -> URL) -> MTLTexture {
        let out = pool.acquire(width: comp.width, height: comp.height)
        fx.run("fxClear", cb, textures: [out], grid: out)
        guard currentDepth < 8 else { return out }
        var sub = project, one = layer
        one.trackMatte = .none; one.clipToBelow = false; one.isSolo = false; one.isVisible = true; one.groupID = nil
        let descendants = layer.isGroup ? EditorState.descendantIDs(of: layer.id, in: project) : []
        sub.layers = project.layers.filter { $0.content == .camera } + [one] + project.layers.filter { descendants.contains($0.id) }
        sub.parentContext = project.layers + (project.parentContext ?? [])
        sub.background = RGBA(0, 0, 0, 0); sub.precompDepth = currentDepth + 1
        encode(project: sub, time: time, renderScale: renderScale, into: out, commandBuffer: cb, pool: pool, mediaURL: mediaURL)
        return out
    }

    private func encodeBackdropDisplacement(_ layer: Layer, matte: Layer?, project: Project, time: Double, renderScale: Double,
                                           opacity: Double, comp: MTLTexture, cb: MTLCommandBuffer, pool: TexturePool,
                                           mediaURL: (String) -> URL) {
        let effects = layer.effects.filter { $0.isEnabled && !(EffectRegistry.definition($0.typeID)?.isTransformEffect ?? false) }
        guard let index = effects.firstIndex(where: { $0.typeID == "awi18.displacementMap" && $0.choice("target") == 1 }) else { return }
        var carrier = layer
        carrier.effects = Array(effects.prefix(index)) + layer.effects.filter { $0.isEnabled && (EffectRegistry.definition($0.typeID)?.isTransformEffect ?? false) }
        carrier.transform.opacity = Animated(100)
        carrier.blendMode = .normal
        if carrier.content == .adjustment { carrier.content = .solid; carrier.fill = Animated(.white) }
        var coverage = fullLayer(carrier, project: project, time: time, renderScale: renderScale, comp: comp, cb: cb, pool: pool, mediaURL: mediaURL)
        if let matte {
            let mask = fullLayer(matte, project: project, time: time, renderScale: renderScale, comp: comp, cb: cb, pool: pool, mediaURL: mediaURL)
            let mixed = pool.acquire(width: comp.width, height: comp.height)
            var params = EffectParams(); params.i.x = 6
            params.i.y = UInt32(TrackMatte.allCases.firstIndex(of: layer.trackMatte == .none ? .alpha : layer.trackMatte) ?? 1) - 1
            fx.run("fxGlow4", cb, textures: [coverage, mixed, mask], params: params, grid: mixed)
            coverage = mixed
        }
        let copy = pool.acquire(width: comp.width, height: comp.height)
        fx.run("fxCopy", cb, textures: [comp, copy], grid: copy)
        var current = copy
        for effect in effects.dropFirst(index) {
            guard let definition = EffectRegistry.definition(effect.typeID), case .pixels(let run) = definition.stage else { continue }
            var context = EffectContext(gpu: fx, cb: cb, input: current, effect: effect, time: time, unit: renderScale, pool: pool)
            context.layerPixels = SIMD2(Double(comp.width), Double(comp.height))
            if let id = effect.text?["layer"].flatMap(UUID.init(uuidString:)), id != layer.id,
               let reference = project.layers.first(where: { $0.id == id }) {
                context.reference = fullLayer(reference, project: project, time: time, renderScale: renderScale, comp: comp, cb: cb, pool: pool, mediaURL: mediaURL)
            } else if effect.typeID == "awi18.displacementMap" { context.reference = coverage }
            current = run(context)
        }
        var params = EffectParams(); params.a.x = Float(opacity)
        if layer.blendMode == .normal {
            fx.run("fxBackdropMix", cb, textures: [comp, current, coverage], params: params, grid: comp)
        } else {
            let masked = pool.acquire(width: comp.width, height: comp.height)
            fx.run("fxBackdropMask", cb, textures: [current, masked, coverage], params: params, grid: masked)
            let matrix = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(comp.width) / 2, Double(comp.height) / 2, 1)))
            drawQuad(cb: cb, target: comp, matrix: matrix, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 0.5,
                     opacity: 1, layer: layer, time: time, source: .image(masked), premultipliedImage: true, blendOverride: layer.blendMode)
        }
    }

    /// Renders a group's parts (comp space, transparent) at the layer's density; the group layer then places
    /// this picture with its own transform, masks and effects. The group layer is comp-sized and centered,
    /// so with an untouched group transform the parts land exactly where they are.
    private func renderGroup(_ group: Layer, time: Double, density: Double, cb: MTLCommandBuffer, mediaURL: (String) -> URL) -> MTLTexture? {
        guard currentDepth < 8, let pool = currentPool else { return nil }
        // Parenting is already baked into the parts this frame: drop links so it is not applied twice.
        var members = (groupParts[group.id] ?? []).map { l -> Layer in var c = l; c.parentID = nil; c.groupID = nil; return c }
        var visited = Set([group.id]), frontier = members.filter(\.isGroup).map(\.id)
        while let id = frontier.popLast() {
            guard visited.insert(id).inserted else { continue }
            let descendants = (groupParts[id] ?? []).filter { !visited.contains($0.id) }
            members.append(contentsOf: descendants)
            frontier.append(contentsOf: descendants.filter(\.isGroup).map(\.id))
        }
        let hs = Self.layerHalfSize(group, time: time)
        let w0 = max(1, Int((group.groupCanvasSize?.x ?? (hs.x * 2)).rounded())), h0 = max(1, Int((group.groupCanvasSize?.y ?? (hs.y * 2)).rounded()))
        let scale = min(2, max(0.05, density))
        let maxSide = Double(max(w0, h0)) * scale
        let s = maxSide > 4096 ? scale * 4096 / maxSide : scale
        let tex = pool.acquire(width: max(1, Int((Double(w0) * s).rounded())), height: max(1, Int((Double(h0) * s).rounded())))
        var sub = Project.new(name: "group", width: w0, height: h0, fps: 30, duration: 1, background: RGBA(0, 0, 0, 0))
        sub.layers = groupCameras + members
        sub.precomps = precompLibrary
        sub.precompList = precompLibrary
        sub.precompDepth = currentDepth + 1
        let library = precompLibrary, depth = currentDepth, saved = groupParts, cams = groupCameras
        encode(project: sub, time: time, renderScale: s, into: tex, commandBuffer: cb, pool: pool, mediaURL: mediaURL)
        precompLibrary = library; currentPool = pool; currentDepth = depth; groupParts = saved; groupCameras = cams
        return tex
    }

    /// Track matte: renders the layer and its matte separately at comp size, multiplies, then composites with the layer's blend mode.
    private func encodeMatted(_ layer: Layer, matte: Layer, project: Project, time: Double, renderScale: Double, comp: MTLTexture,
                              cb: MTLCommandBuffer, pool: TexturePool, mediaURL: (String) -> URL) {
        let library = precompLibrary, depth = currentDepth
        let cameras = project.layers.filter { $0.content == .camera }
        func renderOnly(_ l: Layer) -> MTLTexture {
            var sub = project
            var one = l; one.trackMatte = .none; one.clipToBelow = false; one.isSolo = false; one.isVisible = true
            sub.layers = cameras + [one]
            sub.background.a = 0
            sub.background = RGBA(0, 0, 0, 0)
            let tex = pool.acquire(width: comp.width, height: comp.height)
            encode(project: sub, time: time, renderScale: renderScale, into: tex, commandBuffer: cb, pool: pool, mediaURL: mediaURL)
            precompLibrary = library; currentPool = pool; currentDepth = depth
            return tex
        }
        let content = renderOnly(layer)
        let m = renderOnly(matte)
        let out = pool.acquire(width: comp.width, height: comp.height)
        var p = EffectParams()
        p.i.x = 6
        p.i.y = UInt32(TrackMatte.allCases.firstIndex(of: layer.trackMatte == .none ? .alpha : layer.trackMatte) ?? 1) - 1
        fx.run("fxGlow4", cb, textures: [content, out, m], params: p, grid: out)
        let I = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(comp.width) / 2, Double(comp.height) / 2, 1)))
        drawQuad(cb: cb, target: comp, matrix: I, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 0.5,
                 opacity: 1, layer: layer, time: time, source: .image(out), premultipliedImage: true)
    }

    /// Echo trails: each echoing layer gets delayed, fading copies stacked underneath it (all keyframes and media delayed).
    static func expandEchoes(_ p: Project, meshSource: Project? = nil, time: Double = 0) -> Project {
        guard p.layers.contains(where: { ($0.timeFX?.echoCount ?? 0) > 0 }) else { return p }
        var q = p
        var out: [Layer] = []
        var meshFrames: [Double: Project] = [:]
        func binding(_ id: UUID, at sampleTime: Double) -> BoneMeshBinding? {
            guard let source = meshSource else { return nil }
            if meshFrames[sampleTime] == nil {
                meshFrames[sampleTime] = resolveParenting(ExpressionResolver.resolve(source,time: sampleTime),time: sampleTime,meshSource: source)
            }
            guard var mesh = meshFrames[sampleTime]?.layers.first(where: { $0.id == id })?.boneMesh else { return nil }
            // Palette already represents the delayed pose; nested encoding must not replace it with the current pose.
            mesh.frameTime = time
            return mesh
        }
        // A layer used as a track matte by the layer below keeps its slot (no echo copies between them).
        let matteSources = Set(p.layers.indices.compactMap { i in i > 0 && p.layers[i].trackMatte != .none ? p.layers[i - 1].id : nil })
        for l in p.layers {
            var current = l
            if l.boneMesh != nil,meshSource != nil { current.boneMesh = binding(l.id,at: time) }
            out.append(current)
            guard let fx = l.timeFX, fx.echoCount > 0, !matteSources.contains(l.id) else { continue }
            for k in 1...min(fx.echoCount, 24) {
                var c = l
                c.id = UUID()
                c.timeFX?.echoCount = 0
                c.trackMatte = .none
                if l.boneMesh != nil,meshSource != nil { c.boneMesh = binding(l.id,at: time-Double(k)*fx.echoDelay) }
                c.shiftTiming(by: Double(k) * fx.echoDelay, duration: p.duration)
                c.inPoint = l.inPoint
                c.transform.opacity = c.transform.opacity.mapped { $0 * pow(max(0, min(1, fx.echoDecay)), Double(k)) }
                out.append(c)
            }
        }
        q.layers = out
        return q
    }

    struct LightGPU { var posType: SIMD4<Float>; var dirCone: SIMD4<Float>; var color: SIMD4<Float>; var falloff: SIMD4<Float> }
    struct ShadowCasterGPU { var inv0: SIMD4<Float>; var inv1: SIMD4<Float>; var plane: SIMD4<Float>; var halfSize: SIMD4<Float> }
    struct LightPass {
        var w0: SIMD4<Float>; var w1: SIMD4<Float>; var w2: SIMD4<Float>; var normal: SIMD4<Float>
        var camPos: SIMD4<Float>; var tex: SIMD4<Float>; var count: SIMD4<UInt32>
    }

    /// Active lights in world space for this frame.
    static func lightsGPU(_ p: Project, time: Double) -> [LightGPU] {
        p.layers.compactMap { l -> LightGPU? in
            guard l.content == .light, l.isActive(at: time), let o = l.light else { return nil }
            let t = l.transform
            let pos = t.position.value(at: time)
            let R = CameraState.rotation(x: t.rotationX.value(at: time), y: t.rotationY.value(at: time), z: t.rotation.value(at: time))
            let dir = R * SIMD4(0, 0, 1, 0)         // lights point down +z (into the scene) before rotation
            let c = o.color.value(at: time), k = o.intensity.value(at: time) / 100
            let type: Float = [LightType.point: 0, .spot: 1, .parallel: 2, .ambient: 3][o.type] ?? 0
            return LightGPU(posType: SIMD4(Float(pos.x), Float(pos.y), Float(t.positionZ.value(at: time)), type),
                            dirCone: SIMD4(Float(dir.x), Float(dir.y), Float(dir.z), Float(cos(o.coneAngle.value(at: time) / 2 * .pi / 180))),
                            color: SIMD4(Float(c.r * k), Float(c.g * k), Float(c.b * k), Float(o.coneFeather.value(at: time) / 100)),
                            falloff: SIMD4(Float(o.falloffRadius.value(at: time)), o.castsShadows ? Float(o.shadowDarkness / 100) : 0, 0, 0))
        }
    }

    private func encodeLights(cb: MTLCommandBuffer, src: MTLTexture, dst: MTLTexture, layer: Layer, time: Double, camera: CameraState,
                              lights: [LightGPU], density: Double, ext: Vec2) {
        let W = Self.layerWorld(layer, time: time)
        let camPos = camera.world * SIMD4(0, 0, 0, 1)
        var n = W * SIMD4(0, 0, -1, 0)
        let len = max(simd_length(SIMD3(n.x, n.y, n.z)), 1e-9)
        n /= len
        func f4(_ v: SIMD4<Double>) -> SIMD4<Float> { SIMD4(Float(v.x), Float(v.y), Float(v.z), Float(v.w)) }
        var pass = LightPass(w0: f4(W.columns.0), w1: f4(W.columns.1), w2: f4(W.columns.3), normal: f4(n), camPos: f4(camPos),
                             tex: SIMD4(Float(1 / density), 0, Float(-ext.x + 0.5 / density), Float(-ext.y + 0.5 / density)),
                             count: SIMD4(UInt32(min(lights.count, 8)), 0, 0, 0))
        var ls = Array(lights.prefix(8))
        // Shadow casters (not the layer itself).
        let casters = shadowCasters.filter { $0.id != layer.id }.prefix(4)
        var cs = casters.map(\.gpu)
        if cs.isEmpty { cs = [ShadowCasterGPU(inv0: .zero, inv1: .zero, plane: .zero, halfSize: .zero)] }
        pass.count.y = UInt32(casters.count)
        pass.count.z = layer.acceptsShadows ? 1 : 0
        guard let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(lightPSO)
        enc.setTexture(src, index: 0)
        enc.setTexture(dst, index: 1)
        for k in 0..<4 { enc.setTexture(k < casters.count ? casters[casters.startIndex + k].tex : whiteTexture, index: 2 + k) }
        enc.setBytes(&pass, length: MemoryLayout<LightPass>.stride, index: 0)
        enc.setBytes(&ls, length: MemoryLayout<LightGPU>.stride * max(ls.count, 1), index: 1)
        enc.setBytes(&cs, length: MemoryLayout<ShadowCasterGPU>.stride * cs.count, index: 2)
        dispatch(enc, pso: lightPSO, width: dst.width, height: dst.height)
        enc.endEncoding()
    }

    /// Motion-blur samples allowed in the live preview (nil = the project's full setting, used by export).
    nonisolated(unsafe) static var allowPrecompProxy = true
    nonisolated(unsafe) static var blurSampleCap: Int? = 8

    /// Max side of an offscreen layer buffer.
    static let maxLayerTexture = 4096

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { throw RenderError.noDevice }
        self.device = device
        self.queue = queue
        guard let lib = device.makeDefaultLibrary() else { throw RenderError.pipeline("no default library") }
        func compute(_ name: String) throws -> MTLComputePipelineState {
            guard let f = lib.makeFunction(name: name) else { throw RenderError.pipeline(name) }
            return try device.makeComputePipelineState(function: f)
        }
        clearPSO = try compute("clearComp")
        drawPSO = try compute("drawLayer")
        glyphPSO = try compute("drawGlyphTxt1")
        lightPSO = try compute("applyLights")
        toBGRAPSO = try compute("compToBGRA")
        fx = try EffectGPU(device: device, library: lib)
        let rp = MTLRenderPipelineDescriptor()
        rp.vertexFunction = lib.makeFunction(name: "displayVertex")
        rp.fragmentFunction = lib.makeFunction(name: "displayFragment")
        rp.colorAttachments[0].pixelFormat = .bgra8Unorm
        displayPSO = try device.makeRenderPipelineState(descriptor: rp)
        loader = MTKTextureLoader(device: device)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        d.usage = [.shaderRead]
        guard let dummy = device.makeTexture(descriptor: d) else { throw RenderError.texture }
        var zero: UInt32 = 0
        dummy.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &zero, bytesPerRow: 4)
        self.dummy = dummy
    }

    func makePool() -> TexturePool { TexturePool(device: device) }

    // MARK: Textures

    func makeCompTexture(width: Int, height: Int, shared: Bool = false) -> MTLTexture? {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.compFormat, width: max(1, width), height: max(1, height), mipmapped: false)
        d.usage = [.shaderRead, .shaderWrite]
        d.storageMode = shared ? .shared : .private
        return device.makeTexture(descriptor: d)
    }

    func imageTexture(url: URL) -> MTLTexture? {
        let key = url.path
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let t = imageCache[key] {
            imageOrder.removeAll { $0 == key }; imageOrder.append(key)
            return t
        }
        var t = try? loader.newTexture(URL: url, options: [
            .SRGB: false,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .origin: MTKTextureLoader.Origin.topLeft,
            .allocateMipmaps: true,
            .generateMipmaps: true,
        ])
        if t == nil, let image = UIImage(contentsOfFile: url.path) {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.preferredRange = .standard
            let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
            let factor = min(1, 8192 / max(pixels.width, pixels.height))
            let size = CGSize(width: max(1, pixels.width * factor), height: max(1, pixels.height * factor))
            let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            if let cg = normalized.cgImage {
                t = try? loader.newTexture(cgImage: cg, options: [.SRGB: false, .origin: MTKTextureLoader.Origin.topLeft])
            }
        }
        if let t {
            let cost = max(t.allocatedSize, t.width * t.height * 4 * 4 / 3)
            while !imageOrder.isEmpty && (imageCacheBytes + cost > Self.imageCacheBudget || imageOrder.count >= 64) {
                let old = imageOrder.removeFirst()
                if let texture = imageCache.removeValue(forKey: old) { imageCacheBytes -= max(texture.allocatedSize, texture.width * texture.height * 4 * 4 / 3) }
            }
            if cost <= Self.imageCacheBudget { imageCache[key] = t; imageOrder.append(key); imageCacheBytes += cost }
        }
        return t
    }

    func clearImageCache() {
        cacheLock.lock(); imageCache.removeAll(); imageOrder.removeAll(); imageCacheBytes = 0; cacheLock.unlock()
    }

    // MARK: Transforms

    /// Sum of transform-stage effects (shake) at `time`.
    static func transformOffsets(_ layer: Layer, time: Double) -> (dx: Double, dy: Double, dr: Double, ds: Double) {
        var o = (dx: 0.0, dy: 0.0, dr: 0.0, ds: 1.0)
        for e in layer.effects where e.isEnabled {
            guard let def = EffectRegistry.definition(e.typeID), case .transform(let f) = def.stage else { continue }
            let r = f(e, time)
            o.dx += r.0; o.dy += r.1; o.dr += r.2; o.ds *= r.3
        }
        return o
    }

    /// Forward affine (layer local px, centered) -> comp px at render scale.
    static func layerMatrix(_ layer: Layer, time: Double, renderScale: Double, includeEffects: Bool = true) -> simd_double3x3 {
        let t = layer.transform
        let fx = includeEffects ? transformOffsets(layer, time: time) : (0, 0, 0, 1)
        let pos = t.position.value(at: time) + Vec2(fx.0, fx.1)
        let anc = t.anchor.value(at: time)
        let sc = t.scale.value(at: time) * fx.3
        let rot = (t.rotation.value(at: time) + fx.2) * .pi / 180
        let T = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(pos.x, pos.y, 1)))
        let R = simd_double3x3(columns: (SIMD3(cos(rot), sin(rot), 0), SIMD3(-sin(rot), cos(rot), 0), SIMD3(0, 0, 1)))
        let S = simd_double3x3(diagonal: SIMD3(sc.x / 100, sc.y / 100, 1))
        let A = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-anc.x, -anc.y, 1)))
        let RS = simd_double3x3(diagonal: SIMD3(renderScale, renderScale, 1))
        return RS * T * R * S * A
    }

    /// Path drawn for a shape layer: its own bezier, or the primitive converted when a stroke is on.
    static func shapePath(_ layer: Layer, time: Double) -> BezierPath? {
        guard case .shape(let k) = layer.content else { return nil }
        if layer.shapeContents != nil { return BezierPath(vertices: []) } // compound path drawn by drawShapePath
        // Shape operators need a real path for every kind.
        if let ops = layer.shapeOps, !ops.isEmpty {
            let s = layer.size.value(at: time)
            let base: BezierPath?
            switch k {
            case .path: base = layer.path?.value(at: time)
            case .ellipse: base = .ellipse(size: s)
            case .rectangle: base = .rectangle(size: s)
            case .polygon: base = .polygon(size: s, sides: Int(layer.sides.value(at: time).rounded()), inner: nil)
            case .star: base = .polygon(size: s, sides: Int(layer.sides.value(at: time).rounded()), inner: layer.innerRatio.value(at: time))
            }
            return base.map { ShapeOpsMath.apply(ops, to: $0, time: time) }
        }
        if k == .path { return layer.path?.value(at: time) }
        guard layer.stroke.enabled || layer.effects.contains(where: { $0.isEnabled && $0.typeID == "awi23.drawProgress" }) else { return nil }
        let s = layer.size.value(at: time)
        switch k {
        case .ellipse: return .ellipse(size: s)
        case .rectangle: return .rectangle(size: s)
        case .polygon: return .polygon(size: s, sides: Int(layer.sides.value(at: time).rounded()), inner: nil)
        case .star: return .polygon(size: s, sides: Int(layer.sides.value(at: time).rounded()), inner: layer.innerRatio.value(at: time))
        default: return nil
        }
    }

    static func layerHalfSize(_ layer: Layer, time: Double) -> Vec2 {
        if let contents = layer.shapeContents, case .shape = layer.content {
            var reach = Vec2(0.5, 0.5)
            for draw in ShapeContentsRenderer.evaluate(contents, time: time) {
                for p in draw.paths {
                    let operated = layer.shapeOps.map { ShapeOpsMath.apply($0, to: p.mapped(draw.matrix), time: time) } ?? p.mapped(draw.matrix)
                    let b = operated.bounds
                    let sw = draw.style.stroke.enabled ? draw.style.stroke.width.value(at: time) / 2 : 0
                    let sc = max(simd_length(draw.matrix.columns.0), simd_length(draw.matrix.columns.1))
                    reach = Vec2(max(reach.x, max(abs(b.min.x), abs(b.max.x)) + sw * sc),
                                 max(reach.y, max(abs(b.min.y), abs(b.max.y)) + sw * sc))
                }
            }
            return layer.shapeOps?.repeater.map { ShapeOpsMath.reach($0, base: reach, time: time) } ?? reach
        }
        if let ops = layer.shapeOps, !ops.isEmpty, case .shape = layer.content, let path = shapePath(layer, time: time) {
            let b = path.bounds
            let sw = layer.stroke.enabled ? layer.stroke.width.value(at: time) / 2 : 0
            let base = Vec2(max(abs(b.min.x), abs(b.max.x)) + sw, max(abs(b.min.y), abs(b.max.y)) + sw)
            return ops.repeater.map { ShapeOpsMath.reach($0, base: base, time: time) } ?? base
        }
        if case .shape(.path) = layer.content, let path = layer.path?.value(at: time) {
            let b = path.bounds
            let sw = layer.stroke.enabled ? layer.stroke.width.value(at: time) / 2 : 0
            return Vec2(max(abs(b.min.x), abs(b.max.x)) + sw, max(abs(b.min.y), abs(b.max.y)) + sw)
        }
        if case .text = layer.content, let b = textBounds(layer, time: time) {
            return Vec2(max(abs(Double(b.minX)), abs(Double(b.maxX))), max(abs(Double(b.minY)), abs(Double(b.maxY))))
        }
        let s = layer.size.value(at: time)
        return Vec2(abs(s.x) / 2, abs(s.y) / 2)
    }

    // MARK: Compositing

    /// Encodes the full composition at `time` into `comp` (size = project size * renderScale).
    /// `pool` supplies scratch textures; the caller recycles it once the command buffer has finished
    /// (or rotates pools for in-flight frames).
    func encode(project rawProject: Project, time: Double, renderScale: Double, into comp: MTLTexture,
                commandBuffer cb: MTLCommandBuffer, pool: TexturePool, mediaURL: (String) -> URL) {
        // Preview, preset thumbnails, and export share this renderer. Protect per-frame state and
        // restore it after recursive group/precomp renders as well as after top-level renders.
        encodeLock.lock()
        let savedLibrary = precompLibrary, savedPool = currentPool, savedDepth = currentDepth, savedBeats = textBeats
        let savedCasters = shadowCasters, savedParts = groupParts, savedCameras = groupCameras
        defer {
            precompLibrary = savedLibrary; currentPool = savedPool; currentDepth = savedDepth; textBeats = savedBeats
            shadowCasters = savedCasters; groupParts = savedParts; groupCameras = savedCameras
            encodeLock.unlock()
        }
        // Expressions are baked into plain values for this frame first.
        let resolved = ExpressionResolver.resolve(rawProject, time: time)
        // Echo needs parenting baked over time (costly); everything else bakes just this frame.
        let hasEcho = resolved.layers.contains { ($0.timeFX?.echoCount ?? 0) > 0 }
        let project = hasEcho ? Self.expandEchoes(Self.resolveParentingAnimated(resolved),meshSource: rawProject,time: time) : Self.resolveParenting(resolved, time: time, meshSource: rawProject)
        var shutterProjects: [Double: Project] = [:]
        func samplePlacement(_ layer: Layer, at sampleTime: Double) -> simd_double3x3 {
            let sample: Project
            if let cached = shutterProjects[sampleTime] { sample = cached }
            else {
                sample = Self.resolveParenting(ExpressionResolver.resolve(rawProject, time: sampleTime), time: sampleTime)
                shutterProjects[sampleTime] = sample
            }
            let sampledLayer = sample.layers.first { $0.id == layer.id } ?? layer
            return Self.placementMatrix(sampledLayer, camera: Self.activeCamera(sample, time: sampleTime), time: sampleTime, renderScale: renderScale)
        }
        precompLibrary = project.precomps.isEmpty ? precompLibrary : project.precomps
        currentPool = pool
        textBeats = project.markers + (project.detectedBeatTimes ?? [])
        currentDepth = project.precompDepth ?? 0
        var bg = project.background.simd
        if let enc = cb.makeComputeCommandEncoder() {
            enc.setComputePipelineState(clearPSO)
            enc.setTexture(comp, index: 0)
            enc.setBytes(&bg, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            dispatch(enc, pso: clearPSO, width: comp.width, height: comp.height)
            enc.endEncoding()
        }

        // Bottom-up, with runs of 3D layers depth-sorted through the active camera (AE behaviour).
        let camera = Self.activeCamera(project, time: time)
        let lights = Self.lightsGPU(project, time: time)
        shadowCasters = []
        if lights.contains(where: { $0.falloff.y > 0 }) {
            for l in project.layers where l.is3D && l.castsShadows && l.isActive(at: time) && l.isVisible {
                let W = Self.layerWorld(l, time: time)
                let inv = W.inverse
                var n = W * SIMD4(0, 0, 1, 0)
                n /= max(simd_length(SIMD3(n.x, n.y, n.z)), 1e-9)
                let o = W * SIMD4(0, 0, 0, 1)
                let hs = Self.layerHalfSize(l, time: time)
                var tex: MTLTexture = whiteTexture
                if case .image(let t)? = sourceTexture(l, sourceTime: l.sourceTime(at: time), time: time, density: 0.5, cb: cb, mediaURL: mediaURL) { tex = t }
                else if case .model(let t)? = sourceTexture(l, sourceTime: l.sourceTime(at: time), time: time, density: 0.5, cb: cb, mediaURL: mediaURL) { tex = t }
                let gpu = ShadowCasterGPU(inv0: SIMD4(Float(inv[0][0]), Float(inv[1][0]), Float(inv[2][0]), Float(inv[3][0])),
                                          inv1: SIMD4(Float(inv[0][1]), Float(inv[1][1]), Float(inv[2][1]), Float(inv[3][1])),
                                          plane: SIMD4(Float(n.x), Float(n.y), Float(n.z), Float(n.x * o.x + n.y * o.y + n.z * o.z)),
                                          halfSize: SIMD4(Float(hs.x), Float(hs.y), 0, 0))
                shadowCasters.append((l.id, gpu, tex))
            }
        }
        let anySolo = project.layers.contains { $0.isSolo }
        // Layers used as a track matte by the layer below them don't draw themselves.
        var matteSources: [UUID: Layer] = [:], hiddenMattes = Set<UUID>()
        for (i, l) in project.layers.enumerated() where l.trackMatte != .none && i > 0 {
            let m = project.layers[i - 1]
            // Only layers that draw pixels can be mattes (a camera / light / audio above means "no matte").
            if m.content == .camera || m.content == .light || m.isAudioOnly { continue }
            matteSources[l.id] = m; hiddenMattes.insert(m.id)
        }
        // Clipping masks: the layer below cuts this one out and keeps drawing itself.
        for (i, l) in project.layers.enumerated() where l.clipToBelow && l.trackMatte == .none && i + 1 < project.layers.count {
            let m = project.layers[i + 1]
            if m.content == .camera || m.content == .light || m.isAudioOnly { continue }
            matteSources[l.id] = m
        }
        // Group parts render inside their group (so the group's mask / effects / transform hit them all at once).
        let groupIDs = Set(project.layers.filter { $0.isGroup }.map(\.id))
        var parts: [UUID: [Layer]] = [:]
        for l in project.layers { if let g = l.groupID, groupIDs.contains(g) { parts[g, default: []].append(l) } }
        groupParts = parts
        groupCameras = project.layers.filter { $0.content == .camera }
        let active = project.layers.filter { l in
            if let g = l.groupID, groupIDs.contains(g) { return false }
            return l.isActive(at: time) && !hiddenMattes.contains(l.id) && (!anySolo || l.isSolo || l.content == .camera)
        }
        let globalTime = time
        for layer in Self.drawOrder(active, camera: camera, time: time) {
            let scratchScope = pool.beginEncodingScope()
            defer { pool.endEncodingScope(scratchScope) }
            // Posterize time / freeze frame evaluate this layer at its own clock.
            let time = layer.timeFX?.localTime(globalTime) ?? globalTime
            if case .audio = layer.content { continue }
            if case .camera = layer.content { continue }
            if case .light = layer.content { continue }
            if layer.isNull { continue }
            if !layer.is3D && camera.projects2DDepth && layer.transform.positionZ.value(at: time) - camera.world.columns.3.z <= max(1, abs(camera.zoom) * 0.01) { continue }
            let opacity = layer.transform.opacity.value(at: time) / 100
            if opacity <= 0 { continue }
            if layer.boneMesh != nil,project.blurs(layer),
               encodeSkinnedShutter(layer,project: project,time: time,renderScale: renderScale,comp: comp,cb: cb,pool: pool,mediaURL: mediaURL) { continue }
            if layer.effects.contains(where: { $0.isEnabled && $0.typeID == "awi18.displacementMap" && $0.choice("target") == 1 }) {
                encodeBackdropDisplacement(layer, matte: matteSources[layer.id], project: project, time: time, renderScale: renderScale,
                                           opacity: opacity, comp: comp, cb: cb, pool: pool, mediaURL: mediaURL)
                continue
            }
            if let matte = matteSources[layer.id] {
                encodeMatted(layer, matte: matte, project: project, time: time, renderScale: renderScale, comp: comp, cb: cb, pool: pool, mediaURL: mediaURL)
                continue
            }
            let pixelFX = layer.effects.filter { e in
                guard e.isEnabled, let d = EffectRegistry.definition(e.typeID) else { return false }
                return !d.isTransformEffect
            }

            if case .adjustment = layer.content {
                guard layer.effects.contains(where: { $0.isEnabled }) else { continue }
                encodeAdjustment(layer, effects: layer.effects.filter(\.isEnabled), time: time, renderScale: renderScale, opacity: opacity,
                                 comp: comp, cb: cb, pool: pool,
                                 shutter: project.blurs(layer) ? project.shutterAngle / 360 / max(project.fps, 1) : 0,
                                 sampleCount: min(project.blurSamples, Renderer.blurSampleCap ?? project.blurSamples))
                continue
            }

            // A 3D model is an object in the scene: it renders through the scene camera over the whole frame.
            if layer.content == .model, layer.is3D, let options = layer.model3D {
                let placement = Self.modelPlacement(layer, project: project, camera: camera, time: time)
                let mw = min(2048, comp.width), mh = min(2048, comp.height)
                var blurred: MTLTexture?
                if project.blurs(layer) {
                    // Each sample renders the model where it is at that moment of the shutter (camera included).
                    let open = project.shutterOpen
                    let n = max(2, min(Renderer.blurSampleCap.map { min($0, 8) } ?? 8, project.blurSamples))
                    let shots: [MTLTexture] = (0..<n).compactMap { k in
                        let t = time + open.start + open.length * Double(k) / Double(n - 1)
                        let sample = Self.resolveParenting(ExpressionResolver.resolve(rawProject, time: t), time: t)
                        let at = sample.layers.first { $0.id == layer.id } ?? layer
                        let p = Self.modelPlacement(at, project: sample, camera: Self.activeCamera(sample, time: t), time: t)
                        return ModelRenderer.shared?.render(options, time: t, width: mw, height: mh, cb: cb, pool: pool, placement: p, mediaURL: mediaURL)
                    }
                    if shots.count == n {
                        let whole = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(mw) / 2, Double(mh) / 2, 1)))
                        blurred = shutterAverage(n, comp: comp, pool: pool, cb: cb) { k, target in
                            drawQuad(cb: cb, target: target, matrix: whole, halfSize: Vec2(Double(mw) / 2, Double(mh) / 2), aa: 1, opacity: 1,
                                     layer: layer, time: time, source: .model(shots[k]), premultipliedImage: true, blendOverride: .normal)
                        }
                    }
                }
                if var picture = blurred ?? ModelRenderer.shared?.render(options, time: time, width: mw, height: mh, cb: cb,
                                                              pool: pool, placement: placement, mediaURL: mediaURL) {
                    for e in layer.effects where e.isEnabled {
                        guard let d = EffectRegistry.definition(e.typeID), !d.isTransformEffect, case .pixels(let run) = d.stage else { continue }
                        picture = run(EffectContext(gpu: fx, cb: cb, input: picture, effect: e, time: time, unit: renderScale, pool: pool))
                    }
                    // Masks cut the model like any layer: they live in the layer's own plane.
                    let modelMasks = layer.masks.filter { $0.mode != .none && !$0.effectsOnly }
                    if !modelMasks.isEmpty {
                        let cut = pool.acquire(width: picture.width, height: picture.height)
                        fx.run("fxCopy", cb, textures: [picture, cut], grid: cut)
                        let M = Self.placementMatrix(layer, camera: camera, time: time, renderScale: renderScale)
                        // Mask paths are drawn with an affine map: scale the projection so the layer's center sits at depth 1 (exact head-on, close when turned).
                        let w0 = max(1e-6, (M * SIMD3(0, 0, 1)).z)
                        let scaleToPicture = simd_double3x3(diagonal: SIMD3(Double(picture.width) / Double(comp.width), Double(picture.height) / Double(comp.height), 1))
                        PathGPU.shared?.applyMasks(cb: cb, layer: cut, masks: modelMasks, time: time, matrix: scaleToPicture * (M * (1 / w0)), aa: 1, pool: pool)
                        picture = cut
                    }
                    // Camera depth of field: the model blurs by how far it is from the focus distance.
                    let dofModel = Self.dofSigma(layer, camera: camera, time: time) * renderScale
                    if dofModel > 0.5, let blur = EffectRegistry.definition("ae.gaussianBlur"), case .pixels(let run) = blur.stage {
                        let e = EffectInstance(typeID: "ae.gaussianBlur", params: ["blurriness": .number(Animated(dofModel))])
                        picture = run(EffectContext(gpu: fx, cb: cb, input: picture, effect: e, time: time, unit: 1, pool: pool))
                    }
                    let whole = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(comp.width) / 2, Double(comp.height) / 2, 1)))
                    drawQuad(cb: cb, target: comp, matrix: whole, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 1, opacity: opacity,
                             layer: layer, time: time, source: .model(picture), premultipliedImage: true)
                }
                continue
            }

            // Real 3D text (Text Studio 3D tab): extruded, bevelled letters through the scene camera; the letter
            // animators drive each letter's real 3D transform.
            if case .text = layer.content, let options3D = layer.text?.text3D, let text3D = Text3DRenderer.shared {
                let mw = min(2048, comp.width), mh = min(2048, comp.height)
                let shotSize = CGSize(width: mw, height: mh)
                var blurred: MTLTexture?
                if project.blurs(layer) {
                    let open = project.shutterOpen
                    let n = max(2, min(Renderer.blurSampleCap.map { min($0, 8) } ?? 8, project.blurSamples))
                    let shots: [MTLTexture] = (0..<n).compactMap { k in
                        let t = time + open.start + open.length * Double(k) / Double(n - 1)
                        let sample = Self.resolveParenting(ExpressionResolver.resolve(rawProject, time: t), time: t)
                        let at = sample.layers.first { $0.id == layer.id } ?? layer
                        let p = Self.modelPlacement(at, project: sample, camera: Self.activeCamera(sample, time: t), time: t)
                        return text3D.render(glyphs: Self.text3DGlyphs(at, time: t, beats: textBeats), options: at.text?.text3D ?? options3D,
                                             time: t, placement: p, size: shotSize, pool: pool)
                    }
                    if shots.count == n {
                        let whole = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(mw) / 2, Double(mh) / 2, 1)))
                        blurred = shutterAverage(n, comp: comp, pool: pool, cb: cb) { k, target in
                            drawQuad(cb: cb, target: target, matrix: whole, halfSize: Vec2(Double(mw) / 2, Double(mh) / 2), aa: 1, opacity: 1,
                                     layer: layer, time: time, source: .model(shots[k]), premultipliedImage: true, blendOverride: .normal)
                        }
                    }
                }
                let placement = Self.modelPlacement(layer, project: project, camera: camera, time: time)
                if var picture = blurred ?? text3D.render(glyphs: Self.text3DGlyphs(layer, time: time, beats: textBeats), options: options3D,
                                                         time: time, placement: placement, size: shotSize, pool: pool) {
                    for e in layer.effects where e.isEnabled {
                        guard let d = EffectRegistry.definition(e.typeID), !d.isTransformEffect, case .pixels(let run) = d.stage else { continue }
                        picture = run(EffectContext(gpu: fx, cb: cb, input: picture, effect: e, time: time, unit: renderScale, pool: pool))
                    }
                    let dof3D = Self.dofSigma(layer, camera: camera, time: time) * renderScale
                    if dof3D > 0.5, let blur = EffectRegistry.definition("ae.gaussianBlur"), case .pixels(let run) = blur.stage {
                        let e = EffectInstance(typeID: "ae.gaussianBlur", params: ["blurriness": .number(Animated(dof3D))])
                        picture = run(EffectContext(gpu: fx, cb: cb, input: picture, effect: e, time: time, unit: 1, pool: pool))
                    }
                    let whole = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(comp.width) / 2, Double(comp.height) / 2, 1)))
                    drawQuad(cb: cb, target: comp, matrix: whole, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 1, opacity: opacity,
                             layer: layer, time: time, source: .model(picture), premultipliedImage: true)
                }
                continue
            }

            let M = Self.placementMatrix(layer, camera: camera, time: time, renderScale: renderScale)
            if abs(M.determinant) < 1e-12 || !(0..<3).allSatisfy({ column in (0..<3).allSatisfy { M[column][$0].isFinite } }) { continue }
            let hs = Self.layerHalfSize(layer, time: time)
            guard hs.x.isFinite, hs.y.isFinite else { continue }
            // Text: the buffer and motion-blur checks cover the animated letters (+ stroke / glow / shadow / letter
            // effect room), so nothing clips. `hs` stays the layout size (effects measure the layer by it).
            var reach = hs
            if case .text = layer.content, let rb = Self.textRenderBounds(layer, time: time, beats: textBeats) {
                let rx = max(abs(Double(rb.minX)), abs(Double(rb.maxX))), ry = max(abs(Double(rb.minY)), abs(Double(rb.maxY)))
                if rx.isFinite, ry.isFinite { reach = Vec2(max(hs.x, rx), max(hs.y, ry)) }
            }
            // A 3D layer behind (or touching) the camera isn't drawn, like AE: projecting it would explode its bounds.
            if layer.is3D {
                let near = 1.0
                let behind = [(-hs.x, -hs.y), (hs.x, -hs.y), (hs.x, hs.y), (-hs.x, hs.y)].contains { c in
                    (M * SIMD3(c.0, c.1, 1)).z <= near * 1e-3
                }
                if behind { continue }
            }
            let pxPerLocal = Self.pixelsPerLocal(M, at: layer.transform.anchor.value(at: time))
            let dof = Self.dofSigma(layer, camera: camera, time: time) * renderScale

            // Text on path uses the first mask as its path (AE), so that mask doesn't cut the text.
            let pathMaskID = layer.text?.onPath == true ? layer.masks.first?.id : nil
            let masks = layer.masks.filter { $0.mode != .none && !$0.effectsOnly && $0.id != pathMaskID }
            let effectMasks = layer.masks.filter { $0.mode != .none && $0.effectsOnly }
            let extrude = layer.is3D && layer.content != .model ? max(0, layer.extrude.value(at: time)) : 0
            // Motion blur: placements across the shutter interval (empty when the layer doesn't move).
            var blurMatrices: [simd_double3x3] = []
            let autoSmooth = project.smoothMotion && layer.effects.contains { $0.isEnabled && (EffectRegistry.definition($0.typeID)?.isTransformEffect ?? false) }
            if (project.blurs(layer) || autoSmooth) && extrude <= 0.5 {
                let shutter = project.shutterAngle / 360 / max(project.fps, 1)
                // Automatic smoothing stays centered; real motion blur follows the shutter phase.
                let open = project.blurs(layer) ? project.shutterOpen.start : -shutter / 2
                func corner(_ m: simd_double3x3, _ x: Double, _ y: Double) -> SIMD2<Double> {
                    let p = m * SIMD3(x, y, 1); return SIMD2(p.x, p.y) / max(p.z, 1e-6)
                }
                // Adaptive: as many samples as the motion needs (≈1 per 1.5 px of travel), capped by the quality setting.
                // Detect the path through the shutter, not just its endpoints: a full spin or
                // out-and-back move can have identical start/end placements and still need blur.
                let probes = (0...4).map { samplePlacement(layer, at: time + open + Double($0) / 4 * shutter) }
                let travel = [(-reach.x, -reach.y), (reach.x, reach.y), (reach.x, -reach.y), (-reach.x, reach.y)].map { c in
                    (1..<probes.count).reduce(0.0) { distance, k in
                        distance + simd_length(corner(probes[k], c.0, c.1) - corner(probes[k - 1], c.0, c.1))
                    }
                }.max() ?? 0
                if travel.isFinite, travel > 0.5 {
                    let cap = Renderer.blurSampleCap.map { min($0, project.blurSamples) } ?? project.blurSamples
                    let n = max(2, min(cap, Int(min(Double(max(2, cap)), (travel / 1.5).rounded(.up))) + 1))
                    blurMatrices = (0..<n).map { k in
                        samplePlacement(layer, at: time + open + Double(k) / Double(n - 1) * shutter)
                    }
                }
            }
            let lit = layer.is3D && !lights.isEmpty && layer.content != .model
            let needsLocal = layer.boneMesh != nil || !pixelFX.isEmpty || !masks.isEmpty || layer.cutout != nil || dof > 0.5 || extrude > 0.5 || !blurMatrices.isEmpty || lit
            if !needsLocal, let path = Self.shapePath(layer, time: time) {
                drawShapePath(cb: cb, target: comp, matrix: M, layer: layer, path: path, time: time,
                              opacity: opacity, blend: layer.blendMode, aa: 1 / pxPerLocal)
                continue
            }
            if !needsLocal, case .text = layer.content {
                drawText(cb: cb, target: comp, matrix: M, density: pxPerLocal, layer: layer, time: time,
                         opacity: opacity, blend: layer.blendMode)
                continue
            }
            if !needsLocal {
                guard let source = sourceTexture(layer, sourceTime: layer.sourceTime(at: time), time: time, density: pxPerLocal, cb: cb, mediaURL: mediaURL) else { continue }
                drawQuad(cb: cb, target: comp, matrix: M, halfSize: hs, aa: 1 / pxPerLocal, opacity: opacity,
                         layer: layer, time: time, source: source, premultipliedImage: false)
                continue
            }

            // Effects path: render the layer in its own (local, unrotated) buffer, run the stack, then place it.
            var rawMargin = pixelFX.reduce(0.0) { acc, e in
                if e.typeID == "ae.motionTile" && !e.bool("manualOutput") { return acc }
                return acc + (EffectRegistry.definition(e.typeID).map { $0.expandedMargin?(e, time, hs * 2) ?? $0.margin(e, time) } ?? 0)
            }
                + (dof > 0.5 ? dof * 3 / max(pxPerLocal, 1e-4) : 0)
            if pixelFX.contains(where: { $0.typeID == "ae.motionTile" && !$0.bool("manualOutput") }) {
                let inverse = M.inverse
                let width = Double(project.width) * renderScale, height = Double(project.height) * renderScale
                let corners = [SIMD3(0.0, 0, 1), SIMD3(width, 0, 1), SIMD3(0.0, height, 1), SIMD3(width, height, 1)]
                for corner in corners {
                    let local = inverse * corner
                    if abs(local.z) > 1e-8 {
                        let x = abs(local.x / local.z), y = abs(local.y / local.z)
                        if x.isFinite && y.isFinite { rawMargin = max(rawMargin, x - hs.x + 2, y - hs.y + 2) }
                    }
                }
            }
            if let mesh = layer.boneMesh, let matrices = mesh.frameMatrices {
                let bounds = mesh.reach(matrices: matrices)
                rawMargin += max(0,bounds.x-hs.x,bounds.y-hs.y)
            }
            // Glow / shadow room beyond what the screen can show is never seen: cap it to the comp size.
            let compReach = Double(max(project.width, project.height)) / max(pxPerLocal, 1e-4)
            // Glow room past half a screen is never visible and only costs memory (big glows crashed phones).
            let hasExpandedOutput = layer.boneMesh != nil || pixelFX.contains { EffectRegistry.definition($0.typeID)?.expandedMargin != nil }
            let marginLimit = hasExpandedOutput ? 20000 : compReach * 0.5
            let margin = rawMargin.isFinite ? min(max(0, rawMargin), 20000, marginLimit) : 0
            guard hs.x.isFinite, hs.y.isFinite, pxPerLocal.isFinite else { continue }
            let ext = Vec2(min(max(reach.x, 0.5), 1e6) + margin, min(max(reach.y, 0.5), 1e6) + margin)
            var density = min(1.5, max(0.05, pxPerLocal))
            let maxSide = max(ext.x, ext.y) * 2 * density
            if maxSide > Double(Self.maxLayerTexture) { density *= Double(Self.maxLayerTexture) / maxSide }
            let tw = max(1, Int(ceil(ext.x * 2 * density))), th = max(1, Int(ceil(ext.y * 2 * density)))
            let local = pool.acquire(width: tw, height: th)
            fx.run("fxClear", cb, textures: [local], grid: local)
            // texture px -> layer local px
            let toLocal = simd_double3x3(columns: (SIMD3(1 / density, 0, 0), SIMD3(0, 1 / density, 0), SIMD3(-ext.x, -ext.y, 1)))
            if let path = Self.shapePath(layer, time: time) {
                drawShapePath(cb: cb, target: local, matrix: toLocal.inverse, layer: layer, path: path, time: time,
                              opacity: 1, blend: .normal, aa: 1 / density)
            } else if case .text = layer.content {
                drawText(cb: cb, target: local, matrix: toLocal.inverse, density: density, layer: layer, time: time,
                         opacity: 1, blend: .normal)
            } else {
                guard let source = sourceTexture(layer, sourceTime: layer.sourceTime(at: time), time: time, density: pxPerLocal, cb: cb, mediaURL: mediaURL) else { continue }
                drawQuad(cb: cb, target: local, matrix: toLocal.inverse, halfSize: hs, aa: 1 / density, opacity: 1,
                         layer: layer, time: time, source: source, premultipliedImage: false, blendOverride: .normal)
            }

            // AE order: masks first, then effects.
            if !masks.isEmpty {
                PathGPU.shared?.applyMasks(cb: cb, layer: local, masks: masks, time: time, matrix: toLocal.inverse,
                                           aa: 1 / density, pool: pool)
            }
            if layer.cutout != nil {
                applyCutout(cb: cb, layer: local, layerModel: layer, sourceTime: layer.sourceTime(at: time),
                            matrix: toLocal.inverse, halfSize: hs, mediaURL: mediaURL)
            }
            var current = local
            if let mesh = layer.boneMesh,let matrices = mesh.frameMatrices {
                let warped = pool.acquire(width: local.width,height: local.height)
                if BoneMeshGPU.encode(mesh,matrices: matrices,input: local,output: warped,unit: density,commandBuffer: cb,device: device) { current = warped }
            }
            let beforeEffects = current
            for e in pixelFX {
                guard let def = EffectRegistry.definition(e.typeID), case .pixels(let run) = def.stage else { continue }
                var ctx = EffectContext(gpu: fx, cb: cb, input: current, effect: e, time: time, unit: density, pool: pool)
                ctx.layerPixels = SIMD2(hs.x * 2 * density, hs.y * 2 * density)
                ctx.compositionPixels = SIMD2(Double(project.width) * density, Double(project.height) * density)
                if EffectRegistry.layerRefIDs.contains(e.typeID), let rid = e.text?["layer"].flatMap(UUID.init(uuidString:)),
                   let refLayer = project.layers.first(where: { $0.id == rid }), rid != layer.id {
                    ctx.reference = layerInBuffer(refLayer, project: project, time: time, renderScale: renderScale, comp: comp,
                                                  placement: M, toLocal: toLocal, size: (current.width, current.height),
                                                  cb: cb, pool: pool, mediaURL: mediaURL)
                } else if EffectRegistry.spriteRefIDs.contains(e.typeID), e.choice("sprite") == 6,
                          let rid = e.text?["layer"].flatMap(UUID.init(uuidString:)),
                          let refLayer = project.layers.first(where: { $0.id == rid }), rid != layer.id {
                    switch sourceTexture(refLayer, sourceTime: refLayer.sourceTime(at: time), time: time, density: 1, cb: cb, mediaURL: mediaURL) {
                    case .image(let t)?, .model(let t)?: ctx.reference = t
                    default: ctx.reference = whiteTexture
                    }
                }
                current = run(ctx)
            }
            // Effects-only masks: effects show inside them, the untouched layer everywhere else.
            if !effectMasks.isEmpty, current !== beforeEffects,
               var cov = PathGPU.shared?.coverage(cb: cb, width: current.width, height: current.height, masks: effectMasks, time: time,
                                                  matrix: toLocal.inverse, aa: 1 / density) {
                let mixed = pool.acquire(width: current.width, height: current.height)
                if let mesh = layer.boneMesh,let matrices = mesh.frameMatrices {
                    let warped = pool.acquire(width: cov.width,height: cov.height)
                    if BoneMeshGPU.encode(mesh,matrices: matrices,input: cov,output: warped,unit: density,commandBuffer: cb,device: device) { cov = warped }
                }
                fx.run("maskMix", cb, textures: [beforeEffects, mixed, current, cov], grid: mixed)
                current = mixed
            }
            // 3D lights shade the layer per pixel (AE: 3D layers accept lights once the comp has any).
            if lit {
                let litTex = pool.acquire(width: current.width, height: current.height)
                encodeLights(cb: cb, src: current, dst: litTex, layer: layer, time: time, camera: camera, lights: lights,
                             density: density, ext: ext)
                current = litTex
            }
            // Depth of field (3D layers through a camera with DOF on).
            if dof > 0.5 {
                let ctx = EffectContext(gpu: fx, cb: cb, input: current, effect: EffectInstance(typeID: "dof", params: [:]),
                                        time: time, unit: density, pool: pool)
                current = fx.gaussian(ctx, input: current, sigma: dof * density / max(pxPerLocal, 1e-4))
            }

            // Place the processed buffer like an image layer covering `ext`.
            let compAA = 1 / pxPerLocal
            if !blurMatrices.isEmpty {
                // A true average of the layer over the shutter. Drawing the samples on top of each other at 1/n
                // opacity left a still layer only about 63% opaque, which is why blurred layers turned see-through.
                let acc = shutterAverage(blurMatrices.count, comp: comp, pool: pool, cb: cb) { k, target in
                    drawQuad(cb: cb, target: target, matrix: blurMatrices[k], halfSize: ext, aa: compAA, opacity: 1,
                             layer: layer, time: time, source: .image(current), premultipliedImage: true, blendOverride: .normal)
                }
                let I = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(comp.width) / 2, Double(comp.height) / 2, 1)))
                drawQuad(cb: cb, target: comp, matrix: I, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 0.5,
                         opacity: opacity, layer: layer, time: time, source: .image(acc), premultipliedImage: true)
                continue
            }
            if extrude > 0.5 {
                // Solid thickness: darker slices stacked along the layer normal, drawn far-to-near, caps on both ends.
                // Walls shade from lit (near the front face) to dark (near the back) so the depth reads like AE's extrude.
                func shade(_ ev: Double) -> MTLTexture {
                    let ctx = EffectContext(gpu: fx, cb: cb, input: current, effect: EffectInstance(typeID: "ae.exposure", params: ["exposure": .number(Animated(ev)), "offset": .number(Animated(0)), "gamma": .number(Animated(1))]),
                                            time: time, unit: density, pool: pool)
                    if let d = EffectRegistry.definition("ae.exposure"), case .pixels(let run) = d.stage { return run(ctx) }
                    return current
                }
                let sides = [shade(-0.7), shade(-1.15), shade(-1.6), shade(-2.1)]
                // One slice per ~0.8 px of on-screen wall depth (measured at the corners), so the side stays solid at any angle.
                let Mback = Self.layerHomography(layer, camera: camera, time: time, renderScale: renderScale, localZ: extrude)
                func proj(_ m: simd_double3x3, _ x: Double, _ y: Double) -> SIMD2<Double> {
                    let q = m * SIMD3(x, y, 1); return SIMD2(q.x, q.y) / max(q.z, 1e-6)
                }
                let span = [(-ext.x, -ext.y), (ext.x, -ext.y), (ext.x, ext.y), (-ext.x, ext.y), (0, 0)]
                    .map { c in simd_length(proj(Mback, c.0, c.1) - proj(M, c.0, c.1)) }.max() ?? 0
                let n = max(3, min(700, Int((span / 0.6).rounded(.up))))
                // Which end is nearer comes from the projected depth (w) of the actual front and back faces, so the
                // draw order stays right at any rotation (the old z-offset test broke once the layer was turned).
                let wFront = (M * SIMD3(0, 0, 1)).z, wBack = (Mback * SIMD3(0, 0, 1)).z
                let backFarther = wBack > wFront
                let steps = Array(0...n)
                for k in (backFarther ? steps : steps.reversed()) {
                    let z = extrude * Double(n - k) / Double(n)
                    let Mk = Self.layerHomography(layer, camera: camera, time: time, renderScale: renderScale, localZ: z)
                    let cap = k == 0 || k == n
                    // k = 0 is the back face, k = n the front: darker walls toward the back.
                    let wall = sides[min(sides.count - 1, Int(Double(n - k) / Double(n + 1) * Double(sides.count)))]
                    drawQuad(cb: cb, target: comp, matrix: Mk, halfSize: ext, aa: compAA, opacity: opacity,
                             layer: layer, time: time, source: .image(cap ? (k == n ? current : sides.last!) : wall), premultipliedImage: true)
                }
                continue
            }
            drawQuad(cb: cb, target: comp, matrix: M, halfSize: ext, aa: compAA, opacity: opacity,
                     layer: layer, time: time, source: .image(current), premultipliedImage: true)
        }
        // Effects on the active camera apply to everything it sees (glitch, grade, glow on the camera = the whole shot).
        if let cam = project.layers.first(where: { $0.content == .camera && $0.isActive(at: globalTime) }) {
            let camFX = cam.effects.filter { e in
                guard e.isEnabled, let d = EffectRegistry.definition(e.typeID) else { return false }
                return !d.isTransformEffect
            }
            if !camFX.isEmpty {
                let copy = pool.acquire(width: comp.width, height: comp.height)
                fx.run("fxCopy", cb, textures: [comp, copy], grid: copy)
                var current = copy
                for e in camFX {
                    guard let def = EffectRegistry.definition(e.typeID), case .pixels(let run) = def.stage else { continue }
                    current = run(EffectContext(gpu: fx, cb: cb, input: current, effect: e, time: globalTime, unit: renderScale, pool: pool))
                }
                fx.run("fxCopy", cb, textures: [current, comp], grid: comp)
            }
        }
    }

    enum Source { case shape, solid, image(MTLTexture), model(MTLTexture) }


    private func mappedGradient(_ gradient: ShapeGradient?, matrix: simd_double3x3, time: Double) -> ShapeGradient? {
        guard var g = gradient else { return nil }
        g.start = Animated(ShapeContentsRenderer.point(g.start.value(at: time), matrix))
        g.end = Animated(ShapeContentsRenderer.point(g.end.value(at: time), matrix))
        return g
    }

    private func drawShapePath(cb: MTLCommandBuffer, target: MTLTexture, matrix: simd_double3x3, layer: Layer, path: BezierPath,
                               time: Double, opacity: Double, blend: BlendMode, aa: Double) {
        if let contents = layer.shapeContents {
            let groupCopies = layer.shapeOps?.repeater.map { ShapeOpsMath.copies($0, time: time) } ?? [(matrix_identity_double3x3, 1.0)]
            for (copy, copyOpacity) in groupCopies.reversed() {
                for draw in ShapeContentsRenderer.evaluate(contents, time: time).reversed() {
                    let c = draw.style, st = c.stroke
                    let stroke = st.enabled ? (color: st.color.value(at: time), width: st.width.value(at: time),
                                              trim: (st.trimStart.value(at: time), st.trimEnd.value(at: time), st.trimOffset.value(at: time))) : nil
                    // Whole-layer operators run after path-local operators and transforms.
                    let useGroup = layer.shapeOps?.changesGeometry == true
                    let paths = useGroup ? draw.paths.map { ShapeOpsMath.apply(layer.shapeOps!, to: $0.mapped(draw.matrix), time: time) } : draw.paths
                    PathGPU.shared?.drawCompound(cb: cb, target: target,
                        matrix: matrix * copy * (useGroup ? matrix_identity_double3x3 : draw.matrix), paths: paths,
                        fill: c.fillOn ? c.fill.value(at: time) : nil, stroke: stroke,
                        opacity: opacity * copyOpacity * draw.opacity, blend: blend, aa: aa,
                        drawingEffects: layer.effects, time: time, trimMode: c.trimMode,
                        fillGradient: c.fillOn ? mappedGradient(c.fillGradient, matrix: useGroup ? draw.matrix : matrix_identity_double3x3, time: time) : nil,
                        strokeGradient: mappedGradient(c.strokeGradient, matrix: useGroup ? draw.matrix : matrix_identity_double3x3, time: time))
                }
            }
            return
        }
        let st = layer.stroke
        let stroke = st.enabled ? (color: st.color.value(at: time), width: st.width.value(at: time),
                                   trim: (st.trimStart.value(at: time), st.trimEnd.value(at: time), st.trimOffset.value(at: time))) : nil
        let fill = layer.fill.value(at: time)
        if let rep = layer.shapeOps?.repeater {
            // Repeater: last copy drawn first so copy 1 sits on top (AE "Above").
            for (m, o) in ShapeOpsMath.copies(rep, time: time).reversed() where o > 0.001 {
                PathGPU.shared?.drawPath(cb: cb, target: target, matrix: matrix * m, path: path, fill: fill.a > 0 ? fill : nil,
                                         stroke: stroke, opacity: opacity * o, blend: blend, aa: aa, drawingEffects: layer.effects, time: time)
            }
            return
        }
        PathGPU.shared?.drawPath(cb: cb, target: target, matrix: matrix, path: path, fill: fill.a > 0 ? fill : nil,
                                 stroke: stroke, opacity: opacity, blend: blend, aa: aa, drawingEffects: layer.effects, time: time)
    }

    private func sourceTexture(_ layer: Layer, sourceTime: Double, time: Double, density: Double, cb: MTLCommandBuffer,
                               mediaURL: (String) -> URL) -> Source? {
        if layer.isGroup { return renderGroup(layer, time: time, density: density, cb: cb, mediaURL: mediaURL).map { .model($0) } }
        switch layer.content {
        case .shape: return .shape
        case .solid: return .solid
        case .image(let file, _, _): return imageTexture(url: mediaURL(file)).map { .image($0) }
        case .video(let file, _, _, _):
            let url = mediaURL(file)
            var blendedFrame: MTLTexture?
            if layer.usesFrameBlending, let pool = currentPool {
                // Between two source frames: blend them (smooth slow motion instead of repeated frames).
                let fps = VideoSources.shared.fps(url)
                let f = sourceTime * fps, a = f.rounded(.down), w = f - a
                if w > 0.03, w < 0.97,
                   let ta = VideoSources.shared.texture(url: url, time: (a + 0.5) / fps, device: device, channel: layer.id.hashValue),
                   let tb = VideoSources.shared.texture(url: url, time: (a + 1.5) / fps, device: device, channel: layer.id.hashValue) {
                    let out = pool.acquire(width: ta.width, height: ta.height)
                    var p = EffectParams()
                    p.a.x = Float(w)
                    fx.run("frameMix", cb, textures: [ta, out, tb], params: p, grid: out)
                    blendedFrame = out
                }
            }
            guard let frame = blendedFrame ?? VideoSources.shared.texture(url: url, time: sourceTime, device: device, channel: layer.id.hashValue) else { return nil }
            // Pixel Motion Blur: estimate how pixels moved since the previous frame, blur along it.
            if let amt = layer.timeFX?.pixelMotionBlur, amt > 0, let pool = currentPool {
                let fps = VideoSources.shared.fps(url)
                if let prev = VideoSources.shared.texture(url: url, time: max(0, sourceTime - 1 / fps), device: device, channel: layer.id.hashValue &+ 1), prev !== frame {
                    let fw = max(8, frame.width / 4), fh = max(8, frame.height / 4)
                    let flow = pool.acquire(width: fw, height: fh)
                    var p = EffectParams()
                    p.a.x = 6
                    fx.run("flowEstimate", cb, textures: [prev, flow, frame], params: p, grid: flow)
                    let out = pool.acquire(width: frame.width, height: frame.height)
                    var q = EffectParams()
                    q.a = SIMD4(Float(amt / 100), Float(layer.timeFX?.pixelBlurLimit ?? 0.15), Float(layer.timeFX?.pixelBlurSamples ?? 12), 1)
                    fx.run("flowBlur", cb, textures: [frame, out, flow], params: q, grid: out)
                    return .image(out)
                }
            }
            return .image(frame)
        case .model:
            guard let o = layer.model3D else { return nil }
            let size = layer.size.value(at: time)
            guard size.x.isFinite, size.y.isFinite, density.isFinite, size.x > 0, size.y > 0 else { return nil }
            let w = Int(min(2048, max(16, size.x * density))), h = Int(min(2048, max(16, size.y * density)))
            return ModelRenderer.shared?.render(o, time: time, width: w, height: h, cb: cb, pool: currentPool, mediaURL: mediaURL).map { .model($0) }
        case .precomp(let id):
            guard let tex = renderPrecomp(id, layer: layer, time: time, density: density, cb: cb, mediaURL: mediaURL) else { return nil }
            // Pixel Motion Blur on a pre-comp: blur everything inside along how it moved since the last frame
            // (pre-compose any group of layers to motion-blur all of it at once, like AE).
            if let amt = layer.timeFX?.pixelMotionBlur, amt > 0, let pool = currentPool,
               let prev = renderPrecomp(id, layer: layer, time: time - 1 / max(1, precompLibrary.first(where: { $0.id == id })?.fps ?? 30), density: density, cb: cb, mediaURL: mediaURL),
               prev.width == tex.width, prev.height == tex.height {
                let fw = max(8, tex.width / 4), fh = max(8, tex.height / 4)
                let flow = pool.acquire(width: fw, height: fh)
                var p = EffectParams()
                p.a.x = 6
                fx.run("flowEstimate", cb, textures: [prev, flow, tex], params: p, grid: flow)
                let out = pool.acquire(width: tex.width, height: tex.height)
                var q = EffectParams()
                q.a = SIMD4(Float(amt / 100), Float(layer.timeFX?.pixelBlurLimit ?? 0.15), Float(layer.timeFX?.pixelBlurSamples ?? 12), 0)
                fx.run("flowBlur", cb, textures: [tex, out, flow], params: q, grid: out)
                return .model(out)
            }
            return .model(tex)
        case .adjustment, .text, .audio, .camera, .light: return nil
        }
    }

    /// Full correlated shutter samples for weighted artwork. The mesh topology remains cached across shots.
    private func encodeSkinnedShutter(_ layer: Layer, project: Project, time: Double, renderScale: Double,
                                      comp: MTLTexture, cb: MTLCommandBuffer, pool: TexturePool,
                                      mediaURL: (String) -> URL) -> Bool {
        guard currentDepth < 7, let mesh = layer.boneMesh, mesh.previewWeightIndex == nil,
              var source = BoneMeshEvaluation.sampleProject(mesh, artworkID: layer.id),
              let owner = source.layers.firstIndex(where: { $0.id == layer.id }) else { return false }
        let shutter = project.shutterOpen
        guard shutter.length > 0 else { return false }
        let corners = [Vec2(-mesh.halfSize.x,-mesh.halfSize.y),Vec2(mesh.halfSize.x,-mesh.halfSize.y),
                       Vec2(mesh.halfSize.x,mesh.halfSize.y),Vec2(-mesh.halfSize.x,mesh.halfSize.y)]
        var previous: [Vec2] = [], distances: [Double] = []
        for probe in 0...4 {
            let t = time+shutter.start+shutter.length*Double(probe)/4
            let pose = Self.resolveParenting(ExpressionResolver.resolve(source,time: t),time: t)
            guard let art = pose.layers.first(where: { $0.id == layer.id }), let palette = art.boneMesh?.frameMatrices else { return false }
            let placement = Self.placementMatrix(art,camera: Self.activeCamera(pose,time: t),time: t,renderScale: renderScale)
            let points = palette.flatMap { matrix in corners.compactMap { LayerPlacement.projected(matrix.apply($0),by: placement) } }
            if probe == 0 { distances = Array(repeating: 0,count: points.count) }
            else if points.count == previous.count {
                for i in points.indices { distances[i] += hypot(points[i].x-previous[i].x,points[i].y-previous[i].y) }
            }
            previous = points
        }
        let travel = distances.max() ?? 0
        guard travel.isFinite, travel > 0.5 else { return false }
        let cap = max(2,min(project.blurSamples,Self.blurSampleCap ?? project.blurSamples))
        let count = max(2,min(cap,Int(min(Double(cap),ceil(travel/1.5)))+1))
        source.width = project.width; source.height = project.height
        source.background = RGBA(0,0,0,0); source.motionBlurEnabled = false; source.smoothMotion = false
        source.precompDepth = currentDepth+1
        // Retain all dependencies for parenting, expressions, references, mattes and lights. Only the owner draws.
        for i in source.layers.indices {
            source.layers[i].isSolo = false
            if i != owner {
                source.layers[i].trackMatte = .none; source.layers[i].clipToBelow = false
                if source.layers[i].content != .camera && source.layers[i].content != .light { source.layers[i].isVisible = false }
            }
        }
        source.layers[owner].groupID = nil; source.layers[owner].blendMode = .normal
        let average = shutterAverage(count,comp: comp,pool: pool,cb: cb) { k,target in
            let t = time+shutter.start+shutter.length*Double(k)/Double(count-1)
            encode(project: source,time: t,renderScale: renderScale,into: target,commandBuffer: cb,pool: pool,mediaURL: mediaURL)
        }
        let center = simd_double3x3(columns: (SIMD3(1,0,0),SIMD3(0,1,0),SIMD3(Double(comp.width)/2,Double(comp.height)/2,1)))
        drawQuad(cb: cb,target: comp,matrix: center,halfSize: Vec2(Double(comp.width)/2,Double(comp.height)/2),aa: 0.5,
                 opacity: 1,layer: layer,time: time,source: .image(average),premultipliedImage: true)
        return true
    }

    /// Averages `count` renders: each sample is drawn alone, then added at weight 1/count.
    func shutterAverage(_ count: Int, comp: MTLTexture, pool: TexturePool, cb: MTLCommandBuffer,
                        draw: (Int, MTLTexture) -> Void) -> MTLTexture {
        var acc = pool.acquire(width: comp.width, height: comp.height)
        fx.run("fxClear", cb, textures: [acc], grid: acc)
        let sample = pool.acquire(width: comp.width, height: comp.height)
        var p = EffectParams()
        p.a.x = Float(1 / Double(max(1, count)))
        for k in 0..<count {
            fx.run("fxClear", cb, textures: [sample], grid: sample)
            draw(k, sample)
            let next = pool.acquire(width: comp.width, height: comp.height)
            fx.run("fxAccumulate", cb, textures: [acc, sample, next], params: p, grid: next)
            acc = next
        }
        return acc
    }

    /// Draws one layer quad into `target` with the drawLayer kernel. `matrix` maps layer-local px -> target px.
    func drawQuad(cb: MTLCommandBuffer, target: MTLTexture, matrix M: simd_double3x3, halfSize hs: Vec2, aa: Double,
                          opacity: Double, layer: Layer, time: Double, source: Source, premultipliedImage: Bool,
                          blendOverride: BlendMode? = nil) {
        let inv = M.inverse
        let m = 2 * aa
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        for cx in [-hs.x - m, hs.x + m] {
            for cy in [-hs.y - m, hs.y + m] {
                let p = M * SIMD3(cx, cy, 1)
                // Corners behind the camera: fall back to the whole target.
                guard p.z > 1e-6 else { minX = 0; minY = 0; maxX = Double(target.width); maxY = Double(target.height); continue }
                minX = min(minX, p.x / p.z); maxX = max(maxX, p.x / p.z)
                minY = min(minY, p.y / p.z); maxY = max(maxY, p.y / p.z)
            }
        }
        let x0 = max(0, Int(floor(minX))), y0 = max(0, Int(floor(minY)))
        let x1 = min(target.width, Int(ceil(maxX))), y1 = min(target.height, Int(ceil(maxY)))
        if x1 <= x0 || y1 <= y0 { return }

        var contentKind: UInt32 = 0
        var shape: UInt32 = 0
        var tex: MTLTexture = dummy
        var color = layer.fill.value(at: time).simd
        // SceneKit renders premultiplied alpha.
        var premul = premultipliedImage
        switch source {
        case .shape: if case .shape(let k) = layer.content { shape = k.shaderIndex }
        case .solid: contentKind = 1
        case .image(let t): contentKind = 2; tex = t; color = SIMD4(1, 1, 1, 1)
        case .model(let t): contentKind = 2; tex = t; color = SIMD4(1, 1, 1, 1); premul = true
        }

        var params = LayerParams(
            invRow0: SIMD4(Float(inv[0][0]), Float(inv[1][0]), Float(inv[2][0]), 0),
            invRow1: SIMD4(Float(inv[0][1]), Float(inv[1][1]), Float(inv[2][1]), 0),
            invRow2: SIMD4(Float(inv[0][2]), Float(inv[1][2]), Float(inv[2][2]), 0),
            color: color,
            geom: SIMD4(Float(hs.x), Float(hs.y), Float(opacity), Float(layer.cornerRadius.value(at: time))),
            geom2: SIMD4(Float(layer.sides.value(at: time)), Float(layer.innerRatio.value(at: time)), Float(aa), premul ? 1 : 0),
            modes: SIMD4(shape, (blendOverride ?? layer.blendMode).shaderIndex, contentKind, 0),
            region: SIMD4(UInt32(x0), UInt32(y0), UInt32(x1 - x0), UInt32(y1 - y0))
        )
        guard let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(drawPSO)
        enc.setTexture(target, index: 0)
        enc.setTexture(tex, index: 1)
        enc.setBytes(&params, length: MemoryLayout<LayerParams>.stride, index: 0)
        dispatch(enc, pso: drawPSO, width: x1 - x0, height: y1 - y0)
        enc.endEncoding()
    }

    private func encodeAdjustment(_ layer: Layer, effects: [EffectInstance], time: Double, renderScale: Double, opacity: Double,
                                  comp: MTLTexture, cb: MTLCommandBuffer, pool: TexturePool, shutter: Double = 0, sampleCount: Int = 1) {
        let copy = pool.acquire(width: comp.width, height: comp.height)
        fx.run("fxCopy", cb, textures: [comp, copy], grid: copy)
        func process(at evaluationTime: Double) -> MTLTexture {
        var current = copy
        for e in effects {
            guard let def = EffectRegistry.definition(e.typeID) else { continue }
            switch def.stage {
            case .pixels(let run):
                current = run(EffectContext(gpu: fx, cb: cb, input: current, effect: e, time: evaluationTime, unit: renderScale, pool: pool))
            case .transform:
                let transformed = pool.acquire(width: comp.width, height: comp.height)
                fx.run("fxClear", cb, textures: [transformed], grid: transformed)
                var control = layer; control.effects = [e]
                let offset = Self.transformOffsets(control, time: evaluationTime)
                var carrier = layer; carrier.fill = Animated(.white)
                let angle = offset.dr * .pi / 180
                let matrix = simd_double3x3(columns: (SIMD3(cos(angle) * offset.ds, sin(angle) * offset.ds, 0),
                    SIMD3(-sin(angle) * offset.ds, cos(angle) * offset.ds, 0),
                    SIMD3(Double(comp.width) / 2 + offset.dx * renderScale, Double(comp.height) / 2 + offset.dy * renderScale, 1)))
                drawQuad(cb: cb, target: transformed, matrix: matrix, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 1,
                         opacity: 1, layer: carrier, time: evaluationTime, source: .image(current), premultipliedImage: true, blendOverride: .normal)
                current = transformed
            }

        }
        return current
        }
        var current: MTLTexture
        let samples = shutter > 0 && effects.contains(where: { EffectRegistry.definition($0.typeID)?.isTransformEffect == true }) ? max(2, min(16, sampleCount)) : 1
        if samples == 1 { current = process(at: time) }
        else {
            let accumulation = pool.acquire(width: comp.width, height: comp.height)
            fx.run("fxClear", cb, textures: [accumulation], grid: accumulation)
            var carrier = layer; carrier.fill = Animated(.white)
            let matrix = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(comp.width) / 2, Double(comp.height) / 2, 1)))
            for index in 0..<samples {
                let evaluationTime = time + (Double(index) / Double(samples - 1) - 0.5) * shutter
                let image = process(at: evaluationTime)
                drawQuad(cb: cb, target: accumulation, matrix: matrix, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 1,
                         opacity: 1 / Double(samples), layer: carrier, time: time, source: .image(image), premultipliedImage: true, blendOverride: .add)
            }
            current = accumulation
        }
        let M = Self.layerMatrix(layer, time: time, renderScale: renderScale, includeEffects: false)
        let inv = M.inverse
        let hs = Self.layerHalfSize(layer, time: time)
        let sc = layer.transform.scale.value(at: time)
        var p = EffectParams()
        p.a = SIMD4(Float(inv[0][0]), Float(inv[1][0]), Float(inv[2][0]), 0)
        p.b = SIMD4(Float(inv[0][1]), Float(inv[1][1]), Float(inv[2][1]), 0)
        p.c = SIMD4(Float(hs.x), Float(hs.y), Float(opacity), Float(1 / max(1e-4, min(abs(sc.x), abs(sc.y)) / 100 * renderScale)))
        fx.run("fxAdjustMix", cb, textures: [comp, current], params: p, grid: comp)
    }

    /// `dither` adds ±1 LSB noise before 8-bit (video export: no banding); stills stay exact.
    func encodeToBGRA(comp: MTLTexture, out: MTLTexture, commandBuffer cb: MTLCommandBuffer, dither: Bool = false, preserveAlpha: Bool = false) {
        guard let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(toBGRAPSO)
        enc.setTexture(comp, index: 0)
        enc.setTexture(out, index: 1)
        var d: UInt32 = dither ? 1 : 0
        enc.setBytes(&d, length: 4, index: 0)
        var a: UInt32 = preserveAlpha ? 1 : 0
        enc.setBytes(&a, length: 4, index: 1)
        dispatch(enc, pso: toBGRAPSO, width: out.width, height: out.height)
        enc.endEncoding()
    }

    func dispatch(_ enc: MTLComputeCommandEncoder, pso: MTLComputePipelineState, width: Int, height: Int) {
        let tw = pso.threadExecutionWidth
        let th = max(1, pso.maxTotalThreadsPerThreadgroup / tw)
        let tg = MTLSize(width: tw, height: th, depth: 1)
        let groups = MTLSize(width: (width + tw - 1) / tw, height: (height + th - 1) / th, depth: 1)
        enc.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
    }

    // MARK: Synchronous helpers (thumbnails, tests)

    /// Renders a frame and returns RGBA8 pixels composited over black (row-major, top-left origin).
    func renderPixels(project: Project, time: Double, renderScale: Double = 1, preserveAlpha: Bool = false, mediaURL: @escaping (String) -> URL) -> (width: Int, height: Int, rgba: [UInt8])? {
        let w = max(1, Int((Double(project.width) * renderScale).rounded()))
        let h = max(1, Int((Double(project.height) * renderScale).rounded()))
        guard let comp = makeCompTexture(width: w, height: h) else { return nil }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.shaderWrite, .shaderRead]
        d.storageMode = .shared
        guard let out = device.makeTexture(descriptor: d), let cb = queue.makeCommandBuffer() else { return nil }
        let pool = makePool()
        encode(project: project, time: time, renderScale: renderScale, into: comp, commandBuffer: cb, pool: pool, mediaURL: mediaURL)
        encodeToBGRA(comp: comp, out: out, commandBuffer: cb, preserveAlpha: preserveAlpha)
        cb.commit()
        cb.waitUntilCompleted()
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        out.getBytes(&bytes, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return (w, h, bytes)
    }

    func renderImage(project: Project, time: Double, maxDimension: Double, mediaURL: @escaping (String) -> URL) -> UIImage? {
        let scale = min(1, maxDimension / Double(max(project.width, project.height)))
        guard let px = renderPixels(project: project, time: time, renderScale: scale, preserveAlpha: true, mediaURL: mediaURL) else { return nil }
        guard let provider = CGDataProvider(data: Data(px.rgba) as CFData),
              let cg = CGImage(width: px.width, height: px.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: px.width * 4,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}
