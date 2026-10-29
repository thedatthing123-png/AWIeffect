import Foundation
import Metal
import simd

/// Must match PathParams in Paths.metal.
struct PathParams {
    var invRow0 = SIMD4<Float>(repeating: 0)
    var invRow1 = SIMD4<Float>(repeating: 0)
    var fill = SIMD4<Float>(repeating: 0)
    var stroke = SIMD4<Float>(repeating: 0)
    var geom = SIMD4<Float>(repeating: 0)
    var geom2 = SIMD4<Float>(repeating: 0)
    var info = SIMD4<UInt32>(repeating: 0)
    var info2 = SIMD4<UInt32>(repeating: 0)
    var region = SIMD4<UInt32>(repeating: 0)
}

/// GPU path rasterizer: shape-layer fills/strokes and AE-style masks.
final class PathGPU {
    static let shared: PathGPU? = Renderer.shared.flatMap { try? PathGPU(device: $0.device) }

    let device: MTLDevice
    private let drawPSO, accPSO, applyPSO: MTLComputePipelineState

    init(device: MTLDevice) throws {
        self.device = device
        guard let lib = device.makeDefaultLibrary() else { throw RenderError.pipeline("library") }
        func pso(_ n: String) throws -> MTLComputePipelineState {
            guard let f = lib.makeFunction(name: n) else { throw RenderError.pipeline(n) }
            return try device.makeComputePipelineState(function: f)
        }
        drawPSO = try pso("drawPath")
        accPSO = try pso("maskAccumulate")
        applyPSO = try pso("maskApply")
    }

    private func dispatch(_ enc: MTLComputeCommandEncoder, _ pso: MTLComputePipelineState, _ w: Int, _ h: Int) {
        let tw = pso.threadExecutionWidth, th = max(1, pso.maxTotalThreadsPerThreadgroup / tw)
        enc.dispatchThreadgroups(MTLSize(width: (w + tw - 1) / tw, height: (h + th - 1) / th, depth: 1),
                                 threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
    }

    private func segBytes(_ enc: MTLComputeCommandEncoder, _ segs: [SIMD4<Float>]) {
        var s = segs.isEmpty ? [SIMD4<Float>(repeating: 0)] : segs
        let len = MemoryLayout<SIMD4<Float>>.stride * s.count
        if len <= 4096 {
            enc.setBytes(&s, length: len, index: 1)
        } else if let buf = device.makeBuffer(bytes: &s, length: len, options: .storageModeShared) {
            enc.setBuffer(buf, offset: 0, index: 1)
        }
    }

    static func inverseRows(_ M: simd_double3x3) -> (SIMD4<Float>, SIMD4<Float>) {
        let inv = M.inverse
        return (SIMD4(Float(inv[0][0]), Float(inv[1][0]), Float(inv[2][0]), 0),
                SIMD4(Float(inv[0][1]), Float(inv[1][1]), Float(inv[2][1]), 0))
    }

    /// Draws a filled/stroked path. `M` maps layer-local px -> target px.
    func drawPath(cb: MTLCommandBuffer, target: MTLTexture, matrix M: simd_double3x3, path: BezierPath,
                  fill: RGBA?, stroke: (color: RGBA, width: Double, trim: (Double, Double, Double))?,
                  opacity: Double, blend: BlendMode, aa: Double) {
        let fillSegs = path.segments()
        var strokeSegs: [SIMD4<Float>] = []
        if let s = stroke { strokeSegs = Self.trimmed(fillSegs, start: s.trim.0, end: s.trim.1, offset: s.trim.2, closed: path.closed) }
        let all = (fill != nil ? fillSegs : []) + strokeSegs
        guard !all.isEmpty else { return }
        // Bounds in target px.
        let b = path.bounds
        let pad = (stroke?.width ?? 0) / 2 + 2 * aa
        var lo = SIMD2<Double>(.infinity, .infinity), hi = SIMD2<Double>(-.infinity, -.infinity)
        for x in [b.min.x - pad, b.max.x + pad] { for y in [b.min.y - pad, b.max.y + pad] {
            let p = M * SIMD3(x, y, 1)
            lo = simd_min(lo, SIMD2(p.x, p.y)); hi = simd_max(hi, SIMD2(p.x, p.y))
        } }
        let x0 = max(0, Int(floor(lo.x))), y0 = max(0, Int(floor(lo.y)))
        let x1 = min(target.width, Int(ceil(hi.x))), y1 = min(target.height, Int(ceil(hi.y)))
        guard x1 > x0, y1 > y0, let enc = cb.makeComputeCommandEncoder() else { return }
        var p = PathParams()
        (p.invRow0, p.invRow1) = Self.inverseRows(M)
        p.fill = fill?.simd ?? SIMD4(0, 0, 0, 0)
        p.stroke = stroke?.color.simd ?? SIMD4(0, 0, 0, 0)
        p.geom = SIMD4(Float(stroke?.width ?? 0), Float(opacity), Float(aa), 0)
        let fillCount = fill != nil ? fillSegs.count : 0
        p.info = SIMD4(UInt32(fillCount), UInt32(fillCount), UInt32(strokeSegs.count), blend.shaderIndex)
        p.region = SIMD4(UInt32(x0), UInt32(y0), UInt32(x1 - x0), UInt32(y1 - y0))
        enc.setComputePipelineState(drawPSO)
        enc.setTexture(target, index: 0)
        enc.setBytes(&p, length: MemoryLayout<PathParams>.stride, index: 0)
        segBytes(enc, all)
        dispatch(enc, drawPSO, x1 - x0, y1 - y0)
        enc.endEncoding()
    }

    /// Applies a layer's masks to `layer` (local buffer). `M` maps layer-local px -> buffer px.
    func applyMasks(cb: MTLCommandBuffer, layer tex: MTLTexture, masks: [LayerMask], time: Double,
                    matrix M: simd_double3x3, aa: Double, pool: TexturePool) {
        let active = masks.filter { $0.mode != .none }
        guard !active.isEmpty else { return }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: tex.width, height: tex.height, mipmapped: false)
        d.usage = [.shaderRead, .shaderWrite]
        d.storageMode = .private
        guard let acc = device.makeTexture(descriptor: d) else { return }
        _ = pool
        for (i, m) in active.enumerated() {
            guard let enc = cb.makeComputeCommandEncoder() else { return }
            var p = PathParams()
            (p.invRow0, p.invRow1) = Self.inverseRows(M)
            let segs = m.path.value(at: time).segments()
            // AE: a first Subtract/Intersect mask starts from a fully visible layer.
            let initial: Float = i == 0 ? ((m.mode == .subtract || m.mode == .intersect || m.mode == .darken) ? 1 : 0) : -1
            p.geom = SIMD4(0, 1, Float(aa), Float(m.feather.value(at: time)))
            p.geom2 = SIMD4(Float(m.expansion.value(at: time)), Float(m.opacity.value(at: time) / 100), initial, 0)
            p.info = SIMD4(UInt32(segs.count), 0, 0, m.mode.shaderIndex)
            p.info2 = SIMD4(m.inverted ? 1 : 0, 0, 0, 0)
            enc.setComputePipelineState(accPSO)
            enc.setTexture(acc, index: 0)
            enc.setBytes(&p, length: MemoryLayout<PathParams>.stride, index: 0)
            segBytes(enc, segs)
            dispatch(enc, accPSO, acc.width, acc.height)
            enc.endEncoding()
        }
        guard let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(applyPSO)
        enc.setTexture(tex, index: 0)
        enc.setTexture(acc, index: 1)
        dispatch(enc, applyPSO, tex.width, tex.height)
        enc.endEncoding()
    }

