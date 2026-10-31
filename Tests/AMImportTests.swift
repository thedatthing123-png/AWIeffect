import XCTest
import QuartzCore
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

/// Frame-time budget for real imported edits (CI GPU is slower than an iPhone 16 Pro Max, so this is a ceiling).
final class RenderSpeedTests: XCTestCase {
    private func msPerFrame(_ p: Project, _ renderer: Renderer) -> Double {
        _ = renderer.renderPixels(project: p, time: 1, renderScale: 0.4, mediaURL: { URL(fileURLWithPath: $0) })
        let t0 = CACurrentMediaTime(), frames = 10
        for i in 0..<frames {
            _ = renderer.renderPixels(project: p, time: 0.5 + Double(i) * (p.duration - 1) / Double(frames), renderScale: 0.4,
                                      mediaURL: { URL(fileURLWithPath: $0) })
        }
        return (CACurrentMediaTime() - t0) / Double(frames) * 1000
    }

    func testHeavyAMEditRendersFast() throws {
        guard let renderer = Renderer.shared,
              let u = Bundle(for: Self.self).url(forResource: "am_effects", withExtension: "xml") else { throw XCTSkip("SKIP-GPU") }
        let p = try AMImporter.load(data: Data(contentsOf: u), fallbackName: "speed").project
        let full = msPerFrame(p, renderer)
        var noMB = p; noMB.motionBlurEnabled = false
        var noFX = p; for i in noFX.layers.indices { noFX.layers[i].effects = [] }; noFX.motionBlurEnabled = false
        var bare = noFX; bare.layers = bare.layers.map { var l = $0; l.content = .solid; return l }
        let a = msPerFrame(noMB, renderer), b = msPerFrame(noFX, renderer), c = msPerFrame(bare, renderer)
        // Cost of each effect type actually used by this edit (remove one type at a time).
        let types = Dictionary(grouping: p.layers.flatMap(\.effects), by: \.typeID).mapValues(\.count)
        for (id, count) in types.sorted(by: { $0.value > $1.value }) {
            var q = p
            for i in q.layers.indices { q.layers[i].effects.removeAll { $0.typeID == id } }
            print(String(format: "SKIP-INFO RENDER-SPEED without %@ (x%d): %.1f ms", id, count, msPerFrame(q, renderer)))
        }
        // "SKIP-INFO" lines are kept by the CI log filter.
        print(String(format: "SKIP-INFO RENDER-SPEED full %.1f | no motion blur %.1f | no effects %.1f | solids only %.1f ms/frame (%d layers)",
                     full, a, b, c, p.layers.count))
        XCTAssertLessThan(full, 900, "preview frames are far too slow")
    }
}

/// A real community AE edit full of third-party plugins (Twitch, Optical Flares, BCC, Sapphire, Universe…).
final class RealAEPTests: XCTestCase {
    func testPluginHeavyEditImports() throws {
        guard let u = Bundle(for: Self.self).url(forResource: "yuta_edit", withExtension: "aep") else { throw XCTSkip("fixture missing") }
        let base = try AEPImporter.load(url: u)
        print("SKIP-INFO YUTA comps: \(base.report.comps.prefix(12)) layers=\(base.project.layers.count)")
        let swapped = base.report.entries.filter { $0.detail.contains("replaced by the built-in") }
        print("SKIP-INFO YUTA swapped \(swapped.count): \(Set(swapped.map(\.item)).sorted())")
        print("SKIP-INFO YUTA missing: \(Set(base.report.entries.filter { $0.status == .missing }.map(\.item)).sorted().prefix(30))")
        XCTAssertGreaterThan(base.project.layers.count, 0)
        if let r = Renderer.shared {
            XCTAssertNotNil(r.renderPixels(project: base.project, time: min(2, base.project.duration / 2), renderScale: 0.2, mediaURL: { URL(fileURLWithPath: $0) }))
        }
    }
}

