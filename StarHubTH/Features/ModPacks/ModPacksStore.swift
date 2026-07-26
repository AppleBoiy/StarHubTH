import Foundation
import UniformTypeIdentifiers

/// Phase 4.5. Owns mod-pack export/import/collection-fetch and the Nexus download flow
/// used to fill in a pack's missing mods.
///
/// `mods`, `steamUsername`, `nexusApiKey`, `showModal`, and `installModFromZip` aren't
/// owned here — they belong to ModsStore (4.7) and AppEnvironment (4.8), neither
/// extracted yet — so the affected methods take them as parameters/closures, same
/// approach as ThaiHubStore (4.3) and ProfilesStore (4.4).
///
/// `importedModPack` only ever mutates through the exposed setter (never from inside this
/// store's own methods — they hand results back via a completion closure instead), so
/// unlike LogStore/ThaiHubStore/ProfilesStore this store doesn't need the
/// objectWillChange-forwarding Combine subscription; a manual send() in the ViewModel's
/// forwarding setter is enough.
@MainActor
final class ModPacksStore: ObservableObject {
    @Published var importedModPack: StarHubPack?

    private let nexusAPIClient: NexusAPIClient
    private let localization: LocalizationStore
    private let logStore: LogStore
    private let filePicking: FilePicking

    init(nexusAPIClient: NexusAPIClient, localization: LocalizationStore, logStore: LogStore, filePicking: FilePicking) {
        self.nexusAPIClient = nexusAPIClient
        self.localization = localization
        self.logStore = logStore
        self.filePicking = filePicking
    }

    func exportModPack(name: String, mods: [Mod], steamUsername: String, showModal: (String) -> Void) -> URL? {
        let packMods = mods.flatMap { mod -> [StarHubPackMod] in
            if case .group(let children) = mod.kind {
                return children.filter { $0.isEnabled }.map {
                    let nexusId = Int($0.nexusUrl.components(separatedBy: "/").last ?? "").map { Mod.NexusID(rawValue: $0) }
                    return StarHubPackMod(name: $0.name, uniqueId: $0.uniqueId, version: $0.version, nexusId: nexusId)
                }
            }
            if mod.isEnabled {
                let nexusId = Int(mod.nexusUrl.components(separatedBy: "/").last ?? "").map { Mod.NexusID(rawValue: $0) }
                return [StarHubPackMod(name: mod.name, uniqueId: mod.uniqueId, version: mod.version, nexusId: nexusId)]
            }
            return []
        }

        let pack = StarHubPack(packName: name, author: steamUsername.isEmpty ? "Player" : steamUsername, description: nil, mods: packMods)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(pack) else { return nil }

        guard let url = filePicking.pickSaveLocation(
            title: nil,
            suggestedName: "\(name.replacingOccurrences(of: " ", with: "_")).starhubpack",
            allowedContentTypes: [.json]
        ) else { return nil }

        do {
            try data.write(to: url)
            return url
        } catch {
            showModal(localization.L(L10n.VM.packSaveFailed))
        }
        return nil
    }

