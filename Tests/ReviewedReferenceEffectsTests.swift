import XCTest
@testable import AWIeffect

final class ReviewedReferenceEffectsTests: XCTestCase {
    private func render(_ effect: EffectInstance?, time: Double = 0.4) throws -> [UInt8] {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        var project = Project.new(name: "Reviewed reference", width: 128, height: 128, fps: 30, duration: 3, background: RGBA(0, 0, 0, 0))
        var layer = project.makeLayer(name: "Artwork", content: .shape(.ellipse), size: Vec2(106, 86))
        layer.fill = Animated(RGBA(0.6, 0.3, 0.8, 0.65))
        layer.effects = effect.map { [$0] } ?? []
        project.layers = [layer]
        return try XCTUnwrap(renderer.renderPixels(project: project, time: time, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }
    func testPromotedNamesAndIDsAreUniqueInBrowser() {
        for definition in EffectRegistry.reviewedReferenceEffects {
            XCTAssertEqual(EffectRegistry.all.filter { $0.id == definition.id }.count, 1)
            XCTAssertEqual(EffectRegistry.all.filter { $0.name.lowercased() == definition.name.lowercased() }.count, 1, definition.name)
        }
    }
    func testColorEffectsKeepTranslucentArtworkCoverage() throws {
        let baseline = try render(nil)
        let alpha = stride(from: 3, to: baseline.count, by: 4).map { baseline[$0] }
        for id in ["awi.amref.e75f2a17f4488", "awi.amref.e51de8cc7d47d", "awi.amref.ea3452b1fb102"] {
            let definition = try XCTUnwrap(EffectRegistry.definition(id))
            let output = try render(definition.makeInstance())
            XCTAssertEqual(stride(from: 3, to: output.count, by: 4).map { output[$0] }, alpha, definition.name)
            XCTAssertNotEqual(output, baseline, definition.name)
        }
    }
    func testFractalColorZeroMixIsExactBypass() throws {
        var effect = ReferenceFragmentCatalog.ea3452b1fb102.definition.makeInstance()
        effect.params["blend"] = .number(Animated(0))
        XCTAssertEqual(try render(effect), try render(nil))
    }
    func testTileBreakKeysReachIntactAndFullyRemovedEndpoints() throws {
        var effect = ReferenceFragmentCatalog.eeab7e403ece5.definition.makeInstance()
        var progress = Animated(0.0)
        progress.insertKeyframe(Keyframe(time: 0, value: 0.0))
        progress.insertKeyframe(Keyframe(time: 1, value: 100.0))
        effect.params["progress"] = .number(progress)
        let baseline = try render(nil, time: 0), start = try render(effect, time: 0)
        let error = zip(baseline, start).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(baseline.count)
        XCTAssertLessThan(error, 0.2)
        let end = try render(effect, time: 1)
        XCTAssertTrue(stride(from: 3, to: end.count, by: 4).allSatisfy { end[$0] == 0 })
    }
    func testPaletteControlsFollowNativeChoiceValuesWithoutDeletingColors() {
        var effect = ReferenceFragmentCatalog.ea4ee3a4adc94.definition.makeInstance()
        XCTAssertFalse(ReferenceFragmentControls.isVisible("color1", effect: effect))
        XCTAssertFalse(ReferenceFragmentControls.isVisible("shades", effect: effect))
        effect.params["palette"] = .choice(7) // Source value 6: custom three-color palette.
        for id in ["color1", "color2", "color3", "shades"] { XCTAssertTrue(ReferenceFragmentControls.isVisible(id, effect: effect), id) }
        XCTAssertFalse(ReferenceFragmentControls.isVisible("color4", effect: effect))
        XCTAssertNotNil(effect.params["color4"], "Switching mode must retain inactive color settings")
        var diffusion = ReferenceFragmentCatalog.e658cad5dcbff.definition.makeInstance()
        diffusion.params["palette"] = .choice(10) // Source value 12, not UI index 12.
        XCTAssertTrue(ReferenceFragmentControls.isVisible("color2", effect: diffusion))
        XCTAssertFalse(ReferenceFragmentControls.isVisible("color3", effect: diffusion))
    }
    func testTileRotateSeedChangesOnlyAnEnabledRandomField() throws {
        var effect = ReferenceFragmentCatalog.e8404b5764d4f.definition.makeInstance()
        XCTAssertFalse(ReferenceFragmentControls.isVisible("seed", effect: effect))
        let fixed = try render(effect)
        effect.params["seed"] = .number(Animated(2))
        XCTAssertEqual(try render(effect), fixed)
        effect.params["strength"] = .number(Animated(0.35))
        XCTAssertTrue(ReferenceFragmentControls.isVisible("seed", effect: effect))
        let randomized = try render(effect)
        effect.params["seed"] = .number(Animated(0))
        XCTAssertNotEqual(try render(effect), randomized)
    }

}
