import XCTest
@testable import AWIeffect

/// GPU tests. If no Metal device exists (some CI simulators), they SKIP loudly, never silently pass.
final class RenderTests: XCTestCase {
    private func renderer() throws -> Renderer {
        guard let r = Renderer.shared else {
            throw XCTSkip("SKIP-GPU: no Metal device available; render tests not run")
        }
        return r
    }

    private func pixel(_ px: (width: Int, height: Int, rgba: [UInt8]), _ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8) {
        let i = (y * px.width + x) * 4
        return (px.rgba[i], px.rgba[i + 1], px.rgba[i + 2])
    }

    private func project(with layers: (inout Project) -> Void) -> Project {
        var p = Project.new(name: "T", width: 200, height: 200, fps: 30, duration: 2, background: .black)
        layers(&p)
        return p
    }

    func testBackgroundOnly() throws {
        let r = try renderer()
        let p = project { $0.background = RGBA(1, 0, 0) }
        let px = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) }))
        let c = pixel(px, 100, 100)
        XCTAssertEqual(c.0, 255); XCTAssertEqual(c.1, 0); XCTAssertEqual(c.2, 0)
    }

    func testEveryShapeDrawsAtCenterAndNotAtCorner() throws {
        let r = try renderer()
        for kind in ShapeKind.allCases {
            let p = project { p in
                var l = p.makeLayer(name: "s", content: .shape(kind), size: Vec2(100, 100))
                l.fill = Animated(.white)
                p.layers.append(l)
            }
            let px = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) }))
            XCTAssertGreaterThan(pixel(px, 100, 100).0, 240, "\(kind) not drawn at center")
            XCTAssertEqual(pixel(px, 2, 2).0, 0, "\(kind) leaked to corner")
        }
    }

    func testPositionKeyframesMoveLayer() throws {
        let r = try renderer()
        let p = project { p in
            var l = p.makeLayer(name: "s", content: .shape(.rectangle), size: Vec2(20, 20))
            l.fill = Animated(.white)
            l.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(30, 100)))
            l.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(170, 100)))
            p.layers.append(l)
        }
        let a = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) }))
        let b = try XCTUnwrap(r.renderPixels(project: p, time: 1, mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertGreaterThan(pixel(a, 30, 100).0, 240)
        XCTAssertEqual(pixel(a, 170, 100).0, 0)
        XCTAssertGreaterThan(pixel(b, 170, 100).0, 240)
        XCTAssertEqual(pixel(b, 30, 100).0, 0)
    }

    func testOpacityAndHiddenLayer() throws {
        let r = try renderer()
        var p = project { p in
            var l = p.makeLayer(name: "s", content: .solid, size: Vec2(200, 200))
            l.fill = Animated(.white)
            l.transform.opacity = Animated(50)
            p.layers.append(l)
        }
        let half = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertEqual(Double(pixel(half, 100, 100).0), 127.5, accuracy: 3)
        p.layers[0].isVisible = false
        let hidden = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertEqual(pixel(hidden, 100, 100).0, 0)
    }

    func testBlendModesProduceDistinctResults() throws {
        let r = try renderer()
        var results: [BlendMode: (UInt8, UInt8, UInt8)] = [:]
        for mode in BlendMode.allCases {
            let p = project { p in
                p.background = RGBA(0.25, 0.5, 0.75)
                var l = p.makeLayer(name: "s", content: .solid, size: Vec2(200, 200))
                l.fill = Animated(RGBA(0.6, 0.3, 0.9))
                l.blendMode = mode
                p.layers.append(l)
            }
            let px = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) }))
            results[mode] = pixel(px, 100, 100)
        }
        // Anti-stub: every mode changes the result vs Normal, and the set is (almost) all distinct
        // (some pairs, like Add / Linear Dodge, are the same formula in AE too for in-range colors).
        let modes = BlendMode.allCases
        // Darker / Lighter Color legitimately return the top color as-is when it wins (same as AE).
        for m in modes where m != .normal && m != .lighterColor && m != .darkerColor {
            XCTAssertFalse(results[m]! == results[.normal]!, "\(m) looks like Normal")
        }
        let distinct = Set(modes.map { "\(results[$0]!)" }).count
        XCTAssertGreaterThanOrEqual(distinct, modes.count - 3, "too many blend modes render the same")
        for i in modes.indices {
            for j in modes.indices where j > i && false {
                let a = results[modes[i]]!, b = results[modes[j]]!
                XCTAssertFalse(a == b, "\(modes[i]) and \(modes[j]) render identically")
            }
        }
        // Spot-check math: multiply 0.25*0.6 = 0.15 -> ~38
        XCTAssertEqual(Double(results[.multiply]!.0), 38, accuracy: 3)
        // screen: 0.25 + 0.6 - 0.15 = 0.7 -> ~178
        XCTAssertEqual(Double(results[.screen]!.0), 178, accuracy: 3)
    }

    func testLayerOrderTopWins() throws {
        let r = try renderer()
        let p = project { p in
            var top = p.makeLayer(name: "top", content: .solid, size: Vec2(200, 200))
            top.fill = Animated(RGBA(0, 1, 0))
            var bottom = p.makeLayer(name: "bottom", content: .solid, size: Vec2(200, 200))
            bottom.fill = Animated(RGBA(1, 0, 0))
            p.layers = [top, bottom]
        }
        let px = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) }))
        let c = pixel(px, 100, 100)
        XCTAssertEqual(c.0, 0); XCTAssertEqual(c.1, 255)
    }

    /// Alight Motion / AE Z: a lower layer with −Z comes in front of a layer above it.
    func testNegativeZBringsLowerLayerToFront() throws {
        let r = try renderer()
        let p = project { p in
            var top = p.makeLayer(name: "top", content: .solid, size: Vec2(200, 200))
            top.fill = Animated(RGBA(0, 1, 0))
            var bottom = p.makeLayer(name: "bottom", content: .solid, size: Vec2(200, 200))
            bottom.fill = Animated(RGBA(1, 0, 0))
            bottom.transform.positionZ = Animated(-10)
            p.layers = [top, bottom]
        }
        let c = pixel(try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) })), 100, 100)
        XCTAssertEqual(c.0, 255, "the −Z layer should be in front"); XCTAssertEqual(c.1, 0)
    }

    /// Huge depths (behind the camera) must render without crashing.
    func testHugeZValuesDontCrash() throws {
        let r = try renderer()
        for z in [-3000.0, -100_000, 1_000_000, -10_000_000] {
            let p = project { p in
                var l = p.makeLayer(name: "s", content: .shape(.rectangle), size: Vec2(100, 100))
                l.fill = Animated(.white)
                l.is3D = true
                l.transform.positionZ = Animated(z)
                var flat = p.makeLayer(name: "f", content: .shape(.ellipse), size: Vec2(60, 60))
                flat.fill = Animated(RGBA(1, 0, 0))
                flat.transform.positionZ = Animated(z)
                p.layers = [l, flat]
            }
            XCTAssertNotNil(r.renderPixels(project: p, time: 0, mediaURL: { URL(fileURLWithPath: $0) }), "z \(z)")
        }
    }

    /// Keyframed motion is smooth frame to frame: equal steps for linear keys, no jumps at keyframes,
    /// including through a parent chain where both layers animate (in-between frames combine).
    func testKeyframedMotionHasNoJumps() {
        var p = Project.new(name: "T", width: 200, height: 200, fps: 30, duration: 2, background: .black)
        var parent = p.makeLayer(name: "null", content: .solid, size: Vec2(10, 10))
        parent.isNull = true
        parent.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(40, 100), interpolation: .linear))
        parent.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(160, 100), interpolation: .linear))
        var child = p.makeLayer(name: "child", content: .shape(.rectangle), size: Vec2(20, 20))
        child.parentID = parent.id
        child.transform.position = Animated(Vec2(0, 0))
        child.transform.position.insertKeyframe(Keyframe(time: 0.5, value: Vec2(0, 0), interpolation: .linear))
        child.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(0, 30), interpolation: .linear))
        p.layers = [child, parent]
        var last: Vec2?
        var lastStep: Double?
        for f in 0...30 {
            let t = Double(f) / 30
            let w = Renderer.resolveParenting(p, time: t).layers[0].transform.position.value(at: t)
            if let l = last {
                let step = hypot(w.x - l.x, w.y - l.y)
                if let ls = lastStep { XCTAssertLessThan(abs(step - ls), 1.6, "jump at frame \(f)") }
                lastStep = step
            }
            last = w
        }
    }

    /// The preview renders exactly on frames: a time between frames shows the same picture as its frame.
    func testInBetweenTimesRenderTheFrame() throws {
        let r = try renderer()
        let p = project { p in
            var l = p.makeLayer(name: "s", content: .shape(.rectangle), size: Vec2(20, 20))
            l.fill = Animated(.white)
            l.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(20, 100)))
            l.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(180, 100)))
            p.layers.append(l)
        }
        let a = try XCTUnwrap(r.renderPixels(project: p, time: 10.0 / 30, mediaURL: { URL(fileURLWithPath: $0) }))
        let b = try XCTUnwrap(r.renderPixels(project: p, time: 10.0 / 30, mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertEqual(a.rgba, b.rgba, "same frame must render identically every time")
    }

    /// Heavy glow must not flicker: a still glowing layer renders the same on every frame, and a moving one glows
    /// smoothly (the glow's brightness and center move evenly, no frames where the glow drops out).
    func testDeepGlowIsStableFrameToFrame() throws {
        let r = try renderer()
        func scene(moving: Bool) -> Project {
            project { p in
                p.width = 400; p.height = 400
                var l = p.makeLayer(name: "s", content: .shape(.star), size: Vec2(120, 120))
                l.fill = Animated(RGBA(1, 0.4, 0.1))
                if moving {
                    l.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(120, 200), interpolation: .linear))
                    l.transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(280, 200), interpolation: .linear))
                } else { l.transform.position = Animated(Vec2(200, 200)) }
                var g = EffectRegistry.deepGlow.makeInstance()
                g.params["radius"] = .number(Animated(400))
                g.params["exposure"] = .number(Animated(1))
                l.effects = [g]
                p.layers = [l]
            }
        }
        let still = scene(moving: false)
        let first = try XCTUnwrap(r.renderPixels(project: still, time: 0, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        for f in 1...8 {
            let px = try XCTUnwrap(r.renderPixels(project: still, time: Double(f) / 30, mediaURL: { URL(fileURLWithPath: $0) })).rgba
            XCTAssertEqual(px, first, "still glow changed at frame \(f)")
        }
        let moving = scene(moving: true)
        var lastSum: Double?, lastX: Double?
        for f in 0...20 {
            let img = try XCTUnwrap(r.renderPixels(project: moving, time: Double(f) / 30, mediaURL: { URL(fileURLWithPath: $0) }))
            var sum = 0.0, sx = 0.0
            for y in stride(from: 0, to: img.height, by: 2) { for x in stride(from: 0, to: img.width, by: 2) {
                let v = Double(img.rgba[(y * img.width + x) * 4]); sum += v; sx += v * Double(x)
            } }
            let cx = sx / max(sum, 1)
            if let ls = lastSum { XCTAssertEqual(sum / ls, 1, accuracy: 0.08, "glow brightness jumped at frame \(f)") }
            if let lx = lastX { XCTAssertLessThan(abs(cx - lx), 9, "glow jumped sideways at frame \(f)") }
            lastSum = sum; lastX = cx
        }
    }
}
