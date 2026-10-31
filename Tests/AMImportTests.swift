import XCTest
@testable import AWIeffect

/// Real Alight Motion project exports (Tests/Fixtures/am) must import with their layers, timing, keyframes and effects.
final class AMImportTests: XCTestCase {
    private func load(_ name: String) throws -> AEPImportResult {
        guard let u = Bundle(for: Self.self).url(forResource: name, withExtension: "xml") else { throw XCTSkip("fixture \(name) missing") }
        return try AMImporter.load(data: Data(contentsOf: u), fallbackName: name)
    }

    func testShakeEditImports() throws {
        let r = try load("am_shakes")
        XCTAssertEqual(r.project.width, 1080); XCTAssertEqual(r.project.height, 1350)
        XCTAssertEqual(r.project.fps, 60)
        XCTAssertEqual(r.project.duration, 2.283, accuracy: 0.01)
        XCTAssertEqual(r.project.layers.count, 4)
        let ids = Set(r.project.layers.flatMap { $0.effects.map(\.typeID) })
        XCTAssertTrue(ids.contains("awi.shake"), "shakes missing: \(ids)")
        XCTAssertTrue(ids.contains("awi.oscillate"))
        XCTAssertTrue(r.project.layers.contains { $0.motionBlur })
        // Keyframed shake magnitude survives with AM bezier easing.
        let shake = try XCTUnwrap(r.project.layers.flatMap(\.effects).first { e in
            if case .number(let a)? = e.params["amplitude"] { return a.isAnimated }; return false
        })
        if case .number(let a)? = shake.params["amplitude"] {
            XCTAssertGreaterThanOrEqual(a.keyframes.count, 2)
            XCTAssertTrue(a.keyframes.contains { $0.interpolation == .bezier })
        }
        // Layers are back-to-back in time (AM startTime/endTime in ms).
        let sorted = r.project.layers.sorted { $0.inPoint < $1.inPoint }
        XCTAssertEqual(sorted.first?.inPoint ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(sorted.last?.outPoint ?? 0, 2.283, accuracy: 0.01)
    }

    func testBigEffectsEditImportsMostEffects() throws {
        let r = try load("am_effects")
        XCTAssertGreaterThan(r.project.layers.count, 50)
        let missing = r.report.entries.filter { $0.status == .missing && $0.item != "Media" && $0.item != "Audio" }
        let total = r.report.entries.filter { $0.item != "Media" && $0.item != "Audio" }.count
        XCTAssertLessThan(Double(missing.count), Double(total) * 0.1, "too many unmapped: \(Set(missing.map(\.item)))")
        XCTAssertFalse(r.project.precomps.isEmpty, "groups should become pre-comps")
        XCTAssertTrue(r.project.layers.contains { $0.content == .camera })
        XCTAssertFalse(r.project.markers.isEmpty, "bookmarks should become beat markers")
    }

    func testTextNullsDrawingsAndParents() throws {
        let r = try load("am_text")
        let texts = r.project.layers.filter { $0.content == .text }
        XCTAssertGreaterThan(texts.count, 5)
        XCTAssertTrue(texts.contains { $0.text?.string == "My" }, "text content: \(texts.compactMap { $0.text?.string }.prefix(5))")
        XCTAssertTrue(r.project.layers.contains { $0.isNull })
        XCTAssertTrue(r.project.layers.contains { $0.parentID != nil }, "parent links")
        XCTAssertTrue(r.project.layers.contains { if case .shape(.path) = $0.content { return $0.stroke.enabled }; return false }, "drawing strokes")
        XCTAssertTrue(r.project.layers.contains { $0.text?.animators.isEmpty == false }, "text progress → typewriter")
    }

    func testImportedAMProjectRenders() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        for name in ["am_shakes", "am_text"] {
            let p = try load(name).project
            XCTAssertNotNil(renderer.renderPixels(project: p, time: min(1, p.duration / 2), renderScale: 0.2, mediaURL: { URL(fileURLWithPath: $0) }))
        }
    }

    func testAEPluginsSwapIn() {
        XCTAssertEqual(PluginSwap.lookup("Videocopilot Twitch")?.id, "awi.jitter")
        XCTAssertEqual(PluginSwap.lookup("VIDEOCOPILOT OpticalFlares")?.id, "ae.lensFlare")
        XCTAssertEqual(PluginSwap.lookup("S_Glow")?.id, "awi.deepGlow")
        for (_, sub) in PluginSwap.table { XCTAssertNotNil(EffectRegistry.definition(sub.id), "\(sub.plugin) → missing \(sub.id)") }
    }
}
