import XCTest
@testable import StarHubTH

/// Live integration test for the actual entry point a real `nxm://` link from a browser
/// hits — `AppCoordinator.handleOpenURL`. `NXMDownloadIntegrationTests` already covers
/// `LiveNexusAPIClient.downloadLink` + `NXMParser.parse` directly, but never through this
/// coordinator method, so a break in `handleOpenURL` itself (wrong scheme check, wrong
/// `NXMParser` result routing, wrong store call) wouldn't be caught there.
@MainActor
final class NXMOpenURLIntegrationTests: XCTestCase {
    func testHandleOpenURLDownloadsAndInstallsFromARealNXMLink() async throws {
        try XCTSkipIf(LiveTestGate.isSkipped, "STARHUB_SKIP_LIVE_TESTS=1")
        let apiKey = LiveTestGate.nexusApiKey
        try XCTSkipIf(apiKey.isEmpty, "No Nexus API Key found in com.appleboiy.StarHubTH defaults.")

        let tempGameDir = FileManager.default.temporaryDirectory.appendingPathComponent("StarHubTH_NXMOpenURLTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempGameDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempGameDir) }

        let preferenceStoring = StubPreferenceStoring()
        preferenceStoring.set(tempGameDir.path, forKey: "gameDir")
        preferenceStoring.set(apiKey, forKey: "nexusApiKey")

        let localizationStore = LocalizationStore(preferenceStoring: StubPreferenceStoring())
        let logStore = LogStore()
        let thaiHubStore = ThaiHubStore(localization: localizationStore)
        let profilesStore = ProfilesStore(profileStoring: StubProfileStoring(), localization: localizationStore)
        let modPacksStore = ModPacksStore(nexusAPIClient: LiveNexusAPIClient.shared, localization: localizationStore, logStore: logStore, filePicking: StubFilePicking())
        let savesStore = SavesStore(saveStoring: StubSaveStoring(), saveNoteStoring: StubSaveNoteStoring(), filePicking: StubFilePicking(), localization: localizationStore)
        let modsStore = ModsStore(
            modScanning: StubModScanning(),
            modInstalling: ModInstaller(),
            nexusAPIClient: LiveNexusAPIClient.shared,
            filePicking: StubFilePicking(),
            preferenceStoring: preferenceStoring,
            localization: localizationStore
        )
        let appEnvironment = AppEnvironment(preferenceStoring: preferenceStoring, localization: localizationStore)
        let alertStore = AlertStore()
        let toastStore = ToastStore()

        let coordinator = AppCoordinator(
            localizationStore: localizationStore,
            logStore: logStore,
            thaiHubStore: thaiHubStore,
            profilesStore: profilesStore,
            modPacksStore: modPacksStore,
            savesStore: savesStore,
            modsStore: modsStore,
            appEnvironment: appEnvironment,
            alertStore: alertStore,
            toastStore: toastStore,
            filePicking: StubFilePicking(),
            preferenceStoring: preferenceStoring
        )

        // Small mod for testing: Mail Framework Mod (modId: 1536, fileId: 128517, ~50KB) —
        // same target NXMDownloadIntegrationTests already uses.
        let url = URL(string: "nxm://stardewvalley/mods/1536/files/128517")!
        await coordinator.handleOpenURL(url)

        let modsPath = tempGameDir.appendingPathComponent("Mods")
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: modsPath.path)) ?? []
        XCTAssertFalse(contents.isEmpty, "handleOpenURL should have downloaded and installed the mod into Mods/ via the real coordinator/store wiring")
    }
}
