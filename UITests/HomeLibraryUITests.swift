import XCTest

/// Home library through its real entry points, on a seeded library (see HomeLibrarySeed).
/// Screenshots land in /tmp/awi-ui for the visual-review artifact.
final class HomeLibraryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: String...) {
        app.launchArguments = ["-uiTesting", "-uiTesting-homeLibrary"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["Create New Project"].waitForExistence(timeout: 20), "Home did not appear")
    }

    private func snap(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name; a.lifetime = .keepAlways
        add(a)
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/home-\(name).png"))
    }

    private var rows: XCUIElementQuery { app.buttons.matching(identifier: "project-row") }

    private func button(_ label: String) -> XCUIElement {
        let b = app.buttons[label].firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: 10), "Missing button: \(label)")
        return b
    }

    private func filter(_ title: String, expect count: Int, _ line: UInt = #line) {
        button(title).tap()
        let predicate = NSPredicate(format: "count == %d", count)
        let done = expectation(for: predicate, evaluatedWith: rows)
        wait(for: [done], timeout: 5)
        XCTAssertEqual(rows.count, count, "\(title) filter", line: line)
    }

    private func row(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'project-row' AND label CONTAINS %@", name)).firstMatch
    }

    func testFiltersSearchSortAndRowActions() {
        launch()
        XCTAssertEqual(rows.count, 4)
        snap("01-all")

        filter("AWI", expect: 2)
        filter("After Effects", expect: 1)
        snap("02-after-effects")
        filter("Alight Motion", expect: 1)
        filter("All", expect: 4)

        // Search + source + sort compose.
        let search = app.textFields["Search projects"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("o")
        filter("AWI", expect: 2)   // Rooftop Flow Edit, Square Loop
        button("Sort: Last Edited").tap()
        button("Name").tap()
        XCTAssertTrue(button("Sort: Name").exists)
        let first = rows.element(boundBy: 0), second = rows.element(boundBy: 1)
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        XCTAssertTrue(first.label.contains("Rooftop"), "Name sort: \(first.label)")
        snap("03-search-awi-name")
        button("Clear search").tap()
        search.typeText(XCUIKeyboardKey.return.rawValue)   // dismiss the keyboard before the next screenshots
        filter("All", expect: 4)
        button("Sort: Name").tap(); button("Last Edited").tap()

        // Three dots open actions, not the project.
        button("Actions for Opening Titles").tap()
        XCTAssertTrue(button("Rename").exists)
        XCTAssertTrue(button("Duplicate").exists)
        XCTAssertTrue(button("Restore Version").exists)
        XCTAssertTrue(button("Share Project File (.awi)").exists)
        snap("04-actions")
        button("Duplicate").tap()
        filter("After Effects", expect: 2)

        // Rename keeps the AE source.
        button("Actions for Opening Titles copy").tap()
        button("Rename").tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "Titles Alt")
        app.alerts.buttons["Rename"].tap()
        XCTAssertTrue(row("Titles Alt").waitForExistence(timeout: 5), "Renamed AE project left the AE filter")
        filter("All", expect: 5)

        // Version restore sheet.
        button("Actions for Opening Titles").tap()
        button("Restore Version").tap()
        XCTAssertTrue(button("Save Named Version of Current State").exists)
        snap("05-versions")
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(button("Create New Project").waitForExistence(timeout: 5))

        // Share sheet presents.
        button("Actions for Square Loop").tap()
        button("Share Project File (.awi)").tap()
        sleep(2)
        snap("06-share")
        app.swipeDown(velocity: .fast)
        if !app.buttons["Create New Project"].waitForExistence(timeout: 3) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        }
        XCTAssertTrue(button("Create New Project").waitForExistence(timeout: 5))

        // Bulk selection replaces the dock with selection actions.
        button("Select").tap()
        rows.element(boundBy: 0).tap(); rows.element(boundBy: 1).tap()
        XCTAssertTrue(button("Duplicate").isEnabled)
        XCTAssertTrue(button("Share").exists)
        XCTAssertTrue(button("Delete").exists)
        XCTAssertFalse(app.buttons["Create New Project"].exists, "Dock should yield to the selection bar")
        snap("07-selection")
        button("Done").tap()

        // Recently Deleted holds the seeded draft; one tap restores it.
        app.swipeUp()
        button("Recently Deleted").tap()
        XCTAssertTrue(button("Restore Old Draft").exists)
        snap("08-recently-deleted")
        button("Restore Old Draft").tap()
        XCTAssertTrue(button("Restore Old Draft").waitForNonExistence(timeout: 5))
        button("Back to Projects").tap()
        filter("AWI", expect: 3)

        // Video Enhance stays visibly unavailable.
        let enhance = app.buttons["Video Enhance, coming soon"]
        XCTAssertTrue(enhance.exists)
        XCTAssertFalse(enhance.isEnabled)

        // Row tap opens the project in the editor.
        filter("All", expect: 6)
        row("Rooftop Flow Edit").tap()
        XCTAssertTrue(app.buttons["Add"].firstMatch.waitForExistence(timeout: 20), "Row tap did not open the editor")
        snap("09-opened-project")
    }

    private var permanentConfirm: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH 'Permanently'")).firstMatch
    }

    private func trash(_ name: String) {
        button("Actions for \(name)").tap()
        button("Delete").tap()
        button("Delete \(name)").tap()
        XCTAssertTrue(app.buttons["Actions for \(name)"].waitForNonExistence(timeout: 5), "\(name) still listed")
    }

    func testRecentlyDeletedPageSelectRestoreAndDelete() {
        launch()
        trash("Square Loop")
        trash("Opening Titles")
        app.swipeUp()
        button("Recently Deleted").tap()
        let deletedRows = app.buttons.matching(identifier: "deleted-row")
        XCTAssertGreaterThanOrEqual(deletedRows.count, 3)
        XCTAssertTrue(button("Restore All").exists)
        XCTAssertTrue(button("Delete All").exists)
        XCTAssertFalse(app.buttons["Create New Project"].exists, "Recently Deleted is its own page")
        snap("16-deleted-page")

        // Tapping a row starts selection with it; delete just that one, with confirmation.
        let before = deletedRows.count
        app.buttons.matching(NSPredicate(format: "identifier == 'deleted-row' AND label CONTAINS 'Square Loop'")).firstMatch.tap()
        XCTAssertTrue(button("Delete (1)").exists)
        XCTAssertTrue(button("Restore (1)").exists)
        XCTAssertTrue(button("Select All").exists)
        snap("17-deleted-selecting")
        button("Delete (1)").tap()
        XCTAssertTrue(permanentConfirm.waitForExistence(timeout: 5))
        permanentConfirm.tap()
        XCTAssertTrue(app.buttons["Restore Square Loop"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(deletedRows.count, before - 1)

        // Select several and restore them.
        button("Select").tap()
        button("Select All").tap()
        XCTAssertTrue(button("Deselect All").exists)
        button("Restore (\(before - 1))").tap()
        XCTAssertTrue(app.staticTexts["Nothing here"].waitForExistence(timeout: 5))
        snap("18-deleted-empty")
        button("Back to Projects").tap()
        XCTAssertTrue(app.buttons["Actions for Opening Titles"].waitForExistence(timeout: 5), "Restored project returns to the library")

        // Delete All empties the page after confirming.
        trash("Rooftop Flow Edit")
        app.swipeUp()
        button("Recently Deleted").tap()
        button("Delete All").tap()
        XCTAssertTrue(permanentConfirm.waitForExistence(timeout: 5))
        snap("19-delete-all-confirm")
        permanentConfirm.tap()
        XCTAssertTrue(app.staticTexts["Nothing here"].waitForExistence(timeout: 5))
    }

    func testCenterPlusAndImportEntryPoints() {
        launch()
        button("Import AEP / XML").tap()
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 15), "Files picker did not open")
        snap("10-import-picker")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(button("Create New Project").waitForExistence(timeout: 10))
        button("Create New Project").tap()
        button("Create from scratch").tap()
        XCTAssertTrue(app.buttons["Add"].firstMatch.waitForExistence(timeout: 20), "Center + did not create a project")
    }

    func testFramingNarrowAndEmptyScreenshots() {
        launch()
        snap("11-fit-inside")
        app.terminate()
        launch("-uiTesting-homeCrop")
        snap("12-center-crop")
        app.terminate()
        launch("-uiTesting-homeNarrow")
        XCTAssertEqual(rows.count, 4)
        for title in ["All", "AWI", "After Effects", "Alight Motion"] { XCTAssertTrue(app.buttons[title].exists, title) }
        snap("13-narrow-375")
        button("Alight Motion").tap()
        XCTAssertTrue(app.buttons["Alight Motion"].isHittable, "Source rail must reach its last filter on narrow phones")
        snap("14-narrow-alight-motion")
        app.terminate()
        app.launchArguments = ["-uiTesting", "-uiTesting-homeEmpty"]
        app.launch()
        XCTAssertTrue(app.staticTexts["No projects yet"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["Select"].exists)
        snap("15-empty")
    }
}
