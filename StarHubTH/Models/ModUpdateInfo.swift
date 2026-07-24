import Foundation

struct ModUpdateInfo: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let version: String
    let url: String
}
