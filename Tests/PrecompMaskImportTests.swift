import XCTest
@testable import AWIeffect

final class PrecompMaskImportTests: XCTestCase {
    private func load(_ name: String) throws -> AEPImportResult {
        guard let u = Bundle(for: Self.self).url(forResource: name, withExtension: "aep") else { throw XCTSkip("fixture \(name) missing") }
        return try AEPImporter.load(url: u)
    }

    func testDumpMaskAndShapeFixtures() throws {
        for n in ["mask", "mask_intersect", "psd_shape_layer", "psd_vector_mask_curves"] {
            let r = try load(n)
            print("AEPDUMP2 \(n): \(r.project.width)x\(r.project.height) layers=\(r.project.layers.count) precomps=\(r.project.precomps.count)")
            for l in r.project.layers.prefix(6) {
                print("AEPDUMP2   L '\(l.name)' \(l.content) size=\(l.size.staticValue) masks=\(l.masks.map { "\($0.mode) inv=\($0.inverted) pts=\($0.path.staticValue.vertices.map { "(\(Int($0.point.x)),\(Int($0.point.y)))" })" }) path=\(l.path?.staticValue.vertices.count ?? -1)")
            }
        }
    }

    func testMasksImportWithPoints() throws {
        let r = try load("mask")
        let masked = try XCTUnwrap(r.project.layers.first { !$0.masks.isEmpty }, "no masks imported")
        let path = masked.masks[0].path.staticValue
        XCTAssertGreaterThanOrEqual(path.vertices.count, 3)
        // Mask points must land inside a generous area around the layer (local coords are centered).
        let hs = Renderer.layerHalfSize(masked, time: 0)
        for v in path.vertices {
            XCTAssertLessThan(abs(v.point.x), hs.x * 3 + 10); XCTAssertLessThan(abs(v.point.y), hs.y * 3 + 10)
        }
    }

    func testMaskModeImports() throws {
        // The sample file holds several comps; check them all.
        guard let u = Bundle(for: Self.self).url(forResource: "mask_intersect", withExtension: "aep") else { throw XCTSkip("fixture missing") }
        let comps = try AEPImporter.load(url: u).report.comps
        let modes = try comps.flatMap { name in try AEPImporter.load(url: u, compName: name).project.layers.flatMap { $0.masks.map(\.mode) } }
        XCTAssertTrue(modes.contains(.intersect), "expected an Intersect mask, got \(modes)")
    }

    func testImportedMaskedLayerRenders() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let p = try load("mask").project
        XCTAssertNotNil(r.renderPixels(project: p, time: 0, renderScale: 0.25, mediaURL: { URL(fileURLWithPath: $0) }))
    }

    // MARK: Pre-comps

    @MainActor
    private func state() -> EditorState {
        var p = Project.new(name: "root", width: 100, height: 100, fps: 30, duration: 2, background: .black)
        var l = p.makeLayer(name: "box", content: .solid, size: Vec2(40, 40))
        l.fill = Animated(.white)
        p.layers = [l]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.select(l.id)
        return s
    }

    @MainActor
    func testPrecomposeOpenEditClose() throws {
        let s = state()
        s.precomposeSelected()
        XCTAssertEqual(s.project.precomps.count, 1)
        guard case .precomp = s.project.layers[0].content else { return XCTFail("not a precomp layer") }
        s.openPrecomp()
        XCTAssertTrue(s.isInPrecomp)
        XCTAssertEqual(s.project.layers.first?.name, "box")
        // Edit inside the pre-comp, then close: the parent must see the change.
        s.mutate("recolor") { $0.layers[0].fill = Animated(RGBA(1, 0, 0)) }
        XCTAssertEqual(s.rootProject.precomps.first?.layers.first?.fill.staticValue, RGBA(1, 0, 0), "root save misses nested edit")
        s.closePrecomp()
        XCTAssertFalse(s.isInPrecomp)
        XCTAssertEqual(s.project.precomps.first?.layers.first?.fill.staticValue, RGBA(1, 0, 0))
    }

    @MainActor
    func testPrecompRendersLikeOriginal() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let s = state()
        let before = try XCTUnwrap(r.renderPixels(project: s.project, time: 0.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        s.precomposeSelected()
        let after = try XCTUnwrap(r.renderPixels(project: s.project, time: 0.5, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let c = (50 * 100 + 50) * 4
        XCTAssertGreaterThan(after[c], 240, "pre-comp content missing")
        XCTAssertEqual(Int(after[(5 * 100 + 5) * 4]), Int(before[(5 * 100 + 5) * 4]), accuracy: 3)
    }

    func testOldProjectWithoutPrecompsDecodes() throws {
        let p = Project.new(name: "o", width: 10, height: 10, fps: 30)
        let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.precomps.count, 0)
    }
}
