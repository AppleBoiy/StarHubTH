import Foundation

struct ModDependency: Equatable {
    let uniqueId: String
    let isRequired: Bool
}

enum DependencyStatus: Equatable {
    case active
    case disabled(ModItem)
    case missing
}

struct ModItem: Identifiable, Equatable {
    var id: String { folderName }
    let uniqueId: String
    let name: String
    let folderName: String
    let version: String
    let author: String
    let description: String
    let nexusUrl: String
    var isEnabled: Bool
    let dependencies: [ModDependency]
    var children: [ModItem]?
    var isGroup: Bool = false
    var modTag: String = ""      // inferred type tag (e.g. "Framework", "Cosmetic", "UI", …)
    var installDate: Date? = nil
    var lastModifiedDate: Date? = nil
}
