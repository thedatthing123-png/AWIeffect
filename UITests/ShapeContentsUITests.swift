import XCTest

final class ShapeContentsUITests: XCTestCase {
    func testPathListSelectionAndSelectedPen() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-shapeContents"]
        app.launch()
        let ring = app.buttons["Select Ring"].firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 15))
        save("shape-contents-list")
        XCTAssertGreaterThanOrEqual(ring.frame.height, 44)
        let accent = app.buttons["Select Accent"].firstMatch
        XCTAssertTrue(accent.exists); XCTAssertGreaterThanOrEqual(accent.frame.height, 44)
        save("shape-contents-list")
        accent.tap()
        let edit = app.buttons["Edit Points"].firstMatch
        let scroll = app.scrollViews["shape-contents-scroll"].firstMatch
        for _ in 0..<5 { if edit.isHittable { break }; scroll.swipeUp() }
        XCTAssertTrue(edit.isHittable); edit.tap()
        XCTAssertTrue(app.buttons["Done"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.exists)
        save("shape-selected-pen")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Select Accent"].firstMatch.waitForExistence(timeout: 5))
        for page in 0..<7 {
            scroll.swipeUp()
            save("shape-settings-\(page)")
        }
    }

    private func save(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: shot); a.name = name; a.lifetime = .keepAlways; add(a)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/\(name).png"))
    }
}
