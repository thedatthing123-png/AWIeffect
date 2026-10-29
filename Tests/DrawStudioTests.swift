import XCTest
import simd
@testable import AWIeffect

final class DrawStudioTests: XCTestCase {
    private func engine(_ w: Int = 64, _ h: Int = 64) throws -> DrawEngine {
        guard let e = DrawEngine(width: w, height: h) else { throw XCTSkip("SKIP-GPU: no Metal device") }
        return e
    }
    private func alpha(_ e: DrawEngine, _ x: Int, _ y: Int) -> UInt8 { e.bytes(of: e.activeLayer!)[(y * e.width + x) * 4 + 3] }
    private func wait(_ e: DrawEngine) { let cb = e.queue.makeCommandBuffer()!; cb.commit(); cb.waitUntilCompleted() }

    func testBrushStrokePaints() throws {
        let e = try engine()
        e.brush.size = 6; e.brush.color = RGBA(1, 0, 0)
        e.beginStroke(at: SIMD2(10, 32), pressure: 1)
        for x in stride(from: 10.0, through: 54, by: 2) { e.continueStroke(to: SIMD2(x, 32), pressure: 1) }
        e.endStroke(); wait(e)
        XCTAssertGreaterThan(alpha(e, 30, 32), 200)
        XCTAssertEqual(alpha(e, 30, 5), 0)
    }

    func testEraserAndUndo() throws {
        let e = try engine()
        e.brush.size = 20
        e.beginStroke(at: SIMD2(32, 32), pressure: 1); e.endStroke(); wait(e)
        XCTAssertGreaterThan(alpha(e, 32, 32), 200)
        e.brush.kind = .eraser
        e.beginStroke(at: SIMD2(32, 32), pressure: 1); e.endStroke(); wait(e)
        XCTAssertLessThan(alpha(e, 32, 32), 20)
        e.undo()
        XCTAssertGreaterThan(alpha(e, 32, 32), 200)
    }

    func testSelectionLimitsPaintingAndCutPaste() throws {
        let e = try engine()
        e.selectLasso([SIMD2(0, 0), SIMD2(32, 0), SIMD2(32, 64), SIMD2(0, 64)])
        e.brush.size = 80
        e.beginStroke(at: SIMD2(32, 32), pressure: 1); e.endStroke(); wait(e)
        XCTAssertGreaterThan(alpha(e, 10, 32), 200)
        XCTAssertEqual(alpha(e, 50, 32), 0, "painted outside the selection")
        e.cutSelection()
        XCTAssertEqual(alpha(e, 10, 32), 0)
        e.paste()
        XCTAssertEqual(e.layers.count, 2)
        XCTAssertGreaterThan(alpha(e, 10, 32), 200)
    }

    func testBucketFillStopsAtLines() throws {
        let e = try engine()
        e.brush.size = 3; e.brush.hardness = 0.99
        // Vertical wall at x = 32.
        e.beginStroke(at: SIMD2(32, 0), pressure: 1)
        for y in stride(from: 0.0, through: 64, by: 1) { e.continueStroke(to: SIMD2(32, y), pressure: 1) }
        e.endStroke(); wait(e)
        e.brush.color = RGBA(0, 0, 1)
        e.fill(at: SIMD2(10, 10), tolerance: 0.1)
        XCTAssertGreaterThan(alpha(e, 10, 50), 200)
        XCTAssertEqual(alpha(e, 55, 10), 0, "fill leaked past the line")
    }

    func testClippingLayerOnlyShowsOverBase() throws {
        let e = try engine()
        e.brush.size = 20
        e.beginStroke(at: SIMD2(16, 16), pressure: 1); e.endStroke()
        let top = e.addLayer(name: "clip")!
        top.clipping = true
        e.brush.color = RGBA(0, 1, 0); e.brush.size = 200
        e.beginStroke(at: SIMD2(32, 32), pressure: 1); e.endStroke(); wait(e)
        let cb = e.queue.makeCommandBuffer()!; e.encodeComposite(cb); cb.commit(); cb.waitUntilCompleted()
        var px = [UInt8](repeating: 0, count: 64 * 64 * 4)
        e.canvas.getBytes(&px, bytesPerRow: 64 * 4, from: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0)
        XCTAssertGreaterThan(px[(16 * 64 + 16) * 4 + 1], 200, "clip layer missing over base")
        XCTAssertEqual(px[(50 * 64 + 50) * 4 + 3], 0, "clip layer leaked outside base")
    }

    func testSaveLoadRoundTripAndFlatten() throws {
        let e = try engine()
        e.brush.size = 10
        e.beginStroke(at: SIMD2(20, 20), pressure: 1); e.endStroke(); wait(e)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let id = UUID()
        _ = try e.save(doc: id, folder: dir)
        let back = try XCTUnwrap(DrawEngine.load(doc: id, folder: dir))
        XCTAssertGreaterThan(back.bytes(of: back.activeLayer!)[(20 * 64 + 20) * 4 + 3], 200)
        XCTAssertNotNil(e.flattenedPNG())
    }

    func testFloodMaskGapClose() {
        // 10x10 white ring with a 1px gap; gap closing keeps the inside separate.
        let w = 10, h = 10
        var px = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<10 {
            for (x, y) in [(i, 0), (i, 9), (0, i), (9, i)] where !(x == 9 && y == 5) {
                let o = (y * w + x) * 4; px[o] = 255; px[o + 1] = 255; px[o + 2] = 255; px[o + 3] = 255
            }
        }
        let leaky = DrawEngine.floodMask(px, w, h, 4, 4, 0.1)
        let closed = DrawEngine.floodMask(px, w, h, 4, 4, 0.1, gapClose: 1)
        XCTAssertEqual(leaky[0], 0) // corner is a wall pixel
        XCTAssertGreaterThan(leaky.filter { $0 > 0 }.count, closed.filter { $0 > 0 }.count - 1)
    }
}
