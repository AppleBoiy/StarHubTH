import XCTest
@testable import StarHubTH

/// Characterization tests for ModGraph — the dependency/pack/chain logic extracted from
/// StarHubTHViewModel in refactor Phase 0. These pin current behaviour so later phases
/// can move the code with confidence.
final class ModGraphTests: XCTestCase {

    // MARK: - Fixtures

    private func mod(
        _ uniqueId: String,
        name: String? = nil,
        folder: String? = nil,
        enabled: Bool = true,
        nexusUrl: String = "",
        dependencies: [ModDependency] = []
    ) -> Mod {
        Mod(
            uniqueId: Mod.UniqueID(rawValue: uniqueId),
            name: name ?? uniqueId,
            folderName: Mod.FolderName(rawValue: folder ?? uniqueId),
            version: "1.0.0",
            author: "Author",
            description: "",
            nexusUrl: nexusUrl,
            isEnabled: enabled,
            dependencies: dependencies,
            kind: .single,
            tag: "",
            installDate: nil,
            lastModifiedDate: nil
        )
    }

    private func group(_ folder: String, children: [Mod], enabled: Bool = true) -> Mod {
        Mod(
            uniqueId: "",
            name: folder,
            folderName: Mod.FolderName(rawValue: folder),
            version: "",
            author: "Author",
            description: "\(children.count)",
            nexusUrl: "",
            isEnabled: enabled,
            dependencies: [],
            kind: .group(children: children),
            tag: "",
            installDate: nil,
            lastModifiedDate: nil
        )
    }

    private func required(_ uniqueId: String) -> ModDependency {
        ModDependency(uniqueId: Mod.UniqueID(rawValue: uniqueId), isRequired: true)
    }

    private func optional(_ uniqueId: String) -> ModDependency {
        ModDependency(uniqueId: Mod.UniqueID(rawValue: uniqueId), isRequired: false)
    }

    // MARK: - flattened

    func testFlattened() {
        let child1 = mod("a.one")
        let child2 = mod("a.two")
        let mods = [group("Bundle", children: [child1, child2]), mod("b.solo")]

        let flat = ModGraph.flattened(mods)
        XCTAssertEqual(flat.count, 3, "flattened expands groups into children")
        XCTAssertTrue(
            flat.contains { $0.uniqueId == "a.one" } && flat.contains { $0.uniqueId == "b.solo" },
            "flattened keeps both group children and standalone mods"
        )
        XCTAssertFalse(
            flat.contains { $0.isGroup },
            "flattened drops the group row itself"
        )
    }

    // MARK: - dependencyStatus

    func testDependencyStatus() {
        let mods = [
            mod("Pathoschild.ContentPatcher", enabled: true),
            mod("spacechase0.SpaceCore", enabled: false),
            group("Bundle", children: [mod("nested.mod", enabled: true)])
        ]

        XCTAssertEqual(
            ModGraph.dependencyStatus(for: "Pathoschild.ContentPatcher", in: mods), .active,
            "installed + enabled dependency resolves .active"
        )
        XCTAssertEqual(
            ModGraph.dependencyStatus(for: "nope.missing", in: mods), .missing,
            "absent dependency resolves .missing"
        )
        XCTAssertEqual(
            ModGraph.dependencyStatus(for: "PATHOSCHILD.CONTENTPATCHER", in: mods), .active,
            "dependency matching is case-insensitive"
        )
        XCTAssertEqual(
            ModGraph.dependencyStatus(for: "nested.mod", in: mods), .active,
            "dependency inside a group is found"
        )

        if case .disabled(let found) = ModGraph.dependencyStatus(for: "spacechase0.SpaceCore", in: mods) {
            XCTAssertEqual(
                found.uniqueId, "spacechase0.SpaceCore",
                "disabled dependency carries the mod it found"
            )
        } else {
            XCTAssertTrue(false, "installed + disabled dependency resolves .disabled")
        }

        // Regression (Phase 2.4): a group's synthetic uniqueId is "". Before Mod.Kind, a
        // group with nil children fell into a code path that could contribute that empty
        // ID to the installed set, so a manifest declaring an empty dependency ID wrongly
        // resolved to .active. Mod.Kind makes that state unrepresentable — a group is never
        // itself a candidate, only its real children are.
        XCTAssertEqual(
            ModGraph.dependencyStatus(for: "", in: mods), .missing,
            "an empty-string dependency ID resolves .missing, not .active, even with a group present"
        )
    }

    // MARK: - missingDependencies

    func testMissingDependencies() {
        let installed = [
            mod("Pathoschild.ContentPatcher"),
            group("Bundle", children: [mod("nested.mod")])
        ]

        let subject = mod("my.mod", dependencies: [
            required("Pathoschild.ContentPatcher"),
            required("absent.framework"),
            optional("also.absent"),
            required("NESTED.MOD")
        ])

        let missing = ModGraph.missingDependencies(for: subject, in: installed)
        XCTAssertEqual(missing, ["absent.framework"], "only absent REQUIRED dependencies are reported")

        XCTAssertEqual(
            ModGraph.missingDependencies(for: mod("no.deps"), in: installed), [],
            "a mod with no dependencies reports nothing missing"
        )
    }

    // MARK: - packModStatus

