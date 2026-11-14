import XCTest

final class EditorPolishUITests: XCTestCase {
    func testIndividualAndCameraBlurDoNotEnableEveryLayer() {
        continueAfterFailure = false
        for camera in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting", "-uiTesting-motionBlur"] + (camera ? ["-uiTesting-motionBlurCamera"] : [])
            app.launch()
            let toggle = app.switches[camera ? "Camera Motion Blur" : "Motion Blur"].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 15))
            let every = app.switches["Every layer"].firstMatch
            XCTAssertEqual(every.value as? String, "0")
            toggle.tap()
            XCTAssertEqual(toggle.value as? String, "1")
            XCTAssertEqual(every.value as? String, "0", "individual opt-in must not turn on Every Layer")
            let shot = XCUIScreen.main.screenshot()
            let name = camera ? "polish-camera-motion-blur" : "polish-layer-motion-blur"
            let attachment = XCTAttachment(screenshot: shot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/\(name).png"))
            app.terminate()
        }
    }

    func testManyLayersScrollVerticallyWithoutScrubbingTime() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-manyLayers"]
        app.launch()
        let timeline = app.scrollViews["layer-timeline-scroll"].firstMatch
        XCTAssertTrue(timeline.waitForExistence(timeout: 15))
        let before = app.staticTexts["timeline-timecode"].firstMatch.label
        let last = app.otherElements["timeline-row-Layer 40"].firstMatch
        for _ in 0..<45 {
            if last.isHittable { break }
            timeline.swipeUp()
        }
        if !last.isHittable { print("TIMELINE-FAILURE " + app.debugDescription) }
        XCTAssertTrue(last.isHittable, "Could not reach the last layer")
        XCTAssertEqual(app.staticTexts["timeline-timecode"].firstMatch.label, before, "Vertical scrolling scrubbed the playhead")
    }
    func testHeaderHoldStartsRangeSelectionWhileTracksRemainScrollable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-manyLayers"]; app.launch()
        let first = app.otherElements["timeline-header-Layer 1"].firstMatch
        let third = app.otherElements["timeline-header-Layer 3"].firstMatch
        if !first.waitForExistence(timeout: 15) { print("HEADER-UI " + app.debugDescription) }
        XCTAssertTrue(first.exists)
        first.press(forDuration: 0.5, thenDragTo: third)
        print("HEADER-SELECTION first=\(String(describing: first.value)) third=\(String(describing: third.value))")
        XCTAssertEqual(first.value as? String, "Selected")
        XCTAssertEqual(third.value as? String, "Selected")
    }
    func testTrackHoldCanLiftAndReorderUnselectedClip() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-manyLayers"]; app.launch()
        let clip = app.descendants(matching: .any)["timeline-clip-Layer 1"].firstMatch
        let first = app.otherElements["timeline-header-Layer 1"].firstMatch
        let second = app.otherElements["timeline-header-Layer 2"].firstMatch
        XCTAssertTrue(clip.waitForExistence(timeout: 15))
        let start = clip.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 35, dy: 0))
        let end = start.withOffset(CGVector(dx: 0, dy: 46))
        print("CLIP-HOLD frame=\(clip.frame) first=\(first.frame) second=\(second.frame)")
        start.press(forDuration: 0.5, thenDragTo: end)
        print("CLIP-HOLD after " + app.debugDescription)
        XCTAssertGreaterThan(first.frame.midY, second.frame.midY)
    }
}
