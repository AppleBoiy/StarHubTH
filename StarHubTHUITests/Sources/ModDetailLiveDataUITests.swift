import XCTest

/// Tier C — see `docs/LIVE_NEXUS_WORKFLOW_TEST_PLAN.md` ("Tier C") and `TestPlans/UILive.xctestplan`.
/// Combines a real GUI session with the real Nexus API key already configured in the app's own
/// Settings screen (`LiveUITestGate`) — skips itself when none is configured, same discipline as
/// `Tests/Integration/*`. Not part of the default `UI` plan: mixing a key-dependent self-skip
/// into `TestPlans/UI.xctestplan` would mean every contributor without a configured key sees
/// silent skips there by default, a worse default than a separate opt-in plan.
@MainActor
final class ModDetailLiveDataUITests: XCTestCase {
    private var app: XCUIApplication!
    private var workspace: UITestEnvironment.Workspace!

    override func setUp() async throws {
        continueAfterFailure = false
        try XCTSkipIf(LiveUITestGate.nexusApiKey.isEmpty, "No Nexus API Key found in com.appleboiy.StarHubTH defaults.")

        // Mail Framework Mod (Nexus ID 1536) — same canonical target Tests/Integration/ uses.
        workspace = UITestEnvironment.makeWorkspace(preInstallFixtureMod: true, nexusModId: 1536, useRealApiKey: true)
        app = AppLauncher.launch(environment: workspace.launchEnvironment)
    }

    override func tearDown() async throws {
        app.terminate()
        workspace.cleanUp()
    }

    func testOpeningModDetailLoadsRealNexusCoverImage() throws {
        let modsTab = app.buttons["sidebar-tab-Mods"]
        XCTAssertTrue(modsTab.waitForExistence(timeout: 15))
        modsTab.click()

        // `mod-row-info-button-<folder>`'s own identifier is silently clobbered by the row's
        // `mod-row-<folder>` identifier (SWIFT_STANDARDS.md §10) — locate it the same way the
        // config-gear button already does: row identifier + the button's own SF Symbol label.
        let infoButton = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mod-row-FixtureMod' AND label == 'info.circle'")).firstMatch
        XCTAssertTrue(infoButton.waitForExistence(timeout: 15))
        infoButton.click()

        // `mod-detail-cover-image` only exists in the view tree once `ModDetailView` has a
        // non-nil `coverUrl` — set exclusively by a successful `fetchNexusInfo` response, so
        // its presence is direct proof a real Nexus API response was loaded and rendered.
        let coverImage = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mod-detail-cover-image'")).firstMatch
        XCTAssertTrue(coverImage.waitForExistence(timeout: 30), "a real modInfo response for a real mod should include a cover image, populating coverUrl")
    }
}
