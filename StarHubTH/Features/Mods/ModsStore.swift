import Foundation
import AppKit
import UniformTypeIdentifiers

/// Phase 4.7. The largest store: owns the installed mod list, its filters, custom tags,
/// mod scanning, enable/disable toggling, installation, and Mods-directory backup/restore.
///
/// `gameDir`, `chainToggleDependencies`, `showModal`, `log`, and `refresh` aren't owned
/// here — they belong to AppEnvironment (4.8) or stay on the ViewModel (showModal/log
/// don't have their own store; refresh is cross-store orchestration) — so the affected
/// methods take them as parameters/closures, same approach as every store since 4.3.
/// `syncActiveProfileIds` (ProfilesStore's) is threaded through `toggleMod` the same way.
@MainActor
final class ModsStore: ObservableObject {
    @Published var mods: [ModItem] = []

    @Published var modFilterStatus: ModFilterStatus = .all
    @Published var modFilterTag: String = ""
    @Published var modFilterDate: ModFilterDate = .all
    @Published var modSortOption: ModSortOption = .name

    @Published var outOfDateMods: [ModUpdateInfo] = []
    @Published var smapiErrors: [String] = []
    @Published var isThaiTranslationInstalled: Bool = false

    @Published var isSyncingAllTags = false
    @Published var syncAllTagsProgress: Double = 0.0

    @Published var editingModConfig: ModItem?
    @Published var viewingModDetails: ModItem?

    @Published var downloadingMods: Set<String> = []
    @Published var isInstallingMod: Bool = false

    @Published var selectedMod: ModItem? {
        didSet {
            if let mod = selectedMod, selectedModID != mod.folderName {
                selectedModID = mod.folderName
            }
        }
    }
    @Published var selectedModID: ModItem.FolderName? {
        didSet {
            if let id = selectedModID, selectedMod?.folderName != id {
                selectedMod = mods.first { $0.folderName == id }
            }
        }
    }

    private let modScanning: ModScanning
    private let modInstalling: ModInstalling
    private let nexusAPIClient: NexusAPIClient
    private let filePicking: FilePicking
    private let preferenceStoring: PreferenceStoring
    private let localization: LocalizationStore

    init(
        modScanning: ModScanning,
        modInstalling: ModInstalling,
        nexusAPIClient: NexusAPIClient,
        filePicking: FilePicking,
        preferenceStoring: PreferenceStoring,
        localization: LocalizationStore
    ) {
        self.modScanning = modScanning
        self.modInstalling = modInstalling
        self.nexusAPIClient = nexusAPIClient
        self.filePicking = filePicking
        self.preferenceStoring = preferenceStoring
        self.localization = localization
    }

    // MARK: - Dependency resolution (pure, delegates to ModGraph)

    func resolveDependencyStatus(for uniqueId: ModItem.UniqueID) -> DependencyStatus {
        ModGraph.dependencyStatus(for: uniqueId, in: mods)
    }

    func resolvePackModStatus(nexusId: ModItem.NexusID?, uniqueId: ModItem.UniqueID) -> PackModStatus {
        ModGraph.packModStatus(nexusID: nexusId, uniqueId: uniqueId, in: mods)
    }

    func missingDependencies(for mod: ModItem) -> [ModItem.UniqueID] {
        ModGraph.missingDependencies(for: mod, in: mods)
    }

    // MARK: - Custom Tags

    var customModTags: [String: String] {
        get { preferenceStoring.dictionary(forKey: "customModTags") ?? [:] }
        set { preferenceStoring.set(newValue, forKey: "customModTags") }
    }

    func setCustomTag(for modId: ModItem.UniqueID, tag: String, shouldRefresh: Bool = true, refresh: () -> Void) {
        var tags = customModTags
        tags[modId.rawValue] = tag
        customModTags = tags
        if shouldRefresh { refresh() }
    }

    func resetCustomTag(for modId: ModItem.UniqueID, refresh: () -> Void) {
        var tags = customModTags
        tags.removeValue(forKey: modId.rawValue)
        customModTags = tags
        refresh()
    }

