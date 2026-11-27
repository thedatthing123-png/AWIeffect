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
    var component: Int = 0
    var pointMinimum: Vec2? = nil
    var pointMaximum: Vec2? = nil
    var choiceValues: [Int] = []
    var choiceTargets: [[String]] = []
}

struct ReferenceFragmentBuffer {
    let name: String
    let binding: Int
    let downsample: Int
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
    var buffers: [ReferenceFragmentBuffer] = []
    /// Empty target names denote the final image; all other targets are named
    /// scratch buffers. The source pass order is retained, including downsampling.
    var passes: [String] = []
    var referenceBinding: Int? = nil
    var sourceID: String = ""
    var externalPasses: [Int: String] = [:]
    var sourcePasses: [Int: String] = [:]
    var iterationParameter: String? = nil

    var definition: EffectDefinition {
        var result=EffectDefinition(id: id, name: name, category: category, aeMatchNames: [], summary: summary,
            params: parameters.map(\.definition), stage: .pixels { context in
                if self.referenceBinding != nil && context.reference == nil { return context.input }
                if self.id == "awi.amref.e4dc1ec616108",
                   let tint = context.effect.params["ballColor"] ?? self.parameters.first(where: { $0.definition.id == "ballColor" })?.definition.defaultValue,
                   tint.color(at:context.time).a <= 0 { return context.input }
                return context.gpu.referenceFragments.render(self, context)
            })
        if id == "awi.amref.e7b0d60717ad7" {
            result.expandedMargin={ effect,time,size in
                let length=effect.params["size"]?.number(at:time) ?? 0.25
                return min(2048,max(size.x,size.y)*min(1,max(0,length))+2)
            }
        }
        return result
    }

