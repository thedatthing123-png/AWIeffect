import SwiftUI
import simd

/// Mesh soft body (XPBD, Mueller et al.): a particle grid over the layer's own shape with stretch + shear springs,
/// area preservation (so squashing bulges sideways, like Blender's soft body), per-point floor contact, friction and
/// plasticity (slime / pudding keep their splat). Baked to a cache the Soft Body effect draws every frame.
extension SoftMaterial {
    /// (compliance: softness, area compliance, damping /s, friction, plastic flow /s, bounce)
    var mesh: (compliance: Double, area: Double, damp: Double, friction: Double, plastic: Double, bounce: Double) {
        switch self {
        case .jelly: return (2e-5, 1e-6, 0.6, 0.5, 0, 0.3)
        case .rubber: return (2e-6, 2e-7, 1.0, 0.7, 0, 0.75)
        case .slime: return (6e-5, 5e-6, 3.0, 0.9, 2.5, 0.0)
        case .pudding: return (4e-5, 2e-6, 2.0, 0.8, 0.6, 0.1)
        case .stiff: return (2e-7, 1e-8, 2.0, 0.6, 0, 0.3)
        }
    }
}

extension EditorState {
    func bakeSoftMesh(_ m: SoftMaterial, drop: Double, gravity: Double, duration: Double, floorAtBottom: Bool,
                      throwX: Double = 0, progress: @escaping (Double) -> Void) {
        guard let i = selectedIndex else { return }
        let l = project.layers[i]
        let hs = Renderer.layerHalfSize(l, time: currentTime)
        guard hs.x > 1, hs.y > 1 else { return }
        // Grid: ~26 points across the longer side.
        let cells = 26.0
        let step = max(hs.x, hs.y) * 2 / cells
        let nx = max(4, Int((hs.x * 2 / step).rounded()) + 1), ny = max(4, Int((hs.y * 2 / step).rounded()) + 1)
        // Which grid points are inside the layer's visible shape (alpha), from a render of the layer alone.
        var solo = project
        solo.layers = [l]
        solo.background = RGBA(0, 0, 0, 0)
        let scale = min(1.0, 900 / Double(max(project.width, project.height)))
        let img = Renderer.shared?.renderImage(project: solo, time: currentTime, maxDimension: Double(max(project.width, project.height)) * scale,
                                               mediaURL: { self.mediaURL($0) })?.cgImage
        var alpha: [UInt8] = []
        var aw = 0, ah = 0
        if let img {
            aw = img.width; ah = img.height
            alpha = [UInt8](repeating: 0, count: aw * ah * 4)
            alpha.withUnsafeMutableBytes { buf in
                let ctx = CGContext(data: buf.baseAddress, width: aw, height: ah, bitsPerComponent: 8, bytesPerRow: aw * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                ctx?.draw(img, in: CGRect(x: 0, y: 0, width: aw, height: ah))
            }
        }
        let compW = Double(project.width)
        func inside(_ local: SIMD2<Double>) -> Bool {
            guard aw > 0, let c = compPoint(fromLocal: Vec2(local.x, local.y)) else { return true }
            let k = Double(aw) / compW
            for (dx, dy) in [(0.0, 0.0), (0.3, 0.0), (-0.3, 0.0), (0.0, 0.3), (0.0, -0.3)] {
                let x = Int((c.x + dx * step) * k), y = Int((c.y + dy * step) * k)
                if x >= 0, y >= 0, x < aw, y < ah, alpha[(y * aw + x) * 4 + 3] > 20 { return true }
            }
            return false
        }
        var rest: [SIMD2<Double>] = []
        var active: [Bool] = []
        for j in 0..<ny { for ii in 0..<nx {
            let p = SIMD2(-hs.x + 2 * hs.x * Double(ii) / Double(nx - 1), -hs.y + 2 * hs.y * Double(j) / Double(ny - 1))
            rest.append(p); active.append(inside(p))
        } }
        let pos0 = l.transform.position.value(at: currentTime)
        let floorY: Double = {
            if floorAtBottom, let fl = layerLocal(fromComp: Vec2(pos0.x, Double(project.height))) { return fl.y }
            return hs.y
        }()
        let t0 = currentTime
        let fps = 30.0
        let mp = m.mesh
        let projID = project.id, store = self.store
        Task.detached(priority: .userInitiated) {
            let n = rest.count
            var x = rest.map { $0 - SIMD2(0, drop) }
            var v = [SIMD2<Double>](repeating: SIMD2(throwX, 0), count: n)
            let w: [Double] = active.map { $0 ? 1 : 4 }        // inactive (outside the shape) points are light followers
            // Constraints: structural + shear distances, and cell areas.
            struct Dist { let a: Int; let b: Int; var L: Double; var lambda = 0.0 }
            struct Area { let a: Int; let b: Int; let c: Int; var A: Double; var lambda = 0.0 }
            var dists: [Dist] = [], areas: [Area] = []
            func id(_ i: Int, _ j: Int) -> Int { j * nx + i }
            for j in 0..<ny { for ii in 0..<nx {
                for (di, dj) in [(1, 0), (0, 1), (1, 1), (-1, 1)] {
                    let i2 = ii + di, j2 = j + dj
                    guard i2 >= 0, i2 < nx, j2 < ny else { continue }
                    let a = id(ii, j), b = id(i2, j2)
                    dists.append(Dist(a: a, b: b, L: simd_length(rest[b] - rest[a])))
                }
                if ii < nx - 1, j < ny - 1 {
                    for (a, b, c) in [(id(ii, j), id(ii + 1, j), id(ii, j + 1)), (id(ii + 1, j), id(ii + 1, j + 1), id(ii, j + 1))] {
                        let A = simd_cross(SIMD3(rest[b] - rest[a], 0), SIMD3(rest[c] - rest[a], 0)).z * 0.5
                        areas.append(Area(a: a, b: b, c: c, A: A))
                    }
                }
            } }
            let dt = 1.0 / 240, sub = 4, h = dt / Double(sub)
            let steps = Int(duration / dt), every = max(1, Int(1 / fps / dt))
            var frames: [Float] = []
            frames.reserveCapacity((steps / every + 2) * n * 2)
            func record() { for p in x { frames.append(Float(p.x)); frames.append(Float(p.y)) } }
            record()
            for s in 1...max(1, steps) {
                for _ in 0..<sub {
                    var prev = x
                    for k in 0..<n {
                        v[k].y += gravity * h
                        v[k] *= max(0, 1 - mp.damp * h)
                        prev[k] = x[k]
                        x[k] += v[k] * h
                    }
                    for c in dists.indices { dists[c].lambda = 0 }
                    for c in areas.indices { areas[c].lambda = 0 }
                    for _ in 0..<2 {
                        // Distance constraints (XPBD).
                        let alphaD = mp.compliance / (h * h)
                        for c in dists.indices {
                            let d = dists[c]
                            let wa = 1 / w[d.a], wb = 1 / w[d.b]
                            let delta = x[d.b] - x[d.a], len = simd_length(delta)
                            guard len > 1e-9 else { continue }
                            let C = len - d.L
                            let dl = (-C - alphaD * d.lambda) / (wa + wb + alphaD)
                            dists[c].lambda += dl
                            let g = delta / len
                            x[d.a] -= g * dl * wa
                            x[d.b] += g * dl * wb
                        }
                        // Area preservation: squash one way, it bulges the other.
                        let alphaA = mp.area / (h * h)
                        for c in areas.indices {
                            let ar = areas[c]
                            let pa = x[ar.a], pb = x[ar.b], pc = x[ar.c]
                            let A = ((pb.x - pa.x) * (pc.y - pa.y) - (pb.y - pa.y) * (pc.x - pa.x)) * 0.5
                            let ga = SIMD2(pb.y - pc.y, pc.x - pb.x) * 0.5
                            let gb = SIMD2(pc.y - pa.y, pa.x - pc.x) * 0.5
                            let gc = SIMD2(pa.y - pb.y, pb.x - pa.x) * 0.5
                            let wa = 1 / w[ar.a], wb = 1 / w[ar.b], wc = 1 / w[ar.c]
                            let denom = wa * simd_length_squared(ga) + wb * simd_length_squared(gb) + wc * simd_length_squared(gc) + alphaA
                            guard denom > 1e-12 else { continue }
                            let C = A - ar.A
                            let dl = (-C - alphaA * ar.lambda) / denom
                            areas[c].lambda += dl
                            x[ar.a] += ga * dl * wa; x[ar.b] += gb * dl * wb; x[ar.c] += gc * dl * wc
                        }
                        // Floor: each point of the shape collides on its own (the bottom flattens first).
                        for k in 0..<n where active[k] && x[k].y > floorY {
                            let pen = x[k].y - floorY
                            x[k].y = floorY
                            // Friction: slide less the harder it presses.
                            let dx = x[k].x - prev[k].x
                            x[k].x -= dx * min(1, mp.friction * pen / max(1, abs(dx) + pen))
                        }
                    }
                    for k in 0..<n {
                        var nv = (x[k] - prev[k]) / h
                        if active[k], x[k].y >= floorY - 0.01, nv.y > 0 { nv.y = -nv.y * mp.bounce }
                        v[k] = nv
                    }
                    // Plasticity: the rest shape flows toward the current one (slime stays splatted).
                    if mp.plastic > 0 {
                        let k = mp.plastic * h
                        for c in dists.indices { let d = dists[c]; dists[c].L += (simd_length(x[d.b] - x[d.a]) - d.L) * k }
                    }
                }
                if s % every == 0 {
                    record()
                    let pr = Double(s) / Double(steps)
                    Task { @MainActor in progress(pr * 0.95) }
                }
            }
            let frameCount = frames.count / (n * 2)
            let cache = SoftMeshCache(nx: nx, ny: ny, frames: frameCount, fps: fps, data: frames)
            let file = try? store.importMedia(data: cache.encoded(), ext: "awisoft", into: projID)
            await MainActor.run {
                guard let file else { progress(1); return }
                self.mutate("Soft Body (\(m.title))") { pr in
                    guard let li = pr.layers.firstIndex(where: { $0.id == l.id }) else { return }
                    pr.layers[li].effects.removeAll { $0.typeID == EffectRegistry.softBody20.id || $0.typeID == EffectRegistry.puppet18.id }
                    var e = EffectRegistry.softBody20.makeInstance()
                    e.text = ["file": file]
                    e.params["start"] = .number(Animated(t0))
                    pr.layers[li].effects.insert(e, at: 0)
                    if t0 + duration > pr.duration { pr.duration = t0 + duration }
                }
                self.redrawToken += 1
                progress(1)
            }
        }
    }
}
