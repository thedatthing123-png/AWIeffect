import XCTest

/// Strict navigation and assertions for the reported interactions; missing controls fail the test.
final class EssentialUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    private func tap(_ name: String) {
        let button = app.buttons[name].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing button: \(name)")
        button.tap()
    }

    private func createProject() {
        tap("Create New Project")
        tap("Create from scratch")
        XCTAssertTrue(app.buttons["Add"].firstMatch.waitForExistence(timeout: 10))
    }

    func testExpandedEffectDragChangesValueWithoutDeletingAndCollapsedSwipeDeletes() {
        createProject()
        tap("Add")
        tap("Star")
        tap("Effects")
        tap("Add Effect")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap(); search.typeText("Gaussian Blur")
        let effect = app.buttons.containing(.staticText, identifier: "Gaussian Blur").firstMatch
        XCTAssertTrue(effect.waitForExistence(timeout: 10))
        effect.tap()
        let slider = app.descendants(matching: .any)["effect-param-ae.gaussianBlur-blurriness"].firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 10), "New effect must open its settings")
        let before = slider.value as? String
        let from = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let to = from.withOffset(CGVector(dx: -260, dy: 0))
        from.press(forDuration: 0.1, thenDragTo: to)
        XCTAssertTrue(slider.exists, "Parameter drag deleted the effect")
        XCTAssertNotEqual(slider.value as? String, before, "Parameter did not change")
        let expand = app.buttons["effect-expand-ae.gaussianBlur"]
        XCTAssertTrue(expand.exists)
        expand.tap()
        XCTAssertFalse(slider.exists)
        let header = expand.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 200, dy: 0))
        header.press(forDuration: 0.1, thenDragTo: header.withOffset(CGVector(dx: -270, dy: 0)))
        XCTAssertTrue(expand.waitForNonExistence(timeout: 5), "Collapsed effect swipe should still delete")
    }

    func testTextAnimatePanelOpensWithoutCrashing() {
        createProject()
        tap("Text")
        tap("Done Typing")
        tap("Animate")
        XCTAssertTrue(app.staticTexts["Presets start at the playhead and are made of normal animators: open Animators to tweak them."].waitForExistence(timeout: 15), "Preset browser did not open")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
