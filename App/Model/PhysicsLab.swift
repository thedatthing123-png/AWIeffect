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
    }

    struct Sample { var time: Double; var position: Vec2; var rotation: Double }

    /// Simulates `bodies` in a `width`×`height` world, returning per-body samples at `fps`.
    static func simulate(_ input: [Body], width: Double, height: Double, settings s: PhysicsSettings, fps: Double) -> [UUID: [Sample]] {
        var bodies = input
        for i in bodies.indices where !bodies[i].isStatic {
            bodies[i].v = bodies[i].v + s.launch
            bodies[i].w += s.spin
        }
        var out: [UUID: [Sample]] = [:]
        let sub = 8
        let dt = 1 / fps / Double(sub)
        let frames = Int((s.duration * fps).rounded())
        for f in 0...frames {
            for b in bodies { out[b.id, default: []].append(Sample(time: Double(f) / fps, position: b.p, rotation: b.angle)) }
            if f == frames { break }
            for _ in 0..<sub {
                // Integrate.
                for i in bodies.indices where !bodies[i].isStatic {
                    bodies[i].v.y += s.gravity * dt
                    bodies[i].v = bodies[i].v * (1 - s.airDrag * dt)
                    bodies[i].p = bodies[i].p + bodies[i].v * dt
                    bodies[i].angle += bodies[i].w * dt
                }
                // Walls.
                for i in bodies.indices where !bodies[i].isStatic {
                    let r = bodies[i].r
                    if s.floor, bodies[i].p.y + r > height {
                        bodies[i].p.y = height - r
                        wallImpulse(&bodies[i], normal: Vec2(0, -1), s: s)
                    }
                    if s.ceiling, bodies[i].p.y - r < 0 {
                        bodies[i].p.y = r
                        wallImpulse(&bodies[i], normal: Vec2(0, 1), s: s)
                    }
                    if s.walls {
                        if bodies[i].p.x - r < 0 { bodies[i].p.x = r; wallImpulse(&bodies[i], normal: Vec2(1, 0), s: s) }
                        if bodies[i].p.x + r > width { bodies[i].p.x = width - r; wallImpulse(&bodies[i], normal: Vec2(-1, 0), s: s) }
                    }
                }
                // Body-body (circle) collisions.
                for i in bodies.indices {
                    for j in bodies.indices where j > i {
                        let d = bodies[j].p - bodies[i].p
                        let dist = (d.x * d.x + d.y * d.y).squareRoot()
                        let minD = bodies[i].r + bodies[j].r
                        guard dist < minD, dist > 1e-9 else { continue }
                        let n = d * (1 / dist)
                        let invSum = bodies[i].invMass + bodies[j].invMass
                        guard invSum > 0 else { continue }
                        // Positional correction.
                        let corr = n * ((minD - dist) / invSum * 0.8)
                        bodies[i].p = bodies[i].p - corr * bodies[i].invMass
                        bodies[j].p = bodies[j].p + corr * bodies[j].invMass
                        // Normal impulse.
                        let rv = bodies[j].v - bodies[i].v
                        let vn = rv.x * n.x + rv.y * n.y
                        if vn > 0 { continue }
                        let jn = -(1 + s.bounciness) * vn / invSum
                        bodies[i].v = bodies[i].v - n * (jn * bodies[i].invMass)
                        bodies[j].v = bodies[j].v + n * (jn * bodies[j].invMass)
                        // Friction impulse along the tangent -> spin.
                        let t = Vec2(-n.y, n.x)
                        let vt = rv.x * t.x + rv.y * t.y
                        let jt = max(-abs(jn) * s.friction, min(abs(jn) * s.friction, -vt / invSum))
                        bodies[i].v = bodies[i].v - t * (jt * bodies[i].invMass)
                        bodies[j].v = bodies[j].v + t * (jt * bodies[j].invMass)
                        bodies[i].w -= jt * bodies[i].invMass / max(bodies[i].r, 1) * 57.3
                        bodies[j].w += jt * bodies[j].invMass / max(bodies[j].r, 1) * 57.3
                    }
                }
            }
        }
        return out
    }

    private static func wallImpulse(_ b: inout Body, normal n: Vec2, s: PhysicsSettings) {
        let vn = b.v.x * n.x + b.v.y * n.y
        guard vn < 0 else { return }
        b.v = b.v - n * ((1 + s.bounciness) * vn)
        // Rolling friction: tangential speed turns into spin and decays.
        let t = Vec2(-n.y, n.x)
        let vt = b.v.x * t.x + b.v.y * t.y
        b.v = b.v - t * (vt * s.friction)
        b.w = b.w * (1 - s.friction) + (-vt / max(b.r, 1)) * 57.3 * s.friction
        // Rest small bounces so bodies settle instead of jittering.
        if abs(b.v.x * n.x + b.v.y * n.y) < 30 { b.v = b.v - n * (b.v.x * n.x + b.v.y * n.y) }
    }
}

extension EditorState {
    /// Simulates the chosen layers (others with `staticIDs` act as fixed obstacles) and bakes keyframes from the playhead.
    func bakePhysics(dynamicIDs: [UUID], staticIDs: [UUID] = [], settings: PhysicsSettings) {
        let t0 = currentTime
        var bodies: [PhysicsLab.Body] = []
        for l in project.layers where dynamicIDs.contains(l.id) || staticIDs.contains(l.id) {
            let hs = Renderer.layerHalfSize(l, time: t0)
            let sc = l.transform.scale.value(at: t0)
            let r = max(2, min(hs.x * abs(sc.x), hs.y * abs(sc.y)) / 100)
            let isStatic = staticIDs.contains(l.id)
            bodies.append(.init(id: l.id, p: l.transform.position.value(at: t0), v: .zero, angle: l.transform.rotation.value(at: t0),
                                w: 0, r: r, invMass: isStatic ? 0 : 1 / max(r * r, 1), isStatic: isStatic))
        }
        let result = PhysicsLab.simulate(bodies, width: Double(project.width), height: Double(project.height), settings: settings, fps: project.fps)
        mutate("Bake Physics") { p in
            for (id, samples) in result where dynamicIDs.contains(id) {
                guard let i = p.layers.firstIndex(where: { $0.id == id }) else { continue }
                var pos = p.layers[i].transform.position, rot = p.layers[i].transform.rotation
                pos.keyframes.removeAll { $0.time >= t0 - 1e-6 && $0.time <= t0 + settings.duration + 1e-6 }
                rot.keyframes.removeAll { $0.time >= t0 - 1e-6 && $0.time <= t0 + settings.duration + 1e-6 }
                for s in samples where t0 + s.time <= p.duration {
                    pos.insertKeyframe(Keyframe(time: p.snapToFrame(t0 + s.time), value: s.position, interpolation: .linear))
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
