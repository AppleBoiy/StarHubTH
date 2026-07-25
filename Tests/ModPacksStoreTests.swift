import Foundation

/// Characterization tests for ModPacksStore, extracted from StarHubTHViewModel in
/// refactor Phase 4.5. Uses StubNexusAPIClient (Phase 3.2) for the network-dependent
/// paths; exportModPack (NSSavePanel) and downloadModFromNexus's success path (real
/// file download + unzip) aren't covered here, same reasoning as LogStore's
/// loadSmapiLog() — no injection seam for those without a bigger change than this
/// extraction warrants.
struct ModPacksStoreTests {
    static func run() async {
        print("Running ModPacksStoreTests...")
        testImportModPackDecodesValidJSON()
        testImportModPackRejectsInvalidJSON()
        await testImportCollectionFromURLRejectsInvalidURL()
        await testImportCollectionFromURLRequiresAPIKey()
        await testImportCollectionFromURLFetchesGraph()
        await testDownloadModFromNexusRequiresAPIKey()
    }

    private static func makeStore() -> (ModPacksStore, StubNexusAPIClient) {
        let stub = StubNexusAPIClient()
        let store = ModPacksStore(
            nexusAPIClient: stub,
            localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()),
            logStore: LogStore()
        )
        return (store, stub)
    }

    private static func testImportModPackDecodesValidJSON() {
        let (store, _) = makeStore()
        let pack = StarHubPack(packName: "Test Pack", author: "Someone", description: nil, mods: [])
        let data = try! JSONEncoder().encode(pack)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).starhubpack")
        try! data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let decoded = store.importModPack(from: url)
        SimpleTestFramework.assertEqual(decoded?.packName, "Test Pack", "importModPack decodes a valid pack file")
    }

    private static func testImportModPackRejectsInvalidJSON() {
        let (store, _) = makeStore()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).starhubpack")
        try! Data("not json".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        SimpleTestFramework.assertTrue(store.importModPack(from: url) == nil, "importModPack returns nil for invalid JSON")
    }

    private static func testImportCollectionFromURLRejectsInvalidURL() async {
        let (store, _) = makeStore()
        // A well-formed URL with no "collections" path segment — the slug extraction
        // finds nothing, which is the guaranteed-empty-slug path.
        let pack = await store.importCollectionFromURL("https://next.nexusmods.com/stardewvalley/mods/123", nexusApiKey: "key", showModal: { _ in })
        SimpleTestFramework.assertTrue(pack == nil, "a URL with no collections segment resolves to nil")
    }

    private static func testImportCollectionFromURLRequiresAPIKey() async {
        let (store, _) = makeStore()
        var modalMessage: String?
        let pack = await store.importCollectionFromURL(
            "https://next.nexusmods.com/stardewvalley/collections/abc123",
            nexusApiKey: "",
            showModal: { message in modalMessage = message }
        )
        SimpleTestFramework.assertTrue(pack == nil, "no API key resolves to a nil pack")
        SimpleTestFramework.assertTrue(modalMessage != nil, "a missing API key shows a modal message")
    }

    private static func testImportCollectionFromURLFetchesGraph() async {
        let (store, stub) = makeStore()
        let graph = LiveNexusAPIClient.CollectionGraph(
            id: 1, slug: "abc123", name: "My Collection", summary: "A summary",
            endorsements: 5, totalDownloads: 100, updatedAt: nil,
            tileImage: nil, user: LiveNexusAPIClient.CollectionUser(name: "Someone"),
            latestPublishedRevision: nil, game: nil
        )
        stub.collectionGraphResult = .success(graph)

        let received = await store.importCollectionFromURL(
            "https://next.nexusmods.com/stardewvalley/collections/abc123",
            nexusApiKey: "real-key",
            showModal: { _ in }
        )

        SimpleTestFramework.assertEqual(received?.packName, "My Collection", "a successful graph fetch produces a pack with the collection's name")
        SimpleTestFramework.assertEqual(received?.author, "Someone", "the pack's author comes from the collection's user")
    }

    private static func testDownloadModFromNexusRequiresAPIKey() async {
        let (store, _) = makeStore()
        let success = await store.downloadModFromNexus(
            nexusId: ModItem.NexusID(rawValue: 1234),
            nexusApiKey: "",
            installModFromZip: { _, completion in completion(true) },
            showModal: { _ in }
        )
        SimpleTestFramework.assertTrue(success == false, "no API key resolves to false")
    }
}
