import Foundation
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
    @Published var saveViewMode: SaveViewMode = .list // STANDARDS-EXCEPTION: §8 — SavesView writes it directly (list/grid toggle buttons)
    @Published var saveSortOption: SaveSortOption = .lastPlayed // STANDARDS-EXCEPTION: §8 — SavesView writes it directly (sort menu)
    @Published var saveFilterTag: String = "" // STANDARDS-EXCEPTION: §8 — SavesView writes it directly (tag filter); ModsStoreTests-style tests also set it directly

    @Published private(set) var saves: [SaveGameInfo] = []
    @Published var editingSave: SaveGameInfo? { // STANDARDS-EXCEPTION: §8 — many Save views write it directly (open/close editor sheet)
        didSet {
            guard let save = editingSave else {
                inventoryToEdit = []
                return
            }
            // A save with unreadable/corrupt inventory XML still opens for editing the
            // other fields — an empty item list here, not a blocking alert.
            inventoryToEdit = (try? saveStoring.fetchInventory(for: save)) ?? []
        }
    }
    @Published var inventoryToEdit: [InventoryItem] = [] // STANDARDS-EXCEPTION: §8 — SaveEditorView binds into it directly ($savesStore.inventoryToEdit[index].stack)
    @Published var viewingSaveTimeline: SaveGameInfo? // STANDARDS-EXCEPTION: §8 — several Save views write it directly (open/close timeline sheet)
    @Published var saveToDuplicate: SaveGameInfo? // STANDARDS-EXCEPTION: §8 — .sheet(item:) needs a two-way Binding; Save views also write it directly
    @Published var backupToBranch: SaveBackup? // STANDARDS-EXCEPTION: §8 — .sheet(item:) needs a two-way Binding; SaveTimelineView also writes it directly

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

    /// A saves-directory read failure degrades to an empty list rather than surfacing a
    /// blocking alert on every reload — `SaveGameInfo` isn't optional-friendly UI-wise, and
    /// this is called after nearly every mutation below, not just on first appearance.
    func reloadSaves() {
        do {
            self.saves = try saveStoring.fetchSaves()
        } catch {
            self.saves = []
        }
    }

    private func message(for error: SaveStorageError, headlineKey: String) -> String {
        guard let detail = error.detail else { return localization.L(headlineKey) }
        return "\(localization.L(headlineKey))\n\(detail)"
    }

    func editSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String, showModal: (String) -> Void) {
        do {
            try saveStoring.updateSave(info: info, newName: newName, newFarm: newFarm, newFav: newFav, newMoney: newMoney, newTotalMoneyEarned: newTotalMoneyEarned, newMaxHealth: newMaxHealth, newMaxStamina: newMaxStamina, newGoldenWalnuts: newGoldenWalnuts, newQiGems: newQiGems, newClubCoins: newClubCoins, newSpouse: newSpouse)
            reloadSaves()
            showModal(localization.L(L10n.VM.saveSuccess))
        } catch {
            showModal(message(for: error, headlineKey: L10n.VM.saveError))
        }
    }

    func saveInventory(showModal: (String) -> Void) {
        guard let save = editingSave else { return }
        do {
            try saveStoring.updateInventory(info: save, items: inventoryToEdit)
            showModal(localization.L(L10n.Saves.inventorySuccess))
            inventoryToEdit = (try? saveStoring.fetchInventory(for: save)) ?? inventoryToEdit
        } catch {
            showModal(message(for: error, headlineKey: L10n.Saves.inventoryError))
        }
    }

    func deleteSave(info: SaveGameInfo, showModal: (String) -> Void) {
        do {
            try saveStoring.deleteSave(info: info)
            reloadSaves()
            showModal(localization.L(L10n.VM.deleteSaveSuccess))
        } catch {
            showModal(message(for: error, headlineKey: L10n.VM.deleteSaveError))
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
        let existing = saveNoteStoring.note(for: folderName)
        saveNoteStoring.setNote(existing.note, tag: existing.tag, forSave: folderName, customIconPath: iconPath)
        objectWillChange.send()
    }

    func selectCustomAvatar(forSave folderName: String, completion: ((String) -> Void)? = nil) {
        let urls = filePicking.pickFiles(
            title: localization.L(L10n.Saves.avatarPanelTitle),
            allowedContentTypes: [.png, .jpeg, .gif],
            allowsMultipleSelection: false,
            canChooseDirectories: false
        )
        guard let url = urls.first else { return }

        // Copy to app support dir to prevent broken paths
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("StarHubTH/Avatars", isDirectory: true)
        // Idempotent — "directory already exists" is the expected outcome on every call
        // after the first, not a failure worth reporting.
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let destURL = supportDir.appendingPathComponent("\(folderName)_\(url.lastPathComponent)")
        do {
            try FileManager.default.copyItem(at: url, to: destURL)
        } catch {
            // The picked file couldn't be copied — leave the existing avatar untouched
            // rather than pointing setAvatar at a path with nothing behind it.
            return
        }
        setAvatar(forSave: folderName, iconPath: destURL.path)
        completion?(destURL.path)
    }

    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String, showModal: (String) -> Void) {
        do {
            try saveStoring.duplicateSave(info: info, newName: newName, newFarm: newFarm)
            reloadSaves()
            showModal(localization.L(L10n.VM.duplicateSaveSuccess))
        } catch {
            showModal(message(for: error, headlineKey: L10n.VM.duplicateSaveError))
        }
    }

    func openSaveInFinder(info: SaveGameInfo) {
        filePicking.reveal(info.fileURL.deletingLastPathComponent())
    }

    // MARK: - Backup Timeline

    /// Same swallow-to-empty tradeoff as `reloadSaves()` — see its comment.
    func listBackups(for info: SaveGameInfo) -> [SaveBackup] {
        (try? saveStoring.listBackups(for: info)) ?? []
    }

    func createBackup(info: SaveGameInfo, showModal: (String) -> Void) {
        do {
            try saveStoring.backupSave(info: info)
        } catch {
            showModal(message(for: error, headlineKey: L10n.VM.saveError))
        }
    }

    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String, showModal: (String) -> Void) {
        do {
            try saveStoring.branchFromBackup(backup: backup, newName: newName, newFarm: newFarm)
            reloadSaves()
            showModal(localization.L(L10n.VM.branchSuccess))
        } catch {
            showModal(message(for: error, headlineKey: L10n.VM.branchError))
        }
    }

    func restoreBackup(backup: SaveBackup, info: SaveGameInfo, showModal: (String) -> Void) {
        do {
            try saveStoring.restoreBackup(backup: backup, info: info)
            reloadSaves()
            viewingSaveTimeline = nil
            editingSave = nil
            showModal(localization.L(L10n.VM.restoreSuccess))
        } catch {
            showModal(message(for: error, headlineKey: L10n.VM.restoreError))
        }
    }

    func deleteBackup(_ backup: SaveBackup, showModal: (String) -> Void) {
        do {
            try saveStoring.deleteBackup(backup)
        } catch {
            showModal(message(for: error, headlineKey: L10n.VM.deleteSaveError))
        }
    }

    // MARK: - Save Notes

    func note(for folderName: String) -> SaveNote {
        saveNoteStoring.note(for: folderName)
    }

    func setNote(_ note: String, tag: String, forSave folderName: String) {
        // Preserve existing customIconPath
        let existing = saveNoteStoring.note(for: folderName)
        saveNoteStoring.setNote(note, tag: tag, forSave: folderName, customIconPath: existing.customIconPath)
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
        filePicking.reveal(savesDir)
    }
}
