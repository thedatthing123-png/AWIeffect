import Foundation
import Metal
import simd

/// Forward triangle skinning. Topology/weights stay in static GPU buffers; only the bone palette changes per frame.
final class BoneMeshGPU {
    private struct Vertex { var rest: SIMD2<Float>; var bones: SIMD4<UInt32>; var weights: SIMD4<Float> }
    private struct Affine { var x: SIMD4<Float>; var y: SIMD4<Float> }
    private struct Key: Hashable { var device: UInt64; var id: UUID; var revision: UUID }
    private struct Buffers {
        var vertices: MTLBuffer; var indices: MTLBuffer
        var sourceVertices: [BoneMeshVertex]; var sourceIndices: [UInt32]
        var boneCount: Int; var halfSize: Vec2; var lastUse: UInt64
        var cost: Int { vertices.length + indices.length + sourceVertices.count*104 + sourceIndices.count*4 }
    }
    private static let lock = NSLock()
    private static var pipelines: [UInt64: MTLRenderPipelineState] = [:]
    private static var cache: [Key: Buffers] = [:]
    private static var serial: UInt64 = 0

    private static func resources(_ mesh: BoneMeshBinding, device: MTLDevice) -> (MTLRenderPipelineState, Buffers)? {
        lock.lock(); defer { lock.unlock() }
        serial &+= 1
        let key = Key(device: device.registryID, id: mesh.id, revision: mesh.revision)
        let pipeline: MTLRenderPipelineState
        if let saved = pipelines[device.registryID] { pipeline = saved }
        else {
            guard let library = device.makeDefaultLibrary(), let vertex = library.makeFunction(name: "boneSkinVertex"),
                  let fragment = library.makeFunction(name: "boneSkinFragment") else { return nil }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertex; desc.fragmentFunction = fragment
            desc.colorAttachments[0].pixelFormat = .rgba16Float
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].sourceRGBBlendFactor = .one
            desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            desc.colorAttachments[0].sourceAlphaBlendFactor = .one
            desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            guard let made = try? device.makeRenderPipelineState(descriptor: desc) else { return nil }
            pipelines[device.registryID] = made; pipeline = made
        }
        // Array equality is constant-time for the same COW storage. It also detects externally decoded edits
        // whose caller did not advance revision, so stale cached weights cannot silently survive an import.
        if var saved = cache[key], saved.sourceVertices == mesh.vertices, saved.sourceIndices == mesh.indices,
           saved.boneCount == mesh.boneIDs.count, saved.halfSize == mesh.halfSize {
            saved.lastUse = serial; cache[key] = saved; return (pipeline, saved)
        }
        guard mesh.isValid, MemoryLayout<Vertex>.stride == 48 else { return nil }
        let vertices = mesh.vertices.map { vertex -> Vertex in
            var ids = SIMD4<UInt32>(repeating: 0), weights = SIMD4<Float>(repeating: 0)
            for (i,w) in vertex.weights.enumerated() { ids[i] = UInt32(w.bone); weights[i] = Float(w.amount) }
            return Vertex(rest: SIMD2(Float(vertex.rest.x), Float(vertex.rest.y)), bones: ids, weights: weights)
        }
        guard vertices.allSatisfy({ $0.rest.x.isFinite && $0.rest.y.isFinite }) else { return nil }
        guard let vb = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride*vertices.count),
              let ib = device.makeBuffer(bytes: mesh.indices, length: MemoryLayout<UInt32>.stride*mesh.indices.count) else { return nil }
        let result = Buffers(vertices: vb, indices: ib, sourceVertices: mesh.vertices, sourceIndices: mesh.indices,
                             boneCount: mesh.boneIDs.count, halfSize: mesh.halfSize, lastUse: serial)
        cache[key] = result
        var cost = cache.values.reduce(0) { $0+$1.cost }
        while cache.count > 64 || cost > 32*1024*1024 {
            guard let oldest = cache.filter({ $0.key != key }).min(by: { $0.value.lastUse < $1.value.lastUse }) else { break }
            cost -= oldest.value.cost; cache[oldest.key] = nil
        }
        return (pipeline, result)
    }

    @discardableResult
    static func encode(_ mesh: BoneMeshBinding, matrices: [RigAffine], input: MTLTexture, output: MTLTexture,
                       unit: Double, commandBuffer: MTLCommandBuffer, device: MTLDevice) -> Bool {
        guard unit.isFinite, unit > 0, input.width == output.width, input.height == output.height,
              output.pixelFormat == .rgba16Float, matrices.count == mesh.boneIDs.count,
              matrices.allSatisfy({ $0.isFinite }), let (pipeline, buffers) = resources(mesh, device: device) else { return false }
        let palette = matrices.map { m in Affine(x: SIMD4(Float(m.a),Float(m.c),Float(m.x),0), y: SIMD4(Float(m.b),Float(m.d),Float(m.y),0)) }
        guard palette.allSatisfy({ p in (0..<4).allSatisfy { p.x[$0].isFinite && p.y[$0].isFinite } }) else { return false }
        let paletteSize = MemoryLayout<Affine>.stride*palette.count
        var paletteBuffer: MTLBuffer?
        if paletteSize > 4096 {
            paletteBuffer = device.makeBuffer(bytes: palette, length: paletteSize)
            guard paletteBuffer != nil else { return false }
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.setRenderPipelineState(pipeline); encoder.setCullMode(.none)
        encoder.setVertexBuffer(buffers.vertices, offset: 0, index: 0)
        var view = SIMD4<Float>(Float(output.width),Float(output.height),Float(unit),Float(palette.count))
        encoder.setVertexBytes(&view, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
        if let paletteBuffer { encoder.setVertexBuffer(paletteBuffer, offset: 0, index: 2) }
        else { palette.withUnsafeBytes { encoder.setVertexBytes($0.baseAddress!, length: paletteSize, index: 2) } }
        let selected = mesh.previewWeightIndex.flatMap { mesh.boneIDs.indices.contains($0) ? $0 : nil }
        var preview = SIMD4<UInt32>(UInt32(selected ?? 0),selected == nil ? 0 : 1,0,0)
        encoder.setVertexBytes(&preview, length: 16, index: 3)
        encoder.setFragmentBytes(&preview, length: 16, index: 0)
        encoder.setFragmentTexture(input, index: 0)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indices.count, indexType: .uint32,
                                      indexBuffer: buffers.indices, indexBufferOffset: 0)
        encoder.endEncoding()
        return true
    }
}
