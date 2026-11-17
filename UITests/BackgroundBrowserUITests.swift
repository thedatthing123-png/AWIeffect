import XCTest

final class BackgroundBrowserUITests: XCTestCase {
    func testNewBackgroundHasReadableBrowserAndExistingEditableControls() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]; app.launch()
        func tap(_ name: String) {
            let button = app.buttons[name].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 12), name); button.tap()
        }
        func screenshot(_ name: String) throws {
            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot); attachment.lifetime = .keepAlways; add(attachment)
            try FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/\(name).png"))
        }
        tap("Create New Project"); tap("Create from scratch"); tap("Add"); tap("Star")
        tap("Effects"); tap("Add Effect")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap(); search.typeText("Solid Sunburst")
        let effect = app.buttons.containing(.staticText, identifier: "Solid Sunburst").firstMatch
        XCTAssertTrue(effect.waitForExistence(timeout: 10))
        try screenshot("expansion-background-browser")
        effect.tap()
        let wedges = app.descendants(matching: .any)["effect-param-awi30.solidSunburst-scale"].firstMatch
        XCTAssertTrue(wedges.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(wedges.frame.height, 44)
        try screenshot("expansion-sunburst-controls")
    }
}
