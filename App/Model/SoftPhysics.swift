import SwiftUI
import CoreImage
import simd

/// Soft-body materials (Blender soft body / goal-style presets): how hard the shape springs back, how fast it calms,
/// how much it bounces and how much it stays squashed (slime).
enum SoftMaterial: String, CaseIterable, Identifiable {
    case jelly, rubber, slime, pudding, stiff
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// (shape stiffness 0-1 per step, velocity damping per second, bounce, plasticity per second)
    var params: (stiff: Double, damp: Double, bounce: Double, plastic: Double) {
        switch self {
        case .jelly: return (0.08, 1.2, 0.35, 0)
        case .rubber: return (0.22, 2.5, 0.7, 0)
        case .slime: return (0.03, 4.0, 0.05, 0.9)
        case .pudding: return (0.05, 2.0, 0.15, 0.15)
        case .stiff: return (0.6, 4.0, 0.25, 0)
        }
    }
}

enum LiquidKind: String, CaseIterable, Identifiable {
    case water, slime, honey
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: RGBA {
        switch self {
        case .water: return RGBA(0.35, 0.7, 1.0)
        case .slime: return RGBA(0.45, 1.0, 0.35)
        case .honey: return RGBA(1.0, 0.68, 0.15)
        }
    }
    /// Clavet et al. 2005 viscoelastic fluid: (rest density, stiffness, near stiffness, viscosity sigma, beta)
    var params: (rest: Double, k: Double, kNear: Double, sigma: Double, beta: Double) {
        switch self {
        case .water: return (10, 0.004, 0.01, 0, 0.05)
        case .slime: return (14, 0.006, 0.02, 0.6, 0.4)
        case .honey: return (12, 0.005, 0.015, 1.2, 0.8)
        }
    }
}

extension EditorState {
    // MARK: Soft body (shape matching, baked to puppet pins)

    /// Drops the selected layer as a soft body (it falls from `drop` px above, hits the floor and wobbles), baked into
    /// Puppet Pins keyframes so the real image deforms. `squash` adds an initial impact squash.
    func bakeSoftBody(_ m: SoftMaterial, drop: Double, gravity: Double, duration: Double, floorAtBottom: Bool) {
        guard let i = selectedIndex else { return }
        let l = project.layers[i]
        let hs = Renderer.layerHalfSize(l, time: currentTime)
        guard hs.x > 1, hs.y > 1 else { return }
        // 4x4 grid of pins over the layer (local px, centered).
        let n = 4
        var rest: [SIMD2<Double>] = []
        for gy in 0..<n { for gx in 0..<n {
            rest.append(SIMD2(-hs.x * 0.85 + 1.7 * hs.x * Double(gx) / Double(n - 1), -hs.y * 0.85 + 1.7 * hs.y * Double(gy) / Double(n - 1)))
        } }
        // The floor in layer-local y (comp bottom, or the layer's own bottom edge when the floor is off: it lands in place).
        let pos = l.transform.position.value(at: currentTime)
        let floorY: Double = {
            if floorAtBottom, let fl = layerLocal(fromComp: Vec2(pos.x, Double(project.height))) { return fl.y }
            return hs.y
        }()
        var x = rest.map { $0 - SIMD2(0, drop) }
        var v = [SIMD2<Double>](repeating: .zero, count: x.count)
        var shape = rest
        let p = m.params
        let fps = max(12, min(30, project.fps / 2))
        let dt = 1.0 / 240
        let steps = Int(duration / dt)
        let keyEvery = max(1, Int((1 / fps) / dt))
        var frames: [(Double, [SIMD2<Double>])] = [(0, x)]
        for s in 1...steps {
            // Shape matching (Mueller 2005): best rigid fit of the rest shape, then pull toward it.
            let com = x.reduce(.zero, +) / Double(x.count)
            let com0 = shape.reduce(.zero, +) / Double(shape.count)
            var a = 0.0, b = 0.0
            for k in x.indices { let q = shape[k] - com0, r = x[k] - com; a += q.x * r.x + q.y * r.y; b += q.x * r.y - q.y * r.x }
            let ang = atan2(b, a), c = cos(ang), sn = sin(ang)
            for k in x.indices {
                let q = shape[k] - com0
                let goal = com + SIMD2(q.x * c - q.y * sn, q.x * sn + q.y * c)
                v[k] += (goal - x[k]) * (p.stiff / dt) * 0.5
                v[k].y += gravity * dt
                v[k] *= max(0, 1 - p.damp * dt)
                x[k] += v[k] * dt
                if x[k].y > floorY {
                    x[k].y = floorY
                    if v[k].y > 0 { v[k].y = -v[k].y * p.bounce }
                    v[k].x *= 0.9
                }
                // Slime: the rest shape creeps toward the current squash, so it stays flattened.
                if p.plastic > 0 { shape[k] += ((x[k] - com) - (shape[k] - com0)) * p.plastic * dt }
            }
            if s % keyEvery == 0 { frames.append((Double(s) * dt, x)) }
        }
        let t0 = currentTime
        ensurePuppet()
        guard let j = puppetEffectIndex else { return }
        mutate("Soft Body (\(m.title))") { pr in
            var params = pr.layers[i].effects[j].params.filter { !$0.key.hasPrefix("pinR") && !$0.key.hasPrefix("pinD") && !$0.key.hasPrefix("pinS") }
            params["stiffness"] = .number(Animated(1.0))
            for k in rest.indices {
                params["pinR\(k)"] = .point(Animated(Vec2(rest[k].x, rest[k].y)))
                var d = Animated(Vec2(frames[0].1[k].x, frames[0].1[k].y))
                for (t, xs) in frames {
                    d.insertKeyframe(Keyframe(time: pr.snapToFrame(t0 + t), value: Vec2(xs[k].x, xs[k].y), interpolation: .linear))
                }
                params["pinD\(k)"] = .point(d)
            }
            pr.layers[i].effects[j].params = params
            if t0 + duration > pr.duration { pr.duration = t0 + duration }
        }
        redrawToken += 1
    }

