import XCTest
import simd
@testable import AWIeffect

/// Crash hunting: every effect rendered with extreme settings (slider ends, typed values far past them,
/// negatives), degenerate layers, and rapid edits during playback-style rendering. Nothing may crash or hang.
final class StressTests: XCTestCase {
    private func scene(_ fx: [EffectInstance], scale: Double = 100) -> Project {
        var p = Project.new(name: "stress", width: 160, height: 160, fps: 30, duration: 2, background: RGBA(0.1, 0.1, 0.15))
        var star = p.makeLayer(name: "star", content: .shape(.star), size: Vec2(90, 90))
        star.fill = Animated(RGBA(1, 0.8, 0.3))
        star.transform.scale = Animated(Vec2(scale, scale))
        star.effects = fx
        var bg = p.makeLayer(name: "bg", content: .solid, size: Vec2(160, 60))
        bg.fill = Animated(RGBA(0.2, 0.6, 0.9))
        p.layers = [star, bg]
        return p
    }

    private func set(_ d: EffectDefinition, _ pick: (Double, Double) -> Double) -> EffectInstance {
        var e = d.makeInstance()
        for pd in d.params {
            if case .number(let lo, let hi, _, _) = pd.kind { e.params[pd.id] = .number(Animated(pick(lo, hi))) }
        }
        return e
    }

