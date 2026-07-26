import XCTest

/// Exercises the real mod config editor end-to-end: open a mod's config, toggle a boolean
/// field in the visual editor, save, then verify the change actually landed in config.json
/// on disk — not just that the UI stopped complaining.
@MainActor
final class ModConfigEditRoundTripUITests: XCTestCase {
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

    func testTogglingAConfigFieldPersistsToDisk() throws {
        let modsTab = app.buttons["sidebar-tab-Mods"]
        XCTAssertTrue(modsTab.waitForExistence(timeout: 15))
        modsTab.click()

        // ModListRow's own "mod-row-FixtureMod" identifier (ModListRow.swift) takes over the
        // whole row's accessibility subtree on macOS — a button nested inside it can't carry
        // a distinct identifier of its own, so this locates the row's gear-icon button by its
        // (locale-independent) SF Symbol accessibility label instead.
        let configButton = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'mod-row-FixtureMod' AND label == 'gearshape'"))
            .firstMatch
        XCTAssertTrue(configButton.waitForExistence(timeout: 15), "the pre-installed fixture mod should show a config (gear) button, since it ships a config.json")
        configButton.click()

        let toggle = app.descendants(matching: .any)["config-field-EnableFeature"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.click()

        let saveButton = app.buttons["config-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isEnabled, "Save should enable once the field changed")
        saveButton.click()

        let configPath = workspace.gameDir.appendingPathComponent("Mods/FixtureMod/config.json")
        let deadline = Date().addingTimeInterval(10)
        var savedValue: Bool?
        while Date() < deadline {
            if let data = try? Data(contentsOf: configPath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                savedValue = json["EnableFeature"] as? Bool
                if savedValue == true { break }
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(savedValue, true, "config.json on disk should reflect the toggle after Save")
    }
}
