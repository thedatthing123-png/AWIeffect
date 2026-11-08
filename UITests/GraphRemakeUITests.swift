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
        let tuned = cycles.value as? String
        bring(repeatButton, scroll: scroll); repeatButton.tap()
        XCTAssertEqual(cycles.value as? String, tuned, "Tapping the active graph must preserve its edits")
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
        let count = bounces.value as? String
        let b = bounces.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        b.press(forDuration: 0.1,thenDragTo: b.withOffset(CGVector(dx: 50,dy: 0)))
        XCTAssertNotEqual(bounces.value as? String, count, "Bounce must be editable too")
        save("graph-bounce")
        XCTAssertFalse(app.buttons["Sine In"].exists, "Duplicate fixed curves should not clutter the new catalog")
    }
    private func bring(_ e: XCUIElement, scroll: XCUIElement) {
        for _ in 0..<18 {
            let viewport = scroll.frame.insetBy(dx: 0,dy: 24)
            if e.exists && viewport.contains(CGPoint(x: e.frame.midX,y: e.frame.midY)) { return }
            // Lazy tiles have no frame until scrolled into view. Search down, not toward CGRect.zero.
            let distance: CGFloat
            if !e.exists { distance = 80 }
            else if e.frame.midY < viewport.minY { distance = e.frame.midY - viewport.minY - 20 }
            else { distance = e.frame.midY - viewport.maxY + 20 }
            let delta = min(100,max(-100,distance))
            let p = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.01,dy: 0.5))
            // Hold after the drag so scroll inertia cannot repeatedly overshoot the handle.
            p.press(forDuration: 0.05,thenDragTo: p.withOffset(CGVector(dx: 0,dy: -delta)), withVelocity: .slow, thenHoldForDuration: 0.3)
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