    // MARK: Hang / rope (verlet chain, baked to puppet pins)

    /// The selected layer hangs from its top edge and swings like rope / hair / cloth, baked into Puppet Pins.
    func bakeHang(swing: Double, wind: Double, stiffness: Double, duration: Double) {
        guard let i = selectedIndex else { return }
        let l = project.layers[i]
        let hs = Renderer.layerHalfSize(l, time: currentTime)
        guard hs.x > 1, hs.y > 1 else { return }
        let segs = 6
        var rest: [SIMD2<Double>] = []
        for side in [-0.6, 0.6] { for k in 0...segs { rest.append(SIMD2(hs.x * side, -hs.y + 2 * hs.y * Double(k) / Double(segs))) } }
        var x = rest, old = rest
        let len = 2 * hs.y / Double(segs)
        let dt = 1.0 / 240, steps = Int(duration / dt)
        let fps = max(12, min(30, project.fps / 2)), keyEvery = max(1, Int((1 / fps) / dt))
        // Initial swing: push the free ends sideways.
        for k in x.indices where k % (segs + 1) != 0 {
            let f = Double(k % (segs + 1)) / Double(segs)
            old[k].x -= swing * f * dt
        }
        var frames: [(Double, [SIMD2<Double>])] = [(0, x)]
        for s in 1...steps {
            let t = Double(s) * dt
            for k in x.indices where k % (segs + 1) != 0 {
                let vel = (x[k] - old[k]) * 0.995
                old[k] = x[k]
                let gust = wind * (0.6 + 0.4 * sin(t * 2.3 + Double(k)))
                x[k] += vel + SIMD2(gust, 1400) * dt * dt
            }
            for _ in 0..<6 {
                for c in 0..<2 {
                    let base = c * (segs + 1)
                    x[base] = rest[base]
                    for k in 0..<segs {
                        let a = base + k, b = a + 1
                        let d = x[b] - x[a], dl = simd_length(d)
                        guard dl > 1e-6 else { continue }
                        let corr = d * ((dl - len) / dl)
                        if k == 0 { x[b] -= corr } else { x[a] += corr * 0.5; x[b] -= corr * 0.5 }
                    }
                }
                // Keep the two chains the same distance apart (cloth width) and bending stiff.
                for k in 1...segs {
                    let a = k, b = k + segs + 1
                    let d = x[b] - x[a], want = rest[b].x - rest[a].x, dl = simd_length(d)
                    guard dl > 1e-6 else { continue }
                    let corr = d * ((dl - want) / dl) * 0.5 * stiffness
                    x[a] += corr; x[b] -= corr
                }
            }
            if s % keyEvery == 0 { frames.append((t, x)) }
        }
        let t0 = currentTime
        ensurePuppet()
        guard let j = puppetEffectIndex else { return }
        mutate("Hang / Swing") { pr in
            var params = pr.layers[i].effects[j].params.filter { !$0.key.hasPrefix("pinR") && !$0.key.hasPrefix("pinD") && !$0.key.hasPrefix("pinS") }
            params["stiffness"] = .number(Animated(1.4))
            for k in rest.indices {
                params["pinR\(k)"] = .point(Animated(Vec2(rest[k].x, rest[k].y)))
                var d = Animated(Vec2(rest[k].x, rest[k].y))
                for (t, xs) in frames { d.insertKeyframe(Keyframe(time: pr.snapToFrame(t0 + t), value: Vec2(xs[k].x, xs[k].y), interpolation: .linear)) }
                params["pinD\(k)"] = .point(d)
            }
            pr.layers[i].effects[j].params = params
            if t0 + duration > pr.duration { pr.duration = t0 + duration }
        }
        redrawToken += 1
    }