    func syncTagFromNexus(for mod: ModItem, nexusApiKey: String, shouldRefresh: Bool = true, refresh: @escaping () -> Void) async -> Bool {
        guard !nexusApiKey.isEmpty, let url = URL(string: mod.nexusUrl), let modId = Int(url.lastPathComponent) else {
            return false
        }

        guard let info = try? await nexusAPIClient.modInfo(modId: modId, apiKey: nexusApiKey),
              let categoryId = info.categoryId else {
            return false
        }

        let newTag = LiveNexusAPIClient.categoryTag(from: categoryId)
        setCustomTag(for: mod.uniqueId, tag: newTag, shouldRefresh: shouldRefresh, refresh: refresh)
        return true
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
    func syncAllTagsFromNexus(nexusApiKey: String, refresh: @escaping () -> Void) async {
        guard !nexusApiKey.isEmpty else { return }

        isSyncingAllTags = true
        syncAllTagsProgress = 0.0

        let modsToSync = mods.filter { !$0.nexusUrl.isEmpty && Int((URL(string: $0.nexusUrl)?.lastPathComponent) ?? "") != nil }

        guard !modsToSync.isEmpty else {
            isSyncingAllTags = false
            return
        }

        for (index, mod) in modsToSync.enumerated() {
            _ = await syncTagFromNexus(for: mod, nexusApiKey: nexusApiKey, shouldRefresh: false, refresh: refresh)
            syncAllTagsProgress = Double(index + 1) / Double(modsToSync.count)
        }

        isSyncingAllTags = false
        refresh()
    }

    // MARK: - Scanning

    func scanMods(gameDir: String) {
        let scannedMods = modScanning.scan(gameDir: gameDir, customModTags: customModTags)

        parseSMAPILog(gameDir: gameDir)

        mods = scannedMods
        if selectedMod == nil, let first = mods.first {
            selectedMod = first
        }
        isThaiTranslationInstalled = scannedMods.contains {
            ($0.folderName.rawValue.lowercased() == "stardew valley - thai" ||
            $0.name.localizedCaseInsensitiveContains("thai")) && $0.isEnabled
        }
    }

    // Parses the SMAPI-latest.txt log for updates and errors
    func parseSMAPILog(gameDir: String) {
        guard !gameDir.isEmpty else { return }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let logPath = (homeDir as NSString).appendingPathComponent(".config/StardewValley/ErrorLogs/SMAPI-latest.txt")
        guard FileManager.default.fileExists(atPath: logPath),
              let logContent = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            outOfDateMods = []
            smapiErrors = []
            return
        }

        let result = SmapiLogParser.parse(logContent: logContent)
        outOfDateMods = result.outOfDateMods
        smapiErrors = result.errors
    }

    // MARK: - Toggle Mod Status (Enabled / Disabled)

