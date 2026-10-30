import Foundation
import AVFoundation
import UIKit

extension EditorState {
    /// Swaps a layer's source for a new image or video, keeping its timing, transform, masks and effects.
    /// Placeholders created by the After Effects importer are replaced this way.
    func replaceMedia(layerID: UUID, url: URL?, imageData: Data?) {
        guard let i = project.layers.firstIndex(where: { $0.id == layerID }) else { return }
        var content: LayerContent?
        var size = project.layers[i].size.staticValue
        if let data = imageData, let img = UIImage(data: data), let cg = img.cgImage,
           let name = try? store.importMedia(data: data, ext: "png", into: project.id) {
            content = .image(fileName: name, pixelWidth: cg.width, pixelHeight: cg.height)
            size = Vec2(Double(cg.width), Double(cg.height))
        } else if let url, let data = try? Data(contentsOf: url),
                  let name = try? store.importMedia(data: data, ext: url.pathExtension.isEmpty ? "mov" : url.pathExtension, into: project.id) {
            let asset = AVURLAsset(url: store.mediaURL(name, projectID: project.id))
            guard let track = asset.tracks(withMediaType: .video).first else { return }
            let s = track.naturalSize.applying(track.preferredTransform)
            content = .video(fileName: name, pixelWidth: Int(abs(s.width)), pixelHeight: Int(abs(s.height)),
                             hasAudio: !asset.tracks(withMediaType: .audio).isEmpty)
            size = Vec2(Double(abs(s.width)), Double(abs(s.height)))
        }
        guard let content else { return }
        let old = project.layers[i].size.staticValue
        mutate("Replace Media") { p in
            p.layers[i].content = content
            // Keep the on-screen size the placeholder had (like AE's Replace Footage).
            let k = min(old.x / max(size.x, 1), old.y / max(size.y, 1))
            let sc = p.layers[i].transform.scale.staticValue
            p.layers[i].size = Animated(size)
            if !p.layers[i].transform.scale.isAnimated { p.layers[i].transform.scale = Animated(Vec2(sc.x * k, sc.y * k)) }
            p.layers[i].fill = Animated(.white)
        }
        AudioPreview.shared.invalidate()
    }
}
