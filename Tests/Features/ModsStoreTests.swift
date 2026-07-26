import XCTest
@testable import StarHubTH

/// Characterization tests for ModsStore, extracted from StarHubTHViewModel in refactor
/// Phase 4.7. Covers what's testable via stubs: scanning, custom tags, and mod
/// installation. toggleMod and downloadAndInstallUpdate (uses NexusDownloader, which has
/// no protocol seam) shell out to real Process/FileManager work with no injection seam —
/// same reasoning as LogStore's loadSmapiLog(). backUp/restore's panel selection now goes
/// through the injected FilePicking, so their guard-clause and picker-cancelled paths are
/// covered here; the zip/unzip Process itself still isn't mocked, so the success path
/// isn't.
@MainActor
final class ModsStoreTests: XCTestCase {
    private func mod(_ uniqueId: String, enabled: Bool = true, nexusUrl: String = "") -> Mod {
        Mod(
            uniqueId: Mod.UniqueID(rawValue: uniqueId),
            name: uniqueId,
            folderName: Mod.FolderName(rawValue: uniqueId),
            version: "1.0.0",
            author: "Author",
            description: "",
            nexusUrl: nexusUrl,
            isEnabled: enabled,
            dependencies: [],
            kind: .single
        )
    }

    private func makeStore() -> (store: ModsStore, scanning: StubModScanning, installing: StubModInstalling, filePicking: StubFilePicking, preferenceStoring: StubPreferenceStoring, nexusAPIClient: StubNexusAPIClient) {
        let scanning = StubModScanning()
        let installing = StubModInstalling()
        let filePicking = StubFilePicking()
        let preferenceStoring = StubPreferenceStoring()
        let nexusAPIClient = StubNexusAPIClient()
        let store = ModsStore(
            modScanning: scanning,
            modInstalling: installing,
            nexusAPIClient: nexusAPIClient,
            filePicking: filePicking,
            preferenceStoring: preferenceStoring,
            localization: LocalizationStore(preferenceStoring: StubPreferenceStoring())
        )
        return (store, scanning, installing, filePicking, preferenceStoring, nexusAPIClient)
    }

    func testDependencyDelegationToModGraph() {
        let (store, _, _, _, _, _) = makeStore()
        store.mods = [mod("a.mod", enabled: true)]
        XCTAssertEqual(
            store.resolveDependencyStatus(for: Mod.UniqueID(rawValue: "a.mod")), .active,
            "resolveDependencyStatus delegates to ModGraph using the store's own mods"
        )
        XCTAssertEqual(
            store.missingDependencies(for: mod("b.mod")), [],
            "missingDependencies delegates to ModGraph"
        )
    }

    func testCustomModTagsRoundTrip() {
        let (store, _, _, _, _, _) = makeStore()
        store.customModTags = ["a.mod": "Framework"]
        XCTAssertEqual(store.customModTags["a.mod"], "Framework", "customModTags persists through the injected PreferenceStoring")
    }

    func testSetCustomTagRefreshesConditionally() {
        let (store, _, _, _, _, _) = makeStore()
        var refreshCount = 0

        store.setCustomTag(for: Mod.UniqueID(rawValue: "a.mod"), tag: "UI", shouldRefresh: true, refresh: { refreshCount += 1 })
        XCTAssertEqual(refreshCount, 1, "setCustomTag refreshes when shouldRefresh is true")
        XCTAssertEqual(store.customModTags["a.mod"], "UI", "setCustomTag persists the new tag")

        store.setCustomTag(for: Mod.UniqueID(rawValue: "b.mod"), tag: "Audio", shouldRefresh: false, refresh: { refreshCount += 1 })
        XCTAssertEqual(refreshCount, 1, "setCustomTag does not refresh when shouldRefresh is false")
    }

    func testResetCustomTagAlwaysRefreshes() {
        let (store, _, _, _, _, _) = makeStore()
        store.customModTags = ["a.mod": "UI"]
        var refreshCount = 0

        store.resetCustomTag(for: Mod.UniqueID(rawValue: "a.mod"), refresh: { refreshCount += 1 })
        XCTAssertEqual(refreshCount, 1, "resetCustomTag always refreshes")
        XCTAssertTrue(store.customModTags["a.mod"] == nil, "resetCustomTag removes the tag")
    }

    /// `scanMods` is a plain synchronous method (no `DispatchQueue.main.async` hop, unlike
    /// when this suite ran under the old custom TestRunner) — no draining/pumping needed
    /// to observe its effect.
    func testScanModsPopulatesStateFromStub() {
        let (store, scanning, _, _, _, _) = makeStore()
        scanning.mods = [mod("a.mod"), mod("stardew valley - thai", enabled: true)]

        store.scanMods(gameDir: "/fake/gamedir")

        XCTAssertEqual(scanning.lastGameDir, "/fake/gamedir", "scanMods passes gameDir through to ModScanning")
        XCTAssertEqual(store.mods.count, 2, "scanMods populates mods from the scan result")
        XCTAssertEqual(store.selectedMod?.uniqueId, Mod.UniqueID(rawValue: "a.mod"), "scanMods selects the first mod when nothing was selected")
        XCTAssertTrue(store.isThaiTranslationInstalled, "scanMods detects an installed, enabled Thai translation mod")
    }

