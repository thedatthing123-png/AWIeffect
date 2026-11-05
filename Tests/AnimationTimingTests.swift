import XCTest
import simd
@testable import AWIeffect

final class AnimationTimingTests: XCTestCase {
    private func scene() -> Project {
        var p = Project.new(name: "timing", width: 128, height: 128, fps: 30, duration: 6, background: RGBA(0,0,0,0))
        var l = p.makeLayer(name: "clip", content: .video(fileName: "test.mov", pixelWidth: 128, pixelHeight: 128, hasAudio: false), size: Vec2(20,20))
        l.inPoint = 1; l.outPoint = 5; l.sourceStart = 2
        p.layers = [l]; return p
    }
    @MainActor private func editor(_ p: Project) -> EditorState {
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.selectedLayerID = p.layers.first?.id; return s
    }

    @MainActor func testMoveSelectionPreservesSpacingEaseAndOccupiedKeys() throws {
        var p = scene()
        for t in [1.0,2,4] { p.layers[0].transform.rotation.insertKeyframe(Keyframe(time: t, value: t * 10, interpolation: .bezier)) }
        p.layers[0].transform.rotation.keyframes[0].curve = EaseCurve(.elasticOut)
        p.layers[0].volume.insertKeyframe(Keyframe(time: 1, value: 35))
        let s = editor(p), original = p.layers[0]
        s.beginEdit("Move")
        XCTAssertEqual(s.moveKeyframeSelection(of: original, times: [1,2], by: 0.5), 0.5)
        XCTAssertEqual(s.moveKeyframeSelection(of: original, times: [1,2], by: 1), 1)
        s.endEdit()
        let moved = s.project.layers[0]
        XCTAssertEqual(moved.transform.rotation.keyframeTimes, [2,3,4])
        XCTAssertEqual(moved.volume.keyframeTimes, [2])
        XCTAssertEqual(moved.transform.rotation.keyframes[0].id, original.transform.rotation.keyframes[0].id)
        XCTAssertEqual(moved.transform.rotation.keyframes[0].curve, original.transform.rotation.keyframes[0].curve)
        XCTAssertNil(s.moveKeyframeSelection(of: moved, times: [2,3], by: 1), "Do not overwrite the unselected key at 4")
        XCTAssertEqual(s.project.layers[0], moved)
        s.undo(); XCTAssertEqual(s.project.layers[0], original)
    }

    @MainActor func testSelectionClampsAsOneBlockAndMarkerIdentitySurvivesDrag() throws {
        var p = scene()
        for t in [1.0,3] { p.layers[0].transform.position.insertKeyframe(Keyframe(time: t, value: Vec2(t, 64))) }
        let s = editor(p), original = p.layers[0], ids = original.keyframeMarkers.map(\.id)
        XCTAssertEqual(s.moveKeyframeSelection(of: original, times: [1,3], by: -100), -1)
        XCTAssertEqual(s.project.layers[0].keyframeTimes, [0,2])
        XCTAssertEqual(s.project.layers[0].keyframeMarkers.map(\.id), ids)
        XCTAssertEqual(s.moveKeyframeSelection(of: original, times: [1,3], by: 100), 3)
        XCTAssertEqual(s.project.layers[0].keyframeTimes, [4,6])
    }

    @MainActor func testSpeedScalesAllKeyTimesAndFreezeWithoutChangingSourceWindow() throws {
        var p = scene(); p.layers[0].speed = 2
        for t in [1.0,3,5] { p.layers[0].transform.positionZ.insertKeyframe(Keyframe(time: t, value: t)) }
        p.layers[0].volume.insertKeyframe(Keyframe(time: 3, value: 60))
        var effect = EffectRegistry.gaussianBlur.makeInstance()
        effect.params["blurriness"] = .number(Animated(0))
        if case .number(var a)? = effect.params["blurriness"] { a.insertKeyframe(Keyframe(time: 3, value: 10)); effect.params["blurriness"] = .number(a) }
        p.layers[0].effects = [effect]; p.layers[0].timeFX = LayerTimeFX(); p.layers[0].timeFX?.freezeAt = 3
        let s = editor(p); s.setLayerSpeed(4)
        let layer = s.project.layers[0]
        XCTAssertEqual(layer.outPoint, 3); XCTAssertEqual(layer.speed, 4)
        XCTAssertEqual(layer.transform.positionZ.keyframeTimes, [1,2,3])
        XCTAssertEqual(layer.volume.keyframeTimes, [2]); XCTAssertEqual(layer.timeFX?.freezeAt, 2)
        XCTAssertEqual(layer.sourceTime(at: 2), p.layers[0].sourceTime(at: 3))
        if case .number(let a)? = layer.effects[0].params["blurriness"] { XCTAssertEqual(a.keyframeTimes, [2]) } else { XCTFail() }
    }