    // MARK: Liquid (viscoelastic particles, rendered as glossy metaballs)

    /// Pours a liquid into the comp: simulates particles (Clavet viscoelastic SPH), renders each frame as glossy blobs,
    /// and adds the result as a pre-comp layer at the playhead.
    func makeLiquid(_ kind: LiquidKind, color: RGBA, amount: Int, pourX: Double, duration: Double, progress: @escaping (Double) -> Void) {
        let W = Double(project.width), H = Double(project.height)
        let fps = min(30, project.fps)
        let start = currentTime
        let count = max(60, min(900, amount))
        let pid = project.id, store = self.store
        Task.detached(priority: .userInitiated) {
            let frames = Self.simulateLiquid(kind, count: count, width: W, height: H, pourX: pourX, duration: duration, fps: fps) { p in
                Task { @MainActor in progress(p * 0.6) }
            }
            var files: [String] = []
            let rw = Int(W / 2), rh = Int(H / 2)
            for (k, pts) in frames.enumerated() {
                if let png = Self.renderLiquid(pts, width: rw, height: rh, scale: 0.5, color: color, radius: 14),
                   let f = try? store.importMedia(data: png, ext: "png", into: pid) { files.append(f) }
                let pr = 0.6 + 0.4 * Double(k + 1) / Double(frames.count)
                Task { @MainActor in progress(pr) }
            }
            await MainActor.run {
                guard !files.isEmpty else { progress(1); return }
                Renderer.shared?.clearImageCache()
                let dur = Double(files.count) / fps
                var comp = Project.new(name: "\(kind.title) \(self.project.precomps.count + 1)", width: self.project.width, height: self.project.height,
                                       fps: self.project.fps, duration: dur, background: RGBA(0, 0, 0, 0))
                for (k, f) in files.enumerated() {
                    var l = comp.makeLayer(name: "F\(k + 1)", content: .image(fileName: f, pixelWidth: rw, pixelHeight: rh), size: Vec2(W, H))
                    l.fill = Animated(.white)
                    l.inPoint = Double(k) / fps
                    l.outPoint = Double(k + 1) / fps
                    comp.layers.insert(l, at: 0)
                }
                var newID = UUID()
                self.mutate("Add \(kind.title)") { p in
                    var all = p.precomps; all.append(comp); p.precomps = all
                    var pl = p.makeLayer(name: comp.name, content: .precomp(id: comp.id), size: Vec2(W, H))
                    pl.inPoint = start; pl.outPoint = start + dur; pl.sourceStart = 0; pl.tag = .teal
                    if start + dur > p.duration { p.duration = start + dur }
                    newID = pl.id
                    p.layers.insert(pl, at: 0)
                }
                self.selectedLayerID = newID
                self.redrawToken += 1
                progress(1)
            }
        }
    }

