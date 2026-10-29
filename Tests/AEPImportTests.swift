import XCTest
@testable import AWIeffect

/// Imports real After Effects projects (py-aep fixtures, MIT) and checks what comes through.
final class AEPImportTests: XCTestCase {
    private func fixture(_ name: String) throws -> URL {
        let b = Bundle(for: Self.self)
        guard let u = b.url(forResource: name, withExtension: "aep") else { throw XCTSkip("fixture \(name) missing") }
        return u
    }

    private func load(_ name: String) throws -> AEPImportResult { try AEPImporter.load(url: fixture(name)) }

    /// Diagnostic dump (visible in CI logs) used to verify the importer against real files.
    func testDumpAllFixtures() throws {
        let names = ["2_gaussian", "2_gaussian_20_30", "2_gaussian_animated", "2_gaussian_expr", "keyframe_LINEAR",
                     "keyframe_HOLD", "keyframe_bezier_ease_in_out_1D", "keyframe_bezier_ease_2D_position", "expression",
                     "effects", "solid_colors", "blendingMode", "layer_timing", "text_ink", "shape_source_rect", "size", "bgColor_custom"]
        for n in names {
            let r = try load(n)
            let p = r.project
            print("AEPDUMP \(n): comp=\(r.report.compName) \(p.width)x\(p.height) fps=\(p.fps) dur=\(p.duration) bg=\(p.background) comps=\(r.report.comps.count) layers=\(p.layers.count)")
            for l in p.layers.prefix(8) {
                let t = l.transform
                print("AEPDUMP   L '\(l.name)' \(l.content) in=\(l.inPoint) out=\(l.outPoint) size=\(l.size.staticValue) fill=\(l.fill.staticValue) blend=\(l.blendMode) pos=\(t.position.staticValue) posKF=\(t.position.keyframes.map { ($0.time, $0.value, $0.interpolation, $0.easeOut, $0.easeIn) }) scale=\(t.scale.staticValue) rot=\(t.rotation.staticValue) rotKF=\(t.rotation.keyframes.map { ($0.time, $0.value, $0.interpolation) }) op=\(t.opacity.staticValue) opKF=\(t.opacity.keyframes.map { ($0.time, $0.value, $0.interpolation, $0.easeOut, $0.easeIn) }) expr=\(t.position.expression ?? t.rotation.expression ?? t.opacity.expression ?? t.scale.expression ?? "-") text=\(l.text?.string ?? "-")")
                for e in l.effects { print("AEPDUMP     FX \(e.typeID) \(e.params.mapValues { "\($0)".prefix(80) })") }
            }
            for e in r.report.entries.prefix(12) { print("AEPDUMP   R \(e.status.rawValue) \(e.layer) / \(e.item) \(e.detail.prefix(50))") }
            print("AEPDUMP   usage \(r.report.effectUsage)")
        }
    }

    func testEveryFixtureImportsWithoutThrowing() throws {
        for n in ["2_gaussian", "keyframe_LINEAR", "effects", "solid_colors", "text_ink", "shape_source_rect", "layer_timing"] {
            let r = try load(n)
            XCTAssertGreaterThan(r.project.width, 0, n)
            XCTAssertGreaterThan(r.project.fps, 0, n)
            XCTAssertFalse(r.report.comps.isEmpty, n)
        }
    }

    func testImportedProjectRenders() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device") }
        let r = try load("2_gaussian")
        XCTAssertNotNil(renderer.renderPixels(project: r.project, time: 0, renderScale: 0.25, mediaURL: { URL(fileURLWithPath: $0) }))
    }

    // MARK: Verified against what each AE sample file contains

    func testGaussianBlurValuesImport() throws {
        let fx = try load("2_gaussian_20_30").project.layers[0].effects
        XCTAssertEqual(fx.map(\.typeID), ["ae.gaussianBlur", "ae.gaussianBlur"])
        XCTAssertEqual(fx.map { $0.number("blurriness", 0) }, [20, 30])
    }

    func testAnimatedEffectParamHasKeyframes() throws {
        let fx = try load("2_gaussian_animated").project.layers[0].effects
        let animated = fx.contains { e in if case .number(let a)? = e.params["blurriness"] { return a.isAnimated }; return false }
        XCTAssertTrue(animated, "Gaussian blurriness keyframes did not import")
    }

    func testCompSettingsImport() throws {
        let p = try load("2_gaussian").project
        XCTAssertEqual(p.width, 1920); XCTAssertEqual(p.height, 1080)
        XCTAssertEqual(p.fps, 24, accuracy: 0.001)
        XCTAssertEqual(p.duration, 30, accuracy: 0.001)
    }

    func testSolidColorImports() throws {
        let l = try load("solid_colors").project.layers[0]
        let c = l.fill.staticValue
        XCTAssertGreaterThan(c.b, 0.9, "solid_color_blue should be blue, got \(c)")
        XCTAssertLessThan(c.r, 0.1)
        XCTAssertEqual(c.a, 1, accuracy: 0.01)
    }

    func testBlendModeImports() throws {
        XCTAssertEqual(try load("blendingMode").project.layers[0].blendMode, .add)
    }

    func testLayerStartTimeImports() throws {
        XCTAssertEqual(try load("layer_timing").project.layers[0].inPoint, 5, accuracy: 0.001)
    }

    func testOpacityIsPercent() throws {
        let l = try load("2_gaussian").project.layers[0]
        XCTAssertEqual(l.transform.opacity.staticValue, 100, accuracy: 0.01)
        XCTAssertEqual(l.transform.scale.staticValue, Vec2(100, 100))
    }

    func testHoldAndLinearInterpolation() throws {
        let hold = try load("keyframe_HOLD").project.layers[0].transform.opacity
        XCTAssertTrue(hold.isAnimated)
        XCTAssertTrue(hold.keyframes.contains { $0.interpolation == .hold }, "no hold keyframe: \(hold.keyframes.map(\.interpolation))")
        let lin = try load("keyframe_LINEAR").project.layers[0].transform.position
        XCTAssertGreaterThanOrEqual(lin.keyframes.count, 2)
        XCTAssertEqual(lin.keyframes.first?.interpolation, .linear)
    }

    func testBezierEaseImportsAsEase() throws {
        let op = try load("keyframe_bezier_ease_in_out_1D").project.layers[0].transform.opacity
        XCTAssertEqual(op.keyframes.first?.interpolation, .bezier)
        // Ease in/out: slow at the start of the segment.
        let k0 = op.keyframes[0], k1 = op.keyframes[1]
        let early = op.value(at: k0.time + (k1.time - k0.time) * 0.1)
        let linearEarly = k0.value + (k1.value - k0.value) * 0.1
        XCTAssertLessThan(abs(early - k0.value), abs(linearEarly - k0.value))
    }

    func testExpressionImports() throws {
        XCTAssertEqual(try load("expression").project.layers[0].transform.opacity.expression, "50")
    }

    func testTextImportsStringNotFontName() throws {
        let layers = try load("text_ink").project.layers
        let hello = try XCTUnwrap(layers.first { $0.name == "ArialMT_Hello" })
        XCTAssertEqual(hello.text?.string, "Hello")
    }

    func testRejectsNonAEP() {
        XCTAssertThrowsError(try AEPImporter.importData(Data("hello world, not a project".utf8)))
    }
}
