import Foundation
import AppKit
import UniformTypeIdentifiers

/// Phase 4.6. Owns save-file management: the save list, its hierarchy/filter/sort view,
/// per-save notes/tags/avatars, the backup timeline, and the editing-sheet state.
///
/// Unlike ThaiHubStore/ProfilesStore/ModPacksStore, this store needs nothing from the
/// not-yet-extracted parts of StarHubTHViewModel (no `mods`, no `gameDir`) — every
/// dependency is a real protocol from Phase 3.1, injected here for the first time
/// without any parameter/closure workaround. `showModal` is the one exception, since
/// alertMessage/showAlert don't have their own store yet.
///
/// `setAvatar`/`setNote` call `objectWillChange.send()` manually, same as the original —
/// they mutate through `saveNoteStoring`, a separate object whose own changes aren't
/// otherwise observed by this store's @Published properties.
@MainActor
final class SavesStore: ObservableObject {
    @Published var saveViewMode: SaveViewMode = .list
    @Published var saveSortOption: SaveSortOption = .lastPlayed
    @Published var saveFilterTag: String = ""

    @Published var saves: [SaveGameInfo] = []
    @Published var editingSave: SaveGameInfo? {
        didSet {
            if let save = editingSave {
                if let items = saveStoring.fetchInventory(for: save) {
                    inventoryToEdit = items
                } else {
                    inventoryToEdit = []
                }
            } else {
                inventoryToEdit = []
            }
        }
    }
    @Published var inventoryToEdit: [InventoryItem] = []
    @Published var viewingSaveTimeline: SaveGameInfo?
    @Published var saveToDuplicate: SaveGameInfo?
    @Published var backupToBranch: SaveBackup?

    private let saveStoring: SaveStoring
    private let saveNoteStoring: SaveNoteStoring
    private let filePicking: FilePicking
    private let localization: LocalizationStore

    init(saveStoring: SaveStoring, saveNoteStoring: SaveNoteStoring, filePicking: FilePicking, localization: LocalizationStore) {
        self.saveStoring = saveStoring
        self.saveNoteStoring = saveNoteStoring
        self.filePicking = filePicking
        self.localization = localization
    }

    func reloadSaves() {
        self.saves = saveStoring.fetchSaves()
    }

