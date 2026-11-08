import XCTest

final class InlineToolsUITests: XCTestCase {
    func testRestoredTransportAndInlineRemoveBG() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting", "-uiTesting-cutoutInline"]; app.launch()
        XCTAssertTrue(app.buttons["Auto Remove Background"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Auto Box"].firstMatch.exists)
        app.buttons["Auto Remove Background"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Restore Original"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Restore Original"].firstMatch.tap()
        XCTAssertFalse(app.buttons["Restore Original"].firstMatch.exists)
        for name in ["Undo", "Redo", "View options", "Go to Start", "Previous Frame", "Play", "Next Frame", "Go to End", "Key All", "Loop", "Select Multiple", "Layer Clipboard", "History"] {
            XCTAssertTrue(app.buttons[name].firstMatch.exists, "Missing one-tap transport control: \(name)")
        }
        XCTAssertFalse(app.buttons["Open Cutout Studio"].exists)
        save("inline-transport-header-remove-bg")
        let scroll = app.scrollViews["remove-bg-scroll"]
        for page in 0..<4 { scroll.swipeUp(); save("inline-remove-bg-\(page)") }
    }
    private func save(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: shot); a.name = name; a.lifetime = .keepAlways; add(a)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/\(name).png"))
    }
}
