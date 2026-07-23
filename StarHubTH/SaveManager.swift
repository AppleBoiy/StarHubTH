import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Save Backup Model

struct SaveBackup: Identifiable, Equatable {
    var id: String { folderPath.path }
    let folderPath: URL
    let timestamp: Date
    let saveFolder: String   // parent save folder name

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale.current
        return f.string(from: timestamp)
    }

    var relativeLabel: String {
        let secs = Date().timeIntervalSince(timestamp)
        if secs < 60 { return "เมื่อสักครู่" }
        if secs < 3600 { return "\(Int(secs/60)) นาทีที่แล้ว" }
        if secs < 86400 { return "\(Int(secs/3600)) ชั่วโมงที่แล้ว" }
        return "\(Int(secs/86400)) วันที่แล้ว"
    }
}

struct SaveNote: Codable {
    var tag: String   // emoji tag key e.g. "⭐", "🏆", ""
    var note: String  // free text
    var customIconPath: String?
}

// MARK: - Save Notes Store (UserDefaults-backed)

class SaveNotesStore {
    static let shared = SaveNotesStore()
    private let key = "SaveNotes_v2" // Upgraded version key to prevent conflicts

    private var cache: [String: SaveNote] = [:]

    init() { load() }

    func note(for folderName: String) -> SaveNote {
        cache[folderName] ?? SaveNote(tag: "", note: "", customIconPath: nil)
    }

    func setNote(for folderName: String, tag: String, note: String, customIconPath: String? = nil) {
        cache[folderName] = SaveNote(tag: tag, note: note, customIconPath: customIconPath)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: SaveNote].self, from: data)
        else { return }
        cache = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}


struct SaveNode: Identifiable, Equatable {
    var id: String { info.id }
    let info: SaveGameInfo
    var children: [SaveNode]
}

struct SaveGameInfo: Identifiable, Equatable, Hashable {
    var id: String { folderName }
    let folderName: String
    let fileURL: URL
    let lastModified: Date
    
    var playerName: String
    var farmName: String
    var favoriteThing: String
    var money: Int
    var spouse: String   // empty string = single (no <spouse> tag)
    
    // Advanced Stats
    var maxHealth: Int
    var maxStamina: Int
    var goldenWalnuts: Int
    var qiGems: Int
    var clubCoins: Int
    var totalMoneyEarned: Int
    
    var year: Int
    var season: Int
    var day: Int
    var whichFarm: Int
    
    var farmTypeName: String {
        switch whichFarm {
        case 0: return "Standard Farm"
        case 1: return "Riverland Farm"
        case 2: return "Forest Farm"
        case 3: return "Hill-top Farm"
        case 4: return "Wilderness Farm"
        case 5: return "Four Corners Farm"
        case 6: return "Beach Farm"
        case 7: return "Meadowlands Farm"
        default: return "Custom Farm"
        }
    }
    
    var farmIcon: String {
        switch whichFarm {
        case 0: return "leaf.fill"
        case 1: return "water.waves"
        case 2: return "tree.fill"
        case 3: return "mountain.2.fill"
        case 4: return "moon.stars.fill"
        case 5: return "square.grid.2x2.fill"
        case 6: return "sun.max.fill"
        case 7: return "pawprint.fill"
        default: return "questionmark.square.fill"
        }
    }
    
    var seasonName: String {
        switch season {
        case 0: return L10n.Saves.spring
        case 1: return L10n.Saves.summer
        case 2: return L10n.Saves.fall
        case 3: return L10n.Saves.winter
        default: return L10n.Saves.spring
        }
    }
}

class SaveManager {
    static let shared = SaveManager()
    
