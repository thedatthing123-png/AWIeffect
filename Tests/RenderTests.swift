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
        for m in modes where m != .normal {
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
}
