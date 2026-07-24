import Foundation

final class StubSaveStoring: SaveStoring {
    var saves: [SaveGameInfo] = []
    var backups: [SaveBackup] = []
    var inventory: [InventoryItem]?
    var operationsSucceed = true

    func fetchSaves() -> [SaveGameInfo] { saves }
    func backupSave(info: SaveGameInfo) -> Bool { operationsSucceed }

    func updateSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String) -> Bool {
        operationsSucceed
    }

    func openSaveInFinder(info: SaveGameInfo) {}
    func deleteSave(info: SaveGameInfo) -> Bool { operationsSucceed }
    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String) -> Bool { operationsSucceed }
    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String) -> Bool { operationsSucceed }
    func listBackups(for info: SaveGameInfo) -> [SaveBackup] { backups }
    func restoreBackup(backup: SaveBackup, info: SaveGameInfo) -> Bool { operationsSucceed }
    func deleteBackup(_ backup: SaveBackup) -> Bool { operationsSucceed }
    func fetchInventory(for info: SaveGameInfo) -> [InventoryItem]? { inventory }
    func updateInventory(info: SaveGameInfo, items: [InventoryItem]) -> Bool { operationsSucceed }
}
