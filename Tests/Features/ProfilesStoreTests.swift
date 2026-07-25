import Foundation

/// Characterization tests for ProfilesStore, extracted from StarHubTHViewModel in
/// refactor Phase 4.4. Uses StubProfileStoring (Phase 3.2) instead of real UserDefaults
/// and filesystem access.
@MainActor
struct ProfilesStoreTests {
    static func run() {
        print("Running ProfilesStoreTests...")
        testLoadProfiles()
        testCreateProfileSnapshotsEnabledMods()
        testDeleteProfileClearsActiveId()
        testSyncActiveProfileIdsUpdatesEnabledMods()
        testApplyChainToSetDelegatesToModGraph()
    }

    private static func mod(_ uniqueId: String, enabled: Bool) -> Mod {
        Mod(
            uniqueId: Mod.UniqueID(rawValue: uniqueId),
            name: uniqueId,
            folderName: Mod.FolderName(rawValue: uniqueId),
            version: "1.0.0",
            author: "Author",
            description: "",
            nexusUrl: "",
            isEnabled: enabled,
            dependencies: [],
            kind: .single
        )
    }

    private static func makeStore(profiles: [ModProfile] = [], activeId: UUID? = nil) -> (ProfilesStore, StubProfileStoring) {
        let stub = StubProfileStoring()
        stub.profiles = profiles
        stub.activeId = activeId
        let store = ProfilesStore(profileStoring: stub, localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()))
        return (store, stub)
    }

    private static func testLoadProfiles() {
        let profile = ModProfile(name: "Test", enabledModIds: [])
        let (store, _) = makeStore(profiles: [profile], activeId: profile.id)
        store.loadProfiles()
        SimpleTestFramework.assertEqual(store.modProfiles.count, 1, "loadProfiles reads profiles from the backing store")
        SimpleTestFramework.assertEqual(store.activeProfileId, profile.id, "loadProfiles reads the active profile id")
    }

    private static func testCreateProfileSnapshotsEnabledMods() {
        let (store, stub) = makeStore()
        let mods = [mod("a.mod", enabled: true), mod("b.mod", enabled: false)]
        store.createProfile(name: "My Profile", mods: mods)

        SimpleTestFramework.assertEqual(store.modProfiles.count, 1, "createProfile appends a new profile")
        SimpleTestFramework.assertEqual(store.modProfiles.first?.enabledModIds, [Mod.UniqueID(rawValue: "a.mod")], "only currently-enabled mods are snapshotted")
        SimpleTestFramework.assertEqual(store.activeProfileId, store.modProfiles.first?.id, "the new profile becomes active")
        SimpleTestFramework.assertTrue(stub.savedProfiles != nil, "createProfile persists via the injected ProfileStoring")
    }

    private static func testDeleteProfileClearsActiveId() {
        let profile = ModProfile(name: "Test", enabledModIds: [])
        let (store, _) = makeStore(profiles: [profile], activeId: profile.id)
        store.loadProfiles()

        store.deleteProfile(id: profile.id)
        SimpleTestFramework.assertTrue(store.modProfiles.isEmpty, "deleteProfile removes the profile")
        SimpleTestFramework.assertTrue(store.activeProfileId == nil, "deleting the active profile clears activeProfileId")
    }

    private static func testSyncActiveProfileIdsUpdatesEnabledMods() {
        let profile = ModProfile(name: "Test", enabledModIds: [])
        let (store, _) = makeStore(profiles: [profile], activeId: profile.id)
        store.loadProfiles()

        let mods = [mod("a.mod", enabled: true), mod("b.mod", enabled: false)]
        store.syncActiveProfileIds(mods: mods)

        SimpleTestFramework.assertEqual(store.modProfiles.first?.enabledModIds, [Mod.UniqueID(rawValue: "a.mod")], "syncActiveProfileIds reflects actual filesystem-derived enabled state")
    }

    private static func testApplyChainToSetDelegatesToModGraph() {
        let (store, _) = makeStore()
        let target = mod("a.mod", enabled: false)
        let result = store.applyChainToSet(mod: target, enable: true, currentEnabled: [], mods: [target], chainToggleDependencies: true)
        SimpleTestFramework.assertTrue(result.contains(Mod.UniqueID(rawValue: "a.mod")), "applyChainToSet enables the toggled mod")
    }
}
