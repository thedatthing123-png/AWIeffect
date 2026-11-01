import Foundation
import Metal
import simd

/// Baked soft-body simulation: a grid of points over the layer, positions per frame in layer-local px (centered).
/// File: [nx, ny, frames] as Int32, fps as Float32, then frames * nx * ny * 2 Float32.
struct SoftMeshCache {
    let nx: Int, ny: Int, frames: Int
    let fps: Double
    let data: [Float]

    func positions(at t: Double) -> [SIMD2<Float>] {
        let f = max(0, min(Double(frames - 1), t * fps))
        let a = Int(f.rounded(.down)), b = min(frames - 1, a + 1), w = Float(f - Double(a))
        let n = nx * ny
        var out = [SIMD2<Float>](repeating: .zero, count: n)
        for k in 0..<n {
            let ia = (a * n + k) * 2, ib = (b * n + k) * 2
            out[k] = SIMD2(data[ia] + (data[ib] - data[ia]) * w, data[ia + 1] + (data[ib + 1] - data[ia + 1]) * w)
        }
        return out
    }

    func encoded() -> Data {
        var d = Data()
        for v in [Int32(nx), Int32(ny), Int32(frames)] { withUnsafeBytes(of: v) { d.append(contentsOf: $0) } }
        withUnsafeBytes(of: Float32(fps)) { d.append(contentsOf: $0) }
        data.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }

    init(nx: Int, ny: Int, frames: Int, fps: Double, data: [Float]) {
        self.nx = nx; self.ny = ny; self.frames = frames; self.fps = fps; self.data = data
    }

    init?(_ d: Data) {
        guard d.count >= 16 else { return nil }
        let ints = d.withUnsafeBytes { Array($0.bindMemory(to: Int32.self).prefix(3)) }
        let fps = d.withUnsafeBytes { $0.load(fromByteOffset: 12, as: Float32.self) }
        let n = Int(ints[0]) * Int(ints[1]) * Int(ints[2]) * 2
        guard ints[0] > 1, ints[1] > 1, ints[2] > 0, d.count >= 16 + n * 4 else { return nil }
        let floats = d.subdata(in: 16..<(16 + n * 4)).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        self.init(nx: Int(ints[0]), ny: Int(ints[1]), frames: Int(ints[2]), fps: Double(fps), data: floats)
    }

    private static var cache: [String: SoftMeshCache] = [:]
    private static let lock = NSLock()
    static func load(_ url: URL) -> SoftMeshCache? {
        lock.lock(); defer { lock.unlock() }
        if let c = cache[url.path] { return c }
        guard let d = try? Data(contentsOf: url), let c = SoftMeshCache(d) else { return nil }
        cache[url.path] = c
        if cache.count > 16 { cache.removeAll() }
        cache[url.path] = c
        return c
    }
    static func forget(_ url: URL) { lock.lock(); cache[url.path] = nil; lock.unlock() }
}

extension EffectRegistry {
    /// Where soft body caches live (set by the renderer for the open project).
    static var softMeshURL: ((String) -> URL)?

    private static var softPSO: MTLRenderPipelineState? = {
        guard let r = Renderer.shared, let lib = r.device.makeDefaultLibrary() else { return nil }
        let d = MTLRenderPipelineDescriptor()
        d.vertexFunction = lib.makeFunction(name: "softMeshVertex")
        d.fragmentFunction = lib.makeFunction(name: "softMeshFragment")
        d.colorAttachments[0].pixelFormat = .rgba16Float
        // Premultiplied over (overlapping folds).
        d.colorAttachments[0].isBlendingEnabled = true
        d.colorAttachments[0].sourceRGBBlendFactor = .one
        d.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        d.colorAttachments[0].sourceAlphaBlendFactor = .one
        d.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try? r.device.makeRenderPipelineState(descriptor: d)
    }()