/// Times every effect alone on a preview-sized frame and reports the slowest (so heavy shaders get fixed).
final class EffectSpeedTests: XCTestCase {
    func testSlowestEffects() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var base = Project.new(name: "s", width: 432, height: 768, fps: 30, duration: 2, background: RGBA(0.1, 0.1, 0.15))
        var l = base.makeLayer(name: "full", content: .solid, size: Vec2(432, 768))
        l.fill = Animated(RGBA(0.8, 0.5, 0.9))
        base.layers = [l]
        func time(_ p: Project) -> Double {
            _ = r.renderPixels(project: p, time: 0.4, mediaURL: { URL(fileURLWithPath: $0) })
            let t0 = CACurrentMediaTime()
            for i in 0..<3 { _ = r.renderPixels(project: p, time: 0.4 + Double(i) * 0.1, mediaURL: { URL(fileURLWithPath: $0) }) }
            return (CACurrentMediaTime() - t0) / 3 * 1000
        }
        let plain = time(base)
        var results: [(String, Double)] = []
        for d in EffectRegistry.all {
            var p = base
            p.layers[0].effects = [d.makeInstance()]
            results.append((d.id, time(p) - plain))
        }
        results.sort { $0.1 > $1.1 }
        print(String(format: "SKIP-INFO EFFECT-SPEED baseline %.1f ms", plain))
        // Re-measure the top ones to rule out GPU warm-up noise.
        for (id, _) in results.prefix(6) {
            var p = base; p.layers[0].effects = [EffectRegistry.definition(id)!.makeInstance()]
            print(String(format: "SKIP-INFO EFFECT-SPEED recheck %@ +%.1f ms", id, time(p) - plain))
        }
        for (id, ms) in results.prefix(25) { print(String(format: "SKIP-INFO EFFECT-SPEED %@ +%.1f ms", id, ms)) }
        let lookup = ["ae.exposure", "ae.glow", "ae.motionTile", "ae.ripple", "ae.bulge", "ae.findEdges", "ae.gaussianBlur", "awi.flicker", "awi.chromaKey", "ae.fill", "ae.invert", "awi15.innerBlur", "ae.directionalBlur", "awi.shake"]
        for id in lookup { if let m = results.first(where: { $0.0 == id }) { print(String(format: "SKIP-INFO EFFECT-SPEED (am) %@ +%.1f ms", id, m.1)) } }
    }
}

/// Long playback of a heavy import with constantly changing preview size must not grow GPU memory without bound.
final class MemoryTests: XCTestCase {
    func testPoolMemoryStaysBoundedDuringPlayback() throws {
        guard let r = Renderer.shared,
              let u = Bundle(for: Self.self).url(forResource: "am_effects", withExtension: "xml") else { throw XCTSkip("SKIP-GPU") }
        let p = try AMImporter.load(data: Data(contentsOf: u), fallbackName: "mem").project
        guard let comp = r.makeCompTexture(width: 432, height: 540) else { return }
        let pool = r.makePool()
        var peak = 0
        for i in 0..<160 {
            // Simulate adaptive preview resolution changing frame to frame.
            let scale = [0.4, 0.3, 0.2, 0.35, 0.25][i % 5]
            guard let cb = r.queue.makeCommandBuffer() else { break }
            pool.recycle()
            r.encode(project: p, time: Double(i) / 30, renderScale: scale, into: comp, commandBuffer: cb, pool: pool,
                     mediaURL: { URL(fileURLWithPath: $0) })
            cb.commit(); cb.waitUntilCompleted()
            peak = max(peak, pool.spareBytes)
        }
        print(String(format: "SKIP-INFO MEMORY peak spare %.1f MB", Double(peak) / 1_048_576))
        XCTAssertLessThanOrEqual(peak, TexturePool.budgetBytes + 64 * 1024 * 1024, "texture pool keeps growing")
    }
}
