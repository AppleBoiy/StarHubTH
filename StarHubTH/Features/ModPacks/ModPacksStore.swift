import Foundation
import AppKit

/// Phase 4.5. Owns mod-pack export/import/collection-fetch and the Nexus download flow
/// used to fill in a pack's missing mods.
///
/// `mods`, `steamUsername`, `nexusApiKey`, `showModal`, and `installModFromZip` aren't
/// owned here — they belong to ModsStore (4.7) and AppEnvironment (4.8), neither
/// extracted yet — so the affected methods take them as parameters/closures, same
/// approach as ThaiHubStore (4.3) and ProfilesStore (4.4).
///
/// Not yet `@MainActor`, same reason as every store so far. `importedModPack` only ever
/// mutates through the exposed setter (never from inside this store's own methods —
/// they hand results back via a completion closure instead), so unlike LogStore/
/// ThaiHubStore/ProfilesStore this store doesn't need the objectWillChange-forwarding
/// Combine subscription; a manual send() in the ViewModel's forwarding setter is enough.
final class ModPacksStore: ObservableObject {
    @Published var importedModPack: StarHubPack?

    private let nexusAPIClient: NexusAPIClient
    private let localization: LocalizationStore
    private let logStore: LogStore

    init(nexusAPIClient: NexusAPIClient, localization: LocalizationStore, logStore: LogStore) {
        self.nexusAPIClient = nexusAPIClient
        self.localization = localization
        self.logStore = logStore
    }

