import XCTest
@testable import StarHubTH

/// Characterization tests for ModPacksStore, extracted from StarHubTHViewModel in
/// refactor Phase 4.5. Uses StubNexusAPIClient (Phase 3.2) for the network-dependent
/// paths; downloadModFromNexus's success path (real file download + unzip) isn't
/// covered here, same reasoning as LogStore's loadSmapiLog() — no injection seam for
/// that without a bigger change than this extraction warrants.
@MainActor
final class ModPacksStoreTests: XCTestCase {
    private func makeStore() -> (store: ModPacksStore, nexusAPIClient: StubNexusAPIClient, filePicking: StubFilePicking) {
        let stub = StubNexusAPIClient()
        let filePicking = StubFilePicking()
        let store = ModPacksStore(
            nexusAPIClient: stub,
            localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()),
            logStore: LogStore(),
            filePicking: filePicking
        )
        return (store, stub, filePicking)
    }

    func testImportModPackDecodesValidJSON() {
        let (store, _, _) = makeStore()
        let pack = StarHubPack(packName: "Test Pack", author: "Someone", description: nil, mods: [])
        let data = try! JSONEncoder().encode(pack)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).starhubpack")
        try! data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let decoded = store.importModPack(from: url)
        XCTAssertEqual(decoded?.packName, "Test Pack", "importModPack decodes a valid pack file")
    }

    func testImportModPackRejectsInvalidJSON() {
        let (store, _, _) = makeStore()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).starhubpack")
        try! Data("not json".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(store.importModPack(from: url) == nil, "importModPack returns nil for invalid JSON")
    }

    func testImportCollectionFromURLRejectsInvalidURL() async {
        let (store, _, _) = makeStore()
        // A well-formed URL with no "collections" path segment — the slug extraction
        // finds nothing, which is the guaranteed-empty-slug path.
        let pack = await store.importCollectionFromURL("https://next.nexusmods.com/stardewvalley/mods/123", nexusApiKey: "key", showModal: { _ in })
        XCTAssertTrue(pack == nil, "a URL with no collections segment resolves to nil")
    }

    func testImportCollectionFromURLRequiresAPIKey() async {
        let (store, _, _) = makeStore()
        var modalMessage: String?
        let pack = await store.importCollectionFromURL(
            "https://next.nexusmods.com/stardewvalley/collections/abc123",
            nexusApiKey: "",
            showModal: { message in modalMessage = message }
        )
        XCTAssertTrue(pack == nil, "no API key resolves to a nil pack")
        XCTAssertTrue(modalMessage != nil, "a missing API key shows a modal message")
    }

    func testImportCollectionFromURLFetchesGraph() async {
        let (store, stub, _) = makeStore()
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

        XCTAssertEqual(received?.packName, "My Collection", "a successful graph fetch produces a pack with the collection's name")
        XCTAssertEqual(received?.author, "Someone", "the pack's author comes from the collection's user")
    }

    func testDownloadModFromNexusRequiresAPIKey() async {
        let (store, _, _) = makeStore()
        let success = await store.downloadModFromNexus(
            nexusId: Mod.NexusID(rawValue: 1234),
            nexusApiKey: "",
            installModFromZip: { _, completion in completion(true) },
            showModal: { _ in }
        )
        XCTAssertTrue(success == false, "no API key resolves to false")
    }

    private func enabledMod(_ uniqueId: String) -> Mod {
        Mod(
            uniqueId: Mod.UniqueID(rawValue: uniqueId),
            name: uniqueId,
            folderName: Mod.FolderName(rawValue: uniqueId),
            version: "1.0.0",
            author: "Author",
            description: "",
            nexusUrl: "",
            isEnabled: true,
            dependencies: [],
            kind: .single
        )
    }

    func testExportModPackWritesToPickedLocation() {
        let (store, _, filePicking) = makeStore()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).starhubpack")
        filePicking.saveLocationToReturn = destination
        defer { try? FileManager.default.removeItem(at: destination) }

        let url = store.exportModPack(name: "My Pack", mods: [enabledMod("a.mod")], steamUsername: "Player", showModal: { _ in })

        XCTAssertTrue(url == destination, "exportModPack writes to the URL FilePicking returns")
        XCTAssertEqual(filePicking.pickedSaveLocationCalls.count, 1, "exportModPack asks FilePicking for a save location")
        XCTAssertTrue(filePicking.pickedSaveLocationCalls.first?.suggestedName == "My_Pack.starhubpack", "the suggested name spaces-to-underscores the pack name")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path), "exportModPack writes pack data to the picked location")
    }

    func testExportModPackReturnsNilWhenPickerCancelled() {
        let (store, _, filePicking) = makeStore()
        filePicking.saveLocationToReturn = nil

        let url = store.exportModPack(name: "My Pack", mods: [enabledMod("a.mod")], steamUsername: "Player", showModal: { _ in })

        XCTAssertTrue(url == nil, "exportModPack returns nil when the user cancels the save panel")
    }
}
