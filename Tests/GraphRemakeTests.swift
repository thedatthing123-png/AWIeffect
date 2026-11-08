import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

final class GraphRemakeTests: XCTestCase {
    private func animation(_ kind: EaseCurve.Kind, cycles: Double = 3, smoothness: Double = 1) -> Animated<Double> {
        var c = EaseCurve(kind); c.a = cycles
        if [.cycleRepeat, .cyclePingPong].contains(kind) { c.b = smoothness }
        var a = Animated(10.0)
        a.insertKeyframe(Keyframe(time: 0, value: 10, interpolation: .bezier))
        a.insertKeyframe(Keyframe(time: 3, value: 0))
        a.keyframes[0].curve = c
        return a
    }
    func testRepeatResetsAndBackForthReturnsWithoutJumping() {
        let repeatA = animation(.cycleRepeat)
        XCTAssertEqual(repeatA.value(at: 0), 10)
        XCTAssertEqual(repeatA.value(at: 1 - 1e-6), 0, accuracy: 0.00001)
        XCTAssertEqual(repeatA.value(at: 1), 10, accuracy: 0.00001)
        XCTAssertEqual(repeatA.value(at: 3), 0)
        let back = animation(.cyclePingPong, cycles: 2)
        XCTAssertEqual(back.value(at: 1), 0, accuracy: 0.00001)
        XCTAssertEqual(back.value(at: 2), 10, accuracy: 0.00001)
        XCTAssertEqual(back.value(at: 3), 0)
        XCTAssertEqual(back.value(at: 1 - 1e-5), back.value(at: 1 + 1e-5), accuracy: 1e-7)
    }
    func testSmoothnessChangesTurnVelocityAndFrequencyChangesPasses() {
        let smooth = animation(.cyclePingPong, cycles: 2)
        let sharp = animation(.cyclePingPong, cycles: 2, smoothness: 0)
        let dt = 0.0001
        XCTAssertLessThan(abs((smooth.value(at: 1) - smooth.value(at: 1-dt))/dt), 0.01)
        XCTAssertGreaterThan(abs((sharp.value(at: 1) - sharp.value(at: 1-dt))/dt), 9)
        let once = animation(.cycleRepeat, cycles: 1), triple = animation(.cycleRepeat, cycles: 3)
        XCTAssertGreaterThan(once.value(at: 1), 5)
        XCTAssertEqual(triple.value(at: 1), 10)
    }
    @MainActor func testTwoHandleEditsAreRelativeAndClamped() {
        let c = EaseCurve(.cyclePingPong)
        XCTAssertEqual(ParameterCurveEditor.translated(c, first: true, delta: 0, width: 348), c)
        let more = ParameterCurveEditor.translated(c, first: true, delta: 60, width: 348)
        XCTAssertEqual(more.a, 5); XCTAssertEqual(more.b, c.b)
        let less = ParameterCurveEditor.translated(c, first: false, delta: -150, width: 348)
        XCTAssertEqual(less.b, 0.5, accuracy: 1e-8); XCTAssertEqual(less.a, c.a)
        XCTAssertEqual(ParameterCurveEditor.translated(c, first: true, delta: 10000, width: 348).a, 12)
        let bounce = EaseCurve(.bounceOut)
        XCTAssertNotEqual(ParameterCurveEditor.translated(bounce, first: false, delta: 80, width: 348).b, bounce.b)
    }
    func testLoopsSerializeReverseAndPreviewLikeActualKeyframes() throws {
        for kind in [EaseCurve.Kind.cycleRepeat, .cyclePingPong] {
            let original = animation(kind)
            let decoded = try JSONDecoder().decode(Animated<Double>.self, from: JSONEncoder().encode(original))
            var reverse = original; reverse.reverseKeys(around: 3)
            let c = original.keyframes[0].curve!
            let preview = SavedEase(name: "loop", interpolation: .bezier, out: .easyOut, into: .easyIn, curve: c)
            for frame in 1..<180 {
                let time = Double(frame) / 60
                XCTAssertEqual(decoded.value(at: time), original.value(at: time), accuracy: 1e-8)
                // Skip exact repeat discontinuities: reversing uses the existing right-continuous key convention.
                if abs(time.rounded() - time) > 0.001 {
                    XCTAssertEqual(reverse.value(at: time), original.value(at: 3-time), accuracy: 1e-7)
                }
                XCTAssertEqual(10 - 10 * preview.progress(time/3), original.value(at: time), accuracy: 1e-7)
                XCTAssertTrue(preview.velocity(at: time/3, valueDelta: -10, duration: 3).isFinite)
            }
        }
        let legacy = try JSONDecoder().decode(EaseCurve.self, from: Data("{\"kind\":\"bounceOut\",\"a\":3,\"b\":0.45}".utf8))
        XCTAssertEqual(legacy, EaseCurve(.bounceOut))
    }
    @MainActor func testLoopEditingKeepsOtherSegmentsAndUndoRestoresThem() {
        var p = Project.new(name: "Graph Undo", width: 64, height: 64, fps: 30, duration: 3)
        var l = p.makeLayer(name: "Shape", content: .solid, size: Vec2(16,16))
        for t in [0.0,1,2] { l.transform.position.insertKeyframe(Keyframe(time: t,value: Vec2(t*10,32))) }
        l.transform.position.keyframes[1].curve = EaseCurve(.elasticOut)
        p.layers = [l]
        let store = ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let state = EditorState(project: p, store: store); state.select(l.id)
        state.setEase(.position, segment: 0, interpolation: .bezier, out: .easyOut, into: .easyIn, curve: EaseCurve(.cyclePingPong), continuous: true)
        var changed = EaseCurve(.cyclePingPong); changed.a = 5
        state.setEase(.position, segment: 0, interpolation: .bezier, out: .easyOut, into: .easyIn, curve: changed, continuous: true)
        state.endEdit()
        XCTAssertEqual(state.project.layers[0].transform.position.keyframes[0].curve, changed)
        XCTAssertEqual(state.project.layers[0].transform.position.keyframes[1].curve, l.transform.position.keyframes[1].curve)
        state.undo(); XCTAssertEqual(state.project, p)
        state.redo(); XCTAssertEqual(state.project.layers[0].transform.position.keyframes[0].curve, changed)
    }

