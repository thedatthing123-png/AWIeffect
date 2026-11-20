import Foundation
import Metal
import MetalKit
import simd

/// A source parameter occupies one std140-aligned 16-byte slot. Choice values
/// need not equal their displayed indices; bool/int slots carry integer bits.
struct ReferenceFragmentParameter {
    let definition: ParamDef
    let slot: Int
    var scalarScale: Float = 1
    var pointMinimum: Vec2? = nil
    var pointMaximum: Vec2? = nil
    var choiceValues: [Int] = []
}

struct ReferenceFragmentDefinition {
    let id: String
    let name: String
    let summary: String
    let category: EffectCategory
    let function: String
    let slots: Int
    let parameters: [ReferenceFragmentParameter]
    let images: [String]

    var definition: EffectDefinition {
        EffectDefinition(id: id, name: name, category: category, aeMatchNames: [], summary: summary,
            params: parameters.map(\.definition), stage: .pixels { context in
                context.gpu.referenceFragments.render(self, context)
            })
    }

    func uniforms(_ context: EffectContext) -> [SIMD4<Float>] {
        var data = [SIMD4<Float>](repeating: .zero, count: slots)
        let width = Float(context.width), height = Float(context.height)
        let rect = EffectRegistry.layerRect(context)
        data[0] = SIMD4(width, height, Float(context.time), Float(context.unit))
        data[1] = rect
        let composition = context.compositionPixels ?? SIMD2(Double(context.width), Double(context.height))
        data[2] = SIMD4(Float(composition.x), Float(composition.y), 0, 0)
        let sx = max(rect.z, 1) / max(width, 1), sy = max(rect.w, 1) / max(height, 1)
        let ox = rect.x / max(width, 1), oy = rect.y / max(height, 1)
        // Reference shaders multiply row vectors by these matrices.
        data[3] = SIMD4(sx, 0, 0, ox); data[4] = SIMD4(0, sy, 0, oy)
        data[5] = SIMD4(0, 0, 1, 0); data[6] = SIMD4(0, 0, 0, 1)
        data[7] = SIMD4(1 / sx, 0, 0, -ox / sx); data[8] = SIMD4(0, 1 / sy, 0, -oy / sy)
        data[9] = SIMD4(0, 0, 1, 0); data[10] = SIMD4(0, 0, 0, 1)
        for parameter in parameters {
            let pd = parameter.definition
            let value = context.effect.params[pd.id] ?? pd.defaultValue
            let slot = parameter.slot
            switch pd.kind {
            case .number(let minimum, let maximum, _, _):
                data[slot].x = Float(min(maximum, max(minimum, value.number(at: context.time)))) * parameter.scalarScale
            case .angle:
                data[slot].x = Float(value.number(at: context.time))
            case .point:
                var point = value.point(at: context.time)
                if let low = parameter.pointMinimum { point.x = max(low.x, point.x); point.y = max(low.y, point.y) }
                if let high = parameter.pointMaximum { point.x = min(high.x, point.x); point.y = min(high.y, point.y) }
                data[slot] = SIMD4(Float(point.x), Float(point.y), 0, 0)
            case .color:
                data[slot] = value.color(at: context.time).simd
            case .toggle:
                let enabled: Bool
                if case .toggle(let flag) = value { enabled = flag } else { enabled = false }
                data[slot].x = Float(bitPattern: enabled ? 1 : 0)
            case .choice:
                let index: Int
                if case .choice(let selected) = value { index = selected } else { index = 0 }
                let values = parameter.choiceValues
                let selected = values.indices.contains(index) ? values[index] : (values.first ?? 0)
                data[slot].x = Float(bitPattern: UInt32(bitPattern: Int32(clamping: selected)))
            }
        }
        return data
    }
}

/// Isolated fragment adapter. Existing compute pipelines and effect stages are
/// unaffected. Pipeline/asset caches are bounded by the registered catalog.
final class ReferenceFragmentGPU {
    private let device: MTLDevice
    private let library: MTLLibrary
    private let inputSampler: MTLSamplerState
    private let imageSampler: MTLSamplerState
    private let lock = NSLock()
    private var pipelines: [String: MTLRenderPipelineState] = [:]
    private var textures: [String: MTLTexture] = [:]
    private var failures: [String: String] = [:]

    init(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device; self.library = library
        let sampler = MTLSamplerDescriptor()
        sampler.minFilter = .linear; sampler.magFilter = .linear
        sampler.sAddressMode = .clampToZero; sampler.tAddressMode = .clampToZero
        guard let input = device.makeSamplerState(descriptor: sampler) else { throw RenderError.pipeline("Reference input sampler") }
        inputSampler = input
        sampler.sAddressMode = .repeat; sampler.tAddressMode = .repeat
        guard let image = device.makeSamplerState(descriptor: sampler) else { throw RenderError.pipeline("Reference image sampler") }
        imageSampler = image
    }

    var diagnostics: [String: String] {
        lock.lock(); defer { lock.unlock() }; return failures
    }

    private func failure(_ key: String, _ reason: String) {
        lock.lock(); failures[key] = reason; lock.unlock()
    }

    private func pipeline(_ function: String, format: MTLPixelFormat) -> MTLRenderPipelineState? {
        let key = "\(function)/\(format.rawValue)"
        lock.lock(); let cached = pipelines[key]; lock.unlock()
        if let cached { return cached }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "referenceVertexAM35")
        descriptor.fragmentFunction = library.makeFunction(name: function)
        descriptor.colorAttachments[0].pixelFormat = format
        do {
            let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            lock.lock(); pipelines[key] = pipeline; lock.unlock()
            return pipeline
        } catch { failure(key, error.localizedDescription); return nil }
    }

    private func image(_ name: String) -> MTLTexture? {
        lock.lock(); let cached = textures[name]; lock.unlock()
        if let cached { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            failure(name, "Missing reference texture"); return nil
        }
        do {
            let texture = try MTKTextureLoader(device: device).newTexture(URL: url,
                options: [.SRGB: false, .generateMipmaps: false, .origin: MTKTextureLoader.Origin.topLeft])
            lock.lock(); textures[name] = texture; lock.unlock()
            return texture
        } catch { failure(name, error.localizedDescription); return nil }
    }

    func render(_ effect: ReferenceFragmentDefinition, _ context: EffectContext) -> MTLTexture {
        guard let pipeline = pipeline(effect.function, format: context.input.pixelFormat) else { return context.input }
        let images = effect.images.compactMap { image($0) }
        guard images.count == effect.images.count else { return context.input }
        let output = context.temp()
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = context.cb.makeRenderCommandEncoder(descriptor: pass) else {
            failure(effect.id, "Could not create reference render encoder"); return context.input
        }
        encoder.label = effect.name
        encoder.setRenderPipelineState(pipeline)
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(output.width), height: Double(output.height), znear: 0, zfar: 1))
        let uniforms = effect.uniforms(context)
        uniforms.withUnsafeBytes { bytes in
            encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 0)
        }
        encoder.setFragmentTexture(context.input, index: 0)
        encoder.setFragmentSamplerState(inputSampler, index: 0)
        for (index, image) in images.enumerated() {
            encoder.setFragmentTexture(image, index: index + 1)
            encoder.setFragmentSamplerState(imageSampler, index: index + 1)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return output
    }
}