    func uniforms(_ context: EffectContext, outputSize: SIMD2<Int>? = nil, pass: Int = 0) -> [SIMD4<Float>] {
        var data = [SIMD4<Float>](repeating: .zero, count: slots)
        let width = Float(outputSize?.x ?? context.width), height = Float(outputSize?.y ?? context.height)
        let original = EffectRegistry.layerRect(context)
        let rx = width / Float(context.width), ry = height / Float(context.height)
        let rect = original * SIMD4(rx, ry, rx, ry)
        let source = context.effect.imported
        let shaderTime = source?.phaseOrigin.map { (context.time - $0) * (source?.rateScale ?? 1) } ?? context.time
        data[0] = SIMD4(width, height, Float(shaderTime), Float(context.height))
        data[1] = rect
        let composition = context.compositionPixels ?? SIMD2(Double(context.width), Double(context.height))
        data[2] = SIMD4(Float(composition.x), Float(composition.y), Float(bitPattern: UInt32(clamping: pass)), Float(context.width))
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
                data[slot][parameter.component] = Float(min(maximum, max(minimum, value.number(at: context.time)))) * parameter.scalarScale
            case .angle:
                data[slot][parameter.component] = Float(value.number(at: context.time))
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
    private let empty: MTLTexture
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
        let blank = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 1, height: 1, mipmapped: false)
        blank.storageMode = .shared; blank.usage = [.shaderRead]
        guard let empty = device.makeTexture(descriptor: blank) else { throw RenderError.pipeline("Reference empty buffer") }
        let zeros = [UInt16](repeating: 0, count: 4)
        zeros.withUnsafeBytes { empty.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 8) }
        self.empty = empty
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
        render(effect,context,depth:0)
    }

    private func render(_ effect: ReferenceFragmentDefinition, _ context: EffectContext, depth:Int) -> MTLTexture {
        guard depth<8 else { failure(effect.id,"Recursive reference pass graph");return context.input }
        let parameter=effect.iterationParameter.flatMap { key in effect.parameters.first { $0.definition.id == key } }
        let requested=parameter.map { (context.effect.params[$0.definition.id] ?? $0.definition.defaultValue).number(at:context.time) } ?? 1
        let iterations=Int(min(12,max(1,requested)))
        var output=context.input
        for _ in 0..<iterations {
            let next=EffectContext(gpu:context.gpu,cb:context.cb,input:output,effect:context.effect,time:context.time,
                                  unit:context.unit,pool:context.pool,reference:context.reference,
                                  layerPixels:context.layerPixels,compositionPixels:context.compositionPixels)
            output=renderPasses(effect,next,depth:depth)
        }
        return output
    }

    private func renderPasses(_ effect: ReferenceFragmentDefinition, _ context: EffectContext, depth:Int) -> MTLTexture {
        guard let pipeline = pipeline(effect.function, format: context.input.pixelFormat) else { return context.input }
        let images = effect.images.compactMap { image($0) }
        guard images.count == effect.images.count else { return context.input }
        var scratch: [String: MTLTexture] = [:]
        let stages = effect.passes.isEmpty ? [""] : effect.passes
        var final = context.input
        for (index, target) in stages.enumerated() {
            if let sourceID = effect.externalPasses[index] {
                guard let dependency = ReferenceFragmentCatalog.bySourceID[sourceID],
                      dependency.id != effect.id else {
                    failure(effect.id, "Unresolved or recursive reference pass: " + sourceID); return context.input
                }
                var instance = dependency.definition.makeInstance()
                for parameter in dependency.parameters {
                    let key=parameter.definition.id
                    guard let parent=effect.parameters.first(where:{$0.definition.id==key}) else { continue }
                    let value=context.effect.params[key] ?? parent.definition.defaultValue
                    switch (parent.definition.kind,parameter.definition.kind) {
                    case (.number,.number),(.angle,.number),(.number,.angle),(.angle,.angle):
                        var number=value.number(at:context.time)
                        if case .number(let low,let high,_,_) = parent.definition.kind { number=min(high,max(low,number)) }
                        number *= Double(parent.scalarScale)/Double(parameter.scalarScale)
                        instance.params[key] = .number(Animated(number))
                    case (.choice,.choice):
                        let selected:Int
                        if case .choice(let index)=value { selected=index } else { selected=0 }
                        let raw=parent.choiceValues.indices.contains(selected) ? parent.choiceValues[selected] : (parent.choiceValues.first ?? 0)
                        instance.params[key] = .choice(parameter.choiceValues.firstIndex(of:raw) ?? 0)
                    case (.point,.point),(.color,.color),(.toggle,.toggle): instance.params[key]=value
                    default: break
                    }
                }
                let input:MTLTexture
                if let source=effect.sourcePasses[index] {
                    guard let texture=scratch[source] else { failure(effect.id,"Missing pass input: "+source);return context.input }
                    input=texture
                } else { input=context.input }
                let nested = EffectContext(gpu: context.gpu, cb: context.cb, input: input, effect: instance,
                    time: context.time, unit: context.unit, pool: context.pool, reference: context.reference,
                    layerPixels: context.layerPixels, compositionPixels: context.compositionPixels)
                let output = render(dependency, nested, depth:depth+1)
                if target.isEmpty { final = output } else { scratch[target] = output }
                continue
            }
            let scale = effect.buffers.first(where: { $0.name == target })?.downsample ?? 1
            let output = context.pool.acquire(width: max(1, context.width / scale), height: max(1, context.height / scale), format: context.input.pixelFormat)
            guard encode(effect, context, pipeline: pipeline, images: images, scratch: scratch, output: output, index: index) else { return context.input }
            if target.isEmpty { final = output } else { scratch[target] = output }
        }
        return final
    }

    private func encode(_ effect: ReferenceFragmentDefinition, _ context: EffectContext,
                        pipeline: MTLRenderPipelineState, images: [MTLTexture], scratch: [String: MTLTexture],
                        output: MTLTexture, index: Int) -> Bool {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = context.cb.makeRenderCommandEncoder(descriptor: pass) else {
            failure(effect.id, "Could not create reference render encoder"); return false
        }
        encoder.label = effect.name
        encoder.setRenderPipelineState(pipeline)
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(output.width), height: Double(output.height), znear: 0, zfar: 1))
        let uniforms = effect.uniforms(context, outputSize: SIMD2(output.width, output.height), pass: index)
        uniforms.withUnsafeBytes { bytes in
            encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 0)
        }
        encoder.setFragmentTexture(context.input, index: 0)
        encoder.setFragmentSamplerState(inputSampler, index: 0)
        for (index, image) in images.enumerated() {
            encoder.setFragmentTexture(image, index: index + 1)
            encoder.setFragmentSamplerState(imageSampler, index: index + 1)
        }
        for buffer in effect.buffers {
            encoder.setFragmentTexture(scratch[buffer.name] ?? empty, index: buffer.binding)
            encoder.setFragmentSamplerState(inputSampler, index: buffer.binding)
        }
        if let binding = effect.referenceBinding {
            encoder.setFragmentTexture(context.reference ?? empty, index: binding)
            encoder.setFragmentSamplerState(inputSampler, index: binding)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return true
    }
}


