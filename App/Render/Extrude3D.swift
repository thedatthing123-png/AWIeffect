import Foundation
import UIKit
import SceneKit

/// Turns 2D layers into real extruded 3D geometry (Alight Motion "3D element" style).
enum Extrude3D {
    /// Outline of any shape layer as a bezier in layer-local px (y down), including polygons and stars.
    static func outline(_ layer: Layer, time: Double) -> BezierPath? {
        guard case .shape(let k) = layer.content else { return nil }
        let s = layer.size.value(at: time)
        switch k {
        case .path: return layer.path?.value(at: time)
        case .ellipse: return .ellipse(size: s)
        case .rectangle: return .rectangle(size: s)
        case .polygon, .star:
            let n = max(3, Int(layer.sides.value(at: time).rounded()))
            let star = k == .star
            let count = star ? n * 2 : n
            let inner = layer.innerRatio.value(at: time)
            let pts = (0..<count).map { i -> Vec2 in
                let a = -Double.pi / 2 + Double(i) * 2 * .pi / Double(count)
                let r = star && i % 2 == 1 ? inner : 1
                return Vec2(cos(a) * s.x / 2 * r, sin(a) * s.y / 2 * r)
            }
            return BezierPath(vertices: pts.map { PathVertex(point: $0) })
        }
    }

    /// UIKit path (y up, as SceneKit expects) from a layer-local bezier.
    static func uiPath(_ p: BezierPath) -> UIBezierPath {
        let u = UIBezierPath()
        guard let first = p.vertices.first else { return u }
        func f(_ v: Vec2) -> CGPoint { CGPoint(x: v.x, y: -v.y) }
        u.move(to: f(first.point))
        let n = p.vertices.count
        for i in 0..<(p.closed ? n : n - 1) {
            let a = p.vertices[i], b = p.vertices[(i + 1) % n]
            if a.outTangent == .zero && b.inTangent == .zero { u.addLine(to: f(b.point)) }
            else { u.addCurve(to: f(b.point), controlPoint1: f(a.point + a.outTangent), controlPoint2: f(b.point + b.inTangent)) }
        }
        u.close()
        return u
    }

    /// Silhouette of an image's alpha as closed polygons (y up, centered on the opaque bounds), plus the crop
    /// rectangle (pixels) those bounds cover so the front texture lines up.
    static func alphaOutline(_ image: CGImage, maxSide: Int = 220, threshold: UInt8 = 110) -> (path: UIBezierPath, crop: CGRect)? {
        let sc = min(1, Double(maxSide) / Double(max(image.width, image.height)))
        let w = max(2, Int(Double(image.width) * sc)), h = max(2, Int(Double(image.height) * sc))
        var px = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        // CGContext rows run bottom-up; flip into top-down rows.
        func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h && px[(h - 1 - y) * w + x] >= threshold }
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h { for x in 0..<w where inside(x, y) { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } }
        guard maxX >= minX else { return nil }

