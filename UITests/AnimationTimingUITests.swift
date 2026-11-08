import XCTest

final class AnimationTimingUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting", "-uiTesting-animationTiming"]
        app.launch(); return app
    }

    func testTimeRemapEditorEditsSourceAndUsesSharedGraph() {
        let app = launch()
        let remap = app.buttons["Time Remap"].firstMatch
        XCTAssertTrue(remap.waitForExistence(timeout: 15))
        let scroll = app.scrollViews["clip-settings-scroll"].firstMatch
        for _ in 0..<8 { if remap.isHittable { break }; scrollPanel(scroll, up: true) }
        remap.tap()
        let resize = app.descendants(matching: .any)["Resize panel"].firstMatch
        if resize.exists {
            let grab = resize.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            grab.press(forDuration: 0.1, thenDragTo: grab.withOffset(CGVector(dx: 0, dy: -180)))
        }
        let sourceGraph = app.buttons["Source Time"].firstMatch
        XCTAssertTrue(sourceGraph.waitForExistence(timeout: 5)); sourceGraph.tap()
        let key = app.buttons["Add source time keyframe"].firstMatch
        for _ in 0..<8 { if key.isHittable { break }; scrollPanel(scroll, up: true) }
        XCTAssertTrue(key.waitForExistence(timeout: 8)); key.tap()
        XCTAssertTrue(app.buttons["1.000s → 1.000s"].waitForExistence(timeout: 3))
        let source = app.descendants(matching: .any)["number-Source seconds"].firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 3))
        for _ in 0..<8 { if source.isHittable { break }; scrollPanel(scroll, up: true) }
        source.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "2\n")
        XCTAssertTrue(app.buttons["1.000s → 2.000s"].waitForExistence(timeout: 5))
        let point = app.descendants(matching: .any)["Source key at 1.000 seconds"].firstMatch
        XCTAssertTrue(point.exists)
        // AX can call an offscreen graph key hittable through a clipped SwiftUI ScrollView.
        // Require its actual touch position to be inside the panel, not merely in the AX tree.
        for _ in 0..<8 {
            let y = point.frame.midY, viewport = scroll.frame.insetBy(dx: 0, dy: 28)
            if viewport.contains(CGPoint(x: point.frame.midX, y: y)) { break }
            let delta = min(60, max(-60, y - viewport.midY))
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -delta)))
        }
        save("remap-before-drag")
        XCTAssertTrue(scroll.frame.insetBy(dx: 0, dy: 20).contains(CGPoint(x: point.frame.midX, y: point.frame.midY)), "key=\(point.frame), scroll=\(scroll.frame)")
        let center = point.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        center.press(forDuration: 0.1,thenDragTo: center.withOffset(CGVector(dx: 0,dy: -20)))
        XCTAssertFalse(app.buttons["1.000s → 2.000s"].exists, "Dragging the source key must edit its value, not scroll the sheet")
        save("remap-value")
        let speed = app.buttons["Playback Speed"].firstMatch
        for _ in 0..<8 { if speed.isHittable { break }; scrollPanel(scroll, up: false) }
        XCTAssertTrue(speed.isHittable, "The inline graph picker must remain reachable")
        speed.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Speed in'")).firstMatch.waitForExistence(timeout: 3))
        save("remap-speed")
        let easing = app.buttons["Edit Segment Easing"].firstMatch
        for _ in 0..<8 { if easing.isHittable { break }; scrollPanel(scroll, up: true) }
        easing.tap()
        XCTAssertTrue(app.staticTexts["Graph"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Time Remap"].firstMatch.exists)
        save("remap-easing")
        let graph = app.descendants(matching: .any)["bezier-editor"].firstMatch
        XCTAssertTrue(graph.waitForExistence(timeout: 5))
        for label in ["Outgoing easing handle", "Incoming easing handle"] {
            let handle = app.descendants(matching: .any)[label].firstMatch
            XCTAssertTrue(handle.exists)
            XCTAssertTrue(graph.frame.contains(CGPoint(x: handle.frame.midX,y: handle.frame.midY)), "Steep easing handles must stay inside the new graph: graph=\(graph.frame), \(label)=\(handle.frame)")
        }
        save("remap-easing")
    }

    func testExistingKeyframeMoverMovesSelectionAsOneBlock() {
        let app = launch()
        let options = app.buttons["Layer Options"].firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 15)); options.tap()
        let mover = app.buttons["Move Keyframes…"].firstMatch
        XCTAssertTrue(mover.waitForExistence(timeout: 5)); mover.tap()
        let all = app.buttons["Select All"].firstMatch
        XCTAssertTrue(all.waitForExistence(timeout: 5)); all.tap()
        app.buttons["To Playhead"].firstMatch.tap()
        XCTAssertTrue(app.buttons["1.000 s"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["3.000 s"].exists)
        save("keyframe-selection")
    }

    private func scrollPanel(_ scroll: XCUIElement, up: Bool) {
        // Short gutter drags avoid both value scrubbers and overshooting a 200pt panel.
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: up ? -60 : 60)))
    }

    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/timing-\(name).png"))
    }
}