    func testPackModStatus() {
        let mods = [
            mod("a.mod", nexusUrl: "https://www.nexusmods.com/stardewvalley/mods/1234"),
            mod("b.mod", enabled: false, nexusUrl: "https://www.nexusmods.com/stardewvalley/mods/5678"),
            mod("c.mod", nexusUrl: "")
        ]

        XCTAssertEqual(
            ModGraph.packModStatus(nexusID: 1234, uniqueId: "irrelevant", in: mods), .installed,
            "pack mod matched by Nexus ID and enabled is .installed"
        )
        XCTAssertEqual(
            ModGraph.packModStatus(nexusID: 5678, uniqueId: "irrelevant", in: mods), .disabled,
            "pack mod matched by Nexus ID but disabled is .disabled"
        )
        XCTAssertEqual(
            ModGraph.packModStatus(nexusID: 9999, uniqueId: "c.mod", in: mods), .installed,
            "unmatched Nexus ID falls back to the SMAPI unique ID"
        )
        XCTAssertEqual(
            ModGraph.packModStatus(nexusID: nil, uniqueId: "a.mod", in: mods), .installed,
            "a nil Nexus ID matches on unique ID alone"
        )
        XCTAssertEqual(
            ModGraph.packModStatus(nexusID: 9999, uniqueId: "not.installed", in: mods), .missing,
            "no match on either key is .missing"
        )
    }

    // MARK: - enable chain

    func testEnableChain() {
        // my.mod → needs core → needs base
        let mods = [
            mod("my.mod", dependencies: [required("core.framework")]),
            mod("core.framework", dependencies: [required("base.lib")]),
            mod("base.lib"),
            mod("unrelated.mod")
        ]

        let result = ModGraph.enabledIDs(
            after: mods[0], enabling: true, from: [], in: mods, chainingDependencies: true
        )

        XCTAssertTrue(result.contains("my.mod"), "enabling a mod enables it")
        XCTAssertTrue(result.contains("core.framework"), "enabling pulls in its direct dependency")
        XCTAssertTrue(result.contains("base.lib"), "enabling pulls in transitive dependencies")
        XCTAssertFalse(result.contains("unrelated.mod"), "enabling leaves unrelated mods alone")
    }

    // MARK: - disable chain

    func testDisableChain() {
        // dependent.mod → needs core.framework
        let mods = [
            mod("core.framework"),
            mod("dependent.mod", dependencies: [required("core.framework")]),
            mod("optional.dependent", dependencies: [optional("core.framework")]),
            mod("unrelated.mod")
        ]
        let current: Set<Mod.UniqueID> = ["core.framework", "dependent.mod", "optional.dependent", "unrelated.mod"]

        let result = ModGraph.enabledIDs(
            after: mods[0], enabling: false, from: current, in: mods, chainingDependencies: true
        )

        XCTAssertFalse(result.contains("core.framework"), "disabling a mod disables it")
        XCTAssertFalse(result.contains("dependent.mod"), "disabling cascades to mods that REQUIRE it")
        XCTAssertTrue(result.contains("optional.dependent"), "an OPTIONAL dependent is left enabled")
        XCTAssertTrue(result.contains("unrelated.mod"), "disabling leaves unrelated mods alone")
    }

    // MARK: - chain resolution through a group
    //
    // The tests above (testEnableChain/testDisableChain) only ever toggle standalone mods.
    // enabledIDs' group-handling branches (topLevelMod's `.group` case, dependencies(of:)/
    // providedIDs(of:) flattening a group's children) were previously exercised by nothing —
    // Phase 0.3's own tracked gap ("profile chain resolution... uncovered"), closed here.

    func testEnableChainThroughGroup() {
        // Toggling the group enables every child; one child's dependency chain still pulls
        // in an unrelated top-level mod.
        let mods = [
            group("Bundle", children: [
                mod("a.mod", dependencies: [required("core.framework")]),
                mod("b.mod")
            ], enabled: false),
            mod("core.framework", enabled: false)
        ]

        let result = ModGraph.enabledIDs(
            after: mods[0], enabling: true, from: [], in: mods, chainingDependencies: true
        )

        XCTAssertTrue(result.contains("a.mod"), "enabling a group enables its first child")
        XCTAssertTrue(result.contains("b.mod"), "enabling a group enables its second child")
        XCTAssertTrue(result.contains("core.framework"), "a group child's dependency is still chained in")
    }

    func testDisableChainCascadesIntoGroup() {
        // Disabling a mod that a group's child depends on must disable the WHOLE group
        // (every child), not just the one child that declared the dependency.
        let mods = [
            mod("core.framework"),
            group("Bundle", children: [
                mod("a.mod", dependencies: [required("core.framework")]),
                mod("b.mod")
            ])
        ]
        let current: Set<Mod.UniqueID> = ["core.framework", "a.mod", "b.mod"]

        let result = ModGraph.enabledIDs(
            after: mods[0], enabling: false, from: current, in: mods, chainingDependencies: true
        )

        XCTAssertFalse(result.contains("core.framework"), "disabling the required mod disables it")
        XCTAssertFalse(result.contains("a.mod"), "the group child that declared the dependency is disabled")
        XCTAssertFalse(result.contains("b.mod"), "the group's OTHER child is disabled too — a group toggles as one unit")
    }

    // MARK: - chaining off

    func testChainingDisabled() {
        let mods = [
            mod("my.mod", dependencies: [required("core.framework")]),
            mod("core.framework")
        ]

        let enabled = ModGraph.enabledIDs(
            after: mods[0], enabling: true, from: [], in: mods, chainingDependencies: false
        )
        XCTAssertEqual(enabled, ["my.mod"], "chaining off enables only the mod itself")

        let disabled = ModGraph.enabledIDs(
            after: mods[1], enabling: false,
            from: ["my.mod", "core.framework"], in: mods, chainingDependencies: false
        )
        XCTAssertEqual(disabled, ["my.mod"], "chaining off disables only the mod itself")
    }
}
