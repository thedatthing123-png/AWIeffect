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
    private let lightPSO: MTLComputePipelineState
    private let toBGRAPSO: MTLComputePipelineState
    let displayPSO: MTLRenderPipelineState
    private let loader: MTKTextureLoader
    let dummy: MTLTexture
    private var imageCache: [String: MTLTexture] = [:]
    private let cacheLock = NSLock()

    static let compFormat: MTLPixelFormat = .rgba16Float
    /// Nested comps available while encoding (root project's library), the pool and nesting depth in use.
    private var precompLibrary: [Project] = []
    private var currentPool: TexturePool?
    private var currentDepth = 0
    /// Parts of each group in the comp being encoded (group id -> parts, in stacking order).
    private var groupParts: [UUID: [Layer]] = [:]
    private var groupCameras: [Layer] = []

    /// Renders a nested comp at `time` (layer time -> comp time via the layer's timing), transparent background.
    private func renderPrecomp(_ id: UUID, layer: Layer, time: Double, density: Double, cb: MTLCommandBuffer,
                               mediaURL: (String) -> URL) -> MTLTexture? {
        guard currentDepth < 6, let pool = currentPool, var comp = precompLibrary.first(where: { $0.id == id }) else { return nil }
        let library = precompLibrary, depth = currentDepth
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
        let library = precompLibrary, depth = currentDepth, savedParts = groupParts, savedCams = groupCameras
        var sub = project
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

    /// Renders a group's parts (comp space, transparent) at the layer's density; the group layer then places
    /// this picture with its own transform, masks and effects. The group layer is comp-sized and centered,
    /// so with an untouched group transform the parts land exactly where they are.
    private func renderGroup(_ group: Layer, time: Double, density: Double, cb: MTLCommandBuffer, mediaURL: (String) -> URL) -> MTLTexture? {
        guard currentDepth < 8, let pool = currentPool else { return nil }
        // Parenting is already baked into the parts this frame: drop links so it is not applied twice.
        let members = (groupParts[group.id] ?? []).map { l -> Layer in var c = l; c.parentID = nil; c.groupID = nil; return c }
        let hs = Self.layerHalfSize(group, time: time)
        let w0 = max(1, Int((hs.x * 2).rounded())), h0 = max(1, Int((hs.y * 2).rounded()))
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
            var one = l; one.trackMatte = .none; one.isSolo = false; one.isVisible = true
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
        p.i.y = UInt32(TrackMatte.allCases.firstIndex(of: layer.trackMatte) ?? 1) - 1
        fx.run("fxGlow4", cb, textures: [content, out, m], params: p, grid: out)
        let I = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(comp.width) / 2, Double(comp.height) / 2, 1)))
        drawQuad(cb: cb, target: comp, matrix: I, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 0.5,
                 opacity: 1, layer: layer, time: time, source: .image(out), premultipliedImage: true)
    }

    /// Echo trails: each echoing layer gets delayed, fading copies stacked underneath it (all keyframes and media delayed).
    static func expandEchoes(_ p: Project) -> Project {
        guard p.layers.contains(where: { ($0.timeFX?.echoCount ?? 0) > 0 }) else { return p }
        var q = p
        var out: [Layer] = []
        // A layer used as a track matte by the layer below keeps its slot (no echo copies between them).
        let matteSources = Set(p.layers.indices.compactMap { i in i > 0 && p.layers[i].trackMatte != .none ? p.layers[i - 1].id : nil })
        for l in p.layers {
            out.append(l)
            guard let fx = l.timeFX, fx.echoCount > 0, !matteSources.contains(l.id) else { continue }
            for k in 1...min(fx.echoCount, 24) {
                var c = l
                c.id = UUID()
                c.timeFX?.echoCount = 0
                c.trackMatte = .none
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
                            falloff: SIMD4(Float(o.falloffRadius.value(at: time)), 0, 0, 0))
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
        guard let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(lightPSO)
        enc.setTexture(src, index: 0)
        enc.setTexture(dst, index: 1)
        enc.setBytes(&pass, length: MemoryLayout<LightPass>.stride, index: 0)
        enc.setBytes(&ls, length: MemoryLayout<LightGPU>.stride * max(ls.count, 1), index: 1)
        dispatch(enc, pso: lightPSO, width: dst.width, height: dst.height)
        enc.endEncoding()
    }

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
        if let t = imageCache[key] { return t }
        let t = try? loader.newTexture(URL: url, options: [
            .SRGB: false,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .origin: MTKTextureLoader.Origin.topLeft,
            .allocateMipmaps: true,
            .generateMipmaps: true,
        ])
        if let t { imageCache[key] = t }
        return t
    }

    func clearImageCache() {
        cacheLock.lock(); imageCache.removeAll(); cacheLock.unlock()
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
        guard layer.stroke.enabled else { return nil }
        let s = layer.size.value(at: time)
        switch k {
        case .ellipse: return .ellipse(size: s)
        case .rectangle: return .rectangle(size: s)
        default: return nil
        }
    }

    static func layerHalfSize(_ layer: Layer, time: Double) -> Vec2 {
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
        // Expressions are baked into plain values for this frame first.
        let resolved = ExpressionResolver.resolve(rawProject, time: time)
        // Echo needs parenting baked over time (costly); everything else bakes just this frame.
        let hasEcho = resolved.layers.contains { ($0.timeFX?.echoCount ?? 0) > 0 }
        let project = hasEcho ? Self.expandEchoes(Self.resolveParentingAnimated(resolved)) : Self.resolveParenting(resolved, time: time)
        precompLibrary = project.precomps.isEmpty ? precompLibrary : project.precomps
        currentPool = pool
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
        let anySolo = project.layers.contains { $0.isSolo }
        // Layers used as a track matte by the layer below them don't draw themselves.
        var matteSources: [UUID: Layer] = [:], hiddenMattes = Set<UUID>()
        for (i, l) in project.layers.enumerated() where l.trackMatte != .none && i > 0 {
            let m = project.layers[i - 1]
            // Only layers that draw pixels can be mattes (a camera / light / audio above means "no matte").
            if m.content == .camera || m.content == .light || m.isAudioOnly { continue }
            matteSources[l.id] = m; hiddenMattes.insert(m.id)
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
            // Posterize time / freeze frame evaluate this layer at its own clock.
            let time = layer.timeFX?.localTime(globalTime) ?? globalTime
            if case .audio = layer.content { continue }
            if case .camera = layer.content { continue }
            if case .light = layer.content { continue }
            if layer.isNull { continue }
            let opacity = layer.transform.opacity.value(at: time) / 100
            if opacity <= 0 { continue }
            if let matte = matteSources[layer.id] {
                encodeMatted(layer, matte: matte, project: project, time: time, renderScale: renderScale, comp: comp, cb: cb, pool: pool, mediaURL: mediaURL)
                continue
            }
            let pixelFX = layer.effects.filter { e in
                guard e.isEnabled, let d = EffectRegistry.definition(e.typeID) else { return false }
                return !d.isTransformEffect
            }

            if case .adjustment = layer.content {
                guard !pixelFX.isEmpty else { continue }
                encodeAdjustment(layer, effects: pixelFX, time: time, renderScale: renderScale, opacity: opacity,
                                 comp: comp, cb: cb, pool: pool)
                continue
            }

            let M = Self.placementMatrix(layer, camera: camera, time: time, renderScale: renderScale)
            if abs(M.determinant) < 1e-12 { continue }
            let hs = Self.layerHalfSize(layer, time: time)
            let sc = layer.transform.scale.value(at: time)
            let pxPerLocal = layer.is3D ? Self.pixelsPerLocal(M, at: layer.transform.anchor.value(at: time))
                                        : max(1e-4, min(abs(sc.x), abs(sc.y)) / 100 * renderScale)
            let dof = Self.dofSigma(layer, camera: camera, time: time) * renderScale

            // Text on path uses the first mask as its path (AE), so that mask doesn't cut the text.
            let pathMaskID = layer.text?.onPath == true ? layer.masks.first?.id : nil
            let masks = layer.masks.filter { $0.mode != .none && !$0.effectsOnly && $0.id != pathMaskID }
            let effectMasks = layer.masks.filter { $0.mode != .none && $0.effectsOnly }
            let extrude = layer.is3D && layer.content != .model ? max(0, layer.extrude.value(at: time)) : 0
            // Motion blur: placements across the shutter interval (empty when the layer doesn't move).
            var blurMatrices: [simd_double3x3] = []
            let autoSmooth = project.smoothMotion && layer.effects.contains { $0.isEnabled && (EffectRegistry.definition($0.typeID)?.isTransformEffect ?? false) }
            if ((project.motionBlurEnabled && layer.motionBlur) || autoSmooth) && extrude <= 0.5 {
                let shutter = project.shutterAngle / 360 / max(project.fps, 1)
                func corner(_ m: simd_double3x3, _ x: Double, _ y: Double) -> SIMD2<Double> {
                    let p = m * SIMD3(x, y, 1); return SIMD2(p.x, p.y) / max(p.z, 1e-6)
                }
                // Adaptive: as many samples as the motion needs (≈1 per 1.5 px of travel), capped by the quality setting.
                let m0 = Self.placementMatrix(layer, camera: camera, time: time - shutter / 2, renderScale: renderScale)
                let m1 = Self.placementMatrix(layer, camera: camera, time: time + shutter / 2, renderScale: renderScale)
                let travel = [(-hs.x, -hs.y), (hs.x, hs.y), (hs.x, -hs.y), (-hs.x, hs.y)]
                    .map { c in simd_length(corner(m1, c.0, c.1) - corner(m0, c.0, c.1)) }.max() ?? 0
                if travel.isFinite, travel > 0.5 {
                    let n = max(3, min(project.blurSamples, Int((travel / 1.5).rounded(.up)) + 1))
                    blurMatrices = (0..<n).map { k in
                        Self.placementMatrix(layer, camera: camera, time: time + (Double(k) / Double(n - 1) - 0.5) * shutter, renderScale: renderScale)
                    }
                }
            }
            let lit = layer.is3D && !lights.isEmpty && layer.content != .model
            let needsLocal = !pixelFX.isEmpty || !masks.isEmpty || layer.cutout != nil || dof > 0.5 || extrude > 0.5 || !blurMatrices.isEmpty || lit
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
            let rawMargin = pixelFX.reduce(0.0) { acc, e in acc + (EffectRegistry.definition(e.typeID)?.margin(e, time) ?? 0) }
                + (dof > 0.5 ? dof * 3 / max(pxPerLocal, 1e-4) : 0)
            // Glow / shadow room beyond what the screen can show is never seen: cap it to the comp size.
            let compReach = Double(max(project.width, project.height)) / max(pxPerLocal, 1e-4)
            let margin = rawMargin.isFinite ? min(max(0, rawMargin), 20000, compReach) : 0
            guard hs.x.isFinite, hs.y.isFinite, pxPerLocal.isFinite else { continue }
            let ext = Vec2(min(max(hs.x, 0.5), 1e6) + margin, min(max(hs.y, 0.5), 1e6) + margin)
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
            for e in pixelFX {
                guard let def = EffectRegistry.definition(e.typeID), case .pixels(let run) = def.stage else { continue }
                var ctx = EffectContext(gpu: fx, cb: cb, input: current, effect: e, time: time, unit: density, pool: pool)
                if EffectRegistry.layerRefIDs.contains(e.typeID), let rid = e.text?["layer"].flatMap(UUID.init(uuidString:)),
                   let refLayer = project.layers.first(where: { $0.id == rid }), rid != layer.id {
                    ctx.reference = layerInBuffer(refLayer, project: project, time: time, renderScale: renderScale, comp: comp,
                                                  placement: M, toLocal: toLocal, size: (current.width, current.height),
                                                  cb: cb, pool: pool, mediaURL: mediaURL)
                }
                current = run(ctx)
            }
            // Effects-only masks: effects show inside them, the untouched layer everywhere else.
            if !effectMasks.isEmpty, current !== local,
               let cov = PathGPU.shared?.coverage(cb: cb, width: current.width, height: current.height, masks: effectMasks, time: time,
                                                  matrix: toLocal.inverse, aa: 1 / density) {
                let mixed = pool.acquire(width: current.width, height: current.height)
                fx.run("maskMix", cb, textures: [local, mixed, current, cov], grid: mixed)
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
                // Average the layer over the shutter: additive samples at 1/n opacity, then composite once.
                let acc = pool.acquire(width: comp.width, height: comp.height)
                fx.run("fxClear", cb, textures: [acc], grid: acc)
                let w = 1 / Double(blurMatrices.count)
                for Mk in blurMatrices {
                    drawQuad(cb: cb, target: acc, matrix: Mk, halfSize: ext, aa: compAA, opacity: w,
                             layer: layer, time: time, source: .image(current), premultipliedImage: true, blendOverride: .add)
                }
                let I = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(comp.width) / 2, Double(comp.height) / 2, 1)))
                drawQuad(cb: cb, target: comp, matrix: I, halfSize: Vec2(Double(comp.width) / 2, Double(comp.height) / 2), aa: 0.5,
                         opacity: opacity, layer: layer, time: time, source: .image(acc), premultipliedImage: true)
                continue
            }
            if extrude > 0.5 {
                // Solid thickness: darker slices stacked along the layer normal, drawn far-to-near, caps on both ends.
                let ctx = EffectContext(gpu: fx, cb: cb, input: current, effect: EffectInstance(typeID: "ae.exposure", params: ["exposure": .number(Animated(-1.4)), "offset": .number(Animated(0)), "gamma": .number(Animated(1))]),
                                        time: time, unit: density, pool: pool)
                let side: MTLTexture
                if let d = EffectRegistry.definition("ae.exposure"), case .pixels(let run) = d.stage { side = run(ctx) } else { side = current }
                // One slice per ~0.8 px of on-screen wall depth (measured at the corners), so the side stays solid at any angle.
                let Mback = Self.layerHomography(layer, camera: camera, time: time, renderScale: renderScale, localZ: extrude)
                func proj(_ m: simd_double3x3, _ x: Double, _ y: Double) -> SIMD2<Double> {
                    let q = m * SIMD3(x, y, 1); return SIMD2(q.x, q.y) / max(q.z, 1e-6)
                }
                let span = [(-ext.x, -ext.y), (ext.x, -ext.y), (ext.x, ext.y), (-ext.x, ext.y), (0, 0)]
                    .map { c in simd_length(proj(Mback, c.0, c.1) - proj(M, c.0, c.1)) }.max() ?? 0
                let n = max(3, min(400, Int((span / 0.8).rounded(.up))))
                let front = Self.layerDepth(layer, camera: camera, time: time)
                var backLayer = layer
                backLayer.transform.positionZ = Animated(layer.transform.positionZ.value(at: time) + 1)
                let backFarther = Self.layerDepth(backLayer, camera: camera, time: time) > front
                let steps = Array(0...n)
                for k in (backFarther ? steps : steps.reversed()) {
                    let z = extrude * Double(n - k) / Double(n)
                    let Mk = Self.layerHomography(layer, camera: camera, time: time, renderScale: renderScale, localZ: z)
                    let cap = k == 0 || k == n
                    drawQuad(cb: cb, target: comp, matrix: Mk, halfSize: ext, aa: compAA, opacity: opacity,
                             layer: layer, time: time, source: .image(cap ? current : side), premultipliedImage: true)
                }
                continue
            }
            drawQuad(cb: cb, target: comp, matrix: M, halfSize: ext, aa: compAA, opacity: opacity,
                     layer: layer, time: time, source: .image(current), premultipliedImage: true)
        }
    }

    private enum Source { case shape, solid, image(MTLTexture), model(MTLTexture) }


    private func drawShapePath(cb: MTLCommandBuffer, target: MTLTexture, matrix: simd_double3x3, layer: Layer, path: BezierPath,
                               time: Double, opacity: Double, blend: BlendMode, aa: Double) {
        let st = layer.stroke
        let stroke = st.enabled ? (color: st.color.value(at: time), width: st.width.value(at: time),
                                   trim: (st.trimStart.value(at: time), st.trimEnd.value(at: time), st.trimOffset.value(at: time))) : nil
        let fill = layer.fill.value(at: time)
        if let rep = layer.shapeOps?.repeater {
            // Repeater: last copy drawn first so copy 1 sits on top (AE "Above").
            for (m, o) in ShapeOpsMath.copies(rep, time: time).reversed() where o > 0.001 {
                PathGPU.shared?.drawPath(cb: cb, target: target, matrix: matrix * m, path: path, fill: fill.a > 0 ? fill : nil,
                                         stroke: stroke, opacity: opacity * o, blend: blend, aa: aa)
            }
            return
        }
        PathGPU.shared?.drawPath(cb: cb, target: target, matrix: matrix, path: path, fill: fill.a > 0 ? fill : nil,
                                 stroke: stroke, opacity: opacity, blend: blend, aa: aa)
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
            if layer.timeFX?.frameBlend == true, let pool = currentPool {
                // Between two source frames: blend them (smooth slow motion instead of repeated frames).
                let fps = VideoSources.shared.fps(url)
                let f = sourceTime * fps, a = f.rounded(.down), w = f - a
                if w > 0.03, w < 0.97,
                   let ta = VideoSources.shared.texture(url: url, time: (a + 0.5) / fps, device: device),
                   let tb = VideoSources.shared.texture(url: url, time: (a + 1.5) / fps, device: device) {
                    let out = pool.acquire(width: ta.width, height: ta.height)
                    var p = EffectParams()
                    p.a.x = Float(w)
                    fx.run("frameMix", cb, textures: [ta, out, tb], params: p, grid: out)
                    return .image(out)
                }
            }
            return VideoSources.shared.texture(url: url, time: sourceTime, device: device).map { .image($0) }
        case .model:
            guard let o = layer.model3D else { return nil }
            let size = layer.size.value(at: time)
            let w = min(2048, max(16, Int(size.x * density))), h = min(2048, max(16, Int(size.y * density)))
            return ModelRenderer.shared?.render(o, time: time, width: w, height: h, cb: cb, mediaURL: mediaURL).map { .model($0) }
        case .precomp(let id):
            guard let tex = renderPrecomp(id, layer: layer, time: time, density: density, cb: cb, mediaURL: mediaURL) else { return nil }
            return .model(tex)
        case .adjustment, .text, .audio, .camera, .light: return nil
        }
    }

    /// Draws one layer quad into `target` with the drawLayer kernel. `matrix` maps layer-local px -> target px.
    private func drawQuad(cb: MTLCommandBuffer, target: MTLTexture, matrix M: simd_double3x3, halfSize hs: Vec2, aa: Double,
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
                                  comp: MTLTexture, cb: MTLCommandBuffer, pool: TexturePool) {
        let copy = pool.acquire(width: comp.width, height: comp.height)
        fx.run("fxCopy", cb, textures: [comp, copy], grid: copy)
        var current = copy
        for e in effects {
            guard let def = EffectRegistry.definition(e.typeID), case .pixels(let run) = def.stage else { continue }
            current = run(EffectContext(gpu: fx, cb: cb, input: current, effect: e, time: time, unit: renderScale, pool: pool))
        }
        let M = Self.layerMatrix(layer, time: time, renderScale: renderScale)
        let inv = M.inverse
        let hs = Self.layerHalfSize(layer, time: time)
        let sc = layer.transform.scale.value(at: time)
        var p = EffectParams()
        p.a = SIMD4(Float(inv[0][0]), Float(inv[1][0]), Float(inv[2][0]), 0)
        p.b = SIMD4(Float(inv[0][1]), Float(inv[1][1]), Float(inv[2][1]), 0)
        p.c = SIMD4(Float(hs.x), Float(hs.y), Float(opacity), Float(1 / max(1e-4, min(abs(sc.x), abs(sc.y)) / 100 * renderScale)))
        fx.run("fxAdjustMix", cb, textures: [comp, current], params: p, grid: comp)
    }

    func encodeToBGRA(comp: MTLTexture, out: MTLTexture, commandBuffer cb: MTLCommandBuffer) {
        guard let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(toBGRAPSO)
        enc.setTexture(comp, index: 0)
        enc.setTexture(out, index: 1)
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
    func renderPixels(project: Project, time: Double, renderScale: Double = 1, mediaURL: @escaping (String) -> URL) -> (width: Int, height: Int, rgba: [UInt8])? {
        let w = max(1, Int((Double(project.width) * renderScale).rounded()))
        let h = max(1, Int((Double(project.height) * renderScale).rounded()))
        guard let comp = makeCompTexture(width: w, height: h) else { return nil }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.shaderWrite, .shaderRead]
        d.storageMode = .shared
        guard let out = device.makeTexture(descriptor: d), let cb = queue.makeCommandBuffer() else { return nil }
        let pool = makePool()
        encode(project: project, time: time, renderScale: renderScale, into: comp, commandBuffer: cb, pool: pool, mediaURL: mediaURL)
        encodeToBGRA(comp: comp, out: out, commandBuffer: cb)
        cb.commit()
        cb.waitUntilCompleted()
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        out.getBytes(&bytes, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return (w, h, bytes)
    }

    func renderImage(project: Project, time: Double, maxDimension: Double, mediaURL: @escaping (String) -> URL) -> UIImage? {
        let scale = min(1, maxDimension / Double(max(project.width, project.height)))
        guard let px = renderPixels(project: project, time: time, renderScale: scale, mediaURL: mediaURL) else { return nil }
        guard let provider = CGDataProvider(data: Data(px.rgba) as CFData),
              let cg = CGImage(width: px.width, height: px.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: px.width * 4,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}
