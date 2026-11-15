import XCTest
import UIKit
@testable import AWIeffect

final class InteractiveSelectionTests: XCTestCase {
    @MainActor func testUndoCancelsPendingSmartSelectionWithoutAddingAnUndoStep() async throws {
        let engine = try XCTUnwrap(DrawEngine(width: 96, height: 96))
        engine.beginSelectStroke(at: SIMD2(20, 20), radius: 8, subtract: false)
        engine.continueSelectStroke(to: SIMD2(50, 50))
        engine.endSelectStroke(snapToSubject: true)
        XCTAssertTrue(engine.isSelectingSubject)
        engine.undo()
        XCTAssertFalse(engine.isSelectingSubject)
        XCTAssertFalse(engine.hasSelection)
        await Task.yield()
        XCTAssertFalse(engine.hasSelection)
        XCTAssertFalse(engine.canUndo)
    }
    func testStrokeSamplingIncludesBothEndsWithinDecoderBudget() {
        let stroke = (0...100).map { CGPoint(x: Double($0) / 100, y: 0.25) }
        let samples = InteractiveSelection.samples(stroke, limit: 9)
        XCTAssertEqual(samples.count, 9)
        XCTAssertEqual(samples.first, stroke.first)
        XCTAssertEqual(samples.last, stroke.last)
        XCTAssertEqual(samples[4].x, 0.5, accuracy: 0.001)
    }

    func testInkIsNotRemovedAndNegativePaintCannotGrowTheSelection() {
        XCTAssertEqual(InteractiveSelection.combine(region: [255, 0, 255, 0], painted: [0, 255, 0, 0], previous: [0, 0, 0, 255], subtract: false), [255, 255, 255, 255])
        XCTAssertEqual(InteractiveSelection.combine(region: [255, 0, 255, 0], painted: [0, 255, 0, 0], previous: [255, 255, 0, 255], subtract: true), [0, 0, 0, 255])
        XCTAssertEqual(InteractiveSelection.touchedComponents([255, 255, 0, 255, 255], painted: [255, 0, 0, 0, 0], width: 5, height: 1), [true, true, false, false, false])
    }

    func testPortraitMaskResamplingKeepsTopAndBottomOrientation() {
        let mask = InteractiveSelection.resample([255, 0, 0, 0, 0, 255], fromWidth: 2, fromHeight: 3, width: 4, height: 6)
        XCTAssertEqual(mask[0], 255)
        XCTAssertEqual(mask[3], 0)
        XCTAssertEqual(mask[20], 0)
        XCTAssertEqual(mask[23], 255)
    }

    func testEdgeFitMakesInteriorsOpaqueAndBackgroundTransparent() {
        XCTAssertEqual(Array(InteractiveSelection.fitEdge([0, 40, 90, 128, 180, 230, 255], tolerance: 0.18).prefix(3)), [0, 0, 0])
        XCTAssertEqual(InteractiveSelection.fitEdge([180, 230, 255], tolerance: 0.18), [255, 255, 255])
        XCTAssertNotEqual(InteractiveSelection.fitEdge([128], tolerance: 0.02), InteractiveSelection.fitEdge([128], tolerance: 0.5))
    }