    func exportModPack(name: String, mods: [ModItem], steamUsername: String, showModal: (String) -> Void) -> URL? {
        let packMods = mods.flatMap { mod -> [StarHubPackMod] in
            if case .group(let children) = mod.kind {
                return children.filter { $0.isEnabled }.map {
                    let nexusId = Int($0.nexusUrl.components(separatedBy: "/").last ?? "").map { ModItem.NexusID(rawValue: $0) }
                    return StarHubPackMod(name: $0.name, uniqueId: $0.uniqueId, version: $0.version, nexusId: nexusId)
                }
            }
            if mod.isEnabled {
                let nexusId = Int(mod.nexusUrl.components(separatedBy: "/").last ?? "").map { ModItem.NexusID(rawValue: $0) }
                return [StarHubPackMod(name: mod.name, uniqueId: mod.uniqueId, version: mod.version, nexusId: nexusId)]
            }
            return []
        }

        let pack = StarHubPack(packName: name, author: steamUsername.isEmpty ? "Player" : steamUsername, description: nil, mods: packMods)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(pack) else { return nil }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "\(name.replacingOccurrences(of: " ", with: "_")).starhubpack"
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try data.write(to: url)
                return url
            } catch {
                showModal(localization.L(L10n.VM.packSaveFailed))
            }
        }
        return nil
    }

    func importModPack(from url: URL) -> StarHubPack? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(StarHubPack.self, from: data)
        } catch {
            print("Failed to decode Mod Pack: \(error)")
            return nil
        }
    }

    func importCollectionFromURL(_ urlString: String, nexusApiKey: String, showModal: @escaping (String) -> Void, completion: @escaping (StarHubPack?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let path = url.path
        let components = path.components(separatedBy: "/")
        // Extract slug from e.g. /stardewvalley/collections/tckf0m
        var slug = ""
        if let idx = components.firstIndex(of: "collections"), idx + 1 < components.count {
            slug = components[idx + 1]
        }

        if slug.isEmpty {
            completion(nil)
            return
        }

        if nexusApiKey.isEmpty {
            showModal(localization.L(L10n.VM.collectionApiKeyRequired))
            completion(nil)
            return
        }

        logStore.log("Fetching collection metadata for slug: \(slug)...")
        nexusAPIClient.getCollectionGraph(slug: slug, apiKey: nexusApiKey) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let collection):
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
                            uniqueId: ModItem.UniqueID(rawValue: "nexus_\(modDetail.modId)"),
                            version: detail.version ?? "",
                            nexusId: ModItem.NexusID(rawValue: modDetail.modId),
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
                    completion(pack)
                case .failure(_):
                    showModal(self.localization.L(L10n.VM.collectionFetchFailed))
                    completion(nil)
                }
            }
        }
    }

    /// `key`/`expires` come from an `nxm://` link (see `NXMParser`) and let a non-premium
    /// API key authorize that one download; pass `nil` for both for an in-app-triggered
    /// download (auto-update, "Download All"), which then only succeeds for a premium key.
    func downloadModFromNexus(
        nexusId: ModItem.NexusID,
        fileId: Int? = nil,
        key: String? = nil,
        expires: String? = nil,
        nexusApiKey: String,
        installModFromZip: @escaping (URL, @escaping (Bool) -> Void) -> Void,
        showModal: @escaping (String) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        if nexusApiKey.isEmpty {
            completion(false)
            return
        }

        let targetFileId: Int

        if let fId = fileId {
            targetFileId = fId
            startDownload(nexusId: nexusId, fileId: targetFileId, key: key, expires: expires, apiKey: nexusApiKey, installModFromZip: installModFromZip, showModal: showModal, completion: completion)
        } else {
            logStore.log("Fetching latest file for Nexus Mod #\(nexusId.rawValue)...")
            nexusAPIClient.getModFiles(modId: nexusId.rawValue, apiKey: nexusApiKey) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    guard let latestFile = response.files.first else {
                        self.logStore.log("No files found for Nexus Mod #\(nexusId.rawValue).")
                        completion(false)
                        return
                    }
                    self.startDownload(nexusId: nexusId, fileId: latestFile.fileId, key: key, expires: expires, apiKey: nexusApiKey, installModFromZip: installModFromZip, showModal: showModal, completion: completion)
                case .failure(let error):
                    self.logStore.log("Failed to fetch mod files: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }

    private func startDownload(
        nexusId: ModItem.NexusID,
        fileId: Int,
        key: String?,
        expires: String?,
        apiKey: String,
        installModFromZip: @escaping (URL, @escaping (Bool) -> Void) -> Void,
        showModal: @escaping (String) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        logStore.log("Requesting download link for file #\(fileId)...")
        nexusAPIClient.getDownloadLink(modId: nexusId.rawValue, fileId: fileId, key: key, expires: expires, apiKey: apiKey) { [weak self] linkResult in
            guard let self = self else { return }
            switch linkResult {
            case .success(let links):
                guard let firstLink = links.first, let downloadURL = URL(string: firstLink.URI) else {
                    self.logStore.log("No valid download links found.")
                    completion(false)
                    return
                }

                self.logStore.log("Starting download for Nexus Mod #\(nexusId.rawValue)...")
                let task = URLSession.shared.downloadTask(with: downloadURL) { localURL, response, error in
                    if let error = error {
                        self.logStore.log("Download failed: \(error.localizedDescription)")
                        completion(false)
                        return
                    }

                    guard let localURL = localURL else {
                        completion(false)
                        return
                    }

                    // Move to a temp zip file
                    let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
                    do {
                        try FileManager.default.moveItem(at: localURL, to: tempZipURL)
                        DispatchQueue.main.async {
                            // Pass completion into installModFromZip so it fires AFTER extraction finishes
                            installModFromZip(tempZipURL, completion)
                        }
                    } catch {
                        self.logStore.log("Failed to process downloaded file: \(error.localizedDescription)")
                        completion(false)
                    }
                }
                task.resume()

            case .failure(let error):
                if let nexusError = error as? NexusAPIError, nexusError.isPremiumRequired {
                    self.logStore.log("Download requires Nexus Premium (Mod #\(nexusId.rawValue), File #\(fileId)).")
                    showModal(self.localization.L(L10n.VM.nexusPremiumRequired))
                } else {
                    self.logStore.log("Failed to get download link: \(error.localizedDescription)")
                }
                completion(false)
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
        currentMods: [ModItem],
        nexusApiKey: String,
        installModFromZip: @escaping (URL, @escaping (Bool) -> Void) -> Void,
        showModal: @escaping (String) -> Void,
        completion: @escaping (_ installed: Int, _ failed: Int) -> Void
    ) {
        let missing = packMods.filter { packMod in
            guard let nexusId = packMod.nexusId else { return false }
            return ModGraph.packModStatus(nexusID: nexusId, uniqueId: packMod.uniqueId, in: currentMods) == .missing
        }

        func step(_ index: Int, installed: Int, failed: Int) {
            guard index < missing.count else {
                completion(installed, failed)
                return
            }
            guard let nexusId = missing[index].nexusId else {
                step(index + 1, installed: installed, failed: failed)
                return
            }
            downloadModFromNexus(
                nexusId: nexusId,
                nexusApiKey: nexusApiKey,
                installModFromZip: installModFromZip,
                showModal: showModal
            ) { success in
                step(index + 1, installed: installed + (success ? 1 : 0), failed: failed + (success ? 0 : 1))
            }
        }

        step(0, installed: 0, failed: 0)
    }
}
