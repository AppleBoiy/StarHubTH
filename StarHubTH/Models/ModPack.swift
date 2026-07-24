import Foundation

struct StarHubPackMod: Codable, Identifiable {
    let id: ModItem.UniqueID // same as uniqueId
    let name: String
    let uniqueId: ModItem.UniqueID
    let version: String?
    let nexusId: ModItem.NexusID?
    // Rich per-mod metadata from Nexus API
    var modAuthor: String?
    var modDownloads: Int?
    var modUpdatedAt: String?
    var thumbnailUrl: String?

    init(name: String, uniqueId: ModItem.UniqueID, version: String?, nexusId: ModItem.NexusID?,
         modAuthor: String? = nil, modDownloads: Int? = nil,
         modUpdatedAt: String? = nil, thumbnailUrl: String? = nil) {
        self.id = uniqueId
        self.name = name
        self.uniqueId = uniqueId
        self.version = version
        self.nexusId = nexusId
        self.modAuthor = modAuthor
        self.modDownloads = modDownloads
        self.modUpdatedAt = modUpdatedAt
        self.thumbnailUrl = thumbnailUrl
    }
}

struct StarHubPack: Codable {
    let packName: String
    let author: String?
    let description: String?
    let mods: [StarHubPackMod]
    // Rich metadata (populated from Nexus API)
    var imageUrl: String?
    var revision: Int?
    var updatedAt: String?
    var gameVersion: String?
    var totalDownloads: Int?
    var endorsements: Int?
}