    func editSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String, showModal: (String) -> Void) {
        let success = saveStoring.updateSave(info: info, newName: newName, newFarm: newFarm, newFav: newFav, newMoney: newMoney, newTotalMoneyEarned: newTotalMoneyEarned, newMaxHealth: newMaxHealth, newMaxStamina: newMaxStamina, newGoldenWalnuts: newGoldenWalnuts, newQiGems: newQiGems, newClubCoins: newClubCoins, newSpouse: newSpouse)
        if success {
            reloadSaves()
            showModal(localization.L(L10n.VM.saveSuccess))
        } else {
            showModal(localization.L(L10n.VM.saveError))
        }
    }

    func saveInventory(showModal: (String) -> Void) {
        guard let save = editingSave else { return }
        if saveStoring.updateInventory(info: save, items: inventoryToEdit) {
            showModal(localization.L(L10n.Saves.inventorySuccess))
            if let items = saveStoring.fetchInventory(for: save) {
                inventoryToEdit = items
            }
        } else {
            showModal(localization.L(L10n.Saves.inventoryError))
        }
    }

    func deleteSave(info: SaveGameInfo, showModal: (String) -> Void) {
        if saveStoring.deleteSave(info: info) {
            reloadSaves()
            showModal(localization.L(L10n.VM.deleteSaveSuccess))
        } else {
            showModal(localization.L(L10n.VM.deleteSaveError))
        }
    }

    var savesHierarchy: [SaveNode] {
        let saveNames = Set(saves.map(\.folderName))

        func parentFolderName(for folderName: String) -> String? {
            var candidate = folderName
            while let range = candidate.range(of: "_", options: .backwards) {
                candidate = String(candidate[..<range.lowerBound])
                if saveNames.contains(candidate) {
                    return candidate
                }
            }
            return nil
        }

        func sortedNodes(_ nodes: [SaveNode]) -> [SaveNode] {
            nodes
                .map { SaveNode(info: $0.info, children: sortedNodes($0.children)) }
                .sorted { a, b in
                    switch saveSortOption {
                    case .name:
                        return a.info.playerName.localizedCaseInsensitiveCompare(b.info.playerName) == .orderedAscending
                    case .lastPlayed:
                        return a.info.lastModified > b.info.lastModified
                    case .money:
                        return a.info.money > b.info.money
                    }
                }
        }

        var childrenByParent: [String: [SaveGameInfo]] = [:]
        var rootSaves: [SaveGameInfo] = []

        for save in saves {
            if let parentFolderName = parentFolderName(for: save.folderName) {
                childrenByParent[parentFolderName, default: []].append(save)
            } else {
                rootSaves.append(save)
            }
        }

        func buildNode(for save: SaveGameInfo) -> SaveNode {
            let children = childrenByParent[save.folderName, default: []].map { buildNode(for: $0) }
            return SaveNode(info: save, children: children)
        }

        var roots = rootSaves.map { buildNode(for: $0) }

        // Apply tag filter recursively
        if !saveFilterTag.isEmpty {
            func filterNode(_ node: SaveNode) -> SaveNode? {
                let tag = saveNoteStoring.note(for: node.info.folderName).tag
                let selfMatches = tag == saveFilterTag
                let filteredChildren = node.children.compactMap { filterNode($0) }
                if selfMatches || !filteredChildren.isEmpty {
                    return SaveNode(info: node.info, children: filteredChildren)
                }
                return nil
            }
            roots = roots.compactMap { filterNode($0) }
        }

        roots = sortedNodes(roots)

        return roots
    }

    var availableFilterTags: [String] {
        let allTags = saves.compactMap { saveNoteStoring.note(for: $0.folderName).tag }.filter { !$0.isEmpty }
        return Array(Set(allTags)).sorted()
    }

    func setAvatar(forSave folderName: String, iconPath: String) {
        let note = saveNoteStoring.note(for: folderName)
        saveNoteStoring.setNote(for: folderName, tag: note.tag, note: note.note, customIconPath: iconPath)
        objectWillChange.send()
    }

    func selectCustomAvatar(forSave folderName: String, completion: ((String) -> Void)? = nil) {
        let urls = filePicking.pickFiles(
            title: localization.L(L10n.Saves.avatarPanelTitle),
            allowedContentTypes: [.png, .jpeg, .gif],
            allowsMultipleSelection: false,
            canChooseDirectories: false
        )
        if let url = urls.first {
            // Copy to app support dir to prevent broken paths
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("StarHubTH/Avatars", isDirectory: true)
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            let destURL = supportDir.appendingPathComponent("\(folderName)_\(url.lastPathComponent)")
            try? FileManager.default.copyItem(at: url, to: destURL)
            setAvatar(forSave: folderName, iconPath: destURL.path)
            completion?(destURL.path)
        }
    }

    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String, showModal: (String) -> Void) {
        if saveStoring.duplicateSave(info: info, newName: newName, newFarm: newFarm) {
            reloadSaves()
            showModal(localization.L(L10n.VM.duplicateSaveSuccess))
        } else {
            showModal(localization.L(L10n.VM.duplicateSaveError))
        }
    }

    func openSaveInFinder(info: SaveGameInfo) {
        saveStoring.openSaveInFinder(info: info)
    }

    // MARK: - Backup Timeline

    func listBackups(for info: SaveGameInfo) -> [SaveBackup] {
        saveStoring.listBackups(for: info)
    }

    func createBackup(info: SaveGameInfo) -> Bool {
        saveStoring.backupSave(info: info)
    }

    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String, showModal: (String) -> Void) -> Bool {
        if saveStoring.branchFromBackup(backup: backup, newName: newName, newFarm: newFarm) {
            reloadSaves()
            showModal(localization.L(L10n.VM.branchSuccess))
            return true
        } else {
            showModal(localization.L(L10n.VM.branchError))
            return false
        }
    }

    func restoreBackup(backup: SaveBackup, info: SaveGameInfo, showModal: (String) -> Void) {
        if saveStoring.restoreBackup(backup: backup, info: info) {
            reloadSaves()
            viewingSaveTimeline = nil
            editingSave = nil
            showModal(localization.L(L10n.VM.restoreSuccess))
        } else {
            showModal(localization.L(L10n.VM.restoreError))
        }
    }

    func deleteBackup(_ backup: SaveBackup) -> Bool {
        saveStoring.deleteBackup(backup)
    }

    // MARK: - Save Notes

    func note(for folderName: String) -> SaveNote {
        saveNoteStoring.note(for: folderName)
    }

    func setNote(for folderName: String, tag: String, note: String) {
        // Preserve existing customIconPath
        let existing = saveNoteStoring.note(for: folderName)
        saveNoteStoring.setNote(for: folderName, tag: tag, note: note, customIconPath: existing.customIconPath)
        objectWillChange.send()
    }

    // MARK: - Backup & Management

    func backupAllSaves(showModal: (String) -> Void) {
        let home = NSHomeDirectory()
        let savesDir = "\(home)/.config/StardewValley/Saves"
        let desktopDir = "\(home)/Desktop"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "")
        let zipPath = "\(desktopDir)/StardewSaves_Backup_\(timestamp).zip"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath, "."]
        process.currentDirectoryURL = URL(fileURLWithPath: savesDir)

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                showModal(String(format: localization.L(L10n.VM.backupSavesSuccess), zipPath))
            } else {
                showModal(localization.L(L10n.VM.zipSavesError))
            }
        } catch {
            showModal(localization.L(L10n.VM.cannotRunZip))
        }
    }

    func openSavesFolder() {
        let home = NSHomeDirectory()
        let savesDir = URL(fileURLWithPath: "\(home)/.config/StardewValley/Saves")
        NSWorkspace.shared.open(savesDir)
    }
}
