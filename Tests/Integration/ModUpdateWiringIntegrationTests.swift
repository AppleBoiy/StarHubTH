import XCTest
@testable import StarHubTH

/// Live integration test for the wiring `ModUpdateTests` doesn't cover: that file calls
/// `LiveNexusAPIClient` directly, simulating what the "Update" button does — this test
/// calls the real click's actual code path, `ModsStore.downloadAndInstallUpdate` (which
/// goes through `NexusDownloader`), so a break in that wiring shows up here even when the
/// underlying API client itself is fine.
@MainActor
final class ModUpdateWiringIntegrationTests: XCTestCase {
    func testDownloadAndInstallUpdateThroughModsStore() async throws {
        try XCTSkipIf(LiveTestGate.isSkipped, "STARHUB_SKIP_LIVE_TESTS=1")
        let apiKey = LiveTestGate.nexusApiKey
        try XCTSkipIf(apiKey.isEmpty, "No Nexus API Key found in com.appleboiy.StarHubTH defaults.")

        let tempGameDir = FileManager.default.temporaryDirectory.appendingPathComponent("StarHubTH_UpdateWiringTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempGameDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempGameDir) }

        let store = ModsStore(
            modScanning: StubModScanning(),
            modInstalling: ModInstaller(),
            nexusAPIClient: LiveNexusAPIClient.shared,
            filePicking: StubFilePicking(),
            preferenceStoring: StubPreferenceStoring(),
            localization: LocalizationStore(preferenceStoring: StubPreferenceStoring())
        )

        // Same mod every other Integration test targets: "Mail Framework Mod" (Nexus ID 1536).
        let updateInfo = ModUpdateInfo(name: "Mail Framework Mod", version: "unknown", url: "https://www.nexusmods.com/stardewvalley/mods/1536")

        await store.downloadAndInstallUpdate(
            for: updateInfo,
            nexusId: Mod.NexusID(rawValue: 1536),
            nexusApiKey: apiKey,
            gameDir: tempGameDir.path,
            showModal: { _ in },
            log: { _ in }
        )

        let modsPath = tempGameDir.appendingPathComponent("Mods")
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: modsPath.path)) ?? []
        XCTAssertFalse(contents.isEmpty, "downloadAndInstallUpdate should have installed the mod into Mods/ via the real NexusDownloader/ModInstaller wiring")
    }
}
