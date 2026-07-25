import Foundation

/// Characterization tests for SavesStore, extracted from StarHubTHViewModel in refactor
/// Phase 4.6. This is the first store test using three stubs at once (SaveStoring,
/// SaveNoteStoring, FilePicking) — every one of its dependencies is a real protocol.
@MainActor
struct SavesStoreTests {
    static func run() {
        print("Running SavesStoreTests...")
        testReloadSaves()
        testEditSaveSuccessAndFailure()
        testDeleteSave()
        testSavesHierarchyBuildsParentChildTree()
        testSavesHierarchyFiltersByTag()
        testAvailableFilterTags()
        testSetAvatarAndGetNote()
        testSelectCustomAvatarCopiesPickedFile()
        testEditingSaveLoadsInventory()
    }

    private static func save(_ folderName: String, playerName: String = "Player") -> SaveGameInfo {
        SaveGameInfo(
            folderName: folderName,
            fileURL: URL(fileURLWithPath: "/tmp/\(folderName)/\(folderName)"),
            lastModified: Date(),
            playerName: playerName,
            farmName: "Farm",
            favoriteThing: "",
            money: 0,
            spouse: "",
            maxHealth: 100,
            maxStamina: 100,
            goldenWalnuts: 0,
            qiGems: 0,
            clubCoins: 0,
            totalMoneyEarned: 0,
            year: 1,
            season: 0,
            day: 1,
            whichFarm: 0
        )
    }

    private static func makeStore(saves: [SaveGameInfo] = []) -> (SavesStore, StubSaveStoring, StubSaveNoteStoring, StubFilePicking) {
        let saveStoring = StubSaveStoring()
        saveStoring.saves = saves
        let noteStoring = StubSaveNoteStoring()
        let filePicking = StubFilePicking()
        let store = SavesStore(
            saveStoring: saveStoring,
            saveNoteStoring: noteStoring,
            filePicking: filePicking,
            localization: LocalizationStore(preferenceStoring: StubPreferenceStoring())
        )
        return (store, saveStoring, noteStoring, filePicking)
    }

    private static func testReloadSaves() {
        let (store, _, _, _) = makeStore(saves: [save("Farm1"), save("Farm2")])
        store.reloadSaves()
        SimpleTestFramework.assertEqual(store.saves.count, 2, "reloadSaves reads saves from the backing store")
    }

    private static func testEditSaveSuccessAndFailure() {
        let (store, stub, _, _) = makeStore(saves: [save("Farm1")])
        store.reloadSaves()

        var messages: [String] = []
        let showModal: (String) -> Void = { messages.append($0) }

        stub.operationsSucceed = true
        store.editSave(info: save("Farm1"), newName: "New", newFarm: "F", newFav: "", newMoney: 0, newTotalMoneyEarned: 0, newMaxHealth: 100, newMaxStamina: 100, newGoldenWalnuts: 0, newQiGems: 0, newClubCoins: 0, newSpouse: "", showModal: showModal)
        SimpleTestFramework.assertEqual(messages.count, 1, "a successful edit shows exactly one modal")

        stub.operationsSucceed = false
        store.editSave(info: save("Farm1"), newName: "New", newFarm: "F", newFav: "", newMoney: 0, newTotalMoneyEarned: 0, newMaxHealth: 100, newMaxStamina: 100, newGoldenWalnuts: 0, newQiGems: 0, newClubCoins: 0, newSpouse: "", showModal: showModal)
        SimpleTestFramework.assertEqual(messages.count, 2, "a failed edit also shows a modal")
    }

    private static func testDeleteSave() {
        let (store, stub, _, _) = makeStore(saves: [save("Farm1")])
        store.reloadSaves()
        stub.operationsSucceed = true

        var succeeded = false
        store.deleteSave(info: save("Farm1"), showModal: { message in
            succeeded = message.count >= 0 // just confirm a message was produced
        })
        SimpleTestFramework.assertTrue(succeeded, "deleteSave shows a modal on success")
    }

    private static func testSavesHierarchyBuildsParentChildTree() {
        let (store, _, _, _) = makeStore(saves: [save("Farm1"), save("Farm1_branch")])
        store.reloadSaves()

        let roots = store.savesHierarchy
        SimpleTestFramework.assertEqual(roots.count, 1, "a branch save nests under its parent instead of appearing at the root")
        SimpleTestFramework.assertEqual(roots.first?.children.count, 1, "the parent has exactly one child")
    }

    private static func testSavesHierarchyFiltersByTag() {
        let (store, _, noteStoring, _) = makeStore(saves: [save("Farm1"), save("Farm2")])
        store.reloadSaves()
        noteStoring.setNote("", tag: "star", forSave: "Farm1", customIconPath: nil)

        store.saveFilterTag = "star"
        let roots = store.savesHierarchy
        SimpleTestFramework.assertEqual(roots.count, 1, "the tag filter keeps only saves carrying that tag")
        SimpleTestFramework.assertEqual(roots.first?.info.folderName, "Farm1", "the surviving save is the one with the matching tag")
    }

    private static func testAvailableFilterTags() {
        let (store, _, noteStoring, _) = makeStore(saves: [save("Farm1"), save("Farm2")])
        store.reloadSaves()
        noteStoring.setNote("", tag: "star", forSave: "Farm1", customIconPath: nil)

        SimpleTestFramework.assertEqual(store.availableFilterTags, ["star"], "availableFilterTags collects distinct non-empty tags across saves")
    }

    private static func testSetAvatarAndGetNote() {
        let (store, _, _, _) = makeStore()
        store.setAvatar(forSave: "Farm1", iconPath: "/tmp/icon.png")
        SimpleTestFramework.assertEqual(store.note(for: "Farm1").customIconPath, "/tmp/icon.png", "setAvatar persists the icon path via SaveNoteStoring")
    }

    private static func testSelectCustomAvatarCopiesPickedFile() {
        let (store, _, _, filePicking) = makeStore()
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        try! Data([0x01, 0x02]).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        filePicking.filesToReturn = [sourceURL]

        var completedPath: String?
        store.selectCustomAvatar(forSave: "Farm1") { path in completedPath = path }

        SimpleTestFramework.assertTrue(completedPath != nil, "selectCustomAvatar's completion fires with the copied file's path")
        SimpleTestFramework.assertEqual(store.note(for: "Farm1").customIconPath, completedPath, "the copied path is persisted as the save's avatar")
    }

    private static func testEditingSaveLoadsInventory() {
        let (store, stub, _, _) = makeStore()
        let item = InventoryItem(slotIndex: 0, itemId: "1", name: "Test Item", stack: 1, isObject: true)
        stub.inventory = [item]

        store.editingSave = save("Farm1")
        SimpleTestFramework.assertEqual(store.inventoryToEdit.count, 1, "setting editingSave loads that save's inventory")

        store.editingSave = nil
        SimpleTestFramework.assertTrue(store.inventoryToEdit.isEmpty, "clearing editingSave clears the loaded inventory")
    }
}
