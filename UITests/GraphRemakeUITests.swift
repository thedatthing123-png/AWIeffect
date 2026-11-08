import XCTest

final class GraphRemakeUITests: XCTestCase {
    func testLoopAndBounceHaveTwoEditableHandles() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting", "-uiTesting-animationTiming", "-uiTesting-graph"]; app.launch()
        XCTAssertTrue(app.buttons["Loops"].firstMatch.waitForExistence(timeout: 15))
        let resize = app.descendants(matching: .any)["Resize panel"].firstMatch
        let grab = resize.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        grab.press(forDuration: 0.1, thenDragTo: grab.withOffset(CGVector(dx: 0,dy: -180)))
        let scroll = app.scrollViews["graph-scroll"].firstMatch
        app.buttons["Loops"].firstMatch.tap()
        let repeatButton = app.buttons["Repeat"].firstMatch
        bring(repeatButton, scroll: scroll); repeatButton.tap()
        let cycles = app.descendants(matching: .any)["Cycles handle"].firstMatch
        XCTAssertTrue(cycles.waitForExistence(timeout: 5))
        bring(cycles, scroll: scroll)
        let before = cycles.value as? String
        let start = cycles.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        start.press(forDuration: 0.1,thenDragTo: start.withOffset(CGVector(dx: 50,dy: 0)))
        XCTAssertNotEqual(cycles.value as? String, before)
        save("graph-repeat")
        let back = app.buttons["Back & Forth"].firstMatch; bring(back, scroll: scroll); back.tap()
        let smooth = app.descendants(matching: .any)["Smoothness handle"].firstMatch
        bring(smooth, scroll: scroll)
        let old = smooth.value as? String
        let p = smooth.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        p.press(forDuration: 0.1,thenDragTo: p.withOffset(CGVector(dx: -60,dy: 0)))
        XCTAssertNotEqual(smooth.value as? String, old)
        save("graph-back-forth")
        let motion = app.buttons["Motion"].firstMatch; bring(motion, scroll: scroll); motion.tap()
        let bounce = app.buttons["Bounce"].firstMatch; bring(bounce, scroll: scroll); bounce.tap()
        let bounces = app.descendants(matching: .any)["Bounces handle"].firstMatch
        XCTAssertTrue(bounces.waitForExistence(timeout: 5)); bring(bounces, scroll: scroll)
        save("graph-bounce")
        XCTAssertFalse(app.buttons["Sine In"].exists, "Duplicate fixed curves should not clutter the new catalog")
    }
    private func bring(_ e: XCUIElement, scroll: XCUIElement) {
        for _ in 0..<18 {
            let viewport = scroll.frame.insetBy(dx: 0,dy: 24)
            if e.exists && viewport.contains(CGPoint(x: e.frame.midX,y: e.frame.midY)) { return }
            let delta = min(60,max(-60,e.frame.midY-viewport.midY))
            let p = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.01,dy: 0.5))
            p.press(forDuration: 0.05,thenDragTo: p.withOffset(CGVector(dx: 0,dy: -delta)))
        }
        XCTAssertTrue(e.isHittable, "Graph control must remain reachable")
    }
    private func save(_ name: String) {
        let s = XCUIScreen.main.screenshot(), a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/\(name).png"))
    }
}
