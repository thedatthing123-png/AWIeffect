import XCTest
import Metal
@testable import AWIeffect

@MainActor final class InlineToolsTests: XCTestCase {
    private func editor() -> EditorState {
        var p = Project.new(name: "inline", width: 100, height: 100, fps: 30, duration: 10)
        p.layers = [p.makeLayer(name: "Picture", content: .image(fileName: "missing.png", pixelWidth: 100, pixelHeight: 100), size: Vec2(100,100))]
        let state = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        state.select(p.layers[0].id); return state
    }
    func testOpeningAndLeavingCutoutDoesNotApplyAnything() {
        let s = editor(), before = s.project
        let model = CutoutStudioModel(state: s, layer: s.project.layers[0], url: s.mediaURL("missing.png"))
        model.finish()
        XCTAssertEqual(s.project, before); XCTAssertFalse(s.canUndo)
        XCTAssertNil(s.cutoutPreview); XCTAssertNil(s.cutoutPeekOriginal)
    }
    func testMatteOverridesKeepOlderNamespacesIntactAcrossUndo() throws {
        guard let gpu = Renderer.shared?.device else { throw XCTSkip("no Metal") }
        let s = editor()
        let folder = s.mediaURL("base").deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try CutoutBake.save(.filled(8, 8, 200), to: s.mediaURL(CutoutBake.fileName("base", frame: 0)))
        try CutoutBake.save(.filled(8, 8, 40), to: s.mediaURL(CutoutBake.fileName("edit", frame: 0)))
        var c = CutoutSettings(); c.bakeID = "base"
        s.project.layers[0].cutout = c
        var edited = c; edited.bakeOverrides = ["0":"edit"]
        s.setCutout(edited)
        func value() throws -> UInt8 {
            let texture = try XCTUnwrap(CutoutEngine.shared.matte(for: s.project.layers[0], sourceTime: 0, mediaURL: { s.mediaURL($0) }, device: gpu))
            var bytes = [UInt8](repeating: 0, count: 64)
            texture.getBytes(&bytes, bytesPerRow: 8, from: MTLRegionMake2D(0,0,8,8), mipmapLevel: 0)
            return bytes[0]
        }
        XCTAssertEqual(try value(), 40)
        s.undo(); XCTAssertEqual(try value(), 200)
        XCTAssertEqual(CutoutBake.load(s.mediaURL(CutoutBake.fileName("base", frame: 0)))?.bytes[0], 200)
    }
    func testInlineRemapHasNoFiveKeyLimitAndSharesSpeedSlopes() {
        let s = editor()
        s.project.layers[0].content = .video(fileName: "missing.mov", pixelWidth: 100, pixelHeight: 100, hasAudio: false)
        for second in 1...7 { s.currentTime = Double(second); s.addSourceTimeKey() }
        XCTAssertEqual(s.selectedLayer?.timeRemap?.keyframes.count, 9)
        s.currentTime = 3
        s.beginScrub(); s.setSourceKeyRate(2); s.setSourceKeyRate(0.5); s.endScrub()
        XCTAssertEqual(s.selectedLayer?.timeRemap?.keyframes.count, 9)
        XCTAssertEqual(s.selectedLayer!.playbackRate(at: 3), 0.5, accuracy: 0.01)
        let original = s.selectedLayer!.timeRemap!.keyframes.first { abs($0.time - 3) < 0.001 }!
        let a = s.selectedLayer!.timeRemap!
        XCTAssertEqual(a.keyframes.first?.value, 0)
        XCTAssertEqual(a.keyframes.last?.value, 10)
        XCTAssertEqual(original.time, 3)
    }

    func testHeavyPropertyLanesCacheDoesNotRebuildOnPlayheadChanges() {
        let s = editor()
        for effect in 0..<6 {
            var e = EffectInstance(typeID: "test.effect", params: [:])
            for property in 0..<5 {
                var a = Animated(0.0)
                for key in 0..<12 { a.insertKeyframe(Keyframe(time: Double(key) / 2, value: Double(key + effect))) }
                e.params["p\(property)"] = .number(a)
            }
            s.project.layers[0].effects.append(e)
        }
        let l = s.project.layers[0]
        let cold = Date.timeIntervalSinceReferenceDate
        let lanes = s.propertyLaneCache.lanes(l)
        XCTAssertEqual(lanes.count, 30)
        XCTAssertLessThan(Date.timeIntervalSinceReferenceDate - cold, 0.1, "Cold build must not stall the editor")
        let start = Date.timeIntervalSinceReferenceDate
        for frame in 0..<2000 {
            s.currentTime = Double(frame % 300) / 30
            XCTAssertEqual(s.propertyLaneCache.lanes(l).count, 30)
        }
        XCTAssertEqual(s.propertyLaneCache.builds, 1, "Time changes must not rebuild lane metadata")
        XCTAssertLessThan(Date.timeIntervalSinceReferenceDate - start, 0.5, "Cached lookup must stay far below a 16.7ms frame budget")
        s.project.layers[0].effects[0].params["p0"] = .number(Animated(2))
        XCTAssertEqual(s.propertyLaneCache.lanes(s.project.layers[0]).count, 29)
        XCTAssertEqual(s.propertyLaneCache.builds, 2)
    }
}
