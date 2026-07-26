import Foundation

/// Custom tags + Nexus tag sync (§ file-size convention split, see ModsStore.swift's
/// header comment).
extension ModsStore {
    var customModTags: [String: String] {
        get { preferenceStoring.dictionary(forKey: "customModTags") ?? [:] }
        set { preferenceStoring.set(newValue, forKey: "customModTags") }
    }

    func setCustomTag(for modId: Mod.UniqueID, tag: String, shouldRefresh: Bool = true, refresh: () -> Void) {
        var tags = customModTags
        tags[modId.rawValue] = tag
        customModTags = tags
        if shouldRefresh { refresh() }
    }

    func resetCustomTag(for modId: Mod.UniqueID, refresh: () -> Void) {
        var tags = customModTags
        tags.removeValue(forKey: modId.rawValue)
        customModTags = tags
        refresh()
    }

    /// No-ops (rather than surfacing an error) when the mod has no valid Nexus URL — that's
    /// an expected, silent case for locally-added mods, not a failure.
    func syncTagFromNexus(for mod: Mod, nexusApiKey: String, shouldRefresh: Bool = true, showModal: @escaping (String) -> Void, refresh: @escaping () -> Void) async {
        guard !nexusApiKey.isEmpty, let url = URL(string: mod.nexusUrl), let modId = Int(url.lastPathComponent) else {
            return
        }

        let info: LiveNexusAPIClient.ModInfo
        do {
            info = try await nexusAPIClient.modInfo(modId: modId, apiKey: nexusApiKey)
        } catch {
            showModal(String(format: localization.L(L10n.VM.syncTagFailed), error.localizedDescription))
            return
        }

        guard let categoryId = info.categoryId else {
            showModal(String(format: localization.L(L10n.VM.syncTagFailed), "No category information available"))
            return
        }

        let newTag = LiveNexusAPIClient.categoryTag(from: categoryId)
        setCustomTag(for: mod.uniqueId, tag: newTag, shouldRefresh: shouldRefresh, refresh: refresh)
    }

    /// Phase 4.9: replaces ModDetailView's direct `LiveNexusAPIClient.shared.modInfo`/
    /// `.modFiles` calls — fetches a mod's Nexus cover image, description, and latest
    /// changelog for display.
    func fetchNexusInfo(
        nexusId: Int,
        apiKey: String
    ) async -> (coverUrl: URL?, description: [LiveNexusAPIClient.DescriptionBlock]?, changelog: [LiveNexusAPIClient.DescriptionBlock]?) {
        async let infoResult = try? nexusAPIClient.modInfo(modId: nexusId, apiKey: apiKey)
        async let filesResult = try? nexusAPIClient.modFiles(modId: nexusId, apiKey: apiKey)

        var coverUrl: URL?
        var description: [LiveNexusAPIClient.DescriptionBlock]?
        if let info = await infoResult {
            if let pic = info.pictureUrl { coverUrl = URL(string: pic) }
            description = LiveNexusAPIClient.parseBlocks(info.description)
        }

        var changelog: [LiveNexusAPIClient.DescriptionBlock]?
        if let files = await filesResult,
           let latestChangelog = files.files.first(where: { !($0.changelogHtml?.isEmpty ?? true) })?.changelogHtml {
            changelog = LiveNexusAPIClient.parseBlocks(latestChangelog)
        }

        return (coverUrl, description, changelog)
    }

    /// Phase 4.9: replaces ModListView's direct `LiveNexusAPIClient.shared.endorseMod` call.
    func endorseMod(nexusId: Int, version: String?, apiKey: String) async throws {
        try await nexusAPIClient.endorseMod(modId: nexusId, version: version, apiKey: apiKey)
    }

    /// Sequential, not concurrent — mirrors `ModPacksStore.downloadAllMissing`'s throttling:
    /// firing every mod's Nexus lookup in parallel risks the same rate-limiting bulk installs
    /// already hit.
    func syncAllTagsFromNexus(nexusApiKey: String, showModal: @escaping (String) -> Void, refresh: @escaping () -> Void) async {
        guard !nexusApiKey.isEmpty else { return }

        isSyncingAllTags = true
        syncAllTagsProgress = 0.0

        let modsToSync = mods.filter { !$0.nexusUrl.isEmpty && Int((URL(string: $0.nexusUrl)?.lastPathComponent) ?? "") != nil }

        guard !modsToSync.isEmpty else {
            isSyncingAllTags = false
            return
        }

        for (index, mod) in modsToSync.enumerated() {
            await syncTagFromNexus(for: mod, nexusApiKey: nexusApiKey, shouldRefresh: false, showModal: showModal, refresh: refresh)
            syncAllTagsProgress = Double(index + 1) / Double(modsToSync.count)
        }

        isSyncingAllTags = false
        refresh()
    }
}
