import XCTest

/// Smoke tests proving the launch-and-drive mechanism works end-to-end against the real
/// app the StarHubTH scheme builds — not a claim of full workflow coverage.
///
/// Uses the async `setUp()`/`tearDown()` override points, not `setUpWithError()`/
/// `tearDownWithError()` — those are synchronous, nonisolated XCTestCase methods, so
/// overriding them in a `@MainActor` subclass and touching `app` (a MainActor-isolated
/// property) inside them is a hard Swift 6 concurrency error. It didn't surface locally
/// under this machine's (unusually new) Xcode/Swift toolchain, only under the Xcode 16.2
/// CI actually runs — a reminder that local toolchain leniency isn't proof of portability.
@MainActor
final class SmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppLauncher.launch()
    }

    override func tearDown() async throws {
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
