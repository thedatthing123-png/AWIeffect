import XCTest
@testable import AWIeffect

final class KeyframeTests: XCTestCase {
    func testStaticValue() {
        let p = Animated(5.0)
        XCTAssertEqual(p.value(at: 0), 5)
        XCTAssertEqual(p.value(at: 100), 5)
        XCTAssertFalse(p.isAnimated)
    }

    func testLinearInterpolation() {
        var p = Animated(0.0)
        p.insertKeyframe(Keyframe(time: 0, value: 0))
        p.insertKeyframe(Keyframe(time: 2, value: 100))
        XCTAssertEqual(p.value(at: -1), 0)
        XCTAssertEqual(p.value(at: 1), 50, accuracy: 1e-9)
        XCTAssertEqual(p.value(at: 1.5), 75, accuracy: 1e-9)
        XCTAssertEqual(p.value(at: 3), 100)
    }

    func testHoldInterpolation() {
        var p = Animated(0.0)
        p.insertKeyframe(Keyframe(time: 0, value: 10, interpolation: .hold))
        p.insertKeyframe(Keyframe(time: 1, value: 20))
        XCTAssertEqual(p.value(at: 0.99), 10)
        XCTAssertEqual(p.value(at: 1), 20)
    }

    func testBezierEasyEaseIsSymmetricAndSlowAtEnds() {
        var p = Animated(0.0)
        p.insertKeyframe(Keyframe(time: 0, value: 0, interpolation: .bezier))
        p.insertKeyframe(Keyframe(time: 1, value: 1))
        XCTAssertEqual(p.value(at: 0.5), 0.5, accuracy: 1e-4)
        // Easy ease starts slower than linear.
        XCTAssertLessThan(p.value(at: 0.1), 0.1)
        XCTAssertGreaterThan(p.value(at: 0.9), 0.9)
        XCTAssertEqual(p.value(at: 0.1) + p.value(at: 0.9), 1, accuracy: 1e-4)
    }

    func testBezierLinearHandlesMatchLinear() {
        for x in stride(from: 0.0, through: 1.0, by: 0.05) {
            let y = BezierTiming.progress(x: x, p1: .linearOut, p2: .linearIn)
            XCTAssertEqual(y, x, accuracy: 1e-5)
        }
    }

    func testSetUpdatesKeyframeWhenAnimated() {
        var p = Animated(Vec2(0, 0))
        p.toggleKeyframe(at: 0)
        p.set(Vec2(10, 20), at: 1)
        XCTAssertEqual(p.keyframes.count, 2)
        p.set(Vec2(30, 40), at: 1)
        XCTAssertEqual(p.keyframes.count, 2)
        XCTAssertEqual(p.value(at: 1), Vec2(30, 40))
    }

    func testToggleRemovesLastKeyframeAndKeepsValue() {
        var p = Animated(7.0)
        p.toggleKeyframe(at: 0.5)
        p.set(9, at: 0.5)
        p.toggleKeyframe(at: 0.5)
        XCTAssertFalse(p.isAnimated)
        XCTAssertEqual(p.value(at: 0), 9)
    }

    func testKeyframesStaySorted() {
        var p = Animated(0.0)
        p.insertKeyframe(Keyframe(time: 3, value: 3))
        p.insertKeyframe(Keyframe(time: 1, value: 1))
        p.insertKeyframe(Keyframe(time: 2, value: 2))
        XCTAssertEqual(p.keyframeTimes, [1, 2, 3])
    }

    func testColorInterpolation() {
        var p = Animated(RGBA.black)
        p.insertKeyframe(Keyframe(time: 0, value: .black))
        p.insertKeyframe(Keyframe(time: 1, value: .white))
        let mid = p.value(at: 0.5)
        XCTAssertEqual(mid.r, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mid.a, 1, accuracy: 1e-9)
    }
}

final class ProjectTests: XCTestCase {
    func testCodableRoundTrip() throws {
        var p = Project.new(name: "Test", width: 1080, height: 1920, fps: 60)
        var l = p.makeLayer(name: "Star", content: .shape(.star), size: Vec2(200, 200))
        l.transform.position.toggleKeyframe(at: 0)
        l.transform.position.set(Vec2(100, 100), at: 1)
        l.blendMode = .screen
        p.layers.append(l)
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(back, p)
    }

    func testAspectLabelAndFrames() {
        let p = Project.new(name: "A", width: 1080, height: 1350, fps: 30, duration: 2)
        XCTAssertEqual(p.aspectLabel, "4:5")
        XCTAssertEqual(p.frameCount, 60)
        XCTAssertEqual(p.snapToFrame(0.51), 0.5, accuracy: 1e-9)
    }

    func testStoreSaveLoadAndVersions() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ProjectStore(root: dir)
        var p = Project.new(name: "Stored", width: 100, height: 100, fps: 24)
        try store.save(p, snapshotVersion: true)
        p.name = "Renamed"
        try store.save(p, snapshotVersion: true)
        XCTAssertEqual(try store.load(p.id).name, "Renamed")
        XCTAssertEqual(store.list().count, 1)
        XCTAssertGreaterThanOrEqual(store.versions(for: p.id).count, 1)
        store.delete(p.id)
        XCTAssertEqual(store.list().count, 0)
    }
}
