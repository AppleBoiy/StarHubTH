import Foundation

/// Advanced save management (delete/duplicate) and the backup timeline (branch/list/
/// restore/delete a backup) — § file-size convention split, see SaveManager.swift's
/// header comment.
extension SaveManager {
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
}
