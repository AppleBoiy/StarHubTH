import Foundation

/// Pure computation, no stored state — a namespace of `static` functions like `ModGraph`,
/// not a singleton (§4.2: `.shared` is for injectable I/O boundaries, not stateless
/// queries that never need a stub).
enum CollectionInstaller {
    static func install(collection: ModCollection, currentMods: [Mod], nexusApiKey: String) -> [String] {
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

        return missingNexusIds
    }
}