    /// AE Trim Paths: keep the [start, end]% portion of the path's length, rotated by `offset` degrees.
    static func trimmed(_ segs: [SIMD4<Float>], start: Double, end: Double, offset: Double, closed: Bool) -> [SIMD4<Float>] {
        guard !segs.isEmpty else { return [] }
        var s = min(start, end) / 100, e = max(start, end) / 100
        if s <= 0 && e >= 1 { return segs }
        if e - s <= 0 { return [] }
        let shift = offset / 360
        s += shift; e += shift
        let lens = segs.map { Double(simd_length(SIMD2($0.z - $0.x, $0.w - $0.y))) }
        let total = lens.reduce(0, +)
        guard total > 0 else { return [] }
        func range(_ a: Double, _ b: Double) -> [SIMD4<Float>] {
            var out: [SIMD4<Float>] = []
            var acc = 0.0
            let A = a * total, B = b * total
            for (i, sg) in segs.enumerated() {
                let l0 = acc, l1 = acc + lens[i]
                acc = l1
                if l1 <= A || l0 >= B || lens[i] <= 0 { continue }
                let t0 = max(0, (A - l0) / lens[i]), t1 = min(1, (B - l0) / lens[i])
                let p = SIMD2(sg.x, sg.y), q = SIMD2(sg.z, sg.w)
                let a2 = p + (q - p) * Float(t0), b2 = p + (q - p) * Float(t1)
                out.append(SIMD4(a2.x, a2.y, b2.x, b2.y))
            }
            return out
        }
        // Wrap around for offsets on closed paths.
        let fs = s - floor(s), fe = fs + (e - s)
        if fe <= 1 { return range(fs, fe) }
        return range(fs, 1) + range(0, fe - 1)
    }
}
