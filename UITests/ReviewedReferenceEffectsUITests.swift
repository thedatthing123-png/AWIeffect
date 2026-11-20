import XCTest

final class ReviewedReferenceEffectsUITests: XCTestCase {
    func testReviewedTransitionAndCustomPalettePanels() {
        continueAfterFailure = false
        for palette in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting", "-uiTesting-referenceEffect"] + (palette ? ["-uiTesting-referencePalette"] : [])
            app.launch()
            let id = palette ? "awi.amref.e658cad5dcbff" : "awi.amref.eeab7e403ece5"
            XCTAssertTrue(app.buttons["effect-expand-" + id].firstMatch.waitForExistence(timeout: 15))
            let shot = XCUIScreen.main.screenshot()
            let name = palette ? "reviewed-custom-palette" : "reviewed-tile-break"
            let attachment = XCTAttachment(screenshot: shot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/\(name).png"))
            app.terminate()
        }
    }
}
