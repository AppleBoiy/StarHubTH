import Foundation

struct SaveNote: Codable, Sendable {
    var tag: String   // emoji tag key e.g. "⭐", "🏆", ""
    var note: String  // free text
    var customIconPath: String?
}
