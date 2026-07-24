import Foundation

/// Characterization tests for ModGraph — the dependency/pack/chain logic extracted from
/// StarHubTHViewModel in refactor Phase 0. These pin current behaviour so later phases
/// can move the code with confidence.
struct ModGraphTests {

    // MARK: - Fixtures

    private static func mod(
        _ uniqueId: String,
        name: String? = nil,
        folder: String? = nil,
        enabled: Bool = true,
        nexusUrl: String = "",
        dependencies: [ModDependency] = []
    ) -> ModItem {
        ModItem(
            uniqueId: uniqueId,
            name: name ?? uniqueId,
            folderName: folder ?? uniqueId,
            version: "1.0.0",
            author: "Author",
            description: "",
            nexusUrl: nexusUrl,
            isEnabled: enabled,
            dependencies: dependencies,
            kind: .single,
            modTag: "",
            installDate: nil,
            lastModifiedDate: nil
        )
    }

    private static func group(_ folder: String, children: [ModItem], enabled: Bool = true) -> ModItem {
        ModItem(
            uniqueId: "",
            name: folder,
            folderName: folder,
            version: "",
            author: "Author",
            description: "\(children.count)",
            nexusUrl: "",
            isEnabled: enabled,
            dependencies: [],
            kind: .group(children: children),
            modTag: "",
            installDate: nil,
            lastModifiedDate: nil
        )
    }

    private static func required(_ uniqueId: String) -> ModDependency {
        ModDependency(uniqueId: uniqueId, isRequired: true)
    }

    private static func optional(_ uniqueId: String) -> ModDependency {
        ModDependency(uniqueId: uniqueId, isRequired: false)
    }

    // MARK: -

    static func run() {
        print("Running ModGraphTests...")
        testFlattened()
        testDependencyStatus()
        testMissingDependencies()
        testPackModStatus()
        testEnableChain()
        testDisableChain()
        testChainingDisabled()
    }

    // MARK: - flattened

    private static func testFlattened() {
        let child1 = mod("a.one")
        let child2 = mod("a.two")
        let mods = [group("Bundle", children: [child1, child2]), mod("b.solo")]

        let flat = ModGraph.flattened(mods)
        SimpleTestFramework.assertEqual(flat.count, 3, "flattened expands groups into children")
        SimpleTestFramework.assertTrue(
            flat.contains { $0.uniqueId == "a.one" } && flat.contains { $0.uniqueId == "b.solo" },
            "flattened keeps both group children and standalone mods"
        )
        SimpleTestFramework.assertFalse(
            flat.contains { $0.isGroup },
            "flattened drops the group row itself"
        )
    }

    // MARK: - dependencyStatus

    private static func testDependencyStatus() {
        let mods = [
            mod("Pathoschild.ContentPatcher", enabled: true),
            mod("spacechase0.SpaceCore", enabled: false),
            group("Bundle", children: [mod("nested.mod", enabled: true)])
        ]

        SimpleTestFramework.assertEqual(
            ModGraph.dependencyStatus(for: "Pathoschild.ContentPatcher", in: mods), .active,
            "installed + enabled dependency resolves .active"
        )
        SimpleTestFramework.assertEqual(
            ModGraph.dependencyStatus(for: "nope.missing", in: mods), .missing,
            "absent dependency resolves .missing"
        )
        SimpleTestFramework.assertEqual(
            ModGraph.dependencyStatus(for: "PATHOSCHILD.CONTENTPATCHER", in: mods), .active,
            "dependency matching is case-insensitive"
        )
        SimpleTestFramework.assertEqual(
            ModGraph.dependencyStatus(for: "nested.mod", in: mods), .active,
            "dependency inside a group is found"
        )

        if case .disabled(let found) = ModGraph.dependencyStatus(for: "spacechase0.SpaceCore", in: mods) {
            SimpleTestFramework.assertEqual(
                found.uniqueId, "spacechase0.SpaceCore",
                "disabled dependency carries the mod it found"
            )
        } else {
            SimpleTestFramework.assertTrue(false, "installed + disabled dependency resolves .disabled")
        }

        // Regression (Phase 2.4): a group's synthetic uniqueId is "". Before Mod.Kind, a
        // group with nil children fell into a code path that could contribute that empty
        // ID to the installed set, so a manifest declaring an empty dependency ID wrongly
        // resolved to .active. Mod.Kind makes that state unrepresentable — a group is never
        // itself a candidate, only its real children are.
        SimpleTestFramework.assertEqual(
            ModGraph.dependencyStatus(for: "", in: mods), .missing,
            "an empty-string dependency ID resolves .missing, not .active, even with a group present"
        )
    }

