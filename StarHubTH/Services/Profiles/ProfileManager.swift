import Foundation

/// Every stored property is a `let`/absent entirely; every method is a pure UserDefaults or
/// filesystem operation with no shared mutable state, so `Sendable` is a plain, honest
/// conformance here — no `actor` isolation needed (see Phase 5's Context notes).
final class ProfileManager: Sendable {
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
    func applyProfileToFilesystem(profile: ModProfile, mods: [Mod], gameDir: String) throws(ProfileApplyError) {
        let fileManager = FileManager.default
        let modsPath = (gameDir as NSString).appendingPathComponent("Mods")
        let disabledModsPath = (gameDir as NSString).appendingPathComponent("Mods_disabled")
        var failedModNames: [String] = []
        
        func isCoveredByProfile(_ mod: Mod) -> Bool {
            if case .group(let children) = mod.kind {
                return children.contains { profile.enabledModIds.contains($0.uniqueId) }
            }
            return profile.enabledModIds.contains(mod.uniqueId)
        }

        // Disable mods not in profile
        for mod in mods.filter({ $0.isEnabled }) {
            if !isCoveredByProfile(mod) {
                let src = (modsPath as NSString).appendingPathComponent(mod.folderName.rawValue)
                let dst = (disabledModsPath as NSString).appendingPathComponent(mod.folderName.rawValue)
                let dstBackup = "\(dst)_profile_backup_temp"
                do {
                    try fileManager.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                            withIntermediateDirectories: true, attributes: nil)
                    if fileManager.fileExists(atPath: dst) {
                        if fileManager.fileExists(atPath: dstBackup) {
                            try? fileManager.removeItem(atPath: dstBackup)
                        }
                        try fileManager.moveItem(atPath: dst, toPath: dstBackup)
                    }
                    
                    do {
                        try fileManager.moveItem(atPath: src, toPath: dst)
                        if fileManager.fileExists(atPath: dstBackup) {
                            try? fileManager.trashItem(at: URL(fileURLWithPath: dstBackup), resultingItemURL: nil)
                        }
                    } catch {
                        if fileManager.fileExists(atPath: dstBackup) && !fileManager.fileExists(atPath: dst) {
                            try? fileManager.moveItem(atPath: dstBackup, toPath: dst)
                        }
                        throw error
                    }
                } catch {
                    failedModNames.append(mod.name)
                }
            }
        }
        
        // Enable mods in profile
        for mod in mods.filter({ !$0.isEnabled }) {
            if isCoveredByProfile(mod) {
                let src = (disabledModsPath as NSString).appendingPathComponent(mod.folderName.rawValue)
                let dst = (modsPath as NSString).appendingPathComponent(mod.folderName.rawValue)
                let dstBackup = "\(dst)_profile_backup_temp"
                do {
                    try fileManager.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                            withIntermediateDirectories: true, attributes: nil)
                    if fileManager.fileExists(atPath: dst) {
                        if fileManager.fileExists(atPath: dstBackup) {
                            try? fileManager.removeItem(atPath: dstBackup)
                        }
                        try fileManager.moveItem(atPath: dst, toPath: dstBackup)
                    }
                    
                    do {
                        try fileManager.moveItem(atPath: src, toPath: dst)
                        if fileManager.fileExists(atPath: dstBackup) {
                            try? fileManager.trashItem(at: URL(fileURLWithPath: dstBackup), resultingItemURL: nil)
                        }
                    } catch {
                        if fileManager.fileExists(atPath: dstBackup) && !fileManager.fileExists(atPath: dst) {
                            try? fileManager.moveItem(atPath: dstBackup, toPath: dst)
                        }
                        throw error
                    }
                } catch {
                    failedModNames.append(mod.name)
                }
            }
        }

        guard failedModNames.isEmpty else { throw ProfileApplyError(failedModNames: failedModNames) }
    }
    
    func exportProfile(_ profile: ModProfile, mods: [Mod], to url: URL) throws {
        let allMods = mods.flatMap { $0.allMods }
        let activeMods = allMods.filter { profile.enabledModIds.contains($0.uniqueId) }

        let collectionMods = activeMods.map { mod in
            let nId: String? = {
                if let u = URL(string: mod.nexusUrl), let id = u.pathComponents.last, Int(id) != nil {
                    return id
                }
                return nil
            }()
            return CollectionModItem(uniqueID: mod.uniqueId.rawValue, nexusID: nId, name: mod.name, version: mod.version)
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
            enabledModIds: collection.mods.map { Mod.UniqueID(rawValue: $0.uniqueID) }
        )
        return (collection, newProfile)
    }
}
