import XCTest
import simd
import UIKit
@testable import AWIeffect

final class EffectsPhaseOneTests: XCTestCase {
    private func scene(_ effect: EffectInstance?, color: RGBA = .black) -> Project {
        var p = Project.new(name: "effect reference", width: 128, height: 96, fps: 30, duration: 3, background: RGBA(0, 0, 0, 0))
        var l = p.makeLayer(name: "card", content: .solid, size: Vec2(128, 96))
        l.fill = Animated(color); l.effects = effect.map { [$0] } ?? []; p.layers = [l]; return p
    }
    private func pixels(_ project: Project, time: Double = 0.4) throws -> [UInt8] {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        return try XCTUnwrap(r.renderPixels(project: project, time: time, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
    }
    private func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(a.count)
    }
    func testLitRippleAddsWhiteBandsWithoutNeedingImageDetail() throws {
        let e = EffectRegistry.litRipple23.makeInstance()
        let plain = try pixels(scene(nil)), lit = try pixels(scene(e))
        XCTAssertGreaterThan(difference(plain, lit), 3)
        let reds = stride(from: 0, to: lit.count, by: 4).map { lit[$0] }
        XCTAssertGreaterThan(Int(reds.max()!) - Int(reds.min()!), 30, "white rings must vary in brightness on a black solid")
        XCTAssertGreaterThan(difference(lit, try pixels(scene(e), time: 1.3)), 1)
        var off = e; off.params["light"] = .number(Animated(0)); off.params["strength"] = .number(Animated(0))
        XCTAssertLessThan(difference(plain, try pixels(scene(off))), 0.01)
        var mixed = e; mixed.params["mix"] = .number(Animated(0))
        XCTAssertLessThan(difference(plain, try pixels(scene(mixed))), 0.01)
    }
    func testLitRipplePreservesTransparentPixelsAndTintWorks() throws {
        var e = EffectRegistry.litRipple23.makeInstance()
        e.params["strength"] = .number(Animated(0))
        let empty = try pixels(scene(e, color: RGBA(0, 0, 0, 0)))
        XCTAssertTrue(empty.allSatisfy { $0 == 0 })
        let white = try pixels(scene(e)); e.params["tint"] = .color(Animated(RGBA(1, 0, 0)))
        let red = try pixels(scene(e))
        XCTAssertGreaterThan(difference(white, red), 2)
        XCTAssertTrue(stride(from: 1, to: red.count, by: 4).allSatisfy { red[$0] == 0 })
    }
    func testLitRippleMatchesSuppliedIPAWhiteHighlightReference() throws {
        var e = EffectRegistry.litRipple23.makeInstance()
        e.params["strength"] = .number(Animated(0))
        // Reference: the supplied IPA's bcc_ripple.xml uses cos-shaped light bands,
        // exponential decay and a net 0.5 light contribution. Check several rings over time.
        for time in [0.0, 0.4, 1.3] {
            let result = try pixels(scene(e), time: time)
            for (x, y) in [(64, 48), (76, 48), (90, 60), (40, 26)] {
                let dx = (Double(x) + 0.5 - 64) / 96, dy = (Double(y) + 0.5 - 48) / 96
                let distance = sqrt(dx * dx + dy * dy)
                let expected = pow(abs(cos(distance * 20 - time)), 2) * exp(-0.5 * distance) * 0.3 * 0.5 * 255
                XCTAssertEqual(Double(result[(y * 128 + x) * 4]), expected, accuracy: 2)
            }
        }
    }
    func testLitRippleMatchesSuppliedIPARadialDisplacementReference() throws {
        var p = scene(nil, color: RGBA(0.1, 0.3, 0.8))
        var right = p.makeLayer(name: "right", content: .solid, size: Vec2(64, 96))
        right.fill = Animated(RGBA(0.9, 0.2, 0.1)); right.transform.position = Animated(Vec2(96, 48))
        p.layers.insert(right, at: 0)
        let original = try pixels(p)
        var e = EffectRegistry.litRipple23.makeInstance()
        e.params["light"] = .number(Animated(0)); e.params["strength"] = .number(Animated(0.08))
        var adjustment = p.makeLayer(name: "ripple", content: .adjustment, size: Vec2(128, 96))
        adjustment.effects = [e]; p.layers.insert(adjustment, at: 0)
        let warped = try pixels(p)
        XCTAssertGreaterThan(difference(original, warped), 1)
        for y in stride(from: 25, through: 70, by: 5) {
            for x in stride(from: 50, through: 80, by: 5) {
                let dx = (Double(x) + 0.5 - 64) / 96, dy = (Double(y) + 0.5 - 48) / 96
                let distance = sqrt(dx * dx + dy * dy)
                let displacement = sin(distance * 20 - 0.4) * exp(-0.5 * distance) * 0.08 * 96
                let sampleX = Double(x) + dx / distance * displacement
                let sampleY = Double(y) + dy / distance * displacement
                let x0 = Int(floor(sampleX)), y0 = Int(floor(sampleY)), fx = sampleX - floor(sampleX), fy = sampleY - floor(sampleY)
                for channel in 0..<3 {
                    func value(_ xx: Int, _ yy: Int) -> Double { Double(original[(yy * 128 + xx) * 4 + channel]) }
                    let top = value(x0, y0) * (1 - fx) + value(x0 + 1, y0) * fx
                    let bottom = value(x0, y0 + 1) * (1 - fx) + value(x0 + 1, y0 + 1) * fx
                    XCTAssertEqual(Double(warped[(y * 128 + x) * 4 + channel]), top * (1 - fy) + bottom * fy, accuracy: 3)
                }
            }
        }
    }
    func testTimeSliceMaskReverseComplementsCoverageAndChangesOverTime() throws {
        var e = EffectRegistry.timeSliceMask23.makeInstance()
        e.params["output"] = .choice(1)
        let a = try pixels(scene(e))
        e.params["reverse"] = .toggle(true)
        let b = try pixels(scene(e))
        for i in stride(from: 3, to: a.count, by: 4) { XCTAssertEqual(Int(a[i]) + Int(b[i]), 255, accuracy: 2) }
        XCTAssertGreaterThan(difference(a, try pixels(scene(e), time: 0.8)), 5)
        e.params["smoothness"] = .number(Animated(0)); e.params["feather"] = .number(Animated(0))
        let hard = try pixels(scene(e))
        XCTAssertTrue(stride(from: 3, to: hard.count, by: 4).allSatisfy { hard[$0] == 0 || hard[$0] == 255 })
    }
    func testDrawProgressUsesLengthAcrossUnequalSegmentsAndCrossedEndsAreEmpty() {
        let segments: [SIMD4<Float>] = [SIMD4(0, 0, 10, 0), SIMD4(10, 0, 100, 0)]
        var e = EffectRegistry.drawingProgress23.makeInstance(); e.params["end"] = .number(Animated(25))
        let quarter = EffectRegistry.drawingSegments(segments, effects: [e], time: 0)
        XCTAssertEqual(quarter.count, 2); XCTAssertEqual(quarter.last!.z, 25, accuracy: 0.001)
        e.params["start"] = .number(Animated(50))
        XCTAssertTrue(EffectRegistry.drawingSegments(segments, effects: [e], time: 0).isEmpty)
        e.isEnabled = false
        XCTAssertEqual(EffectRegistry.drawingSegments(segments, effects: [e], time: 0), segments)
    }
    func testDrawProgressKeyframesRenderStrokeRevealAndRoundTrip() throws {
        var p = scene(nil)
        p.layers[0].content = .shape(.path); p.layers[0].fill = Animated(RGBA(0, 0, 0, 0))
        p.layers[0].path = Animated(BezierPath(vertices: [PathVertex(point: Vec2(-50, 0)), PathVertex(point: Vec2(50, 0))], closed: false))
        p.layers[0].stroke.enabled = true; p.layers[0].stroke.width = Animated(6); p.layers[0].stroke.color = Animated(.white)
        var e = EffectRegistry.drawingProgress23.makeInstance()
        var end = Animated(0.0); end.insertKeyframe(Keyframe(time: 0, value: 0)); end.insertKeyframe(Keyframe(time: 1, value: 100))
        e.params["end"] = .number(end); p.layers[0].effects = [e]
        let empty = try pixels(p, time: 0), halfway = try pixels(p, time: 0.5), full = try pixels(p, time: 1)
        func coverage(_ px: [UInt8]) -> Int { stride(from: 3, to: px.count, by: 4).filter { px[$0] > 128 }.count }
        XCTAssertEqual(coverage(empty), 0); XCTAssertGreaterThan(coverage(halfway), 200)
        XCTAssertEqual(Double(coverage(halfway)) / Double(coverage(full)), 0.5, accuracy: 0.08)
        let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(try pixels(decoded, time: 0.5), halfway)
    }
    func testHalftonePrintHasSolidEndpointsAndMixIdentity() throws {
        var e = EffectRegistry.halftone.makeInstance()
        e.params["version"] = .choice(1); e.params["ink"] = .color(Animated(.black)); e.params["paper"] = .color(Animated(.white))
        for color in [RGBA.black, .white] {
            XCTAssertLessThan(difference(try pixels(scene(e, color: color)), try pixels(scene(nil, color: color))), 0.1)
        }
        let gray = RGBA(0.45, 0.45, 0.45)
        let print = try pixels(scene(e, color: gray))
        XCTAssertGreaterThan(difference(print, try pixels(scene(nil, color: gray))), 10)
        e.params["mix"] = .number(Animated(0))
        XCTAssertLessThan(difference(try pixels(scene(e, color: gray)), try pixels(scene(nil, color: gray))), 0.01)
        e.params["mix"] = .number(Animated(100)); e.params["version"] = nil
        let missing = try pixels(scene(e, color: gray)); e.params["version"] = .choice(0)
        XCTAssertEqual(try pixels(scene(e, color: gray)), missing)
        XCTAssertNotEqual(missing, print)
        XCTAssertNil(EffectRegistry.definition(aeMatchName: "CC Ball Action"), "2D print dots are not 3D Ball Action")
    }
    func testHalftoneAMDotsMatchesSuppliedIPAToneAndStaggerReference() throws {
        var e = EffectRegistry.halftone.makeInstance()
        XCTAssertEqual(e.choice("version"), 2)
        e.params["amount"] = .number(Animated(16)); e.params["angle"] = .number(Animated(0))
        let result = try pixels(scene(e, color: RGBA(0.35, 0.35, 0.35)))
        let ink = [17.0, 51, 85], paper = [255.0, 238, 221]
        for y in stride(from: 13, through: 80, by: 9) {
            for x in stride(from: 10, through: 115, by: 11) {
                let gx = (Double(x) + 0.5 - 64) / 8, gy = (Double(y) + 0.5 - 48) / 8
                let row = floor(gy + 0.5), shift = Int(row) & 1 != 0 ? 0.5 : 0
                let centerX = floor(gx + shift + 0.5) - shift
                let distance = hypot(gx - centerX, gy - row)
                let u = min(1, max(0, (0.35 + distance - 0.4) / 0.2)), weight = u * u * (3 - 2 * u)
                for channel in 0..<3 {
                    XCTAssertEqual(Double(result[(y * 128 + x) * 4 + channel]), ink[channel] * (1 - weight) + paper[channel] * weight, accuracy: 3)
                }
            }
        }
    }
    func testOlderHalftoneCanSwitchToNewModeWithoutMissingControlDefaults() throws {
        let fresh = EffectRegistry.halftone.makeInstance()
        var old = EffectInstance(typeID: "awi.halftone", params: ["size": .number(Animated(8)), "angle": .number(Animated(45)), "color": .toggle(false)])
        old.params["version"] = .choice(2)
        XCTAssertEqual(try pixels(scene(old, color: RGBA(0.4, 0.4, 0.4))), try pixels(scene(fresh, color: RGBA(0.4, 0.4, 0.4))))
    }

    func testExportReferencePreviews() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        let folder = URL(fileURLWithPath: "/tmp/awi-ui", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var mask = EffectRegistry.timeSliceMask23.makeInstance(); mask.params["output"] = .choice(1)
        let entries: [(String, Project)] = [
            ("lit-ripple-white-rings", scene(EffectRegistry.litRipple23.makeInstance())),
            ("time-slice-mask", scene(mask)),
            ("halftone-print", scene(EffectRegistry.halftone.makeInstance(), color: RGBA(0.45, 0.45, 0.45)))
        ]
        for (name, project) in entries {
            let image = try XCTUnwrap(r.renderImage(project: project, time: 0.4, maxDimension: 512, mediaURL: { URL(fileURLWithPath: $0) }))
            try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("phase-one-\(name).png"))
        }
    }
    func testReferenceImportsRetainEffectSettingsInsteadOfUsingFuzzyDefaults() throws {
        var p = scene(nil)
        var report = ImportReport()
        func apply(_ xml: String) throws {
            let node = try XCTUnwrap(AMImporter.parse(Data(xml.utf8)))
            var layer = p.layers[0]
            AMImporter.applyEffect(node, to: &layer, project: &p, inPoint: 0, length: 2, report: &report)
            p.layers[0] = layer
        }
        try apply("""
        <effect id="com.alightcreative.effects.ripplelight"><property name="frequency" value="32"/><property name="lightIntensity" value="0.8"/><property name="centerX" value="0.25"/><property name="blend" value="0.75"/></effect>
        """)
        var effect = try XCTUnwrap(p.layers[0].effects.last)
        XCTAssertEqual(effect.typeID, "awi23.litRipple"); XCTAssertEqual(effect.number("frequency", 0), 32)
        XCTAssertEqual(effect.number("light", 0), 0.8); XCTAssertEqual(effect.number("mix", 0), 75)
        XCTAssertEqual(effect.point("center", 0), Vec2(0.25, 0.5))
        try apply("""
        <effect id="com.alightcreative.effects.halftonedots"><property name="amount" value="33"/><property name="strength" value="0.7"/><property name="phase" value="0.25"/></effect>
        """)
        effect = try XCTUnwrap(p.layers[0].effects.last)
        XCTAssertEqual(effect.typeID, "awi.halftone"); XCTAssertEqual(effect.choice("version"), 2)
        XCTAssertEqual(effect.number("amount", 0), 33); XCTAssertEqual(effect.number("strength", 0), 70, accuracy: 0.001)
        XCTAssertEqual(effect.number("phase", 0), 0.25)
    }
}
