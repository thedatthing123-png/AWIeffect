import Foundation
import CoreText
import CoreGraphics
import simd

/// Cache key for one glyph's extruded mesh. Values are quantized so tiny keyframe changes reuse meshes.
struct Text3DMeshKey: Hashable {
    var fontName: String
    var fontSize: Int      // 1/100 pt
    var glyph: CGGlyph
    var extrusion: Int     // 1/4 px
    var bevelSize: Int     // 1/20 px
    var bevelSegments: Int
    var profile: Text3DBevelProfile

    init(fontName: String, fontSize: Double, glyph: CGGlyph, extrusion: Double, bevelSize: Double,
         bevelSegments: Int, profile: Text3DBevelProfile) {
        self.fontName = fontName
        self.fontSize = Int((max(0.5, fontSize) * 100).rounded())
        self.glyph = glyph
        self.extrusion = Int((max(0, extrusion) * 4).rounded())
        self.bevelSize = profile == .flat ? 0 : Int((max(0, bevelSize) * 20).rounded())
        self.bevelSegments = profile == .round ? max(1, min(16, bevelSegments)) : 1
        self.profile = profile
    }
}

/// Real geometry for one glyph: front/back caps, bevel rings and extruded sides, with normals.
/// Glyph space: CoreText points at the font size, x right, y up, origin on the baseline at the glyph origin;
/// z toward the viewer, the front face at +extrusion/2 and the back face at -extrusion/2.
final class Text3DMesh {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    /// Triangle index lists (counter-clockwise seen from outside) per surface part.
    let front: [UInt32]
    let back: [UInt32]
    let bevel: [UInt32]
    let side: [UInt32]
    /// Glyph-space bounds (min, max).
    let bounds: (SIMD3<Float>, SIMD3<Float>)

    var isEmpty: Bool { front.isEmpty && side.isEmpty }

    init(positions: [SIMD3<Float>], normals: [SIMD3<Float>], front: [UInt32], back: [UInt32], bevel: [UInt32], side: [UInt32]) {
        self.positions = positions; self.normals = normals
        self.front = front; self.back = back; self.bevel = bevel; self.side = side
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for p in positions { lo = simd_min(lo, p); hi = simd_max(hi, p) }
        bounds = positions.isEmpty ? (.zero, .zero) : (lo, hi)
    }

    // MARK: Cache

    private static var cache: [Text3DMeshKey: Text3DMesh] = [:]
    private static var missing: Set<Text3DMeshKey> = []
    private static let cacheLock = NSLock()

    /// Cached mesh for a glyph (nil for glyphs without outline, e.g. space).
    static func mesh(for key: Text3DMeshKey) -> Text3DMesh? {
        cacheLock.lock()
        if let m = cache[key] { cacheLock.unlock(); return m }
        if missing.contains(key) { cacheLock.unlock(); return nil }
        cacheLock.unlock()
        let built = build(key)
        cacheLock.lock()
        if cache.count >= 768 { cache.removeAll(); missing.removeAll() }
        if let built { cache[key] = built } else { missing.insert(key) }
        cacheLock.unlock()
        return built
    }

    static func mesh(glyph: CGGlyph, fontName: String, fontSize: Double, extrusion: Double, bevelSize: Double,
                     bevelSegments: Int, profile: Text3DBevelProfile) -> Text3DMesh? {
        mesh(for: Text3DMeshKey(fontName: fontName, fontSize: fontSize, glyph: glyph, extrusion: extrusion,
                                bevelSize: bevelSize, bevelSegments: bevelSegments, profile: profile))
    }

    static func clearCache() { cacheLock.lock(); cache.removeAll(); missing.removeAll(); cacheLock.unlock() }

    // MARK: Outline

    typealias P2 = SIMD2<Double>

