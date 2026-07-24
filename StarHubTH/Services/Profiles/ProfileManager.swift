import Foundation

final class ProfileManager {
    static let shared = ProfileManager()
    private init() {}
    
    func loadProfiles() -> (profiles: [ModProfile], activeId: UUID?) {
        var loadedProfiles: [ModProfile] = []
        var loadedActiveId: UUID? = nil
        
        if let data = UserDefaults.standard.data(forKey: "modProfiles"),
           let profiles = try? JSONDecoder().decode([ModProfile].self, from: data) {
            loadedProfiles = profiles
        }
        
        if let activeIdStr = UserDefaults.standard.string(forKey: "activeProfileId"),
           let activeId = UUID(uuidString: activeIdStr) {
            loadedActiveId = activeId
        }
        
        return (loadedProfiles, loadedActiveId)
    }
    
    func saveProfiles(_ profiles: [ModProfile], activeProfileId: UUID?) {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "modProfiles")
        }
        if let activeId = activeProfileId {
            UserDefaults.standard.set(activeId.uuidString, forKey: "activeProfileId")
        } else {
            UserDefaults.standard.removeObject(forKey: "activeProfileId")
        }
    }
    
    /// Moves mod files to match the given profile's enabledModIds.
    func applyProfileToFilesystem(profile: ModProfile, mods: [ModItem], gameDir: String) -> Bool {
        let fm = FileManager.default
        let modsPath = (gameDir as NSString).appendingPathComponent("Mods")
        let disabledModsPath = (gameDir as NSString).appendingPathComponent("Mods_disabled")
        var hasError = false
        
        func isCoveredByProfile(_ mod: ModItem) -> Bool {
            if case .group(let children) = mod.kind {
                return children.contains { profile.enabledModIds.contains($0.uniqueId) }
            }
            return profile.enabledModIds.contains(mod.uniqueId)
        }
        
        // Disable mods not in profile
        for mod in mods.filter({ $0.isEnabled }) {
            if !isCoveredByProfile(mod) {
                let src = (modsPath as NSString).appendingPathComponent(mod.folderName)
                let dst = (disabledModsPath as NSString).appendingPathComponent(mod.folderName)
                let dstBackup = "\(dst)_profile_backup_temp"
                do {
                    try fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                            withIntermediateDirectories: true, attributes: nil)
                    if fm.fileExists(atPath: dst) {
                        if fm.fileExists(atPath: dstBackup) {
                            try? fm.removeItem(atPath: dstBackup)
                        }
                        try fm.moveItem(atPath: dst, toPath: dstBackup)
                    }
                    
                    do {
                        try fm.moveItem(atPath: src, toPath: dst)
                        if fm.fileExists(atPath: dstBackup) {
                            try? fm.trashItem(at: URL(fileURLWithPath: dstBackup), resultingItemURL: nil)
                        }
                    } catch {
                        if fm.fileExists(atPath: dstBackup) && !fm.fileExists(atPath: dst) {
                            try? fm.moveItem(atPath: dstBackup, toPath: dst)
                        }
                        throw error
                    }
                } catch {
                    print("Failed to disable \(mod.name) for profile: \(error)")
                    hasError = true
                }
            }
        }
        
        // Enable mods in profile
        for mod in mods.filter({ !$0.isEnabled }) {
            if isCoveredByProfile(mod) {
                let src = (disabledModsPath as NSString).appendingPathComponent(mod.folderName)
                let dst = (modsPath as NSString).appendingPathComponent(mod.folderName)
                let dstBackup = "\(dst)_profile_backup_temp"
                do {
                    try fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                            withIntermediateDirectories: true, attributes: nil)
                    if fm.fileExists(atPath: dst) {
                        if fm.fileExists(atPath: dstBackup) {
                            try? fm.removeItem(atPath: dstBackup)
                        }
                        try fm.moveItem(atPath: dst, toPath: dstBackup)
                    }
                    
                    do {
                        try fm.moveItem(atPath: src, toPath: dst)
                        if fm.fileExists(atPath: dstBackup) {
                            try? fm.trashItem(at: URL(fileURLWithPath: dstBackup), resultingItemURL: nil)
                        }
                    } catch {
                        if fm.fileExists(atPath: dstBackup) && !fm.fileExists(atPath: dst) {
                            try? fm.moveItem(atPath: dstBackup, toPath: dst)
                        }
                        throw error
                    }
                } catch {
                    print("Failed to enable \(mod.name) for profile: \(error)")
                    hasError = true
                }
            }
        }
        
        return !hasError
    }
    
    func exportProfile(_ profile: ModProfile, mods: [ModItem], to url: URL) throws {
        let allMods = mods.flatMap { $0.allMods }
        let activeMods = allMods.filter { profile.enabledModIds.contains($0.uniqueId) }
        
        let collectionMods = activeMods.map { mod in
            let nId: String? = {
                if let u = URL(string: mod.nexusUrl), let id = u.pathComponents.last, Int(id) != nil {
                    return id
                }
                return nil
            }()
            return CollectionModItem(uniqueID: mod.uniqueId, nexusID: nId, name: mod.name, version: mod.version)
        }
        
        let collection = ModCollection(name: profile.name, author: NSUserName(), mods: collectionMods)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(collection)
        try data.write(to: url)
    }
    
    func importProfile(from url: URL) throws -> (ModCollection, ModProfile) {
        let data = try Data(contentsOf: url)
        let collection = try JSONDecoder().decode(ModCollection.self, from: data)
        
        let newProfile = ModProfile(
            id: UUID(),
            name: "\(collection.name) (Imported)",
            enabledModIds: collection.mods.map { $0.uniqueID }
        )
        return (collection, newProfile)
    }
}
