import XCTest

/// Spike smoke tests proving the launch-and-drive mechanism works end-to-end against the
/// real app `build_app.py` produces — not a claim of full workflow coverage. See
/// docs/UI_TESTING.md for what this layer is and isn't for.
@MainActor
final class SmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLauncher.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testAppLaunchesIntoModsTab() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15), "the main window should appear")

        let modsTab = app.buttons["sidebar-tab-Mods"]
        XCTAssertTrue(modsTab.waitForExistence(timeout: 15), "the Mods sidebar tab should exist")
        modsTab.click()

        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 15), "the Mods search field should appear once the tab is selected")
    }

    /// Doesn't assume any particular number of mods are installed on the machine running
    /// the test — the assertion (zero rows match a string no real mod is ever named) holds
    /// whether the local Mods folder is empty or populated.
    func testSearchingFiltersModList() throws {
        app.buttons["sidebar-tab-Mods"].click()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 15))
        searchField.click()

        let needle = "zzz-no-mod-named-this-zzz"
        searchField.typeText(needle)
        XCTAssertEqual(searchField.value as? String, needle, "the search field should reflect the typed query")

        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'mod-row-'"))
        let noMatches = NSPredicate(format: "count == 0")
        expectation(for: noMatches, evaluatedWith: rows, handler: nil)
        waitForExpectations(timeout: 10)
    }
}
