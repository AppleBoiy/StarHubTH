import Foundation

/// Mod installation (ZIP or folder) and Nexus auto-download-and-install (§ file-size
/// convention split, see ModsStore.swift's header comment).
extension ModsStore {
    func openInstallModPanel(gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async {
        let urls = filePicking.pickFiles(
            title: localization.L(L10n.Mods.installMod),
            allowedContentTypes: [.init(filenameExtension: "zip")!],
            allowsMultipleSelection: true,
            canChooseDirectories: true   // ← also accept extracted folders
        )
        for url in urls {
            // Each picked file/folder installs independently — one failing (already
            // shown to the user via showModal inside installMod) shouldn't stop the
            // rest of a multi-selection from being attempted.
            try? await installMod(url: url, gameDir: gameDir, showModal: showModal, log: log)
        }
    }

    /// Entry point — detects whether the URL is a .zip or a folder and routes accordingly.
    func installMod(url: URL, gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async throws(ModInstallerError) {
        guard !gameDir.isEmpty else {
            showModal(localization.L(L10n.Settings.gameDirNotSet))
            return
        }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        if isDir.boolValue {
            try await installModFromFolder(url: url, gameDir: gameDir, showModal: showModal, log: log)
        } else if url.pathExtension.lowercased() == "zip" {
            try await installModFromZip(url: url, gameDir: gameDir, showModal: showModal, log: log)
        } else {
            showModal(localization.L(L10n.Mods.installInvalidFile))
        }
    }

    /// Installs a mod from a .zip file
    func installModFromZip(url: URL, gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async throws(ModInstallerError) {
        isInstallingMod = true
        do {
            let installedNames = try await modInstalling.installFromZip(url: url, gameDir: gameDir)
            try handleInstallResult(.success(installedNames), gameDir: gameDir, showModal: showModal, log: log)
        } catch {
            try handleInstallResult(.failure(error), gameDir: gameDir, showModal: showModal, log: log)
        }
    }

    /// Installs a mod from an already-extracted folder.
    func installModFromFolder(url: URL, gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async throws(ModInstallerError) {
        isInstallingMod = true
        do {
            let installedNames = try await modInstalling.installFromFolder(url: url, gameDir: gameDir)
            try handleInstallResult(.success(installedNames), gameDir: gameDir, showModal: showModal, log: log)
        } catch {
            try handleInstallResult(.failure(error), gameDir: gameDir, showModal: showModal, log: log)
        }
    }

    private func handleInstallResult(_ result: Result<[String], ModInstallerError>, gameDir: String, showModal: (String) -> Void, log: (String) -> Void) throws(ModInstallerError) {
        isInstallingMod = false
        switch result {
        case .success(let installedNames):
            let names = installedNames.joined(separator: ", ")
            let msg = String(format: localization.L(L10n.Mods.installSuccess), names)
            showModal(msg)
            log(msg)
            scanMods(gameDir: gameDir)
        case .failure(let error):
            switch error {
            case .noModFound:
                log("Install failed: No manifest.json found in extracted content (gameDir: \(gameDir))")
                showModal(localization.L(L10n.Mods.installNoModFound))
            case .unzipProcessError:
                log("Install failed: unzip process error")
                showModal(localization.L(L10n.VM.unzipError))
            case .unzipFailed(let msg), .other(let msg):
                log("Install failed: \(msg)")
                showModal(String(format: localization.L(L10n.VM.unzipFailed), msg))
            }
            throw error
        }
    }

    func downloadAndInstallUpdate(for mod: ModUpdateInfo, nexusId: Mod.NexusID, nexusApiKey: String, gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async {
        downloadingMods.insert(mod.name)

        let zipUrl: URL
        do {
            zipUrl = try await NexusDownloader.downloadUpdate(nexusId: nexusId, apiKey: nexusApiKey, nexusAPIClient: nexusAPIClient)
        } catch {
            downloadingMods.remove(mod.name)
            if let downloaderError = error as? NexusDownloaderError, case .premiumRequired = downloaderError {
                showModal(localization.L(L10n.VM.nexusPremiumRequired))
            } else {
                showModal(error.localizedDescription)
            }
            return
        }
        downloadingMods.remove(mod.name)
        // installModFromZip already shows its own success/failure message via showModal.
        try? await installModFromZip(url: zipUrl, gameDir: gameDir, showModal: showModal, log: log)
    }
}
