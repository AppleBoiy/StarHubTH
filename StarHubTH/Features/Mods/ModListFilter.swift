import Foundation

/// The search / filter / sort pipeline for the mod list, as a pure value.
///
/// Extracted from `ModListView.processedMods` in refactor Phase 0. Keeping it out of the
/// view makes the pipeline testable and lets the view body shrink to layout only.
///
/// - Note: Behaviour is identical to the original inline pipeline, with one deliberate
///   addition: `apply(to:now:)` takes the reference date as a parameter rather than
///   calling `Date()` inline, so the relative date filter is testable. The default
///   argument preserves the original behaviour at every call site.
struct ModListFilter: Equatable {
    var searchText: String = ""
    var status: ModFilterStatus = .all
    var tag: String = ""
    var date: ModFilterDate = .all
    var sort: ModSortOption = .name

    /// Applies search, all three filters, then the sort — in that order.
    func apply(to mods: [ModItem], now: Date = Date()) -> [ModItem] {
        mods
            .filter { matchesSearch($0) }
            .filter { matchesStatus($0) }
            .filter { matchesTag($0) }
            .filter { matchesDate($0, now: now) }
            .sorted(by: isOrderedBefore)
    }

    // MARK: - Search

    /// Matches name, unique ID or author. For a group, also matches any child's name or ID.
    private func matchesSearch(_ mod: ModItem) -> Bool {
        let query = searchText.lowercased()
        guard !query.isEmpty else { return true }

        if mod.name.lowercased().contains(query) { return true }
        if mod.uniqueId.lowercased().contains(query) { return true }
        if mod.author.lowercased().contains(query) { return true }

        if case .group(let children) = mod.kind {
            return children.contains {
                $0.name.lowercased().contains(query) || $0.uniqueId.lowercased().contains(query)
            }
        }
        return false
    }

    // MARK: - Filters

    private func matchesStatus(_ mod: ModItem) -> Bool {
        switch status {
        case .all:      return true
        case .enabled:  return mod.isEnabled
        case .disabled: return !mod.isEnabled
        }
    }

    /// A group matches if any of its children carries the tag.
    private func matchesTag(_ mod: ModItem) -> Bool {
        guard !tag.isEmpty else { return true }
        if case .group(let children) = mod.kind {
            return children.contains { $0.modTag == tag }
        }
        return mod.modTag == tag
    }

    private func matchesDate(_ mod: ModItem, now: Date) -> Bool {
        guard date != .all else { return true }

        let reference = mod.lastModifiedDate ?? mod.installDate ?? Date.distantPast
        let age = now.timeIntervalSince(reference)

        switch date {
        case .all:         return true
        case .past24Hours: return age <= 24 * 3600
        case .past7Days:   return age <= 7 * 24 * 3600
        case .past30Days:  return age <= 30 * 24 * 3600
        }
    }

    // MARK: - Sort

    /// Groups always float above standalone mods, whatever the sort option.
    private func isOrderedBefore(_ first: ModItem, _ second: ModItem) -> Bool {
        if first.isGroup != second.isGroup { return first.isGroup }

        switch sort {
        case .name:
            return first.name.lowercased() < second.name.lowercased()
        case .nameDesc:
            return first.name.lowercased() > second.name.lowercased()
        case .author:
            return first.author.lowercased() < second.author.lowercased()
        case .version:
            return first.version.lowercased() < second.version.lowercased()
        case .dateAddedDesc:
            return (first.installDate ?? .distantPast) > (second.installDate ?? .distantPast)
        case .dateModifiedDesc:
            return (first.lastModifiedDate ?? .distantPast) > (second.lastModifiedDate ?? .distantPast)
        case .status:
            if first.isEnabled != second.isEnabled { return first.isEnabled }
            return first.name.lowercased() < second.name.lowercased()
        }
    }
}
