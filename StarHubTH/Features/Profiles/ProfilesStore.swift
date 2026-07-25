import Foundation

/// Phase 4.4. Owns mod profiles: persistence, activation, and the in-memory chain-toggle
/// preview used while editing a profile.
///
/// `mods` and `gameDir` aren't owned here — they belong to ModsStore (4.7) and
/// AppEnvironment (4.8), neither extracted yet — so methods that need them take the
/// current value as a parameter, same approach as ThaiHubStore (4.3). Two methods
/// (`applyProfile`, `updateProfile`) need `mods` to be re-read *after* triggering a
/// filesystem scan, so those take a `modsProvider` closure instead of a snapshot value.
@MainActor
final class ProfilesStore: ObservableObject {
    @Published var modProfiles: [ModProfile] = []
    @Published var activeProfileId: UUID?

    private let profileStoring: ProfileStoring
    private let localization: LocalizationStore

    init(profileStoring: ProfileStoring, localization: LocalizationStore) {
        self.profileStoring = profileStoring
        self.localization = localization
    }

    func loadProfiles() {
        let loaded = profileStoring.loadProfiles()
        self.modProfiles = loaded.profiles
        self.activeProfileId = loaded.activeId
    }

    func saveProfiles() {
        profileStoring.saveProfiles(modProfiles, activeProfileId: activeProfileId)
    }

    func createProfile(name: String, mods: [Mod]) {
        // Snapshot the currently enabled mods into the new profile
        let currentEnabledIds = mods
            .flatMap { mod -> [Mod.UniqueID] in
                if case .group(let children) = mod.kind {
                    return children.filter { $0.isEnabled }.map { $0.uniqueId }
                }
                return mod.isEnabled ? [mod.uniqueId] : []
            }
            .filter { !$0.rawValue.isEmpty }

        let newProfile = ModProfile(name: name, enabledModIds: currentEnabledIds)
        modProfiles.append(newProfile)
        saveProfiles()
        // Do NOT applyProfile here — just save so the user can edit it first
        activeProfileId = newProfile.id
        saveProfiles()
    }

    func deleteProfile(id: UUID) {
        modProfiles.removeAll { $0.id == id }
        if activeProfileId == id {
            activeProfileId = nil
        }
        saveProfiles()
    }

    func updateProfile(
        id: UUID,
        newName: String,
        enabledModIds: [Mod.UniqueID],
        gameDir: String,
        modsProvider: () -> [Mod],
        scanMods: () -> Void,
        showModal: (String) -> Void
    ) {
        if let index = modProfiles.firstIndex(where: { $0.id == id }) {
            modProfiles[index].name = newName
            modProfiles[index].enabledModIds = enabledModIds
            saveProfiles()

            // If this is the active profile, apply the new mod selection to the filesystem
            if activeProfileId == id {
                do {
                    try applyProfileToFilesystem(profile: modProfiles[index], gameDir: gameDir, modsProvider: modsProvider, scanMods: scanMods)
                } catch {
                    showModal(message(for: error))
                }
            }
        }
    }

    func applyProfile(
        id: UUID?,
        gameDir: String,
        modsProvider: () -> [Mod],
        scanMods: () -> Void,
        log: (String) -> Void,
        showModal: (String) -> Void
    ) {
        guard let id = id, let profile = modProfiles.first(where: { $0.id == id }) else {
            activeProfileId = nil
            saveProfiles()
            return
        }

        // If already active, just sync stored list from current filesystem (no file moves)
        if activeProfileId == id {
            syncActiveProfileIds(mods: modsProvider())
            return
        }

        do {
            try applyProfileToFilesystem(profile: profile, gameDir: gameDir, modsProvider: modsProvider, scanMods: scanMods)
            activeProfileId = id
            saveProfiles()
            log(String(format: localization.L(L10n.VM.switchProfile), profile.name))
        } catch {
            showModal(message(for: error))
        }
    }

    private func message(for error: ProfileApplyError) -> String {
        "\(localization.L(L10n.VM.profileApplyError))\n\(error.failedModNames.joined(separator: ", "))"
    }

    /// Actually move mod files to match the given profile's enabledModIds.
    private func applyProfileToFilesystem(
        profile: ModProfile,
        gameDir: String,
        modsProvider: () -> [Mod],
        scanMods: () -> Void
    ) throws(ProfileApplyError) {
        defer {
            scanMods()
            syncActiveProfileIds(mods: modsProvider())
        }
        try profileStoring.applyProfileToFilesystem(profile: profile, mods: modsProvider(), gameDir: gameDir)
    }

    /// Compute which uniqueIds should be added/removed when toggling a mod in a profile,
    /// using the same chain logic as toggleMod. Works on an in-memory set (no file I/O).
    /// - Parameters:
    ///   - mod: The mod being toggled (can be a group or single mod)
    ///   - enable: true = enabling, false = disabling
    ///   - currentEnabled: the current set of enabled uniqueIds in the profile
    /// - Returns: A new set with the chain applied
    func applyChainToSet(mod: Mod, enable: Bool, currentEnabled: Set<Mod.UniqueID>, mods: [Mod], chainToggleDependencies: Bool) -> Set<Mod.UniqueID> {
        ModGraph.enabledIDs(
            after: mod,
            enabling: enable,
            from: currentEnabled,
            in: mods,
            chainingDependencies: chainToggleDependencies
        )
    }

    // MARK: - Local collection import/export

    /// Phase 4.9: routes what `ModProfilesView` used to call directly on
    /// `ProfileManager.shared`/`CollectionInstaller.shared` through this store instead.
    func importProfile(from url: URL) throws -> (ModCollection, ModProfile) {
        try profileStoring.importProfile(from: url)
    }

    func exportProfile(_ profile: ModProfile, mods: [Mod], to url: URL) throws {
        try profileStoring.exportProfile(profile, mods: mods, to: url)
    }

    /// Nexus IDs from `collection` that aren't already installed among `currentMods`.
    /// This local collection format has no `nxm://` key/expires pair to authorize a
    /// direct API download for a non-premium account (see `NXMParser`'s doc comment),
    /// so the caller opens each missing mod's Nexus page for a manual download rather
    /// than downloading automatically.
    func missingNexusIds(in collection: ModCollection, currentMods: [Mod], nexusApiKey: String) -> [String] {
        CollectionInstaller.shared.install(collection: collection, currentMods: currentMods, nexusApiKey: nexusApiKey)
    }

    /// Call this after any toggleMod so the profile stays up to date.
    func syncActiveProfileIds(mods: [Mod]) {
        guard let id = activeProfileId,
              let index = modProfiles.firstIndex(where: { $0.id == id }) else { return }

        let actualEnabledIds = mods
            .flatMap { mod -> [Mod.UniqueID] in
                if case .group(let children) = mod.kind {
                    return children.filter { $0.isEnabled }.map { $0.uniqueId }
                }
                return mod.isEnabled ? [mod.uniqueId] : []
            }
            .filter { !$0.rawValue.isEmpty }

        modProfiles[index].enabledModIds = actualEnabledIds
        saveProfiles()
    }
}