    nonisolated static func simulateLiquid(_ kind: LiquidKind, count: Int, width W: Double, height H: Double, pourX: Double,
                                           duration: Double, fps: Double, progress: (Double) -> Void) -> [[SIMD2<Double>]] {
        let pr = kind.params
        let h = 34.0                       // interaction radius (comp px)
        let dt = 1.0 / 120, steps = Int(duration / dt), every = max(1, Int(1 / fps / dt))
        var x: [SIMD2<Double>] = [], v: [SIMD2<Double>] = [], born: [Double] = []
        // A stream poured from the top over the first half of the run.
        for k in 0..<count {
            born.append(Double(k) / Double(count) * duration * 0.5)
            x.append(SIMD2(pourX * W + Double.random(in: -18...18), -20 - Double.random(in: 0...10)))
            v.append(SIMD2(Double.random(in: -20...20), 200))
        }
        var out: [[SIMD2<Double>]] = []
        var springs: [Int64: Double] = [:]
        let g = 1800.0
        for s in 0..<steps {
            let t = Double(s) * dt
            let alive = (0..<count).filter { born[$0] <= t }
            // Gravity + viscosity (radial impulses between close neighbours).
            for i in alive { v[i].y += g * dt }
            var grid: [Int64: [Int]] = [:]
            func key(_ p: SIMD2<Double>) -> Int64 { Int64(Int(floor(p.x / h))) << 32 | Int64(UInt32(bitPattern: Int32(Int(floor(p.y / h))))) }
            for i in alive { grid[key(x[i]), default: []].append(i) }
            func neighbours(_ i: Int) -> [Int] {
                let cx = Int(floor(x[i].x / h)), cy = Int(floor(x[i].y / h))
                var r: [Int] = []
                for dy in -1...1 { for dx in -1...1 {
                    let k = Int64(cx + dx) << 32 | Int64(UInt32(bitPattern: Int32(cy + dy)))
                    if let c = grid[k] { r.append(contentsOf: c) }
                } }
                return r
            }
            if pr.sigma > 0 || pr.beta > 0 {
                for i in alive { for j in neighbours(i) where j > i {
                    let d = x[j] - x[i], r = simd_length(d)
                    guard r > 1e-6, r < h else { continue }
                    let n = d / r, q = r / h
                    let u = simd_dot(v[i] - v[j], n)
                    if u > 0 {
                        let I = dt * (1 - q) * (pr.sigma * u + pr.beta * u * u) * n * 0.5
                        v[i] -= I; v[j] += I
                    }
                } }
            }
            var prev = x
            for i in alive { prev[i] = x[i]; x[i] += v[i] * dt }
            // Slime / honey: springs between neighbours (elastic, stretchy strands).
            if kind != .water {
                for i in alive { for j in neighbours(i) where j > i {
                    let r = simd_length(x[j] - x[i]); guard r < h else { continue }
                    let k = Int64(i) << 32 | Int64(j)
                    let L = springs[k] ?? r
                    springs[k] = L + dt * 0.3 * (r - L)
                    let d = x[j] - x[i]; guard r > 1e-6 else { continue }
                    let D = dt * dt * 30 * (1 - L / h) * (L - r) * d / r
                    x[i] -= D * 0.5; x[j] += D * 0.5
                } }
                if s % 60 == 0 { springs = springs.filter { k, L in L < h } }
            }
            // Double density relaxation: keeps the liquid incompressible and gives surface tension.
            for i in alive {
                var rho = 0.0, rhoN = 0.0
                let nb = neighbours(i)
                for j in nb where j != i {
                    let q = simd_length(x[j] - x[i]) / h
                    if q < 1 { let a = 1 - q; rho += a * a; rhoN += a * a * a }
                }
                let P = pr.k * (rho - pr.rest) * 600, PN = pr.kNear * rhoN * 600
                var dx = SIMD2<Double>.zero
                for j in nb where j != i {
                    let d = x[j] - x[i], r = simd_length(d), q = r / h
                    guard q < 1, r > 1e-6 else { continue }
                    let a = 1 - q
                    let D = dt * dt * (P * a + PN * a * a) * d / r
                    x[j] += D * 0.5; dx -= D * 0.5
                }
                x[i] += dx
            }
            // Container: floor and side walls of the frame.
            for i in alive {
                if x[i].y > H - 6 { x[i].y = H - 6 }
                if x[i].x < 6 { x[i].x = 6 }
                if x[i].x > W - 6 { x[i].x = W - 6 }
                v[i] = (x[i] - prev[i]) / dt
            }
            if s % every == 0 {
                out.append(alive.map { x[$0] })
                progress(Double(s) / Double(max(1, steps)))
            }
        }
        return out
    }

    /// One frame of liquid: soft dots -> blur -> threshold (metaballs), colored, with a glossy highlight.
    nonisolated static func renderLiquid(_ pts: [SIMD2<Double>], width: Int, height: Int, scale: Double, color: RGBA, radius: Double) -> Data? {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
        ctx.setFillColor(UIColor.white.cgColor)
        let r = radius * scale
        for p in pts { ctx.fillEllipse(in: CGRect(x: p.x * scale - r, y: p.y * scale - r, width: r * 2, height: r * 2)) }
        guard let dots = ctx.makeImage() else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let blurred = CIImage(cgImage: dots).clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: r * 0.9]).cropped(to: rect)
        // Threshold the blurred alpha into a crisp blob edge.
        let mask = blurred.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 9),
            "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: -3.6)]).applyingFilter("CIColorClamp")
        let body = CIImage(color: CIColor(red: color.r, green: color.g, blue: color.b, alpha: 0.88)).cropped(to: rect)
        let colored = body.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: mask])
        // Gloss: the blob shrunk and nudged up-left, as a soft white highlight inside the body.
        let inner = mask.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: r * 0.5])
            .transformed(by: CGAffineTransform(translationX: -r * 0.35, y: r * 0.35))
        let edge = mask.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.5]).cropped(to: rect)
        let hiMask = inner.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: r * 0.4]).cropped(to: rect)
        let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 0.35)).cropped(to: rect)
        let highlight = white.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: hiMask])
            .applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: edge])
        let final = highlight.composited(over: colored)
        let ci = CIContext()
        guard let cg = ci.createCGImage(final, from: rect) else { return nil }
        return UIImage(cgImage: cg).pngData()
    }
}

