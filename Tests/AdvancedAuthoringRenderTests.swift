import XCTest
import UIKit
import simd
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

@MainActor
final class AdvancedAuthoringRenderTests: XCTestCase {
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
    func testContinuousArtworkWithFingerBranchesMeshMotionArtifact() throws {
        let folder = URL(fileURLWithPath: "/tmp/awi-authoring",isDirectory: true)
        try FileManager.default.createDirectory(at: folder,withIntermediateDirectories: true)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let artwork = UIGraphicsImageRenderer(size: CGSize(width: 400,height: 400),format: format).image { context in
            let c = context.cgContext
            c.setFillColor(UIColor.systemIndigo.cgColor)
            c.fill(CGRect(x: 55,y: 95,width: 100,height: 240))
            c.setStrokeColor(UIColor.systemTeal.cgColor); c.setLineWidth(36); c.setLineCap(.round); c.setLineJoin(.round)
            c.move(to: CGPoint(x: 150,y: 190)); c.addLine(to: CGPoint(x: 230,y: 190)); c.addLine(to: CGPoint(x: 300,y: 190)); c.strokePath()
            c.setStrokeColor(UIColor.systemYellow.cgColor); c.setLineWidth(8)
            for i in 0..<5 {
                c.move(to: CGPoint(x: 300,y: 190)); c.addLine(to: CGPoint(x: 350,y: CGFloat(160+i*15))); c.strokePath()
            }
        }
        let imageURL = folder.appendingPathComponent("continuous-character.png")
        try XCTUnwrap(artwork.pngData()).write(to: imageURL)
        var p = Project.new(name: "One image - arm and five finger branches",width: 600,height: 600,fps: 30,duration: 2)
        let art = p.makeLayer(name: "Continuous artwork",content: .image(fileName: imageURL.lastPathComponent,pixelWidth: 400,pixelHeight: 400),size: Vec2(400,400))
        p.layers = [art]
        let state = EditorState(project: p,store: ProjectStore(root: folder.appendingPathComponent("mesh-project")))
        let upper = try XCTUnwrap(state.addBone(artworkID: art.id,parentID: nil,start: Vec2(-50,-10),end: Vec2(30,-10)))
        let lower = try XCTUnwrap(state.addBone(artworkID: art.id,parentID: upper,start: .zero,end: Vec2(100,-10)))
        var fingers: [UUID] = []
        for i in 0..<5 {
            fingers.append(try XCTUnwrap(state.addBone(artworkID: art.id,parentID: lower,start: .zero,end: Vec2(150,Double(-40+i*15)))))
        }
        state.selectAuthoringBone(lower); state.meshInfluenceRadius = 42; state.bindBoneMesh()
        let mesh = try XCTUnwrap(state.project.layers.first { $0.id == art.id }?.boneMesh)
        XCTAssertEqual(mesh.boneIDs.count,8)
        for (id,degrees) in [(upper,-25.0),(lower,-65.0)] + fingers.enumerated().map({ ($0.element,Double($0.offset-2)*12) }) {
            let index = try XCTUnwrap(state.project.layers.firstIndex { $0.id == id })
            let rest = state.project.layers[index].transform.rotation.value(at: 0)
            state.project.layers[index].transform.rotation.insertKeyframe(Keyframe(time: 0,value: rest,interpolation: .linear))
            state.project.layers[index].transform.rotation.insertKeyframe(Keyframe(time: 1,value: rest+degrees,interpolation: .linear))
            state.project.layers[index].transform.rotation.insertKeyframe(Keyframe(time: 2,value: rest,interpolation: .linear))
        }
        let copy = try JSONDecoder().decode(Project.self,from: JSONEncoder().encode(state.project))
        try JSONEncoder().encode(copy).write(to: folder.appendingPathComponent("continuous-character.json"))
        let posed = IKSolver.apply(copy,time: 1)
        let palette = try XCTUnwrap(BoneMeshEvaluation.palette(mesh,artworkID: art.id,posed: posed,time: 1))
        for vertex in mesh.vertices where vertex.rest.x < -100 {
            let actual = mesh.deformed(vertex,matrices: palette)
            XCTAssertEqual(actual.x,vertex.rest.x,accuracy: 1e-7); XCTAssertEqual(actual.y,vertex.rest.y,accuracy: 1e-7)
        }
        let renderer = try XCTUnwrap(Renderer.shared)
        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent("continuous-character.gif") as CFURL,UTType.gif.identifier as CFString,60,nil))
        CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        var first: Data?,posedPNG: Data?
        for frame in 0..<60 {
            let image = try XCTUnwrap(renderer.renderImage(project: copy,time: Double(frame)/30,maxDimension: 480,mediaURL: { folder.appendingPathComponent($0) }))
            CGImageDestinationAddImage(gif,try XCTUnwrap(image.cgImage),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
            if frame == 0 { first = image.pngData() }
            if frame == 30 { posedPNG = image.pngData() }
            if frame % 15 == 0 { try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("continuous-\(frame).png")) }
        }
        XCTAssertTrue(CGImageDestinationFinalize(gif)); XCTAssertNotEqual(try XCTUnwrap(first),try XCTUnwrap(posedPNG))
    }

    func testWideTexturedCutoutArmMovesAndBendsAsOneWeightedImage() throws {
        let folder = URL(fileURLWithPath: "/tmp/awi-authoring",isDirectory: true)
        try FileManager.default.createDirectory(at: folder,withIntermediateDirectories: true)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let artImage = UIGraphicsImageRenderer(size: CGSize(width: 400,height: 200),format: format).image { context in
            UIBezierPath(roundedRect: CGRect(x: 10,y: 10,width: 380,height: 180),cornerRadius: 75).addClip()
            for row in 0..<40 {
                UIColor(red: CGFloat(0.5+Double(row)*0.01),green: CGFloat(0.24+Double(row)*0.006),blue: 0.14,alpha: 1).setFill()
                context.fill(CGRect(x: 0,y: CGFloat(row*5),width: 400,height: 5))
            }
            UIColor(white: 1,alpha: 0.25).setStroke()
            for x in stride(from: 20,through: 380,by: 20) {
                let line = UIBezierPath(); line.move(to: CGPoint(x: CGFloat(x),y: 0)); line.addLine(to: CGPoint(x: CGFloat(x),y: 200)); line.lineWidth = 2; line.stroke()
            }
        }
        let url = folder.appendingPathComponent("wide-arm-source.png")
        try XCTUnwrap(artImage.pngData()).write(to: url)
        var p = Project.new(name: "Whole cutout - three bones",width: 640,height: 480,fps: 30,duration: 2)
        let art = p.makeLayer(name: "One wide arm image",content: .image(fileName: url.lastPathComponent,pixelWidth: 400,pixelHeight: 200),size: Vec2(400,200)); p.layers = [art]
        let state = EditorState(project: p,store: ProjectStore(root: folder.appendingPathComponent("wide-arm-project")))
        let root = try XCTUnwrap(state.addBone(artworkID: art.id,parentID: nil,start: Vec2(-170,0),end: Vec2(-50,0)))
        let middle = try XCTUnwrap(state.addBone(artworkID: art.id,parentID: root,start: .zero,end: Vec2(70,0)))
        let end = try XCTUnwrap(state.addBone(artworkID: art.id,parentID: middle,start: .zero,end: Vec2(170,0)))
        state.selectAuthoringBone(root); state.boneMeshCoverage = .wholeArtwork; state.bindBoneMesh()
        for (id,angle) in [(root,25.0),(middle,-70.0),(end,20.0)] {
            let i = try XCTUnwrap(state.project.layers.firstIndex { $0.id == id })
            state.project.layers[i].transform.rotation.insertKeyframe(Keyframe(time: 0,value: 0,interpolation: .linear))
            state.project.layers[i].transform.rotation.insertKeyframe(Keyframe(time: 1,value: angle,interpolation: .linear))
            state.project.layers[i].transform.rotation.insertKeyframe(Keyframe(time: 2,value: 0,interpolation: .linear))
        }
        let ri = try XCTUnwrap(state.project.layers.firstIndex { $0.id == root })
        state.project.layers[ri].transform.position.insertKeyframe(Keyframe(time: 0,value: Vec2(-170,0),interpolation: .linear))
        state.project.layers[ri].transform.position.insertKeyframe(Keyframe(time: 1,value: Vec2(-140,35),interpolation: .linear))
        state.project.layers[ri].transform.position.insertKeyframe(Keyframe(time: 2,value: Vec2(-170,0),interpolation: .linear))
        let copy = try JSONDecoder().decode(Project.self,from: JSONEncoder().encode(state.project))
        try JSONEncoder().encode(copy).write(to: folder.appendingPathComponent("wide-arm.json"))
        let renderer = try XCTUnwrap(Renderer.shared)
        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent("wide-arm.gif") as CFURL,UTType.gif.identifier as CFString,60,nil))
        CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        var first: Data?,posed: Data?
        for frame in 0..<60 {
            let image = try XCTUnwrap(renderer.renderImage(project: copy,time: Double(frame)/30,maxDimension: 480,mediaURL: { folder.appendingPathComponent($0) }))
            CGImageDestinationAddImage(gif,try XCTUnwrap(image.cgImage),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
            if frame == 0 { first = image.pngData() }; if frame == 30 { posed = image.pngData() }
            if frame % 15 == 0 { try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("wide-arm-\(frame).png")) }
        }
        XCTAssertTrue(CGImageDestinationFinalize(gif)); XCTAssertNotEqual(try XCTUnwrap(first),try XCTUnwrap(posed))
    }

}