    func toggleMod(
        _ mod: ModItem,
        gameDir: String,
        chainToggleDependencies: Bool,
        log: (String) -> Void,
        onToggled: () -> Void
    ) {
        // Helper to find the top-level folder that contains a given uniqueId
        func topLevelFolder(for uniqueId: ModItem.UniqueID) -> ModItem.FolderName? {
            for m in self.mods {
                switch m.kind {
                case .single:
                    if m.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame {
                        return m.folderName
                    }
                case .group(let children):
                    if children.contains(where: { $0.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame }) {
                        return m.folderName
                    }
                }
            }
            return nil
        }

        // Helper to get all dependencies of a top-level folder (including its children)
        func dependencies(for folderName: ModItem.FolderName) -> [ModDependency] {
            guard let m = self.mods.first(where: { $0.folderName == folderName }) else { return [] }
            if case .group(let children) = m.kind {
                return children.flatMap { $0.dependencies }
            } else {
                return m.dependencies
            }
        }

        var foldersToToggle: Set<ModItem.FolderName> = [mod.folderName]
        let targetState = !mod.isEnabled // True if we are enabling, false if disabling

        if chainToggleDependencies {
            if targetState == true {
                // Enabling: recursively enable all REQUIRED dependencies
                var queue = [mod.folderName]
                while !queue.isEmpty {
                    let currentFolder = queue.removeFirst()
                    let deps = dependencies(for: currentFolder)

                    for dep in deps where dep.isRequired {
                        if let depFolder = topLevelFolder(for: dep.uniqueId) {
                            let isDepFolderEnabled = self.mods.first(where: { $0.folderName == depFolder })?.isEnabled ?? false
                            if !isDepFolderEnabled && !foldersToToggle.contains(depFolder) {
                                foldersToToggle.insert(depFolder)
                                queue.append(depFolder)
                            }
                        }
                    }
                }
            } else {
                // Disabling: recursively disable all enabled mods that REQUIRE this mod
                var queue = [mod.folderName]
                while !queue.isEmpty {
                    let currentFolder = queue.removeFirst()

                    var providedUniqueIds: [ModItem.UniqueID] = []
                    if let m = self.mods.first(where: { $0.folderName == currentFolder }) {
                        if case .group(let children) = m.kind {
                            providedUniqueIds = children.map { $0.uniqueId }
                        } else {
                            providedUniqueIds = [m.uniqueId]
                        }
                    }

                    for otherMod in self.mods where otherMod.isEnabled && !foldersToToggle.contains(otherMod.folderName) {
                        let otherDeps = dependencies(for: otherMod.folderName)
                        let requiresCurrent = otherDeps.contains { dep in
                            dep.isRequired && providedUniqueIds.contains { $0.rawValue.caseInsensitiveCompare(dep.uniqueId.rawValue) == .orderedSame }
                        }
                        if requiresCurrent {
                            foldersToToggle.insert(otherMod.folderName)
                            queue.append(otherMod.folderName)
                        }
                    }
                }
            }
        }
        // else: chainToggleDependencies == false → only toggle the single mod itself

        let fm = FileManager.default
        let modsPath = (gameDir as NSString).appendingPathComponent("Mods")
        let disabledModsPath = (gameDir as NSString).appendingPathComponent("Mods_disabled")
        var anyMoved = false

        for folderName in foldersToToggle {
            guard let m = self.mods.first(where: { $0.folderName == folderName }) else { continue }
            if m.isEnabled == targetState { continue }

            let srcPath = ((m.isEnabled ? modsPath : disabledModsPath) as NSString).appendingPathComponent(m.folderName.rawValue)
            let destFolder = m.isEnabled ? disabledModsPath : modsPath
            let destPath = ((destFolder as NSString).appendingPathComponent(m.folderName.rawValue) as String)

            let destBackup = "\(destPath)_toggle_backup_temp"
            do {
                let destParent = (destPath as NSString).deletingLastPathComponent
                if !fm.fileExists(atPath: destParent) {
                    try fm.createDirectory(atPath: destParent, withIntermediateDirectories: true, attributes: nil)
                }
                if fm.fileExists(atPath: destPath) {
                    if fm.fileExists(atPath: destBackup) {
                        try? fm.removeItem(atPath: destBackup)
                    }
                    try fm.moveItem(atPath: destPath, toPath: destBackup)
                }

                do {
                    try fm.moveItem(atPath: srcPath, toPath: destPath)
                    if fm.fileExists(atPath: destBackup) {
                        try? fm.trashItem(at: URL(fileURLWithPath: destBackup), resultingItemURL: nil)
                    }
                    anyMoved = true
                } catch {
                    if fm.fileExists(atPath: destBackup) && !fm.fileExists(atPath: destPath) {
                        try? fm.moveItem(atPath: destBackup, toPath: destPath)
                    }
                    throw error
                }
            } catch {
                print("Failed to toggle \(m.name): \(error.localizedDescription)")
            }
        }

        if anyMoved {
            log("\(targetState ? localization.L(L10n.Mods.enabled) : localization.L(L10n.Mods.disabled)): \(mod.name)\(foldersToToggle.count > 1 ? " + Dependencies" : "")")
            self.scanMods(gameDir: gameDir)
            onToggled()
        }
    }

    // MARK: - Install Mod (ZIP or Folder)

