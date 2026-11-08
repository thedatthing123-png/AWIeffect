import XCTest

final class StabilityUITests: XCTestCase {
    func testBuild21HeaderControlsAndShortClipLanes() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting", "-uiTesting-stability"]; app.launch()
        let row = app.otherElements["timeline-row-Short Clip"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        let header = app.otherElements["timeline-header-Short Clip"].firstMatch
        XCTAssertTrue(header.buttons["Hide Layer"].exists)
        XCTAssertTrue(header.buttons["Lock Layer"].exists)
        XCTAssertTrue(header.buttons["Solo Layer"].exists)
        XCTAssertEqual(header.frame.width,132,accuracy: 0.5)
        header.buttons["Lock Layer"].tap(); XCTAssertTrue(header.buttons["Unlock Layer"].waitForExistence(timeout: 3))
        header.buttons["Unlock Layer"].tap()
        let expand = row.buttons["Open property lanes"].firstMatch
        XCTAssertTrue(expand.exists)
        let clip = app.descendants(matching: .any)["timeline-clip-Short Clip"].firstMatch
        XCTAssertGreaterThanOrEqual(expand.frame.midX,clip.frame.minX-1)
        XCTAssertLessThanOrEqual(expand.frame.midX,clip.frame.maxX+1)
        save("stability-header-short-clips")
        expand.tap(); XCTAssertTrue(row.buttons["Close property lanes"].waitForExistence(timeout: 3))
        save("stability-expanded-lanes")
        row.buttons["Close property lanes"].tap()
    }
    private func save(_ name: String) {
        let s = XCUIScreen.main.screenshot(), a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/\(name).png"))
    }
}