extension EffectRegistry {
    static let reviewedReferenceEffects: [EffectDefinition] = ReferenceFragmentCatalog.promoted.map { $0.definition }
}


enum ReferenceFragmentControls {
    private static let reviewed = Dictionary(uniqueKeysWithValues: ReferenceFragmentCatalog.all.map { ($0.id, $0) })

    static func pointParameter(_ typeID: String, _ key: String) -> ReferenceFragmentParameter? {
        var sourceID=typeID,sourceKey=key
        if typeID == "awi.am35.fractalRidges" || typeID == "awi.animatedFractalRidges" {
            sourceID="awi.amref.e1fc2d92d8130"
            if key == "parallax" { sourceKey="parr" }
            if key == "offset" { sourceKey="offs" }
        } else if typeID == "awi20.fractalWarp" {
            sourceID="awi.amref.e7efd76a1919d"
            if key == "parallax" { sourceKey="parr" }
            if key == "position" { sourceKey="offs" }
        }
        return reviewed[sourceID]?.parameters.first { $0.definition.id == sourceKey }
    }

    /// Native point controls include offsets and stretch vectors, not only
    /// normalized positions. Do not put a misleading canvas crosshair on them.
    static func canvasPoint(_ typeID: String, _ key: String, _ value: Vec2, inverse: Bool = false) -> Vec2? {
        guard let parameter = pointParameter(typeID, key) else { return value }
        if typeID == "awi.amref.e7b0d60717ad7", key == "light" {
            return inverse ? Vec2((value.x-0.5)*1000, (0.5-value.y)*1000) : Vec2(0.5+value.x/1000, 0.5-value.y/1000)
        }
        if parameter.pointMinimum == Vec2(0,0), parameter.pointMaximum == Vec2(1,1) { return value }
        return nil
    }

    static func isVisible(_ parameterID: String, effect: EffectInstance, time: Double = 0) -> Bool {
        guard let definition = reviewed[effect.typeID] else { return true }
        if effect.typeID == "awi.amref.ec88108d754e8" {
            let pattern = effect.choice("preset")
            if ["colorR", "colorG", "colorB"].contains(parameterID) { return effect.choice("colorMode") == 1 }
            if parameterID == "density" { return pattern == 5 }
            if parameterID == "frequency" { return [0,1,2,3,6,7].contains(pattern) }
            if parameterID == "phase" { return [0,1,2,3,7].contains(pattern) }
            if parameterID == "orientation" { return [0,1,6].contains(pattern) }
            if ["distortion", "animSpeed", "generators"].contains(parameterID) { return pattern != 4 }
        }
        if effect.typeID == "awi.amref.e4dc1ec616108", parameterID == "sizeVar" { return effect.bool("randomSize") }
        if effect.typeID == "awi.amref.e9e78f72e74ef", ["color2", "color3"].contains(parameterID) { return effect.choice("typeComet") == 0 }
        if effect.typeID == "awi.amref.e7b0d60717ad7", parameterID == "fadeType" { return effect.number("fade", time) > 0 }
        if effect.typeID == "awi.amref.edd3f3773971b", ["inkColor", "paperColor"].contains(parameterID) { return !effect.bool("alphaMode") }
        if effect.typeID == "awi.amref.e8404b5764d4f", parameterID == "seed" {
            return (effect.params["strength"]?.number(at: time) ?? 0) > 0
        }
        for controller in definition.parameters where !controller.choiceTargets.isEmpty {
            guard controller.choiceTargets.joined().contains(parameterID) else { continue }
            let value = effect.params[controller.definition.id] ?? controller.definition.defaultValue
            let index: Int
            if case .choice(let selected) = value { index = selected } else { index = 0 }
            guard controller.choiceTargets.indices.contains(index), controller.choiceTargets[index].contains(parameterID) else { return false }
        }
        if effect.typeID == "awi.amref.ea3452b1fb102", ["hueScale", "saturation", "value"].contains(parameterID) {
            return effect.params["colorizeHSV"].map { if case .toggle(let on) = $0 { return on }; return true } ?? true
        }
        return true
    }
}