    @MainActor func testGroupSpeedCarriesHiddenMembersAndTheirMediaTiming() throws {
        var p = scene()
        var second = p.layers[0]; second.id = UUID(); second.inPoint = 2; second.outPoint = 4; second.speed = 2
        second.transform.rotation.insertKeyframe(Keyframe(time: 3, value: 90)); p.layers.append(second)
        let s = editor(p); s.multiSelection = Set(p.layers.map(\.id)); s.groupSelected(); s.setLayerSpeed(2)
        let member = try XCTUnwrap(s.project.layers.first(where: { $0.id == second.id }))
        XCTAssertEqual(member.inPoint, 1.5); XCTAssertEqual(member.outPoint, 2.5); XCTAssertEqual(member.speed, 4)
        XCTAssertEqual(member.transform.rotation.keyframeTimes, [2])
        XCTAssertEqual(member.sourceTime(at: 2), second.sourceTime(at: 3))
    }

    @MainActor func testLiveSpeedScrubUsesCurrentPreviewRateAndCommitsOneUndo() {
        var p = scene()
        p.layers[0].transform.rotation.insertKeyframe(Keyframe(time: 3,value: 90))
        let s = editor(p)
        s.beginEdit("Speed"); s.beginLiveGesture()
        s.setLayerSpeed(4); s.setLayerSpeed(2)
        XCTAssertEqual(s.project.layers[0], p.layers[0])
        XCTAssertEqual(s.live.project?.layers[0].outPoint, 3)
        XCTAssertEqual(s.live.project?.layers[0].transform.rotation.keyframeTimes, [2])
        s.endLiveGesture(); s.endEdit()
        XCTAssertEqual(s.project.layers[0].speed, 2)
        s.undo(); XCTAssertEqual(s.project.layers[0], p.layers[0])
    }

    @MainActor func testAllPropertyGraphDragCommitsAsOneUndo() {
        var p = scene()
        for t in [1.0,3] {
            p.layers[0].transform.position.insertKeyframe(Keyframe(time: t,value: Vec2(t,64)))
            p.layers[0].transform.rotation.insertKeyframe(Keyframe(time: t,value: t * 10))
        }
        let s = editor(p)
        s.setEaseAll(segmentAt: 1,interpolation: .bezier,out: .easyOut,into: .easyIn,curve: nil,continuous: true)
        s.setEaseAll(segmentAt: 1,interpolation: .bezier,out: EaseHandle(x: 0.8,y: 0),into: .easyIn,curve: nil,continuous: true)
        s.endEdit(); s.undo(); XCTAssertEqual(s.project.layers[0], p.layers[0])
    }

    @MainActor func testRampKeepsSourceEndpointsAndSmoothSignedVelocity() throws {
        for direction in [1.0,-1] {
            var p = scene(); p.layers[0].sourceStart = direction > 0 ? 2 : 6; p.layers[0].speed = direction
            let s = editor(p); s.currentTime = 3; s.applySpeedRamp()
            let layer = s.project.layers[0], remap = try XCTUnwrap(layer.timeRemap)
            XCTAssertEqual(layer.sourceTime(at: 1), p.layers[0].sourceTime(at: 1), accuracy: 1e-8)
            XCTAssertEqual(layer.sourceTime(at: 5), p.layers[0].sourceTime(at: 5), accuracy: 1e-8)
            for t in stride(from: 1.001, to: 4.999, by: 0.025) { XCTAssertGreaterThan(layer.playbackRate(at: t) * direction, 0) }
            for key in remap.keyframes.dropFirst().dropLast() {
                XCTAssertEqual(layer.playbackRate(at: key.time - 0.0001), layer.playbackRate(at: key.time + 0.0001), accuracy: 0.002)
            }
            XCTAssertLessThan(abs(layer.playbackRate(at: 3)), abs(layer.playbackRate(at: 1.2)))
        }
    }

