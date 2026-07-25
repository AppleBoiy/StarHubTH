import Foundation

struct ModScanner {
    static func scan(gameDir: String, customModTags: [String: String]) -> [Mod] {
        guard !gameDir.isEmpty else { return [] }
        
        let fm = FileManager.default
        let modsPath = (gameDir as NSString).appendingPathComponent("Mods")
        let disabledModsPath = (gameDir as NSString).appendingPathComponent("Mods_disabled")
        
        var scannedMods: [Mod] = []
        
        func parseModFolder(at path: String, relativePath: String, isEnabled: Bool) -> Mod? {
            return ModManifestParser.parse(at: path, relativePath: relativePath, isEnabled: isEnabled, customTags: customModTags)
        }
        
        func scanFolderForMods(at path: String, isEnabled: Bool) {
            let url = URL(fileURLWithPath: path)
            var groups: [String: [Mod]] = [:]
            var ungrouped: [Mod] = []
            
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
                    let groupAuthor = allSame ? firstAuthor : L10n.Mods.multipleAuthors
                    
                    let groupInstallDate = modsInGroup.compactMap { $0.installDate }.min()
                    let groupLastModifiedDate = modsInGroup.compactMap { $0.lastModifiedDate }.max()
                    
                    let groupMod = Mod(
                        uniqueId: "",
                        name: groupName,
                        folderName: Mod.FolderName(rawValue: groupName),
                        version: "",
                        author: groupAuthor,
                        description: "\(modsInGroup.count)",
                        nexusUrl: "",
                        isEnabled: isEnabled,
                        dependencies: [],
                        kind: .group(children: modsInGroup),
                        tag: modsInGroup.first(where: { !$0.tag.isEmpty })?.tag ?? "",
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
