import Foundation

/// 2D rigid-body physics (impulse solver) baked into position/rotation keyframes, so results stay editable.
/// Bodies collide as circles (radius from the layer size); walls are the comp edges.
struct PhysicsSettings: Codable, Equatable {
    var gravity = 1800.0          // px/s², positive = down
    var bounciness = 0.55         // restitution 0...1
    var friction = 0.3
    var airDrag = 0.02
    var floor = true
    var walls = true
    var ceiling = false
    /// Initial velocity applied to every body (px/s) — "throw".
    var launch = Vec2(0, 0)
    var spin = 0.0                // initial angular velocity, deg/s
    var duration = 3.0
}

/// Rigid-body solver (sequential impulses with box/polygon SAT contacts, Box2D-lite style): boxes tumble and stack,
/// round things roll. Circles use `r`; polygons use `shape` (convex, body-local, centered).
enum PhysicsLab {
    struct Body {
        var id: UUID
        var p: Vec2
        var v: Vec2
        var angle: Double         // degrees
        var w: Double             // deg/s
        var r: Double
        var invMass: Double
        var isStatic: Bool
        /// Convex outline in body space (px, around the center); nil = circle of radius `r`.
        var shape: [Vec2]? = nil
    }

    struct Sample { var time: Double; var position: Vec2; var rotation: Double }

    private struct RB {
        var p: Vec2, v: Vec2, a: Double, w: Double   // a, w in radians
        var invM: Double, invI: Double
        var r: Double, poly: [Vec2]?
        var world: [Vec2] = []
        var resting = 0
    }

    private struct Contact {
        var a: Int, b: Int, n: Vec2, point: Vec2, depth: Double
        var rA = Vec2.zero, rB = Vec2.zero, mN = 0.0, mT = 0.0, bias = 0.0, jn = 0.0, jt = 0.0
    }

