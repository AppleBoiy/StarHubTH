import Foundation

struct ModCollection: Codable, Sendable {
    let name: String
    let author: String
    let mods: [CollectionModItem]
}

struct CollectionModItem: Codable, Sendable {
    let uniqueID: String
    let nexusID: String?
    let name: String
    let version: String
}