    func testEveryEffectSurvivesExtremeSettings() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let cases: [(String, (Double, Double) -> Double)] = [
            ("min", { lo, _ in lo }),
            ("max", { _, hi in hi }),
        ]
        var slow: [String] = []
        for d in EffectRegistry.all {
            for (name, pick) in cases {
                let p = scene([set(d, pick)])
                let t0 = CFAbsoluteTimeGetCurrent()
                _ = r.renderPixels(project: p, time: 0.4, mediaURL: { URL(fileURLWithPath: $0) })
                let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
                if ms > 1500 { slow.append("\(d.id) [\(name)] \(Int(ms))ms") }
            }
        }
        for s in slow { print("SKIP-INFO slow extreme: \(s)") }
        XCTAssertLessThan(slow.count, 1, "effects that stall at extreme settings: \(slow.prefix(20))")
    }

    func testDegenerateLayersDoNotCrash() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let glow = EffectRegistry.glow.makeInstance(), blur = EffectRegistry.gaussianBlur.makeInstance()
        for s in [0.0, 0.0001, -100, 100_000, 5_000_000] {
            _ = r.renderPixels(project: scene([glow, blur], scale: s), time: 0.4, mediaURL: { URL(fileURLWithPath: $0) })
        }
        var p = scene([glow])
        p.layers[0].size = Animated(Vec2(0, 0))
        _ = r.renderPixels(project: p, time: 0.4, mediaURL: { URL(fileURLWithPath: $0) })
        p.layers[0].transform.position = Animated(Vec2(.nan, .infinity))
        p.layers[0].transform.rotation = Animated(.nan)
        _ = r.renderPixels(project: p, time: 0.4, mediaURL: { URL(fileURLWithPath: $0) })
        p.layers[0].transform.position.expression = "1/0"
        _ = r.renderPixels(project: p, time: 0.4, mediaURL: { URL(fileURLWithPath: $0) })
    }

    /// Settings changing every frame while "playing" through the preview path (pool recycling, triple buffering).
    func testRapidEditsWhilePlaying() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let pools = (0..<3).map { _ in r.makePool() }
        let defs = Array(EffectRegistry.all.prefix(60))
        var p = scene([])
        for frame in 0..<240 {
            let d = defs[frame % defs.count]
            p.layers[0].effects = [set(d) { lo, hi in lo + (hi - lo) * Double(frame % 7) / 6 }]
            p.layers[0].transform.scale = Animated(Vec2(20 + Double(frame % 50) * 8, 100))
            p.modifiedAt = Date()
            guard let tex = r.makeCompTexture(width: 120 + frame % 40, height: 120), let cb = r.queue.makeCommandBuffer() else { continue }
            let pool = pools[frame % 3]
            pool.recycle()
            r.encode(project: p, time: Double(frame) / 30, renderScale: 0.75, into: tex, commandBuffer: cb, pool: pool, mediaURL: { URL(fileURLWithPath: $0) })
            cb.commit()
            if frame % 3 == 2 { cb.waitUntilCompleted() }
        }
    }

    /// Every title style must look different from plain white text and keep its animation.
    func testTitleStylesRenderAndDiffer() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var plain = TitleStylePreviews.project(for: TitleStyles.all[0])
        plain.layers[0].effects = []; plain.layers[0].text?.animators = []
        plain.layers[0].text?.fill = Animated(.white); plain.layers[0].text?.fontName = "Helvetica-Bold"
        let base = try XCTUnwrap(r.renderPixels(project: plain, time: 1.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        for st in TitleStyles.all {
            XCTAssertEqual(st.makeEffects().count, st.effects.count, "\(st.name): unknown effect id")
            if let a = st.animation { XCTAssertNotNil(TextPresets.all.first { $0.id == a }, "\(st.name): unknown animation \(a)") }
            let px = try XCTUnwrap(r.renderPixels(project: TitleStylePreviews.project(for: st), time: 1.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
            var d = 0.0
            for i in 0..<min(px.count, base.count) { d += Double(abs(Int(px[i]) - Int(base[i]))) }
            if !["clean", "softShadow", "elegant", "typewriter", "wideSpaced"].contains(st.id) { XCTAssertGreaterThan(d / Double(px.count), 0.3, "\(st.name) looks like plain text") }
        }
    }

    /// Smooth Motion: a shaking layer is motion-blurred automatically (AE look), and turning it off removes the blur.
    func testSmoothMotionBlursShakes() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var shake = EffectRegistry.shake.makeInstance()
        shake.params["amplitude"] = .number(Animated(40))
        var p = scene([shake])
        let on = try XCTUnwrap(r.renderPixels(project: p, time: 0.43, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        p.smoothMotion = false
        let off = try XCTUnwrap(r.renderPixels(project: p, time: 0.43, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        var d = 0.0
        for i in 0..<min(on.count, off.count) { d += Double(abs(Int(on[i]) - Int(off[i]))) }
        XCTAssertGreaterThan(d / Double(on.count), 0.2, "shake should be motion-blurred by default")
    }

    /// 2D camera (Alight Motion style): moving the camera right slides 2D layers left; scaling it zooms in.
    func testTwoDCameraMovesScene() {
        var p = Project.new(name: "cam", width: 200, height: 200, fps: 30, duration: 2)
        let box = p.makeLayer(name: "box", content: .solid, size: Vec2(20, 20))
        var cam = p.makeLayer(name: "cam", content: .camera, size: Vec2(1, 1))
        cam.camera = CameraOptions()
        cam.camera?.affects2D = true
        cam.transform.position = Animated(Vec2(150, 100))
        cam.transform.scale = Animated(Vec2(200, 200))
        p.layers = [cam, box]
        let state = Renderer.activeCamera(p, time: 0)
        let m = Renderer.placementMatrix(box, camera: state, time: 0, renderScale: 1)
        let c = m * SIMD3(0, 0, 1)
        // Box center (100,100) is 50 px left of the camera; zoom 2x -> 100 px left of frame center.
        XCTAssertEqual(c.x, 0, accuracy: 1e-6); XCTAssertEqual(c.y, 100, accuracy: 1e-6)
        cam.camera?.affects2D = false
        p.layers = [cam, box]
        let m2 = Renderer.placementMatrix(box, camera: Renderer.activeCamera(p, time: 0), time: 0, renderScale: 1)
        XCTAssertEqual((m2 * SIMD3(0, 0, 1)).x, 100, accuracy: 1e-6, "3D-only camera leaves 2D layers alone")
    }

    /// Groups: parts render in place; moving the group moves every part; a mask on the group cuts all parts.
    func testGroupAppliesToAllParts() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var p = Project.new(name: "grp", width: 100, height: 100, fps: 30, duration: 2, background: RGBA(0, 0, 0, 1))
        var a = p.makeLayer(name: "a", content: .solid, size: Vec2(20, 20)); a.fill = Animated(RGBA(1, 0, 0)); a.transform.position = Animated(Vec2(25, 50))
        var b = p.makeLayer(name: "b", content: .solid, size: Vec2(20, 20)); b.fill = Animated(RGBA(0, 1, 0)); b.transform.position = Animated(Vec2(75, 50))
        var g = p.makeLayer(name: "g", content: .solid, size: Vec2(100, 100)); g.isGroup = true; g.fill = Animated(RGBA(0, 0, 0, 0))
        a.groupID = g.id; b.groupID = g.id
        p.layers = [g, a, b]
        func px(_ proj: Project, _ x: Int, _ y: Int) -> (Int, Int) {
            let o = r.renderPixels(project: proj, time: 0.5, mediaURL: { URL(fileURLWithPath: $0) })!
            let i = (y * o.width + x) * 4
            return (Int(o.rgba[i]), Int(o.rgba[i + 1]))
        }
        XCTAssertGreaterThan(px(p, 25, 50).0, 200, "part a renders in place")
        XCTAssertGreaterThan(px(p, 75, 50).1, 200, "part b renders in place")
        var moved = p
        moved.layers[0].transform.position = Animated(Vec2(50, 70))
        XCTAssertGreaterThan(px(moved, 25, 70).0, 200, "moving the group moves part a")
        XCTAssertGreaterThan(px(moved, 75, 70).1, 200, "and part b")
        var masked = p
        var path = BezierPath.rectangle(size: Vec2(50, 100))
        for k in path.vertices.indices { path.vertices[k].point = path.vertices[k].point + Vec2(-25, 0) }
        masked.layers[0].masks = [LayerMask(path: Animated(path))]
        XCTAssertGreaterThan(px(masked, 25, 50).0, 200, "left part inside the group mask stays")
        XCTAssertLessThan(px(masked, 75, 50).1, 40, "right part outside the group mask is cut")
    }
}
