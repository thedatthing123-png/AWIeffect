import Foundation
import Metal

extension Renderer {
    func relightTexture(_ media: RelightMedia?, sourceTime: Double, layerID: UUID,
                        pass: RelightPass, mediaURL: (String) -> URL) -> MTLTexture? {
        guard let media else { return nil }
        let url = mediaURL(media.file)
        if media.isVideo {
            var channel = Hasher()
            channel.combine(layerID)
            channel.combine(pass)
            return VideoSources.shared.texture(url: url, time: sourceTime, device: device, channel: channel.finalize())
        }
        return imageTexture(url: url)
    }

    /// Replace baked color and/or apply the imported matte at the source stage. This way
    /// effects, cutout, shadow coverage and the layer's own masks all see the same source.
    func prepareRelightSource(_ input: MTLTexture, layer: Layer, sourceTime: Double, density: Double,
                              cb: MTLCommandBuffer, mediaURL: (String) -> URL) -> MTLTexture {
        guard let surface = layer.activeRelight, let pool = currentPool else { return input }
        let base = relightTexture(surface.maps[.baseColor], sourceTime: sourceTime, layerID: layer.id, pass: .baseColor, mediaURL: mediaURL)
        let alpha = relightTexture(surface.maps[.alpha], sourceTime: sourceTime, layerID: layer.id, pass: .alpha, mediaURL: mediaURL)
        guard base != nil || alpha != nil else { return input }
        let scale = min(1, max(0.05, density))
        let out = pool.acquire(width: max(1, Int((Double(input.width) * scale).rounded())),
                               height: max(1, Int((Double(input.height) * scale).rounded())))
        var params = EffectParams()
        params.i.x = base == nil ? 0 : 1
        params.i.y = alpha == nil ? 0 : 1
        fx.run("fxRelightSource", cb, textures: [input, out, base ?? input, alpha ?? input], params: params, grid: out)
        return out
    }
}
