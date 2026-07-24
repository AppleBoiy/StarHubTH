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
    enum Kind: Equatable {
        case single
        case group(children: [ModItem])   // a group always has its children
    }

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
    var kind: Kind = .single
    var modTag: String = ""      // inferred type tag (e.g. "Framework", "Cosmetic", "UI", …)
    var installDate: Date? = nil
    var lastModifiedDate: Date? = nil

    var isGroup: Bool {
        if case .group = kind { return true }
        return false
    }

    /// This mod if it's standalone, or its children if it's a group. Replaces the
    /// `isGroup ? (children ?? []) : [self]` ternary that used to be copy-pasted at every
    /// call site that needed to walk mods without caring whether they're grouped.
    var allMods: [ModItem] {
        switch kind {
        case .single: return [self]
        case .group(let children): return children
        }
    }
}
