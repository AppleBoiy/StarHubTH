import Foundation

struct ModUpdateInfo: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let version: String
    let url: String
}
