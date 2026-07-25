import Foundation

/// Characterization tests for ModsStore, extracted from StarHubTHViewModel in refactor
/// Phase 4.7. Covers what's testable via stubs: scanning, custom tags, and mod
/// installation. toggleMod, downloadAndInstallUpdate (uses NexusDownloader, which has no
/// protocol seam), and the Mods-directory backup/restore trio all shell out to real
/// Process/FileManager work with no injection seam — same reasoning as LogStore's
/// loadSmapiLog() and ModPacksStore's exportModPack.
@MainActor
struct ModsStoreTests {
    static func run() async {
        print("Running ModsStoreTests...")
        testDependencyDelegationToModGraph()
        testCustomModTagsRoundTrip()
        testSetCustomTagRefreshesConditionally()
        testResetCustomTagAlwaysRefreshes()
        testScanModsPopulatesStateFromStub()
        await testInstallModRequiresGameDir()
        await testInstallModFromZipUsesModInstalling()
        await testOpenInstallModPanelInstallsEachPickedURL()
        await testSyncTagFromNexusShowsModalOnApiFailure()
        await testSyncTagFromNexusIsSilentWithoutNexusUrl()
    }

    /// scanMods still wraps its state update in DispatchQueue.main.async (unconverted —
    /// out of scope for the install cluster). Queueing another block on the main queue
    /// afterward and waiting for it runs after anything already pending there, since it's
    /// a serial FIFO queue — this only resolves because Tests/main.swift runs this whole
    /// suite on a background thread while pumping RunLoop.main.
    private static func drainMainQueue() {
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.main.async { sem.signal() }
        _ = sem.wait(timeout: .now() + 2)
    }