    func testPartCandidateMustCoverTheWholeStroke() {
        let chosen = InteractiveSelection.choose([([255, 0, 0, 0], 0.99), ([255, 255, 0, 0], 0.9)], points: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.1)], width: 2, height: 2)
        XCTAssertEqual(chosen, [255, 255, 0, 0])
        let corrected = InteractiveSelection.choose([([255, 255, 0, 0], 0.99), ([255, 0, 0, 0], 0.9)], points: [CGPoint(x: 0.1, y: 0.1)], width: 2, height: 2, negative: [CGPoint(x: 0.9, y: 0.1)])
        XCTAssertEqual(corrected, [255, 0, 0, 0])
    }

    func testMaskChoiceRejectsInkFragmentsWithoutFillingRealHoles() {
        var punched = [UInt8](repeating: 255, count: 81)
        for i in [20, 24, 38, 42, 56, 60] { punched[i] = 0 }
        let solid = [UInt8](repeating: 255, count: 81)
        XCTAssertEqual(InteractiveSelection.choose([(punched, 0.95), (solid, 0.9)], points: [CGPoint(x: 0.5, y: 0.5)], width: 9, height: 9), solid)
        var ring = solid; ring[40] = 0
        XCTAssertEqual(InteractiveSelection.inkHolePenalty(ring, width: 9, height: 9, protected: []), 0)
        XCTAssertEqual(ring[40], 0, "ranking must never paint over a real gap")
    }

    /// Runs the actual bundled neural encoder/decoder, not a fake mask. The ink crosses the
    /// brushed region; it must remain inside the inferred shape rather than becoming a hole.
    func testBundledModelSelectsShadedObjectAcrossInternalInk() async throws {
        let size = CGSize(width: 512, height: 384)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { c in
            UIColor(white: 0.9, alpha: 1).setFill(); c.fill(CGRect(origin: .zero, size: size))
            let body = UIBezierPath(roundedRect: CGRect(x: 115, y: 75, width: 235, height: 235), cornerRadius: 40)
            UIColor(red: 0.6, green: 0.25, blue: 0.12, alpha: 1).setFill(); body.fill()
            UIColor.black.setStroke(); body.lineWidth = 6; body.stroke()
            for y in stride(from: 130, through: 250, by: 30) {
                let ink = UIBezierPath(); ink.move(to: CGPoint(x: 140, y: y)); ink.addCurve(to: CGPoint(x: 325, y: y), controlPoint1: CGPoint(x: 200, y: y - 18), controlPoint2: CGPoint(x: 260, y: y + 18))
                ink.lineWidth = 4; ink.stroke()
            }
        }
        let cg = try XCTUnwrap(image.cgImage)
        let session = InteractiveSelection()
        let mask = try await session.region(image: cg, points: [CGPoint(x: 0.45, y: 0.4), CGPoint(x: 0.46, y: 0.62)], width: 512, height: 384)
        XCTAssertEqual(mask.count, 512 * 384)
        XCTAssertGreaterThan(mask[190 * 512 + 230], 128, "internal ink must stay selected")
        XCTAssertLessThan(mask[20 * 512 + 20], 128, "background must stay outside")
        var intersection = 0, union = 0, interior = 0, coveredInterior = 0
        for y in 0..<384 { for x in 0..<512 {
            let expected = (120..<345).contains(x) && (80..<305).contains(y)
            let selected = mask[y * 512 + x] >= 128
            if expected && selected { intersection += 1 }
            if expected || selected { union += 1 }
            if (140..<325).contains(x) && (110..<270).contains(y) {
                interior += 1; if selected { coveredInterior += 1 }
            }
        } }
        XCTAssertGreaterThan(Double(intersection) / Double(max(1, union)), 0.8, "mask must cover the object, not just return a nonempty region")
        XCTAssertGreaterThan(Double(coveredInterior) / Double(interior), 0.95, "shading and muscle/ink lines must remain filled")
        try save(image, mask: mask, name: "shaded-ink-object")
        // A second request exercises the cached embedding and part prompts without re-encoding.
        let again = try await session.region(image: cg, points: [CGPoint(x: 0.5, y: 0.5)], width: 512, height: 384)
        XCTAssertEqual(again.count, mask.count)
    }

    func testPortraitInferenceSelectsThePromptedTopObjectNotItsMirror() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 512), format: format).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 256, height: 512))
            UIColor.blue.setFill(); UIBezierPath(ovalIn: CGRect(x: 25, y: 40, width: 110, height: 130)).fill()
            UIColor.red.setFill(); UIBezierPath(roundedRect: CGRect(x: 120, y: 350, width: 110, height: 130), cornerRadius: 18).fill()
        }
        let cg = try XCTUnwrap(image.cgImage)
        let mask = try await InteractiveSelection().region(image: cg, points: [CGPoint(x: 80.0 / 256, y: 100.0 / 512)], width: 256, height: 512)
        XCTAssertGreaterThan(mask[100 * 256 + 80], 128)
        XCTAssertLessThan(mask[410 * 256 + 180], 128)
        try save(image, mask: mask, name: "portrait-orientation")
    }

    func testDetailedMangaInferenceProducesReviewableMasks() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "hokusai", withExtension: "jpg"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)), cg = try XCTUnwrap(image.cgImage)
        let session = InteractiveSelection()
        // Two different people, with dense outlines, muscle lines, neighboring figures and paper texture.
        for (name, points) in [
            ("manga-left", [CGPoint(x: 0.20, y: 0.31), CGPoint(x: 0.22, y: 0.45)]),
            ("manga-right", [CGPoint(x: 0.79, y: 0.12), CGPoint(x: 0.80, y: 0.24)])
        ] {
            let mask = try await session.region(image: cg, points: points, width: cg.width, height: cg.height)
            XCTAssertEqual(mask.count, cg.width * cg.height)
            XCTAssertTrue(mask.contains { $0 > 128 })
            XCTAssertTrue(mask.contains { $0 < 128 })
            try save(image, mask: mask, name: name)
        }
    }

    func testAnimeHairAndFacePrompts() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "default-preview", withExtension: "jpg"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)), cg = try XCTUnwrap(image.cgImage)
        let session = InteractiveSelection()
        for (name, points) in [
            ("anime-hair", [CGPoint(x: 0.40, y: 0.18), CGPoint(x: 0.60, y: 0.20)]),
            ("anime-face", [CGPoint(x: 0.46, y: 0.62), CGPoint(x: 0.55, y: 0.72)])
        ] {
            let mask = try await session.region(image: cg, points: points, width: cg.width, height: cg.height)
            XCTAssertEqual(mask.count, cg.width * cg.height)
            try save(image, mask: mask, name: name)
            if name == "anime-face" {
                let pixels = CutoutBake.pixels(of: cg, width: cg.width, height: cg.height)
                var dark = 0, kept = 0
                for y in 780..<920 { for x in 480..<700 {
                    let i = y * cg.width + x, p = i * 4
                    if max(pixels[p], max(pixels[p + 1], pixels[p + 2])) < 95 {
                        dark += 1; if mask[i] >= 128 { kept += 1 }
                    }
                } }
                XCTAssertGreaterThan(dark, 100)
                XCTAssertGreaterThan(Double(kept) / Double(max(1, dark)), 0.95, "mouth and internal ink are foreground, not transparent holes")
            }
        }
    }

    private func save(_ image: UIImage, mask: [UInt8], name: String) throws {
        let cg = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(mask.count, cg.width * cg.height)
        let maskImage = try XCTUnwrap(MatteFrame(width: cg.width, height: cg.height, bytes: mask).image())
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: image.size.width * 2, height: image.size.height), format: format).image { _ in
            image.draw(at: .zero); maskImage.draw(in: CGRect(x: image.size.width, y: 0, width: image.size.width, height: image.size.height))
        }
        let folder = URL(fileURLWithPath: "/tmp/awi-selection")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try XCTUnwrap(sheet.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(image: sheet); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
