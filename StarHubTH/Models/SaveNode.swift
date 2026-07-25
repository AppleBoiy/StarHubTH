import Foundation

struct SaveNode: Identifiable, Equatable, Sendable {
    var id: String { info.id }
    let info: SaveGameInfo
    var children: [SaveNode]
}