    @MainActor func testEnableRemapIsNonDestructiveAndGraphChangesActualPlayback() throws {
        let s = editor(scene()); s.enableTimeRemap()
        s.setRemapEase(segment: 0, ease: SavedEase(name: "quad", interpolation: .bezier, out: .easyOut, into: .easyIn, curve: EaseCurve(.quadIn)))
        let remap = s.project.layers[0].timeRemap
        XCTAssertEqual(s.project.layers[0].sourceTime(at: 3), 3, accuracy: 1e-6)
        s.enableTimeRemap(); XCTAssertEqual(s.project.layers[0].timeRemap, remap)
        s.currentTime = 3; s.toggleRemapKey()
        XCTAssertTrue(s.project.layers[0].timeRemap?.hasKeyframe(at: 3) == true)
    }

    @MainActor func testReversePlaybackRoundTripWithTrimAndRemap() throws {
        let s = editor(scene()); let original = s.project.layers[0]
        s.reversePlayback()
        for t in stride(from: 1.1, to: 5, by: 0.1) { XCTAssertEqual(s.project.layers[0].sourceTime(at: t), original.sourceTime(at: 6-t), accuracy: 1e-8) }
        s.reversePlayback(); XCTAssertEqual(s.project.layers[0], original)
        s.enableTimeRemap(); s.currentTime = 3; s.applySpeedRamp()
        let mapped = s.project.layers[0]
        s.reversePlayback()
        for t in stride(from: 1.1, to: 5, by: 0.1) { XCTAssertEqual(s.project.layers[0].sourceTime(at: t), mapped.sourceTime(at: 6-t), accuracy: 1e-6) }
        s.reversePlayback()
        for t in stride(from: 1.1, to: 5, by: 0.1) { XCTAssertEqual(s.project.layers[0].sourceTime(at: t), mapped.sourceTime(at: t), accuracy: 1e-6) }
    }

    @MainActor func testDisableRemapKeepsReverseEndpointsAndFrozenClipCanResume() {
        let s = editor(scene()); s.reversePlayback(); s.enableTimeRemap()
        let before = s.project.layers[0]; s.disableTimeRemap()
        XCTAssertEqual(s.project.layers[0].sourceTime(at: 1), before.sourceTime(at: 1))
        XCTAssertEqual(s.project.layers[0].sourceTime(at: 5), before.sourceTime(at: 5))
        s.enableTimeRemap(); s.project.layers[0].timeRemap = Animated(2)
        s.disableTimeRemap(); XCTAssertEqual(s.project.layers[0].speed, 0)
        s.setLayerSpeed(1); XCTAssertEqual(s.project.layers[0].speed, 1)
    }

    @MainActor func testExtendingTrimBeforeFirstSourceFrameKeepsExistingFrames() {
        var p = scene(); p.layers[0].inPoint = 2; p.layers[0].sourceStart = 0
        let s = editor(p); s.trimClip(p.layers[0], start: true, by: -1)
        XCTAssertEqual(s.project.layers[0].inPoint, 1)
        for t in [2.0,3,4] { XCTAssertEqual(s.project.layers[0].sourceTime(at: t), p.layers[0].sourceTime(at: t)) }
    }

    @MainActor func testGraphHandleUsesStartAndTranslationAndReversedCurvePreviewMatches() {
        let handle = EaseHandle(x: 0.3, y: 0.6), box = CGRect(x: 24,y: 20,width: 200,height: 100)
        XCTAssertEqual(CurveEditor.translated(handle, by: .zero, box: box), handle)
        let moved = CurveEditor.translated(handle, by: CGSize(width: 20,height: 10), box: box)
        XCTAssertEqual(moved.x, 0.4, accuracy: 1e-9); XCTAssertEqual(moved.y, 0.5, accuracy: 1e-9)
        let curve = EaseCurve(.elasticOut)
        let ease = SavedEase(name: "reverse", interpolation: .bezier, out: .easyOut, into: .easyIn, curve: curve, reversedSegment: true)
        XCTAssertEqual(ease.progress(0.4), 1 - curve.progress(0.6), accuracy: 1e-9)
        let linear = SavedEase(name: "linear", interpolation: .linear, out: .linearOut, into: .linearIn, curve: nil)
        XCTAssertEqual(linear.velocity(at: 0.4, valueDelta: -4, duration: 2), -2, accuracy: 1e-6)
    }

