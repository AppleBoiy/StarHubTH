import Foundation

/// Install status of a mod referenced by a mod pack.
enum PackModStatus: Equatable {
    case installed
    case disabled
    case missing
}

/// Pure queries over a collection of mods.
///
/// Every function here is total, side-effect free, and independent of any view model,
/// which is what makes the mod dependency logic testable. `StarHubTHViewModel` delegates
/// to these and holds no dependency-resolution logic of its own.
///
/// - Note: Extracted in refactor Phase 0 as characterization-tested seams. Behaviour is
///   deliberately identical to the original view-model implementations, including the
///   edge cases called out below — those are resolved in Phase 2, not here.
enum ModGraph {

    /// Flattens group rows into their children, leaving standalone mods as-is.
    ///
    /// A group row is a synthetic entry produced by `ModScanner` for a folder containing
    /// several mods; it is never itself an installable mod.
    static func flattened(_ mods: [ModItem]) -> [ModItem] {
        mods.flatMap { $0.allMods }
    }

    // MARK: - Dependency resolution

    /// Resolves whether the mod providing `uniqueId` is present and enabled.
    static func dependencyStatus(for uniqueId: ModItem.UniqueID, in mods: [ModItem]) -> DependencyStatus {
        let candidates = flattened(mods)
        if let found = candidates.first(where: { $0.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame }) {
            return found.isEnabled ? .active : .disabled(found)
        }
        return .missing
    }

    /// Returns the unique IDs of `mod`'s required dependencies that are not installed.
    ///
    /// Optional dependencies are ignored. Comparison is case-insensitive because SMAPI
    /// treats manifest unique IDs case-insensitively.
    static func missingDependencies(for mod: ModItem, in mods: [ModItem]) -> [ModItem.UniqueID] {
        // `Mod.Kind` (Phase 2.3) makes a group-with-no-children unrepresentable, so a group
        // can never contribute its own (empty) unique ID here the way it could before —
        // `flattened` only ever contributes real mod IDs.
        let installedIDs = Set(flattened(mods).map { $0.uniqueId.rawValue.lowercased() })

        return mod.dependencies.compactMap { dependency in
            guard dependency.isRequired else { return nil }
            return installedIDs.contains(dependency.uniqueId.rawValue.lowercased()) ? nil : dependency.uniqueId
        }
    }

    // MARK: - Mod pack status

    /// Resolves the install status of a mod referenced by a pack.
    ///
    /// Matches on the Nexus numeric ID first (parsed from each installed mod's `nexusUrl`),
    /// then falls back to the SMAPI unique ID.
    static func packModStatus(nexusID: ModItem.NexusID?, uniqueId: ModItem.UniqueID, in mods: [ModItem]) -> PackModStatus {
        let candidates = flattened(mods)

        if let nexusID {
            let matchedByNexusID = candidates.first { candidate in
                guard let url = URL(string: candidate.nexusUrl),
                      let id = Int(url.lastPathComponent) else { return false }
                return id == nexusID.rawValue
            }
            if let matchedByNexusID {
                return matchedByNexusID.isEnabled ? .installed : .disabled
            }
        }

        if let matchedByUniqueID = candidates.first(where: {
            $0.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame
        }) {
            return matchedByUniqueID.isEnabled ? .installed : .disabled
        }

        return .missing
    }

    // MARK: - Chained enable/disable

    /// Returns the set of enabled unique IDs that results from toggling `mod`.
    ///
    /// When `chainingDependencies` is true, enabling a mod also enables everything it
    /// requires, and disabling a mod also disables everything that requires it — both
    /// resolved breadth-first so transitive chains are covered.
    ///
    /// - Parameters:
    ///   - mod: the mod being toggled; may be a group row.
    ///   - enabling: `true` to enable, `false` to disable.
    ///   - currentEnabled: the set being edited, keyed by mod unique ID.
    ///   - mods: the full top-level mod list to resolve against.
    ///   - chainingDependencies: whether to follow the dependency chain.
    /// - Returns: a new set; `currentEnabled` is not modified.
    static func enabledIDs(
        after mod: ModItem,
        enabling: Bool,
        from currentEnabled: Set<ModItem.UniqueID>,
        in mods: [ModItem],
        chainingDependencies: Bool
    ) -> Set<ModItem.UniqueID> {
        var result = currentEnabled

        func topLevelMod(providing uniqueId: ModItem.UniqueID) -> ModItem? {
            for candidate in mods {
                switch candidate.kind {
                case .single:
                    if candidate.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame {
                        return candidate
                    }
                case .group(let children):
                    if children.contains(where: { $0.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame }) {
                        return candidate
                    }
                }
            }
            return nil
        }

        func dependencies(of topMod: ModItem) -> [ModDependency] {
            if case .group(let children) = topMod.kind {
                return children.flatMap { $0.dependencies }
            }
            return topMod.dependencies
        }

        /// Every unique ID a top-level entry provides — for a group, that's all its children.
        func providedIDs(of topMod: ModItem) -> [ModItem.UniqueID] {
            if case .group(let children) = topMod.kind {
                return children.map { $0.uniqueId }
            }
            return [topMod.uniqueId]
        }

        let startingMod = mod.isGroup ? mod : (topLevelMod(providing: mod.uniqueId) ?? mod)
        let startingIDs = providedIDs(of: startingMod)

        if enabling {
            startingIDs.forEach { result.insert($0) }

            guard chainingDependencies else { return result }

            // Walk down: enable everything the starting mod requires.
            var queue = [startingMod]
            var visited = Set<ModItem.FolderName>([startingMod.folderName])
            while !queue.isEmpty {
                let current = queue.removeFirst()
                for dependency in dependencies(of: current) where dependency.isRequired {
                    guard let dependencyMod = topLevelMod(providing: dependency.uniqueId),
                          !visited.contains(dependencyMod.folderName) else { continue }
                    visited.insert(dependencyMod.folderName)
                    providedIDs(of: dependencyMod).forEach { result.insert($0) }
                    queue.append(dependencyMod)
                }
            }
        } else {
            startingIDs.forEach { result.remove($0) }

            guard chainingDependencies else { return result }

            // Walk up: disable everything that requires the starting mod.
            var queue = [startingMod]
            var visited = Set<ModItem.FolderName>([startingMod.folderName])
            while !queue.isEmpty {
                let current = queue.removeFirst()
                let currentIDs = providedIDs(of: current)
                for candidate in mods {
                    guard !visited.contains(candidate.folderName) else { continue }
                    let requiresCurrent = dependencies(of: candidate).contains { dependency in
                        dependency.isRequired && currentIDs.contains {
                            $0.rawValue.caseInsensitiveCompare(dependency.uniqueId.rawValue) == .orderedSame
                        }
                    }
                    guard requiresCurrent else { continue }
                    visited.insert(candidate.folderName)
                    providedIDs(of: candidate).forEach { result.remove($0) }
                    queue.append(candidate)
                }
            }
        }

        return result
    }
}
