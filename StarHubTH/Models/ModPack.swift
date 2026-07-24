import Foundation

struct StarHubPackMod: Codable, Identifiable {
    let id: String // same as uniqueId
    let name: String
    let uniqueId: String
    let version: String?
    let nexusId: Int?
    
    init(name: String, uniqueId: String, version: String?, nexusId: Int?) {
        self.id = uniqueId
        self.name = name
        self.uniqueId = uniqueId
        self.version = version
        self.nexusId = nexusId
    }
}

struct StarHubPack: Codable {
    let packName: String
    let author: String?
    let description: String?
    let mods: [StarHubPackMod]
}