/// Physics Studio: soft bodies, hanging / rope swing and liquids.
struct SoftPhysicsSection: View {
    @ObservedObject var state: EditorState
    @State private var material: SoftMaterial = .jelly
    @State private var drop = 400.0
    @State private var gravity = 1800.0
    @State private var duration = 3.0
    @State private var floor = true
    @State private var swing = 600.0
    @State private var wind = 120.0
    @State private var clothStiff = 0.8
    @State private var liquid: LiquidKind = .water
    @State private var liquidColor = LiquidKind.water.color
    @State private var amount = 400.0
    @State private var pourX = 0.5
    @State private var liquidProgress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            block("Soft Body", "The selected layer falls, lands and wobbles: the image itself squashes and jiggles (baked to Puppet Pins).") {
                Picker("", selection: $material) { ForEach(SoftMaterial.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                row("Drop Height", $drop, 0...1500)
                row("Gravity", $gravity, 200...5000)
                row("Duration s", $duration, 0.5...8)
                Toggle("Land on the frame's floor", isOn: $floor).tint(Theme.accent).foregroundStyle(Theme.text).font(.system(size: 13))
                bake("Make Soft Body", enabled: state.selectedLayer != nil) {
                    state.bakeSoftBody(material, drop: drop, gravity: gravity, duration: duration, floorAtBottom: floor)
                }
            }
            block("Hang / Rope / Cloth", "The selected layer hangs from its top edge and swings (capes, hair, banners, rope).") {
                row("Swing", $swing, 0...3000)
                row("Wind", $wind, -1500...1500)
                row("Cloth Stiffness", $clothStiff, 0...1)
                row("Duration s", $duration, 0.5...8)
                bake("Make It Hang", enabled: state.selectedLayer != nil) {
                    state.bakeHang(swing: swing, wind: wind, stiffness: clothStiff, duration: duration)
                }
            }
            block("Liquid", "Pours a liquid into the frame (particle fluid with glossy blobs) as a new layer at the playhead.") {
                Picker("", selection: $liquid) { ForEach(LiquidKind.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    .onChange(of: liquid) { _, k in liquidColor = k.color }
                AWIColorWell("Color", selection: Binding(get: { Color(liquidColor) }, set: { liquidColor = $0.rgba }), supportsOpacity: false)
                    .foregroundStyle(Theme.text)
                row("Amount", $amount, 60...900)
                row("Pour From", $pourX, 0.05...0.95)
                row("Duration s", $duration, 0.5...6)
                if let p = liquidProgress {
                    ProgressView(value: p).tint(Theme.accent)
                    Text("Simulating \(Int(p * 100))%").font(.caption).foregroundStyle(Theme.textDim)
                } else {
                    bake("Pour \(liquid.title)", enabled: true) {
                        liquidProgress = 0
                        state.makeLiquid(liquid, color: liquidColor, amount: Int(amount), pourX: pourX, duration: duration) { p in
                            liquidProgress = p >= 1 ? nil : p
                        }
                    }
                }
            }
        }
    }

    private func block<C: View>(_ t: String, _ hint: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accentGlow)
            Text(hint).font(.caption).foregroundStyle(Theme.textDim)
            c()
        }
    }

    private func row(_ t: String, _ v: Binding<Double>, _ r: ClosedRange<Double>) -> some View {
        HStack {
            Text(t).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 96, alignment: .leading)
            ValueScrubber(value: v.wrappedValue, range: r, onChange: { v.wrappedValue = $0 })
        }
    }

    private func bake(_ t: String, enabled: Bool, _ a: @escaping () -> Void) -> some View {
        Button { a(); UIImpactFeedbackGenerator(style: .medium).impactOccurred() } label: {
            Label(t, systemImage: "play.circle.fill").font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(RoundedRectangle(cornerRadius: 12).fill(enabled ? Theme.accent : Theme.raised))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain).disabled(!enabled)
    }
}
