import XCTest

final class PremadeBrowserUITests:XCTestCase {
    func testNewTextCatalogFitsAndShowsEditableKinds() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["-uiTesting"];app.launch()
        func tap(_ label:String) {
            let button=app.buttons[label].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout:15),label);button.tap()
        }
        tap("Create New Project");tap("Create from scratch");tap("Text");tap("Done Typing")
        tap("Text Studio Tab Presets")
        XCTAssertTrue(app.buttons["Baseline Focus"].firstMatch.waitForExistence(timeout:15))
        save("premades33-animations")
        tap("Baseline Focus")
        save("premades33-selected-motion")
        tap("Look")
        XCTAssertTrue(app.buttons["Heavy Manga Sound"].firstMatch.waitForExistence(timeout:15))
        save("premades33-looks")
        XCTAssertEqual(app.state,.runningForeground)
    }
    private func save(_ name:String) {
        let screenshot=XCUIScreen.main.screenshot()
        let attachment=XCTAttachment(screenshot:screenshot);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
        try? FileManager.default.createDirectory(atPath:"/tmp/awi-ui",withIntermediateDirectories:true)
        try? screenshot.pngRepresentation.write(to:URL(fileURLWithPath:"/tmp/awi-ui/\(name).png"))
    }
}
