import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

final class ShapeContentsTests: XCTestCase {
    private func rect(_ x: Double, _ size: Double = 100) -> BezierPath {
        var p = BezierPath.rectangle(size: Vec2(size, size))
        for i in p.vertices.indices { p.vertices[i].point.x += x }
        return p
    }
    private func area(_ paths: [BezierPath]) -> Double {
        abs(paths.reduce(0) { sum, p in
            sum + p.segments(stepsPerCurve: 32).reduce(0.0) { $0 + Double($1.x * $1.w - $1.z * $1.y) / 2 }
        })
    }
    func testBooleanAreasAndSubtractionOrder() {
        let a = rect(0), b = rect(50)
        for (mode, expected) in [(MergePathsMode.add, 15000.0), (.subtract, 5000), (.intersect, 5000), (.exclude, 10000)] {
            XCTAssertEqual(area(ShapeBoolean.combine([[a], [b]], mode: mode)), expected, accuracy: 1, mode.rawValue)
        }
        let sub = ShapeBoolean.cgPath(ShapeBoolean.combine([[a], [b]], mode: .subtract))
        XCTAssertTrue(sub.contains(CGPoint(x: 75, y: 0)))
        XCTAssertFalse(sub.contains(CGPoint(x: -25, y: 0)))
        XCTAssertEqual(ShapeBoolean.combine([[a], [b]], mode: .merge), [a, b])
    }
    func testBooleanHolesDisjointCurvesAndCoincidentEdges() {
        let hole = ShapeBoolean.combine([[rect(0, 40)], [rect(0)]], mode: .subtract)
        XCTAssertEqual(area(hole), 8400, accuracy: 1)
        XCTAssertEqual(hole.count, 2)
        XCTAssertFalse(ShapeBoolean.cgPath(hole).contains(.zero))
        XCTAssertEqual(area(ShapeBoolean.combine([[rect(-150)], [rect(150)]], mode: .add)), 20000, accuracy: 1)
        XCTAssertEqual(area(ShapeBoolean.combine([[rect(0)], [rect(0)]], mode: .exclude)), 0, accuracy: 1)
        XCTAssertEqual(area(ShapeBoolean.combine([[rect(0)], [rect(100)]], mode: .add)), 20000, accuracy: 1)
        let circle = BezierPath.ellipse(size: Vec2(100, 100))
        XCTAssertEqual(area(ShapeBoolean.combine([[circle], [rect(0, 200)]], mode: .intersect)), .pi * 2500, accuracy: 45)
    }
    func testLegacyDecodeKeepsSinglePathAndAnimation() throws {
        var p = Project.new(name: "old", width: 200, height: 200, fps: 30)
        var l = p.makeLayer(name: "Old Star", content: .shape(.star), size: Vec2(120, 90))
        l.size.insertKeyframe(Keyframe(time: 0, value: Vec2(100, 80)))
        l.size.insertKeyframe(Keyframe(time: 1, value: Vec2(160, 120)))
        l.stroke.enabled = true
        p.layers = [l]
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertNil(decoded.layers[0].shapeContents)
        let one = decoded.layers[0].editableShapeContents
        XCTAssertEqual(one.count, 1); XCTAssertEqual(one[0].id, l.id)
        XCTAssertEqual(one[0].component?.size, l.size)
        XCTAssertEqual(one[0].component?.stroke, l.stroke)
        XCTAssertEqual(decoded, p)
    }
    func testMergeOnlyConsumesAboveAndUsesBottomStyle() {
        var a = ShapeComponent(), b = ShapeComponent(), below = ShapeComponent()
        a.path = Animated(rect(0)); a.fill = Animated(RGBA(1, 0, 0))
        b.path = Animated(rect(50)); b.fill = Animated(RGBA(0, 1, 0))
        below.path = Animated(rect(200))
        let items = [ShapeContent(name: "A", component: a), ShapeContent(name: "B", component: b),
                     ShapeContent(name: "Add", merge: .add), ShapeContent(name: "Below", component: below)]
        let result = ShapeContentsRenderer.evaluate(items, time: 0)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(area(result[0].paths), 15000, accuracy: 1)
        XCTAssertEqual(result[0].style.fill.staticValue, RGBA(0, 1, 0))
        XCTAssertEqual(result[1].paths, [below.path.staticValue])
        var hidden = items; hidden[0].visible = false
        XCTAssertEqual(area(ShapeContentsRenderer.evaluate(hidden, time: 0)[0].paths), 10000, accuracy: 1)
    }
    func testOperatorsRespectOrderAndOneStepMove() {
        var ops = ShapeOps(); ops.offset = Animated(15); ops.twist = TwistOp(); ops.pucker = Animated(20)
        let original = ops.activeOrder
        ops.move(.twist, by: -1)
        XCTAssertEqual(ops.activeOrder, [.pucker, .twist, .offset])
        let one = ShapeOpsMath.apply(ops, to: rect(0), time: 0)
        ops.move(.twist, by: -2)
        XCTAssertEqual(ops.activeOrder, [.pucker, .twist, .offset])
        ops.order = original
        XCTAssertNotEqual(one, ShapeOpsMath.apply(ops, to: rect(0), time: 0))
    }
    @MainActor func testPathEditsUndoAndKeyTimingInventory() throws {
        var p = Project.new(name: "edit", width: 200, height: 200, fps: 30)
        p.layers = [p.makeLayer(name: "Shape", content: .shape(.rectangle), size: Vec2(100, 100))]
        let state = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        state.select(p.layers[0].id)
        state.addShapeContent(.ellipse)
        XCTAssertEqual(state.project.layers[0].shapeContents?.count, 2)
        let id = try XCTUnwrap(state.selectedShapeContentID)
        state.editShapeContent(id, "Animate Path") { item in
            item.component?.position.insertKeyframe(Keyframe(time: 1, value: Vec2(20, 0)))
            item.component?.stroke.width.insertKeyframe(Keyframe(time: 2, value: 14))
            item.component?.fillGradient = ShapeGradient()
            item.component?.fillGradient?.end.insertKeyframe(Keyframe(time: 3, value: Vec2(150, 0)))
        }
        XCTAssertTrue(state.project.layers[0].keyframeTimes.contains(3))
        XCTAssertTrue(state.project.layers[0].propertyLanes().contains { $0.title == "Path 2" && $0.times == [1, 2, 3] })
        var layer = state.project.layers[0], traversal = AnimationTraversal(operation: .shift(2))
        layer.traverseAnimations(&traversal)
        XCTAssertEqual(layer.shapeContents?[1].component?.position.keyframeTimes, [3])
        XCTAssertEqual(layer.shapeContents?[1].component?.fillGradient?.end.keyframeTimes, [5])
        state.undo(); XCTAssertNil(state.project.layers[0].shapeContents?[1].component?.fillGradient)
        state.undo(); XCTAssertNil(state.project.layers[0].shapeContents)
    }
    func testCopyPastePathKeysKeepsStyleAndRelativeTimes() {
        var source = logo(), target = logo()
        source.layers[0].shapeContents?[0].component?.position.insertKeyframe(Keyframe(time: 2, value: Vec2(40, 20)))
        let clipboard = KeyClipboard(layer: source.layers[0], at: 0)
        let oldFill = target.layers[0].shapeContents?[0].component?.fill
        clipboard.paste(into: &target.layers[0], at: 5)
        XCTAssertEqual(target.layers[0].shapeContents?[0].component?.position.keyframeTimes, [7])
        XCTAssertEqual(target.layers[0].shapeContents?[0].component?.fill, oldFill)
        XCTAssertNotEqual(target.layers[0].shapeContents?[0].component?.position.keyframes.first?.id,
                          source.layers[0].shapeContents?[0].component?.position.keyframes.first?.id)
    }

