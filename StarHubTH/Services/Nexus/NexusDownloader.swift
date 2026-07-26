import Foundation

enum NexusDownloaderError: Error, LocalizedError {
    case missingAPIKey
    case noValidFile
    case noDownloadLink
    case premiumRequired
    case downloadFailed(String)
    case moveFailed(String)
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No Nexus API key configured."
        case .noValidFile: return "Could not find a valid file to download."
        case .noDownloadLink: return "Could not obtain download link."
        case .premiumRequired: return "This download requires a Nexus Premium account."
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .moveFailed(let msg): return "File move error: \(msg)"
        case .fetchFailed(let msg): return "Failed to fetch mod files: \(msg)"
        }
    }
}

struct NexusDownloader {
    static func downloadUpdate(
        nexusId: Mod.NexusID,
        apiKey: String,
        nexusAPIClient: NexusAPIClient
    ) async throws -> URL {
        guard !apiKey.isEmpty else {
            throw NexusDownloaderError.missingAPIKey
        }

        let fileList: LiveNexusAPIClient.ModFileListResponse
        do {
            fileList = try await nexusAPIClient.modFiles(modId: nexusId.rawValue, apiKey: apiKey)
        } catch {
            throw NexusDownloaderError.fetchFailed(error.localizedDescription)
        }

        let mainFiles = fileList.files.filter { $0.categoryId == 1 }
        let newest = mainFiles.sorted { $0.fileId > $1.fileId }.first
        let targetFile = newest ?? fileList.files.sorted { $0.fileId > $1.fileId }.first
        guard let fileId = targetFile?.fileId else {
            throw NexusDownloaderError.noValidFile
        }

        // No `key`/`expires` here — auto-update isn't triggered from an `nxm://` link,
        // so this only succeeds for a premium key.
        let links: [LiveNexusAPIClient.ModDownloadLink]
        do {
            links = try await nexusAPIClient.downloadLink(modId: nexusId.rawValue, fileId: fileId, key: nil, expires: nil, apiKey: apiKey)
        } catch {
            if let nexusError = error as? NexusAPIError, nexusError.isPremiumRequired {
                throw NexusDownloaderError.premiumRequired
            }
            throw NexusDownloaderError.downloadFailed(error.localizedDescription)
        }

        guard let downloadLink = links.first?.URI, let url = URL(string: downloadLink) else {
            throw NexusDownloaderError.noDownloadLink
        }

        let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        let (localURL, _): (URL, URLResponse)
        do {
            (localURL, _) = try await URLSession.shared.download(for: URLRequest(url: url))
        } catch {
            throw NexusDownloaderError.downloadFailed(error.localizedDescription)
        }

        do {
            try FileManager.default.moveItem(at: localURL, to: tempZipURL)
        } catch {
            throw NexusDownloaderError.moveFailed(error.localizedDescription)
        }

        return tempZipURL
    }
}
