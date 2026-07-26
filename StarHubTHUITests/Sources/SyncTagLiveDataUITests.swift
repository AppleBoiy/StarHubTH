import XCTest

/// Tier C — see `docs/LIVE_NEXUS_WORKFLOW_TEST_PLAN.md` ("Tier C") and `TestPlans/UILive.xctestplan`.
/// Same real-key/real-GUI combination as `ModDetailLiveDataUITests`; see that file's doc
/// comment for why this stays out of the default `UI` plan.
@MainActor
final class SyncTagLiveDataUITests: XCTestCase {
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

    func testSyncTagUpdatesRowBadgeFromRealNexusCategory() throws {
        let modsTab = app.buttons["sidebar-tab-Mods"]
        XCTAssertTrue(modsTab.waitForExistence(timeout: 15))
        modsTab.click()

        // Before syncing, the fixture mod carries the local "Other" fallback tag (no keyword
        // in its name/uniqueId/description matches `Mod.inferTag`'s heuristics) — capture it
        // as the baseline the sync should change.
        let tagBadge = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mod-row-tag-FixtureMod'")).firstMatch
        XCTAssertTrue(tagBadge.waitForExistence(timeout: 15))
        let originalTagLabel = tagBadge.label

        // `mod-row-info-button-<folder>`'s own identifier is silently clobbered by the row's
        // `mod-row-<folder>` identifier (SWIFT_STANDARDS.md §10) — locate it the same way the
        // config-gear button already does: row identifier + the button's own SF Symbol label.
        let infoButton = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mod-row-FixtureMod' AND label == 'info.circle'")).firstMatch
        XCTAssertTrue(infoButton.waitForExistence(timeout: 15))
        infoButton.click()

        let syncButton = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mod-detail-sync-button'")).firstMatch
        XCTAssertTrue(syncButton.waitForExistence(timeout: 15), "the sync button only renders once a real nexusId and a configured API key are both present")
        syncButton.click()

        // syncTagFromNexus → setCustomTag(shouldRefresh: true) → AppCoordinator.refresh() →
        // ModsStore.scanMods rescans from disk with the newly-written customModTags, replacing
        // the in-memory Mod array — the row badge should update as a result, not just an
        // internal store dictionary invisible to the UI.
        let deadline = Date().addingTimeInterval(30)
        var updatedTagLabel = originalTagLabel
        while Date() < deadline {
            let currentBadge = self.app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'mod-row-tag-FixtureMod'")).firstMatch
            if currentBadge.exists, currentBadge.label != originalTagLabel {
                updatedTagLabel = currentBadge.label
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertNotEqual(updatedTagLabel, originalTagLabel, "syncing against real Nexus category data should change the row's tag badge from its local fallback")
    }
}