    @MainActor func testCompoundStylePasteAndNoLegacyGhostLanes() {
        var p = logo(), source = p.layers[0]
        source.shapeContents = nil; source.content = .solid; source.fill = Animated(RGBA(1,0,0))
        source.stroke.enabled = true; source.stroke.width = Animated(12)
        p.layers[0].fill.insertKeyframe(Keyframe(time: 9, value: .white))
        XCTAssertFalse(p.layers[0].keyframeTimes.contains(9))
        EditorState.applyStyle(source, to: &p.layers[0], parts: [.fill, .border])
        XCTAssertEqual(p.layers[0].shapeContents?[0].component?.fill.staticValue, RGBA(1,0,0))
        XCTAssertEqual(p.layers[0].shapeContents?[0].component?.stroke.width.staticValue, 12)
        XCTAssertFalse(p.layers[0].propertyLanes().contains { $0.id == "c.fill" })
        XCTAssertFalse(p.layers[0].keyframeTimes.contains(9))
    }

    func testCompoundRoundTripAndBoundsIncludeTransformsRepeaterStroke() throws {
        var p = logo()
        var c = try XCTUnwrap(p.layers[0].shapeContents?[0].component)
        c.position = Animated(Vec2(400, 0)); c.stroke.enabled = true; c.stroke.width = Animated(20)
        c.ops = ShapeOps(); c.ops?.repeater = RepeaterOp()
        p.layers[0].shapeContents = [ShapeContent(name: "Far", component: c)]
        let bounds = Renderer.layerHalfSize(p.layers[0], time: 0)
        XCTAssertGreaterThan(bounds.x, 600)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p)), p)
    }
    func testCompoundHoleAndGradientRenderWithEffectsAndMotion() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal") }
        var p = logo()
        let before = try XCTUnwrap(renderer.renderPixels(project: p, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) }))
        let after = try XCTUnwrap(renderer.renderPixels(project: p, time: 0.7, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertNotEqual(before.rgba, after.rgba)
        let center = (128 * 256 + 128) * 4
        XCTAssertEqual(before.rgba[center + 3], 0, "Subtraction hole must remain transparent")
        var merged = p; merged.layers[0].shapeContents?[2].merge = .merge
        let solid = try XCTUnwrap(renderer.renderPixels(project: merged, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) }))
        for x in 174...180 { XCTAssertEqual(solid.rgba[(128 * 256 + x) * 4 + 3], 255, "Internal contour must not create a fill seam") }
        p.layers[0].effects = [EffectRegistry.gaussianBlur.makeInstance()]
        let fx = try XCTUnwrap(renderer.renderPixels(project: p, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertTrue(fx.rgba.enumerated().contains { $0.offset % 4 == 3 && $0.element > 0 })
    }
    func logo() -> Project {
        var p = Project.new(name: "Three-path logo", width: 256, height: 256, fps: 30, duration: 2, background: RGBA(0,0,0,0))
        var l = p.makeLayer(name: "Logo", content: .shape(.path), size: Vec2(200,200))
        var outer = ShapeComponent(); outer.kind = .ellipse; outer.size = Animated(Vec2(176,176)); outer.fillGradient = ShapeGradient()
        var hole = ShapeComponent(); hole.kind = .ellipse; hole.size = Animated(Vec2(100,100))
        var bar = ShapeComponent(); bar.kind = .rectangle; bar.size = Animated(Vec2(36,176)); bar.position = Animated(Vec2(62,0))
        bar.fill = Animated(RGBA(hex: 0xFFD177)); bar.rotation.insertKeyframe(Keyframe(time: 0, value: -15)); bar.rotation.insertKeyframe(Keyframe(time: 1, value: 25))
        l.shapeContents = [ShapeContent(name: "Hole", component: hole), ShapeContent(name: "Ring", component: outer),
                           ShapeContent(name: "Cutout", merge: .subtract), ShapeContent(name: "Accent", component: bar)]
        p.layers = [l]; return p
    }
    func testWriteShapeContactSheetAndMovingRender() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal") }
        let folder = URL(fileURLWithPath: "/tmp/awi-shapes", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var images: [UIImage] = []
        for mode in MergePathsMode.allCases {
            var p = logo(); p.layers[0].shapeContents?[2].merge = mode
            images.append(try XCTUnwrap(renderer.renderImage(project: p, time: 0.35, maxDimension: 256, mediaURL: { URL(fileURLWithPath: $0) })))
        }
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: 768, height: 600)).image { context in
            UIColor(white: 0.08, alpha: 1).setFill(); context.fill(CGRect(x: 0, y: 0, width: 768, height: 600))
            for (i, image) in images.enumerated() {
                let x = CGFloat(i % 3) * 256, y = CGFloat(i / 3) * 300
                image.draw(in: CGRect(x: x, y: y, width: 256, height: 256))
                (MergePathsMode.allCases[i].rawValue as NSString).draw(at: CGPoint(x: x + 12, y: y + 262), withAttributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.white])
            }
        }
        try XCTUnwrap(sheet.pngData()).write(to: folder.appendingPathComponent("shape-contact-sheet.png"))
        let url = folder.appendingPathComponent("shape-motion.gif")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 30, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<30 {
            let image = try XCTUnwrap(renderer.renderImage(project: logo(), time: Double(frame) / 29, maxDimension: 256, mediaURL: { URL(fileURLWithPath: $0) }))
            CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 30]] as CFDictionary)
            if frame % 10 == 0 { try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("motion-\(frame).png")) }
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
