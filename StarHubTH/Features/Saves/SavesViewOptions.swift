import Foundation

enum SaveViewMode: String, Codable {
    case list
    case grid
}

enum SaveSortOption: String, Codable {
    case name
    case lastPlayed
    case money
}
