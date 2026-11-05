import XCTest
import simd
@testable import AWIeffect

final class ArtStudioRenewTests: XCTestCase {
    private func engine() throws -> DrawEngine { try XCTUnwrap(DrawEngine(width: 96, height: 96)) }
    private func px(_ e: DrawEngine, _ x: Int, _ y: Int) -> [UInt8] {
        let b = e.bytes(of: e.activeLayer!), i = (y * 96 + x) * 4
        return Array(b[i..<(i + 4)])
    }
    private func paint(_ e: DrawEngine, y: Double = 48) {
        e.beginStroke(at: SIMD2(10, y), pressure: 1)
        for x in stride(from: 12.0, through: 86, by: 2) { e.continueStroke(to: SIMD2(x, y), pressure: 1) }
        e.endStroke()
    }

    func testOneStrokeNeverBuildsPastItsOpacity() throws {
        let e = try engine()
        e.brush.size = 20; e.brush.opacity = 0.5; e.brush.hardness = 0.9; e.brush.color = RGBA(1, 0, 0)
        e.beginStroke(at: SIMD2(10, 48), pressure: 1)
        // Scrubbing back and forth over the same spot.
        for i in 0..<60 { e.continueStroke(to: SIMD2(i % 2 == 0 ? 30 : 60, 48), pressure: 1) }
        e.endStroke()
        let a = Int(px(e, 45, 48)[3])
        XCTAssertTrue((120...135).contains(a), "alpha \(a)")
        // A second stroke builds on the first.
        paint(e)
        XCTAssertGreaterThan(Int(px(e, 45, 48)[3]), 170)
    }

    func testStabilizedStrokeReachesWhereItWasLifted() throws {
        let e = try engine()
        e.brush.size = 6; e.brush.stabilizer = 1
        e.beginStroke(at: SIMD2(10, 48), pressure: 1)
        e.continueStroke(to: SIMD2(80, 48), pressure: 1)
        e.endStroke()
        XCTAssertGreaterThan(px(e, 79, 48)[3], 150)
    }

    func testEndTaperExtendsAndThins() throws {
        let e = try engine()
        e.brush.size = 16; e.brush.stabilizer = 0; e.brush.taperEnd = 20
        e.beginStroke(at: SIMD2(10, 48), pressure: 1)
        for x in stride(from: 12.0, through: 60, by: 2) { e.continueStroke(to: SIMD2(x, 48), pressure: 1) }
        e.endStroke()
        XCTAssertGreaterThan(px(e, 66, 48)[3], 100, "the tail continues past the lift point")
        XCTAssertEqual(px(e, 74, 54)[3], 0, "and it is narrower than the line")
    }

    func testEraserStrokeRespectsSelectionAndAlphaLockKeepsCoverage() throws {
        let e = try engine()
        e.brush.size = 30; e.brush.color = RGBA(0, 1, 0)
        paint(e)
        e.selectShape(SIMD2(0, 0), SIMD2(48, 96), ellipse: false)
        e.erasing = true
        paint(e)
        e.erasing = false
        XCTAssertLessThan(px(e, 20, 48)[3], 10)
        XCTAssertGreaterThan(px(e, 70, 48)[3], 200)
        e.clearSelection()
        e.activeLayer?.alphaLock = true
        e.brush.color = RGBA(0, 0, 1)
        paint(e)
        XCTAssertLessThan(px(e, 20, 48)[3], 10, "alpha lock adds no coverage")
        let kept = px(e, 70, 48)
        XCTAssertGreaterThan(kept[2], 200); XCTAssertLessThan(kept[1], 40)
    }

    func testSmudgePullsColorAndBlurSoftens() throws {
        let e = try engine()
        e.brush.size = 20; e.brush.hardness = 0.95; e.brush.pressureSize = false; e.brush.stabilizer = 0
        e.brush.color = RGBA(1, 1, 1)
        e.beginStroke(at: SIMD2(30, 48), pressure: 1); e.endStroke()
        XCTAssertEqual(px(e, 60, 48)[3], 0)
        e.strokeMode = .smudge
        e.brush.size = 30; e.brush.opacity = 1
        e.beginStroke(at: SIMD2(30, 48), pressure: 1)
        for x in stride(from: 32.0, through: 70, by: 2) { e.continueStroke(to: SIMD2(x, 48), pressure: 1) }
        e.endStroke()
        XCTAssertGreaterThan(px(e, 50, 48)[3], 20, "paint is dragged along the stroke")

        let f = try engine()
        f.brush.size = 40; f.brush.hardness = 0.99; f.brush.pressureSize = false
        f.beginStroke(at: SIMD2(48, 48), pressure: 1); f.endStroke()
        let edgeBefore = px(f, 48, 70)[3]
        f.strokeMode = .blur
        f.brush.size = 50; f.brush.opacity = 1
        for _ in 0..<4 { f.beginStroke(at: SIMD2(48, 68), pressure: 1); f.endStroke() }
        XCTAssertGreaterThan(px(f, 48, 70)[3], edgeBefore, "the hard edge spreads out")
    }

