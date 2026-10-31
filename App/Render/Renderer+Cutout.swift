import Foundation
import Metal
import simd

/// Must match CutoutParams in Paths.metal.
struct CutoutParams {
    var invRow0: SIMD4<Float>
    var invRow1: SIMD4<Float>
    var geom: SIMD4<Float>
    var flags: SIMD4<UInt32>
}

extension Renderer {
    private static var cutoutPSO: MTLComputePipelineState? = {
        guard let r = Renderer.shared, let f = r.device.makeDefaultLibrary()?.makeFunction(name: "cutoutApply") else { return nil }
        return try? r.device.makeComputePipelineState(function: f)
    }()

    /// Multiplies the layer's local buffer by its AI matte. `M` maps layer-local px -> buffer px.
    func applyCutout(cb: MTLCommandBuffer, layer tex: MTLTexture, layerModel l: Layer, sourceTime: Double,
                     matrix M: simd_double3x3, halfSize hs: Vec2, mediaURL: (String) -> URL) {
        guard let s = l.cutout, let pso = Self.cutoutPSO,
              let matte = CutoutEngine.shared.matte(for: l, sourceTime: sourceTime, mediaURL: mediaURL, device: device),
              let enc = cb.makeComputeCommandEncoder() else { return }
        let (r0, r1) = PathGPU.inverseRows(M)
        // Choke/feather are in px; convert to matte-value space against the local half size.
        let px = 1 / max(hs.x, hs.y)
        var p = CutoutParams(invRow0: r0, invRow1: r1,
                             geom: SIMD4(Float(hs.x), Float(hs.y), Float(s.choke * px * 8), Float(max(0.02, s.feather * px * 8))),
                             flags: SIMD4(s.invert ? 1 : 0, UInt32(min(100, max(0, s.edgeContrast))), 0, 0))
        enc.setComputePipelineState(pso)
        enc.setTexture(tex, index: 0)
        enc.setTexture(matte, index: 1)
        enc.setBytes(&p, length: MemoryLayout<CutoutParams>.stride, index: 0)
        let tw = pso.threadExecutionWidth, th = max(1, pso.maxTotalThreadsPerThreadgroup / tw)
        enc.dispatchThreadgroups(MTLSize(width: (tex.width + tw - 1) / tw, height: (tex.height + th - 1) / th, depth: 1),
                                 threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
        enc.endEncoding()
    }
}
