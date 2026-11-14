import XCTest
import simd
import CoreVideo
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
        XCTAssertGreaterThan(px(e, 70, 48)[3], 200, "painted before selecting")
        e.selectShape(SIMD2(0, 0), SIMD2(48, 96), ellipse: false)
        let mask = e.selectionBytes()
        XCTAssertEqual(mask[48 * 96 + 70], 0, "outside the selection"); XCTAssertEqual(mask[48 * 96 + 20], 255)
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

    func testSelectingRightAfterAStrokeKeepsTheStroke() throws {
        let e = try engine()
        e.brush.size = 12; e.brush.hardness = 0.95; e.brush.pressureSize = false
        e.beginStroke(at: SIMD2(70, 70), pressure: 1); e.endStroke()
        // No read-back in between: the selection changes while the stroke may still be on the GPU.
        e.selectShape(SIMD2(5, 5), SIMD2(40, 40), ellipse: false)
        XCTAssertGreaterThan(px(e, 70, 70)[3], 200)
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
        XCTAssertGreaterThan(px(e, 68, 48)[3], 60, "at full strength the paint travels to the end of the stroke")

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
        XCTAssertGreaterThan(px(e, 70, 70)[3], 200, "second tap painted")
        XCTAssertGreaterThan(px(e, 20, 20)[3], 200, "first tap kept")
        e.selectShape(SIMD2(5, 5), SIMD2(40, 40), ellipse: false)
        XCTAssertEqual(e.selectionBytes()[70 * 96 + 70], 0, "outside the selection")
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

    func testAIAssistanceRetainsExplicitPaintAndExistingSelection() {
        let mask = DrawEngine.assistedSelection([0, 255, 12, 0], previous: [255, 0, 0, 0], painted: [0, 0, 255, 180])
        XCTAssertEqual(mask, [255, 255, 255, 180], "AI must retain ink and fingertips painted outside its subject estimate")
    }

    func testQuickSelectStaysInsideItsPartAndReach() throws {
        let e = try engine()
        let l = try XCTUnwrap(e.activeLayer)
        var b = [UInt8](repeating: 0, count: 96 * 96 * 4)
        // A white field split by a black line at x = 40.
        for y in 0..<96 { for x in 0..<96 {
            let v: UInt8 = x == 40 ? 0 : 255
            b[(y * 96 + x) * 4] = v; b[(y * 96 + x) * 4 + 1] = v; b[(y * 96 + x) * 4 + 2] = v; b[(y * 96 + x) * 4 + 3] = 255
        } }
        e.setBytes(b, of: l)
        e.beginQuickSelect(at: SIMD2(60, 48), subtract: false, reach: 24)
        e.endQuickSelect()
        let m = e.selectionBytes()
        XCTAssertGreaterThan(m[48 * 96 + 70], 200); XCTAssertLessThan(m[48 * 96 + 30], 30, "stops at the line")
        XCTAssertLessThan(m[5 * 96 + 60], 30, "stops at its reach")
    }

    func testAIBrushGrowsToPartWithoutDiscardingExplicitPaint() throws {
        let e = try engine()
        let l = try XCTUnwrap(e.activeLayer)
        var b = [UInt8](repeating: 255, count: 96 * 96 * 4)
        // A red square on white.
        for y in 30..<60 { for x in 30..<60 { b[(y * 96 + x) * 4 + 1] = 0; b[(y * 96 + x) * 4 + 2] = 0 } }
        e.setBytes(b, of: l)
        e.beginSelectStroke(at: SIMD2(45, 45), radius: 20, subtract: false)
        e.endSelectStroke(snapToSubject: false, snapToEdges: true)
        let m = e.selectionBytes()
        XCTAssertGreaterThan(m[35 * 96 + 35], 200, "fills to the edge of the part")
        XCTAssertGreaterThan(m[45 * 96 + 62], 200, "explicitly brushed ink/edges must remain selected")
        XCTAssertEqual(m[10 * 96 + 10], 0, "unpainted background stays unselected")
        e.undo()
        XCTAssertFalse(e.hasSelection)
    }

    func testVisionSelectionRasterKeepsTopAndBottomInPlace() throws {
        var optional: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 32, 32, kCVPixelFormatType_OneComponent8, nil, &optional), kCVReturnSuccess)
        let buffer = try XCTUnwrap(optional)
        CVPixelBufferLockBaseAddress(buffer, [])
        let bytes = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self))
        let row = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<32 { for x in 0..<32 { bytes[y * row + x] = y < 8 && x < 12 ? 255 : 0 } }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let mask = DrawEngine.rasterSelectionMask(buffer, width: 32, height: 32)
        XCTAssertGreaterThan(mask[3 * 32 + 3], 240, "top-left subject stays at the top")
        XCTAssertLessThan(mask[28 * 32 + 3], 15, "no vertically mirrored selection")
    }

    func testQuickBrushSweepsAcrossThinInkWithoutLeavingFragments() throws {
        let e = try engine()
        var b = [UInt8](repeating: 255, count: 96 * 96 * 4)
        for y in 20..<80 { for x in 44..<47 {
            let i = (y * 96 + x) * 4
            b[i] = 0; b[i + 1] = 0; b[i + 2] = 0
        } }
        e.setBytes(b, of: try XCTUnwrap(e.activeLayer))
        e.beginQuickSelect(at: SIMD2(35, 48), subtract: false, reach: 24, radius: 5)
        for x in stride(from: 35.5, through: 55, by: 0.5) { e.continueQuickSelect(to: SIMD2(x, 48)) }
        e.endQuickSelect()
        XCTAssertGreaterThan(e.selectionBytes()[48 * 96 + 45], 240, "slow strokes cover the black outline")
        e.beginQuickSelect(at: SIMD2(35, 48), subtract: true, reach: 24, radius: 5)
        e.continueQuickSelect(to: SIMD2(55, 48)); e.endQuickSelect()
        XCTAssertLessThan(e.selectionBytes()[48 * 96 + 45], 15, "Cut must clear the same outline")
    }

    func testPenPathCurvesAndClosesAndApplies() throws {
        var path = PenPath()
        path.anchors = [PenAnchor(point: SIMD2(20, 60)), PenAnchor(point: SIMD2(70, 60), handle: SIMD2(0, -30))]
        let curve = path.flattened()
        XCTAssertGreaterThan(curve.map(\.y).max()!, 65, "the handle bends the line")
        XCTAssertEqual(curve.last!, SIMD2(70, 60))
        path.anchors.append(PenAnchor(point: SIMD2(45, 20)))
        path.closed = true
        XCTAssertEqual(path.flattened().last!, SIMD2(20, 60))
        let e = try engine()
        e.brush.hardness = 0.95
        e.applyPath(path, filled: true)
        XCTAssertGreaterThan(px(e, 45, 50)[3], 200)
        e.undo()
        e.selectPath(path)
        XCTAssertGreaterThan(e.selectionBytes()[50 * 96 + 45], 200)
        XCTAssertEqual(e.selectionBytes()[5 * 96 + 5], 0)
    }

    func testLiveFilterPreviewsCancelsAndCommitsWithOneUndo() throws {
        let e = try engine()
        e.brush.size = 40; e.brush.hardness = 0.95; e.brush.color = RGBA(1, 0, 0)
        e.beginStroke(at: SIMD2(48, 48), pressure: 1); e.endStroke()
        let before = px(e, 48, 48)
        var f = DrawFilter(); f.saturation = 0
        e.beginFilter()
        e.updateFilter(f)
        let shown = expectation(description: "preview")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { shown.fulfill() }
        wait(for: [shown], timeout: 5)
        XCTAssertGreaterThan(px(e, 48, 48)[1], 40, "gray now, while the slider is live")
        e.cancelFilter()
        XCTAssertEqual(px(e, 48, 48), before)
        e.beginFilter(); e.commitFilter(f)
        XCTAssertGreaterThan(px(e, 48, 48)[1], 40)
        e.undo()
        XCTAssertEqual(px(e, 48, 48), before)
    }

    func testLayerDeleteMergeAndReorderUndo() throws {
        let e = try engine()
        e.brush.size = 20; e.brush.hardness = 0.95
        e.beginStroke(at: SIMD2(20, 20), pressure: 1); e.endStroke()
        let bottom = try XCTUnwrap(e.activeLayer)
        let top = try XCTUnwrap(e.addLayer())
        e.beginStroke(at: SIMD2(70, 70), pressure: 1); e.endStroke()
        e.deleteActiveLayer()
        XCTAssertEqual(e.layers.count, 1)
        e.undo()
        XCTAssertEqual(e.layers.map(\.id), [bottom.id, top.id])
        XCTAssertGreaterThan(px(e, 70, 70)[3], 200, "the deleted layer came back with its paint")
        e.moveLayer(from: 0, to: 1)
        XCTAssertEqual(e.layers.map(\.id), [top.id, bottom.id])
        e.undo()
        XCTAssertEqual(e.layers.map(\.id), [bottom.id, top.id])
        e.mergeLayers([bottom.id, top.id])
        XCTAssertEqual(e.layers.count, 1)
        XCTAssertGreaterThan(px(e, 70, 70)[3], 200); XCTAssertGreaterThan(px(e, 20, 20)[3], 200)
        e.undo()
        XCTAssertEqual(e.layers.count, 2)
        e.activeIndex = 0
        XCTAssertEqual(px(e, 70, 70)[3], 0, "the merged paint left the bottom layer")
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
