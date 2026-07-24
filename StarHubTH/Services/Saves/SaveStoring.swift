import Foundation

/// I/O boundary for reading and editing Stardew save files. `SaveManager` is the `Live`
/// implementation; a `Stub` conformance lets stores be tested without touching disk.
protocol SaveStoring {
    func fetchSaves() -> [SaveGameInfo]
    func backupSave(info: SaveGameInfo) -> Bool
    func updateSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String) -> Bool
    func openSaveInFinder(info: SaveGameInfo)
    func deleteSave(info: SaveGameInfo) -> Bool
    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String) -> Bool
    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String) -> Bool
    func listBackups(for info: SaveGameInfo) -> [SaveBackup]
    func restoreBackup(backup: SaveBackup, info: SaveGameInfo) -> Bool
    func deleteBackup(_ backup: SaveBackup) -> Bool
    func fetchInventory(for info: SaveGameInfo) -> [InventoryItem]?
    func updateInventory(info: SaveGameInfo, items: [InventoryItem]) -> Bool
}

extension SaveManager: SaveStoring {}
