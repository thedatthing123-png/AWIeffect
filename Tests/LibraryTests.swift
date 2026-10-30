import XCTest
@testable import AWIeffect

final class LibraryTests: XCTestCase {
    private func layerProject() -> Project {
        var p = Project.new(name: "lib", width: 160, height: 160, fps: 30, duration: 3, background: RGBA(0.1, 0.1, 0.15))
        var l = p.makeLayer(name: "star", content: .shape(.star), size: Vec2(90, 90))
        l.fill = Animated(RGBA(1, 0.9, 0.6))
        l.inPoint = 0.5; l.outPoint = 2.5
        p.layers = [l]
        return p
    }

    private func render(_ p: Project, _ t: Double) throws -> [UInt8] {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device") }
        return try XCTUnwrap(r.renderPixels(project: p, time: t, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }

    private func diff(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(a.count)
    }

    /// Every preset must change how the layer renders at the moment it targets.
    func testEveryPresetDoesSomething() throws {
        let base = layerProject()
        for preset in PresetLibrary.all {
            var p = base
            let t: Double
            switch preset.kind {
            case .transitionIn: t = 0.55
            case .transitionOut: t = 2.45
            default: t = 1.2
            }
            let anchor = preset.kind == .transitionIn ? 0.5 : (preset.kind == .transitionOut ? 2.5 : 1.2)
            preset.apply(&p.layers[0], p, anchor)
            XCTAssertGreaterThan(diff(try render(base, t), try render(p, t)), 0.3, "\(preset.name) did nothing")
        }
    }

    func testTransitionsSettleBackToTheLayer() throws {
        let base = layerProject()
        for preset in PresetLibrary.all where preset.kind == .transitionIn {
            var p = base
            preset.apply(&p.layers[0], p, 0.5)
            XCTAssertLessThan(diff(try render(base, 1.5), try render(p, 1.5)), 0.5, "\(preset.name) doesn't end on the original layer")
        }
    }

    func testOverlaysAreNotBlank() {
        for k in OverlayKind.allCases {
            let img = OverlayLibrary.render(k, width: 96, height: 64, seed: 3)
            guard let cg = img.cgImage, let data = cg.dataProvider?.data as Data? else { return XCTFail("no image for \(k)") }
            let bytes = [UInt8](data)
            let lo = bytes.min() ?? 0, hi = bytes.max() ?? 0
            XCTAssertGreaterThan(Int(hi) - Int(lo), 20, "\(k.title) is flat")
        }
    }

    func testOverlayIsDeterministicPerSeed() {
        let a = OverlayLibrary.render(.bokeh, width: 64, height: 64, seed: 9).pngData()
        let b = OverlayLibrary.render(.bokeh, width: 64, height: 64, seed: 9).pngData()
        XCTAssertEqual(a, b)
    }

    func testGoogleFontsCSSParsing() {
        let css = """
        @font-face { font-family: 'Bebas Neue'; src: url(https://fonts.gstatic.com/s/bebasneue/v14/abc.ttf) format('truetype'); }
        @font-face { font-family: 'Bebas Neue'; font-weight: 700; src: url('https://fonts.gstatic.com/s/bebasneue/v14/def.ttf') format('truetype'); }
        """
        let urls = FontLibrary.fontURLs(inCSS: css)
        XCTAssertEqual(urls.map(\.lastPathComponent), ["abc.ttf", "def.ttf"])
    }

    @MainActor
    func testKeyAllTransform() {
        var p = layerProject()
        p.layers[0].inPoint = 0
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.select(p.layers[0].id)
        s.currentTime = 1
        s.keyAllTransform()
        let t = s.project.layers[0].transform
        XCTAssertTrue(t.position.hasKeyframe(at: 1) && t.scale.hasKeyframe(at: 1) && t.rotation.hasKeyframe(at: 1) && t.opacity.hasKeyframe(at: 1))
    }
}
