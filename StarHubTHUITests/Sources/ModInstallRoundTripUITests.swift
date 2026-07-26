import XCTest

/// Exercises the real "Install Mod" pipeline end-to-end. XCUITest cannot drive `NSOpenPanel`,
/// so `STARHUB_UITEST_FIXTURE_MOD_PATH` (`StarHubTH/App/UITestFixture.swift`) substitutes a
/// fixture folder for the one step it can't automate — everything after that (`ModInstaller`
/// copying it into `gameDir/Mods`, `ModScanner` picking it up, the row appearing) is real,
/// unmodified app behavior.
@MainActor
final class ModInstallRoundTripUITests: XCTestCase {
    private var app: XCUIApplication!
    private var workspace: UITestEnvironment.Workspace!

    override func setUp() async throws {
        continueAfterFailure = false
        workspace = UITestEnvironment.makeWorkspace(preInstallFixtureMod: false)
        app = AppLauncher.launch(environment: workspace.launchEnvironment)
    }

    override func tearDown() async throws {
        app.terminate()
        workspace.cleanUp()
    }

    func testInstallingAModShowsItInTheModsList() throws {
        let modsTab = app.buttons["sidebar-tab-Mods"]
        XCTAssertTrue(modsTab.waitForExistence(timeout: 15))
        modsTab.click()

        let installButton = app.buttons["install-mod-button"]
        XCTAssertTrue(installButton.waitForExistence(timeout: 15))
        installButton.click()

        let row = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mod-row-FixtureMod'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "the fixture mod should appear in the Mods list after installing")
    }
}
