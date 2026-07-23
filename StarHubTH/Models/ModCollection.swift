import Foundation

struct ModCollection: Codable {
    let name: String
    let author: String
    let mods: [CollectionModItem]
}

struct CollectionModItem: Codable {
    let uniqueID: String
    let nexusID: String?
    let name: String
    let version: String
}
