import XCTest
import UIKit
import simd
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

@MainActor
final class AdvancedAuthoringRenderTests: XCTestCase {
    func testWeightedMeshMotionArtifactAndShutterDeformation() throws {
        var p = Project.new(name: "Flexible strip — editable weights",width: 400,height: 400,fps: 12,duration: 2,background: RGBA(0,0,0,0))
        var art = p.makeLayer(name: "Flexible artwork",content: .solid,size: Vec2(240,40))
        art.fill = Animated(RGBA(0.15,0.8,0.95,1)); p.layers = [art]
        let s = EditorState(project: p,store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        let upper = try XCTUnwrap(s.addBone(artworkID: art.id,parentID: nil,start: Vec2(-120,0),end: .zero))
        let lower = try XCTUnwrap(s.addBone(artworkID: art.id,parentID: upper,start: .zero,end: Vec2(120,0)))
        s.select(lower); s.bindBoneMesh()
        let li = try XCTUnwrap(s.project.layers.firstIndex { $0.id == lower })
        s.project.layers[li].transform.rotation.insertKeyframe(Keyframe(time: 0,value: 0,interpolation: .linear))
        s.project.layers[li].transform.rotation.insertKeyframe(Keyframe(time: 1,value: 110,interpolation: .linear))
        s.project.layers[li].transform.rotation.insertKeyframe(Keyframe(time: 2,value: 0,interpolation: .linear))
        let copy = try JSONDecoder().decode(Project.self,from: JSONEncoder().encode(s.project))
        let renderer = try XCTUnwrap(Renderer.shared)
        let a = try XCTUnwrap(renderer.renderPixels(project: copy,time: 0,preserveAlpha: true,mediaURL: { URL(fileURLWithPath: $0) }))
        let b = try XCTUnwrap(renderer.renderPixels(project: copy,time: 1,preserveAlpha: true,mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertNotEqual(a.rgba,b.rgba,"Stationary artwork must deform from bone motion")
        var blurred = copy; blurred.motionBlurEnabled = true; blurred.shutterAngle = 360; blurred.blurSamples = 12
        let ai = try XCTUnwrap(blurred.layers.firstIndex { $0.id == art.id }); blurred.layers[ai].motionBlur = true
        let sharp = try XCTUnwrap(renderer.renderPixels(project: copy,time: 0.5,preserveAlpha: true,mediaURL: { URL(fileURLWithPath: $0) }))
        let soft = try XCTUnwrap(renderer.renderPixels(project: blurred,time: 0.5,preserveAlpha: true,mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertNotEqual(sharp.rgba,soft.rgba,"Bone deformation needs shutter samples even when the layer matrix does not move")
        func alphaMass(_ pixels: [UInt8]) -> Double { stride(from: 3,to: pixels.count,by: 4).reduce(0.0) { $0+Double(pixels[$1])/255 } }
        XCTAssertEqual(alphaMass(soft.rgba)/alphaMass(sharp.rgba),1,accuracy: 0.08,"Shutter averaging must preserve opacity")
        let folder = URL(fileURLWithPath: "/tmp/awi-authoring",isDirectory: true)
        try FileManager.default.createDirectory(at: folder,withIntermediateDirectories: true)
        try JSONEncoder().encode(copy).write(to: folder.appendingPathComponent("weighted-strip.json"))
        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent("weighted-strip.gif") as CFURL,UTType.gif.identifier as CFString,48,nil))
        CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<48 {
            let image = try XCTUnwrap(renderer.renderImage(project: copy,time: Double(frame)/24,maxDimension: 360,mediaURL: { URL(fileURLWithPath: $0) }))
            CGImageDestinationAddImage(gif,try XCTUnwrap(image.cgImage),[kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0/24]] as CFDictionary)
            if frame%12 == 0 { try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("mesh-\(frame).png")) }
        }
        XCTAssertTrue(CGImageDestinationFinalize(gif))
    }

    func testEditableLetterPoseMotionArtifact() throws {
        var project = Project.new(name: "Letters — editable fan pose", width: 600, height: 600, fps: 30, duration: 2)
        var layer = project.makeLayer(name: "HELLO", content: .text, size: Vec2(500, 200))
        var text = TextData(string: "HELLO")
        text.fontSize = 100; text.ensureCharIDs()
        let layout = TextEngine.shared.layout(text, time: 0)
        for (index, id) in text.resolvedCharIDs.enumerated() {
            guard let glyph = layout.glyphs.first(where: { $0.charIndex == index }) else { continue }
            let i = TextStudioLogic.ensureSelectionAnimator(&text, ids: [id])
            let angle = Double(index - 2) * 25
            let target = Vec2(Double(index - 2) * 65, -120 + abs(Double(index - 2)) * 35)
            var position = Animated(Vec2.zero)
            position.insertKeyframe(Keyframe(time: 0, value: .zero, interpolation: .linear))
            position.insertKeyframe(Keyframe(time: 1, value: target - glyph.center, interpolation: .linear))
            position.insertKeyframe(Keyframe(time: 2, value: .zero, interpolation: .linear))
            text.animators[i].properties.position = position
            var rotation = Animated(0.0)
            rotation.insertKeyframe(Keyframe(time: 0, value: 0, interpolation: .linear))
            rotation.insertKeyframe(Keyframe(time: 1, value: angle, interpolation: .linear))
            rotation.insertKeyframe(Keyframe(time: 2, value: 0, interpolation: .linear))
            text.animators[i].properties.rotation = rotation
        }
        layer.text = text; project.layers = [layer]
        let folder = URL(fileURLWithPath: "/tmp/awi-authoring", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(project).write(to: folder.appendingPathComponent("letter-fan.json"))
        let renderer = try XCTUnwrap(Renderer.shared)
        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent("letter-fan.gif") as CFURL, UTType.gif.identifier as CFString, 60, nil))
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<60 {
            let image = try XCTUnwrap(renderer.renderImage(project: project, time: Double(frame) / 30, maxDimension: 360, mediaURL: { URL(fileURLWithPath: $0) }))
            CGImageDestinationAddImage(gif, try XCTUnwrap(image.cgImage), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 30]] as CFDictionary)
            if frame % 15 == 0 { try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("letters-\(frame).png")) }
        }
        XCTAssertTrue(CGImageDestinationFinalize(gif))
    }

    func testEditableRigMotionRenderAndRoundTrip() throws {
        var p = Project.new(name: "Sideways arm — editable IK", width: 600, height: 600, fps: 30, duration: 2)
        var upper = p.makeLayer(name: "Upper arm", content: .solid, size: Vec2(130, 34))
        upper.transform.position = Animated(Vec2(160, 300))
        upper.transform.anchor = Animated(Vec2(-65, 0))
        upper.fill = Animated(RGBA(0.5, 0.25, 0.95, 1))
        var lower = p.makeLayer(name: "Forearm", content: .solid, size: Vec2(120, 30))
        lower.transform.position = Animated(Vec2(290, 300))
        lower.transform.anchor = Animated(Vec2(-60, 0))
        lower.fill = Animated(RGBA(0.2, 0.8, 0.75, 1))
        p.layers = [lower, upper]
        let state = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        state.select(lower.id)
        state.ikDraftTip = (lower.id, Vec2(60, 0))
        state.makeIK(upper: upper.id, controller: nil)
        let rig = try XCTUnwrap(state.project.layers.first { $0.id == lower.id }?.ik)
        let ci = try XCTUnwrap(state.project.layers.firstIndex { $0.id == rig.controllerID })
        state.project.layers[ci].transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(410, 300), interpolation: .linear))
        state.project.layers[ci].transform.position.insertKeyframe(Keyframe(time: 1, value: Vec2(260, 150), interpolation: .linear))
        state.project.layers[ci].transform.position.insertKeyframe(Keyframe(time: 2, value: Vec2(410, 300), interpolation: .linear))
        let copy = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(state.project))
        XCTAssertEqual(copy.layers.first { $0.id == lower.id }?.ik, rig)
        let renderer = try XCTUnwrap(Renderer.shared)
        let folder = URL(fileURLWithPath: "/tmp/awi-authoring", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(copy).write(to: folder.appendingPathComponent("sideways-arm.json"))
        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent("sideways-arm.gif") as CFURL, UTType.gif.identifier as CFString, 60, nil))
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<60 {
            let time = Double(frame) / 30
            let resolved = Renderer.resolveParenting(copy, time: time)
            let limb = try XCTUnwrap(resolved.layers.first { $0.id == lower.id })
            let endpoint = Renderer.layerMatrix(limb, time: time, renderScale: 1) * SIMD3(60.0, 0, 1)
            let target = copy.layers[ci].transform.position.value(at: time)
            XCTAssertEqual(endpoint.x, target.x, accuracy: 1e-5)
            XCTAssertEqual(endpoint.y, target.y, accuracy: 1e-5)
            let image = try XCTUnwrap(renderer.renderImage(project: copy, time: time, maxDimension: 360, mediaURL: { URL(fileURLWithPath: $0) }))
            CGImageDestinationAddImage(gif, try XCTUnwrap(image.cgImage), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 30]] as CFDictionary)
            if frame % 15 == 0 { try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("arm-\(frame).png")) }
        }
        XCTAssertTrue(CGImageDestinationFinalize(gif))
    }
}
