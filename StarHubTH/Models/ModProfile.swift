import Foundation

struct ModProfile: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var enabledModIds: [Mod.UniqueID]
}