    /// Soft Body (Physics Studio): the layer deforms on a simulated mesh (squash, bulge, splat, wobble).
    static let softBody20 = EffectDefinition(
        id: "awi20.softBody", name: "Soft Body (baked)", category: .distort, aeMatchNames: [],
        summary: "Made by Physics Studio → Soft Body: the layer is drawn on a simulated mesh so it squashes, bulges and wobbles like jelly or slime.",
        params: [
            .number("start", "Starts At", 0, 0, 3600, step: 0.01, unit: "s"),
            .number("amount", "Amount", 100, 0, 150, unit: "%"),
            .number("shade", "Volume Shading", 40, 0, 100, unit: "%"),
        ],
        margin: { _, _ in 1600 },
        stage: .pixels { ctx in
            guard let file = ctx.effect.text?["file"], let url = softMeshURL?(file), let cache = SoftMeshCache.load(url),
                  let pso = softPSO else { return ctx.input }
            let lp = ctx.layerPixels ?? SIMD2(Double(ctx.width), Double(ctx.height))
            let W = Double(ctx.width), H = Double(ctx.height)
            let ox = (W - lp.x) / 2, oy = (H - lp.y) / 2
            let pos = cache.positions(at: ctx.time - ctx.num("start"))
            let amount = Float(ctx.num("amount") / 100)
            let nx = cache.nx, ny = cache.ny
            // Rest grid (layer-local px, centered) for blending by Amount and for the UVs.
            let hx = lp.x / ctx.unit / 2, hy = lp.y / ctx.unit / 2
            func rest(_ i: Int, _ j: Int) -> SIMD2<Float> {
                SIMD2(Float(-hx + 2 * hx * Double(i) / Double(nx - 1)), Float(-hy + 2 * hy * Double(j) / Double(ny - 1)))
            }
            struct V { var pos: SIMD2<Float>; var uv: SIMD2<Float> }
            var verts: [V] = []
            var shades: [Float] = []
            verts.reserveCapacity((nx - 1) * (ny - 1) * 6)
            func vert(_ i: Int, _ j: Int, _ shade: Float) {
                let r = rest(i, j)
                let q = r + (pos[j * nx + i] - r) * amount
                let bx = Float(ox) + (q.x + Float(hx)) * Float(ctx.unit), by = Float(oy) + (q.y + Float(hy)) * Float(ctx.unit)
                let u = Float((ox + (Double(r.x) + hx) * ctx.unit) / W), v = Float((oy + (Double(r.y) + hy) * ctx.unit) / H)
                verts.append(V(pos: SIMD2(bx, by), uv: SIMD2(u, v)))
                shades.append(shade)
            }
            for j in 0..<(ny - 1) { for i in 0..<(nx - 1) {
                // Cell area now vs at rest: squash < 1 darkens, stretch > 1 brightens slightly.
                let a = pos[j * nx + i], b = pos[j * nx + i + 1], c = pos[(j + 1) * nx + i], d = pos[(j + 1) * nx + i + 1]
                let area = abs(simd_cross(SIMD3(b - a, 0), SIMD3(c - a, 0)).z) + abs(simd_cross(SIMD3(c - d, 0), SIMD3(b - d, 0)).z)
                let ra = rest(1, 1) - rest(0, 0)
                let restArea = abs(ra.x * ra.y) * 2
                let sh = max(-0.4, min(0.4, (area / max(restArea, 1e-3) - 1) * 0.5))
                vert(i, j, sh); vert(i + 1, j, sh); vert(i, j + 1, sh)
                vert(i + 1, j, sh); vert(i + 1, j + 1, sh); vert(i, j + 1, sh)
            } }
            let out = ctx.temp()
            let rp = MTLRenderPassDescriptor()
            rp.colorAttachments[0].texture = out
            rp.colorAttachments[0].loadAction = .clear
            rp.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            rp.colorAttachments[0].storeAction = .store
            guard !verts.isEmpty, let enc = ctx.cb.makeRenderCommandEncoder(descriptor: rp) else { return ctx.input }
            var view = SIMD4<Float>(Float(W), Float(H), Float(ctx.num("shade") / 100), 0)
            enc.setRenderPipelineState(pso)
            // Mesh data is bigger than setVertexBytes' 4 KB limit: real buffers.
            guard let vb = ctx.gpu.device.makeBuffer(bytes: verts, length: MemoryLayout<V>.stride * verts.count),
                  let sb = ctx.gpu.device.makeBuffer(bytes: shades, length: 4 * shades.count) else { enc.endEncoding(); return ctx.input }
            enc.setVertexBuffer(vb, offset: 0, index: 0)
            enc.setVertexBytes(&view, length: 16, index: 1)
            enc.setVertexBuffer(sb, offset: 0, index: 2)
            enc.setFragmentTexture(ctx.input, index: 0)
            enc.setFragmentBytes(&view, length: 16, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: verts.count)
            enc.endEncoding()
            return out
        })
}