    @inline(__always) private static func dot(_ a: Vec2, _ b: Vec2) -> Double { a.x * b.x + a.y * b.y }
    @inline(__always) private static func cross(_ a: Vec2, _ b: Vec2) -> Double { a.x * b.y - a.y * b.x }
    @inline(__always) private static func cross(_ s: Double, _ a: Vec2) -> Vec2 { Vec2(-s * a.y, s * a.x) }
    @inline(__always) private static func rot(_ v: Vec2, _ a: Double) -> Vec2 { Vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a)) }

    /// Mass properties with unit density (mass ∝ area).
    private static func massProps(_ b: Body) -> (invM: Double, invI: Double) {
        if b.isStatic || b.invMass == 0 { return (0, 0) }
        if let poly = b.shape, poly.count >= 3 {
            var area = 0.0, I = 0.0
            for i in poly.indices {
                let p1 = poly[i], p2 = poly[(i + 1) % poly.count]
                let c = cross(p1, p2)
                area += c / 2
                I += c * (dot(p1, p1) + dot(p1, p2) + dot(p2, p2)) / 12
            }
            let m = max(abs(area), 1) / 100
            return (1 / m, 1 / max(abs(I) / 100, 1e-6))
        }
        let m = max(Double.pi * b.r * b.r, 1) / 100
        return (1 / m, 1 / max(m * b.r * b.r / 2, 1e-6))
    }

    static func simulate(_ input: [Body], width: Double, height: Double, settings s: PhysicsSettings, fps: Double) -> [UUID: [Sample]] {
        var bodies: [RB] = input.map { b in
            let mp = massProps(b)
            let dyn = !b.isStatic && b.invMass > 0
            return RB(p: b.p, v: dyn ? b.v + s.launch : .zero, a: b.angle * .pi / 180, w: dyn ? (b.w + s.spin) * .pi / 180 : 0,
                      invM: mp.invM, invI: mp.invI, r: b.r, poly: b.shape)
        }
        let nUser = bodies.count
        // World bounds as thick static boxes.
        let T = 4000.0
        func wall(_ cx: Double, _ cy: Double, _ hw: Double, _ hh: Double) {
            bodies.append(RB(p: Vec2(cx, cy), v: .zero, a: 0, w: 0, invM: 0, invI: 0, r: 0,
                             poly: [Vec2(-hw, -hh), Vec2(hw, -hh), Vec2(hw, hh), Vec2(-hw, hh)]))
        }
        if s.floor { wall(width / 2, height + T, width * 4 + T, T) }
        if s.ceiling { wall(width / 2, -T, width * 4 + T, T) }
        if s.walls { wall(-T, height / 2, T, height * 4 + T); wall(width + T, height / 2, T, height * 4 + T) }

        var out: [UUID: [Sample]] = [:]
        let sub = 4
        let dt = 1 / fps / Double(sub)
        let frames = Int((s.duration * fps).rounded())
        for f in 0...frames {
            for i in 0..<nUser {
                out[input[i].id, default: []].append(Sample(time: Double(f) / fps, position: bodies[i].p, rotation: bodies[i].a * 180 / .pi))
            }
            if f == frames { break }
            for _ in 0..<sub { step(&bodies, dt: dt, s: s) }
        }
        return out
    }

    private static func step(_ bodies: inout [RB], dt: Double, s: PhysicsSettings) {
        for i in bodies.indices where bodies[i].invM > 0 {
            bodies[i].v.y += s.gravity * dt
            bodies[i].v = bodies[i].v * max(0, 1 - s.airDrag * dt)
            bodies[i].w *= max(0, 1 - (s.airDrag + 0.05) * dt)
        }
        for i in bodies.indices {
            if let poly = bodies[i].poly { bodies[i].world = poly.map { bodies[i].p + rot($0, bodies[i].a) } }
        }
        var contacts: [Contact] = []
        for i in bodies.indices {
            for j in bodies.indices where j > i && (bodies[i].invM > 0 || bodies[j].invM > 0) {
                collide(bodies, i, j, into: &contacts)
            }
        }
        for k in contacts.indices {
            var c = contacts[k]
            let A = bodies[c.a], B = bodies[c.b]
            c.rA = c.point - A.p; c.rB = c.point - B.p
            let rnA = cross(c.rA, c.n), rnB = cross(c.rB, c.n)
            c.mN = 1 / max(A.invM + B.invM + A.invI * rnA * rnA + B.invI * rnB * rnB, 1e-12)
            let t = Vec2(c.n.y, -c.n.x)
            let rtA = cross(c.rA, t), rtB = cross(c.rB, t)
            c.mT = 1 / max(A.invM + B.invM + A.invI * rtA * rtA + B.invI * rtB * rtB, 1e-12)
            let rv = B.v + cross(B.w, c.rB) - A.v - cross(A.w, c.rA)
            let vn = dot(rv, c.n)
            let restitution = vn < -60 ? -s.bounciness * vn : 0
            c.bias = max(restitution, 0.25 / dt * max(0, c.depth - 0.5))
            contacts[k] = c
        }
        let mu = s.friction
        for _ in 0..<10 {
            for k in contacts.indices {
                var c = contacts[k]
                var A = bodies[c.a], B = bodies[c.b]
                var rv = B.v + cross(B.w, c.rB) - A.v - cross(A.w, c.rA)
                let dPn = c.mN * (-dot(rv, c.n) + c.bias)
                let jn0 = c.jn
                c.jn = max(jn0 + dPn, 0)
                var P = c.n * (c.jn - jn0)
                A.v = A.v - P * A.invM; A.w -= A.invI * cross(c.rA, P)
                B.v = B.v + P * B.invM; B.w += B.invI * cross(c.rB, P)
                rv = B.v + cross(B.w, c.rB) - A.v - cross(A.w, c.rA)
                let t = Vec2(c.n.y, -c.n.x)
                let dPt = c.mT * -dot(rv, t)
                let maxF = mu * c.jn
                let jt0 = c.jt
                c.jt = max(-maxF, min(maxF, jt0 + dPt))
                P = t * (c.jt - jt0)
                A.v = A.v - P * A.invM; A.w -= A.invI * cross(c.rA, P)
                B.v = B.v + P * B.invM; B.w += B.invI * cross(c.rB, P)
                bodies[c.a] = A; bodies[c.b] = B
                contacts[k] = c
            }
        }
        // Integrate; bodies that barely move for a while sleep so stacks settle without jitter.
        for i in bodies.indices where bodies[i].invM > 0 {
            let slow = dot(bodies[i].v, bodies[i].v) < 25 && abs(bodies[i].w) < 0.08
            bodies[i].resting = slow ? bodies[i].resting + 1 : 0
            if bodies[i].resting > 40 { bodies[i].v = .zero; bodies[i].w = 0; continue }
            bodies[i].p = bodies[i].p + bodies[i].v * dt
            bodies[i].a += bodies[i].w * dt
        }
    }

    // MARK: Narrow phase (normal points from a to b)

    private static func collide(_ bodies: [RB], _ i: Int, _ j: Int, into out: inout [Contact]) {
        let A = bodies[i], B = bodies[j]
        switch (A.poly != nil, B.poly != nil) {
        case (false, false):
            let d = B.p - A.p, dist = dot(d, d).squareRoot(), minD = A.r + B.r
            guard dist < minD else { return }
            let n = dist > 1e-9 ? d * (1 / dist) : Vec2(0, 1)
            out.append(Contact(a: i, b: j, n: n, point: A.p + n * A.r, depth: minD - dist))
        case (true, false): circlePoly(B.p, B.r, A.world, circle: j, poly: i, flip: false, into: &out)
        case (false, true): circlePoly(A.p, A.r, B.world, circle: i, poly: j, flip: true, into: &out)
        case (true, true): polyPoly(A.world, B.world, i, j, into: &out)
        }
    }

    /// Outward edge normals (works for either winding).
    private static func normals(_ v: [Vec2]) -> [Vec2] {
        let c = v.reduce(Vec2.zero) { $0 + $1 } * (1 / Double(v.count))
        return v.indices.map { k in
            let e = v[(k + 1) % v.count] - v[k]
            var n = Vec2(e.y, -e.x)
            n = n * (1 / max(dot(n, n).squareRoot(), 1e-12))
            return dot(n, v[k] - c) < 0 ? n * -1 : n
        }
    }

    private static func circlePoly(_ c: Vec2, _ r: Double, _ v: [Vec2], circle: Int, poly: Int, flip: Bool, into out: inout [Contact]) {
        let ns = normals(v)
        var best = -Double.infinity, bi = 0
        for k in v.indices { let sep = dot(ns[k], c - v[k]); if sep > best { best = sep; bi = k } }
        guard best < r else { return }
        var n: Vec2, depth: Double
        if best < 0 { n = ns[bi]; depth = r - best }
        else {
            var cp = v[0], cd = Double.infinity
            for k in v.indices {
                let a = v[k], b = v[(k + 1) % v.count], e = b - a
                let t = max(0, min(1, dot(c - a, e) / max(dot(e, e), 1e-12)))
                let q = a + e * t, d = dot(c - q, c - q)
                if d < cd { cd = d; cp = q }
            }
            let dist = cd.squareRoot()
            guard dist < r else { return }
            n = dist > 1e-9 ? (c - cp) * (1 / dist) : ns[bi]
            depth = r - dist
        }
        let point = c - n * r
        out.append(flip ? Contact(a: circle, b: poly, n: n * -1, point: point, depth: depth)
                        : Contact(a: poly, b: circle, n: n, point: point, depth: depth))
    }

    private static func maxSeparation(_ a: [Vec2], _ na: [Vec2], _ b: [Vec2]) -> (sep: Double, edge: Int) {
        var best = -Double.infinity, edge = 0
        for k in a.indices {
            var m = Double.infinity
            for p in b { m = min(m, dot(na[k], p - a[k])) }
            if m > best { best = m; edge = k }
        }
        return (best, edge)
    }

    private static func polyPoly(_ a: [Vec2], _ b: [Vec2], _ i: Int, _ j: Int, into out: inout [Contact]) {
        let na = normals(a), nb = normals(b)
        let sa = maxSeparation(a, na, b), sb = maxSeparation(b, nb, a)
        guard sa.sep < 0, sb.sep < 0 else { return }
        let useA = sa.sep >= sb.sep * 0.98 - 0.01
        let ref = useA ? a : b, inc = useA ? b : a, nRefs = useA ? na : nb, nIncs = useA ? nb : na
        let e = useA ? sa.edge : sb.edge
        let n = nRefs[e]
        var ie = 0, md = Double.infinity
        for k in inc.indices { let d = dot(nIncs[k], n); if d < md { md = d; ie = k } }
        var pts = [inc[ie], inc[(ie + 1) % inc.count]]
        let v1 = ref[e], v2 = ref[(e + 1) % ref.count]
        let side = (v2 - v1) * (1 / max(dot(v2 - v1, v2 - v1).squareRoot(), 1e-12))
        func clip(_ p: [Vec2], _ nn: Vec2, _ off: Double) -> [Vec2] {
            guard p.count == 2 else { return p }
            let d0 = dot(nn, p[0]) - off, d1 = dot(nn, p[1]) - off
            var r: [Vec2] = []
            if d0 <= 0 { r.append(p[0]) }
            if d1 <= 0 { r.append(p[1]) }
            if d0 * d1 < 0 { r.append(p[0] + (p[1] - p[0]) * (d0 / (d0 - d1))) }
            return r
        }
        pts = clip(pts, side * -1, -dot(side, v1))
        pts = clip(pts, side, dot(side, v2))
        let normal = useA ? n : n * -1
        for p in pts {
            let sep = dot(n, p - v1)
            if sep <= 0 { out.append(Contact(a: i, b: j, n: normal, point: p, depth: -sep)) }
        }
    }
}

