import XCTest

final class AnimationTimingUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting", "-uiTesting-animationTiming"]
        app.launch(); return app
    }

    func testTimeRemapEditorEditsSourceAndUsesSharedGraph() {
        let app = launch()
        let remap = app.buttons["Time Remap"].firstMatch
        XCTAssertTrue(remap.waitForExistence(timeout: 15))
        let scroll = app.scrollViews["clip-settings-scroll"].firstMatch
        for _ in 0..<4 { if remap.isHittable { break }; scroll.swipeUp() }
        remap.tap()
        let key = app.buttons["Toggle source time keyframe"].firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 8)); key.tap()
        XCTAssertTrue(app.buttons["1.000s → 1.000s"].waitForExistence(timeout: 3))
        let source = app.descendants(matching: .any)["number-Source seconds"].firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 3)); source.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "2\n")
        XCTAssertTrue(app.buttons["1.000s → 2.000s"].waitForExistence(timeout: 5))
        let point = app.descendants(matching: .any)["Source key at 1.000 seconds"].firstMatch
        XCTAssertTrue(point.exists)
        let center = point.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        center.press(forDuration: 0.1,thenDragTo: center.withOffset(CGVector(dx: 0,dy: -20)))
        XCTAssertFalse(app.buttons["1.000s → 2.000s"].exists, "Dragging the source key must edit its value, not scroll the sheet")
        save("remap-value")
        app.buttons["Playback Speed"].firstMatch.tap(); save("remap-speed")
        let easing = app.buttons["Edit Segment Easing"].firstMatch
        if !easing.isHittable { app.scrollViews.firstMatch.swipeUp() }
        easing.tap()
        XCTAssertTrue(app.staticTexts["Graph"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Time Remap"].firstMatch.exists)
        save("remap-easing")
    }

    func testExistingKeyframeMoverMovesSelectionAsOneBlock() {
        let app = launch()
        let options = app.buttons["Layer Options"].firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 15)); options.tap()
        let mover = app.buttons["Move Keyframes…"].firstMatch
        XCTAssertTrue(mover.waitForExistence(timeout: 5)); mover.tap()
        let all = app.buttons["Select All"].firstMatch
        XCTAssertTrue(all.waitForExistence(timeout: 5)); all.tap()
        app.buttons["To Playhead"].firstMatch.tap()
        XCTAssertTrue(app.buttons["1.000 s"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["3.000 s"].exists)
        save("keyframe-selection")
    }

    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/timing-\(name).png"))
    }
}