    func testTransformIsLiveCancelsAndCommitsWithOneUndo() throws {
        let e = try engine()
        e.brush.size = 12; e.brush.hardness = 0.95; e.brush.pressureSize = false
        e.beginStroke(at: SIMD2(30, 30), pressure: 1); e.endStroke()
        XCTAssertGreaterThan(px(e, 30, 30)[3], 200)
        XCTAssertTrue(e.beginFloating())
        e.floating?.translate = SIMD2(30, 30)
        e.updateFloating()
        XCTAssertLessThan(px(e, 30, 30)[3], 10); XCTAssertGreaterThan(px(e, 60, 60)[3], 200)
        e.cancelFloating()
        XCTAssertGreaterThan(px(e, 30, 30)[3], 200); XCTAssertEqual(px(e, 60, 60)[3], 0)

        e.beginFloating()
        e.floating?.translate = SIMD2(30, 30); e.floating?.scale = SIMD2(2, 2)
        e.commitFloating()
        XCTAssertFalse(e.isFloating)
        XCTAssertGreaterThan(px(e, 68, 60)[3], 200, "scaled to twice the width")
        e.undo()
        XCTAssertGreaterThan(px(e, 30, 30)[3], 200); XCTAssertEqual(px(e, 60, 60)[3], 0)
    }

    func testTransformMovesTheSelectionMaskAlong() throws {
        let e = try engine()
        e.brush.size = 12; e.brush.hardness = 0.95; e.brush.pressureSize = false
        e.beginStroke(at: SIMD2(20, 20), pressure: 1); e.endStroke()
        e.beginStroke(at: SIMD2(70, 70), pressure: 1); e.endStroke()
        e.selectShape(SIMD2(5, 5), SIMD2(40, 40), ellipse: false)
        e.beginFloating()
        e.floating?.translate = SIMD2(0, 40)
        e.commitFloating()
        XCTAssertGreaterThan(px(e, 20, 60)[3], 200)
        XCTAssertGreaterThan(px(e, 70, 70)[3], 200, "unselected pixels stay")
        XCTAssertLessThan(px(e, 20, 20)[3], 10)
        // Painting is now limited to the moved selection.
        e.brush.size = 96; e.brush.color = RGBA(1, 0, 0)
        e.beginStroke(at: SIMD2(48, 48), pressure: 1); e.endStroke()
        XCTAssertGreaterThan(px(e, 10, 60)[3], 200)
        XCTAssertEqual(px(e, 90, 10)[3], 0)
    }

    func testShapeToolDrawsOutlineOrFill() throws {
        let e = try engine()
        e.brush.size = 4; e.brush.hardness = 0.95; e.brush.pressureSize = false
        let square: [SIMD2<Double>] = [SIMD2(20, 20), SIMD2(70, 20), SIMD2(70, 70), SIMD2(20, 70), SIMD2(20, 20)]
        e.drawShape(square, filled: false)
        XCTAssertGreaterThan(px(e, 45, 20)[3], 150); XCTAssertEqual(px(e, 45, 45)[3], 0)
        e.undo()
        e.drawShape(square, filled: true)
        XCTAssertGreaterThan(px(e, 45, 45)[3], 200)
    }

    @MainActor func testEveryBrushPresetPaintsItsPreview() throws {
        XCTAssertEqual(Set(BrushPreset.all.map(\.id)).count, BrushPreset.all.count)
        for preset in BrushPreset.all {
            XCTAssertTrue(BrushPreset.groups.contains(preset.group))
            let e = try engine()
            e.brush = preset.brush
            e.brush.size = min(preset.brush.size, 40)
            paint(e)
            let pixels = e.bytes(of: e.activeLayer!)
            let touched = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
            XCTAssertTrue(touched, preset.name)
            XCTAssertNotNil(BrushPreset.preview(preset), preset.name)
        }
    }
}
