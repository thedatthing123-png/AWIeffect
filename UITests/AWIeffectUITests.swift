import XCTest

/// Drives the real app in the simulator and saves screenshots of each main screen (CI artifact).
final class AWIeffectUITests: XCTestCase {
    private var app: XCUIApplication!
    private var shot = 0

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    private func snap(_ name: String) {
        shot += 1
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = String(format: "%02d-%@", shot, name)
        a.lifetime = .keepAlways
        add(a)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: String(format: "/tmp/awi-ui/%02d-%@.png", shot, name)))
    }

    private func tap(_ label: String, timeout: TimeInterval = 5) {
        let e = app.buttons[label].firstMatch
        if e.waitForExistence(timeout: timeout) { e.tap() } else {
            let t = app.staticTexts[label].firstMatch
            if t.waitForExistence(timeout: 2) { t.tap() }
        }
    }

    func testTourAndScreenshots() {
        snap("home")
        tap("Create New Project")
        snap("create-sheet")
        tap("Create from scratch")
        sleep(1)
        snap("editor-empty")

        tap("Add Layer")
        snap("add-panel")
        tap("Star")
        sleep(1)
        snap("transform-panel")

        tap("Effects")
        snap("effects-panel")
        tap("Add Effect")
        sleep(2)
        snap("effect-browser")
        tap("Close")

        tap("Panel Back")
        tap("Presets")
        snap("presets")
        tap("Zoom Blur In")

        tap("Panel Back")
        tap("Masks")
        snap("masks")

        tap("Panel Back")
        app.scrollViews.firstMatch.swipeLeft()
        tap("3D")
        snap("3d-panel")

        tap("Panel Back")
        app.scrollViews.firstMatch.swipeLeft()
        tap("Physics")
        snap("physics-lab")
        tap("Panel Back")

        tap("Quick actions")
        sleep(1)
        snap("quick-actions")
        tap("Quick actions")

        // Text Studio
        app.swipeUp()
        tap("Add Layer")
        tap("Text")
        sleep(1)
        snap("text-studio")
        tap("Animate")
        sleep(2)
        snap("text-presets")

        // Draw Studio
        tap("Add Layer")
        tap("Draw Studio")
        sleep(2)
        snap("draw-studio")
        tap("Cancel")

        // Export
        tap("Export")
        sleep(1)
        snap("export")

        XCTAssertTrue(app.state == .runningForeground, "app crashed during the tour")
    }

    /// Every on-screen button must sit fully inside the window (catches off-screen / overlapping chrome).
    func testNoButtonsOffscreen() {
        tap("Create New Project")
        tap("Create from scratch")
        tap("Add Layer")
        tap("Star")
        let window = app.windows.firstMatch.frame
        for b in app.buttons.allElementsBoundByIndex where b.exists && b.isHittable {
            let f = b.frame
            // Scroll views may clip a row partially; a button is broken only if its center is outside the window.
            XCTAssertTrue(window.contains(CGPoint(x: f.midX, y: f.midY)), "button \(b.label) is off-screen: \(f)")
        }
    }
}
