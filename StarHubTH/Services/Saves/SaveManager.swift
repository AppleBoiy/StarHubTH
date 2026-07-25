import Foundation

/// `savesDir` is a `let`, set once in `init()` and never mutated — a plain `Sendable`
/// conformance, no actor needed (see Phase 5's Context notes on why `SaveManager` isn't
/// worth actor-izing: it holds no mutable state for an actor to protect).
final class SaveManager: Sendable {
    static let shared = SaveManager()

    private let savesDir: URL

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.savesDir = homeDir.appendingPathComponent(".config/StardewValley/Saves")
    }

    func fetchSaves() throws(SaveStorageError) -> [SaveGameInfo] {
        var saves: [SaveGameInfo] = []
        let fileManager = FileManager.default

        let folders: [URL]
        do {
            folders = try fileManager.contentsOfDirectory(at: savesDir, includingPropertiesForKeys: [.isDirectoryKey])
        } catch {
            throw .directoryUnreadable(underlying: error)
        }

        for folder in folders {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue {
                let saveName = folder.lastPathComponent
                let saveFile = folder.appendingPathComponent(saveName)

                if fileManager.fileExists(atPath: saveFile.path) {
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
        // Hardcoded pattern, not user input — NSRegularExpression can only fail on malformed
        // syntax, which this literal isn't, so `try?` degrading to a no-op edit is unreachable
        // in practice rather than a swallowed real failure.
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
                // Hardcoded pattern — see updateSpouseInPlayer's comment above.
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

    func backupSave(info: SaveGameInfo) throws(SaveStorageError) {
        let fileManager = FileManager.default
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let folderPath = info.fileURL.deletingLastPathComponent()
        var backupPath = folderPath.appendingPathExtension("backup_\(timestamp)")

        // The timestamp has 1-second resolution, so two edits within the same second
        // (e.g. updateSave and updateInventory both call this) would otherwise collide
        // on the same path and make copyItem throw "already exists".
        var suffix = 1
        while fileManager.fileExists(atPath: backupPath.path) {
            backupPath = folderPath.appendingPathExtension("backup_\(timestamp)_\(suffix)")
            suffix += 1
        }

        do {
            try fileManager.copyItem(at: folderPath, to: backupPath)
        } catch {
            throw .backupFailed(underlying: error)
        }
    }

    func updateSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String) throws(SaveStorageError) {
        try backupSave(info: info)

        var content: String
        do {
            content = try String(contentsOf: info.fileURL, encoding: .utf8)
        } catch {
            throw .fileUnreadable(underlying: error)
        }

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
        } catch {
            throw .fileWriteFailed(underlying: error)
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
        //
        // Not finding the entry (any of the three guards below) is an expected, non-fatal
        // state — an NPC's friendship entry can legitimately be absent (e.g. never met) —
        // so this degrades to a no-op edit rather than throwing.
        let keyMarker = "<string>\(npcName)</string>"
        guard let keyRange = xml.range(of: keyMarker) else {
            return xml
        }

        // Find the enclosing <item>...</item> that contains this key
        let beforeKey = String(xml[..<keyRange.lowerBound])
        guard let itemStart = beforeKey.range(of: "<item>", options: .backwards) else {
            return xml
        }

        let itemStartIdx = itemStart.lowerBound
        guard let itemEnd = xml.range(of: "</item>", range: keyRange.upperBound..<xml.endIndex) else {
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
        // Hardcoded pattern — see updateSpouseInPlayer's comment above.
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
        // `tag` is always one of this file's own hardcoded literals ("name", "farmName", …),
        // never user input, so the interpolated pattern can't become malformed regex syntax.
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

    func deleteSave(info: SaveGameInfo) throws(SaveStorageError) {
        let folderPath = info.fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.trashItem(at: folderPath, resultingItemURL: nil)
        } catch {
            throw .moveFailed(underlying: error)
        }
    }

    /// Throws if any file that needed updating couldn't be read or written — callers must
    /// propagate that instead of reporting overall success, since a duplicated/branched save
    /// whose internal name silently didn't update still shows the *old* player/farm name
    /// in-game despite the app confirming the rename worked.
    private func modifyInternalSaveNames(in folderURL: URL, newSaveName: String, newPlayerName: String, newFarmName: String) throws(SaveStorageError) {
        let fileManager = FileManager.default
        let saveGameInfoURL = folderURL.appendingPathComponent("SaveGameInfo")
        let mainSaveURL = folderURL.appendingPathComponent(newSaveName)

        // Its Bool return isn't a swallowed failure — `succeeded` below is checked at the
        // end of this function and thrown as `.internalNameUpdateFailed`, so a read/write
        // failure here does reach the caller, just aggregated across both files first.
        func updateFile(at url: URL) -> Bool {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
            var modified = replaceFirstTag(tag: "name", with: newPlayerName, in: content)
            modified = replaceFirstTag(tag: "farmName", with: newFarmName, in: modified)
            do {
                try modified.write(to: url, atomically: true, encoding: .utf8)
                return true
            } catch {
                return false
            }
        }

        var succeeded = true
        if fileManager.fileExists(atPath: saveGameInfoURL.path) {
            succeeded = updateFile(at: saveGameInfoURL) && succeeded
        }
        if fileManager.fileExists(atPath: mainSaveURL.path) {
            succeeded = updateFile(at: mainSaveURL) && succeeded
        }
        guard succeeded else { throw .internalNameUpdateFailed }
    }

    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String) throws(SaveStorageError) {
        let fileManager = FileManager.default
        let folderPath = info.fileURL.deletingLastPathComponent()
        let saveName = folderPath.lastPathComponent

        var newSaveName = "\(saveName)_copy"
        var newFolderPath = folderPath.deletingLastPathComponent().appendingPathComponent(newSaveName)

        var counter = 1
        while fileManager.fileExists(atPath: newFolderPath.path) {
            newSaveName = "\(saveName)_copy_\(counter)"
            newFolderPath = folderPath.deletingLastPathComponent().appendingPathComponent(newSaveName)
            counter += 1
        }

        do {
            try fileManager.copyItem(at: folderPath, to: newFolderPath)

            // Rename internal file
            let oldFilePath = newFolderPath.appendingPathComponent(saveName)
            let newFilePath = newFolderPath.appendingPathComponent(newSaveName)
            if fileManager.fileExists(atPath: oldFilePath.path) {
                try fileManager.moveItem(at: oldFilePath, to: newFilePath)
            }

            // Modify name and farm name inside XML files
            try modifyInternalSaveNames(in: newFolderPath, newSaveName: newSaveName, newPlayerName: newName, newFarmName: newFarm)
        } catch let error as SaveStorageError {
            throw error
        } catch {
            throw .moveFailed(underlying: error)
        }
    }

    // MARK: - Backup Timeline

    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String) throws(SaveStorageError) {
        let fileManager = FileManager.default
        let backupFolderPath = backup.folderPath
        let originalSaveName = String(backupFolderPath.lastPathComponent.split(separator: ".")[0])
        let parentDir = backupFolderPath.deletingLastPathComponent()

        var newSaveName = "\(originalSaveName)_branch"
        var newFolderPath = parentDir.appendingPathComponent(newSaveName)

        var counter = 1
        while fileManager.fileExists(atPath: newFolderPath.path) {
            newSaveName = "\(originalSaveName)_branch_\(counter)"
            newFolderPath = parentDir.appendingPathComponent(newSaveName)
            counter += 1
        }

        do {
            try fileManager.copyItem(at: backupFolderPath, to: newFolderPath)

            // Rename internal file
            let oldFilePath = newFolderPath.appendingPathComponent(originalSaveName)
            let newFilePath = newFolderPath.appendingPathComponent(newSaveName)
            if fileManager.fileExists(atPath: oldFilePath.path) {
                try fileManager.moveItem(at: oldFilePath, to: newFilePath)
            }

            // Modify name and farm name inside XML files
            try modifyInternalSaveNames(in: newFolderPath, newSaveName: newSaveName, newPlayerName: newName, newFarmName: newFarm)
        } catch let error as SaveStorageError {
            throw error
        } catch {
            throw .moveFailed(underlying: error)
        }
    }

    /// List all `.backup_*` sibling folders for a given save
    func listBackups(for info: SaveGameInfo) throws(SaveStorageError) -> [SaveBackup] {
        let saveFolder = info.fileURL.deletingLastPathComponent()
        let parentDir = saveFolder.deletingLastPathComponent()
        let saveName = saveFolder.lastPathComponent

        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(
                at: parentDir,
                includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
                options: .skipsHiddenFiles
            )
        } catch {
            throw .directoryUnreadable(underlying: error)
        }

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
    func restoreBackup(backup: SaveBackup, info: SaveGameInfo) throws(SaveStorageError) {
        let fileManager = FileManager.default
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
            try fileManager.copyItem(at: saveFolder, to: preRestoreBackupPath)

            // Move current save folder to temporary staging
            try fileManager.moveItem(at: saveFolder, to: tempTrash)

            do {
                // Copy backup into place
                try fileManager.copyItem(at: backup.folderPath, to: saveFolder)
                // Best-effort: the restore itself already succeeded once we reach this line,
                // so a failure trashing the now-unneeded temp copy isn't worth reporting as
                // an overall restore failure.
                try? fileManager.trashItem(at: tempTrash, resultingItemURL: nil)
            } catch {
                // Rollback: restore original save from tempTrash. Best-effort — we're
                // already in the failure path of the primary operation, and there's no
                // further fallback if the rollback itself fails; the `.moveFailed` thrown
                // below is the only signal the caller gets either way.
                if fileManager.fileExists(atPath: tempTrash.path) && !fileManager.fileExists(atPath: saveFolder.path) {
                    try? fileManager.moveItem(at: tempTrash, to: saveFolder)
                }
                throw error
            }
        } catch {
            throw .moveFailed(underlying: error)
        }
    }

    /// Delete a single backup folder
    func deleteBackup(_ backup: SaveBackup) throws(SaveStorageError) {
        do {
            try FileManager.default.trashItem(at: backup.folderPath, resultingItemURL: nil)
        } catch {
            throw .moveFailed(underlying: error)
        }
    }
    // MARK: - Inventory Editing

    func fetchInventory(for info: SaveGameInfo) throws(SaveStorageError) -> [InventoryItem] {
        // No `.documentTidyXML` — that's libxml's HTML-tidy-style repair mode for
        // malformed input, and it can reformat/normalize content it considers invalid.
        // Stardew's save XML is always well-formed (produced by .NET's XmlSerializer),
        // so plain parsing avoids passing SMAPI mods' own <modData> content through a
        // "repair" pass it was never meant for.
        guard let data = try? Data(contentsOf: info.fileURL),
              let document = try? XMLDocument(data: data, options: []),
              let root = document.rootElement() else {
            throw .inventoryUnreadable
        }

        var inventory: [InventoryItem] = []

        // Find /SaveGame/player/items
        let player = root.elements(forName: "player").first
        let itemsElement = player?.elements(forName: "items").first

        guard let itemsNode = itemsElement else { throw .inventoryUnreadable }

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

    func updateInventory(info: SaveGameInfo, items: [InventoryItem]) throws(SaveStorageError) {
        // Backup first
        try backupSave(info: info)

        // Same reasoning as `fetchInventory`: no `.documentTidyXML` on the way in.
        guard let data = try? Data(contentsOf: info.fileURL),
              let document = try? XMLDocument(data: data, options: []),
              let root = document.rootElement() else {
            throw .inventoryUnreadable
        }

        // Find /SaveGame/player/items
        guard let player = root.elements(forName: "player").first,
              let itemsElement = player.elements(forName: "items").first else {
            throw .inventoryUnreadable
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
            // No `.nodePrettyPrint` — that reformats the entire document's whitespace,
            // not just the nodes this function actually changed.
            let updatedXMLData = document.xmlData
            try updatedXMLData.write(to: info.fileURL, options: .atomic)
        } catch {
            throw .fileWriteFailed(underlying: error)
        }
    }
}
