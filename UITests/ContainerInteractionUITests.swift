import XCTest

final class ContainerInteractionUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-containerInteractions"]
        app.launch(); return app
    }

    func testGroupShowsOneRowAndOpensItsChildren() {
        let app = launch()
        let group = app.descendants(matching: .any)["timeline-clip-Group Test"].firstMatch
        XCTAssertTrue(group.waitForExistence(timeout: 15))
        XCTAssertFalse(app.otherElements["timeline-row-Inside"].exists)
        group.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 35, dy: 0)).doubleTap()
        XCTAssertTrue(app.otherElements["timeline-row-Inside"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["timeline-row-Outside"].exists)
        save("group-inside")
        let close = app.buttons["Close Group"].firstMatch
        XCTAssertTrue(close.exists); close.tap()
        XCTAssertTrue(app.otherElements["timeline-row-Group Test"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["timeline-row-Inside"].exists)
        save("group-outside")
    }

    func testPositionFieldSelectsPadWithoutExtraButtonsAndNumberStillEdits() {
        let app = launch()
        let outside = app.descendants(matching: .any)["timeline-clip-Outside"].firstMatch
        XCTAssertTrue(outside.waitForExistence(timeout: 15)); outside.tap()
        let transform = app.buttons["Move & Transform"].firstMatch
        XCTAssertTrue(transform.waitForExistence(timeout: 5)); transform.tap()
        let z = app.descendants(matching: .any)["position-field-Z"].firstMatch
        XCTAssertTrue(z.waitForExistence(timeout: 5))
        z.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Swipe to adjust Z position"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        save("position-z-mode")
        let x = app.descendants(matching: .any)["position-field-X"].firstMatch
        x.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Swipe here to move the layer"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["XY"].exists)
        save("position-xy-mode")
        z.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Swipe to adjust Z position"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 3))
    }

    private func save(_ name: String) {
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image); attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/interaction-\(name).png"))
    }
}