    // MARK: - missingDependencies

    private static func testMissingDependencies() {
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
        SimpleTestFramework.assertEqual(missing, ["absent.framework"], "only absent REQUIRED dependencies are reported")

        SimpleTestFramework.assertEqual(
            ModGraph.missingDependencies(for: mod("no.deps"), in: installed), [],
            "a mod with no dependencies reports nothing missing"
        )
    }

    // MARK: - packModStatus

    private static func testPackModStatus() {
        let mods = [
            mod("a.mod", nexusUrl: "https://www.nexusmods.com/stardewvalley/mods/1234"),
            mod("b.mod", enabled: false, nexusUrl: "https://www.nexusmods.com/stardewvalley/mods/5678"),
            mod("c.mod", nexusUrl: "")
        ]

        SimpleTestFramework.assertEqual(
            ModGraph.packModStatus(nexusID: 1234, uniqueId: "irrelevant", in: mods), .installed,
            "pack mod matched by Nexus ID and enabled is .installed"
        )
        SimpleTestFramework.assertEqual(
            ModGraph.packModStatus(nexusID: 5678, uniqueId: "irrelevant", in: mods), .disabled,
            "pack mod matched by Nexus ID but disabled is .disabled"
        )
        SimpleTestFramework.assertEqual(
            ModGraph.packModStatus(nexusID: 9999, uniqueId: "c.mod", in: mods), .installed,
            "unmatched Nexus ID falls back to the SMAPI unique ID"
        )
        SimpleTestFramework.assertEqual(
            ModGraph.packModStatus(nexusID: nil, uniqueId: "a.mod", in: mods), .installed,
            "a nil Nexus ID matches on unique ID alone"
        )
        SimpleTestFramework.assertEqual(
            ModGraph.packModStatus(nexusID: 9999, uniqueId: "not.installed", in: mods), .missing,
            "no match on either key is .missing"
        )
    }

    // MARK: - enable chain

    private static func testEnableChain() {
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

        SimpleTestFramework.assertTrue(result.contains("my.mod"), "enabling a mod enables it")
        SimpleTestFramework.assertTrue(result.contains("core.framework"), "enabling pulls in its direct dependency")
        SimpleTestFramework.assertTrue(result.contains("base.lib"), "enabling pulls in transitive dependencies")
        SimpleTestFramework.assertFalse(result.contains("unrelated.mod"), "enabling leaves unrelated mods alone")
    }

    // MARK: - disable chain

    private static func testDisableChain() {
        // dependent.mod → needs core.framework
        let mods = [
            mod("core.framework"),
            mod("dependent.mod", dependencies: [required("core.framework")]),
            mod("optional.dependent", dependencies: [optional("core.framework")]),
            mod("unrelated.mod")
        ]
        let current: Set<String> = ["core.framework", "dependent.mod", "optional.dependent", "unrelated.mod"]

        let result = ModGraph.enabledIDs(
            after: mods[0], enabling: false, from: current, in: mods, chainingDependencies: true
        )

        SimpleTestFramework.assertFalse(result.contains("core.framework"), "disabling a mod disables it")
        SimpleTestFramework.assertFalse(result.contains("dependent.mod"), "disabling cascades to mods that REQUIRE it")
        SimpleTestFramework.assertTrue(result.contains("optional.dependent"), "an OPTIONAL dependent is left enabled")
        SimpleTestFramework.assertTrue(result.contains("unrelated.mod"), "disabling leaves unrelated mods alone")
    }

    // MARK: - chaining off

    private static func testChainingDisabled() {
        let mods = [
            mod("my.mod", dependencies: [required("core.framework")]),
            mod("core.framework")
        ]

        let enabled = ModGraph.enabledIDs(
            after: mods[0], enabling: true, from: [], in: mods, chainingDependencies: false
        )
        SimpleTestFramework.assertEqual(enabled, ["my.mod"], "chaining off enables only the mod itself")

        let disabled = ModGraph.enabledIDs(
            after: mods[1], enabling: false,
            from: ["my.mod", "core.framework"], in: mods, chainingDependencies: false
        )
        SimpleTestFramework.assertEqual(disabled, ["my.mod"], "chaining off disables only the mod itself")
    }
}
