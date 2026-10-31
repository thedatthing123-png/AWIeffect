import XCTest

/// Drives the real app in the simulator and saves screenshots of each main screen (CI artifact).
final class AWIeffectUITests: XCTestCase {
    private var app: XCUIApplication!
    private var shot = 0

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // Looping previews never let the app go idle, which stalls UI testing: run them as stills.
        app.launchArguments = ["-uiTesting"]
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

    private func onScreen(_ e: XCUIElement) -> Bool {
        let f = e.frame, w = app.windows.firstMatch.frame
        return w.contains(CGPoint(x: f.midX, y: f.midY))
    }

    /// Taps a button by label; scrolls the bottom category strip sideways if the item is off-screen.
    private func tap(_ label: String, timeout: TimeInterval = 5) {
        let e = app.buttons[label].firstMatch
        if e.waitForExistence(timeout: timeout) {
            var tries = 0
            while !onScreen(e) && tries < 6 {
                let goLeft = e.frame.midX > app.windows.firstMatch.frame.midX
                let y = min(0.985, max(0.5, (e.frame.midY) / app.windows.firstMatch.frame.height))
                let a = app.coordinate(withNormalizedOffset: CGVector(dx: goLeft ? 0.85 : 0.15, dy: y))
                let b = app.coordinate(withNormalizedOffset: CGVector(dx: goLeft ? 0.25 : 0.75, dy: y))
                a.press(forDuration: 0.05, thenDragTo: b)
                tries += 1
            }
            e.tap()
        } else {
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

        tap("Add")
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

        tap("Presets")
        snap("presets")
        tap("Zoom Blur In")

        tap("Masks")
        snap("masks")
        tap("Border & Shadow")
        snap("border-shadow")
        tap("Motion Blur")
        snap("motion-blur")
        tap("3D")
        snap("3d-panel")
        tap("Physics")
        snap("physics-lab")
        tap("Layer")
        snap("layer-menu")
        tap("Select Many")
        sleep(1)
        snap("multi-select")
        tap("Done")

        tap("Deselect Layer")
        tap("3D view")
        sleep(1)
        snap("orbit-view")
        tap("2D view")

        tap("Deselect Layer")
        tap("Scene Settings")
        sleep(1)
        snap("scene-settings")

        // Text Studio
        tap("Deselect Layer")
        sleep(1)
        snap("nav-empty")
        tap("Text")
        sleep(1)
        snap("text-studio")
        tap("Animate")
        sleep(2)
        snap("text-presets")

        // Draw Studio
        tap("Deselect Layer")
        tap("Draw")
        sleep(2)
        snap("draw-studio")
        tap("Cancel")

        // Export (project bar shows once nothing is selected)
        tap("Deselect Layer")
        tap("Export")
        sleep(1)
        snap("export")
        app.swipeUp()
        sleep(1)
        snap("export-more")

        XCTAssertTrue(app.state == .runningForeground, "app crashed during the tour")
    }

    /// Every on-screen button must sit fully inside the window (catches off-screen / overlapping chrome).
    func testNoButtonsOffscreen() {
        tap("Create New Project")
        tap("Create from scratch")
        tap("Add")
        tap("Star")
        sleep(2)   // let the panel finish sliding in
        let window = app.windows.firstMatch.frame
        // Fixed chrome (top bar + transport) must sit fully inside the window and must not overlap each other.
        let chrome = ["Deselect Layer", "Rename Layer", "Duplicate Layer", "Delete Layer", "Layer Options", "Play", "Key All", "Panel Back"]
        var frames: [(String, CGRect)] = []
        for label in chrome {
            let e = app.buttons[label].firstMatch
            guard e.exists else { continue }
            XCTAssertTrue(window.contains(e.frame), "\(label) is (partly) off-screen: \(e.frame)")
            frames.append((label, e.frame))
        }
        for i in frames.indices { for j in frames.indices where j > i {
            XCTAssertFalse(frames[i].1.insetBy(dx: 2, dy: 2).intersects(frames[j].1.insetBy(dx: 2, dy: 2)), "\(frames[i].0) overlaps \(frames[j].0)")
        } }
    }
}
