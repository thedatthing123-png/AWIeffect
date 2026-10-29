import Foundation
import Metal
import MetalKit
import simd
import UIKit

/// Must match `LayerParams` in Shaders.metal.
struct LayerParams {
    var invRow0: SIMD4<Float>
    var invRow1: SIMD4<Float>
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
    private let clearPSO: MTLComputePipelineState
    private let drawPSO: MTLComputePipelineState
    private let toBGRAPSO: MTLComputePipelineState
    let displayPSO: MTLRenderPipelineState
    private let loader: MTKTextureLoader
    private let dummy: MTLTexture
    private var imageCache: [String: MTLTexture] = [:]
    private let cacheLock = NSLock()

    static let compFormat: MTLPixelFormat = .rgba16Float

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
        toBGRAPSO = try compute("compToBGRA")
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
        ])
        if let t { imageCache[key] = t }
        return t
    }

    func clearImageCache() {
        cacheLock.lock(); imageCache.removeAll(); cacheLock.unlock()
    }

    // MARK: Compositing

    /// Forward affine (layer local px, centered) -> comp px at render scale.
    static func layerMatrix(_ layer: Layer, time: Double, renderScale: Double) -> simd_double3x3 {
        let t = layer.transform
        let pos = t.position.value(at: time)
        let anc = t.anchor.value(at: time)
        let sc = t.scale.value(at: time)
        let rot = t.rotation.value(at: time) * .pi / 180
        let T = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(pos.x, pos.y, 1)))
        let R = simd_double3x3(columns: (SIMD3(cos(rot), sin(rot), 0), SIMD3(-sin(rot), cos(rot), 0), SIMD3(0, 0, 1)))
        let S = simd_double3x3(diagonal: SIMD3(sc.x / 100, sc.y / 100, 1))
        let A = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-anc.x, -anc.y, 1)))
        let RS = simd_double3x3(diagonal: SIMD3(renderScale, renderScale, 1))
        return RS * T * R * S * A
    }

    static func layerHalfSize(_ layer: Layer, time: Double) -> Vec2 {
        let s = layer.size.value(at: time)
        return Vec2(abs(s.x) / 2, abs(s.y) / 2)
    }

    /// Encodes the full composition at `time` into `comp` (size = project size * renderScale).
    func encode(project: Project, time: Double, renderScale: Double, into comp: MTLTexture,
                commandBuffer cb: MTLCommandBuffer, mediaURL: (String) -> URL) {
        guard let enc = cb.makeComputeCommandEncoder() else { return }
        let w = comp.width, h = comp.height

        enc.setComputePipelineState(clearPSO)
        enc.setTexture(comp, index: 0)
        var bg = project.background.simd
        enc.setBytes(&bg, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        dispatch(enc, pso: clearPSO, width: w, height: h)

        enc.setComputePipelineState(drawPSO)
        // layers[0] is the top layer, so draw bottom-up.
        for layer in project.layers.reversed() where layer.isActive(at: time) {
            let opacity = layer.transform.opacity.value(at: time) / 100
            if opacity <= 0 { continue }
            let M = Self.layerMatrix(layer, time: time, renderScale: renderScale)
            let det = M[0][0] * M[1][1] - M[1][0] * M[0][1]
            if abs(det) < 1e-9 { continue }
            let inv = M.inverse
            let hs = Self.layerHalfSize(layer, time: time)
            let sc = layer.transform.scale.value(at: time)
            let pxPerLocal = max(1e-4, min(abs(sc.x), abs(sc.y)) / 100 * renderScale)
            let aa = 1 / pxPerLocal

            // Bounding box in comp px (+ AA margin).
            let m = 2 * aa
            var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
            for cx in [-hs.x - m, hs.x + m] {
                for cy in [-hs.y - m, hs.y + m] {
                    let p = M * SIMD3(cx, cy, 1)
                    minX = min(minX, p.x); maxX = max(maxX, p.x)
                    minY = min(minY, p.y); maxY = max(maxY, p.y)
                }
            }
            let x0 = max(0, Int(floor(minX))), y0 = max(0, Int(floor(minY)))
            let x1 = min(w, Int(ceil(maxX))), y1 = min(h, Int(ceil(maxY)))
            if x1 <= x0 || y1 <= y0 { continue }

            var contentKind: UInt32 = 0
            var shape: UInt32 = 0
            var tex: MTLTexture = dummy
            switch layer.content {
            case .shape(let k): shape = k.shaderIndex
            case .solid: contentKind = 1
            case .image(let file, _, _):
                guard let t = imageTexture(url: mediaURL(file)) else { continue }
                contentKind = 2
                tex = t
            }

            var params = LayerParams(
                invRow0: SIMD4(Float(inv[0][0]), Float(inv[1][0]), Float(inv[2][0]), 0),
                invRow1: SIMD4(Float(inv[0][1]), Float(inv[1][1]), Float(inv[2][1]), 0),
                color: layer.fill.value(at: time).simd,
                geom: SIMD4(Float(hs.x), Float(hs.y), Float(opacity), Float(layer.cornerRadius.value(at: time))),
                geom2: SIMD4(Float(layer.sides.value(at: time)), Float(layer.innerRatio.value(at: time)), Float(aa), 0),
                modes: SIMD4(shape, layer.blendMode.shaderIndex, contentKind, 0),
                region: SIMD4(UInt32(x0), UInt32(y0), UInt32(x1 - x0), UInt32(y1 - y0))
            )
            enc.setTexture(comp, index: 0)
            enc.setTexture(tex, index: 1)
            enc.setBytes(&params, length: MemoryLayout<LayerParams>.stride, index: 0)
            dispatch(enc, pso: drawPSO, width: x1 - x0, height: y1 - y0)
            // Each layer reads what the previous layer wrote.
            enc.memoryBarrier(scope: .textures)
        }
        enc.endEncoding()
    }

    func encodeToBGRA(comp: MTLTexture, out: MTLTexture, commandBuffer cb: MTLCommandBuffer) {
        guard let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(toBGRAPSO)
        enc.setTexture(comp, index: 0)
        enc.setTexture(out, index: 1)
        dispatch(enc, pso: toBGRAPSO, width: out.width, height: out.height)
        enc.endEncoding()
    }

    private func dispatch(_ enc: MTLComputeCommandEncoder, pso: MTLComputePipelineState, width: Int, height: Int) {
        let tw = pso.threadExecutionWidth
        let th = max(1, pso.maxTotalThreadsPerThreadgroup / tw)
        let tg = MTLSize(width: tw, height: th, depth: 1)
        let groups = MTLSize(width: (width + tw - 1) / tw, height: (height + th - 1) / th, depth: 1)
        enc.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
    }

    // MARK: Synchronous helpers (thumbnails, tests)

    /// Renders a frame and returns straight-alpha-over-black RGBA8 pixels (row-major, top-left origin).
    func renderPixels(project: Project, time: Double, renderScale: Double = 1, mediaURL: @escaping (String) -> URL) -> (width: Int, height: Int, rgba: [UInt8])? {
        let w = max(1, Int((Double(project.width) * renderScale).rounded()))
        let h = max(1, Int((Double(project.height) * renderScale).rounded()))
        guard let comp = makeCompTexture(width: w, height: h) else { return nil }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.shaderWrite, .shaderRead]
        d.storageMode = .shared
        guard let out = device.makeTexture(descriptor: d), let cb = queue.makeCommandBuffer() else { return nil }
        encode(project: project, time: time, renderScale: renderScale, into: comp, commandBuffer: cb, mediaURL: mediaURL)
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
        let data = Data(px.rgba)
        guard let provider = CGDataProvider(data: data as CFData),
              let cg = CGImage(width: px.width, height: px.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: px.width * 4,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}
