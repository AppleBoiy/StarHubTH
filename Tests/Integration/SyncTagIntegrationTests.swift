import XCTest
@testable import StarHubTH

/// Live integration test for "Sync Tag" (mod detail toolbar) — `ModsStoreTests` only
/// exercises this against `StubNexusAPIClient`; this closes the "never tested against real
/// Nexus data" gap for exactly one mod, not the full "Sync All" fan-out (that stays
/// stub-only — see docs/LIVE_NEXUS_WORKFLOW_TEST_PLAN.md).
@MainActor
final class SyncTagIntegrationTests: XCTestCase {
    func testSyncTagFromNexusForOneMod() async throws {
        try XCTSkipIf(LiveTestGate.isSkipped, "STARHUB_SKIP_LIVE_TESTS=1")
        let apiKey = LiveTestGate.nexusApiKey
        try XCTSkipIf(apiKey.isEmpty, "No Nexus API Key found in com.appleboiy.StarHubTH defaults.")

        let store = ModsStore(
            modScanning: StubModScanning(),
            modInstalling: StubModInstalling(),
            nexusAPIClient: LiveNexusAPIClient.shared,
            filePicking: StubFilePicking(),
            preferenceStoring: StubPreferenceStoring(),
            localization: LocalizationStore(preferenceStoring: StubPreferenceStoring())
        )

        // Same mod every other Integration test targets: "Mail Framework Mod" (Nexus ID 1536).
        let mod = Mod(
            uniqueId: Mod.UniqueID(rawValue: "DIGUS.MailFrameworkMod"),
            name: "Mail Framework Mod",
            folderName: Mod.FolderName(rawValue: "MailFrameworkMod"),
            version: "1.0.0",
            author: "DIGUS",
            description: "",
            nexusUrl: "https://www.nexusmods.com/stardewvalley/mods/1536",
            isEnabled: true,
            dependencies: [],
            kind: .single
        )

        await store.syncTagFromNexus(
            for: mod,
            nexusApiKey: apiKey,
            shouldRefresh: false,
            showModal: { _ in },
            refresh: {}
        )

        let syncedTag = store.customModTags[mod.uniqueId.rawValue]
        XCTAssertNotNil(syncedTag, "Syncing a real mod's tag from Nexus should set a custom tag from live category data")
    }
}