    private let savesDir: URL
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.savesDir = homeDir.appendingPathComponent(".config/StardewValley/Saves")
    }
    
    func fetchSaves() -> [SaveGameInfo] {
        var saves: [SaveGameInfo] = []
        let fm = FileManager.default
        
        guard let folders = try? fm.contentsOfDirectory(at: savesDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }
        
        for folder in folders {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue {
                let saveName = folder.lastPathComponent
                let saveFile = folder.appendingPathComponent(saveName)
                
                if fm.fileExists(atPath: saveFile.path) {
                    if let info = SaveFileParser.parse(url: saveFile, folderName: saveName) {
                        saves.append(info)
                    }
                }
            }
        }
        
        return saves.sorted { $0.playerName < $1.playerName }
    }
    

    
    /// Update or remove the <spouse> tag inside the <player> block.
    /// - If newSpouse is non-empty: sets <spouse>newSpouse</spouse>
    /// - If newSpouse is empty: removes the <spouse>...</spouse> tag
    private func updateSpouseInPlayer(newSpouse: String, in xml: String) -> String {
        let spousePattern = "<spouse>[^<]*</spouse>"
        guard let regex = try? NSRegularExpression(pattern: spousePattern, options: []) else { return xml }
        
        // Find <player> block range
        guard let playerStartRange = xml.range(of: "<player>"),
              let playerEndRange = xml.range(of: "</player>", range: playerStartRange.upperBound..<xml.endIndex) else {
            // Fallback: operate on whole file
            return replaceOrRemoveSpouseTag(newSpouse: newSpouse, in: xml, using: regex)
        }
        
        let beforePlayer = String(xml[..<playerStartRange.lowerBound])
        let playerBlock  = String(xml[playerStartRange.lowerBound..<playerEndRange.upperBound])
        let afterPlayer  = String(xml[playerEndRange.upperBound...])
        
        let updatedPlayer = replaceOrRemoveSpouseTag(newSpouse: newSpouse, in: playerBlock, using: regex)
        return beforePlayer + updatedPlayer + afterPlayer
    }
    
    private func replaceOrRemoveSpouseTag(newSpouse: String, in block: String, using regex: NSRegularExpression) -> String {
        let nsBlock = block as NSString
        let fullRange = NSRange(location: 0, length: nsBlock.length)
        
        if newSpouse.isEmpty {
            // Remove the <spouse>...</spouse> tag entirely
            return regex.stringByReplacingMatches(in: block, options: [], range: fullRange, withTemplate: "")
        } else {
            let replacement = "<spouse>\(newSpouse)</spouse>"
            let firstMatch = regex.firstMatch(in: block, options: [], range: fullRange)
            if let firstMatch = firstMatch {
                // Tag exists — replace it
                return regex.stringByReplacingMatches(in: block, options: [], range: firstMatch.range, withTemplate: replacement)
            } else {
                // Tag doesn't exist — insert after <name>...</name>
                let namePattern = "(<name>[^<]*</name>)"
                guard let nameRegex = try? NSRegularExpression(pattern: namePattern, options: []),
                      let nameMatch = nameRegex.firstMatch(in: block, options: [], range: fullRange),
                      let nameRange = Range(nameMatch.range, in: block) else {
                    return block  // cannot insert safely
                }
                var modified = block
                modified.insert(contentsOf: "<spouse>\(newSpouse)</spouse>", at: nameRange.upperBound)
                return modified
            }
        }
    }
    
    func backupSave(info: SaveGameInfo) -> Bool {
        let fm = FileManager.default
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let folderPath = info.fileURL.deletingLastPathComponent()
        let backupPath = folderPath.appendingPathExtension("backup_\(timestamp)")
        
        do {
            try fm.copyItem(at: folderPath, to: backupPath)
            print("Backup created at: \(backupPath.path)")
            return true
        } catch {
            print("Failed to backup save: \(error)")
            return false
        }
    }
    
    func updateSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String) -> Bool {
        guard backupSave(info: info) else { return false }
        
        guard var content = try? String(contentsOf: info.fileURL, encoding: .utf8) else { return false }
        
        // Replace values using regex
        content = replaceFirstTag(tag: "name", with: newName, in: content)
        content = replaceFirstTag(tag: "farmName", with: newFarm, in: content)
        content = replaceFirstTag(tag: "favoriteThing", with: newFav, in: content)
        content = replaceFirstTag(tag: "money", with: "\(newMoney)", in: content)
        content = replaceFirstTag(tag: "totalMoneyEarned", with: "\(newTotalMoneyEarned)", in: content)
        
        content = replaceFirstTag(tag: "maxHealth", with: "\(newMaxHealth)", in: content)
        content = replaceFirstTag(tag: "maxStamina", with: "\(newMaxStamina)", in: content)
        content = replaceFirstTag(tag: "goldenWalnuts", with: "\(newGoldenWalnuts)", in: content)
        content = replaceFirstTag(tag: "qiGems", with: "\(newQiGems)", in: content)
        content = replaceFirstTag(tag: "clubCoins", with: "\(newClubCoins)", in: content)
        
        let oldSpouse = info.spouse   // NPC name before the edit
        
        // Spouse: update or remove tag inside <player> block
        content = updateSpouseInPlayer(newSpouse: newSpouse, in: content)
        
        // If removing or changing a spouse, also fix the NPC's friendship entry
        // so they return to their original home/schedule without glitching.
        if !oldSpouse.isEmpty && newSpouse != oldSpouse {
            content = cleanDivorceNPCFriendship(npcName: oldSpouse, in: content)
        }
        
        do {
            try content.write(to: info.fileURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to write updated save: \(error)")
            return false
        }
    }
    
    /// Cleans up a previously married NPC's friendship entry so they return
    /// to their normal home and schedule without bugging out.
    ///
    /// Changes inside the NPC's `<Friendship>` block (inside a `<key><string>NpcName</string></key>` item):
    ///   - `<Status>Married</Status>`  →  `<Status>Friendly</Status>`
    ///   - `<WeddingDate>...</WeddingDate>` block is removed entirely
    private func cleanDivorceNPCFriendship(npcName: String, in xml: String) -> String {
        // We locate the <item> block that belongs to this NPC.
        // Structure: <item><key><string>NpcName</string></key><value><Friendship>...</Friendship></value></item>
        let keyMarker = "<string>\(npcName)</string>"
        guard let keyRange = xml.range(of: keyMarker) else {
            print("[Divorce] Could not find friendship entry for \(npcName)")
            return xml
        }
        
        // Find the enclosing <item>...</item> that contains this key
        let beforeKey = String(xml[..<keyRange.lowerBound])
        guard let itemStart = beforeKey.range(of: "<item>", options: .backwards) else {
            print("[Divorce] Could not find <item> before key for \(npcName)")
            return xml
        }
        
        let itemStartIdx = itemStart.lowerBound
        guard let itemEnd = xml.range(of: "</item>", range: keyRange.upperBound..<xml.endIndex) else {
            print("[Divorce] Could not find </item> after key for \(npcName)")
            return xml
        }
        
        let itemEndIdx = itemEnd.upperBound
        
        let beforeItem = String(xml[..<itemStartIdx])
        var itemBlock  = String(xml[itemStartIdx..<itemEndIdx])
        let afterItem  = String(xml[itemEndIdx...])
        
        // 1. Change <Status>Married</Status> → <Status>Friendly</Status>
        itemBlock = itemBlock.replacingOccurrences(of: "<Status>Married</Status>", with: "<Status>Friendly</Status>")
        
        // 2. Remove <WeddingDate>...</WeddingDate> (multiline/nested block)
        //    Pattern matches <WeddingDate> followed by any content up to </WeddingDate>
        if let wdRegex = try? NSRegularExpression(pattern: "<WeddingDate>.*?</WeddingDate>", options: .dotMatchesLineSeparators) {
            let nsBlock = itemBlock as NSString
            itemBlock = wdRegex.stringByReplacingMatches(
                in: itemBlock, options: [],
                range: NSRange(location: 0, length: nsBlock.length),
                withTemplate: ""
            )
        }
        
        return beforeItem + itemBlock + afterItem
    }


    private func replaceFirstTag(tag: String, with value: String, in xml: String) -> String {
        let pattern = "(<\(tag)>)([^<]+)(</\(tag)>)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return xml }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        
        // We only want to replace the first occurrence (player data is always at the top)
        if let match = regex.firstMatch(in: xml, options: [], range: range) {

            // wait, stringByReplacingMatches with match.range will only return the replaced SUBSTRING,
            // no, wait, it returns a new string where the matches within the range are replaced.
            // Oh, the range param to stringByReplacingMatches specifies the portion of the string to search.
            // If I restrict the search to match.range, it will only return that small portion.
            // Better to use mutating String method.
            if let swiftRange = Range(match.range, in: xml) {
                var modified = xml
                modified.replaceSubrange(swiftRange, with: "<\(tag)>\(value)</\(tag)>")
                return modified
            }
        }
        return xml
    }
    
    // MARK: - Advanced Management
    
    func openSaveInFinder(info: SaveGameInfo) {
        #if os(macOS)
        let folderPath = info.fileURL.deletingLastPathComponent()
        NSWorkspace.shared.open(folderPath)
        #endif
    }
    
    func deleteSave(info: SaveGameInfo) -> Bool {
        let folderPath = info.fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.trashItem(at: folderPath, resultingItemURL: nil)
            return true
        } catch {
            print("Failed to trash save: \(error)")
            return false
        }
    }
    
    private func modifyInternalSaveNames(in folderURL: URL, newSaveName: String, newPlayerName: String, newFarmName: String) {
        let fm = FileManager.default
        let saveGameInfoURL = folderURL.appendingPathComponent("SaveGameInfo")
        let mainSaveURL = folderURL.appendingPathComponent(newSaveName)
        
        func updateFile(at url: URL) {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            var modified = replaceFirstTag(tag: "name", with: newPlayerName, in: content)
            modified = replaceFirstTag(tag: "farmName", with: newFarmName, in: modified)
            try? modified.write(to: url, atomically: true, encoding: .utf8)
        }
        
        if fm.fileExists(atPath: saveGameInfoURL.path) {
            updateFile(at: saveGameInfoURL)
        }
        if fm.fileExists(atPath: mainSaveURL.path) {
            updateFile(at: mainSaveURL)
        }
    }

    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String) -> Bool {
        let fm = FileManager.default
        let folderPath = info.fileURL.deletingLastPathComponent()
        let saveName = folderPath.lastPathComponent
        
        var newSaveName = "\(saveName)_copy"
        var newFolderPath = folderPath.deletingLastPathComponent().appendingPathComponent(newSaveName)
        
        var counter = 1
        while fm.fileExists(atPath: newFolderPath.path) {
            newSaveName = "\(saveName)_copy_\(counter)"
            newFolderPath = folderPath.deletingLastPathComponent().appendingPathComponent(newSaveName)
            counter += 1
        }
        
        do {
            try fm.copyItem(at: folderPath, to: newFolderPath)
            
            // Rename internal file
            let oldFilePath = newFolderPath.appendingPathComponent(saveName)
            let newFilePath = newFolderPath.appendingPathComponent(newSaveName)
            if fm.fileExists(atPath: oldFilePath.path) {
                try fm.moveItem(at: oldFilePath, to: newFilePath)
            }
            
            // Modify name and farm name inside XML files
            modifyInternalSaveNames(in: newFolderPath, newSaveName: newSaveName, newPlayerName: newName, newFarmName: newFarm)
            
            return true
        } catch {
            print("Failed to duplicate save: \(error)")
            return false
        }
    }

    // MARK: - Backup Timeline
    
    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String) -> Bool {
        let fm = FileManager.default
        let backupFolderPath = backup.folderPath
        let originalSaveName = String(backupFolderPath.lastPathComponent.split(separator: ".")[0])
        let parentDir = backupFolderPath.deletingLastPathComponent()
        
        var newSaveName = "\(originalSaveName)_branch"
        var newFolderPath = parentDir.appendingPathComponent(newSaveName)
        
        var counter = 1
        while fm.fileExists(atPath: newFolderPath.path) {
            newSaveName = "\(originalSaveName)_branch_\(counter)"
            newFolderPath = parentDir.appendingPathComponent(newSaveName)
            counter += 1
        }
        
        do {
            try fm.copyItem(at: backupFolderPath, to: newFolderPath)
            
            // Rename internal file
            let oldFilePath = newFolderPath.appendingPathComponent(originalSaveName)
            let newFilePath = newFolderPath.appendingPathComponent(newSaveName)
            if fm.fileExists(atPath: oldFilePath.path) {
                try fm.moveItem(at: oldFilePath, to: newFilePath)
            }
            
            // Modify name and farm name inside XML files
            modifyInternalSaveNames(in: newFolderPath, newSaveName: newSaveName, newPlayerName: newName, newFarmName: newFarm)
            
            return true
        } catch {
            print("Failed to branch backup: \(error)")
            return false
        }
    }

    /// List all `.backup_*` sibling folders for a given save
    func listBackups(for info: SaveGameInfo) -> [SaveBackup] {
        let saveFolder = info.fileURL.deletingLastPathComponent()
        let parentDir = saveFolder.deletingLastPathComponent()
        let saveName = saveFolder.lastPathComponent

        guard let items = try? FileManager.default.contentsOfDirectory(
            at: parentDir,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        var backups: [SaveBackup] = []
        for item in items {
            let name = item.lastPathComponent
            // Match pattern: saveName.backup_YYYYMMDD_HHMMSS
            let prefix = "\(saveName).backup_"
            guard name.hasPrefix(prefix) else { continue }

            let tsString = String(name.dropFirst(prefix.count))
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let date = formatter.date(from: tsString) ?? Date()

            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                backups.append(SaveBackup(folderPath: item, timestamp: date, saveFolder: saveName))
            }
        }
        return backups.sorted { $0.timestamp > $1.timestamp }
    }

    /// Restore a backup: backup current save first, then swap
    func restoreBackup(backup: SaveBackup, info: SaveGameInfo) -> Bool {
        let fm = FileManager.default
        let saveFolder = info.fileURL.deletingLastPathComponent()

        // 1. First backup the current state before restoring
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let preRestoreBackupPath = saveFolder
            .deletingLastPathComponent()
            .appendingPathComponent("\(saveFolder.lastPathComponent).backup_\(timestamp)")

        let tempTrash = saveFolder.deletingLastPathComponent()
            .appendingPathComponent("\(saveFolder.lastPathComponent)_RESTORING_TEMP")

        do {
            // Backup current state
            try fm.copyItem(at: saveFolder, to: preRestoreBackupPath)

            // Move current save folder to temporary staging
            try fm.moveItem(at: saveFolder, to: tempTrash)

            do {
                // Copy backup into place
                try fm.copyItem(at: backup.folderPath, to: saveFolder)
                // Trash the temp after successful restore
                try? fm.trashItem(at: tempTrash, resultingItemURL: nil)
                return true
            } catch {
                // Rollback: restore original save from tempTrash
                if fm.fileExists(atPath: tempTrash.path) && !fm.fileExists(atPath: saveFolder.path) {
                    try? fm.moveItem(at: tempTrash, to: saveFolder)
                }
                throw error
            }
        } catch {
            print("Failed to restore backup: \(error)")
            return false
        }
    }

    /// Delete a single backup folder
    func deleteBackup(_ backup: SaveBackup) -> Bool {
        do {
            try FileManager.default.trashItem(at: backup.folderPath, resultingItemURL: nil)
            return true
        } catch {
            print("Failed to delete backup: \(error)")
            return false
        }
    }
    // MARK: - Inventory Editing
    
    func fetchInventory(for info: SaveGameInfo) -> [InventoryItem]? {
        guard let data = try? Data(contentsOf: info.fileURL),
              let document = try? XMLDocument(data: data, options: .documentTidyXML),
              let root = document.rootElement() else {
            return nil
        }
        
        var inventory: [InventoryItem] = []
        
        // Find /SaveGame/player/items
        let player = root.elements(forName: "player").first
        let itemsElement = player?.elements(forName: "items").first
        
        guard let itemsNode = itemsElement else { return nil }
        
        let itemNodes = itemsNode.elements(forName: "Item")
        
        for (index, itemNode) in itemNodes.enumerated() {
            let xsiType = itemNode.attribute(forName: "xsi:type")?.stringValue ?? ""
            
            if xsiType == "Object" {
                let name = itemNode.elements(forName: "name").first?.stringValue ?? "Unknown"
                let itemId = itemNode.elements(forName: "itemId").first?.stringValue ?? "Unknown"
                let stack = Int(itemNode.elements(forName: "stack").first?.stringValue ?? "1") ?? 1
                
                inventory.append(InventoryItem(slotIndex: index, itemId: itemId, name: name, stack: stack, isObject: true))
            } else if itemNode.attribute(forName: "xsi:nil")?.stringValue == "true" {
                // Empty slot
                inventory.append(InventoryItem.empty(slot: index))
            } else {
                // Other items like weapons, rings, etc.
                let name = itemNode.elements(forName: "name").first?.stringValue ?? xsiType
                let itemId = itemNode.elements(forName: "itemId").first?.stringValue ?? ""
                let displayName = name.isEmpty ? (xsiType.isEmpty ? "Unknown Item" : xsiType) : name
                inventory.append(InventoryItem(slotIndex: index, itemId: itemId, name: displayName, stack: 1, isObject: false))
            }
        }
        
        return inventory
    }
    
    func updateInventory(info: SaveGameInfo, items: [InventoryItem]) -> Bool {
        // Backup first
        guard backupSave(info: info) else { return false }
        
        guard let data = try? Data(contentsOf: info.fileURL),
              let document = try? XMLDocument(data: data, options: .documentTidyXML),
              let root = document.rootElement() else {
            return false
        }
        
        // Find /SaveGame/player/items
        guard let player = root.elements(forName: "player").first,
              let itemsElement = player.elements(forName: "items").first else {
            return false
        }
        
        let itemNodes = itemsElement.elements(forName: "Item")
        
        for updatedItem in items {
            guard updatedItem.slotIndex >= 0 && updatedItem.slotIndex < itemNodes.count else { continue }
            let nodeToUpdate = itemNodes[updatedItem.slotIndex]
            
            // Only update if it's an Object
            if updatedItem.isObject {
                // Stack
                if let stackNode = nodeToUpdate.elements(forName: "stack").first {
                    stackNode.stringValue = "\(updatedItem.stack)"
                } else {
                    let newStack = XMLElement(name: "stack", stringValue: "\(updatedItem.stack)")
                    nodeToUpdate.addChild(newStack)
                }
                
                // Item ID (if needed, but usually we just update stack for safety)
                if let idNode = nodeToUpdate.elements(forName: "itemId").first {
                    idNode.stringValue = updatedItem.itemId
                }
            } else if updatedItem.name.isEmpty {
                // Delete the item (make it an empty slot)
                nodeToUpdate.setChildren(nil)
                if let nilAttr = XMLNode.attribute(withName: "xsi:nil", stringValue: "true") as? XMLNode {
                    nodeToUpdate.attributes = [nilAttr]
                }
            }
        }
        
        do {
            let updatedXMLData = document.xmlData(options: .nodePrettyPrint)
            try updatedXMLData.write(to: info.fileURL, options: .atomic)
            return true
        } catch {
            print("Failed to save updated inventory XML: \(error)")
            return false
        }
    }
}
