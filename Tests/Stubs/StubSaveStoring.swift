import Foundation

final class StubSaveStoring: SaveStoring {
    var saves: [SaveGameInfo] = []
    var backups: [SaveBackup] = []
    var inventory: [InventoryItem] = []
    var operationsSucceed = true

    private func failIfNeeded() throws(SaveStorageError) {
        guard !operationsSucceed else { return }
        throw .fileWriteFailed(underlying: NSError(domain: "StubSaveStoring", code: 1))
    }

    func fetchSaves() throws(SaveStorageError) -> [SaveGameInfo] { saves }

    func backupSave(info: SaveGameInfo) throws(SaveStorageError) { try failIfNeeded() }

    func updateSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String) throws(SaveStorageError) {
        try failIfNeeded()
    }

    func deleteSave(info: SaveGameInfo) throws(SaveStorageError) { try failIfNeeded() }
    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String) throws(SaveStorageError) { try failIfNeeded() }
    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String) throws(SaveStorageError) { try failIfNeeded() }
    func listBackups(for info: SaveGameInfo) throws(SaveStorageError) -> [SaveBackup] { backups }
    func restoreBackup(backup: SaveBackup, info: SaveGameInfo) throws(SaveStorageError) { try failIfNeeded() }
    func deleteBackup(_ backup: SaveBackup) throws(SaveStorageError) { try failIfNeeded() }
    func fetchInventory(for info: SaveGameInfo) throws(SaveStorageError) -> [InventoryItem] { inventory }
    func updateInventory(info: SaveGameInfo, items: [InventoryItem]) throws(SaveStorageError) { try failIfNeeded() }
}
