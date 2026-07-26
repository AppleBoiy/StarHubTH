import XCTest
@testable import StarHubTH

/// Characterization tests for ModListFilter — the search/filter/sort pipeline extracted
/// from ModListView.processedMods in refactor Phase 0.
final class ModListFilterTests: XCTestCase {

    // MARK: - Fixtures

    /// Fixed reference date so the relative date filter is deterministic.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func daysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 24 * 3600)
    }

    private func mod(
        _ name: String,
        uniqueId: String = "",
        author: String = "Author",
        version: String = "1.0.0",
        enabled: Bool = true,
        tag: String = "",
        installed: Date? = nil,
        modified: Date? = nil
    ) -> Mod {
        Mod(
            uniqueId: Mod.UniqueID(rawValue: uniqueId.isEmpty ? "id.\(name.lowercased())" : uniqueId),
            name: name,
            folderName: Mod.FolderName(rawValue: name),
            version: version,
            author: author,
            description: "",
            nexusUrl: "",
            isEnabled: enabled,
            dependencies: [],
            kind: .single,
            tag: tag,
            installDate: installed,
            lastModifiedDate: modified
        )
    }

    private func group(_ name: String, children: [Mod]) -> Mod {
        Mod(
            uniqueId: "",
            name: name,
            folderName: Mod.FolderName(rawValue: name),
            version: "",
            author: "Author",
            description: "\(children.count)",
            nexusUrl: "",
            isEnabled: true,
            dependencies: [],
            kind: .group(children: children),
            tag: "",
            installDate: nil,
            lastModifiedDate: nil
        )
    }

    private func names(_ mods: [Mod]) -> [String] {
        mods.map(\.name)
    }

    func testNoFilterPassesEverything() {
        let mods = [mod("Alpha"), mod("Beta")]
        let result = ModListFilter().apply(to: mods, now: now)
        XCTAssertEqual(result.count, 2, "an empty filter passes every mod through")
    }

    // MARK: - Search

    func testSearch() {
        let mods = [
            mod("Content Patcher", uniqueId: "Pathoschild.ContentPatcher", author: "Pathoschild"),
            mod("Automate", uniqueId: "Pathoschild.Automate", author: "Pathoschild"),
            mod("Lookup Anything", uniqueId: "other.lookup", author: "Someone")
        ]

        var filter = ModListFilter()

        filter.searchText = "automate"
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Automate"], "search matches name")

        filter.searchText = "AUTOMATE"
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Automate"], "search is case-insensitive")

        filter.searchText = "pathoschild"
        XCTAssertEqual(filter.apply(to: mods, now: now).count, 2, "search matches author")

        filter.searchText = "other.lookup"
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Lookup Anything"], "search matches unique ID")

        filter.searchText = "nothingmatchesthis"
        XCTAssertEqual(filter.apply(to: mods, now: now).count, 0, "search with no match returns nothing")
    }

    func testGroupsFloatToTop() {
        let grouped = group("Bundle", children: [mod("Hidden Gem", uniqueId: "deep.gem")])
        let mods = [mod("Alpha"), grouped, mod("Beta")]

        let sorted = ModListFilter().apply(to: mods, now: now)
        XCTAssertEqual(sorted.first?.name, "Bundle", "groups sort above standalone mods")

        var filter = ModListFilter()
        filter.searchText = "hidden gem"
        XCTAssertEqual(
            names(filter.apply(to: mods, now: now)), ["Bundle"],
            "a group matches when one of its children matches the search"
        )
    }

    // MARK: - Filters

    func testStatusFilter() {
        let mods = [mod("On", enabled: true), mod("Off", enabled: false)]
        var filter = ModListFilter()

        filter.status = .enabled
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["On"], "status .enabled keeps only enabled mods")

        filter.status = .disabled
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Off"], "status .disabled keeps only disabled mods")

        filter.status = .all
        XCTAssertEqual(filter.apply(to: mods, now: now).count, 2, "status .all keeps everything")
    }

    func testTagFilter() {
        let mods = [mod("Framework One", tag: "Framework"), mod("Pretty Thing", tag: "Cosmetic")]
        var filter = ModListFilter()

        filter.tag = "Framework"
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Framework One"], "tag filter matches exactly")

        filter.tag = ""
        XCTAssertEqual(filter.apply(to: mods, now: now).count, 2, "an empty tag disables the tag filter")

        let grouped = group("Bundle", children: [mod("Child", tag: "Audio")])
        filter.tag = "Audio"
        XCTAssertEqual(
            names(filter.apply(to: [grouped], now: now)), ["Bundle"],
            "a group matches when a child carries the tag"
        )
    }

    func testDateFilter() {
        let mods = [
            mod("Today", modified: daysAgo(0.5)),
            mod("ThisWeek", modified: daysAgo(3)),
            mod("ThisMonth", modified: daysAgo(20)),
            mod("Ancient", modified: daysAgo(200)),
            mod("Undated")
        ]
        var filter = ModListFilter()

        filter.date = .past24Hours
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Today"], "past24Hours keeps only the last day")

        filter.date = .past7Days
        XCTAssertEqual(filter.apply(to: mods, now: now).count, 2, "past7Days keeps the last week")

        filter.date = .past30Days
        XCTAssertEqual(filter.apply(to: mods, now: now).count, 3, "past30Days keeps the last month")

        filter.date = .all
        XCTAssertEqual(filter.apply(to: mods, now: now).count, 5, "date .all keeps everything including undated mods")

        // A mod with no dates falls back to Date.distantPast, so it is excluded by any window.
        filter.date = .past30Days
        XCTAssertFalse(
            names(filter.apply(to: mods, now: now)).contains("Undated"),
            "a mod with no install or modified date is excluded by a date window"
        )
    }

    // MARK: - Sorting

    func testSorting() {
        let mods = [
            mod("Charlie", author: "Zed", version: "3.0", enabled: false, installed: daysAgo(1), modified: daysAgo(1)),
            mod("alpha", author: "Yan", version: "1.0", enabled: true, installed: daysAgo(10), modified: daysAgo(30)),
            mod("Bravo", author: "Xu", version: "2.0", enabled: true, installed: daysAgo(5), modified: daysAgo(2))
        ]
        var filter = ModListFilter()

        filter.sort = .name
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["alpha", "Bravo", "Charlie"], "sort .name is case-insensitive ascending")

        filter.sort = .nameDesc
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Charlie", "Bravo", "alpha"], "sort .nameDesc is descending")

        filter.sort = .author
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Bravo", "alpha", "Charlie"], "sort .author is ascending by author")

        filter.sort = .version
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["alpha", "Bravo", "Charlie"], "sort .version is ascending by version string")

        filter.sort = .dateAddedDesc
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Charlie", "Bravo", "alpha"], "sort .dateAddedDesc is newest-installed first")

        filter.sort = .dateModifiedDesc
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["Charlie", "Bravo", "alpha"], "sort .dateModifiedDesc is newest-modified first")

        filter.sort = .status
        XCTAssertEqual(names(filter.apply(to: mods, now: now)), ["alpha", "Bravo", "Charlie"], "sort .status puts enabled first, then name")
    }
}