extension EditorState {
    /// Simulates the chosen layers (others with `staticIDs` act as fixed obstacles) and bakes keyframes from the playhead.
    func bakePhysics(dynamicIDs: [UUID], staticIDs: [UUID] = [], settings: PhysicsSettings) {
        let t0 = currentTime
        var bodies: [PhysicsLab.Body] = []
        var anchors: [UUID: (anchor: Vec2, scale: Vec2)] = [:]
        for l in project.layers where dynamicIDs.contains(l.id) || staticIDs.contains(l.id) {
            let hs = Renderer.layerHalfSize(l, time: t0)
            let sc = l.transform.scale.value(at: t0) * 0.01
            let ex = Vec2(max(2, hs.x * abs(sc.x)), max(2, hs.y * abs(sc.y)))
            let isStatic = staticIDs.contains(l.id)
            var shape: [Vec2]? = [Vec2(-ex.x, -ex.y), Vec2(ex.x, -ex.y), Vec2(ex.x, ex.y), Vec2(-ex.x, ex.y)]
            var r = min(ex.x, ex.y)
            if case .shape(let k) = l.content {
                switch k {
                case .ellipse:
                    if abs(ex.x - ex.y) < 0.08 * max(ex.x, ex.y) { shape = nil; r = (ex.x + ex.y) / 2 }
                    else { shape = (0..<16).map { i in let a = Double(i) / 16 * 2 * .pi; return Vec2(cos(a) * ex.x, sin(a) * ex.y) } }
                case .polygon, .star:
                    let n = max(3, Int(l.sides.value(at: t0).rounded()))
                    shape = (0..<n).map { i in let a = -Double.pi / 2 + Double(i) / Double(n) * 2 * .pi; return Vec2(cos(a) * ex.x, sin(a) * ex.y) }
                default: break
                }
            }
            // The body sits at the layer's visual center; position = center + R·S·anchor.
            let anc = l.transform.anchor.value(at: t0)
            let ang = l.transform.rotation.value(at: t0) * .pi / 180
            let off = Vec2(anc.x * sc.x, anc.y * sc.y)
            let center = l.transform.position.value(at: t0) - Vec2(off.x * cos(ang) - off.y * sin(ang), off.x * sin(ang) + off.y * cos(ang))
            anchors[l.id] = (anc, sc)
            bodies.append(.init(id: l.id, p: center, v: .zero, angle: l.transform.rotation.value(at: t0),
                                w: 0, r: r, invMass: isStatic ? 0 : 1, isStatic: isStatic, shape: shape))
        }
        let result = PhysicsLab.simulate(bodies, width: Double(project.width), height: Double(project.height), settings: settings, fps: project.fps)
        mutate("Bake Physics") { p in
            for (id, samples) in result where dynamicIDs.contains(id) {
                guard let i = p.layers.firstIndex(where: { $0.id == id }) else { continue }
                var pos = p.layers[i].transform.position, rot = p.layers[i].transform.rotation
                pos.keyframes.removeAll { $0.time >= t0 - 1e-6 && $0.time <= t0 + settings.duration + 1e-6 }
                rot.keyframes.removeAll { $0.time >= t0 - 1e-6 && $0.time <= t0 + settings.duration + 1e-6 }
                let ac = anchors[id] ?? (Vec2.zero, Vec2(1, 1))
                for s in samples where t0 + s.time <= p.duration {
                    let a = s.rotation * .pi / 180, off = Vec2(ac.anchor.x * ac.scale.x, ac.anchor.y * ac.scale.y)
                    let position = s.position + Vec2(off.x * cos(a) - off.y * sin(a), off.x * sin(a) + off.y * cos(a))
                    pos.insertKeyframe(Keyframe(time: p.snapToFrame(t0 + s.time), value: position, interpolation: .linear))
                    rot.insertKeyframe(Keyframe(time: p.snapToFrame(t0 + s.time), value: s.rotation, interpolation: .linear))
                }
                p.layers[i].transform.position = pos
                p.layers[i].transform.rotation = rot
            }
        }
    }

    func addModelLayer(text: String?, fileURL: URL?) {
        var opts = Model3DOptions()
        if let t = text { opts.text = t }
        if let u = fileURL {
            let access = u.startAccessingSecurityScopedResource()
            defer { if access { u.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: u),
                  let name = try? store.importMedia(data: data, ext: u.pathExtension.isEmpty ? "usdz" : u.pathExtension, into: project.id) else { return }
            opts.fileName = name
        }
        let side = Double(min(project.width, project.height)) * 0.7
        mutate(fileURL == nil ? "Add 3D Text" : "Add 3D Model") { p in
            var l = p.makeLayer(name: fileURL?.deletingPathExtension().lastPathComponent ?? "3D \(opts.text)", content: .model,
                                size: Vec2(side, side))
            l.model3D = opts
            l.fill = Animated(.white)
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .model
    }
}