    func openInstallModPanel(gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async {
        let urls = filePicking.pickFiles(
            title: localization.L(L10n.Mods.installMod),
            allowedContentTypes: [.init(filenameExtension: "zip")!],
            allowsMultipleSelection: true,
            canChooseDirectories: true   // ← also accept extracted folders
        )
        for url in urls {
            _ = await installMod(url: url, gameDir: gameDir, showModal: showModal, log: log)
        }
    }

    /// Entry point — detects whether the URL is a .zip or a folder and routes accordingly.
    @discardableResult
    func installMod(url: URL, gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async -> Bool {
        guard !gameDir.isEmpty else {
            showModal(localization.L(L10n.Settings.gameDirNotSet))
            return false
        }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        if isDir.boolValue {
            return await installModFromFolder(url: url, gameDir: gameDir, showModal: showModal, log: log)
        } else if url.pathExtension.lowercased() == "zip" {
            return await installModFromZip(url: url, gameDir: gameDir, showModal: showModal, log: log)
        } else {
            showModal(localization.L(L10n.Mods.installInvalidFile))
            return false
        }
    }

    /// Installs a mod from a .zip file
    @discardableResult
    func installModFromZip(url: URL, gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async -> Bool {
        isInstallingMod = true
        do {
            let installedNames = try await modInstalling.installFromZip(url: url, gameDir: gameDir)
            return handleInstallResult(.success(installedNames), gameDir: gameDir, showModal: showModal, log: log)
        } catch {
            return handleInstallResult(.failure(error), gameDir: gameDir, showModal: showModal, log: log)
        }
    }

    /// Installs a mod from an already-extracted folder.
    @discardableResult
    func installModFromFolder(url: URL, gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async -> Bool {
        isInstallingMod = true
        do {
            let installedNames = try await modInstalling.installFromFolder(url: url, gameDir: gameDir)
            return handleInstallResult(.success(installedNames), gameDir: gameDir, showModal: showModal, log: log)
        } catch {
            return handleInstallResult(.failure(error), gameDir: gameDir, showModal: showModal, log: log)
        }
    }

    @discardableResult
    private func handleInstallResult(_ result: Result<[String], ModInstallerError>, gameDir: String, showModal: (String) -> Void, log: (String) -> Void) -> Bool {
        isInstallingMod = false
        switch result {
        case .success(let installedNames):
            let names = installedNames.joined(separator: ", ")
            let msg = String(format: localization.L(L10n.Mods.installSuccess), names)
            showModal(msg)
            log(msg)
            scanMods(gameDir: gameDir)
            return true
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
            return false
        }
    }

    // MARK: - Nexus Auto-Download

    func downloadAndInstallUpdate(for mod: ModUpdateInfo, nexusId: ModItem.NexusID, nexusApiKey: String, gameDir: String, showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async {
        downloadingMods.insert(mod.name)

        do {
            let zipUrl = try await NexusDownloader.downloadUpdate(nexusId: nexusId, apiKey: nexusApiKey)
            downloadingMods.remove(mod.name)
            await installModFromZip(url: zipUrl, gameDir: gameDir, showModal: showModal, log: log)
        } catch {
            downloadingMods.remove(mod.name)
            if let downloaderError = error as? NexusDownloaderError, case .premiumRequired = downloaderError {
                showModal(localization.L(L10n.VM.nexusPremiumRequired))
            } else {
                showModal(error.localizedDescription)
            }
        }
    }

    // MARK: - Mods-directory backup & restore

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

    func backUp(_ mod: ModItem, gameDir: String, showModal: @escaping (String) -> Void) async {
        guard !gameDir.isEmpty else {
            showModal(localization.L(L10n.Settings.gameDirNotSet))
            return
        }
        let basePath = (gameDir as NSString).appendingPathComponent(mod.isEnabled ? "Mods" : "Mods_disabled")
        let modDir = (basePath as NSString).appendingPathComponent(mod.folderName.rawValue)
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "")
        let defaultFileName = "\(mod.folderName.rawValue)_Backup_\(timestamp).zip"

        let panel = NSSavePanel()
        panel.title = "Save Backup"
        panel.nameFieldStringValue = defaultFileName
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

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

    func restore(_ mod: ModItem, gameDir: String, showModal: @escaping (String) -> Void) async {
        guard !gameDir.isEmpty else {
            showModal(localization.L(L10n.Settings.gameDirNotSet))
            return
        }
        let basePath = (gameDir as NSString).appendingPathComponent(mod.isEnabled ? "Mods" : "Mods_disabled")
        let modDir = (basePath as NSString).appendingPathComponent(mod.folderName.rawValue)

        let panel = NSOpenPanel()
        panel.title = "Select Mod Backup (.zip)"
        panel.allowedContentTypes = [.init(filenameExtension: "zip")!]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let zipUrl = panel.url else { return }

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
