import Foundation

/// `savesDir` is a `let`, set once in `init()` and never mutated — a plain `Sendable`
/// conformance, no actor needed (see Phase 5's Context notes on why `SaveManager` isn't
/// worth actor-izing: it holds no mutable state for an actor to protect).
///
/// Split across SaveManager.swift/SaveManager+Management.swift/SaveManager+Inventory.swift
/// (§ file-size convention) — this file owns save fetch/backup/field-editing; the other
/// two own advanced management (delete/duplicate/branch/backup-timeline) and inventory
/// editing respectively. `replaceFirstTag` is `internal` rather than `private` because
/// SaveManager+Management.swift's `modifyInternalSaveNames` also calls it — `private` is
/// file-scoped in Swift, not type-scoped, so a helper shared across the split can't stay
/// `private`. Every other helper here is used only within this file and stays `private`.
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

    func replaceFirstTag(tag: String, with value: String, in xml: String) -> String {
        let pattern = "(<\(tag)>)([^<]+)(</\(tag)>)"
        // `tag` is always one of this file's own hardcoded literals ("name", "farmName", …),
        // never user input, so the interpolated pattern can't become malformed regex syntax.
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return xml }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)

        // We only want to replace the first occurrence (player data is always at the top)
        if let match = regex.firstMatch(in: xml, options: [], range: range) {
            if let swiftRange = Range(match.range, in: xml) {
                var modified = xml
                modified.replaceSubrange(swiftRange, with: "<\(tag)>\(value)</\(tag)>")
                return modified
            }
        }
        return xml
    }
}