    func testAddingRemapKeysPreservesBezierAndWindowedMathCurves() throws {
        for math in [nil, EaseCurve(.quadIn), EaseCurve(.elasticOut)] {
            var original = Animated(2.0)
            original.insertKeyframe(Keyframe(time: 0,value: 2,interpolation: .bezier,easeOut: EaseHandle(x: 0.2,y: -0.1)))
            original.insertKeyframe(Keyframe(time: 4,value: 10,easeIn: EaseHandle(x: 0.7,y: 1.2)))
            original.keyframes[0].curve = math
            for reverse in [false,true] {
                var reference = original
                if reverse { reference.reverseKeys(around: 4) }
                var split = reference; split.insertSampledKey(at: 1.25); split.insertSampledKey(at: 2.75)
                let decoded = try JSONDecoder().decode(Animated<Double>.self, from: JSONEncoder().encode(split))
                for t in stride(from: 0.0,through: 4,by: 0.025) {
                    XCTAssertEqual(decoded.value(at: t), reference.value(at: t), accuracy: 0.0001)
                }
            }
        }
    }

    @MainActor func testVelocityUsesSelectedPropertyAndReadsExistingValues() throws {
        var p = scene()
        for t in [1.0,3,5] {
            p.layers[0].transform.position.insertKeyframe(Keyframe(time: t,value: Vec2(t,64)))
            p.layers[0].transform.positionZ.insertKeyframe(Keyframe(time: t,value: t))
            p.layers[0].transform.rotation.insertKeyframe(Keyframe(time: t,value: t * 10))
        }
        let s = editor(p); s.currentTime = 3
        s.applyKeyframeVelocity(inInfluence: 0.7,inSpeed: 0.2,outInfluence: 0.8,outSpeed: 0.3,property: .position)
        XCTAssertEqual(s.project.layers[0].transform.rotation, p.layers[0].transform.rotation)
        let values = try XCTUnwrap(s.keyframeVelocity(property: .position))
        XCTAssertEqual(values.inInfluence, 0.7, accuracy: 1e-8); XCTAssertEqual(values.inSpeed, 0.2, accuracy: 1e-8)
        XCTAssertEqual(values.outInfluence, 0.8, accuracy: 1e-8); XCTAssertEqual(values.outSpeed, 0.3, accuracy: 1e-8)
        XCTAssertEqual(s.project.layers[0].transform.positionZ.keyframes[1].easeOut, s.project.layers[0].transform.position.keyframes[1].easeOut)
    }

    func testFreezeMovesWithTimingAndOldCurvesStillDecode() throws {
        var layer = scene().layers[0]; layer.timeFX = LayerTimeFX(); layer.timeFX?.freezeAt = 2
        layer.shiftTiming(by: 1,duration: 6); XCTAssertEqual(layer.timeFX?.freezeAt, 3)
        var traversal = AnimationTraversal(operation: .scaleTime(2,0.5)); layer.traverseAnimations(&traversal)
        XCTAssertEqual(layer.timeFX?.freezeAt, 2.5)
        let curve = try JSONDecoder().decode(EaseCurve.self, from: Data("{\"kind\":\"quadIn\",\"a\":0,\"b\":0}".utf8))
        XCTAssertNil(curve.window); XCTAssertEqual(curve.progress(0.5), 0.25)
    }

    @MainActor func testUnlinkFromAnimatedNullPreservesInheritedXYZMotion() throws {
        var p = scene(); p.layers[0].content = .solid
        var parent = p.makeLayer(name: "Null", content: .solid, size: Vec2(1,1)); parent.isNull = true
        parent.transform.position.insertKeyframe(Keyframe(time: 0,value: Vec2(20,30)))
        parent.transform.position.insertKeyframe(Keyframe(time: 6,value: Vec2(80,90)))
        parent.transform.rotation.insertKeyframe(Keyframe(time: 0,value: 0))
        parent.transform.rotation.insertKeyframe(Keyframe(time: 6,value: 90))
        parent.transform.positionZ.insertKeyframe(Keyframe(time: 0,value: 0))
        parent.transform.positionZ.insertKeyframe(Keyframe(time: 6,value: 200))
        p.layers[0].parentID = parent.id; p.layers.append(parent)
        let s = editor(p); s.currentTime = 2; s.setParent(nil)
        XCTAssertNil(s.project.layers[0].parentID)
        for frame in 30...150 {
            let t = Double(frame) / 30
            let expected = Renderer.resolveParenting(p, time: t).layers[0].transform, actual = s.project.layers[0].transform
            XCTAssertEqual(actual.position.value(at: t).x, expected.position.value(at: t).x, accuracy: 1e-6)
            XCTAssertEqual(actual.position.value(at: t).y, expected.position.value(at: t).y, accuracy: 1e-6)
            XCTAssertEqual(actual.positionZ.value(at: t), expected.positionZ.value(at: t), accuracy: 1e-6)
            XCTAssertEqual(actual.rotation.value(at: t), expected.rotation.value(at: t), accuracy: 1e-6)
        }
        s.undo(); XCTAssertEqual(s.project.layers, p.layers)
    }

