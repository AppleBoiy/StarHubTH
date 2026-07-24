import Foundation

enum ModFilterStatus: String, CaseIterable {
    case all
    case enabled
    case disabled
}

enum ModFilterDate: String, CaseIterable {
    case all
    case past24Hours
    case past7Days
    case past30Days
}

enum ModSortOption: String, CaseIterable {
    case name
    case nameDesc
    case author
    case version
    case status
    case dateAddedDesc
    case dateModifiedDesc
}
