import XCTest
import Metal
@testable import AWIeffect

final class CutoutStudioTests: XCTestCase {
    private func tempFile() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    func testMatteFileRoundTrips() throws {
        var m = MatteFrame.filled(40, 30, 0)
        m.bytes[5] = 200
        let url = tempFile()
        try CutoutBake.save(m, to: url)
        XCTAssertEqual(CutoutBake.load(url), m)
        XCTAssertNil(CutoutBake.load(tempFile()))
    }

    func testKeepAndCutOnlyChangeTheSelection() {
        var m = MatteFrame(width: 2, height: 2, bytes: [255, 255, 0, 0])
        m.apply(selection: [255, 0, 255, 0], keep: false)
        XCTAssertEqual(m.bytes, [0, 255, 0, 0])
        m.apply(selection: [0, 0, 255, 0], keep: true)
        XCTAssertEqual(m.bytes, [0, 255, 255, 0])
    }

    func testIsolateRemovesLeftoverBackground() {
        var m = MatteFrame.filled(40, 40, 0)
        // The subject in the middle, a loose island inside the box, another outside it.
        for y in 14..<26 { for x in 14..<26 { m.bytes[y * 40 + x] = 255 } }
        for y in 5..<8 { for x in 5..<8 { m.bytes[y * 40 + x] = 255 } }
        for y in 34..<38 { for x in 34..<38 { m.bytes[y * 40 + x] = 255 } }
        CutoutBake.isolate(&m, box: CGRect(x: 0.1, y: 0.1, width: 0.6, height: 0.6))
        XCTAssertEqual(m.bytes[20 * 40 + 20], 255, "the subject stays")
        XCTAssertEqual(m.bytes[6 * 40 + 6], 0, "the island goes")
        XCTAssertEqual(m.bytes[36 * 40 + 36], 0, "outside the box goes")
    }

    func testMedianDropsOneFrameFlickerButKeepsSteadyPixels() {
        let a = MatteFrame(width: 2, height: 1, bytes: [0, 255])
        let b = MatteFrame(width: 2, height: 1, bytes: [255, 255])
        let c = MatteFrame(width: 2, height: 1, bytes: [0, 255])
        XCTAssertEqual(CutoutBake.median(a, b, c).bytes, [0, 255])
    }

    func testHeldAnimeFrameIsRecognized() {
        let a = [UInt8](repeating: 100, count: 64 * 64)
        var near = a; near[3] = 104
        XCTAssertTrue(CutoutBake.isHeldFrame(a, near))
        XCTAssertFalse(CutoutBake.isHeldFrame(a, [UInt8](repeating: 130, count: 64 * 64)))
    }

    func testBakedFrameReplacesTheAIAndOtherFramesStayIndependent() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("no Metal") }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var p = Project.new(name: "c", width: 64, height: 64, fps: 30, duration: 1, background: .black)
        var l = p.makeLayer(name: "v", content: .video(fileName: "none.mov", pixelWidth: 64, pixelHeight: 64, hasAudio: false), size: Vec2(64, 64))
        var s = CutoutSettings(mode: .drawn)
        s.bakeID = "test"; s.bakeRate = 30; s.bakeRevision = 1
        l.cutout = s
        p.layers = [l]
        let url: (String) -> URL = { folder.appendingPathComponent($0) }
        try CutoutBake.save(MatteFrame.filled(8, 8, 200), to: url(CutoutBake.fileName("test", frame: 3)))
        let tex = try XCTUnwrap(CutoutEngine.shared.matte(for: l, sourceTime: 3.5 / 30, mediaURL: url, device: device))
        var px = [UInt8](repeating: 0, count: 64)
        tex.getBytes(&px, bytesPerRow: 8, from: MTLRegionMake2D(0, 0, 8, 8), mipmapLevel: 0)
        XCTAssertEqual(px[10], 200)
        // A frame with nothing stored falls back to the live path, here with no file to read.
        XCTAssertNil(CutoutEngine.shared.matte(for: l, sourceTime: 9.5 / 30, mediaURL: url, device: device))
        // Editing that frame shows up: the revision changes the cache key.
        try CutoutBake.save(MatteFrame.filled(8, 8, 50), to: url(CutoutBake.fileName("test", frame: 3)))
        l.cutout?.bakeRevision = 2
        let edited = try XCTUnwrap(CutoutEngine.shared.matte(for: l, sourceTime: 3.5 / 30, mediaURL: url, device: device))
        edited.getBytes(&px, bytesPerRow: 8, from: MTLRegionMake2D(0, 0, 8, 8), mipmapLevel: 0)
        XCTAssertEqual(px[10], 50)
    }

    func testOldProjectSettingsStillDecode() throws {
        let old = #"{"mode":"object","choke":0,"feather":1,"invert":false}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(CutoutSettings.self, from: old)
        XCTAssertNil(s.bakeID); XCTAssertEqual(s.manualFrames, [])
    }
}