    /// Closed polygons of a path (curves flattened), duplicate and closing points removed.
    static func contours(of path: CGPath, fontSize: Double) -> [[P2]] {
        var result: [[P2]] = []
        var current: [P2] = []
        var last = P2.zero
        let quadSteps = fontSize > 60 ? 8 : 6, cubicSteps = fontSize > 60 ? 10 : 8
        func finish() {
            var pts: [P2] = []
            for p in current where pts.last.map({ simd_distance($0, p) > 1e-6 }) ?? true { pts.append(p) }
            while pts.count > 1, let f = pts.first, let l = pts.last, simd_distance(f, l) <= 1e-6 { pts.removeLast() }
            if pts.count >= 3, abs(signedArea(pts)) > 1e-9 { result.append(pts) }
            current = []
        }
        path.applyWithBlock { element in
            let e = element.pointee
            switch e.type {
            case .moveToPoint:
                finish()
                last = P2(Double(e.points[0].x), Double(e.points[0].y))
                current = [last]
            case .addLineToPoint:
                last = P2(Double(e.points[0].x), Double(e.points[0].y))
                current.append(last)
            case .addQuadCurveToPoint:
                let c = P2(Double(e.points[0].x), Double(e.points[0].y)), end = P2(Double(e.points[1].x), Double(e.points[1].y))
                let start = last
                for i in 1...quadSteps {
                    let t = Double(i) / Double(quadSteps), u = 1 - t
                    current.append(start * (u * u) + c * (2 * u * t) + end * (t * t))
                }
                last = end
            case .addCurveToPoint:
                let c1 = P2(Double(e.points[0].x), Double(e.points[0].y)), c2 = P2(Double(e.points[1].x), Double(e.points[1].y))
                let end = P2(Double(e.points[2].x), Double(e.points[2].y))
                let start = last
                for i in 1...cubicSteps {
                    let t = Double(i) / Double(cubicSteps), u = 1 - t
                    let a = start * (u * u * u) + c1 * (3 * u * u * t)
                    current.append(a + c2 * (3 * u * t * t) + end * (t * t * t))
                }
                last = end
            case .closeSubpath:
                finish()
            @unknown default:
                break
            }
        }
        finish()
        return result
    }

    static func signedArea(_ p: [P2]) -> Double {
        var a = 0.0
        for i in 0..<p.count { let q = p[i], r = p[(i + 1) % p.count]; a += q.x * r.y - r.x * q.y }
        return a / 2
    }

