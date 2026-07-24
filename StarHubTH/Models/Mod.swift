import Foundation

extension ModItem {
    /// SMAPI UniqueID (e.g. "Pathoschild.ContentPatcher"). Distinct from `NexusID` —
    /// nothing at the type level used to stop `setCustomTag(for modId:)` and
    /// `downloadModFromNexus(nexusId:)` from being passed the wrong one.
    ///
    /// Named `UniqueID`, not `ID` — `ModItem` conforms to `Identifiable` with `id` returning
    /// `FolderName` (see `ID.5` in SWIFT_STANDARDS.md: identity is the stable folder name, not
    /// the SMAPI unique ID). A nested type literally named `ID` collides with `Identifiable`'s
    /// own associated type `ID`: Swift infers `Identifiable.ID = ModItem.ID` from the nested
    /// type's name rather than from the `id` property's actual return type, and conformance
    /// fails with a misleading "does not conform to Identifiable" pointing at `var body`.
    ///
    /// Codable is hand-written as a single-value container so the wire format stays a
    /// bare string — this type replaces raw `String` fields in `Codable` models
    /// (`ModProfile.enabledModIds`, `StarHubPackMod.uniqueId`) that are already persisted
    /// in UserDefaults and exported pack/collection files. Synthesized Codable would encode
    /// `{"rawValue": "..."}` instead and silently fail to decode a user's existing data.
    struct UniqueID: Hashable, RawRepresentable, ExpressibleByStringLiteral {
        let rawValue: String
        init(rawValue: String) { self.rawValue = rawValue }
        init(stringLiteral value: String) { self.rawValue = value }
    }

    /// Nexus Mods' numeric mod ID. Same single-value-container reasoning as `UniqueID`.
    struct NexusID: Hashable, RawRepresentable, ExpressibleByIntegerLiteral {
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }
        init(integerLiteral value: Int) { self.rawValue = value }
    }

    /// The mod's folder name under `Mods/` — stable across enable/disable, since
    /// toggling moves the folder between `Mods/` and `Mods_disabled/` without renaming it.
    /// Same single-value-container reasoning as `UniqueID`.
    struct FolderName: Hashable, RawRepresentable, ExpressibleByStringLiteral {
        let rawValue: String
        init(rawValue: String) { self.rawValue = rawValue }
        init(stringLiteral value: String) { self.rawValue = value }
    }
}

extension ModItem.UniqueID: Codable {
    init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension ModItem.NexusID: Codable {
    init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(Int.self) }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension ModItem.FolderName: Codable {
    init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ModDependency: Equatable {
    let uniqueId: ModItem.UniqueID
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

    var id: FolderName { folderName }
    let uniqueId: UniqueID
    let name: String
    let folderName: FolderName
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