    func testInstallModRequiresGameDir() async {
        let (store, _, _, _, _, _) = makeStore()
        var modalMessage: String?
        try? await store.installMod(url: URL(fileURLWithPath: "/tmp/mod.zip"), gameDir: "", showModal: { modalMessage = $0 }, log: { _ in })
        XCTAssertTrue(modalMessage != nil, "installMod shows a modal when gameDir is empty")
    }

    func testInstallModFromZipUsesModInstalling() async {
        let (store, _, installing, _, _, _) = makeStore()
        installing.installFromZipResult = .success(["MyMod"])

        var successMessage: String?
        var logged: String?
        try? await store.installModFromZip(
            url: URL(fileURLWithPath: "/tmp/mod.zip"),
            gameDir: "/fake/gamedir",
            showModal: { successMessage = $0 },
            log: { logged = $0 }
        )
        XCTAssertTrue(successMessage != nil, "a successful install shows a modal")
        XCTAssertTrue(logged != nil, "a successful install logs a message")
        XCTAssertFalse(store.isInstallingMod, "isInstallingMod resets to false after completion")
    }

    func testOpenInstallModPanelInstallsEachPickedURL() async {
        let (store, _, installing, filePicking, _, _) = makeStore()
        installing.installFromZipResult = .success(["MyMod"])
        filePicking.filesToReturn = [URL(fileURLWithPath: "/tmp/one.zip"), URL(fileURLWithPath: "/tmp/two.zip")]

        var modalCount = 0
        await store.openInstallModPanel(gameDir: "/fake/gamedir", showModal: { _ in modalCount += 1 }, log: { _ in })
        XCTAssertEqual(modalCount, 2, "openInstallModPanel installs every URL FilePicking returns")
    }

    func testSyncTagFromNexusShowsModalOnApiFailure() async {
        let (store, _, _, _, _, nexusAPIClient) = makeStore()
        nexusAPIClient.modInfoResult = .failure(StubError.unconfigured)

        var modalMessage: String?
        await store.syncTagFromNexus(
            for: mod("a.mod", nexusUrl: "https://www.nexusmods.com/stardewvalley/mods/12345"),
            nexusApiKey: "test-key",
            showModal: { modalMessage = $0 },
            refresh: {}
        )
        XCTAssertTrue(modalMessage != nil, "syncTagFromNexus shows a modal when the Nexus API call fails")
    }

    func testSyncTagFromNexusIsSilentWithoutNexusUrl() async {
        let (store, _, _, _, _, _) = makeStore()

        var modalMessage: String?
        await store.syncTagFromNexus(
            for: mod("a.mod", nexusUrl: ""),
            nexusApiKey: "test-key",
            showModal: { modalMessage = $0 },
            refresh: {}
        )
        XCTAssertTrue(modalMessage == nil, "syncTagFromNexus stays silent when the mod has no valid Nexus URL")
    }

    func testBackUpRequiresGameDir() async {
        let (store, _, _, _, _, _) = makeStore()
        var modalMessage: String?
        await store.backUp(mod("a.mod"), gameDir: "", showModal: { modalMessage = $0 })
        XCTAssertTrue(modalMessage != nil, "backUp shows a modal when gameDir is empty")
    }

    func testBackUpDoesNothingWhenSaveLocationCancelled() async {
        let (store, _, _, filePicking, _, _) = makeStore()
        filePicking.saveLocationToReturn = nil
        var modalMessage: String?
        await store.backUp(mod("a.mod"), gameDir: "/fake/gamedir", showModal: { modalMessage = $0 })
        XCTAssertTrue(modalMessage == nil, "backUp does nothing when the save panel is cancelled")
        XCTAssertEqual(filePicking.pickedSaveLocationCalls.count, 1, "backUp asks FilePicking for a save location")
    }

    func testRestoreRequiresGameDir() async {
        let (store, _, _, _, _, _) = makeStore()
        var modalMessage: String?
        await store.restore(mod("a.mod"), gameDir: "", showModal: { modalMessage = $0 })
        XCTAssertTrue(modalMessage != nil, "restore shows a modal when gameDir is empty")
    }

    func testRestoreDoesNothingWhenNoFilePicked() async {
        let (store, _, _, filePicking, _, _) = makeStore()
        filePicking.filesToReturn = []
        var modalMessage: String?
        await store.restore(mod("a.mod"), gameDir: "/fake/gamedir", showModal: { modalMessage = $0 })
        XCTAssertTrue(modalMessage == nil, "restore does nothing when no backup file is picked")
    }
}
