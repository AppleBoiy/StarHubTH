import Foundation

/// Mods-directory backup & restore (§ file-size convention split, see ModsStore.swift's
/// header comment).
extension ModsStore {
    func backupAllMods(gameDir: String, showModal: (String) -> Void) {
        guard !gameDir.isEmpty else {
            showModal(localization.L(L10n.Settings.gameDirNotSet))
            return
        }
        let modsDir = (gameDir as NSString).appendingPathComponent("Mods")
        let home = NSHomeDirectory()
        let desktopDir = "\(home)/Desktop"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "")
        let zipPath = "\(desktopDir)/StardewMods_Backup_\(timestamp).zip"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath, "."]
        process.currentDirectoryURL = URL(fileURLWithPath: modsDir)

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                showModal(String(format: localization.L(L10n.VM.backupModsSuccess), zipPath))
            } else {
                showModal(localization.L(L10n.VM.zipModsError))
            }
        } catch {
            showModal(localization.L(L10n.VM.cannotRunZip))
        }
    }

    /// Runs a zip/unzip `Process` off the calling actor and resumes once it exits — the
    /// shared plumbing behind `backUp`/`restore`.
    private func runProcess(executable: String, arguments: [String], currentDirectory: URL? = nil) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            // Process.run()/waitUntilExit() are synchronous-blocking with no async form —
            // off-load to a background queue so the caller's actor isn't blocked.
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                if let currentDirectory { process.currentDirectoryURL = currentDirectory }
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func backUp(_ mod: Mod, gameDir: String, showModal: @escaping (String) -> Void) async {
        guard !gameDir.isEmpty else {
            showModal(localization.L(L10n.Settings.gameDirNotSet))
            return
        }
        let basePath = (gameDir as NSString).appendingPathComponent(mod.isEnabled ? "Mods" : "Mods_disabled")
        let modDir = (basePath as NSString).appendingPathComponent(mod.folderName.rawValue)
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "")
        let defaultFileName = "\(mod.folderName.rawValue)_Backup_\(timestamp).zip"

        guard let url = filePicking.pickSaveLocation(title: "Save Backup", suggestedName: defaultFileName, allowedContentTypes: [.zip]) else { return }

        do {
            let status = try await runProcess(executable: "/usr/bin/zip", arguments: ["-r", url.path, "."], currentDirectory: URL(fileURLWithPath: modDir))
            if status == 0 {
                showModal(String(format: localization.L(L10n.VM.backupModsSuccess), url.path))
            } else {
                showModal(localization.L(L10n.VM.zipModsError))
            }
        } catch {
            showModal(localization.L(L10n.VM.cannotRunZip))
        }
    }

    func restore(_ mod: Mod, gameDir: String, showModal: @escaping (String) -> Void) async {
        guard !gameDir.isEmpty else {
            showModal(localization.L(L10n.Settings.gameDirNotSet))
            return
        }
        let basePath = (gameDir as NSString).appendingPathComponent(mod.isEnabled ? "Mods" : "Mods_disabled")
        let modDir = (basePath as NSString).appendingPathComponent(mod.folderName.rawValue)

        let urls = filePicking.pickFiles(
            title: "Select Mod Backup (.zip)",
            allowedContentTypes: [.init(filenameExtension: "zip")!],
            allowsMultipleSelection: false,
            canChooseDirectories: false
        )
        guard let zipUrl = urls.first else { return }

        do {
            let status = try await runProcess(executable: "/usr/bin/unzip", arguments: ["-o", zipUrl.path, "-d", modDir])
            if status == 0 {
                showModal(localization.L(L10n.VM.modZipRestoreSuccess))
                scanMods(gameDir: gameDir)
            } else {
                showModal(localization.L(L10n.VM.modZipRestoreFailed))
            }
        } catch {
            showModal(localization.L(L10n.VM.modZipRestoreError))
        }
    }

    func cleanDisabledMods(gameDir: String, showModal: (String) -> Void) {
        guard !gameDir.isEmpty else { return }
        let disabledModsPath = (gameDir as NSString).appendingPathComponent("Mods_disabled")
        do {
            if FileManager.default.fileExists(atPath: disabledModsPath) {
                try FileManager.default.removeItem(atPath: disabledModsPath)
                showModal(localization.L(L10n.VM.cleanModsSuccess))
                self.scanMods(gameDir: gameDir)
            } else {
                showModal(localization.L(L10n.VM.cleanModsNotFound))
            }
        } catch {
            showModal(String(format: localization.L(L10n.VM.cleanModsError), error.localizedDescription))
        }
    }
}