    @MainActor func testBezierViewportFitsSteepRemapHandlesWithoutChangingThem() {
        let out = EaseHandle(x: 0.33, y: 7.94), into = EaseHandle(x: 0.67, y: -3)
        let range = CurveEditor.verticalRange(out: out, into: into)
        let box = CGRect(x: 24, y: 24, width: 300, height: 140)
        for h in [out, into, EaseHandle(x: 0, y: 0), EaseHandle(x: 1, y: 1)] {
            XCTAssertTrue(box.contains(CurveEditor.pt(h, box, range: range)))
            XCTAssertEqual(CurveEditor.translated(h, by: .zero, box: box, range: range), h)
        }
        for i in 0...200 {
            let x = Double(i)/200, y = BezierTiming.progress(x: x, p1: out, p2: into)
            XCTAssertTrue(box.contains(CurveEditor.pt(EaseHandle(x: x,y: y), box, range: range)))
        }
    }

    @MainActor func testPropertyLoopCannotBePastedIntoSourceTimeRemap() {
        var p = Project.new(name: "Remap isolation", width: 64, height: 64, fps: 30, duration: 3)
        let nested = Project.new(name: "Source", width: 64, height: 64, fps: 30, duration: 3)
        p.precomps = [nested]
        let layer = p.makeLayer(name: "Comp", content: .precomp(id: nested.id), size: Vec2(64,64))
        p.layers = [layer]
        let store = ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let state = EditorState(project: p, store: store); state.select(layer.id); state.enableTimeRemap()
        let original = state.project
        for kind in [EaseCurve.Kind.cycleRepeat, .cyclePingPong] {
            state.setRemapEase(segment: 0, ease: SavedEase(name: "loop", interpolation: .bezier, out: .easyOut, into: .easyIn, curve: EaseCurve(kind)))
            XCTAssertEqual(state.project, original)
        }
    }

    @MainActor func testAnimatedCurveMotionArtifact() throws {
        let folder = URL(fileURLWithPath: "/tmp/awi-graphs", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("graph-motion.gif")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(file as CFURL, UTType.gif.identifier as CFString, 90, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let curves = [animation(.cycleRepeat), animation(.cyclePingPong), animation(.bounceOut)]
        let names = ["Repeat — instant reset", "Back & Forth — smooth return", "Bounce — gravity and recoil"]
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400,height: 216))
        for frame in 0..<90 {
            let t = Double(frame) / 30
            let image = renderer.image { ctx in
                UIColor(white: 0.06,alpha: 1).setFill(); ctx.fill(CGRect(x: 0,y: 0,width: 400,height: 216))
                for row in 0..<3 {
                    let y = CGFloat(row * 72)
                    (names[row] as NSString).draw(at: CGPoint(x: 12,y: y+3), withAttributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.white])
                    let value = curves[row].value(at: t)
                    XCTAssertTrue(value.isFinite)
                    UIColor(white: 0.3,alpha: 1).setStroke()
                    ctx.cgContext.move(to: CGPoint(x: 36,y: y+45)); ctx.cgContext.addLine(to: CGPoint(x: 364,y: y+45)); ctx.cgContext.strokePath()
                    UIColor(red: 0.64,green: 0.36,blue: 1,alpha: 1).setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 28 + value / 10 * 328,y: Double(y+37),width: 16,height: 16))
                }
            }
            CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0/30]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

}
