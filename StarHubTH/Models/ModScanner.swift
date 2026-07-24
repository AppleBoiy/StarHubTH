import Foundation

struct ModScanner {
    static func scan(gameDir: String, customModTags: [String: String]) -> [ModItem] {
        guard !gameDir.isEmpty else { return [] }
        
        let fm = FileManager.default
        let modsPath = (gameDir as NSString).appendingPathComponent("Mods")
        let disabledModsPath = (gameDir as NSString).appendingPathComponent("Mods_disabled")
        
        var scannedMods: [ModItem] = []
        
        func parseModFolder(at path: String, relativePath: String, isEnabled: Bool) -> ModItem? {
            return ModManifestParser.parse(at: path, relativePath: relativePath, isEnabled: isEnabled, customTags: customModTags)
        }
        
        func scanFolderForMods(at path: String, isEnabled: Bool) {
            let url = URL(fileURLWithPath: path)
            var groups: [String: [ModItem]] = [:]
            var ungrouped: [ModItem] = []
            
            if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent.lowercased() == "manifest.json" {
                        let modFolderURL = fileURL.deletingLastPathComponent()
                        let relativePath = modFolderURL.path.replacingOccurrences(of: url.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        if let mod = parseModFolder(at: modFolderURL.path, relativePath: relativePath, isEnabled: isEnabled) {
                            
                            // Determine top-level folder
                            let pathComponents = relativePath.components(separatedBy: "/")
                            
                            if pathComponents.count > 1, let topFolder = pathComponents.first, !topFolder.isEmpty {
                                groups[topFolder, default: []].append(mod)
                            } else {
                                ungrouped.append(mod)
                            }
                        }
                    }
                }
            }
            
            scannedMods.append(contentsOf: ungrouped)
            
            for (groupName, modsInGroup) in groups {
                if modsInGroup.count == 1 {
                    scannedMods.append(modsInGroup[0])
                } else {
                    let firstAuthor = modsInGroup.first(where: { $0.author != "Unknown" })?.author ?? "Unknown"
                    let allSame = modsInGroup.allSatisfy { $0.author == firstAuthor || $0.author == "Unknown" }
                    let groupAuthor = allSame ? firstAuthor : NSLocalizedString("mods_multiple_authors", comment: "")
                    
                    let groupInstallDate = modsInGroup.compactMap { $0.installDate }.min()
                    let groupLastModifiedDate = modsInGroup.compactMap { $0.lastModifiedDate }.max()
                    
                    let groupMod = ModItem(
                        uniqueId: "",
                        name: groupName,
                        folderName: groupName,
                        version: "",
                        author: groupAuthor,
                        description: "\(modsInGroup.count) mods",
                        nexusUrl: "",
                        isEnabled: isEnabled,
                        dependencies: [],
                        children: modsInGroup,
                        isGroup: true,
                        modTag: modsInGroup.first(where: { !$0.modTag.isEmpty })?.modTag ?? "",
                        installDate: groupInstallDate,
                        lastModifiedDate: groupLastModifiedDate
                    )
                    scannedMods.append(groupMod)
                }
            }
        }
        
        if fm.fileExists(atPath: modsPath) {
            scanFolderForMods(at: modsPath, isEnabled: true)
        }
        
        if fm.fileExists(atPath: disabledModsPath) {
            scanFolderForMods(at: disabledModsPath, isEnabled: false)
        }
        
        return scannedMods.sorted { 
            if $0.isGroup != $1.isGroup {
                return $0.isGroup 
            }
            return $0.name.lowercased() < $1.name.lowercased() 
        }
    }
}