        // Directed pixel-boundary edges (inside on the right going clockwise in y-down space), then chain them.
        var next: [Int: [Int]] = [:]
        func key(_ x: Int, _ y: Int) -> Int { y * (w + 1) + x }
        for y in minY...maxY { for x in minX...maxX where inside(x, y) {
            if !inside(x, y - 1) { next[key(x, y), default: []].append(key(x + 1, y)) }
            if !inside(x + 1, y) { next[key(x + 1, y), default: []].append(key(x + 1, y + 1)) }
            if !inside(x, y + 1) { next[key(x + 1, y + 1), default: []].append(key(x, y + 1)) }
            if !inside(x - 1, y) { next[key(x, y + 1), default: []].append(key(x, y)) }
        } }
        let cx = Double(minX + maxX + 1) / 2, cy = Double(minY + maxY + 1) / 2
        let path = UIBezierPath()
        path.usesEvenOddFillRule = true
        while let start = next.keys.first {
            var loop: [Vec2] = []
            var cur = start
            while var outs = next[cur], !outs.isEmpty {
                let to = outs.removeLast()
                next[cur] = outs.isEmpty ? nil : outs
                loop.append(Vec2(Double(cur % (w + 1)), Double(cur / (w + 1))))
                cur = to
                if cur == start { break }
            }
            next[start] = next[start]?.isEmpty == true ? nil : next[start]
            guard loop.count >= 4 else { continue }
            // Chaikin smoothing knocks the pixel stairs off.
            var pts = loop
            for _ in 0..<2 {
                var o: [Vec2] = []
                for i in pts.indices { let a = pts[i], b = pts[(i + 1) % pts.count]; o.append(a * 0.75 + b * 0.25); o.append(a * 0.25 + b * 0.75) }
                pts = o
            }
            path.move(to: CGPoint(x: pts[0].x - cx, y: -(pts[0].y - cy)))
            for p in pts.dropFirst() { path.addLine(to: CGPoint(x: p.x - cx, y: -(p.y - cy))) }
            path.close()
        }
        let crop = CGRect(x: Double(minX) / sc, y: Double(minY) / sc, width: Double(maxX - minX + 1) / sc, height: Double(maxY - minY + 1) / sc)
        return (path, crop)
    }

    /// Extruded SceneKit geometry for an options set (shape outline or image silhouette), or nil for text/models.
    static func geometry(_ o: Model3DOptions, mediaURL: (String) -> URL) -> (geometry: SCNGeometry, front: SCNMaterial?)? {
        if let p = o.shapePath {
            let s = SCNShape(path: uiPath(p), extrusionDepth: CGFloat(o.extrusion))
            s.chamferRadius = CGFloat(min(o.chamfer, o.extrusion / 2))
            return (s, nil)
        }
        if let f = o.imageFile, let img = UIImage(contentsOfFile: mediaURL(f).path)?.cgImage,
           let out = alphaOutline(img) {
            // Scale the silhouette back to source pixels so depth/bevel keep their meaning.
            let k = out.crop.width / max(out.path.bounds.width, 1)
            out.path.apply(CGAffineTransform(scaleX: k, y: k))
            out.path.flatness = 0.6
            let s = SCNShape(path: out.path, extrusionDepth: CGFloat(o.extrusion))
            s.chamferRadius = CGFloat(min(o.chamfer, o.extrusion / 2))
            var front: SCNMaterial?
            if let cropped = img.cropping(to: out.crop) {
                let m = SCNMaterial()
                m.diffuse.contents = UIImage(cgImage: cropped)
                m.lightingModel = .physicallyBased
                m.roughness.contents = o.roughness
                m.metalness.contents = 0.0
                front = m
            }
            return (s, front)
        }
        return nil
    }
}

extension EditorState {
    /// Converts the selected shape / text / image / drawing into a real extruded 3D object; video becomes a thick 3D card.
    func makeSelected3DObject() {
        guard let l = selectedLayer else { return }
        let t = currentTime
        var o = Model3DOptions()
        o.yaw = Animated(-28); o.pitch = Animated(14)
        o.metalness = 0.15; o.roughness = 0.45
        switch l.content {
        case .shape:
            guard let p = Extrude3D.outline(l, time: t) else { return }
            o.shapePath = p
            o.color = Animated(l.fill.value(at: t))
            o.extrusion = max(10, min(l.size.value(at: t).x, l.size.value(at: t).y) * 0.25)
            o.chamfer = o.extrusion * 0.12
        case .text:
            guard let d = l.text else { return }
            o.text = d.string; o.fontName = d.fontName
            o.color = Animated(d.fill.value(at: t))
        case .image(let file, _, _):
            o.imageFile = file
            o.color = Animated(RGBA(0.85, 0.85, 0.9))
            o.extrusion = 40; o.chamfer = 3
        case .video, .precomp, .solid:
            mutate("Make 3D") { p in
                guard let i = self.selectedIndex else { return }
                p.layers[i].is3D = true
                p.layers[i].extrude = Animated(40)
                p.layers[i].transform.rotationY = Animated(-25)
                p.layers[i].transform.rotationX = Animated(12)
            }
            panel = .threeD
            return
        default: return
        }
        let size = Renderer.layerHalfSize(l, time: t)
        mutate("Make 3D Object") { p in
            guard let i = self.selectedIndex else { return }
            p.layers[i].content = .model
            p.layers[i].model3D = o
            // Enough room for the object as it turns.
            let side = max(size.x, size.y) * 2.6
            p.layers[i].size = Animated(Vec2(side, side))
        }
        panel = .model
    }
}
