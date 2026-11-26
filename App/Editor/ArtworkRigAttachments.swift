import CoreGraphics
import Foundation
import ImageIO
import simd

enum ArtworkRigAttachments {
    static func apply(to project: inout Project, time: Double) {
        let rigs = Dictionary(project.layers.compactMap { layer in
            layer.artworkRig.map { (layer.id, $0) }
        }, uniquingKeysWith: { first, _ in first })
        var frames: [UUID: [UUID: RigAffine]] = [:]
        for i in project.layers.indices {
            guard let bone = project.layers[i].artworkRigBoneID, let owner = project.layers[i].parentID,
                  let rig = rigs[owner] else { continue }
            if frames[owner] == nil { frames[owner] = rig.pose(at: time) }
            guard let frame = frames[owner]?[bone] else { continue }
            let transform = project.layers[i].transform
            let rotation = atan2(frame.b, frame.a) * 180 / .pi
            let scale = hypot(frame.a, frame.b)
            project.layers[i].transform.position = Animated(frame.apply(transform.position.value(at: time)))
            project.layers[i].transform.rotation = Animated(transform.rotation.value(at: time) + rotation)
            project.layers[i].transform.scale = Animated(transform.scale.value(at: time) * scale)
            project.layers[i].artworkRigBoneID = nil
        }
    }
}

extension EditorState {
    func addArtworkBone(_ id: UUID, from start: Vec2, to end: Vec2) {
        guard let layer = project.layers.first(where: { $0.id == id }), !layer.isLocked,
              hypot(end.x - start.x, end.y - start.y) >= 0.1 else { return }
        var rig = layer.artworkRig ?? ArtworkRig()
        guard rig.bones.count < 128 else { return }
        let parent = artworkRigSelectedBone.flatMap { selected in
            rig.bones.first { $0.id == selected && hypot($0.end.x - start.x, $0.end.y - start.y) <= 1 }
        }
        let bone = ArtworkBone(name: "Bone \(rig.bones.count + 1)", start: parent?.end ?? start, end: end,
                               parentID: parent?.id)
        rig.bones.append(bone)
        mutate("Add Artwork Bone") { p in
            guard let index = p.layers.firstIndex(where: { $0.id == id }) else { return }
            p.layers[index].artworkRig = rig
        }
        artworkRigSelectedBone = bone.id
        artworkRigDraftStart = nil
        rigCursor = end
    }

    func bindArtworkRig(_ layer: Layer, radius: Double?) {
        guard case let .image(fileName, _, _) = layer.content else { return }
        let url = mediaURL(fileName)
        let halfSize = layer.size.value(at: currentTime) * 0.5
        let mask = Self.artworkRigAlpha(at: url)
        mutate("Bind Artwork") { project in
            guard let i = project.layers.firstIndex(where: { $0.id == layer.id }),
                  !project.layers[i].isLocked, var rig = project.layers[i].artworkRig else { return }
            rig.bind(halfSize: halfSize, artworkID: layer.id, detail: 32,
                     radius: radius, amount: rig.mesh?.amount ?? 1)
            if let mask { rig.trimTransparentCells(alpha: mask.alpha, width: mask.width, height: mask.height) }
            project.layers[i].artworkRig = rig
        }
    }

    private static func artworkRigAlpha(at url: URL) -> (alpha: [UInt8], width: Int, height: Int)? {
        let options: [String: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways as String: true,
            kCGImageSourceCreateThumbnailWithTransform as String: true,
            kCGImageSourceThumbnailMaxPixelSize as String: 256
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let width = image.width, height = image.height
        var alpha = Array(repeating: UInt8(0), count: width * height)
        let rendered = alpha.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width, space: nil,
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return rendered ? (alpha, width, height) : nil
    }

    func moveArtworkIK(_ id: UUID, bone: UUID, x: Double?, y: Double?) {
        let time = currentTime
        mutate("Move Artwork IK") { p in
            guard let i = p.layers.firstIndex(where: { $0.id == id }), !p.layers[i].isLocked,
                  var track = p.layers[i].artworkRig?.constraint(on: bone)?.target else { return }
            let before = track.value(at: time)
            let value = Vec2(x ?? before.x, y ?? before.y)
            guard value.x.isFinite, value.y.isFinite else { return }
            track.set(value, at: time)
            p.layers[i].artworkRig?.editIK(on: bone) { $0.target = track }
        }
    }

    func canAttachToArtworkRig(_ layer: Layer, owner: UUID) -> Bool {
        guard Self.isSceneArtwork(layer), !layer.isLocked, layer.id != owner, layer.artworkRig == nil,
              layer.artworkRigBoneID == nil,
              project.layers.first(where: { $0.id == owner })?.groupID == layer.groupID else { return false }
        var parent: UUID? = owner
        var visited = Set<UUID>()
        while let id = parent {
            guard id != layer.id, visited.insert(id).inserted else { return false }
            parent = project.layers.first { $0.id == id }?.parentID
        }
        return true
    }

    func paintArtworkWeights(_ id: UUID, bone: UUID, from previous: Vec2?, to point: Vec2,
                             radius: Double, brush: BoneWeightBrush) {
        let origin = previous ?? point
        let delta = point - origin
        let distance = hypot(delta.x, delta.y)
        guard distance.isFinite, previous == nil || distance >= max(1, radius * 0.15) else { return }
        let count = Int(min(32, max(1, ceil(distance / max(1, radius * 0.25)))))
        let dabs = (1...count).map { index in
            BoneWeightDab(center: origin + delta * (Double(index) / Double(count)), amount: 0.55)
        }
        mutate("Brush Bone Weights") { p in
            guard let i = p.layers.firstIndex(where: { $0.id == id }), !p.layers[i].isLocked,
                  var mesh = p.layers[i].artworkRig?.mesh,
                  let index = mesh.boneIDs.firstIndex(of: bone),
                  mesh.paint(dabs, selected: index, radius: radius, mode: brush) else { return }
            p.layers[i].artworkRig?.mesh = mesh
        }
    }

    func attachArtworkLayer(_ child: UUID, owner: UUID, bone: UUID) {
        guard let layer = project.layers.first(where: { $0.id == child }), canAttachToArtworkRig(layer, owner: owner),
              let rig = project.layers.first(where: { $0.id == owner })?.artworkRig,
              let frame = rig.pose(at: currentTime)[bone] else { return }
        let time = currentTime
        let keepID = selectedLayerID
        beginEdit("Attach Layer to Bone")
        selectedLayerID = child
        setParent(owner)
        mutate("Attach Layer to Bone") { p in
            guard let i = p.layers.firstIndex(where: { $0.id == child && $0.parentID == owner }) else { return }
            var transform = p.layers[i].transform
            let rotation = atan2(frame.b, frame.a) * 180 / .pi
            let scale = max(1e-9, hypot(frame.a, frame.b))
            transform.position.set(RigAffine(frame.matrix.inverse).apply(transform.position.value(at: time)), at: time)
            transform.rotation.set(transform.rotation.value(at: time) - rotation, at: time)
            transform.scale.set(transform.scale.value(at: time) * (1 / scale), at: time)
            p.layers[i].transform = transform
            p.layers[i].artworkRigBoneID = bone
        }
        selectedLayerID = keepID
        endEdit()
    }
}
