import XCTest

final class RigAuthoringUITests: XCTestCase {
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
        let before = target.frame
        let hand = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        hand.press(forDuration: 0.1, thenDragTo: hand.withOffset(CGVector(dx: -30, dy: 25)))
        XCTAssertNotEqual(target.frame.origin.x, before.origin.x, "Direct posing must move the target")
        XCTAssertTrue(app.buttons["Remove IK"].firstMatch.exists, "Posing must keep the existing Rig panel available")
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = "rig-authoring-direct-pose"; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/rig-authoring-direct-pose.png"))
    }
}
