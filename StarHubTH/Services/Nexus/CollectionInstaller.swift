import Foundation

final class CollectionInstaller {
    static let shared = CollectionInstaller()
    private init() {}
    
    func install(collection: ModCollection, currentMods: [ModItem], nexusApiKey: String, onMissingQueue: @escaping ([String]) -> Void) {
        let allMods = currentMods.flatMap { $0.allMods }
        var missingNexusIds: [String] = []
        
        for mod in collection.mods {
            let found = allMods.contains { $0.uniqueId.rawValue.caseInsensitiveCompare(mod.uniqueID) == .orderedSame }
            if !found {
                if let nId = mod.nexusID, !nId.isEmpty {
                    missingNexusIds.append(nId)
                }
            }
        }
        
        if !missingNexusIds.isEmpty {
            onMissingQueue(missingNexusIds)
        }
    }
}