    private static func mod(_ uniqueId: String, enabled: Bool = true, nexusUrl: String = "") -> Mod {
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

    private static func makeStore() -> (store: ModsStore, scanning: StubModScanning, installing: StubModInstalling, filePicking: StubFilePicking, preferenceStoring: StubPreferenceStoring, nexusAPIClient: StubNexusAPIClient) {
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

    private static func testDependencyDelegationToModGraph() {
        let (store, _, _, _, _, _) = makeStore()
        store.mods = [mod("a.mod", enabled: true)]
        SimpleTestFramework.assertEqual(
            store.resolveDependencyStatus(for: Mod.UniqueID(rawValue: "a.mod")), .active,
            "resolveDependencyStatus delegates to ModGraph using the store's own mods"
        )
        SimpleTestFramework.assertEqual(
            store.missingDependencies(for: mod("b.mod")), [],
            "missingDependencies delegates to ModGraph"
        )
    }

    private static func testCustomModTagsRoundTrip() {
        let (store, _, _, _, _, _) = makeStore()
        store.customModTags = ["a.mod": "Framework"]
        SimpleTestFramework.assertEqual(store.customModTags["a.mod"], "Framework", "customModTags persists through the injected PreferenceStoring")
    }

    private static func testSetCustomTagRefreshesConditionally() {
        let (store, _, _, _, _, _) = makeStore()
        var refreshCount = 0

        store.setCustomTag(for: Mod.UniqueID(rawValue: "a.mod"), tag: "UI", shouldRefresh: true, refresh: { refreshCount += 1 })
        SimpleTestFramework.assertEqual(refreshCount, 1, "setCustomTag refreshes when shouldRefresh is true")
        SimpleTestFramework.assertEqual(store.customModTags["a.mod"], "UI", "setCustomTag persists the new tag")

        store.setCustomTag(for: Mod.UniqueID(rawValue: "b.mod"), tag: "Audio", shouldRefresh: false, refresh: { refreshCount += 1 })
        SimpleTestFramework.assertEqual(refreshCount, 1, "setCustomTag does not refresh when shouldRefresh is false")
    }

    private static func testResetCustomTagAlwaysRefreshes() {
        let (store, _, _, _, _, _) = makeStore()
        store.customModTags = ["a.mod": "UI"]
        var refreshCount = 0

        store.resetCustomTag(for: Mod.UniqueID(rawValue: "a.mod"), refresh: { refreshCount += 1 })
        SimpleTestFramework.assertEqual(refreshCount, 1, "resetCustomTag always refreshes")
        SimpleTestFramework.assertTrue(store.customModTags["a.mod"] == nil, "resetCustomTag removes the tag")
    }

    private static func testScanModsPopulatesStateFromStub() {
        let (store, scanning, _, _, _, _) = makeStore()
        scanning.mods = [mod("a.mod"), mod("stardew valley - thai", enabled: true)]

        store.scanMods(gameDir: "/fake/gamedir")
        drainMainQueue()

        SimpleTestFramework.assertEqual(scanning.lastGameDir, "/fake/gamedir", "scanMods passes gameDir through to ModScanning")
        SimpleTestFramework.assertEqual(store.mods.count, 2, "scanMods populates mods from the scan result")
        SimpleTestFramework.assertEqual(store.selectedMod?.uniqueId, Mod.UniqueID(rawValue: "a.mod"), "scanMods selects the first mod when nothing was selected")
        SimpleTestFramework.assertTrue(store.isThaiTranslationInstalled, "scanMods detects an installed, enabled Thai translation mod")
    }

    private static func testInstallModRequiresGameDir() async {
        let (store, _, _, _, _, _) = makeStore()
        var modalMessage: String?
        try? await store.installMod(url: URL(fileURLWithPath: "/tmp/mod.zip"), gameDir: "", showModal: { modalMessage = $0 }, log: { _ in })
        SimpleTestFramework.assertTrue(modalMessage != nil, "installMod shows a modal when gameDir is empty")
    }

    private static func testInstallModFromZipUsesModInstalling() async {
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
        SimpleTestFramework.assertTrue(successMessage != nil, "a successful install shows a modal")
        SimpleTestFramework.assertTrue(logged != nil, "a successful install logs a message")
        SimpleTestFramework.assertFalse(store.isInstallingMod, "isInstallingMod resets to false after completion")
    }

    private static func testOpenInstallModPanelInstallsEachPickedURL() async {
        let (store, _, installing, filePicking, _, _) = makeStore()
        installing.installFromZipResult = .success(["MyMod"])
        filePicking.filesToReturn = [URL(fileURLWithPath: "/tmp/one.zip"), URL(fileURLWithPath: "/tmp/two.zip")]

        var modalCount = 0
        await store.openInstallModPanel(gameDir: "/fake/gamedir", showModal: { _ in modalCount += 1 }, log: { _ in })
        SimpleTestFramework.assertEqual(modalCount, 2, "openInstallModPanel installs every URL FilePicking returns")
    }

    private static func testSyncTagFromNexusShowsModalOnApiFailure() async {
        let (store, _, _, _, _, nexusAPIClient) = makeStore()
        nexusAPIClient.modInfoResult = .failure(StubError.unconfigured)

        var modalMessage: String?
        await store.syncTagFromNexus(
            for: mod("a.mod", nexusUrl: "https://www.nexusmods.com/stardewvalley/mods/12345"),
            nexusApiKey: "test-key",
            showModal: { modalMessage = $0 },
            refresh: {}
        )
        SimpleTestFramework.assertTrue(modalMessage != nil, "syncTagFromNexus shows a modal when the Nexus API call fails")
    }

    private static func testSyncTagFromNexusIsSilentWithoutNexusUrl() async {
        let (store, _, _, _, _, _) = makeStore()

        var modalMessage: String?
        await store.syncTagFromNexus(
            for: mod("a.mod", nexusUrl: ""),
            nexusApiKey: "test-key",
            showModal: { modalMessage = $0 },
            refresh: {}
        )
        SimpleTestFramework.assertTrue(modalMessage == nil, "syncTagFromNexus stays silent when the mod has no valid Nexus URL")
    }
}
