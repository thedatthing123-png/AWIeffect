import XCTest
import UIKit
import simd
@testable import AWIeffect

final class SceneFinishTests: XCTestCase {
    @MainActor
    func testFramingHoldsOnTiltedCardAndCameraMoveReusesLens() throws {
        var project = Project.new(name: "Framing", width: 480, height: 320, fps: 30, duration: 4)
        var camera = project.makeLayer(name: "Shot Camera", content: .camera, size: Vec2(1, 1))
        camera.camera = CameraOptions(zoom: Animated(730), focusDistance: Animated(600))
        camera.transform.positionZ = Animated(-690)
        camera.transform.rotationY = Animated(11)
        var card = project.makeLayer(name: "Foreground", content: .solid, size: Vec2(80, 80))
        card.is3D = true
        card.transform.position = Animated(Vec2(315, 136))
        card.transform.rotationX = Animated(26)
        card.transform.anchor = Animated(Vec2(4, -2))
        project.layers = [camera, card]
        let state = EditorState(project: project, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))

        let optics = Renderer.activeCamera(project, time: 0)
        let before = Renderer.placementMatrix(card, camera: optics, time: 0, renderScale: 1)
        state.setSceneDepth(145, for: card.id, keepFraming: true)
        let updated = try XCTUnwrap(state.project.layers.first { $0.id == card.id })
        XCTAssertEqual(updated.transform.positionZ.value(at: 0), 145, accuracy: 1e-8)
        let after = Renderer.placementMatrix(updated, camera: optics, time: 0, renderScale: 1)
        for corner in [Vec2(-40, -40), Vec2(40, -40), Vec2(40, 40), Vec2(-40, 40)] {
            let a = try XCTUnwrap(LayerPlacement.projected(corner, by: before))
            let b = try XCTUnwrap(LayerPlacement.projected(corner, by: after))
            XCTAssertEqual(a.x, b.x, accuracy: 0.01)
            XCTAssertEqual(a.y, b.y, accuracy: 0.01)
        }
        state.keySceneCameraMove(push: 0.24, duration: 1.5, drift: 0.03, roll: 3)
        XCTAssertEqual(state.project.layers.filter { $0.content == .camera }.count, 1)
        let moving = try XCTUnwrap(state.project.layers.first { $0.id == camera.id })
        XCTAssertEqual(moving.camera, camera.camera)
        XCTAssertEqual(moving.transform.positionZ.keyframeTimes, [0, 1.5])
        XCTAssertGreaterThan(moving.transform.positionZ.value(at: 1.5), -690)
        state.undo()
        XCTAssertEqual(state.project.layers.first?.transform, camera.transform)
    }

    @MainActor
    func testRiggedMangaShotRendersAndExports() async throws {
        let renderer = try XCTUnwrap(Renderer.shared)
        let output = try reviewDirectory()
        let artURL = output.appendingPathComponent("arm-source.png")
        try XCTUnwrap(armArtwork().pngData()).write(to: artURL)
        let project = try mangaShot()
        let media: (String) -> URL = { output.appendingPathComponent($0) }
        let initial = try XCTUnwrap(renderer.renderPixels(project: project, time: 0.04, mediaURL: media))
        let bent = try XCTUnwrap(renderer.renderPixels(project: project, time: 1.35, mediaURL: media))
        XCTAssertNotEqual(initial.rgba, bent.rgba)
        var flatLighting = project
        for index in flatLighting.layers.indices { flatLighting.layers[index].light?.castsShadows = false }
        let shadowless = try XCTUnwrap(renderer.renderPixels(project: flatLighting, time: 1.35, mediaURL: media))
        XCTAssertGreaterThan(zip(bent.rgba, shadowless.rgba).filter { abs(Int($0.0) - Int($0.1)) > 3 }.count, 80)
        let saved = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
        let reopened = try XCTUnwrap(renderer.renderPixels(project: saved, time: 1.35, mediaURL: media))
        XCTAssertEqual(reopened.rgba, bent.rgba)
        for (i, time) in [0.25, 0.95, 1.35, 2.35].enumerated() {
            let still = try XCTUnwrap(renderer.renderImage(project: project, time: time, maxDimension: 640, mediaURL: media))
            try XCTUnwrap(still.pngData()).write(to: output.appendingPathComponent("manga-\(i).png"))
        }
        let exported = try await Exporter().export(project: project, settings: ExportSettings(format: .mp4), mediaURL: media) { _ in }
        try FileManager.default.moveItem(at: exported, to: output.appendingPathComponent("manga-scene.mp4"))
    }

    private func reviewDirectory() throws -> URL {
        let url = URL(fileURLWithPath: "/tmp/awi-authoring/scene-finish", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func mangaShot() throws -> Project {
        var scene = Project.new(name: "The last train", width: 480, height: 320, fps: 24, duration: 3,
                                background: RGBA(hex: 0x101019))
        var camera = scene.makeLayer(name: "Camera", content: .camera, size: Vec2(1, 1))
        camera.camera = CameraOptions(zoom: Animated(575), focusDistance: Animated(550))
        camera.transform.positionZ = move([(0, -575.0), (2.85, -450)])
        camera.transform.position = move([(0, Vec2(239, 160)), (2.85, Vec2(253, 151))])
        var ambient = scene.makeLayer(name: "Station ambience", content: .light, size: Vec2(1, 1))
        ambient.light = LightOptions(type: .ambient)
        ambient.light?.color = Animated(RGBA(hex: 0xAC9DBB))
        ambient.light?.intensity = Animated(38)
        var sweep = scene.makeLayer(name: "Train light", content: .light, size: Vec2(1, 1))
        sweep.light = LightOptions(type: .point)
        sweep.transform.position = move([(0, Vec2(20, 109)), (1.2, Vec2(205, 94)), (2.85, Vec2(495, 157))])
        sweep.transform.positionZ = Animated(-210)
        sweep.light?.color = Animated(RGBA(hex: 0xB6DAFF))
        sweep.light?.intensity = move([(0, 42.0), (1.28, 185), (2.85, 62)])
        sweep.light?.falloffRadius = Animated(630)
        sweep.light?.castsShadows = true
        sweep.light?.shadowSpread = Animated(46)
        sweep.light?.shadowDarkness = 78

        var arm = scene.makeLayer(name: "Rigged artwork", content: .image(fileName: "arm-source.png", pixelWidth: 300, pixelHeight: 200),
                                  size: Vec2(270, 180))
        arm.transform.position = Animated(Vec2(253, 175))
        arm.is3D = true
        arm.castsShadows = true
        let shoulder = ArtworkBone(name: "Shoulder", start: Vec2(-97, 10), end: Vec2(-25, 12))
        let forearm = ArtworkBone(name: "Forearm", start: shoulder.end, end: Vec2(63, 12), parentID: shoulder.id)
        var rig = ArtworkRig(bones: [shoulder, forearm])
        rig.bind(halfSize: Vec2(135, 90), artworkID: arm.id, detail: 48, radius: nil, amount: 1)
        XCTAssertTrue(rig.enableIK(on: forearm.id, time: 0))
        rig.editIK(on: forearm.id) { constraint in
            constraint.flipped = false
            constraint.target = move([(0, forearm.end), (1.28, Vec2(15, -65)), (2.35, Vec2(46, -38)), (2.95, Vec2(53, -31))])
        }
        arm.artworkRig = rig
        var cuff = card(&scene, "Rigid cuff", Vec2(12, 44), Vec2(57, 12), 0, 0xA85137)
        cuff.parentID = arm.id
        cuff.artworkRigBoneID = forearm.id
        var title = scene.makeLayer(name: "Chapter title", content: .text, size: Vec2(300, 80))
        title.text = TextData(string: "THE LAST TRAIN", fontSize: 37)
        title.transform.position = Animated(Vec2(239, 268))
        title.text?.style = TextStyleStack(
            fills: [TextFillLayer(colors: [RGBA(hex: 0xF4E8CD)])],
            strokes: [TextStrokeLayer(color: RGBA(hex: 0x17141B), width: 3.5)],
            shadows: [TextShadowLayer(color: RGBA(hex: 0x5C2530), distance: 7, blur: 1)])
        let reveal = try XCTUnwrap(TextPresetLibrary.animation("studio.lineRise"))
        TextPresetLibrary.applyPreset(reveal, to: &title, start: 0.65, duration: 1.3)
        let foreground = card(&scene, "Door frame", Vec2(52, 485), Vec2(32, 160), -95, 0x182032)
        let foregroundEdge = card(&scene, "Door edge", Vec2(4, 485), Vec2(61, 160), -92, 0x697F93)
        let platforms = [
            card(&scene, "Signal stripe", Vec2(720, 5), Vec2(245, 216), 145, 0xA47D5F),
            card(&scene, "Window light", Vec2(166, 126), Vec2(404, 107), 155, 0x7F91A9),
            card(&scene, "Window shadow", Vec2(179, 137), Vec2(404, 107), 159, 0x242533),
            card(&scene, "Station wall", Vec2(880, 580), Vec2(240, 162), 175, 0x74717A)
        ]
        scene.layers = [camera, ambient, sweep, title, foregroundEdge, foreground, cuff, arm] + platforms
        return scene
    }

    private func card(_ scene: inout Project, _ name: String, _ size: Vec2, _ position: Vec2,
                      _ z: Double, _ color: UInt32) -> Layer {
        var layer = scene.makeLayer(name: name, content: .solid, size: size)
        layer.is3D = true
        layer.transform.position = Animated(position)
        layer.transform.positionZ = Animated(z)
        layer.fill = Animated(RGBA(hex: color))
        return layer
    }

    private func move<Value: Interpolatable>(_ keys: [(Double, Value)]) -> Animated<Value> {
        var animation = Animated(keys[0].1)
        for (time, value) in keys { animation.insertKeyframe(Keyframe(time: time, value: value, interpolation: .bezier)) }
        return animation
    }

    private func armArtwork() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200), format: format).image { _ in
            let outline = UIColor(red: 0.12, green: 0.10, blue: 0.16, alpha: 1)
            let contour = UIBezierPath()
            contour.move(to: CGPoint(x: 25, y: 94))
            contour.addQuadCurve(to: CGPoint(x: 118, y: 89), controlPoint: CGPoint(x: 70, y: 73))
            contour.addQuadCurve(to: CGPoint(x: 221, y: 99), controlPoint: CGPoint(x: 154, y: 87))
            contour.addQuadCurve(to: CGPoint(x: 265, y: 90), controlPoint: CGPoint(x: 252, y: 84))
            contour.addQuadCurve(to: CGPoint(x: 272, y: 121), controlPoint: CGPoint(x: 291, y: 101))
            contour.addQuadCurve(to: CGPoint(x: 215, y: 131), controlPoint: CGPoint(x: 250, y: 129))
            contour.addQuadCurve(to: CGPoint(x: 129, y: 141), controlPoint: CGPoint(x: 180, y: 146))
            contour.addQuadCurve(to: CGPoint(x: 26, y: 152), controlPoint: CGPoint(x: 81, y: 154))
            contour.close()
            UIColor(red: 0.91, green: 0.64, blue: 0.49, alpha: 1).setFill()
            contour.fill()
            outline.setStroke()
            contour.lineWidth = 4
            contour.stroke()
            let fabric = UIBezierPath()
            fabric.move(to: CGPoint(x: 25, y: 94))
            fabric.addQuadCurve(to: CGPoint(x: 102, y: 84), controlPoint: CGPoint(x: 62, y: 74))
            fabric.addQuadCurve(to: CGPoint(x: 107, y: 147), controlPoint: CGPoint(x: 92, y: 112))
            fabric.addQuadCurve(to: CGPoint(x: 26, y: 152), controlPoint: CGPoint(x: 58, y: 159))
            fabric.close()
            UIColor(red: 0.25, green: 0.33, blue: 0.47, alpha: 1).setFill()
            fabric.fill()
            fabric.lineWidth = 4
            fabric.stroke()
            for (from, to, mid) in [
                (CGPoint(x: 36, y: 106), CGPoint(x: 92, y: 106), CGPoint(x: 68, y: 94)),
                (CGPoint(x: 115, y: 123), CGPoint(x: 157, y: 114), CGPoint(x: 131, y: 125)),
                (CGPoint(x: 228, y: 111), CGPoint(x: 266, y: 104), CGPoint(x: 249, y: 96)),
                (CGPoint(x: 248, y: 119), CGPoint(x: 275, y: 111), CGPoint(x: 262, y: 119))
            ] {
                let line = UIBezierPath()
                line.move(to: from)
                line.addQuadCurve(to: to, controlPoint: mid)
                line.lineWidth = 2
                line.lineCapStyle = .round
                line.stroke()
            }
        }
    }
}
