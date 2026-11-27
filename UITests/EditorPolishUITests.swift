import XCTest

final class EditorPolishUITests: XCTestCase {
    func testLUTThumbnailsUseThreeColumnsAndApplyInOneTap() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-ccLUTGrid"]
        app.launch()
        let tab = app.buttons["LUT"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let firstRow = ["none", "AWI Teal & Orange.cube", "AWI Bleach Bypass.cube"].map { app.buttons["cc-lut-\($0)"] }
        XCTAssertTrue(firstRow[0].waitForExistence(timeout: 7))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Preview ready"), object: firstRow[2])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
        let dock = app.buttons.matching(identifier: "CC Studio").firstMatch
        XCTAssertTrue(dock.exists)
        for tile in firstRow {
            XCTAssertTrue(tile.exists)
            XCTAssertGreaterThanOrEqual(tile.frame.height, 44)
            XCTAssertLessThanOrEqual(tile.frame.maxY, dock.frame.minY)
        }
        XCTAssertEqual(firstRow[0].frame.minY, firstRow[2].frame.minY, accuracy: 1)
        XCTAssertLessThan(firstRow[0].frame.midX, firstRow[1].frame.midX)
        XCTAssertLessThan(firstRow[1].frame.midX, firstRow[2].frame.midX)
        firstRow[1].tap()
        XCTAssertTrue(firstRow[1].isSelected)
        XCTAssertFalse(firstRow[0].isSelected)
        let output = URL(fileURLWithPath: "/tmp/awi-ui")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("cc-lut-grid.png"))
        firstRow[0].tap()
        XCTAssertTrue(firstRow[0].isSelected)
        XCTAssertFalse(firstRow[1].isSelected)
    }

    func testSceneWorkspaceAddsCameraAndKeepsLayerPlacementAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-sceneWorkspace"]
        app.launch()
        let camera = app.buttons["scene-add-camera"].firstMatch
        XCTAssertTrue(camera.waitForExistence(timeout: 15))
        camera.tap()
        XCTAssertTrue(app.staticTexts["Active"].firstMatch.waitForExistence(timeout: 5))
        let output = URL(fileURLWithPath: "/tmp/awi-ui")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("3d-scene-camera.png"))
        app.buttons["3D Scene Layers"].tap()
        app.buttons["Select Foreground"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Layer Depth Z"].firstMatch.isHittable)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("3d-scene-placement.png"))
        let framing = app.switches["Keep Framing"].firstMatch
        let panel = app.scrollViews["scene-workspace-scroll"].firstMatch
        for _ in 0..<4 where !framing.isHittable { panel.swipeUp() }
        XCTAssertTrue(framing.isHittable)
        framing.tap()
        XCTAssertEqual(framing.value as? String, "1")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("3d-scene-framing.png"))
        app.buttons["3D Scene Camera Move"].tap()
        let keyMove = app.buttons["scene-key-camera-move"].firstMatch
        XCTAssertTrue(keyMove.waitForExistence(timeout: 5))
        XCTAssertTrue(keyMove.isHittable)
        XCTAssertTrue(keyMove.isEnabled)
        keyMove.tap()
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("3d-scene-key-move.png"))
    }

    func testLightingStudioKeepsLayerLightingAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-lightingStudio"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lighting Studio"].waitForExistence(timeout: 15))
        let output = URL(fileURLWithPath: "/tmp/awi-ui")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for title in ["Light", "Placement", "Layers"] {
            let tab = app.segmentedControls.buttons[title].firstMatch
            XCTAssertTrue(tab.isHittable, title)
            tab.tap()
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("lighting-studio-\(title).png"))
        }
        let response = app.switches["Receive Light"].firstMatch
        XCTAssertTrue(response.isHittable)
        XCTAssertEqual(response.value as? String, "1")
        XCTAssertTrue(app.switches["Receive Shadows"].firstMatch.isHittable)
        response.tap()
        XCTAssertEqual(response.value as? String, "0")
        app.segmentedControls.buttons["Light"].firstMatch.tap()
        let spread = app.descendants(matching: .any).matching(identifier: "shadow-distance-spread").firstMatch
        let panel = app.scrollViews["lighting-studio-scroll"].firstMatch
        // Start in the scroll gutter so the swipe doesn't land on a horizontal numeric scrubber.
        let bottom = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.88))
        let top = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.18))
        for _ in 0..<5 where !spread.isHittable { bottom.press(forDuration: 0.05, thenDragTo: top) }
        XCTAssertTrue(spread.isHittable)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("lighting-shadow-spread.png"))
    }

    func testRelightStudioFitsPassesAndSurfaceControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-relight"]
        app.launch()
        let depth = app.buttons["Replace Depth"].firstMatch
        XCTAssertTrue(depth.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Import Alpha"].firstMatch.isHittable)
        XCTAssertTrue(app.buttons["Replace Normals"].firstMatch.isHittable)
        XCTAssertGreaterThanOrEqual(depth.frame.height, 44)
        let output = URL(fileURLWithPath: "/tmp/awi-ui", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("relight-passes.png"))
        app.segmentedControls.buttons["Surface"].firstMatch.tap()
        let enabled = app.switches["Relight Surface"].firstMatch
        XCTAssertTrue(enabled.isHittable)
        XCTAssertEqual(enabled.value as? String, "1")
        enabled.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(enabled.value as? String, "0")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("relight-surface.png"))
    }

    func testSmoothSceneIsDirectlyOnAdjustmentAndCamera() throws {
        let output = URL(fileURLWithPath: "/tmp/awi-ui", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for camera in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting", "-uiTesting-smoothScene"] + (camera ? ["-uiTesting-smoothSceneCamera"] : [])
            app.launch()
            let toggle = app.switches["smooth-scene-toggle"].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 15))
            XCTAssertTrue(toggle.isHittable)
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "1")
            XCTAssertTrue(app.staticTexts["65%"].firstMatch.exists)
            let name = camera ? "smooth-scene-camera" : "smooth-scene-adjustment"
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent(name + ".png"))
            app.terminate()
        }
    }

    func testIndividualAndCameraBlurDoNotEnableEveryLayer() {
        continueAfterFailure = false
        for camera in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting", "-uiTesting-motionBlur"] + (camera ? ["-uiTesting-motionBlurCamera"] : [])
            app.launch()
            let toggle = app.switches["selected-layer-motion-blur"].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 15))
            let every = app.switches["blur-every-layer"].firstMatch
            XCTAssertEqual(every.value as? String, "0")
            // The switch row must fit inside the panel padding, including
            // the trailing area where the user taps the switch.
            XCTAssertTrue(toggle.isHittable)
            XCTAssertLessThanOrEqual(toggle.frame.maxX,app.frame.maxX-12+0.5)
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: toggle)
            let result = XCTWaiter.wait(for: [changed], timeout: 3)
            let shot = XCUIScreen.main.screenshot()
            let name = camera ? "polish-camera-motion-blur" : "polish-layer-motion-blur"
            let attachment = XCTAttachment(screenshot: shot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/\(name).png"))
            XCTAssertEqual(result, .completed, "One tap must enable the selected layer/camera switch")
            XCTAssertEqual(toggle.value as? String, "1")
            XCTAssertEqual(every.value as? String, "0", "individual opt-in must not turn on Every Layer")
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
