import XCTest

final class RigAuthoringUITests: XCTestCase {
    func testPoseOriginDragMovesTheJointWithoutEnteringRestMode() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting","-uiTesting-rigAuthoring","-uiTesting-boneAuthoring"]; app.launch()
        let draw = app.buttons["Draw Bones"].firstMatch; XCTAssertTrue(draw.waitForExistence(timeout: 15)); draw.tap()
        let canvas = app.descendants(matching: .any)["Draw connected bones"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35,dy: 0.5)).press(forDuration: 0.1,thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65,dy: 0.5)))
        app.buttons["Done"].firstMatch.tap()
        let head = app.descendants(matching: .any)["Select Bone 1"].firstMatch
        XCTAssertTrue(head.waitForExistence(timeout: 5))
        let before = head.frame.midX
        let point = head.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        point.press(forDuration: 0.1,thenDragTo: point.withOffset(CGVector(dx: 35,dy: -15)))
        XCTAssertGreaterThan(head.frame.midX,before+5)
        XCTAssertTrue(app.staticTexts["Joint origin · parent X/Y"].firstMatch.exists)
        let image = XCUIScreen.main.screenshot(); let attachment = XCTAttachment(screenshot: image)
        attachment.name = "joint-origin-pose"; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui",withIntermediateDirectories: true)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/joint-origin-pose.png"))
    }

    func testPieceControllerShowsArtworkBindingInsteadOfAnEmptyWeightPanel() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting","-uiTesting-rigAuthoring","-uiTesting-pieceWeight"]; app.launch()
        let bind = app.buttons["Bind Mesh"].firstMatch
        XCTAssertTrue(bind.waitForExistence(timeout: 15))
        for _ in 0..<6 where !bind.isHittable { app.scrollViews["bone-weight-panel-scroll"].swipeUp() }
        XCTAssertTrue(bind.isHittable); bind.tap()
        XCTAssertTrue(app.buttons["Weights"].firstMatch.waitForExistence(timeout: 5))
        let image = XCUIScreen.main.screenshot(); let attachment = XCTAttachment(screenshot: image)
        attachment.name = "piece-controller-weights"; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui",withIntermediateDirectories: true)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/piece-controller-weights.png"))
    }

    func testWeightBrushEditsTheMeshAndKeepsControlsInPanel() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting","-uiTesting-boneWeights"]; app.launch()
        let canvas = app.descendants(matching: .any)["Paint bone weights"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 15))
        let before = canvas.value as? String
        let point = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        point.press(forDuration: 0.1,thenDragTo: point.withOffset(CGVector(dx: 40,dy: 0)))
        XCTAssertNotEqual(canvas.value as? String,before,"Erasing a bound influence must change actual mesh weights")
        XCTAssertTrue(app.buttons["Done"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Draw Bones"].firstMatch.exists)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = "weight-brush-panel"; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui",withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/weight-brush-panel.png"))
    }

    func testSelectEarlierBoneAndBranchWithoutLeavingAuthoringPanel() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting","-uiTesting-rigAuthoring","-uiTesting-boneAuthoring"]; app.launch()
        let draw = app.buttons["Draw Bones"].firstMatch; XCTAssertTrue(draw.waitForExistence(timeout: 15)); draw.tap()
        let canvas = app.descendants(matching: .any)["Draw connected bones"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35,dy: 0.5)).press(forDuration: 0.1,thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5)))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5)).press(forDuration: 0.1,thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65,dy: 0.6)))
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Bone hierarchy"].firstMatch.tap()
        let first = app.buttons["Select bone Bone 1"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5)); first.tap()
        let branch = app.buttons["Branch"].firstMatch; XCTAssertTrue(branch.waitForExistence(timeout: 5)); branch.tap()
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5)).press(forDuration: 0.1,thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65,dy: 0.35)))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Select bone Bone 3"].firstMatch.waitForExistence(timeout: 5))
        let image = XCUIScreen.main.screenshot(); let attachment = XCTAttachment(screenshot: image)
        attachment.name = "branch-earlier-joint"; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui",withIntermediateDirectories: true)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/branch-earlier-joint.png"))
    }

    func testDrawConnectedBoneChainAndPoseItOnCanvas() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-rigAuthoring", "-uiTesting-boneAuthoring"]
        app.launch()
        let draw = app.buttons["Draw Bones"].firstMatch
        XCTAssertTrue(draw.waitForExistence(timeout: 15)); draw.tap()
        let canvas = app.descendants(matching: .any)["Draw connected bones"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let a = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45))
        let b = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.45))
        let c = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7))
        a.press(forDuration: 0.1, thenDragTo: b)
        b.press(forDuration: 0.1, thenDragTo: c)
        app.buttons["Done"].firstMatch.tap()
        let tip = app.descendants(matching: .any)["Pose Bone 2"].firstMatch
        XCTAssertTrue(tip.waitForExistence(timeout: 5))
        let before = tip.value as? String
        let handle = tip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: 35, dy: -15)))
        XCTAssertNotEqual(tip.value as? String, before)
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = "bone-chain-authoring"; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/bone-chain-authoring.png"))
    }

    func testRigPrecisionPadPositionsRestEndpointWithoutMovingArtwork() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-rigAuthoring"]
        app.launch()
        let pad = app.descendants(matching: .any)["rig-position-swipe-pad"].firstMatch
        XCTAssertTrue(pad.waitForExistence(timeout: 15), "The native X/Y SwipePad belongs in Rig")
        for _ in 0..<4 where !pad.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(pad.isHittable, "Precision pad must be reachable within the tool panel")
        let endpoint = app.descendants(matching: .any)["Limb end joint"].firstMatch
        XCTAssertTrue(endpoint.waitForExistence(timeout: 5))
        let before = endpoint.value as? String
        let origin = pad.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: 80, dy: -30)))
        XCTAssertNotEqual(endpoint.value as? String, before, "Swipe pad must move the selected rest joint")
        XCTAssertTrue(app.buttons["Make IK"].firstMatch.exists, "Rest editing remains in Rig, not in a separate studio")
    }

    func testLettersRotateDirectlyWithoutOpeningAnotherPanel() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-letterAuthoring"]
        app.launch()
        let handle = app.descendants(matching: .any)["Rotate selected letters"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 15))
        XCTAssertGreaterThanOrEqual(handle.frame.width, 44)
        let before = handle.value as? String
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 45, dy: 15)))
        XCTAssertNotEqual(handle.value as? String, before)
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = "letter-authoring-direct-rotation"; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/letter-authoring-direct-rotation.png"))
    }

    func testEndpointBindingAndDirectTargetAreOnCanvas() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-rigAuthoring"]
        app.launch()
        let endpoint = app.descendants(matching: .any)["Limb end joint"].firstMatch
        XCTAssertTrue(endpoint.waitForExistence(timeout: 15))
        XCTAssertGreaterThanOrEqual(endpoint.frame.width, 44)
        XCTAssertLessThanOrEqual(endpoint.frame.width, 45)
        XCTAssertLessThanOrEqual(endpoint.frame.height, 45)
        let originalTip = endpoint.value as? String
        let start = endpoint.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 34, dy: -15)))
        XCTAssertNotEqual(endpoint.value as? String, originalTip, "Dragging the joint must edit its rest point, not move or deselect the image")
        let makeIK = app.buttons["Make IK"].firstMatch
        for _ in 0..<5 where !makeIK.exists || !makeIK.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(makeIK.exists)
        makeIK.tap()
        let target = app.descendants(matching: .any)["Pose Forearm Controller"].firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertFalse(endpoint.exists)
        XCTAssertGreaterThanOrEqual(target.frame.width, 44)
        XCTAssertLessThanOrEqual(target.frame.width, 45)
        XCTAssertLessThanOrEqual(target.frame.height, 45)
        let before = target.value as? String
        let hand = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        hand.press(forDuration: 0.1, thenDragTo: hand.withOffset(CGVector(dx: -30, dy: 25)))
        XCTAssertNotEqual(target.value as? String, before, "Direct posing must move the target")
        XCTAssertTrue(app.buttons["Remove IK"].firstMatch.exists, "Posing must keep the existing Rig panel available")
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = "rig-authoring-direct-pose"; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/rig-authoring-direct-pose.png"))
    }
}