    func testNullTransformEffectCarriesChildRotationAndScaleAsWellAsPosition() throws {
        var p = scene(); p.layers[0].content = .solid
        var parent = p.makeLayer(name: "Null",content: .solid,size: Vec2(1,1)); parent.isNull = true
        var effect = EffectRegistry.transformFX18.makeInstance()
        effect.params["rotation"] = .number(Animated(90)); effect.params["scale"] = .number(Animated(200))
        parent.effects = [effect]
        p.layers[0].parentID = parent.id; p.layers[0].transform.position = Animated(Vec2(10,0)); p.layers.append(parent)
        let child = Renderer.resolveParenting(p,time: 2).layers[0]
        XCTAssertEqual(child.transform.rotation.value(at: 2),90,accuracy: 1e-8)
        XCTAssertEqual(child.transform.scale.value(at: 2),Vec2(200,200))
        XCTAssertEqual(child.transform.position.value(at: 2).x,64,accuracy: 1e-8)
        XCTAssertEqual(child.transform.position.value(at: 2).y,84,accuracy: 1e-8)
    }

    @MainActor func testLinkedCameraDragPreservesWorldDirectionAndPairsXYZKeys() throws {
        var p = scene(); p.layers[0].content = .camera; p.layers[0].camera = CameraOptions(); p.layers[0].camera?.affects2D = true
        p.layers[0].transform.position = Animated(Vec2(64,64))
        p.layers[0].transform.positionZ = Animated(-CameraState.defaultZoom(p))
        var parent = p.makeLayer(name: "Null", content: .solid,size: Vec2(1,1)); parent.isNull = true
        parent.transform.rotation = Animated(90); parent.transform.scale = Animated(Vec2(150,150)); p.layers.append(parent)
        let s = editor(p); s.currentTime = 2; s.setParent(parent.id)
        let before = Renderer.resolveParenting(s.project, time: 2).layers[0].transform.position.value(at: 2)
        s.toggleKeyframe(.position); s.currentTime = 3
        let drag = try XCTUnwrap(s.beginCameraGesture()); s.updateCameraDrag(drag, delta: Vec2(10,0)); s.endCameraGesture()
        let after = Renderer.resolveParenting(s.project, time: 3).layers[0].transform.position.value(at: 3)
        XCTAssertEqual(after.x, before.x - 10, accuracy: 0.1); XCTAssertEqual(after.y, before.y, accuracy: 0.1)
        XCTAssertEqual(s.project.layers[0].transform.position.keyframeTimes, s.project.layers[0].transform.positionZ.keyframeTimes)
    }

    func testFullSpinProducesMotionBlurEvenWithMatchingShutterEndpoints() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("Metal unavailable") }
        var p = Project.new(name: "spin",width: 128,height: 128,fps: 1,duration: 2,background: RGBA(0,0,0,0))
        var l = p.makeLayer(name: "bar",content: .solid,size: Vec2(4,30)); l.fill = Animated(.white); l.motionBlur = true
        l.transform.rotation.insertKeyframe(Keyframe(time: 0,value: -180))
        l.transform.rotation.insertKeyframe(Keyframe(time: 1,value: 180)); p.layers = [l]
        p.smoothMotion = false; p.shutterAngle = 360; p.blurSamples = 32
        func pixels() throws -> [UInt8] { try XCTUnwrap(renderer.renderPixels(project: p,time: 0.5,preserveAlpha: true,mediaURL: { URL(fileURLWithPath: $0) })).rgba }
        p.motionBlurEnabled = false; let sharp = try pixels()
        p.motionBlurEnabled = true; let blurred = try pixels()
        func coverage(_ rgba: [UInt8]) -> Int { stride(from: 3,to: rgba.count,by: 4).filter { rgba[$0] > 8 }.count }
        XCTAssertGreaterThan(coverage(blurred), coverage(sharp) * 2)
    }
}