    func importModPack(from url: URL) -> StarHubPack? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(StarHubPack.self, from: data)
        } catch {
            logStore.log("Failed to decode Mod Pack: \(error.localizedDescription)")
            return nil
        }
    }

    func importCollectionFromURL(_ urlString: String, nexusApiKey: String, showModal: @escaping (String) -> Void) async -> StarHubPack? {
        guard let url = URL(string: urlString) else { return nil }

        let path = url.path
        let components = path.components(separatedBy: "/")
        // Extract slug from e.g. /stardewvalley/collections/tckf0m
        var slug = ""
        if let idx = components.firstIndex(of: "collections"), idx + 1 < components.count {
            slug = components[idx + 1]
        }

        guard !slug.isEmpty else { return nil }

        guard !nexusApiKey.isEmpty else {
            showModal(localization.L(L10n.VM.collectionApiKeyRequired))
            return nil
        }

        logStore.log("Fetching collection metadata for slug: \(slug)...")

        let collection: LiveNexusAPIClient.CollectionGraph
        do {
            collection = try await nexusAPIClient.collectionGraph(slug: slug, apiKey: nexusApiKey)
        } catch {
            showModal(localization.L(L10n.VM.collectionFetchFailed))
            return nil
        }

        let packMods = collection.latestPublishedRevision?.modFiles?.compactMap { modFile -> StarHubPackMod? in
            guard let detail = modFile.file, let modDetail = detail.mod else { return nil }
            // Format mod's updatedAt as relative string
            var modUpdated: String? = nil
            if let rawDate = modDetail.updatedAt {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate) {
                    let rel = RelativeDateTimeFormatter()
                    rel.unitsStyle = .abbreviated
                    modUpdated = rel.localizedString(for: date, relativeTo: Date())
                }
            }
            return StarHubPackMod(
                name: modDetail.name,
                uniqueId: Mod.UniqueID(rawValue: "nexus_\(modDetail.modId)"),
                version: detail.version ?? "",
                nexusId: Mod.NexusID(rawValue: modDetail.modId),
                modAuthor: modDetail.author,
                modDownloads: modDetail.downloads,
                modUpdatedAt: modUpdated,
                thumbnailUrl: modDetail.thumbnailUrl
            )
        } ?? []

        // Format updatedAt from ISO8601 to readable date string
        var updatedAtDisplay: String? = nil
        if let rawDate = collection.updatedAt {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate) {
                let rel = RelativeDateTimeFormatter()
                rel.unitsStyle = .abbreviated
                updatedAtDisplay = rel.localizedString(for: date, relativeTo: Date())
            }
        }

        let gameVersion = collection.latestPublishedRevision?.gameVersions?.first?.reference

        var pack = StarHubPack(
            packName: collection.name,
            author: collection.user?.name ?? "Unknown",
            description: collection.summary,
            mods: packMods
        )
        pack.imageUrl = collection.tileImage?.url
        pack.revision = collection.latestPublishedRevision?.revisionNumber
        pack.updatedAt = updatedAtDisplay
        pack.gameVersion = gameVersion
        pack.totalDownloads = collection.totalDownloads
        pack.endorsements = collection.endorsements
        return pack
    }

    /// `key`/`expires` come from an `nxm://` link (see `NXMParser`) and let a non-premium
    /// API key authorize that one download; pass `nil` for both for an in-app-triggered
    /// download (auto-update, "Download All"), which then only succeeds for a premium key.
    func downloadModFromNexus(
        nexusId: Mod.NexusID,
        fileId: Int? = nil,
        key: String? = nil,
        expires: String? = nil,
        nexusApiKey: String,
        installModFromZip: @escaping (URL, @escaping (Bool) -> Void) -> Void,
        showModal: @escaping (String) -> Void
    ) async -> Bool {
        guard !nexusApiKey.isEmpty else { return false }

        let targetFileId: Int
        if let fId = fileId {
            targetFileId = fId
        } else {
            logStore.log("Fetching latest file for Nexus Mod #\(nexusId.rawValue)...")
            do {
                let response = try await nexusAPIClient.modFiles(modId: nexusId.rawValue, apiKey: nexusApiKey)
                guard let latestFile = response.files.first else {
                    logStore.log("No files found for Nexus Mod #\(nexusId.rawValue).")
                    return false
                }
                targetFileId = latestFile.fileId
            } catch {
                logStore.log("Failed to fetch mod files: \(error.localizedDescription)")
                return false
            }
        }

        return await startDownload(nexusId: nexusId, fileId: targetFileId, key: key, expires: expires, apiKey: nexusApiKey, installModFromZip: installModFromZip, showModal: showModal)
    }

    private func startDownload(
        nexusId: Mod.NexusID,
        fileId: Int,
        key: String?,
        expires: String?,
        apiKey: String,
        installModFromZip: @escaping (URL, @escaping (Bool) -> Void) -> Void,
        showModal: @escaping (String) -> Void
    ) async -> Bool {
        logStore.log("Requesting download link for file #\(fileId)...")

        let links: [LiveNexusAPIClient.ModDownloadLink]
        do {
            links = try await nexusAPIClient.downloadLink(modId: nexusId.rawValue, fileId: fileId, key: key, expires: expires, apiKey: apiKey)
        } catch {
            if let nexusError = error as? NexusAPIError, nexusError.isPremiumRequired {
                logStore.log("Download requires Nexus Premium (Mod #\(nexusId.rawValue), File #\(fileId)).")
                showModal(localization.L(L10n.VM.nexusPremiumRequired))
            } else {
                logStore.log("Failed to get download link: \(error.localizedDescription)")
            }
            return false
        }

        guard let firstLink = links.first, let downloadURL = URL(string: firstLink.URI) else {
            logStore.log("No valid download links found.")
            return false
        }

        logStore.log("Starting download for Nexus Mod #\(nexusId.rawValue)...")

        let localURL: URL
        do {
            let (downloaded, _) = try await URLSession.shared.download(for: URLRequest(url: downloadURL))
            localURL = downloaded
        } catch {
            logStore.log("Download failed: \(error.localizedDescription)")
            return false
        }

        let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
        do {
            try FileManager.default.moveItem(at: localURL, to: tempZipURL)
        } catch {
            logStore.log("Failed to process downloaded file: \(error.localizedDescription)")
            return false
        }

        // Pass a continuation into installModFromZip so it resumes AFTER extraction finishes
        return await withCheckedContinuation { continuation in
            installModFromZip(tempZipURL) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Downloads every mod in `packMods` that isn't already installed, one at a time.
    /// Firing every missing mod's download concurrently (the previous "Download All"
    /// behavior) commonly triggers Nexus's rate limiting on a collection with more than
    /// a handful of missing mods, and gave the caller no way to know which ones failed —
    /// this reports an aggregate count instead of silently dropping failures.
    func downloadAllMissing(
        from packMods: [StarHubPackMod],
        currentMods: [Mod],
        nexusApiKey: String,
        installModFromZip: @escaping (URL, @escaping (Bool) -> Void) -> Void,
        showModal: @escaping (String) -> Void
    ) async -> (installed: Int, failed: Int) {
        let missing = packMods.filter { packMod in
            guard let nexusId = packMod.nexusId else { return false }
            return ModGraph.packModStatus(nexusID: nexusId, uniqueId: packMod.uniqueId, in: currentMods) == .missing
        }

        var installed = 0
        var failed = 0

        for packMod in missing {
            guard let nexusId = packMod.nexusId else { continue }
            let success = await downloadModFromNexus(
                nexusId: nexusId,
                nexusApiKey: nexusApiKey,
                installModFromZip: installModFromZip,
                showModal: showModal
            )
            if success { installed += 1 } else { failed += 1 }
        }

        return (installed, failed)
    }
}
