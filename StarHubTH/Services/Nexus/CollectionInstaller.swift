import Foundation

/// No stored properties, pure computation — a plain `Sendable` conformance, no actor needed.
final class CollectionInstaller: Sendable {
    static let shared = CollectionInstaller()
    private init() {}
    
    func install(collection: ModCollection, currentMods: [ModItem], nexusApiKey: String) -> [String] {
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
