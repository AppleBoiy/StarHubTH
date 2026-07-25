import Foundation

/// I/O boundary for reading and editing Stardew save files. `SaveManager` is the `Live`
/// implementation; a `Stub` conformance lets stores be tested without touching disk.
protocol SaveStoring {
    func fetchSaves() throws(SaveStorageError) -> [SaveGameInfo]
    func backupSave(info: SaveGameInfo) throws(SaveStorageError)
    func updateSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String) throws(SaveStorageError)
    func openSaveInFinder(info: SaveGameInfo)
    func deleteSave(info: SaveGameInfo) throws(SaveStorageError)
    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String) throws(SaveStorageError)
    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String) throws(SaveStorageError)
    func listBackups(for info: SaveGameInfo) throws(SaveStorageError) -> [SaveBackup]
    func restoreBackup(backup: SaveBackup, info: SaveGameInfo) throws(SaveStorageError)
    func deleteBackup(_ backup: SaveBackup) throws(SaveStorageError)
    func fetchInventory(for info: SaveGameInfo) throws(SaveStorageError) -> [InventoryItem]
    func updateInventory(info: SaveGameInfo, items: [InventoryItem]) throws(SaveStorageError)
}

extension SaveManager: SaveStoring {}
