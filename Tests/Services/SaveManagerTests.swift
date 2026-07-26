import XCTest
@testable import StarHubTH

/// Exercises real `SaveManager` filesystem operations against synthetic save folders on
/// disk. `SavesStoreTests` only covers the store's delegation through `SaveStoring` — it
/// never runs `SaveManager`'s actual file handling, which is where the fixed bugs lived.
final class SaveManagerTests: XCTestCase {
    private func makeTempSaveFolder(saveName: String, saveXML: String, saveGameInfoData: Data? = nil) -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StarHubTH_SaveManagerTest_\(UUID().uuidString)")
        let folder = root.appendingPathComponent(saveName)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? saveXML.write(to: folder.appendingPathComponent(saveName), atomically: true, encoding: .utf8)
        if let saveGameInfoData {
            try? saveGameInfoData.write(to: folder.appendingPathComponent("SaveGameInfo"))
        }
        return folder
    }

    private func makeSaveGameInfo(fileURL: URL) -> SaveGameInfo {
        SaveGameInfo(
            folderName: fileURL.deletingLastPathComponent().lastPathComponent,
            fileURL: fileURL,
            lastModified: Date(),
            playerName: "Tester",
            farmName: "TestFarm",
            favoriteThing: "",
            money: 0,
            spouse: "",
            maxHealth: 100,
            maxStamina: 270,
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

    /// backupSave's timestamp has 1-second resolution — a second call within the same
    /// second used to throw "already exists" and silently no-op the caller's edit.
    func testBackupSaveDoesNotCollideWithinSameSecond() {
        let saveName = "TestSave"
        let folder = makeTempSaveFolder(saveName: saveName, saveXML: "<SaveGame></SaveGame>")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }

        let info = makeSaveGameInfo(fileURL: folder.appendingPathComponent(saveName))

        var firstSucceeded = true
        var secondSucceeded = true
        do { try SaveManager.shared.backupSave(info: info) } catch { firstSucceeded = false }
        do { try SaveManager.shared.backupSave(info: info) } catch { secondSucceeded = false }

        XCTAssertTrue(firstSucceeded, "First backup should succeed")
        XCTAssertTrue(secondSucceeded, "A second backup within the same second should not collide and silently fail")

        let backups = (try? SaveManager.shared.listBackups(for: info)) ?? []
        XCTAssertTrue(backups.count == 2, "Both backups should exist on disk, not one silently dropped")
    }

    /// updateInventory used to round-trip the whole file through XMLDocument's
    /// .documentTidyXML + .nodePrettyPrint, which can reformat content it didn't touch —
    /// including SMAPI mods' own <modData> entries. This asserts unrelated content and
    /// unusual whitespace survive an edit exactly, not just "the file still parses."
    func testUpdateInventoryPreservesUnrelatedContent() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <SaveGame xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <player>
            <items>
              <Item xsi:type="Object"><name>Parsnip</name><itemId>24</itemId><stack>5</stack></Item>
            </items>
          </player>
          <modData>
            <item><key><string>SomeMod.CustomKey</string></key><value><string>keep-me-exact:  spaced  </string></value></item>
          </modData>
        </SaveGame>
        """
        let saveName = "TestSaveInventory"
        let folder = makeTempSaveFolder(saveName: saveName, saveXML: xml)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }

        let fileURL = folder.appendingPathComponent(saveName)
        let info = makeSaveGameInfo(fileURL: fileURL)

        guard var inventory = try? SaveManager.shared.fetchInventory(for: info) else {
            XCTAssertTrue(false, "fetchInventory should parse the synthetic save")
            return
        }
        XCTAssertTrue(inventory.count == 1, "Should find the one item slot")

        inventory[0].stack = 10
        var updated = true
        do { try SaveManager.shared.updateInventory(info: info, items: inventory) } catch { updated = false }
        XCTAssertTrue(updated, "updateInventory should succeed")

        let rewritten = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        XCTAssertTrue(
            rewritten.contains("keep-me-exact:  spaced  "),
            "Unrelated modData content should survive the rewrite exactly, not be normalized by a tidy/pretty-print pass"
        )
        XCTAssertTrue(rewritten.contains("<stack>10</stack>"), "The edited item's stack should reflect the new value")
    }

    /// modifyInternalSaveNames used to swallow its own read/write failures with `try?`,
    /// so duplicateSave reported success even when the rename silently didn't happen.
    func testDuplicateSaveReportsFailureWhenRenameFails() {
        let saveName = "TestSaveDuplicate"
        // Invalid UTF-8 bytes make `String(contentsOf:encoding:.utf8)` fail to decode,
        // forcing modifyInternalSaveNames's read step to fail for this file.
        let corruptSaveGameInfo = Data([0xFF, 0xFE, 0x00, 0x01])
        let folder = makeTempSaveFolder(saveName: saveName, saveXML: "<SaveGame><name>Old</name></SaveGame>", saveGameInfoData: corruptSaveGameInfo)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }

        let info = makeSaveGameInfo(fileURL: folder.appendingPathComponent(saveName))
        var succeeded = true
        do {
            try SaveManager.shared.duplicateSave(info: info, newName: "NewName", newFarm: "NewFarm")
        } catch {
            succeeded = false
        }

        XCTAssertFalse(succeeded, "duplicateSave should report failure when the internal rename can't read a file, not silently claim success")
    }
}
