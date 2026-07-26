import XCTest

/// Exercises the real mod enable/disable pipeline end-to-end: click the row's toggle, wait
/// through `ModListRow`'s built-in ~300ms debounce, then verify the mod's folder actually
/// moved from `Mods/` to `Mods_disabled/` on disk (`ModsStore+Toggle.swift`) — not just that
/// the switch visually flipped.
@MainActor
final class ModToggleRoundTripUITests: XCTestCase {
    private var app: XCUIApplication!
    private var workspace: UITestEnvironment.Workspace!

    override func setUp() async throws {
        continueAfterFailure = false
        workspace = UITestEnvironment.makeWorkspace(preInstallFixtureMod: true)
        app = AppLauncher.launch(environment: workspace.launchEnvironment)
    }

    override func tearDown() async throws {
        app.terminate()
        workspace.cleanUp()
    }

    func testTogglingAModMovesItToTheDisabledFolder() throws {
        let modsTab = app.buttons["sidebar-tab-Mods"]
        XCTAssertTrue(modsTab.waitForExistence(timeout: 15))
        modsTab.click()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'mod-row-FixtureMod'"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))

        // ModListRow's Toggle carries no identifier of its own (the row's own identifier
        // clobbers a child's — see SWIFT_STANDARDS.md §10) and its label is empty
        // (.labelsHidden()), so it's located by element type instead: it's the only
        // checkBox-typed descendant in a row that otherwise has only button-typed controls.
        let toggle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'mod-row-FixtureMod' AND elementType == %d", XCUIElement.ElementType.checkBox.rawValue))
            .firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.click()

        let enabledPath = workspace.gameDir.appendingPathComponent("Mods/FixtureMod")
        let disabledPath = workspace.gameDir.appendingPathComponent("Mods_disabled/FixtureMod")
        let deadline = Date().addingTimeInterval(10)
        var moved = false
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: disabledPath.path) && !FileManager.default.fileExists(atPath: enabledPath.path) {
                moved = true
                break
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertTrue(moved, "toggling the mod off should move its folder from Mods/ to Mods_disabled/ on disk")
    }
}