    static func contains(_ poly: [P2], _ pt: P2) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > pt.y) != (b.y > pt.y), pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    private static func cross(_ a: P2, _ b: P2) -> Double { a.x * b.y - a.y * b.x }

    private static func strictlyInside(_ p: P2, _ a: P2, _ b: P2, _ c: P2) -> Bool {
        let d1 = cross(b - a, p - a), d2 = cross(c - b, p - b), d3 = cross(a - c, p - c)
        return d1 > 1e-12 && d2 > 1e-12 && d3 > 1e-12
    }

    // MARK: Triangulation

    /// Splices every hole into its outer contour through a bridge so one simple polygon remains (indices into `pts`).
    private static func bridged(outer: [Int], holes: [[Int]], pts: [P2]) -> [Int] {
        var poly = outer
        let sortedHoles = holes.sorted { a, b in
            (a.map { pts[$0].x }.max() ?? 0) > (b.map { pts[$0].x }.max() ?? 0)
        }
        for hole in sortedHoles where !hole.isEmpty {
            var m = 0
            for i in hole.indices where pts[hole[i]].x > pts[hole[m]].x { m = i }
            let M = pts[hole[m]]
            var bestX = Double.greatestFiniteMagnitude, bestIndex = -1
            var hit = M
            let n = poly.count
            for i in 0..<n {
                let a = pts[poly[i]], b = pts[poly[(i + 1) % n]]
                guard a.y != b.y, min(a.y, b.y) <= M.y, max(a.y, b.y) >= M.y else { continue }
                let x = a.x + (M.y - a.y) * (b.x - a.x) / (b.y - a.y)
                if x >= M.x, x < bestX {
                    bestX = x
                    bestIndex = a.x > b.x ? i : (i + 1) % n
                    hit = P2(x, M.y)
                }
            }
            if bestIndex < 0 {
                // No edge to the right (degenerate outline): bridge to the nearest vertex.
                var bestD = Double.greatestFiniteMagnitude
                for i in 0..<n { let d = simd_distance_squared(pts[poly[i]], M); if d < bestD { bestD = d; bestIndex = i } }
            } else {
                // A vertex inside the triangle (M, hit, candidate) would block the bridge: take the one closest in angle.
                let P = pts[poly[bestIndex]]
                var bestAngle = Double.greatestFiniteMagnitude
                var replacement = -1
                for i in 0..<n where i != bestIndex {
                    let v = pts[poly[i]]
                    guard v.x >= M.x, strictlyInside(v, M, hit, P) || strictlyInside(v, M, P, hit) else { continue }
                    let angle = abs(atan2(v.y - M.y, v.x - M.x))
                    if angle < bestAngle { bestAngle = angle; replacement = i }
                }
                if replacement >= 0 { bestIndex = replacement }
            }
            var splice: [Int] = []
            for k in 0...hole.count { splice.append(hole[(m + k) % hole.count]) }
            splice.append(poly[bestIndex])
            poly.insert(contentsOf: splice, at: bestIndex + 1)
        }
        return poly
    }

    /// Ear clipping of a counter-clockwise simple polygon (bridged duplicates allowed).
    private static func earClip(_ polygon: [Int], pts: [P2]) -> [Int] {
        var idx = polygon
        var tris: [Int] = []
        var guardCount = 0
        while idx.count > 3, guardCount < 100_000 {
            guardCount += 1
            let n = idx.count
            var clipped = false
            for i in 0..<n {
                let ia = idx[(i + n - 1) % n], ib = idx[i], ic = idx[(i + 1) % n]
                let a = pts[ia], b = pts[ib], c = pts[ic]
                guard cross(b - a, c - b) > 1e-12 else { continue }
                var blocked = false
                for j in 0..<n {
                    let ij = idx[j]
                    if ij == ia || ij == ib || ij == ic { continue }
                    let p = pts[ij]
                    if p == a || p == b || p == c { continue }
                    if strictlyInside(p, a, b, c) { blocked = true; break }
                }
                if blocked { continue }
                tris += [ia, ib, ic]
                idx.remove(at: i)
                clipped = true
                break
            }
            if !clipped {
                // Numerically degenerate leftovers: drop the flattest vertex to keep making progress.
                var flattest = 0, smallest = Double.greatestFiniteMagnitude
                for i in 0..<n {
                    let a = pts[idx[(i + n - 1) % n]], b = pts[idx[i]], c = pts[idx[(i + 1) % n]]
                    let s = abs(cross(b - a, c - b))
                    if s < smallest { smallest = s; flattest = i }
                }
                idx.remove(at: flattest)
            }
        }
        if idx.count == 3 {
            let a = pts[idx[0]], b = pts[idx[1]], c = pts[idx[2]]
            if cross(b - a, c - b) > 1e-12 { tris += idx }
        }
        return tris
    }

    /// Triangles (indices into the flattened contour points) filling the outlines with even-odd holes.
    static func triangulate(_ contours: [[P2]]) -> (points: [P2], triangles: [Int]) {
        var pts: [P2] = []
        var ranges: [[Int]] = []
        for c in contours { ranges.append(Array(pts.count..<(pts.count + c.count))); pts += c }
        let depth = contours.indices.map { i in contours.indices.filter { $0 != i && contains(contours[$0], contours[i][0]) }.count }
        var tris: [Int] = []
        for o in contours.indices where depth[o] % 2 == 0 {
            let holes = contours.indices.filter { h in
                depth[h] == depth[o] + 1 && contains(contours[o], contours[h][0])
            }.map { ranges[$0] }
            tris += earClip(bridged(outer: ranges[o], holes: holes, pts: pts), pts: pts)
        }
        return (pts, tris)
    }

    // MARK: Build

    private static func build(_ key: Text3DMeshKey) -> Text3DMesh? {
        let fontSize = Double(key.fontSize) / 100
        let font = CTFontCreateWithName(key.fontName as CFString, CGFloat(fontSize), nil)
        guard let path = CTFontCreatePathForGlyph(font, key.glyph, nil) else { return nil }
        return build(contours: contours(of: path, fontSize: fontSize), fontSize: fontSize,
                     extrusion: Double(key.extrusion) / 4, bevelSize: Double(key.bevelSize) / 20,
                     segments: key.bevelSegments, profile: key.profile)
    }

    /// Builds the extruded mesh from closed outlines (any orientation; holes by even-odd nesting).
    static func build(contours raw: [[P2]], fontSize: Double, extrusion: Double, bevelSize: Double,
                      segments: Int, profile: Text3DBevelProfile) -> Text3DMesh? {
        guard !raw.isEmpty else { return nil }
        // Orient: filled region always on the left (outers counter-clockwise, holes clockwise).
        let depth = raw.indices.map { i in raw.indices.filter { $0 != i && contains(raw[$0], raw[i][0]) }.count }
        let contours: [[P2]] = raw.indices.map { i in
            let ccw = signedArea(raw[i]) > 0
            let wantCCW = depth[i] % 2 == 0
            return ccw == wantCCW ? raw[i] : Array(raw[i].reversed())
        }
        let (flat, tris) = triangulate(contours)
        guard !tris.isEmpty else { return nil }

        let halfD = max(0.01, extrusion) / 2
        var b = profile == .flat ? 0 : max(0, bevelSize)
        b = min(b, halfD * 0.98, fontSize * 0.1)
        if b < 1e-4 { b = 0 }
        let segs = b == 0 ? 0 : (profile == .round ? max(1, min(16, segments)) : 1)

        // Per-contour outward edge normals, vertex miter directions and miter lengths.
        struct Ring { var edgeN: [P2]; var miter: [P2]; var miterLen: [Double] }
        var rings: [Ring] = []
        for c in contours {
            let n = c.count
            var edgeN = [P2](repeating: .zero, count: n)
            for i in 0..<n {
                let d = c[(i + 1) % n] - c[i]
                let len = max(1e-12, simd_length(d))
                edgeN[i] = P2(d.y, -d.x) / len   // right of travel = outside
            }
            var miter = [P2](repeating: .zero, count: n), miterLen = [Double](repeating: 1, count: n)
            for i in 0..<n {
                let a = edgeN[(i + n - 1) % n], e = edgeN[i]
                var m = a + e
                if simd_length(m) < 1e-9 { m = e }
                m = simd_normalize(m)
                miter[i] = m
                miterLen[i] = min(3, 1 / max(0.33, simd_dot(m, e)))
            }
            rings.append(Ring(edgeN: edgeN, miter: miter, miterLen: miterLen))
        }
        func inset(_ c: Int, _ i: Int, _ amount: Double) -> P2 {
            contours[c][i] - rings[c].miter[i] * (rings[c].miterLen[i] * amount)
        }

        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = []
        func add(_ p: P2, _ z: Double, _ n: SIMD3<Double>) -> UInt32 {
            positions.append(SIMD3(Float(p.x), Float(p.y), Float(z)))
            let l = simd_length(n)
            normals.append(SIMD3<Float>(l > 1e-12 ? n / l : SIMD3(0, 0, 1)))
            return UInt32(positions.count - 1)
        }

        // Map flattened point index -> (contour, vertex).
        var owner: [(Int, Int)] = []
        for (ci, c) in contours.enumerated() { for vi in c.indices { owner.append((ci, vi)) } }
        _ = flat

        // Caps.
        var front: [UInt32] = [], back: [UInt32] = []
        let frontBase = UInt32(positions.count)
        for (ci, vi) in owner { _ = add(inset(ci, vi, b), halfD, SIMD3(0, 0, 1)) }
        let backBase = UInt32(positions.count)
        for (ci, vi) in owner { _ = add(inset(ci, vi, b), -halfD, SIMD3(0, 0, -1)) }
        for t in stride(from: 0, to: tris.count, by: 3) {
            front += [frontBase + UInt32(tris[t]), frontBase + UInt32(tris[t + 1]), frontBase + UInt32(tris[t + 2])]
            back += [backBase + UInt32(tris[t]), backBase + UInt32(tris[t + 2]), backBase + UInt32(tris[t + 1])]
        }

        // Bevel rings: (inset, depth from the face, profile normal (outward, z)).
        var bevel: [UInt32] = []
        if segs > 0 {
            var profileRings: [(inset: Double, zoff: Double, nh: Double, nz: Double)] = []
            for k in 0...segs {
                let t = Double(k) / Double(segs)
                if profile == .round {
                    let th = t * .pi / 2
                    profileRings.append((b * (1 - sin(th)), b * (1 - cos(th)), sin(th), cos(th)))
                } else {
                    profileRings.append((b * (1 - t), b * t, sqrt(0.5), sqrt(0.5)))
                }
            }
            for (ci, c) in contours.enumerated() {
                let n = c.count
                for sideSign in [1.0, -1.0] {
                    var ringStart: [UInt32] = []
                    for r in profileRings {
                        ringStart.append(UInt32(positions.count))
                        for i in 0..<n {
                            let m = rings[ci].miter[i]
                            _ = add(inset(ci, i, r.inset), sideSign * (halfD - r.zoff), SIMD3(m.x * r.nh, m.y * r.nh, sideSign * r.nz))
                        }
                    }
                    for k in 0..<segs {
                        for i in 0..<n {
                            let j = (i + 1) % n
                            let a0 = ringStart[k] + UInt32(i), a1 = ringStart[k] + UInt32(j)
                            let b0 = ringStart[k + 1] + UInt32(i), b1 = ringStart[k + 1] + UInt32(j)
                            if sideSign > 0 { bevel += [b0, b1, a1, b0, a1, a0] }
                            else { bevel += [a0, a1, b1, a0, b1, b0] }
                        }
                    }
                }
            }
        }

        // Sides: hard edges at corners sharper than 35°, smooth across flattened curves.
        var side: [UInt32] = []
        let zTop = halfD - b, zBottom = -halfD + b
        let smooth = cos(35 * Double.pi / 180)
        if zTop - zBottom > 1e-6 {
            for (ci, c) in contours.enumerated() {
                let n = c.count, r = rings[ci]
                for i in 0..<n {
                    let j = (i + 1) % n
                    let e = r.edgeN[i]
                    let nStart = simd_dot(r.edgeN[(i + n - 1) % n], e) > smooth ? r.miter[i] : e
                    let nEnd = simd_dot(r.edgeN[j], e) > smooth ? r.miter[j] : e
                    let t0 = add(c[i], zTop, SIMD3(nStart.x, nStart.y, 0)), t1 = add(c[j], zTop, SIMD3(nEnd.x, nEnd.y, 0))
                    let u0 = add(c[i], zBottom, SIMD3(nStart.x, nStart.y, 0)), u1 = add(c[j], zBottom, SIMD3(nEnd.x, nEnd.y, 0))
                    side += [u0, u1, t1, u0, t1, t0]
                }
            }
        }
        return Text3DMesh(positions: positions, normals: normals, front: front, back: back, bevel: bevel, side: side)
    }
}
