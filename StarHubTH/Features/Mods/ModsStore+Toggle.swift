import Foundation

/// Enable/disable toggling, including dependency-chain cascade (§ file-size convention
/// split, see ModsStore.swift's header comment).
extension ModsStore {
    func toggleMod(
        _ mod: Mod,
        gameDir: String,
        chainToggleDependencies: Bool,
        log: (String) -> Void,
        onToggled: () -> Void
    ) {
        // Helper to find the top-level folder that contains a given uniqueId
        func topLevelFolder(for uniqueId: Mod.UniqueID) -> Mod.FolderName? {
            for m in self.mods {
                switch m.kind {
                case .single:
                    if m.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame {
                        return m.folderName
                    }
                case .group(let children):
                    if children.contains(where: { $0.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame }) {
                        return m.folderName
                    }
                }
            }
            return nil
        }

        // Helper to get all dependencies of a top-level folder (including its children)
        func dependencies(for folderName: Mod.FolderName) -> [ModDependency] {
            guard let m = self.mods.first(where: { $0.folderName == folderName }) else { return [] }
            if case .group(let children) = m.kind {
                return children.flatMap { $0.dependencies }
            } else {
                return m.dependencies
            }
        }

        var foldersToToggle: Set<Mod.FolderName> = [mod.folderName]
        let targetState = !mod.isEnabled // True if we are enabling, false if disabling

        if chainToggleDependencies {
            if targetState == true {
                // Enabling: recursively enable all REQUIRED dependencies
                var queue = [mod.folderName]
                while !queue.isEmpty {
                    let currentFolder = queue.removeFirst()
                    let deps = dependencies(for: currentFolder)

                    for dep in deps where dep.isRequired {
                        if let depFolder = topLevelFolder(for: dep.uniqueId) {
                            let isDepFolderEnabled = self.mods.first(where: { $0.folderName == depFolder })?.isEnabled ?? false
                            if !isDepFolderEnabled && !foldersToToggle.contains(depFolder) {
                                foldersToToggle.insert(depFolder)
                                queue.append(depFolder)
                            }
                        }
                    }
                }
            } else {
                // Disabling: recursively disable all enabled mods that REQUIRE this mod
                var queue = [mod.folderName]
                while !queue.isEmpty {
                    let currentFolder = queue.removeFirst()

                    var providedUniqueIds: [Mod.UniqueID] = []
                    if let m = self.mods.first(where: { $0.folderName == currentFolder }) {
                        if case .group(let children) = m.kind {
                            providedUniqueIds = children.map { $0.uniqueId }
                        } else {
                            providedUniqueIds = [m.uniqueId]
                        }
                    }

                    for otherMod in self.mods where otherMod.isEnabled && !foldersToToggle.contains(otherMod.folderName) {
                        let otherDeps = dependencies(for: otherMod.folderName)
                        let requiresCurrent = otherDeps.contains { dep in
                            dep.isRequired && providedUniqueIds.contains { $0.rawValue.caseInsensitiveCompare(dep.uniqueId.rawValue) == .orderedSame }
                        }
                        if requiresCurrent {
                            foldersToToggle.insert(otherMod.folderName)
                            queue.append(otherMod.folderName)
                        }
                    }
                }
            }
        }
        // else: chainToggleDependencies == false → only toggle the single mod itself

        let fileManager = FileManager.default
        let modsPath = (gameDir as NSString).appendingPathComponent("Mods")
        let disabledModsPath = (gameDir as NSString).appendingPathComponent("Mods_disabled")
        var anyMoved = false

        for folderName in foldersToToggle {
            guard let m = self.mods.first(where: { $0.folderName == folderName }) else { continue }
            if m.isEnabled == targetState { continue }

            let srcPath = ((m.isEnabled ? modsPath : disabledModsPath) as NSString).appendingPathComponent(m.folderName.rawValue)
            let destFolder = m.isEnabled ? disabledModsPath : modsPath
            let destPath = ((destFolder as NSString).appendingPathComponent(m.folderName.rawValue) as String)

            let destBackup = "\(destPath)_toggle_backup_temp"
            do {
                let destParent = (destPath as NSString).deletingLastPathComponent
                if !fileManager.fileExists(atPath: destParent) {
                    try fileManager.createDirectory(atPath: destParent, withIntermediateDirectories: true, attributes: nil)
                }
                if fileManager.fileExists(atPath: destPath) {
                    if fileManager.fileExists(atPath: destBackup) {
                        try? fileManager.removeItem(atPath: destBackup)
                    }
                    try fileManager.moveItem(atPath: destPath, toPath: destBackup)
                }

                do {
                    try fileManager.moveItem(atPath: srcPath, toPath: destPath)
                    if fileManager.fileExists(atPath: destBackup) {
                        try? fileManager.trashItem(at: URL(fileURLWithPath: destBackup), resultingItemURL: nil)
                    }
                    anyMoved = true
                } catch {
                    if fileManager.fileExists(atPath: destBackup) && !fileManager.fileExists(atPath: destPath) {
                        try? fileManager.moveItem(atPath: destBackup, toPath: destPath)
                    }
                    throw error
                }
            } catch {
                log("Failed to toggle \(m.name): \(error.localizedDescription)")
            }
        }

        if anyMoved {
            log("\(targetState ? localization.L(L10n.Mods.enabled) : localization.L(L10n.Mods.disabled)): \(mod.name)\(foldersToToggle.count > 1 ? " + Dependencies" : "")")
            self.scanMods(gameDir: gameDir)
            onToggled()
        }
    }
}
